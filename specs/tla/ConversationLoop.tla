--------------------------- MODULE ConversationLoop ---------------------------
(***************************************************************************)
(* The multi-turn tool-calling loop behind every agent wake and evolution *)
(* chat: ConversationRepository.sendMessage driving one ConversationManager*)
(* history, with a ConversationStrategy deciding after each tool round.   *)
(*                                                                         *)
(* The history is a sequence of messages: the system prompt, the          *)
(* truncation notice, user turns, assistant turns carrying tool-call ids, *)
(* and tool results naming the id they answer. A tool-call id is          *)
(* [t |-> turn, i |-> n], the `tool_turn<t>_<n>` the Gemini adapters      *)
(* synthesize from the turn index the repository passes them. Each sender *)
(* makes sendMessage calls on the same conversation; the awaits in one    *)
(* (the attribution session, the stream, every tool execution) are where  *)
(* another sender's call can interleave.                                   *)
(*                                                                         *)
(*   Begin     sendMessage: (wait for the conversation,) addUserMessage + *)
(*             _trimHistoryIfNeeded, then canContinue()                    *)
(*   Again     the caller sends again: the task agent's forced            *)
(*             update_report retry, the next evolution chat message        *)
(*   Request   the top of the while loop: getMessagesForRequest and        *)
(*             turnIndex = manager.turnCount, then the provider call       *)
(*   Reply     the stream completes: addAssistantMessage with k tool calls*)
(*             (k = 0: no tool calls, the loop ends)                       *)
(*   Answer    strategy.processToolCalls: one addToolResponse per call,    *)
(*             each after an await (a tool execution, a log write)         *)
(*   Throw     processToolCalls throws part-way (a failed write); the      *)
(*             outer catch stores the error and the loop ends              *)
(*   Decide    the strategy's action: continueConversation with a         *)
(*             continuation prompt (addUserMessage + trim, canContinue())  *)
(*             or the end (complete, wait, a null prompt)                  *)
(*                                                                         *)
(* The switches are the fixes; FALSE is the code before them:             *)
(*   MonotonicTurns   turnCount counts the user turns ever added, not the *)
(*                    user messages the trimmed history still holds        *)
(*   TailFromUser     a trim keeps the tail from its first user message,   *)
(*                    not merely from its first message that is not a tool *)
(*                    result                                               *)
(*   AnswerPending    a loop that ends with tool calls unanswered answers  *)
(*                    each with an error result                            *)
(*   Serialize        sendMessage calls on one conversation run one after  *)
(*                    the other                                            *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS Senders, SendsEach, MaxTurns, MaxHistory, MaxCalls, ThrowBudget,
          MonotonicTurns, TailFromUser, AnswerPending, Serialize

ASSUME MaxHistory >= 3 /\ MaxTurns >= 1 /\ MaxCalls >= 1

S == 1..Senders
NoId == [t |-> 0, i |-> 0]
Msg(r, calls, id) == [r |-> r, calls |-> calls, id |-> id]
Sys == Msg("sys", <<>>, NoId)
Note == Msg("note", <<>>, NoId)
User == Msg("user", <<>>, NoId)

Range(q) == {q[j] : j \in DOMAIN q}

VARIABLES hist, turns, pc, pend, turnOf, rounds, sends, holder, issued,
          reused, bad, throws

vars == <<hist, turns, pc, pend, turnOf, rounds, sends, holder, issued,
          reused, bad, throws>>

------------------------------------------------------------------------------
(* ConversationManager *)

UserCount(h) == Cardinality({p \in DOMAIN h : h[p].r = "user"})

(* turnCount: before the fix, the user messages left after trimming *)
TurnCount(h, t) == IF MonotonicTurns THEN t ELSE UserCount(h)

(* The retained tail must not open on a message whose context was cut. *)
RECURSIVE DropLead(_)
DropLead(tail) ==
    IF tail = <<>> THEN tail
    ELSE IF (TailFromUser /\ Head(tail).r # "user")
            \/ (~TailFromUser /\ Head(tail).r = "tool")
         THEN DropLead(Tail(tail))
         ELSE tail

(* _trimHistoryIfNeeded; every caller passes a system prompt *)
Trim(h) ==
    IF Len(h) <= MaxHistory THEN h
    ELSE LET keep == MaxHistory - 2
             body == SelectSeq(Tail(h), LAMBDA m : m.r # "note")
             from == IF Len(body) > keep THEN Len(body) - keep ELSE 0
             had == \E p \in DOMAIN h : h[p].r = "note"
             tail == DropLead(SubSeq(body, from + 1, Len(body)))
         IN IF (from = 0 /\ ~had) \/ tail = <<>> THEN h
            ELSE <<Sys, Note>> \o tail

(* addUserMessage: append and trim; after the fix, also count the turn *)
AddUser(h) == Trim(Append(h, User))
NextTurns == IF MonotonicTurns THEN turns + 1 ELSE turns

------------------------------------------------------------------------------
(* What a strict provider rejects *)

(* The nearest message before p that is not a tool result *)
Owner(h, p) == LET qs == {q \in 1..(p - 1) : h[q].r # "tool"}
               IN IF qs = {} THEN 0
                  ELSE CHOOSE q \in qs : \A o \in qs : o <= q

OrphanResult(h) ==
    \E p \in DOMAIN h :
       /\ h[p].r = "tool"
       /\ LET q == Owner(h, p)
          IN q = 0 \/ h[q].r # "assistant" \/ h[p].id \notin Range(h[q].calls)

Answered(h, q) ==
    \A c \in Range(h[q].calls) :
       \E p \in (q + 1)..Len(h) : /\ h[p].r = "tool" /\ h[p].id = c
                                  /\ Owner(h, p) = q

UnansweredCall(h) ==
    \E q \in DOMAIN h : h[q].r = "assistant" /\ ~Answered(h, q)

(* After the system instructions, the first turn is the user's *)
OpensWithUser(h) ==
    LET ps == {p \in DOMAIN h : h[p].r \notin {"sys", "note"}}
    IN ps = {} \/ h[CHOOSE p \in ps : \A o \in ps : p <= o].r = "user"

Faults(h) ==
    (IF OrphanResult(h) THEN {"orphan"} ELSE {})
    \cup (IF UnansweredCall(h) THEN {"unanswered"} ELSE {})
    \cup (IF OpensWithUser(h) THEN {} ELSE {"opening"})

------------------------------------------------------------------------------
(* ConversationRepository.sendMessage *)

Init ==
    /\ hist = <<Sys>>
    /\ turns = 0
    /\ pc = [s \in S |-> "idle"]
    /\ pend = [s \in S |-> <<>>]
    /\ turnOf = [s \in S |-> 0]
    /\ rounds = [s \in S |-> 0]
    /\ sends = [s \in S |-> 0]
    /\ holder = 0
    /\ issued = {}
    /\ reused = FALSE
    /\ bad = {}
    /\ throws = 0

Release(s) == IF holder = s THEN 0 ELSE holder

(* Leave the loop; after the fix, answer what the round left open. *)
Finish(s, h) ==
    /\ hist' = IF AnswerPending
               THEN h \o [j \in 1..Len(pend[s]) |->
                             Msg("tool", <<>>, pend[s][j])]
               ELSE h
    /\ pc' = [pc EXCEPT ![s] = "done"]
    /\ pend' = [pend EXCEPT ![s] = <<>>]
    /\ holder' = Release(s)

Begin(s) ==
    /\ pc[s] = "idle" /\ sends[s] < SendsEach
    /\ ~Serialize \/ holder = 0
    /\ sends' = [sends EXCEPT ![s] = @ + 1]
    /\ rounds' = [rounds EXCEPT ![s] = 0]
    /\ LET h == AddUser(hist)
           t == NextTurns
           go == TurnCount(h, t) < MaxTurns
       IN /\ turns' = t
          /\ hist' = h
          /\ pc' = [pc EXCEPT ![s] = IF go THEN "request" ELSE "done"]
          /\ holder' = IF Serialize /\ go THEN s ELSE holder
    /\ UNCHANGED <<pend, turnOf, issued, reused, bad, throws>>

Again(s) ==
    /\ pc[s] = "done" /\ sends[s] < SendsEach
    /\ pc' = [pc EXCEPT ![s] = "idle"]
    /\ UNCHANGED <<hist, turns, pend, turnOf, rounds, sends, holder, issued,
                   reused, bad, throws>>

(* The request is built from the history as it stands. rounds saturates *)
(* one past the limit, so a runaway loop stays a finite state space.     *)
Request(s) ==
    /\ pc[s] = "request"
    /\ bad' = bad \cup Faults(hist)
    /\ turnOf' = [turnOf EXCEPT ![s] = TurnCount(hist, turns)]
    /\ rounds' = [rounds EXCEPT ![s] = IF @ > MaxTurns THEN @ ELSE @ + 1]
    /\ pc' = [pc EXCEPT ![s] = "reply"]
    /\ UNCHANGED <<hist, turns, pend, sends, holder, issued, reused, throws>>

Reply(s) ==
    /\ pc[s] = "reply"
    /\ \E k \in 0..MaxCalls :
         LET ids == [j \in 1..k |-> [t |-> turnOf[s], i |-> j]]
         IN /\ issued' = issued \cup Range(ids)
            /\ reused' = (reused \/ Range(ids) \cap issued # {})
            /\ hist' = Append(hist, Msg("assistant", ids, NoId))
            /\ IF k = 0
               THEN /\ pc' = [pc EXCEPT ![s] = "done"]
                    /\ holder' = Release(s)
                    /\ UNCHANGED pend
               ELSE /\ pend' = [pend EXCEPT ![s] = ids]
                    /\ pc' = [pc EXCEPT ![s] = "tools"]
                    /\ UNCHANGED holder
    /\ UNCHANGED <<turns, turnOf, rounds, sends, bad, throws>>

Answer(s) ==
    /\ pc[s] = "tools" /\ pend[s] # <<>>
    /\ hist' = Append(hist, Msg("tool", <<>>, Head(pend[s])))
    /\ pend' = [pend EXCEPT ![s] = Tail(@)]
    /\ UNCHANGED <<turns, pc, turnOf, rounds, sends, holder, issued, reused,
                   bad, throws>>

Throw(s) ==
    /\ pc[s] = "tools" /\ pend[s] # <<>> /\ throws < ThrowBudget
    /\ throws' = throws + 1
    /\ Finish(s, hist)
    /\ UNCHANGED <<turns, turnOf, rounds, sends, issued, reused, bad>>

(* continueConversation: addUserMessage, then canContinue(), the loop's  *)
(* only turn limit; or the strategy ends the loop.                        *)
Decide(s) ==
    /\ pc[s] = "tools" /\ pend[s] = <<>>
    /\ \/ LET h == AddUser(hist)
              t == NextTurns
          IN /\ turns' = t
             /\ IF TurnCount(h, t) < MaxTurns
                THEN /\ hist' = h
                     /\ pc' = [pc EXCEPT ![s] = "request"]
                     /\ UNCHANGED <<pend, holder>>
                ELSE Finish(s, h)
       \/ /\ Finish(s, hist)
          /\ UNCHANGED turns
    /\ UNCHANGED <<turnOf, rounds, sends, issued, reused, bad, throws>>

Next == \E s \in S : Begin(s) \/ Again(s) \/ Request(s) \/ Reply(s)
                     \/ Answer(s) \/ Throw(s) \/ Decide(s)

Spec == Init /\ [][Next]_vars
        /\ \A s \in S : /\ WF_vars(Begin(s)) /\ WF_vars(Request(s))
                        /\ WF_vars(Reply(s)) /\ WF_vars(Answer(s))
                        /\ WF_vars(Decide(s))

------------------------------------------------------------------------------
(* Properties *)

TypeOK ==
    /\ \A p \in DOMAIN hist :
         hist[p].r \in {"sys", "note", "user", "assistant", "tool"}
    /\ pc \in [S -> {"idle", "request", "reply", "tools", "done"}]
    /\ turns \in Nat /\ holder \in 0..Senders
    /\ rounds \in [S -> 0..(MaxTurns + 1)]
    /\ sends \in [S -> 0..SendsEach]
    /\ \A id \in issued : id.i \in 1..MaxCalls
    /\ reused \in BOOLEAN
    /\ bad \subseteq {"orphan", "unanswered", "opening"}
    /\ throws \in 0..ThrowBudget

(* One sendMessage makes at most maxTurns requests, however it trims.    *)
BoundedRounds == \A s \in S : rounds[s] <= MaxTurns

(* No tool-call id is issued twice: thought signatures are keyed by it,   *)
(* and Gemini's replay maps each result back to its function by it.       *)
UniqueToolCallIds == ~reused

(* Every request a provider receives is one a strict provider accepts.   *)
NoOrphanResult == "orphan" \notin bad
EveryCallAnswered == "unanswered" \notin bad
OpensWithUserTurn == "opening" \notin bad

(* Every sendMessage returns. *)
Terminates == \A s \in S : (pc[s] \in {"request", "reply", "tools"})
                               ~> (pc[s] = "done")
=============================================================================

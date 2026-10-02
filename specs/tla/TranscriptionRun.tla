-------------------------- MODULE TranscriptionRun --------------------------
(***************************************************************************)
(* Skill-based transcription of one recording on one device:              *)
(* SkillInferenceRunner.runTranscription, from the requests that start it *)
(* to the transcript it saves back onto the JournalAudio, and what its    *)
(* callers do once it returns.                                            *)
(*                                                                         *)
(* Each request r is one call of runTranscription on the same audio: the  *)
(* automatic trigger when a recording stops, the AI popup or a timeline's *)
(* Retry through triggerSkillProvider, the synced-audio dispatcher on a   *)
(* pinned host, or the check-in service. `Nudger` is a caller that wakes  *)
(* the subject's agent when the call returns (AutomaticPromptTrigger);    *)
(* `Waiter` is a caller that watches the entry's text for the words and   *)
(* gives up on onError (CheckInTranscriptionService).                     *)
(*                                                                         *)
(* The entity is its stored text, the transcripts in its history          *)
(* (`persisted`, by the run that wrote each; `appends` counts how often), *)
(* the peer's component of its vector clock, and its stored version       *)
(* (`ver`), which every stored write moves. A peer's synced edit raises   *)
(* the peer component; a write derived from a re-read taken before it is  *)
(* concurrent with the stored row, and JournalDb.updateJournalEntity      *)
(* refuses it. A local user edit only raises this host's counter, which   *)
(* the run's own write passes — unless the write is guarded on the        *)
(* version it was built on.                                               *)
(*                                                                         *)
(*   Request     runTranscription: the entity's first read (step 1); with *)
(*               SingleFlight, TranscriptionRuns joins a run in flight    *)
(*   Infer(Fail) the provider call and _recordAttributedConsumption       *)
(*               (steps 5-6); a provider error surfaces as a failure     *)
(*   Reread      EntityStateHelper.getCurrentEntityState (step 7)         *)
(*   Write       JournalRepository.updateJournalEntity(onlyIfUnchanged),  *)
(*               which returns false on a refusal and on a throw it       *)
(*               logged — including a throw after the row was stored;    *)
(*               then _finalizeAttribution                                *)
(*   Summary     _maybeRunAudioSummary                                    *)
(*   Return      the caller after the call: the agent nudge, onError      *)
(*   WaiterSees  the check-in waiter re-reading on a notification         *)
(*   PeerEdit    a synced edit of the recording from another device       *)
(*   UserEdit    the user editing the recording's text on this device     *)
(*                                                                         *)
(* The switches are the fixes; FALSE is the code before them:             *)
(*   CheckWrite         a write that did not land fails the run: status   *)
(*                      error, onError, and no succeeded attribution      *)
(*   RetryConflict  a write that did not land is re-read and tried    *)
(*                      again, up to MaxAttempts                          *)
(*   SettleOnOutcome    the summary and the agent nudge follow only a     *)
(*                      transcript that was saved                         *)
(*   SingleFlight       a request while a run of the same audio is in     *)
(*                      flight joins it instead of paying for another     *)
(*   KeepConcurrentEdit text edited since the run's first read is kept;   *)
(*                      the transcript still joins the history            *)
(*   GuardedWrite       the write applies only while the stored row is   *)
(*                      the version it was built on; before, a local edit *)
(*                      between the re-read and the write was overwritten *)
(*   IdempotentRetry    a re-read that already holds the transcript       *)
(*                      counts as saved: it is not appended again, and    *)
(*                      after the last attempt it is not reported lost    *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS N, Nudger, Waiter,
          PeerEditBudget, UserEditBudget, InferFailBudget, ThrowBudget,
          MaxAttempts,
          CheckWrite, RetryConflict, SettleOnOutcome, SingleFlight,
          KeepConcurrentEdit, GuardedWrite, IdempotentRetry

Runs == 1..N
ASSUME Nudger \in Runs /\ Waiter \in Runs /\ MaxAttempts >= 1

(* A text is a value: 0 is none, 1..Edits the edits in the order they are  *)
(* made (by the user here or on the peer), and Edits + r run r's           *)
(* transcript.                                                             *)
Edits == PeerEditBudget + UserEditBudget
Texts == 0..(Edits + N)
IsEdit(t) == t \in 1..Edits
Transcript(r) == Edits + r

Pcs == {"idle", "infer", "reread", "write", "summary", "return", "joined",
        "done"}
Outcomes == {"none", "ok", "failed"}
Attrs == {"none", "open", "succeeded"}

(* A run owns the registry entry until its shared future completes, which *)
(* is after the summary: a request in that window joins it.               *)
Registered == {"infer", "reread", "write", "summary"}
(* A paid inference, or the write of its result, is under way. *)
InFlight == {"infer", "reread", "write"}

VARIABLES pc, owner, firstText, firstEdits, readText, readPeer, readVer,
          refusals, outcome, cause, attr, status, text, peer, ver, persisted,
          appends, summarized, nudged, waiter, editLost, peerEdits,
          userEdits, inferFails, throws

vars == <<pc, owner, firstText, firstEdits, readText, readPeer, readVer,
          refusals, outcome, cause, attr, status, text, peer, ver, persisted,
          appends, summarized, nudged, waiter, editLost, peerEdits,
          userEdits, inferFails, throws>>

(* What only the write path changes. *)
writeVars == <<ver, appends, readVer>>

EditsMade == peerEdits + userEdits

Init ==
    /\ pc = [r \in Runs |-> "idle"]
    /\ owner = [r \in Runs |-> r]
    /\ firstText = [r \in Runs |-> 0]
    /\ firstEdits = [r \in Runs |-> 0]
    /\ readText = [r \in Runs |-> 0]
    /\ readPeer = [r \in Runs |-> 0]
    /\ readVer = [r \in Runs |-> 0]
    /\ refusals = [r \in Runs |-> 0]
    /\ outcome = [r \in Runs |-> "none"]
    /\ cause = [r \in Runs |-> "none"]
    /\ attr = [r \in Runs |-> "none"]
    /\ status = "idle"
    /\ text = 0
    /\ peer = 0
    /\ ver = 0
    /\ persisted = {}
    /\ appends = [r \in Runs |-> 0]
    /\ summarized = {}
    /\ nudged = {}
    /\ waiter = "off"
    /\ editLost = FALSE
    /\ peerEdits = 0 /\ userEdits = 0 /\ inferFails = 0 /\ throws = 0

Owns(r) == owner[r] = r

------------------------------------------------------------------------------
(* The runner *)

Request(r) ==
    /\ pc[r] = "idle"
    /\ waiter' = IF r = Waiter THEN "waiting" ELSE waiter
    /\ IF SingleFlight /\ \E o \in Runs : Owns(o) /\ pc[o] \in Registered
       THEN /\ \E o \in Runs :
                 /\ Owns(o) /\ pc[o] \in Registered
                 /\ owner' = [owner EXCEPT ![r] = o]
            /\ pc' = [pc EXCEPT ![r] = "joined"]
            /\ UNCHANGED <<firstText, firstEdits, status>>
       ELSE /\ pc' = [pc EXCEPT ![r] = "infer"]
            /\ firstText' = [firstText EXCEPT ![r] = text]
            /\ firstEdits' = [firstEdits EXCEPT ![r] = EditsMade]
            /\ status' = "running"
            /\ UNCHANGED owner
    /\ UNCHANGED writeVars
    /\ UNCHANGED <<readText, readPeer, refusals, outcome, cause, attr, text,
                   peer, persisted, summarized, nudged, editLost, peerEdits,
                   userEdits, inferFails, throws>>

(* _withStatusTracking's catch: status error. An attribution whose usage  *)
(* was recorded stays an in-memory session that is never finalized, as    *)
(* image analysis leaves one whose response entry was not stored: the     *)
(* consumption events are the evidence, and no output claims the work.    *)
Fail(r, why) ==
    /\ pc' = [pc EXCEPT ![r] = "summary"]
    /\ outcome' = [outcome EXCEPT ![r] = "failed"]
    /\ cause' = [cause EXCEPT ![r] = why]
    /\ status' = "error"
    /\ UNCHANGED attr

Infer(r) ==
    /\ pc[r] = "infer"
    /\ pc' = [pc EXCEPT ![r] = "reread"]
    /\ attr' = [attr EXCEPT ![r] = "open"]
    /\ UNCHANGED writeVars
    /\ UNCHANGED <<owner, firstText, firstEdits, readText, readPeer, refusals,
                   outcome, cause, status, text, peer, persisted, summarized,
                   nudged, waiter, editLost, peerEdits, userEdits, inferFails,
                   throws>>

InferFail(r) ==
    /\ pc[r] = "infer" /\ inferFails < InferFailBudget
    /\ Fail(r, "infer")
    /\ inferFails' = inferFails + 1
    /\ UNCHANGED writeVars
    /\ UNCHANGED <<owner, firstText, firstEdits, readText, readPeer, refusals,
                   text, peer, persisted, summarized, nudged, waiter,
                   editLost, peerEdits, userEdits, throws>>

Reread(r) ==
    /\ pc[r] = "reread"
    /\ pc' = [pc EXCEPT ![r] = "write"]
    /\ readText' = [readText EXCEPT ![r] = text]
    /\ readPeer' = [readPeer EXCEPT ![r] = peer]
    /\ readVer' = [readVer EXCEPT ![r] = ver]
    /\ UNCHANGED <<owner, firstText, firstEdits, refusals, outcome, cause,
                   attr, status, text, peer, ver, persisted, appends,
                   summarized, nudged, waiter, editLost, peerEdits, userEdits,
                   inferFails, throws>>

(* The text the write stores: the transcript, unless the text changed     *)
(* since the first read, in which case the re-read copy's text is kept.   *)
NewText(r) ==
    IF KeepConcurrentEdit /\ readText[r] # firstText[r] THEN readText[r]
    ELSE Transcript(r)

(* The write is refused: with GuardedWrite, when any version was stored   *)
(* since the re-read; before, only when a peer's edit made it concurrent. *)
Moved(r) == IF GuardedWrite THEN ver # readVer[r] ELSE peer # readPeer[r]

(* The re-read already holds this run's transcript: it is saved.          *)
Saved(r) == IdempotentRetry /\ r \in persisted

(* The run's transcript is saved: status idle, attribution succeeded.     *)
Succeed(r) ==
    /\ pc' = [pc EXCEPT ![r] = "summary"]
    /\ outcome' = [outcome EXCEPT ![r] = "ok"]
    /\ attr' = [attr EXCEPT ![r] = "succeeded"]
    /\ status' = "idle"
    /\ UNCHANGED cause

(* The row stores this run's write: the transcript joins the history and  *)
(* the text becomes NewText(r).                                           *)
Store(r) ==
    /\ persisted' = persisted \cup {r}
    /\ appends' = [appends EXCEPT ![r] = @ + 1]
    /\ ver' = ver + 1
    /\ text' = NewText(r)
    \* The stored text is an edit made after this run's first read, and the
    \* write replaces it.
    /\ editLost' = (editLost \/ (IsEdit(text) /\ text > firstEdits[r]
                                 /\ NewText(r) # text))

(* updateJournalEntity returned false, whether or not the row was stored. *)
(* A run that ran out of attempts re-reads once more, and with            *)
(* IdempotentRetry a transcript it finds there is saved after all.        *)
NotApplied(r) ==
    /\ refusals' = [refusals EXCEPT ![r] = @ + 1]
    /\ IF ~CheckWrite
       THEN \* The bool was dropped: the run carried on as if it had saved.
            Succeed(r)
       ELSE IF RetryConflict /\ refusals[r] + 1 < MaxAttempts
       THEN /\ pc' = [pc EXCEPT ![r] = "reread"]
            /\ UNCHANGED <<outcome, cause, attr, status>>
       ELSE IF IdempotentRetry /\ r \in persisted'
       THEN Succeed(r)
       ELSE Fail(r, "write")

WriteApplied(r) ==
    /\ pc[r] = "write" /\ ~Saved(r) /\ ~Moved(r)
    /\ Store(r)
    /\ Succeed(r)
    /\ UNCHANGED <<owner, firstText, firstEdits, readText, readPeer, readVer,
                   refusals, peer, summarized, nudged, waiter, peerEdits,
                   userEdits, inferFails, throws>>

(* Refused (the row moved since the re-read), or it threw before storing. *)
WriteNotApplied(r) ==
    /\ pc[r] = "write" /\ ~Saved(r)
    /\ \/ Moved(r) /\ UNCHANGED throws
       \/ throws < ThrowBudget /\ throws' = throws + 1
    /\ UNCHANGED <<owner, firstText, firstEdits, readText, readPeer, readVer,
                   text, peer, ver, persisted, appends, summarized, nudged,
                   waiter, editLost, peerEdits, userEdits, inferFails>>
    /\ NotApplied(r)

(* The row was stored, and a step after the commit threw. *)
WriteStoredButFailed(r) ==
    /\ pc[r] = "write" /\ ~Saved(r) /\ ~Moved(r)
    /\ throws < ThrowBudget /\ throws' = throws + 1
    /\ Store(r)
    /\ NotApplied(r)
    /\ UNCHANGED <<owner, firstText, firstEdits, readText, readPeer, readVer,
                   peer, summarized, nudged, waiter, peerEdits, userEdits,
                   inferFails>>

(* A retry's re-read finds the transcript an earlier attempt stored. *)
AlreadySaved(r) ==
    /\ pc[r] = "write" /\ Saved(r)
    /\ Succeed(r)
    /\ UNCHANGED <<owner, firstText, firstEdits, readText, readPeer, readVer,
                   refusals, text, peer, ver, persisted, appends, summarized,
                   nudged, waiter, editLost, peerEdits, userEdits, inferFails,
                   throws>>

(* The shared future completes after the summary; the registry entry goes *)
(* with it.                                                               *)
Summary(r) ==
    /\ pc[r] = "summary"
    /\ pc' = [pc EXCEPT ![r] = "return"]
    /\ summarized' = IF SettleOnOutcome /\ outcome[r] # "ok"
                     THEN summarized ELSE summarized \cup {r}
    /\ UNCHANGED writeVars
    /\ UNCHANGED <<owner, firstText, firstEdits, readText, readPeer, refusals,
                   outcome, cause, attr, status, text, peer, persisted,
                   nudged, waiter, editLost, peerEdits, userEdits, inferFails,
                   throws>>

------------------------------------------------------------------------------
(* The callers *)

(* A joined request returns with its owner's outcome once the owner's     *)
(* future has completed.                                                  *)
Settled(r) == pc[owner[r]] \in {"return", "done"}
OutcomeOf(r) == outcome[owner[r]]

Return(r) ==
    /\ \/ pc[r] = "return"
       \/ pc[r] = "joined" /\ Settled(r)
    /\ pc' = [pc EXCEPT ![r] = "done"]
    /\ outcome' = [outcome EXCEPT ![r] = OutcomeOf(r)]
    \* AutomaticPromptTrigger nudges the subject's agent after the call.
    /\ nudged' = IF r = Nudger /\ (~SettleOnOutcome \/ OutcomeOf(r) = "ok")
                 THEN nudged \cup {r} ELSE nudged
    \* onError cancels the check-in wait.
    /\ waiter' = IF r = Waiter /\ waiter = "waiting"
                    /\ OutcomeOf(r) = "failed"
                 THEN "cancelled" ELSE waiter
    /\ UNCHANGED writeVars
    /\ UNCHANGED <<owner, firstText, firstEdits, readText, readPeer, refusals,
                   cause, attr, status, text, peer, persisted, summarized,
                   editLost, peerEdits, userEdits, inferFails, throws>>

WaiterSees ==
    /\ waiter = "waiting" /\ text # 0
    /\ waiter' = "text"
    /\ UNCHANGED writeVars
    /\ UNCHANGED <<pc, owner, firstText, firstEdits, readText, readPeer,
                   refusals, outcome, cause, attr, status, text, peer,
                   persisted, summarized, nudged, editLost, peerEdits,
                   userEdits, inferFails, throws>>

------------------------------------------------------------------------------
(* The rest of the world *)

PeerEdit ==
    /\ peerEdits < PeerEditBudget
    /\ peerEdits' = peerEdits + 1
    /\ peer' = peer + 1
    /\ ver' = ver + 1
    \* A peer may edit the words, or something else about the recording.
    /\ text' \in {text, EditsMade + 1}
    /\ UNCHANGED <<pc, owner, firstText, firstEdits, readText, readPeer,
                   readVer, refusals, outcome, cause, attr, status, persisted,
                   appends, summarized, nudged, waiter, editLost, userEdits,
                   inferFails, throws>>

UserEdit ==
    /\ userEdits < UserEditBudget
    /\ userEdits' = userEdits + 1
    /\ ver' = ver + 1
    /\ text' = EditsMade + 1
    /\ UNCHANGED <<pc, owner, firstText, firstEdits, readText, readPeer,
                   readVer, refusals, outcome, cause, attr, status, peer,
                   persisted, appends, summarized, nudged, waiter, editLost,
                   peerEdits, inferFails, throws>>

Next ==
    \/ \E r \in Runs :
         \/ Request(r) \/ Infer(r) \/ InferFail(r) \/ Reread(r)
         \/ WriteApplied(r) \/ WriteNotApplied(r) \/ WriteStoredButFailed(r)
         \/ AlreadySaved(r) \/ Summary(r) \/ Return(r)
    \/ WaiterSees \/ PeerEdit \/ UserEdit

Spec == Init /\ [][Next]_vars
        /\ \A r \in Runs :
             /\ WF_vars(Infer(r)) /\ WF_vars(Reread(r))
             /\ WF_vars(WriteApplied(r)) /\ WF_vars(WriteNotApplied(r))
             /\ WF_vars(AlreadySaved(r))
             /\ WF_vars(Summary(r)) /\ WF_vars(Return(r))
        /\ WF_vars(WaiterSees)

------------------------------------------------------------------------------
(* Properties *)

TypeOK ==
    /\ pc \in [Runs -> Pcs]
    /\ owner \in [Runs -> Runs]
    /\ firstText \in [Runs -> Texts] /\ readText \in [Runs -> Texts]
    /\ firstEdits \in [Runs -> 0..Edits]
    /\ readPeer \in [Runs -> 0..PeerEditBudget]
    /\ readVer \in [Runs -> Nat]
    /\ refusals \in [Runs -> 0..(Edits + ThrowBudget)]
    /\ outcome \in [Runs -> Outcomes]
    /\ cause \in [Runs -> {"none", "infer", "write"}]
    /\ attr \in [Runs -> Attrs]
    /\ status \in {"idle", "running", "error"}
    /\ text \in Texts /\ peer \in 0..PeerEditBudget /\ ver \in Nat
    /\ persisted \subseteq Runs /\ summarized \subseteq Runs
    /\ appends \in [Runs -> Nat]
    /\ nudged \subseteq Runs
    /\ waiter \in {"off", "waiting", "text", "cancelled"}
    /\ editLost \in BOOLEAN

(* A caller told the run succeeded can find its transcript. *)
OkMeansPersisted ==
    \A r \in Runs : outcome[r] = "ok" => owner[r] \in persisted

(* The attribution ledger calls succeeded only work whose output exists. *)
AttributionTruthful ==
    \A r \in Runs : attr[r] = "succeeded" => r \in persisted

(* The summary and the agent's wake follow a saved transcript only. *)
FollowUpsNeedTranscript ==
    /\ summarized \subseteq persisted
    /\ \A r \in nudged : owner[r] \in persisted

(* At most one paid inference of the recording at a time on a device. *)
SingleInference == Cardinality({r \in Runs : pc[r] \in InFlight}) <= 1

(* While a transcription is under way its status says so. *)
StatusShowsRunning ==
    (\E r \in Runs : pc[r] \in InFlight) => status = "running"

(* An edit made while the run was under way survives its write. *)
NoLostEdit == ~editLost

(* A run's transcript joins the history once. *)
NoDuplicateTranscript == \A r \in Runs : appends[r] <= 1

(* A run reports a lost transcript only when it is not stored. *)
WriteFailureIsReal == \A r \in Runs : cause[r] = "write" => r \notin persisted

(* A write that did not land fails the run only after MaxAttempts tries. *)
ConflictIsTransient ==
    \A r \in Runs : cause[r] = "write" => refusals[r] >= MaxAttempts

(* Every request ends, succeeded or visibly failed. *)
EveryRequestSettles ==
    \A r \in Runs : pc[r] # "idle" ~> pc[r] = "done"

(* The check-in waiter ends with the words or with the error, never only  *)
(* by its timeout.                                                         *)
WaiterResolves == waiter = "waiting" ~> waiter \in {"text", "cancelled"}
=============================================================================

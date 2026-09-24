---------------------------- MODULE LogCompaction ----------------------------
(***************************************************************************)
(* Summary checkpoints over an agent's captured input log (ADR 0017, ADR   *)
(* 0020, ADR 0057) on several devices. Each device captures versions of    *)
(* its sources, folds the oldest part of its uncovered tail into a         *)
(* checkpoint, and receives the other devices' captures and checkpoints   *)
(* late and in any order. The prompt shows the active checkpoint's prose   *)
(* and, verbatim, every event after its cutoff.                            *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Capture       AgentInputCaptureService: a new version of a source is  *)
(*                 a `messagePayload` link (the event, at its capture      *)
(*                 position) plus a content-addressed payload row; sync    *)
(*                 carries the two separately                              *)
(*   Compact       AgentLogCompactor.compactAndAssemble: select the active *)
(*                 checkpoint, resolve the tail's content (an event whose  *)
(*                 payload has not arrived is dropped), planCompaction     *)
(*                 folds an oldest prefix and keeps at least the newest    *)
(*                 resolved event; the new checkpoint extends the active   *)
(*                 one's coveredSources and prose                          *)
(*   Deliver       sync: link, payload and checkpoint rows arrive once     *)
(*                 each, in any order                                      *)
(*   Active        selectActiveSummary: the valid checkpoint with the      *)
(*                 greatest cutoff, ties to the lowest id                  *)
(*                                                                         *)
(* A position is a global tick (capture order); a digest is unique per     *)
(* version. `saw` is a ghost: the events whose content the checkpoint's    *)
(* prose actually folded, its own and its predecessors'. Both switches are *)
(* TRUE in the code; setting one FALSE restores the behaviour before ADR   *)
(* 0071.                                                                   *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Devices,          \* a set of positive integers
    Sources,
    LeadCaptures,     \* captures on device 1
    PeerCaptures,     \* captures on every other device
    LeadFolds,        \* compactions on device 1
    PeerFolds,        \* compactions on every other device
    DigestCoverage,   \* a checkpoint dies when a newer version sorts before
                      \* its cutoff, not only an unknown source
    FoldStopsAtGap    \* a fold never passes an event it could not resolve

NoSum == [id |-> <<0, 0>>, cutoff |-> 0, cov |-> [s \in Sources |-> 0],
          saw |-> {}]

VARIABLES
    log,       \* per device: capture events (links) present
    pay,       \* per device: events whose payload row is present
    sums,      \* per device: checkpoints present
    sent,      \* every row emitted to sync
    got,       \* per device: the emitted rows it has processed
    caps,      \* captures per device
    folds,     \* compactions per device
    now,       \* global tick
    deadWrite  \* ghost: a device wrote a checkpoint its own log rejects

vars == <<log, pay, sums, sent, got, caps, folds, now, deadWrite>>

-----------------------------------------------------------------------------
(* Checkpoint selection (selectActiveSummary).                             *)

\* The latest version of s at or before position c in log L.
LatestBefore(L, s, c) ==
    LET V == {e \in L : e.src = s /\ e.pos <= c}
    IN CHOOSE e \in V : \A f \in V : f.pos <= e.pos

Valid(L, S) ==
    IF DigestCoverage
    THEN \A s \in Sources :
            (\E e \in L : e.src = s /\ e.pos <= S.cutoff)
                => S.cov[s] = LatestBefore(L, s, S.cutoff).dig
    ELSE \A e \in L : e.pos <= S.cutoff => S.cov[e.src] # 0

IdLess(a, b) == a[1] < b[1] \/ (a[1] = b[1] /\ a[2] < b[2])

Better(S, T) == S.cutoff > T.cutoff \/ (S.cutoff = T.cutoff /\ IdLess(S.id, T.id))

Active(L, Ss) ==
    LET C == {S \in Ss : Valid(L, S)} IN
    IF C = {} THEN NoSum
    ELSE CHOOSE S \in C : \A T \in C : T = S \/ Better(S, T)

-----------------------------------------------------------------------------

Init ==
    /\ log = [d \in Devices |-> {}]
    /\ pay = [d \in Devices |-> {}]
    /\ sums = [d \in Devices |-> {}]
    /\ sent = {}
    /\ got = [d \in Devices |-> {}]
    /\ caps = [d \in Devices |-> 0]
    /\ folds = [d \in Devices |-> 0]
    /\ now = 0
    /\ deadWrite = FALSE

Ev(s, t) == [src |-> s, pos |-> t, dig |-> t]
NoEv == Ev(CHOOSE s \in Sources : TRUE, 0)
Item(t, e, S) == [t |-> t, e |-> e, s |-> S]

Emit(d, items) ==
    /\ sent' = sent \cup items
    /\ got' = [got EXCEPT ![d] = @ \cup items]

Capture(d, s) ==
    /\ caps[d] < (IF d = 1 THEN LeadCaptures ELSE PeerCaptures)
    /\ LET e == Ev(s, now + 1) IN
       /\ log' = [log EXCEPT ![d] = @ \cup {e}]
       /\ pay' = [pay EXCEPT ![d] = @ \cup {e}]
       /\ Emit(d, {Item("link", e, NoSum), Item("payload", e, NoSum)})
    /\ caps' = [caps EXCEPT ![d] = @ + 1]
    /\ now' = now + 1
    /\ UNCHANGED <<sums, folds, deadWrite>>

\* The fold input: the tail after the active cutoff whose content resolved,
\* and, with FoldStopsAtGap, only the part before the first that did not.
Eligible(d, A) ==
    LET tail == {e \in log[d] : e.pos > A.cutoff}
        resolved == tail \cap pay[d]
        gaps == tail \ pay[d]
    IN IF FoldStopsAtGap
       THEN {e \in resolved : \A u \in gaps : e.pos < u.pos}
       ELSE resolved

Compact(d) ==
    /\ folds[d] < (IF d = 1 THEN LeadFolds ELSE PeerFolds)
    /\ LET A == Active(log[d], sums[d])
           resolved == {e \in log[d] : e.pos > A.cutoff} \cap pay[d]
       IN \E c \in {e.pos : e \in Eligible(d, A)} :
            \* planCompaction keeps the newest resolved event verbatim.
            /\ \E k \in resolved : k.pos > c
            /\ LET F == {e \in Eligible(d, A) : e.pos <= c}
                   cov == [s \in Sources |->
                             IF \E e \in F : e.src = s
                             THEN LatestBefore(F, s, c).dig
                             ELSE A.cov[s]]
                   S == [id |-> <<d, folds[d] + 1>>, cutoff |-> c, cov |-> cov,
                         saw |-> A.saw \cup F]
               IN /\ sums' = [sums EXCEPT ![d] = @ \cup {S}]
                  /\ deadWrite' = (deadWrite \/ ~Valid(log[d], S))
                  /\ Emit(d, {Item("summary", NoEv, S)})
    /\ folds' = [folds EXCEPT ![d] = @ + 1]
    /\ UNCHANGED <<log, pay, caps, now>>

Deliver(d, i) ==
    /\ i \in sent \ got[d]
    /\ got' = [got EXCEPT ![d] = @ \cup {i}]
    /\ CASE i.t = "link" ->
              /\ log' = [log EXCEPT ![d] = @ \cup {i.e}]
              /\ UNCHANGED <<pay, sums>>
         [] i.t = "payload" ->
              /\ pay' = [pay EXCEPT ![d] = @ \cup {i.e}]
              /\ UNCHANGED <<log, sums>>
         [] OTHER ->
              /\ sums' = [sums EXCEPT ![d] = @ \cup {i.s}]
              /\ UNCHANGED <<log, pay>>
    /\ UNCHANGED <<sent, caps, folds, now, deadWrite>>

Next ==
    \/ \E d \in Devices, s \in Sources : Capture(d, s)
    \/ \E d \in Devices : Compact(d)
    \/ \E d \in Devices, i \in sent : Deliver(d, i)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* Properties.                                                             *)

TypeOK ==
    /\ \A d \in Devices : got[d] \subseteq sent
    /\ \A d \in Devices : pay[d] \subseteq log[d] \cup {i.e : i \in sent}

\* Nothing is lost from the prompt: every event is after the active cutoff
\* (rendered in the tail once its content resolves), folded into the active
\* checkpoint's prose, or superseded by a newer version of its source that
\* is one of the two.
NoLostContext ==
    \A d \in Devices :
        LET A == Active(log[d], sums[d])
            shown == A.saw \cup {f \in log[d] : f.pos > A.cutoff}
        IN \A e \in log[d] :
              \E f \in shown : f.src = e.src /\ f.pos >= e.pos

\* A device never writes a checkpoint its own log already rejects: that one
\* is dead on arrival, and the next wake summarizes the same tail again.
NoDeadCheckpoint == ~deadWrite

\* Selection is a function of the log and checkpoint sets: two devices
\* holding the same rows show the same prose and tail.
Converged ==
    \A d, e \in Devices :
        (log[d] = log[e] /\ sums[d] = sums[e])
            => Active(log[d], sums[d]) = Active(log[e], sums[e])
=============================================================================

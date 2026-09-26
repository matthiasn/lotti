-------------------------- MODULE SyncSettings --------------------------
(***************************************************************************)
(* Non-sequence-tracked settings: configFlag, themingSelection and        *)
(* dailyOsUserName, in SyncEventProcessor._applySyncMessage. Three fixed  *)
(* envelopes are available to two receivers. A receiver applies one at  *)
(* a time, but peers can choose different delivery orders. The timestamp *)
(* guard is < (equal stamps overwrite); configFlag has no stamp at all. *)
(*                                                                         *)
(* Start/Write/Commit reflect guard, transaction-local writes, then the  *)
(* atomic group commit (including stamp) and successful return. A failed *)
(* write rolls back and propagates, leaving the envelope retryable.      *)
(* AtomicGroups and RetryFailures expose the two old behaviors as mutants.*)
(* The failure profile permits ONE transient failure, within the inbound *)
(* worker's bounded retry budget; it does not assume unbounded retries.  *)
(* EqualStamps and unordered flags remain residual counterexamples.      *)
(* Local concurrent writes, platform effects, normalization and the name*)
(* bootstrap-published marker are outside this register abstraction.    *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets
CONSTANTS Peers, FieldCount, Timestamped, EqualStamps, OrderedDelivery,
          FailureBudget, AtomicGroups, RetryFailures
Versions == 1..3
Fields == 1..FieldCount
Stamp(v) == IF v = 0 THEN 0 ELSE IF EqualStamps THEN 1 ELSE v
VARIABLES rows, pending, stamp, done, active, nextField, failures
vars == <<rows, pending, stamp, done, active, nextField, failures>>
Init == /\ rows = [p \in Peers |-> [f \in Fields |-> 0]]
        /\ pending = rows
        /\ stamp = [p \in Peers |-> 0]
        /\ done = [p \in Peers |-> {}]
        /\ active = [p \in Peers |-> 0]
        /\ nextField = [p \in Peers |-> 1]
        /\ failures = 0
Eligible(p, v) == /\ v \notin done[p] /\ active[p] = 0
                 /\ (~OrderedDelivery \/ (1..(v-1)) \subseteq done[p])
Start(p, v) ==
    /\ Eligible(p, v)
    /\ IF Timestamped /\ Stamp(v) < stamp[p]
       THEN /\ done' = [done EXCEPT ![p] = @ \cup {v}]
            /\ UNCHANGED active
       ELSE /\ active' = [active EXCEPT ![p] = v]
            /\ UNCHANGED done
    /\ UNCHANGED <<rows, pending, stamp, nextField, failures>>
Write(p) ==
    /\ active[p] # 0 /\ nextField[p] <= FieldCount
    /\ pending' = [pending EXCEPT ![p][nextField[p]] = active[p]]
    /\ rows' = IF AtomicGroups THEN rows ELSE [rows EXCEPT ![p] = pending'[p]]
    /\ nextField' = [nextField EXCEPT ![p] = @ + 1]
    /\ UNCHANGED <<stamp, done, active, failures>>
Commit(p) ==
    /\ active[p] # 0 /\ nextField[p] = FieldCount + 1
    /\ rows' = [rows EXCEPT ![p] = pending[p]]
    /\ stamp' = [stamp EXCEPT ![p] = IF Timestamped THEN Stamp(active[p]) ELSE 0]
    /\ done' = [done EXCEPT ![p] = @ \cup {active[p]}]
    /\ active' = [active EXCEPT ![p] = 0]
    /\ nextField' = [nextField EXCEPT ![p] = 1]
    /\ UNCHANGED <<pending, failures>>
Fail(p) ==
    /\ active[p] # 0 /\ Timestamped /\ failures < FailureBudget
    /\ done' = IF RetryFailures THEN done ELSE [done EXCEPT ![p] = @ \cup {active[p]}]
    /\ pending' = [pending EXCEPT ![p] = rows[p]]
    /\ active' = [active EXCEPT ![p] = 0]
    /\ nextField' = [nextField EXCEPT ![p] = 1]
    /\ failures' = failures + 1
    /\ UNCHANGED <<rows, stamp>>
Next == (\E p \in Peers, v \in Versions : Start(p, v))
        \/ (\E p \in Peers : Write(p) \/ Commit(p) \/ Fail(p))
Spec == Init /\ [][Next]_vars
        /\ (\A p \in Peers, v \in Versions : WF_vars(Start(p, v)))
        /\ (\A p \in Peers : WF_vars(Write(p)) /\ WF_vars(Commit(p)))
TypeOK == /\ rows \in [Peers -> [Fields -> 0..3]]
          /\ pending \in [Peers -> [Fields -> 0..3]]
          /\ stamp \in [Peers -> 0..3]
          /\ done \in [Peers -> SUBSET Versions]
          /\ active \in [Peers -> 0..3]
          /\ nextField \in [Peers -> 1..(FieldCount + 1)]
          /\ failures \in 0..FailureBudget
CompletedCoherent == \A p \in Peers : active[p] = 0 =>
    /\ \A f \in Fields : rows[p][f] = rows[p][1]
    /\ ~Timestamped \/ stamp[p] = Stamp(rows[p][1])
Converged == \A p, q \in Peers :
    (done[p] = Versions /\ done[q] = Versions) => rows[p] = rows[q]
LatestWins == \A p \in Peers :
    (done[p] = Versions /\ (OrderedDelivery \/ (Timestamped /\ ~EqualStamps)))
    => \A f \in Fields : rows[p][f] = 3
EventuallyComplete == \A p \in Peers : <> (done[p] = Versions)
=============================================================================

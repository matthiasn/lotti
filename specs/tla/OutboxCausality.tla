------------------------- MODULE OutboxCausality -------------------------
(***************************************************************************)
(* Refines Outbox's scalar-version collapse with two-host vector clocks.      *)
(* One inline entry link, agent entity, or agent link, staged by one       *)
(* device (including backfill/history snapshots). Its three versions form *)
(* a fork and a successor of both branches. Enqueues may arrive in any    *)
(* order. The source retains the committed snapshots until staging; the  *)
(* outbox carries the actual inline payload, not just an acknowledged     *)
(* counter. Sending, receiving, and sequence acknowledgement are separate *)
(* actions. Delivery can repeat and recipients can see different orders.  *)
(*                                                                         *)
(* Commit / Stage: payload commit then immutable OutboxEnqueueWriter append. *)
(* Claim: OutboxProcessor collapses causally superseded rows into one send  *)
(*        (batch/CAS detail in Outbox); enqueues cannot rewrite the claim.  *)
(* Send: OutboxProcessor -> the immutable claimed inline payload.         *)
(* Apply: entry-link total order / basic agent LWW, with a timestamp      *)
(*        order that extends causality but does not order concurrent      *)
(*        versions by enqueue order. Type-specific joins remain covered  *)
(*        by AgentReplication, AgentLinks and their conformance traces.   *)
(* Ack: SyncSequenceReceiver marks the envelope's covered counters.       *)
(*                                                                         *)
(* A process may die after commit, claim, send or apply. Durable outbox   *)
(* rows and applied data remain; claims replay, and an apply without an   *)
(* acknowledgement is repeated. There is no network loss in this focused *)
(* model: gap discovery/backfill, attachments, clockless payloads, retry  *)
(* exhaustion and payload purges are not claims of this configuration.   *)
(* Setting PreserveConcurrent FALSE allows unsound concurrent coverage.        *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets
CONSTANTS Peers, PreserveConcurrent, MaxCrashes
Hosts == {"A", "B"}
Versions == 1..3
Clock(v) == CASE v = 1 -> [h \in Hosts |-> IF h = "A" THEN 2 ELSE 1]
             [] v = 2 -> [h \in Hosts |-> IF h = "A" THEN 1 ELSE 2]
             [] OTHER -> [h \in Hosts |-> 3]
Covers(a, b) == \A h \in Hosts : Clock(a)[h] >= Clock(b)[h]
\* v1 is a later-timestamp tombstone; v2 is a concurrent older live copy.
\* v3 succeeds both. Every causal successor also wins the receiver order.
Rank(v) == CASE v = 1 -> 2 [] v = 2 -> 1 [] OTHER -> 3
Winner(S) == IF S = {} THEN 0
             ELSE CHOOSE v \in S : \A w \in S : Rank(v) >= Rank(w)
Msg(v, cov) == [payload |-> v, covered |-> cov]
Carried(m) == {m.payload} \cup m.covered
Messages == [payload : Versions, covered : SUBSET Versions]

VARIABLES committed, staged, pending, claim, wire, applied, receipts, acked,
          crashes
vars == <<committed, staged, pending, claim, wire, applied, receipts, acked,
          crashes>>
Init == /\ committed = {} /\ staged = {} /\ pending = <<>> /\ claim = <<>>
        /\ wire = {} /\ applied = [p \in Peers |-> {}]
        /\ receipts = [p \in Peers |-> {}]
        /\ acked = [p \in Peers |-> {}] /\ crashes = 0
Commit(v) == /\ v \notin committed
             /\ committed' = committed \cup {v}
             /\ UNCHANGED <<staged, pending, claim, wire, applied, receipts,
                             acked, crashes>>
Stage(v) ==
    /\ v \in committed \ staged
    /\ pending' = Append(pending, Msg(v, {}))
    /\ staged' = staged \cup {v}
    /\ UNCHANGED <<committed, claim, wire, applied, receipts, acked, crashes>>
\* Choose the causal maximum, breaking concurrent ties by row order. With
\* this fixed three-version fork, this is newestOf's sequential reduction.
NewestIndex ==
    CHOOSE i \in 1..Len(pending) :
        \A j \in 1..Len(pending) :
            Covers(pending[i].payload, pending[j].payload)
            \/ (~Covers(pending[j].payload, pending[i].payload) /\ i > j)
Claim == /\ claim = <<>> /\ pending # <<>>
         /\ LET newest == pending[NewestIndex]
                folds(m) == ~PreserveConcurrent
                            \/ Covers(newest.payload, m.payload)
                members == {m \in {pending[i] : i \in 1..Len(pending)} : folds(m)}
                covered == UNION {Carried(m) : m \in members}
            IN /\ claim' = <<Msg(newest.payload, covered \ {newest.payload})>>
               /\ pending' = SelectSeq(pending, LAMBDA m : ~folds(m))
         /\ UNCHANGED <<committed, staged, wire, applied, receipts, acked,
                         crashes>>
Send == /\ claim # <<>>
        /\ wire' = wire \cup {Head(claim)} /\ claim' = <<>>
        /\ UNCHANGED <<committed, staged, pending, applied, receipts, acked,
                        crashes>>
Apply(p, m) ==
    /\ m \in wire /\ m \notin receipts[p]
    /\ applied' = [applied EXCEPT ![p] = @ \cup {m.payload}]
    /\ receipts' = [receipts EXCEPT ![p] = @ \cup {m}]
    /\ UNCHANGED <<committed, staged, pending, claim, wire, acked, crashes>>
Ack(p, m) ==
    /\ m \in receipts[p] /\ ~Carried(m) \subseteq acked[p]
    /\ acked' = [acked EXCEPT ![p] = @ \cup Carried(m)]
    /\ UNCHANGED <<committed, staged, pending, claim, wire, applied, receipts,
                    crashes>>
\* Release orphaned claims before the next drain. Sending a claim twice is
\* harmless; receivers still get the exact same payload and covered set.
Crash == /\ crashes < MaxCrashes
         /\ pending' = claim \o pending /\ claim' = <<>>
         /\ receipts' = [p \in Peers |-> {}]
         /\ crashes' = crashes + 1
         /\ UNCHANGED <<committed, staged, wire, applied, acked>>
Next == (\E v \in Versions : Commit(v) \/ Stage(v)) \/ Claim \/ Send \/ Crash
        \/ (\E p \in Peers, m \in Messages : Apply(p, m) \/ Ack(p, m))
Spec == Init /\ [][Next]_vars
        /\ (\A v \in Versions : WF_vars(Stage(v)))
        /\ WF_vars(Claim) /\ WF_vars(Send)
        /\ (\A p \in Peers, m \in Messages :
                WF_vars(Apply(p, m)) /\ WF_vars(Ack(p, m)))

TypeOK == /\ staged \subseteq committed /\ committed \subseteq Versions
          /\ pending \in Seq(Messages) /\ Len(pending) <= 3
          /\ claim \in Seq(Messages) /\ Len(claim) <= 1
          /\ wire \subseteq Messages
          /\ applied \in [Peers -> SUBSET Versions]
          /\ receipts \in [Peers -> SUBSET Messages]
          /\ acked \in [Peers -> SUBSET Versions]
          /\ crashes \in 0..MaxCrashes
Queued == {pending[i] : i \in 1..Len(pending)}
          \cup {claim[i] : i \in 1..Len(claim)}
CoveredIsCausal ==
    \A m \in Queued \cup wire : \A v \in m.covered : Covers(m.payload, v)
NoLostStagedVersion ==
    \A v \in staged : \E m \in Queued \cup wire : v \in Carried(m)
NoFalseAcknowledgement ==
    \A p \in Peers : \A v \in acked[p] :
        \E w \in applied[p] : Covers(w, v)
\* Once a recipient claims every committed version, its actual payload
\* winner must agree with the winner of those versions, not merely its log.
AcknowledgedWinner ==
    \A p \in Peers : committed \subseteq acked[p] =>
        Winner(applied[p]) = Winner(committed)
EventuallyAcknowledged ==
    \A v \in Versions, p \in Peers : v \in committed ~> v \in acked[p]
=============================================================================

-------------------------- MODULE AgentReplication --------------------------
(***************************************************************************)
(* Replicas of one synced agent entity: local writes, the throttle's        *)
(* device-local bookkeeping, and the receive path, over a network that     *)
(* delivers every write to every replica in any order, any number of      *)
(* times. The question is convergence: once every replica has received     *)
(* every write, do they hold the same row? And is a write that causally    *)
(* succeeds the row ever lost to the version it replaced?                  *)
(*                                                                         *)
(* One entity stands for a family of types, chosen by `Kind`:              *)
(*                                                                         *)
(*   "state"     AgentStateEntity: whole-row last-writer-wins plus per-    *)
(*               host G-counters (wakeCounter, session counters) that a    *)
(*               concurrent conflict joins element-wise                    *)
(*   "terminal"  a type with a status override that outranks the          *)
(*               timestamp: retracted knowledge, a consumed wake window,   *)
(*               a dismissed nudge (`term`)                                *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Write     AgentSyncService._upsertEntityRaw. The clock comes from     *)
(*             VectorClockService.getNextVectorClock(previous: ...). The   *)
(*             entity the caller passes may carry the persisted row's      *)
(*             clock, a wake-start snapshot's, or none (`vectorClock:      *)
(*             null`); `now - Skew .. now` is its updatedAt                *)
(*   Snapshot  a workflow reading the row at wake start                    *)
(*   Throttle  WakeThrottleCoordinator persisting nextWakeAt straight to   *)
(*             the repository, with no clock and no sync message           *)
(*   Deliver   SyncEventProcessor._applyAgentEntityMessage, which applies  *)
(*             resolveAgentEntityVersions (agent_concurrent_resolver.dart):*)
(*             causal dominance first; a concurrent pair goes to the       *)
(*             type's override, then updatedAt, then the canonical clock   *)
(*             tiebreak, and agent state joins its G-counters              *)
(*   Tick      the wall clock                                              *)
(*                                                                         *)
(* The four design switches are the fixes of ADR 0068; setting one to      *)
(* FALSE restores the old behaviour and its counterexample (README).       *)
(* `RankDrop` lets a write leave the terminal status it built on -- a      *)
(* digest retry re-arming its consumed window at the same instant -- which *)
(* is a documented residual, not a checked configuration.                  *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    N,            \* replicas 1..N
    MaxWrites,    \* local writes, across all replicas
    MaxTime,      \* the wall clock runs 0..MaxTime
    Skew,         \* how far a write's updatedAt may lag the clock
    Kind,         \* "state" or "terminal"
    StaleWrites,  \* may a write build on a snapshot or on no clock at all?
    Throttle,     \* does the throttle coordinator persist deadlines?
    RankDrop,     \* may a write leave the terminal status it built on?
    \* Design switches: TRUE is the code after ADR 0068.
    ThrottleKeepsTimestamp,  \* device-local writes leave updatedAt alone
    CountersJoinAlways,      \* G-counters join on every delivery
    ResolveLocalWrites,      \* a write succeeds the row it replaces
    ClampTimestamp           \* ...and its updatedAt is not older

ASSUME Kind \in {"state", "terminal"}
ASSUME \A b \in {StaleWrites, Throttle, RankDrop, ThrottleKeepsTimestamp,
                 CountersJoinAlways, ResolveLocalWrites, ClampTimestamp} :
            b \in BOOLEAN

R == 1..N
Zero == [r \in R |-> 0]
Max(a, b) == IF a > b THEN a ELSE b
Join(a, b) == [r \in R |-> Max(a[r], b[r])]
Leq(a, b) == \A r \in R : a[r] <= b[r]
Before(a, b) == Leq(a, b) /\ a # b

\* compareClocksCanonically(a, b) > 0: the first host, in sorted order,
\* whose counters differ is larger in a.
CanonGt(a, b) == \E k \in R : a[k] > b[k] /\ \A j \in R : j < k => a[j] = b[j]

\* A version: its write id, clock, updatedAt, override status, G-counter.
\* A merged row keeps the id of the version whose fields won.
V0 == [id |-> 0, vc |-> Zero, ts |-> 0, term |-> FALSE, g |-> Zero]

VARIABLES
    row,        \* per replica: the persisted row
    snap,       \* per replica: a row read at wake start
    sent,       \* every write ever made (the network delivers each)
    delivered,  \* per replica: the writes it has received or made
    now,        \* the wall clock
    hc,         \* per replica: the last counter VectorClockService issued
    incs        \* ghost: G-counter increments made by each host

vars == <<row, snap, sent, delivered, now, hc, incs>>

Init ==
    /\ row = [r \in R |-> V0]
    /\ snap = [r \in R |-> V0]
    /\ sent = {}
    /\ delivered = [r \in R |-> {}]
    /\ now = 0
    /\ hc = [r \in R |-> 0]
    /\ incs = [r \in R |-> 0]

\* The concurrent winner: the type's override, then updatedAt, then the
\* canonical clock tiebreak (resolveConcurrent).
Winner(l, i) ==
    IF Kind = "terminal" /\ l.term # i.term
    THEN IF l.term THEN l ELSE i
    ELSE IF i.ts > l.ts THEN i
    ELSE IF l.ts > i.ts THEN l
    ELSE IF CanonGt(i.vc, l.vc) THEN i ELSE l

\* Two concurrent versions: the winner's fields, under its own clock; agent
\* state joins the G-counters (mergeAgentStateCounters).
MergeConcurrent(l, i) ==
    LET w == Winner(l, i)
    IN IF Kind = "state" THEN [w EXCEPT !.g = Join(l.g, i.g)] ELSE w

\* The row a replica holding `l` keeps after receiving `i`. After the fix a
\* G-counter is joined whichever version wins, causally or not: a version
\* that succeeds one side of an earlier merge need not carry the other's.
Merge(l, i) ==
    IF Leq(i.vc, l.vc) THEN l
    ELSE IF Leq(l.vc, i.vc)
         THEN IF Kind = "state" /\ CountersJoinAlways
              THEN [i EXCEPT !.g = Join(l.g, i.g)] ELSE i
    ELSE MergeConcurrent(l, i)

Bases == {"row"} \cup (IF StaleWrites THEN {"snap", "null"} ELSE {})

BaseRow(r, b) ==
    CASE b = "row"  -> row[r]
      [] b = "snap" -> snap[r]
      [] b = "null" -> [row[r] EXCEPT !.vc = Zero]

\* A write keeps the terminal status it built on unless RankDrop.
Terms(base) ==
    IF Kind = "state" THEN {FALSE}
    ELSE IF RankDrop THEN BOOLEAN ELSE {base.term, TRUE}

\* A G-counter is only bumped on the row the writer re-read; the snapshot
\* writers that bumped one are AgentStateWrites.tla.
Incs(b) == IF Kind = "state" /\ b = "row" THEN BOOLEAN ELSE {FALSE}

\* Old: the clock is the base's plus this host's next counter, and the write
\* replaces the row whatever it was built on. Fixed: the clock also covers
\* the persisted row, so the write succeeds it on every replica; a write
\* whose base did not cover the row keeps the fields that would have won had
\* the two been concurrent, and a write never lowers a G-counter.
Write(r) ==
    /\ Cardinality(sent) < MaxWrites
    /\ \E b \in Bases, t \in (IF now > Skew THEN now - Skew ELSE 0)..now,
          tm \in BOOLEAN, inc \in BOOLEAN :
        LET B == BaseRow(r, b)
            P == row[r]
            base == [B EXCEPT !.ts = t, !.term = tm,
                              !.g = IF inc THEN [B.g EXCEPT ![r] = @ + 1]
                                    ELSE B.g]
            fields == IF ResolveLocalWrites /\ ~Leq(P.vc, B.vc)
                      THEN MergeConcurrent(P, base)
                      ELSE base
            vc == [(IF ResolveLocalWrites THEN Join(B.vc, P.vc) ELSE B.vc)
                     EXCEPT ![r] = hc[r] + 1]
            ts == IF ClampTimestamp /\ Before(P.vc, vc)
                  THEN Max(fields.ts, P.ts) ELSE fields.ts
            \* A merge may have joined counters into P without moving its
            \* clock, so a base that covers P's clock can still lack them.
            g == IF ResolveLocalWrites THEN Join(fields.g, P.g) ELSE fields.g
            w == [id |-> Cardinality(sent) + 1, vc |-> vc, ts |-> ts,
                  term |-> fields.term, g |-> g]
        IN /\ tm \in Terms(B)
           /\ inc \in Incs(b)
           /\ sent' = sent \cup {w}
           /\ delivered' = [delivered EXCEPT ![r] = @ \cup {w}]
           /\ row' = [row EXCEPT ![r] = w]
           /\ hc' = [hc EXCEPT ![r] = @ + 1]
           /\ incs' = IF inc THEN [incs EXCEPT ![r] = @ + 1] ELSE incs
    /\ UNCHANGED <<snap, now>>

Snapshot(r) ==
    /\ StaleWrites
    /\ snap[r] # row[r]
    /\ snap' = [snap EXCEPT ![r] = row[r]]
    /\ UNCHANGED <<row, sent, delivered, now, hc, incs>>

\* The throttle persists nextWakeAt, which sync never carries. The old code
\* also stamped updatedAt with the local clock.
ThrottleDeadline(r) ==
    /\ Throttle
    /\ ~ThrottleKeepsTimestamp
    /\ row[r].ts < now
    /\ row' = [row EXCEPT ![r].ts = now]
    /\ UNCHANGED <<snap, sent, delivered, now, hc, incs>>

Deliver(r) ==
    /\ \E m \in sent :
        /\ row' = [row EXCEPT ![r] = Merge(@, m)]
        /\ delivered' = [delivered EXCEPT ![r] = @ \cup {m}]
    /\ UNCHANGED <<snap, sent, now, hc, incs>>

Tick ==
    /\ now < MaxTime
    /\ now' = now + 1
    /\ UNCHANGED <<row, snap, sent, delivered, hc, incs>>

Next ==
    \/ Tick
    \/ \E r \in R : Write(r) \/ Snapshot(r) \/ ThrottleDeadline(r) \/ Deliver(r)

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MaxTime
    /\ \A r \in R : row[r].id \in 0..MaxWrites /\ delivered[r] \subseteq sent

\* Every write has been received everywhere.
Quiescent == \A r \in R : delivered[r] = sent

\* The synced part of a row (updatedAt aside: the throttle mutant bumps it
\* locally, and what matters is which version and fields each replica keeps).
Content(v) == [id |-> v.id, vc |-> v.vc, term |-> v.term, g |-> v.g]

\* Strong eventual consistency: the same writes received, the same row.
Converged ==
    Quiescent => \A a, b \in R : Content(row[a]) = Content(row[b])

VcOf(id) == IF id = 0 THEN Zero ELSE (CHOOSE v \in sent : v.id = id).vc

\* A row never holds a version that a write it received causally replaced.
NoLostSuccessor ==
    \A r \in R : \A m \in delivered[r] : ~Before(VcOf(row[r].id), m.vc)

\* A host always sees all of its own increments...
OwnCountKept == Kind = "state" => \A r \in R : row[r].g[r] = incs[r]

\* ...and, once everything is delivered, everyone else's.
NoLostIncrement ==
    (Kind = "state" /\ Quiescent) =>
        \A r, h \in R : row[r].g[h] = incs[h]
=============================================================================

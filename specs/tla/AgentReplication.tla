-------------------------- MODULE AgentReplication --------------------------
(***************************************************************************)
(* Replicas of one synced agent entity: local writes, the throttle's        *)
(* device-local bookkeeping, and the receive path, over a network that     *)
(* delivers every write to every replica in any order, any number of      *)
(* times, and may lose a delivery that backfill later recovers. The        *)
(* question is convergence: once every replica has received every write,   *)
(* do they hold the same row? And is a write that causally succeeds the    *)
(* row ever lost to the version it replaced?                               *)
(*                                                                         *)
(* One entity stands for a family of types, chosen by `Kind`:              *)
(*                                                                         *)
(*   "state"     AgentStateEntity: whole-row last-writer-wins plus per-    *)
(*               host G-counters (wakeCounter, session counters) that a    *)
(*               concurrent conflict joins element-wise                    *)
(*   "terminal"  a type with a status override that outranks the          *)
(*               timestamp: retracted knowledge, a consumed wake window,   *)
(*               a dismissed nudge (`term`)                                *)
(*   "removal"   a register that is removed and written again: `term` is   *)
(*               its tombstone (`deletedAt`), ordered like any other       *)
(*               field -- a day plan deleted and redrafted, a parsed       *)
(*               capture item replaced by a re-parse, a template or soul   *)
(*               deleted, a recommendation set or query chat row cleared   *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Write     AgentSyncService._upsertEntityRaw. The clock comes from     *)
(*             VectorClockService.getNextVectorClock(previous: ...). The   *)
(*             entity the caller passes may carry the persisted row's      *)
(*             clock, a wake-start snapshot's, or none (`vectorClock:      *)
(*             null`); `now - Skew .. now` is its updatedAt (a removal's   *)
(*             `deletedAt`). The persisted row it resolves against is      *)
(*             read with its tombstone (`getEntityIncludingDeleted`), or,  *)
(*             before, with `getEntity`, which read a tombstone as no row  *)
(*   Snapshot  a workflow reading the row at wake start                    *)
(*   Throttle  WakeThrottleCoordinator persisting nextWakeAt straight to   *)
(*             the repository, with no clock and no sync message           *)
(*   Deliver   SyncEventProcessor._applyAgentEntityMessage, which applies  *)
(*             resolveReceivedAgentEntity (agent_entity_receive.dart):     *)
(*             the stored row, tombstone included, against                 *)
(*             resolveAgentEntityVersions (agent_concurrent_resolver.dart):*)
(*             causal dominance first; a concurrent pair goes to the       *)
(*             type's override, then updatedAt, then the canonical clock   *)
(*             tiebreak, and agent state joins its G-counters. One         *)
(*             transaction, or, as before for most types, a read and a     *)
(*             write with an await between them (ReceiveRead,              *)
(*             ReceiveWrite)                                               *)
(*   Lose      the network drops one delivery to one replica               *)
(*   Backfill  BackfillResponseHandler: the writer answers the gap with    *)
(*             its current row for the id, or with `deleted` when it has   *)
(*             none to send                                                *)
(*   Tick      the wall clock                                              *)
(*                                                                         *)
(* The five design switches are the fixes of ADR 0068; setting one to      *)
(* FALSE restores the old behaviour and its counterexample (README).       *)
(* `Intend` (the ADR 0068 addendum) is a write meant to move the row       *)
(* against the resolver's order -- out of the terminal status, or to new  *)
(* fields at the row's own timestamp. `IntentCarriesClock` is its fix: a  *)
(* writer built on no clock was judged concurrent with the row it meant   *)
(* to replace and handed that row back (`LocalWriteTakesEffect`). On the  *)
(* removal kind `Intend` is a re-creation: a writer that cannot see the   *)
(* tombstone builds the row afresh under the same id, and                  *)
(* `RecreateKeepsFields` is the rule that it keeps its fields.             *)
(* `RankDrop` lets a write leave the terminal status it built on -- a      *)
(* digest retry re-arming its consumed window at the same instant -- which *)
(* is a documented residual, not a checked configuration.                  *)
(*                                                                         *)
(* The five tombstone switches (ReceiveSeesTombstones,                     *)
(* BackfillServesTombstones, WriteSeesTombstones, RecreateKeepsFields,     *)
(* AtomicReceive) are the fixes of ADR 0081's addendum; they matter only   *)
(* to the removal kind and to lossy delivery, and leave the other          *)
(* configurations' state spaces as they were.                              *)
(*                                                                         *)
(* A clock maps each replica to a counter or to `Absent`: a host that has  *)
(* never written the entity has no entry. `FirstCounter` is the first      *)
(* counter VectorClockService hands a new host -- 1 since ADR 0080, 0 on   *)
(* every host an older build created, which is the installed base. The     *)
(* two ADR 0080 switches say how the receive path reads an absent entry:   *)
(* `AbsentBelowZero` for VectorClock.compare (causal dominance, and the    *)
(* local write resolution's cover check), `CanonAbsentBelowZero` for       *)
(* VectorClock.compareCanonically (the concurrent tiebreak). Read as 0, a  *)
(* host's first counter 0 is invisible: the write that adds it compares    *)
(* equal to the version it extends. The properties use the causal order    *)
(* itself, in which a present entry is always above an absent one.        *)
(***************************************************************************)
EXTENDS Integers, FiniteSets

CONSTANTS
    N,            \* replicas 1..N
    MaxWrites,    \* local writes, across all replicas
    MaxTime,      \* the wall clock runs 0..MaxTime
    Skew,         \* how far a write's updatedAt may lag the clock
    Kind,         \* "state", "terminal" or "removal"
    StaleWrites,  \* may a write build on a snapshot or on no clock at all?
    Throttle,     \* does the throttle coordinator persist deadlines?
    RankDrop,     \* may a write leave the terminal status it built on?
    Lossy,        \* may a delivery be lost and recovered by backfill?
    \* Design switches: TRUE is the code after ADR 0068.
    ThrottleKeepsTimestamp,  \* device-local writes leave updatedAt alone
    CountersJoinAlways,      \* G-counters join on every delivery
    ResolveLocalWrites,      \* a write succeeds the row it replaces
    ClampTimestamp,          \* ...and its updatedAt is not older
    IntentWrites,            \* are there writes meant to move the row back?
    IntentCarriesClock,      \* ...carrying the row's clock (0068 addendum)
    FirstCounter,            \* a new host's first counter: 1, or 0 (legacy)
    \* Design switches: TRUE is the code after ADR 0080.
    AbsentBelowZero,         \* compare ranks an absent host below counter 0
    CanonAbsentBelowZero,    \* ...and so does the canonical tiebreak
    \* Design switches: TRUE is the code after ADR 0081's addendum.
    ReceiveSeesTombstones,     \* the receive compares against a tombstone
    BackfillServesTombstones,  \* backfill answers with a tombstone
    WriteSeesTombstones,       \* the local write resolves against one
    RecreateKeepsFields,       \* a row built afresh over one keeps its fields
    AtomicReceive              \* the receive reads and writes in one transaction

ASSUME Kind \in {"state", "terminal", "removal"}
ASSUME \A b \in {StaleWrites, Throttle, RankDrop, Lossy,
                 ThrottleKeepsTimestamp, CountersJoinAlways,
                 ResolveLocalWrites, ClampTimestamp, IntentWrites,
                 IntentCarriesClock, AbsentBelowZero, CanonAbsentBelowZero,
                 ReceiveSeesTombstones, BackfillServesTombstones,
                 WriteSeesTombstones, RecreateKeepsFields, AtomicReceive} :
            b \in BOOLEAN
ASSUME FirstCounter \in {0, 1}

R == 1..N
Absent == -1
NoClock == [r \in R |-> Absent]
Zero == [r \in R |-> 0]
Max(a, b) == IF a > b THEN a ELSE b
\* VectorClock.merge: the union of the hosts, each at its larger counter.
\* The same join serves the G-counters.
Join(a, b) == [r \in R |-> Max(a[r], b[r])]

\* The causal order. A present entry, 0 included, says the host wrote.
CLeq(a, b) == \A r \in R : a[r] <= b[r]
Before(a, b) == CLeq(a, b) /\ a # b

\* VectorClock.compare(a, b) is `equal` or `b_gt_a`. Before ADR 0080 it
\* read an absent host as counter 0.
Read(x) == IF AbsentBelowZero THEN x ELSE Max(x, 0)
Leq(a, b) == \A r \in R : Read(a[r]) <= Read(b[r])

\* VectorClock.compareCanonically(a, b) > 0: the first host, in sorted
\* order, whose counters differ is larger in a. Before ADR 0080 it too
\* read an absent host as counter 0.
CanonRead(x) == IF CanonAbsentBelowZero THEN x ELSE Max(x, 0)
CanonGt(a, b) ==
    \E k \in R : /\ CanonRead(a[k]) > CanonRead(b[k])
                /\ \A j \in R : j < k => CanonRead(a[j]) = CanonRead(b[j])

\* A version: its write id, the replica that wrote it, clock, updatedAt,
\* override status (on the removal kind, its tombstone), G-counter. A merged
\* row keeps the id and writer of the version whose fields won. The first
\* version was written by a host outside R.
V0 == [id |-> 0, host |-> 0, vc |-> NoClock, ts |-> 0, term |-> FALSE,
       g |-> Zero]

\* A removed row.
Tomb(v) == Kind = "removal" /\ v.term

VARIABLES
    row,        \* per replica: the persisted row
    snap,       \* per replica: a row read at wake start
    sent,       \* every write ever made (the network delivers each)
    delivered,  \* per replica: the writes it has received or made
    lost,       \* per replica: writes whose delivery the network dropped
    resolved,   \* per replica: lost writes that backfill has answered
    rd,         \* per replica: a receive that has read the row, not written
    now,        \* the wall clock
    hc,         \* per replica: the last counter VectorClockService issued
                \* (FirstCounter - 1 before the first)
    incs,       \* ghost: G-counter increments made by each host
    intentLost  \* ghost: a local write lost to the row it meant to move

vars == <<row, snap, sent, delivered, lost, resolved, rd, now, hc, incs,
          intentLost>>

NoRead == [m |-> V0, l |-> V0, on |-> FALSE]

Init ==
    /\ row = [r \in R |-> V0]
    /\ snap = [r \in R |-> V0]
    /\ sent = {}
    /\ delivered = [r \in R |-> {}]
    /\ lost = [r \in R |-> {}]
    /\ resolved = [r \in R |-> {}]
    /\ rd = [r \in R |-> NoRead]
    /\ now = 0
    /\ hc = [r \in R |-> FirstCounter - 1]
    /\ incs = [r \in R |-> 0]
    /\ intentLost = FALSE

\* The concurrent winner: the type's override, then updatedAt, then the
\* canonical clock tiebreak (resolveConcurrent). A tombstone has no override:
\* its `deletedAt` is its timestamp (effectiveUpdatedAt).
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
\* Before ADR 0081's addendum the stored row was read with `getEntity`,
\* which filters `deleted_at IS NULL`: a tombstone read as no row, and any
\* version that arrived replaced it.
Merge(l, i) ==
    IF Tomb(l) /\ ~ReceiveSeesTombstones THEN i
    ELSE IF Leq(i.vc, l.vc) THEN l
    ELSE IF Leq(l.vc, i.vc)
         THEN IF Kind = "state" /\ CountersJoinAlways
              THEN [i EXCEPT !.g = Join(l.g, i.g)] ELSE i
    ELSE MergeConcurrent(l, i)

Bases == {"row"} \cup (IF StaleWrites THEN {"snap", "null"} ELSE {})

BaseRow(r, b) ==
    CASE b = "row"  -> row[r]
      [] b = "snap" -> snap[r]
      [] b = "null" -> [row[r] EXCEPT !.vc = NoClock]

\* A write keeps the terminal status it built on unless RankDrop. A write
\* may remove the removal kind's row, or write it live.
Terms(base) ==
    IF Kind = "state" THEN {FALSE}
    ELSE IF Kind = "removal" \/ RankDrop THEN BOOLEAN
    ELSE {base.term, TRUE}

\* A G-counter is only bumped on the row the writer re-read; the snapshot
\* writers that bumped one are AgentStateWrites.tla.
Incs(b) == IF Kind = "state" /\ b = "row" THEN BOOLEAN ELSE {FALSE}

\* Old: the clock is the base's plus this host's next counter, and the write
\* replaces the row whatever it was built on. Fixed: the clock also covers
\* the persisted row, so the write succeeds it on every replica; a write
\* whose base did not cover the row keeps the fields that would have won had
\* the two been concurrent, and a write never lowers a G-counter.
Fields(r, B, t, tm, inc) ==
    [B EXCEPT !.ts = t, !.term = tm,
              !.g = IF inc THEN [B.g EXCEPT ![r] = @ + 1] ELSE B.g]

\* Whether the local write resolution reads the persisted row. Before ADR
\* 0081's addendum it read with `getEntity` too, and a tombstone was no row.
Seen(P) == ~(Tomb(P) /\ ~WriteSeesTombstones)

\* The local write resolution judges the base concurrent with the row.
Resolved(r, B) ==
    ResolveLocalWrites /\ Seen(row[r]) /\ ~Leq(row[r].vc, B.vc)

\* A live row built afresh over a tombstone: a re-creation under the same
\* id, which keeps its fields (resolveLocalAgentWrite).
Recreation(P, B, tm) ==
    RecreateKeepsFields /\ Tomb(P) /\ ~tm /\ B.vc = NoClock

NewVersion(r, B, t, tm, inc) ==
    LET P == row[r]
        base == Fields(r, B, t, tm, inc)
        fields == IF Resolved(r, B) /\ ~Recreation(P, B, tm)
                  THEN MergeConcurrent(P, base) ELSE base
        succeeds == ResolveLocalWrites /\ Seen(P)
        vc == [(IF succeeds THEN Join(B.vc, P.vc) ELSE B.vc)
                 EXCEPT ![r] = hc[r] + 1]
        ts == IF ClampTimestamp /\ Before(P.vc, vc)
              THEN Max(fields.ts, P.ts) ELSE fields.ts
        \* A merge may have joined counters into P without moving its
        \* clock, so a base that covers P's clock can still lack them.
        g == IF succeeds THEN Join(fields.g, P.g) ELSE fields.g
    IN [id |-> Cardinality(sent) + 1, host |-> r, vc |-> vc,
        ts |-> ts, term |-> fields.term, g |-> g]

Commit(r, w, inc) ==
    /\ sent' = sent \cup {w}
    /\ delivered' = [delivered EXCEPT ![r] = @ \cup {w}]
    /\ row' = [row EXCEPT ![r] = w]
    /\ hc' = [hc EXCEPT ![r] = @ + 1]
    /\ incs' = IF inc THEN [incs EXCEPT ![r] = @ + 1] ELSE incs
    /\ UNCHANGED <<lost, resolved, rd>>

Write(r) ==
    /\ Cardinality(sent) < MaxWrites
    /\ \E b \in Bases, t \in (IF now > Skew THEN now - Skew ELSE 0)..now,
          tm \in BOOLEAN, inc \in BOOLEAN :
        LET B == BaseRow(r, b)
        IN /\ tm \in Terms(B)
           /\ inc \in Incs(b)
           /\ Commit(r, NewVersion(r, B, t, tm, inc), inc)
    /\ UNCHANGED <<snap, now, intentLost>>

\* A write whose whole point is to move the row against the resolver's
\* order, built on the row it read: on the terminal kind it leaves the
\* terminal status (a pre-warm moved earlier, a consumed window re-armed);
\* on the state kind it keeps the row's own timestamp (a report head moved
\* at the instant the head it replaces was stamped). After the ADR 0068
\* addendum such writers carry the row's clock; built on none, the local
\* write resolution judged them concurrent with the row and handed the row
\* back. On the removal kind it re-creates a removed row: the writer reads
\* with `getEntity`, sees no row, and builds it afresh.
Intend(r) ==
    /\ IntentWrites
    /\ Cardinality(sent) < MaxWrites
    /\ Kind = "state" \/ row[r].term
    /\ LET P == row[r]
           B == [P EXCEPT !.vc = IF IntentCarriesClock /\ Kind # "removal"
                                 THEN P.vc ELSE NoClock]
           t == IF Kind = "state" THEN P.ts ELSE now
       IN /\ Commit(r, NewVersion(r, B, t, FALSE, FALSE), FALSE)
          /\ intentLost' =
                \/ intentLost
                \/ /\ Resolved(r, B)
                   /\ ~Recreation(P, B, FALSE)
                   /\ Winner(P, Fields(r, B, t, FALSE, FALSE)) = P
    /\ UNCHANGED <<snap, now>>

Snapshot(r) ==
    /\ StaleWrites
    /\ snap[r] # row[r]
    /\ snap' = [snap EXCEPT ![r] = row[r]]
    /\ UNCHANGED <<row, sent, delivered, lost, resolved, rd, now, hc, incs,
                   intentLost>>

\* The throttle persists nextWakeAt, which sync never carries. The old code
\* also stamped updatedAt with the local clock.
ThrottleDeadline(r) ==
    /\ Throttle
    /\ ~ThrottleKeepsTimestamp
    /\ row[r].ts < now
    /\ row' = [row EXCEPT ![r].ts = now]
    /\ UNCHANGED <<snap, sent, delivered, lost, resolved, rd, now, hc, incs,
                   intentLost>>

\* The receive reads the stored row and writes what the resolver keeps in
\* one transaction.
Deliver(r) ==
    /\ AtomicReceive
    /\ \E m \in sent \ lost[r] :
        /\ row' = [row EXCEPT ![r] = Merge(@, m)]
        /\ delivered' = [delivered EXCEPT ![r] = @ \cup {m}]
    /\ UNCHANGED <<snap, sent, lost, resolved, rd, now, hc, incs, intentLost>>

\* Before ADR 0081's addendum every type but agent state, change sets and
\* evolution sessions read the stored row (or the bundle's prefetched
\* snapshot of it), and wrote the resolved row after an await, where a
\* local write can commit.
ReceiveRead(r) ==
    /\ ~AtomicReceive
    /\ ~rd[r].on
    /\ \E m \in sent \ lost[r] :
        rd' = [rd EXCEPT ![r] = [m |-> m, l |-> row[r], on |-> TRUE]]
    /\ UNCHANGED <<row, snap, sent, delivered, lost, resolved, now, hc, incs,
                   intentLost>>

ReceiveWrite(r) ==
    /\ rd[r].on
    /\ LET kept == Merge(rd[r].l, rd[r].m)
       IN row' = IF kept = rd[r].l THEN row ELSE [row EXCEPT ![r] = kept]
    /\ delivered' = [delivered EXCEPT ![r] = @ \cup {rd[r].m}]
    /\ rd' = [rd EXCEPT ![r] = NoRead]
    /\ UNCHANGED <<snap, sent, lost, resolved, now, hc, incs, intentLost>>

Lose(r) ==
    /\ Lossy
    /\ \E m \in sent \ (delivered[r] \cup lost[r]) :
        lost' = [lost EXCEPT ![r] = @ \cup {m}]
    /\ UNCHANGED <<row, snap, sent, delivered, resolved, rd, now, hc, incs,
                   intentLost>>

\* The writer of a lost version answers with its current row for the id --
\* before the fix only a live one (`getEntity` again); a tombstone was
\* answered `deleted`, which settles the gap with nothing applied.
Served(v) == v.id # 0 /\ ~(Tomb(v) /\ ~BackfillServesTombstones)

Backfill(r) ==
    /\ \E m \in lost[r] :
        LET answer == row[m.host]
        IN /\ lost' = [lost EXCEPT ![r] = @ \ {m}]
           /\ resolved' = [resolved EXCEPT ![r] = @ \cup {m}]
           /\ IF Served(answer)
              THEN /\ row' = [row EXCEPT ![r] = Merge(@, answer)]
                   /\ delivered' = [delivered EXCEPT ![r] = @ \cup {answer}]
              ELSE UNCHANGED <<row, delivered>>
    /\ UNCHANGED <<snap, sent, rd, now, hc, incs, intentLost>>

Tick ==
    /\ now < MaxTime
    /\ now' = now + 1
    /\ UNCHANGED <<row, snap, sent, delivered, lost, resolved, rd, hc, incs,
                   intentLost>>

Next ==
    \/ Tick
    \/ \E r \in R : \/ Write(r) \/ Intend(r) \/ Snapshot(r)
                   \/ ThrottleDeadline(r) \/ Deliver(r)
                   \/ ReceiveRead(r) \/ ReceiveWrite(r)
                   \/ Lose(r) \/ Backfill(r)

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MaxTime
    /\ \A r \in R : /\ row[r].id \in 0..MaxWrites
                    /\ delivered[r] \subseteq sent
                    /\ lost[r] \subseteq sent

\* Every write has reached every replica, directly or through backfill.
Quiescent ==
    \A r \in R : sent \subseteq delivered[r] \cup resolved[r] /\ ~rd[r].on

\* The synced part of a row (updatedAt aside: the throttle mutant bumps it
\* locally, and what matters is which version and fields each replica keeps).
Content(v) == [id |-> v.id, vc |-> v.vc, term |-> v.term, g |-> v.g]

\* Strong eventual consistency: the same writes received, the same row.
Converged ==
    Quiescent => \A a, b \in R : Content(row[a]) = Content(row[b])

VcOf(id) == IF id = 0 THEN NoClock ELSE (CHOOSE v \in sent : v.id = id).vc

\* A row never holds a version that a write it received causally replaced:
\* on the removal kind, a removed row is never brought back by a late copy
\* of the live version it removed.
NoLostSuccessor ==
    \A r \in R : \A m \in delivered[r] : ~Before(VcOf(row[r].id), m.vc)

\* A host always sees all of its own increments...
OwnCountKept == Kind = "state" => \A r \in R : row[r].g[r] = incs[r]

\* ...and, once everything is delivered, everyone else's.
NoLostIncrement ==
    (Kind = "state" /\ Quiescent) =>
        \A r, h \in R : row[r].g[h] = incs[h]

\* A write meant to move the row keeps its fields on the writing device.
LocalWriteTakesEffect == ~intentLost
=============================================================================

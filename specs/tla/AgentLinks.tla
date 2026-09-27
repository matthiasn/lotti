---------------------------- MODULE AgentLinks ----------------------------
(***************************************************************************)
(* Replicas of synced agent links (`AgentLink`): their versions are live   *)
(* or tombstoned (`deletedAt`), written on any device, and delivered to    *)
(* every replica in any order, any number of times. A delivery can also be *)
(* lost, and the receiver then asks the writer for it by backfill. The     *)
(* question is the one AgentReplication.tla asks of agent entities: once   *)
(* every write has reached every replica, do they hold the same version,   *)
(* and is a version never replaced by one it causally succeeded -- a       *)
(* removed link never brought back by a late copy of its live self?        *)
(*                                                                         *)
(* Without `Slot`, one link id stands for every link written under a      *)
(* reused id: the deterministic ids of the Daily OS links                  *)
(* (`parsed_item_to_task:...`, `capture_to_plan:...`, the parse-completion *)
(* self-link), the planner's template assignment, the `msgprev-...` edges, *)
(* and any link that is soft-deleted and written again.                    *)
(*                                                                         *)
(* With `Slot`, two link ids share one slot: a template's soul assignment *)
(* (`soul_assignment`, keyed by from_id) or a template's improver          *)
(* (`improver_target`, keyed by to_id). Each assignment is written under a *)
(* fresh id, and the slot shows one of the live ones. Before ADR 0099 the *)
(* repository's upsert handed the slot over: writing a live assignment     *)
(* tombstoned the slot's other live rows locally, with no clock bump and   *)
(* no sync message. After it, every row is kept as it arrived and the      *)
(* slot shows the live row ranked first by (createdAt, id); a writer       *)
(* stamps a new assignment's createdAt above every row of the slot it has *)
(* seen.                                                                   *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Link      a writer constructing the link afresh (`vectorClock: null`)  *)
(*             and AgentSyncService.upsertLink stamping it                  *)
(*   Unlink    `link.softDeleted(now)` of the row the writer read, which   *)
(*             carries that row's clock, through upsertLink               *)
(*   Deliver   SyncEventProcessor._resolveAndPersistAgentLink: the local   *)
(*             row stands if it dominates, or wins a concurrent pair on     *)
(*             updatedAt and then the canonical clock tiebreak             *)
(*             (resolveAgentLinkVersions), in one transaction or, as      *)
(*             before, with an await between the read and the write       *)
(*             (ReceiveRead, ReceiveWrite)                                 *)
(*   Apply     AgentRepoLinks.upsertLink persisting a version, with or    *)
(*             without the old slot handoff                               *)
(*   Winner    AgentRepoLinks' slot rule, which leaves only the winner    *)
(*             visible to reads (`deleted_at IS NULL`)                    *)
(*   Lose      the network drops one delivery to one replica               *)
(*   Backfill  BackfillResponseHandler: the writer answers the gap with    *)
(*             its current row for the id, or with `deleted` when it has   *)
(*             none to send                                                *)
(*                                                                         *)
(* The first five design switches are the fixes of ADR 0081, the last two *)
(* those of ADR 0099; FALSE restores the old behaviour and its             *)
(* counterexample (README).                                                *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    N,          \* replicas 1..N
    MaxWrites,  \* local writes, across all replicas
    MaxTime,    \* the wall clock runs 0..MaxTime
    Skew,       \* how far a write's updatedAt may lag the clock
    Lossy,      \* may a delivery be lost and recovered by backfill?
    Slot,       \* two fresh-id assignments of one slot, not one reused id
    \* Design switches: TRUE is the code after ADR 0081 and ADR 0099.
    ReceiveSeesTombstones,     \* the receive compares against a tombstone
    BackfillServesTombstones,  \* backfill answers with a tombstone
    WriteSucceedsRow,          \* a write's clock covers the persisted row's
    ClampTimestamp,            \* ...and its updatedAt is not older
    AtomicReceive,             \* the receive reads and writes in one transaction
    SlotRule,                  \* every row kept, the slot ranks them; no handoff
    ClampCreatedAt             \* a new assignment outranks every row seen

ASSUME \A b \in {Lossy, Slot, ReceiveSeesTombstones, BackfillServesTombstones,
                 WriteSucceedsRow, ClampTimestamp, AtomicReceive, SlotRule,
                 ClampCreatedAt} :
            b \in BOOLEAN

R == 1..N
Keys == IF Slot THEN {1, 2} ELSE {1}
Zero == [r \in R |-> 0]
Max(a, b) == IF a > b THEN a ELSE b
Join(a, b) == [r \in R |-> Max(a[r], b[r])]
Leq(a, b) == \A r \in R : a[r] <= b[r]
Before(a, b) == Leq(a, b) /\ a # b
CanonGt(a, b) == \E k \in R : a[k] > b[k] /\ \A j \in R : j < k => a[j] = b[j]

\* A version: write id, link id (`key`), the host that wrote it, live or
\* tombstoned, clock, updatedAt, createdAt (`ca`), and the other links of the
\* slot its writer held when it wrote (`saw`, a ghost). `Absent` is no row.
Absent == [id |-> 0, key |-> 0, host |-> 0, live |-> FALSE, vc |-> Zero,
           ts |-> 0, ca |-> 0, saw |-> {}]

VARIABLES
    row,        \* per replica, per link id: the persisted link row
    sent,       \* every write ever made
    delivered,  \* per replica: the versions it has received or made
    lost,       \* per replica: writes whose delivery the network dropped
    resolved,   \* per replica: lost writes that backfill has answered
    now,        \* the wall clock
    hc,         \* per replica: the last counter VectorClockService issued
    rd          \* per replica: a receive that has read the row, not written

vars == <<row, sent, delivered, lost, resolved, now, hc, rd>>

NoRead == [m |-> Absent, l |-> Absent, on |-> FALSE]

Init ==
    /\ row = [r \in R |-> [k \in Keys |-> Absent]]
    /\ sent = {}
    /\ delivered = [r \in R |-> {}]
    /\ lost = [r \in R |-> {}]
    /\ resolved = [r \in R |-> {}]
    /\ now = 0
    /\ hc = [r \in R |-> 0]
    /\ rd = [r \in R |-> NoRead]

\* What the receive compares against. Before the fix the local row was read
\* with `getLinkById`, which filters `deleted_at IS NULL`: a tombstone read
\* as no row, and any version that arrived replaced it.
Visible(v) == v.id # 0 /\ (v.live \/ ReceiveSeesTombstones)

\* The row a replica holding `l` keeps after receiving `i`.
Merge(l, i) ==
    IF ~Visible(l) THEN i
    ELSE IF Leq(i.vc, l.vc) THEN l
    ELSE IF Leq(l.vc, i.vc) THEN i
    ELSE IF i.ts > l.ts THEN i
    ELSE IF l.ts > i.ts THEN l
    ELSE IF CanonGt(i.vc, l.vc) THEN i ELSE l

\* The slot's ranking: createdAt, then the link id (`orderedPrimaryFirst`).
RankGt(v, w) == v.ca > w.ca \/ (v.ca = w.ca /\ v.key > w.key)

LiveKeys(r) == {k \in Keys : row[r][k].live}

\* The link the slot shows on replica r, or 0 for none.
Winner(r) ==
    IF LiveKeys(r) = {} THEN 0
    ELSE CHOOSE k \in LiveKeys(r) :
            \A j \in LiveKeys(r) \ {k} : RankGt(row[r][k], row[r][j])

\* AgentRepoLinks.upsertLink persisting version v of its link. Before ADR
\* 0099 a live assignment tombstoned the slot's other live rows in place:
\* the same clock and write id, updatedAt now, and nothing sent.
Apply(r, v) ==
    [k \in Keys |->
        IF k = v.key THEN v
        ELSE IF ~SlotRule /\ v.live /\ row[r][k].live
             THEN [row[r][k] EXCEPT !.live = FALSE, !.ts = now]
             ELSE row[r][k]]

Stamps == (IF now > Skew THEN now - Skew ELSE 0)..now

\* The newest createdAt among the slot's rows replica r holds, any state.
Seen(r) == {row[r][k].ca : k \in {j \in Keys : row[r][j].id # 0}}
SeenMax(r) == CHOOSE c \in Seen(r) : \A d \in Seen(r) : c >= d

\* A new assignment's createdAt: the writer's clock, or after ADR 0099 above
\* every row of the slot the writer has seen.
Created(r, t) ==
    IF ClampCreatedAt /\ Seen(r) # {} THEN Max(t, SeenMax(r) + 1) ELSE t

\* Old: the clock is the base's plus this host's next counter, and the row
\* is overwritten. Fixed: the clock also covers the persisted row, tombstone
\* included, and updatedAt is not older than that row's.
NewVersion(r, k, B, live, t) ==
    LET P == row[r][k]
        vc == [(IF WriteSucceedsRow THEN Join(B.vc, P.vc) ELSE B.vc)
                 EXCEPT ![r] = hc[r] + 1]
        fresh == Slot /\ live /\ P.id = 0
    IN [id |-> Cardinality(sent) + 1, key |-> k, host |-> r, live |-> live,
        vc |-> vc,
        ts |-> IF ClampTimestamp THEN Max(t, P.ts) ELSE t,
        ca |-> IF fresh THEN Created(r, t) ELSE P.ca,
        saw |-> IF fresh THEN {j \in Keys \ {k} : row[r][j].id # 0}
                ELSE P.saw]

Commit(r, v) ==
    /\ sent' = sent \cup {v}
    /\ delivered' = [delivered EXCEPT ![r] = @ \cup {v}]
    /\ row' = [row EXCEPT ![r] = Apply(r, v)]
    /\ hc' = [hc EXCEPT ![r] = @ + 1]
    /\ UNCHANGED <<lost, resolved, now, rd>>

\* A writer constructing the link afresh: `vectorClock: null`. A slot
\* assignment always takes a fresh id.
Link(r, k) ==
    /\ Cardinality(sent) < MaxWrites
    /\ Slot => \A v \in sent : v.key # k
    /\ \E t \in Stamps : Commit(r, NewVersion(r, k, Absent, TRUE, t))

\* `softDeleted` of the live row the writer read.
Unlink(r, k) ==
    /\ Cardinality(sent) < MaxWrites
    /\ row[r][k].live
    /\ \E t \in Stamps : Commit(r, NewVersion(r, k, row[r][k], FALSE, t))

\* A receive writes only when the incoming version wins its link's row.
Receive(r, m) ==
    IF Merge(row[r][m.key], m) = row[r][m.key] THEN row[r]
    ELSE Apply(r, m)

\* After ADR 0081 the receive reads the local row and writes the winner in
\* one transaction.
Deliver(r) ==
    /\ AtomicReceive
    /\ \E m \in sent \ lost[r] :
        /\ row' = [row EXCEPT ![r] = Receive(r, m)]
        /\ delivered' = [delivered EXCEPT ![r] = @ \cup {m}]
    /\ UNCHANGED <<sent, lost, resolved, now, hc, rd>>

\* Before: the local row was read, and the incoming version written after an
\* await, where a local write can commit.
ReceiveRead(r) ==
    /\ ~AtomicReceive
    /\ ~rd[r].on
    /\ \E m \in sent \ lost[r] :
        rd' = [rd EXCEPT ![r] = [m |-> m, l |-> row[r][m.key], on |-> TRUE]]
    /\ UNCHANGED <<row, sent, delivered, lost, resolved, now, hc>>

ReceiveWrite(r) ==
    /\ rd[r].on
    /\ row' = IF Merge(rd[r].l, rd[r].m) = rd[r].l THEN row
              ELSE [row EXCEPT ![r] = Apply(r, rd[r].m)]
    /\ delivered' = [delivered EXCEPT ![r] = @ \cup {rd[r].m}]
    /\ rd' = [rd EXCEPT ![r] = NoRead]
    /\ UNCHANGED <<sent, lost, resolved, now, hc>>

Lose(r) ==
    /\ Lossy
    /\ \E m \in sent \ (delivered[r] \cup lost[r]) :
        lost' = [lost EXCEPT ![r] = @ \cup {m}]
    /\ UNCHANGED <<row, sent, delivered, resolved, now, hc, rd>>

\* The writer of a lost version answers with its current row for the id --
\* before the fix only a live one (`getLinkById` again); a tombstone was
\* answered `deleted`, which settles the gap with nothing applied.
Served(v) == v.id # 0 /\ (v.live \/ BackfillServesTombstones)

Backfill(r) ==
    /\ \E m \in lost[r] :
        LET answer == row[m.host][m.key]
        IN /\ lost' = [lost EXCEPT ![r] = @ \ {m}]
           /\ resolved' = [resolved EXCEPT ![r] = @ \cup {m}]
           /\ IF Served(answer)
              THEN /\ row' = [row EXCEPT ![r] = Receive(r, answer)]
                   /\ delivered' = [delivered EXCEPT ![r] = @ \cup {answer}]
              ELSE UNCHANGED <<row, delivered>>
    /\ UNCHANGED <<sent, now, hc, rd>>

Tick ==
    /\ now < MaxTime
    /\ now' = now + 1
    /\ UNCHANGED <<row, sent, delivered, lost, resolved, hc, rd>>

Next ==
    \/ Tick
    \/ \E r \in R : \/ \E k \in Keys : Link(r, k) \/ Unlink(r, k)
                   \/ Deliver(r)
                   \/ ReceiveRead(r) \/ ReceiveWrite(r)
                   \/ Lose(r) \/ Backfill(r)

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MaxTime
    /\ \A r \in R : /\ \A k \in Keys : row[r][k].id \in 0..MaxWrites
                    /\ delivered[r] \subseteq sent
                    /\ lost[r] \subseteq sent

\* Every write has reached every replica, directly or through backfill.
Quiescent ==
    \A r \in R : sent \subseteq delivered[r] \cup resolved[r] /\ ~rd[r].on

Content(v) == [id |-> v.id, live |-> v.live]

\* Strong eventual consistency: the same writes received, the same links.
Converged ==
    Quiescent => \A a, b \in R : \A k \in Keys :
                    Content(row[a][k]) = Content(row[b][k])

\* ...and the slot shows the same assignment everywhere.
SlotConverged ==
    Quiescent => \A a, b \in R : Winner(a) = Winner(b)

\* A row never holds a version that a version it received causally
\* replaced: a removal is not undone by a late copy of the live link.
NoLostSuccessor ==
    \A r \in R : \A k \in Keys : \A m \in delivered[r] :
        m.key = k => ~Before(row[r][k].vc, m.vc)

\* An assignment outranks every assignment its writer had seen, so a
\* reassignment shows wherever both are live -- on its own device first.
SuccessorOutranks ==
    \A r \in R : \A j, k \in LiveKeys(r) :
        j \in row[r][k].saw => RankGt(row[r][k], row[r][j])
=============================================================================

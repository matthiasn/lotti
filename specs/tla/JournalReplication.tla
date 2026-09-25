------------------------- MODULE JournalReplication -------------------------
(***************************************************************************)
(* Replicas of one journal entry -- a task, a note, a habit completion, a  *)
(* checklist item -- on two or three devices: edits and soft deletions,    *)
(* written on the stored row or on an entry a screen read earlier; a       *)
(* network that delivers every version to every device in any order, any   *)
(* number of times, and may lose one that backfill then recovers; the user *)
(* resolving the conflicts the devices raise; and the JSON sidecar, the    *)
(* payload a device sends for the entry. Unlike agent entities, journal    *)
(* entries never merge on their own: two concurrent versions become a      *)
(* Conflict row that the user decides. So the question is not only         *)
(* whether the devices converge, but whether a divergence is ever silent   *)
(* -- a version dropped without a conflict to show for it.                 *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Decide      JournalDb.updateJournalEntity and detectConflict          *)
(*               (database_entity_ops.dart), the one write decision for    *)
(*               local writes and the receive alike: the stored row, read  *)
(*               in the write's transaction, against the incoming clock.   *)
(*               Newer applies; equal or older is refused; concurrent is   *)
(*               stored as the entry's single Conflict row                 *)
(*               (insertOnConflictUpdate by id) and refused. An applied    *)
(*               write marks the conflict resolved.                        *)
(*   Edit        an edit or JournalRepository.deleteJournalEntity: the     *)
(*               entry read with journalEntityById (which hides a deleted  *)
(*               one), MetadataService.updateMetadata's clock -- the       *)
(*               read's plus this device's next counter -- then Decide     *)
(*   Restore     a writer that reads the deletion and brings the entry     *)
(*               back on its clock (RelationshipToolDispatcher)            *)
(*   Snapshot    a screen holding the entry it read (the entry editor)     *)
(*   LabelWrite  LabelsRepository.setLabels and suppressLabelOnTask        *)
(*   Resolve     ConflictResolutionService.keepSide / combine and the      *)
(*               delete-versus-edit choice: VectorClock.merge of both      *)
(*               sides plus this device's next counter, through            *)
(*               PersistenceLogic.updateJournalEntity                      *)
(*   Deliver     SyncEventProcessor._persistJournalEntity for an envelope  *)
(*               that names its attachment event: Decide in one            *)
(*               transaction                                               *)
(*   Prepare,    the same for a path-only envelope from an older peer:     *)
(*   ApplyTx,    SmartJournalEntityLoader saves the incoming JSON over the *)
(*   CommitTx,   sidecar before the decision; the decision is nested in    *)
(*   RollbackTx  the receive's transaction with the embedded links, whose  *)
(*               failure rolls it back and the event is retried            *)
(*   Publish     JournalDb._publishSidecar: sidecar writes per entry in    *)
(*               ticket order, a ticket older than the newest on disk      *)
(*               skipped                                                   *)
(*   Refresh*    OutboxEnqueueWriter.enqueueJournalEntity rewriting the    *)
(*               sidecar from the stored row before it reads the payload   *)
(*   Lose,       the network drops a delivery; BackfillResponseHandler     *)
(*   Backfill    answers with the writer's current row if it still carries *)
(*               the requested counter, `unresolvable` if not, `deleted`   *)
(*               for a row journalEntityById does not return               *)
(*                                                                         *)
(* A clock maps each device to a counter, 0 for absent (new hosts start at *)
(* 1, ADR 0080). `nc` marks a version without a clock: an entry created    *)
(* before clocks existed. The properties judge the code's decisions        *)
(* against the ghost history `hist`, the versions a version causally       *)
(* follows. On one device the last save supersedes an earlier one it did   *)
(* not read whenever its clock covers it (Covered): that is the design,    *)
(* not a hole, and the ghost says so too.                                  *)
(*                                                                         *)
(* The nine design switches are the fixes of ADR 0083; setting one to      *)
(* FALSE restores the old behaviour and its counterexample (README).       *)
(***************************************************************************)
EXTENDS Integers, FiniteSets

CONSTANTS
    N,            \* devices 1..N
    MaxWrites,    \* versions written, across all devices
    Stale,        \* may a local write build on an entry read earlier?
    Resolves,     \* may the user resolve an open conflict?
    Restores,     \* may a writer bring a deleted entry back?
    Labels,       \* label writes: setLabels and suppressLabelOnTask
    NullBase,     \* the entry predates clocks, and a late copy is in flight
    Lossy,        \* may a delivery be lost and recovered by backfill?
    Sidecars,     \* the JSON sidecar, a path-only receive and its transaction
    Rollbacks,    \* ...whose enclosing transaction rolls back this often
    Queued,       \* sidecar writes queued per device, at most
    \* Design switches: TRUE is the code after ADR 0083.
    ReceiveSeesTombstones,     \* the write decision reads a soft-deleted row
    BackfillServesTombstones,  \* backfill answers with a soft-deleted row
    ConflictSeesTombstone,     \* the conflict page opens over one
    ResolveOnlyCovered,        \* an applied write settles only a conflict it covers
    KeepNewerConflict,         \* a stale copy does not replace a newer conflict
    LabelsRebuild,             \* a label write rebuilds on the stored row
    RefuseNullClock,           \* a clockless copy never replaces a clocked row
    RestoreSidecar,            \* a refused path-only receive restores the sidecar
    RefreshThroughQueue        \* the outbox's sidecar refresh takes a ticket

ASSUME Rollbacks \in Nat /\ Queued \in Nat
ASSUME \A b \in {Stale, Resolves, Restores, Labels, NullBase, Lossy, Sidecars,
                 ReceiveSeesTombstones, BackfillServesTombstones,
                 ConflictSeesTombstone, ResolveOnlyCovered, KeepNewerConflict,
                 LabelsRebuild, RefuseNullClock, RestoreSidecar,
                 RefreshThroughQueue} : b \in BOOLEAN

R == 1..N
Zero == [r \in R |-> 0]
Max(a, b) == IF a > b THEN a ELSE b
\* VectorClock.merge.
Join(a, b) == [r \in R |-> Max(a[r], b[r])]

\* A version: its write id, the device that wrote it, its clock (`nc`: none),
\* whether it is soft-deleted (`deletedAt`), and the ghost `hist`: the ids of
\* every version it causally follows, itself included. The properties use
\* `hist`, the code only the clock. The first version was created on a device
\* outside 1..N, by a build without clocks when NullBase.
V0 == [id |-> 0, host |-> 0, vc |-> Zero, nc |-> NullBase, del |-> FALSE,
       hist |-> {0}]

NoConf == [v |-> V0, open |-> FALSE]
NoRd == [m |-> V0, on |-> FALSE]
NoTx == [on |-> FALSE, row |-> V0, conf |-> NoConf, applied |-> FALSE]

\* VectorClock.compare(existing, incoming) as detectConflict reads it. A
\* missing clock on either side made the incoming version newer.
Leq(a, b) == \A r \in R : a.vc[r] <= b.vc[r]
Status(a, b) ==
    IF a.nc \/ b.nc
    THEN IF RefuseNullClock /\ b.nc /\ ~a.nc THEN "a_gt_b" ELSE "b_gt_a"
    ELSE IF a.vc = b.vc THEN "equal"
    ELSE IF Leq(a, b) THEN "b_gt_a"
    ELSE IF Leq(b, a) THEN "a_gt_b"
    ELSE "concurrent"

\* `b` is the same version as `a` or a newer one, by the clocks.
Covers(a, b) == Status(a, b) \in {"b_gt_a", "equal"}

VARIABLES
    row,        \* per device: the journal row
    conf,       \* per device: its conflict row, `open` while unresolved
    displaced,  \* ghost, per device: open conflicts another version replaced
    snap,      \* per device: an entry a writer read earlier
    sent,       \* every version sent (the network delivers each, any times)
    delivered,  \* per device: versions received
    lost,       \* per device: versions whose delivery was dropped
    gaps,       \* per device: lost versions that backfill has answered
    seen,       \* ghost, per device: versions received or written there
    hc,         \* per device: the last counter it issued
    nid,        \* the next version id
    side,       \* per device: the version its JSON sidecar describes
    pend,       \* per device: sidecar writes queued, <<version, ticket>>
    iss,        \* per device: the last sidecar ticket issued
    wr,         \* per device: the newest ticket written to disk
    rd,         \* per device: a path-only receive past its prepare phase
    tx,         \* per device: the receive's enclosing transaction, open
    enq,        \* per device: outbox enqueues of this entry not yet run
    rf,         \* per device: an enqueue's sidecar refresh, row read
    rbs         \* receives rolled back so far

vars == <<row, conf, displaced, snap, sent, delivered, lost, gaps, seen, hc,
          nid, side, pend, iss, wr, rd, tx, enq, rf, rbs>>
sidecarVars == <<side, pend, iss, wr, rd, tx, enq, rf, rbs>>

Init ==
    /\ row = [r \in R |-> V0]
    /\ conf = [r \in R |-> NoConf]
    /\ displaced = [r \in R |-> {}]
    /\ snap = [r \in R |-> V0]
    \* The late copy of the clockless first version.
    /\ sent = IF NullBase THEN {V0} ELSE {}
    /\ delivered = [r \in R |-> {}]
    /\ lost = [r \in R |-> {}]
    /\ gaps = [r \in R |-> {}]
    /\ seen = [r \in R |-> {}]
    /\ hc = [r \in R |-> 0]
    /\ nid = 1
    /\ side = [r \in R |-> V0]
    /\ pend = [r \in R |-> {}]
    /\ iss = [r \in R |-> 0]
    /\ wr = [r \in R |-> 0]
    /\ rd = [r \in R |-> NoRd]
    /\ tx = [r \in R |-> NoTx]
    /\ enq = [r \in R |-> 0]
    /\ rf = [r \in R |-> NoRd]
    /\ rbs = 0

(***************************************************************************)
(* JournalDb.updateJournalEntity: the stored row `P`, the conflict row     *)
(* `C`, the incoming version `w`.                                          *)
(***************************************************************************)
\* The stored row was read with `entityById`, which filters
\* `deleted = false`: a deleted row read as no row, and anything replaced
\* it. Fixed: entityByIdIncludingDeleted.
Visible(P) == ~P.del \/ ReceiveSeesTombstones

\* detectConflict stores a concurrent version as the conflict row, one per
\* entry id (insertOnConflictUpdate). Fixed: not over an open conflict that
\* already holds the same version or a newer one.
StoredOn(C, w) ==
    IF KeepNewerConflict /\ C.open /\ Covers(w, C.v)
    THEN C ELSE [v |-> w, open |-> TRUE]

\* An applied write marks the entry's conflict resolved. Fixed: only one
\* that includes the conflict's version.
SettledOn(C, w) ==
    IF C.open /\ (~ResolveOnlyCovered \/ Covers(C.v, w)) THEN NoConf ELSE C

\* VectorClock.compareCanonically(a, b) > 0.
CanonGt(a, b) ==
    \E k \in R : /\ a[k] > b[k]
                /\ \A j \in R : j < k => a[j] = b[j]

\* Two concurrent deletions leave the user nothing to choose. Each device
\* keeps the canonically greater one's fields under the join of both clocks,
\* so both compute the same row and it covers both deletions.
BothDeleted(P, w) == P.del /\ w.del
Tombstones(P, w) ==
    LET win == IF CanonGt(w.vc, P.vc) THEN w ELSE P
    IN [win EXCEPT !.vc = Join(P.vc, w.vc), !.hist = P.hist \cup w.hist]

DecideOn(P, C, w, override) ==
    IF ~Visible(P)
    THEN [row |-> w, conf |-> C, applied |-> TRUE]
    ELSE LET s == Status(P, w)
             c == IF s = "concurrent" THEN StoredOn(C, w) ELSE C
             t == Tombstones(P, w)
         IN IF s = "concurrent" /\ BothDeleted(P, w) /\ ~override
            THEN [row |-> t, conf |-> SettledOn(C, t), applied |-> t # P]
            ELSE IF s = "b_gt_a" \/ override
            THEN [row |-> w, conf |-> SettledOn(c, w), applied |-> TRUE]
            ELSE [row |-> P, conf |-> c, applied |-> FALSE]

Decide(r, w, override) == DecideOn(row[r], conf[r], w, override)

\* Device r's conflict row becomes `c`. The table holds one version per
\* entry, so a concurrent version replaces an open conflict it does not
\* follow; the ghost `displaced` keeps what it replaced.
SetConf(r, c) ==
    /\ conf' = [conf EXCEPT ![r] = c]
    /\ displaced' =
        IF conf[r].open /\ c.open /\ ~(conf[r].v.hist \subseteq c.v.hist)
        THEN [displaced EXCEPT ![r] = @ \cup {conf[r].v}]
        ELSE displaced

\* The history of a version written on device r with clock `vc`: whatever it
\* was built on, and every version the device knows whose clock `vc` covers.
\* On one device the last save supersedes an earlier one it did not read,
\* when the clocks say so; the ghost history says so too.
Covered(r, vc) ==
    UNION {x.hist : x \in {y \in seen[r] : ~y.nc /\ \A h \in R : y.vc[h] <= vc[h]}}

\* A new version written on device r over base `b`: the base's clock plus r's
\* next counter (MetadataService.updateMetadata).
NewV(r, b, del, id, n) ==
    LET vc == [b.vc EXCEPT ![r] = n]
    IN [id |-> id, host |-> r, vc |-> vc, nc |-> FALSE, del |-> del,
        hist |-> b.hist \cup Covered(r, vc) \cup {id}]

\* A sidecar ticket for version v on device r (_publishSidecar).
Ticket(r, v) ==
    /\ pend' = [pend EXCEPT ![r] = @ \cup {<<v, iss[r] + 1>>}]
    /\ iss' = [iss EXCEPT ![r] = @ + 1]

\* A local write's decision `d`, committed in its own transaction: `kept`
\* are the versions it wrote, `n` the counters it reserved, `ids` the
\* version ids it used.
LocalCommit(r, d, kept, n, ids) ==
    /\ row' = [row EXCEPT ![r] = d.row]
    /\ SetConf(r, d.conf)
    \* What is sent is the sidecar: the row as written, from this device.
    /\ sent' = IF d.applied THEN sent \cup {[d.row EXCEPT !.host = r]} ELSE sent
    /\ seen' = [seen EXCEPT ![r] = @ \cup kept]
    /\ hc' = [hc EXCEPT ![r] = @ + n]
    /\ nid' = nid + ids
    /\ IF Sidecars /\ d.applied
       THEN /\ Ticket(r, d.row)
            /\ enq' = [enq EXCEPT ![r] = @ + 1]
       ELSE UNCHANGED <<pend, iss, enq>>
    /\ UNCHANGED <<snap, delivered, lost, gaps, side, wr, rd, tx, rf, rbs>>

\* No local write commits while the receive's transaction holds the writer.
Idle(r) == ~tx[r].on

Bases(r) == IF Stale THEN {row[r], snap[r]} ELSE {row[r]}

\* An edit or a soft delete (JournalRepository.deleteJournalEntity) of an
\* entry the writer read with journalEntityById, which hides a deleted one.
Edit(r) ==
    /\ nid <= MaxWrites
    /\ Idle(r)
    /\ \E b \in Bases(r), del \in BOOLEAN :
        /\ ~b.del
        /\ LET w == NewV(r, b, del, nid, hc[r] + 1)
           IN LocalCommit(r, Decide(r, w, FALSE), {w}, 1, 1)

\* A deleted entry brought back by a writer that reads the deletion: the
\* relationship dispatcher confirming a task an undo deleted, built on the
\* tombstone's clock.
Restore(r) ==
    /\ Restores
    /\ nid <= MaxWrites
    /\ Idle(r)
    /\ row[r].del
    /\ LET w == NewV(r, row[r], FALSE, nid, hc[r] + 1)
       IN LocalCommit(r, Decide(r, w, FALSE), {w}, 1, 1)

Snapshot(r) ==
    /\ Stale
    /\ snap[r] # row[r]
    /\ snap' = [snap EXCEPT ![r] = row[r]]
    /\ UNCHANGED <<row, conf, displaced, sent, delivered, lost, gaps, seen, hc, nid>>
    /\ UNCHANGED sidecarVars

\* LabelsRepository.setLabels / suppressLabelOnTask, on an entry read
\* earlier or just now. setLabels' first attempt is an ordinary write;
\* suppressLabelOnTask's kept the clock of the entry it read, so it was
\* always refused as equal. When the first attempt was refused, setLabels
\* wrote the same version again with overrideComparison, and
\* suppressLabelOnTask wrote the stored row with the label suppressed,
\* under the row's own clock, with overrideComparison. Fixed
\* (LabelsRepository._writeOnStored): a new counter on the entry read,
\* applied only while that is still the stored row (the `precondition`,
\* checked before the write decision, so no conflict row is written);
\* otherwise built again on the stored row.
LabelWrite(r) ==
    /\ Labels
    /\ nid + 1 <= MaxWrites
    /\ Idle(r)
    /\ \E b \in Bases(r),
          suppress \in (IF LabelsRebuild THEN {FALSE} ELSE BOOLEAN) :
        /\ ~b.del
        /\ LET P == row[r]
               w == IF suppress
                    THEN [b EXCEPT !.id = nid, !.host = r,
                                   !.hist = b.hist \cup {nid}]
                    ELSE NewV(r, b, FALSE, nid, hc[r] + 1)
               d == Decide(r, w, FALSE)
               rebuilt == NewV(r, P, FALSE, nid + 1, hc[r] + 2)
               sameClock == [P EXCEPT !.id = nid + 1, !.host = r,
                                      !.hist = P.hist \cup {nid + 1}]
           IN IF LabelsRebuild
              THEN IF b = P
                   THEN LocalCommit(r, d, {w}, 1, 1)
                   ELSE /\ ~P.del
                        /\ LocalCommit(r, Decide(r, rebuilt, FALSE),
                                       {rebuilt}, 2, 2)
              ELSE IF d.applied
              THEN LocalCommit(r, d, {w}, IF suppress THEN 0 ELSE 1, 1)
              ELSE IF suppress
              THEN /\ ~P.del
                   /\ LocalCommit(r, DecideOn(P, d.conf, sameClock, TRUE),
                                  {sameClock}, 0, 2)
              ELSE LocalCommit(r, DecideOn(P, d.conf, w, TRUE), {w}, 1, 1)

\* ConflictResolutionService: keep this device, keep the other, combine, or,
\* between a deletion and an edit, keep the edit or confirm the deletion.
\* The written version carries VectorClock.merge of both sides, and
\* updateMetadata adds this device's next counter. The conflict page reads
\* the local side with journalEntityById, which hid a deleted row.
Resolve(r) ==
    /\ Resolves
    /\ nid <= MaxWrites
    /\ Idle(r)
    /\ conf[r].open
    /\ ~row[r].del \/ ConflictSeesTombstone
    /\ \E del \in {row[r].del, conf[r].v.del} :
        LET P == row[r]
            X == conf[r].v
            vc == [Join(P.vc, X.vc) EXCEPT ![r] = hc[r] + 1]
            m == [id |-> nid, host |-> r, vc |-> vc, nc |-> FALSE,
                  del |-> del,
                  hist |-> P.hist \cup X.hist \cup Covered(r, vc) \cup {nid}]
        IN LocalCommit(r, Decide(r, m, FALSE), {m}, 1, 1)

Receivable(r) == {m \in sent : m.host # r /\ m \notin lost[r]}

\* SyncEventProcessor._persistJournalEntity: an exact envelope (attachment
\* event id) is loaded without touching the sidecar and applied in one
\* transaction.
Deliver(r) ==
    /\ ~Sidecars
    /\ \E m \in Receivable(r) :
        LET d == Decide(r, m, FALSE)
        IN /\ row' = [row EXCEPT ![r] = d.row]
           /\ SetConf(r, d.conf)
           /\ delivered' = [delivered EXCEPT ![r]= @ \cup {m}]
           /\ seen' = [seen EXCEPT ![r] = @ \cup {m}]
    /\ UNCHANGED <<snap, sent, lost, gaps, hc, nid>>
    /\ UNCHANGED sidecarVars

\* A path-only envelope (an older peer): SmartJournalEntityLoader fetches the
\* descriptor and saves it over the sidecar unless the sidecar's clock is
\* newer or equal -- before the write decision.
Prepare(r) ==
    /\ Sidecars
    /\ ~rd[r].on
    /\ \E m \in Receivable(r) :
        /\ rd' = [rd EXCEPT ![r] = [m |-> m, on |-> TRUE]]
        /\ side' = IF Covers(m, side[r]) THEN side
                   ELSE [side EXCEPT ![r] = m]
    /\ UNCHANGED <<row, conf, displaced, snap, sent, delivered, lost, gaps, seen, hc, nid,
                   pend, iss, wr, tx, enq, rf, rbs>>

\* The write decision, nested in the receive's transaction with the embedded
\* links. updateJournalEntity queues the sidecar write as soon as its own,
\* nested, transaction returns -- before the receive commits.
ApplyTx(r) ==
    /\ rd[r].on
    /\ ~tx[r].on
    /\ LET m == rd[r].m
           d == Decide(r, m, FALSE)
       IN /\ row' = [row EXCEPT ![r] = d.row]
          /\ SetConf(r, d.conf)
          /\ tx' = [tx EXCEPT ![r] = [on |-> TRUE, row |-> row[r],
                                      conf |-> conf[r], applied |-> d.applied]]
          /\ IF d.applied THEN Ticket(r, d.row) ELSE UNCHANGED <<pend, iss>>
    /\ UNCHANGED <<snap, sent, delivered, lost, gaps, seen, hc, nid, side, wr,
                   rd, enq, rf, rbs>>

\* The receive commits. After the fix a refused path-only version restores
\* the sidecar from the stored row, through the same queue.
CommitTx(r) ==
    /\ tx[r].on
    /\ LET m == rd[r].m
       IN /\ delivered' = [delivered EXCEPT ![r] = @ \cup {m}]
          /\ seen' = [seen EXCEPT ![r] = @ \cup {m}]
          /\ IF ~tx[r].applied /\ RestoreSidecar THEN Ticket(r, row[r])
             ELSE UNCHANGED <<pend, iss>>
    /\ tx' = [tx EXCEPT ![r] = NoTx]
    /\ rd' = [rd EXCEPT ![r] = NoRd]
    /\ UNCHANGED <<row, conf, displaced, snap, sent, lost, gaps, hc, nid, side, wr,
                   enq, rf, rbs>>

\* A failed embedded link rolls the receive back; the event is retried.
RollbackTx(r) ==
    /\ rbs < Rollbacks
    /\ tx[r].on
    /\ rbs' = rbs + 1
    /\ row' = [row EXCEPT ![r] = tx[r].row]
    /\ conf' = [conf EXCEPT ![r] = tx[r].conf]
    /\ UNCHANGED displaced
    \* The event is not marked processed: it is delivered again.
    /\ delivered' = [delivered EXCEPT ![r] = @ \ {rd[r].m}]
    /\ tx' = [tx EXCEPT ![r] = NoTx]
    /\ rd' = [rd EXCEPT ![r] = NoRd]
    /\ UNCHANGED <<snap, sent, lost, gaps, seen, hc, nid, side, pend, iss, wr,
                   enq, rf>>

\* One queued sidecar write runs; a ticket older than the newest on disk is
\* skipped.
\* Only the order of tickets matters, so they are counted from the newest
\* one written, and every ticket at or below it -- all of them skipped --
\* is 0. That keeps the numbers small. (Once every ticket issued has run,
\* the code drops both counters and starts again at 1.)
Publish(r) ==
    /\ \E p \in pend[r] :
        LET top == IF p[2] > wr[r] THEN p[2] ELSE wr[r]
        IN /\ pend' = [pend EXCEPT
                 ![r] = {<<q[1], Max(q[2] - top, 0)>> : q \in @ \ {p}}]
           /\ side' = IF p[2] > wr[r] THEN [side EXCEPT ![r] = p[1]] ELSE side
           /\ wr' = [wr EXCEPT ![r] = 0]
           /\ iss' = [iss EXCEPT ![r] = @ - top]
    /\ UNCHANGED <<row, conf, displaced, snap, sent, delivered, lost, gaps,
                   seen, hc, nid, rd, tx, enq, rf, rbs>>

\* OutboxEnqueueWriter.enqueueJournalEntity refreshes the sidecar before it
\* reads the payload: it read the stored row with journalEntityById and
\* saved its JSON, outside the sidecar queue. Fixed: it restores the sidecar
\* through the queue (JournalDb.restoreSidecar), reading the row, tombstone
\* included, and taking a ticket in one transaction.
RefreshRead(r) ==
    /\ enq[r] > 0
    /\ ~rf[r].on
    /\ Idle(r)
    /\ enq' = [enq EXCEPT ![r] = @ - 1]
    /\ IF RefreshThroughQueue
       THEN /\ Ticket(r, row[r])
            /\ UNCHANGED rf
       ELSE /\ rf' = IF row[r].del THEN rf
                     ELSE [rf EXCEPT ![r] = [m |-> row[r], on |-> TRUE]]
            /\ UNCHANGED <<pend, iss>>
    /\ UNCHANGED <<row, conf, displaced, snap, sent, delivered, lost, gaps, seen,
                   hc, nid, side, wr, rd, tx, rbs>>

RefreshWrite(r) ==
    /\ rf[r].on
    /\ side' = [side EXCEPT ![r] = rf[r].m]
    /\ rf' = [rf EXCEPT ![r] = NoRd]
    /\ UNCHANGED <<row, conf, displaced, snap, sent, delivered, lost, gaps, seen,
                   hc, nid, pend, iss, wr, rd, tx, enq, rbs>>

Lose(r) ==
    /\ Lossy
    /\ \E m \in sent :
        /\ m.host \in R \ {r}
        /\ m \notin delivered[r] \cup lost[r] \cup gaps[r]
        /\ lost' = [lost EXCEPT ![r] = @ \cup {m}]
    /\ UNCHANGED <<row, conf, displaced, snap, sent, delivered, gaps, seen, hc, nid>>
    /\ UNCHANGED sidecarVars

\* BackfillResponseHandler: the writer answers with its current row for the
\* id if that still carries the requested counter, `unresolvable` if not, and
\* `deleted` for a row journalEntityById does not return.
Backfill(r) ==
    /\ \E m \in lost[r] :
        LET a == row[m.host]
            served == /\ ~a.del \/ BackfillServesTombstones
                      /\ a.vc[m.host] >= m.vc[m.host]
            d == Decide(r, a, FALSE)
        IN /\ lost' = [lost EXCEPT ![r] = @ \ {m}]
           /\ gaps' = [gaps EXCEPT ![r] = @ \cup {m}]
           /\ IF served
              THEN /\ row' = [row EXCEPT ![r] = d.row]
                   /\ SetConf(r, d.conf)
                   /\ delivered' = [delivered EXCEPT ![r]= @ \cup {a}]
                   /\ seen' = [seen EXCEPT ![r] = @ \cup {a}]
              ELSE UNCHANGED <<row, conf, displaced, delivered, seen>>
    /\ UNCHANGED <<snap, sent, hc, nid>>
    /\ UNCHANGED sidecarVars

Next ==
    \E r \in R :
        \/ Edit(r) \/ Restore(r) \/ Snapshot(r) \/ LabelWrite(r)
        \/ Resolve(r)
        \/ Deliver(r) \/ Prepare(r) \/ ApplyTx(r) \/ CommitTx(r)
        \/ RollbackTx(r) \/ Publish(r) \/ RefreshRead(r) \/ RefreshWrite(r)
        \/ Lose(r) \/ Backfill(r)

Spec == Init /\ [][Next]_vars

\* A state constraint for the sidecar configurations: a duplicate delivery
\* queues a sidecar write each time, and the queue is bounded.
QueueBound == \A r \in R : Cardinality(pend[r]) <= Queued

TypeOK ==
    /\ nid \in 1..(MaxWrites + 2)
    /\ \A r \in R : /\ lost[r] \subseteq sent
                    /\ row[r].id < nid

\* What a device holds, apart from which device sent it.
Content(v) == [id |-> v.id, vc |-> v.vc, del |-> v.del, hist |-> v.hist]

\* Every version has reached every other device, directly or by backfill, and
\* every receive and sidecar write has finished.
Quiescent ==
    \A r \in R :
        /\ \A m \in sent : m.host = r \/ m \in delivered[r] \cup gaps[r]
        /\ ~rd[r].on
        /\ ~tx[r].on
        /\ pend[r] = {}
        /\ enq[r] = 0
        /\ ~rf[r].on

\* Once everything is delivered, the devices hold the same entry -- or one of
\* them shows the user a conflict to resolve. Divergence is never silent.
\* (Devices that all hold a deletion agree on the entry, whichever deletion
\* each holds: two deletions are merged without the user, and one displaced
\* from the conflict table on a third device may never meet the other.)
Converged ==
    Quiescent =>
        \/ \A a, b \in R : Content(row[a]) = Content(row[b])
        \/ \A a \in R : row[a].del
        \/ \E r \in R : conf[r].open

\* `m` causally replaced `v`. (Two merged deletions keep the winner's id, so
\* versions are compared by their histories.)
Replaced(v, m) == v.hist \subseteq m.hist /\ v.hist # m.hist

\* A row is never a version that a version received or written on the same
\* device causally replaced: a deletion is not undone by a late copy.
NoLostSuccessor ==
    \A r \in R : \A m \in seen[r] : ~Replaced(row[r], m)

\* `v` keeps `m`: it follows it, or both delete the entry.
Keeps(v, m) == m.hist \subseteq v.hist \/ (m.del /\ v.del)

\* Every version a device has received or written is kept by its row or by
\* its open conflict: nothing is dropped on a device without the user
\* choosing so -- except a conflict another concurrent version displaced
\* from the one-row-per-entry conflict table (a residual).
NothingDropped ==
    \A r \in R : \A m \in seen[r] :
        \/ Keeps(row[r], m)
        \/ conf[r].open /\ Keeps(conf[r].v, m)
        \/ \E x \in displaced[r] : Keeps(x, m)

\* Not checked: the residual itself.
NoDisplacement == \A r \in R : displaced[r] = {}

\* An open conflict never holds a version its row, or a version the device
\* has already seen, replaced: a stale copy neither re-opens a resolved
\* conflict nor regresses an open one -- unless what it replaced was itself
\* displaced from the conflict table (the same residual).
ConflictNotStale ==
    \A r \in R : conf[r].open =>
        /\ ~(conf[r].v.hist \subseteq row[r].hist)
        /\ \A m \in seen[r] :
            Replaced(conf[r].v, m) => \E x \in displaced[r] : Keeps(x, m)

\* An open conflict can be opened and resolved.
ConflictResolvable ==
    \A r \in R : conf[r].open => (~row[r].del \/ ConflictSeesTombstone)

\* Once writes and receives have settled, every sidecar describes its
\* device's committed row. (A receive that rolled back is retried, so this is
\* claimed once everything is delivered.)
SidecarMatchesRow ==
    Sidecars /\ Quiescent => \A r \in R : Content(side[r]) = Content(row[r])
=============================================================================

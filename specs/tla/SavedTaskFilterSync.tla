------------------------ MODULE SavedTaskFilterSync ------------------------
(***************************************************************************)
(* Saved task filters across devices: SavedTaskFiltersRepository and its  *)
(* controller, the outbox row a local write owes the peers, the room that *)
(* carries it, and the receive rules in SyncEventProcessor's apply.       *)
(*                                                                         *)
(* Each device holds, per filter id, the stored revision (a stamp and the *)
(* content, which the code breaks ties on as canonical JSON), a tombstone *)
(* stamp, the ids whose outbox row is still owed (`pending`, the durable  *)
(* sync intent) and the controller's in-memory list (`snap`). Everything  *)
(* happens under the repository's lock, so a local write runs Begin,       *)
(* Write, Enqueue with nothing of the same device in between; a crash can *)
(* stop it after any step. `log` is every row that reached the outbox:    *)
(* the outbox retries until the room acknowledges (Outbox.tla), and a     *)
(* receiver can apply any logged row in any order, and again (Replay).     *)
(*                                                                         *)
(*   Begin          SavedTaskFiltersController create/rename/update/delete *)
(*                  and the ledger's intent write in upsert/delete         *)
(*   Write          SavedTaskFiltersPersistence.save (+ tombstone)         *)
(*   Enqueue(Fail)  OutboxService.enqueueMessageOrThrow, clearing intent   *)
(*   Flush(Fail)    SavedTaskFiltersRepository.flushPending: startup,      *)
(*                  after every write, and the retry timer                 *)
(*   Receive        _applySyncMessage -> upsert/delete(fromSync: true)     *)
(*   Refresh        the controller reloading on the change notification   *)
(*   Reorder        SavedTaskFiltersController.reorder -> saveOrder        *)
(*   Crash          process death; the controller reloads on restart      *)
(*                                                                         *)
(* The switches are the fixes; FALSE is the code before them:             *)
(*   DurableIntent   the owed row is recorded before the write and cleared*)
(*                   only by a successful enqueue; a missing ledger marks  *)
(*                   every stored filter owed (filters saved before sync)  *)
(*   StableReorder   a reorder rewrites the order of what is stored, not   *)
(*                   the controller's copy of it                           *)
(*   RefreshOnSync   the controller reloads when a synced change lands     *)
(*   TotalOrder      equal stamps are ordered by content, not accepted     *)
(*   Tombstones      a delete carries its stamp and is kept as a tombstone*)
(*   MonotonicStamps a local write stamps past the revision it replaces    *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS N, Filters, LegacyFilter, Legacy, MaxStamp,
          EditBudget, DeleteBudget, ReorderBudget, CrashBudget,
          FailBudget, DropBudget,
          DurableIntent, StableReorder, RefreshOnSync, TotalOrder,
          Tombstones, MonotonicStamps

Devices == 1..N
Stamps == 1..MaxStamp
Absent == [s |-> 0, c |-> 0]
Revs == [s : 0..MaxStamp, c : 0..N]
Present(r) == r.s > 0
Max(a, b) == IF a >= b THEN a ELSE b

(* Rows: an upsert carries the revision; a delete carries its stamp in r.s *)
Msgs == [k : {"up", "del"}, from : Devices, f : Filters, r : Revs]

VARIABLES store, tomb, pending, snap, op, log, delivered,
          used, hist, dels,
          edits, deletes, reorders, crashes, failures, drops

vars == <<store, tomb, pending, snap, op, log, delivered, used, hist, dels,
          edits, deletes, reorders, crashes, failures, drops>>

Idle == [k |-> "none", f |-> LegacyFilter, r |-> Absent, step |-> "done"]

LegacyRev == [s |-> 1, c |-> 1]

Init ==
    /\ store = [d \in Devices |-> [f \in Filters |->
            IF Legacy /\ d = 1 /\ f = LegacyFilter THEN LegacyRev ELSE Absent]]
    /\ tomb = [d \in Devices |-> [f \in Filters |-> 0]]
    \* The ledger migration: a device without a ledger owes every filter.
    /\ pending = [d \in Devices |->
            IF Legacy /\ d = 1 /\ DurableIntent THEN {LegacyFilter} ELSE {}]
    /\ snap = store
    /\ op = [d \in Devices |-> Idle]
    /\ log = {}
    /\ delivered = [d \in Devices |-> {}]
    /\ used = IF Legacy THEN {LegacyFilter} ELSE {}
    /\ hist = [f \in Filters |->
            IF Legacy /\ f = LegacyFilter THEN {LegacyRev} ELSE {}]
    /\ dels = [f \in Filters |-> {}]
    /\ edits = 0 /\ deletes = 0 /\ reorders = 0
    /\ crashes = 0 /\ failures = 0 /\ drops = 0

(* a beats b as a revision of the same filter *)
Newer(a, b) ==
    IF TotalOrder THEN a.s > b.s \/ (a.s = b.s /\ a.c > b.c)
    ELSE a.s >= b.s /\ a # b     \* only strictly older was stale

Busy(d) == op[d].k # "none"

------------------------------------------------------------------------------
(* Local writes *)

StartOp(d, k, f, r) ==
    /\ op' = [op EXCEPT ![d] = [k |-> k, f |-> f, r |-> r, step |-> "write"]]
    /\ pending' = IF DurableIntent
                  THEN [pending EXCEPT ![d] = @ \cup {f}] ELSE pending
    \* The controller shows its own write at once.
    /\ snap' = [snap EXCEPT ![d][f] = IF k = "up" THEN r ELSE Absent]

Create(d, f) ==
    /\ ~Busy(d) /\ f \notin used /\ edits < EditBudget
    /\ \E now \in Stamps : StartOp(d, "up", f, [s |-> now, c |-> d])
    /\ used' = used \cup {f}
    /\ edits' = edits + 1
    /\ UNCHANGED <<store, tomb, log, delivered, hist, dels, deletes, reorders,
                   crashes, failures, drops>>

Edit(d, f) ==
    /\ ~Busy(d) /\ Present(store[d][f]) /\ edits < EditBudget
    /\ \E now \in Stamps :
         LET s == IF MonotonicStamps THEN Max(now, store[d][f].s + 1) ELSE now
             r == [s |-> s, c |-> d]
         IN /\ s <= MaxStamp
            /\ StartOp(d, "up", f, r)
    /\ edits' = edits + 1
    /\ UNCHANGED <<store, tomb, log, delivered, used, hist, dels, deletes,
                   reorders, crashes, failures, drops>>

Delete(d, f) ==
    /\ ~Busy(d) /\ Present(store[d][f]) /\ deletes < DeleteBudget
    /\ \E now \in Stamps :
         \* A delete wins a tie, so its stamp need only reach the revision.
         LET s == IF MonotonicStamps THEN Max(now, store[d][f].s) ELSE now
         IN StartOp(d, "del", f, [s |-> s, c |-> 0])
    /\ deletes' = deletes + 1
    /\ UNCHANGED <<store, tomb, log, delivered, used, hist, dels, edits,
                   reorders,
                   crashes, failures, drops>>

Write(d) ==
    /\ op[d].step = "write"
    /\ LET f == op[d].f IN
       \* The ghosts record a write once it is on disk: one a crash stopped
       \* before this step never happened.
       IF op[d].k = "up"
       THEN /\ store' = [store EXCEPT ![d][f] = op[d].r]
            /\ hist' = [hist EXCEPT ![f] = @ \cup {op[d].r}]
            /\ UNCHANGED <<tomb, dels>>
       ELSE /\ store' = [store EXCEPT ![d][f] = Absent]
            /\ tomb' = IF Tombstones
                       THEN [tomb EXCEPT ![d][f] = Max(@, op[d].r.s)]
                       ELSE tomb
            /\ dels' = [dels EXCEPT ![f] = @ \cup {op[d].r.s}]
            /\ UNCHANGED hist
    /\ op' = [op EXCEPT ![d].step = "enqueue"]
    /\ UNCHANGED <<pending, snap, log, delivered, used, edits,
                   deletes, reorders, crashes, failures, drops>>

RowFor(d) == [k |-> op[d].k, from |-> d, f |-> op[d].f,
              r |-> IF Tombstones \/ op[d].k = "up" THEN op[d].r ELSE Absent]

Enqueue(d) ==
    /\ op[d].step = "enqueue"
    /\ log' = log \cup {RowFor(d)}
    /\ pending' = IF DurableIntent
                  THEN [pending EXCEPT ![d] = @ \ {op[d].f}] ELSE pending
    /\ op' = [op EXCEPT ![d] = Idle]
    /\ UNCHANGED <<store, tomb, snap, delivered, used, hist, dels, edits,
                   deletes, reorders, crashes, failures, drops>>

(* Before the fix enqueueMessage logged and swallowed the failure; now the *)
(* intent stays recorded for the next flush.                              *)
EnqueueFail(d) ==
    /\ op[d].step = "enqueue" /\ failures < FailBudget
    /\ op' = [op EXCEPT ![d] = Idle]
    /\ failures' = failures + 1
    /\ UNCHANGED <<store, tomb, pending, snap, log, delivered, used, hist,
                   dels, edits, deletes, reorders, crashes, drops>>

(* Re-send what is stored now for an owed id: the revision, else the      *)
(* tombstone, else nothing (the id was never written).                    *)
FlushRows(d, f) ==
    IF Present(store[d][f])
    THEN {[k |-> "up", from |-> d, f |-> f, r |-> store[d][f]]}
    ELSE IF tomb[d][f] > 0
         THEN {[k |-> "del", from |-> d, f |-> f,
                r |-> [s |-> tomb[d][f], c |-> 0]]}
         ELSE {}

Flush(d, f) ==
    /\ DurableIntent /\ ~Busy(d) /\ f \in pending[d]
    /\ log' = log \cup FlushRows(d, f)
    /\ pending' = [pending EXCEPT ![d] = @ \ {f}]
    /\ UNCHANGED <<store, tomb, snap, op, delivered, used, hist, dels, edits,
                   deletes, reorders, crashes, failures, drops>>

FlushFail(d) ==
    /\ DurableIntent /\ ~Busy(d) /\ pending[d] # {} /\ failures < FailBudget
    /\ failures' = failures + 1
    /\ UNCHANGED <<store, tomb, pending, snap, op, log, delivered, used, hist,
                   dels, edits, deletes, reorders, crashes, drops>>

------------------------------------------------------------------------------
(* Receiving *)

ApplyRow(d, m) ==
    LET f == m.f
        cur == store[d][f]
    IN IF m.k = "up"
       THEN IF (Tombstones /\ tomb[d][f] >= m.r.s)
               \/ (Present(cur) /\ ~Newer(m.r, cur))
            THEN UNCHANGED <<store, tomb>>
            ELSE /\ store' = [store EXCEPT ![d][f] = m.r]
                 /\ UNCHANGED tomb
       ELSE IF Tombstones
            THEN IF Present(cur) /\ cur.s > m.r.s
                 THEN UNCHANGED <<store, tomb>>   \* an edit after the delete
                 ELSE /\ store' = [store EXCEPT ![d][f] = Absent]
                      /\ tomb' = [tomb EXCEPT ![d][f] = Max(@, m.r.s)]
            ELSE /\ store' = [store EXCEPT ![d][f] = Absent]
                 /\ UNCHANGED tomb

Receive(d) ==
    /\ ~Busy(d)
    /\ \E m \in log :
         /\ m.from # d /\ m \notin delivered[d]
         /\ ApplyRow(d, m)
         /\ delivered' = [delivered EXCEPT ![d] = @ \cup {m}]
    /\ UNCHANGED <<pending, snap, op, log, used, hist, dels, edits, deletes,
                   reorders, crashes, failures, drops>>

(* A catch-up re-delivers a row already applied. *)
Replay(d) ==
    /\ ~Busy(d)
    /\ \E m \in delivered[d] : ApplyRow(d, m)
    /\ UNCHANGED <<pending, snap, op, log, delivered, used, hist, dels, edits,
                   deletes, reorders, crashes, failures, drops>>

(* A row the receiver cannot decode is skipped for good. A residual: no   *)
(* checked configuration grants a budget.                                 *)
Drop(d) ==
    /\ ~Busy(d) /\ drops < DropBudget
    /\ \E m \in log :
         /\ m.from # d /\ m \notin delivered[d]
         /\ delivered' = [delivered EXCEPT ![d] = @ \cup {m}]
    /\ drops' = drops + 1
    /\ UNCHANGED <<store, tomb, pending, snap, op, log, used, hist, dels,
                   edits, deletes, reorders, crashes, failures>>

------------------------------------------------------------------------------
(* The controller and the process *)

Refresh(d) ==
    /\ RefreshOnSync /\ ~Busy(d) /\ snap[d] # store[d]
    /\ snap' = [snap EXCEPT ![d] = store[d]]
    /\ UNCHANGED <<store, tomb, pending, op, log, delivered, used, hist, dels,
                   edits, deletes, reorders, crashes, failures, drops>>

(* Before the fix saveOrder persisted the controller's list as it was:    *)
(* whatever sync had written since it loaded was overwritten.             *)
Reorder(d) ==
    /\ ~Busy(d) /\ reorders < ReorderBudget
    /\ store' = IF StableReorder THEN store
                ELSE [store EXCEPT ![d] = snap[d]]
    /\ reorders' = reorders + 1
    /\ UNCHANGED <<tomb, pending, snap, op, log, delivered, used, hist, dels,
                   edits, deletes, crashes, failures, drops>>

Crash(d) ==
    /\ crashes < CrashBudget
    /\ op' = [op EXCEPT ![d] = Idle]
    /\ snap' = [snap EXCEPT ![d] = store[d]]
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<store, tomb, pending, log, delivered, used, hist, dels,
                   edits, deletes, reorders, failures, drops>>

Next ==
    \/ \E d \in Devices, f \in Filters : Create(d, f) \/ Edit(d, f)
                                          \/ Delete(d, f) \/ Flush(d, f)
    \/ \E d \in Devices :
         \/ Write(d) \/ Enqueue(d) \/ EnqueueFail(d) \/ FlushFail(d)
         \/ Receive(d) \/ Replay(d) \/ Drop(d)
         \/ Refresh(d) \/ Reorder(d) \/ Crash(d)

Spec == Init /\ [][Next]_vars
        /\ \A d \in Devices :
             /\ WF_vars(Write(d)) /\ WF_vars(Enqueue(d))
             /\ WF_vars(Receive(d)) /\ WF_vars(Refresh(d))
             /\ \A f \in Filters : WF_vars(Flush(d, f))

------------------------------------------------------------------------------
(* Properties *)

TypeOK ==
    /\ store \in [Devices -> [Filters -> Revs]]
    /\ snap \in [Devices -> [Filters -> Revs]]
    /\ tomb \in [Devices -> [Filters -> 0..MaxStamp]]
    /\ pending \in [Devices -> SUBSET Filters]
    /\ log \subseteq Msgs
    /\ delivered \in [Devices -> SUBSET Msgs]
    /\ used \subseteq Filters
    /\ edits \in 0..EditBudget /\ deletes \in 0..DeleteBudget
    /\ reorders \in 0..ReorderBudget /\ crashes \in 0..CrashBudget
    /\ failures \in 0..FailBudget /\ drops \in 0..DropBudget

(* Nothing left to do: no write in flight, nothing owed, every row applied *)
Quiescent ==
    /\ \A d \in Devices : ~Busy(d) /\ pending[d] = {}
    /\ \A d \in Devices, m \in log : m.from = d \/ m \in delivered[d]

(* The revision every device must end on: the greatest written, unless a  *)
(* delete at or past its stamp removed it.                                *)
Top(f) == CHOOSE r \in hist[f] :
            \A o \in hist[f] : o = r \/ r.s > o.s \/ (r.s = o.s /\ r.c > o.c)
Winner(f) ==
    IF hist[f] = {} THEN Absent
    ELSE IF \E s \in dels[f] : s >= Top(f).s THEN Absent ELSE Top(f)

Converged == Quiescent => \A d, e \in Devices : store[d] = store[e]

LatestWins == Quiescent => \A d \in Devices, f \in Filters :
                             store[d][f] = Winner(f)

(* A filter somebody holds and nobody deleted reaches every device. *)
EventuallyEverywhere ==
    \A f \in Filters :
      ((\E d \in Devices : Present(store[d][f])) /\ dels[f] = {})
        ~> (dels[f] # {} \/ \A d \in Devices : Present(store[d][f]))

EventuallyConverged == <>[](\A d, e \in Devices : store[d] = store[e])

(* The list on screen ends up being the list that is stored. *)
ShowsWhatIsStored == <>[](\A d \in Devices : snap[d] = store[d])
=============================================================================

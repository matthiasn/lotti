------------------------------- MODULE Outbox -------------------------------
(***************************************************************************)
(* The sync outbox of one device: local writes enqueue payloads, pending   *)
(* rows of one entity are merged, a single processor claims, sends, marks  *)
(* and retries rows, and old sent rows are pruned.                         *)
(*                                                                         *)
(* SyncSequence.tla treats the outbox as a set of counters per entity that *)
(* is sent atomically and never fails. This model opens that box: rows,    *)
(* their status, the merge's read-then-write, bundled claims, failed and   *)
(* timed-out sends, retries up to the cap, a crash between the send and    *)
(* the mark, the claim lease, pruning and the monitor's Retry and Remove.  *)
(* It reuses SyncSequence's convention that a payload announces one        *)
(* counter (`ver`) and carries the counters it superseded (`cov`).         *)
(*                                                                         *)
(* A key is one entity with an inline payload (an agent entity or link, an *)
(* entry link): the row carries the version it sends. Version v of a key   *)
(* stands for the write that took the device's counter v for that entity,  *)
(* so versions of one key are ordered like their vector clocks. A simple   *)
(* message (a backfill request, a node profile) is inserted and never      *)
(* merged.                                                                 *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   EnqRead, EnqWrite   OutboxEnqueueWriter.enqueueAgentPayload and       *)
(*                       enqueueEntryLink: findPendingByEntryId, then      *)
(*                       updateOutboxMessage (CAS on status = pending) or, *)
(*                       on a miss, addOutboxItem with the merged message; *)
(*                       a fresh row's covered clocks are enriched from    *)
(*                       the sequence log (enrichCoveredVcsFromSequenceLog)*)
(*   EnqSimple           OutboxEnqueueSimple.enqueueSimple                 *)
(*   StartDrain          MatrixOutboxService.sendNext, run one at a time   *)
(*                       by the ClientRunner                               *)
(*   Claim               SyncDatabase.claimNextOutboxBatch: pending rows   *)
(*                       and expired `sending` leases, in claim order, the *)
(*                       longest prefix up to the bundle size              *)
(*   SendOk, SendFail,   OutboxProcessor._processSingle/_processBundle     *)
(*   SendGhost           over OutboxMessageSender.send; a ghost is a send  *)
(*                       that timed out (sendTimeout) but still lands      *)
(*   MarkSent, MarkRetry DatabaseOutboxRepository.markSent(Batch) and      *)
(*                       markRetry(Batch): retries + 1, `error` at the cap *)
(*   MarkSentThrows      markSent throws; the catch runs markRetry         *)
(*   MarkThrows          markRetry throws too; the rows stay `sending`     *)
(*   LeaseExpire         SyncTuning.outboxClaimLease running out           *)
(*   Prune               SyncDatabase.pruneSentOutboxItemsChunked          *)
(*   UserRetry,          OutboxMonitorPage._requeue and _removeItem        *)
(*   UserRemove                                                            *)
(*   Crash               the process dies; the database survives           *)
(*   Teardown            OutboxService.dispose in a profile switch or a    *)
(*                       closed-generation restart; ServiceDisposer then   *)
(*                       closes SyncDatabase, so a drain dispose did not   *)
(*                       wait for can no longer mark, only land its send   *)
(*                                                                         *)
(* The switches are the fixes of ADR 0085; setting one FALSE restores the  *)
(* code before it:                                                         *)
(*                                                                         *)
(*   KeyedEnqueueLock    enqueues of one entity run one at a time          *)
(*   NewestPayloadWins   a merge keeps the newer of the two payloads       *)
(*   CoverOnlyOlder      a fresh row is enriched only with an older clock  *)
(*   ReleaseBeforeDrain  a drain first returns orphaned `sending` rows to  *)
(*                       `pending`                                         *)
(*   QuiesceOnDispose    dispose waits for the drain in flight             *)
(*                                                                         *)
(* Abstractions: claim order is row id order (priority is fixed per        *)
(* message type, and createdAt follows the id while the clock does not     *)
(* step back); media rows, which only travel alone, are left out because   *)
(* they change a bundle's size, never the order; retention and every       *)
(* timer are nondeterministic.                                             *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    Keys,               \* entities whose pending rows merge
    SimpleMsgs,         \* messages that are inserted and never merged
    MaxVersion,         \* versions enqueued per key
    MaxRetries,         \* DatabaseOutboxRepository.maxRetries
    MaxBundle,          \* SyncTuning.outboxBundleMaxSize
    MaxCrashes,         \* bound on process deaths
    FaultBudget,        \* bound on injected faults of the kinds in Faults
    Faults,             \* subset of FaultKinds this configuration tolerates
    InOrderEnqueue,     \* TRUE: one key's versions are enqueued in order
    UserActions,        \* TRUE: the monitor's Retry and Remove may run
    KeyedEnqueueLock,
    NewestPayloadWins,
    CoverOnlyOlder,
    ReleaseBeforeDrain,
    QuiesceOnDispose

FaultKinds == {
    "sendFail",     \* the sender returns false or throws
    "ghost",        \* the send times out, is retried, and lands anyway
    "markFail"      \* markSent throws; with a second fault markRetry too
}

ASSUME Faults \subseteq FaultKinds
ASSUME MaxVersion \in Nat \ {0} /\ MaxRetries \in Nat \ {0}
ASSUME MaxBundle \in Nat \ {0} /\ MaxCrashes \in Nat /\ FaultBudget \in Nat
ASSUME Keys \cap SimpleMsgs = {}
ASSUME \A b \in {InOrderEnqueue, UserActions, KeyedEnqueueLock,
                 NewestPayloadWins, CoverOnlyOlder, ReleaseBeforeDrain,
                 QuiesceOnDispose} :
          b \in BOOLEAN

Versions == 1..MaxVersion
Items == (Keys \X Versions) \cup (SimpleMsgs \X {1})
MaxRows == Cardinality(Items)
RowIds == 1..MaxRows

\* `pruned` and `removed` stand for a deleted row; ids are never reused.
Status == {"pending", "sending", "sent", "error", "pruned", "removed"}
Live == {"pending", "sending", "error"}

Msg(k, v, c) == [key |-> k, ver |-> v, cov |-> c]
Row(k, v, c) == [key |-> k, ver |-> v, cov |-> c, st |-> "pending",
                 tries |-> 0]
NoSnap == [row |-> 0, ver |-> 0, cov |-> {}]

Max(S) == CHOOSE x \in S : \A y \in S : y <= x
Min(S) == CHOOSE x \in S : \A y \in S : x <= y

RECURSIVE Sorted(_)
Sorted(S) == IF S = {} THEN <<>> ELSE <<Min(S)>> \o Sorted(S \ {Min(S)})

VARIABLES
    rows,       \* the outbox table, indexed by row id
    expired,    \* `sending` rows whose claim lease has run out
    phase,      \* the processor: off, idle, sending, delivered, failed
    batch,      \* the claimed rows, in claim order
    enq,        \* per item: idle, read (between find and write), done
    snap,       \* per item: the pending row the enqueue read, and its content
    wire,       \* the Matrix room: every message sent, in order
    ghosts,     \* timed-out sends that may still land
    abandoned,  \* items the user removed from the outbox
    faults,
    crashes

vars == <<rows, expired, phase, batch, enq, snap, wire, ghosts, abandoned,
          faults, crashes>>

CanFault(kind) == kind \in Faults /\ faults < FaultBudget

Ids == 1..Len(rows)
Carried(m) == m.cov \cup {m.ver}
AsMsg(r) == Msg(rows[r].key, rows[r].ver, rows[r].cov)

\* The versions of `k` whose enqueue wrote the outbox; the sequence log
\* records each one right after that write.
DoneVersions(k) == {v \in Versions : enq[<<k, v>>] = "done"}

\* SyncSequenceLogService.getLastSentVectorClockForEntry: the highest
\* counter recorded for the entity, or 0.
LastRecorded(k) == Max(DoneVersions(k) \cup {0})

\* findPendingByEntryId: the newest pending row of the key.
NewestPending(k) ==
    LET P == {r \in Ids : rows[r].key = k /\ rows[r].st = "pending"} IN
    IF P = {} THEN 0 ELSE Max(P)

\* The merged message for version v over a row read as (sv, sc).
Merge(sv, sc, v) ==
    LET all == sc \cup {sv, v}
        top == IF NewestPayloadWins THEN Max(all) ELSE v
    IN [ver |-> top, cov |-> all \ {top}]

\* A fresh row for version v, its covered clocks enriched from the log.
FreshCov(k, v) ==
    LET last == LastRecorded(k) IN
    IF last = 0 \/ last = v \/ (CoverOnlyOlder /\ last > v) THEN {}
    ELSE {last}

Eligible(r) ==
    \/ rows[r].st = "pending"
    \/ rows[r].st = "sending" /\ r \in expired

----------------------------------------------------------------------------
Init ==
    /\ rows = <<>>
    /\ expired = {}
    /\ phase = "off"
    /\ batch = <<>>
    /\ enq = [i \in Items |-> "idle"]
    /\ snap = [i \in Items |-> NoSnap]
    /\ wire = <<>>
    /\ ghosts = {}
    /\ abandoned = {}
    /\ faults = 0
    /\ crashes = 0

----------------------------------------------------------------------------
(* Enqueue. *)

\* A caller may start enqueueing version v of k. In order: the previous
\* version's enqueue finished first. With the lock, no other enqueue of k is
\* between its find and its write.
MayStart(k, v) ==
    /\ enq[<<k, v>>] = "idle"
    /\ InOrderEnqueue => IF v = 1 THEN TRUE ELSE enq[<<k, v - 1>>] = "done"
    /\ KeyedEnqueueLock => \A w \in Versions : enq[<<k, w>>] # "read"

\* findPendingByEntryId, and the decode of the row it returns.
EnqRead(k, v) ==
    /\ MayStart(k, v)
    /\ LET r == NewestPending(k) IN
       snap' = [snap EXCEPT ![<<k, v>>] =
                  IF r = 0 THEN NoSnap
                  ELSE [row |-> r, ver |-> rows[r].ver, cov |-> rows[r].cov]]
    /\ enq' = [enq EXCEPT ![<<k, v>>] = "read"]
    /\ UNCHANGED <<rows, expired, phase, batch, wire, ghosts, abandoned,
                   faults, crashes>>

\* updateOutboxMessage (a CAS on status = pending) or addOutboxItem.
EnqWrite(k, v) ==
    /\ enq[<<k, v>>] = "read"
    /\ LET s == snap[<<k, v>>]
           m == Merge(s.ver, s.cov, v)
       IN
       IF s.row = 0
       THEN rows' = Append(rows, Row(k, v, FreshCov(k, v)))
       ELSE IF rows[s.row].st = "pending"
       THEN rows' = [rows EXCEPT ![s.row].ver = m.ver, ![s.row].cov = m.cov]
       \* MERGE-MISS: the row was claimed in between; insert the merge.
       ELSE rows' = Append(rows, Row(k, m.ver, m.cov))
    /\ enq' = [enq EXCEPT ![<<k, v>>] = "done"]
    /\ UNCHANGED <<expired, phase, batch, snap, wire, ghosts, abandoned,
                   faults, crashes>>

EnqSimple(m) ==
    /\ enq[<<m, 1>>] = "idle"
    /\ rows' = Append(rows, Row(m, 1, {}))
    /\ enq' = [enq EXCEPT ![<<m, 1>>] = "done"]
    /\ UNCHANGED <<expired, phase, batch, snap, wire, ghosts, abandoned,
                   faults, crashes>>

----------------------------------------------------------------------------
(* The processor. One ClientRunner callback at a time. *)

\* A nudge starts a drain. With the fix, no claim of this process is in
\* flight here, so every `sending` row is an orphan and goes back to pending.
StartDrain ==
    /\ phase = "off"
    /\ \E r \in Ids : Eligible(r) \/ rows[r].st = "sending"
    /\ phase' = "idle"
    /\ IF ReleaseBeforeDrain
       THEN /\ rows' = [r \in Ids |->
                          IF rows[r].st = "sending"
                          THEN [rows[r] EXCEPT !.st = "pending"]
                          ELSE rows[r]]
            /\ expired' = {}
       ELSE UNCHANGED <<rows, expired>>
    /\ UNCHANGED <<batch, enq, snap, wire, ghosts, abandoned, faults, crashes>>

\* The longest prefix of eligible rows, up to the bundle size. An empty
\* queue ends the drain.
Claim ==
    /\ phase = "idle"
    /\ LET E == Sorted({r \in Ids : Eligible(r)})
           n == IF Len(E) < MaxBundle THEN Len(E) ELSE MaxBundle
           B == SubSeq(E, 1, n)
           S == {B[i] : i \in 1..n}
       IN
       IF n = 0
       THEN /\ phase' = "off"
            /\ UNCHANGED <<rows, expired, batch>>
       ELSE /\ rows' = [r \in Ids |->
                          IF r \in S THEN [rows[r] EXCEPT !.st = "sending"]
                          ELSE rows[r]]
            /\ expired' = expired \ S
            /\ batch' = B
            /\ phase' = "sending"
    /\ UNCHANGED <<enq, snap, wire, ghosts, abandoned, faults, crashes>>

BatchMsgs == [i \in 1..Len(batch) |-> AsMsg(batch[i])]
BatchSet == {batch[i] : i \in 1..Len(batch)}

SendOk ==
    /\ phase = "sending"
    /\ wire' = wire \o BatchMsgs
    /\ phase' = "delivered"
    /\ UNCHANGED <<rows, expired, batch, enq, snap, ghosts, abandoned, faults,
                   crashes>>

SendFail ==
    /\ phase = "sending"
    /\ "sendFail" \in Faults
    /\ phase' = "failed"
    /\ UNCHANGED <<rows, expired, batch, enq, snap, wire, ghosts, abandoned,
                   faults, crashes>>

SendGhost ==
    /\ phase = "sending"
    /\ CanFault("ghost")
    /\ ghosts' = ghosts \cup {BatchMsgs}
    /\ phase' = "failed"
    /\ faults' = faults + 1
    /\ UNCHANGED <<rows, expired, batch, enq, snap, wire, abandoned, crashes>>

GhostLand(g) ==
    /\ g \in ghosts
    /\ wire' = wire \o g
    /\ ghosts' = ghosts \ {g}
    /\ UNCHANGED <<rows, expired, phase, batch, enq, snap, abandoned, faults,
                   crashes>>

MarkSent ==
    /\ phase = "delivered"
    /\ rows' = [r \in Ids |->
                  IF r \in BatchSet THEN [rows[r] EXCEPT !.st = "sent"]
                  ELSE rows[r]]
    /\ batch' = <<>>
    /\ phase' = "idle"
    /\ UNCHANGED <<expired, enq, snap, wire, ghosts, abandoned, faults,
                   crashes>>

\* markRetry(Batch), then the backoff ends this drain.
Retried(r) ==
    [rows[r] EXCEPT !.tries = @ + 1,
                    !.st = IF rows[r].tries + 1 < MaxRetries
                           THEN "pending" ELSE "error"]

RetryBatch ==
    /\ rows' = [r \in Ids |-> IF r \in BatchSet THEN Retried(r) ELSE rows[r]]
    /\ batch' = <<>>
    /\ phase' = "off"

MarkRetry ==
    /\ phase = "failed"
    /\ RetryBatch
    /\ UNCHANGED <<expired, enq, snap, wire, ghosts, abandoned, faults,
                   crashes>>

MarkSentThrows ==
    /\ phase = "delivered"
    /\ CanFault("markFail")
    /\ RetryBatch
    /\ faults' = faults + 1
    /\ UNCHANGED <<expired, enq, snap, wire, ghosts, abandoned, crashes>>

\* The retry write throws as well: processQueue throws, sendNext backs off,
\* and the rows stay `sending` until their lease runs out.
MarkThrows ==
    /\ phase \in {"delivered", "failed"}
    /\ CanFault("markFail")
    /\ batch' = <<>>
    /\ phase' = "off"
    /\ faults' = faults + 1
    /\ UNCHANGED <<rows, expired, enq, snap, wire, ghosts, abandoned, crashes>>

\* A lease outlives the send timeout, so only an orphaned claim expires.
LeaseExpire(r) ==
    /\ rows[r].st = "sending"
    /\ r \notin BatchSet
    /\ r \notin expired
    /\ expired' = expired \cup {r}
    /\ UNCHANGED <<rows, phase, batch, enq, snap, wire, ghosts, abandoned,
                   faults, crashes>>

----------------------------------------------------------------------------
(* Pruning, the monitor, and crashes. *)

Prune(r) ==
    /\ rows[r].st = "sent"
    /\ rows' = [rows EXCEPT ![r].st = "pruned"]
    /\ UNCHANGED <<expired, phase, batch, enq, snap, wire, ghosts, abandoned,
                   faults, crashes>>

\* Retry sets retries + 1 on an error row, so one more failure is final.
UserRetry(r) ==
    /\ UserActions
    /\ rows[r].st = "error"
    /\ rows' = [rows EXCEPT ![r].st = "pending", ![r].tries = MaxRetries - 1]
    /\ UNCHANGED <<expired, phase, batch, enq, snap, wire, ghosts, abandoned,
                   faults, crashes>>

UserRemove(r) ==
    /\ UserActions
    /\ rows[r].st = "error"
    /\ rows' = [rows EXCEPT ![r].st = "removed"]
    /\ abandoned' = abandoned \cup {<<rows[r].key, v>> : v \in Carried(rows[r])}
    /\ UNCHANGED <<expired, phase, batch, enq, snap, wire, ghosts, faults,
                   crashes>>

\* In-flight enqueues die with the process; the sequence log's startup
\* settlement enqueues their payloads again (SyncSequence's ResolveOrphan).
Crash ==
    /\ crashes < MaxCrashes
    /\ phase' = "off"
    /\ batch' = <<>>
    /\ enq' = [i \in Items |-> IF enq[i] = "read" THEN "idle" ELSE enq[i]]
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<rows, expired, snap, wire, ghosts, abandoned, faults>>

\* The generation is disposed and the same profile starts again. With the
\* fix, dispose returns only once the drain in flight has finished. Without
\* it, a send still running outlives its service: its database is closed, so
\* it cannot mark, but it can still land after the next generation has
\* released its rows and sent newer ones.
Teardown ==
    /\ crashes < MaxCrashes
    /\ QuiesceOnDispose => phase \in {"off", "idle"}
    /\ ghosts' = IF phase = "sending" THEN ghosts \cup {BatchMsgs} ELSE ghosts
    /\ phase' = "off"
    /\ batch' = <<>>
    /\ enq' = [i \in Items |-> IF enq[i] = "read" THEN "idle" ELSE enq[i]]
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<rows, expired, snap, wire, abandoned, faults>>

Next ==
    \/ \E k \in Keys, v \in Versions : EnqRead(k, v) \/ EnqWrite(k, v)
    \/ \E m \in SimpleMsgs : EnqSimple(m)
    \/ StartDrain \/ Claim \/ SendOk \/ SendFail \/ SendGhost
    \/ MarkSent \/ MarkRetry \/ MarkSentThrows \/ MarkThrows
    \/ \E g \in ghosts : GhostLand(g)
    \/ \E r \in Ids : LeaseExpire(r) \/ Prune(r) \/ UserRetry(r)
                      \/ UserRemove(r)
    \/ Crash \/ Teardown

\* The implementation's own steps eventually happen: an enqueue that read
\* writes, nudges start drains, sends finish, marks land and leases run out.
\* New writes, faults, crashes, pruning and the user are never forced.
Fairness ==
    /\ \A k \in Keys, v \in Versions : WF_vars(EnqWrite(k, v))
    /\ WF_vars(StartDrain)
    /\ WF_vars(Claim)
    /\ WF_vars(SendOk \/ SendFail)
    /\ WF_vars(MarkSent)
    /\ WF_vars(MarkRetry)
    /\ \A r \in RowIds : WF_vars(r \in Ids /\ LeaseExpire(r))

Spec == Init /\ [][Next]_vars /\ Fairness

----------------------------------------------------------------------------
(* Properties. *)

TypeOK ==
    /\ Len(rows) <= MaxRows
    /\ \A r \in Ids :
          /\ rows[r].key \in Keys \cup SimpleMsgs
          /\ rows[r].ver \in Versions
          /\ rows[r].cov \subseteq Versions
          /\ rows[r].st \in Status
          /\ rows[r].tries \in 0..MaxRetries
    /\ expired \subseteq Ids
    /\ phase \in {"off", "idle", "sending", "delivered", "failed"}
    /\ enq \in [Items -> {"idle", "read", "done"}]
    /\ abandoned \subseteq Items
    /\ faults \in 0..FaultBudget
    /\ crashes \in 0..MaxCrashes

OnWire(k, v) == \E i \in 1..Len(wire) : wire[i].key = k /\ v \in Carried(wire[i])

InLiveRow(k, v) ==
    \E r \in Ids : rows[r].key = k /\ rows[r].st \in Live
                   /\ v \in Carried(rows[r])

\* Every enqueued version is on the wire, still in a live row, or was
\* removed by the user: dedup never drops the only row carrying a counter.
NoLostCounter ==
    \A <<k, v>> \in Items :
        enq[<<k, v>>] = "done" =>
            OnWire(k, v) \/ InLiveRow(k, v) \/ <<k, v>> \in abandoned

\* A row never covers a counter newer than the payload it sends: a peer
\* marks every covered counter received, so it must hold that version.
CoversOnlyOlder ==
    \A r \in Ids : \A c \in rows[r].cov : c < rows[r].ver

\* A merge never replaces a pending payload with an older one.
MergeNeverRegresses ==
    [][\A r \in Ids :
         (rows[r].st = "pending" /\ rows'[r].st = "pending")
            => rows'[r].ver >= rows[r].ver]_vars

\* A row is `sent` only after its message reached the room.
SentWasDelivered ==
    \A r \in Ids :
        rows[r].st \in {"sent", "pruned"} =>
            \E i \in 1..Len(wire) : wire[i] = AsMsg(r)

\* Pruning deletes only sent rows.
PruneOnlySent ==
    [][\A r \in Ids :
         rows'[r].st = "pruned" /\ rows[r].st # "pruned"
            => rows[r].st = "sent"]_vars

\* The last payload of a key in the room is the newest one the room holds.
\* A receiver that applies in arrival order (a config flag, an AI
\* configuration) ends on that payload. A resent bundle repeats older versions
\* before the newer ones it also carries, which is a duplicate, not a stale
\* overwrite; a lone older payload after a newer one is.
NewestLandsLast ==
    \A k \in Keys :
        LET I == {i \in 1..Len(wire) : wire[i].key = k} IN
        I # {} => wire[Max(I)].ver = Max({wire[i].ver : i \in I})

\* Every row leaves the queue: sent, failed for good, or removed.
EveryRowSettles ==
    \A r \in RowIds :
        (r \in Ids /\ rows[r].st \in {"pending", "sending"})
            ~> (r \in Ids /\ rows[r].st \in {"sent", "error", "pruned",
                                             "removed"})

\* Every enqueued version reaches the room unless its row failed for good.
EnqueuedIsDelivered ==
    \A <<k, v>> \in Items :
        (enq[<<k, v>>] = "done")
            ~> (\/ OnWire(k, v) \/ <<k, v>> \in abandoned
                \/ \E r \in Ids : rows[r].key = k /\ rows[r].st = "error"
                                  /\ v \in Carried(rows[r]))
=============================================================================

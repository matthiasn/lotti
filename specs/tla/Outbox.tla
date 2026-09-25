------------------------------- MODULE Outbox -------------------------------
(***************************************************************************)
(* The sync outbox of one device: local writes append one immutable row    *)
(* per version, and a single processor claims rows, collapses each         *)
(* entity's rows into one send of its newest version, sends, marks and     *)
(* retries, and old sent rows are pruned (ADR 0086; ADR 0085 before it).   *)
(*                                                                         *)
(* SyncSequence.tla treats the outbox as a set of counters per entity that *)
(* is sent atomically and never fails. This model opens that box: rows,    *)
(* their status, bundled claims, the dequeue-time collapse, failed and     *)
(* timed-out sends, retries up to the cap, marks that throw, a crash       *)
(* between the send and the mark, the claim lease, a teardown and restart  *)
(* of the same profile, pruning and the monitor's Retry and Remove. It     *)
(* reuses SyncSequence's convention that a payload announces one counter   *)
(* (`ver`) and carries the counters it superseded (`cov`).                 *)
(*                                                                         *)
(* A key is one entity whose rows collapse: a journal entry, an entry      *)
(* link, an agent entity or link, a config flag. Version v of a key stands *)
(* for the write that took the device's counter v for that entity, so its  *)
(* versions are ordered like their vector clocks. A version in             *)
(* MediaVersions owes the peers the entry's attachment (the row's          *)
(* `filePath`). A simple message (a backfill request, a node profile) is   *)
(* sent row by row and never collapses.                                    *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   EnqAppend, EnqSimple  OutboxEnqueueWriter: addOutboxItem, one row per *)
(*                       version, never merged                             *)
(*   StartDrain          MatrixOutboxService.sendNext (one drain at a      *)
(*                       time), which first releases orphaned claims       *)
(*   Claim               SyncDatabase.claimNextOutboxBatch: pending rows   *)
(*                       and expired leases in claim order, the longest    *)
(*                       prefix up to the bundle size, an attachment alone;*)
(*                       then OutboxProcessor._collapse: for each entity,  *)
(*                       collapsibleOutboxRows (its pending and failed     *)
(*                       rows) and claimOutboxRows, folded by              *)
(*                       outbox_collapse.dart into one message             *)
(*   SendOk, SendFail,   OutboxProcessor._processSingle/_processBundle     *)
(*   SendGhost           over OutboxMessageSender.send; a ghost is a send  *)
(*                       that timed out but still lands                    *)
(*   MarkSent, MarkRetry markSent(Batch) / markRetry(Batch) over every     *)
(*                       collapsed row                                     *)
(*   MarkSentThrows      markSent throws; the catch runs markRetry         *)
(*   MarkThrows          markRetry throws too; the rows stay `sending`     *)
(*   LeaseExpire         SyncTuning.outboxClaimLease running out           *)
(*   Prune               SyncDatabase.pruneSentOutboxItemsChunked          *)
(*   UserRetry,          OutboxMonitorPage._requeue and _removeItem        *)
(*   UserRemove                                                            *)
(*   Crash, Teardown     the process dies; the generation is disposed and  *)
(*                       the same profile restarts                         *)
(*                                                                         *)
(* The switches are the design's load-bearing choices; setting one FALSE   *)
(* restores the defect it prevents:                                        *)
(*                                                                         *)
(*   NewestByClock       the collapse sends the newest version by clock,   *)
(*                       not the row enqueued last                         *)
(*   CoverCollapsed      the send covers every collapsed row's counter     *)
(*   CarryMedia          the send carries the attachment if any collapsed  *)
(*                       row owed it                                       *)
(*   AbsorbErrorRows     a send settles the entity's failed rows too       *)
(*   ReleaseBeforeDrain  a drain first returns orphaned `sending` rows to  *)
(*                       `pending` (ADR 0085)                              *)
(*   QuiesceOnDispose    dispose waits for the drain in flight (ADR 0085)  *)
(*                                                                         *)
(* Abstractions: claim order is row id order (priority is fixed per        *)
(* message type, and createdAt follows the id while the clock does not     *)
(* step back). The claim and the collapse are one step: in between only    *)
(* appends (rows the collapse did not read), the monitor (a compare-and-   *)
(* set on status guards it) and pruning (sent rows only) can run.          *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    Keys,               \* entities whose rows collapse
    SimpleMsgs,         \* messages that are sent row by row
    MaxVersion,         \* versions enqueued per key
    MediaVersions,      \* versions whose row owes the attachment
    MaxRetries,         \* DatabaseOutboxRepository.maxRetries
    MaxBundle,          \* SyncTuning.outboxBundleMaxSize
    MaxCrashes,         \* bound on process deaths and teardowns
    FaultBudget,        \* bound on injected faults of the kinds in Faults
    Faults,             \* subset of FaultKinds this configuration tolerates
    InOrderEnqueue,     \* TRUE: one key's versions are enqueued in order
    UserActions,        \* TRUE: the monitor's Retry may run
    UserRemoves,        \* TRUE: the monitor's Remove may run too
    NewestByClock,
    CoverCollapsed,
    CarryMedia,
    AbsorbErrorRows,
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
ASSUME MediaVersions \subseteq 1..MaxVersion
ASSUME Keys \cap SimpleMsgs = {}
ASSUME \A b \in {InOrderEnqueue, UserActions, UserRemoves, NewestByClock,
                 CoverCollapsed, CarryMedia, AbsorbErrorRows,
                 ReleaseBeforeDrain, QuiesceOnDispose} :
          b \in BOOLEAN

Versions == 1..MaxVersion
Items == (Keys \X Versions) \cup (SimpleMsgs \X {1})
MaxRows == Cardinality(Items)
RowIds == 1..MaxRows

\* `pruned` and `removed` stand for a deleted row; ids are never reused.
Status == {"pending", "sending", "sent", "error", "pruned", "removed"}
Live == {"pending", "sending", "error"}

Msg(k, v, c, m) == [key |-> k, ver |-> v, cov |-> c, media |-> m]
Row(k, v, m) == [key |-> k, ver |-> v, media |-> m, st |-> "pending",
                 tries |-> 0]

Max(S) == CHOOSE x \in S : \A y \in S : y <= x
Min(S) == CHOOSE x \in S : \A y \in S : x <= y

RECURSIVE Sorted(_)
Sorted(S) == IF S = {} THEN <<>> ELSE <<Min(S)>> \o Sorted(S \ {Min(S)})

VARIABLES
    rows,       \* the outbox table, indexed by row id; rows never change
                \* but for their status and retry count
    expired,    \* `sending` rows whose claim lease has run out
    phase,      \* the processor: off, idle, sending, delivered, failed
    inflight,   \* the rows the claimed sends settle
    msgs,       \* the claimed sends, in claim order
    enq,        \* per item: idle, done
    wire,       \* the Matrix room: every message sent, in order
    ghosts,     \* timed-out sends that may still land
    abandoned,  \* items the user removed from the outbox
    faults,
    crashes

vars == <<rows, expired, phase, inflight, msgs, enq, wire, ghosts, abandoned,
          faults, crashes>>

CanFault(kind) == kind \in Faults /\ faults < FaultBudget

Ids == 1..Len(rows)
Carried(m) == m.cov \cup {m.ver}

Eligible(r) ==
    \/ rows[r].st = "pending"
    \/ rows[r].st = "sending" /\ r \in expired

----------------------------------------------------------------------------
Init ==
    /\ rows = <<>>
    /\ expired = {}
    /\ phase = "off"
    /\ inflight = {}
    /\ msgs = <<>>
    /\ enq = [i \in Items |-> "idle"]
    /\ wire = <<>>
    /\ ghosts = {}
    /\ abandoned = {}
    /\ faults = 0
    /\ crashes = 0

----------------------------------------------------------------------------
(* Enqueue: a plain append, one row per version. *)

EnqAppend(k, v) ==
    /\ enq[<<k, v>>] = "idle"
    /\ InOrderEnqueue => IF v = 1 THEN TRUE ELSE enq[<<k, v - 1>>] = "done"
    /\ rows' = Append(rows, Row(k, v, v \in MediaVersions))
    /\ enq' = [enq EXCEPT ![<<k, v>>] = "done"]
    /\ UNCHANGED <<expired, phase, inflight, msgs, wire, ghosts, abandoned,
                   faults, crashes>>

EnqSimple(m) ==
    /\ enq[<<m, 1>>] = "idle"
    /\ rows' = Append(rows, Row(m, 1, FALSE))
    /\ enq' = [enq EXCEPT ![<<m, 1>>] = "done"]
    /\ UNCHANGED <<expired, phase, inflight, msgs, wire, ghosts, abandoned,
                   faults, crashes>>

----------------------------------------------------------------------------
(* The processor. One drain at a time. *)

\* A nudge starts a drain. No claim of this process is in flight here, so
\* every `sending` row is an orphan and goes back to pending.
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
    /\ UNCHANGED <<inflight, msgs, enq, wire, ghosts, abandoned, faults,
                   crashes>>

\* The claim prefix: an attachment travels alone, and the walk stops before
\* the next one.
Prefix(E) ==
    LET n == IF Len(E) < MaxBundle THEN Len(E) ELSE MaxBundle
        P == SubSeq(E, 1, n)
        stop == {i \in 1..n : rows[P[i]].media}
    IN
    IF n = 0 THEN <<>>
    ELSE IF rows[P[1]].media THEN <<P[1]>>
    ELSE IF stop = {} THEN P
    ELSE SubSeq(P, 1, Min(stop) - 1)

\* The rows of key k a send can fold in, beside the claimed ones.
Collapsible(k, claimed) ==
    {r \in Ids \ claimed :
        /\ rows[r].key = k
        /\ \/ rows[r].st = "pending"
           \/ AbsorbErrorRows /\ rows[r].st = "error"}

\* The newest of a set of rows: by version (clock), or by enqueue order.
Newest(M) ==
    IF NewestByClock
    THEN CHOOSE r \in M : \A s \in M : rows[s].ver <= rows[r].ver
    ELSE Max(M)

\* The message a collapsed send carries.
Folded(M) ==
    LET n == Newest(M) IN
    Msg(rows[n].key, rows[n].ver,
        IF CoverCollapsed THEN {rows[r].ver : r \in M} \ {rows[n].ver} ELSE {},
        IF CarryMedia THEN \E r \in M : rows[r].media ELSE rows[n].media)

\* Claim the prefix and collapse each entity's rows. A bundle ships JSON
\* only, so it does not fold in the rows that owe an attachment; they go
\* out alone later.
Claim ==
    /\ phase = "idle"
    /\ LET B == Prefix(Sorted({r \in Ids : Eligible(r)}))
           BS == {B[i] : i \in 1..Len(B)}
           keys == {rows[r].key : r \in BS}
           Extra(k) ==
               IF k \in SimpleMsgs THEN {}
               ELSE {r \in Collapsible(k, BS) :
                        Len(B) = 1 \/ ~rows[r].media}
           Group(k) == {r \in BS : rows[r].key = k} \cup Extra(k)
           \* One send per key, in the order of each key's first claimed row.
           Heads == Sorted({Min({r \in BS : rows[r].key = k}) : k \in keys})
           All == UNION {Group(k) : k \in keys}
       IN
       IF Len(B) = 0
       THEN /\ phase' = "off"
            /\ UNCHANGED <<rows, expired, inflight, msgs>>
       ELSE /\ rows' = [r \in Ids |->
                          IF r \in All THEN [rows[r] EXCEPT !.st = "sending"]
                          ELSE rows[r]]
            /\ expired' = expired \ All
            /\ inflight' = All
            /\ msgs' = [i \in 1..Len(Heads) |->
                          Folded(Group(rows[Heads[i]].key))]
            /\ phase' = "sending"
    /\ UNCHANGED <<enq, wire, ghosts, abandoned, faults, crashes>>

SendOk ==
    /\ phase = "sending"
    /\ wire' = wire \o msgs
    /\ phase' = "delivered"
    /\ UNCHANGED <<rows, expired, inflight, msgs, enq, ghosts, abandoned,
                   faults, crashes>>

SendFail ==
    /\ phase = "sending"
    /\ "sendFail" \in Faults
    /\ phase' = "failed"
    /\ UNCHANGED <<rows, expired, inflight, msgs, enq, wire, ghosts,
                   abandoned, faults, crashes>>

SendGhost ==
    /\ phase = "sending"
    /\ CanFault("ghost")
    /\ ghosts' = ghosts \cup {msgs}
    /\ phase' = "failed"
    /\ faults' = faults + 1
    /\ UNCHANGED <<rows, expired, inflight, msgs, enq, wire, abandoned,
                   crashes>>

GhostLand(g) ==
    /\ g \in ghosts
    /\ wire' = wire \o g
    /\ ghosts' = ghosts \ {g}
    /\ UNCHANGED <<rows, expired, phase, inflight, msgs, enq, abandoned,
                   faults, crashes>>

MarkSent ==
    /\ phase = "delivered"
    /\ rows' = [r \in Ids |->
                  IF r \in inflight THEN [rows[r] EXCEPT !.st = "sent"]
                  ELSE rows[r]]
    /\ inflight' = {}
    /\ msgs' = <<>>
    /\ phase' = "idle"
    /\ UNCHANGED <<expired, enq, wire, ghosts, abandoned, faults, crashes>>

\* markRetry(Batch), then the backoff ends this drain. The count stops at
\* the cap, which is all the model needs of it (an absorbed failed row that
\* fails again stays failed).
Retried(r) ==
    [rows[r] EXCEPT !.tries = IF @ < MaxRetries THEN @ + 1 ELSE @,
                    !.st = IF rows[r].tries + 1 < MaxRetries
                           THEN "pending" ELSE "error"]

RetryBatch ==
    /\ rows' = [r \in Ids |-> IF r \in inflight THEN Retried(r) ELSE rows[r]]
    /\ inflight' = {}
    /\ msgs' = <<>>
    /\ phase' = "off"

MarkRetry ==
    /\ phase = "failed"
    /\ RetryBatch
    /\ UNCHANGED <<expired, enq, wire, ghosts, abandoned, faults, crashes>>

MarkSentThrows ==
    /\ phase = "delivered"
    /\ CanFault("markFail")
    /\ RetryBatch
    /\ faults' = faults + 1
    /\ UNCHANGED <<expired, enq, wire, ghosts, abandoned, crashes>>

\* The retry write throws as well: processQueue throws, sendNext backs off,
\* and the rows stay `sending`.
MarkThrows ==
    /\ phase \in {"delivered", "failed"}
    /\ CanFault("markFail")
    /\ inflight' = {}
    /\ msgs' = <<>>
    /\ phase' = "off"
    /\ faults' = faults + 1
    /\ UNCHANGED <<rows, expired, enq, wire, ghosts, abandoned, crashes>>

\* A lease outlives the send timeout, so only an orphaned claim expires.
LeaseExpire(r) ==
    /\ rows[r].st = "sending"
    /\ r \notin inflight
    /\ r \notin expired
    /\ expired' = expired \cup {r}
    /\ UNCHANGED <<rows, phase, inflight, msgs, enq, wire, ghosts, abandoned,
                   faults, crashes>>

----------------------------------------------------------------------------
(* Pruning, the monitor, crashes and teardowns. *)

Prune(r) ==
    /\ rows[r].st = "sent"
    /\ rows' = [rows EXCEPT ![r].st = "pruned"]
    /\ UNCHANGED <<expired, phase, inflight, msgs, enq, wire, ghosts,
                   abandoned, faults, crashes>>

\* Retry sets retries + 1 on an error row, so one more failure is final.
UserRetry(r) ==
    /\ UserActions
    /\ rows[r].st = "error"
    /\ rows' = [rows EXCEPT ![r].st = "pending", ![r].tries = MaxRetries - 1]
    /\ UNCHANGED <<expired, phase, inflight, msgs, enq, wire, ghosts,
                   abandoned, faults, crashes>>

UserRemove(r) ==
    /\ UserRemoves
    /\ rows[r].st = "error"
    /\ rows' = [rows EXCEPT ![r].st = "removed"]
    /\ abandoned' = abandoned \cup {<<rows[r].key, rows[r].ver>>}
    /\ UNCHANGED <<expired, phase, inflight, msgs, enq, wire, ghosts, faults,
                   crashes>>

\* The process dies; the database survives. Appends are single inserts, so
\* no enqueue is left half done.
Crash ==
    /\ crashes < MaxCrashes
    /\ phase' = "off"
    /\ inflight' = {}
    /\ msgs' = <<>>
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<rows, expired, enq, wire, ghosts, abandoned, faults>>

\* The generation is disposed and the same profile starts again. Dispose
\* waits for the drain in flight; without that, a send still running
\* outlives its service and can land after the next generation's sends.
Teardown ==
    /\ crashes < MaxCrashes
    /\ QuiesceOnDispose => phase \in {"off", "idle"}
    /\ ghosts' = IF phase = "sending" THEN ghosts \cup {msgs} ELSE ghosts
    /\ phase' = "off"
    /\ inflight' = {}
    /\ msgs' = <<>>
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<rows, expired, enq, wire, abandoned, faults>>

Next ==
    \/ \E k \in Keys, v \in Versions : EnqAppend(k, v)
    \/ \E m \in SimpleMsgs : EnqSimple(m)
    \/ StartDrain \/ Claim \/ SendOk \/ SendFail \/ SendGhost
    \/ MarkSent \/ MarkRetry \/ MarkSentThrows \/ MarkThrows
    \/ \E g \in ghosts : GhostLand(g)
    \/ \E r \in Ids : LeaseExpire(r) \/ Prune(r) \/ UserRetry(r)
                      \/ UserRemove(r)
    \/ Crash \/ Teardown

\* The implementation's own steps eventually happen: nudges start drains,
\* sends finish, marks land and leases run out. New writes, faults, crashes,
\* pruning and the user are never forced.
Fairness ==
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
          /\ rows[r].media \in BOOLEAN
          /\ rows[r].st \in Status
          /\ rows[r].tries \in 0..MaxRetries
    /\ expired \subseteq Ids
    /\ inflight \subseteq Ids
    /\ phase \in {"off", "idle", "sending", "delivered", "failed"}
    /\ enq \in [Items -> {"idle", "done"}]
    /\ abandoned \subseteq Items
    /\ faults \in 0..FaultBudget
    /\ crashes \in 0..MaxCrashes

OnWire(k, v) == \E i \in 1..Len(wire) : wire[i].key = k /\ v \in Carried(wire[i])

InLiveRow(k, v) ==
    \E r \in Ids : rows[r].key = k /\ rows[r].ver = v /\ rows[r].st \in Live

\* Every enqueued version is on the wire, still in a live row, or was
\* removed by the user: nothing drops the only row carrying a counter.
NoLostCounter ==
    \A <<k, v>> \in Items :
        enq[<<k, v>>] = "done" =>
            OnWire(k, v) \/ InLiveRow(k, v) \/ <<k, v>> \in abandoned

\* A send never covers a counter newer than the payload it carries: a peer
\* marks every covered counter received, so it must hold that version.
CoversOnlyOlder ==
    \A i \in 1..Len(wire) : \A c \in wire[i].cov : c < wire[i].ver

\* A row, once appended, keeps its payload: enqueue never rewrites a row.
RowsImmutable ==
    [][\A r \in Ids :
         /\ rows'[r].key = rows[r].key
         /\ rows'[r].ver = rows[r].ver
         /\ rows'[r].media = rows[r].media]_vars

\* A row is `sent` only after its counter reached the room.
SentWasDelivered ==
    \A r \in Ids :
        rows[r].st \in {"sent", "pruned"} => OnWire(rows[r].key, rows[r].ver)

\* A row that owed the attachment is `sent` only after a send of its entity
\* carried the attachment.
MediaNotDropped ==
    \A r \in Ids :
        (rows[r].media /\ rows[r].st \in {"sent", "pruned"}) =>
            \E i \in 1..Len(wire) : wire[i].key = rows[r].key /\ wire[i].media

\* Pruning deletes only sent rows.
PruneOnlySent ==
    [][\A r \in Ids :
         rows'[r].st = "pruned" /\ rows[r].st # "pruned"
            => rows[r].st = "sent"]_vars

\* The last payload of a key in the room is the newest one the room holds.
\* A receiver that applies in arrival order (a config flag, an AI
\* configuration) ends on that payload.
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
                \/ \E r \in Ids : rows[r].key = k /\ rows[r].ver = v
                                  /\ rows[r].st = "error")
=============================================================================

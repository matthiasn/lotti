------------------------- MODULE ChangeSetLifecycle -------------------------
(***************************************************************************)
(* A whole change set across its lifetime and across devices.             *)
(* ChangeSetConfirm.tla checks one item on one device; this spec checks    *)
(* what happens between the items of a set, and between the replicas of   *)
(* it: every writer of the set, the sync that carries each write to the    *)
(* other devices, and the resolver that settles concurrent versions.       *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code                   *)
(* (lib/features/agents/...):                                              *)
(*                                                                         *)
(*   Confirm       service/change_set_confirmation_service.dart            *)
(*                 _confirmItem: the claim (claimChangeSetItem, one        *)
(*                 transaction), after the placeholder check of            *)
(*                 _resolveArgsIfNeeded for a migration item               *)
(*   DispatchOk    the tool took effect; for create_follow_up_task the     *)
(*                 in-memory placeholder mapping (captureResolvedId)       *)
(*   DispatchFails the tool failed: revert to pending, or retract when     *)
(*                 the failure is non-retryable (transitionChangeSetItem)  *)
(*   PersistSib    service/change_set_resolution_store.dart                *)
(*                 persistResolvedIdToSiblings: the migration's            *)
(*                 targetTaskId rewritten to the created task              *)
(*   Reject        rejectItem: the claim to `rejected`                     *)
(*   Cascade       cascadeRejectMigrationItems after a rejected follow-up  *)
(*   Retract       service/suggestion_retraction_service.dart applyStaged, *)
(*                 inside the wake's transaction                           *)
(*   Consolidate   workflow/change_set_builder.dart build: the final       *)
(*                 flush folds an older set into the survivor and retires  *)
(*                 it (workflow/change_item_dedup.dart                     *)
(*                 retireConsolidatedSet), inside the wake's transaction   *)
(*   Receive       lib/features/sync/matrix/                               *)
(*                 sync_event_processor_agent_handlers.dart: vector-clock  *)
(*                 comparison, then sync/agent_concurrent_resolver.dart    *)
(*                 for concurrent versions                                 *)
(*                                                                         *)
(* A change set syncs as one row. Every local write stamps the row with    *)
(* the next counter of its device on top of the clock it read, and sends   *)
(* it to every other device; sync applies a received row directly,         *)
(* without a new stamp or a send.                                          *)
(*                                                                         *)
(* The four switches are the fixes of ADR 0067, and each is a mutation     *)
(* point: set one to FALSE to check the design without it.                 *)
(*                                                                         *)
(*   AtomicWrites       every local write of a set re-reads it in the same *)
(*                      transaction and changes only what it owns;         *)
(*                      without it, the revert, the sibling rewrite and    *)
(*                      the cascade write back a snapshot read earlier     *)
(*   AtomicReceive      sync compares and writes a received set in one     *)
(*                      transaction over a fresh read                      *)
(*   ItemMerge          concurrent versions merge item by item, by a       *)
(*                      per-item revision; without it, one whole version   *)
(*                      wins and the other's decisions are lost            *)
(*   PendingCopiesOnly  consolidation moves only pending items into the    *)
(*                      survivor; without it, a decided item is copied     *)
(*                      with its status                                    *)
(*                                                                         *)
(* `applied` is a ghost: how often each change took effect, per device.    *)
(* A consolidated copy and its original propose the same change, so they   *)
(* share one effect.                                                       *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, TLC

CONSTANTS
    Devices,       \* replicas, as 1..N; the numeric order is the host order
    Items,         \* change items, model values
    FollowUp,      \* the create_follow_up_task item, or NoItem
    Migration,     \* the migrate_checklist_item targeting it, or NoItem
    CopySrc,       \* an item of an older set that a wake consolidates
    CopyDst,       \* its slot in the surviving set, or NoItem
    NoItem,
    Faults,        \* subset of {"dispatchFails", "nonRetryable"}
    MaxAttempts,   \* user decisions per device and item
    MaxAgentOps,   \* retractions and consolidations per device
    RaceFree,      \* no item is decided on two devices before they synced
    AtomicWrites, AtomicReceive, ItemMerge, PendingCopiesOnly

ASSUME
    /\ Faults \subseteq {"dispatchFails", "nonRetryable"}
    /\ {RaceFree, AtomicWrites, AtomicReceive, ItemMerge, PendingCopiesOnly}
           \subseteq BOOLEAN

\* The older set is row 2, the surviving set row 1.
Rows == IF CopyDst # NoItem THEN {1, 2} ELSE {1}
RowOf(i) == IF CopyDst # NoItem /\ i = CopySrc THEN 2 ELSE 1
ItemsIn(r) == {i \in Items : RowOf(i) = r}

\* A copy applies the same change as its original.
Effect(i) == IF i = CopyDst THEN CopySrc ELSE i
Effects == {Effect(i) : i \in Items}
ItemsOf(x) == {i \in Items : Effect(i) = x}

Status == {"absent", "pending", "confirmed", "rejected", "retracted"}
Decided == {"confirmed", "rejected", "retracted"}

\* Among two versions of an item at the same revision, the more final
\* status wins: a confirmed change took effect, and the rest never did.
Rank(s) == CASE s = "absent" -> 0 [] s = "pending" -> 1
             [] s = "retracted" -> 2 [] s = "rejected" -> 3
             [] s = "confirmed" -> 4

Pc == {"idle", "claimed", "failP", "failPW", "failR", "failRW",
       "sib", "sibW", "cascade", "cascadeW"}

InitItem(i) == [st |-> IF i = CopyDst THEN "absent" ELSE "pending",
                rev |-> 0,
                res |-> i # Migration]  \* targetTaskId resolved
InitRow(r) == [items |-> [i \in ItemsIn(r) |-> InitItem(i)],
               vc |-> [e \in Devices |-> 0]]

VARIABLES
    rows,      \* rows[d][r]: device d's replica of set r
    hc,        \* hc[d]: the last counter device d stamped
    msgs,      \* sync messages in flight
    pc,        \* pc[d][i]: progress of device d's operation on item i
    snap,      \* snap[d][i]: {} or {the row an unatomic write read}
    recv,      \* recv[d]: {} or {[m, local]} mid-way through a receive
    mem,       \* mem[d]: device d's in-memory placeholder mapping
    attempts,  \* attempts[d][i]: user decisions started
    agentOps,  \* agentOps[d]: retractions and consolidations run
    applied,   \* ghost: applied[x][d], effects taken by device d
    early      \* ghost: a migration took effect before its target task

vars == <<rows, hc, msgs, pc, snap, recv, mem, attempts, agentOps,
          applied, early>>

Init ==
    /\ rows = [d \in Devices |-> [r \in Rows |-> InitRow(r)]]
    /\ hc = [d \in Devices |-> 0]
    /\ msgs = {}
    /\ pc = [d \in Devices |-> [i \in Items |-> "idle"]]
    /\ snap = [d \in Devices |-> [i \in Items |-> {}]]
    /\ recv = [d \in Devices |-> {}]
    /\ mem = [d \in Devices |-> FALSE]
    /\ attempts = [d \in Devices |-> [i \in Items |-> 0]]
    /\ agentOps = [d \in Devices |-> 0]
    /\ applied = [x \in Effects |-> [d \in Devices |-> 0]]
    /\ early = FALSE

-----------------------------------------------------------------------------
(* Writes and sync *)

Item(d, i) == rows[d][RowOf(i)].items[i]

\* A status change. Revisions exist only with ItemMerge: the as-is item
\* carries none.
Bump(rec, st) == [rec EXCEPT !.st = st,
                             !.rev = IF ItemMerge THEN @ + 1 ELSE @]

\* The items whose status a write changes, compared with the replica it
\* lands on — what RaceFree keeps other devices from deciding meanwhile.
Touched(old, new) == {i \in DOMAIN new : old[i].st # new[i].st}

\* Device d writes set r: `items` on top of the clock `base` it read.
\* W maps each written row to [items, base]. Every row gets the next
\* counter of d and goes to every other device.
Stamp(d, W, r) ==
    [items |-> W[r].items,
     vc |-> [W[r].base EXCEPT ![d] = hc[d] + Cardinality({q \in DOMAIN W : q <= r})]]

Put(d, W) ==
    /\ rows' = [rows EXCEPT ![d] =
                  [r \in Rows |-> IF r \in DOMAIN W THEN Stamp(d, W, r)
                                  ELSE rows[d][r]]]
    /\ hc' = [hc EXCEPT ![d] = @ + Cardinality(DOMAIN W)]
    /\ msgs' = msgs \cup
         {[to |-> e, row |-> r, v |-> Stamp(d, W, r),
           touched |-> Touched(rows[d][r].items, W[r].items)] :
              e \in Devices \ {d}, r \in DOMAIN W}

\* One row, written with the item i changed.
PutItem(d, i, rec, base) ==
    LET r == RowOf(i) IN
    Put(d, r :> [items |-> [base.items EXCEPT ![i] = rec], base |-> base.vc])

Leq(a, b) == \A e \in Devices : a[e] <= b[e]
Join(a, b) == [e \in Devices |-> IF a[e] >= b[e] THEN a[e] ELSE b[e]]

\* compareClocksCanonically: the first host, in host order, whose counters
\* differ decides.
CanonGreater(a, b) ==
    LET diff == {e \in Devices : a[e] # b[e]} IN
    /\ diff # {}
    /\ LET e0 == CHOOSE e \in diff : \A f \in diff : e <= f IN a[e0] > b[e0]

MergeItem(a, b, bWins) ==
    IF a.rev # b.rev THEN (IF a.rev > b.rev THEN a ELSE b)
    ELSE IF Rank(a.st) # Rank(b.st) THEN (IF Rank(a.st) > Rank(b.st) THEN a ELSE b)
    ELSE IF bWins THEN b ELSE a

\* The version a receiving device keeps.
Resolve(local, incoming) ==
    IF Leq(incoming.vc, local.vc) THEN local
    ELSE IF Leq(local.vc, incoming.vc) THEN incoming
    ELSE LET inWins == CanonGreater(incoming.vc, local.vc) IN
         IF ItemMerge
         THEN [items |-> [i \in DOMAIN local.items |->
                             MergeItem(local.items[i], incoming.items[i], inWins)],
               vc |-> Join(local.vc, incoming.vc)]
         ELSE IF inWins THEN incoming ELSE local

\* Nothing about item i from another device is on its way to d, and no
\* other device is mid-way through an operation on the same change.
RaceGuard(d, i) ==
    \/ ~RaceFree
    \/ /\ \A e \in Devices \ {d}, j \in ItemsOf(Effect(i)) : pc[e][j] = "idle"
       /\ ~\E m \in msgs : m.to = d /\ \E j \in m.touched : Effect(j) = Effect(i)
       /\ \A rc \in recv[d] : ~\E j \in rc.m.touched : Effect(j) = Effect(i)

-----------------------------------------------------------------------------
(* Confirming and rejecting *)

\* The claim: pending -> confirmed in one transaction. A migration whose
\* target task is still a placeholder, and not in this device's memory,
\* is refused before the claim.
Confirm(d, i) ==
    /\ pc[d][i] = "idle"
    /\ attempts[d][i] < MaxAttempts
    /\ Item(d, i).st = "pending"
    /\ i = Migration => (Item(d, i).res \/ mem[d])
    /\ RaceGuard(d, i)
    /\ PutItem(d, i, Bump(Item(d, i), "confirmed"), rows[d][RowOf(i)])
    /\ pc' = [pc EXCEPT ![d][i] = "claimed"]
    /\ attempts' = [attempts EXCEPT ![d][i] = @ + 1]
    /\ UNCHANGED <<snap, recv, mem, agentOps, applied, early>>

DispatchOk(d, i) ==
    /\ pc[d][i] = "claimed"
    /\ applied' = [applied EXCEPT ![Effect(i)][d] = @ + 1]
    /\ early' = (early \/ (i = Migration /\
                   \A e \in Devices : applied[FollowUp][e] = 0))
    /\ mem' = IF i = FollowUp THEN [mem EXCEPT ![d] = TRUE] ELSE mem
    /\ pc' = [pc EXCEPT ![d][i] =
                IF i = FollowUp /\ Migration # NoItem THEN "sib" ELSE "idle"]
    /\ UNCHANGED <<rows, hc, msgs, snap, recv, attempts, agentOps>>

\* A retryable failure reverts to pending; a non-retryable one retracts.
DispatchFails(d, i) ==
    /\ pc[d][i] = "claimed"
    /\ \/ "dispatchFails" \in Faults /\ pc' = [pc EXCEPT ![d][i] = "failP"]
       \/ "nonRetryable" \in Faults /\ pc' = [pc EXCEPT ![d][i] = "failR"]
    /\ UNCHANGED <<rows, hc, msgs, snap, recv, mem, attempts, agentOps,
                   applied, early>>

\* The targetTaskId rewrite is a change of the item too.
Resolved(rec) == [rec EXCEPT !.res = TRUE,
                             !.rev = IF ItemMerge THEN @ + 1 ELSE @]

FailTarget(p) == IF p \in {"failP", "failPW"} THEN "pending" ELSE "retracted"

\* Fixed: one transaction moves the item from confirmed, and only the item.
FailAtomic(d, i) ==
    /\ AtomicWrites
    /\ pc[d][i] \in {"failP", "failR"}
    /\ IF Item(d, i).st = "confirmed"
       THEN PutItem(d, i, Bump(Item(d, i), FailTarget(pc[d][i])),
                    rows[d][RowOf(i)])
       ELSE UNCHANGED <<rows, hc, msgs>>
    /\ pc' = [pc EXCEPT ![d][i] = "idle"]
    /\ UNCHANGED <<snap, recv, mem, attempts, agentOps, applied, early>>

\* As is: updateChangeSetItemStatus reads the set, awaits, and writes the
\* whole set back with the item changed.
FailRead(d, i) ==
    /\ ~AtomicWrites
    /\ pc[d][i] \in {"failP", "failR"}
    /\ snap' = [snap EXCEPT ![d][i] = {rows[d][RowOf(i)]}]
    /\ pc' = [pc EXCEPT ![d][i] = IF @ = "failP" THEN "failPW" ELSE "failRW"]
    /\ UNCHANGED <<rows, hc, msgs, recv, mem, attempts, agentOps, applied,
                   early>>

FailWrite(d, i) ==
    /\ pc[d][i] \in {"failPW", "failRW"}
    /\ \E s \in snap[d][i] :
          PutItem(d, i, Bump(s.items[i], FailTarget(pc[d][i])), s)
    /\ snap' = [snap EXCEPT ![d][i] = {}]
    /\ pc' = [pc EXCEPT ![d][i] = "idle"]
    /\ UNCHANGED <<recv, mem, attempts, agentOps, applied, early>>

\* After the follow-up task exists, its migration's targetTaskId is
\* rewritten to the real task id.
SibAtomic(d) ==
    /\ AtomicWrites
    /\ pc[d][FollowUp] = "sib"
    /\ IF ~Item(d, Migration).res
       THEN PutItem(d, Migration, Resolved(Item(d, Migration)),
                    rows[d][RowOf(Migration)])
       ELSE UNCHANGED <<rows, hc, msgs>>
    /\ pc' = [pc EXCEPT ![d][FollowUp] = "idle"]
    /\ UNCHANGED <<snap, recv, mem, attempts, agentOps, applied, early>>

SibRead(d) ==
    /\ ~AtomicWrites
    /\ pc[d][FollowUp] = "sib"
    /\ snap' = [snap EXCEPT ![d][FollowUp] = {rows[d][RowOf(Migration)]}]
    /\ pc' = [pc EXCEPT ![d][FollowUp] = "sibW"]
    /\ UNCHANGED <<rows, hc, msgs, recv, mem, attempts, agentOps, applied,
                   early>>

SibWrite(d) ==
    /\ pc[d][FollowUp] = "sibW"
    /\ \E s \in snap[d][FollowUp] :
          IF ~s.items[Migration].res
          THEN PutItem(d, Migration, Resolved(s.items[Migration]), s)
          ELSE UNCHANGED <<rows, hc, msgs>>
    /\ snap' = [snap EXCEPT ![d][FollowUp] = {}]
    /\ pc' = [pc EXCEPT ![d][FollowUp] = "idle"]
    /\ UNCHANGED <<recv, mem, attempts, agentOps, applied, early>>

\* The claim: pending -> rejected in one transaction.
Reject(d, i) ==
    /\ pc[d][i] = "idle"
    /\ attempts[d][i] < MaxAttempts
    /\ Item(d, i).st = "pending"
    /\ RaceGuard(d, i)
    /\ PutItem(d, i, Bump(Item(d, i), "rejected"), rows[d][RowOf(i)])
    /\ pc' = [pc EXCEPT ![d][i] =
                IF i = FollowUp /\ Migration # NoItem THEN "cascade" ELSE "idle"]
    /\ attempts' = [attempts EXCEPT ![d][i] = @ + 1]
    /\ UNCHANGED <<snap, recv, mem, agentOps, applied, early>>

\* A rejected follow-up rejects its pending migration.
CascadeAtomic(d) ==
    /\ AtomicWrites
    /\ pc[d][FollowUp] = "cascade"
    /\ IF Item(d, Migration).st = "pending"
       THEN PutItem(d, Migration, Bump(Item(d, Migration), "rejected"),
                    rows[d][RowOf(Migration)])
       ELSE UNCHANGED <<rows, hc, msgs>>
    /\ pc' = [pc EXCEPT ![d][FollowUp] = "idle"]
    /\ UNCHANGED <<snap, recv, mem, attempts, agentOps, applied, early>>

CascadeRead(d) ==
    /\ ~AtomicWrites
    /\ pc[d][FollowUp] = "cascade"
    /\ IF Item(d, Migration).st = "pending"
       THEN /\ snap' = [snap EXCEPT ![d][FollowUp] = {rows[d][RowOf(Migration)]}]
            /\ pc' = [pc EXCEPT ![d][FollowUp] = "cascadeW"]
       ELSE /\ pc' = [pc EXCEPT ![d][FollowUp] = "idle"]
            /\ UNCHANGED snap
    /\ UNCHANGED <<rows, hc, msgs, recv, mem, attempts, agentOps, applied,
                   early>>

CascadeWrite(d) ==
    /\ pc[d][FollowUp] = "cascadeW"
    /\ \E s \in snap[d][FollowUp] :
          PutItem(d, Migration, Bump(s.items[Migration], "rejected"), s)
    /\ snap' = [snap EXCEPT ![d][FollowUp] = {}]
    /\ pc' = [pc EXCEPT ![d][FollowUp] = "idle"]
    /\ UNCHANGED <<recv, mem, attempts, agentOps, applied, early>>

-----------------------------------------------------------------------------
(* The agent *)

\* A staged retraction, applied at the end of a wake inside its
\* transaction: only a still-pending item is retracted.
Retract(d, i) ==
    /\ agentOps[d] < MaxAgentOps
    /\ Item(d, i).st = "pending"
    /\ PutItem(d, i, Bump(Item(d, i), "retracted"), rows[d][RowOf(i)])
    /\ agentOps' = [agentOps EXCEPT ![d] = @ + 1]
    /\ UNCHANGED <<pc, snap, recv, mem, attempts, applied, early>>

\* The final build of a wake folds the older set (row 2) into the
\* survivor (row 1) and retires it: a pending original is retracted,
\* because its actionable copy now lives in the survivor.
Consolidate(d) ==
    /\ CopyDst # NoItem
    /\ agentOps[d] < MaxAgentOps
    /\ Item(d, CopyDst).st = "absent"
    /\ LET src == Item(d, CopySrc)
           copy == ~PendingCopiesOnly \/ src.st = "pending"
           dst == [st |-> src.st, rev |-> IF ItemMerge THEN 1 ELSE 0,
                   res |-> TRUE]
           survivor == [items |-> [rows[d][1].items EXCEPT ![CopyDst] = dst],
                        base |-> rows[d][1].vc]
           retired == [items |-> [rows[d][2].items EXCEPT ![CopySrc] =
                          IF src.st = "pending" THEN Bump(src, "retracted")
                          ELSE src],
                       base |-> rows[d][2].vc]
       IN IF copy THEN Put(d, (1 :> survivor) @@ (2 :> retired))
          ELSE Put(d, 2 :> retired)
    /\ agentOps' = [agentOps EXCEPT ![d] = @ + 1]
    /\ UNCHANGED <<pc, snap, recv, mem, attempts, applied, early>>

-----------------------------------------------------------------------------
(* Sync *)

ReceiveAtomic(d) ==
    /\ AtomicReceive
    /\ \E m \in msgs :
          /\ m.to = d
          /\ rows' = [rows EXCEPT ![d][m.row] = Resolve(rows[d][m.row], m.v)]
          /\ msgs' = msgs \ {m}
    /\ UNCHANGED <<hc, pc, snap, recv, mem, attempts, agentOps, applied, early>>

\* As is: the local row is read (or prefetched for a whole bundle), and
\* the chosen version written later.
ReceiveRead(d) ==
    /\ ~AtomicReceive
    /\ recv[d] = {}
    /\ \E m \in msgs :
          /\ m.to = d
          /\ recv' = [recv EXCEPT ![d] = {[m |-> m, local |-> rows[d][m.row]]}]
          /\ msgs' = msgs \ {m}
    /\ UNCHANGED <<rows, hc, pc, snap, mem, attempts, agentOps, applied, early>>

ReceiveWrite(d) ==
    /\ \E rc \in recv[d] :
          LET keep == Resolve(rc.local, rc.m.v) IN
          rows' = IF keep = rc.local THEN rows
                  ELSE [rows EXCEPT ![d][rc.m.row] = keep]
    /\ recv' = [recv EXCEPT ![d] = {}]
    /\ UNCHANGED <<hc, msgs, pc, snap, mem, attempts, agentOps, applied, early>>

-----------------------------------------------------------------------------

Next ==
    \/ \E d \in Devices :
          \/ ReceiveAtomic(d) \/ ReceiveRead(d) \/ ReceiveWrite(d)
          \/ Consolidate(d)
          \/ \E i \in Items :
                \/ Confirm(d, i) \/ DispatchOk(d, i) \/ DispatchFails(d, i)
                \/ FailAtomic(d, i) \/ FailRead(d, i) \/ FailWrite(d, i)
                \/ Reject(d, i) \/ Retract(d, i)
          \/ /\ FollowUp # NoItem
             /\ Migration # NoItem
             /\ \/ SibAtomic(d) \/ SibRead(d) \/ SibWrite(d)
                \/ CascadeAtomic(d) \/ CascadeRead(d) \/ CascadeWrite(d)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* Properties *)

TypeOK ==
    /\ \A d \in Devices, i \in Items :
          /\ Item(d, i).st \in Status
          /\ Item(d, i).rev \in Nat
          /\ pc[d][i] \in Pc
    /\ \A d \in Devices : mem[d] \in BOOLEAN

Total(x) == LET f[S \in SUBSET Devices] ==
                 IF S = {} THEN 0
                 ELSE LET e == CHOOSE e \in S : TRUE
                      IN applied[x][e] + f[S \ {e}]
            IN f[Devices]

\* Nothing in flight: every write delivered, every operation finished.
Quiescent ==
    /\ msgs = {}
    /\ \A d \in Devices : recv[d] = {}
    /\ \A d \in Devices, i \in Items : pc[d][i] = "idle"

\* A confirmed change takes effect at most once, on any device.
AtMostOnceApply == \A x \in Effects : Total(x) <= 1

\* ... and at most once per device, whoever else applied it.
AtMostOncePerDevice == \A x \in Effects, d \in Devices : applied[x][d] <= 1

\* A device that applied a change never shows it pending again: no
\* decided item returns to pending except by its own failed dispatch.
AppliedStaysDecided ==
    \A d \in Devices, i \in Items :
        applied[Effect(i)][d] >= 1 => Item(d, i).st # "pending"

\* Once everything has been delivered, what every device shows is what
\* happened: confirmed exactly when applied, never pending or rejected
\* when applied.
StatusMatchesEffect ==
    Quiescent =>
        \A d \in Devices, x \in Effects :
            LET sts == {Item(d, i).st : i \in ItemsOf(x)} IN
            /\ ("confirmed" \in sts) = (Total(x) >= 1)
            /\ Total(x) >= 1 => sts \cap {"pending", "rejected"} = {}

\* Once everything has been delivered, the replicas agree.
Converged ==
    Quiescent =>
        \A d, e \in Devices, i \in Items : Item(d, i) = Item(e, i)

\* A migration never runs before its target task exists.
MigrationAfterTarget == ~early
=============================================================================

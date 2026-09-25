------------------------- MODULE ChangeSetLifecycle -------------------------
(***************************************************************************)
(* A whole change set across its lifetime and across devices.             *)
(* ChangeSetConfirm.tla checks one item on one device; this spec checks    *)
(* what happens between the items of a set, and between the replicas of   *)
(* it: every writer of the set, the sync that carries each write to the    *)
(* other devices, the resolver that settles concurrent versions, and what  *)
(* a confirmed change does to the journal on each device.                  *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code                   *)
(* (lib/features/agents/...):                                              *)
(*                                                                         *)
(*   Confirm       service/change_set_confirmation_service.dart            *)
(*                 _confirmItem: the claim (claimChangeSetItem, one        *)
(*                 transaction), after the placeholder check of            *)
(*                 _resolveArgsIfNeeded for a migration item               *)
(*   DispatchOk    the tool took effect; for create_follow_up_task the     *)
(*                 in-memory placeholder mapping (captureResolvedId).      *)
(*                 The effect itself: tools/change_effect.dart (the        *)
(*                 effect key, derived entity ids, the compare-and-set     *)
(*                 base) and the tool handlers that use it                 *)
(*   DispatchFails the tool failed: revert to pending, or retract when     *)
(*                 the failure is non-retryable (transitionChangeSetItem,  *)
(*                 which also compares the revision the claim observed)    *)
(*   PersistSib    service/change_set_resolution_store.dart                *)
(*                 persistResolvedIdToSiblings: the migration's            *)
(*                 targetTaskId rewritten to the created task              *)
(*   Reject        rejectItem: the claim to `rejected`                     *)
(*   Cascade       cascadeRejectMigrationItems after a rejected follow-up  *)
(*   Reopen        reopenItem: a decided item back to pending, in one      *)
(*                 transaction. Record only: the task tools have no Undo   *)
(*                 of their effect, so the effect stays where it landed    *)
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
(*   ReceiveEnt,   the journal side of an effect: an entity or a task      *)
(*   ReceiveReg    field synced to the other devices, applied by           *)
(*                 lib/database/database_entity_ops.dart                   *)
(*                 updateJournalEntity / detectConflict: a newer version   *)
(*                 is taken, an older one dropped, and a concurrent one    *)
(*                 is kept aside as a Conflict row while the local         *)
(*                 version stays. Entities are modelled by id only: two    *)
(*                 devices that create the same id hold one entity         *)
(*   UserEdit      the user editing the field a set-style tool writes      *)
(*                                                                         *)
(* A change set syncs as one row. Every local write stamps the row with    *)
(* the next counter of its device on top of the clock it read, and sends   *)
(* it to every other device; sync applies a received row directly,         *)
(* without a new stamp or a send.                                          *)
(*                                                                         *)
(* Every user decision runs in its own attempt slot: a confirm of an item  *)
(* that was reopened while an earlier confirm's dispatch still ran is a    *)
(* second, concurrent operation on the same item.                          *)
(*                                                                         *)
(* An item is create-style (it creates an entity: a follow-up task, a      *)
(* time entry, a checklist item) or, when in SetItems, set-style (it       *)
(* writes one field, modelled as a register that starts at "base" and     *)
(* that the change sets to "target").                                      *)
(*                                                                         *)
(* The switches are fixes, and each is a mutation point: set one to FALSE *)
(* to check the design without it. ADR 0067:                               *)
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
(*   RevisionGuard      a failed dispatch moves its item only while the    *)
(*                      item still holds the revision its claim wrote;     *)
(*                      without it, it reverts a later claim of the item   *)
(*                                                                         *)
(* ADR 0075:                                                               *)
(*                                                                         *)
(*   ClaimResolvesTarget  a migration claimed through the in-memory        *)
(*                      placeholder mapping writes the resolved target in  *)
(*                      its claim; without it, the follow-up's sibling     *)
(*                      rewrite later bumps the claimed item's revision,   *)
(*                      and the revision guard then refuses the failed     *)
(*                      dispatch's revert: the item stays confirmed,       *)
(*                      though nothing was applied                         *)
(*   DerivedIds         a create-style tool derives its entity id from the *)
(*                      item's effect key and does nothing when that       *)
(*                      entity already exists; without it, every dispatch  *)
(*                      mints a random id                                  *)
(*   CopyCarriesKey     a consolidated copy carries its original's effect  *)
(*                      key; without it, the copy derives its own          *)
(*   CasGuard           a set-style tool writes only while the field       *)
(*                      still holds the value the proposal was based on;   *)
(*                      without it, a late second application overwrites   *)
(*                      whatever the field holds                           *)
(*   ReuseLive          with SeparateAttach, where a created entity and    *)
(*                      its link to a parent sync apart (a checklist and   *)
(*                      the task update listing it: tasks/repository/      *)
(*                      checklist_repository.dart derivedChecklistFor), a  *)
(*                      device that holds the entity but not its link      *)
(*                      writes nothing: the creator's own link update is   *)
(*                      on its way. Without it, it takes the id as spent   *)
(*                      and creates another                                *)
(*                                                                         *)
(* CrashBeforeLink is not a fix: it lets the creating device stop between  *)
(* the entity and its link — createChecklist's two writes — the residual   *)
(* EffectsLinked then shows.                                               *)
(*                                                                         *)
(* UserRestoresBase is not a fix: it lets the user's edit restore the base *)
(* value, the ABA a value compare-and-set cannot see.                      *)
(*                                                                         *)
(* `applied` is a ghost: how often each change was dispatched and took     *)
(* effect, per device. A consolidated copy and its original propose the    *)
(* same change, so they share one effect. `ents` is what the journal       *)
(* holds: the entity ids the effects created.                              *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, TLC

CONSTANTS
    Devices,       \* replicas, as 1..N; the numeric order is the host order
    Items,         \* change items, model values
    SetItems,      \* the set-style items; the others create an entity
    FollowUp,      \* the create_follow_up_task item, or NoItem
    Migration,     \* the migrate_checklist_item targeting it, or NoItem
    CopySrc,       \* an item of an older set that a wake consolidates
    CopyDst,       \* its slot in the surviving set, or NoItem
    NoItem,
    Faults,        \* subset of {"dispatchFails", "nonRetryable"}
    MaxAttempts,   \* user decisions per device and item
    MaxAgentOps,   \* retractions and consolidations per device
    MaxReopens,    \* reopens per device
    MaxUserEdits,  \* user edits of the set-style field per device, 0 or 1
    UserRestoresBase,
    RaceFree,      \* no item is decided on two devices before they synced
    AtomicWrites, AtomicReceive, ItemMerge, PendingCopiesOnly,
    RevisionGuard, ClaimResolvesTarget, DerivedIds, CopyCarriesKey, CasGuard,
    SeparateAttach, \* a created entity and its link to its parent sync apart
    ReuseLive,
    CrashBeforeLink

ASSUME
    /\ Faults \subseteq {"dispatchFails", "nonRetryable"}
    /\ SetItems \subseteq Items
    /\ MaxUserEdits \in {0, 1}
    /\ {UserRestoresBase, RaceFree, AtomicWrites, AtomicReceive, ItemMerge,
        PendingCopiesOnly, RevisionGuard, ClaimResolvesTarget, DerivedIds,
        CopyCarriesKey, CasGuard, SeparateAttach, ReuseLive,
        CrashBeforeLink} \subseteq BOOLEAN

\* The older set is row 2, the surviving set row 1.
Rows == IF CopyDst # NoItem THEN {1, 2} ELSE {1}
RowOf(i) == IF CopyDst # NoItem /\ i = CopySrc THEN 2 ELSE 1
ItemsIn(r) == {i \in Items : RowOf(i) = r}

\* A copy applies the same change as its original.
Effect(i) == IF i = CopyDst THEN CopySrc ELSE i
Effects == {Effect(i) : i \in Items}
ItemsOf(x) == {i \in Items : Effect(i) = x}
CreateEffects == {Effect(i) : i \in Items \ SetItems}

Slots == 1..MaxAttempts

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

\* The user's value for the set-style field. Strings, so that TLC compares
\* like with like.
UserVal(d) == IF UserRestoresBase THEN "base"
              ELSE IF d = 1 THEN "u1" ELSE "u2"

VARIABLES
    rows,      \* rows[d][r]: device d's replica of set r
    hc,        \* hc[d]: the last counter device d stamped on a set
    msgs,      \* change-set sync messages in flight
    pc,        \* pc[d][i][k]: progress of device d's attempt k on item i
    obs,       \* obs[d][i][k]: the item revision attempt k's claim wrote
    snap,      \* snap[d][i][k]: {} or {the row an unatomic write read}
    recv,      \* recv[d]: {} or {[m, local]} mid-way through a receive
    mem,       \* mem[d]: device d's in-memory placeholder mapping
    attempts,  \* attempts[d][i]: user decisions started
    agentOps,  \* agentOps[d]: retractions and consolidations run
    reopens,   \* reopens[d]: reopens run
    ents,      \* ents[d]: the entity ids device d's journal holds
    emsgs,     \* entity sync messages in flight
    atts,      \* atts[d]: the entity ids device d's journal links to their
               \* parent (a checklist in its task's checklistIds)
    amsgs,     \* link sync messages in flight
    reg,       \* reg[d]: device d's version of the set-style field
    rhc,       \* rhc[d]: the last counter device d stamped on the field
    rmsgs,     \* field sync messages in flight
    userEdits, \* userEdits[d]: user edits of the field on device d
    applied,   \* ghost: applied[x][d], effects taken by device d
    early,     \* ghost: a migration took effect before its target task
    latest,    \* ghost: latest[d][i], the slot of the standing claim, or 0
    lastOk,    \* ghost: the standing claim's dispatch succeeded
    conflict,  \* ghost: the field landed as a Conflict row somewhere
    clobbered  \* ghost: a dispatch overwrote a value the user wrote

entVars == <<ents, emsgs, atts, amsgs>>
effVars == <<entVars, reg, rhc, rmsgs, userEdits, conflict, clobbered>>
claimVars == <<obs, latest, lastOk, reopens>>

vars == <<rows, hc, msgs, pc, snap, recv, mem, attempts, agentOps,
          applied, early, effVars, claimVars>>

ZeroVc == [e \in Devices |-> 0]

Init ==
    /\ rows = [d \in Devices |-> [r \in Rows |-> InitRow(r)]]
    /\ hc = [d \in Devices |-> 0]
    /\ msgs = {}
    /\ pc = [d \in Devices |-> [i \in Items |-> [k \in Slots |-> "idle"]]]
    /\ obs = [d \in Devices |-> [i \in Items |-> [k \in Slots |-> 0]]]
    /\ snap = [d \in Devices |-> [i \in Items |-> [k \in Slots |-> {}]]]
    /\ recv = [d \in Devices |-> {}]
    /\ mem = [d \in Devices |-> FALSE]
    /\ attempts = [d \in Devices |-> [i \in Items |-> 0]]
    /\ agentOps = [d \in Devices |-> 0]
    /\ reopens = [d \in Devices |-> 0]
    /\ ents = [d \in Devices |-> {}]
    /\ emsgs = {}
    /\ atts = [d \in Devices |-> {}]
    /\ amsgs = {}
    /\ reg = [d \in Devices |-> [val |-> "base", user |-> FALSE, vc |-> ZeroVc]]
    /\ rhc = [d \in Devices |-> 0]
    /\ rmsgs = {}
    /\ userEdits = [d \in Devices |-> 0]
    /\ applied = [x \in Effects |-> [d \in Devices |-> 0]]
    /\ early = FALSE
    /\ latest = [d \in Devices |-> [i \in Items |-> 0]]
    /\ lastOk = [d \in Devices |-> [i \in Items |-> FALSE]]
    /\ conflict = FALSE
    /\ clobbered = FALSE

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

\* VectorClock.compareCanonically: the first host, in host order, whose counters
\* differ decides.
CanonGreater(a, b) ==
    LET diff == {e \in Devices : a[e] # b[e]} IN
    /\ diff # {}
    /\ LET e0 == CHOOSE e \in diff : \A f \in diff : e <= f IN a[e0] > b[e0]

\* mergeConcurrentChangeSets: the later revision, then the more final
\* status, then a fixed order on content (here: a resolved target first) —
\* never the clock order, so the merge does not depend on arrival order.
MergeItem(a, b) ==
    IF a.rev # b.rev THEN (IF a.rev > b.rev THEN a ELSE b)
    ELSE IF Rank(a.st) # Rank(b.st) THEN (IF Rank(a.st) > Rank(b.st) THEN a ELSE b)
    ELSE IF a.res THEN a ELSE b

\* The version a receiving device keeps.
Resolve(local, incoming) ==
    IF Leq(incoming.vc, local.vc) THEN local
    ELSE IF Leq(local.vc, incoming.vc) THEN incoming
    ELSE LET inWins == CanonGreater(incoming.vc, local.vc) IN
         IF ItemMerge
         THEN [items |-> [i \in DOMAIN local.items |->
                             MergeItem(local.items[i], incoming.items[i])],
               vc |-> Join(local.vc, incoming.vc)]
         ELSE IF inWins THEN incoming ELSE local

Idle(d, i) == \A k \in Slots : pc[d][i][k] = "idle"

\* Nothing about item i from another device is on its way to d, and no
\* other device is mid-way through an operation on the same change.
RaceGuard(d, i) ==
    \/ ~RaceFree
    \/ /\ \A e \in Devices \ {d}, j \in ItemsOf(Effect(i)) : Idle(e, j)
       /\ ~\E m \in msgs : m.to = d /\ \E j \in m.touched : Effect(j) = Effect(i)
       /\ \A rc \in recv[d] : ~\E j \in rc.m.touched : Effect(j) = Effect(i)

-----------------------------------------------------------------------------
(* The effect of a dispatch on the journal *)

\* The entity a create-style dispatch writes: derived from the item's
\* effect key (which a consolidated copy inherits from its original), or
\* a fresh id per dispatch.
EntityId(d, i, k) ==
    IF DerivedIds THEN (IF CopyCarriesKey THEN <<Effect(i)>> ELSE <<i>>)
    ELSE <<i, d, k>>
EffOf(id) == Effect(id[1])

\* Create the entity unless the journal already holds it.
Create(d, i, k) ==
    LET id == EntityId(d, i, k) IN
    /\ IF id \in ents[d]
       THEN UNCHANGED <<ents, emsgs>>
       ELSE /\ ents' = [ents EXCEPT ![d] = @ \cup {id}]
            /\ emsgs' = emsgs \cup {[to |-> e, id |-> id] : e \in Devices \ {d}}
    /\ UNCHANGED <<atts, amsgs, reg, rhc, rmsgs, userEdits, conflict,
                   clobbered>>

\* ... and link it to its parent: two writes that sync apart, so a device
\* can hold the entity another device created without its link. A device
\* that holds the entity has nothing to add and writes nothing (ReuseLive):
\* the link is the creator's to send — relinking would be a task write
\* concurrent with it, a journal conflict. As first written, it took the id
\* as spent and created the entity afresh.
Link(d, id) ==
    /\ atts' = [atts EXCEPT ![d] = @ \cup {id}]
    /\ amsgs' = amsgs \cup {[to |-> e, id |-> id] : e \in Devices \ {d}}

CreateLinked(d, i, k) ==
    LET id == EntityId(d, i, k)
        fresh == <<i, d, k>>
        new(x) == /\ ents' = [ents EXCEPT ![d] = @ \cup {x}]
                  /\ emsgs' = emsgs \cup
                        {[to |-> e, id |-> x] : e \in Devices \ {d}}
    IN
    /\ IF id \in atts[d]
       THEN UNCHANGED <<ents, emsgs, atts, amsgs>>
       ELSE IF id \notin ents[d]
       THEN new(id) /\ (Link(d, id) \/ (CrashBeforeLink /\ UNCHANGED <<atts, amsgs>>))
       ELSE IF ReuseLive \/ ~DerivedIds
       THEN UNCHANGED <<ents, emsgs, atts, amsgs>>
       ELSE new(fresh) /\ Link(d, fresh)
    /\ UNCHANGED <<reg, rhc, rmsgs, userEdits, conflict, clobbered>>

\* Device d writes the field: its next counter on the clock it holds.
RegPut(d, val, user) ==
    LET v == [val |-> val, user |-> user,
              vc |-> [reg[d].vc EXCEPT ![d] = rhc[d] + 1]] IN
    /\ reg' = [reg EXCEPT ![d] = v]
    /\ rhc' = [rhc EXCEPT ![d] = @ + 1]
    /\ rmsgs' = rmsgs \cup {[to |-> e, v |-> v] : e \in Devices \ {d}}

\* A set-style dispatch. With the guard it writes only over the base the
\* proposal was made on; a field that holds the target, or anything else,
\* is left alone and the dispatch still succeeds.
SetField(d) ==
    LET r == reg[d]
        write == IF CasGuard THEN r.val = "base" ELSE r.val # "target"
    IN /\ IF write
          THEN /\ RegPut(d, "target", FALSE)
               /\ clobbered' = (clobbered \/ r.user)
          ELSE UNCHANGED <<reg, rhc, rmsgs, clobbered>>
       /\ UNCHANGED <<entVars, userEdits, conflict>>

-----------------------------------------------------------------------------
(* Confirming and rejecting *)

\* The claim: pending -> confirmed in one transaction, in a fresh attempt
\* slot. A migration whose target task is still a placeholder, and not in
\* this device's memory, is refused before the claim.
Confirm(d, i) ==
    LET k == attempts[d][i] + 1
        claimed == Bump(Item(d, i), "confirmed")
        rec == IF ClaimResolvesTarget /\ i = Migration
               THEN [claimed EXCEPT !.res = TRUE] ELSE claimed
    IN
    /\ attempts[d][i] < MaxAttempts
    /\ Item(d, i).st = "pending"
    /\ i = Migration => (Item(d, i).res \/ mem[d])
    /\ RaceGuard(d, i)
    /\ PutItem(d, i, rec, rows[d][RowOf(i)])
    /\ pc' = [pc EXCEPT ![d][i][k] = "claimed"]
    /\ obs' = [obs EXCEPT ![d][i][k] = rec.rev]
    /\ attempts' = [attempts EXCEPT ![d][i] = @ + 1]
    /\ latest' = [latest EXCEPT ![d][i] = k]
    /\ lastOk' = [lastOk EXCEPT ![d][i] = FALSE]
    /\ UNCHANGED <<snap, recv, mem, agentOps, applied, early, effVars,
                   reopens>>

DispatchOk(d, i, k) ==
    /\ pc[d][i][k] = "claimed"
    /\ applied' = [applied EXCEPT ![Effect(i)][d] = @ + 1]
    /\ early' = (early \/ (i = Migration /\
                   \A e \in Devices : applied[FollowUp][e] = 0))
    /\ mem' = IF i = FollowUp THEN [mem EXCEPT ![d] = TRUE] ELSE mem
    /\ pc' = [pc EXCEPT ![d][i][k] =
                IF i = FollowUp /\ Migration # NoItem THEN "sib" ELSE "idle"]
    /\ lastOk' = IF latest[d][i] = k THEN [lastOk EXCEPT ![d][i] = TRUE]
                 ELSE lastOk
    /\ IF i \in SetItems THEN SetField(d)
       ELSE IF SeparateAttach THEN CreateLinked(d, i, k)
       ELSE Create(d, i, k)
    /\ UNCHANGED <<rows, hc, msgs, snap, recv, attempts, agentOps, obs,
                   latest, reopens>>

\* A retryable failure reverts to pending; a non-retryable one retracts.
DispatchFails(d, i, k) ==
    /\ pc[d][i][k] = "claimed"
    /\ \/ "dispatchFails" \in Faults /\ pc' = [pc EXCEPT ![d][i][k] = "failP"]
       \/ "nonRetryable" \in Faults /\ pc' = [pc EXCEPT ![d][i][k] = "failR"]
    /\ UNCHANGED <<rows, hc, msgs, snap, recv, mem, attempts, agentOps,
                   applied, early, effVars, claimVars>>

\* The targetTaskId rewrite is a change of the item too.
Resolved(rec) == [rec EXCEPT !.res = TRUE,
                             !.rev = IF ItemMerge THEN @ + 1 ELSE @]

FailTarget(p) == IF p \in {"failP", "failPW"} THEN "pending" ELSE "retracted"

\* Fixed: one transaction moves the item from confirmed, and only the item,
\* and only while it holds the revision this attempt's claim wrote.
FailAtomic(d, i, k) ==
    /\ AtomicWrites
    /\ pc[d][i][k] \in {"failP", "failR"}
    /\ IF /\ Item(d, i).st = "confirmed"
          /\ RevisionGuard => Item(d, i).rev = obs[d][i][k]
       THEN PutItem(d, i, Bump(Item(d, i), FailTarget(pc[d][i][k])),
                    rows[d][RowOf(i)])
       ELSE UNCHANGED <<rows, hc, msgs>>
    /\ pc' = [pc EXCEPT ![d][i][k] = "idle"]
    /\ UNCHANGED <<snap, recv, mem, attempts, agentOps, applied, early,
                   effVars, claimVars>>

\* As is: updateChangeSetItemStatus reads the set, awaits, and writes the
\* whole set back with the item changed.
FailRead(d, i, k) ==
    /\ ~AtomicWrites
    /\ pc[d][i][k] \in {"failP", "failR"}
    /\ snap' = [snap EXCEPT ![d][i][k] = {rows[d][RowOf(i)]}]
    /\ pc' = [pc EXCEPT ![d][i][k] = IF @ = "failP" THEN "failPW" ELSE "failRW"]
    /\ UNCHANGED <<rows, hc, msgs, recv, mem, attempts, agentOps, applied,
                   early, effVars, claimVars>>

FailWrite(d, i, k) ==
    /\ pc[d][i][k] \in {"failPW", "failRW"}
    /\ \E s \in snap[d][i][k] :
          PutItem(d, i, Bump(s.items[i], FailTarget(pc[d][i][k])), s)
    /\ snap' = [snap EXCEPT ![d][i][k] = {}]
    /\ pc' = [pc EXCEPT ![d][i][k] = "idle"]
    /\ UNCHANGED <<recv, mem, attempts, agentOps, applied, early, effVars,
                   claimVars>>

\* After the follow-up task exists, its migration's targetTaskId is
\* rewritten to the real task id.
SibAtomic(d, k) ==
    /\ AtomicWrites
    /\ pc[d][FollowUp][k] = "sib"
    /\ IF ~Item(d, Migration).res
       THEN PutItem(d, Migration, Resolved(Item(d, Migration)),
                    rows[d][RowOf(Migration)])
       ELSE UNCHANGED <<rows, hc, msgs>>
    /\ pc' = [pc EXCEPT ![d][FollowUp][k] = "idle"]
    /\ UNCHANGED <<snap, recv, mem, attempts, agentOps, applied, early,
                   effVars, claimVars>>

SibRead(d, k) ==
    /\ ~AtomicWrites
    /\ pc[d][FollowUp][k] = "sib"
    /\ snap' = [snap EXCEPT ![d][FollowUp][k] = {rows[d][RowOf(Migration)]}]
    /\ pc' = [pc EXCEPT ![d][FollowUp][k] = "sibW"]
    /\ UNCHANGED <<rows, hc, msgs, recv, mem, attempts, agentOps, applied,
                   early, effVars, claimVars>>

SibWrite(d, k) ==
    /\ pc[d][FollowUp][k] = "sibW"
    /\ \E s \in snap[d][FollowUp][k] :
          IF ~s.items[Migration].res
          THEN PutItem(d, Migration, Resolved(s.items[Migration]), s)
          ELSE UNCHANGED <<rows, hc, msgs>>
    /\ snap' = [snap EXCEPT ![d][FollowUp][k] = {}]
    /\ pc' = [pc EXCEPT ![d][FollowUp][k] = "idle"]
    /\ UNCHANGED <<recv, mem, attempts, agentOps, applied, early, effVars,
                   claimVars>>

\* The claim: pending -> rejected in one transaction.
Reject(d, i) ==
    LET k == attempts[d][i] + 1 IN
    /\ attempts[d][i] < MaxAttempts
    /\ Item(d, i).st = "pending"
    /\ RaceGuard(d, i)
    /\ PutItem(d, i, Bump(Item(d, i), "rejected"), rows[d][RowOf(i)])
    /\ pc' = [pc EXCEPT ![d][i][k] =
                IF i = FollowUp /\ Migration # NoItem THEN "cascade" ELSE "idle"]
    /\ attempts' = [attempts EXCEPT ![d][i] = @ + 1]
    /\ latest' = [latest EXCEPT ![d][i] = k]
    /\ lastOk' = [lastOk EXCEPT ![d][i] = FALSE]
    /\ UNCHANGED <<snap, recv, mem, agentOps, applied, early, effVars, obs,
                   reopens>>

\* A rejected follow-up rejects its pending migration.
CascadeAtomic(d, k) ==
    /\ AtomicWrites
    /\ pc[d][FollowUp][k] = "cascade"
    /\ IF Item(d, Migration).st = "pending"
       THEN PutItem(d, Migration, Bump(Item(d, Migration), "rejected"),
                    rows[d][RowOf(Migration)])
       ELSE UNCHANGED <<rows, hc, msgs>>
    /\ pc' = [pc EXCEPT ![d][FollowUp][k] = "idle"]
    /\ UNCHANGED <<snap, recv, mem, attempts, agentOps, applied, early,
                   effVars, claimVars>>

CascadeRead(d, k) ==
    /\ ~AtomicWrites
    /\ pc[d][FollowUp][k] = "cascade"
    /\ IF Item(d, Migration).st = "pending"
       THEN /\ snap' = [snap EXCEPT ![d][FollowUp][k] =
                           {rows[d][RowOf(Migration)]}]
            /\ pc' = [pc EXCEPT ![d][FollowUp][k] = "cascadeW"]
       ELSE /\ pc' = [pc EXCEPT ![d][FollowUp][k] = "idle"]
            /\ UNCHANGED snap
    /\ UNCHANGED <<rows, hc, msgs, recv, mem, attempts, agentOps, applied,
                   early, effVars, claimVars>>

CascadeWrite(d, k) ==
    /\ pc[d][FollowUp][k] = "cascadeW"
    /\ \E s \in snap[d][FollowUp][k] :
          PutItem(d, Migration, Bump(s.items[Migration], "rejected"), s)
    /\ snap' = [snap EXCEPT ![d][FollowUp][k] = {}]
    /\ pc' = [pc EXCEPT ![d][FollowUp][k] = "idle"]
    /\ UNCHANGED <<recv, mem, attempts, agentOps, applied, early, effVars,
                   claimVars>>

\* reopenItem: a decided item back to pending in one transaction. The
\* standing claim no longer stands, whatever its dispatch still does.
Reopen(d, i) ==
    /\ reopens[d] < MaxReopens
    /\ Item(d, i).st \in {"confirmed", "rejected"}
    /\ PutItem(d, i, Bump(Item(d, i), "pending"), rows[d][RowOf(i)])
    /\ reopens' = [reopens EXCEPT ![d] = @ + 1]
    /\ latest' = [latest EXCEPT ![d][i] = 0]
    /\ lastOk' = [lastOk EXCEPT ![d][i] = FALSE]
    /\ UNCHANGED <<pc, snap, recv, mem, attempts, agentOps, applied, early,
                   effVars, obs>>

-----------------------------------------------------------------------------
(* The agent *)

\* A staged retraction, applied at the end of a wake inside its
\* transaction: only a still-pending item is retracted.
Retract(d, i) ==
    /\ agentOps[d] < MaxAgentOps
    /\ Item(d, i).st = "pending"
    /\ PutItem(d, i, Bump(Item(d, i), "retracted"), rows[d][RowOf(i)])
    /\ agentOps' = [agentOps EXCEPT ![d] = @ + 1]
    /\ UNCHANGED <<pc, snap, recv, mem, attempts, applied, early, effVars,
                   claimVars>>

\* The final build of a wake folds the older set (row 2) into the
\* survivor (row 1) and retires it: a pending original is retracted,
\* because its actionable copy now lives in the survivor. A set holding a
\* migration whose follow-up is unresolved is not folded at all
\* (ChangeSetDependency.tla), so the copied item is a plain one here, and a
\* retained group's items keep their position as their effect key.
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
    /\ UNCHANGED <<pc, snap, recv, mem, attempts, applied, early, effVars,
                   claimVars>>

-----------------------------------------------------------------------------
(* The user *)

\* The user edits the field a set-style item proposes to change.
UserEdit(d) ==
    /\ userEdits[d] < MaxUserEdits
    /\ RegPut(d, UserVal(d), TRUE)
    /\ userEdits' = [userEdits EXCEPT ![d] = @ + 1]
    /\ UNCHANGED <<rows, hc, msgs, pc, snap, recv, mem, attempts, agentOps,
                   applied, early, entVars, conflict, clobbered,
                   claimVars>>

-----------------------------------------------------------------------------
(* Sync *)

ReceiveAtomic(d) ==
    /\ AtomicReceive
    /\ \E m \in msgs :
          /\ m.to = d
          /\ rows' = [rows EXCEPT ![d][m.row] = Resolve(rows[d][m.row], m.v)]
          /\ msgs' = msgs \ {m}
    /\ UNCHANGED <<hc, pc, snap, recv, mem, attempts, agentOps, applied,
                   early, effVars, claimVars>>

\* As is: the local row is read (or prefetched for a whole bundle), and
\* the chosen version written later.
ReceiveRead(d) ==
    /\ ~AtomicReceive
    /\ recv[d] = {}
    /\ \E m \in msgs :
          /\ m.to = d
          /\ recv' = [recv EXCEPT ![d] = {[m |-> m, local |-> rows[d][m.row]]}]
          /\ msgs' = msgs \ {m}
    /\ UNCHANGED <<rows, hc, pc, snap, mem, attempts, agentOps, applied,
                   early, effVars, claimVars>>

ReceiveWrite(d) ==
    /\ \E rc \in recv[d] :
          LET keep == Resolve(rc.local, rc.m.v) IN
          rows' = IF keep = rc.local THEN rows
                  ELSE [rows EXCEPT ![d][rc.m.row] = keep]
    /\ recv' = [recv EXCEPT ![d] = {}]
    /\ UNCHANGED <<hc, msgs, pc, snap, mem, attempts, agentOps, applied,
                   early, effVars, claimVars>>

\* A created entity arrives. An entity under an id the journal already
\* holds is the same entity.
ReceiveEnt(d) ==
    /\ \E m \in emsgs :
          /\ m.to = d
          /\ ents' = [ents EXCEPT ![d] = @ \cup {m.id}]
          /\ emsgs' = emsgs \ {m}
    /\ UNCHANGED <<rows, hc, msgs, pc, snap, recv, mem, attempts, agentOps,
                   applied, early, atts, amsgs, reg, rhc, rmsgs, userEdits,
                   conflict, clobbered, claimVars>>

\* A link arrives: the parent's update that lists the entity.
ReceiveLink(d) ==
    /\ \E m \in amsgs :
          /\ m.to = d
          /\ atts' = [atts EXCEPT ![d] = @ \cup {m.id}]
          /\ amsgs' = amsgs \ {m}
    /\ UNCHANGED <<rows, hc, msgs, pc, snap, recv, mem, attempts, agentOps,
                   applied, early, ents, emsgs, reg, rhc, rmsgs, userEdits,
                   conflict, clobbered, claimVars>>

\* updateJournalEntity: an older or equal version is dropped, a newer one
\* taken, and a concurrent one — equal content or not — is kept aside as a
\* Conflict row for the user while the local version stays.
ReceiveReg(d) ==
    /\ \E m \in rmsgs :
          /\ m.to = d
          /\ LET local == reg[d]
                 in == m.v
             IN IF Leq(in.vc, local.vc)
                THEN UNCHANGED <<reg, conflict>>
                ELSE IF Leq(local.vc, in.vc)
                THEN /\ reg' = [reg EXCEPT ![d] = in]
                     /\ UNCHANGED conflict
                ELSE /\ conflict' = TRUE
                     /\ UNCHANGED reg
          /\ rmsgs' = rmsgs \ {m}
    /\ UNCHANGED <<rows, hc, msgs, pc, snap, recv, mem, attempts, agentOps,
                   applied, early, entVars, rhc, userEdits, clobbered,
                   claimVars>>

-----------------------------------------------------------------------------

Next ==
    \/ \E d \in Devices :
          \/ ReceiveAtomic(d) \/ ReceiveRead(d) \/ ReceiveWrite(d)
          \/ ReceiveEnt(d) \/ ReceiveLink(d) \/ ReceiveReg(d)
          \/ UserEdit(d)
          \/ Consolidate(d)
          \/ \E i \in Items :
                \/ Confirm(d, i) \/ Reject(d, i) \/ Retract(d, i)
                \/ Reopen(d, i)
                \/ \E k \in Slots :
                      \/ DispatchOk(d, i, k) \/ DispatchFails(d, i, k)
                      \/ FailAtomic(d, i, k) \/ FailRead(d, i, k)
                      \/ FailWrite(d, i, k)
          \/ /\ FollowUp # NoItem
             /\ Migration # NoItem
             /\ \E k \in Slots :
                   \/ SibAtomic(d, k) \/ SibRead(d, k) \/ SibWrite(d, k)
                   \/ CascadeAtomic(d, k) \/ CascadeRead(d, k)
                   \/ CascadeWrite(d, k)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* Properties *)

TypeOK ==
    /\ \A d \in Devices, i \in Items :
          /\ Item(d, i).st \in Status
          /\ Item(d, i).rev \in Nat
          /\ \A k \in Slots : pc[d][i][k] \in Pc
          /\ latest[d][i] \in 0..MaxAttempts
          /\ lastOk[d][i] \in BOOLEAN
    /\ \A d \in Devices :
          /\ mem[d] \in BOOLEAN
          /\ reg[d].val \in {"base", "target", "u1", "u2"}
          /\ \A id \in ents[d] : EffOf(id) \in CreateEffects
    /\ conflict \in BOOLEAN
    /\ clobbered \in BOOLEAN

Total(x) == LET f[S \in SUBSET Devices] ==
                 IF S = {} THEN 0
                 ELSE LET e == CHOOSE e \in S : TRUE
                      IN applied[x][e] + f[S \ {e}]
            IN f[Devices]

\* Nothing about the change sets in flight: every write delivered, every
\* operation finished.
Quiescent ==
    /\ msgs = {}
    /\ \A d \in Devices : recv[d] = {}
    /\ \A d \in Devices, i \in Items : Idle(d, i)

\* ... and every journal write delivered as well.
QuiescentAll == Quiescent /\ emsgs = {} /\ amsgs = {} /\ rmsgs = {}

\* A confirmed change is dispatched at most once, on any device. It holds
\* only where no item is decided on two devices before they sync; where
\* one is, EffectsConverge says what the second dispatch may do instead.
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

\* A claim whose dispatch succeeded stands: nothing but a new decision
\* takes its item out of `confirmed` — in particular not the failure of an
\* earlier attempt at the same item.
SucceededClaimStands ==
    \A d \in Devices, i \in Items : lastOk[d][i] => Item(d, i).st = "confirmed"

AllIds == UNION {ents[d] \cup atts[d] : d \in Devices}
              \cup {m.id : m \in emsgs \cup amsgs}

\* However often a change is dispatched, and wherever, it creates at most
\* one entity.
NoDuplicateEffects ==
    \A x \in Effects : Cardinality({id \in AllIds : EffOf(id) = x}) <= 1

\* A dispatch never overwrites a value the user wrote to the field.
NoClobber == ~clobbered

\* Once everything has been delivered, every journal holds the same
\* entities — one for each change that took effect anywhere, none for one
\* that did not — and the same field value, unless a concurrent write
\* landed as a Conflict row for the user to resolve.
EffectsConverge ==
    QuiescentAll =>
        /\ \A d, e \in Devices : ents[d] = ents[e]
        /\ ~conflict => \A d, e \in Devices : reg[d].val = reg[e].val
        /\ \A d \in Devices, x \in CreateEffects :
              (\E id \in ents[d] : EffOf(id) = x) <=> (Total(x) >= 1)
\* Once everything has been delivered, every entity a change created is
\* linked to its parent on every device — the checklist a task lists — and
\* nothing is linked that no device created.
EffectsLinked ==
    SeparateAttach /\ QuiescentAll => \A d \in Devices : atts[d] = ents[d]
=============================================================================

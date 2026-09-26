------------------------ MODULE AiConfigReplication ------------------------
(***************************************************************************)
(* AI configurations across devices: an inference provider and the models *)
(* that point at it, as AiConfigRepository writes them, the aiConfig and  *)
(* aiConfigDelete messages the outbox sends, and the receive rules of     *)
(* SyncEventProcessor's apply. Profiles, prompts and skills replicate     *)
(* through the same rows and the same receive rule as the models here.    *)
(*                                                                         *)
(* Each device holds, per config id, nothing (never written, or hard      *)
(* deleted), a live row or a tombstone (`deletedAt` set). A row carries   *)
(* its stamp (`updatedAt`) and its content, abstracted to the device that *)
(* wrote it. `log` is every message that reached the outbox; a receiver  *)
(* can apply any logged message in any order, and again (Redeliver): the *)
(* outbox retries, catch-up re-delivers, and "Send settings" re-sends     *)
(* whatever a device holds (Replay). A write and its enqueue are one step *)
(* (the enqueue's own failure is Outbox.tla's).                           *)
(*                                                                         *)
(*   Edit        AiConfigRepository.saveConfig from the settings forms,  *)
(*               seeding upgrades and model-id migrations                  *)
(*   SoftDelete  AiConfigRepository.deleteConfig of a model or profile   *)
(*   Restore     AiConfigRepository.restoreConfig, and the provider undo *)
(*               in AiConfigDeleteService re-saving what it deleted        *)
(*   Cascade     AiConfigRepository.deleteInferenceProviderWithModels     *)
(*   Backfill    ModelPrepopulationService.backfillNewModels creating a   *)
(*               known model under its deterministic generateModelId      *)
(*   Replay      SyncMaintenanceRepository "Send settings": every row,   *)
(*               deleted ones included                                     *)
(*   Receive     _applySyncMessage -> saveConfig(fromSync: true), or      *)
(*               hardDeleteConfig(fromSync: true) for a hard delete        *)
(*                                                                         *)
(* The switches are the fixes; FALSE is the code before them:             *)
(*   OrderLiveRows    an incoming live row is applied only when it beats *)
(*                    the local row (stamp, then tombstone over live, then *)
(*                    content); before, it overwrote any live row and was *)
(*                    screened only against a local tombstone's stamp     *)
(*   OrderTombstones  an incoming tombstone obeys the same order; before, *)
(*                    it was applied whatever it met                       *)
(*   MonotonicStamps  a local write stamps `updatedAt` itself, past the   *)
(*                    row it replaces; before, many writers left the      *)
(*                    caller's stamp (often none, or the one copied)      *)
(*   SoftCascade      the provider cascade tombstones the provider and    *)
(*                    its models; before, it hard-deleted them and sent   *)
(*                    aiConfigDelete(hardDelete: true)                     *)
(*   CascadeOnReceive a receiver tombstones, and sends, its live models   *)
(*                    of a tombstoned provider: when the provider's       *)
(*                    tombstone lands, and when a live model of it does   *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS N, Provider, Models, Backfilled, MaxStamp,
          EditBudget, DeleteBudget, RestoreBudget, CascadeBudget,
          BackfillBudget, ReplayBudget,
          OrderLiveRows, OrderTombstones, MonotonicStamps, SoftCascade,
          CascadeOnReceive

Devices == 1..N
Ids == {Provider} \cup Models
Stamps == 1..MaxStamp
Kinds == {"none", "live", "tomb"}
None == [k |-> "none", s |-> 0, c |-> 0]
Max(a, b) == IF a >= b THEN a ELSE b

(* The rows every device starts with: the provider and its models, synced *)
(* long ago. The backfilled model does not exist anywhere yet.            *)
InitialRow(i) == IF i = Backfilled THEN None
                 ELSE [k |-> "live", s |-> 1, c |-> 0]

(* A message: a row (aiConfig, deletedAt set for a tombstone), or a hard  *)
(* delete (aiConfigDelete(hardDelete: true)), which carries no row.       *)
Rows == [k : Kinds, s : Nat, c : 0..N]
Msgs == [t : {"row", "hard"}, from : Devices, id : Ids, r : Rows]

VARIABLES row, log, delivered, hist,
          edits, deletes, restores, cascades, backfills, replays

vars == <<row, log, delivered, hist,
          edits, deletes, restores, cascades, backfills, replays>>

Init ==
    /\ row = [d \in Devices |-> [i \in Ids |-> InitialRow(i)]]
    /\ log = {}
    /\ delivered = [d \in Devices |-> {}]
    /\ hist = [i \in Ids |-> IF i = Backfilled THEN {} ELSE {InitialRow(i)}]
    /\ edits = 0 /\ deletes = 0 /\ restores = 0 /\ cascades = 0
    /\ backfills = 0 /\ replays = 0

Live(r) == r.k = "live"
Tomb(r) == r.k = "tomb"
Rank(k) == IF k = "tomb" THEN 1 ELSE 0

(* The total order the fix introduces: stamp, then a tombstone over a     *)
(* live row, then content (compareAiConfigRevisions).                     *)
Newer(a, b) ==
    \/ a.s > b.s
    \/ a.s = b.s /\ Rank(a.k) > Rank(b.k)
    \/ a.s = b.s /\ a.k = b.k /\ a.c > b.c

(* The stamp of a local write that replaces `prev`, at clock `now`.       *)
StampPast(now, prev) == IF MonotonicStamps THEN Max(now, prev.s + 1) ELSE now

Send(d, i, r) == [t |-> "row", from |-> d, id |-> i, r |-> r]

------------------------------------------------------------------------------
(* Local writes. Each writes its row and enqueues it in one step. *)

Write(d, i, r) ==
    /\ row' = [row EXCEPT ![d][i] = r]
    /\ log' = log \cup {Send(d, i, r)}
    /\ hist' = [hist EXCEPT ![i] = @ \cup {r}]

Edit(d, i) ==
    /\ edits < EditBudget /\ Live(row[d][i])
    /\ \E now \in Stamps :
         Write(d, i, [k |-> "live", s |-> StampPast(now, row[d][i]), c |-> d])
    /\ edits' = edits + 1
    /\ UNCHANGED <<delivered, deletes, restores, cascades, backfills, replays>>

SoftDelete(d, m) ==
    /\ deletes < DeleteBudget /\ m \in Models /\ Live(row[d][m])
    /\ \E now \in Stamps :
         Write(d, m, [k |-> "tomb", s |-> StampPast(now, row[d][m]), c |-> d])
    /\ deletes' = deletes + 1
    /\ UNCHANGED <<delivered, edits, restores, cascades, backfills, replays>>

(* restoreConfig clears `deletedAt`, stamped now. The provider's undo     *)
(* re-saves the row it deleted, which after the fix is stamped past the   *)
(* tombstone the same way.                                                *)
Restore(d, i) ==
    /\ restores < RestoreBudget /\ Tomb(row[d][i])
    /\ \E now \in Stamps :
         Write(d, i, [k |-> "live", s |-> StampPast(now, row[d][i]), c |-> d])
    /\ restores' = restores + 1
    /\ UNCHANGED <<delivered, edits, deletes, cascades, backfills, replays>>

(* The provider's live models on d. The cascade reads live rows only.     *)
LiveModels(d) == {m \in Models : Live(row[d][m])}

Cascade(d) ==
    /\ cascades < CascadeBudget /\ Live(row[d][Provider])
    /\ \E now \in Stamps :
         LET gone == LiveModels(d) \cup {Provider}
             tomb(i) == [k |-> "tomb", s |-> StampPast(now, row[d][i]), c |-> d]
         IN IF SoftCascade
            THEN /\ row' = [row EXCEPT ![d] =
                       [i \in Ids |-> IF i \in gone THEN tomb(i) ELSE @[i]]]
                 /\ log' = log \cup {Send(d, i, tomb(i)) : i \in gone}
                 /\ hist' = [i \in Ids |->
                       IF i \in gone THEN hist[i] \cup {tomb(i)} ELSE hist[i]]
            ELSE /\ row' = [row EXCEPT ![d] =
                       [i \in Ids |-> IF i \in gone THEN None ELSE @[i]]]
                 /\ log' = log \cup {[t |-> "hard", from |-> d, id |-> i,
                                      r |-> None] : i \in gone}
                 /\ UNCHANGED hist
    /\ cascades' = cascades + 1
    /\ UNCHANGED <<delivered, edits, deletes, restores, backfills, replays>>

(* Only a live provider is backfilled, and only a model id this device    *)
(* holds no row for, deleted or not.                                      *)
Backfill(d) ==
    /\ backfills < BackfillBudget
    /\ Live(row[d][Provider]) /\ row[d][Backfilled].k = "none"
    /\ \E now \in Stamps :
         Write(d, Backfilled,
               [k |-> "live", s |-> StampPast(now, None), c |-> d])
    /\ backfills' = backfills + 1
    /\ UNCHANGED <<delivered, edits, deletes, restores, cascades, replays>>

Replay(d) ==
    /\ replays < ReplayBudget
    /\ log' = log \cup {Send(d, i, row[d][i]) : i \in {j \in Ids :
                                                   row[d][j].k # "none"}}
    /\ replays' = replays + 1
    /\ UNCHANGED <<row, delivered, hist, edits, deletes, restores, cascades,
                   backfills>>

------------------------------------------------------------------------------
(* Receiving *)

(* Whether an incoming row replaces what device d holds for id i. *)
Accepts(d, i, r) ==
    LET cur == row[d][i] IN
    IF cur.k = "none" THEN TRUE
    ELSE IF Live(r)
         THEN IF OrderLiveRows THEN Newer(r, cur)
              \* the stale-replay screen: only against a tombstone, by stamp
              ELSE ~(Tomb(cur) /\ r.s <= cur.s)
         ELSE IF OrderTombstones THEN Newer(r, cur) ELSE TRUE

(* The row device d holds for i after applying message m. *)
Applied(d, m) ==
    IF m.t = "hard" THEN None
    ELSE IF Accepts(d, m.id, m.r) THEN m.r ELSE row[d][m.id]

(* The models the receiver must tombstone once `after` is its state:      *)
(* live models of a tombstoned provider.                                  *)
Orphans(after) ==
    IF CascadeOnReceive /\ Tomb(after[Provider])
    THEN {x \in Models : Live(after[x])} ELSE {}

(* An orphan's tombstone is stamped just past the row it replaces: the     *)
(* local clock only matters when it is further ahead, which the other     *)
(* writes already explore.                                                *)
Apply(d, m) ==
    LET after == [row[d] EXCEPT ![m.id] = Applied(d, m)]
        orphans == Orphans(after)
        tomb(i) == [k |-> "tomb", s |-> after[i].s + 1, c |-> d]
    IN /\ row' = [row EXCEPT ![d] =
              [i \in Ids |-> IF i \in orphans THEN tomb(i) ELSE after[i]]]
       /\ log' = log \cup {Send(d, i, tomb(i)) : i \in orphans}
       /\ hist' = [i \in Ids |->
              IF i \in orphans THEN hist[i] \cup {tomb(i)} ELSE hist[i]]

Receive(d) ==
    /\ \E m \in log :
         /\ m.from # d /\ m \notin delivered[d]
         /\ Apply(d, m)
         /\ delivered' = [delivered EXCEPT ![d] = @ \cup {m}]
    /\ UNCHANGED <<edits, deletes, restores, cascades, backfills, replays>>

(* The outbox's retry or a catch-up re-delivers a message already applied *)
Redeliver(d) ==
    /\ \E m \in delivered[d] : Apply(d, m)
    /\ UNCHANGED <<delivered, edits, deletes, restores, cascades, backfills,
                   replays>>

Next ==
    \/ \E d \in Devices, i \in Ids :
         Edit(d, i) \/ SoftDelete(d, i) \/ Restore(d, i)
    \/ \E d \in Devices :
         \/ Cascade(d) \/ Backfill(d) \/ Replay(d)
         \/ Receive(d) \/ Redeliver(d)

Spec == Init /\ [][Next]_vars /\ \A d \in Devices : WF_vars(Receive(d))

------------------------------------------------------------------------------
(* Properties *)

TypeOK ==
    /\ row \in [Devices -> [Ids -> Rows]]
    /\ log \subseteq Msgs
    /\ delivered \in [Devices -> SUBSET Msgs]
    /\ edits \in 0..EditBudget /\ deletes \in 0..DeleteBudget
    /\ restores \in 0..RestoreBudget /\ cascades \in 0..CascadeBudget
    /\ backfills \in 0..BackfillBudget /\ replays \in 0..ReplayBudget

(* Every message has reached every other device. *)
Quiescent == \A d \in Devices, m \in log : m.from = d \/ m \in delivered[d]

Converged == Quiescent => \A d, e \in Devices : row[d] = row[e]

(* The revision every device must end on: the greatest one written. *)
Winner(i) ==
    IF hist[i] = {} THEN None
    ELSE CHOOSE r \in hist[i] : \A o \in hist[i] : o = r \/ Newer(r, o)

(* Every device ends on the greatest revision written: a newer restore    *)
(* beats an older delete and the reverse, a replayed or late older copy   *)
(* changes nothing, and nothing deleted comes back without a newer write. *)
LatestWins == Quiescent => \A d \in Devices, i \in Ids :
                             row[d][i] = Winner(i)

(* No device ends with a live model whose provider is deleted or missing: *)
(* it would be listed, and fail every request routed to it.               *)
NoDanglingModel == Quiescent => \A d \in Devices, x \in Models :
                                  Live(row[d][x]) => Live(row[d][Provider])

EventuallyConverged == <>[](\A d, e \in Devices : row[d] = row[e])
=============================================================================

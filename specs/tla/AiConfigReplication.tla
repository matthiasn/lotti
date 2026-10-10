------------------------ MODULE AiConfigReplication ------------------------
(***************************************************************************)
(* AI configurations across devices: an inference provider and the models *)
(* that point at it, as AiConfigRepository writes them, the aiConfig and  *)
(* aiConfigDelete messages the outbox sends, and the receive rules of     *)
(* SyncEventProcessor's apply. Profiles, prompts and skills replicate     *)
(* through the same rows and the same receive rule as the models here.    *)
(*                                                                         *)
(* Each device holds, per config id, nothing (never seen), a live row, a  *)
(* tombstone (a row with `deletedAt` set) or a deletion alone (the id's   *)
(* stamp in `ai_config_versions` with no row: a hard delete). Each        *)
(* version carries its stamp (AiConfigDb's version stamp, ADR 0094) and   *)
(* its content, abstracted to the device that wrote it. `log` is every    *)
(* message that reached the outbox; a receiver can apply any logged       *)
(* message in any order, and again (Redeliver): the outbox retries,       *)
(* catch-up re-delivers, and "Send settings" re-sends every row a device  *)
(* holds (Replay). A write and its enqueue are one step, except where the  *)
(* enqueue fails (LostEdit, LostCascade, Interrupted): the write is       *)
(* durable and its message is not. OutboxService.enqueueMessage swallows   *)
(* that failure, so before the ledger nothing recorded the owed message;   *)
(* with it, the id is owed in AiConfigSyncLedger before the message is     *)
(* staged, settled once the outbox accepts it, and Flush (flushPending)    *)
(* sends what the device holds for an owed id later. `owed` is the ledger. *)
(*                                                                         *)
(*   Edit        AiConfigRepository.saveConfig from the settings forms,  *)
(*               seeding upgrades and model-id migrations                  *)
(*   SoftDelete  AiConfigRepository.deleteConfig of a model or profile   *)
(*   Restore     AiConfigRepository.restoreConfig of one row              *)
(*   Cascade     AiConfigRepository.deleteInferenceProviderWithModels     *)
(*   Undo        the provider delete toast's undo,                        *)
(*               AiConfigRepository.restoreProviderWithModels: the       *)
(*               provider and the models its cascade took, each its own  *)
(*               message, which peers receive in any order                 *)
(*   Backfill    ModelPrepopulationService.backfillNewModels creating a   *)
(*               known model under its deterministic generateModelId      *)
(*   Replay      SyncMaintenanceRepository "Send settings": every row,   *)
(*               tombstones included, with its stamp                       *)
(*   Receive     _applySyncMessage -> saveConfig(fromSync: true), or      *)
(*               hardDeleteConfig(fromSync: true) for a hard delete        *)
(*   Interrupted a Receive whose orphan cleanup cannot send some of its   *)
(*               deletions: before OwedSends, a deletion was sent before  *)
(*               it was stored, so the orphan whose send failed stayed    *)
(*               live and the message stayed unprocessed, to come again;  *)
(*               with it, every deletion is stored, the ones not sent are  *)
(*               owed, and the message is done                             *)
(*   Crashed     a Receive that dies after the row is written and before  *)
(*               the cleanup; the message stays unprocessed and comes      *)
(*               again                                                     *)
(*   LostEdit    an Edit whose enqueue fails                                *)
(*   LostCascade a Cascade whose hard deletes the outbox refuses: the rows *)
(*               are gone here, and Replay has no row to re-send them from *)
(*   Flush       AiConfigRepository.flushPending: an owed message reaches  *)
(*               the outbox                                                *)
(*                                                                         *)
(* The switches are the fixes; FALSE is the code before them. The first   *)
(* four are AiConfigDb's version stamps (#4537); the rest are #4522's.    *)
(*   OrderLiveRows    an incoming live row is applied only when it beats *)
(*                    the held version (stamp, then a deletion over a     *)
(*                    row, then content); before, it overwrote any live   *)
(*                    row and was screened only against a local           *)
(*                    tombstone's stamp                                    *)
(*   OrderTombstones  an incoming tombstone or deletion obeys the same   *)
(*                    order; before, it was applied whatever it met       *)
(*   MonotonicStamps  a local write stamps past the version it replaces; *)
(*                    before, many writers left the caller's stamp        *)
(*   StampedDeletes   a hard delete leaves its stamp behind; before, it  *)
(*                    left nothing, and any older copy brought the row   *)
(*                    back                                                 *)
(*   CascadeOnReceive a receiver deletes, and sends the deletion of, its  *)
(*                    live models of a deleted provider whenever a        *)
(*                    provider's or a model's message lands               *)
(*   KeepNewerModels  ... only the models not newer than the provider's  *)
(*                    deletion; before, every live one, including a       *)
(*                    restore written after the deletion                   *)
(*   OrphanAtProviderStamp  that deletion carries the provider deletion's *)
(*                    stamp, so every device writes the same one; before, *)
(*                    the receiver's clock, past the model's               *)
(*   UndoPastProvider the undo stamps each model it restores no earlier   *)
(*                    than the provider it restores, so past the provider *)
(*                    deletion; before, each only past its own deletion   *)
(*   CreateAtProviderStamp  a model created on a device (the backfill) is *)
(*                    stamped with its provider's stamp, not the clock    *)
(*   ResumeOnReplay   the cleanup runs on every delivery, including one  *)
(*                    that changes no row; before, only on one that did   *)
(*   BackfillSkipsDeletions  the backfill leaves alone a model id this    *)
(*                    device holds a deletion of; before, a hard delete   *)
(*                    left no row, so it read as missing and came back    *)
(*   OwedSends        a write's message is owed until the outbox accepts  *)
(*                    it, and flushed later if it did not; before, a      *)
(*                    failed enqueue lost the message for good            *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS N, Provider, Models, Backfilled, MaxStamp,
          EditBudget, DeleteBudget, RestoreBudget, CascadeBudget,
          BackfillBudget, ReplayBudget, UndoBudget, FailBudget,
          OrderLiveRows, OrderTombstones, MonotonicStamps, StampedDeletes,
          CascadeOnReceive, KeepNewerModels, OrphanAtProviderStamp,
          UndoPastProvider, CreateAtProviderStamp, ResumeOnReplay,
          BackfillSkipsDeletions, OwedSends

Devices == 1..N
Ids == {Provider} \cup Models
Stamps == 1..MaxStamp
Kinds == {"none", "live", "tomb", "gone"}
None == [k |-> "none", s |-> 0, c |-> 0]
Gone(s) == [k |-> "gone", s |-> s, c |-> 0]
Max(a, b) == IF a >= b THEN a ELSE b

(* The rows every device starts with: the provider and its models, synced *)
(* long ago. The backfilled model does not exist anywhere yet.            *)
InitialRow(i) == IF i = Backfilled THEN None
                 ELSE [k |-> "live", s |-> 1, c |-> 0]

(* A message: a row (aiConfig, deletedAt set for a tombstone), or a hard  *)
(* delete (aiConfigDelete(hardDelete: true)), which carries its stamp but *)
(* no row; before StampedDeletes, not even the stamp.                      *)
Rows == [k : Kinds, s : Nat, c : 0..N]
Msgs == [t : {"row", "hard"}, from : Devices, id : Ids, r : Rows]

(* `user` holds the model revisions a user wrote one row at a time (an    *)
(* edit, or a restore of that model): the only ones allowed to outlive    *)
(* their provider's deletion. `taken` is what each device's last cascade *)
(* took, for its undo; `undos` records every undo, for UndoSticks.        *)
(* `owed` holds the messages whose enqueue failed and that the ledger      *)
(* still owes; without OwedSends such a message is simply lost.           *)
VARIABLES row, log, owed, delivered, hist, user, taken, undos,
          edits, deletes, restores, cascades, backfills, replays, fails

vars == <<row, log, owed, delivered, hist, user, taken, undos,
          edits, deletes, restores, cascades, backfills, replays, fails>>

Init ==
    /\ row = [d \in Devices |-> [i \in Ids |-> InitialRow(i)]]
    /\ log = {}
    /\ owed = {}
    /\ delivered = [d \in Devices |-> {}]
    /\ hist = [i \in Ids |-> IF i = Backfilled THEN {} ELSE {InitialRow(i)}]
    /\ user = {}
    /\ taken = [d \in Devices |-> {}]
    /\ undos = {}
    /\ edits = 0 /\ deletes = 0 /\ restores = 0 /\ cascades = 0
    /\ backfills = 0 /\ replays = 0 /\ fails = 0

Live(r) == r.k = "live"
Tomb(r) == r.k = "tomb"
Deleted(r) == r.k \in {"tomb", "gone"}

(* A held deletion wins a tie with any row (AiConfigDb.applyConfigVersion *)
(* and applyConfigDeletion). Two rows with one stamp are ordered by their *)
(* content, the payload without its credential; `c`, then the tombstone   *)
(* flag, stands in for that order here.                                   *)
Rank(k) == IF k = "gone" THEN 1 ELSE 0
Content(r) == 2 * r.c + (IF Tomb(r) THEN 1 ELSE 0)

Newer(a, b) ==
    \/ a.s > b.s
    \/ a.s = b.s /\ Rank(a.k) > Rank(b.k)
    \/ a.s = b.s /\ Rank(a.k) = Rank(b.k) /\ Content(a) > Content(b)

(* The stamp of a local write that replaces `prev`, at clock `now`.       *)
StampPast(now, prev) == IF MonotonicStamps THEN Max(now, prev.s + 1) ELSE now

Send(d, i, r) == [t |-> "row", from |-> d, id |-> i, r |-> r]
SendHard(d, i, r) == [t |-> "hard", from |-> d, id |-> i, r |-> r]

(* A model revision a user wrote on its own. *)
UserRow(i, r) == IF i \in Models THEN {<<i, r>>} ELSE {}

------------------------------------------------------------------------------
(* Local writes. Each writes its row and enqueues it in one step. *)

Write(d, i, r) ==
    /\ row' = [row EXCEPT ![d][i] = r]
    /\ log' = log \cup {Send(d, i, r)}
    /\ hist' = [hist EXCEPT ![i] = @ \cup {r}]

Edit(d, i) ==
    /\ edits < EditBudget /\ Live(row[d][i])
    /\ \E now \in Stamps :
         LET r == [k |-> "live", s |-> StampPast(now, row[d][i]), c |-> d]
         IN Write(d, i, r) /\ user' = user \cup UserRow(i, r)
    /\ edits' = edits + 1
    /\ UNCHANGED <<owed, delivered, taken, undos, deletes, restores, cascades,
                   backfills, replays, fails>>

SoftDelete(d, m) ==
    /\ deletes < DeleteBudget /\ m \in Models /\ Live(row[d][m])
    /\ \E now \in Stamps :
         Write(d, m, [k |-> "tomb", s |-> StampPast(now, row[d][m]), c |-> d])
    /\ deletes' = deletes + 1
    /\ UNCHANGED <<owed, delivered, user, taken, undos, edits, restores, cascades,
                   backfills, replays, fails>>

(* restoreConfig clears `deletedAt`, stamped past the tombstone. A hard   *)
(* deletion has no row to restore.                                        *)
Restore(d, i) ==
    /\ restores < RestoreBudget /\ Tomb(row[d][i])
    /\ \E now \in Stamps :
         LET r == [k |-> "live", s |-> StampPast(now, row[d][i]), c |-> d]
         IN Write(d, i, r) /\ user' = user \cup UserRow(i, r)
    /\ restores' = restores + 1
    /\ UNCHANGED <<owed, delivered, taken, undos, edits, deletes, cascades,
                   backfills, replays, fails>>

(* The provider's live models on d. The cascade reads live rows only.     *)
LiveModels(d) == {m \in Models : Live(row[d][m])}

(* The cascade hard-deletes the provider and its live models in one       *)
(* transaction and sends a hard delete for each.                          *)
Cascade(d) ==
    /\ cascades < CascadeBudget /\ Live(row[d][Provider])
    /\ \E now \in Stamps :
         LET gone == LiveModels(d) \cup {Provider}
             del(i) == IF StampedDeletes
                       THEN Gone(StampPast(now, row[d][i])) ELSE None
         IN /\ taken' = [taken EXCEPT ![d] = gone]
            /\ row' = [row EXCEPT ![d] =
                   [i \in Ids |-> IF i \in gone THEN del(i) ELSE @[i]]]
            /\ log' = log \cup {SendHard(d, i, del(i)) : i \in gone}
            /\ hist' = IF StampedDeletes
                       THEN [i \in Ids |->
                               IF i \in gone THEN hist[i] \cup {del(i)}
                               ELSE hist[i]]
                       ELSE hist
    /\ cascades' = cascades + 1
    /\ UNCHANGED <<owed, delivered, user, undos, edits, deletes, restores,
                   backfills, replays, fails>>

(* The toast's undo on the device that cascaded: the provider and every   *)
(* model the cascade took, re-saved one after the other, each sent as its *)
(* own message. A model is stamped past its own deletion and, with the    *)
(* fix, no earlier than the provider it restores with it.                 *)
Undo(d) ==
    /\ Cardinality(undos) < UndoBudget /\ taken[d] # {}
    /\ \E now \in Stamps :
         LET ms == taken[d] \ {Provider}
             rp == [k |-> "live", s |-> StampPast(now, row[d][Provider]),
                    c |-> d]
             rm(x) == [k |-> "live",
                       s |-> IF UndoPastProvider
                             THEN Max(StampPast(now, row[d][x]), rp.s)
                             ELSE StampPast(now, row[d][x]),
                       c |-> d]
             new(i) == IF i = Provider THEN rp ELSE rm(i)
         IN /\ row' = [row EXCEPT ![d] =
                   [i \in Ids |-> IF i \in taken[d] THEN new(i) ELSE @[i]]]
            /\ log' = log \cup {Send(d, i, new(i)) : i \in taken[d]}
            /\ hist' = [i \in Ids |->
                   IF i \in taken[d] THEN hist[i] \cup {new(i)} ELSE hist[i]]
            /\ undos' = undos \cup {[p |-> rp, m |-> [x \in ms |-> rm(x)]]}
    /\ taken' = [taken EXCEPT ![d] = {}]
    /\ UNCHANGED <<owed, delivered, user, edits, deletes, restores, cascades,
                   backfills, replays, fails>>

(* Only a live provider is backfilled, and only a model id this device    *)
(* has never held a version of; before BackfillSkipsDeletions, also one   *)
(* it holds a hard deletion of, which has no row. A model never held      *)
(* takes, with the fix, its provider's stamp; a deleted one is stamped    *)
(* past its deletion.                                                      *)
Backfill(d) ==
    /\ backfills < BackfillBudget
    /\ Live(row[d][Provider])
    /\ row[d][Backfilled].k \in IF BackfillSkipsDeletions THEN {"none"}
                                ELSE {"none", "gone"}
    /\ \E now \in Stamps :
         Write(d, Backfilled,
               [k |-> "live",
                s |-> IF CreateAtProviderStamp /\ row[d][Backfilled].k = "none"
                      THEN row[d][Provider].s
                      ELSE StampPast(now, row[d][Backfilled]),
                c |-> d])
    /\ backfills' = backfills + 1
    /\ UNCHANGED <<owed, delivered, user, taken, undos, edits, deletes, restores,
                   cascades, replays, fails>>

(* "Send settings" re-sends the stored rows; a hard deletion has none.    *)
Replay(d) ==
    /\ replays < ReplayBudget
    /\ log' = log \cup {Send(d, i, row[d][i]) : i \in {j \in Ids :
                                         row[d][j].k \in {"live", "tomb"}}}
    /\ replays' = replays + 1
    /\ UNCHANGED <<owed, row, delivered, hist, user, taken, undos, edits, deletes,
                   restores, cascades, backfills, fails>>

------------------------------------------------------------------------------
(* Receiving *)

(* Whether an incoming version replaces what device d holds for id i. *)
Accepts(d, i, r) ==
    LET cur == row[d][i] IN
    IF cur.k = "none" THEN TRUE
    ELSE IF Live(r)
         THEN IF OrderLiveRows THEN Newer(r, cur)
              \* the stale-replay screen: only against a deletion, by stamp
              ELSE ~(Deleted(cur) /\ r.s <= cur.s)
         ELSE IF OrderTombstones THEN Newer(r, cur) ELSE TRUE

(* The version device d holds for i after applying message m. A hard     *)
(* delete without its stamp always removes the row and leaves nothing.    *)
Applied(d, m) ==
    IF m.t = "hard" /\ ~StampedDeletes THEN None
    ELSE IF Accepts(d, m.id, m.r) THEN m.r ELSE row[d][m.id]

After(d, m) == [row[d] EXCEPT ![m.id] = Applied(d, m)]

(* Whether the delivery runs the orphan cleanup: a row of the provider or *)
(* of a model, or the provider's hard delete (a model's hard delete names *)
(* no provider). With the fix, every such delivery; before, only one that *)
(* changed the row.                                                        *)
Cleans(d, m) ==
    /\ m.t = "row" \/ m.id = Provider
    /\ ResumeOnReplay \/ Applied(d, m) # row[d][m.id]

(* The models the receiver deletes once `after` is its state             *)
(* (_deleteOrphanedModels): the live models of a deleted provider; with  *)
(* the fix, only those not newer than the provider's deletion.            *)
Orphans(d, m) ==
    LET after == After(d, m) IN
    IF CascadeOnReceive /\ Cleans(d, m) /\ Deleted(after[Provider])
    THEN {x \in Models : /\ Live(after[x])
                         /\ ~KeepNewerModels \/ after[x].s <= after[Provider].s}
    ELSE {}

(* The orphan's deletion: the provider deletion's stamp with the fix, so  *)
(* every device writes the same one; before, the receiver's clock, past   *)
(* the model.                                                             *)
OrphanDel(x, after, now) ==
    IF OrphanAtProviderStamp THEN Gone(after[Provider].s)
    ELSE Gone(StampPast(now, after[x]))

Nows == IF OrphanAtProviderStamp THEN {1} ELSE Stamps

(* Apply m on d, writing (and sending) the deletions of `done`. *)
ApplyWith(d, m, now, done) ==
    LET after == After(d, m)
        del(i) == OrphanDel(i, after, now)
    IN /\ row' = [row EXCEPT ![d] =
              [i \in Ids |-> IF i \in done THEN del(i) ELSE after[i]]]
       /\ log' = log \cup {SendHard(d, i, del(i)) : i \in done}
       /\ hist' = [i \in Ids |->
              IF i \in done THEN hist[i] \cup {del(i)} ELSE hist[i]]

Apply(d, m) == \E now \in Nows : ApplyWith(d, m, now, Orphans(d, m))

Receive(d) ==
    /\ \E m \in log :
         /\ m.from # d /\ m \notin delivered[d]
         /\ Apply(d, m)
         /\ delivered' = [delivered EXCEPT ![d] = @ \cup {m}]
    /\ UNCHANGED <<owed, user, taken, undos, edits, deletes, restores,
                   cascades, backfills, replays, fails>>

(* Apply m on d, writing every orphan's deletion; those in `failed` could  *)
(* not be sent and are owed instead of logged.                            *)
ApplyOwing(d, m, now, failed) ==
    LET after == After(d, m)
        orphans == Orphans(d, m)
        del(i) == OrphanDel(i, after, now)
    IN /\ row' = [row EXCEPT ![d] =
              [i \in Ids |-> IF i \in orphans THEN del(i) ELSE after[i]]]
       /\ log' = log \cup {SendHard(d, i, del(i)) : i \in orphans \ failed}
       /\ owed' = owed \cup {SendHard(d, i, del(i)) : i \in failed}
       /\ hist' = [i \in Ids |->
              IF i \in orphans THEN hist[i] \cup {del(i)} ELSE hist[i]]

(* The cleanup cannot send some of its orphans' deletions. Before          *)
(* OwedSends, an orphan's deletion was sent before it was stored, so the  *)
(* one that failed stayed live and the message was not marked processed,  *)
(* to come again. With OwedSends every deletion is stored, the ones not   *)
(* sent are owed, and the message is done.                                *)
Interrupted(d) ==
    /\ fails < FailBudget
    /\ \E m \in log, now \in Nows :
         /\ m.from # d /\ m \notin delivered[d]
         /\ IF OwedSends
            THEN \E failed \in SUBSET Orphans(d, m) :
                   /\ failed # {}
                   /\ ApplyOwing(d, m, now, failed)
                   /\ delivered' = [delivered EXCEPT ![d] = @ \cup {m}]
            ELSE \E done \in SUBSET Orphans(d, m) :
                   /\ done # Orphans(d, m)
                   /\ ApplyWith(d, m, now, done)
                   /\ UNCHANGED <<owed, delivered>>
    /\ fails' = fails + 1
    /\ UNCHANGED <<user, taken, undos, edits, deletes, restores, cascades,
                   backfills, replays>>

(* The receive dies after the row is written and before the cleanup. The  *)
(* message is not marked processed, so it comes again.                    *)
Crashed(d) ==
    /\ fails < FailBudget
    /\ \E m \in log :
         /\ m.from # d /\ m \notin delivered[d]
         /\ ApplyWith(d, m, 1, {})
    /\ fails' = fails + 1
    /\ UNCHANGED <<owed, delivered, user, taken, undos, edits, deletes,
                   restores, cascades, backfills, replays>>

(* The outbox's retry or a catch-up re-delivers a message already applied *)
Redeliver(d) ==
    /\ \E m \in delivered[d] : Apply(d, m)
    /\ UNCHANGED <<owed, delivered, user, taken, undos, edits, deletes,
                   restores, cascades, backfills, replays, fails>>

------------------------------------------------------------------------------
(* The enqueue that fails. The write is durable here; with OwedSends its  *)
(* message is owed, without it the message is lost.                       *)

Stage(msgs) == IF OwedSends THEN owed \cup msgs ELSE owed

LostEdit(d, i) ==
    /\ fails < FailBudget /\ edits < EditBudget /\ Live(row[d][i])
    /\ \E now \in Stamps :
         LET r == [k |-> "live", s |-> StampPast(now, row[d][i]), c |-> d]
         IN /\ row' = [row EXCEPT ![d][i] = r]
            /\ hist' = [hist EXCEPT ![i] = @ \cup {r}]
            /\ owed' = Stage({Send(d, i, r)})
            /\ user' = user \cup UserRow(i, r)
    /\ edits' = edits + 1 /\ fails' = fails + 1
    /\ UNCHANGED <<log, delivered, taken, undos, deletes, restores, cascades,
                   backfills, replays>>

(* The cascade's hard deletes never reach the outbox. Replay cannot repair *)
(* them: a hard deletion has no row to re-send.                           *)
LostCascade(d) ==
    /\ fails < FailBudget /\ cascades < CascadeBudget
    /\ Live(row[d][Provider]) /\ StampedDeletes
    /\ \E now \in Stamps :
         LET gone == LiveModels(d) \cup {Provider}
             del(i) == Gone(StampPast(now, row[d][i]))
         IN /\ taken' = [taken EXCEPT ![d] = gone]
            /\ row' = [row EXCEPT ![d] =
                   [i \in Ids |-> IF i \in gone THEN del(i) ELSE @[i]]]
            /\ owed' = Stage({SendHard(d, i, del(i)) : i \in gone})
            /\ hist' = [i \in Ids |->
                   IF i \in gone THEN hist[i] \cup {del(i)} ELSE hist[i]]
    /\ cascades' = cascades + 1 /\ fails' = fails + 1
    /\ UNCHANGED <<log, delivered, user, undos, edits, deletes, restores,
                   backfills, replays>>

(* flushPending: an owed message reaches the outbox. The code sends what   *)
(* the device holds for the id by then; a later write of the id was owed  *)
(* and logged in its own right, so the owed message itself is sent here   *)
(* and an older one is dropped by every receiver's stamp order.           *)
Flush(d) ==
    /\ \E m \in owed :
         /\ m.from = d
         /\ log' = log \cup {m}
         /\ owed' = owed \ {m}
    /\ UNCHANGED <<row, delivered, hist, user, taken, undos, edits, deletes,
                   restores, cascades, backfills, replays, fails>>

Next ==
    \/ \E d \in Devices, i \in Ids :
         Edit(d, i) \/ SoftDelete(d, i) \/ Restore(d, i) \/ LostEdit(d, i)
    \/ \E d \in Devices :
         \/ Cascade(d) \/ Undo(d) \/ Backfill(d) \/ Replay(d)
         \/ Receive(d) \/ Interrupted(d) \/ Crashed(d) \/ Redeliver(d)
         \/ LostCascade(d) \/ Flush(d)

Spec == Init /\ [][Next]_vars
        /\ \A d \in Devices : WF_vars(Receive(d)) /\ WF_vars(Flush(d))

------------------------------------------------------------------------------
(* Properties *)

TypeOK ==
    /\ row \in [Devices -> [Ids -> Rows]]
    /\ log \subseteq Msgs
    /\ owed \subseteq Msgs
    /\ delivered \in [Devices -> SUBSET Msgs]
    /\ taken \in [Devices -> SUBSET Ids]
    /\ edits \in 0..EditBudget /\ deletes \in 0..DeleteBudget
    /\ restores \in 0..RestoreBudget /\ cascades \in 0..CascadeBudget
    /\ backfills \in 0..BackfillBudget /\ replays \in 0..ReplayBudget
    /\ fails \in 0..FailBudget /\ Cardinality(undos) \in 0..UndoBudget

(* Nothing is owed, and every message has reached every other device. *)
Quiescent ==
    /\ owed = {}
    /\ \A d \in Devices, m \in log : m.from = d \/ m \in delivered[d]

Converged == Quiescent => \A d, e \in Devices : row[d] = row[e]

(* The version every device must end on: the greatest one written. *)
Winner(i) ==
    IF hist[i] = {} THEN None
    ELSE CHOOSE r \in hist[i] : \A o \in hist[i] : o = r \/ Newer(r, o)

(* Every device ends on the greatest version written: a newer restore     *)
(* beats an older delete and the reverse, a replayed or late older copy   *)
(* changes nothing, and nothing deleted comes back without a newer write. *)
LatestWins == Quiescent => \A d \in Devices, i \in Ids :
                             row[d][i] = Winner(i)

(* No device ends with a live model whose provider is deleted or missing: *)
(* it would be listed, and fail every request routed to it. The one       *)
(* exception is a user's own edit or restore of that model stamped after  *)
(* the provider's deletion: a device that had not heard of the deletion   *)
(* wrote it later, and deleting it would discard that write.              *)
NoDanglingModel == Quiescent => \A d \in Devices, x \in Models :
                     Live(row[d][x]) =>
                       \/ Live(row[d][Provider])
                       \/ /\ <<x, row[d][x]>> \in user
                          /\ row[d][x].s > row[d][Provider].s

(* An undo sticks: where the provider ends on the version an undo wrote,  *)
(* every model that undo restored is live. (The configurations that check *)
(* it delete no model on its own.)                                        *)
UndoSticks == Quiescent => \A u \in undos, d \in Devices :
                row[d][Provider] = u.p =>
                  \A x \in DOMAIN u.m : Live(row[d][x])

EventuallyConverged == <>[](\A d, e \in Devices : row[d] = row[e])
=============================================================================

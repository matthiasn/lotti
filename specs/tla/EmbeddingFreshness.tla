------------------------ MODULE EmbeddingFreshness ------------------------
(***************************************************************************)
(* The local vector index keeping up with the journal: EmbeddingService,  *)
(* the manual EmbeddingBackfillController and the task agent's report     *)
(* writer all feed one ShardedEmbeddingStore, one category shard per      *)
(* category, through EmbeddingProcessor. The store is a regenerable local *)
(* cache: nothing repairs it except the next processing of an id, so a    *)
(* stale or orphaned vector stays until that entry is edited again.       *)
(*                                                                         *)
(* A journal entity has a text (Short stands for any text under the 20-   *)
(* character minimum), a deleted flag and a category. The store holds, per*)
(* key and shard, the text a vector was made from (its content hash), the *)
(* in-memory primary index (`idx`) and which shard was written last       *)
(* (`newest`, the chunks' createdAt). One report of the task agent is a    *)
(* second kind of key, stored in its task's category.                     *)
(*                                                                         *)
(*   Edit/Shorten/Delete/Recat  a local journal write; its notification on*)
(*                  localUpdateStream adds the id to the pending set       *)
(*   SyncEdit       an edit that arrives by sync (syncUpdateStream): the   *)
(*                  service never hears of it. A residual; see README      *)
(*   Take           EmbeddingService._processNext takes an id and removes  *)
(*                  it from the pending set before processing it           *)
(*   BackfillStart/ EmbeddingBackfillController.backfillCategories and     *)
(*   BackfillTake   _processEntities, one id at a time                     *)
(*   Acquire..Finish EmbeddingProcessor.processEntity for either actor:    *)
(*     Read         journalEntityById, the length check, getCategoryId,    *)
(*                  getContentHash, and the hash-equal move                *)
(*                  (moveEntityToShard) as one step                        *)
(*     Embed(Fail)  OllamaEmbeddingRepository.embed over the network; down *)
(*                  means the outage cooldown, where every call fails fast *)
(*                  with EmbeddingEndpointUnavailableException             *)
(*     Write        ShardedEmbeddingStore.replaceEntityEmbeddings: the new *)
(*                  shard first, then the old copy deleted                 *)
(*     Reports      moveRelatedReportEmbeddings to the category read       *)
(*   Ag*            TaskAgentPersistenceHelpers._embedAgentReport and      *)
(*                  EmbeddingProcessor.processAgentReport: the task's      *)
(*                  category, the hash check, the embedding, the write     *)
(*   RetryFire      the service's retry timer at the cooldown's retryAt    *)
(*   Outage/Recover the endpoint's circuit (ollama_embedding_repository)   *)
(*   Crash          process death and ShardedEmbeddingStore.open's         *)
(*                  _rebuildIndexes; CrashMidWrite dies between the two    *)
(*                  halves of a replace, leaving the key in two shards.    *)
(*                  The pending and retry sets live in memory, so the ghost*)
(*                  `lost` excuses the ids a crash drops until their next  *)
(*                  local change                                           *)
(*                                                                         *)
(* The switches are the fixes; FALSE is the code before them:             *)
(*   SerializeEntity    processEntity holds a per-entity lock from its     *)
(*                      journal read to its store write, so a slow run     *)
(*                      cannot land a read older than a later run's        *)
(*   RequeueFailures    an id whose embedding failed is kept and retried   *)
(*                      when the cooldown ends, instead of dropped         *)
(*   DropStale          a deleted entry, or one whose text fell under the  *)
(*                      minimum, has its vectors deleted                   *)
(*   ReportUnderTaskLock the report writer reads the task's category and   *)
(*                      writes under the task's lock                       *)
(*   ReconcileReports   every processing of a task moves its reports to   *)
(*                      its category, not only when the task's own vector  *)
(*                      moved                                              *)
(*   RecoverNewest      the rebuild keeps the copy written last (createdAt)*)
(*                      rather than the shard whose name sorts last        *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS Entities, Task, Report, Texts, Short, ReportText, Cats, LastCat,
          EditBudget, RecatBudget, DeleteBudget, SyncBudget, OutageBudget,
          CrashBudget, BackfillBudget, ReportBudget,
          SerializeEntity, RequeueFailures, DropStale, ReportUnderTaskLock,
          ReconcileReports, RecoverNewest

None == "none"
Free == "free"
Keys == Entities \cup {Report}
Actors == {"svc", "bf"}
Holders == Actors \cup {"ag"}
AllTexts == Texts \cup {Short, ReportText}

VARIABLES jtext, jdel, jcat,            \* the journal
          copies, idx, newest, lastPut, \* the store; lastPut is a ghost
          pend, retry, job, bfTodo, ag, lock, up,
          edits, recats, dels, syncs, outages, crashes, bfRuns, reports,
          lost                          \* ghost: ids a crash dropped

vars == <<jtext, jdel, jcat, copies, idx, newest, lastPut, pend, retry, job,
          bfTodo, ag, lock, up, edits, recats, dels, syncs, outages, crashes,
          bfRuns, reports, lost>>

InitText == CHOOSE t \in Texts : TRUE
\* Entities start in the shard whose name sorts last, so one recategorising
\* write is enough to leave an older copy where the rebuild used to look.
InitCat == LastCat

Idle == [k |-> Task, pc |-> "idle", t |-> None, c |-> None, chg |-> FALSE]
AgIdle == [pc |-> "idle", c |-> None]

(* Every entity starts embedded and fresh; the report does not exist yet. *)
Init ==
    /\ jtext = [e \in Entities |-> InitText]
    /\ jdel = [e \in Entities |-> FALSE]
    /\ jcat = [e \in Entities |-> InitCat]
    /\ copies = [k \in Keys |-> [c \in Cats |->
            IF k \in Entities /\ c = InitCat THEN InitText ELSE None]]
    /\ idx = [k \in Keys |-> IF k \in Entities THEN InitCat ELSE None]
    /\ newest = idx
    /\ lastPut = [k \in Keys |-> IF k \in Entities THEN InitText ELSE None]
    /\ pend = {} /\ retry = {}
    /\ job = [a \in Actors |-> Idle]
    /\ bfTodo = {}
    /\ ag = AgIdle
    /\ lock = [e \in Entities |-> Free]
    /\ up = TRUE
    /\ edits = 0 /\ recats = 0 /\ dels = 0 /\ syncs = 0
    /\ outages = 0 /\ crashes = 0 /\ bfRuns = 0 /\ reports = 0
    /\ lost = {}

Live(e) == ~jdel[e] /\ jtext[e] # Short

------------------------------------------------------------------------------
(* The user, on this device and elsewhere *)

UserVars == <<copies, idx, newest, lastPut, retry, job, bfTodo, ag, lock, up,
              outages, crashes, bfRuns, reports>>

(* A new notification makes an id the service's again, even after a crash *)
(* dropped the previous one.                                              *)
Notify(e) == pend' = pend \cup {e} /\ lost' = lost \ {e}

Edit(e) ==
    /\ ~jdel[e] /\ edits < EditBudget
    /\ \E t \in Texts \cup {Short} :
         /\ t # jtext[e]
         /\ jtext' = [jtext EXCEPT ![e] = t]
    /\ edits' = edits + 1
    /\ Notify(e)
    /\ UNCHANGED <<jdel, jcat, recats, dels, syncs>> /\ UNCHANGED UserVars

Delete(e) ==
    /\ ~jdel[e] /\ dels < DeleteBudget
    /\ jdel' = [jdel EXCEPT ![e] = TRUE]
    /\ dels' = dels + 1
    /\ Notify(e)
    /\ UNCHANGED <<jtext, jcat, edits, recats, syncs>> /\ UNCHANGED UserVars

Recat(e) ==
    /\ ~jdel[e] /\ recats < RecatBudget
    /\ \E c \in Cats : c # jcat[e] /\ jcat' = [jcat EXCEPT ![e] = c]
    /\ recats' = recats + 1
    /\ Notify(e)
    /\ UNCHANGED <<jtext, jdel, edits, dels, syncs>> /\ UNCHANGED UserVars

(* A synced edit notifies only syncUpdateStream, which the service ignores. *)
SyncEdit(e) ==
    /\ ~jdel[e] /\ syncs < SyncBudget
    /\ \E t \in Texts : t # jtext[e] /\ jtext' = [jtext EXCEPT ![e] = t]
    /\ syncs' = syncs + 1
    /\ UNCHANGED <<jdel, jcat, edits, recats, dels, pend, lost>>
    /\ UNCHANGED UserVars

------------------------------------------------------------------------------
(* Taking work *)

Take ==
    /\ job["svc"].pc = "idle" /\ pend # {}
    /\ \E e \in pend :
         /\ pend' = pend \ {e}
         /\ job' = [job EXCEPT !["svc"] = [Idle EXCEPT !.k = e, !.pc = "lock"]]
    /\ UNCHANGED <<jtext, jdel, jcat, copies, idx, newest, lastPut, retry,
                   bfTodo, ag, lock, up, edits, recats, dels, syncs, outages,
                   crashes, bfRuns, reports, lost>>

RetryFire ==
    /\ retry # {}
    /\ pend' = pend \cup retry
    /\ retry' = {}
    /\ UNCHANGED <<jtext, jdel, jcat, copies, idx, newest, lastPut, job,
                   bfTodo, ag, lock, up, edits, recats, dels, syncs, outages,
                   crashes, bfRuns, reports, lost>>

BackfillStart ==
    /\ bfRuns < BackfillBudget /\ bfTodo = {} /\ job["bf"].pc = "idle"
    /\ bfTodo' = {e \in Entities : ~jdel[e]}
    /\ bfRuns' = bfRuns + 1
    /\ UNCHANGED <<jtext, jdel, jcat, copies, idx, newest, lastPut, pend,
                   retry, job, ag, lock, up, edits, recats, dels, syncs,
                   outages, crashes, reports, lost>>

BackfillTake ==
    /\ job["bf"].pc = "idle" /\ bfTodo # {}
    /\ \E e \in bfTodo :
         /\ bfTodo' = bfTodo \ {e}
         /\ job' = [job EXCEPT !["bf"] = [Idle EXCEPT !.k = e, !.pc = "lock"]]
    /\ UNCHANGED <<jtext, jdel, jcat, copies, idx, newest, lastPut, pend,
                   retry, ag, lock, up, edits, recats, dels, syncs, outages,
                   crashes, bfRuns, reports, lost>>

------------------------------------------------------------------------------
(* EmbeddingProcessor.processEntity, for the service and the backfill *)

JobVars == <<jtext, jdel, jcat, pend, bfTodo, ag, up, edits, recats, dels,
             syncs, outages, crashes, bfRuns, reports, lost>>

SetPc(a, pc) == job' = [job EXCEPT ![a].pc = pc]

Release(e, h) ==
    lock' = IF lock[e] = h THEN [lock EXCEPT ![e] = Free] ELSE lock

Finish(a) ==
    /\ job' = [job EXCEPT ![a] = Idle]
    /\ Release(job[a].k, a)

Acquire(a) ==
    /\ job[a].pc = "lock"
    /\ IF SerializeEntity
       THEN /\ lock[job[a].k] = Free
            /\ lock' = [lock EXCEPT ![job[a].k] = a]
       ELSE UNCHANGED lock
    /\ SetPc(a, "read")
    /\ UNCHANGED <<copies, idx, newest, lastPut, retry>> /\ UNCHANGED JobVars

(* After the task itself: move its reports, or stop. *)
AfterTask(a, e, c, moveReports) ==
    IF e = Task /\ moveReports
    THEN /\ job' = [job EXCEPT ![a].pc = "reports", ![a].c = c]
         /\ UNCHANGED lock
    ELSE Finish(a)

Read(a) ==
    /\ job[a].pc = "read"
    /\ LET e == job[a].k
           t == jtext[e]
           c == jcat[e]
           sc == idx[e]
           sh == IF sc = None THEN None ELSE copies[e][sc]
       IN IF ~Live(e)
          THEN \* The early return: before the fix the vectors stay.
               /\ IF DropStale /\ sc # None
                  THEN /\ copies' = [copies EXCEPT ![e][sc] = None]
                       /\ idx' = [idx EXCEPT ![e] = None]
                  ELSE UNCHANGED <<copies, idx>>
               /\ AfterTask(a, e, c, ReconcileReports /\ ~jdel[e])
               /\ UNCHANGED <<newest, lastPut>>
          ELSE IF sh = t
          THEN IF sc # c
               THEN \* moveEntityToShard, then the reports
                    /\ copies' = [copies EXCEPT ![e][c] = t, ![e][sc] = None]
                    /\ idx' = [idx EXCEPT ![e] = c]
                    /\ newest' = [newest EXCEPT ![e] = c]
                    /\ lastPut' = [lastPut EXCEPT ![e] = t]
                    /\ AfterTask(a, e, c, TRUE)
               ELSE /\ AfterTask(a, e, c, ReconcileReports)
                    /\ UNCHANGED <<copies, idx, newest, lastPut>>
          ELSE /\ job' = [job EXCEPT ![a].pc = "embed", ![a].t = t,
                                     ![a].c = c,
                                     ![a].chg = (sc # None /\ sc # c)]
               /\ UNCHANGED <<copies, idx, newest, lastPut, lock>>
    /\ UNCHANGED retry /\ UNCHANGED JobVars

Embed(a) ==
    /\ job[a].pc = "embed" /\ up
    /\ SetPc(a, "write")
    /\ UNCHANGED <<copies, idx, newest, lastPut, retry, lock>>
    /\ UNCHANGED JobVars

(* The service logged and swallowed the failure; now it keeps the id. The *)
(* backfill logs it and moves on, as it still does.                        *)
EmbedFail(a) ==
    /\ job[a].pc = "embed" /\ ~up
    /\ retry' = IF a = "svc" /\ RequeueFailures
                THEN retry \cup {job[a].k} ELSE retry
    /\ Finish(a)
    /\ UNCHANGED <<copies, idx, newest, lastPut>> /\ UNCHANGED JobVars

(* replaceEntityEmbeddings: new shard, then the copy the index names.      *)
Replace(k, c, t) ==
    /\ copies' = [copies EXCEPT ![k] = [s \in Cats |->
                                  IF s = c THEN t
                                  ELSE IF s = idx[k] THEN None
                                  ELSE copies[k][s]]]
    /\ idx' = [idx EXCEPT ![k] = c]
    /\ newest' = [newest EXCEPT ![k] = c]
    /\ lastPut' = [lastPut EXCEPT ![k] = t]

Write(a) ==
    /\ job[a].pc = "write"
    /\ LET e == job[a].k IN
       /\ Replace(e, job[a].c, job[a].t)
       /\ AfterTask(a, e, job[a].c, ReconcileReports \/ job[a].chg)
    /\ UNCHANGED retry /\ UNCHANGED JobVars

MoveTo(k, c) ==
    IF idx[k] # None /\ idx[k] # c
    THEN /\ copies' = [copies EXCEPT ![k][c] = copies[k][idx[k]],
                                     ![k][idx[k]] = None]
         /\ idx' = [idx EXCEPT ![k] = c]
         /\ newest' = [newest EXCEPT ![k] = c]
    ELSE UNCHANGED <<copies, idx, newest>>

Reports(a) ==
    /\ job[a].pc = "reports"
    /\ MoveTo(Report, job[a].c)
    /\ Finish(a)
    /\ UNCHANGED <<lastPut, retry>> /\ UNCHANGED JobVars

------------------------------------------------------------------------------
(* The task agent's report *)

AgVars == <<jtext, jdel, jcat, pend, retry, job, bfTodo, up, edits, recats,
            dels, syncs, outages, crashes, bfRuns, lost>>

AgStart ==
    /\ ag.pc = "idle" /\ reports < ReportBudget
    /\ ag' = [ag EXCEPT !.pc = "lock"]
    /\ reports' = reports + 1
    /\ UNCHANGED <<copies, idx, newest, lastPut, lock>> /\ UNCHANGED AgVars

AgAcquire ==
    /\ ag.pc = "lock"
    /\ IF ReportUnderTaskLock
       THEN /\ lock[Task] = Free
            /\ lock' = [lock EXCEPT ![Task] = "ag"]
       ELSE UNCHANGED lock
    /\ ag' = [ag EXCEPT !.pc = "read"]
    /\ UNCHANGED <<copies, idx, newest, lastPut, reports>> /\ UNCHANGED AgVars

AgFinish ==
    /\ ag' = AgIdle
    /\ Release(Task, "ag")

(* The task's category, then the report's hash check. *)
AgRead ==
    /\ ag.pc = "read"
    /\ IF jdel[Task] \/ (idx[Report] # None
                         /\ copies[Report][idx[Report]] = ReportText)
       THEN AgFinish
       ELSE /\ ag' = [pc |-> "embed", c |-> jcat[Task]]
            /\ UNCHANGED lock
    /\ UNCHANGED <<copies, idx, newest, lastPut, reports>> /\ UNCHANGED AgVars

(* A failed report embedding is logged and never retried. *)
AgEmbed ==
    /\ ag.pc = "embed"
    /\ IF up THEN /\ ag' = [ag EXCEPT !.pc = "write"]
                  /\ UNCHANGED lock
             ELSE AgFinish
    /\ UNCHANGED <<copies, idx, newest, lastPut, reports>> /\ UNCHANGED AgVars

AgWrite ==
    /\ ag.pc = "write"
    /\ Replace(Report, ag.c, ReportText)
    /\ AgFinish
    /\ UNCHANGED reports /\ UNCHANGED AgVars

------------------------------------------------------------------------------
(* The endpoint and the process *)

Outage ==
    /\ up /\ outages < OutageBudget
    /\ up' = FALSE /\ outages' = outages + 1
    /\ UNCHANGED <<jtext, jdel, jcat, copies, idx, newest, lastPut, pend,
                   retry, job, bfTodo, ag, lock, edits, recats, dels, syncs,
                   crashes, bfRuns, reports, lost>>

Recover ==
    /\ ~up /\ up' = TRUE
    /\ UNCHANGED <<jtext, jdel, jcat, copies, idx, newest, lastPut, pend,
                   retry, job, bfTodo, ag, lock, edits, recats, dels, syncs,
                   outages, crashes, bfRuns, reports, lost>>

(* _rebuildIndexes over what is on disk (`st`, with `nw` the shard each key *)
(* was written to last): one copy per key survives.                       *)
Rebuild(st, nw) ==
    LET Held(k) == {c \in Cats : st[k][c] # None}
        Kept(k) == IF Held(k) = {} THEN None
                   ELSE IF Cardinality(Held(k)) = 1
                        THEN CHOOSE c \in Held(k) : TRUE
                   ELSE IF RecoverNewest THEN nw[k]
                   ELSE LastCat   \* the shard whose name sorts last
    IN /\ idx' = [k \in Keys |-> Kept(k)]
       /\ copies' = [k \in Keys |-> [c \in Cats |->
                        IF c = Kept(k) THEN st[k][c] ELSE None]]

(* Everything in memory is gone: the pending set, the retries, the runs.   *)
(* The ghost remembers which ids nothing will process again.               *)
Restart ==
    /\ lost' = lost \cup pend \cup retry
               \cup (IF job["svc"].pc # "idle" THEN {job["svc"].k} ELSE {})
               \cup (IF ag.pc # "idle" THEN {Report} ELSE {})
    /\ pend' = {} /\ retry' = {} /\ bfTodo' = {}
    /\ job' = [a \in Actors |-> Idle]
    /\ ag' = AgIdle
    /\ lock' = [e \in Entities |-> Free]
    /\ crashes' = crashes + 1

Crash ==
    /\ crashes < CrashBudget
    /\ Restart
    /\ Rebuild(copies, newest)
    /\ UNCHANGED <<jtext, jdel, jcat, newest, lastPut, up, edits, recats,
                   dels, syncs, outages, bfRuns, reports>>

(* The process dies after a replace's new shard and before its old copy   *)
(* is deleted; the rebuild then sees the key in two shards.               *)
CrashMidWrite(k, c, t) ==
    /\ crashes < CrashBudget
    /\ newest' = [newest EXCEPT ![k] = c]
    /\ Rebuild([copies EXCEPT ![k][c] = t], newest')
    /\ lastPut' = [lastPut EXCEPT ![k] = t]
    /\ Restart
    /\ UNCHANGED <<jtext, jdel, jcat, up, edits, recats, dels, syncs,
                   outages, bfRuns, reports>>

------------------------------------------------------------------------------

Next ==
    \/ \E e \in Entities : Edit(e) \/ Delete(e) \/ Recat(e) \/ SyncEdit(e)
    \/ Take \/ RetryFire \/ BackfillStart \/ BackfillTake
    \/ \E a \in Actors :
         \/ Acquire(a) \/ Read(a) \/ Embed(a) \/ EmbedFail(a) \/ Write(a)
         \/ Reports(a)
         \/ (job[a].pc = "write" /\ CrashMidWrite(job[a].k, job[a].c,
                                                  job[a].t))
    \/ AgStart \/ AgAcquire \/ AgRead \/ AgEmbed \/ AgWrite
    \/ (ag.pc = "write" /\ CrashMidWrite(Report, ag.c, ReportText))
    \/ Outage \/ Recover \/ Crash

Fair ==
    /\ WF_vars(Take) /\ WF_vars(RetryFire) /\ WF_vars(BackfillTake)
    /\ WF_vars(Recover)
    /\ \A a \in Actors :
         /\ WF_vars(Acquire(a)) /\ WF_vars(Read(a)) /\ WF_vars(Embed(a))
         /\ WF_vars(EmbedFail(a)) /\ WF_vars(Write(a)) /\ WF_vars(Reports(a))
    /\ WF_vars(AgAcquire) /\ WF_vars(AgRead) /\ WF_vars(AgEmbed)
    /\ WF_vars(AgWrite)

Spec == Init /\ [][Next]_vars /\ Fair

------------------------------------------------------------------------------
(* Properties *)

TypeOK ==
    /\ jtext \in [Entities -> Texts \cup {Short}]
    /\ jdel \in [Entities -> BOOLEAN]
    /\ jcat \in [Entities -> Cats]
    /\ copies \in [Keys -> [Cats -> AllTexts \cup {None}]]
    /\ idx \in [Keys -> Cats \cup {None}]
    /\ pend \subseteq Entities /\ retry \subseteq Entities
    /\ bfTodo \subseteq Entities
    /\ lock \in [Entities -> Holders \cup {Free}]
    /\ lost \subseteq Keys

Quiescent ==
    /\ pend = {} /\ retry = {} /\ bfTodo = {}
    /\ \A a \in Actors : job[a].pc = "idle"
    /\ ag.pc = "idle"

Held(k) == {c \in Cats : copies[k][c] # None}

(* A live entry has exactly one vector, of its current text, in its       *)
(* category's shard; a deleted or too-short one has none.                 *)
EntryFresh(e) ==
    IF Live(e)
    THEN Held(e) = {jcat[e]} /\ copies[e][jcat[e]] = jtext[e]
         /\ idx[e] = jcat[e]
    ELSE Held(e) = {}

(* A report that was embedded sits in its task's category.               *)
ReportFresh ==
    Held(Report) # {} /\ ~jdel[Task] => Held(Report) = {jcat[Task]}

AllFresh ==
    /\ \A e \in Entities \ lost : EntryFresh(e)
    /\ Report \notin lost /\ Task \notin lost => ReportFresh

Fresh == Quiescent => AllFresh

(* The rebuild leaves each key in at most one shard. *)
OneShard == \A k \in Keys : Cardinality(Held(k)) <= 1

(* The index never points at an older copy than the last one written:     *)
(* recovery cannot revert content.                                        *)
NoRevert == \A k \in Keys : idx[k] # None => copies[k][idx[k]] = lastPut[k]

(* Once the endpoint is back for good, every local change is embedded.    *)
EventuallyFresh == <>[]AllFresh
=============================================================================

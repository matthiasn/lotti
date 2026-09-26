------------------------- MODULE ChecklistMembership -------------------------
(***************************************************************************)
(* Which checklists a task shows, and which items each checklist shows, on *)
(* one device. Membership is stored as whole lists on the parent: a task's *)
(* `TaskData.checklistIds` and a checklist's                               *)
(* `ChecklistData.linkedChecklistItems`. Readers resolve membership from   *)
(* those lists — the task page, `getChecklistItemsForTask` and the agent's *)
(* context — so an id missing from its parent's list is an item or a       *)
(* checklist the user and the agent no longer see, although its row is     *)
(* alive. Each item also names its checklist                               *)
(* (`ChecklistItemData.linkedChecklists`), which the agent's checklist     *)
(* tools read to authorise an update.                                      *)
(*                                                                         *)
(* The user (through the checklist and task screens) and the agent (through *)
(* ChecklistRepository and its task and item tools) write those rows while *)
(* sync lands newer versions of them, and the app can die between the      *)
(* writes of one operation. A screen writes from the value it holds, which *)
(* an update notification refreshes some time after the row changes; the   *)
(* repository reads the row, then writes after further awaits. Each write  *)
(* replaces the whole row under a clock built on the stored row, so the    *)
(* write decision (JournalDb.updateJournalEntity) accepts it as the newer  *)
(* version: a row built on an older value silently drops what landed in    *)
(* between. Two devices writing concurrently are JournalReplication's      *)
(* subject (the user resolves a conflict); this spec is about one device   *)
(* overwriting what it has already stored, and leaving an operation half   *)
(* done.                                                                   *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   read/commit  one write of a row: the value it is built on (the        *)
(*                screen's state, or the row the writer read), and the     *)
(*                write itself (PersistenceLogic.updateDbEntity). With a   *)
(*                switch on, the write is built on the stored row by       *)
(*                writeOnStored, under the precondition that the row is    *)
(*                still the version read; a refused write is built again   *)
(*                on the new row                                           *)
(*   uiAdd        ChecklistController.createChecklistItem                  *)
(*   uiReorder    ChecklistController.dropChecklistItem within a checklist *)
(*   uiMove       dropChecklistItem across checklists                      *)
(*                (ChecklistRepository.moveItem): the item's back-link,    *)
(*                the target's list, then the source's                     *)
(*   uiCheck      ChecklistItemController's check, title and archive       *)
(*                writes (ChecklistRepository.updateChecklistItem)         *)
(*   uiDropItem   deleting an item: ChecklistItemRow unlinks it, and       *)
(*                deletes it when the undo window closes                   *)
(*   uiDelete     ChecklistController.delete: the checklist is deleted,    *)
(*                then removed from the task's list                        *)
(*   uiTaskEdit   any task field edit that saves the whole TaskData —      *)
(*                status, priority, due date, estimate — through           *)
(*                PersistenceLogic.updateTask (updateTaskImpl)             *)
(*   uiSort       ChecklistsWidget's reorder of the task's checklists,     *)
(*                EntryController.updateChecklistOrder                     *)
(*   agAdd        ChecklistRepository.addItemToChecklist                   *)
(*   agList       ChecklistRepository.createChecklist                      *)
(*   agCheck      the agent's checklist update tools, which write an item  *)
(*                read when the tool call began                            *)
(*   agTaskEdit   the agent's task field tools, which write a task read    *)
(*                when the tool call began (JournalRepository.             *)
(*                updateJournalEntity)                                     *)
(*   Receive      sync applying a newer version from another device — an  *)
(*                item and the checklist version listing it, or a new      *)
(*                checklist and the task version listing it                *)
(*   Refresh      a screen's update notification: the controllers re-read *)
(*                their row                                                *)
(*   Crash        the app dies mid-operation; Replay and Restart are      *)
(*                ChecklistMembershipIntents.replay at the next start,     *)
(*                which finishes every operation whose intent it recorded  *)
(*                before its first write                                   *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    Lists,             \* checklist ids
    First,             \* the checklist the task starts with
    Items,             \* item ids an operation may create
    MaxOps,            \* operations started, both processes together
    MaxReceives,       \* versions sync lands
    MaxCrashes,        \* times the app dies mid-operation
    RebaseLists,       \* checklist lists are written on the stored row
    RebaseTask,        \* the task's list is written on the stored row, and
                       \* every other task write keeps the stored list
    RebaseItems,       \* item writes are built on the stored item
    WidgetFollowsTask, \* ChecklistsWidget drops its own order when the
                       \* task's list changes
    IntentLog          \* a multi-row operation records its intent first,
                       \* and the next start finishes it

ASSUME First \in Lists /\ Lists \cap Items = {}

Procs == {"ui", "agent"}
Idle == [steps |-> <<>>, pc |-> 1, base |-> <<>>, ver |-> 0]
NoIntent == [op |-> "none"]

VARIABLES
    task,       \* stored task row: [ids, ver]
    cl,         \* stored checklist rows: [live, born, items, ver]
    item,       \* stored item rows: [st ("none"/"live"/"dead"), back, ver]
    home,       \* ghost: the checklist each item was last put into
    uiList,     \* ChecklistController state per checklist
    uiItem,     \* ChecklistItemController state per item: its back-link
    uiTask,     \* EntryController's task: its checklist ids
    widget,     \* ChecklistsWidget's own order: [set, ids]
    proc,       \* the operation each process is running
    intents,    \* recorded intents, one per process at most: [p |-> intent]
    up,         \* the app runs
    ops,
    receives,
    crashes

vars == <<task, cl, item, home, uiList, uiItem, uiTask, widget, proc,
          intents, up, ops, receives, crashes>>

-----------------------------------------------------------------------------
\* Lists as the code manipulates them.

Elems(s) == {s[k] : k \in 1..Len(s)}
Without(s, x) == SelectSeq(s, LAMBDA y : y # x)
\* Every writer lists an id at most once: `withMember` checks first, and
\* `_insertItemAt` removes before it inserts.
AppendNew(s, x) == IF x \in Elems(s) THEN s ELSE Append(s, x)
ToFront(s, x) == IF x \in Elems(s) THEN <<x>> \o Without(s, x) ELSE s

\* What one write does to the value it is built on: a list, or an item's
\* back-link.
Apply(d, s) ==
    CASE d.what = "add"     -> AppendNew(s, d.x)
      [] d.what = "remove"  -> Without(s, d.x)
      [] d.what = "front"   -> ToFront(s, d.x)
      [] d.what = "setBack" -> d.x
      [] d.what = "keep"    -> s

Stored(r) ==
    IF r = "task" THEN task.ids
    ELSE IF r \in Lists THEN cl[r].items
    ELSE item[r].back
Ver(r) ==
    IF r = "task" THEN task.ver
    ELSE IF r \in Lists THEN cl[r].ver
    ELSE item[r].ver

\* The checklists the task page shows.
View == IF widget.set THEN widget.ids ELSE uiTask

-----------------------------------------------------------------------------
\* Steps. An operation is a sequence of them, run by one process.

Read(r, src) == [act |-> "read", row |-> r, src |-> src]
Commit(r, d, cas) == [act |-> "commit", row |-> r, d |-> d, cas |-> cas]
Create(i, c) == [act |-> "create", x |-> i, row |-> c]
MakeList(c) == [act |-> "makeList", row |-> c]
Kill(c) == [act |-> "kill", row |-> c]
KillItem(i) == [act |-> "killItem", row |-> i]
D(what, x) == [what |-> what, x |-> x]

ListSrc == IF RebaseLists THEN "stored" ELSE "screen"
ItemSrc == IF RebaseItems THEN "stored" ELSE "screen"

\* The screen builds its rows from its controllers' state.
UiAdd(c, i) ==
    << Read(c, ListSrc), Create(i, c), Commit(c, D("add", i), RebaseLists) >>
UiReorder(c, x) ==
    << Read(c, ListSrc), Commit(c, D("front", x), RebaseLists) >>
UiMove(i, from, to) ==
    << Read(i, ItemSrc), Commit(i, D("setBack", to), RebaseItems),
       Read(to, ListSrc), Commit(to, D("add", i), RebaseLists),
       Read(from, ListSrc), Commit(from, D("remove", i), RebaseLists) >>
UiCheck(i) ==
    << Read(i, ItemSrc), Commit(i, D("keep", "none"), RebaseItems) >>
UiDropItem(i, c) ==
    << Read(c, ListSrc), Commit(c, D("remove", i), RebaseLists), KillItem(i) >>
\* delete() reads the task after the checklist is gone.
UiDelete(c) ==
    << Kill(c), Read("task", "stored"),
       Commit("task", D("remove", c), RebaseTask) >>
UiTaskEdit ==
    << Read("task", IF RebaseTask THEN "stored" ELSE "screen"),
       Commit("task", D("keep", "none"), RebaseTask) >>
UiSort(c) ==
    << Read("task", IF RebaseTask THEN "stored" ELSE "widget"),
       Commit("task", D("front", c), RebaseTask) >>

AgAdd(c, i) ==
    << Create(i, c), Read(c, "stored"), Commit(c, D("add", i), RebaseLists) >>
\* createChecklist read the task before it created the checklist.
AgList(c) ==
    IF RebaseTask
    THEN << MakeList(c), Read("task", "stored"),
            Commit("task", D("add", c), TRUE) >>
    ELSE << Read("task", "stored"), MakeList(c),
            Commit("task", D("add", c), FALSE) >>
\* The agent's tools read their row when the tool call begins.
AgCheck(i) ==
    << Read(i, "stored"), Commit(i, D("keep", "none"), RebaseItems) >>
AgTaskEdit ==
    << Read("task", "stored"), Commit("task", D("keep", "none"), RebaseTask) >>

\* The intent a multi-row operation records before its first write.
ListItemIntent(i, c) == [op |-> "listItem", i |-> i, c |-> c]
MoveIntent(i, from, to) == [op |-> "move", i |-> i, from |-> from, to |-> to]
DropItemIntent(i, c) == [op |-> "dropItem", i |-> i, c |-> c]
ListListIntent(c) == [op |-> "listList", c |-> c]
UnlistListIntent(c) == [op |-> "unlistList", c |-> c]

-----------------------------------------------------------------------------

Init ==
    /\ task = [ids |-> <<First>>, ver |-> 1]
    /\ cl = [c \in Lists |->
               [live |-> c = First, born |-> c = First,
                items |-> <<>>, ver |-> IF c = First THEN 1 ELSE 0]]
    /\ item = [i \in Items |-> [st |-> "none", back |-> First, ver |-> 0]]
    /\ home = [i \in Items |-> First]
    /\ uiList = [c \in Lists |-> <<>>]
    /\ uiItem = [i \in Items |-> First]
    /\ uiTask = <<First>>
    /\ widget = [set |-> FALSE, ids |-> <<>>]
    /\ proc = [p \in Procs |-> Idle]
    /\ intents = [p \in Procs |-> NoIntent]
    /\ up = TRUE
    /\ ops = 0
    /\ receives = 0
    /\ crashes = 0

\* An operation starts; with IntentLog, its intent is recorded first.
Start(p, steps, intent) ==
    /\ up
    /\ proc[p] = Idle
    /\ ops < MaxOps
    /\ proc' = [proc EXCEPT ![p] = [Idle EXCEPT !.steps = steps]]
    /\ intents' = IF IntentLog /\ intent # NoIntent
                  THEN [intents EXCEPT ![p] = intent] ELSE intents
    /\ ops' = ops + 1

\* Ids are random: one an operation is about to create is nobody else's.
Taken ==
    {i \in Items : item[i].st # "none"}
    \cup UNION {{proc[p].steps[k].x :
                   k \in {j \in 1..Len(proc[p].steps) :
                            proc[p].steps[j].act = "create"}} :
                  p \in Procs}

\* A checklist the screen shows: listed on the task page and loaded.
Shown(c) == c \in Elems(View) /\ cl[c].live
LiveItem(i) == item[i].st = "live"

UserStarts ==
    \/ \E c \in Lists, i \in Items \ Taken :
          /\ Shown(c)
          /\ Start("ui", UiAdd(c, i), ListItemIntent(i, c))
          /\ UNCHANGED home
    \/ \E c \in Lists : \E x \in Elems(uiList[c]) :
          /\ Shown(c) /\ Len(uiList[c]) > 1 /\ uiList[c][1] # x
          /\ Start("ui", UiReorder(c, x), NoIntent)
          /\ UNCHANGED home
    \/ \E from, to \in Lists : \E i \in Elems(uiList[from]) :
          /\ from # to /\ Shown(from) /\ Shown(to) /\ LiveItem(i)
          /\ Start("ui", UiMove(i, from, to), MoveIntent(i, from, to))
          \* Once recorded, the move will happen; without the log it is
          \* decided by its first write.
          /\ home' = IF IntentLog THEN [home EXCEPT ![i] = to] ELSE home
    \/ \E c \in Lists : \E i \in Elems(uiList[c]) :
          /\ Shown(c) /\ LiveItem(i)
          /\ Start("ui", UiCheck(i), NoIntent)
          /\ UNCHANGED home
    \/ \E c \in Lists : \E i \in Elems(uiList[c]) :
          /\ Shown(c) /\ LiveItem(i)
          /\ Start("ui", UiDropItem(i, c), DropItemIntent(i, c))
          /\ UNCHANGED home
    \/ \E c \in Lists :
          /\ Shown(c) /\ c # First
          /\ Start("ui", UiDelete(c), UnlistListIntent(c))
          /\ UNCHANGED home
    \/ /\ Start("ui", UiTaskEdit, NoIntent)
       /\ UNCHANGED home

AgentStarts ==
    \/ \E c \in Lists, i \in Items \ Taken :
          /\ cl[c].live /\ c \in Elems(task.ids)
          /\ Start("agent", AgAdd(c, i), ListItemIntent(i, c))
          /\ UNCHANGED home
    \/ \E c \in Lists :
          /\ ~cl[c].born
          /\ Start("agent", AgList(c), ListListIntent(c))
          /\ UNCHANGED home
    \/ \E i \in Items :
          /\ LiveItem(i)
          /\ Start("agent", AgCheck(i), NoIntent)
          /\ UNCHANGED home
    \/ /\ Start("agent", AgTaskEdit, NoIntent)
       /\ UNCHANGED home

Begin ==
    /\ (UserStarts \/ AgentStarts)
    /\ UNCHANGED <<task, cl, item, uiList, uiItem, uiTask, widget, up,
                   receives, crashes>>

\* The widget shows the order the checklists were dragged into from the
\* moment of the drag, and saves it.
BeginSort ==
    /\ \E c \in Elems(View) :
          /\ Len(View) > 1 /\ View[1] # c
          /\ Start("ui", UiSort(c), NoIntent)
          /\ widget' = [set |-> TRUE, ids |-> ToFront(View, c)]
    /\ UNCHANGED <<task, cl, item, home, uiList, uiItem, uiTask, up,
                   receives, crashes>>

\* The value a write is built on, from where the writer takes it.
Source(r, src) ==
    CASE src = "stored" -> Stored(r)
      [] src = "widget" -> View
      [] src = "screen" ->
            IF r = "task" THEN uiTask
            ELSE IF r \in Lists THEN uiList[r] ELSE uiItem[r]

Done(p) ==
    IF proc[p].pc = Len(proc[p].steps) THEN [proc EXCEPT ![p] = Idle]
    ELSE [proc EXCEPT ![p].pc = @ + 1]

\* The last step of an operation removes its intent.
Finish(p) ==
    intents' = IF proc[p].pc = Len(proc[p].steps)
               THEN [intents EXCEPT ![p] = NoIntent] ELSE intents

\* A write to a deleted item is refused: its writers read live rows only.
WriteRow(r, s) ==
    CASE r = "task" ->
            /\ task' = [ids |-> s, ver |-> task.ver + 1]
            /\ UNCHANGED <<cl, item>>
      [] r \in Lists ->
            /\ cl' = [cl EXCEPT ![r].items = s, ![r].ver = @ + 1]
            /\ UNCHANGED <<task, item>>
      [] OTHER ->
            /\ item' = IF LiveItem(r)
                       THEN [item EXCEPT ![r].back = s, ![r].ver = @ + 1]
                       ELSE item
            /\ UNCHANGED <<task, cl>>

Step(p) ==
    /\ up
    /\ proc[p] # Idle
    /\ LET st == proc[p].steps[proc[p].pc] IN
       CASE st.act = "read" ->
              /\ proc' = [Done(p) EXCEPT ![p].base = Source(st.row, st.src),
                                         ![p].ver = Ver(st.row)]
              /\ UNCHANGED <<task, cl, item, home, uiList, uiItem, intents>>
         [] st.act = "commit" /\ st.cas /\ Ver(st.row) # proc[p].ver ->
              \* The precondition refuses the write: build it again on the
              \* row as it now is.
              /\ proc' = [proc EXCEPT ![p].pc = @ - 1]
              /\ UNCHANGED <<task, cl, item, home, uiList, uiItem, intents>>
         [] st.act = "commit" /\ ~(st.cas /\ Ver(st.row) # proc[p].ver) ->
              LET s == Apply(st.d, proc[p].base) IN
              /\ WriteRow(st.row, s)
              \* A controller publishes what it wrote as its state.
              /\ uiList' = IF p = "ui" /\ st.row \in Lists
                           THEN [uiList EXCEPT ![st.row] = s] ELSE uiList
              /\ uiItem' = IF p = "ui" /\ st.row \in Items
                           THEN [uiItem EXCEPT ![st.row] = s] ELSE uiItem
              \* A move is decided by its first write, the item's back-link.
              /\ home' = IF st.d.what = "setBack"
                         THEN [home EXCEPT ![st.row] = st.d.x] ELSE home
              /\ proc' = Done(p)
              /\ Finish(p)
         [] st.act = "create" ->
              /\ item' = [item EXCEPT ![st.x] =
                            [st |-> "live", back |-> st.row, ver |-> 1]]
              /\ home' = [home EXCEPT ![st.x] = st.row]
              /\ proc' = Done(p)
              /\ Finish(p)
              /\ UNCHANGED <<task, cl, uiList, uiItem>>
         [] st.act = "makeList" ->
              \* A derived id (ADR 0075) can already hold another device's
              \* checklist: the creation is then refused as concurrent.
              /\ cl' = IF cl[st.row].born THEN cl
                       ELSE [cl EXCEPT ![st.row] =
                               [live |-> TRUE, born |-> TRUE, items |-> <<>>,
                                ver |-> 1]]
              /\ proc' = Done(p)
              /\ Finish(p)
              /\ UNCHANGED <<task, item, home, uiList, uiItem>>
         [] st.act = "kill" ->
              /\ cl' = [cl EXCEPT ![st.row].live = FALSE, ![st.row].ver = @ + 1]
              /\ proc' = Done(p)
              /\ Finish(p)
              /\ UNCHANGED <<task, item, home, uiList, uiItem>>
         [] st.act = "killItem" ->
              /\ item' = [item EXCEPT ![st.row].st = "dead",
                                      ![st.row].ver = @ + 1]
              /\ proc' = Done(p)
              /\ Finish(p)
              /\ UNCHANGED <<task, cl, home, uiList, uiItem>>
    /\ UNCHANGED <<uiTask, widget, up, ops, receives, crashes>>

\* Sync lands a version another device wrote after it had everything this
\* device wrote: it applies as the newer version.
Receive ==
    /\ up
    /\ receives < MaxReceives
    /\ receives' = receives + 1
    /\ \/ \E c \in Lists, i \in Items \ Taken :
             /\ cl[c].live
             /\ item' = [item EXCEPT ![i] = [st |-> "live", back |-> c, ver |-> 1]]
             /\ home' = [home EXCEPT ![i] = c]
             /\ cl' = [cl EXCEPT ![c].items = AppendNew(@, i), ![c].ver = @ + 1]
             /\ UNCHANGED task
       \/ \E c \in Lists :
             /\ ~cl[c].born
             /\ cl' = [cl EXCEPT ![c] =
                         [live |-> TRUE, born |-> TRUE, items |-> <<>>, ver |-> 1]]
             /\ task' = [ids |-> AppendNew(task.ids, c), ver |-> task.ver + 1]
             /\ UNCHANGED <<item, home>>
    /\ UNCHANGED <<uiList, uiItem, uiTask, widget, proc, intents, up, ops,
                   crashes>>

\* An update notification reaches a screen, which re-reads its row. With
\* WidgetFollowsTask, ChecklistsWidget drops its own order when the task's
\* list changes under it.
RefreshList(c) ==
    /\ up
    /\ uiList[c] # cl[c].items
    /\ uiList' = [uiList EXCEPT ![c] = cl[c].items]
    /\ UNCHANGED <<task, cl, item, home, uiItem, uiTask, widget, proc,
                   intents, up, ops, receives, crashes>>

RefreshItem(i) ==
    /\ up
    /\ uiItem[i] # item[i].back
    /\ uiItem' = [uiItem EXCEPT ![i] = item[i].back]
    /\ UNCHANGED <<task, cl, item, home, uiList, uiTask, widget, proc,
                   intents, up, ops, receives, crashes>>

RefreshTask ==
    /\ up
    /\ uiTask # task.ids
    /\ uiTask' = task.ids
    /\ widget' = IF WidgetFollowsTask THEN [set |-> FALSE, ids |-> <<>>]
                 ELSE widget
    /\ UNCHANGED <<task, cl, item, home, uiList, uiItem, proc, intents, up,
                   ops, receives, crashes>>

\* The app dies with an operation part-way: what it wrote stays written,
\* the recorded intents stay recorded, and everything in memory is gone.
Crash ==
    /\ up
    /\ crashes < MaxCrashes
    /\ \E p \in Procs : proc[p] # Idle
    /\ up' = FALSE
    /\ crashes' = crashes + 1
    /\ proc' = [p \in Procs |-> Idle]
    /\ UNCHANGED <<task, cl, item, home, uiList, uiItem, uiTask, widget,
                   intents, ops, receives>>

\* At the next start, ChecklistMembershipIntents.replay finishes one
\* recorded operation. Every step is idempotent and written on the stored
\* rows, so a replay that dies is replayed again.
Replay(p) ==
    /\ ~up
    /\ intents[p] # NoIntent
    /\ LET n == intents[p] IN
       CASE n.op = "listItem" ->
              /\ cl' = IF LiveItem(n.i) /\ cl[n.c].live
                       THEN [cl EXCEPT ![n.c].items = AppendNew(@, n.i),
                                       ![n.c].ver = @ + 1]
                       ELSE cl
              /\ UNCHANGED <<task, item>>
         [] n.op = "move" ->
              IF LiveItem(n.i)
              THEN /\ item' = [item EXCEPT ![n.i].back = n.to,
                                           ![n.i].ver = @ + 1]
                   /\ cl' = [c \in Lists |->
                               IF c = n.to /\ cl[c].live
                               THEN [cl[c] EXCEPT !.items = AppendNew(@, n.i),
                                                  !.ver = @ + 1]
                               ELSE IF c = n.from
                               THEN [cl[c] EXCEPT !.items = Without(@, n.i),
                                                  !.ver = @ + 1]
                               ELSE cl[c]]
                   /\ UNCHANGED task
              ELSE UNCHANGED <<task, cl, item>>
         [] n.op = "dropItem" ->
              /\ cl' = [cl EXCEPT ![n.c].items = Without(@, n.i),
                                  ![n.c].ver = @ + 1]
              /\ item' = IF item[n.i].st = "live"
                         THEN [item EXCEPT ![n.i].st = "dead",
                                           ![n.i].ver = @ + 1]
                         ELSE item
              /\ UNCHANGED task
         [] n.op = "listList" ->
              /\ task' = IF cl[n.c].live
                         THEN [ids |-> AppendNew(task.ids, n.c),
                               ver |-> task.ver + 1]
                         ELSE task
              /\ UNCHANGED <<cl, item>>
         [] n.op = "unlistList" ->
              /\ cl' = IF cl[n.c].live
                       THEN [cl EXCEPT ![n.c].live = FALSE, ![n.c].ver = @ + 1]
                       ELSE cl
              /\ task' = [ids |-> Without(task.ids, n.c), ver |-> task.ver + 1]
              /\ UNCHANGED item
    /\ intents' = [intents EXCEPT ![p] = NoIntent]
    /\ UNCHANGED <<home, uiList, uiItem, uiTask, widget, proc, up, ops,
                   receives, crashes>>

\* Once every intent is replayed the app runs again, and its screens load
\* the rows afresh.
Restart ==
    /\ ~up
    /\ \A p \in Procs : intents[p] = NoIntent
    /\ up' = TRUE
    /\ uiList' = [c \in Lists |-> cl[c].items]
    /\ uiItem' = [i \in Items |-> item[i].back]
    /\ uiTask' = task.ids
    /\ widget' = [set |-> FALSE, ids |-> <<>>]
    /\ UNCHANGED <<task, cl, item, home, proc, intents, ops, receives,
                   crashes>>

Next ==
    \/ Begin
    \/ BeginSort
    \/ \E p \in Procs : Step(p)
    \/ Receive
    \/ \E c \in Lists : RefreshList(c)
    \/ \E i \in Items : RefreshItem(i)
    \/ RefreshTask
    \/ Crash
    \/ \E p \in Procs : Replay(p)
    \/ Restart

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------

\* The app runs, no operation is running, and nothing is left to replay.
Quiet ==
    /\ up
    /\ \A p \in Procs : proc[p] = Idle /\ intents[p] = NoIntent

TypeOK ==
    /\ task.ids \in Seq(Lists)
    /\ \A c \in Lists : cl[c].items \in Seq(Items)
    /\ \A i \in Items : item[i].st \in {"none", "live", "dead"}
                        /\ item[i].back \in Lists
    /\ ops \in 0..MaxOps
    /\ receives \in 0..MaxReceives
    /\ crashes \in 0..MaxCrashes

\* No list names an id twice.
NoDuplicates ==
    /\ Cardinality(Elems(task.ids)) = Len(task.ids)
    /\ \A c \in Lists : Cardinality(Elems(cl[c].items)) = Len(cl[c].items)

\* Once quiet, every live item is listed by the checklist it was last put
\* into, while that checklist lives: nothing the user typed, the agent added
\* or sync delivered disappears from its list — and an item the user
\* deleted is deleted, not left alive and unlisted.
NoLostItem ==
    Quiet =>
        \A i \in Items :
            LiveItem(i) /\ cl[home[i]].live => i \in Elems(cl[home[i]].items)

\* And by no other checklist: a move leaves the item in one place.
NoStrayItem ==
    Quiet =>
        \A i \in Items : \A c \in Lists \ {home[i]} :
            LiveItem(i) /\ cl[c].live => i \notin Elems(cl[c].items)

\* Every live item names the checklist that lists it, which the agent's
\* checklist tools read to authorise an update.
BackLinkAgrees ==
    Quiet => \A i \in Items : LiveItem(i) => item[i].back = home[i]

\* Every live checklist is listed by the task.
NoLostChecklist ==
    Quiet => \A c \in Lists : cl[c].live => c \in Elems(task.ids)

\* Once the task page has re-read the task, it shows the task's live
\* checklists. (A card whose checklist is deleted renders nothing, so a
\* deleted id in the page's order is harmless.)
Live == {c \in Lists : cl[c].live}
PageShowsChecklists ==
    (Quiet /\ uiTask = task.ids) =>
        Elems(View) \cap Live = Elems(task.ids) \cap Live

=============================================================================

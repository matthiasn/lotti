------------------------ MODULE ChecklistReplication ------------------------
(***************************************************************************)
(* A task's checklists and their items on several devices. Membership is   *)
(* held three times over: the task lists its checklists                     *)
(* (`TaskData.checklistIds`), a checklist lists its items                  *)
(* (`ChecklistData.linkedChecklistItems`), and each item names the         *)
(* checklist it is in (`ChecklistItemData.linkedChecklists`, its back-link; *)
(* the first entry is its checklist, `homeChecklistId`). Each is a separate *)
(* journal row, and journal rows never merge across devices: each is a     *)
(* register whose concurrent versions become Conflict rows the user        *)
(* resolves (JournalReplication). Sync delivers each row on its own, in    *)
(* any order, so a device holds any mix of another device's rows.          *)
(*                                                                         *)
(* ChecklistMembership proves one device writes these rows on what is       *)
(* stored and finishes a multi-row operation it died in. Here those writers *)
(* are taken as given -- every write is built on the stored row, every      *)
(* multi-row operation records its intent first -- and run on two devices   *)
(* at once. The question is what a device shows: which checklists, which    *)
(* items in each, in what order, counted how many times.                    *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Decide    JournalDb.updateJournalEntity and detectConflict, as in      *)
(*             JournalReplication with its fixes: newer applies, equal or   *)
(*             older is refused, concurrent is kept as a Conflict row per   *)
(*             version, two concurrent deletions merge into one side's row. *)
(*   View      what a device shows (readShownChecklistItems, shownItemIds): *)
(*             the task's live checklists in its order; in each, the live   *)
(*             items naming it -- in the checklist's order, then any it     *)
(*             does not list yet -- found by their back-link                *)
(*             (JournalDb.checklistItemsNaming)                             *)
(*   add       ChecklistRepository.addItemToChecklist and the screen's      *)
(*             createChecklistItem: create the item naming its checklist,   *)
(*             then list it (_listItems)                                    *)
(*   move      ChecklistRepository.moveItem: the item's back-link, the      *)
(*             target's list, then the source's                             *)
(*   check     updateChecklistItem: any item field, on the stored item      *)
(*   dropItem  beginItemDeletion / completeItemDeletion: unlist, delete     *)
(*   addList   createChecklist: create the checklist, list it on the task   *)
(*   dropList  deleteChecklist: unlist it from the task, delete it, delete  *)
(*             the items naming it                                          *)
(*   taskEdit  a task field edit (status, title...), on the stored task     *)
(*   Resolve   ConflictResolutionService: one side under the merged clock   *)
(*             (conflict_merge.dart _resolved), written through             *)
(*             ChecklistRepository.resolveConflict for a checklist          *)
(*   Deliver   SyncEventProcessor applying one row another device sent,     *)
(*             then ChecklistRepository.settleReceived                      *)
(*   Crash,    the app dies mid-operation; a start replays the recorded     *)
(*   Replay    intent (replayMembershipIntents). Replay may run at any      *)
(*             time, a superset of "at the next start"                      *)
(*                                                                         *)
(* A lost delivery that backfill recovers is a delivery made late, of the   *)
(* writer's current row, which covers the lost one: delivery in any order   *)
(* covers it. The design switches are the fixes of ADR 0105; FALSE restores *)
(* the old behaviour and its counterexample (README).                       *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    N,             \* devices 1..N
    TaskId,        \* the task
    Lists,         \* checklist ids
    Initial,       \* the checklists the task starts with, on every device
    First,         \* the one of them the seeded items start in
    Items,         \* item ids
    Seeded,        \* items First starts with, on every device
    Ops,           \* the operations enabled in this configuration
    MaxOps,        \* operations started by users, all devices together
    MaxResolves,   \* conflict resolutions, all devices together
    MaxCrashes,    \* times an app dies mid-operation
    DerivedIds,    \* two devices may create one item id (a derived id,
                   \* ADR 0075: the migration handler's copy)
    \* Design switches: TRUE is the code after ADR 0105.
    ItemsByHome,   \* a checklist shows the items naming it, not its list
    JoinOnResolve, \* a resolved list keeps the ids either side listed
    RelistOnResolve, \* keeping a checklist lists it on its task, in a new
                     \* version even when it is listed already
    UnlistFirst,   \* a checklist is unlisted from its task before it is
                   \* deleted
    ReplayGuard,   \* a replayed intent does not repeat a write of its own
                   \* that landed
    Cascade        \* deleting a checklist deletes the items naming it

ASSUME /\ First \in Initial /\ Initial \subseteq Lists /\ Seeded \subseteq Items
       /\ Ops \subseteq {"add", "move", "check", "dropItem", "addList",
                         "dropList", "taskEdit"}

Dev == 1..N
Ents == {TaskId} \cup Lists \cup Items
Zero == [d \in Dev |-> 0]
Max(a, b) == IF a > b THEN a ELSE b
Join(a, b) == [d \in Dev |-> Max(a[d], b[d])]

Elems(s) == {s[k] : k \in 1..Len(s)}
Without(s, x) == SelectSeq(s, LAMBDA y : y # x)
\* The kept side's order, then what only the other side listed (joinMembers).
JoinList(a, b) == a \o SelectSeq(b, LAMBDA x : x \notin Elems(a))
SetToSeq(X) ==
    CHOOSE f \in [1..Cardinality(X) -> X] :
        \A i, j \in 1..Cardinality(X) : i # j => f[i] # f[j]

\* A row: whether it exists, its clock, whether it is deleted, and its value
\* -- the list of a task or checklist, <<checklist>> for an item's back-link.
Absent == [ex |-> FALSE, vc |-> Zero, del |-> FALSE, val |-> <<>>]
Row(val) == [ex |-> TRUE, vc |-> Zero, del |-> FALSE, val |-> val]

VARIABLES
    row,        \* per device and entity: the stored row
    conf,       \* per device and entity: open conflict versions
    sent,       \* every row version written: [e, v, from]
    delivered,  \* per device: the versions it received
    hc,         \* per device: the last counter it issued
    proc,       \* per device: the operation running
    intents,    \* per device: recorded intents not yet complete
    used,       \* per device: ids it has created or is creating
    ops,
    resolves,
    crashes

vars == <<row, conf, sent, delivered, hc, proc, intents, used, ops, resolves,
          crashes>>

\* An operation: its kind, the entity whose write decides it (`key`) and
\* this device's counter on that row when it began (`mark`), its changes of
\* stored rows, one per step, and whether it is a replay.
Idle == [kind |-> "idle", key |-> TaskId, mark |-> 0, steps |-> <<>>, pc |-> 0,
         replay |-> FALSE]

-----------------------------------------------------------------------------
\* The write decision (JournalReplication, every fix on).

Leq(a, b) == \A d \in Dev : a[d] <= b[d]
Status(a, b) ==
    IF a = b THEN "equal"
    ELSE IF Leq(a, b) THEN "b_gt_a"
    ELSE IF Leq(b, a) THEN "a_gt_b"
    ELSE "concurrent"
\* `b` is `a` or newer.
Covers(a, b) == Leq(a.vc, b.vc)
CanonGt(a, b) ==
    \E k \in Dev : a[k] > b[k] /\ \A j \in Dev : j < k => a[j] = b[j]

StoredOn(C, w) ==
    IF \E c \in C : Covers(w, c) THEN C
    ELSE {c \in C : ~Covers(c, w)} \cup {w}
SettledOn(C, w) == {c \in C : ~Covers(c, w)}

DecideOn(P, C, w) ==
    IF ~P.ex THEN [row |-> w, conf |-> C, applied |-> TRUE]
    ELSE LET s == Status(P.vc, w.vc) IN
         IF s = "b_gt_a"
         THEN [row |-> w, conf |-> SettledOn(C, w), applied |-> TRUE]
         ELSE IF s = "concurrent" /\ P.del /\ w.del
         THEN LET win == IF CanonGt(w.vc, P.vc) THEN w ELSE P
                  t == [win EXCEPT !.vc = Join(P.vc, w.vc)]
              IN [row |-> t, conf |-> SettledOn(C, t), applied |-> t # P]
         ELSE IF s = "concurrent"
         THEN [row |-> P, conf |-> StoredOn(C, w), applied |-> FALSE]
         ELSE [row |-> P, conf |-> C, applied |-> FALSE]

-----------------------------------------------------------------------------
\* What a device holds and shows.

Ex(d, e) == row[d][e].ex
Live(d, e) == row[d][e].ex /\ ~row[d][e].del
Gone(d, e) == row[d][e].ex /\ row[d][e].del
List(d, e) == row[d][e].val
\* The checklist an item names (homeChecklistId).
Home(d, i) == row[d][i].val[1]

\* The live items naming checklist c (JournalDb.checklistItemsNaming).
Named(d, c) == {i \in Items : Live(d, i) /\ Home(d, i) = c}

\* The checklists the task page shows, in the task's order.
ShownLists(d) ==
    IF Live(d, TaskId) THEN SelectSeq(List(d, TaskId), LAMBDA c : Live(d, c))
    ELSE <<>>
\* The items a checklist shows, in order. With ItemsByHome, the items naming
\* it: those it lists in its order, then the others. Otherwise, the live
\* items it lists.
ShownIn(d, c) ==
    IF ItemsByHome
    THEN SelectSeq(List(d, c), LAMBDA i : i \in Named(d, c))
         \o SetToSeq(Named(d, c) \ Elems(List(d, c)))
    ELSE SelectSeq(List(d, c), LAMBDA i : Live(d, i))
View(d) ==
    [lists |-> ShownLists(d),
     items |-> [c \in Lists |->
                  IF c \in Elems(ShownLists(d)) THEN ShownIn(d, c) ELSE <<>>]]
ShownItems(d, c) == IF c \in Elems(ShownLists(d)) THEN Elems(ShownIn(d, c))
                    ELSE {}

-----------------------------------------------------------------------------
\* A local write, always on the stored row: its clock plus this device's
\* next counter, so it applies; it settles only the conflicts it covers.

Write(d, e, val, del) ==
    LET w == [ex |-> TRUE, vc |-> [row[d][e].vc EXCEPT ![d] = hc[d] + 1],
              del |-> del, val |-> val]
        r == DecideOn(row[d][e], conf[d][e], w)
    IN /\ row' = [row EXCEPT ![d][e] = r.row]
       /\ conf' = [conf EXCEPT ![d][e] = r.conf]
       /\ hc' = [hc EXCEPT ![d] = @ + 1]
       /\ sent' = sent \cup {[e |-> e, v |-> r.row, from |-> d]}

NoWrite == UNCHANGED <<row, conf, hc, sent>>

-----------------------------------------------------------------------------
\* Operations. A step `g`uarded is one a replay skips once the operation's
\* own write of its key has landed: a later version there is someone else's
\* choice, which the replay must not undo.

S(k, x, y) == [k |-> k, x |-> x, y |-> y, g |-> FALSE]
G(k, x, y) == [k |-> k, x |-> x, y |-> y, g |-> TRUE]
Op(kind, key, steps) ==
    [kind |-> kind, key |-> key, mark |-> 0, steps |-> steps, pc |-> 1,
     replay |-> FALSE]

\* An item is listed on a checklist; listed on a deleted one, the item goes
\* with it (Cascade). _listItems.
ListOn(c, i) == S("listOn", c, i)

AddOp(c, i) == Op("add", i, << S("create", i, c), ListOn(c, i) >>)
MoveOp(i, from, to) ==
    Op("move", i, << G("setHome", i, to), ListOn(to, i),
                     S("unlist", from, i) >>)
CheckOp(i) == Op("check", i, << S("touch", i, i) >>)
DropItemOp(i, c) == Op("dropItem", i, << S("unlist", c, i), G("kill", i, i) >>)
AddListOp(c) == Op("addList", c, << S("createList", c, c), S("taskAdd", c, c) >>)
Sweep(c) == IF Cascade THEN << S("cascade", c, c) >> ELSE <<>>
DropListOp(c) ==
    Op("dropList", c,
       IF UnlistFirst
       THEN << G("unlist", TaskId, c), G("killList", c, c) >> \o Sweep(c)
       ELSE << G("killList", c, c) >> \o Sweep(c) \o << G("unlist", TaskId, c) >>)
TaskEditOp == Op("taskEdit", TaskId, << S("touch", TaskId, TaskId) >>)

\* The last change of an operation removes its intent.
Finish(d) ==
    IF proc[d].pc = Len(proc[d].steps)
    THEN /\ proc' = [proc EXCEPT ![d] = Idle]
         /\ intents' = [intents EXCEPT ![d] =
                          @ \ {[proc[d] EXCEPT !.pc = 1, !.replay = FALSE]}]
    ELSE /\ proc' = [proc EXCEPT ![d].pc = @ + 1]
         /\ UNCHANGED intents

\* The operation's own write of its key has landed.
Landed(d, op) == row[d][op.key].vc[d] > op.mark

Step(d) ==
    /\ proc[d] # Idle
    /\ LET st == proc[d].steps[proc[d].pc]
           x == st.x
           y == st.y
       IN CASE st.g /\ proc[d].replay /\ ReplayGuard /\ Landed(d, proc[d]) ->
                 NoWrite /\ Finish(d)
            [] st.k = "cascade" ->
                 \* Only while the checklist is deleted: kept by a
                 \* resolution meanwhile, its items stay.
                 IF Gone(d, x) /\ Named(d, x) # {}
                 THEN \E i \in Named(d, x) :
                        /\ Write(d, i, List(d, i), TRUE)
                        /\ UNCHANGED <<proc, intents>>
                 ELSE NoWrite /\ Finish(d)
            [] OTHER ->
                 /\ CASE st.k = "listOn" ->
                          IF Live(d, x)
                          THEN IF y \in Elems(List(d, x)) THEN NoWrite
                               ELSE Write(d, x, Append(List(d, x), y), FALSE)
                          ELSE IF Cascade /\ Gone(d, x) /\ Live(d, y)
                                  /\ Home(d, y) = x
                          THEN Write(d, y, List(d, y), TRUE)
                          ELSE NoWrite
                      [] st.k = "unlist" ->
                          IF Live(d, x) /\ y \in Elems(List(d, x))
                          THEN Write(d, x, Without(List(d, x), y), FALSE)
                          ELSE NoWrite
                      [] st.k = "setHome" ->
                          IF Live(d, x) /\ Home(d, x) # y
                          THEN Write(d, x, <<y>>, FALSE) ELSE NoWrite
                      [] st.k = "touch" ->
                          IF Live(d, x) THEN Write(d, x, List(d, x), FALSE)
                          ELSE NoWrite
                      [] st.k = "create" ->
                          IF ~Ex(d, x) THEN Write(d, x, <<y>>, FALSE)
                          ELSE NoWrite
                      [] st.k \in {"kill", "killList"} ->
                          IF Live(d, x) THEN Write(d, x, List(d, x), TRUE)
                          ELSE NoWrite
                      [] st.k = "createList" ->
                          IF ~Ex(d, x) THEN Write(d, x, <<>>, FALSE)
                          ELSE NoWrite
                      [] st.k = "taskAdd" ->
                          IF Live(d, x) /\ x \notin Elems(List(d, TaskId))
                          THEN Write(d, TaskId, Append(List(d, TaskId), x),
                                     FALSE)
                          ELSE NoWrite
                      \* A kept checklist is written onto its task in a new
                      \* version, listed or not: an unlisting this device
                      \* has not received yet then meets it as a concurrent
                      \* version -- a conflict, whose join keeps it --
                      \* instead of silently replacing it.
                      [] st.k = "taskRestate" ->
                          IF Live(d, x)
                          THEN Write(d, TaskId,
                                     IF x \in Elems(List(d, TaskId))
                                     THEN List(d, TaskId)
                                     ELSE Append(List(d, TaskId), x), FALSE)
                          ELSE NoWrite
                 /\ Finish(d)
    /\ UNCHANGED <<delivered, used, ops, resolves, crashes>>

-----------------------------------------------------------------------------

Init ==
    /\ row = [d \in Dev |-> [e \in Ents |->
                 IF e = TaskId
                 THEN Row(<<First>> \o SetToSeq(Initial \ {First}))
                 ELSE IF e = First THEN Row(SetToSeq(Seeded))
                 ELSE IF e \in Initial THEN Row(<<>>)
                 ELSE IF e \in Seeded THEN Row(<<First>>)
                 ELSE Absent]]
    /\ conf = [d \in Dev |-> [e \in Ents |-> {}]]
    /\ sent = {}
    /\ delivered = [d \in Dev |-> {}]
    /\ hc = [d \in Dev |-> 0]
    /\ proc = [d \in Dev |-> Idle]
    /\ intents = [d \in Dev |-> {}]
    /\ used = [d \in Dev |-> Seeded \cup Initial]
    /\ ops = 0
    /\ resolves = 0
    /\ crashes = 0

\* Ids are random, so one an operation creates is nobody else's -- unless
\* derived (ADR 0075), when another device may create it too.
Fresh(d, Ids) ==
    {x \in Ids : x \notin used[d] /\ ~Ex(d, x)
               /\ (DerivedIds \/ \A o \in Dev : x \notin used[o])}

\* A user operation starts on what device d shows. One that writes several
\* rows records its intent first.
Start(d, op) ==
    LET o == [op EXCEPT !.mark = row[d][op.key].vc[d]] IN
    /\ proc[d] = Idle
    /\ ops < MaxOps
    /\ proc' = [proc EXCEPT ![d] = o]
    /\ intents' = IF Len(o.steps) > 1
                  THEN [intents EXCEPT ![d] = @ \cup {o}] ELSE intents
    /\ ops' = ops + 1

Begin(d) ==
    /\ \/ \E c \in Elems(ShownLists(d)), i \in Fresh(d, Items) :
             /\ "add" \in Ops
             /\ Start(d, AddOp(c, i))
             /\ used' = [used EXCEPT ![d] = @ \cup {i}]
       \/ \E from, to \in Elems(ShownLists(d)) :
             \E i \in ShownItems(d, from) :
                /\ "move" \in Ops /\ from # to
                /\ Start(d, MoveOp(i, from, to))
                /\ UNCHANGED used
       \/ \E c \in Elems(ShownLists(d)) : \E i \in ShownItems(d, c) :
             /\ "check" \in Ops
             /\ Start(d, CheckOp(i))
             /\ UNCHANGED used
       \/ \E c \in Elems(ShownLists(d)) : \E i \in ShownItems(d, c) :
             /\ "dropItem" \in Ops
             /\ Start(d, DropItemOp(i, c))
             /\ UNCHANGED used
       \/ \E c \in Lists :
             /\ "addList" \in Ops
             /\ c \notin UNION {used[o] : o \in Dev}
             /\ Start(d, AddListOp(c))
             /\ used' = [used EXCEPT ![d] = @ \cup {c}]
       \/ \E c \in Elems(ShownLists(d)) :
             /\ "dropList" \in Ops
             /\ Start(d, DropListOp(c))
             /\ UNCHANGED used
       \/ /\ "taskEdit" \in Ops
          /\ Start(d, TaskEditOp)
          /\ UNCHANGED used
    /\ UNCHANGED <<row, conf, sent, delivered, hc, resolves, crashes>>

\* What a resolution that kept `v` of `e` still has to do
\* (resolveConflict): write a kept checklist onto its task, or delete the
\* items naming a checklist whose deletion the user kept -- those the other
\* side put in it included.
Settle(e, v) ==
    IF e \in Lists /\ ~v.del /\ RelistOnResolve
    THEN Op("relist", e, << S("taskRestate", e, e) >>)
    ELSE IF e \in Lists /\ v.del /\ Cascade
    THEN Op("settle", e, Sweep(e))
    ELSE Idle

\* The user resolves one open conflict of `e` on device d, keeping this
\* device's row or the other version, under the merged clock. With
\* JoinOnResolve a list keeps what either side listed (_resolved).
Resolve(d) ==
    /\ proc[d] = Idle
    /\ resolves < MaxResolves
    /\ \E e \in Ents : \E X \in conf[d][e] : \E mine \in BOOLEAN :
        LET P == row[d][e]
            kept == IF mine THEN P ELSE X
            other == IF mine THEN X ELSE P
            val == IF JoinOnResolve /\ e \notin Items
                   THEN JoinList(kept.val, other.val) ELSE kept.val
            w == [ex |-> TRUE, vc |-> [Join(P.vc, X.vc) EXCEPT ![d] = hc[d] + 1],
                  del |-> kept.del, val |-> val]
            r == DecideOn(P, conf[d][e], w)
            op == Settle(e, w)
        IN /\ row' = [row EXCEPT ![d][e] = r.row]
           /\ conf' = [conf EXCEPT ![d][e] = r.conf]
           /\ hc' = [hc EXCEPT ![d] = @ + 1]
           /\ sent' = sent \cup {[e |-> e, v |-> r.row, from |-> d]}
           /\ proc' = [proc EXCEPT ![d] = op]
           /\ intents' = IF op = Idle THEN intents
                         ELSE [intents EXCEPT ![d] = @ \cup {op}]
    /\ resolves' = resolves + 1
    /\ UNCHANGED <<delivered, used, ops, crashes>>

\* What a row `v` of `e`, just received on device d, leaves to do
\* (settleReceived): `v` deletes a checklist items still name, or `v` is a
\* live item naming a deleted checklist. The item's version and the
\* deletion arrive in either order, and the device that deleted the
\* checklist may have held an older version of the item, naming another.
Orphaned(d, e, v) ==
    IF ~Cascade \/ ~v.ex THEN {}
    ELSE IF e \in Lists /\ v.del /\ Named(d, e) # {}
         THEN {Op("settle", e, Sweep(e))}
    ELSE IF e \in Items /\ ~v.del /\ Gone(d, v.val[1])
         THEN {Op("settle", e, << ListOn(v.val[1], e) >>)}
    ELSE {}

\* Sync applies one row another device wrote, any time, in any order; what
\* it leaves to do is recorded, and the device runs it next (Replay).
Deliver(d) ==
    /\ \E m \in sent :
        /\ m.from # d
        /\ m \notin delivered[d]
        /\ LET r == DecideOn(row[d][m.e], conf[d][m.e], m.v) IN
           /\ row' = [row EXCEPT ![d][m.e] = r.row]
           /\ conf' = [conf EXCEPT ![d][m.e] = r.conf]
           /\ intents' = IF r.applied
                         THEN [intents EXCEPT ![d] =
                                 @ \cup Orphaned(d, m.e, r.row)]
                         ELSE intents
        /\ delivered' = [delivered EXCEPT ![d] = @ \cup {m}]
    /\ UNCHANGED <<sent, hc, proc, used, ops, resolves, crashes>>

\* The app dies part-way: written rows stay, the intent stays recorded.
Crash(d) ==
    /\ proc[d] # Idle
    /\ crashes < MaxCrashes
    /\ proc' = [proc EXCEPT ![d] = Idle]
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<row, conf, sent, delivered, hc, intents, used, ops,
                   resolves>>

\* A recorded intent runs again from its first change; each change is
\* applied to the stored rows as they are now.
Replay(d) ==
    /\ proc[d] = Idle
    /\ \E op \in intents[d] : proc' = [proc EXCEPT ![d] = [op EXCEPT !.replay = TRUE]]
    /\ UNCHANGED <<row, conf, sent, delivered, hc, intents, used, ops,
                   resolves, crashes>>

Next ==
    \E d \in Dev :
        \/ Begin(d) \/ Step(d) \/ Resolve(d) \/ Deliver(d) \/ Crash(d)
        \/ Replay(d)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------

\* Every row version has reached every device, no operation is running and
\* none is left to run.
Quiescent ==
    \A d \in Dev :
        /\ proc[d] = Idle
        /\ intents[d] = {}
        /\ \A m \in sent : m.from = d \/ m \in delivered[d]

\* ... and the user has resolved every conflict.
Settled == Quiescent /\ \A d \in Dev, e \in Ents : conf[d][e] = {}

TypeOK ==
    /\ \A d \in Dev : \A e \in Ents :
          /\ row[d][e].ex \in BOOLEAN
          /\ e \in Items /\ row[d][e].ex => Len(row[d][e].val) = 1
    /\ ops \in 0..MaxOps
    /\ resolves \in 0..MaxResolves
    /\ crashes \in 0..MaxCrashes

\* No list names an id twice.
NoDuplicates ==
    \A d \in Dev : \A e \in {TaskId} \cup Lists :
        Cardinality(Elems(List(d, e))) = Len(List(d, e))

\* At every moment, whatever has arrived: no item is shown in two
\* checklists of the task, so none is counted twice in its completion.
ShownOnce ==
    \A d \in Dev : \A i \in Items :
        Cardinality({c \in Elems(ShownLists(d)) : i \in ShownItems(d, c)}) <= 1

\* Once everything has arrived, the devices show the same checklists and
\* items in the same order -- or one of them shows the user a conflict.
NeverSilent ==
    Quiescent =>
        \/ \A a, b \in Dev : View(a) = View(b)
        \/ \E d \in Dev, e \in Ents : conf[d][e] # {}

\* Once settled: every live item is shown by the checklist it names.
NoLostItem ==
    Settled =>
        \A d \in Dev : \A i \in Items :
            Live(d, i) /\ Home(d, i) \in Elems(ShownLists(d))
                => i \in ShownItems(d, Home(d, i))

\* ... every live item's checklist lives: a deleted checklist took its
\* items with it, including those that arrived after the deletion.
NoOrphanItem ==
    Settled => \A d \in Dev : \A i \in Items : Live(d, i) => Live(d, Home(d, i))

\* ... and every live checklist is on the task.
NoLostChecklist ==
    Settled =>
        \A d \in Dev : \A c \in Lists : Live(d, c) => c \in Elems(List(d, TaskId))
=============================================================================

---------------------------- MODULE TaskFieldWrites ----------------------------
(***************************************************************************)
(* The fields of one task — its status, priority, title, estimate, due     *)
(* date, language, cover — written by the user's screens, the agent's      *)
(* tools and the day agent's triage on several devices, while sync lands   *)
(* the other devices' versions.                                            *)
(*                                                                         *)
(* Every writer holds a copy of the task it read earlier: a screen's       *)
(* state, refreshed by an update notification some time after the row      *)
(* changes, or the task a tool call began with. A write replaces the whole *)
(* row, and the write decision (JournalDb.updateJournalEntity) keeps it    *)
(* only when its vector clock is newer than the stored row's. So the       *)
(* clock a write carries says which versions it has seen, and the data it  *)
(* carries must hold what those versions hold. A write whose clock claims  *)
(* a version its data never saw silently drops that version's edit: no     *)
(* conflict is raised, because by the clock there is nothing to conflict   *)
(* with.                                                                   *)
(*                                                                         *)
(* Two devices writing before they sync are JournalReplication's subject:  *)
(* the second version becomes a conflict row the user resolves. This spec  *)
(* keeps that decision and adds what JournalReplication abstracts away —   *)
(* the fields — to check that no writer claims a version whose fields it   *)
(* lost, that the status history records every status the task was set    *)
(* to, and that the agent sets a field only over the value it decided      *)
(* against.                                                                *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Read       a writer takes its copy: EntryController's state (the      *)
(*              user), the task a tool call began with (the agent)         *)
(*   UiWrite    a field set from a screen: EntryController.save (title,    *)
(*              estimate, due date), updateTaskStatus, updateTaskPriority, *)
(*              updateTaskLanguage, setCoverArt, through                   *)
(*              PersistenceLogic.updateTask                                *)
(*   AgentWrite a field set by a tool: TaskStatusHandler,                  *)
(*              TaskTitleHandler, TaskLanguageHandler, TaskPriorityHandler, *)
(*              TaskEstimateHandler, TaskDueDateHandler and the day        *)
(*              agent's triage (DayAgentTriageService)                     *)
(*   Receive    sync lands another device's version: newer applies, older  *)
(*              is dropped, concurrent becomes a conflict row              *)
(*              (JournalDb.detectConflict)                                 *)
(*   Resolve    the user keeps one side of a conflict                      *)
(*              (ConflictResolutionService, conflict_merge.dart)           *)
(*                                                                         *)
(* A field write is one transaction: with WriteOnStored the change is      *)
(* applied to the stored row by writeOnStored, which rebuilds it whenever  *)
(* the row moved under it, so the commit is modelled as one step.          *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Devices,              \* devices holding the task
    AgentDevices,         \* devices whose agent writes the task
    Fields,               \* the task's fields; "status" is one of them
    Vals,                 \* values a write may set; every field starts at 0
    MaxWrites,            \* field writes, all writers together
    MaxResolves,          \* conflicts the user resolves
    UiOnStored,           \* a screen's write applies its change to the
                          \* stored row; FALSE is the former updateTaskImpl,
                          \* which wrote the screen's whole TaskData under a
                          \* clock built on the stored row
    AgentOnStored,        \* a tool's write applies its change to the stored
                          \* row; FALSE is the former handlers, which wrote
                          \* their copy under a clock built on the copy's
    AgentCas,             \* the agent sets a field only while the stored
                          \* row holds the value it decided against
    UiRecordsStatus,      \* a status set from a screen is appended to the
                          \* status history, as the agent's is
    ResolveJoinsHistory   \* resolving a conflict keeps both sides' status
                          \* history

ASSUME "status" \in Fields /\ AgentDevices \subseteq Devices /\ 0 \notin Vals

Writers == {<<d, "ui">> : d \in Devices} \cup {<<d, "agent">> : d \in AgentDevices}
Edits == 1..MaxWrites

(* A version: its clock, its field values, and two ghosts.                 *)
(*   lin[f]  the writes whose value this version's field f knowingly       *)
(*           derives from: the write that set it, and every write of f it  *)
(*           was built over                                                *)
(*   hist    the status writes its status history records                  *)
NoVersion == [vc |-> [d \in Devices |-> 0], val |-> [f \in Fields |-> 0],
              lin |-> [f \in Fields |-> {}], hist |-> {}]
Init0 == NoVersion

VARIABLES
    row,       \* the stored task per device
    conf,      \* conflict rows per device: versions concurrent with row
    snap,      \* each writer's copy; NoVersion before its first Read
    reading,   \* whether each writer holds a copy it has not written yet
    ctr,       \* each device's own vector-clock counter
    net,       \* every version any device stored, for others to receive
    all,       \* ghost: every version any device stored
    moved,     \* ghost: status writes that changed the status
    blind,     \* ghost: agent writes over a value other than the one
               \* they decided against
    writes,
    resolves

vars == <<row, conf, snap, reading, ctr, net, all, moved, blind, writes,
          resolves>>

-----------------------------------------------------------------------------
Leq(a, b) == \A d \in Devices : a[d] <= b[d]
Join(a, b) == [d \in Devices |-> IF a[d] >= b[d] THEN a[d] ELSE b[d]]
Tick(vc, d) == [vc EXCEPT ![d] = ctr[d] + 1]

\* Stores version v on device d as its row, and offers it to the others.
Store(d, v) ==
    /\ row' = [row EXCEPT ![d] = v]
    /\ conf' = [conf EXCEPT ![d] = {c \in @ : ~Leq(c.vc, v.vc)}]
    /\ ctr' = [ctr EXCEPT ![d] = v.vc[d]]
    /\ net' = net \cup {v}
    /\ all' = all \cup {v}

-----------------------------------------------------------------------------
Init ==
    /\ row = [d \in Devices |-> Init0]
    /\ conf = [d \in Devices |-> {}]
    /\ snap = [w \in Writers |-> NoVersion]
    /\ reading = [w \in Writers |-> FALSE]
    /\ ctr = [d \in Devices |-> 0]
    /\ net = {}
    /\ all = {Init0}
    /\ moved = {}
    /\ blind = {}
    /\ writes = 0
    /\ resolves = 0

Read(w) ==
    /\ snap' = [snap EXCEPT ![w] = row[w[1]]]
    /\ reading' = [reading EXCEPT ![w] = TRUE]
    /\ UNCHANGED <<row, conf, ctr, net, all, moved, blind, writes, resolves>>

\* The version a write of field f to value x makes, as edit e by writer w.
\* `base` is the copy the data comes from, `clock` the clock it extends.
Written(w, f, x, e, base, clock, recordsStatus) ==
    LET changesStatus == f = "status" /\ x # base.val[f]
    IN [vc   |-> Tick(clock, w[1]),
        val  |-> [base.val EXCEPT ![f] = x],
        lin  |-> [base.lin EXCEPT ![f] = @ \cup {e}],
        hist |-> IF changesStatus /\ recordsStatus
                 THEN base.hist \cup {e} ELSE base.hist]

UiWrite(d, f, x) ==
    LET w == <<d, "ui">>
        s == row[d]
        e == writes + 1
        base == IF UiOnStored THEN s ELSE snap[w]
        v == Written(w, f, x, e, base, s.vc, UiRecordsStatus)
    IN
    /\ reading[w]
    /\ writes < MaxWrites
    \* A screen writes only a value it changes (on the copy it shows).
    /\ x # snap[w].val[f]
    /\ writes' = e
    /\ reading' = [reading EXCEPT ![w] = FALSE]
    /\ moved' = IF f = "status" /\ x # base.val[f] THEN moved \cup {e} ELSE moved
    /\ IF base.val[f] = x /\ UiOnStored
       THEN UNCHANGED <<row, conf, ctr, net, all>>   \* nothing to write
       ELSE Store(d, v)
    /\ UNCHANGED <<snap, blind, resolves>>

AgentWrite(d, f, x) ==
    LET w == <<d, "agent">>
        s == row[d]
        c == snap[w]
        e == writes + 1
        \* The tool compares against its copy (ADR 0075); with AgentCas the
        \* comparison is repeated on the stored row inside the write.
        stale == AgentCas /\ s.val[f] # c.val[f]
        base == IF AgentOnStored THEN s ELSE c
        clock == IF AgentOnStored THEN s.vc ELSE c.vc
        v == Written(w, f, x, e, base, clock, TRUE)
        \* The write decision: newer applies; concurrent is a conflict row.
        newer == Leq(s.vc, v.vc)
    IN
    /\ reading[w]
    /\ writes < MaxWrites
    /\ x # c.val[f]
    /\ writes' = e
    /\ reading' = [reading EXCEPT ![w] = FALSE]
    /\ IF stale \/ base.val[f] = x
       THEN /\ UNCHANGED <<row, conf, ctr, net, all, moved, blind>>
       ELSE /\ moved' = IF f = "status" THEN moved \cup {e} ELSE moved
            \* A value the user put back is the same value (ADR 0098's
            \* effect record answers a change applied twice), so only a
            \* different value counts as unseen.
            /\ blind' = IF newer /\ s.val[f] # c.val[f]
                        THEN blind \cup {e} ELSE blind
            /\ IF newer
               THEN Store(d, v)
               ELSE /\ conf' = [conf EXCEPT ![d] = @ \cup {v}]
                    /\ ctr' = [ctr EXCEPT ![d] = v.vc[d]]
                    /\ net' = net \cup {v}
                    /\ all' = all \cup {v}
                    /\ UNCHANGED row
    /\ UNCHANGED <<snap, resolves>>

Receive(d, m) ==
    LET s == row[d] IN
    /\ m \in net
    /\ ~Leq(m.vc, s.vc)
    /\ m \notin conf[d]
    /\ IF Leq(s.vc, m.vc)
       THEN /\ row' = [row EXCEPT ![d] = m]
            /\ conf' = [conf EXCEPT ![d] = {c \in @ : ~Leq(c.vc, m.vc)}]
       ELSE /\ conf' = [conf EXCEPT ![d] = @ \cup {m}]
            /\ UNCHANGED row
    /\ UNCHANGED <<snap, reading, ctr, net, all, moved, blind, writes, resolves>>

\* The user keeps `keep`'s fields; the version records both sides as seen.
Resolve(d, c, keepRemote) ==
    LET s == row[d]
        k == IF keepRemote THEN c ELSE s
        v == [vc   |-> Tick(Join(s.vc, c.vc), d),
              val  |-> k.val,
              lin  |-> [f \in Fields |-> s.lin[f] \cup c.lin[f]],
              hist |-> IF ResolveJoinsHistory THEN s.hist \cup c.hist
                       ELSE k.hist]
    IN
    /\ c \in conf[d]
    /\ resolves < MaxResolves
    /\ resolves' = resolves + 1
    /\ Store(d, v)
    /\ UNCHANGED <<snap, reading, moved, blind, writes>>

Next ==
    \/ \E w \in Writers : ~reading[w] /\ Read(w)
    \/ \E d \in Devices, f \in Fields, x \in Vals : UiWrite(d, f, x)
    \/ \E d \in AgentDevices, f \in Fields, x \in Vals : AgentWrite(d, f, x)
    \/ \E d \in Devices, m \in net : Receive(d, m)
    \/ \E d \in Devices, c \in UNION {conf[x] : x \in Devices},
          k \in BOOLEAN : c \in conf[d] /\ Resolve(d, c, k)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
Version == [vc : [Devices -> Nat], val : [Fields -> Vals \cup {0}],
            lin : [Fields -> SUBSET Edits], hist : SUBSET Edits]

TypeOK ==
    /\ \A d \in Devices : row[d] \in Version /\ conf[d] \subseteq Version
    /\ \A w \in Writers : snap[w] \in Version
    /\ writes \in 0..MaxWrites /\ resolves \in 0..MaxResolves
    /\ moved \subseteq Edits /\ blind \subseteq Edits

\* No stored version claims, by its clock, a version whose field edits it
\* does not hold: every edit an older version knew is still known.
NoLostFieldEdit ==
    \A d \in Devices, v \in all :
        Leq(v.vc, row[d].vc) =>
            \A f \in Fields : v.lin[f] \subseteq row[d].lin[f]

\* The status history records every status write the stored status derives
\* from.
HistoryComplete ==
    \A d \in Devices : row[d].lin["status"] \cap moved \subseteq row[d].hist

\* The agent never replaces a field value it did not see when it decided.
NoBlindAgentWrite == blind = {}

\* Once every version has reached every device and no conflict is open,
\* every device holds the same task.
Quiescent ==
    \A d \in Devices :
        /\ conf[d] = {}
        /\ \A m \in net : Leq(m.vc, row[d].vc)

Converged ==
    Quiescent => \A d, e \in Devices : row[d].val = row[e].val

=============================================================================

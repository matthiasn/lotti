--------------------- MODULE RelationshipAgentLifecycle ---------------------
(***************************************************************************)
(* One tracked person and the relationship agent that follows them, across *)
(* devices. The person is a journal entity (RelationshipEntry) with an     *)
(* `important` flag, the single consent switch for the agent (ADR 0059).   *)
(* The agent's identity has a deterministic id per person                  *)
(* (relationshipAgentIdFor), so every device that creates it writes the   *)
(* same row, and an `agentRelationship` link names the person it watches.  *)
(*                                                                         *)
(* The two halves travel on different paths. The person is a journal row:  *)
(* a version that dominates the stored one applies, two concurrent         *)
(* deletions merge, and any other concurrent pair is a conflict -- the     *)
(* device keeps its own version and records the other for the user        *)
(* (JournalDb.detectConflict, updateJournalEntity). The identity is an     *)
(* agent entity: a dominating version applies, and a concurrent pair is    *)
(* decided as a whole row by `updatedAt`, then a canonical clock order     *)
(* (resolveAgentEntityVersions; no rule looks at the lifecycle). Nothing   *)
(* orders the two paths against each other: a device can hold the agent   *)
(* and its link before it holds the person (an attachment-pending journal *)
(* row does not hold back later rows; a lost one waits for backfill).      *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Mark        PersonRemindersPill, RelationshipFormModal, contact      *)
(*               import: the person saved with `important`, then           *)
(*               ensureRelationshipAgentInBackground, unawaited (the job   *)
(*               "mark")                                                   *)
(*   Unmark      the pill's off switch: `important = false` only; the     *)
(*               agent is left alone and Phase A goes quiet                *)
(*   Edit        RelationshipFormModal save of the person, then, when it   *)
(*               is important, the same background ensure ("save"), which  *)
(*               writes the new title through to `displayName`             *)
(*   Delete      RelationshipRepository.deleteRelationship. From the      *)
(*               person page (page = TRUE) it is followed by               *)
(*               handleRelationshipDeleted, unawaited ("teardown"); from   *)
(*               the generic journal path it is not                        *)
(*   Ensure      RelationshipAgentService.ensureAgentForRelationship: an   *)
(*               existing identity, whatever its lifecycle, is kept        *)
(*               (renamed on "save"); with none, identity and link are     *)
(*               written in one transaction                                *)
(*   Teardown    handleRelationshipDeleted: AgentService.destroyAgent      *)
(*   Reap        RelationshipRuntimeMaintenance._reapIfRelationshipGone,   *)
(*               before every scheduled-wake scan, for each ACTIVE agent   *)
(*               whose link the device holds. The person is read through   *)
(*               journalEntityById, which returns no row for a tombstone   *)
(*               and for a row that never arrived alike                    *)
(*   Reconciles  RelationshipAgentService.reconcileAgent from the same     *)
(*               maintenance pass: a live person's agent set to what the   *)
(*               user last asked for (reconcileRelationshipAgent)          *)
(*   Stop        AgentControls destroy; pause with Pauses                 *)
(*   Resume      AgentControls resume                                      *)
(*   HardDelete  AgentService.deleteAgent on a destroyed agent, which is a *)
(*               stop as well: the rows go, the id is recorded in          *)
(*               `deleted_agents`, and every later write about it is       *)
(*               refused (refusesWriteAboutDeletedAgent, ADR 0108)         *)
(*   Resolve     the conflict page: the user keeps one side, written as a  *)
(*               version whose clock covers both                           *)
(*   Crash       process death: the unawaited jobs are lost                *)
(*   Deliver     SyncEventProcessor, one message at a time, in any order   *)
(*                                                                         *)
(* Not modelled: Phase A and Phase B (a destroyed or dormant agent never   *)
(* wakes: WakeDrainEngine refuses it); cadence and reports; lost           *)
(* deliveries (JournalReplication and AgentReplication model loss and      *)
(* backfill -- here every message arrives, however late); clock skew       *)
(* (every timestamp is the step order).                                    *)
(*                                                                         *)
(* The design switches are ADR 0111's fixes: TRUE is the code, FALSE the   *)
(* code at 9f1fec4e5 before it (the README lists each counterexample). The *)
(* stamps: the person's `mt` is `importantSince`, and the identity's       *)
(* `lts`, `ust`, `usk` and `urs` are `lifecycleUpdatedAt`,                 *)
(* `userStoppedAt`, `userStopLifecycle` and `userResumedAt`. The model's   *)
(* joined clock on a concurrent merge is the code's join of these fields   *)
(* on every receive                                                        *)
(* (joinIdentityDecisions). The conformance trace is                       *)
(* relationship_agent_lifecycle_model_conformance.dart.                    *)
(***************************************************************************)
EXTENDS Naturals

CONSTANTS
    N,                  \* devices 1..N; the person is created on device 1
    MaxPersonWrites,    \* person versions written, all devices together
    MaxAgentWrites,     \* identity versions written, all devices together
    MaxCrashes,
    MaxStops,           \* user destroys, pauses and hard deletes, together
    Conflicts,          \* may the user resolve a person conflict?
    Pauses,             \* may the user pause and resume the agent?
    HardDeletes,        \* may the user hard-delete a destroyed agent?
    \* Design switches.
    ReapNeedsTombstone, \* reap only over a person tombstone, never over a
                        \* person this device does not hold
    Reconcile,          \* for a live person the maintenance pass sets the
                        \* lifecycle the user's latest word asks for: the
                        \* stop if it is newer than the last mark or resume,
                        \* else active if the person is important; and it
                        \* creates a missing agent
    FieldMerge,         \* two concurrent identity versions merge field by
                        \* field: the lifecycle by its own stamp `lts`, the
                        \* user's last stop and resume by their stamps, all
                        \* under the joined clock. FALSE: the whole row by
                        \* `updatedAt`
    HardDeleteStops,    \* a hard delete first sends the user's stop, so
                        \* every device learns of it; FALSE: local only
    CreateHonorsDeleted \* the background ensure never recreates an agent
                        \* this device deleted; only the maintenance pass
                        \* does, for a mark newer than the delete, clearing
                        \* the `deleted_agents` entry

ASSUME N >= 2
ASSUME \A b \in {Conflicts, Pauses, HardDeletes, ReapNeedsTombstone,
                 Reconcile, FieldMerge, HardDeleteStops,
                 CreateHonorsDeleted} :
    b \in BOOLEAN

R == 1..N
Zero == [r \in R |-> 0]
Max2(a, b) == IF a > b THEN a ELSE b
Join(a, b) == [r \in R |-> Max2(a[r], b[r])]
Leq(a, b) == \A r \in R : a[r] <= b[r]
\* VectorClock.compare(stored, incoming).
Cmp(a, b) ==
    IF a = b THEN "equal"
    ELSE IF Leq(a, b) THEN "b_gt_a"
    ELSE IF Leq(b, a) THEN "a_gt_b"
    ELSE "concurrent"
\* VectorClock.compareCanonically: any total order every device shares.
FirstDiff(a, b) ==
    CHOOSE r \in R : a[r] # b[r] /\ \A s \in R : s < r => a[s] = b[s]
CanonGt(a, b) == a # b /\ a[FirstDiff(a, b)] > b[FirstDiff(a, b)]

\* A person version: `st` is "none" for no row; `mt` is when `important`
\* was last switched on (0: never). An identity version: `lc` is "none" for
\* no row; `ts` is `updatedAt`, bumped by every write; `lts` is bumped by a
\* lifecycle change or a user decision, never by a rename; `ust` is when
\* the user last stopped the agent and `usk` the lifecycle that stop set
\* (destroy and hard delete: destroyed, pause: dormant); `urs` is when the
\* user last resumed it. Every stamp is the step order, so along any causal
\* chain it only grows.
NoP == [st |-> "none", imp |-> FALSE, mt |-> 0, vc |-> Zero]
NoI == [lc |-> "none", lts |-> 0, ust |-> 0, usk |-> "none", urs |-> 0,
        vc |-> Zero, ts |-> 0]
PM(v) == [k |-> "person", p |-> v, i |-> NoI]
IM(v) == [k |-> "ident", p |-> NoP, i |-> v]
LM == [k |-> "link", p |-> NoP, i |-> NoI]

VARIABLES
    person,      \* per device: the stored person version
    pconf,       \* per device: person versions held as open conflicts
    ident,       \* per device: the stored identity version
    link,        \* per device: the agentRelationship link is held
    gone,        \* per device: when it deleted the agent (0: it did not)
    inbox,       \* per device: messages sent to it, not yet applied
    pend,        \* per device: unawaited jobs not yet run
    hc,          \* per device: the last clock counter it issued
    now,         \* step order: the stamp of the next write
    pw, aw,      \* person and identity writes so far (bounds)
    crashes, stops,
    everDeleted, \* ghost: someone deleted the person
    badReap,     \* ghost: a reap ran while nobody had deleted the person
    lastMark,    \* ghost: when the user last asked for the agent (mark
                 \* or resume)
    lastResume,  \* ghost: when the user last resumed it
    lastStop     \* ghost: when the user last stopped it

vars == <<person, pconf, ident, link, gone, inbox, pend, hc, now, pw, aw,
          crashes, stops, everDeleted, badReap, lastMark, lastResume,
          lastStop>>

P0 == [st |-> "live", imp |-> FALSE, mt |-> 0,
       vc |-> [r \in R |-> IF r = 1 THEN 1 ELSE 0]]

Init ==
    /\ person = [d \in R |-> IF d = 1 THEN P0 ELSE NoP]
    /\ pconf = [d \in R |-> {}]
    /\ ident = [d \in R |-> NoI]
    /\ link = [d \in R |-> FALSE]
    /\ gone = [d \in R |-> 0]
    /\ inbox = [d \in R |-> IF d = 1 THEN {} ELSE {PM(P0)}]
    /\ pend = [d \in R |-> {}]
    /\ hc = [d \in R |-> IF d = 1 THEN 1 ELSE 0]
    /\ now = 0
    /\ pw = 1
    /\ aw = 0
    /\ crashes = 0
    /\ stops = 0
    /\ everDeleted = FALSE
    /\ badReap = FALSE
    /\ lastMark = 0
    /\ lastResume = 0
    /\ lastStop = 0

-----------------------------------------------------------------------------
\* Writes. Each one takes the next clock counter of its device over the
\* version it replaces, and is sent to every other device.

Send(d, ms) == [e \in R |-> IF e = d THEN inbox[e] ELSE inbox[e] \cup ms]

\* An applied person version settles every conflict it covers
\* (_settleConflictCoveredBy).
Settle(cs, v) == {c \in cs : ~Leq(c.vc, v.vc)}

PWrite(d, st, imp, mt) ==
    LET v == [st |-> st, imp |-> imp, mt |-> mt,
              vc |-> [person[d].vc EXCEPT ![d] = hc[d] + 1]] IN
    /\ pw < MaxPersonWrites
    /\ person' = [person EXCEPT ![d] = v]
    /\ pconf' = [pconf EXCEPT ![d] = Settle(@, v)]
    /\ hc' = [hc EXCEPT ![d] = @ + 1]
    /\ pw' = pw + 1
    /\ now' = now + 1
    /\ inbox' = Send(d, {PM(v)})

\* An identity write over the stored version: a new lifecycle `lc` (the
\* stored one for a rename), and whether it is the user's "stop" or
\* "resume" ("none" otherwise).
NewI(d, lc, user) ==
    [lc |-> lc,
     lts |-> IF lc # ident[d].lc \/ user # "none" THEN now + 1
             ELSE ident[d].lts,
     ust |-> IF user = "stop" THEN now + 1 ELSE ident[d].ust,
     usk |-> IF user = "stop" THEN lc ELSE ident[d].usk,
     urs |-> IF user = "resume" THEN now + 1 ELSE ident[d].urs,
     vc |-> [ident[d].vc EXCEPT ![d] = hc[d] + 1],
     ts |-> now + 1]

IWrite(d, lc, user) ==
    LET v == NewI(d, lc, user) IN
    /\ aw < MaxAgentWrites
    /\ ident' = [ident EXCEPT ![d] = v]
    /\ hc' = [hc EXCEPT ![d] = @ + 1]
    /\ aw' = aw + 1
    /\ now' = now + 1
    /\ inbox' = Send(d, {IM(v)})

\* The creation: identity and link in one transaction, the identity a new
\* row (createAgent). `clear` drops this device's `deleted_agents` entry.
Create(d, clear) ==
    LET v == [lc |-> "active", lts |-> now + 1, ust |-> 0, usk |-> "none",
              urs |-> 0,
              vc |-> [Zero EXCEPT ![d] = hc[d] + 1], ts |-> now + 1] IN
    /\ aw < MaxAgentWrites
    /\ ident' = [ident EXCEPT ![d] = v]
    /\ link' = [link EXCEPT ![d] = TRUE]
    /\ gone' = [gone EXCEPT ![d] = IF clear THEN 0 ELSE @]
    /\ hc' = [hc EXCEPT ![d] = @ + 1]
    /\ aw' = aw + 1
    /\ now' = now + 1
    /\ inbox' = Send(d, {IM(v), LM})

-----------------------------------------------------------------------------
\* What a device decides from what it holds.

PersonGone(d) ==
    \/ person[d].st = "dead"
    \/ ~ReapNeedsTombstone /\ person[d].st = "none"

CanReap(d) ==
    /\ ident[d].lc = "active"
    /\ link[d]
    /\ PersonGone(d)

\* For a live person, the lifecycle the user's latest word asks for: the
\* last stop if it is newer than the last mark and resume, else active if
\* the person is important. An unimportant person's agent is left as it is
\* (Phase A keeps it quiet). The last mark is the newest this device holds,
\* in its person version or in an open conflict.
MaxOf(S) == CHOOSE x \in S : \A y \in S : y <= x
Asked(d) == MaxOf({person[d].mt, ident[d].urs} \cup {c.mt : c \in pconf[d]})
Target(d) ==
    IF ident[d].ust > Asked(d) THEN ident[d].usk
    ELSE IF person[d].imp THEN "active"
    ELSE ident[d].lc

\* The pass creates a missing agent -- a lost background ensure, a peer's
\* creation not yet arrived, a delete older than the last mark -- and sets
\* the target over whatever the merge, the reaper or the cascade left.
\* While the person has an open conflict it only ever stops the agent.
CanReconcile(d) ==
    /\ Reconcile
    /\ person[d].st = "live"
    /\ IF ident[d].lc = "none"
       THEN pconf[d] = {} /\ person[d].imp /\ gone[d] < person[d].mt
       ELSE /\ Target(d) # ident[d].lc
            /\ pconf[d] = {} \/ Target(d) \in {"dormant", "destroyed"}

-----------------------------------------------------------------------------
\* Steps.

Mark(d) ==
    /\ person[d].st = "live"
    /\ ~person[d].imp
    /\ PWrite(d, "live", TRUE, now + 1)
    /\ pend' = [pend EXCEPT ![d] = @ \cup {"mark"}]
    /\ lastMark' = now + 1
    /\ UNCHANGED <<ident, link, gone, aw, crashes, stops, everDeleted,
                   badReap, lastResume, lastStop>>

Unmark(d) ==
    /\ person[d].st = "live"
    /\ person[d].imp
    /\ PWrite(d, "live", FALSE, person[d].mt)
    /\ UNCHANGED <<ident, link, gone, pend, aw, crashes, stops, everDeleted,
                   badReap, lastMark, lastResume, lastStop>>

Edit(d) ==
    /\ person[d].st = "live"
    /\ PWrite(d, "live", person[d].imp, person[d].mt)
    /\ pend' = [pend EXCEPT ![d] = IF person[d].imp THEN @ \cup {"save"}
                                    ELSE @]
    /\ UNCHANGED <<ident, link, gone, aw, crashes, stops, everDeleted,
                   badReap, lastMark, lastResume, lastStop>>

Delete(d, page) ==
    /\ person[d].st = "live"
    /\ PWrite(d, "dead", person[d].imp, person[d].mt)
    /\ pend' = [pend EXCEPT ![d] = IF page THEN @ \cup {"teardown"} ELSE @]
    /\ everDeleted' = TRUE
    /\ UNCHANGED <<ident, link, gone, aw, crashes, stops, badReap, lastMark,
                   lastResume, lastStop>>

Resolve(d, c, keepLocal) ==
    LET kept == IF keepLocal THEN person[d] ELSE c
        v == [kept EXCEPT !.vc = [Join(person[d].vc, c.vc) EXCEPT
                                    ![d] = hc[d] + 1]] IN
    /\ Conflicts
    /\ c \in pconf[d]
    /\ pw < MaxPersonWrites
    /\ person' = [person EXCEPT ![d] = v]
    /\ pconf' = [pconf EXCEPT ![d] = Settle(@ \ {c}, v)]
    /\ hc' = [hc EXCEPT ![d] = @ + 1]
    /\ pw' = pw + 1
    /\ now' = now + 1
    /\ inbox' = Send(d, {PM(v)})
    /\ UNCHANGED <<ident, link, gone, pend, aw, crashes, stops, everDeleted,
                   badReap, lastMark, lastResume, lastStop>>

\* The background ensure. With no identity it creates one -- over a
\* `deleted_agents` entry too, unless CreateHonorsDeleted. An existing one
\* is kept whatever its lifecycle; "save" writes the title through, which
\* rewrites the row with the lifecycle it read.
Ensure(d, why) ==
    /\ why \in pend[d] \cap {"mark", "save"}
    /\ pend' = [pend EXCEPT ![d] = @ \ {why}]
    /\ IF ident[d].lc = "none"
       THEN IF CreateHonorsDeleted /\ gone[d] > 0
            THEN UNCHANGED <<ident, link, gone, hc, aw, now, inbox>>
            ELSE Create(d, FALSE)
       ELSE IF why = "save"
       THEN IWrite(d, ident[d].lc, "none") /\ UNCHANGED <<link, gone>>
       ELSE UNCHANGED <<ident, link, gone, hc, aw, now, inbox>>
    /\ UNCHANGED <<person, pconf, pw, crashes, stops, everDeleted, badReap,
                   lastMark, lastResume, lastStop>>

Teardown(d) ==
    /\ "teardown" \in pend[d]
    /\ pend' = [pend EXCEPT ![d] = @ \ {"teardown"}]
    /\ IF ident[d].lc \in {"active", "dormant"}
       THEN IWrite(d, "destroyed", "none")
       ELSE UNCHANGED <<ident, hc, aw, now, inbox>>
    /\ UNCHANGED <<person, pconf, link, gone, pw, crashes, stops,
                   everDeleted, badReap, lastMark, lastResume, lastStop>>

Reap(d) ==
    /\ CanReap(d)
    /\ IWrite(d, "destroyed", "none")
    /\ badReap' = (badReap \/ ~everDeleted)
    /\ UNCHANGED <<person, pconf, link, gone, pend, pw, crashes, stops,
                   everDeleted, lastMark, lastResume, lastStop>>

Reconciles(d) ==
    /\ CanReconcile(d)
    /\ IF ident[d].lc = "none"
       THEN Create(d, TRUE)
       ELSE IWrite(d, Target(d), "none") /\ UNCHANGED <<link, gone>>
    /\ UNCHANGED <<person, pconf, pend, pw, crashes, stops, everDeleted,
                   badReap, lastMark, lastResume, lastStop>>

UserDestroy(d) ==
    /\ stops < MaxStops
    /\ ident[d].lc \in {"active", "dormant"}
    /\ IWrite(d, "destroyed", "stop")
    /\ stops' = stops + 1
    /\ lastStop' = now + 1
    /\ UNCHANGED <<person, pconf, link, gone, pend, pw, crashes, everDeleted,
                   badReap, lastMark, lastResume>>

Pause(d) ==
    /\ Pauses
    /\ stops < MaxStops
    /\ ident[d].lc = "active"
    /\ IWrite(d, "dormant", "stop")
    /\ stops' = stops + 1
    /\ lastStop' = now + 1
    /\ UNCHANGED <<person, pconf, link, gone, pend, pw, crashes, everDeleted,
                   badReap, lastMark, lastResume>>

Resume(d) ==
    /\ Pauses
    /\ ident[d].lc = "dormant"
    /\ IWrite(d, "active", "resume")
    /\ lastMark' = now + 1
    /\ lastResume' = now + 1
    /\ UNCHANGED <<person, pconf, link, gone, pend, pw, crashes, stops,
                   everDeleted, badReap, lastStop>>

\* A hard delete is the user's stop too. With HardDeleteStops it first
\* writes and sends that stop, then drops the rows here.
HardDelete(d) ==
    LET v == NewI(d, "destroyed", "stop") IN
    /\ HardDeletes
    /\ stops < MaxStops
    /\ ident[d].lc = "destroyed"
    /\ HardDeleteStops => aw < MaxAgentWrites
    /\ ident' = [ident EXCEPT ![d] = NoI]
    /\ link' = [link EXCEPT ![d] = FALSE]
    /\ gone' = [gone EXCEPT ![d] = now + 1]
    /\ now' = now + 1
    /\ lastStop' = now + 1
    /\ stops' = stops + 1
    /\ IF HardDeleteStops
       THEN /\ inbox' = Send(d, {IM(v)})
            /\ hc' = [hc EXCEPT ![d] = @ + 1]
            /\ aw' = aw + 1
       ELSE UNCHANGED <<inbox, hc, aw>>
    /\ UNCHANGED <<person, pconf, pend, pw, crashes, everDeleted, badReap,
                   lastMark, lastResume>>

Crash(d) ==
    /\ crashes < MaxCrashes
    /\ pend[d] # {}
    /\ pend' = [pend EXCEPT ![d] = {}]
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<person, pconf, ident, link, gone, inbox, hc, now, pw, aw,
                   stops, everDeleted, badReap, lastMark, lastResume,
                   lastStop>>

\* Applying one person version (updateJournalEntity on receive).
RecvPerson(d, v) ==
    LET cur == person[d]
        s == Cmp(cur.vc, v.vc) IN
    IF cur.st = "none" \/ s = "b_gt_a"
    THEN /\ person' = [person EXCEPT ![d] = v]
         /\ pconf' = [pconf EXCEPT ![d] = Settle(@, v)]
    ELSE IF s = "concurrent" /\ cur.st = "dead" /\ v.st = "dead"
    THEN LET m == [cur EXCEPT !.vc = Join(cur.vc, v.vc)] IN
         /\ person' = [person EXCEPT ![d] = m]
         /\ pconf' = [pconf EXCEPT ![d] = Settle(@, m)]
    ELSE IF s = "concurrent"
    THEN /\ pconf' = [pconf EXCEPT ![d] = @ \cup {v}]
         /\ UNCHANGED person
    ELSE UNCHANGED <<person, pconf>>

\* Two concurrent identity versions. The code keeps the whole row with the
\* later `updatedAt` (then the canonical clock order). FieldMerge takes the
\* lifecycle with the later `lts`, the stop with the later `ust` (each then
\* the clock order), the later resume, and the joined clock, so the result
\* covers both. Each field is a join, so the merge is too.
Later(a, b, fa, fb) == fa > fb \/ (fa = fb /\ CanonGt(a.vc, b.vc))
Merge(cur, v) ==
    IF FieldMerge
    THEN LET w == IF Later(v, cur, v.lts, cur.lts) THEN v ELSE cur
             u == IF Later(v, cur, v.ust, cur.ust) THEN v ELSE cur IN
         [lc |-> w.lc, lts |-> w.lts, ust |-> u.ust, usk |-> u.usk,
          urs |-> Max2(cur.urs, v.urs),
          vc |-> Join(cur.vc, v.vc), ts |-> Max2(cur.ts, v.ts)]
    ELSE IF Later(v, cur, v.ts, cur.ts) THEN v ELSE cur

\* Applying one identity version (resolveReceivedAgentEntity), unless this
\* device deleted the agent.
RecvIdent(d, v) ==
    LET cur == ident[d]
        s == Cmp(cur.vc, v.vc) IN
    IF gone[d] > 0 THEN UNCHANGED ident
    ELSE IF cur.lc = "none" \/ s = "b_gt_a"
    THEN ident' = [ident EXCEPT ![d] = v]
    ELSE IF s = "concurrent"
    THEN ident' = [ident EXCEPT ![d] = Merge(cur, v)]
    ELSE UNCHANGED ident

Deliver(d, m) ==
    /\ m \in inbox[d]
    /\ inbox' = [inbox EXCEPT ![d] = @ \ {m}]
    /\ CASE m.k = "person" ->
              RecvPerson(d, m.p) /\ UNCHANGED <<ident, link>>
         [] m.k = "ident" ->
              RecvIdent(d, m.i) /\ UNCHANGED <<person, pconf, link>>
         [] m.k = "link" ->
              /\ link' = [link EXCEPT ![d] = IF gone[d] > 0 THEN @ ELSE TRUE]
              /\ UNCHANGED <<person, pconf, ident>>
    /\ UNCHANGED <<gone, pend, hc, now, pw, aw, crashes, stops, everDeleted,
                   badReap, lastMark, lastResume, lastStop>>

Next ==
    \E d \in R :
        \/ Mark(d) \/ Unmark(d) \/ Edit(d)
        \/ \E page \in BOOLEAN : Delete(d, page)
        \/ \E c \in pconf[d] : \E keep \in BOOLEAN : Resolve(d, c, keep)
        \/ \E why \in {"mark", "save"} : Ensure(d, why)
        \/ Teardown(d) \/ Reap(d) \/ Reconciles(d)
        \/ UserDestroy(d) \/ Pause(d) \/ Resume(d) \/ HardDelete(d)
        \/ Crash(d)
        \/ \E m \in inbox[d] : Deliver(d, m)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
\* Properties.

PVersions == [st : {"none", "live", "dead"}, imp : BOOLEAN, mt : Nat,
              vc : [R -> Nat]]
Lifecycles == {"none", "active", "dormant", "destroyed"}
IVersions == [lc : Lifecycles, lts : Nat, ust : Nat, usk : Lifecycles,
              urs : Nat, vc : [R -> Nat], ts : Nat]

TypeOK ==
    /\ person \in [R -> PVersions]
    /\ \A d \in R : pconf[d] \subseteq PVersions
    /\ ident \in [R -> IVersions]
    /\ link \in [R -> BOOLEAN]
    /\ gone \in [R -> Nat]
    /\ pend \in [R -> SUBSET {"mark", "save", "teardown"}]
    /\ badReap \in BOOLEAN

\* Every message applied, every unawaited job run or lost, and the
\* maintenance pass has nothing left to do on any device.
Quiescent ==
    \A d \in R :
        inbox[d] = {} /\ pend[d] = {} /\ ~CanReap(d) /\ ~CanReconcile(d)

\* Every device holds the same person version and no open conflict.
PersonAgreed ==
    \A d, e \in R : person[d] = person[e] /\ pconf[d] = {}

\* A device that deleted the agent holds no row: it counts as destroyed.
Lc(d) == IF ident[d].lc = "none" /\ gone[d] > 0 THEN "destroyed"
         ELSE ident[d].lc

\* The reaper only ever tears down an agent whose person somebody deleted.
NoReapOfLivePerson == ~badReap

\* A live person the user asked to track has an active agent on every
\* device, unless the user stopped it after last asking. The ask is the mark
\* the agreed person carries -- resolving a conflict may keep an older one
\* and drop a later mark -- or a later resume.
Tracked ==
    (Quiescent /\ PersonAgreed /\ person[1].st = "live" /\ person[1].imp
     /\ lastStop < Max2(person[1].mt, lastResume))
        => \A d \in R : ident[d].lc = "active"

\* A deleted person has no active agent anywhere.
Untracked ==
    (Quiescent /\ PersonAgreed /\ person[1].st = "dead")
        => \A d \in R : ident[d].lc # "active"

\* The user's stop holds until the user asks again.
StopSticks ==
    (Quiescent /\ stops > 0 /\ lastStop > lastMark)
        => \A d \in R : ident[d].lc # "active"

\* Once the devices agree on the person, they agree on the agent's
\* lifecycle. (While a conflict is open, each device follows the person it
\* holds: one that holds the tombstone may keep the agent destroyed.)
Converged ==
    (Quiescent /\ PersonAgreed) => \A d, e \in R : Lc(d) = Lc(e)
=============================================================================

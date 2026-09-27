---------------------------- MODULE TaskLinkGraph ----------------------------
(***************************************************************************)
(* The graph the task entry links make, across devices.                   *)
(* `EntryLinkIdentity` settles one link: every device keeps the same       *)
(* version of each (fromId, toId, type). This spec asks what the links     *)
(* say together:                                                           *)
(*                                                                         *)
(*   - `blocks` links between tasks. A task is blocked while a live       *)
(*     `blocks` link names it and its blocker is open (ADR 0042 section    *)
(*     4); a closed or deleted blocker releases it. Creating a link, or    *)
(*     retyping one onto `blocks`, is refused when it would close a cycle  *)
(*     (ADR 0042 section 5).                                               *)
(*   - `ProjectLink`s, project to task. A task belongs to at most one      *)
(*     project; the one shown is the live link with the latest updatedAt,  *)
(*     then the greatest id (`_projectIdSubquery`, `projectLinkForTask`).  *)
(*                                                                         *)
(* Devices write links and close tasks, and every version reaches every    *)
(* device in any order, any number of times. A version of one link is the  *)
(* write number that made it, its updatedAt and whether it is live; the    *)
(* receive keeps the greater under ADR 0078's order, which the write       *)
(* number stands in for past updatedAt. A task's status is one register   *)
(* ordered the same way.                                                   *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Create        PersistenceLogic.createLink with EntryLinkType.blocks: *)
(*                 the check (`wouldCreateBlocksCycle`) and the write     *)
(*                 (`linkCreationBase`, `upsertEntryLink`) in one step    *)
(*   Flip          JournalRepository.updateLinkType turning a `blocks`    *)
(*                 link around, its own row left out of the check. A      *)
(*                 retype onto `blocks` from another type is Create for   *)
(*                 the graph                                              *)
(*   AgentCheck,   the task agent's link tool (`TaskLinkHandler`, which   *)
(*   AgentWrite    calls createLink) on device 1 at the same time as the  *)
(*                 user: its check passes, and its write -- after the     *)
(*                 fix, with the check again inside the write's           *)
(*                 transaction -- comes after any other step              *)
(*   Remove        JournalRepository.removeTypedLink                       *)
(*   Close         a task set DONE or REJECTED, or deleted                 *)
(*   File          ProjectRepository.linkTaskToProject: file or move       *)
(*   Unfile        ProjectRepository.unlinkTaskFromProject                 *)
(*   Deliver*      JournalDb.upsertEntryLink and updateJournalEntity       *)
(*                                                                         *)
(* The readers: `Blocked` is TaskBlockersController and                    *)
(* TaskDependencyResolver, `Cycle` their cycle report                      *)
(* (`findBlockersInCycle`), `Shown` the denormalized project id.           *)
(*                                                                         *)
(* No crash: every write here is one transaction, so a crash loses an      *)
(* operation whole. Loss and backfill are `SyncPipeline`'s: a backfill     *)
(* answers with the writer's stored version of the link, which is the      *)
(* lost one or its successor -- a later delivery, as here.                 *)
(*                                                                         *)
(* The design switches are the fixes of ADR 0106; FALSE restores the old   *)
(* behaviour and its counterexample (README). `ReleaseByStatus` and        *)
(* `DeterministicWinner` are not fixes: today's code has them, and FALSE   *)
(* shows that the property they carry can fail.                            *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    ND,         \* devices 1..ND
    NT,         \* tasks 1..NT
    NP,         \* projects 1..NP
    MaxWrites,  \* writes, across all devices
    MaxTime,    \* the wall clock runs 0..MaxTime
    Skew,       \* how far a write's updatedAt may lag the clock
    HopCap,     \* the cycle check's depth when it is capped
    \* Design switches: TRUE is the code after ADR 0106.
    AtomicCheck,       \* the cycle check runs again inside the write
    Uncapped,          \* the cycle check follows every path
    DetectCycle,       \* the readers report a cycle of open tasks
    RetireAll,         \* a move or unfile removes every live project link
    \* Not fixes: TRUE is today's code, FALSE a mutation.
    ReleaseByStatus,   \* a closed blocker releases what it blocks
    DeterministicWinner \* the project shown is a function of the rows

Devices == 1..ND
Tasks == 1..NT
Projects == 1..NP

ASSUME \A b \in {AtomicCheck, Uncapped, DetectCycle, RetireAll,
                 ReleaseByStatus, DeterministicWinner} : b \in BOOLEAN

BKeys == {k \in Tasks \X Tasks : k[1] # k[2]}
PKeys == Projects \X Tasks

\* A version of a link: the write that made it (0: none), its writer, its
\* updatedAt, and whether it is live.
Absent == [w |-> 0, by |-> 0, ts |-> 0, live |-> FALSE]

\* ADR 0078's order: the later updatedAt, then -- standing in for the
\* clock and the content -- the later write.
Greater(a, b) == a.ts > b.ts \/ (a.ts = b.ts /\ a.w > b.w)

Max(a, b) == IF a > b THEN a ELSE b

NoOp == [op |-> "none", a |-> 0, b |-> 0]

VARIABLES
    blinks,      \* per device: the stored version of each blocks link
    plinks,      \* per device: the stored version of each project link
    closed,      \* per device: each task's status, [w, closed]
    now,         \* the wall clock
    wc,          \* writes made
    pending,     \* the agent's create or flip on device 1 that passed its
                 \* pre-check and has not written yet
    bsent,       \* blocks messages: a set of <<key, version>> each (a flip
                 \* moves one link, so it lands on both keys at once)
    psent,       \* project link messages, <<key, version>>
    tsent,       \* task status messages, <<task, status>>
    localCycle,  \* ghost: a device wrote a blocks link closing a cycle it
                 \* held at that moment
    filings,     \* ghost: per project write, the task and the live
                 \* project link versions its writer held
    filingLost   \* ghost: a device filed a task and did not show it there

vars == <<blinks, plinks, closed, now, wc, pending, bsent, psent, tsent,
          localCycle, filings, filingLost>>

Init ==
    /\ blinks = [d \in Devices |-> [k \in BKeys |-> Absent]]
    /\ plinks = [d \in Devices |-> [k \in PKeys |-> Absent]]
    /\ closed = [d \in Devices |->
                    [t \in Tasks |-> [w |-> 0, closed |-> FALSE]]]
    /\ now = 0
    /\ wc = 0
    /\ pending = NoOp
    /\ bsent = {}
    /\ psent = {}
    /\ tsent = {}
    /\ localCycle = FALSE
    /\ filings = {}
    /\ filingLost = FALSE

---------------------------------------------------------------------------
(* The readers. *)

IsOpen(d, t) == ~closed[d][t].closed
LiveB(d) == {k \in BKeys : blinks[d][k].live}

\* A path of at most n links from x to y.
RECURSIVE Reach(_, _, _, _)
Reach(E, x, y, n) ==
    /\ n > 0
    /\ \/ <<x, y>> \in E
       \/ \E z \in Tasks : <<x, z>> \in E /\ Reach(E, z, y, n - 1)

\* TaskBlockersController and TaskDependencyResolver: one hop.
Blocked(d, t) ==
    \E b \in Tasks : <<b, t>> \in LiveB(d) /\ (ReleaseByStatus => IsOpen(d, b))

\* The links that block: live, from an open task.
Blocking(d) == {k \in LiveB(d) : IsOpen(d, k[1])}

\* The readers' cycle report: the task is blocked by a task it blocks.
Cycle(d, t) == DetectCycle /\ Reach(Blocking(d), t, t, NT)

\* The cycle check (`wouldCreateBlocksCycle`): a new link from `from` to
\* `to` closes a cycle when `to` already reaches `from`, over every live
\* link but the ones in `except`.
Hops == IF Uncapped THEN NT ELSE HopCap
Closes(d, from, to, except) ==
    from = to \/ Reach(LiveB(d) \ except, to, from, Hops)

\* The same, over every path: whether the write really closed one.
ClosesReally(d, from, to, except) == Reach(LiveB(d) \ except, to, from, NT)

LiveP(d, t) == {p \in Projects : plinks[d][<<p, t>>].live}

\* `_projectIdSubquery`: the latest updatedAt, then the greatest id. The
\* mutation lets a device prefer the link it wrote itself.
Beats(d, t, p, q) ==
    LET vp == plinks[d][<<p, t>>]
        vq == plinks[d][<<q, t>>]
    IN IF ~DeterministicWinner /\ (vp.by = d) # (vq.by = d)
       THEN vp.by = d
       ELSE vp.ts > vq.ts \/ (vp.ts = vq.ts /\ p >= q)

Shown(d, t) ==
    IF LiveP(d, t) = {} THEN 0
    ELSE CHOOSE p \in LiveP(d, t) : \A q \in LiveP(d, t) : Beats(d, t, p, q)

---------------------------------------------------------------------------
(* Writes. *)

Stamps == (IF now > Skew THEN now - Skew ELSE 0)..now

\* A write's next version of a link: the stored one's successor, never
\* stamped earlier (`linkEditTimestamp`).
Succ(stored, d, live, t) ==
    [w |-> wc + 1, by |-> d, ts |-> Max(t, stored.ts), live |-> live]

CanWrite == wc < MaxWrites

\* A new blocks link a -> b on device d (`PersistenceLogic.createLink`),
\* past its pre-check. `linkCreationBase` finds the link live and writes
\* nothing; after the fix the write's transaction runs the cycle check
\* again, over what it holds now.
WriteCreate(d, a, b) ==
    LET k == <<a, b>>
    IN IF ~CanWrite \/ blinks[d][k].live
              \/ (AtomicCheck /\ Closes(d, a, b, {}))
       THEN UNCHANGED <<blinks, wc, bsent, localCycle>>
       ELSE \E t \in Stamps :
              LET v == Succ(blinks[d][k], d, TRUE, t)
              IN /\ blinks' = [blinks EXCEPT ![d][k] = v]
                 /\ wc' = wc + 1
                 /\ bsent' = bsent \cup {{<<k, v>>}}
                 /\ localCycle' = (localCycle \/ ClosesReally(d, a, b, {}))

\* Turning a -> b around (`updateLinkType` with swapDirection), past its
\* pre-check: one version of the one link, which every receiver applies to
\* both triples at once. After the fix the transaction checks again that
\* the link is still live, that no other live link is b -> a, and that
\* b -> a closes no cycle over every link but this one.
WriteFlip(d, a, b) ==
    LET old == <<a, b>>
        new == <<b, a>>
    IN IF ~CanWrite
              \/ (AtomicCheck /\ (~blinks[d][old].live
                                  \/ blinks[d][new].live
                                  \/ Closes(d, b, a, {old})))
       THEN UNCHANGED <<blinks, wc, bsent, localCycle>>
       ELSE \E t \in Stamps :
              LET gone == Succ(blinks[d][old], d, FALSE, t)
                  moved == Succ(blinks[d][new], d, TRUE, t)
              IN /\ blinks' = [blinks EXCEPT ![d][old] = gone,
                                             ![d][new] = moved]
                 /\ wc' = wc + 1
                 /\ bsent' = bsent \cup {{<<old, gone>>, <<new, moved>>}}
                 /\ localCycle' =
                      (localCycle \/ ClosesReally(d, b, a, {old}))

\* The pre-checks, outside any transaction.
CreateChecks(d, a, b) ==
    /\ CanWrite
    /\ ~blinks[d][<<a, b>>].live
    /\ ~Closes(d, a, b, {})

FlipChecks(d, a, b) ==
    /\ CanWrite
    /\ blinks[d][<<a, b>>].live
    /\ ~blinks[d][<<b, a>>].live
    /\ ~Closes(d, b, a, {<<a, b>>})

UnchangedOther == UNCHANGED <<plinks, closed, now, psent, tsent, filings,
                              filingLost>>

\* The user creates or turns a link: its pre-check and its write in one
\* step, which is one of the interleavings of the two.
Create(d, a, b) ==
    /\ CreateChecks(d, a, b)
    /\ WriteCreate(d, a, b)
    /\ UNCHANGED pending
    /\ UnchangedOther

Flip(d, a, b) ==
    /\ FlipChecks(d, a, b)
    /\ WriteFlip(d, a, b)
    /\ UNCHANGED pending
    /\ UnchangedOther

\* The agent's link tool on device 1, at the same time: its pre-check
\* passes, and its write follows later, after any other step. One such
\* writer is enough to split the check from the write; the devices are
\* alike, so device 1 stands for each.
AgentCheck(a, b) ==
    /\ pending = NoOp
    /\ \/ /\ CreateChecks(1, a, b)
          /\ pending' = [op |-> "create", a |-> a, b |-> b]
       \/ /\ FlipChecks(1, a, b)
          /\ pending' = [op |-> "flip", a |-> a, b |-> b]
    /\ UNCHANGED <<blinks, plinks, closed, now, wc, bsent, psent, tsent,
                   localCycle, filings, filingLost>>

AgentWrite ==
    /\ pending # NoOp
    /\ pending' = NoOp
    /\ IF pending.op = "create"
       THEN WriteCreate(1, pending.a, pending.b)
       ELSE WriteFlip(1, pending.a, pending.b)
    /\ UnchangedOther

Remove(d, a, b) ==
    /\ CanWrite
    /\ blinks[d][<<a, b>>].live
    /\ \E t \in Stamps :
        LET v == Succ(blinks[d][<<a, b>>], d, FALSE, t)
        IN /\ blinks' = [blinks EXCEPT ![d][<<a, b>>] = v]
           /\ bsent' = bsent \cup {{<<<<a, b>>, v>>}}
    /\ wc' = wc + 1
    /\ UNCHANGED <<plinks, closed, now, pending, psent, tsent, localCycle,
                   filings, filingLost>>

Close(d, t) ==
    /\ CanWrite
    /\ IsOpen(d, t)
    /\ LET v == [w |-> wc + 1, closed |-> TRUE]
       IN /\ closed' = [closed EXCEPT ![d][t] = v]
          /\ tsent' = tsent \cup {<<t, v>>}
    /\ wc' = wc + 1
    /\ UNCHANGED <<blinks, plinks, now, pending, bsent, psent, localCycle,
                   filings, filingLost>>

\* A project write on task t, in one transaction (`_relinkTask`,
\* `_softDeleteLink`): tombstones for the links in `retire`, and a live
\* link to `to` unless it is 0. Every version it writes is its own message.
ProjectWrite(d, t, retire, to, stamp) ==
    LET tomb(q) == Succ(plinks[d][<<q, t>>], d, FALSE, stamp)
        new == Succ(plinks[d][<<to, t>>], d, TRUE, stamp)
        after == [k \in PKeys |->
                    IF k[2] = t /\ k[1] \in retire THEN tomb(k[1])
                    ELSE IF k[2] = t /\ k[1] = to /\ ~plinks[d][k].live
                    THEN new
                    ELSE plinks[d][k]]
    IN /\ plinks' = [plinks EXCEPT ![d] = after]
       /\ psent' = psent
            \cup {<<<<q, t>>, tomb(q)>> : q \in retire}
            \cup (IF to # 0 /\ ~plinks[d][<<to, t>>].live
                  THEN {<<<<to, t>>, new>>} ELSE {})
       /\ filings' = filings \cup
            {[t |-> t,
              saw |-> {plinks[d][<<q, t>>].w : q \in LiveP(d, t) \ {to}}]}
       /\ wc' = wc + 1

\* File or move task t under project p (`linkTaskToProject`). Already
\* shown there: nothing to do. Before the fix the move retired only the
\* link shown, and a live link to p that did not show made `_newProjectLink`
\* return null, so the move wrote nothing.
File(d, t, p) ==
    /\ CanWrite
    /\ Shown(d, t) # p
    /\ LET shown == Shown(d, t)
           retire == IF RetireAll THEN LiveP(d, t) \ {p}
                     ELSE IF shown = 0 THEN {} ELSE {shown}
       IN IF ~RetireAll /\ plinks[d][<<p, t>>].live
          THEN /\ filingLost' = TRUE
               /\ UNCHANGED <<plinks, psent, filings, wc>>
          ELSE \E stamp \in Stamps :
                /\ ProjectWrite(d, t, retire, p, stamp)
                \* The device that filed the task shows it there.
                /\ filingLost' = (filingLost \/ Shown(d, t)' # p)
    /\ UNCHANGED <<blinks, closed, now, pending, bsent, tsent, localCycle>>

\* Take task t out of its project (`unlinkTaskFromProject`).
Unfile(d, t) ==
    /\ CanWrite
    /\ Shown(d, t) # 0
    /\ \E stamp \in Stamps :
         ProjectWrite(d, t,
                      IF RetireAll THEN LiveP(d, t) ELSE {Shown(d, t)},
                      0, stamp)
    /\ UNCHANGED <<blinks, closed, now, pending, bsent, tsent, localCycle,
                   filingLost>>

---------------------------------------------------------------------------
(* Delivery: every version, in any order, any number of times. *)

DeliverB(d) ==
    /\ \E m \in bsent :
        blinks' = [blinks EXCEPT ![d] =
                    [k \in BKeys |->
                        IF \E kv \in m : kv[1] = k /\ Greater(kv[2], @[k])
                        THEN (CHOOSE kv \in m : kv[1] = k)[2]
                        ELSE @[k]]]
    /\ UNCHANGED <<plinks, closed, now, wc, pending, bsent, psent, tsent,
                   localCycle, filings, filingLost>>

DeliverP(d) ==
    /\ \E m \in psent :
        /\ Greater(m[2], plinks[d][m[1]])
        /\ plinks' = [plinks EXCEPT ![d][m[1]] = m[2]]
    /\ UNCHANGED <<blinks, closed, now, wc, pending, bsent, psent, tsent,
                   localCycle, filings, filingLost>>

DeliverT(d) ==
    /\ \E m \in tsent :
        /\ m[2].w > closed[d][m[1]].w
        /\ closed' = [closed EXCEPT ![d][m[1]] = m[2]]
    /\ UNCHANGED <<blinks, plinks, now, wc, pending, bsent, psent, tsent,
                   localCycle, filings, filingLost>>

Tick ==
    /\ now < MaxTime
    /\ now' = now + 1
    /\ UNCHANGED <<blinks, plinks, closed, wc, pending, bsent, psent, tsent,
                   localCycle, filings, filingLost>>

Next ==
    \/ Tick
    \/ AgentWrite
    \/ \E k \in BKeys : AgentCheck(k[1], k[2])
    \/ \E d \in Devices :
        \/ DeliverB(d) \/ DeliverP(d) \/ DeliverT(d)
        \/ \E k \in BKeys : Create(d, k[1], k[2]) \/ Flip(d, k[1], k[2])
        \/ \E k \in BKeys : Remove(d, k[1], k[2])
        \/ \E t \in Tasks : Close(d, t) \/ Unfile(d, t)
                            \/ \E p \in Projects : File(d, t, p)

Spec == Init /\ [][Next]_vars

---------------------------------------------------------------------------
(* Properties. *)

TypeOK ==
    /\ wc \in 0..MaxWrites
    /\ now \in 0..MaxTime
    /\ pending.op \in {"none", "create", "flip"}
    /\ \A d \in Devices :
        /\ \A k \in BKeys : blinks[d][k].w \in 0..MaxWrites
        /\ \A k \in PKeys : plinks[d][k].w \in 0..MaxWrites


\* Every version has reached every device. (Not an invariant: the
\* premise of the ones below.)
Converged ==
    \A d \in Devices :
        /\ \A m \in bsent : \A kv \in m : ~Greater(kv[2], blinks[d][kv[1]])
        /\ \A m \in psent : ~Greater(m[2], plinks[d][m[1]])
        /\ \A m \in tsent : m[2].w <= closed[d][m[1]].w

\* One device never writes a blocks link that closes a cycle it holds: a
\* cycle needs links written on different devices, each before the other
\* arrived.
NoLocalCycle == ~localCycle

\* Once the versions have arrived, the links any one device wrote form no
\* cycle: every cycle has links from two devices. (Before, a device can
\* hold a link another has since removed, and that one's later link.)
OneWriterAcyclic ==
    Converged =>
        \A d, e \in Devices : \A t \in Tasks :
            ~Reach({k \in LiveB(d) : blinks[d][k].by = e}, t, t, NT)

\* The readers report a task in a cycle exactly when it is on a cycle of
\* links between open tasks, on every device, whatever it holds -- so every
\* device reports the same once the versions have arrived.
CycleSurfaced ==
    \A d \in Devices : \A t \in Tasks :
        Cycle(d, t) <=> Reach(Blocking(d), t, t, NT)

\* Once the versions have arrived, a task is blocked on every device
\* exactly while an open task blocks it: closing or deleting its last open
\* blocker releases it everywhere, in a cycle too.
ReleaseOnClose ==
    Converged =>
        \A d \in Devices : \A t \in Tasks :
            Blocked(d, t) <=> \E b \in Tasks : <<b, t>> \in Blocking(d)

\* Once the versions have arrived, every device shows each task in the
\* same project, or in none.
AtMostOneProject ==
    Converged =>
        \A t \in Tasks : \A d, e \in Devices : Shown(d, t) = Shown(e, t)

\* Once the versions have arrived, no device shows a task in a project
\* through a link that a move or unfile of that task had seen: that write
\* took the task out of it.
ProjectWriteSticks ==
    Converged =>
        \A d \in Devices : \A t \in Tasks :
            Shown(d, t) # 0 =>
                \A f \in filings :
                    f.t = t => plinks[d][<<Shown(d, t), t>>].w \notin f.saw

\* The device that files or moves a task shows it in that project.
FilingShows == ~filingLost
=============================================================================

------------------------- MODULE ProjectWakeGovernor -------------------------
(***************************************************************************)
(* How much work one project agent does, across several devices.          *)
(*                                                                         *)
(* A project agent's report goes stale when its project changes. Staleness *)
(* is cheap synced state: two watermarks on the agent state, `staleAt`     *)
(* (latest change) and `freshAt` (start of the latest refreshing run),     *)
(* each joined by maximum. The report is stale while staleAt >= freshAt.   *)
(*                                                                         *)
(* A device whose replica is stale, with no update slot pending, arms the  *)
(* next one: a synced scheduled-wake record whose id is the agent and the  *)
(* slot's start, so every device arming it arms the same row. It does so   *)
(* on its own change, after its own run, and when stale state arrives by   *)
(* sync; an arm is inert data, and only the lease below turns it into      *)
(* work. When a slot is due a connected device waits for its sync inbox to *)
(* drain, claims the record, waits out the settle, confirms its claim      *)
(* survived and that its connection never dropped meanwhile, and fires    *)
(* the earliest pending slot: it consumes every pending slot — the synced  *)
(* "done" every other device skips on — and, if its replica is still      *)
(* stale and the daily budget allows, runs the agent, claiming the budget  *)
(* in the same write. A run that ends with the report still stale, or      *)
(* fails, arms the next slot. The user may update at any time; those runs  *)
(* are not deduplicated but count against the budget.                      *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Edit        ProjectActivityMonitor: a local change marks the report   *)
(*               stale and arms the next slot (ProjectUpdateCadence)       *)
(*   Write,      the outbox and the Matrix room: every local write is      *)
(*   Deliver     queued for every peer and reaches a connected one within  *)
(*               MaxDelay; an offline peer gets it when it comes back      *)
(*   Apply       the inbound worker applying the queue within MaxApplyLag, *)
(*               which the backlog configuration sets longer than the      *)
(*               settle, as a long offline backlog is; a stale result arms *)
(*   Claim,      ScheduledWakeManager._leaseApprovedRecord, gated on the   *)
(*   Fire        sync connection and InboundEventQueue.waitForDrainAtMost- *)
(*               To(0); Fire is the re-read, the consume, the enqueue, the *)
(*               workflow's cheap skip of a fresh report and the drain's   *)
(*               budget claim                                              *)
(*   Manual      "Update now": user-initiated, never deduplicated          *)
(*   Complete,   the run settling: success marks the report fresh as of    *)
(*   Fail        the run's start; either re-arms while still stale         *)
(*   Pause       the identity's lifecycle going dormant (synced); with     *)
(*               HaltOnPause the device halts its running wake at once     *)
(*   Offline,    a device losing and regaining its sync connection; a      *)
(*   Online      loss taints the device's claims                           *)
(*   Tick        wall-clock time; it cannot pass a delivery or apply       *)
(*               deadline, a run's cap or a manager step that is due       *)
(*                                                                         *)
(* The slot record is abstracted to a join: none < pending (ordered by     *)
(* claim) < consumed. That the real vector-clocked register converges to   *)
(* one surviving claim and keeps a consumed window consumed is what        *)
(* ScheduledWakeLease.tla checks (`Converged`, `WindowTerminal`); this     *)
(* spec takes it as given and checks what is new: the governor around it.  *)
(*                                                                         *)
(* Each rule has a switch, so TLC can show what it prevents:               *)
(*   SyncedSlots    slots are synced, leased records — FALSE is the design *)
(*                  this replaces: a device-local fallback that each       *)
(*                  device armed, also when stale state arrived by sync,   *)
(*                  and fired on its own                                   *)
(*   InboxGate      claim and fire only with a drained inbox               *)
(*   ConnectedClaims  claim and fire only while connected to sync, and    *)
(*                  re-claim instead of firing after the connection        *)
(*                  dropped: a claim that settles unseen proves nothing    *)
(*   EarliestSlot   fire only the earliest pending slot, consuming every   *)
(*                  pending one                                            *)
(*   SkipWhenFresh  a fired slot whose report is already fresh runs no     *)
(*                  inference                                              *)
(*   BudgetCheck    the daily budget is checked before a run               *)
(*   HaltOnPause    pausing aborts the running wake                        *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    N,            \* devices 1..N
    Interval,     \* slot length; slot s starts at s * Interval
    Slots,        \* number of slots modelled
    MaxTime,      \* time bound
    MaxDelay,     \* a write reaches a running peer within this
    MaxApplyLag,  \* received state is applied within this — longer than the
                  \* settle, as a long backlog is
    Settle,       \* ScheduledWakeManager.leaseSettle
    Lease,        \* ScheduledWakeManager.leaseDuration
    RunCap,       \* WakeOrchestrator.wakeRunMaxDuration
    Budget,       \* the agent's maxWakesPerDay
    EditsBy,      \* local changes happen no later than this instant
    MaxEdits,
    MaxManual,
    MaxFailures,
    MaxOffline,   \* bound on a device going offline
    AllowPause,
    SyncedSlots,
    InboxGate,
    ConnectedClaims,
    EarliestSlot,
    SkipWhenFresh,
    BudgetCheck,
    HaltOnPause

ASSUME Settle > 2 * MaxDelay
ASSUME Lease > Settle
ASSUME Interval > MaxDelay

Devices == 1..N
SlotIds == 1..Slots
Start(s) == s * Interval
NoHost == 0
Null == [none |-> TRUE]

NoRec == [st |-> "none", host |-> NoHost, until |-> 0]
Idle == [kind |-> "idle", slot |-> 0, start |-> 0, stale |-> FALSE]

Max(a, b) == IF a >= b THEN a ELSE b

----------------------------------------------------------------------------
(* Replicas and their join. *)

Rank(r) == CASE r.st = "none" -> 0 [] r.st = "pending" -> 1
             [] r.st = "consumed" -> 2

RecLeq(a, b) ==
    \/ Rank(a) < Rank(b)
    \/ Rank(a) = Rank(b) /\ a.until < b.until
    \/ Rank(a) = Rank(b) /\ a.until = b.until /\ a.host <= b.host

RecJoin(a, b) == IF RecLeq(a, b) THEN b ELSE a

\* A replica: the two watermarks, the budget ledger (a G-counter, one entry
\* per device), the slot records and the lifecycle.
Join(a, b) ==
    [stale  |-> Max(a.stale, b.stale),
     fresh  |-> Max(a.fresh, b.fresh),
     ledger |-> [x \in Devices |-> Max(a.ledger[x], b.ledger[x])],
     rec    |-> IF SyncedSlots
                THEN [s \in SlotIds |-> RecJoin(a.rec[s], b.rec[s])]
                ELSE a.rec,
     active |-> a.active /\ b.active]

Stale(r) == r.stale > 0 /\ r.stale >= r.fresh
Used(r) == LET F[x \in SUBSET Devices] ==
                 IF x = {} THEN 0
                 ELSE LET y == CHOOSE z \in x : TRUE
                      IN r.ledger[y] + F[x \ {y}]
           IN F[Devices]

\* The first slot strictly after t that this replica holds no record for,
\* or 0 past the last one. A slot consumed early (with an earlier one, see
\* Fire) is skipped rather than blocking the arm.
NextSlot(r, t) ==
    LET free == {s \in SlotIds : Start(s) > t /\ r.rec[s].st = "none"} IN
    IF free = {} THEN 0
    ELSE CHOOSE s \in free : \A u \in free : s <= u

\* Arm the next slot after t — unless any slot is still pending, due or not:
\* one pending update per agent, so a late slot and the next one never both
\* run for the same change.
ArmNext(r, t) ==
    LET s == NextSlot(r, t) IN
    IF s = 0 \/ \E u \in SlotIds : r.rec[u].st = "pending"
    THEN r
    ELSE [r EXCEPT !.rec[s] = [st |-> "pending", host |-> NoHost, until |-> 0]]

VARIABLES
    now,
    rep,       \* per device: its replica
    chan,      \* per sender and receiver: the latest undelivered replica,
               \* and since when it is deliverable
    inbox,     \* per device: delivered, not yet applied (joined)
    up,        \* per device: connected to sync
    run,       \* per device: the running wake, or Idle
    ran,       \* ghost: per slot, the devices that ran it
    autoRuns,  \* ghost: per device, slot runs started
    allRuns,   \* ghost: per device, runs started
    causes,    \* ghost: why runs started: "lease", "manual", "local"
    edits,     \* ghost: instants of local changes
    pausedRun, \* ghost: a run went on while its device knew it was paused
    tainted,   \* per device: the connection dropped since its last claim
    droppedSlots, \* ghost: slots a device ran, then lost its connection
                  \* with the slot's consume still unsent
    nEdits, nManual, nFailures, nOffline

vars == <<now, rep, chan, inbox, up, run, ran, autoRuns, allRuns,
          causes, edits, pausedRun, tainted, droppedSlots, nEdits, nManual, nFailures,
          nOffline>>

Empty == [stale |-> 0, fresh |-> 0, ledger |-> [x \in Devices |-> 0],
          rec |-> [s \in SlotIds |-> NoRec], active |-> TRUE]

Init ==
    /\ now = 1
    /\ rep = [d \in Devices |-> Empty]
    /\ chan = [d \in Devices |-> [e \in Devices |-> Null]]
    /\ inbox = [d \in Devices |-> Null]
    /\ up = [d \in Devices |-> TRUE]
    /\ run = [d \in Devices |-> Idle]
    /\ ran = [s \in SlotIds |-> {}]
    /\ autoRuns = [d \in Devices |-> 0]
    /\ allRuns = [d \in Devices |-> 0]
    /\ causes = {}
    /\ edits = {}
    /\ pausedRun = FALSE
    /\ tainted = [d \in Devices |-> FALSE]
    /\ droppedSlots = {}
    /\ nEdits = 0
    /\ nManual = 0
    /\ nFailures = 0
    /\ nOffline = 0

----------------------------------------------------------------------------
(* Local changes and sync. *)

\* A local write: persisted and queued for every peer at once. The latest
\* replica subsumes an undelivered older one, since every write is
\* inflationary in the join.
Write(d, r) ==
    /\ rep' = [rep EXCEPT ![d] = r]
    /\ chan' = [chan EXCEPT ![d] =
                  [e \in Devices |->
                     IF e = d THEN Null
                     ELSE [snap |-> r,
                           at |-> IF chan[d][e] = Null THEN now
                                  ELSE chan[d][e].at]]]

Edit(d) ==
    /\ nEdits < MaxEdits
    /\ now <= EditsBy
    /\ rep[d].active
    /\ nEdits' = nEdits + 1
    /\ edits' = edits \cup {now}
    /\ Write(d, ArmNext([rep[d] EXCEPT !.stale = now], now))
    /\ UNCHANGED <<now, inbox, up, run, ran, autoRuns, allRuns, causes,
                   pausedRun, tainted, droppedSlots, nManual, nFailures, nOffline>>

\* Delivery needs both ends connected: the sender to upload, the receiver
\* to download. Within MaxDelay once both are (see Tick).
Deliver(d, e) ==
    /\ chan[d][e] # Null
    /\ up[d] /\ up[e]
    /\ inbox' = [inbox EXCEPT ![e] =
                   IF @ = Null THEN [snap |-> chan[d][e].snap, at |-> now]
                   ELSE [@ EXCEPT !.snap = Join(@, chan[d][e].snap)]]
    /\ chan' = [chan EXCEPT ![d][e] = Null]
    /\ UNCHANGED <<now, rep, up, run, ran, autoRuns, allRuns, causes, edits,
                   pausedRun, tainted, droppedSlots, nEdits, nManual, nFailures,
                   nOffline>>

\* Applying received state. It never starts work. A stale report with no
\* pending slot arms one: the arm is inert data with the slot's own id, so
\* every device arming it arms the same row, and only the lease turns it
\* into a run. Under the replaced design (SyncedSlots = FALSE) the same arm
\* was a device-local fallback each device fired on its own — the
\* receiver-side repair in _reconcileProjectAgentRuntime. Received state is
\* not re-published: every device sends only its own writes.
Apply(d) ==
    /\ inbox[d] # Null
    /\ LET joined == Join(rep[d], inbox[d].snap)
           armed == IF Stale(joined) THEN ArmNext(joined, now) ELSE joined
       IN /\ rep' = [rep EXCEPT ![d] = armed]
          /\ run' = [run EXCEPT ![d] =
                       IF HaltOnPause /\ ~armed.active THEN Idle ELSE @]
    /\ inbox' = [inbox EXCEPT ![d] = Null]
    /\ UNCHANGED <<now, chan, up, ran, autoRuns, allRuns, causes, edits,
                   pausedRun, tainted, droppedSlots, nEdits, nManual, nFailures,
                   nOffline>>

\* Losing the connection taints this device's claims: they may not have
\* reached any peer, so their settle proved nothing.
Offline(d) ==
    /\ nOffline < MaxOffline
    /\ up[d]
    /\ nOffline' = nOffline + 1
    /\ up' = [up EXCEPT ![d] = FALSE]
    /\ tainted' = [tainted EXCEPT ![d] = TRUE]
    /\ droppedSlots' = droppedSlots \cup
         {s \in SlotIds :
            /\ d \in ran[s]
            /\ \E e \in Devices : /\ chan[d][e] # Null
                                 /\ chan[d][e].snap.rec[s].st = "consumed"}
    /\ UNCHANGED <<now, rep, chan, inbox, run, ran, autoRuns, allRuns, causes,
                   edits, pausedRun, nEdits, nManual, nFailures>>

\* Back online: what waited for it, either way, becomes deliverable now.
Online(d) ==
    /\ ~up[d]
    /\ up' = [up EXCEPT ![d] = TRUE]
    /\ chan' = [x \in Devices |-> [e \in Devices |->
                  IF (e = d \/ x = d) /\ chan[x][e] # Null
                  THEN [chan[x][e] EXCEPT !.at = now] ELSE chan[x][e]]]
    /\ UNCHANGED <<now, rep, inbox, run, ran, autoRuns, allRuns, causes,
                   edits, pausedRun, tainted, droppedSlots, nEdits, nManual, nFailures,
                   nOffline>>

----------------------------------------------------------------------------
(* The slot lease. *)

Gate(d) == InboxGate => inbox[d] = Null

Due(d, s) ==
    /\ rep[d].rec[s].st = "pending"
    /\ now >= Start(s)

Lapsed(r) == r.host = NoHost \/ r.until <= now

\* Claiming and firing need a live connection, and a firing claim must not
\* have lost it since it was made (ConnectedClaims).
Connected(d) == ConnectedClaims => up[d]

\* Only the earliest pending slot fires: two devices that armed different
\* slots for one change hold both, and the earlier one's run covers it.
Earliest(d, s) == \A u \in SlotIds : u < s => rep[d].rec[u].st # "pending"

\* Claim a due slot that nobody holds — or that this device holds on a claim
\* the connection dropped under, which it re-makes so its settle restarts
\* where peers can see it.
Claim(d, s) ==
    /\ SyncedSlots
    /\ Connected(d)
    /\ rep[d].active
    /\ Due(d, s)
    /\ \/ Lapsed(rep[d].rec[s])
       \/ ConnectedClaims /\ rep[d].rec[s].host = d /\ tainted[d]
    /\ Gate(d)
    /\ Write(d, [rep[d] EXCEPT !.rec[s] =
                   [st |-> "pending", host |-> d, until |-> now + Lease]])
    /\ tainted' = [tainted EXCEPT ![d] = FALSE]
    /\ UNCHANGED <<now, inbox, up, run, ran, autoRuns, allRuns, causes, edits,
                   pausedRun, droppedSlots, nEdits, nManual, nFailures, nOffline>>

Settled(r) == r.until > now /\ now >= r.until - Lease + Settle


\* Fire: consume the record, then run unless the report is fresh or the
\* budget is spent. Under the replaced design every device fires its own
\* local fallback once due, with no lease.
\* Firing consumes every pending slot, not just its own: the run reads the
\* agent as of its start, which covers every change any of them was armed
\* for, and the consume carries the run's budget claim in the same write.
Fire(d, s) ==
    /\ rep[d].active
    /\ run[d] = Idle
    /\ Due(d, s)
    /\ IF SyncedSlots
       THEN /\ rep[d].rec[s].host = d /\ Settled(rep[d].rec[s]) /\ Gate(d)
            /\ Connected(d) /\ ~(ConnectedClaims /\ tainted[d])
            /\ EarliestSlot => Earliest(d, s)
       ELSE TRUE
    /\ LET r == rep[d]
           stale == Stale(r)
           allowed == (SkipWhenFresh => stale)
                      /\ (BudgetCheck => Used(r) < Budget)
           consumed ==
             [r EXCEPT !.rec =
                [u \in SlotIds |->
                   IF u = s \/ (EarliestSlot /\ SyncedSlots
                                /\ @[u].st = "pending")
                   THEN [st |-> "consumed", host |-> d, until |-> 0]
                   ELSE @[u]]]
       IN IF allowed
          THEN /\ Write(d, [consumed EXCEPT !.ledger[d] = @ + 1])
               /\ run' = [run EXCEPT ![d] =
                            [kind |-> "slot", slot |-> s, start |-> now,
                             stale |-> stale]]
               /\ ran' = [ran EXCEPT ![s] = @ \cup {d}]
               /\ autoRuns' = [autoRuns EXCEPT ![d] = @ + 1]
               /\ allRuns' = [allRuns EXCEPT ![d] = @ + 1]
               /\ causes' = causes \cup
                    {IF SyncedSlots THEN "lease" ELSE "local"}
          ELSE /\ Write(d, consumed)
               /\ UNCHANGED <<run, ran, autoRuns, allRuns, causes>>
    /\ UNCHANGED <<now, inbox, up, edits, pausedRun, tainted, droppedSlots, nEdits,
                   nManual, nFailures, nOffline>>

----------------------------------------------------------------------------
(* Runs. *)

\* "Update now": allowed up to twice the budget, never deduplicated.
Manual(d) ==
    /\ nManual < MaxManual
    /\ rep[d].active
    /\ run[d] = Idle
    /\ BudgetCheck => Used(rep[d]) < 2 * Budget
    /\ nManual' = nManual + 1
    /\ Write(d, [rep[d] EXCEPT !.ledger[d] = @ + 1])
    /\ run' = [run EXCEPT ![d] =
                 [kind |-> "manual", slot |-> 0, start |-> now,
                  stale |-> Stale(rep[d])]]
    /\ allRuns' = [allRuns EXCEPT ![d] = @ + 1]
    /\ causes' = causes \cup {"manual"}
    /\ UNCHANGED <<now, inbox, up, ran, autoRuns, edits, pausedRun,
                   tainted, droppedSlots, nEdits, nFailures, nOffline>>

\* Success: the report is fresh as of the run's start. Still stale (a change
\* arrived meanwhile) re-arms.
Complete(d) ==
    /\ run[d] # Idle
    /\ now > run[d].start
    /\ LET fresh == [rep[d] EXCEPT !.fresh = Max(@, run[d].start)]
       IN Write(d, IF Stale(fresh) THEN ArmNext(fresh, now) ELSE fresh)
    /\ run' = [run EXCEPT ![d] = Idle]
    /\ UNCHANGED <<now, inbox, up, ran, autoRuns, allRuns, causes, edits,
                   pausedRun, tainted, droppedSlots, nEdits, nManual, nFailures,
                   nOffline>>

Fail(d) ==
    /\ nFailures < MaxFailures
    /\ run[d] # Idle
    /\ nFailures' = nFailures + 1
    /\ Write(d, IF Stale(rep[d]) THEN ArmNext(rep[d], now) ELSE rep[d])
    /\ run' = [run EXCEPT ![d] = Idle]
    /\ UNCHANGED <<now, inbox, up, ran, autoRuns, allRuns, causes, edits,
                   pausedRun, tainted, droppedSlots, nEdits, nManual, nOffline>>

Pause(d) ==
    /\ AllowPause
    /\ rep[d].active
    /\ Write(d, [rep[d] EXCEPT !.active = FALSE])
    /\ run' = [run EXCEPT ![d] = IF HaltOnPause THEN Idle ELSE @]
    /\ UNCHANGED <<now, inbox, up, ran, autoRuns, allRuns, causes, edits,
                   pausedRun, tainted, droppedSlots, nEdits, nManual, nFailures,
                   nOffline>>

----------------------------------------------------------------------------
(* Time. *)

\* A manager step that is due: the timers act as soon as they can.
StepDue(d) ==
    \/ \E s \in SlotIds : ENABLED Claim(d, s)
    \/ \E s \in SlotIds : ENABLED Fire(d, s)

Tick ==
    /\ now < MaxTime
    /\ \A d, e \in Devices :
         (chan[d][e] # Null /\ up[d] /\ up[e]) =>
            chan[d][e].at + MaxDelay > now
    /\ \A d \in Devices : run[d] # Idle => run[d].start + RunCap > now
    /\ \A d \in Devices : inbox[d] # Null => inbox[d].at + MaxApplyLag > now
    /\ \A d \in Devices : ~StepDue(d)
    /\ now' = now + 1
    \* A device that knows it is paused and still runs: recorded at the
    \* moment time moves on with it running.
    /\ pausedRun' = (pausedRun \/ \E d \in Devices :
                        run[d] # Idle /\ ~rep[d].active)
    /\ UNCHANGED <<rep, chan, inbox, up, run, ran, autoRuns, allRuns, causes,
                   edits, tainted, droppedSlots, nEdits, nManual, nFailures,
                   nOffline>>

Next ==
    \/ Tick
    \/ \E d \in Devices :
          \/ Edit(d) \/ Apply(d) \/ Offline(d) \/ Online(d)
          \/ Manual(d) \/ Complete(d) \/ Fail(d) \/ Pause(d)
          \/ \E s \in SlotIds : Claim(d, s) \/ Fire(d, s)
          \/ \E e \in Devices : Deliver(d, e)

Fairness ==
    /\ WF_vars(Tick)
    /\ \A d \in Devices :
          /\ WF_vars(Apply(d)) /\ WF_vars(Online(d)) /\ WF_vars(Complete(d))
          /\ \A s \in SlotIds : WF_vars(Claim(d, s)) /\ WF_vars(Fire(d, s))
          /\ \A e \in Devices : WF_vars(Deliver(d, e))

Spec == Init /\ [][Next]_vars /\ Fairness

----------------------------------------------------------------------------
(* Properties. *)

TypeOK ==
    /\ now \in 1..MaxTime
    /\ \A d \in Devices : up[d] \in BOOLEAN
    /\ \A s \in SlotIds : ran[s] \subseteq Devices
    /\ causes \subseteq {"lease", "manual", "local"}
    /\ droppedSlots \subseteq SlotIds

Sum(f) == LET F[x \in SUBSET Devices] ==
                IF x = {} THEN 0
                ELSE LET y == CHOOSE z \in x : TRUE IN f[y] + F[x \ {y}]
          IN F[Devices]

\* One slot, one run: no two devices spend inference on the same update.
NoDuplicateScheduledWake == \A s \in SlotIds : Cardinality(ran[s]) <= 1

\* What a partition can still cost: a device that fired and lost its
\* connection before its consume left cannot tell its peers, which take the
\* slot over once its lease lapses. The exception covers that slot alone,
\* not every slot after any unsent write. Nothing else runs a slot twice — not a
\* device that claimed while offline, nor one that came back to a backlog.
NoDuplicateUnlessWriteDropped ==
    \A s \in SlotIds : Cardinality(ran[s]) <= 1 \/ s \in droppedSlots

\* Each device keeps its own claims within the budget: automatic runs stop
\* at the budget, every run at twice it.
WakeBudgetRespected ==
    \A d \in Devices : autoRuns[d] <= Budget /\ allRuns[d] <= 2 * Budget

\* Devices that stay connected share one budget for automatic work.
SharedBudget == Sum(autoRuns) <= Budget

\* Stale state that arrives by sync starts no work of its own: every run is
\* a leased slot or a user's request.
StaleDoesNotTriggerWork == causes \subseteq {"lease", "manual"}

\* An automatic run never starts over a report that is already fresh — the
\* "No movement again" wake.
NoWorkWhenFresh ==
    \A d \in Devices : run[d].kind = "slot" => run[d].stale

\* A paused agent does no work: no run continues while its device knows the
\* agent is paused.
PausedRunsNothing == ~pausedRun

\* Every local change is eventually reflected in a refreshed report.
NoLostUpdate ==
    \A t \in 1..EditsBy :
       (t \in edits) ~> (\E d \in Devices : rep[d].fresh > t)
=============================================================================

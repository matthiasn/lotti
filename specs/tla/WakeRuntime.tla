---------------------------- MODULE WakeRuntime ----------------------------
(***************************************************************************)
(* The agent wake runtime: triggers become queued jobs, the drain loop     *)
(* dispatches a job when its agent's runner lease is free, and the         *)
(* executor runs the wake. An abort (user cancel, the 10-minute timeout,   *)
(* or a stuck-drain force reset) releases the lease, but a Dart future     *)
(* cannot be cancelled, so the executor keeps running until it settles.    *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   ManualTrigger      WakeOrchestrator.enqueueManualWake / content wakes *)
(*   SubTrigger         WakeBatchRouter: a subscription match queues a job *)
(*                      and persists the throttle deadline (nextWakeAt)    *)
(*   DeadlineFires      WakeThrottleCoordinator's timer                    *)
(*   RestoreDeadline    restorePendingWake and restoreWakeIntents at       *)
(*                      startup; `deadline` is the throttle deadline plus  *)
(*                      the WakeIntentStore record, one intent per job     *)
(*   Dispatch           WakeDrainEngine._drain: the dispatch predicate,    *)
(*                      tryAcquireLease, _executeJob                       *)
(*   Complete           the executor future settling (_trackExecutor)      *)
(*   Abort              runner.abortLease: cancel, timeout, force reset    *)
(*   Crash              process death; abandonOrphanedWakeRuns at startup  *)
(*                                                                         *)
(* A job carries the triggers (token sets) merged into it; a run covers    *)
(* the triggers of the job it started from. The ghost `outstanding` holds  *)
(* every trigger no completed run has covered yet.                         *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Agents,        \* agent ids
    MaxTriggers,   \* bound on triggers
    MaxCrashes,    \* bound on process crashes
    MaxAborts      \* bound on aborts (cancel, timeout, force reset)

Triggers == 1..MaxTriggers
\* A restored intent may run once more after a crash, so allow twice as
\* many runs as triggers.
MaxRuns == 2 * MaxTriggers
NoRun == 0

VARIABLES
    nextTrigger,  \* the next trigger id
    nextRun,      \* the next run id
    queue,        \* per agent: triggers merged into its dispatchable job
    throttled,    \* per agent: triggers in a job waiting for its deadline
    deadline,     \* per agent: the persisted wake intent (nextWakeAt) and
                  \* the triggers it stands for; cleared only when a run
                  \* covering them completes
    restored,     \* per agent: this boot has restored its persisted intent
    timerArmed,   \* per agent: the in-memory throttle timer
    lease,        \* per agent: the run holding the runner lock, or NoRun
    running,      \* live executors: [id, agent, cov, hung]
    outstanding,  \* ghost: triggers no completed run has covered
    crashes,
    aborts

vars == <<nextTrigger, nextRun, queue, throttled, deadline, restored,
          timerArmed, lease, running, outstanding, crashes, aborts>>

Init ==
    /\ nextTrigger = 1
    /\ nextRun = 1
    /\ queue = [a \in Agents |-> {}]
    /\ throttled = [a \in Agents |-> {}]
    /\ deadline = [a \in Agents |-> {}]
    /\ restored = [a \in Agents |-> TRUE]
    /\ timerArmed = [a \in Agents |-> FALSE]
    /\ lease = [a \in Agents |-> NoRun]
    /\ running = {}
    /\ outstanding = {}
    /\ crashes = 0
    /\ aborts = 0

\* Executors that still block a new run of `a`: every live one, except one
\* declared hung after running past WakeOrchestrator.hungExecutorAfter.
LiveFor(a) == {r \in running : r.agent = a /\ ~r.hung}

\* Triggers this process already has for `a`: queued, throttled or running.
Known(a) == queue[a] \cup throttled[a] \cup UNION {r.cov : r \in LiveFor(a)}

----------------------------------------------------------------------------
(* Triggers. *)

\* A manual, content or immediate wake: an in-memory job, drained at once.
ManualTrigger(a) ==
    /\ nextTrigger <= MaxTriggers
    /\ queue' = [queue EXCEPT ![a] = @ \cup {nextTrigger}]
    /\ deadline' = [deadline EXCEPT ![a] = @ \cup {nextTrigger}]
    /\ outstanding' = outstanding \cup {nextTrigger}
    /\ nextTrigger' = nextTrigger + 1
    /\ UNCHANGED <<nextRun, throttled, restored, timerArmed, lease, running,
                   crashes, aborts>>

\* A subscription match: a throttled job plus a persisted deadline.
SubTrigger(a) ==
    /\ nextTrigger <= MaxTriggers
    /\ throttled' = [throttled EXCEPT ![a] = @ \cup {nextTrigger}]
    /\ deadline' = [deadline EXCEPT ![a] = @ \cup {nextTrigger}]
    /\ timerArmed' = [timerArmed EXCEPT ![a] = TRUE]
    /\ outstanding' = outstanding \cup {nextTrigger}
    /\ nextTrigger' = nextTrigger + 1
    /\ UNCHANGED <<nextRun, queue, restored, lease, running, crashes,
                   aborts>>

\* The throttle timer fires: the job becomes dispatchable. The persisted
\* intent stays until a run covering it completes.
DeadlineFires(a) ==
    /\ timerArmed[a]
    /\ queue' = [queue EXCEPT ![a] = @ \cup throttled[a]]
    /\ throttled' = [throttled EXCEPT ![a] = {}]
    /\ timerArmed' = [timerArmed EXCEPT ![a] = FALSE]
    /\ UNCHANGED <<nextTrigger, nextRun, deadline, restored, lease, running,
                   outstanding, crashes, aborts>>

\* Startup, once per boot: a persisted intent rebuilds its job and timer —
\* including the intent of a run the crash interrupted — unless this process
\* already has those triggers queued, throttled or running.
RestoreDeadline(a) ==
    /\ ~restored[a]
    /\ restored' = [restored EXCEPT ![a] = TRUE]
    /\ IF deadline[a] \ Known(a) # {}
       THEN /\ throttled' =
                   [throttled EXCEPT ![a] = @ \cup (deadline[a] \ Known(a))]
            /\ timerArmed' = [timerArmed EXCEPT ![a] = TRUE]
       ELSE UNCHANGED <<throttled, timerArmed>>
    /\ UNCHANGED <<nextTrigger, nextRun, queue, deadline, lease, running,
                   outstanding, crashes, aborts>>

----------------------------------------------------------------------------
(* Running wakes. *)

\* The drain dispatches an agent's job only while its runner lock is free
\* and no earlier executor of that agent — aborted or not — is still live.
\* The queue may hold several jobs for one agent (a manual wake that does
\* not supersede, another workspace), so a run covers some of its queued
\* triggers, not necessarily all.
Dispatch(a) ==
    /\ lease[a] = NoRun
    /\ LiveFor(a) = {}
    /\ nextRun <= MaxRuns
    /\ \E job \in SUBSET queue[a] \ {{}} :
          /\ running' = running \cup
                {[id |-> nextRun, agent |-> a, cov |-> job, hung |-> FALSE]}
          /\ queue' = [queue EXCEPT ![a] = @ \ job]
    /\ lease' = [lease EXCEPT ![a] = nextRun]
    /\ nextRun' = nextRun + 1
    /\ UNCHANGED <<nextTrigger, throttled, deadline, restored, timerArmed,
                   outstanding, crashes, aborts>>

\* The executor settles; its lease is released only if it still holds it.
Complete(r) ==
    /\ r \in running
    /\ running' = running \ {r}
    /\ outstanding' = outstanding \ r.cov
    /\ deadline' = [deadline EXCEPT ![r.agent] = @ \ r.cov]
    /\ lease' = IF lease[r.agent] = r.id
                THEN [lease EXCEPT ![r.agent] = NoRun] ELSE lease
    /\ UNCHANGED <<nextTrigger, nextRun, queue, throttled, restored,
                   timerArmed, crashes, aborts>>

\* Cancel, the 10-minute timeout, or a stuck-drain force reset: the lease
\* is released, the uncancellable executor runs on.
Abort(r) ==
    /\ aborts < MaxAborts
    /\ r \in running
    /\ lease[r.agent] = r.id
    /\ lease' = [lease EXCEPT ![r.agent] = NoRun]
    /\ aborts' = aborts + 1
    /\ UNCHANGED <<nextTrigger, nextRun, queue, throttled, deadline,
                   restored, timerArmed, running, outstanding, crashes>>

\* An aborted executor has run for longer than any healthy wake could: it
\* stops blocking its agent, so a truly hung future cannot wedge it. It is
\* still live, and still settles its triggers if it ever completes.
DeclareHung(r) ==
    /\ r \in running
    /\ ~r.hung
    /\ lease[r.agent] # r.id
    /\ running' = (running \ {r}) \cup {[r EXCEPT !.hung = TRUE]}
    /\ UNCHANGED <<nextTrigger, nextRun, queue, throttled, deadline, restored,
                   timerArmed, lease, outstanding, crashes, aborts>>

\* Process death: executors, jobs, timers and leases are gone; persisted
\* deadlines survive. Running rows become `abandoned` and are not retried.
Crash ==
    /\ crashes < MaxCrashes
    /\ running' = {}
    /\ lease' = [a \in Agents |-> NoRun]
    /\ queue' = [a \in Agents |-> {}]
    /\ throttled' = [a \in Agents |-> {}]
    /\ timerArmed' = [a \in Agents |-> FALSE]
    /\ restored' = [a \in Agents |-> FALSE]
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<nextTrigger, nextRun, deadline, outstanding, aborts>>

Next ==
    \/ \E a \in Agents :
          \/ ManualTrigger(a) \/ SubTrigger(a) \/ DeadlineFires(a)
          \/ RestoreDeadline(a) \/ Dispatch(a)
    \/ \E r \in running : Complete(r) \/ Abort(r) \/ DeclareHung(r)
    \/ Crash

\* The runtime does its own work; triggers, aborts and crashes are never
\* forced. An executor always settles eventually.
Fairness ==
    /\ \A a \in Agents :
          /\ WF_vars(DeadlineFires(a))
          /\ WF_vars(RestoreDeadline(a))
          /\ WF_vars(Dispatch(a))
    /\ WF_vars(\E r \in running : Complete(r))

Spec == Init /\ [][Next]_vars /\ Fairness

----------------------------------------------------------------------------
(* Properties. *)

TypeOK ==
    /\ nextTrigger \in 1..(MaxTriggers + 1)
    /\ queue \in [Agents -> SUBSET Triggers]
    /\ throttled \in [Agents -> SUBSET Triggers]
    /\ deadline \in [Agents -> SUBSET Triggers]
    /\ lease \in [Agents -> 0..MaxRuns]
    /\ outstanding \subseteq Triggers

\* At most one wake executes per agent at a time (WakeRunner's promise),
\* short of an executor declared hung.
SingleFlight == \A a \in Agents : Cardinality(LiveFor(a)) <= 1

\* Only an aborted executor — one that no longer holds its lease — is ever
\* declared hung.
HungOnlyWhenDetached ==
    \A r \in running : r.hung => lease[r.agent] # r.id

\* Every trigger is eventually covered by a run that completes.
NoLostWake == \A t \in Triggers : (t \in outstanding) ~> (t \notin outstanding)
=============================================================================

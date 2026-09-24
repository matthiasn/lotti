--------------------------- MODULE DigestRecovery ---------------------------
(***************************************************************************)
(* Crash recovery of the coordinator's morning digest on the device that   *)
(* runs it (ADR 0048, ADR 0070). One day window, one device: the digest    *)
(* record fires, its wake runs, and the process may die anywhere. Startup  *)
(* then has recovery paths that must between them produce the day's        *)
(* briefing exactly once: the consumed-record retry in DayAgentService,    *)
(* and — in the design before ADR 0070 — the WakeIntentStore replay of the *)
(* digest wake the crash interrupted.                                      *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Claim / Settle     ScheduledWakeManager._leaseApprovedRecord: write   *)
(*                      leaseHostId, wait leaseSettle, confirm             *)
(*   Fire               _processDueRecords: enqueueManualWake(digest)      *)
(*   Consume            ... then the awaited `consumed` upsert             *)
(*   Take / Back        WakeDrainEngine._drain: the job leaves the queue   *)
(*                      (drain-owned, or held back while the agent is      *)
(*                      busy) before it executes or is requeued            *)
(*   Start              _executeJob: the executor starts the inference     *)
(*   Complete           DayAgentWorkflow: dailyWakeCompleted milestone and *)
(*                      the next-day re-arm, one transaction               *)
(*   Flush              WakeIntentStore._writeLoop: the coalesced snapshot *)
(*                      write of the in-memory intents                     *)
(*   Crash              process death; every in-memory job and executor    *)
(*                      is gone, the record and the settings db survive    *)
(*   StartManager       agentInitialization step 3.5: the manager starts   *)
(*   PreCheck           beforeWakeScan -> ensureCoordinatorDigestWake      *)
(*   RestoreSubs        restoreSubscriptions -> _ensurePendingDigestWake   *)
(*   RestoreIntents     WakeOrchestrator.restoreWakeIntents (step 5, after *)
(*                      the subscription passes)                           *)
(*                                                                         *)
(* `Recovery(...)` is DayAgentService._digestRecovery for this device on   *)
(* the day the record fired: the coordinator is active and this device is  *)
(* the claimant, so the three answers left are preserve (live local work), *)
(* advance (a watermark inside the window) and retry.                      *)
(*                                                                         *)
(* Design switches (TRUE is the code after ADR 0070):                      *)
(*   DigestOwnsRecovery  digest wakes are never WakeIntentStore intents;   *)
(*                       the consumed record is their only recovery path   *)
(*   ProbeSeesLimbo      hasPendingOrActiveWake also sees a job the drain  *)
(*                       has taken out of the queue but not yet started    *)
(*   WindowFromDayStart  the watermark window starts at the local day of   *)
(*                       consumedAt, not at consumedAt itself              *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    MaxCrashes,          \* bound on process deaths
    MaxSkews,            \* bound on backward clock steps inside the day
    MaxJobs,             \* bound on digest wake jobs ever enqueued
    Leased,              \* the record needs the claim-settle lease
    DigestOwnsRecovery,
    ProbeSeesLimbo,
    WindowFromDayStart

Jobs == 1..MaxJobs
NoJob == 0

VARIABLES
    rec,          \* the digest record: "pending" | "consumed" | "next"
    lease,        \* this device's claim: "none" | "claimed" | "settled"
    firing,       \* the job a Fire enqueued whose consume write is pending
    queue,        \* queued digest jobs
    limbo,        \* jobs the drain took out of the queue, not yet started
    exec,         \* the job whose inference is running, or NoJob
    mem,          \* WakeIntentStore in memory
    disk,         \* WakeIntentStore in the settings database
    owed,         \* intents loaded at this boot and not yet restored
    watermark,    \* a dailyWakeCompleted milestone for the day exists
    wmEarly,      \* ... stamped before consumedAt (a backward clock step)
    started,      \* the wake manager is running in this boot
    subsDone,     \* restoreSubscriptions has run in this boot
    intentsDone,  \* restoreWakeIntents has run in this boot
    nextJob,
    crashes,
    skews,
    inferences,   \* ghost: inferences started for the day
    completed,    \* ghost: digests completed for the day
    wasted        \* ghost: inferences started after the briefing existed

vars == <<rec, lease, firing, queue, limbo, exec, mem, disk, owed, watermark,
          wmEarly, started, subsDone, intentsDone, nextJob, crashes, skews,
          inferences, completed, wasted>>

Init ==
    /\ rec = "pending"
    /\ lease = "none"
    /\ firing = NoJob
    /\ queue = {}
    /\ limbo = {}
    /\ exec = NoJob
    /\ mem = {}
    /\ disk = {}
    /\ owed = {}
    /\ watermark = FALSE
    /\ wmEarly = FALSE
    /\ started = FALSE
    /\ subsDone = FALSE
    /\ intentsDone = FALSE
    /\ nextJob = 1
    /\ crashes = 0
    /\ skews = 0
    /\ inferences = 0
    /\ completed = 0
    /\ wasted = 0

\* WakeOrchestrator.hasPendingOrActiveWake(coordinator, coordinator:digest).
HasWork ==
    \/ queue # {}
    \/ exec # NoJob
    \/ (ProbeSeesLimbo /\ limbo # {})

\* _digestRanIn(consumedAt, now): a watermark inside the window.
RanInWindow == watermark /\ (WindowFromDayStart \/ ~wmEarly)

\* Enqueues a digest job; before ADR 0070 it also became a wake intent.
Remember(j) == IF DigestOwnsRecovery THEN mem ELSE mem \cup {j}

----------------------------------------------------------------------------
(* The wake manager fires the record. *)

Claim ==
    /\ started /\ Leased
    /\ rec = "pending" /\ lease = "none" /\ firing = NoJob
    /\ lease' = "claimed"
    /\ UNCHANGED <<rec, firing, queue, limbo, exec, mem, disk, owed,
                   watermark, wmEarly, started, subsDone, intentsDone,
                   nextJob, crashes, skews, inferences, completed, wasted>>

Settle ==
    /\ lease = "claimed"
    /\ lease' = "settled"
    /\ UNCHANGED <<rec, firing, queue, limbo, exec, mem, disk, owed,
                   watermark, wmEarly, started, subsDone, intentsDone,
                   nextJob, crashes, skews, inferences, completed, wasted>>

Fire ==
    /\ started
    /\ rec = "pending" /\ firing = NoJob
    /\ (Leased => lease = "settled")
    /\ nextJob <= MaxJobs
    /\ queue' = queue \cup {nextJob}
    /\ mem' = Remember(nextJob)
    /\ firing' = nextJob
    /\ nextJob' = nextJob + 1
    /\ UNCHANGED <<rec, lease, limbo, exec, disk, owed, watermark, wmEarly,
                   started, subsDone, intentsDone, crashes, skews,
                   inferences, completed, wasted>>

\* The consume write replaces the whole row, including a re-arm a fast run
\* may already have committed.
Consume ==
    /\ firing # NoJob
    /\ rec' = "consumed"
    /\ firing' = NoJob
    /\ UNCHANGED <<lease, queue, limbo, exec, mem, disk, owed, watermark,
                   wmEarly, started, subsDone, intentsDone, nextJob, crashes,
                   skews, inferences, completed, wasted>>

----------------------------------------------------------------------------
(* The wake runtime runs the digest. *)

Take ==
    /\ \E j \in queue :
          /\ queue' = queue \ {j}
          /\ limbo' = limbo \cup {j}
    /\ UNCHANGED <<rec, lease, firing, exec, mem, disk, owed, watermark,
                   wmEarly, started, subsDone, intentsDone, nextJob, crashes,
                   skews, inferences, completed, wasted>>

\* The agent's runner is busy: the job goes back to the queue.
Back ==
    /\ exec # NoJob
    /\ \E j \in limbo :
          /\ limbo' = limbo \ {j}
          /\ queue' = queue \cup {j}
    /\ UNCHANGED <<rec, lease, firing, exec, mem, disk, owed, watermark,
                   wmEarly, started, subsDone, intentsDone, nextJob, crashes,
                   skews, inferences, completed, wasted>>

Start ==
    /\ exec = NoJob
    /\ \E j \in limbo :
          /\ limbo' = limbo \ {j}
          /\ exec' = j
    /\ inferences' = inferences + 1
    /\ wasted' = IF watermark THEN wasted + 1 ELSE wasted
    /\ UNCHANGED <<rec, lease, firing, queue, mem, disk, owed, watermark,
                   wmEarly, started, subsDone, intentsDone, nextJob, crashes,
                   skews, completed>>

\* Milestone and next-day re-arm commit together; the run's intent settles.
\* The milestone is stamped from the run's own clock, which a backward step
\* can put before the record's consumedAt.
Complete ==
    /\ exec # NoJob
    /\ \E early \in (IF skews < MaxSkews THEN BOOLEAN ELSE {FALSE}) :
          /\ wmEarly' = (IF watermark THEN wmEarly ELSE early)
          /\ skews' = IF early THEN skews + 1 ELSE skews
    /\ watermark' = TRUE
    /\ rec' = "next"
    /\ lease' = "none"
    /\ exec' = NoJob
    /\ mem' = mem \ {exec}
    /\ completed' = completed + 1
    /\ UNCHANGED <<firing, queue, limbo, disk, owed, started, subsDone,
                   intentsDone, nextJob, crashes, inferences, wasted>>

Flush ==
    /\ disk # mem
    /\ disk' = mem
    /\ UNCHANGED <<rec, lease, firing, queue, limbo, exec, mem, owed,
                   watermark, wmEarly, started, subsDone, intentsDone,
                   nextJob, crashes, skews, inferences, completed, wasted>>

----------------------------------------------------------------------------
(* Crash and startup. *)

Crash ==
    /\ crashes < MaxCrashes
    /\ crashes' = crashes + 1
    /\ firing' = NoJob
    /\ queue' = {}
    /\ limbo' = {}
    /\ exec' = NoJob
    /\ mem' = disk
    /\ owed' = disk
    /\ started' = FALSE
    /\ subsDone' = FALSE
    /\ intentsDone' = FALSE
    /\ UNCHANGED <<rec, lease, disk, watermark, wmEarly, nextJob, skews,
                   inferences, completed, wasted>>

StartManager ==
    /\ ~started
    /\ started' = TRUE
    /\ UNCHANGED <<rec, lease, firing, queue, limbo, exec, mem, disk, owed,
                   watermark, wmEarly, subsDone, intentsDone, nextJob,
                   crashes, skews, inferences, completed, wasted>>

\* _digestRecovery on a consumed record of today, claimed by this device.
Recover ==
    IF rec = "consumed" /\ ~HasWork
    THEN IF RanInWindow
         THEN /\ rec' = "next" /\ lease' = "none"
         ELSE /\ rec' = "pending" /\ lease' = "none"
    ELSE UNCHANGED <<rec, lease>>

\* The repair before every wake-manager pass.
PreCheck ==
    /\ started
    /\ firing = NoJob
    /\ Recover
    /\ UNCHANGED <<firing, queue, limbo, exec, mem, disk, owed, watermark,
                   wmEarly, started, subsDone, intentsDone, nextJob, crashes,
                   skews, inferences, completed, wasted>>

RestoreSubs ==
    /\ started /\ ~subsDone
    /\ firing = NoJob
    /\ subsDone' = TRUE
    /\ Recover
    /\ UNCHANGED <<firing, queue, limbo, exec, mem, disk, owed, watermark,
                   wmEarly, started, intentsDone, nextJob, crashes, skews,
                   inferences, completed, wasted>>

\* Owed intents merge into a queued digest job, or become a new one.
RestoreIntents ==
    /\ subsDone /\ ~intentsDone
    /\ intentsDone' = TRUE
    /\ owed' = {}
    /\ IF owed = {}
       THEN UNCHANGED <<queue, mem, nextJob>>
       ELSE IF queue # {}
            THEN /\ mem' = mem \ owed
                 /\ UNCHANGED <<queue, nextJob>>
            ELSE /\ nextJob <= MaxJobs
                 /\ queue' = {nextJob}
                 /\ mem' = (mem \ owed) \cup {nextJob}
                 /\ nextJob' = nextJob + 1
    /\ UNCHANGED <<rec, lease, firing, limbo, exec, disk, watermark, wmEarly,
                   started, subsDone, crashes, skews, inferences, completed,
                   wasted>>

Next ==
    \/ Claim \/ Settle \/ Fire \/ Consume
    \/ Take \/ Back \/ Start \/ Complete \/ Flush
    \/ Crash \/ StartManager \/ PreCheck \/ RestoreSubs \/ RestoreIntents

\* Crashes and clock steps are never forced; everything else the app does
\* on its own eventually happens.
Fairness ==
    /\ WF_vars(Claim) /\ WF_vars(Settle) /\ WF_vars(Fire) /\ WF_vars(Consume)
    /\ WF_vars(Take) /\ WF_vars(Start) /\ WF_vars(Complete) /\ WF_vars(Flush)
    /\ WF_vars(StartManager) /\ WF_vars(PreCheck) /\ WF_vars(RestoreSubs)
    /\ WF_vars(RestoreIntents)

Spec == Init /\ [][Next]_vars /\ Fairness

----------------------------------------------------------------------------
(* Properties. *)

TypeOK ==
    /\ rec \in {"pending", "consumed", "next"}
    /\ lease \in {"none", "claimed", "settled"}
    /\ queue \subseteq Jobs /\ limbo \subseteq Jobs
    /\ exec \in Jobs \cup {NoJob}
    /\ mem \subseteq Jobs /\ disk \subseteq Jobs /\ owed \subseteq Jobs

\* At most one briefing for the day.
AtMostOneDigest == completed <= 1

\* Never a second inference for a briefing the user already has.
NoInferenceAfterBriefing == wasted = 0

\* Every inference beyond the first was paid for a run a crash killed.
InferencesBounded == inferences <= crashes + 1

\* At least one briefing for the day, across any bounded run of crashes.
EventuallyBriefed == <>watermark
=============================================================================

------------------------- MODULE ScheduledWakeLease -------------------------
(***************************************************************************)
(* One leased scheduled-wake record — a goal escalation, a relationship    *)
(* escalation or the coordinator digest — replicated on several devices    *)
(* that sync it as a vector-clocked register. A device that finds it due   *)
(* claims it, waits a settle period, re-reads it, and fires it only if its *)
(* own claim survived; firing queues a wake job and flips the record to    *)
(* `consumed`. A lease that lapses unconsumed may be taken over.           *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Arm         goal_agent_phase_a.dart _armEscalation (ArmMode "carry"), *)
(*               relationship_agent_phase_a.dart _armEscalation            *)
(*               ("ifAbsent"); "fresh" is the goal arm before ADR 0069,    *)
(*               a new row with a null vector clock                        *)
(*   Scan        ScheduledWakeManager._processDueRecords and               *)
(*               _leaseApprovedRecord: claim, or approve a settled claim   *)
(*   Fire        the re-read before firing, the owed-wake check, and       *)
(*               WakeOrchestrator.enqueueManualWake (which records the     *)
(*               job's WakeIntentStore intent in memory)                   *)
(*   FlushIntent WakeIntentStore's coalesced write to the settings db      *)
(*   Consume     the `consumed` upsert through AgentSyncService            *)
(*   Deliver     sync apply: SyncEventProcessor._localAgentPayloadDominates*)
(*               with agent_concurrent_resolver.dart's scheduled-wake rule *)
(*   StartJob,   the wake drain and the executor settling, which settles   *)
(*   FinishJob   the job's intent                                          *)
(*   Crash,      process death, and the next launch; Restore is            *)
(*   Restart,    WakeOrchestrator.restoreWakeIntents, which may interleave *)
(*   Restore     with the startup scan                                     *)
(*   Die         a device that never comes back (lost, wiped)              *)
(*   Tick        wall-clock time; it cannot pass a message's delivery      *)
(*               deadline, a device's pending step, or a scan the          *)
(*               manager's timers owe (_scheduleRecheck re-arms at the     *)
(*               settle and at lease expiry)                               *)
(*                                                                         *)
(* A wake window is ordinal: arming over no row or a pending row joins the *)
(* current window, arming over a consumed row of window k opens k + 1.     *)
(* Concurrent arms of one window are one window. The ghost `runs` counts   *)
(* completed runs per window.                                              *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    N,                   \* devices 1..N
    MaxArms,             \* bound on arms (and so on windows)
    ArmBy,               \* arms happen no later than this instant
    Settle,              \* ScheduledWakeManager.leaseSettle
    Lease,               \* ScheduledWakeManager.leaseDuration
    MaxDelay,            \* sync delivers a write to a running peer within this
    MaxDown,             \* a crashed device restarts within this
    MaxTime,             \* time bound
    MaxCrashes,
    MaxDeaths,
    ArmMode,             \* "carry", "ifAbsent" or "fresh"; see the header
    FlushBeforeConsume,  \* the consume waits for the intent to be durable
    OwedCheck,           \* a due record whose wake is already owed is
                         \* consumed without a second enqueue
    ConsumeCurrentRow,   \* the consume re-reads the row (see Consume)
    RunOutlastsConsume   \* assumption: a run (an inference) does not
                         \* settle before the local consume write that was
                         \* issued first commits

Devices == 1..N
Windows == 1..MaxArms
NoHost == 0

ZeroVc == [x \in Devices |-> 0]
Empty == [st |-> "none", win |-> 0, at |-> 0, host |-> NoHost, until |-> 0,
          vc |-> ZeroVc, upd |-> 0]

VARIABLES
    now,
    rep,          \* per device: its replica of the record
    ctr,          \* per device: its vector-clock counter
    net,          \* sync messages in flight: [to, v, sent]
    pc,           \* per device: "idle", "approved" (claim confirmed, not
                  \* fired yet) or "fired" (job queued, not consumed yet)
    appr,         \* per device: the version its claim was approved on
    queued,       \* per device and window: queued jobs
    running,      \* per device and window: running jobs
    pend,         \* per device: windows whose intent is recorded in memory
    intents,      \* per device: windows whose intent is on disk
    status,       \* per device: "up", "down" or "dead"
    downSince,    \* per device: when it crashed
    booted,       \* per device: intents loaded at restart, not restored yet
    runs,         \* ghost: completed runs per window
    runsBy,       \* ghost: completed runs per device and window
    created,      \* ghost: windows some device armed
    consumedSeen, \* ghost: per device, windows its replica held consumed
    arms, crashes, deaths

vars == <<now, rep, ctr, net, pc, appr, queued, running, pend, intents,
          status, downSince, booted, runs, runsBy, created, consumedSeen,
          arms, crashes, deaths>>

Init ==
    /\ now = 0
    /\ rep = [d \in Devices |-> Empty]
    /\ ctr = [d \in Devices |-> 0]
    /\ net = {}
    /\ pc = [d \in Devices |-> "idle"]
    /\ appr = [d \in Devices |-> Empty]
    /\ queued = [d \in Devices |-> [w \in Windows |-> 0]]
    /\ running = [d \in Devices |-> [w \in Windows |-> 0]]
    /\ pend = [d \in Devices |-> {}]
    /\ intents = [d \in Devices |-> {}]
    /\ status = [d \in Devices |-> "up"]
    /\ downSince = [d \in Devices |-> 0]
    /\ booted = [d \in Devices |-> {}]
    /\ runs = [w \in Windows |-> 0]
    /\ runsBy = [d \in Devices |-> [w \in Windows |-> 0]]
    /\ created = {}
    /\ consumedSeen = [d \in Devices |-> {}]
    /\ arms = 0
    /\ crashes = 0
    /\ deaths = 0

----------------------------------------------------------------------------
(* Vector clocks and the resolver. *)

Leq(a, b) == \A x \in Devices : a[x] <= b[x]

\* A replica-independent total order on clocks (compareClocksCanonically).
FirstDiff(a, b) ==
    CHOOSE i \in Devices : a[i] # b[i] /\ \A j \in 1..(i - 1) : a[j] = b[j]
CanonGT(a, b) == a # b /\ a[FirstDiff(a, b)] > b[FirstDiff(a, b)]

\* Whether a replica holding `local` keeps it when `inc` arrives. Causal
\* dominance first; a concurrent pair goes to the later scheduledAt (`at`),
\* then, at one instant, to `consumed`, then to the later updatedAt, then to
\* the canonical clock order.
KeepLocal(local, inc) ==
    IF local.st = "none" THEN FALSE
    ELSE IF Leq(inc.vc, local.vc) THEN TRUE
    ELSE IF Leq(local.vc, inc.vc) THEN FALSE
    ELSE IF local.at # inc.at THEN local.at > inc.at
    ELSE IF local.st = "consumed" /\ inc.st # "consumed" THEN TRUE
    ELSE IF inc.st = "consumed" /\ local.st # "consumed" THEN FALSE
    ELSE IF local.upd # inc.upd THEN local.upd > inc.upd
    ELSE ~CanonGT(inc.vc, local.vc)

\* The next clock a device stamps on a write built from `vc`.
Bump(d, vc) == [vc EXCEPT ![d] = ctr[d] + 1]
\* A row built from scratch: `vectorClock: null`.
NullClock(d) == [ZeroVc EXCEPT ![d] = ctr[d] + 1]

Seen(d, v) ==
    IF v.st = "consumed" THEN consumedSeen[d] \cup {v.win} ELSE consumedSeen[d]

\* A local write: persisted, stamped, and queued for every peer.
Write(d, v) ==
    /\ rep' = [rep EXCEPT ![d] = v]
    /\ ctr' = [ctr EXCEPT ![d] = @ + 1]
    /\ net' = net \cup {[to |-> e, v |-> v, sent |-> now] : e \in Devices \ {d}}
    /\ consumedSeen' = [consumedSeen EXCEPT ![d] = Seen(d, v)]

Held(r) == r.host # NoHost /\ r.until > now
Settled(r) == now >= r.until - Lease + Settle

\* A wake for window w that this device already owes: queued, running or
\* restorable. Every such job has an intent, in memory or on disk, tagged
\* with the window it fires (WakeIntentStore.markWindow).
Owed(d, w) == w \in pend[d] \cup intents[d]

\* The pending record's window is already owed here: consume it, no lease.
OwedNow(d) == OwedCheck /\ rep[d].st = "pending" /\ Owed(d, rep[d].win)

\* A scan this device's timers owe now: a due record it already owes, one
\* it can claim, or its own claim whose settle has elapsed.
Actionable(d) ==
    /\ status[d] = "up"
    /\ pc[d] = "idle"
    /\ rep[d].st = "pending"
    /\ \/ OwedNow(d)
       \/ ~Held(rep[d])
       \/ rep[d].host = d /\ Settled(rep[d])

----------------------------------------------------------------------------
(* Arming. *)

NextWindow(r) ==
    CASE r.st = "none" -> 1
      [] r.st = "pending" -> r.win
      [] r.st = "consumed" -> r.win + 1

\* The scheduledAt an arm writes. Before ADR 0069 every goal arm wrote the
\* period's instant; now a window armed over a consumed row is due one
\* microsecond after it, which every device computes alike.
ArmAt(r) == IF ArmMode = "carry" /\ r.st = "consumed" THEN r.at + 1 ELSE 1

Arm(d) ==
    /\ status[d] = "up"
    /\ now <= ArmBy
    /\ arms < MaxArms
    /\ arms' = arms + 1
    /\ LET r == rep[d]
           w == NextWindow(r)
           fresh == [st |-> "pending", win |-> w, at |-> ArmAt(r),
                     host |-> NoHost, until |-> 0, vc |-> NullClock(d),
                     upd |-> now]
       IN CASE ArmMode = "fresh" ->
                 /\ w \in Windows
                 /\ Write(d, fresh)
                 /\ created' = created \cup {w}
            [] ArmMode = "ifAbsent" ->
                 IF r.st = "none"
                 THEN /\ Write(d, fresh)
                      /\ created' = created \cup {w}
                 ELSE UNCHANGED <<rep, ctr, net, consumedSeen, created>>
            [] ArmMode = "carry" ->
                 \* A pending row is this window already: left as it is,
                 \* claim and all. A consumed row is carried forward, so
                 \* the new window causally follows the consumption, and it
                 \* is due a microsecond later, so it also outranks every
                 \* version of the consumed window a peer still holds.
                 IF r.st = "pending"
                 THEN UNCHANGED <<rep, ctr, net, consumedSeen, created>>
                 ELSE /\ w \in Windows
                      /\ Write(d, [fresh EXCEPT !.vc = Bump(d, r.vc)])
                      /\ created' = created \cup {w}
    /\ UNCHANGED <<now, pc, appr, queued, running, pend, intents, status,
                   downSince, booted, runs, runsBy, crashes, deaths>>

----------------------------------------------------------------------------
(* The lease. *)

\* Consume a record whose wake is already owed; otherwise claim an unheld
\* record, or approve this device's own settled claim.
Scan(d) ==
    /\ Actionable(d)
    /\ LET r == rep[d] IN
       IF OwedNow(d)
       THEN /\ Write(d, [r EXCEPT !.st = "consumed", !.upd = now,
                                  !.vc = Bump(d, r.vc)])
            /\ UNCHANGED <<pc, appr>>
       ELSE IF Held(r)
       THEN /\ pc' = [pc EXCEPT ![d] = "approved"]
            /\ appr' = [appr EXCEPT ![d] = r]
            /\ UNCHANGED <<rep, ctr, net, consumedSeen>>
       ELSE /\ Write(d, [r EXCEPT !.host = d, !.until = now + Lease,
                                  !.upd = now, !.vc = Bump(d, r.vc)])
            /\ UNCHANGED <<pc, appr>>
    /\ UNCHANGED <<now, queued, running, pend, intents, status, downSince,
                   booted, runs, runsBy, created, arms, crashes, deaths>>

\* The re-read before firing: the record must still be pending under the
\* approved claim. Then the job is queued — unless it is already owed.
Fire(d) ==
    /\ status[d] = "up"
    /\ pc[d] = "approved"
    /\ LET r == rep[d]
           a == appr[d]
       IN IF r.st # "pending" \/ r.host # a.host \/ r.until # a.until
             \/ r.win # a.win
          THEN /\ pc' = [pc EXCEPT ![d] = "idle"]
               /\ UNCHANGED <<queued, pend>>
          ELSE /\ pc' = [pc EXCEPT ![d] = "fired"]
               /\ IF OwedCheck /\ Owed(d, r.win)
                  THEN UNCHANGED <<queued, pend>>
                  ELSE /\ queued' = [queued EXCEPT ![d][r.win] = @ + 1]
                       /\ pend' = [pend EXCEPT ![d] = @ \cup {r.win}]
    /\ UNCHANGED <<now, rep, ctr, net, appr, running, intents, status,
                   downSince, booted, runs, runsBy, created, consumedSeen,
                   arms, crashes, deaths>>

\* The coalesced intent write lands on disk.
FlushIntent(d) ==
    /\ status[d] = "up"
    /\ pend[d] # {}
    /\ intents' = [intents EXCEPT ![d] = @ \cup pend[d]]
    /\ pend' = [pend EXCEPT ![d] = {}]
    /\ UNCHANGED <<now, rep, ctr, net, pc, appr, queued, running, status,
                   downSince, booted, runs, runsBy, created, consumedSeen,
                   arms, crashes, deaths>>

\* ConsumeCurrentRow: the row is re-read and consumed only while it is still
\* the fired window and pending; anything newer is left alone. Otherwise it
\* is built from the approved snapshot, as the due-query row was before ADR
\* 0069, overwriting whatever the replica holds by then.
Consume(d) ==
    /\ status[d] = "up"
    /\ pc[d] = "fired"
    /\ FlushBeforeConsume => appr[d].win \notin pend[d]
    /\ LET r == rep[d]
           a == appr[d]
       IN IF ConsumeCurrentRow
          THEN IF r.st = "pending" /\ r.at = a.at
               THEN Write(d, [r EXCEPT !.st = "consumed", !.upd = now,
                                       !.vc = Bump(d, r.vc)])
               ELSE UNCHANGED <<rep, ctr, net, consumedSeen>>
          ELSE Write(d, [a EXCEPT !.st = "consumed", !.upd = now,
                                  !.vc = Bump(d, a.vc)])
    /\ pc' = [pc EXCEPT ![d] = "idle"]
    /\ UNCHANGED <<now, appr, queued, running, pend, intents, status,
                   downSince, booted, runs, runsBy, created, arms, crashes,
                   deaths>>

----------------------------------------------------------------------------
(* Sync. *)

Deliver(m) ==
    /\ m \in net
    /\ status[m.to] # "down"
    /\ net' = net \ {m}
    /\ IF status[m.to] = "up" /\ ~KeepLocal(rep[m.to], m.v)
       THEN /\ rep' = [rep EXCEPT ![m.to] = m.v]
            /\ consumedSeen' = [consumedSeen EXCEPT ![m.to] = Seen(m.to, m.v)]
       ELSE UNCHANGED <<rep, consumedSeen>>
    /\ UNCHANGED <<now, ctr, pc, appr, queued, running, pend, intents, status,
                   downSince, booted, runs, runsBy, created, arms, crashes,
                   deaths>>

----------------------------------------------------------------------------
(* Jobs. *)

StartJob(d, w) ==
    /\ status[d] = "up"
    /\ queued[d][w] > 0
    /\ queued' = [queued EXCEPT ![d][w] = @ - 1]
    /\ running' = [running EXCEPT ![d][w] = @ + 1]
    /\ UNCHANGED <<now, rep, ctr, net, pc, appr, pend, intents, status,
                   downSince, booted, runs, runsBy, created, consumedSeen,
                   arms, crashes, deaths>>

\* A settled run settles the window's intent.
FinishJob(d, w) ==
    /\ status[d] = "up"
    /\ running[d][w] > 0
    /\ RunOutlastsConsume => ~(pc[d] = "fired" /\ appr[d].win = w)
    /\ running' = [running EXCEPT ![d][w] = @ - 1]
    /\ runs' = [runs EXCEPT ![w] = @ + 1]
    /\ runsBy' = [runsBy EXCEPT ![d][w] = @ + 1]
    /\ pend' = [pend EXCEPT ![d] = @ \ {w}]
    /\ intents' = [intents EXCEPT ![d] = @ \ {w}]
    /\ UNCHANGED <<now, rep, ctr, net, pc, appr, queued, status, downSince,
                   booted, created, consumedSeen, arms, crashes, deaths>>

----------------------------------------------------------------------------
(* Failures. *)

\* Process death: jobs, unflushed intents and in-flight steps are gone. The
\* replica, the on-disk intents and the sync outbox survive.
Crash(d) ==
    /\ crashes < MaxCrashes
    /\ status[d] = "up"
    /\ status' = [status EXCEPT ![d] = "down"]
    /\ downSince' = [downSince EXCEPT ![d] = now]
    /\ crashes' = crashes + 1
    /\ pc' = [pc EXCEPT ![d] = "idle"]
    /\ queued' = [queued EXCEPT ![d] = [w \in Windows |-> 0]]
    /\ running' = [running EXCEPT ![d] = [w \in Windows |-> 0]]
    /\ pend' = [pend EXCEPT ![d] = {}]
    /\ UNCHANGED <<now, rep, ctr, net, appr, intents, booted, runs, runsBy,
                   created, consumedSeen, arms, deaths>>

\* Messages that waited for the device are due from its restart on.
Restart(d) ==
    /\ status[d] = "down"
    /\ status' = [status EXCEPT ![d] = "up"]
    /\ booted' = [booted EXCEPT ![d] = intents[d]]
    /\ net' = {IF m.to = d THEN [m EXCEPT !.sent = now] ELSE m : m \in net}
    /\ UNCHANGED <<now, rep, ctr, pc, appr, queued, running, pend, intents,
                   downSince, runs, runsBy, created, consumedSeen, arms,
                   crashes, deaths>>

\* restoreWakeIntents: an intent the previous process left, and no run has
\* settled since, merges into a queued job of its window, and otherwise
\* becomes a job of its own. It runs after the startup scan has acted
\* (agent_providers.dart starts the manager before restoring intents).
Restore(d) ==
    /\ status[d] = "up"
    /\ booted[d] # {}
    /\ ~Actionable(d)
    /\ booted' = [booted EXCEPT ![d] = {}]
    /\ queued' = [queued EXCEPT ![d] =
                    [w \in Windows |->
                       IF w \in booted[d] \cap intents[d] /\ @[w] = 0
                       THEN 1 ELSE @[w]]]
    /\ UNCHANGED <<now, rep, ctr, net, pc, appr, running, pend, intents,
                   status, downSince, runs, runsBy, created, consumedSeen,
                   arms, crashes, deaths>>

\* A device gone for good, between steps: holding at most a claim. One that
\* dies after consuming takes the run with it (ADR 0048's residual).
Die(d) ==
    /\ deaths < MaxDeaths
    /\ status[d] = "up"
    /\ pc[d] = "idle"
    /\ \A w \in Windows : queued[d][w] = 0 /\ running[d][w] = 0
    /\ pend[d] = {} /\ intents[d] = {}
    /\ status' = [status EXCEPT ![d] = "dead"]
    /\ deaths' = deaths + 1
    /\ UNCHANGED <<now, rep, ctr, net, pc, appr, queued, running, pend,
                   intents, downSince, booted, runs, runsBy, created,
                   consumedSeen, arms, crashes>>

----------------------------------------------------------------------------
(* Time. *)

Tick ==
    /\ now < MaxTime
    /\ \A m \in net : status[m.to] = "up" => now < m.sent + MaxDelay
    /\ \A d \in Devices :
          /\ ~Actionable(d)
          /\ status[d] = "up" => pc[d] = "idle"
          /\ status[d] = "down" => now < downSince[d] + MaxDown
    /\ now' = now + 1
    /\ UNCHANGED <<rep, ctr, net, pc, appr, queued, running, pend, intents,
                   status, downSince, booted, runs, runsBy, created,
                   consumedSeen, arms, crashes, deaths>>

Next ==
    \/ Tick
    \/ \E d \in Devices :
          \/ Arm(d) \/ Scan(d) \/ Fire(d) \/ FlushIntent(d) \/ Consume(d)
          \/ Crash(d) \/ Restart(d) \/ Restore(d) \/ Die(d)
          \/ \E w \in Windows : StartJob(d, w) \/ FinishJob(d, w)
    \/ \E m \in net : Deliver(m)

Fairness ==
    /\ WF_vars(Tick)
    /\ \A d \in Devices :
          /\ WF_vars(Scan(d))
          /\ WF_vars(Fire(d))
          /\ WF_vars(FlushIntent(d))
          /\ WF_vars(Consume(d))
          /\ WF_vars(Restart(d))
          /\ WF_vars(Restore(d))
          /\ WF_vars(\E m \in net : m.to = d /\ Deliver(m))
          /\ \A w \in Windows :
                WF_vars(StartJob(d, w)) /\ WF_vars(FinishJob(d, w))

Spec == Init /\ [][Next]_vars /\ Fairness

----------------------------------------------------------------------------
(* Properties. *)

TypeOK ==
    /\ now \in 0..MaxTime
    /\ pc \in [Devices -> {"idle", "approved", "fired"}]
    /\ status \in [Devices -> {"up", "down", "dead"}]
    /\ \A d \in Devices : rep[d].st \in {"none", "pending", "consumed"}
    /\ created \subseteq Windows

\* The lease picks exactly one device to run each window.
AtMostOnce == \A w \in Windows : runs[w] <= 1

\* No device runs a window twice — the crash-restore guarantee, which holds
\* where AtMostOnce cannot (see the README).
NoDeviceRunsTwice == \A d \in Devices, w \in Windows : runsBy[d][w] <= 1

\* Consumption is terminal per wake window: a replica that held window w
\* consumed never holds it pending again.
WindowTerminal ==
    \A d \in Devices : rep[d].st = "pending" => rep[d].win \notin consumedSeen[d]

\* Once every write is delivered, the live replicas agree.
Converged ==
    net = {} =>
        \A d, e \in {x \in Devices : status[x] # "dead"} :
            rep[d].st = rep[e].st /\ rep[d].win = rep[e].win

\* Every armed window is run to completion by some device.
NoLostWindow == \A w \in Windows : (w \in created) ~> (runs[w] >= 1)
=============================================================================

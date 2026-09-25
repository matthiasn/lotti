---------------------------- MODULE GoalRegister ----------------------------
(***************************************************************************)
(* One goal's register row for one day, across devices: Phase A of the     *)
(* goal-agent wake (ADR 0054, "convergence over coordination"). Evidence   *)
(* (a habit check-off, a measurement) is written on some device and syncs; *)
(* every device recomputes the day's row from its own journal and writes   *)
(* it wholesale; rows sync and resolve. A status the standing report does  *)
(* not state arms the synced escalation wake, whose lease-elected Phase B  *)
(* writes the report.                                                      *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Write     a local journal write the goal's criteria read; the         *)
(*             WakeOrchestrator subscription owes the "local" lane a run   *)
(*             (a durable wake intent, WakeRuntime.tla)                    *)
(*   Deliver   sync applying a row on a peer. A journal row owes the       *)
(*             "sync" lane a run (GoalSignalSyncDispatcher runs Phase A    *)
(*             from an in-memory, serialized queue). A register row        *)
(*             resolves by resolveAgentEntityVersions: vector-clock        *)
(*             dominance, else the later updatedAt. A report replaces an   *)
(*             older one.                                                  *)
(*   Derive    GoalAgentPhaseA.deriveWakeFacts: read the journal, the      *)
(*             day's row (previousStatus: today's row, else yesterday's,   *)
(*             here "behind") and today's standing report                  *)
(*   Commit    persistDerivation: write a row carrying the clock of the    *)
(*             row it builds on, unless it would reproduce that row; owe   *)
(*             an escalation on a transition or a contradicted report      *)
(*   Stale     persistDerivation's GoalPersistOutcome.stale: the row or    *)
(*             today's report moved since the derivation read it, so it    *)
(*             derives again                                               *)
(*   Arm       the device-local deferred refresh firing (the "deferred"    *)
(*             arm only): Phase A re-entered arms the escalation           *)
(*   Run       the escalation's lease elects a live device                 *)
(*             (ScheduledWakeLease.tla, taken as given); Phase B there     *)
(*             derives from its own journal and writes the report          *)
(*   Crash     process restart: in-flight runs and the in-memory sync      *)
(*             dispatch queue are lost; durable intents and the local      *)
(*             refresh deadline (nextWakeAt) survive                       *)
(*   Death     a device that never comes back                              *)
(*                                                                         *)
(* Each constant but Hidden and MaxTick contrasts the code before this     *)
(* spec with the code now; the configurations check the code now.         *)
(*   Lock      "none": the orchestrator's and the dispatcher's runs of one *)
(*             goal interleave on a device. "agent": runExclusive.         *)
(*   Validate  "none": a commit builds on whatever row it re-reads.        *)
(*             "rederive": a row or report that moved under the run is     *)
(*             re-derived.                                                 *)
(*   Escalate  "transition": owed when the status differs from the last   *)
(*             persisted row. "contradicted": also when a report for today *)
(*             states another status (reportContradicted).                 *)
(*   Restart   "restore": durable intents only. "recompute": startup      *)
(*             runs Phase A for every active goal (GoalRuntimeMaintenance) *)
(*   ArmAt     "deferred": behind a device-local countdown. "commit": in   *)
(*             the register's transaction.                                 *)
(*   OnSynced  "ignore": the code. "recompute": a rejected alternative in  *)
(*             which a synced register row or report owes the receiver a   *)
(*             run; see the README for why it is not the code.             *)
(*   Hidden    0, or an item the last device can never see: a private      *)
(*             entry its visibility setting hides, or one its time zone    *)
(*             puts on another day.                                        *)
(*                                                                         *)
(* One spec version (revisions: VersionHeads.tla), one day, and evidence   *)
(* only ever added. Status is "onTrack" once every item is recorded.       *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    N,           \* devices 1..N
    K,           \* evidence items 1..K
    Hidden,      \* 0, or an item device N never sees
    Lock,        \* "none" or "agent"
    Validate,    \* "none" or "rederive"
    Escalate,    \* "transition" or "contradicted"
    Restart,     \* "restore" or "recompute"
    ArmAt,       \* "deferred" or "commit"
    OnSynced,    \* "ignore" or "recompute"
    MaxTick,     \* bound on register and report writes
    MaxCrashes,
    MaxDeaths

Devices == 1..N
Items == 1..K
Lanes == {"local", "sync"}
Yesterday == "behind"
Status(ev) == IF ev = Items THEN "onTrack" ELSE "behind"
Sees(d, i) == ~(d = N /\ i = Hidden)
NoReg == [ev |-> {}, st |-> "none", vc |-> [e \in Devices |-> 0], at |-> 0]
NoRep == [st |-> Yesterday, at |-> 0]
Idle == [pc |-> "idle", ev |-> {}, prev |-> "none", seen |-> NoReg,
         seenRep |-> NoRep]

VARIABLES
    written,    \* items some device has written
    jr,         \* per device: the journal items it holds
    reg,        \* per device: its replica of the day's register row
    lane,       \* per device and lane: an in-flight Phase A run
    owed,       \* per device and lane: a run is owed
    refresh,    \* per device: a queued local refresh ("deferred" arm)
    pending,    \* the period's escalation wake is armed and not yet run
    rep,        \* per device: its replica of the standing report
    net,        \* in-flight sync messages
    tick,       \* wall clock for updatedAt
    lost,       \* ghost: a device died holding an escalation it owed
    alive, crashes, deaths

vars == <<written, jr, reg, lane, owed, refresh, pending, rep, net, tick,
          lost, alive, crashes, deaths>>

Init ==
    /\ written = {}
    /\ jr = [d \in Devices |-> {}]
    /\ reg = [d \in Devices |-> NoReg]
    /\ lane = [d \in Devices |-> [l \in Lanes |-> Idle]]
    /\ owed = [d \in Devices |-> [l \in Lanes |-> FALSE]]
    /\ refresh = [d \in Devices |-> FALSE]
    /\ pending = FALSE
    /\ rep = [d \in Devices |-> NoRep]
    /\ net = {}
    /\ tick = 1
    /\ lost = FALSE
    /\ alive = [d \in Devices |-> TRUE]
    /\ crashes = 0
    /\ deaths = 0

\* resolveAgentEntityVersions for two rows of one spec version.
Dominates(a, b) == \A e \in Devices : a[e] >= b[e]
Resolve(local, incoming) ==
    IF local = NoReg THEN incoming
    ELSE IF Dominates(local.vc, incoming.vc) THEN local
    ELSE IF Dominates(incoming.vc, local.vc) THEN incoming
    ELSE IF incoming.at > local.at THEN incoming ELSE local

\* The standing report: the newer write wins.
NewerRep(local, incoming) == IF incoming.at > local.at THEN incoming ELSE local

Msg(e, what, item, row, r) ==
    [to |-> e, what |-> what, item |-> item, row |-> row, rep |-> r]

Other(l) == IF l = "local" THEN "sync" ELSE "local"

Write(d, i) ==
    /\ alive[d]
    /\ i \notin written
    /\ Sees(d, i)
    /\ written' = written \cup {i}
    /\ jr' = [jr EXCEPT ![d] = @ \cup {i}]
    /\ owed' = [owed EXCEPT ![d]["local"] = TRUE]
    /\ net' = net \cup {Msg(e, "item", i, NoReg, NoRep) : e \in Devices \ {d}}
    /\ UNCHANGED <<reg, lane, refresh, pending, rep, tick, lost, alive,
                   crashes, deaths>>

Derive(d, l) ==
    /\ alive[d]
    /\ owed[d][l]
    /\ lane[d][l].pc = "idle"
    /\ Lock = "agent" => lane[d][Other(l)].pc = "idle"
    /\ lane' = [lane EXCEPT ![d][l] =
         [pc |-> "derived", ev |-> jr[d],
          prev |-> IF reg[d] = NoReg THEN Yesterday ELSE reg[d].st,
          seen |-> reg[d], seenRep |-> rep[d]]]
    /\ owed' = [owed EXCEPT ![d][l] = FALSE]
    /\ UNCHANGED <<written, jr, reg, refresh, pending, rep, net, tick, lost,
                   alive, crashes, deaths>>

Stale(d, l) ==
    /\ alive[d]
    /\ Validate = "rederive"
    /\ lane[d][l].pc = "derived"
    /\ reg[d] # lane[d][l].seen \/ rep[d] # lane[d][l].seenRep
    /\ owed' = [owed EXCEPT ![d][l] = TRUE]
    /\ lane' = [lane EXCEPT ![d][l] = Idle]
    /\ UNCHANGED <<written, jr, reg, refresh, pending, rep, net, tick, lost,
                   alive, crashes, deaths>>

Commit(d, l) ==
    /\ alive[d]
    /\ lane[d][l].pc = "derived"
    /\ Validate = "rederive" =>
         reg[d] = lane[d][l].seen /\ rep[d] = lane[d][l].seenRep
    /\ tick < MaxTick
    /\ LET run == lane[d][l]
           base == reg[d]
           row == [ev |-> run.ev, st |-> Status(run.ev),
                   vc |-> [base.vc EXCEPT ![d] = @ + 1], at |-> tick]
           unchanged == base # NoReg /\ base.ev = run.ev
           owes ==
             \/ Status(run.ev) # run.prev
             \/ Escalate = "contradicted"
                  /\ run.seenRep # NoRep /\ Status(run.ev) # run.seenRep.st
       IN /\ IF unchanged
             THEN UNCHANGED <<reg, net, tick>>
             ELSE /\ reg' = [reg EXCEPT ![d] = row]
                  /\ net' = net \cup
                       {Msg(e, "reg", 0, row, NoRep) : e \in Devices \ {d}}
                  /\ tick' = tick + 1
          /\ IF ArmAt = "commit"
             THEN /\ pending' = (pending \/ owes)
                  /\ UNCHANGED refresh
             ELSE /\ refresh' = [refresh EXCEPT ![d] = @ \/ owes]
                  /\ UNCHANGED pending
    /\ lane' = [lane EXCEPT ![d][l] = Idle]
    /\ UNCHANGED <<written, jr, owed, rep, lost, alive, crashes, deaths>>

\* The deferred refresh fires: Phase A arms the period's escalation, and
\* arming again while it is pending joins it.
Arm(d) ==
    /\ alive[d]
    /\ refresh[d]
    /\ pending' = TRUE
    /\ refresh' = [refresh EXCEPT ![d] = FALSE]
    /\ UNCHANGED <<written, jr, reg, lane, owed, rep, net, tick, lost,
                   alive, crashes, deaths>>

Run(d) ==
    /\ alive[d]
    /\ pending
    /\ tick < MaxTick
    /\ LET r == [st |-> Status(jr[d]), at |-> tick]
       IN /\ rep' = [rep EXCEPT ![d] = r]
          /\ net' = net \cup
               {Msg(e, "rep", 0, NoReg, r) : e \in Devices \ {d}}
    /\ pending' = FALSE
    /\ tick' = tick + 1
    /\ UNCHANGED <<written, jr, reg, lane, owed, refresh, lost, alive,
                   crashes, deaths>>

Deliver(m) ==
    /\ net' = net \ {m}
    /\ IF ~alive[m.to]
       THEN UNCHANGED <<jr, reg, rep, owed>>
       ELSE IF m.what = "item"
       THEN IF Sees(m.to, m.item)
            THEN /\ jr' = [jr EXCEPT ![m.to] = @ \cup {m.item}]
                 /\ owed' = [owed EXCEPT ![m.to]["sync"] = TRUE]
                 /\ UNCHANGED <<reg, rep>>
            ELSE UNCHANGED <<jr, reg, rep, owed>>
       ELSE IF m.what = "reg"
       THEN /\ reg' = [reg EXCEPT ![m.to] = Resolve(@, m.row)]
            /\ owed' = IF OnSynced = "recompute"
                          /\ Resolve(reg[m.to], m.row) # reg[m.to]
                        THEN [owed EXCEPT ![m.to]["sync"] = TRUE]
                        ELSE owed
            /\ UNCHANGED <<jr, rep>>
       ELSE /\ rep' = [rep EXCEPT ![m.to] = NewerRep(@, m.rep)]
            /\ owed' = IF OnSynced = "recompute"
                          /\ NewerRep(rep[m.to], m.rep) # rep[m.to]
                        THEN [owed EXCEPT ![m.to]["sync"] = TRUE]
                        ELSE owed
            /\ UNCHANGED <<jr, reg>>
    /\ UNCHANGED <<written, lane, refresh, pending, tick, lost, alive,
                   crashes, deaths>>

Crash(d) ==
    /\ alive[d]
    /\ crashes < MaxCrashes
    /\ crashes' = crashes + 1
    /\ lane' = [lane EXCEPT ![d] = [l \in Lanes |-> Idle]]
    \* A local run's wake intent is durable until the run completes; the
    \* dispatcher's queue lives in memory.
    /\ owed' = [owed EXCEPT
         ![d]["local"] = @ \/ lane[d]["local"].pc = "derived"
                           \/ Restart = "recompute",
         ![d]["sync"] = FALSE]
    /\ UNCHANGED <<written, jr, reg, refresh, pending, rep, net, tick, lost,
                   alive, deaths>>

Death(d) ==
    /\ alive[d]
    /\ deaths < MaxDeaths
    /\ Cardinality({e \in Devices : alive[e]}) > 1
    /\ deaths' = deaths + 1
    /\ alive' = [alive EXCEPT ![d] = FALSE]
    /\ lost' = (lost \/ refresh[d])
    /\ UNCHANGED <<written, jr, reg, lane, owed, refresh, pending, rep, net,
                   tick, crashes>>

Next ==
    \/ \E d \in Devices :
         \/ \E i \in Items : Write(d, i)
         \/ \E l \in Lanes : Derive(d, l) \/ Commit(d, l) \/ Stale(d, l)
         \/ Arm(d)
         \/ Run(d)
         \/ Crash(d)
         \/ Death(d)
    \/ \E m \in net : Deliver(m)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------

Live == {d \in Devices : alive[d]}

\* Nothing left to happen on any live device: sync is quiet, no run is in
\* flight or owed, no refresh is queued and no escalation is pending. The
\* write bound must not be what stopped it.
Quiescent ==
    /\ tick < MaxTick
    /\ \A m \in net : ~alive[m.to]
    /\ ~pending
    /\ \A d \in Live :
         /\ \A l \in Lanes : lane[d][l].pc = "idle" /\ ~owed[d][l]
         /\ ~refresh[d]

TypeOK ==
    /\ written \subseteq Items
    /\ \A d \in Devices : jr[d] \subseteq Items
    /\ \A d \in Devices : rep[d].st \in {"behind", "onTrack"}

\* Every live replica holds the same row once sync is quiet.
Converged == Quiescent => \A d, e \in Live : reg[d] = reg[e]

\* Recompute-never-accumulate delivers its promise: once quiet, the row was
\* computed from every item recorded that day.
Complete ==
    Quiescent /\ written # {} => \A d \in Live : reg[d].ev = written

\* Once quiet, the standing report says what the day came to.
ReportCurrent ==
    Quiescent => \A d \in Live : rep[d].st = Status(written)

\* An escalation a commit owed never dies with the device that owed it: it
\* is synced (the lease takes it over) or already run. Holds under deaths,
\* where the other properties have a residual (see the README).
EscalationDurable == ~lost

\* Devices whose views of the journal never agree do not trade register rows
\* or reports forever: the evidence written, not the disagreement, bounds
\* the writes.
Bounded == tick < MaxTick

=============================================================================

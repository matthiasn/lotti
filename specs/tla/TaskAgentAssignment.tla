------------------------- MODULE TaskAgentAssignment -------------------------
(***************************************************************************)
(* At most one task agent per task, across devices. A task agent is an     *)
(* agent identity plus an `agent_task` link from it to the task, both      *)
(* written by TaskAgentService.createTaskAgent under a fresh random id.    *)
(* That method refuses when the device already holds a link to the task,  *)
(* but the check is local: two devices that assign the task before either  *)
(* has the other's agent both create one. The follow-up tool does exactly  *)
(* that — a follow-up task confirmed on two devices gets one derived id    *)
(* (ADR 0075), and each device auto-assigns its category's agent — and so  *)
(* does a manual assignment on two devices. Both agents then live on,      *)
(* wake and write reports and proposals; the card shows only the one its   *)
(* primary link names.                                                     *)
(*                                                                         *)
(* A derived agent id would make the two creations one entity, but the     *)
(* task's agent is not a register: deleting an agent is local (it          *)
(* hard-deletes the rows and syncs only the `destroyed` lifecycle), and a  *)
(* reassignment after it would reuse the id that other devices still hold, *)
(* destroyed, with the old agent's history. So the fix ranks instead. The  *)
(* rank is the one every primary-link read already uses                    *)
(* (AgentLinkSelection.orderedPrimaryFirst: `createdAt`, then id, newest   *)
(* first), over the task's links whose agent identity the device holds,    *)
(* live or destroyed. The first-ranked link is the task's agent; every     *)
(* other live agent of the task is retired, which is a destroy: a synced   *)
(* lifecycle write, so each retirement reaches every device once.          *)
(*                                                                         *)
(* One task. Its agents come from a pool of ids; the rank is a creation    *)
(* order number, or, with Skew, any unused one (a device clock that is     *)
(* ahead or behind). An identity's lifecycle only moves from live to       *)
(* destroyed, so the merge of two versions is the destroyed one if either  *)
(* is. Every write reaches every other device exactly once, in any order;  *)
(* a lost delivery is recovered by backfill, which only delays it          *)
(* (AgentLinks and AgentReplication model loss). Legacy starts from data   *)
(* an older build left: two live agents on the task on every device.       *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Create      TaskAgentService.createTaskAgent: refused while the       *)
(*               device holds any link to the task, else identity and      *)
(*               link written in one transaction. "auto" is                *)
(*               FollowUpTaskHandler._tryAutoAssignAgent, once per         *)
(*               device; "manual" the assign button                        *)
(*               (assign_agent_cta_part.dart) and the other creation       *)
(*               paths                                                     *)
(*   Destroy     AgentService.destroyAgent, the Destroy button             *)
(*   HardDelete  AgentService.deleteAgent on a destroyed agent:            *)
(*               repository.hardDeleteAgent, local only                    *)
(*   Receive     SyncEventProcessor applying an agent identity or an       *)
(*               `agent_task` link; with RetireOnReceive it then calls     *)
(*               the retirement pass for the task (a separate              *)
(*               transaction, so a crash can fall between)                 *)
(*   Retire      TaskAgentRetirement.retireSuperseded: rank, and destroy   *)
(*               every live agent below the first, in one transaction      *)
(*   Wake        a task agent's wake (wireWakeExecutor): with WakeGate it  *)
(*               runs the pass first, and a retired agent does not run     *)
(*   Crash       process death between a receive and its pass; the next   *)
(*               start runs the pass over every task with more than one    *)
(*               agent (TaskAgentService.restoreSubscriptions) when        *)
(*               StartupRetire is on                                       *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Devices,
    Agents,          \* ids a creation can take
    LegacyAgents,    \* with Legacy: the two agents already on the task
    MaxDestroys,     \* user destroys, all devices together
    MaxCrashes,
    Legacy,          \* start from two live agents on every device
    Skew,            \* a new agent's rank can be anywhere
    \* Switches: TRUE is the implemented behaviour, FALSE the mutation.
    RetireLosers,    \* the pass retires the live agents ranked below first
    RetireOnReceive, \* a received link or identity schedules the pass
    StartupRetire,   \* the next start runs the pass
    WakeGate,        \* a wake runs the pass first; a retired agent stops
    SharedRank       \* the pass ranks by replicated data; FALSE keeps the
                     \* agent this device created

ASSUME /\ LegacyAgents \subseteq Agents
       /\ Cardinality(LegacyAgents) = 2
       /\ Cardinality(Devices) >= 2

Ranks == 1..Cardinality(Agents)
Msgs == [kind : {"link"}, a : Agents] \cup
        [kind : {"ident"}, a : Agents, st : {"live", "dead"}]

VARIABLES
    link,        \* per device: the agents whose agent_task link it holds
    ident,       \* per device, per agent: "none", "live" or "dead"
    inbox,       \* per device: writes sent to it, not yet received
    pending,     \* per device: a received write whose pass has not run
    rank,        \* per agent: 0 until created, then its createdAt rank
    creator,     \* per agent: the device that created it
    autoDone,    \* per device: the follow-up's auto-assign has run
    now,         \* ghost: a step counter, for creation and destroy times
    born,        \* ghost, per agent: when it was created
    lastDestroy, \* ghost: when the user last destroyed an agent
    destroyed,   \* ghost: agents the user destroyed
    badWake,     \* ghost: a wake ran for an agent its device ranks second
    crashes

vars == <<link, ident, inbox, pending, rank, creator, autoDone, now, born,
          lastDestroy, destroyed, badWake, crashes>>

LegacyRank(a) == IF a = CHOOSE x \in LegacyAgents : TRUE THEN 1 ELSE 2

Init ==
    /\ link = [d \in Devices |-> IF Legacy THEN LegacyAgents ELSE {}]
    /\ ident = [d \in Devices |-> [a \in Agents |->
                  IF Legacy /\ a \in LegacyAgents THEN "live" ELSE "none"]]
    /\ inbox = [d \in Devices |-> {}]
    \* An upgraded app's first start runs the startup pass.
    /\ pending = [d \in Devices |-> Legacy /\ StartupRetire]
    /\ rank = [a \in Agents |->
                  IF Legacy /\ a \in LegacyAgents THEN LegacyRank(a) ELSE 0]
    /\ creator = [a \in Agents |->
                  IF Legacy /\ a \in LegacyAgents
                  THEN CHOOSE d \in Devices : TRUE ELSE "none"]
    /\ autoDone = [d \in Devices |-> Legacy]
    /\ now = IF Legacy THEN 2 ELSE 0
    /\ born = [a \in Agents |->
                  IF Legacy /\ a \in LegacyAgents THEN LegacyRank(a) ELSE 0]
    /\ lastDestroy = 0
    /\ destroyed = {}
    /\ badWake = FALSE
    /\ crashes = 0

-----------------------------------------------------------------------------
\* What a device holds.

Created == {a \in Agents : rank[a] > 0}
Live(d) == {a \in link[d] : ident[d][a] = "live"}
\* The links the pass ranks: those whose identity the device holds.
Ranked(d) == {a \in link[d] : ident[d][a] # "none"}
Top(S) == CHOOSE a \in S : \A b \in S : rank[b] <= rank[a]
\* The task's agent on d. Without SharedRank, a device keeps its own.
First(d) ==
    IF ~SharedRank /\ \E a \in Live(d) : creator[a] = d
    THEN CHOOSE a \in Live(d) : creator[a] = d
    ELSE Top(Ranked(d))
Losers(d) ==
    IF Ranked(d) = {} \/ ~RetireLosers THEN {}
    ELSE Live(d) \ {First(d)}

Send(d, ms) ==
    [e \in Devices |-> IF e = d THEN inbox[e] ELSE inbox[e] \cup ms]

\* The pass on d: every loser destroyed, and each destroy sent.
RetireOn(d) ==
    LET out == Losers(d) IN
    /\ ident' = [ident EXCEPT ![d] =
          [a \in Agents |-> IF a \in out THEN "dead" ELSE ident[d][a]]]
    /\ inbox' = Send(d, {[kind |-> "ident", a |-> a, st |-> "dead"] :
                             a \in out})

-----------------------------------------------------------------------------
\* Steps.

Create(d, how) ==
    /\ link[d] = {}
    /\ how = "auto" => ~autoDone[d]
    /\ \E a \in Agents \ Created :
       \E r \in (IF Skew
                 THEN Ranks \ {rank[b] : b \in Created}
                 ELSE {Cardinality(Created) + 1}) :
          /\ rank' = [rank EXCEPT ![a] = r]
          /\ creator' = [creator EXCEPT ![a] = d]
          /\ link' = [link EXCEPT ![d] = @ \cup {a}]
          /\ ident' = [ident EXCEPT ![d][a] = "live"]
          /\ inbox' = Send(d, {[kind |-> "link", a |-> a],
                               [kind |-> "ident", a |-> a, st |-> "live"]})
          /\ born' = [born EXCEPT ![a] = now + 1]
    /\ now' = now + 1
    /\ autoDone' = IF how = "auto"
                   THEN [autoDone EXCEPT ![d] = TRUE] ELSE autoDone
    /\ UNCHANGED <<pending, lastDestroy, destroyed, badWake, crashes>>

Destroy(d, a) ==
    /\ Cardinality(destroyed) < MaxDestroys
    /\ ident[d][a] = "live"
    /\ ident' = [ident EXCEPT ![d][a] = "dead"]
    /\ inbox' = Send(d, {[kind |-> "ident", a |-> a, st |-> "dead"]})
    /\ destroyed' = destroyed \cup {a}
    /\ now' = now + 1
    /\ lastDestroy' = now + 1
    /\ UNCHANGED <<link, pending, rank, creator, autoDone, born, badWake,
                   crashes>>

\* Only once every write about the agent has arrived: a hard delete before
\* a late live copy lets that copy insert the agent again (see README).
HardDelete(d, a) ==
    /\ ident[d][a] = "dead"
    /\ \A m \in inbox[d] : m.a # a
    /\ ident' = [ident EXCEPT ![d][a] = "none"]
    /\ link' = [link EXCEPT ![d] = @ \ {a}]
    /\ UNCHANGED <<inbox, pending, rank, creator, autoDone, now, born,
                   lastDestroy, destroyed, badWake, crashes>>

Receive(d, m) ==
    /\ m \in inbox[d]
    /\ inbox' = [inbox EXCEPT ![d] = @ \ {m}]
    /\ IF m.kind = "link"
       THEN /\ link' = [link EXCEPT ![d] = @ \cup {m.a}]
            /\ UNCHANGED ident
       ELSE /\ ident' = [ident EXCEPT ![d][m.a] =
                           IF m.st = "dead" \/ @ = "dead" THEN "dead"
                           ELSE "live"]
            /\ UNCHANGED link
    /\ pending' = [pending EXCEPT ![d] = RetireOnReceive]
    /\ UNCHANGED <<rank, creator, autoDone, now, born, lastDestroy,
                   destroyed, badWake, crashes>>

Retire(d) ==
    /\ pending[d]
    /\ pending' = [pending EXCEPT ![d] = FALSE]
    /\ RetireOn(d)
    /\ UNCHANGED <<link, rank, creator, autoDone, now, born, lastDestroy,
                   destroyed, badWake, crashes>>

\* A wake of a live agent. The gate's pass and its verdict are one step: the
\* pass commits before the wake reads anything, and the wake runs only if
\* the pass left its agent live.
Wake(d, a) ==
    /\ a \in Live(d)
    /\ LET runs == ~WakeGate \/ a \notin Losers(d) IN
       badWake' = (badWake \/ (runs /\ a # Top(Ranked(d))))
    /\ IF WakeGate THEN RetireOn(d) ELSE UNCHANGED <<ident, inbox>>
    /\ UNCHANGED <<link, pending, rank, creator, autoDone, now, born,
                   lastDestroy, destroyed, crashes>>

Crash(d) ==
    /\ crashes < MaxCrashes
    /\ crashes' = crashes + 1
    /\ pending' = [pending EXCEPT ![d] = StartupRetire]
    /\ UNCHANGED <<link, ident, inbox, rank, creator, autoDone, now, born,
                   lastDestroy, destroyed, badWake>>

Next ==
    \E d \in Devices :
        \/ \E how \in {"auto", "manual"} : Create(d, how)
        \/ \E a \in Agents : Destroy(d, a) \/ HardDelete(d, a) \/ Wake(d, a)
        \/ \E m \in inbox[d] : Receive(d, m)
        \/ Retire(d)
        \/ Crash(d)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
\* Properties.

TypeOK ==
    /\ link \in [Devices -> SUBSET Agents]
    /\ ident \in [Devices -> [Agents -> {"none", "live", "dead"}]]
    /\ inbox \in [Devices -> SUBSET Msgs]
    /\ pending \in [Devices -> BOOLEAN]
    /\ rank \in [Agents -> 0..Cardinality(Agents)]
    /\ creator \in [Agents -> Devices \cup {"none"}]
    /\ destroyed \subseteq Created
    /\ badWake \in BOOLEAN

\* Every write has arrived everywhere and every pass it scheduled has run.
Quiescent == \A d \in Devices : inbox[d] = {} /\ ~pending[d]

\* Once quiescent, no device holds two live agents of the task.
AtMostOneLive == Quiescent => \A d \in Devices : Cardinality(Live(d)) <= 1

\* Once quiescent, every device holds the same live agent, or none.
LiveAgreed == Quiescent => \A d, e \in Devices : Live(d) = Live(e)

\* No over-retirement: an agent assigned after the user's last destroy (or
\* any agent, when the user destroyed none) leaves the task with a live
\* agent. Retiring may only take away agents in favour of one that stays,
\* or that the user destroyed before this one was assigned.
KeepsAgent ==
    (Quiescent /\ \E a \in Created : born[a] > lastDestroy)
        => \A d \in Devices : Live(d) # {}

\* Holds under Skew: with no destroy at all, some agent always stays.
KeepsAgentUndestroyed ==
    (Quiescent /\ destroyed = {} /\ Created # {})
        => \A d \in Devices : Live(d) # {}

\* A wake never runs for an agent that its own device ranks below another
\* link of the task: the loser of a race stops at its next wake, whatever
\* the sync has delivered.
NoSupersededWake == ~badWake
=============================================================================

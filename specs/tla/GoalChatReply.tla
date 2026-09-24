---------------------------- MODULE GoalChatReply ----------------------------
(***************************************************************************)
(* One user message to a goal agent, typed on the author device and synced *)
(* to its peers, and who answers it. The author's own wake answers it      *)
(* first; if that wake never succeeds, some device must still answer — but *)
(* only one.                                                               *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Init        GoalChatService.sendMessage: the durable user turn, its   *)
(*               recovery record (Recovery "lease"), and the explicit wake *)
(*   Restore     GoalChatService.restoreOldestPendingMessage, run by       *)
(*               GoalRuntimeMaintenance at startup, before every scheduled *)
(*               scan and on a synced identity. "eager": before ADR 0069 it *)
(*               enqueued a wake for the message on whichever device ran   *)
(*               it, and every goal wake answered the oldest pending       *)
(*               message; "lease": it arms the message's recovery record   *)
(*   Fire        ScheduledWakeManager firing the recovery record: a lease  *)
(*               election, checked in ScheduledWakeLease.tla, lets one     *)
(*               device fire each window; here that is taken as given      *)
(*   StartJob    goalAgentWakeRunnersProvider's router: a wake whose       *)
(*               message is already answered on this device does nothing   *)
(*   Commit,     the reply (GoalAgentWorkflow) or a failed run; the        *)
(*   Fail        author's explicit wake, on success, consumes the record   *)
(*   Crash       process death; the author's explicit wake is a durable    *)
(*               intent (WakeRuntime.tla) and is restored                  *)
(*   Tick        wall-clock time: a run commits within RunCap unless its   *)
(*               device is paused; sync delivers within MaxDelay           *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    N,           \* devices 1..N; device 1 is the author
    Recovery,    \* "lease" (ADR 0069) or "eager" (before it)
    Grace,       \* goalChatRecoveryGrace: how long the author has
    RunCap,      \* a healthy run commits or fails within this
    MaxDelay,    \* sync delivers within this
    MaxTime,
    MaxWindows,  \* bound on recovery windows
    MaxFails,    \* bound on failed runs
    MaxCrashes,
    MaxDeaths,
    MaxPauses    \* bound on devices paused past RunCap (a suspended app)

Devices == 1..N
Author == 1
None == [st |-> "none", at |-> 0, win |-> 0, until |-> 0]
NoRun == MaxTime + 1

VARIABLES
    now,
    answered,   \* per device: the reply is visible here
    rec,        \* per device: its replica of the recovery record
    net,        \* sync messages: [to, kind ("reply" or "rec"), v, sent]
    queued,     \* per device: queued wakes for the message
    running,    \* per device: start time of the running wake, or NoRun
    paused,     \* per device: its running wake may outlast RunCap
    explicit,   \* the author's own wake has not settled yet
    fired,      \* windows of the record some device fired
    status,     \* per device: "up", "down" or "dead"
    replies,    \* ghost: replies committed
    fails, crashes, deaths, pauses

vars == <<now, answered, rec, net, queued, running, paused, explicit, fired,
          status, replies, fails, crashes, deaths, pauses>>

Init ==
    /\ now = 0
    /\ answered = [d \in Devices |-> FALSE]
    /\ rec = [d \in Devices |->
                IF Recovery = "lease" /\ d = Author
                THEN [st |-> "pending", at |-> Grace, win |-> 1, until |-> 0] ELSE None]
    /\ net = IF Recovery = "lease"
             THEN {[to |-> e, kind |-> "rec",
                    v |-> [st |-> "pending", at |-> Grace, win |-> 1, until |-> 0],
                    sent |-> 0] : e \in Devices \ {Author}}
             ELSE {}
    /\ queued = [d \in Devices |-> IF d = Author THEN 1 ELSE 0]
    /\ running = [d \in Devices |-> NoRun]
    /\ paused = [d \in Devices |-> FALSE]
    /\ explicit = TRUE
    /\ fired = {}
    /\ status = [d \in Devices |-> "up"]
    /\ replies = 0
    /\ fails = 0
    /\ crashes = 0
    /\ deaths = 0
    /\ pauses = 0

Up(d) == status[d] = "up"

\* The record's resolver on the fields that matter here: a later deadline
\* wins, and at one deadline `consumed` is terminal.
Newer(inc, local) ==
    \/ local.st = "none"
    \/ inc.at > local.at
    \/ inc.at = local.at /\ inc.st = "consumed" /\ local.st = "pending"

WriteRec(d, v) ==
    /\ rec' = [rec EXCEPT ![d] = v]
    /\ net' = net \cup {[to |-> e, kind |-> "rec", v |-> v, sent |-> now] :
                          e \in Devices \ {d}}

----------------------------------------------------------------------------

\* The message is still unanswered here, and no wake for it is in hand.
Idle(d) == queued[d] = 0 /\ running[d] = NoRun

Restore(d) ==
    /\ Up(d)
    /\ ~answered[d]
    /\ IF Recovery = "eager"
       THEN /\ Idle(d)
            /\ queued' = [queued EXCEPT ![d] = 1]
            /\ UNCHANGED <<rec, net>>
       ELSE /\ \/ rec[d].st = "none"
               \/ rec[d].st = "consumed" /\ rec[d].win < MaxWindows
            \* The next window is due when the fired one's lease lapses —
            \* the same UTC instant on every replica — so a recovery run
            \* still in flight has had its time; a window the author
            \* consumed carries no lease and waits a grace instead.
            /\ WriteRec(d, IF rec[d].st = "none"
                           THEN [st |-> "pending", at |-> now + Grace,
                                 win |-> 1, until |-> 0]
                           ELSE [st |-> "pending",
                                 at |-> IF rec[d].until > 0
                                        THEN rec[d].until
                                        ELSE rec[d].at + Grace,
                                 win |-> rec[d].win + 1, until |-> 0])
            /\ UNCHANGED queued
    /\ UNCHANGED <<now, answered, running, paused, explicit, fired, status,
                   replies, fails, crashes, deaths, pauses>>

\* The lease elects one device per window; firing consumes the record, which
\* keeps the claim's leaseUntil (a Grace from now, as thirty minutes are
\* well past a ten-minute run cap).
Fire(d) ==
    /\ Up(d)
    /\ rec[d].st = "pending"
    /\ now >= rec[d].at
    /\ rec[d].win \notin fired
    /\ fired' = fired \cup {rec[d].win}
    /\ WriteRec(d, [rec[d] EXCEPT !.st = "consumed", !.until = now + Grace])
    /\ queued' = [queued EXCEPT ![d] = @ + 1]
    /\ UNCHANGED <<now, answered, running, paused, explicit, status, replies,
                   fails, crashes, deaths, pauses>>

\* The author's explicit wake settled successfully: consume the record, if it
\* is still the window the message was sent with.
SettleExplicit(d, ok) ==
    IF d = Author /\ explicit /\ ok
    THEN /\ explicit' = FALSE
         /\ IF rec[d].st = "pending" /\ rec[d].win = 1
            THEN WriteRec(d, [rec[d] EXCEPT !.st = "consumed"])
            ELSE UNCHANGED <<rec, net>>
    ELSE /\ explicit' = (IF d = Author THEN FALSE ELSE explicit)
         /\ UNCHANGED <<rec, net>>

\* The router: a wake whose message is answered here does nothing.
StartJob(d) ==
    /\ Up(d)
    /\ queued[d] > 0
    /\ running[d] = NoRun
    /\ queued' = [queued EXCEPT ![d] = @ - 1]
    /\ IF answered[d]
       THEN /\ SettleExplicit(d, TRUE)
            /\ UNCHANGED running
       ELSE /\ running' = [running EXCEPT ![d] = now]
            /\ UNCHANGED <<rec, net, explicit>>
    /\ UNCHANGED <<now, answered, paused, fired, status, replies, fails,
                   crashes, deaths, pauses>>

Commit(d) ==
    /\ Up(d)
    /\ running[d] # NoRun
    /\ running' = [running EXCEPT ![d] = NoRun]
    /\ paused' = [paused EXCEPT ![d] = FALSE]
    /\ replies' = replies + 1
    /\ answered' = [answered EXCEPT ![d] = TRUE]
    /\ LET replyMsgs == {[to |-> e, kind |-> "reply", v |-> None,
                          sent |-> now] : e \in Devices \ {d}}
       IN IF d = Author /\ explicit /\ rec[d].st = "pending"
                /\ rec[d].win = 1
          THEN /\ explicit' = FALSE
               /\ rec' = [rec EXCEPT ![d].st = "consumed"]
               /\ net' = net \cup replyMsgs \cup
                         {[to |-> e, kind |-> "rec",
                           v |-> [rec[d] EXCEPT !.st = "consumed"],
                           sent |-> now] : e \in Devices \ {d}}
          ELSE /\ explicit' = (IF d = Author THEN FALSE ELSE explicit)
               /\ net' = net \cup replyMsgs
               /\ UNCHANGED rec
    /\ UNCHANGED <<now, queued, fired, status, fails, crashes, deaths, pauses>>

Fail(d) ==
    /\ Up(d)
    /\ running[d] # NoRun
    /\ fails < MaxFails
    /\ fails' = fails + 1
    /\ running' = [running EXCEPT ![d] = NoRun]
    /\ paused' = [paused EXCEPT ![d] = FALSE]
    /\ SettleExplicit(d, FALSE)
    /\ UNCHANGED <<now, answered, queued, fired, status, replies, crashes,
                   deaths, pauses>>

Pause(d) ==
    /\ pauses < MaxPauses
    /\ running[d] # NoRun
    /\ ~paused[d]
    /\ paused' = [paused EXCEPT ![d] = TRUE]
    /\ pauses' = pauses + 1
    /\ UNCHANGED <<now, answered, rec, net, queued, running, explicit, fired,
                   status, replies, fails, crashes, deaths>>

Deliver(m) ==
    /\ m \in net
    /\ status[m.to] # "down"
    /\ net' = net \ {m}
    /\ IF status[m.to] = "up"
       THEN IF m.kind = "reply"
            THEN /\ answered' = [answered EXCEPT ![m.to] = TRUE]
                 /\ UNCHANGED rec
            ELSE /\ rec' = IF Newer(m.v, rec[m.to])
                           THEN [rec EXCEPT ![m.to] = m.v] ELSE rec
                 /\ UNCHANGED answered
       ELSE UNCHANGED <<answered, rec>>
    /\ UNCHANGED <<now, queued, running, paused, explicit, fired, status,
                   replies, fails, crashes, deaths, pauses>>

\* Process death. The author's explicit wake is a durable intent and comes
\* back at the restart.
Crash(d) ==
    /\ crashes < MaxCrashes
    /\ Up(d)
    /\ status' = [status EXCEPT ![d] = "down"]
    /\ crashes' = crashes + 1
    /\ queued' = [queued EXCEPT ![d] = 0]
    /\ running' = [running EXCEPT ![d] = NoRun]
    /\ paused' = [paused EXCEPT ![d] = FALSE]
    /\ UNCHANGED <<now, answered, rec, net, explicit, fired, replies, fails,
                   deaths, pauses>>

Restart(d) ==
    /\ status[d] = "down"
    /\ status' = [status EXCEPT ![d] = "up"]
    /\ queued' = [queued EXCEPT ![d] =
                    IF d = Author /\ explicit THEN 1 ELSE 0]
    /\ net' = {IF m.to = d THEN [m EXCEPT !.sent = now] ELSE m : m \in net}
    /\ UNCHANGED <<now, answered, rec, running, paused, explicit, fired,
                   replies, fails, crashes, deaths, pauses>>

\* A device gone for good.
Die(d) ==
    /\ deaths < MaxDeaths
    /\ status[d] # "dead"
    /\ status' = [status EXCEPT ![d] = "dead"]
    /\ deaths' = deaths + 1
    /\ queued' = [queued EXCEPT ![d] = 0]
    /\ running' = [running EXCEPT ![d] = NoRun]
    /\ explicit' = (IF d = Author THEN FALSE ELSE explicit)
    /\ UNCHANGED <<now, answered, rec, net, paused, fired, replies, fails,
                   crashes, pauses>>

Tick ==
    /\ now < MaxTime
    /\ \A m \in net : status[m.to] = "up" => now < m.sent + MaxDelay
    /\ \A d \in Devices :
          /\ running[d] # NoRun /\ ~paused[d] => now < running[d] + RunCap
          \* The drain dispatches a queued wake at once.
          /\ ~(Up(d) /\ queued[d] > 0 /\ running[d] = NoRun)
          \* The pre-scan maintenance runs before time moves on — hourly in
          \* the app, which only stretches every deadline alike.
          /\ ~ENABLED Restore(d)
          /\ ~(Up(d) /\ rec[d].st = "pending" /\ now >= rec[d].at
               /\ rec[d].win \notin fired)
    /\ now' = now + 1
    /\ UNCHANGED <<answered, rec, net, queued, running, paused, explicit,
                   fired, status, replies, fails, crashes, deaths, pauses>>

Next ==
    \/ Tick
    \/ \E d \in Devices :
          \/ Restore(d) \/ Fire(d) \/ StartJob(d) \/ Commit(d) \/ Fail(d)
          \/ Pause(d) \/ Crash(d) \/ Restart(d) \/ Die(d)
    \/ \E m \in net : Deliver(m)

Fairness ==
    /\ WF_vars(Tick)
    /\ \A d \in Devices :
          /\ WF_vars(Restore(d))
          /\ WF_vars(Fire(d))
          /\ WF_vars(StartJob(d))
          /\ WF_vars(Commit(d))
          /\ WF_vars(Restart(d))
          /\ WF_vars(\E m \in net : m.to = d /\ Deliver(m))

Spec == Init /\ [][Next]_vars /\ Fairness

----------------------------------------------------------------------------

TypeOK ==
    /\ now \in 0..MaxTime
    /\ replies \in 0..N * (MaxWindows + 2)
    /\ fired \subseteq 1..MaxWindows

\* Every device that answers answers the same one message: at most one reply.
AtMostOneReply == replies <= 1

\* While a device lives, the message is answered.
Answered == <>(replies >= 1)
=============================================================================

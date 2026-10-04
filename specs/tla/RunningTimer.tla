---------------------------- MODULE RunningTimer ----------------------------
(***************************************************************************)
(* The running timer on one device: a time entry whose end is moved to     *)
(* "now" while it runs, so a task's tracked time grows as work goes on.    *)
(* The timer lives in memory (TimeService); its entry is a journal row     *)
(* whose dateTo is the end the task's time adds up to. What the row holds   *)
(* when the timer stops is the tracked time, on this device and, through   *)
(* sync, on every other one.                                               *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Tick       time passes, one unit at a time; the autosave fires on     *)
(*              its cadence and is never late (TimeService's Timer)        *)
(*   Autosave   the running entry's end is written as now                  *)
(*              (persistRunningTimerEnd, every Interval)                   *)
(*   UserStart  the user starts a timer on a task                          *)
(*              (EntryCreationService → TimeService.start); replacing a    *)
(*              running one writes its end first                           *)
(*   UserStop   the user stops it: from the entry or the task's action bar *)
(*              (EntryController.save(stopRecording: true), which writes  *)
(*              the end), from the desktop sidebar's timer card, or by     *)
(*              switching profiles (ProfileSwitcher._quiesce), both       *)
(*              through TimeService.stop                                   *)
(*   Close      the app is quit normally (WindowService.shutdown →         *)
(*              ServiceDisposer)                                           *)
(*   Crash      the app dies; Restart starts it again with no timer        *)
(*   AgentCheck the task agent's time-entry tool checks that no timer runs *)
(*   AgentStart ... and, several awaits later, creates its entry and       *)
(*              starts the timer (TimeEntryHandler)                        *)
(***************************************************************************)
EXTENDS Naturals

CONSTANTS
    Entries,          \* time entries a start may create
    MaxTime,          \* the last moment modelled
    Interval,         \* the autosave cadence
    MaxCrashes,
    StopPersists,     \* every stop writes the entry's end; FALSE is the
                      \* former TimeService.stop, which only cleared memory
    ShutdownPersists, \* a normal quit stops the timer, writing its end;
                      \* FALSE is the former shutdown, which left the entry
                      \* at its last autosave
    AgentStartAtomic  \* the agent's check that no timer runs and its start
                      \* are one step (TimeService.startIfIdle); FALSE is
                      \* the former handler, which checked, awaited reads
                      \* and writes, then started over whatever ran by then

None == "none"
StopPaths == {"entry", "sidebar", "profile"}

VARIABLES
    now,       \* the clock
    cur,       \* the running timer's entry, or None
    lastSave,  \* when the running entry's end was last written
    entry,     \* per entry: made, its stored end, and ghosts — stopped (and
               \* when) or lost to a crash (and when)
    up,        \* the app runs
    agent,     \* the agent's tool call: "idle", "checked" (no timer ran)
    stolen,    \* ghost: the agent stopped a timer the user started after
               \* the agent had checked
    crashes

vars == <<now, cur, lastSave, entry, up, agent, stolen, crashes>>

NoEntry == [made |-> FALSE, end |-> 0, stopped |-> FALSE, stopAt |-> 0,
            crashed |-> FALSE, crashAt |-> 0]

Init ==
    /\ now = 0
    /\ cur = None
    /\ lastSave = 0
    /\ entry = [e \in Entries |-> NoEntry]
    /\ up = TRUE
    /\ agent = "idle"
    /\ stolen = FALSE
    /\ crashes = 0

-----------------------------------------------------------------------------
\* The running timer is stopped at now; [write] says whether its end is
\* written as now.
StopCur(write) ==
    IF cur = None THEN UNCHANGED entry
    ELSE entry' = [entry EXCEPT ![cur].stopped = TRUE, ![cur].stopAt = now,
                               ![cur].end = IF write THEN now ELSE @]

\* The autosave timer fires when it is due, before time moves on.
AutosaveDue == cur # None /\ now - lastSave >= Interval

Tick ==
    /\ now < MaxTime
    /\ ~AutosaveDue
    /\ now' = now + 1
    /\ UNCHANGED <<cur, lastSave, entry, up, agent, stolen, crashes>>

Autosave ==
    /\ up
    /\ AutosaveDue
    /\ entry' = [entry EXCEPT ![cur].end = now]
    /\ lastSave' = now
    /\ UNCHANGED <<now, cur, up, agent, stolen, crashes>>

\* A new timer: its entry is created ending now, and a running one is
\* stopped with its end written (TimeService.start's finalisation).
UserStart(e) ==
    /\ up
    /\ ~entry[e].made
    /\ cur' = e
    /\ lastSave' = now
    /\ entry' = [x \in Entries |->
                   IF x = e THEN [NoEntry EXCEPT !.made = TRUE, !.end = now]
                   ELSE IF x = cur
                   THEN [entry[x] EXCEPT !.stopped = TRUE, !.stopAt = now,
                                         !.end = now]
                   ELSE entry[x]]
    /\ UNCHANGED <<now, up, agent, stolen, crashes>>

UserStop(path) ==
    /\ up
    /\ cur # None
    /\ StopCur(path = "entry" \/ StopPersists)
    /\ cur' = None
    /\ UNCHANGED <<now, lastSave, up, agent, stolen, crashes>>

Close ==
    /\ up
    /\ StopCur(ShutdownPersists)
    /\ cur' = None
    /\ up' = FALSE
    /\ agent' = "idle"
    /\ UNCHANGED <<now, lastSave, stolen, crashes>>

Crash ==
    /\ up
    /\ crashes < MaxCrashes
    /\ entry' = IF cur = None THEN entry
                ELSE [entry EXCEPT ![cur].crashed = TRUE,
                                   ![cur].crashAt = now]
    /\ cur' = None
    /\ up' = FALSE
    /\ agent' = "idle"
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<now, lastSave, stolen>>

Restart ==
    /\ ~up
    /\ up' = TRUE
    /\ UNCHANGED <<now, cur, lastSave, entry, agent, stolen, crashes>>

\* The tool checks that no timer runs. With AgentStartAtomic the check is
\* repeated in the same step as the start (AgentStart).
AgentCheck ==
    /\ up
    /\ agent = "idle"
    /\ cur = None
    /\ agent' = "checked"
    /\ UNCHANGED <<now, cur, lastSave, entry, up, stolen, crashes>>

\* The tool creates its entry and starts the timer. Atomic, it starts only
\* while no timer runs, and otherwise leaves its entry stopped where it
\* began; otherwise it replaces whatever runs by now.
AgentStart(e) ==
    /\ up
    /\ agent = "checked"
    /\ ~entry[e].made
    /\ agent' = "idle"
    /\ IF AgentStartAtomic /\ cur # None
       THEN /\ entry' = [entry EXCEPT ![e] =
                           [NoEntry EXCEPT !.made = TRUE, !.end = now,
                                           !.stopped = TRUE, !.stopAt = now]]
            /\ UNCHANGED <<cur, lastSave, stolen>>
       ELSE /\ stolen' = (stolen \/ cur # None)
            /\ cur' = e
            /\ lastSave' = now
            /\ entry' = [x \in Entries |->
                           IF x = e
                           THEN [NoEntry EXCEPT !.made = TRUE, !.end = now]
                           ELSE IF x = cur
                           THEN [entry[x] EXCEPT !.stopped = TRUE,
                                                 !.stopAt = now, !.end = now]
                           ELSE entry[x]]
    /\ UNCHANGED <<now, up, crashes>>

Next ==
    \/ Tick
    \/ Autosave
    \/ \E e \in Entries : UserStart(e)
    \/ \E p \in StopPaths : UserStop(p)
    \/ Close
    \/ Crash
    \/ Restart
    \/ AgentCheck
    \/ \E e \in Entries : AgentStart(e)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
TypeOK ==
    /\ now \in 0..MaxTime
    /\ cur \in Entries \cup {None}
    /\ \A e \in Entries : entry[e].end \in 0..MaxTime
    /\ agent \in {"idle", "checked"}
    /\ crashes \in 0..MaxCrashes

\* A timer that was stopped — by the user, by a new timer, by quitting —
\* has its entry ending when it stopped: no tracked time is dropped.
NoLostTime ==
    \A e \in Entries : entry[e].stopped => entry[e].end = entry[e].stopAt

\* A timer lost to a crash keeps all but the last autosave interval.
CrashLossBounded ==
    \A e \in Entries :
        entry[e].crashed => entry[e].crashAt - entry[e].end <= Interval

\* The agent never stops a timer the user started after it checked.
NoStolenTimer == ~stolen
=============================================================================

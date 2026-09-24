-------------------------- MODULE AgentStateWrites --------------------------
(***************************************************************************)
(* One agent's state row on one device, and the writers that share it: a  *)
(* wake that records its outcome when it ends, and the report-freshness    *)
(* watermarks that subscription events and finished refreshes move while   *)
(* the wake runs. A wake is single-flight per agent (WakeRuntime.tla), so  *)
(* at most one is in progress; the watermark writers run beside it.        *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   StartWake  the wake reads its state: TaskAgentWorkflow.execute's      *)
(*              reconciledAgentState, kept for the whole wake              *)
(*   Event      WakeBatchRouter._persistReportStale through                *)
(*              AgentSyncService.updateAgentState: reportStaleAt := max    *)
(*   EndWake    the outcome: WakeOutputWriter.persist on success (failure  *)
(*              count reset, wakeCounter bumped, lastWakeAt), the          *)
(*              workflow's catch block on failure (failure count bumped)   *)
(*   MarkFresh  WakeDrainEngine._persistReportFresh after a successful     *)
(*              run: reportFreshAt := max(it, the run's start)             *)
(*                                                                         *)
(* `TransformWrites` is the fix of ADR 0068: the outcome is a transform of *)
(* the row as it is when the wake ends (updateAgentState), not a copy of   *)
(* the row the wake started from. FALSE restores the old writers.         *)
(***************************************************************************)
EXTENDS Naturals

CONSTANTS MaxWakes, MaxEvents, TransformWrites
ASSUME TransformWrites \in BOOLEAN

VARIABLES
    row,        \* the persisted fields: stale, fresh, fails, wakes
    snap,       \* the row the running wake read when it started
    running,    \* is a wake in progress?
    startedAt,  \* when the running (or last) wake started
    t,          \* a logical clock: every event and wake start ticks it
    wakes,      \* wakes started
    events,     \* ghost: events recorded
    lastEvent,  \* ghost: the newest event's instant
    successes,  \* ghost: wakes that succeeded
    streak,     \* ghost: failures since the last success
    toMark      \* a successful run whose refresh start is still to persist

vars == <<row, snap, running, startedAt, t, wakes, events, lastEvent,
          successes, streak, toMark>>

Row0 == [stale |-> 0, fresh |-> 0, fails |-> 0, wakes |-> 0]
Max(a, b) == IF a > b THEN a ELSE b

Init ==
    /\ row = Row0
    /\ snap = Row0
    /\ running = FALSE
    /\ startedAt = 0
    /\ t = 1
    /\ wakes = 0
    /\ events = 0
    /\ lastEvent = 0
    /\ successes = 0
    /\ streak = 0
    /\ toMark = FALSE

StartWake ==
    /\ ~running /\ ~toMark
    /\ wakes < MaxWakes
    /\ running' = TRUE
    /\ snap' = row
    /\ startedAt' = t
    /\ t' = t + 1
    /\ wakes' = wakes + 1
    /\ UNCHANGED <<row, events, lastEvent, successes, streak, toMark>>

\* A subscription event after the report was written marks it stale.
Event ==
    /\ events < MaxEvents
    /\ row' = [row EXCEPT !.stale = Max(@, t)]
    /\ lastEvent' = t
    /\ t' = t + 1
    /\ events' = events + 1
    /\ UNCHANGED <<snap, running, startedAt, wakes, successes, streak, toMark>>

\* The outcome write: over the row the wake started from (old), or over the
\* row as it is now (fixed).
EndWake(ok) ==
    /\ running
    /\ LET base == IF TransformWrites THEN row ELSE snap
       IN row' = [base EXCEPT !.fails = IF ok THEN 0 ELSE @ + 1,
                              !.wakes = IF ok THEN @ + 1 ELSE @]
    /\ running' = FALSE
    /\ successes' = IF ok THEN successes + 1 ELSE successes
    /\ streak' = IF ok THEN 0 ELSE streak + 1
    /\ toMark' = ok
    /\ UNCHANGED <<snap, startedAt, t, wakes, events, lastEvent>>

MarkFresh ==
    /\ toMark
    /\ row' = [row EXCEPT !.fresh = Max(@, startedAt)]
    /\ toMark' = FALSE
    /\ UNCHANGED <<snap, running, startedAt, t, wakes, events, lastEvent,
                    successes, streak>>

Next == StartWake \/ Event \/ EndWake(TRUE) \/ EndWake(FALSE) \/ MarkFresh

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ row \in [stale : Nat, fresh : Nat, fails : Nat, wakes : Nat]
    /\ running \in BOOLEAN

\* Every recorded event survives in the stale watermark...
NoLostWatermark == row.stale = lastEvent

\* ...so a report refreshed before the newest event never reads as fresh.
FreshIsHonest == lastEvent > row.fresh => row.stale > row.fresh

\* The failure streak and the wake counter count what actually happened.
FailureStreakExact == row.fails = streak
NoLostWake == row.wakes = successes
=============================================================================

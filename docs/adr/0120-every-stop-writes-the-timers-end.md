# ADR 0120: Every Stop Writes the Timer's End

- Status: Accepted
- Date: 2026-10-04

## Context

A running timer lives in memory (`TimeService`); its entry's stored `dateTo`
is the time a task's tracked time adds up to, here and on every other device.
The autosave writes the end every five minutes, and a new timer writes the
end of the one it replaces. Stopping did not: `TimeService.stop` only cleared
memory. The entry page's stop button wrote the end through
`EntryController.save` before calling it, but the desktop sidebar's stop
button, a profile switch (`ProfileSwitcher._quiesce`) and quitting the app
did not, so each lost the time since the last autosave — up to five minutes
per stop. A comment in `task_action_bar.dart` already explained why calling
`stop` directly was wrong; the sidebar still did.

The task agent's time-entry tool checked that no timer ran, then read the
task, minted the entry's metadata and wrote it, and only then started its
timer. A timer the user started in between was finalised and replaced. The
tool's comment claimed Dart's event loop made the check and the start atomic;
the three awaits between them do not.

We modelled the timer in `specs/tla/RunningTimer.tla`. TLC found each in five
states: the sidebar's stop (`NoLostTime`), a quit (`NoLostTime`), and the
tool's start replacing the user's timer (`NoStolenTimer`).

## Decision

- **`TimeService.stop` writes the end.** It persists the running entry's
  end through the injected `persistRunningTimerEnd` — on the stored row,
  with the editor's draft — before it returns. A caller that has written the
  end itself (the entry page's save) or whose entry is deleted passes
  `persistEnd: false`. A failed write is logged; the timer stops all the same.
- **Shutdown stops the timer first.** `ServiceDisposer`'s first step is
  `TimeService.stop`, while the journal and the outbox are open; quitting and
  a profile switch both run it, so `_quiesce` no longer stops the timer
  itself.
- **The agent starts only an idle timer.** `TimeService.startIfIdle` checks
  and starts with nothing awaited between; `TimeEntryHandler` uses it and,
  finding a timer running, reports its entry saved but not started.
- **The ticker is a `Timer`.** The one-second ticker was a `Stream.periodic`
  subscription whose cancellation completed on the root zone; a `Timer`
  cancels synchronously, which keeps `stop` awaitable under fake time.

## Consequences

- No way of stopping a timer loses tracked time; a crash still loses up to
  one autosave interval, and a timer still does not resume after a restart.
- Quitting with a timer running stops it, ending its entry at the quit.
- The agent's tool can leave a zero-length entry when the user's timer won
  the race; it says so in its result.

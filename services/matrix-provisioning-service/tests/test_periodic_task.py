"""Tests for the shared background-loop lifecycle.

Both long-running jobs in the service are built on this, so a bug here stops
redemption detection *and* retention at once — silently, because a dead task
raises nothing that anybody sees.
"""

from __future__ import annotations

import asyncio

import pytest

from src.services.periodic_task import PeriodicTask

pytestmark = pytest.mark.anyio


class _Counter(PeriodicTask):
    """A loop that records its runs and can be told to fail."""

    def __init__(self, *, fail: bool = False, **kwargs) -> None:
        kwargs.setdefault("name", "Test loop")
        kwargs.setdefault("interval_seconds", 0)
        super().__init__(**kwargs)
        self.runs = 0
        self.reached = asyncio.Event()
        self._fail = fail

    async def run_once(self) -> None:
        self.runs += 1
        if self.runs >= 2:
            self.reached.set()
        if self._fail:
            raise RuntimeError("boom")


async def test_the_base_class_refuses_to_run_without_a_body():
    """A subclass that forgets run_once must fail loudly, not loop doing nothing."""
    with pytest.raises(NotImplementedError):
        await PeriodicTask(name="Bare", interval_seconds=0).run_once()


async def test_the_loop_keeps_running_until_stopped():
    task = _Counter()

    task.start()
    await asyncio.wait_for(task.reached.wait(), timeout=2)
    await task.stop()

    assert task.runs >= 2


async def test_a_failing_run_does_not_kill_the_loop():
    task = _Counter(fail=True)

    task.start()
    await asyncio.wait_for(task.reached.wait(), timeout=2)
    await task.stop()

    assert task.runs >= 2


async def test_cancellation_during_a_run_unwinds_instead_of_hanging():
    """The catch-all must not swallow CancelledError, or shutdown never returns."""
    entered = asyncio.Event()

    class _Blocking(PeriodicTask):
        async def run_once(self) -> None:
            entered.set()
            await asyncio.sleep(3600)

    task = _Blocking(name="Blocking", interval_seconds=0)
    task.start()
    await asyncio.wait_for(entered.wait(), timeout=2)

    await asyncio.wait_for(task.stop(), timeout=2)

    assert task._task is None


async def test_the_first_run_waits_out_the_startup_delay():
    """Destructive work must not fire the instant a bad deploy comes up."""
    task = _Counter(startup_delay_seconds=3600)

    task.start()
    await asyncio.sleep(0)
    await task.stop()

    assert task.runs == 0


async def test_start_is_idempotent():
    task = _Counter(interval_seconds=3600)

    task.start()
    first = task._task
    task.start()

    assert task._task is first
    await task.stop()


async def test_stopping_a_task_that_never_started_is_harmless():
    await _Counter().stop()

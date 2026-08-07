"""Shared lifecycle for the service's background loops.

The redemption poller and the retention sweep are the same machine with
different bodies: start a task, run work on an interval, survive any failure,
and unwind cleanly on shutdown. That machine lives here so a fix to it — the
cancellation handling in particular, which is easy to get subtly wrong — applies
to both rather than to whichever copy someone happened to edit.
"""

from __future__ import annotations

import asyncio
import logging

logger = logging.getLogger(__name__)


class PeriodicTask:
    """A cancellable loop that runs :meth:`run_once` on a fixed interval."""

    def __init__(
        self,
        *,
        name: str,
        interval_seconds: float,
        startup_delay_seconds: float = 0.0,
    ) -> None:
        """Configure the loop.

        Args:
            name: Human-readable label for the lifecycle log lines.
            interval_seconds: Delay between runs.
            startup_delay_seconds: Delay before the *first* run. Non-zero for
                destructive work, so a bad deploy can be stopped before it acts.
        """
        self._name = name
        self._interval_seconds = interval_seconds
        self._startup_delay_seconds = startup_delay_seconds
        self._task: asyncio.Task | None = None

    async def run_once(self) -> None:
        """Do one unit of work. Subclasses implement this."""
        raise NotImplementedError

    async def _run(self) -> None:
        if self._startup_delay_seconds:
            await asyncio.sleep(self._startup_delay_seconds)
        while True:
            try:
                await self.run_once()
            except asyncio.CancelledError:
                # Re-raised rather than swallowed by the catch-all below, or
                # shutdown would hang waiting for a loop that ignored it.
                raise
            except Exception:  # noqa: BLE001 - the loop must survive any run
                logger.exception("%s failed", self._name)
            await asyncio.sleep(self._interval_seconds)

    def start(self) -> None:
        """Start the loop. Idempotent while a previous run is still alive."""
        if self._task is not None and not self._task.done():
            return
        self._task = asyncio.create_task(self._run())
        logger.info(
            "%s started (every %.0fs, first run in %.0fs)",
            self._name,
            self._interval_seconds,
            self._startup_delay_seconds,
        )

    async def stop(self) -> None:
        """Cancel the loop and wait for it to unwind."""
        if self._task is None:
            return
        self._task.cancel()
        try:
            await self._task
        except asyncio.CancelledError:
            pass
        self._task = None
        logger.info("%s stopped", self._name)

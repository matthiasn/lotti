"""Background sweep that applies retention on a schedule.

Without this, retention is a button an admin has to remember to press, and disk
grows until someone notices. The sweep runs ``RetentionService.purge_all``,
which resolves each user's own window before falling back to the service
default and skips anyone marked exempt.

Enabled by default. It deletes data, so two guardrails are deliberate: the
service-wide minimum retention still applies to every resolved window, and the
first sweep is delayed rather than run at startup, so a misconfigured deploy can
be stopped before it acts.
"""

from __future__ import annotations

import asyncio
import logging

from ..core.constants import (
    DEFAULT_RETENTION_SWEEP_HOURS,
    RETENTION_SWEEP_STARTUP_DELAY_SECONDS,
)
from .retention_service import RetentionService

logger = logging.getLogger(__name__)


class RetentionScheduler:
    """Runs the retention sweep on a fixed interval."""

    def __init__(
        self,
        retention_service: RetentionService,
        *,
        interval_hours: float = DEFAULT_RETENTION_SWEEP_HOURS,
        startup_delay_seconds: float = RETENTION_SWEEP_STARTUP_DELAY_SECONDS,
        include_media: bool = True,
    ) -> None:
        self._retention_service = retention_service
        self._interval_seconds = interval_hours * 3600
        self._startup_delay_seconds = startup_delay_seconds
        self._include_media = include_media
        self._task: asyncio.Task | None = None

    async def sweep_once(self) -> dict:
        """Run one sweep.

        Returns:
            A summary with the number of users purged and bytes reclaimed.
        """
        results = await self._retention_service.purge_all(
            include_media=self._include_media
        )
        return {
            "purged": len(results),
            "bytes_freed": sum(r["bytes_freed"] for r in results),
            "media_deleted": sum(r["media_deleted"] for r in results),
        }

    async def _run(self) -> None:
        # Deliberate: a destructive job should not fire the instant the process
        # comes up, so a bad deploy can be rolled back before it deletes.
        await asyncio.sleep(self._startup_delay_seconds)
        while True:
            try:
                summary = await self.sweep_once()
                logger.info(
                    "Retention sweep complete: %s user(s), %s bytes reclaimed",
                    summary["purged"],
                    summary["bytes_freed"],
                )
            except asyncio.CancelledError:
                raise
            except Exception:  # noqa: BLE001 - the loop must survive any sweep
                logger.exception("Retention sweep failed")
            await asyncio.sleep(self._interval_seconds)

    def start(self) -> None:
        """Start the background sweep loop."""
        if self._task is not None and not self._task.done():
            return
        self._task = asyncio.create_task(self._run())
        logger.info(
            "Retention sweep scheduled every %.1fh (first run in %.0fs)",
            self._interval_seconds / 3600,
            self._startup_delay_seconds,
        )

    async def stop(self) -> None:
        """Stop the sweep loop and wait for it to unwind."""
        if self._task is None:
            return
        self._task.cancel()
        try:
            await self._task
        except asyncio.CancelledError:
            pass
        self._task = None
        logger.info("Retention sweep stopped")

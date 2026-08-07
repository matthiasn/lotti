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

import logging

from ..core.constants import (
    DEFAULT_RETENTION_SWEEP_HOURS,
    RETENTION_SWEEP_STARTUP_DELAY_SECONDS,
)
from .periodic_task import PeriodicTask
from .retention_service import RetentionService

logger = logging.getLogger(__name__)


class RetentionScheduler(PeriodicTask):
    """Runs the retention sweep on a fixed interval."""

    def __init__(
        self,
        retention_service: RetentionService,
        *,
        interval_hours: float = DEFAULT_RETENTION_SWEEP_HOURS,
        startup_delay_seconds: float = RETENTION_SWEEP_STARTUP_DELAY_SECONDS,
        include_media: bool = True,
    ) -> None:
        super().__init__(
            name="Retention sweep",
            interval_seconds=interval_hours * 3600,
            startup_delay_seconds=startup_delay_seconds,
        )
        self._retention_service = retention_service
        self._include_media = include_media

    async def run_once(self) -> None:
        """Run one sweep for the background loop, logging what it reclaimed."""
        summary = await self.sweep_once()
        logger.info(
            "Retention sweep complete: %s user(s), %s bytes reclaimed",
            summary["purged"],
            summary["bytes_freed"],
        )

    async def sweep_once(self) -> dict:
        """Run one sweep.

        Returns:
            A summary with the number of users purged and bytes reclaimed.
        """
        results = await self._retention_service.purge_all(include_media=self._include_media)
        return {
            "purged": len(results),
            "bytes_freed": sum(r["bytes_freed"] for r in results),
            "media_deleted": sum(r["media_deleted"] for r in results),
        }

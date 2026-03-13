"""Persistent per-request usage logging service backed by SQLite"""

import asyncio
import logging
import os
import sqlite3
from datetime import datetime, timezone, timedelta

from ..core.interfaces import IUsageLogService

logger = logging.getLogger(__name__)

DEFAULT_RETENTION_DAYS = 90


class UsageLogService(IUsageLogService):
    """SQLite-backed usage logging service"""

    def __init__(self, db_path: str | None = None) -> None:
        self._db_path = db_path or os.path.join("data", "usage_log.db")
        self._retention_days = int(
            os.getenv("USAGE_LOG_RETENTION_DAYS", str(DEFAULT_RETENTION_DAYS))
        )
        self._init_db()
        # Schedule cleanup in a background thread to avoid blocking startup
        # on large databases
        import threading

        threading.Thread(
            target=self._cleanup_old_entries, daemon=True
        ).start()

    def _get_connection(self) -> sqlite3.Connection:
        """Create a new SQLite connection"""
        conn = sqlite3.connect(self._db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self) -> None:
        """Initialize the database schema"""
        os.makedirs(os.path.dirname(self._db_path) or ".", exist_ok=True)
        conn = self._get_connection()
        try:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS usage_log (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    model TEXT NOT NULL,
                    prompt_tokens INTEGER NOT NULL,
                    completion_tokens INTEGER NOT NULL,
                    total_tokens INTEGER NOT NULL,
                    cost_usd REAL NOT NULL,
                    request_id TEXT NOT NULL,
                    created_at TEXT NOT NULL
                )
                """
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_usage_log_user_id ON usage_log(user_id)"
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_usage_log_created_at ON usage_log(created_at)"
            )
            conn.commit()
        finally:
            conn.close()

    def _cleanup_old_entries(self) -> None:
        """Delete entries older than retention period"""
        cutoff = datetime.now(timezone.utc) - timedelta(days=self._retention_days)
        cutoff_str = cutoff.isoformat()
        conn = self._get_connection()
        try:
            cursor = conn.execute(
                "DELETE FROM usage_log WHERE created_at < ?", (cutoff_str,)
            )
            deleted = cursor.rowcount
            conn.commit()
            if deleted > 0:
                logger.info(
                    f"Cleaned up {deleted} usage log entries older than {self._retention_days} days"
                )
        finally:
            conn.close()

    def _log_usage_sync(
        self,
        user_id: str,
        model: str,
        prompt_tokens: int,
        completion_tokens: int,
        total_tokens: int,
        cost_usd: float,
        request_id: str,
    ) -> None:
        """Synchronous insert for use with asyncio.to_thread"""
        created_at = datetime.now(timezone.utc).isoformat()
        conn = self._get_connection()
        try:
            conn.execute(
                """
                INSERT INTO usage_log
                    (user_id, model, prompt_tokens, completion_tokens, total_tokens, cost_usd, request_id, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    user_id,
                    model,
                    prompt_tokens,
                    completion_tokens,
                    total_tokens,
                    cost_usd,
                    request_id,
                    created_at,
                ),
            )
            conn.commit()
        finally:
            conn.close()

    async def log_usage(
        self,
        user_id: str,
        model: str,
        prompt_tokens: int,
        completion_tokens: int,
        total_tokens: int,
        cost_usd: float,
        request_id: str,
    ) -> None:
        """Log a usage entry"""
        await asyncio.to_thread(
            self._log_usage_sync,
            user_id,
            model,
            prompt_tokens,
            completion_tokens,
            total_tokens,
            cost_usd,
            request_id,
        )

    def _get_user_usage_sync(
        self, user_id: str, page: int, page_size: int
    ) -> tuple[list[dict], int]:
        """Synchronous paginated query"""
        conn = self._get_connection()
        try:
            row = conn.execute(
                "SELECT COUNT(*) as cnt FROM usage_log WHERE user_id = ?",
                (user_id,),
            ).fetchone()
            total = row["cnt"]

            offset = (page - 1) * page_size
            rows = conn.execute(
                """
                SELECT id, user_id, model, prompt_tokens, completion_tokens,
                       total_tokens, cost_usd, request_id, created_at
                FROM usage_log
                WHERE user_id = ?
                ORDER BY created_at DESC
                LIMIT ? OFFSET ?
                """,
                (user_id, page_size, offset),
            ).fetchall()

            entries = [dict(r) for r in rows]
            return entries, total
        finally:
            conn.close()

    async def get_user_usage(
        self, user_id: str, page: int = 1, page_size: int = 20
    ) -> tuple[list[dict], int]:
        """Get usage entries for a user. Returns (entries, total_count)."""
        return await asyncio.to_thread(
            self._get_user_usage_sync, user_id, page, page_size
        )

    def _get_summary_sync(self, user_id: str | None = None) -> dict:
        """Synchronous summary query, optionally filtered by user_id"""
        conn = self._get_connection()
        try:
            where_clause = "WHERE user_id = ?" if user_id else ""
            params: tuple = (user_id,) if user_id else ()

            row = conn.execute(
                f"""
                SELECT
                    COUNT(*) as total_requests,
                    COALESCE(SUM(prompt_tokens), 0) as total_prompt_tokens,
                    COALESCE(SUM(completion_tokens), 0) as total_completion_tokens,
                    COALESCE(SUM(total_tokens), 0) as total_tokens,
                    COALESCE(SUM(cost_usd), 0.0) as total_cost_usd
                FROM usage_log
                {where_clause}
                """,
                params,
            ).fetchone()

            by_model_rows = conn.execute(
                f"""
                SELECT
                    model,
                    COUNT(*) as requests,
                    SUM(prompt_tokens) as prompt_tokens,
                    SUM(completion_tokens) as completion_tokens,
                    SUM(total_tokens) as total_tokens,
                    SUM(cost_usd) as cost_usd
                FROM usage_log
                {where_clause}
                GROUP BY model
                """,
                params,
            ).fetchall()

            by_model = {}
            for mr in by_model_rows:
                by_model[mr["model"]] = {
                    "requests": mr["requests"],
                    "prompt_tokens": mr["prompt_tokens"],
                    "completion_tokens": mr["completion_tokens"],
                    "total_tokens": mr["total_tokens"],
                    "cost_usd": mr["cost_usd"],
                }

            return {
                "total_requests": row["total_requests"],
                "total_prompt_tokens": row["total_prompt_tokens"],
                "total_completion_tokens": row["total_completion_tokens"],
                "total_tokens": row["total_tokens"],
                "total_cost_usd": row["total_cost_usd"],
                "by_model": by_model,
            }
        finally:
            conn.close()

    async def get_user_summary(self, user_id: str) -> dict:
        """Get usage summary for a user."""
        return await asyncio.to_thread(self._get_summary_sync, user_id)

    async def get_system_summary(self) -> dict:
        """Get system-wide usage summary."""
        return await asyncio.to_thread(self._get_summary_sync)

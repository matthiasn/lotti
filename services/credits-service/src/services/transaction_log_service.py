"""Transaction log service backed by SQLite"""

from __future__ import annotations

import asyncio
import logging
import os
import sqlite3
from datetime import datetime, timezone
from decimal import Decimal

from ..core.interfaces import ITransactionLogService
from ..core.money import microcents_to_usd, usd_to_microcents

logger = logging.getLogger(__name__)


class TransactionLogService(ITransactionLogService):
    """SQLite-backed transaction log for recording user transactions"""

    def __init__(self, db_path: str = "data/transaction_log.db"):
        self.db_path = db_path
        self._has_legacy_cent_columns = False
        self._ensure_db()

    def _ensure_db(self) -> None:
        """Create database and table if they don't exist"""
        os.makedirs(os.path.dirname(self.db_path) or ".", exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        try:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS transactions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    type TEXT NOT NULL,
                    amount_microcents INTEGER,
                    description TEXT,
                    balance_after_microcents INTEGER,
                    created_at TEXT NOT NULL
                )
            """)
            columns = {
                row[1] for row in conn.execute("PRAGMA table_info(transactions)").fetchall()
            }
            self._has_legacy_cent_columns = {
                "amount_cents",
                "balance_after_cents",
            }.issubset(columns)
            if "amount_microcents" not in columns:
                conn.execute("ALTER TABLE transactions ADD COLUMN amount_microcents INTEGER")
            if "balance_after_microcents" not in columns:
                conn.execute("ALTER TABLE transactions ADD COLUMN balance_after_microcents INTEGER")
            if "amount_cents" in columns:
                conn.execute(
                    """
                    UPDATE transactions
                    SET amount_microcents = amount_cents * 1000000
                    WHERE amount_microcents IS NULL
                    """,
                )
            if "balance_after_cents" in columns:
                conn.execute(
                    """
                    UPDATE transactions
                    SET balance_after_microcents = balance_after_cents * 1000000
                    WHERE balance_after_microcents IS NULL
                    """,
                )
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_transactions_user_id
                ON transactions (user_id)
            """)
            conn.commit()
        finally:
            conn.close()

    def _log_transaction_sync(
        self,
        user_id: str,
        tx_type: str,
        amount: Decimal,
        balance_after: Decimal,
        description: str | None,
    ) -> None:
        amount_microcents = usd_to_microcents(amount)
        balance_after_microcents = usd_to_microcents(balance_after)
        conn = sqlite3.connect(self.db_path)
        try:
            conn.execute(
                """INSERT INTO transactions
                   (user_id, type, amount_microcents, description, balance_after_microcents, created_at)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (
                    user_id,
                    tx_type,
                    amount_microcents,
                    description,
                    balance_after_microcents,
                    datetime.now(timezone.utc).isoformat(),
                ),
            )
            conn.commit()
        finally:
            conn.close()

    async def log_transaction(
        self,
        user_id: str,
        tx_type: str,
        amount: Decimal,
        balance_after: Decimal,
        description: str | None = None,
    ) -> None:
        """Log a transaction"""
        await asyncio.to_thread(
            self._log_transaction_sync, user_id, tx_type, amount, balance_after, description
        )

    def _get_transactions_sync(
        self, user_id: str, page: int, page_size: int
    ) -> tuple[list[dict], int]:
        page = max(1, page)
        page_size = max(1, min(100, page_size))
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            total = conn.execute(
                "SELECT COUNT(*) FROM transactions WHERE user_id = ?", (user_id,)
            ).fetchone()[0]
            offset = (page - 1) * page_size
            amount_expression = "amount_microcents"
            balance_expression = "balance_after_microcents"
            if self._has_legacy_cent_columns:
                amount_expression = "COALESCE(amount_microcents, amount_cents * 1000000)"
                balance_expression = (
                    "COALESCE(balance_after_microcents, balance_after_cents * 1000000)"
                )
            rows = conn.execute(
                f"""
                SELECT
                    id,
                    user_id,
                    type,
                    description,
                    created_at,
                    {amount_expression} AS amount_microcents,
                    {balance_expression} AS balance_after_microcents
                FROM transactions
                WHERE user_id = ?
                ORDER BY id DESC
                LIMIT ? OFFSET ?
                """,
                (user_id, page_size, offset),
            ).fetchall()
            result = []
            for row in rows:
                d = dict(row)
                d["amount"] = microcents_to_usd(d.pop("amount_microcents"))
                d["balance_after"] = microcents_to_usd(
                    d.pop("balance_after_microcents"),
                )
                result.append(d)
            return result, total
        finally:
            conn.close()

    async def get_transactions(
        self, user_id: str, page: int = 1, page_size: int = 20
    ) -> tuple[list[dict], int]:
        """Get transactions for a user with pagination"""
        return await asyncio.to_thread(self._get_transactions_sync, user_id, page, page_size)

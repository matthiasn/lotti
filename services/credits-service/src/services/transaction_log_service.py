"""Transaction log service backed by SQLite"""

from __future__ import annotations

import asyncio
import logging
import os
import sqlite3
from datetime import datetime, timezone
from decimal import Decimal

from ..core.constants import CURRENCY_PRECISION
from ..core.interfaces import ITransactionLogService

logger = logging.getLogger(__name__)


class TransactionLogService(ITransactionLogService):
    """SQLite-backed transaction log for recording user transactions"""

    def __init__(self, db_path: str = "data/transaction_log.db"):
        self.db_path = db_path
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
                    amount_cents INTEGER NOT NULL,
                    description TEXT,
                    balance_after_cents INTEGER NOT NULL,
                    created_at TEXT NOT NULL
                )
            """)
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
        amount_cents = int(amount * CURRENCY_PRECISION)
        balance_after_cents = int(balance_after * CURRENCY_PRECISION)
        conn = sqlite3.connect(self.db_path)
        try:
            conn.execute(
                """INSERT INTO transactions
                   (user_id, type, amount_cents, description, balance_after_cents, created_at)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (
                    user_id,
                    tx_type,
                    amount_cents,
                    description,
                    balance_after_cents,
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
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            total = conn.execute(
                "SELECT COUNT(*) FROM transactions WHERE user_id = ?", (user_id,)
            ).fetchone()[0]
            offset = (page - 1) * page_size
            rows = conn.execute(
                "SELECT * FROM transactions WHERE user_id = ? ORDER BY id DESC LIMIT ? OFFSET ?",
                (user_id, page_size, offset),
            ).fetchall()
            result = []
            for row in rows:
                d = dict(row)
                d["amount"] = Decimal(d.pop("amount_cents")) / CURRENCY_PRECISION
                d["balance_after"] = Decimal(d.pop("balance_after_cents")) / CURRENCY_PRECISION
                result.append(d)
            return result, total
        finally:
            conn.close()

    async def get_transactions(
        self, user_id: str, page: int = 1, page_size: int = 20
    ) -> tuple[list[dict], int]:
        """Get transactions for a user with pagination"""
        return await asyncio.to_thread(self._get_transactions_sync, user_id, page, page_size)

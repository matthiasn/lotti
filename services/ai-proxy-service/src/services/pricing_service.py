"""Model pricing management service backed by SQLite"""

import asyncio
import logging
import os
import sqlite3
from datetime import datetime, timezone

from ..core.constants import (
    DEFAULT_MODEL_PRICING,
    MODEL_MAPPINGS,
    MODEL_PRICING,
)
from ..core.interfaces import IPricingService

logger = logging.getLogger(__name__)


class PricingService(IPricingService):
    """SQLite-backed pricing management service with in-memory cache"""

    def __init__(self, db_path: str | None = None) -> None:
        self._db_path = db_path or os.path.join("data", "pricing.db")
        self._cache: dict[str, dict] = {}
        self._init_db()
        self._seed_data()
        self._refresh_cache()

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
                CREATE TABLE IF NOT EXISTS model_pricing (
                    model_id TEXT PRIMARY KEY,
                    display_name TEXT,
                    input_price_per_1k REAL NOT NULL,
                    output_price_per_1k REAL NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """
            )
            conn.commit()
        finally:
            conn.close()

    def _seed_data(self) -> None:
        """Seed pricing from constants (INSERT OR IGNORE to preserve existing data)"""
        now = datetime.now(timezone.utc).isoformat()
        conn = self._get_connection()
        try:
            for model_id, pricing in MODEL_PRICING.items():
                conn.execute(
                    """
                    INSERT OR IGNORE INTO model_pricing
                        (model_id, display_name, input_price_per_1k, output_price_per_1k, updated_at)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    (
                        model_id,
                        model_id,
                        pricing["input_price_per_1k"],
                        pricing["output_price_per_1k"],
                        now,
                    ),
                )
            conn.commit()
        finally:
            conn.close()

    def _refresh_cache(self) -> None:
        """Refresh the in-memory pricing cache from the database.

        Builds a new dict and assigns it atomically to avoid partial reads
        from concurrent threads.
        """
        conn = self._get_connection()
        try:
            rows = conn.execute(
                "SELECT model_id, display_name, input_price_per_1k, output_price_per_1k, updated_at FROM model_pricing"
            ).fetchall()
            new_cache = {
                row["model_id"]: {
                    "model_id": row["model_id"],
                    "display_name": row["display_name"],
                    "input_price_per_1k": row["input_price_per_1k"],
                    "output_price_per_1k": row["output_price_per_1k"],
                    "updated_at": row["updated_at"],
                }
                for row in rows
            }
            # Atomic reference swap — safe for concurrent readers
            self._cache = new_cache
        finally:
            conn.close()

    def _get_all_pricing_sync(self) -> list[dict]:
        """Synchronous get all pricing"""
        conn = self._get_connection()
        try:
            rows = conn.execute(
                "SELECT model_id, display_name, input_price_per_1k, output_price_per_1k, updated_at FROM model_pricing ORDER BY model_id"
            ).fetchall()
            return [dict(r) for r in rows]
        finally:
            conn.close()

    async def get_all_pricing(self) -> list[dict]:
        """Get all model pricing entries"""
        return await asyncio.to_thread(self._get_all_pricing_sync)

    def _get_pricing_sync(self, model_id: str) -> dict | None:
        """Synchronous get pricing for a model"""
        conn = self._get_connection()
        try:
            row = conn.execute(
                "SELECT model_id, display_name, input_price_per_1k, output_price_per_1k, updated_at FROM model_pricing WHERE model_id = ?",
                (model_id,),
            ).fetchone()
            return dict(row) if row else None
        finally:
            conn.close()

    async def get_pricing(self, model_id: str) -> dict | None:
        """Get pricing for a specific model"""
        return await asyncio.to_thread(self._get_pricing_sync, model_id)

    def _update_pricing_sync(
        self,
        model_id: str,
        display_name: str | None,
        input_price: float,
        output_price: float,
    ) -> dict:
        """Synchronous update pricing"""
        now = datetime.now(timezone.utc).isoformat()
        conn = self._get_connection()
        try:
            conn.execute(
                """
                UPDATE model_pricing
                SET display_name = ?, input_price_per_1k = ?, output_price_per_1k = ?, updated_at = ?
                WHERE model_id = ?
                """,
                (display_name, input_price, output_price, now, model_id),
            )
            conn.commit()
            row = conn.execute(
                "SELECT model_id, display_name, input_price_per_1k, output_price_per_1k, updated_at "
                "FROM model_pricing WHERE model_id = ?",
                (model_id,),
            ).fetchone()
            if row is None:
                raise ValueError(f"Model '{model_id}' not found after update")
            result = dict(row)
            self._refresh_cache()
            return result
        finally:
            conn.close()

    async def update_pricing(
        self,
        model_id: str,
        display_name: str | None,
        input_price: float,
        output_price: float,
    ) -> dict:
        """Update pricing for a model"""
        return await asyncio.to_thread(
            self._update_pricing_sync, model_id, display_name, input_price, output_price
        )

    def _create_pricing_sync(
        self,
        model_id: str,
        display_name: str | None,
        input_price: float,
        output_price: float,
    ) -> dict:
        """Synchronous create pricing"""
        now = datetime.now(timezone.utc).isoformat()
        conn = self._get_connection()
        try:
            conn.execute(
                """
                INSERT INTO model_pricing
                    (model_id, display_name, input_price_per_1k, output_price_per_1k, updated_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                (model_id, display_name, input_price, output_price, now),
            )
            conn.commit()
            row = conn.execute(
                "SELECT model_id, display_name, input_price_per_1k, output_price_per_1k, updated_at "
                "FROM model_pricing WHERE model_id = ?",
                (model_id,),
            ).fetchone()
            if row is None:
                raise ValueError(f"Model '{model_id}' not found after insert")
            result = dict(row)
            self._refresh_cache()
            return result
        finally:
            conn.close()

    async def create_pricing(
        self,
        model_id: str,
        display_name: str | None,
        input_price: float,
        output_price: float,
    ) -> dict:
        """Create new model pricing"""
        return await asyncio.to_thread(
            self._create_pricing_sync, model_id, display_name, input_price, output_price
        )

    def get_pricing_for_model_sync(self, model: str) -> dict:
        """Get pricing dict for billing (synchronous, cached).

        Resolves model mappings (e.g. gpt-4 -> gemini-2.5-pro) and falls
        back to DEFAULT_MODEL_PRICING for unknown models.
        """
        # Resolve OpenAI-style model names
        mapped_model = MODEL_MAPPINGS.get(model, model)

        if mapped_model in self._cache:
            entry = self._cache[mapped_model]
            return {
                "input_price_per_1k": entry["input_price_per_1k"],
                "output_price_per_1k": entry["output_price_per_1k"],
            }

        # Fall back to default pricing
        return dict(DEFAULT_MODEL_PRICING)

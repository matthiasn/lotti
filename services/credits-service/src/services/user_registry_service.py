"""User registry service backed by SQLite"""

from __future__ import annotations

import asyncio
import logging
import os
import sqlite3
from datetime import datetime, timezone

from ..core.interfaces import IUserRegistryService

logger = logging.getLogger(__name__)


class UserRegistryService(IUserRegistryService):
    """SQLite-backed user registry for mapping user IDs to metadata"""

    def __init__(self, db_path: str = "data/user_registry.db"):
        self.db_path = db_path
        self._ensure_db()

    def _ensure_db(self) -> None:
        """Create database and table if they don't exist"""
        os.makedirs(os.path.dirname(self.db_path) or ".", exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        try:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    user_id TEXT PRIMARY KEY,
                    display_name TEXT,
                    created_at TEXT NOT NULL
                )
            """)
            conn.commit()
        finally:
            conn.close()

    def _register_user_sync(self, user_id: str, display_name: str | None = None) -> None:
        conn = sqlite3.connect(self.db_path)
        try:
            conn.execute(
                "INSERT OR IGNORE INTO users (user_id, display_name, created_at) VALUES (?, ?, ?)",
                (user_id, display_name, datetime.now(timezone.utc).isoformat()),
            )
            conn.commit()
        finally:
            conn.close()

    async def register_user(self, user_id: str, display_name: str | None = None) -> None:
        """Register a user in the registry"""
        await asyncio.to_thread(self._register_user_sync, user_id, display_name)

    def _get_user_sync(self, user_id: str) -> dict | None:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            row = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
            return dict(row) if row else None
        finally:
            conn.close()

    async def get_user(self, user_id: str) -> dict | None:
        """Get user info by ID"""
        return await asyncio.to_thread(self._get_user_sync, user_id)

    def _list_users_sync(self, page: int, page_size: int) -> tuple[list[dict], int]:
        page = max(1, page)
        page_size = max(1, min(100, page_size))
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            total = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
            offset = (page - 1) * page_size
            rows = conn.execute(
                "SELECT * FROM users ORDER BY created_at DESC LIMIT ? OFFSET ?",
                (page_size, offset),
            ).fetchall()
            return [dict(row) for row in rows], total
        finally:
            conn.close()

    async def list_users(self, page: int = 1, page_size: int = 20) -> tuple[list[dict], int]:
        """List users with pagination"""
        return await asyncio.to_thread(self._list_users_sync, page, page_size)

    def _user_exists_sync(self, user_id: str) -> bool:
        conn = sqlite3.connect(self.db_path)
        try:
            row = conn.execute("SELECT 1 FROM users WHERE user_id = ?", (user_id,)).fetchone()
            return row is not None
        finally:
            conn.close()

    async def user_exists(self, user_id: str) -> bool:
        """Check if a user is registered"""
        return await asyncio.to_thread(self._user_exists_sync, user_id)

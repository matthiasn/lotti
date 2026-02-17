// ignore_for_file: cascade_invocations
import 'package:sqlite3/sqlite3.dart';

/// Creates the linked_entries table with the pre-v30 buggy index in a raw
/// SQLite database. Required because the v30 migration expects this table
/// to exist when it drops and recreates the index.
void createLinkedEntriesTableWithBuggyIndex(Database sqlite) {
  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS linked_entries (
      id TEXT NOT NULL UNIQUE,
      from_id TEXT NOT NULL,
      to_id TEXT NOT NULL,
      type TEXT NOT NULL,
      serialized TEXT NOT NULL,
      hidden BOOLEAN DEFAULT FALSE,
      created_at DATETIME,
      updated_at DATETIME,
      PRIMARY KEY (id),
      UNIQUE(from_id, to_id, type)
    )
  ''');
  sqlite.execute('''
    CREATE INDEX IF NOT EXISTS idx_linked_entries_to_id_hidden
      ON linked_entries(from_id COLLATE BINARY ASC, hidden COLLATE BINARY ASC)
  ''');
}

/// Creates a complete v29-style schema in a raw SQLite database, including
/// all tables, indices, and the buggy `idx_linked_entries_to_id_hidden` index
/// that the v30 migration will fix.
void createV29Schema(Database sqlite) {
  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS journal (
      id TEXT PRIMARY KEY,
      serialized TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      date_from INTEGER NOT NULL,
      date_to INTEGER NOT NULL,
      type TEXT NOT NULL,
      subtype TEXT,
      starred BOOLEAN DEFAULT FALSE,
      private BOOLEAN DEFAULT FALSE,
      deleted BOOLEAN DEFAULT FALSE,
      task BOOLEAN DEFAULT FALSE,
      task_status TEXT,
      task_priority TEXT,
      task_priority_rank INTEGER,
      category TEXT NOT NULL DEFAULT '',
      flag INTEGER DEFAULT 0,
      schema_version INTEGER DEFAULT 0,
      plain_text TEXT,
      latitude REAL,
      longitude REAL,
      geohash_string TEXT,
      geohash_int INTEGER
    )
  ''');

  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS linked_entries (
      id TEXT NOT NULL UNIQUE,
      from_id TEXT NOT NULL,
      to_id TEXT NOT NULL,
      type TEXT NOT NULL,
      serialized TEXT NOT NULL,
      hidden BOOLEAN DEFAULT FALSE,
      created_at DATETIME,
      updated_at DATETIME,
      PRIMARY KEY (id),
      UNIQUE(from_id, to_id, type)
    )
  ''');

  // Single-column indices on linked_entries
  sqlite.execute('''
    CREATE INDEX idx_linked_entries_from_id ON linked_entries (from_id)
  ''');
  sqlite.execute('''
    CREATE INDEX idx_linked_entries_to_id ON linked_entries (to_id)
  ''');
  sqlite.execute('''
    CREATE INDEX idx_linked_entries_type ON linked_entries (type)
  ''');
  sqlite.execute('''
    CREATE INDEX idx_linked_entries_hidden ON linked_entries (hidden)
  ''');

  // Composite indices — note the buggy _to_id_hidden that indexes from_id
  sqlite.execute('''
    CREATE INDEX idx_linked_entries_from_id_hidden
      ON linked_entries(from_id COLLATE BINARY ASC, hidden COLLATE BINARY ASC)
  ''');
  sqlite.execute('''
    CREATE INDEX idx_linked_entries_to_id_hidden
      ON linked_entries(from_id COLLATE BINARY ASC, hidden COLLATE BINARY ASC)
  ''');

  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS conflicts (
      id TEXT PRIMARY KEY,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,
      serialized TEXT NOT NULL,
      schema_version INTEGER NOT NULL DEFAULT 0,
      status INTEGER NOT NULL
    )
  ''');

  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS measurable_types (
      id TEXT PRIMARY KEY,
      unique_name TEXT NOT NULL UNIQUE,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,
      deleted BOOLEAN NOT NULL DEFAULT FALSE,
      private BOOLEAN NOT NULL DEFAULT FALSE,
      serialized TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 0,
      status INTEGER NOT NULL
    )
  ''');

  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS habit_definitions (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,
      deleted BOOLEAN NOT NULL DEFAULT FALSE,
      private BOOLEAN NOT NULL DEFAULT FALSE,
      serialized TEXT NOT NULL,
      active BOOLEAN NOT NULL
    )
  ''');

  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS category_definitions (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,
      deleted BOOLEAN NOT NULL DEFAULT FALSE,
      private BOOLEAN NOT NULL DEFAULT FALSE,
      serialized TEXT NOT NULL,
      active BOOLEAN NOT NULL
    )
  ''');

  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS dashboard_definitions (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,
      last_reviewed DATETIME NOT NULL,
      deleted BOOLEAN NOT NULL DEFAULT FALSE,
      private BOOLEAN NOT NULL DEFAULT FALSE,
      serialized TEXT NOT NULL,
      active BOOLEAN NOT NULL
    )
  ''');

  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS config_flags (
      name TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL UNIQUE,
      status BOOLEAN NOT NULL DEFAULT FALSE,
      PRIMARY KEY (name)
    )
  ''');

  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS tag_entities (
      id TEXT NOT NULL UNIQUE,
      tag TEXT NOT NULL,
      type TEXT NOT NULL,
      inactive BOOLEAN DEFAULT FALSE,
      private BOOLEAN NOT NULL DEFAULT FALSE,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,
      deleted BOOLEAN DEFAULT FALSE,
      serialized TEXT NOT NULL,
      PRIMARY KEY (id),
      UNIQUE(tag, type)
    )
  ''');

  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS tagged (
      id TEXT NOT NULL UNIQUE,
      journal_id TEXT NOT NULL,
      tag_entity_id TEXT NOT NULL,
      PRIMARY KEY (id),
      UNIQUE(journal_id, tag_entity_id)
    )
  ''');

  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS label_definitions (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      color TEXT NOT NULL,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,
      deleted BOOLEAN NOT NULL DEFAULT FALSE,
      private BOOLEAN NOT NULL DEFAULT FALSE,
      serialized TEXT NOT NULL
    )
  ''');

  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS labeled (
      id TEXT NOT NULL UNIQUE,
      journal_id TEXT NOT NULL,
      label_id TEXT NOT NULL,
      PRIMARY KEY (id),
      FOREIGN KEY(journal_id) REFERENCES journal(id) ON DELETE CASCADE,
      FOREIGN KEY(label_id) REFERENCES label_definitions(id) ON DELETE CASCADE,
      UNIQUE(journal_id, label_id)
    )
  ''');
}

// ignore_for_file: cascade_invocations
import 'package:sqlite3/sqlite3.dart';

/// Creates the `journal` table in a raw SQLite database at the shape it had
/// for a given schema [version].
///
/// Two distinct historical shapes exist:
///
/// * **Legacy** (`version < 29`): the pre-priority schema with a nullable
///   `category TEXT` column and no `task_priority`, `task_priority_rank`,
///   `plain_text`, `latitude`, `longitude`, `geohash_string`, or
///   `geohash_int` columns. This is what installs looked like at v25–v28
///   before the v29 priority migration added the priority columns.
/// * **Full** (`version >= 29`): the post-priority schema with the priority
///   columns, geolocation columns, and `category TEXT NOT NULL DEFAULT ''`.
///   This is the journal shape seeded by tests that exercise v32+ index
///   migrations and by [createV29Schema].
///
/// The default ([version] = 29) creates the full schema. The threshold of 29
/// matches the migration ladder, where the v29 step (`if (from < 29)`) is the
/// one that introduces `task_priority` / `task_priority_rank`.
void createJournalTable(Database sqlite, {int version = 29}) {
  if (version < 29) {
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
        category TEXT,
        flag INTEGER DEFAULT 0,
        schema_version INTEGER DEFAULT 0
      )
    ''');
    return;
  }

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
}

/// Creates the legacy (v25–v27) `tag_entities` table in a raw SQLite database.
///
/// This is the pre-v29 shape used by the labels migration tests: it has no
/// explicit `PRIMARY KEY (id)` / `UNIQUE(tag, type)` clauses and carries a
/// trailing `schema_version` column. It is intentionally distinct from the
/// v29 `tag_entities` table seeded by [createV29Schema].
void createLegacyTagEntitiesTable(Database sqlite) {
  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS tag_entities (
      id TEXT PRIMARY KEY,
      tag TEXT NOT NULL,
      type TEXT NOT NULL,
      inactive BOOLEAN DEFAULT FALSE,
      private BOOLEAN DEFAULT FALSE,
      deleted BOOLEAN DEFAULT FALSE,
      serialized TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      schema_version INTEGER DEFAULT 0
    )
  ''');
}

/// Creates the legacy (v25–v27) `label_definitions` table in a raw SQLite
/// database.
///
/// This is the pre-v29 shape used by the labels migration tests: `name` is a
/// plain `TEXT NOT NULL` (not `UNIQUE`) and a trailing `schema_version`
/// column is present. It is intentionally distinct from the v29
/// `label_definitions` table seeded by [createV29Schema].
void createLegacyLabelDefinitionsTable(Database sqlite) {
  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS label_definitions (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      color TEXT NOT NULL,
      serialized TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted BOOLEAN DEFAULT FALSE,
      private BOOLEAN DEFAULT FALSE,
      schema_version INTEGER DEFAULT 0
    )
  ''');
}

/// Creates the pre-v28 `labeled` link table in a raw SQLite database.
///
/// This is the old shape *without* `ON DELETE CASCADE` on its foreign keys,
/// used by the labels migration tests to verify that the v28 migration
/// rebuilds the table with cascading deletes.
void createLegacyLabeledTable(Database sqlite) {
  sqlite.execute('''
    CREATE TABLE IF NOT EXISTS labeled (
      id TEXT NOT NULL UNIQUE,
      journal_id TEXT NOT NULL,
      label_id TEXT NOT NULL,
      PRIMARY KEY (id),
      FOREIGN KEY(journal_id) REFERENCES journal(id),
      FOREIGN KEY(label_id) REFERENCES label_definitions(id),
      UNIQUE(journal_id, label_id)
    )
  ''');
}

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
  // version defaults to 29 — the full (priority + geohash) journal shape.
  createJournalTable(sqlite);

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

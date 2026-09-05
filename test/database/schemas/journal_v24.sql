-- JournalDb fresh-install schema at schemaVersion 24.
-- Extracted from lib/database/database.drift at 3bc19f6e3
-- by tool/db_schema/extract_journal_schema.dart. Do not edit.

CREATE TABLE journal (
  id TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  date_from DATETIME NOT NULL,
  date_to DATETIME NOT NULL,
  deleted BOOLEAN NOT NULL DEFAULT FALSE,
  starred BOOLEAN NOT NULL DEFAULT FALSE,
  private BOOLEAN NOT NULL DEFAULT FALSE,
  task BOOLEAN NOT NULL DEFAULT FALSE,
  task_status TEXT,
  flag INTEGER NOT NULL DEFAULT 0,
  type TEXT NOT NULL,
  subtype TEXT,
  serialized TEXT NOT NULL,
  schema_version INTEGER NOT NULL DEFAULT 0,
  plain_text TEXT,
  latitude REAL,
  longitude REAL,
  geohash_string TEXT,
  geohash_int INTEGER,
  category TEXT NOT NULL DEFAULT '',
  PRIMARY KEY (id)
);

CREATE INDEX idx_journal_created_at ON journal (created_at);

CREATE INDEX idx_journal_updated_at ON journal (updated_at);

CREATE INDEX idx_journal_date_from ON journal (date_from DESC);

CREATE INDEX idx_journal_date_to ON journal (date_to);

CREATE INDEX idx_journal_deleted ON journal (deleted);

CREATE INDEX idx_journal_starred ON journal (starred);

CREATE INDEX idx_journal_private ON journal (private);

CREATE INDEX idx_journal_task ON journal (task);

CREATE INDEX idx_journal_task_status ON journal (task_status);

CREATE INDEX idx_journal_flag ON journal (flag);

CREATE INDEX idx_journal_type ON journal (type);

CREATE INDEX idx_journal_subtype ON journal (subtype);

CREATE INDEX idx_journal_geohash_string ON journal (geohash_string);

CREATE INDEX idx_journal_geohash_int ON journal (geohash_int);

CREATE INDEX idx_journal_category ON journal (category);

CREATE INDEX idx_journal_composite ON journal(type COLLATE BINARY ASC, private COLLATE BINARY ASC, starred COLLATE BINARY ASC, flag COLLATE BINARY ASC, deleted COLLATE BINARY ASC, date_from COLLATE BINARY DESC);

CREATE INDEX idx_journal_habit_completions ON journal(type COLLATE BINARY ASC, subtype COLLATE BINARY ASC, deleted COLLATE BINARY ASC, private COLLATE BINARY ASC, date_from COLLATE BINARY ASC, date_from COLLATE BINARY DESC, date_to COLLATE BINARY ASC, date_to COLLATE BINARY DESC);

CREATE INDEX idx_journal_habit_completions2 ON journal(type COLLATE BINARY ASC, deleted COLLATE BINARY ASC, private COLLATE BINARY ASC, date_from COLLATE BINARY ASC, date_from COLLATE BINARY DESC, created_at COLLATE BINARY ASC);

CREATE INDEX idx_journal_linked ON journal(id COLLATE BINARY ASC, private COLLATE BINARY ASC, deleted COLLATE BINARY ASC, date_from COLLATE BINARY DESC);

CREATE INDEX idx_journal_filtered_tasks ON journal(type COLLATE BINARY ASC, private COLLATE BINARY ASC, starred COLLATE BINARY ASC, private COLLATE BINARY ASC, deleted COLLATE BINARY ASC, task COLLATE BINARY ASC, task_status COLLATE BINARY ASC, category COLLATE BINARY ASC, date_from COLLATE BINARY DESC);

CREATE TABLE conflicts (
  id TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  serialized TEXT NOT NULL,
  schema_version INTEGER NOT NULL DEFAULT 0,
  status INTEGER NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE measurable_types (
  id TEXT NOT NULL,
  unique_name TEXT NOT NULL UNIQUE,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  deleted BOOLEAN NOT NULL DEFAULT FALSE,
  private BOOLEAN NOT NULL DEFAULT FALSE,
  serialized TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 0,
  status INTEGER NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE habit_definitions (
  id TEXT NOT NULL,
  name TEXT NOT NULL UNIQUE,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  deleted BOOLEAN NOT NULL DEFAULT FALSE,
  private BOOLEAN NOT NULL DEFAULT FALSE,
  serialized TEXT NOT NULL,
  active BOOLEAN NOT NULL,
  PRIMARY KEY (id)
);

CREATE INDEX idx_habit_definitions_id ON habit_definitions (id);

CREATE INDEX idx_habit_definitions_name ON habit_definitions (name);

CREATE INDEX idx_habit_definitions_private ON habit_definitions (private);

CREATE TABLE category_definitions (
  id TEXT NOT NULL,
  name TEXT NOT NULL UNIQUE,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  deleted BOOLEAN NOT NULL DEFAULT FALSE,
  private BOOLEAN NOT NULL DEFAULT FALSE,
  serialized TEXT NOT NULL,
  active BOOLEAN NOT NULL,
  PRIMARY KEY (id)
);

CREATE INDEX idx_category_definitions_id ON category_definitions (id);

CREATE INDEX idx_category_definitions_name ON category_definitions (name);

CREATE INDEX idx_category_definitions_private ON category_definitions (private);

CREATE TABLE dashboard_definitions (
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  last_reviewed DATETIME NOT NULL,
  deleted BOOLEAN NOT NULL DEFAULT FALSE,
  private BOOLEAN NOT NULL DEFAULT FALSE,
  serialized TEXT NOT NULL,
  active BOOLEAN NOT NULL,
  PRIMARY KEY (id)
);

CREATE INDEX idx_dashboard_definitions_id ON dashboard_definitions (id);

CREATE INDEX idx_dashboard_definitions_name ON dashboard_definitions (name);

CREATE INDEX idx_dashboard_definitions_private ON dashboard_definitions (private);

CREATE TABLE config_flags (
  name TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL UNIQUE,
  status BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (name)
);

CREATE TABLE tag_entities (
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
);

CREATE INDEX idx_tag_entities_id ON tag_entities (id);

CREATE INDEX idx_tag_entities_tag ON tag_entities (tag);

CREATE INDEX idx_tag_entities_type ON tag_entities (type);

CREATE INDEX idx_tag_entities_private ON tag_entities (private);

CREATE INDEX idx_tag_entities_inactive ON tag_entities (inactive);

CREATE TABLE tagged (
  id TEXT NOT NULL UNIQUE,
  journal_id TEXT NOT NULL,
  tag_entity_id TEXT NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(journal_id) REFERENCES journal(id) ON DELETE CASCADE,
  FOREIGN KEY(tag_entity_id) REFERENCES tag_entities(id) ON DELETE CASCADE,
  UNIQUE(journal_id, tag_entity_id)
);

CREATE INDEX idx_tagged_journal_id ON tagged (journal_id);

CREATE INDEX idx_tagged_tag_entity_id ON tagged (tag_entity_id);

CREATE TABLE linked_entries (
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
);

CREATE INDEX idx_linked_entries_from_id ON linked_entries (from_id);

CREATE INDEX idx_linked_entries_to_id ON linked_entries (to_id);

CREATE INDEX idx_linked_entries_type ON linked_entries (type);

CREATE INDEX idx_linked_entries_hidden ON linked_entries (hidden);

CREATE INDEX idx_linked_entries_from_id_hidden ON linked_entries(from_id COLLATE BINARY ASC, hidden COLLATE BINARY ASC);

CREATE INDEX idx_linked_entries_to_id_hidden ON linked_entries(from_id COLLATE BINARY ASC, hidden COLLATE BINARY ASC);

/* Queries;


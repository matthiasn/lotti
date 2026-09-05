-- JournalDb fresh-install schema at schemaVersion 46.
-- Extracted from lib/database/database.drift at b38c9aefa
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
  task_priority TEXT,
  task_priority_rank INTEGER,
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
  project_id TEXT,
  
  
  day_id TEXT,
  recording_session_id TEXT,
  
  
  
  
  due_at DATETIME,
  PRIMARY KEY (id)
);

CREATE INDEX idx_journal_date_from_asc ON journal (date_from ASC);

CREATE INDEX idx_journal_date_to_asc ON journal (date_to ASC);

CREATE INDEX idx_journal_day_audio ON journal(
  day_id COLLATE BINARY ASC,
  date_from COLLATE BINARY ASC,
  id COLLATE BINARY ASC
)
WHERE type = 'JournalAudio'
  AND deleted = FALSE
  AND day_id IS NOT NULL;

CREATE UNIQUE INDEX idx_journal_recording_session ON journal(
  recording_session_id COLLATE BINARY ASC
)
WHERE type = 'JournalAudio'
  AND deleted = FALSE
  AND recording_session_id IS NOT NULL;

CREATE INDEX idx_journal_tab ON journal(type COLLATE BINARY ASC, starred COLLATE BINARY ASC, flag COLLATE BINARY ASC, private COLLATE BINARY ASC, date_from COLLATE BINARY DESC);

CREATE INDEX idx_journal_import_flag_date ON journal(
  flag COLLATE BINARY ASC,
  date_from COLLATE BINARY DESC,
  id COLLATE BINARY ASC
)
WHERE deleted = FALSE;

CREATE INDEX idx_journal_browse ON journal(
  deleted COLLATE BINARY ASC,
  type COLLATE BINARY ASC,
  date_from COLLATE BINARY DESC
);

CREATE INDEX idx_journal_tasks ON journal(
  category COLLATE BINARY ASC,
  task_status COLLATE BINARY ASC,
  task_priority_rank COLLATE BINARY ASC,
  date_from COLLATE BINARY DESC
)
WHERE type = 'Task'
  AND deleted = FALSE
  AND task = 1;

CREATE INDEX idx_journal_tasks_date ON journal(
  category COLLATE BINARY ASC,
  task_status COLLATE BINARY ASC,
  date_from COLLATE BINARY DESC,
  id COLLATE BINARY ASC
)
WHERE type = 'Task'
  AND deleted = FALSE
  AND task = 1;

CREATE INDEX idx_journal_tasks_date_priority ON journal(
  category COLLATE BINARY ASC,
  task_status COLLATE BINARY ASC,
  task_priority COLLATE BINARY ASC,
  date_from COLLATE BINARY DESC,
  id COLLATE BINARY ASC
)
WHERE type = 'Task'
  AND deleted = FALSE
  AND task = 1;

CREATE INDEX idx_journal_type_subtype ON journal(type COLLATE BINARY ASC, subtype COLLATE BINARY ASC, category COLLATE BINARY ASC, date_from COLLATE BINARY DESC);

CREATE INDEX idx_journal_tasks_due_open ON journal(due_at ASC)
WHERE type = 'Task'
  AND task = 1
  AND deleted = FALSE
  AND task_status NOT IN ('DONE', 'REJECTED');

CREATE INDEX idx_journal_task_status_private ON journal(
  task_status COLLATE BINARY ASC,
  private COLLATE BINARY ASC
)
WHERE type = 'Task' AND task = 1 AND deleted = FALSE;

CREATE INDEX idx_journal_project_id ON journal(project_id)
WHERE type = 'Task'
  AND task = 1
  AND deleted = FALSE
  AND project_id IS NOT NULL;

CREATE INDEX idx_journal_project_task_status ON journal(
  project_id COLLATE BINARY ASC,
  task_status COLLATE BINARY ASC
)
WHERE type = 'Task'
  AND task = 1
  AND deleted = FALSE
  AND project_id IS NOT NULL;

CREATE INDEX idx_journal_tasks_status_priority_date ON journal(
  task_status COLLATE BINARY ASC,
  task_priority_rank COLLATE BINARY ASC,
  date_from COLLATE BINARY DESC
)
WHERE type = 'Task'
  AND task = 1
  AND deleted = FALSE;

CREATE INDEX idx_journal_tasks_priority_date ON journal(
  task_priority_rank COLLATE BINARY ASC,
  date_from COLLATE BINARY DESC,
  id COLLATE BINARY ASC
)
WHERE type = 'Task'
  AND task = 1
  AND deleted = FALSE;

CREATE INDEX idx_journal_insights_time ON journal(
  date_from COLLATE BINARY ASC,
  date_to COLLATE BINARY ASC,
  category COLLATE BINARY ASC,
  private COLLATE BINARY ASC,
  id COLLATE BINARY ASC
)
WHERE type = 'JournalEntry'
  AND deleted = FALSE;

CREATE TABLE conflicts (
  id TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  serialized TEXT NOT NULL,
  schema_version INTEGER NOT NULL DEFAULT 0,
  status INTEGER NOT NULL,
  PRIMARY KEY (id)
);

CREATE INDEX idx_conflicts_status_created_at
ON conflicts(status ASC, created_at DESC);

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

CREATE INDEX idx_habit_definitions_name ON habit_definitions (name);

CREATE INDEX idx_habit_definitions_private ON habit_definitions (private);

CREATE INDEX idx_habit_definitions_deleted_private ON habit_definitions(
  deleted COLLATE BINARY ASC,
  private COLLATE BINARY ASC
);

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

CREATE INDEX idx_category_definitions_name ON category_definitions (name);

CREATE INDEX idx_category_definitions_private ON category_definitions (private);

CREATE TABLE label_definitions (
  id TEXT NOT NULL,
  name TEXT NOT NULL UNIQUE,
  color TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  deleted BOOLEAN NOT NULL DEFAULT FALSE,
  private BOOLEAN NOT NULL DEFAULT FALSE,
  serialized TEXT NOT NULL,
  PRIMARY KEY (id)
);

CREATE INDEX idx_label_definitions_name ON label_definitions (name);

CREATE INDEX idx_label_definitions_private ON label_definitions (private);

CREATE INDEX idx_label_definitions_deleted_private_name ON label_definitions(
  deleted COLLATE BINARY ASC,
  private COLLATE BINARY ASC,
  name COLLATE NOCASE ASC
);

CREATE INDEX idx_label_definitions_deleted_name_nocase ON label_definitions(
  deleted COLLATE BINARY ASC,
  name COLLATE NOCASE ASC
);

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

CREATE INDEX idx_dashboard_definitions_name ON dashboard_definitions (name);

CREATE INDEX idx_dashboard_definitions_private ON dashboard_definitions (private);

CREATE INDEX idx_dashboard_definitions_deleted_private_name ON dashboard_definitions(
  deleted COLLATE BINARY ASC,
  private COLLATE BINARY ASC,
  name COLLATE NOCASE ASC
);

CREATE TABLE config_flags (
  name TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL UNIQUE,
  status BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (name)
);

CREATE TABLE labeled (
  id TEXT NOT NULL UNIQUE,
  journal_id TEXT NOT NULL,
  label_id TEXT NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(journal_id) REFERENCES journal(id) ON DELETE CASCADE,
  FOREIGN KEY(label_id) REFERENCES label_definitions(id) ON DELETE CASCADE,
  UNIQUE(journal_id, label_id)
);

CREATE INDEX idx_labeled_journal_id ON labeled (journal_id);

CREATE INDEX idx_labeled_label_id ON labeled (label_id);

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

CREATE INDEX idx_linked_entries_type ON linked_entries (type);

CREATE INDEX idx_linked_entries_from_id_hidden ON linked_entries(from_id COLLATE BINARY ASC, hidden COLLATE BINARY ASC);

CREATE INDEX idx_linked_entries_from_id_hidden_to_id ON linked_entries(
  from_id COLLATE BINARY ASC,
  hidden COLLATE BINARY ASC,
  to_id COLLATE BINARY ASC
);

CREATE INDEX idx_linked_entries_to_id_hidden ON linked_entries(to_id COLLATE BINARY ASC, hidden COLLATE BINARY ASC);

CREATE INDEX idx_linked_entries_from_id_hidden_created_at_desc ON linked_entries(
  from_id COLLATE BINARY ASC,
  hidden COLLATE BINARY ASC,
  created_at COLLATE BINARY DESC
);

CREATE INDEX idx_linked_entries_to_id_type ON linked_entries(
  to_id COLLATE BINARY ASC,
  type COLLATE BINARY ASC
);

CREATE INDEX idx_linked_entries_rating_to_id ON linked_entries(
  to_id COLLATE BINARY ASC,
  from_id COLLATE BINARY ASC
)
WHERE type = 'RatingLink' AND COALESCE(hidden, FALSE) = FALSE;

/* Queries;


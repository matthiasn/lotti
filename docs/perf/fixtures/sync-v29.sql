-- SyncDatabase fresh-create schema 29 at d9a4f2a99.
-- Exported from sqlite_master through the app database constructor.
-- sqlite_sequence is automatically created by AUTOINCREMENT, so omitted.
CREATE TABLE "host_activity" ("host_id" TEXT NOT NULL, "last_seen_at" INTEGER NOT NULL, PRIMARY KEY ("host_id"));
CREATE TABLE "inbound_event_queue" ("queue_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "event_id" TEXT NOT NULL UNIQUE, "room_id" TEXT NOT NULL, "origin_ts" INTEGER NOT NULL, "producer" TEXT NOT NULL, "raw_json" TEXT NOT NULL, "enqueued_at" INTEGER NOT NULL, "attempts" INTEGER NOT NULL DEFAULT 0, "next_due_at" INTEGER NOT NULL DEFAULT 0, "lease_until" INTEGER NOT NULL DEFAULT 0, "status" TEXT NOT NULL DEFAULT 'enqueued', "committed_at" INTEGER NULL, "abandoned_at" INTEGER NULL, "last_error_reason" TEXT NULL, "resurrection_count" INTEGER NOT NULL DEFAULT 0, "json_path" TEXT NULL);
CREATE TABLE "onboarding_sync_rounds" ("round_id" TEXT NOT NULL, "direction" TEXT NOT NULL, "state" TEXT NOT NULL, "sender_host_id" TEXT NOT NULL, "sender_user_id" TEXT NULL, "sender_device_id" TEXT NULL, "recipient_host_id" TEXT NULL, "recipient_user_id" TEXT NOT NULL, "recipient_device_id" TEXT NOT NULL, "coverage_upper_bounds_json" TEXT NOT NULL, "started_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "expires_at" INTEGER NOT NULL, PRIMARY KEY ("round_id"));
CREATE TABLE "outbox" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "status" INTEGER NOT NULL DEFAULT 0, "retries" INTEGER NOT NULL DEFAULT 0, "message" TEXT NOT NULL, "subject" TEXT NOT NULL, "file_path" TEXT NULL, "outbox_entry_id" TEXT NULL, "payload_size" INTEGER NULL, "priority" INTEGER NOT NULL DEFAULT 2);
CREATE TABLE "queue_markers" ("room_id" TEXT NOT NULL, "last_applied_event_id" TEXT NULL, "last_applied_ts" INTEGER NOT NULL DEFAULT 0, "last_applied_commit_seq" INTEGER NOT NULL DEFAULT 0, "resume_floor_ts" INTEGER NULL, PRIMARY KEY ("room_id"));
CREATE TABLE "sync_sequence_log" ("host_id" TEXT NOT NULL, "counter" INTEGER NOT NULL, "entry_id" TEXT NULL, "payload_type" INTEGER NOT NULL DEFAULT 0, "originating_host_id" TEXT NULL, "status" INTEGER NOT NULL DEFAULT 0, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "request_count" INTEGER NOT NULL DEFAULT 0, "last_requested_at" INTEGER NULL, "json_path" TEXT NULL, PRIMARY KEY ("host_id", "counter"));
CREATE TABLE sync_sequence_watermarks (
  host_id TEXT PRIMARY KEY NOT NULL,
  last_counter INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
);
CREATE INDEX idx_inbound_event_queue_abandoned_path ON inbound_event_queue (json_path) WHERE status = 'abandoned';
CREATE INDEX idx_inbound_event_queue_abandoned_reason ON inbound_event_queue (last_error_reason) WHERE status = 'abandoned';
CREATE INDEX idx_inbound_event_queue_abandoned_reason_resurrection ON inbound_event_queue (last_error_reason, resurrection_count) WHERE status = 'abandoned';
CREATE INDEX idx_inbound_event_queue_active_ready_at ON inbound_event_queue (next_due_at, lease_until) WHERE status IN ('enqueued', 'retrying', 'leased');
CREATE INDEX idx_inbound_event_queue_active_room_ts ON inbound_event_queue (room_id, origin_ts) WHERE status IN ('enqueued', 'leased', 'retrying');
CREATE INDEX idx_inbound_event_queue_active_status_room ON inbound_event_queue (status, room_id) WHERE status IN ('enqueued', 'leased', 'retrying');
CREATE INDEX idx_inbound_event_queue_ready ON inbound_event_queue (next_due_at, origin_ts, queue_id) WHERE status IN ('enqueued', 'retrying', 'leased');
CREATE INDEX idx_inbound_event_queue_room ON inbound_event_queue (room_id, origin_ts);
CREATE INDEX idx_inbound_event_queue_status_due_lease ON inbound_event_queue (status, next_due_at, lease_until);
CREATE INDEX idx_inbound_event_queue_status_enqueued ON inbound_event_queue (status, enqueued_at);
CREATE INDEX idx_inbound_event_queue_status_producer_enqueued ON inbound_event_queue (status, producer, enqueued_at);
CREATE INDEX idx_outbox_actionable_priority_created_at ON outbox (priority, created_at, id) WHERE status IN (0, 3);
CREATE INDEX idx_outbox_actionable_subject ON outbox (subject) WHERE status IN (0, 3);
CREATE INDEX idx_outbox_pending_created_id ON outbox (created_at, id) WHERE status = 0;
CREATE INDEX idx_outbox_pending_entry_id_created_at ON outbox (outbox_entry_id, created_at) WHERE status = 0 AND outbox_entry_id IS NOT NULL;
CREATE INDEX idx_outbox_sent_updated_at ON outbox (updated_at, id) WHERE status = 1;
CREATE INDEX idx_outbox_status_priority_created_at ON outbox (status, priority, created_at);
CREATE INDEX idx_sync_sequence_log_actionable_status_created_at ON sync_sequence_log (status, created_at) WHERE status IN (1, 2);
CREATE INDEX idx_sync_sequence_log_actionable_status_last_requested_at ON sync_sequence_log (status, last_requested_at) WHERE status IN (1, 2) AND last_requested_at IS NOT NULL;
CREATE INDEX idx_sync_sequence_log_actionable_status_updated_at ON sync_sequence_log (status, updated_at) WHERE status IN (1, 2);
CREATE INDEX idx_sync_sequence_log_host_entry_status_counter ON sync_sequence_log (host_id, entry_id, counter DESC, status) WHERE entry_id IS NOT NULL;
CREATE INDEX idx_sync_sequence_log_host_status ON sync_sequence_log (host_id, status);
CREATE INDEX idx_sync_sequence_log_payload_resolution ON sync_sequence_log (entry_id, payload_type, status) WHERE entry_id IS NOT NULL;
CREATE INDEX idx_sync_sequence_log_resolved_host_counter ON sync_sequence_log (host_id, counter) WHERE status IN (0, 3, 4, 5, 8);
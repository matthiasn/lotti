import 'dart:io';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_db.dart';

/// A complete set of storage handles rooted at [root], independent of the
/// active getIt generation. Used to populate a world BEFORE switching the
/// live app to it (demo seeding) and to read/write the inactive side during
/// exit copy-over.
///
/// Every database is constructed with an explicit documents-directory
/// provider so nothing can fall back to the process-active profile root.
/// Construction is cheap — every Drift database is a LazyDatabase whose file
/// opens on first query.
///
/// Contract: getIt-coupled logic (PersistenceLogic, repositories,
/// EntitiesCacheService) must NOT be run against a non-active WorldHandle.
/// Writes go through the DB-level APIs plus the explicit JSON sidecar seam;
/// entities are expected to arrive with fully formed metadata.
class WorldHandle {
  WorldHandle._({
    required this.root,
    required this.journalDb,
    required this.settingsDb,
    required this.syncDb,
    required this.agentDb,
    required this.editorDb,
    required this.notificationsDb,
    required this.consumptionDb,
    required this.onboardingMetricsDb,
    required this.dayProcessingDb,
    required this.fts5Db,
    required this.aiConfigDb,
  });

  factory WorldHandle.open(Directory root) {
    Future<Directory> provider() async => root;
    return WorldHandle._(
      root: root,
      journalDb: JournalDb(
        readPool: 0,
        documentsDirectoryProvider: provider,
        documentsDirectory: root,
      ),
      settingsDb: SettingsDb(documentsDirectoryProvider: provider),
      syncDb: SyncDatabase(documentsDirectoryProvider: provider),
      agentDb: AgentDatabase(
        readPool: 0,
        documentsDirectoryProvider: provider,
      ),
      editorDb: EditorDb(documentsDirectoryProvider: provider),
      notificationsDb: NotificationsDb(
        readPool: 0,
        documentsDirectoryProvider: provider,
      ),
      consumptionDb: ConsumptionDatabase(
        readPool: 0,
        documentsDirectoryProvider: provider,
      ),
      onboardingMetricsDb: OnboardingMetricsDb(
        documentsDirectoryProvider: provider,
      ),
      dayProcessingDb: DayProcessingDb(
        readPool: 0,
        documentsDirectoryProvider: provider,
      ),
      fts5Db: Fts5Db(documentsDirectoryProvider: provider),
      aiConfigDb: AiConfigDb(documentsDirectoryProvider: provider),
    );
  }

  final Directory root;
  final JournalDb journalDb;
  final SettingsDb settingsDb;
  final SyncDatabase syncDb;
  final AgentDatabase agentDb;
  final EditorDb editorDb;
  final NotificationsDb notificationsDb;
  final ConsumptionDatabase consumptionDb;
  final OnboardingMetricsDb onboardingMetricsDb;
  final DayProcessingDb dayProcessingDb;
  final Fts5Db fts5Db;
  final AiConfigDb aiConfigDb;

  /// Writes [entity] into this world: journal row, JSON sidecar (written by
  /// JournalDb itself against this world's root — the `_documentsDirectory`
  /// constructor binding is what keeps it out of the active world), and —
  /// for searchable kinds — the FTS index.
  ///
  /// Note: `Fts5Db.insertText` resolves the ACTIVE generation's
  /// EntitiesCacheService, but only consults it for measurement entries;
  /// seeding writes tasks, entries, images and checklists, which never touch
  /// that path.
  Future<void> writeJournalEntity(JournalEntity entity) async {
    await journalDb.updateJournalEntity(entity);
    await fts5Db.insertText(entity);
  }

  Future<void> writeEntityDefinition(EntityDefinition definition) =>
      journalDb.upsertEntityDefinition(definition);

  Future<void> writeEntryLink(EntryLink link) =>
      journalDb.upsertEntryLink(link);

  Future<void> writeAiConfig(AiConfig config) => aiConfigDb.saveConfig(config);

  Future<void> writeSetting(String key, String value) =>
      settingsDb.saveSettingsItem(key, value);

  /// Closes every database, mirroring the ServiceDisposer order (settings
  /// last).
  Future<void> close() async {
    await aiConfigDb.close();
    await journalDb.close();
    await syncDb.close();
    await agentDb.close();
    await editorDb.close();
    await fts5Db.close();
    await consumptionDb.close();
    await notificationsDb.close();
    await onboardingMetricsDb.close();
    await dayProcessingDb.close();
    await settingsDb.close();
  }
}

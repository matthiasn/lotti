import 'dart:io';

import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';

/// The services of whichever world is active at the moment of each read.
///
/// `DemoModeGateway` spans profile switches — it drives them — so it can never
/// hold one generation's services: every getter here resolves against the
/// generation that is live when it is called. Read the demo world's journal
/// before `activate`, and the same getter returns the real world's after it.
/// The composition root supplies the implementation; tests stub it and swap
/// the answers where the app would switch profiles.
abstract interface class LiveWorldServices {
  /// The active world's profile, or null for the real world.
  ProfileContext? get profileContext;

  JournalDb get journalDb;

  AiConfigRepository get aiConfigs;

  /// The active world's documents root.
  Directory get root;

  PersistenceLogic get persistence;

  /// The full-text index, where the active world has one.
  Fts5Db? get fts;

  /// The active world's logger, or null before one is registered.
  DomainLogger? get domainLogger;
}

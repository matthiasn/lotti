import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

/// Holds the mocks registered during [setUpTestGetIt] so tests can access
/// them for stubbing without re-creating or looking them up.
class TestGetItMocks {
  TestGetItMocks({
    required this.journalDb,
    required this.updateNotifications,
    required this.settingsDb,
    required this.loggingService,
    required this.domainLogger,
  });

  final MockJournalDb journalDb;
  final MockUpdateNotifications updateNotifications;
  final MockSettingsDb settingsDb;
  final LoggingService loggingService;
  final DomainLogger domainLogger;
}

/// Sets up GetIt with common mocks for widget tests.
///
/// Call this in setUp() before creating widgets that use controllers
/// which access GetIt (e.g., ChecklistController, ChecklistItemController,
/// ThemingController).
///
/// Pass additional services via [additionalSetup] to register extra mocks
/// after the core ones:
/// ```dart
/// final mocks = await setUpTestGetIt(
///   additionalSetup: () {
///     getIt.registerSingleton<EntitiesCacheService>(mockCache);
///   },
/// );
/// ```
Future<TestGetItMocks> setUpTestGetIt({
  void Function()? additionalSetup,
}) async {
  await getIt.reset();

  final mockUpdateNotifications = MockUpdateNotifications();
  final mockJournalDb = MockJournalDb();
  final mockSettingsDb = MockSettingsDb();
  final loggingService = LoggingService();
  final domainLogger = DomainLogger(loggingService: loggingService);

  when(
    () => mockUpdateNotifications.updateStream,
  ).thenAnswer((_) => const Stream.empty());
  when(
    () => mockUpdateNotifications.localUpdateStream,
  ).thenAnswer((_) => const Stream.empty());
  when(
    () => mockJournalDb.journalEntityById(any()),
  ).thenAnswer((_) async => null);
  when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
  when(
    () => mockSettingsDb.itemsByKeys(any()),
  ).thenAnswer((_) async => <String, String?>{});
  when(
    () => mockSettingsDb.saveSettingsItem(any(), any()),
  ).thenAnswer((_) async => 1);
  when(() => mockSettingsDb.removeSettingsItem(any())).thenAnswer((_) async {});
  when(
    () => mockSettingsDb.itemsWithKeyPrefix(any()),
  ).thenAnswer((_) async => <String, String>{});
  _stubLocalSettingsGroup(mockSettingsDb);
  final mockEmbeddingStore = MockEmbeddingStore();

  getIt
    ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
    ..registerSingleton<JournalDb>(mockJournalDb)
    ..registerSingleton<SettingsDb>(mockSettingsDb)
    ..registerSingleton<LoggingService>(loggingService)
    ..registerSingleton<DomainLogger>(domainLogger)
    ..registerSingleton<EmbeddingStore>(mockEmbeddingStore)
    ..registerSingleton<OllamaEmbeddingRepository>(
      MockOllamaEmbeddingRepository(),
    );

  additionalSetup?.call();

  return TestGetItMocks(
    journalDb: mockJournalDb,
    updateNotifications: mockUpdateNotifications,
    settingsDb: mockSettingsDb,
    loggingService: loggingService,
    domainLogger: domainLogger,
  );
}

/// Tears down GetIt after tests.
/// Call this in tearDown() to clean up registrations.
Future<void> tearDownTestGetIt() async {
  await getIt.reset();
}

/// Registers a [DomainLogger] in GetIt if one is not already registered,
/// backed by the currently registered [LoggingService] (registering a fresh
/// one when absent).
///
/// Migrated production code resolves `getIt<DomainLogger>()` rather than
/// `getIt<LoggingService>()`. Tests that set up GetIt by hand and only register
/// a (mock) [LoggingService] must call this afterwards so the logger resolves.
/// It is idempotent — safe under reset-based, guard-based, and
/// unregister/re-register setups, and across the shared CI isolate.
void ensureDomainLoggerRegistered() {
  if (!getIt.isRegistered<LoggingService>()) {
    getIt.registerSingleton<LoggingService>(LoggingService());
  }
  if (!getIt.isRegistered<DomainLogger>()) {
    getIt.registerSingleton<DomainLogger>(
      DomainLogger(loggingService: getIt<LoggingService>()),
    );
  }
}

/// Ensures core services required by ThemingController are registered.
/// Unlike setUpTestGetIt, this does NOT reset GetIt - it only registers
/// missing services. Safe to call in tests that have their own setup.
void ensureThemingServicesRegistered() {
  if (!getIt.isRegistered<UpdateNotifications>()) {
    final mockUpdateNotifications = MockUpdateNotifications();
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockUpdateNotifications.localUpdateStream,
    ).thenAnswer((_) => const Stream.empty());
    getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  }

  if (!getIt.isRegistered<SettingsDb>()) {
    final mockSettingsDb = MockSettingsDb();
    when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
    when(
      () => mockSettingsDb.itemsByKeys(any()),
    ).thenAnswer((_) async => <String, String?>{});
    when(
      () => mockSettingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);
    when(
      () => mockSettingsDb.removeSettingsItem(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockSettingsDb.itemsWithKeyPrefix(any()),
    ).thenAnswer((_) async => <String, String>{});
    _stubLocalSettingsGroup(mockSettingsDb);
    getIt.registerSingleton<SettingsDb>(mockSettingsDb);
  }

  if (!getIt.isRegistered<LoggingService>()) {
    getIt.registerSingleton<LoggingService>(LoggingService());
  }

  if (!getIt.isRegistered<DomainLogger>()) {
    getIt.registerSingleton<DomainLogger>(
      DomainLogger(loggingService: getIt<LoggingService>()),
    );
  }
}

void _stubLocalSettingsGroup(MockSettingsDb settingsDb) {
  Future<SavedSettingsGroup> answer(Invocation invocation) async {
    final defaults =
        invocation.namedArguments[#retainedDefaults] as Map<String, String>? ??
        const {};
    final retained = defaults.isEmpty
        ? <String, String?>{}
        : await settingsDb.itemsByKeys(defaults.keys);
    return (
      updatedAt: invocation.namedArguments[#timestamp] as int,
      values: {
        for (final entry in defaults.entries)
          entry.key: retained[entry.key] ?? entry.value,
        ...invocation.positionalArguments.single as Map<String, String>,
      },
    );
  }

  when(
    () => settingsDb.saveLocalSettingsGroup(
      any(),
      stampKey: any(named: 'stampKey'),
      timestamp: any(named: 'timestamp'),
      retainedDefaults: any(named: 'retainedDefaults'),
    ),
  ).thenAnswer(answer);
}

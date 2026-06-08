import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

/// Shared per-test harness for the JournalDb coalescing / chunking suites.
///
/// All of those suites drive an **in-memory** [JournalDb] (every spy/failing
/// subclass and the plain `batch_chunking` db pass `inMemoryDatabase: true`).
/// `openDbConnection` short-circuits to `NativeDatabase.memory()` for the
/// in-memory case and never touches the filesystem, `path_provider`, or
/// `getIt<Directory>` — so the only ambient dependency these tests actually
/// need is a registered [DomainLogger] (the DB's `_logger` getter falls back
/// to `getIt<DomainLogger>()`).
///
/// This bench therefore registers a stubbed [MockDomainLogger] (preserving any
/// previously-registered logger), builds the caller's in-memory db via
/// `dbFactory`, and seeds the standard config flags. [tearDown] closes the db
/// and restores the prior logger registration. Because each suite keeps its own
/// `late` db field (test bodies reassign it — e.g. closing the real db and
/// swapping in a failing subclass), the factory pattern lets the spy subclasses
/// be constructed by the caller while the boilerplate lives here.
///
/// Usage:
/// ```dart
/// late CoalescingDbBench<_CountingJournalDb> bench;
/// setUp(() async {
///   bench = await CoalescingDbBench.create(_CountingJournalDb.new);
/// });
/// tearDown(() => bench.tearDown());
/// // bench.db / bench.logger
/// ```
class CoalescingDbBench<T extends JournalDb> {
  CoalescingDbBench._({
    required this.db,
    required this.logger,
    required DomainLogger? previousLogger,
    // ignore: prefer_initializing_formals
  }) : _previousLogger = previousLogger;

  /// The in-memory db built by the caller's factory, with config flags seeded.
  final T db;

  /// The stubbed logger registered as `getIt<DomainLogger>` for the test.
  final MockDomainLogger logger;

  final DomainLogger? _previousLogger;

  /// Builds the bench: registers a stubbed [MockDomainLogger] (saving any prior
  /// registration), constructs the in-memory db via [dbFactory], and seeds the
  /// standard config flags via [initConfigFlags].
  static Future<CoalescingDbBench<T>> create<T extends JournalDb>(
    T Function() dbFactory,
  ) async {
    final logger = MockDomainLogger();
    when(
      () => logger.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String?>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => logger.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any<String?>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});

    DomainLogger? previousLogger;
    if (getIt.isRegistered<DomainLogger>()) {
      previousLogger = getIt<DomainLogger>();
      getIt.unregister<DomainLogger>();
    }
    getIt.registerSingleton<DomainLogger>(logger);

    final db = dbFactory();
    await initConfigFlags(db, inMemoryDatabase: true);

    return CoalescingDbBench<T>._(
      db: db,
      logger: logger,
      previousLogger: previousLogger,
    );
  }

  /// Closes the bench db and restores the logger registration that existed
  /// before [create] ran.
  Future<void> tearDown() async {
    await db.close();
    if (getIt.isRegistered<DomainLogger>()) {
      getIt.unregister<DomainLogger>();
    }
    if (_previousLogger != null) {
      getIt.registerSingleton<DomainLogger>(_previousLogger);
    }
  }
}

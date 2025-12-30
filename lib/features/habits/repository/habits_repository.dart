import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'habits_repository.g.dart';

/// Repository interface for habit-related data operations.
///
/// This abstraction layer separates data access from state management,
/// making controllers easier to test and more modular.
abstract class HabitsRepository {
  /// Watches all habit definitions from the database.
  ///
  /// Returns a stream that emits whenever habit definitions change.
  Stream<List<HabitDefinition>> watchHabitDefinitions();

  /// Watches a specific habit definition by ID.
  ///
  /// Returns a stream that emits whenever the habit changes.
  /// Emits null if the habit doesn't exist.
  Stream<HabitDefinition?> watchHabitById(String id);

  /// Fetches habit completions within a date range.
  ///
  /// [rangeStart] is the start of the date range (inclusive).
  /// Returns all habit completion entries from [rangeStart] to now.
  Future<List<JournalEntity>> getHabitCompletionsInRange({
    required DateTime rangeStart,
  });

  /// Fetches habit completions for a specific habit within a date range.
  ///
  /// [habitId] is the ID of the habit to fetch completions for.
  /// [rangeStart] and [rangeEnd] define the date range (inclusive).
  Future<List<JournalEntity>> getHabitCompletionsByHabitId({
    required String habitId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  /// Saves or updates a habit definition.
  ///
  /// Returns the number of affected rows (1 on success).
  Future<int> upsertHabitDefinition(HabitDefinition habitDefinition);

  /// Watches all dashboard definitions.
  ///
  /// Used for selecting which dashboard a habit belongs to.
  Stream<List<DashboardDefinition>> watchDashboards();

  /// Stream of notification IDs that may affect habits.
  ///
  /// Consumers should filter for [habitCompletionNotification] to know
  /// when habit completions have changed.
  Stream<Set<String>> get updateStream;
}

/// Default implementation of [HabitsRepository] using [JournalDb].
class HabitsRepositoryImpl implements HabitsRepository {
  /// Creates a repository instance.
  ///
  /// [journalDb] is the database for habit data access.
  /// [updateNotifications] provides the stream of update notifications.
  HabitsRepositoryImpl({
    required JournalDb journalDb,
    required UpdateNotifications updateNotifications,
  })  : _journalDb = journalDb,
        _updateNotifications = updateNotifications;

  final JournalDb _journalDb;
  final UpdateNotifications _updateNotifications;

  @override
  Stream<List<HabitDefinition>> watchHabitDefinitions() {
    return _journalDb.watchHabitDefinitions();
  }

  @override
  Stream<HabitDefinition?> watchHabitById(String id) {
    return _journalDb.watchHabitById(id);
  }

  @override
  Future<List<JournalEntity>> getHabitCompletionsInRange({
    required DateTime rangeStart,
  }) {
    return _journalDb.getHabitCompletionsInRange(rangeStart: rangeStart);
  }

  @override
  Future<List<JournalEntity>> getHabitCompletionsByHabitId({
    required String habitId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return _journalDb.getHabitCompletionsByHabitId(
      habitId: habitId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Future<int> upsertHabitDefinition(HabitDefinition habitDefinition) {
    return _journalDb.upsertHabitDefinition(habitDefinition);
  }

  @override
  Stream<List<DashboardDefinition>> watchDashboards() {
    return _journalDb.watchDashboards();
  }

  @override
  Stream<Set<String>> get updateStream => _updateNotifications.updateStream;
}

/// Provides the [HabitsRepository] instance.
///
/// This provider bridges the gap between getIt service locator and Riverpod,
/// allowing the repository to be easily overridden in tests.
@Riverpod(keepAlive: true)
HabitsRepository habitsRepository(Ref ref) {
  return HabitsRepositoryImpl(
    journalDb: getIt<JournalDb>(),
    updateNotifications: getIt<UpdateNotifications>(),
  );
}

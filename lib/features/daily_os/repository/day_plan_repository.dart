import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'day_plan_repository.g.dart';

/// Repository for day plan data operations.
///
/// Provides CRUD operations for day plans. Plans are created lazily
/// on first user interaction, not on navigation.
abstract class DayPlanRepository {
  /// Gets the day plan for a specific date.
  ///
  /// Returns null if no plan exists for that date.
  Future<DayPlanEntry?> getDayPlan(DateTime date);

  /// Saves a day plan.
  ///
  /// Creates or updates the plan using the existing persistence logic.
  /// Returns the saved plan with updated metadata (e.g., new vector clock).
  Future<DayPlanEntry> save(DayPlanEntry plan);

  /// Gets all day plans within a date range.
  Future<List<DayPlanEntry>> getDayPlansInRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  /// Stream of notification IDs that may affect day plans.
  ///
  /// Consumers should filter for [dayPlanNotification] to know
  /// when day plans have changed.
  Stream<Set<String>> get updateStream;
}

/// Default implementation of [DayPlanRepository].
class DayPlanRepositoryImpl implements DayPlanRepository {
  DayPlanRepositoryImpl({
    required JournalDb journalDb,
    required PersistenceLogic persistenceLogic,
    required UpdateNotifications updateNotifications,
  })  : _journalDb = journalDb,
        _persistenceLogic = persistenceLogic,
        _updateNotifications = updateNotifications;

  final JournalDb _journalDb;
  final PersistenceLogic _persistenceLogic;
  final UpdateNotifications _updateNotifications;

  @override
  Future<DayPlanEntry?> getDayPlan(DateTime date) async {
    final id = dayPlanId(date);
    return _journalDb.getDayPlanById(id);
  }

  @override
  Future<DayPlanEntry> save(DayPlanEntry plan) async {
    // Check if this is an update or a new create
    final existing = await _journalDb.getDayPlanById(plan.meta.id);

    if (existing == null) {
      // New plan - use createDbEntity
      await _persistenceLogic.createDbEntity(plan);
      return plan;
    } else {
      // Update existing - use updateMetadata + updateDbEntity
      final updatedMeta = await _persistenceLogic.updateMetadata(plan.meta);
      final updatedPlan = plan.copyWith(meta: updatedMeta);
      await _persistenceLogic.updateDbEntity(updatedPlan);
      return updatedPlan;
    }
  }

  @override
  Future<List<DayPlanEntry>> getDayPlansInRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return _journalDb.getDayPlansInRange(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Stream<Set<String>> get updateStream => _updateNotifications.updateStream;
}

/// Provides the [DayPlanRepository] instance.
@Riverpod(keepAlive: true)
DayPlanRepository dayPlanRepository(Ref ref) {
  return DayPlanRepositoryImpl(
    journalDb: getIt<JournalDb>(),
    persistenceLogic: getIt<PersistenceLogic>(),
    updateNotifications: getIt<UpdateNotifications>(),
  );
}

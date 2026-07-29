import 'package:drift/drift.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_directive_models.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_db.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:meta/meta.dart';

/// Shared corpus ages for storage and full-workflow benchmarks.
const Map<String, int> dayPlannerBenchmarkCorpora = {
  '1 month': 30,
  '6 months': 182,
  '12 months': 365,
};

/// Synthetic Daily OS history for measuring how per-action cost scales with
/// install age (`lotti3-hkb.1`).
///
/// The point is not absolute numbers — those depend on the machine — but the
/// *slope*: an operation whose cost tracks outstanding work should read the
/// same at twelve simulated months as at one, while anything still scanning
/// history grows visibly. Every measurement below is therefore reported per
/// corpus size and compared across sizes, never in isolation.
///
/// Deterministic by construction: all timestamps derive from [baseDay], and
/// the only clock used is a [Stopwatch] for elapsed time, never a wall clock
/// feeding data.
class DayPlannerCorpus {
  DayPlannerCorpus({
    required this.agentDb,
    required this.processingDb,
    this.days = 30,
  });

  /// The day the corpus ends on. Everything is seeded backwards from here, so
  /// the "current" day is always the newest and the same regardless of size.
  static final DateTime baseDay = DateTime(2026, 7, 18);

  /// Rough per-day shape of real use. Deliberately not uniform: status events
  /// are the fastest-growing type, captures the next.
  ///
  /// Processing jobs for past days are seeded *terminal*, so the corpus has
  /// the shape a real install has — a small pending head over a large ledger.
  static const int capturesPerDay = 3;
  static const int statusEventsPerDay = 6;
  static const int changeSetsPerDay = 2;

  final AgentDatabase agentDb;
  final DayProcessingDb processingDb;

  /// Simulated install age in days.
  final int days;

  late final AgentRepository repository = AgentRepository(agentDb);
  late final DayProcessingOutboxRepository outbox =
      DayProcessingOutboxRepository(
        db: processingDb,
        now: () => baseDay,
        tokenFactory: () => 'claim-token',
      );

  /// The day every measurement targets: the newest, i.e. the one a user would
  /// actually be looking at.
  String get currentDayId => dayAgentIdForDate(baseDay);

  DateTime dayAt(int offset) => DateTime(
    baseDay.year,
    baseDay.month,
    baseDay.day - offset,
  );

  /// Seeds the whole corpus under the coordinator.
  ///
  /// Under the coordinator specifically, because that is the agent that
  /// actually accumulates — a `day_agent:<dayId>` holds one day and goes cold,
  /// so seeding those would measure nothing.
  Future<void> seed() async {
    for (var offset = 0; offset < days; offset++) {
      final day = dayAt(offset);
      final dayId = dayPlanId(day);
      final at = DateTime(day.year, day.month, day.day, 9);

      await repository.upsertEntity(
        AgentDomainEntity.dayPlan(
          id: 'day_agent_plan:$dayId',
          agentId: dailyOsPlannerAgentId,
          dayId: dayId,
          planDate: day,
          data: DayPlanData(planDate: day, status: const DayPlanStatus.draft()),
          createdAt: at,
          updatedAt: at,
          vectorClock: null,
        ),
      );

      for (var i = 0; i < capturesPerDay; i++) {
        await repository.upsertEntity(
          AgentDomainEntity.capture(
            id: 'capture-$dayId-$i',
            agentId: dailyOsPlannerAgentId,
            transcript: 'Captured note $i',
            capturedAt: at,
            createdAt: at,
            dayId: dayId,
            vectorClock: null,
          ),
        );
        final job = await outbox.enqueueParseCapture(
          dayId: dayId,
          captureId: 'capture-$dayId-$i',
        );
        // Everything but the current day is drained, which is what a real
        // outbox looks like: a small pending head and an ever-growing ledger
        // of terminal rows behind it. Leaving it all pending would measure a
        // backlog nobody has, and would hide the property under test —
        // whether the retained ledger stays off the drain path.
        if (offset > 0) {
          final claim = await outbox.claimById(job.id);
          await outbox.markSucceeded(
            jobId: job.id,
            claimToken: claim!.token,
          );
        }
      }

      for (var i = 0; i < statusEventsPerDay; i++) {
        await repository.upsertEntity(
          AgentDomainEntity.dayStatusEvent(
            id: 'status-$dayId-$i',
            agentId: dailyOsPlannerAgentId,
            dayId: dayId,
            status: DayStatusKind.onTrack,
            raisedAt: at,
            createdAt: at,
            vectorClock: null,
          ),
        );
      }

      for (var i = 0; i < changeSetsPerDay; i++) {
        await repository.upsertEntity(
          AgentDomainEntity.changeSet(
            id: 'plan_diff:$dayId-$i',
            agentId: dailyOsPlannerAgentId,
            taskId: 'day_agent_plan:$dayId',
            threadId: 'thread-$dayId',
            runKey: 'run-$dayId-$i',
            // Historic diffs that are no longer actionable — the pile a
            // pending read must not have to walk.
            status: i.isEven
                ? ChangeSetStatus.resolved
                : ChangeSetStatus.expired,
            items: const [],
            createdAt: at,
            vectorClock: null,
          ),
        );
      }
    }
  }

  /// Runs every measured operation and returns the median elapsed
  /// microseconds over [repetitions].
  ///
  /// Median rather than a single shot: at these magnitudes a single run is
  /// dominated by scheduling noise, and the property being tested — that cost
  /// does not grow with corpus size — is not readable through that noise. The
  /// median also discards the first-run outlier where SQLite is still
  /// preparing the statement.
  ///
  /// Each entry names an operation a user action actually triggers, so a
  /// regression here is a regression they would feel.
  Future<Map<String, int>> measure({int repetitions = 9}) async {
    return {
      // The drain path: what every enqueue and every retry tick costs.
      'outbox.claimNext': await _time(outbox.claimNext, repetitions),
      // The day view: captures and the persona indicator.
      'dayView.captures': await _time(
        () => repository.getEntitiesByAgentIdAndSubtype(
          dailyOsPlannerAgentId,
          type: AgentEntityTypes.capture,
          subtype: currentDayId,
        ),
        repetitions,
      ),
      'dayView.statusEvents': await _time(
        () => repository.getEntitiesByAgentIdAndSubtype(
          dailyOsPlannerAgentId,
          type: AgentEntityTypes.dayStatusEvent,
          subtype: currentDayId,
        ),
        repetitions,
      ),
      // Runs ahead of both of the above, on every day-agent resolution.
      'dayView.plannerOwnsDay': await _time(
        () => repository.getEntitiesByAgentIdAndSubtype(
          dailyOsPlannerAgentId,
          type: AgentEntityTypes.capture,
          subtype: currentDayId,
          limit: 1,
        ),
        repetitions,
      ),
      // Pending diffs, read past however much confirmed/rejected history.
      'planEditor.pendingDiffs': await _time(
        () => repository.getEntitiesByAgentIdAndSubtype(
          dailyOsPlannerAgentId,
          type: 'changeSet',
          subtype: ChangeSetStatus.pending.name,
        ),
        repetitions,
      ),
      // A seven-day plan lookback.
      'planWriter.lookback': await _time(
        () => repository.getEntitiesByAgentIdAndSubtypes(
          dailyOsPlannerAgentId,
          type: AgentEntityTypes.dayPlan,
          subtypes: [
            for (var offset = 0; offset < 7; offset++) dayPlanId(dayAt(offset)),
          ],
        ),
        repetitions,
      ),
    };
  }

  /// Deterministic SQL work performed by every measured user action.
  ///
  /// Unlike elapsed time, statement and returned-row counts are independent of
  /// CPU scheduling and cache warmth. Counting at Drift's executor boundary
  /// also catches a repository that loads broad history and filters it in
  /// Dart: those discarded rows still appear here.
  Future<Map<String, int>> operationCosts() async {
    final costs = <String, _SqlOperationCost>{
      'outbox.claimNext': await _countSqlOperation(
        processingDb,
        outbox.claimNext,
      ),
      'dayView.captures': await _countSqlOperation(
        agentDb,
        () => repository.getEntitiesByAgentIdAndSubtype(
          dailyOsPlannerAgentId,
          type: AgentEntityTypes.capture,
          subtype: currentDayId,
        ),
      ),
      'dayView.statusEvents': await _countSqlOperation(
        agentDb,
        () => repository.getEntitiesByAgentIdAndSubtype(
          dailyOsPlannerAgentId,
          type: AgentEntityTypes.dayStatusEvent,
          subtype: currentDayId,
        ),
      ),
      'dayView.plannerOwnsDay': await _countSqlOperation(
        agentDb,
        () => repository.getEntitiesByAgentIdAndSubtype(
          dailyOsPlannerAgentId,
          type: AgentEntityTypes.capture,
          subtype: currentDayId,
          limit: 1,
        ),
      ),
      'planEditor.pendingDiffs': await _countSqlOperation(
        agentDb,
        () => repository.getEntitiesByAgentIdAndSubtype(
          dailyOsPlannerAgentId,
          type: 'changeSet',
          subtype: ChangeSetStatus.pending.name,
        ),
      ),
      'planWriter.lookback': await _countSqlOperation(
        agentDb,
        () => repository.getEntitiesByAgentIdAndSubtypes(
          dailyOsPlannerAgentId,
          type: AgentEntityTypes.dayPlan,
          subtypes: [
            for (var offset = 0; offset < 7; offset++) dayPlanId(dayAt(offset)),
          ],
        ),
      ),
    };
    return {
      for (final entry in costs.entries) ...{
        '${entry.key}.statements': entry.value.statements,
        '${entry.key}.rowsReturned': entry.value.rowsReturned,
        '${entry.key}.unboundedPlanSteps': entry.value.unboundedPlanSteps,
      },
    };
  }

  /// Row counts, so a report states how much history produced its numbers.
  Future<Map<String, int>> counts() async {
    final agentRows = await agentDb
        .customSelect('SELECT COUNT(*) AS c FROM agent_entities')
        .getSingle();
    final jobRows = await processingDb
        .customSelect('SELECT COUNT(*) AS c FROM day_processing_jobs')
        .getSingle();
    return {
      'days': days,
      'agentEntities': agentRows.read<int>('c'),
      'processingJobs': jobRows.read<int>('c'),
    };
  }

  static Future<int> _time(
    Future<void> Function() operation,
    int repetitions,
  ) async {
    final samples = <int>[];
    for (var i = 0; i < repetitions; i++) {
      final stopwatch = Stopwatch()..start();
      await operation();
      samples.add((stopwatch..stop()).elapsedMicroseconds);
    }
    samples.sort();
    return samples[samples.length ~/ 2];
  }

  static Future<_SqlOperationCost> _countSqlOperation(
    GeneratedDatabase db,
    Future<Object?> Function() operation,
  ) async {
    final interceptor = _SqlOperationCounter();
    await db.runWithInterceptor(operation, interceptor: interceptor);
    return _SqlOperationCost(
      statements: interceptor.statements,
      rowsReturned: interceptor.rowsReturned,
      unboundedPlanSteps: interceptor.unboundedPlanSteps,
    );
  }

  /// Whether an SQLite query-plan step touches retained history without the
  /// bounded index family for that operation.
  ///
  /// A broad index can still walk every row owned by an agent, so merely
  /// checking for `USING INDEX` is insufficient. Outbox claims may use the
  /// pending partial index plus the table's primary-key auto-index for the
  /// outer update; day reads must use a subtype index.
  @visibleForTesting
  static bool debugIsUnboundedHistoryPlanDetail(String detail) {
    final normalized = detail.toUpperCase();
    if (normalized.contains('AGENT_ENTITIES')) {
      return !normalized.contains('IDX_AGENT_ENTITIES_AGENT_TYPE_SUB') &&
          !normalized.contains(
            'IDX_AGENT_ENTITIES_ACTIVE_AGENT_TYPE_SUB_CREATED_ID',
          );
    }
    if (normalized.contains('DAY_PROCESSING_JOBS')) {
      return !normalized.contains('IDX_DAY_PROCESSING_JOBS_PENDING') &&
          !normalized.contains('SQLITE_AUTOINDEX_DAY_PROCESSING_JOBS_1');
    }
    return false;
  }
}

class _SqlOperationCost {
  const _SqlOperationCost({
    required this.statements,
    required this.rowsReturned,
    required this.unboundedPlanSteps,
  });

  final int statements;
  final int rowsReturned;
  final int unboundedPlanSteps;
}

class _SqlOperationCounter extends QueryInterceptor {
  int statements = 0;
  int rowsReturned = 0;
  int unboundedPlanSteps = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    statements++;
    final queryPlan = await executor.runSelect(
      'EXPLAIN QUERY PLAN $statement',
      args,
    );
    unboundedPlanSteps += queryPlan.where((row) {
      final detail = row['detail'];
      return detail is String &&
          DayPlannerCorpus.debugIsUnboundedHistoryPlanDetail(detail);
    }).length;
    final rows = await executor.runSelect(statement, args);
    rowsReturned += rows.length;
    return rows;
  }
}

import 'dart:io';

import 'package:lotti/features/system_health/domain/log_records.dart';
import 'package:lotti/features/system_health/domain/system_health_range.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:path/path.dart' as p;

/// A day inside every fixture window.
final DateTime fixtureDay = DateTime(2026, 9, 12);

/// A window covering [fixtureDay] and the day before it, whole days.
SystemHealthRange fixtureRange() => SystemHealthRange.days(
  firstDay: fixtureDay.subtract(const Duration(days: 1)),
  lastDay: fixtureDay,
);

/// Writes [content] to `<logs>/<stem>-<yyyy-MM-dd>.log`.
Future<File> writeLogFile(
  Directory logs,
  String stem,
  DateTime day,
  String content,
) async {
  final date =
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
  final file = File(p.join(logs.path, '$stem-$date.log'));
  await file.parent.create(recursive: true);
  return file.writeAsString(content);
}

/// Lines in the per-domain file shape, as `DomainLogger` writes them.
const String agentRuntimeFixture = '''
2026-09-12T01:32:41.334188 [INFO] restore: restoring task agent subscriptions...
2026-09-12T01:33:02.044370 [INFO] execute: wake completed in 20900ms for [id:114033]
2026-09-12T00:05:23.082870 [ERROR]: wake failed in 18136ms for [id:95a30c]: Bad state: interactive goal turn left rejected tools unresolved: update_goal_report
#0      GoalAgentWorkflow.execute (package:lotti/features/goals/workflow/goal_agent_workflow.dart:707:9)
<asynchronous suspension>
#1      wireWakeExecutor.<anonymous closure> (package:lotti/features/agents/state/agent_wiring.dart:99:22)
2026-09-12T00:06:23.000000 [ERROR]: wake failed in 2000ms for [id:77aa00]: Bad state: interactive goal turn left rejected tools unresolved: update_goal_report
2026-09-12T00:07:00.000000 [WARN] drain: drain skipped, queue.length=3
''';

/// The PII-safe error mirror: shared shape, message plus error type only.
/// Timestamps sit a few hundred microseconds from the per-domain entries,
/// the way `DomainLogger._writeError` really writes them.
const String errorSafeFixture = '''
2026-09-12T00:05:03.833900 [ERROR] sync vc.reserved.audit: vc.reserved.audit host=19d6f0b3-7d45-4ca1-aeb2-8829cac4b42e count=12 (errorType=String)
2026-09-12T00:05:23.083100 [ERROR] agentRuntime: wake failed in 18136ms for [id:95a30c] (errorType=StateError)
2026-09-12T00:06:23.000300 [ERROR] agentRuntime: wake failed in 2000ms for [id:77aa00] (errorType=StateError)
2026-09-12T00:07:30.000000 [ERROR] speech audio_waveform_service: waveform extraction failed (errorType=MissingPluginException)
2026-09-12T00:08:00.000000 [WARN] agentRuntime: not an error line
''';

/// Lines in the shared file shape, as the sync log is written.
const String syncFixture = '''
2026-09-12T00:05:03.833698 [ERROR] sync vc.reserved.audit: vc.reserved.audit host=19d6f0b3-7d45-4ca1-aeb2-8829cac4b42e count=12
2026-09-12T00:05:04.000000 [INFO] sync outbox: sent 3 messages
2026-09-12T00:05:05.000000 [WARN] sync: user user@example.com retried
''';

const String slowQueriesFixture = '''
2026-09-12T19:11:48.592 [db.sqlite] select 388.759ms args=0 SELECT * FROM journal WHERE deleted = 0 ORDER BY date_from DESC
  TIMING: scope=executorAwait started=2026-09-12T19:11:48.203 completed=2026-09-12T19:11:48.592 inFlightAtStart=4
2026-09-12T19:11:49.000 [db.sqlite] select 12.000ms args=1 SELECT * FROM journal WHERE id IN (?, ?, ?)
2026-09-12T19:11:50.000 [db.sqlite] select 14.000ms args=1 SELECT * FROM journal WHERE id IN (?, ?)
2026-09-12T19:11:51.000 [db.sqlite] select 250.000ms args=0 SELECT * FROM journal WHERE deleted = 0 ORDER BY date_from DESC
''';

/// A `BEGIN` that queued behind open transactions, with the timing and
/// transaction rows the interceptor writes for it, followed by an entry
/// written without timing bookkeeping.
const String transactionSlowQueriesFixture = '''
2026-09-12T19:11:52.000 [agent.sqlite] transaction.open 1064.000ms args=0 BEGIN
  TIMING: scope=executorAwait started=2026-09-12T19:11:50.936 completed=2026-09-12T19:11:52.000 inFlightAtStart=12
  TRANSACTION: id=7 parent=null activeAtStart=[3, 5]
2026-09-12T19:11:53.000 [agent.sqlite] transaction.open 20.000ms args=0 BEGIN
''';

const String superSlowQueriesFixture = '''
2026-09-12T19:11:48.592 [db.sqlite] select 388.759ms args=0 SELECT * FROM journal WHERE deleted = 0 ORDER BY date_from DESC
  PLAN: 4|0|SEARCH journal USING INDEX idx_journal_browse (deleted=?)
  PLAN: 84|0|USE TEMP B-TREE FOR ORDER BY
  STACK: #10     JournalDb.getAllDashboards (package:lotti/database/database.dart:3056:34)
  STACK: #11     dashboardsProvider.<anonymous closure> (package:lotti/features/dashboards/state/dashboards_page_controller.dart:20:14)
2026-09-12T19:11:51.000 [db.sqlite] select 250.000ms args=0 SELECT * FROM journal WHERE deleted = 0 ORDER BY date_from DESC
  PLAN: 4|0|SEARCH journal USING INDEX idx_journal_browse (deleted=?)
  PLAN: 84|0|USE TEMP B-TREE FOR ORDER BY
  STACK: #10     JournalDb.getAllDashboards (package:lotti/database/database.dart:3056:34)
''';

LogRecord logRecord({
  required DateTime timestamp,
  String level = 'ERROR',
  LogDomain domain = LogDomain.agentRuntime,
  String? subDomain,
  String message = 'wake failed',
  List<String> continuation = const [],
}) => LogRecord(
  timestamp: timestamp,
  level: level,
  domain: domain,
  subDomain: subDomain,
  message: message,
  continuation: continuation,
);

SlowQueryRecord slowQuery({
  required DateTime timestamp,
  double elapsedMs = 20,
  String statement = 'SELECT * FROM journal WHERE id = ?',
  String databaseName = 'db.sqlite',
  String operation = 'select',
  bool isSuperSlow = false,
  List<String> planRows = const [],
  List<String> stackFrames = const [],
  int? inFlightAtStart,
  int? openTransactionsAtStart,
}) => SlowQueryRecord(
  timestamp: timestamp,
  databaseName: databaseName,
  operation: operation,
  elapsedMs: elapsedMs,
  statement: statement,
  isSuperSlow: isSuperSlow,
  planRows: planRows,
  stackFrames: stackFrames,
  inFlightAtStart: inFlightAtStart,
  openTransactionsAtStart: openTransactionsAtStart,
);

// Model conformance with specs/tla/TaskFieldWrites.tla: one task on this
// device, a real in-memory JournalDb behind the real PersistenceLogic
// (updateTask), the real agent field tools (TaskStatusHandler,
// TaskTitleHandler, TaskPriorityHandler, all through writeTaskField) and the
// real ConflictResolutionService; the other device is a copy of the task
// that writes under its own host's clock and lands its versions here the
// way sync does (JournalDb.updateJournalEntity).
//
// The screen and the agent each take a copy of the task (Read) and set a
// field some steps later (UiWrite, AgentWrite): the status, the title or the
// priority. The other device writes on its own copy, which catches up with
// this device's row between steps; its versions land here as newer versions
// or, when this device wrote meanwhile, as concurrent ones (a conflict row;
// remoteStatusFork makes one likely by setting a status on the other
// device's copy and landing it at once),
// and a landing can be armed to happen right after a writer's read of the
// task — between the read and the write built on it. The user resolves an
// open conflict by keeping either side (Resolve); with none open, the other
// device first forks one.
//
// After every step the trace checks what the model does:
//   NoLostFieldEdit    every field holds the value the last write that won
//                      set, whoever wrote it — no write puts back a value
//                      it did not set
//   HistoryComplete    the status history records every status a write
//                      that won set
//   NoBlindAgentWrite  an agent tool sets its field only while the stored
//                      value is the one its copy held, and reports every
//                      other outcome as nothing applied

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/tools/task_status_handler.dart';
import 'package:lotti/features/agents/tools/task_title_handler.dart';
import 'package:lotti/features/ai/functions/task_priority_handler.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/state/conflict_resolution_service.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:path_provider/path_provider.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/path_provider.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

enum _FieldOp {
  screenRead,
  agentRead,
  screenStatus,
  screenTitle,
  screenPriority,
  agentStatus,
  agentTitle,
  agentPriority,
  remoteWrite,
  remoteStatusFork,
  land,
  catchUp,
  armLanding,
  resolveLocal,
  resolveRemote,
}

class _FieldStep {
  const _FieldStep(this.op, this.arg);

  factory _FieldStep.decode(int code) => _FieldStep(
    _FieldOp.values[code % _FieldOp.values.length],
    code ~/ _FieldOp.values.length,
  );

  final _FieldOp op;

  /// Picks the value a write sets, the field the other device writes, and
  /// for an armed landing the read it follows.
  final int arg;

  @override
  String toString() => '${op.name}($arg)';
}

const _maxArg = 12;

extension _AnyFieldTrace on glados.Any {
  glados.Generator<List<_FieldStep>> get fieldTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        14,
        glados.IntAnys(
          this,
        ).intInRange(0, _FieldOp.values.length * _maxArg),
      )
      .map((codes) => [for (final code in codes) _FieldStep.decode(code)]);
}

/// The statuses the screen sets, and the agent's (DONE is the user's
/// alone): none needs a reason.
const _statuses = ['OPEN', 'IN PROGRESS', 'DONE'];
const _agentStatuses = ['OPEN', 'IN PROGRESS', 'GROOMED'];
const _titles = ['Write the report', 'Send the report', 'File the report'];
const List<TaskPriority> _priorities = TaskPriority.values;

/// A [JournalDb] that can land the other device's version right after a
/// writer's read of the task — between the read and the write built on it.
class _RacingJournalDb extends JournalDb {
  _RacingJournalDb() : super(inMemoryDatabase: true);

  ({String id, int skip, Future<void> Function() land})? _armed;

  void disarm() => _armed = null;

  void arm(String id, int skip, Future<void> Function() land) =>
      _armed = (id: id, skip: skip, land: land);

  Future<JournalEntity?> peek(String id) => super.journalEntityById(id);

  @override
  Future<JournalEntity?> journalEntityById(String id) async {
    final read = await super.journalEntityById(id);
    final armed = _armed;
    if (armed != null && armed.id == id) {
      if (armed.skip == 0) {
        _armed = null;
        await armed.land();
      } else {
        _armed = (id: id, skip: armed.skip - 1, land: armed.land);
      }
    }
    return read;
  }
}

/// The fields the model's `val` holds, as the bench compares them.
typedef _Fields = ({String status, String title, TaskPriority priority});

_Fields _fieldsOf(TaskData data) => (
  status: data.status.toDbString,
  title: data.title,
  priority: data.priority,
);

class _FieldBench {
  _FieldBench(this.db);

  final _RacingJournalDb db;
  final PersistenceLogic persistence = getIt<PersistenceLogic>();
  final JournalRepository repository = JournalRepository();
  late final String taskId;

  /// Ghost: the fields as the last write that won set them.
  late _Fields expected;

  /// Ghost: the ids of the statuses a write that won set.
  final known = <String>{};

  /// The copies the screen and the agent read, and the other device's row.
  Task? _screen;
  Task? _agent;
  late Task _remote;

  /// Whether the other device wrote a version this device has not received.
  var _unsent = false;
  var _serial = 0;
  var _remoteCounter = 0;

  Future<void> setUp() async {
    final meta = await persistence.createMetadata();
    taskId = meta.id;
    await persistence.createDbEntity(
      testTask.copyWith(
        meta: meta,
        data: testTask.data.copyWith(
          checklistIds: const [],
          statusHistory: const [],
        ),
      ),
    );
    final stored = await _stored();
    expected = _fieldsOf(stored.data);
    // The screen and the agent hold the task as it was opened; the other
    // device has it as created.
    _screen = stored;
    _agent = stored;
    _remote = stored;
  }

  Future<Task> _stored() async => (await db.peek(taskId))! as Task;

  TaskStatus _status(String value) {
    final status = taskStatusFromString(value);
    return status.copyWith(
      createdAt: DateTime.utc(2026, 9, 27).add(Duration(minutes: ++_serial)),
    );
  }

  /// The other device sets one field on its own copy, under its own clock.
  void _remoteWrite(int arg) {
    final data = _remote.data;
    final next = switch (arg % 3) {
      0 => data.withStatus(_status(_statuses[arg % _statuses.length])),
      1 => data.copyWith(title: '${_titles[arg % _titles.length]} ($arg)'),
      _ => data.copyWith(priority: _priorities[arg % _priorities.length]),
    };
    if (next == data) return;
    _remote = _remote.copyWith(
      meta: _remote.meta.copyWith(
        updatedAt: _remote.meta.updatedAt.add(Duration(minutes: ++_serial)),
        vectorClock: VectorClock({
          ...?_remote.meta.vectorClock?.vclock,
          'other-device': ++_remoteCounter,
        }),
      ),
      data: next,
    );
    _unsent = true;
  }

  /// The other device's newest version lands here: newer applies, older is
  /// dropped, concurrent becomes a conflict row.
  Future<void> _land() async {
    if (!_unsent) return;
    _unsent = false;
    final before = await _stored();
    final result = await db.updateJournalEntity(_remote);
    if (result.applied) {
      // Newer by its clock: the other device had everything stored here.
      expect(
        known.difference(_historyIds(_remote.data)),
        isEmpty,
        reason: 'a newer version carries every status it saw',
      );
      expected = _fieldsOf(_remote.data);
      known
        ..clear()
        ..addAll(_historyIds(_remote.data));
    } else {
      expect(await _stored(), before, reason: 'a refused version is not kept');
    }
  }

  /// The other device receives this device's row, when it is newer.
  Future<void> _catchUp() async {
    final stored = await _stored();
    final status = VectorClock.compare(
      stored.meta.vectorClock ?? const VectorClock({}),
      _remote.meta.vectorClock ?? const VectorClock({}),
    );
    if (status == VclockStatus.a_gt_b) _remote = stored;
  }

  static Set<String> _historyIds(TaskData data) => {
    for (final status in data.statusHistory) status.id,
  };

  /// The screen sets a field through the write EntryController makes:
  /// [change] of the stored data, unless its copy already shows the value.
  Future<void> _screenWrite(
    bool Function(TaskData copy) unchanged,
    TaskData Function(TaskData stored) change,
    void Function(Task written) record,
  ) async {
    final copy = _screen;
    if (copy == null || unchanged(copy.data)) return;
    final written = await persistence.updateTask(
      journalEntityId: taskId,
      change: change,
    );
    expect(written, isNotNull);
    record(written!);
  }

  /// Runs an agent tool on its copy and checks it wrote exactly when the
  /// stored value — as the last write that won left it, a landing armed
  /// inside the call included — is still its copy's.
  Future<void> _agentWrite(
    Object Function(_Fields fields) field,
    Object Function(TaskData copy) copyValue,
    Object target,
    Future<bool> Function(Task copy) run,
    void Function() record,
  ) async {
    final copy = _agent;
    if (copy == null) return;
    final didWrite = await run(copy);
    final unchanged = field(expected) == copyValue(copy.data);
    final shouldWrite = unchanged && target != copyValue(copy.data);
    expect(
      didWrite,
      shouldWrite,
      reason:
          'NoBlindAgentWrite: the tool writes only over the value its '
          'copy held',
    );
    if (didWrite) record();
  }

  Future<void> run(_FieldStep step) async {
    final arg = step.arg;
    switch (step.op) {
      case _FieldOp.screenRead:
        _screen = await _stored();
      case _FieldOp.agentRead:
        _agent = await _stored();
      case _FieldOp.screenStatus:
        final value = _statuses[arg % _statuses.length];
        final next = _status(value);
        await _screenWrite(
          (copy) => copy.status.toDbString == value,
          (stored) => stored.withStatus(next),
          (written) {
            if (expected.status != value) known.add(next.id);
            expected = (
              status: value,
              title: expected.title,
              priority: expected.priority,
            );
          },
        );
      case _FieldOp.screenTitle:
        final value = '${_titles[arg % _titles.length]} (screen $arg)';
        await _screenWrite(
          (copy) => copy.title == value,
          (stored) => stored.copyWith(title: value),
          (_) => expected = (
            status: expected.status,
            title: value,
            priority: expected.priority,
          ),
        );
      case _FieldOp.screenPriority:
        final value = _priorities[arg % _priorities.length];
        await _screenWrite(
          (copy) => copy.priority == value,
          (stored) => stored.copyWith(priority: value),
          (_) => expected = (
            status: expected.status,
            title: expected.title,
            priority: value,
          ),
        );
      case _FieldOp.agentStatus:
        final value = _agentStatuses[arg % _agentStatuses.length];
        late TaskStatusHandler handler;
        await _agentWrite(
          (fields) => fields.status,
          (copy) => copy.status.toDbString,
          value,
          (copy) async {
            handler = TaskStatusHandler(
              task: copy,
              journalRepository: repository,
            );
            return (await handler.handle(value)).didWrite;
          },
          () {
            known.add(handler.task.data.status.id);
            expected = (
              status: value,
              title: expected.title,
              priority: expected.priority,
            );
          },
        );
      case _FieldOp.agentTitle:
        final value = '${_titles[arg % _titles.length]} (agent $arg)';
        await _agentWrite(
          (fields) => fields.title,
          (copy) => copy.title,
          value,
          (copy) async => (await TaskTitleHandler(
            task: copy,
            journalRepository: repository,
          ).handle(value)).didWrite,
          () => expected = (
            status: expected.status,
            title: value,
            priority: expected.priority,
          ),
        );
      case _FieldOp.agentPriority:
        final value = _priorities[arg % _priorities.length];
        await _agentWrite(
          (fields) => fields.priority,
          (copy) => copy.priority,
          value,
          (copy) async => (await TaskPriorityHandler(
            task: copy,
            journalRepository: repository,
          ).processToolCall(_priorityCall(value.short))).didWrite,
          () => expected = (
            status: expected.status,
            title: expected.title,
            priority: value,
          ),
        );
      case _FieldOp.remoteWrite:
        _remoteWrite(arg);
      case _FieldOp.remoteStatusFork:
        await _fork(arg);
      case _FieldOp.land:
        await _land();
      case _FieldOp.catchUp:
        await _catchUp();
      case _FieldOp.armLanding:
        // The other device writes on its copy of this row, and the version
        // lands right after the next read of the task — inside a writer's
        // read and write, when one follows.
        db.arm(taskId, arg % 2, () async {
          await _catchUp();
          _remoteWrite(arg);
          await _land();
        });
      case _FieldOp.resolveLocal:
        await _resolve(ConflictSide.local, arg);
      case _FieldOp.resolveRemote:
        await _resolve(ConflictSide.remote, arg);
    }
  }

  Future<List<Conflict>> _open() async => [
    for (final conflict in await db.conflictsForEntry(taskId))
      if (conflict.status == ConflictStatus.unresolved.index) conflict,
  ];

  /// The other device sets a status on the copy it has — without catching
  /// up first — and the version lands here at once: a conflict whenever
  /// this device wrote since, with two histories for a resolution to keep.
  Future<void> _fork(int arg) async {
    _remoteWrite(3 * arg);
    await _land();
  }

  /// The user keeps [side] of the oldest open conflict; with none open, the
  /// other device forks one first.
  Future<void> _resolve(ConflictSide side, int arg) async {
    if ((await _open()).isEmpty) await _fork(arg);
    final open = await _open();
    if (open.isEmpty) return;
    final remote = fromSerialized(open.last.serialized) as Task;
    final local = await _stored();
    final resolved = await ConflictResolutionService(
      persistenceLogic: persistence,
    ).keepSide(ConflictPair(local: local, remote: remote), side);
    expect(resolved, isTrue);
    final kept = side == ConflictSide.local ? local : remote;
    expected = _fieldsOf(kept.data);
    known.addAll(_historyIds(local.data).union(_historyIds(remote.data)));
  }

  /// The model's invariants, on the stored row.
  Future<void> check(List<_FieldStep> trace) async {
    final stored = await _stored();
    expect(
      _fieldsOf(stored.data),
      expected,
      reason: 'NoLostFieldEdit: $trace',
    );
    expect(
      known.difference(_historyIds(stored.data)),
      isEmpty,
      reason: 'HistoryComplete: $trace',
    );
  }
}

ChatCompletionMessageToolCall _priorityCall(String priority) =>
    ChatCompletionMessageToolCall(
      id: 'call_priority',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: 'update_task_priority',
        arguments: jsonEncode({'priority': priority}),
      ),
    );

/// Registers the TaskFieldWrites conformance group.
void registerTaskFieldWritesConformance() {
  group('TaskFieldWrites model conformance', () {
    final mockNotificationService = MockNotificationService();
    final mockUpdateNotifications = MockUpdateNotifications();
    final mockFts5Db = MockFts5Db();
    final mockOutboxService = MockOutboxService();

    late _RacingJournalDb db;
    late SettingsDb settingsDb;

    setUpAll(registerAllFallbackValues);

    setUp(() async {
      setFakeDocumentsPath();
      db = _RacingJournalDb();
      settingsDb = SettingsDb(inMemoryDatabase: true);
      await initConfigFlags(db, inMemoryDatabase: true);

      when(mockNotificationService.updateBadge).thenAnswer((_) async {});
      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => const Stream<Set<String>>.empty());
      when(
        () => mockFts5Db.insertText(any(), removePrevious: true),
      ).thenAnswer((_) async {});
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      final documentsDirectory = await getApplicationDocumentsDirectory();
      void put<T extends Object>(T instance) {
        if (getIt.isRegistered<T>()) getIt.unregister<T>();
        getIt.registerSingleton<T>(instance);
      }

      put<UpdateNotifications>(mockUpdateNotifications);
      put<Directory>(documentsDirectory);
      put<SettingsDb>(settingsDb);
      put<Fts5Db>(mockFts5Db);
      put<JournalDb>(db);
      put<OutboxService>(mockOutboxService);
      put<NotificationService>(mockNotificationService);
      put<VectorClockService>(VectorClockService());
      put<TimeService>(MockTimeService());
      put<NavService>(MockNavService());
      put<EntitiesCacheService>(MockEntitiesCacheService());
      put<DomainLogger>(DomainLogger(loggingService: LoggingService()));
      put<MetadataService>(
        MetadataService(vectorClockService: getIt<VectorClockService>()),
      );
      put<GeolocationService>(MockGeolocationService());
      put<PersistenceLogic>(PersistenceLogic());
    });

    tearDown(() async {
      await db.close();
      await settingsDb.close();
    });

    Future<void> replay(List<_FieldStep> trace) async {
      final bench = _FieldBench(db..disarm());
      await bench.setUp();
      await bench.check(trace);
      for (final step in trace) {
        await bench.run(step);
        await bench.check(trace);
      }
      db.disarm();
    }

    // The shortest traces the three fixes answer, as glados shrank them with
    // each fix reverted.
    test('an agent tool never sets a field over a value it did not read '
        '(NoBlindAgentWrite)', () async {
      await replay(const [
        _FieldStep(_FieldOp.armLanding, 10),
        _FieldStep(_FieldOp.agentRead, 3),
        _FieldStep(_FieldOp.agentTitle, 4),
      ]);
    });

    test('a write never puts back a field a version stored meanwhile set '
        '(NoLostFieldEdit)', () async {
      await replay(const [
        _FieldStep(_FieldOp.armLanding, 10),
        _FieldStep(_FieldOp.agentRead, 3),
        _FieldStep(_FieldOp.agentStatus, 4),
      ]);
    });

    test("keeping the other device's side keeps this device's statuses in "
        'the history (HistoryComplete)', () async {
      await replay(const [
        _FieldStep(_FieldOp.screenStatus, 4),
        _FieldStep(_FieldOp.remoteWrite, 7),
        _FieldStep(_FieldOp.resolveRemote, 2),
      ]);
    });

    glados.Glados(
      glados.any.fieldTrace,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'the screen, the agent and another device never put back a field '
      'another writer set, and every status set is in the history',
      replay,
      timeout: const Timeout(Duration(minutes: 4)),
      tags: 'glados',
    );
  });
}

part of 'checklist_repository_test.dart';

// Model conformance with specs/tla/ChecklistReplication.tla: one task's
// checklists on two devices, each a real in-memory JournalDb and SettingsDb
// behind its own real ChecklistRepository. The devices' users add, move,
// check and delete items, add and delete checklists and edit the task; every
// row version one device stores is sent to the other and delivered in a
// generated order, through the real write decision
// (JournalDb.updateJournalEntity) and the receive hook the sync processor
// runs (ChecklistRepository.settleReceived); the user resolves conflicts
// with the real ConflictResolutionService; and a start replays what a device
// recorded. A device's clock is its own, as MetadataService stamps it.
//
// After every step the trace checks, on each device, that no item is shown
// by two of the task's checklists (ShownOnce) and that no list names an id
// twice (NoDuplicates). Once every version has arrived and every conflict is
// resolved: every live item is shown by the checklist it names
// (NoLostItem), names a live checklist (NoOrphanItem), every live checklist
// is on the task (NoLostChecklist), and both devices show the same
// checklists and items in the same order (NeverSilent).

enum _ReplicaChecklistOp {
  addItem,
  addDerivedItem,
  move,
  check,
  dropItem,
  addList,
  dropList,
  taskEdit,
  resolve,
  deliver,
  replay,
}

class _ReplicaChecklistStep {
  const _ReplicaChecklistStep(this.op, this.device, this.arg);

  factory _ReplicaChecklistStep.decode(int code) => _ReplicaChecklistStep(
    _ReplicaChecklistOp.values[code % _ReplicaChecklistOp.values.length],
    (code ~/ _ReplicaChecklistOp.values.length) % 2,
    code ~/ (_ReplicaChecklistOp.values.length * 2),
  );

  final _ReplicaChecklistOp op;
  final int device;

  /// Picks the checklist, the item, the delivery or the side kept.
  final int arg;

  @override
  String toString() => '${op.name}(d$device, $arg)';
}

extension _AnyReplicaChecklistTrace on glados.Any {
  glados.Generator<List<_ReplicaChecklistStep>> get replicaChecklistTrace =>
      glados.ListAnys(this)
          .listWithLengthInRange(
            1,
            16,
            glados.IntAnys(
              this,
            ).intInRange(0, _ReplicaChecklistOp.values.length * 2 * 12),
          )
          .map(
            (codes) => [
              for (final code in codes) _ReplicaChecklistStep.decode(code),
            ],
          );
}

/// User operations per trace, as the model bounds them (`MaxOps`), plus
/// some: traces are shorter than the model's exhaustive search.
const _maxReplicaOps = 6;

/// A device's persistence: its own clock, stamped as MetadataService stamps
/// it, and every write through its own write decision. What it stores is
/// sent to the other device.
class _ReplicaPersistence extends Fake implements PersistenceLogic {
  _ReplicaPersistence(this.device);

  final _ReplicaDevice device;

  VectorClock _next(VectorClock? base) => VectorClock({
    ...?base?.vclock,
    device.host: ++device.counter,
  });

  @override
  Future<Metadata> createMetadata({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? uuidV5Input,
    bool? private,
    List<String>? labelIds,
    String? categoryId,
    bool? starred,
    EntryFlag? flag,
    String? id,
  }) async => Metadata(
    id:
        id ??
        (uuidV5Input != null
            ? MetadataService.deterministicId(uuidV5Input)
            : '${device.host}-${++device.serial}'),
    createdAt: _replicaDate,
    updatedAt: _replicaDate,
    dateFrom: _replicaDate.add(Duration(minutes: device.serial)),
    dateTo: _replicaDate,
    vectorClock: _next(null),
  );

  @override
  Future<Metadata> updateMetadata(
    Metadata metadata, {
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? deletedAt,
    List<String>? labelIds,
    bool clearLabelIds = false,
  }) async => metadata.copyWith(
    vectorClock: _next(metadata.vectorClock),
    deletedAt: deletedAt ?? metadata.deletedAt,
  );

  @override
  Future<bool?> createDbEntity(
    JournalEntity journalEntity, {
    bool shouldAddGeolocation = true,
    bool enqueueSync = true,
    String? linkedId,
    bool linkCollapsed = false,
  }) => device.write(journalEntity);

  @override
  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    String? linkedId,
    bool enqueueSync = true,
    Future<void> Function()? beforeNotify,
    Future<bool> Function()? precondition,
  }) async {
    if (precondition != null && !await precondition()) return false;
    return device.write(journalEntity);
  }

  /// A conflict's resolution: the merged clock plus this device's next
  /// counter.
  @override
  Future<bool> updateJournalEntity(
    JournalEntity journalEntity,
    Metadata metadata, {
    Future<bool> Function()? precondition,
  }) async => device.write(
    journalEntity.copyWith(
      meta: metadata.copyWith(vectorClock: _next(metadata.vectorClock)),
    ),
  );
}

final _replicaDate = DateTime(2024, 3, 15, 9);

class _ReplicaDevice {
  _ReplicaDevice(this.index, this.bench)
    : host = 'host-$index',
      db = JournalDb(inMemoryDatabase: true),
      settings = SettingsDb(inMemoryDatabase: true);

  final int index;
  final _ReplicaChecklistBench bench;
  final String host;
  final JournalDb db;
  final SettingsDb settings;
  late final _ReplicaPersistence persistence = _ReplicaPersistence(this);
  late final ChecklistRepository repository;
  final vectorClock = MockVectorClockService();
  int counter = 0;
  int serial = 0;

  /// Sent versions this device has received, by index.
  final received = <int>{};

  /// The write decision; a stored version is sent.
  Future<bool> write(JournalEntity version) async {
    final result = await db.updateJournalEntity(version);
    if (result.applied) {
      bench.sent.add((
        from: index,
        version: (await db.journalEntityByIdIncludingDeleted(version.id))!,
      ));
    }
    return result.applied;
  }

  Future<void> close() async {
    await db.close();
    await settings.close();
  }
}

class _ReplicaChecklistBench {
  _ReplicaChecklistBench() {
    devices = [_ReplicaDevice(0, this), _ReplicaDevice(1, this)];
  }

  late final List<_ReplicaDevice> devices;
  final sent = <({int from, JournalEntity version})>[];
  late final String taskId;
  var _ops = 0;
  var _derived = 0;

  /// Points GetIt at [device], as the process running on it sees it.
  void use(_ReplicaDevice device) {
    void put<T extends Object>(T instance) {
      if (getIt.isRegistered<T>()) getIt.unregister<T>();
      getIt.registerSingleton<T>(instance);
    }

    put<JournalDb>(device.db);
    put<SettingsDb>(device.settings);
    put<PersistenceLogic>(device.persistence);
    put<VectorClockService>(device.vectorClock);
  }

  Future<void> setUp() async {
    for (final device in devices) {
      when(device.vectorClock.getHost).thenAnswer((_) async => device.host);
      await initConfigFlags(device.db, inMemoryDatabase: true);
      use(device);
      device.repository = ChecklistRepository(
        intents: ChecklistMembershipIntents(settingsDb: device.settings),
      );
    }
    // The task with two checklists and an item in the first, on both
    // devices — the model's `Initial` and `Seeded`.
    const clock = VectorClock({'origin': 1});
    final task = testTask.copyWith(
      meta: testTask.meta.copyWith(id: 'task', vectorClock: clock),
      data: testTask.data.copyWith(checklistIds: const ['first', 'second']),
    );
    taskId = task.id;
    Checklist checklist(String id, List<String> items) => Checklist(
      meta: task.meta.copyWith(id: id),
      data: ChecklistData(
        title: id,
        linkedChecklistItems: items,
        linkedTasks: [task.id],
      ),
    );
    final seed = ChecklistItem(
      meta: task.meta.copyWith(id: 'seed'),
      data: const ChecklistItemData(
        title: 'Seed',
        isChecked: false,
        linkedChecklists: ['first'],
      ),
    );
    for (final device in devices) {
      for (final entity in [
        task,
        checklist('first', const ['seed']),
        checklist('second', const []),
        seed,
      ]) {
        await device.db.updateJournalEntity(entity);
      }
    }
  }

  Future<void> close() async {
    for (final device in devices) {
      await device.close();
    }
  }

  Future<List<Checklist>> _shownLists(_ReplicaDevice device) async {
    final task = await device.db.journalEntityById(taskId);
    if (task is! Task) return const [];
    return [
      for (final id in task.data.checklistIds ?? const <String>[])
        if (await device.db.journalEntityById(id) case final Checklist c) c,
    ];
  }

  Future<Map<String, List<ChecklistItem>>> _shown(
    _ReplicaDevice device,
  ) async => readShownChecklistItems(device.db, await _shownLists(device));

  /// What [device] shows: its checklists in order, each with its items.
  Future<List<String>> view(_ReplicaDevice device) async {
    final shown = await _shown(device);
    return [
      for (final checklist in await _shownLists(device))
        '${checklist.id}: ${[for (final item in shown[checklist.id] ?? const <ChecklistItem>[]) item.id]}',
    ];
  }

  List<int> _pendingFor(_ReplicaDevice device) => [
    for (var i = 0; i < sent.length; i++)
      if (sent[i].from != device.index && !device.received.contains(i)) i,
  ];

  /// Sync applies one version, then what storing it leaves to do.
  Future<void> _deliver(_ReplicaDevice device, int index) async {
    device.received.add(index);
    use(device);
    final version = sent[index].version;
    final result = await device.db.updateJournalEntity(version);
    if (result.applied) await device.repository.settleReceived(version);
  }

  Future<List<(JournalEntity, JournalEntity)>> _openConflicts(
    _ReplicaDevice device,
  ) async {
    final open = <(JournalEntity, JournalEntity)>[];
    final rows = await device.db
        .customSelect(
          'SELECT DISTINCT id FROM conflicts WHERE status = ?',
          variables: [Variable.withInt(ConflictStatus.unresolved.index)],
        )
        .get();
    for (final row in rows) {
      final id = row.read<String>('id');
      final local = await device.db.journalEntityByIdIncludingDeleted(id);
      if (local == null) continue;
      for (final conflict in await device.db.conflictsForEntry(id)) {
        if (conflict.status != ConflictStatus.unresolved.index) continue;
        open.add((
          local,
          JournalEntity.fromJson(
            jsonDecode(conflict.serialized) as Map<String, dynamic>,
          ),
        ));
      }
    }
    return open;
  }

  Future<void> _resolve(_ReplicaDevice device, int arg) async {
    final open = await _openConflicts(device);
    if (open.isEmpty) return;
    final (local, remote) = open[(arg ~/ 2) % open.length];
    use(device);
    await ConflictResolutionService(
      persistenceLogic: device.persistence,
      checklistRepository: device.repository,
    ).keepSide(
      ConflictPair(local: local, remote: remote),
      arg.isEven ? ConflictSide.local : ConflictSide.remote,
    );
  }

  Future<void> run(_ReplicaChecklistStep step) async {
    final device = devices[step.device];
    final arg = step.arg;
    final repository = device.repository;
    final userOp = step.op.index <= _ReplicaChecklistOp.taskEdit.index;
    if (userOp && _ops >= _maxReplicaOps) return;
    use(device);
    final lists = await _shownLists(device);
    final shown = await _shown(device);
    final items = [
      for (final checklist in lists)
        for (final item in shown[checklist.id] ?? const <ChecklistItem>[])
          (checklist.id, item.id),
    ];
    switch (step.op) {
      case _ReplicaChecklistOp.addItem || _ReplicaChecklistOp.addDerivedItem:
        if (lists.isEmpty) return;
        _ops++;
        final derived = step.op == _ReplicaChecklistOp.addDerivedItem;
        // A derived id is the migration handler's copy: both devices may
        // create it, each in the checklist it sees first.
        await repository.addItemToChecklist(
          checklistId: lists[arg % lists.length].id,
          title: 'Item $arg',
          isChecked: false,
          categoryId: null,
          uuidV5Input: derived ? 'copy-${_derived++ % 2}' : null,
        );
      case _ReplicaChecklistOp.move:
        if (items.isEmpty || lists.length < 2) return;
        _ops++;
        final (from, itemId) = items[arg % items.length];
        final targets = [
          for (final list in lists)
            if (list.id != from) list.id,
        ];
        await repository.moveItem(
          itemId: itemId,
          fromId: from,
          toId: targets[(arg ~/ items.length) % targets.length],
          taskId: taskId,
        );
      case _ReplicaChecklistOp.check:
        if (items.isEmpty) return;
        _ops++;
        await repository.updateChecklistItem(
          checklistItemId: items[arg % items.length].$2,
          change: (stored) => stored.copyWith(isChecked: !stored.isChecked),
          taskId: taskId,
        );
      case _ReplicaChecklistOp.dropItem:
        if (items.isEmpty) return;
        _ops++;
        final (checklistId, itemId) = items[arg % items.length];
        await _withoutUndoTimer(() async {
          final key = await repository.beginItemDeletion(
            itemId: itemId,
            checklistId: checklistId,
            undoWindow: _undoWindow,
          );
          await repository.completeItemDeletion(key: key!, itemId: itemId);
        });
      case _ReplicaChecklistOp.addList:
        _ops++;
        await repository.createChecklist(taskId: taskId);
      case _ReplicaChecklistOp.dropList:
        if (lists.isEmpty) return;
        _ops++;
        await repository.deleteChecklist(
          checklistId: lists[arg % lists.length].id,
          taskId: taskId,
        );
      case _ReplicaChecklistOp.taskEdit:
        // A task field saved on the stored task: a new version of it.
        _ops++;
        await repository.updateTaskChecklistIds(
          taskId: taskId,
          change: (ids) => ids,
          restate: true,
        );
      case _ReplicaChecklistOp.resolve:
        await _resolve(device, arg);
      case _ReplicaChecklistOp.deliver:
        final pending = _pendingFor(device);
        if (pending.isEmpty) return;
        await _deliver(device, pending[arg % pending.length]);
      case _ReplicaChecklistOp.replay:
        await repository.replayMembershipIntents();
    }
  }

  /// Delivers everything, resolves every conflict — keeping each device's
  /// side in turn — and replays what is left, until nothing moves.
  Future<void> settle() async {
    for (var round = 0; round < 8; round++) {
      for (final device in devices) {
        for (final index in _pendingFor(device)) {
          await _deliver(device, index);
        }
      }
      var resolved = false;
      for (final device in devices) {
        if ((await _openConflicts(device)).isNotEmpty) {
          await _resolve(device, round);
          resolved = true;
          break;
        }
      }
      for (final device in devices) {
        use(device);
        await device.repository.replayMembershipIntents();
      }
      if (!resolved && devices.every((d) => _pendingFor(d).isEmpty)) return;
    }
  }

  Future<void> checkStep(Object trace) async {
    for (final device in devices) {
      final host = device.host;
      final shown = await _shown(device);
      final placements = <String, List<String>>{};
      for (final MapEntry(key: checklistId, value: items) in shown.entries) {
        for (final item in items) {
          placements.putIfAbsent(item.id, () => []).add(checklistId);
        }
      }
      for (final MapEntry(key: item, value: where) in placements.entries) {
        expect(
          where,
          hasLength(1),
          reason: 'ShownOnce on $host ($item in $where): $trace',
        );
      }
      final task = (await device.db.journalEntityById(taskId))! as Task;
      final taskIds = task.data.checklistIds ?? const <String>[];
      expect(
        taskIds.toSet(),
        hasLength(taskIds.length),
        reason: 'NoDuplicates on $host (task $taskIds): $trace',
      );
      for (final checklist in await _checklists(device)) {
        final listed = checklist.data.linkedChecklistItems;
        expect(
          listed.toSet(),
          hasLength(listed.length),
          reason: 'NoDuplicates on $host (${checklist.id} $listed): $trace',
        );
      }
    }
  }

  Future<List<Checklist>> _checklists(_ReplicaDevice device) async => [
    for (final row
        in await device.db
            .customSelect(
              "SELECT id FROM journal WHERE type = 'Checklist' "
              'AND deleted = FALSE',
            )
            .get())
      if (await device.db.journalEntityById(row.read<String>('id'))
          case final Checklist checklist)
        checklist,
  ];

  Future<void> checkSettled(Object trace) async {
    // settle() resolves every conflict it meets; one left means it did not
    // finish, and the invariants below would go unchecked.
    for (final device in devices) {
      expect(
        await _openConflicts(device),
        isEmpty,
        reason: 'settled with a conflict open on ${device.host}: $trace',
      );
    }
    final views = [for (final device in devices) await view(device)];
    expect(views.first, views.last, reason: 'NeverSilent: $trace');
    for (final device in devices) {
      final host = device.host;
      final task = (await device.db.journalEntityById(taskId))! as Task;
      final taskIds = task.data.checklistIds ?? const <String>[];
      final live = await _checklists(device);
      for (final checklist in live) {
        expect(
          taskIds,
          contains(checklist.id),
          reason: 'NoLostChecklist on $host (${checklist.id}): $trace',
        );
      }
      final shown = await _shown(device);
      for (final item in await device.db.checklistItemsNaming([
        for (final checklist in live) checklist.id,
      ])) {
        final home = item.data.linkedChecklists.first;
        expect(
          shown[home]?.map((i) => i.id),
          contains(item.id),
          reason: 'NoLostItem on $host (${item.id} in $home): $trace',
        );
      }
      final orphans = await device.db
          .customSelect(
            'SELECT i.id FROM journal i JOIN journal c '
            r"ON c.id = json_extract(i.serialized, '$.data.linkedChecklists[0]') "
            "WHERE i.type = 'ChecklistItem' AND i.deleted = FALSE "
            'AND c.deleted = TRUE',
          )
          .get();
      expect(
        orphans.map((row) => row.read<String>('id')),
        isEmpty,
        reason: 'NoOrphanItem on $host: $trace',
      );
    }
  }
}

void _registerChecklistReplicationConformance() {
  group('checklist replication (specs/tla/ChecklistReplication.tla)', () {
    final mockNotificationService = MockNotificationService();
    final mockUpdateNotifications = MockUpdateNotifications();

    setUpAll(registerAllFallbackValues);

    setUp(() async {
      setFakeDocumentsPath();
      when(mockNotificationService.updateBadge).thenAnswer((_) async {});
      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => const Stream<Set<String>>.empty());
      void put<T extends Object>(T instance) {
        if (getIt.isRegistered<T>()) getIt.unregister<T>();
        getIt.registerSingleton<T>(instance);
      }

      put<UpdateNotifications>(mockUpdateNotifications);
      put<Directory>(await getApplicationDocumentsDirectory());
      put<NotificationService>(mockNotificationService);
      put<TimeService>(MockTimeService());
      put<DomainLogger>(DomainLogger(loggingService: LoggingService()));
    });

    glados.Glados(
      glados.any.replicaChecklistTrace,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'two devices adding, moving, checking and deleting items and '
      'checklists, with every row delivered on its own in any order, show '
      'each item once and converge on what they show',
      (trace) async {
        final bench = _ReplicaChecklistBench();
        await bench.setUp();
        try {
          await bench.checkStep(trace);
          for (final step in trace) {
            await bench.run(step);
            await bench.checkStep(trace);
          }
          await bench.settle();
          await bench.checkStep(trace);
          await bench.checkSettled(trace);
        } finally {
          await bench.close();
        }
      },
      timeout: const Timeout(Duration(minutes: 6)),
      tags: 'glados',
    );
  });
}

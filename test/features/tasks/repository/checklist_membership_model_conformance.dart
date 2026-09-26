part of 'checklist_repository_test.dart';

// Model conformance with specs/tla/ChecklistMembership.tla: one task with up
// to three checklists on one device, a real in-memory JournalDb and
// SettingsDb behind the real ChecklistRepository, PersistenceLogic.updateTask
// (updateTaskImpl) and JournalRepository.updateJournalEntity.
//
// The screen writes from a copy it took earlier — its lists (add, reorder),
// its items (check: uiCheck), a move between two checklists it shows
// (uiMove), an item deletion across its undo window (uiDropItem), a checklist
// deletion (uiDelete) and a task field edit of the stale TaskData
// (uiTaskEdit). The agent adds items (agAdd), creates a checklist (agList),
// renames an item (agCheck) and edits the task from a stale copy
// (agTaskEdit). Sync lands newer versions from another device — between
// steps, or armed to land right after a writer has read the row it is about
// to write, the interleaving the model splits every operation at; the agent,
// as the other process on this device, can be armed the same way (its add or
// its new checklist lands between another writer's read and write). And the app
// dies part-way through a multi-row operation (Crash): its intent is
// recorded, only a prefix of its writes happen, and the next start replays
// what was recorded (Replay, Restart).
//
// After every step — each one quiet, a crash included once replayed — the
// trace checks NoDuplicates, NoLostItem, NoStrayItem, BackLinkAgrees and
// NoLostChecklist, that a deleted item or checklist stays deleted, and that
// the task's items as the reader resolves them (getChecklistItemsForTask)
// are the ones listed.

enum _MembershipOp {
  snapshot,
  agentAdd,
  screenAdd,
  screenReorder,
  screenCheck,
  agentCheck,
  screenMove,
  screenDeleteItem,
  deleteChecklist,
  taskEdit,
  agentTaskEdit,
  createChecklist,
  syncItem,
  syncChecklist,
  armSyncItem,
  armSyncChecklist,
  armAgentItem,
  armAgentChecklist,
  crash,
}

class _MembershipStep {
  const _MembershipStep(this.op, this.arg);

  factory _MembershipStep.decode(int code) => _MembershipStep(
    _MembershipOp.values[code % _MembershipOp.values.length],
    code ~/ _MembershipOp.values.length,
  );

  final _MembershipOp op;

  /// Picks the checklist, the item, for an armed landing the read it
  /// follows, and for a crash the operation and how far it got.
  final int arg;

  @override
  String toString() => '${op.name}($arg)';
}

/// The undo window of an item deletion. The trace decides when it closes —
/// completing or undoing the deletion itself, or crashing inside it — so the
/// window's own timer never runs ([_withoutUndoTimer]).
const _undoWindow = Duration(days: 1);

/// A timer that never fires.
class _UnstartedTimer implements Timer {
  @override
  void cancel() {}

  @override
  bool get isActive => false;

  @override
  int get tick => 0;
}

/// Runs [body] with the undo window's timer left unstarted, and every other
/// timer as usual.
Future<T> _withoutUndoTimer<T>(Future<T> Function() body) => runZoned(
  body,
  zoneSpecification: ZoneSpecification(
    createTimer: (self, parent, zone, duration, callback) =>
        duration == _undoWindow
        ? _UnstartedTimer()
        : parent.createTimer(zone, duration, callback),
  ),
);

/// The range of [_MembershipStep.arg].
const _maxArg = 24;

extension _AnyMembershipTrace on glados.Any {
  glados.Generator<List<_MembershipStep>> get membershipTrace =>
      glados.ListAnys(this)
          .listWithLengthInRange(
            1,
            12,
            glados.IntAnys(
              this,
            ).intInRange(0, _MembershipOp.values.length * _maxArg),
          )
          .map(
            (codes) => [for (final code in codes) _MembershipStep.decode(code)],
          );
}

/// The model's bounds, per trace: `Lists` and `Items` (created by any
/// writer), and `MaxReceives`.
const _maxChecklists = 3;
const _maxItems = 5;
const _maxReceives = 3;

/// A [JournalDb] that can land a sync version right after a writer's read
/// of a row — between the read and the write built on it, where the model
/// splits every operation.
class _RacingJournalDb extends JournalDb {
  _RacingJournalDb() : super(inMemoryDatabase: true);

  ({String id, int skip, Future<void> Function() land})? _armed;

  bool get armed => _armed != null;

  /// Drops a landing no read triggered — the trace that armed it is over.
  void disarm() => _armed = null;

  /// Lands [land] after the read of [id] that follows [skip] others.
  void arm(String id, int skip, Future<void> Function() land) =>
      _armed = (id: id, skip: skip, land: land);

  /// The stored row, read without landing anything.
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

class _MembershipBench {
  _MembershipBench(this.db);

  final _RacingJournalDb db;
  final repository = ChecklistRepository();
  final intents = ChecklistMembershipIntents();
  final PersistenceLogic persistence = getIt<PersistenceLogic>();
  late final String taskId;

  /// Ghost: the live checklists, the task's first one first.
  final live = <String>[];

  /// Ghost: the checklists deleted.
  final deletedLists = <String>{};

  /// Ghost (`home`): the checklist each live item was last put into — once
  /// a move is recorded, its target.
  final home = <String, String>{};

  /// Ghost: the items deleted.
  final deletedItems = <String>{};

  /// The screen's copies: the task, its checklists and their items as last
  /// read or written.
  Task? _screenTask;
  final _screenLists = <String, ChecklistData>{};
  final _screenItems = <String, ChecklistItemData>{};

  var _receives = 0;
  var _checklistsMade = 0;
  var _itemsMade = 0;
  var _serial = 0;
  var _remoteCounter = 0;

  Future<void> setUp() async {
    final meta = await persistence.createMetadata();
    taskId = meta.id;
    await persistence.createDbEntity(
      testTask.copyWith(
        meta: meta,
        data: testTask.data.copyWith(checklistIds: const []),
      ),
    );
    final created = await repository.createChecklist(taskId: taskId);
    live.add(created.checklist!.meta.id);
    _checklistsMade++;
    await _snapshot();
  }

  Future<Task> _storedTask() async => (await db.peek(taskId))! as Task;

  Future<Checklist> _storedList(String id) async =>
      (await db.peek(id))! as Checklist;

  Future<ChecklistItem> _storedItem(String id) async =>
      (await db.peek(id))! as ChecklistItem;

  String _nextTitle(String what) => '$what ${++_serial}';

  /// A version another device writes after it has everything stored here:
  /// the stored clock plus the other device's next counter.
  Metadata _remoteMeta(Metadata base) => base.copyWith(
    updatedAt: base.updatedAt.add(Duration(minutes: ++_serial)),
    vectorClock: VectorClock({
      ...?base.vectorClock?.vclock,
      'other-device': ++_remoteCounter,
    }),
  );

  bool get _itemsLeft => _itemsMade < _maxItems;
  bool get _checklistsLeft => _checklistsMade < _maxChecklists;
  bool get _receivesLeft => _receives < _maxReceives;

  /// Sync lands a new item and the version of [checklistId] listing it.
  Future<void> _landItem(String checklistId) async {
    // A landing armed on a checklist deleted since has nothing to land on.
    if (!live.contains(checklistId)) return;
    _receives++;
    _itemsMade++;
    final stored = await _storedList(checklistId);
    final itemId = 'synced-item-${++_serial}-$taskId';
    final item = ChecklistItem(
      meta: _remoteMeta(stored.meta).copyWith(id: itemId),
      data: ChecklistItemData(
        title: _nextTitle('synced item'),
        isChecked: false,
        linkedChecklists: [checklistId],
      ),
    );
    final itemResult = await db.updateJournalEntity(item);
    final listResult = await db.updateJournalEntity(
      stored.copyWith(
        meta: _remoteMeta(stored.meta),
        data: stored.data.copyWith(
          linkedChecklistItems: withMember(
            stored.data.linkedChecklistItems,
            itemId,
          ),
        ),
      ),
    );
    expect(itemResult.applied && listResult.applied, isTrue);
    home[itemId] = checklistId;
  }

  /// Sync lands a new checklist and the version of the task listing it.
  Future<void> _landChecklist() async {
    _receives++;
    _checklistsMade++;
    final stored = await _storedTask();
    final checklistId = 'synced-checklist-${++_serial}-$taskId';
    final checklist = Checklist(
      meta: _remoteMeta(stored.meta).copyWith(id: checklistId),
      data: ChecklistData(
        title: _nextTitle('synced checklist'),
        linkedChecklistItems: const [],
        linkedTasks: [taskId],
      ),
    );
    final listResult = await db.updateJournalEntity(checklist);
    final taskResult = await db.updateJournalEntity(
      stored.copyWith(
        meta: _remoteMeta(stored.meta),
        data: stored.data.copyWith(
          checklistIds: withMember(
            stored.data.checklistIds ?? const [],
            checklistId,
          ),
        ),
      ),
    );
    expect(listResult.applied && taskResult.applied, isTrue);
    live.add(checklistId);
  }

  /// The screen (re-)reads the task, its checklists and their items.
  Future<void> _snapshot() async {
    _screenTask = await _storedTask();
    _screenLists.clear();
    _screenItems.clear();
    for (final id in live) {
      final data = (await _storedList(id)).data;
      _screenLists[id] = data;
      for (final itemId in data.linkedChecklistItems) {
        final item = await db.peek(itemId);
        if (item is ChecklistItem) _screenItems[itemId] = item.data;
      }
    }
  }

  /// The screen publishes the stored [checklistId] as its state.
  Future<void> _publishList(String checklistId) async =>
      _screenLists[checklistId] = (await _storedList(checklistId)).data;

  /// The checklists the screen shows.
  List<String> get _shownLists => [
    for (final id in live)
      if (_screenLists.containsKey(id)) id,
  ];

  /// A checklist the screen shows, and the items it shows in it.
  ({String id, List<String> items})? _shown(int arg) {
    final shown = _shownLists;
    if (shown.isEmpty) return null;
    final id = shown[arg % shown.length];
    return (id: id, items: _screenLists[id]!.linkedChecklistItems);
  }

  /// A checklist the screen shows, and a live item it shows in it.
  ({String checklistId, String itemId})? _shownItem(int arg) {
    final shown = _shown(arg);
    if (shown == null) return null;
    final items = [
      for (final id in shown.items)
        if (home.containsKey(id) && _screenItems.containsKey(id)) id,
    ];
    if (items.isEmpty) return null;
    final itemId = items[(arg ~/ 2) % items.length];
    // The screen's copy of a list lags only additions: an item leaves a list
    // by the screen's own writes, which it publishes, or by a replay, after
    // which it reloads.
    expect(home[itemId], shown.id, reason: 'the screen shows $itemId');
    return (checklistId: shown.id, itemId: itemId);
  }

  Future<void> run(_MembershipStep step) async {
    final arg = step.arg;
    final target = live[arg % live.length];
    switch (step.op) {
      case _MembershipOp.snapshot:
        await _snapshot();
      case _MembershipOp.agentAdd:
        if (!_itemsLeft) return;
        await _agentAdd(target);
      case _MembershipOp.screenAdd:
        // ChecklistController.createChecklistItem.
        final shown = _shown(arg);
        if (shown == null || !_itemsLeft) return;
        _itemsMade++;
        final item = await repository.addItemToChecklist(
          checklistId: shown.id,
          title: _nextTitle('screen item'),
          isChecked: false,
          categoryId: null,
        );
        expect(item, isNotNull, reason: 'addItemToChecklist(${shown.id})');
        home[item!.meta.id] = shown.id;
        _screenItems[item.meta.id] = item.data;
        await _publishList(shown.id);
      case _MembershipOp.screenReorder:
        // ChecklistController.updateItemOrder, with an item dragged to the
        // top of the order the screen shows.
        final shown = _shown(arg);
        if (shown == null || shown.items.length < 2) return;
        final moved = shown.items[(arg ~/ 2) % shown.items.length];
        final visible = [moved, ...withoutMember(shown.items, moved)];
        await _screenWrite(shown.id, (ids) => inVisibleOrder(ids, visible));
      case _MembershipOp.screenCheck:
        // ChecklistItemController.updateChecked, from the item as the
        // screen last read it — perhaps before a move.
        final shown = _shownItem(arg);
        if (shown == null) return;
        final copy = _screenItems[shown.itemId]!;
        final written = await repository.updateChecklistItem(
          checklistItemId: shown.itemId,
          taskId: taskId,
          change: (stored) => stored.copyWith(
            isChecked: !copy.isChecked,
            checkedBy: ChangeSource.user,
          ),
        );
        expect(written, isNotNull, reason: 'check ${shown.itemId}');
        _screenItems[shown.itemId] = written!.data;
      case _MembershipOp.agentCheck:
        // The agent's checklist update tool renames an item.
        final items = home.keys.toList();
        if (items.isEmpty) return;
        final itemId = items[arg % items.length];
        final title = _nextTitle('agent title');
        final written = await repository.updateChecklistItem(
          checklistItemId: itemId,
          taskId: taskId,
          change: (stored) => stored.copyWith(title: title),
        );
        expect(written?.data.title, title, reason: 'rename $itemId');
      case _MembershipOp.screenMove:
        // ChecklistController.dropChecklistItem across two checklists the
        // screen shows.
        final shown = _shownItem(arg);
        if (shown == null) return;
        final others = [
          for (final id in _shownLists)
            if (id != shown.checklistId) id,
        ];
        if (others.isEmpty) return;
        final to = others[(arg ~/ 4) % others.length];
        final itemId = shown.itemId;
        final moved = await repository.moveItem(
          itemId: itemId,
          fromId: shown.checklistId,
          toId: to,
          taskId: taskId,
          place: arg.isEven
              ? null
              : (ids) => [itemId, ...withoutMember(ids, itemId)],
        );
        expect(moved, isNotNull, reason: 'moveItem($itemId to $to)');
        home[itemId] = to;
        _screenLists[to] = moved!.data;
        await _publishList(shown.checklistId);
        _screenItems[itemId] = (await _storedItem(itemId)).data;
      case _MembershipOp.screenDeleteItem:
        // ChecklistItemRow's swipe: the item is unlisted at once, and
        // deleted when the undo window closes (completeItemDeletion, as the
        // window's timer calls it) — or listed again on undo.
        final shown = _shownItem(arg);
        if (shown == null) return;
        final (:checklistId, :itemId) = shown;
        final key = await _withoutUndoTimer(
          () => repository.beginItemDeletion(
            itemId: itemId,
            checklistId: checklistId,
            undoWindow: _undoWindow,
          ),
        );
        expect(key, isNotNull, reason: 'beginItemDeletion($itemId)');
        await _publishList(checklistId);
        if ((arg ~/ 4).isEven) {
          await repository.completeItemDeletion(key: key!, itemId: itemId);
          home.remove(itemId);
          deletedItems.add(itemId);
        } else {
          final relisted = await repository.undoItemDeletion(
            key: key!,
            itemId: itemId,
            checklistId: checklistId,
          );
          _screenLists[checklistId] = relisted!.data;
        }
      case _MembershipOp.deleteChecklist:
        // ChecklistController.delete of a checklist the screen shows.
        final candidates = _shownLists.skip(1).toList();
        if (candidates.isEmpty) return;
        final checklistId = candidates[arg % candidates.length];
        final deleted = await repository.deleteChecklist(
          checklistId: checklistId,
          taskId: taskId,
        );
        expect(deleted, isTrue, reason: 'deleteChecklist($checklistId)');
        _deleteList(checklistId);
      case _MembershipOp.taskEdit:
        // A task field saved from the screen's copy of the task.
        final screenTask = _screenTask;
        if (screenTask == null) return;
        final title = _nextTitle('title');
        final saved = await persistence.updateTask(
          journalEntityId: taskId,
          taskData: screenTask.data.copyWith(title: title),
        );
        expect(saved, isTrue, reason: 'updateTask');
        expect((await _storedTask()).data.title, title);
      case _MembershipOp.agentTaskEdit:
        // The agent's task-field tools: the whole task as read earlier,
        // under its clock. Behind a synced version that is a conflict, not
        // an overwrite; either way the stored lists must hold.
        final screenTask = _screenTask;
        if (screenTask == null) return;
        await JournalRepository().updateJournalEntity(
          screenTask.copyWith(
            data: screenTask.data.copyWith(title: _nextTitle('agent title')),
          ),
        );
      case _MembershipOp.createChecklist:
        if (!_checklistsLeft) return;
        await _agentList();
      case _MembershipOp.syncItem:
        if (!_receivesLeft || !_itemsLeft) return;
        await _landItem(target);
      case _MembershipOp.syncChecklist:
        if (!_receivesLeft || !_checklistsLeft) return;
        await _landChecklist();
      case _MembershipOp.armSyncItem:
        if (!_receivesLeft || !_itemsLeft || db.armed) return;
        db.arm(target, (arg ~/ 2) % 2, () => _landItem(target));
      case _MembershipOp.armSyncChecklist:
        if (!_receivesLeft || !_checklistsLeft || db.armed) return;
        db.arm(taskId, arg % 2, _landChecklist);
      case _MembershipOp.armAgentItem:
        // The other process on this device: the agent adds an item right
        // after a writer read the checklist.
        if (!_itemsLeft || db.armed) return;
        db.arm(target, (arg ~/ 2) % 2, () => _agentAdd(target));
      case _MembershipOp.armAgentChecklist:
        // The agent creates a checklist right after a writer read the task.
        if (!_checklistsLeft || db.armed) return;
        db.arm(taskId, arg % 3, _agentList);
      case _MembershipOp.crash:
        await _crash(kind: arg % 5, progress: arg ~/ 5);
    }
  }

  /// ChecklistRepository.addItemToChecklist (agAdd).
  Future<void> _agentAdd(String checklistId) async {
    // An armed add whose checklist was deleted since has nothing to add to.
    if (!live.contains(checklistId)) return;
    _itemsMade++;
    final item = await repository.addItemToChecklist(
      checklistId: checklistId,
      title: _nextTitle('agent item'),
      isChecked: false,
      categoryId: null,
    );
    expect(item, isNotNull, reason: 'addItemToChecklist($checklistId)');
    home[item!.meta.id] = checklistId;
  }

  /// ChecklistRepository.createChecklist (agList).
  Future<void> _agentList() async {
    _checklistsMade++;
    final created = await repository.createChecklist(taskId: taskId);
    expect(created.checklist, isNotNull, reason: 'createChecklist');
    live.add(created.checklist!.meta.id);
  }

  void _deleteList(String checklistId) {
    live.remove(checklistId);
    deletedLists.add(checklistId);
    _screenLists.remove(checklistId);
  }

  /// The app dies part-way through a multi-row operation: its intent is
  /// recorded and only the first [progress] of its writes happen. The next
  /// start replays the recorded intents and the screens load afresh.
  Future<void> _crash({required int kind, required int progress}) async {
    final crashed = await _startAndDie(kind: kind, progress: progress);
    if (!crashed) return;
    await repository.replayMembershipIntents();
    expect(await intents.pending(), isEmpty, reason: 'replay finishes all');
    await _snapshot();
  }

  /// Runs a prefix of one operation's writes after recording its intent;
  /// `false` when the operation has nothing to act on.
  Future<bool> _startAndDie({required int kind, required int progress}) async {
    // Live items in live checklists.
    final listed = [
      for (final MapEntry(key: itemId, value: checklistId) in home.entries)
        if (live.contains(checklistId)) itemId,
    ];
    switch (kind) {
      case 0:
        // addItemToChecklist, before or after it creates the item.
        if (!_itemsLeft) return false;
        final checklistId = live[progress % live.length];
        final item = ChecklistItem(
          meta: await persistence.createMetadata(),
          data: ChecklistItemData(
            title: _nextTitle('crashed item'),
            isChecked: false,
            linkedChecklists: [checklistId],
          ),
        );
        await intents.record(
          ListItemsIntent(checklistId: checklistId, itemIds: [item.id]),
        );
        if (progress.isOdd) {
          _itemsMade++;
          await persistence.createDbEntity(item);
          home[item.id] = checklistId;
        }
      case 1:
        // moveItem, after none to all three of its writes.
        if (listed.isEmpty) return false;
        final itemId = listed[progress % listed.length];
        final fromId = home[itemId]!;
        final others = [
          for (final id in live)
            if (id != fromId) id,
        ];
        if (others.isEmpty) return false;
        final toId = others[progress % others.length];
        await intents.record(
          MoveItemIntent(itemId: itemId, fromId: fromId, toId: toId),
        );
        // Once recorded, the move will happen (spec: home' = to).
        home[itemId] = toId;
        final writes = progress % 4;
        if (writes > 0) {
          await repository.updateChecklistItem(
            checklistItemId: itemId,
            taskId: taskId,
            change: (stored) => stored.copyWith(
              linkedChecklists: withMember(
                withoutMember(stored.linkedChecklists, fromId),
                toId,
              ),
            ),
          );
        }
        if (writes > 1) {
          await repository.updateChecklist(
            checklistId: toId,
            change: (stored) => stored.copyWith(
              linkedChecklistItems: withMember(
                stored.linkedChecklistItems,
                itemId,
              ),
            ),
          );
        }
        if (writes > 2) {
          await repository.updateChecklist(
            checklistId: fromId,
            change: (stored) => stored.copyWith(
              linkedChecklistItems: withoutMember(
                stored.linkedChecklistItems,
                itemId,
              ),
            ),
          );
        }
      case 2:
        // An item deletion, before it unlists the item or inside its undo
        // window: the user last saw it deleted.
        if (listed.isEmpty) return false;
        final itemId = listed[progress % listed.length];
        final checklistId = home[itemId]!;
        if (progress.isEven) {
          await intents.record(
            DeleteItemIntent(itemId: itemId, checklistId: checklistId),
          );
        } else {
          // The app dies inside the window: its timer dies with it.
          final key = await _withoutUndoTimer(
            () => repository.beginItemDeletion(
              itemId: itemId,
              checklistId: checklistId,
              undoWindow: _undoWindow,
            ),
          );
          expect(key, isNotNull, reason: 'beginItemDeletion($itemId)');
        }
        home.remove(itemId);
        deletedItems.add(itemId);
      case 3:
        // createChecklist, before or after it creates the checklist.
        if (!_checklistsLeft) return false;
        _checklistsMade++;
        final checklist = Checklist(
          meta: await persistence.createMetadata(),
          data: ChecklistData(
            title: _nextTitle('crashed checklist'),
            linkedChecklistItems: const [],
            linkedTasks: [taskId],
          ),
        );
        await intents.record(
          ListChecklistIntent(checklistId: checklist.id, taskId: taskId),
        );
        if (progress.isOdd) {
          await persistence.createDbEntity(checklist);
          live.add(checklist.id);
        }
      case 4:
        // deleteChecklist, before or after it deletes the checklist.
        final candidates = live.skip(1).toList();
        if (candidates.isEmpty) return false;
        final checklistId = candidates[progress % candidates.length];
        await intents.record(
          DeleteChecklistIntent(checklistId: checklistId, taskId: taskId),
        );
        if (progress.isOdd) {
          await JournalRepository().deleteJournalEntity(checklistId);
        }
        _deleteList(checklistId);
    }
    return true;
  }

  /// The screen's write through ChecklistController.updateChecklist: its
  /// intent, applied by the repository to the stored list.
  Future<void> _screenWrite(
    String checklistId,
    List<String> Function(List<String> stored) change,
  ) async {
    final written = await repository.updateChecklist(
      checklistId: checklistId,
      change: (stored) => stored.copyWith(
        linkedChecklistItems: change(stored.linkedChecklistItems),
      ),
    );
    expect(written, isNotNull, reason: 'updateChecklist($checklistId)');
    // The controller publishes what was stored as its state.
    _screenLists[checklistId] = written!.data;
  }

  Future<void> check(Object trace) async {
    final task = await _storedTask();
    final taskIds = task.data.checklistIds ?? const <String>[];
    expect(
      taskIds.toSet(),
      hasLength(taskIds.length),
      reason: 'NoDuplicates (task $taskIds): $trace',
    );
    for (final id in live) {
      expect(
        taskIds,
        contains(id),
        reason: 'NoLostChecklist ($id): $trace',
      );
    }
    for (final id in deletedLists) {
      expect(await db.peek(id), isNull, reason: 'deleted ($id): $trace');
      expect(taskIds, isNot(contains(id)), reason: 'unlisted ($id): $trace');
    }
    final lists = {for (final id in live) id: await _storedList(id)};
    for (final MapEntry(key: id, value: checklist) in lists.entries) {
      final items = checklist.data.linkedChecklistItems;
      expect(
        items.toSet(),
        hasLength(items.length),
        reason: 'NoDuplicates ($id $items): $trace',
      );
    }
    for (final MapEntry(key: item, value: itemHome) in home.entries) {
      final row = await db.peek(item);
      expect(row, isA<ChecklistItem>(), reason: 'live ($item): $trace');
      expect(
        (row! as ChecklistItem).data.linkedChecklists,
        [itemHome],
        reason: 'BackLinkAgrees ($item): $trace',
      );
      for (final MapEntry(key: id, value: checklist) in lists.entries) {
        final listed = checklist.data.linkedChecklistItems.contains(item);
        if (id == itemHome) {
          expect(listed, isTrue, reason: 'NoLostItem ($item in $id): $trace');
        } else {
          expect(
            listed,
            isFalse,
            reason: 'NoStrayItem ($item in $id): $trace',
          );
        }
      }
    }
    for (final item in deletedItems) {
      expect(await db.peek(item), isNull, reason: 'deleted ($item): $trace');
      for (final MapEntry(key: id, value: checklist) in lists.entries) {
        expect(
          checklist.data.linkedChecklistItems,
          isNot(contains(item)),
          reason: 'deleted ($item) unlisted from $id: $trace',
        );
      }
    }
    // What the task page and the agent's context resolve from those lists.
    final resolved = await repository.getChecklistItemsForTask(task: task);
    expect(
      resolved.map((item) => item.meta.id).toSet(),
      {
        for (final MapEntry(key: item, value: itemHome) in home.entries)
          if (live.contains(itemHome)) item,
      },
      reason: 'getChecklistItemsForTask: $trace',
    );
  }
}

void _registerChecklistMembershipConformance() {
  group('checklist membership (specs/tla/ChecklistMembership.tla)', () {
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
      // Replaces the suite's mocks with the real databases and persistence.
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

    glados.Glados(
      glados.any.membershipTrace,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'the screen, the agent, sync and a crash never drop an item from its '
      'checklist or a checklist from its task',
      (trace) async {
        // Each trace has its own task, checklists and items in the one
        // database, and starts with no intent left over from another.
        final bench = _MembershipBench(db..disarm());
        for (final key in (await bench.intents.pending()).keys) {
          await bench.intents.clear(key);
        }
        await bench.setUp();
        await bench.check(trace);
        for (final step in trace) {
          await bench.run(step);
          await bench.check(trace);
        }
      },
      timeout: const Timeout(Duration(minutes: 4)),
      tags: 'glados',
    );
  });
}

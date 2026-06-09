import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

enum _GeneratedChecklistBatchElementShape {
  newTitle,
  existingTitle,
  duplicateTitle,
  emptyTitle,
  nonMap,
}

class _GeneratedChecklistBatchElement {
  const _GeneratedChecklistBatchElement({
    required this.shape,
    required this.seed,
  });

  final _GeneratedChecklistBatchElementShape shape;
  final int seed;

  Object value(int index) => switch (shape) {
    _GeneratedChecklistBatchElementShape.newTitle => {
      'title': 'Generated item $seed',
      if (seed.isEven) 'isChecked': true,
    },
    _GeneratedChecklistBatchElementShape.existingTitle => {
      'title': seed.isEven ? '  Existing item  ' : 'existing ITEM',
    },
    _GeneratedChecklistBatchElementShape.duplicateTitle => {
      'title': 'Generated duplicate',
      'note': 'same fingerprint',
    },
    _GeneratedChecklistBatchElementShape.emptyTitle => {
      'title': index.isEven ? '' : '   ',
    },
    _GeneratedChecklistBatchElementShape.nonMap => 'not-a-map-$seed',
  };

  @override
  String toString() {
    return '_GeneratedChecklistBatchElement('
        'shape: $shape, seed: $seed)';
  }
}

class _GeneratedChecklistBatchScenario {
  const _GeneratedChecklistBatchScenario({
    required this.elements,
  });

  final List<_GeneratedChecklistBatchElement> elements;

  static const existingTitles = {'existing item'};

  List<Object> get values => [
    for (var index = 0; index < elements.length; index++)
      elements[index].value(index),
  ];

  _ExpectedChecklistBatch expected() {
    final seenTitles = {...existingTitles};
    final seenFingerprints = <String>{};
    final kept = <Map<String, dynamic>>[];
    var skipped = 0;
    var redundant = 0;

    for (final value in values) {
      if (value is! Map<String, dynamic>) {
        skipped++;
        continue;
      }

      final title = value['title'];
      if (title is String) {
        final normalized = title.trim().toLowerCase();
        if (normalized.isNotEmpty && seenTitles.contains(normalized)) {
          redundant++;
          continue;
        }
      }

      final fingerprint = ChangeItem.fingerprintFromParts(
        TaskAgentToolNames.addChecklistItem,
        value,
      );
      if (!seenFingerprints.add(fingerprint)) {
        redundant++;
        continue;
      }

      kept.add(value);
      if (title is String) {
        final normalized = title.trim().toLowerCase();
        if (normalized.isNotEmpty) {
          seenTitles.add(normalized);
        }
      }
    }

    return _ExpectedChecklistBatch(
      added: kept.length,
      skipped: skipped,
      redundant: redundant,
      kept: kept,
    );
  }

  @override
  String toString() {
    return '_GeneratedChecklistBatchScenario(values: $values)';
  }
}

class _ExpectedChecklistBatch {
  const _ExpectedChecklistBatch({
    required this.added,
    required this.skipped,
    required this.redundant,
    required this.kept,
  });

  final int added;
  final int skipped;
  final int redundant;
  final List<Map<String, dynamic>> kept;
}

extension _AnyGeneratedChecklistBatchScenario on glados.Any {
  glados.Generator<_GeneratedChecklistBatchElementShape>
  get checklistBatchElementShape =>
      glados.AnyUtils(this).choose(_GeneratedChecklistBatchElementShape.values);

  glados.Generator<_GeneratedChecklistBatchElement> get checklistBatchElement =>
      glados.CombinableAny(this).combine2(
        checklistBatchElementShape,
        glados.IntAnys(this).intInRange(0, 1000),
        (
          _GeneratedChecklistBatchElementShape shape,
          int seed,
        ) => _GeneratedChecklistBatchElement(
          shape: shape,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedChecklistBatchScenario>
  get checklistBatchScenario => glados.CombinableAny(this).combine2(
    glados.ListAnys(
      this,
    ).listWithLengthInRange(0, 12, checklistBatchElement),
    glados.AnyUtils(this).choose([false, true]),
    (
      List<_GeneratedChecklistBatchElement> elements,
      bool reverse,
    ) => _GeneratedChecklistBatchScenario(
      elements: reverse ? elements.reversed.toList() : elements,
    ),
  );
}

typedef _GeneratedChecklistItemState = ({
  String? title,
  bool? isChecked,
  bool? isArchived,
});

enum _GeneratedChecklistUpdateElementShape {
  nonMap,
  missingId,
  checkAlreadyChecked,
  checkUnchecked,
  uncheckAlreadyUnchecked,
  uncheckChecked,
  titleSame,
  titleDifferent,
  bothSame,
  checkedSameTitleDifferent,
  checkedDifferentTitleSame,
  idOnly,
  emptyTitle,
  unknownItem,
  duplicateExact,
}

class _GeneratedChecklistUpdateElement {
  const _GeneratedChecklistUpdateElement({
    required this.shape,
    required this.seed,
  });

  static const duplicateId = 'duplicate-update-id';

  final _GeneratedChecklistUpdateElementShape shape;
  final int seed;

  int get _slot => seed % 7;

  String get _checkedId => 'checked-update-$_slot';
  String get _uncheckedId => 'unchecked-update-$_slot';
  String get _titleId => 'title-update-$_slot';
  String get _unknownId => 'unknown-update-$_slot';

  String get _currentTitle => 'Current checklist title $_slot';
  String get _replacementTitle => 'Replacement checklist title $_slot';

  Object value() => switch (shape) {
    _GeneratedChecklistUpdateElementShape.nonMap => 'not-a-map-$seed',
    _GeneratedChecklistUpdateElementShape.missingId => <String, dynamic>{
      'isChecked': seed.isEven,
    },
    _GeneratedChecklistUpdateElementShape.checkAlreadyChecked =>
      <String, dynamic>{
        'id': _checkedId,
        'isChecked': true,
      },
    _GeneratedChecklistUpdateElementShape.checkUnchecked => <String, dynamic>{
      'id': _uncheckedId,
      'isChecked': true,
    },
    _GeneratedChecklistUpdateElementShape.uncheckAlreadyUnchecked =>
      <String, dynamic>{
        'id': _uncheckedId,
        'isChecked': false,
      },
    _GeneratedChecklistUpdateElementShape.uncheckChecked => <String, dynamic>{
      'id': _checkedId,
      'isChecked': false,
    },
    _GeneratedChecklistUpdateElementShape.titleSame => <String, dynamic>{
      'id': _titleId,
      'title': _currentTitle,
    },
    _GeneratedChecklistUpdateElementShape.titleDifferent => <String, dynamic>{
      'id': _titleId,
      'title': _replacementTitle,
    },
    _GeneratedChecklistUpdateElementShape.bothSame => <String, dynamic>{
      'id': _checkedId,
      'isChecked': true,
      'title': _currentTitle,
    },
    _GeneratedChecklistUpdateElementShape.checkedSameTitleDifferent =>
      <String, dynamic>{
        'id': _checkedId,
        'isChecked': true,
        'title': _replacementTitle,
      },
    _GeneratedChecklistUpdateElementShape.checkedDifferentTitleSame =>
      <String, dynamic>{
        'id': _uncheckedId,
        'isChecked': true,
        'title': _currentTitle,
      },
    _GeneratedChecklistUpdateElementShape.idOnly => <String, dynamic>{
      'id': _titleId,
    },
    _GeneratedChecklistUpdateElementShape.emptyTitle => <String, dynamic>{
      'id': _titleId,
      'title': '',
    },
    _GeneratedChecklistUpdateElementShape.unknownItem => <String, dynamic>{
      'id': _unknownId,
      'isChecked': seed.isEven,
    },
    _GeneratedChecklistUpdateElementShape.duplicateExact => <String, dynamic>{
      'id': duplicateId,
      'isChecked': true,
      'title': 'Duplicate title',
    },
  };

  String? get itemId {
    final currentValue = value();
    if (currentValue is! Map<String, dynamic>) return null;
    final id = currentValue['id'];
    return id is String ? id : null;
  }

  _GeneratedChecklistItemState? get resolvedState {
    return switch (shape) {
      _GeneratedChecklistUpdateElementShape.nonMap ||
      _GeneratedChecklistUpdateElementShape.missingId ||
      _GeneratedChecklistUpdateElementShape.unknownItem => null,
      _GeneratedChecklistUpdateElementShape.checkAlreadyChecked ||
      _GeneratedChecklistUpdateElementShape.uncheckChecked ||
      _GeneratedChecklistUpdateElementShape.bothSame ||
      _GeneratedChecklistUpdateElementShape.checkedSameTitleDifferent => (
        title: _currentTitle,
        isChecked: true,
        isArchived: null,
      ),
      _GeneratedChecklistUpdateElementShape.checkUnchecked ||
      _GeneratedChecklistUpdateElementShape.uncheckAlreadyUnchecked ||
      _GeneratedChecklistUpdateElementShape.checkedDifferentTitleSame => (
        title: _currentTitle,
        isChecked: false,
        isArchived: null,
      ),
      _GeneratedChecklistUpdateElementShape.titleSame ||
      _GeneratedChecklistUpdateElementShape.titleDifferent ||
      _GeneratedChecklistUpdateElementShape.idOnly ||
      _GeneratedChecklistUpdateElementShape.emptyTitle => (
        title: _currentTitle,
        isChecked: null,
        isArchived: null,
      ),
      _GeneratedChecklistUpdateElementShape.duplicateExact => (
        title: 'Duplicate current',
        isChecked: false,
        isArchived: null,
      ),
    };
  }

  @override
  String toString() {
    return '_GeneratedChecklistUpdateElement('
        'shape: $shape, seed: $seed, value: ${value()})';
  }
}

class _GeneratedChecklistUpdateScenario {
  const _GeneratedChecklistUpdateScenario({
    required this.elements,
  });

  final List<_GeneratedChecklistUpdateElement> elements;

  List<Object> get values => [
    for (final element in elements) element.value(),
  ];

  Map<String, _GeneratedChecklistItemState?> get stateById {
    final states = <String, _GeneratedChecklistItemState?>{};
    for (final element in elements) {
      final id = element.itemId;
      if (id != null) states[id] = element.resolvedState;
    }
    return states;
  }

  _ExpectedChecklistUpdateBatch expected() {
    final queuedFingerprints = <String>{};
    final queuedDisplayKeys = <String>{};
    final kept = <_ExpectedChecklistUpdateItem>[];
    var skipped = 0;
    var redundant = 0;
    var rejected = 0;

    for (final element in elements) {
      final value = element.value();
      if (value is! Map<String, dynamic>) {
        skipped++;
        continue;
      }

      // Fail-closed existence gate (mirrors the exploder): an update without
      // an id, or one whose id the resolver cannot find, is rejected before
      // any redundancy/dedup consideration. The test resolver never throws,
      // so a null resolvedState is always a clean not-found.
      final itemId = element.itemId;
      if (itemId == null) {
        rejected++;
        continue;
      }
      final state = element.resolvedState;
      if (state == null) {
        rejected++;
        continue;
      }
      if (_isRedundant(value, state)) {
        redundant++;
        continue;
      }

      final fingerprint = ChangeItem.fingerprintFromParts(
        TaskAgentToolNames.updateChecklistItem,
        value,
      );
      if (queuedFingerprints.contains(fingerprint)) {
        redundant++;
        continue;
      }

      final summary = _summary(value, state);
      final displayKey = ChangeItem.displayDuplicateKeyFromParts(
        TaskAgentToolNames.updateChecklistItem,
        summary,
        args: value,
      );
      if (displayKey != null && queuedDisplayKeys.contains(displayKey)) {
        redundant++;
        continue;
      }
      queuedFingerprints.add(fingerprint);
      if (displayKey != null) queuedDisplayKeys.add(displayKey);

      kept.add(
        _ExpectedChecklistUpdateItem(
          args: value,
          summary: summary,
        ),
      );
    }

    return _ExpectedChecklistUpdateBatch(
      added: kept.length,
      skipped: skipped,
      redundant: redundant,
      rejected: rejected,
      kept: kept,
    );
  }

  bool _isRedundant(
    Map<String, dynamic> args,
    _GeneratedChecklistItemState? state,
  ) {
    final itemId = args['id'];
    if (itemId is! String || state == null) return false;

    final proposedIsChecked = args['isChecked'];
    final proposedTitle = args['title'];
    final isCheckedChanging =
        proposedIsChecked is bool &&
        (state.isChecked == null || proposedIsChecked != state.isChecked);
    final isTitleChanging =
        proposedTitle is String &&
        proposedTitle.isNotEmpty &&
        proposedTitle != state.title;

    if (isCheckedChanging || isTitleChanging) return false;

    return proposedIsChecked is bool ||
        (proposedTitle is String && proposedTitle.isNotEmpty);
  }

  String _summary(
    Map<String, dynamic> args,
    _GeneratedChecklistItemState? state,
  ) {
    final title = args['title'];
    if (title is String && title.isNotEmpty) {
      final isChecked = args['isChecked'];
      if (isChecked is bool) {
        return '${isChecked ? 'Check' : 'Uncheck'}: "$title"';
      }
      return 'Update: "$title"';
    }

    final id = args['id'];
    if (id is String) {
      final isChecked = args['isChecked'];
      final resolvedTitle = state?.title;
      if (isChecked is bool) {
        final action = isChecked ? 'Check off' : 'Uncheck';
        if (resolvedTitle != null) return '$action: "$resolvedTitle"';
        return '$action item ${_truncateGeneratedId(id)}';
      }
      if (resolvedTitle != null) return 'Checklist update: "$resolvedTitle"';
      return 'Checklist update item ${_truncateGeneratedId(id)}';
    }

    return 'Checklist update item';
  }

  String _truncateGeneratedId(String id) =>
      id.length > 8 ? '${id.substring(0, 8)}…' : id;

  @override
  String toString() {
    return '_GeneratedChecklistUpdateScenario(values: $values)';
  }
}

class _ExpectedChecklistUpdateBatch {
  const _ExpectedChecklistUpdateBatch({
    required this.added,
    required this.skipped,
    required this.redundant,
    required this.rejected,
    required this.kept,
  });

  final int added;
  final int skipped;
  final int redundant;
  final int rejected;
  final List<_ExpectedChecklistUpdateItem> kept;
}

class _ExpectedChecklistUpdateItem {
  const _ExpectedChecklistUpdateItem({
    required this.args,
    required this.summary,
  });

  final Map<String, dynamic> args;
  final String summary;
}

extension _AnyGeneratedChecklistUpdateScenario on glados.Any {
  glados.Generator<_GeneratedChecklistUpdateElementShape>
  get checklistUpdateElementShape => glados.AnyUtils(
    this,
  ).choose(_GeneratedChecklistUpdateElementShape.values);

  glados.Generator<_GeneratedChecklistUpdateElement>
  get checklistUpdateElement => glados.CombinableAny(this).combine2(
    checklistUpdateElementShape,
    glados.IntAnys(this).intInRange(0, 1000),
    (
      _GeneratedChecklistUpdateElementShape shape,
      int seed,
    ) => _GeneratedChecklistUpdateElement(
      shape: shape,
      seed: seed,
    ),
  );

  glados.Generator<_GeneratedChecklistUpdateScenario>
  get checklistUpdateScenario => glados.CombinableAny(this).combine2(
    glados.ListAnys(
      this,
    ).listWithLengthInRange(0, 12, checklistUpdateElement),
    glados.AnyUtils(this).choose([false, true]),
    (
      List<_GeneratedChecklistUpdateElement> elements,
      bool reverse,
    ) => _GeneratedChecklistUpdateScenario(
      elements: reverse ? elements.reversed.toList() : elements,
    ),
  );
}

void main() {
  late ChangeSetBuilder builder;
  late MockAgentSyncService mockSyncService;
  late MockAgentRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(
      AgentDomainEntity.unknown(
        id: 'fallback',
        agentId: 'fallback',
        createdAt: DateTime(2024),
      ),
    );
  });

  setUp(() {
    mockSyncService = MockAgentSyncService();
    mockRepository = MockAgentRepository();
    builder = ChangeSetBuilder(
      agentId: 'agent-001',
      taskId: 'task-001',
      threadId: 'thread-001',
      runKey: 'run-key-001',
    );

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSyncService.repository).thenReturn(mockRepository);

    // Default: getEntity returns null so build() falls back to the
    // passed-in entity.
    when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);
  });

  group('addBatchItem', () {
    test(
      'explodes add_multiple_checklist_items into individual items',
      () async {
        await builder.addBatchItem(
          toolName: 'add_multiple_checklist_items',
          args: {
            'items': [
              {'title': 'Design mockup'},
              {'title': 'Implement API'},
              {'title': 'Write tests'},
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(builder.items, hasLength(3));
        expect(builder.items[0].toolName, 'add_checklist_item');
        expect(builder.items[0].args, {'title': 'Design mockup'});
        expect(builder.items[0].humanSummary, 'Add: "Design mockup"');
        expect(builder.items[1].humanSummary, 'Add: "Implement API"');
        expect(builder.items[2].humanSummary, 'Add: "Write tests"');
      },
    );

    test('explodes update_checklist_items into individual items', () async {
      await builder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-1', 'isChecked': true, 'title': 'Design mockup'},
            {'id': 'item-2', 'title': 'Revised title'},
          ],
        },
        summaryPrefix: 'Checklist update',
      );

      expect(builder.items, hasLength(2));
      expect(builder.items[0].toolName, 'update_checklist_item');
      expect(builder.items[0].args['id'], 'item-1');
      expect(builder.items[0].humanSummary, 'Check: "Design mockup"');
      expect(builder.items[1].humanSummary, contains('Revised title'));
    });

    test(
      'dedupes identical update_checklist_item elements within the same '
      'batch by fingerprint',
      () async {
        // LLM occasionally repeats the exact same `{id, isChecked}`
        // element multiple times in a single tool call. The builder
        // must keep only one so the user does not see N duplicate rows.
        final result = await builder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-1', 'isChecked': true, 'title': 'Ship it'},
              {'id': 'item-1', 'isChecked': true, 'title': 'Ship it'},
              {'id': 'item-1', 'isChecked': true, 'title': 'Ship it'},
            ],
          },
          summaryPrefix: 'Checklist update',
        );

        expect(result.added, 1);
        expect(result.redundant, 2);
        expect(builder.items, hasLength(1));
        expect(
          result.redundantDetails.every(
            (d) => d.contains('already queued in this wake'),
          ),
          isTrue,
        );
      },
    );

    test(
      'dedupes batch elements whose fingerprint already matches an item '
      'queued by an earlier addBatchItem call in the same wake',
      () async {
        await builder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-1', 'isChecked': true, 'title': 'Ship it'},
            ],
          },
          summaryPrefix: 'Checklist update',
        );

        final secondResult = await builder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-1', 'isChecked': true, 'title': 'Ship it'},
              {'id': 'item-2', 'isChecked': true, 'title': 'Ship the other'},
            ],
          },
          summaryPrefix: 'Checklist update',
        );

        // The first element was already queued by the earlier call —
        // only the genuinely new element survives.
        expect(secondResult.added, 1);
        expect(secondResult.redundant, 1);
        expect(builder.items, hasLength(2));
        expect(
          builder.items.map((i) => i.args['id']).toList(),
          ['item-1', 'item-2'],
        );
      },
    );

    test(
      'handles check-only update (no title) by ID with truncated ID',
      () async {
        await builder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-42', 'isChecked': true},
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(builder.items, hasLength(1));
        // Short ID — no truncation needed.
        expect(builder.items.first.humanSummary, 'Check off item item-42');
      },
    );

    test('truncates long UUIDs in fallback display', () async {
      await builder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {
              'id': '2ff860d0-141d-11f1-a937-89a8ebc23f0b',
              'isChecked': true,
            },
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(builder.items, hasLength(1));
      expect(
        builder.items.first.humanSummary,
        'Check off item 2ff860d0…',
      );
    });

    test('resolves title from resolver for ID-only updates', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async {
          if (id == 'item-42') {
            return (title: 'Buy groceries', isChecked: false, isArchived: null);
          }
          return null;
        },
      );

      await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-42', 'isChecked': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(
        resolverBuilder.items.first.humanSummary,
        'Check off: "Buy groceries"',
      );
    });

    test('summarizes an archival as Archive with the resolved title', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async {
          if (id == 'item-42') {
            return (
              title: 'Duplicate groceries item',
              isChecked: false,
              isArchived: false,
            );
          }
          return null;
        },
      );

      await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-42', 'isArchived': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(
        resolverBuilder.items.first.humanSummary,
        'Archive: "Duplicate groceries item"',
      );
    });

    test(
      'summarizes an archival using the title from the args when present',
      () async {
        final builder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
        );

        await builder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-1', 'title': 'Known title', 'isArchived': true},
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(builder.items.first.humanSummary, 'Archive: "Known title"');
      },
    );

    test(
      'falls back to the truncated id when archiving without a resolver',
      () async {
        final builder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
        );

        await builder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {
                'id': 'abcdefgh-1234-5678-9012-abcdefghijkl',
                'isArchived': true,
              },
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(builder.items.first.humanSummary, 'Archive item abcdefgh…');
      },
    );

    test('summarizes an unarchival as Restore', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async =>
            (title: 'Shelved item', isChecked: false, isArchived: true),
      );

      await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-9', 'isArchived': false},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(
        resolverBuilder.items.first.humanSummary,
        'Restore: "Shelved item"',
      );
    });

    test('suppresses a redundant archival when the item is already '
        'archived', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async =>
            (title: 'Old duplicate', isChecked: false, isArchived: true),
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-9', 'isArchived': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, isEmpty);
      expect(result.redundant, 1);
      expect(
        result.redundantDetails.single,
        '"Old duplicate" is already archived',
      );
    });

    test(
      'rejects an update whose id a wired resolver cannot find (no raw-id '
      'suggestion is queued)',
      () async {
        final resolverBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          checklistItemStateResolver: (_) async => null,
        );

        final result = await resolverBuilder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {
                'id': 'abcdefgh-1234-5678-9012-abcdefghijkl',
                'isChecked': false,
              },
            ],
          },
          summaryPrefix: 'Checklist',
        );

        // Hallucinated id: nothing is queued and the model is told the id is
        // fake instead of the user seeing a raw-id suggestion.
        expect(resolverBuilder.items, isEmpty);
        expect(result.added, 0);
        expect(result.rejected, 1);
        expect(result.redundant, 0);
        expect(result.rejectedDetails.single, contains('does not exist'));
        expect(
          result.rejectedDetails.single,
          contains('abcdefgh-1234-5678-9012-abcdefghijkl'),
        );
      },
    );

    test('falls back gracefully when resolver throws', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (_) async => throw Exception('DB error'),
      );

      await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {
              'id': '12345678-abcd-ef01-2345-678901234567',
              'isChecked': true,
            },
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(
        resolverBuilder.items.first.humanSummary,
        'Check off item 12345678…',
      );
    });

    test('logs error via DomainLogger when resolver throws', () async {
      final mockLogger = MockDomainLogger();
      when(
        () => mockLogger.enabledDomains,
      ).thenReturn({LogDomain.agentWorkflow});
      when(
        () => mockLogger.error(
          any(),
          any(),
          message: any(named: 'message'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).thenReturn(null);

      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        domainLogger: mockLogger,
        checklistItemStateResolver: (_) => throw Exception('connection lost'),
      );

      await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-err', 'isChecked': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      // Verify logger was called with the error.
      verify(
        () => mockLogger.error(
          LogDomain.agentWorkflow,
          any(),
          message: any(
            named: 'message',
            that: contains('failed to resolve checklist item state'),
          ),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);

      // Should still produce a fallback summary.
      expect(resolverBuilder.items, hasLength(1));
      expect(
        resolverBuilder.items.first.humanSummary,
        'Check off item item-err',
      );
    });

    test('handles uncheck update', () async {
      await builder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-7', 'isChecked': false},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(builder.items.first.humanSummary, 'Uncheck item item-7');
    });

    test('falls back to single item for unknown batch tool', () async {
      await builder.addBatchItem(
        toolName: 'unknown_batch_tool',
        args: {
          'items': [1, 2, 3],
        },
        summaryPrefix: 'Unknown',
      );

      expect(builder.items, hasLength(1));
      expect(builder.items.first.toolName, 'unknown_batch_tool');
      expect(builder.items.first.humanSummary, 'Unknown (batch)');
    });

    test('handles empty array without queuing a placeholder', () async {
      final result = await builder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {'items': <dynamic>[]},
        summaryPrefix: 'Checklist',
      );

      expect(builder.items, isEmpty);
      expect(result.added, 0);
    });

    test('handles missing array key without queuing a placeholder', () async {
      final result = await builder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {'wrong_key': 'value'},
        summaryPrefix: 'Checklist',
      );

      expect(builder.items, isEmpty);
      expect(result.added, 0);
    });
  });

  group('addBatchItem — label explosion', () {
    test(
      'explodes assign_task_labels into individual assign_task_label items',
      () async {
        final result = await builder.addBatchItem(
          toolName: 'assign_task_labels',
          args: {
            'labels': [
              {'id': 'label-1', 'confidence': 'high'},
              {'id': 'label-2', 'confidence': 'medium'},
            ],
          },
          summaryPrefix: 'Label',
        );

        expect(result.added, 2);
        expect(result.skipped, 0);
        expect(result.redundant, 0);
        expect(builder.items, hasLength(2));
        expect(builder.items[0].toolName, 'assign_task_label');
        expect(builder.items[0].args, {'id': 'label-1', 'confidence': 'high'});
        expect(builder.items[1].toolName, 'assign_task_label');
        expect(builder.items[1].args, {
          'id': 'label-2',
          'confidence': 'medium',
        });
      },
    );

    test('generates human-readable summaries with label names', () async {
      final builderWithResolver = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        labelNameResolver: (labelId) async {
          return switch (labelId) {
            'label-1' => 'Bug',
            'label-2' => 'Backend',
            _ => null,
          };
        },
      );

      await builderWithResolver.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'id': 'label-1', 'confidence': 'high'},
            {'id': 'label-2', 'confidence': 'medium'},
          ],
        },
        summaryPrefix: 'Label',
      );

      expect(
        builderWithResolver.items[0].humanSummary,
        'Assign label: "Bug" (high)',
      );
      expect(
        builderWithResolver.items[1].humanSummary,
        'Assign label: "Backend" (medium)',
      );
    });

    test('generates summary with truncated ID when no resolver', () async {
      await builder.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'id': 'abcdefgh-1234-5678', 'confidence': 'high'},
          ],
        },
        summaryPrefix: 'Label',
      );

      expect(
        builder.items[0].humanSummary,
        contains('Assign label:'),
      );
      expect(
        builder.items[0].humanSummary,
        contains('abcdefgh'),
      );
    });

    test('filters out labels already assigned to the task', () async {
      final builderWithResolver = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingLabelIdsResolver: () async => {'label-1'},
        labelNameResolver: (id) async => 'Label $id',
      );

      final result = await builderWithResolver.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'id': 'label-1', 'confidence': 'high'},
            {'id': 'label-2', 'confidence': 'medium'},
          ],
        },
        summaryPrefix: 'Label',
      );

      expect(result.added, 1);
      expect(result.redundant, 1);
      expect(result.redundantDetails, hasLength(1));
      expect(result.redundantDetails[0], contains('already assigned'));
      expect(builderWithResolver.items, hasLength(1));
      expect(builderWithResolver.items[0].args['id'], 'label-2');
    });

    test(
      'redundant label detail falls back to truncated id when name is null',
      () async {
        // The label is already assigned but the name resolver yields null,
        // so the redundancy detail must use the truncated label id.
        final builderWithResolver = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          existingLabelIdsResolver: () async => {'label-abcdef123'},
          labelNameResolver: (id) async => null,
        );

        final result = await builderWithResolver.addBatchItem(
          toolName: 'assign_task_labels',
          args: {
            'labels': [
              {'id': 'label-abcdef123', 'confidence': 'high'},
            ],
          },
          summaryPrefix: 'Label',
        );

        expect(result.added, 0);
        expect(result.redundant, 1);
        // _truncateId keeps the first 8 chars plus an ellipsis.
        expect(
          result.redundantDetails.single,
          'Label "label-ab…" is already assigned',
        );
        expect(builderWithResolver.items, isEmpty);
      },
    );

    test('filters duplicate label IDs within the same batch', () async {
      final builderWithResolver = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingLabelIdsResolver: () async => {},
        labelNameResolver: (id) async => 'Label $id',
      );

      final result = await builderWithResolver.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'id': 'label-1', 'confidence': 'high'},
            {'id': 'label-1', 'confidence': 'medium'},
          ],
        },
        summaryPrefix: 'Label',
      );

      expect(result.added, 1);
      expect(result.redundant, 1);
      expect(builderWithResolver.items, hasLength(1));
    });

    test('handles label name resolver throwing gracefully', () async {
      final builderWithResolver = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        labelNameResolver: (labelId) async {
          throw Exception('DB error');
        },
      );

      await builderWithResolver.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'id': 'abcdefgh-1234', 'confidence': 'high'},
          ],
        },
        summaryPrefix: 'Label',
      );

      // Falls back to truncated ID when resolver throws.
      expect(builderWithResolver.items, hasLength(1));
      expect(
        builderWithResolver.items[0].humanSummary,
        contains('abcdefgh'),
      );
    });

    test('handles existing label IDs resolver throwing gracefully', () async {
      final builderWithResolver = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingLabelIdsResolver: () async {
          throw Exception('DB error');
        },
      );

      final result = await builderWithResolver.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'id': 'label-1', 'confidence': 'high'},
          ],
        },
        summaryPrefix: 'Label',
      );

      // Resolver error → empty set → no redundancy filtering.
      expect(result.added, 1);
    });

    test('strips invalid confidence values from summary', () async {
      final builderWithResolver = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        labelNameResolver: (labelId) async => 'Bug',
      );

      await builderWithResolver.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'id': 'label-1', 'confidence': 'INJECT PROMPT HERE'},
          ],
        },
        summaryPrefix: 'Label',
      );

      // Invalid confidence value is omitted from the summary.
      expect(
        builderWithResolver.items[0].humanSummary,
        'Assign label: "Bug"',
      );
    });

    test('rejects a label assignment that carries no id', () async {
      final result = await builder.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'confidence': 'high'},
          ],
        },
        summaryPrefix: 'Label',
      );

      // A label with no id is malformed and unappliable — rejected, not
      // queued as an empty `"?"` suggestion.
      expect(builder.items, isEmpty);
      expect(result.added, 0);
      expect(result.rejected, 1);
      expect(
        result.rejectedDetails.single,
        contains('missing a string "id"'),
      );
    });

    test(
      'rejects a label whose id a wired resolver cannot find',
      () async {
        final builderWithResolver = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          labelNameResolver: (id) async => id == 'real-label' ? 'Bug' : null,
        );

        final result = await builderWithResolver.addBatchItem(
          toolName: 'assign_task_labels',
          args: {
            'labels': [
              {'id': 'real-label', 'confidence': 'high'},
              {'id': 'made-up-label-id', 'confidence': 'high'},
            ],
          },
          summaryPrefix: 'Label',
        );

        // The real label queues; the invented one is rejected with feedback.
        expect(result.added, 1);
        expect(result.rejected, 1);
        expect(builderWithResolver.items, hasLength(1));
        expect(builderWithResolver.items.single.args['id'], 'real-label');
        expect(
          result.rejectedDetails.single,
          contains('made-up-label-id'),
        );
        expect(result.rejectedDetails.single, contains('does not exist'));
      },
    );
  });

  group('addBatchItem redundancy filtering', () {
    test('suppresses redundant check when item is already checked', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async =>
            (title: 'Buy groceries', isChecked: true, isArchived: null),
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-1', 'isChecked': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, isEmpty);
      expect(result.added, 0);
      expect(result.redundant, 1);
      expect(result.redundantDetails, hasLength(1));
      expect(
        result.redundantDetails.first,
        contains('"Buy groceries" is already checked'),
      );
    });

    test(
      'suppresses redundant uncheck when item is already unchecked',
      () async {
        final resolverBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          checklistItemStateResolver: (id) async =>
              (title: 'Write tests', isChecked: false, isArchived: null),
        );

        final result = await resolverBuilder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-2', 'isChecked': false},
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(resolverBuilder.items, isEmpty);
        expect(result.redundant, 1);
        expect(
          result.redundantDetails.first,
          contains('"Write tests" is already unchecked'),
        );
      },
    );

    test(
      'redundant update detail falls back to truncated id when title is null',
      () async {
        // Resolver returns a known checked state but no title, so the
        // redundant-update detail must fall back to the truncated item id.
        final resolverBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          checklistItemStateResolver: (id) async =>
              (title: null, isChecked: true, isArchived: null),
        );

        final result = await resolverBuilder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'abcdef1234567890', 'isChecked': true},
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(resolverBuilder.items, isEmpty);
        expect(result.added, 0);
        expect(result.redundant, 1);
        // _truncateId keeps the first 8 chars plus an ellipsis.
        expect(
          result.redundantDetails.single,
          '"abcdef12…" is already checked',
        );
      },
    );

    test('allows non-redundant check update to pass through', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async =>
            (title: 'Deploy app', isChecked: false, isArchived: null),
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-3', 'isChecked': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
    });

    test('mixed batch: some items redundant, some not', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async {
          if (id == 'item-a') {
            return (title: 'Already done', isChecked: true, isArchived: null);
          }
          if (id == 'item-b') {
            return (title: 'Not done', isChecked: false, isArchived: null);
          }
          return null;
        },
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-a', 'isChecked': true}, // redundant
            {'id': 'item-b', 'isChecked': true}, // not redundant
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(resolverBuilder.items.first.args['id'], 'item-b');
      expect(result.added, 1);
      expect(result.redundant, 1);
    });

    test(
      'title-only update is NOT suppressed even when isChecked matches',
      () async {
        final resolverBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          checklistItemStateResolver: (id) async =>
              (title: 'Old title', isChecked: true, isArchived: null),
        );

        final result = await resolverBuilder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-1', 'title': 'New title'},
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(resolverBuilder.items, hasLength(1));
        expect(result.added, 1);
        expect(result.redundant, 0);
      },
    );

    test('title change with redundant isChecked is NOT suppressed', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async =>
            (title: 'Old title', isChecked: true, isArchived: null),
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-1', 'isChecked': true, 'title': 'New title'},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
    });

    test('rejects an update referencing a non-existent item id', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (_) async => null,
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-unknown', 'isChecked': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      // A clean not-found (resolver ran, returned null) is a hallucinated id.
      expect(resolverBuilder.items, isEmpty);
      expect(result.added, 0);
      expect(result.rejected, 1);
      expect(result.redundant, 0);
      expect(result.rejectedDetails.single, contains('item-unknown'));
      expect(result.rejectedDetails.single, contains('does not exist'));
    });

    test('keeps item when resolver throws (conservative)', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (_) async => throw Exception('DB error'),
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-err', 'isChecked': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
    });

    test(
      'keeps item when resolver returns isChecked as null (conservative)',
      () async {
        final resolverBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          checklistItemStateResolver: (id) async =>
              (title: 'Ambiguous item', isChecked: null, isArchived: null),
        );

        final result = await resolverBuilder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-null', 'isChecked': true},
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(resolverBuilder.items, hasLength(1));
        expect(result.added, 1);
        expect(result.redundant, 0);
      },
    );

    test(
      'suppresses when both isChecked and title match current state',
      () async {
        final resolverBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          checklistItemStateResolver: (id) async =>
              (title: 'Same title', isChecked: true, isArchived: null),
        );

        final result = await resolverBuilder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-both', 'isChecked': true, 'title': 'Same title'},
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(resolverBuilder.items, isEmpty);
        expect(result.added, 0);
        expect(result.redundant, 1);
        expect(
          result.redundantDetails.first,
          contains('"Same title" is already checked'),
        );
      },
    );

    test(
      'keeps update with empty title string (treated as malformed)',
      () async {
        final resolverBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          checklistItemStateResolver: (id) async =>
              (title: 'Some item', isChecked: true, isArchived: null),
        );

        final result = await resolverBuilder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-y', 'title': ''}, // Empty title — malformed
            ],
          },
          summaryPrefix: 'Checklist',
        );

        // Empty title is not a valid proposal — kept defensively.
        expect(resolverBuilder.items, hasLength(1));
        expect(result.added, 1);
        expect(result.redundant, 0);
      },
    );

    test(
      'keeps malformed update with only id (no isChecked, no title)',
      () async {
        final resolverBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          checklistItemStateResolver: (id) async =>
              (title: 'Some item', isChecked: true, isArchived: null),
        );

        final result = await resolverBuilder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-x'}, // No isChecked, no title — malformed
            ],
          },
          summaryPrefix: 'Checklist',
        );

        // Malformed proposals are kept defensively.
        expect(resolverBuilder.items, hasLength(1));
        expect(result.added, 1);
        expect(result.redundant, 0);
      },
    );

    test('does not filter add_checklist_item (only updates)', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async =>
            (title: 'Existing item', isChecked: true, isArchived: null),
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {
          'items': [
            {'title': 'New item'},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
    });
  });

  group('task splitting — migrate batch explosion', () {
    test(
      'singularizes migrate_checklist_items to migrate_checklist_item',
      () async {
        final result = await builder.addBatchItem(
          toolName: 'migrate_checklist_items',
          args: {
            'items': [
              {'id': 'item-1', 'title': 'Buy milk'},
            ],
            'targetTaskId': 'target-001',
          },
          summaryPrefix: 'Migrate',
        );

        expect(result.added, 1);
        expect(builder.items.first.toolName, 'migrate_checklist_item');
      },
    );

    test('injects targetTaskId into each child element', () async {
      await builder.addBatchItem(
        toolName: 'migrate_checklist_items',
        args: {
          'items': [
            {'id': 'item-1', 'title': 'Buy milk'},
            {'id': 'item-2', 'title': 'Walk dog'},
          ],
          'targetTaskId': 'target-task-xyz',
        },
        summaryPrefix: 'Migrate',
      );

      expect(builder.items, hasLength(2));
      for (final item in builder.items) {
        expect(item.args['targetTaskId'], 'target-task-xyz');
      }
    });

    test('assigns groupId to all exploded items', () async {
      await builder.addBatchItem(
        toolName: 'migrate_checklist_items',
        args: {
          'items': [
            {'id': 'item-1', 'title': 'Item A'},
            {'id': 'item-2', 'title': 'Item B'},
          ],
          'targetTaskId': 'target-001',
        },
        summaryPrefix: 'Migrate',
        groupId: 'split-group-001',
      );

      expect(builder.items, hasLength(2));
      expect(builder.items[0].groupId, 'split-group-001');
      expect(builder.items[1].groupId, 'split-group-001');
    });

    test('handles missing targetTaskId gracefully', () async {
      await builder.addBatchItem(
        toolName: 'migrate_checklist_items',
        args: {
          'items': [
            {'id': 'item-1', 'title': 'Buy milk'},
          ],
        },
        summaryPrefix: 'Migrate',
      );

      // Item is still added, just without targetTaskId injection.
      expect(builder.items, hasLength(1));
      expect(builder.items.first.args.containsKey('targetTaskId'), isFalse);
    });

    test(
      'rejects a migrate item whose id a wired resolver cannot find',
      () async {
        final resolverBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          checklistItemStateResolver: (id) async => id == 'real-item'
              ? (title: 'Real', isChecked: false, isArchived: null)
              : null,
        );

        final result = await resolverBuilder.addBatchItem(
          toolName: 'migrate_checklist_items',
          args: {
            'items': [
              {'id': 'real-item', 'title': 'Real'},
              {'id': 'ghost-item', 'title': 'Ghost'},
            ],
            'targetTaskId': 'target-001',
          },
          summaryPrefix: 'Migrate',
        );

        // Only the existing item migrates; the invented id is rejected.
        expect(result.added, 1);
        expect(result.rejected, 1);
        expect(resolverBuilder.items, hasLength(1));
        expect(resolverBuilder.items.single.args['id'], 'real-item');
        expect(result.rejectedDetails.single, contains('ghost-item'));
        expect(result.rejectedDetails.single, contains('does not exist'));
      },
    );

    test('rejects a migrate item that carries no id', () async {
      // The missing-id gate is structural (it fires without a resolver), so a
      // migrate item with no id is rejected, not queued as unappliable.
      final result = await builder.addBatchItem(
        toolName: 'migrate_checklist_items',
        args: {
          'items': [
            {'title': 'No id'},
          ],
          'targetTaskId': 'target-001',
        },
        summaryPrefix: 'Migrate',
      );

      expect(result.added, 0);
      expect(result.rejected, 1);
      expect(builder.items, isEmpty);
      expect(
        result.rejectedDetails.single,
        contains('migrate_checklist_item is missing'),
      );
    });
  });

  // Properties: generated batch scenarios run through addBatchItem and the
  // final build() consolidation, proving the explosion dedupe semantics.
  group('addBatchItem — generated batch properties', () {
    glados.Glados(
      glados.any.checklistBatchScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'matches generated add-checklist batch dedupe semantics',
      (scenario) async {
        final generatedBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          existingChecklistTitlesResolver: () async =>
              _GeneratedChecklistBatchScenario.existingTitles,
        );
        final expected = scenario.expected();

        final result = await generatedBuilder.addBatchItem(
          toolName: TaskAgentToolNames.addMultipleChecklistItems,
          args: {'items': scenario.values},
          summaryPrefix: 'Checklist',
        );

        expect(result.added, expected.added, reason: '$scenario');
        expect(result.skipped, expected.skipped, reason: '$scenario');
        expect(result.redundant, expected.redundant, reason: '$scenario');
        expect(generatedBuilder.items, hasLength(expected.added));

        for (var index = 0; index < expected.kept.length; index++) {
          final item = generatedBuilder.items[index];
          final args = expected.kept[index];
          expect(item.toolName, TaskAgentToolNames.addChecklistItem);
          expect(item.args, args, reason: '$scenario');

          final title = args['title'];
          if (title is String && title.isNotEmpty) {
            expect(item.humanSummary, 'Add: "$title"', reason: '$scenario');
          } else {
            expect(item.humanSummary, 'Checklist item', reason: '$scenario');
          }
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.checklistUpdateScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'matches generated update-checklist batch semantics',
      (scenario) async {
        final stateById = scenario.stateById;
        final generatedBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          checklistItemStateResolver: (id) async => stateById[id],
        );
        final expected = scenario.expected();

        final result = await generatedBuilder.addBatchItem(
          toolName: TaskAgentToolNames.updateChecklistItems,
          args: {'items': scenario.values},
          summaryPrefix: 'Checklist update',
        );

        expect(result.added, expected.added, reason: '$scenario');
        expect(result.skipped, expected.skipped, reason: '$scenario');
        expect(result.redundant, expected.redundant, reason: '$scenario');
        expect(result.rejected, expected.rejected, reason: '$scenario');
        expect(generatedBuilder.items, hasLength(expected.added));

        for (var index = 0; index < expected.kept.length; index++) {
          final item = generatedBuilder.items[index];
          final expectedItem = expected.kept[index];
          expect(item.toolName, TaskAgentToolNames.updateChecklistItem);
          expect(item.args, expectedItem.args, reason: '$scenario');
          expect(
            item.humanSummary,
            expectedItem.summary,
            reason: '$scenario',
          );
        }
      },
      tags: 'glados',
    );
  });
}

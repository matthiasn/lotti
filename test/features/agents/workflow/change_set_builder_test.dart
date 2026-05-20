import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../projects/test_utils.dart';
import '../test_utils.dart';

class _GeneratedFollowUpScenario {
  const _GeneratedFollowUpScenario({
    required this.titleSeed,
    required this.dueSeed,
    required this.prioritySeed,
    required this.flags,
  });

  static const _titles = [
    'Write migration plan',
    'Audit retry behavior',
    'Draft release notes',
    'Review analytics query',
  ];

  final int titleSeed;
  final int dueSeed;
  final int prioritySeed;
  final int flags;

  String get title => _titles[titleSeed % _titles.length];
  String get dueDate =>
      '2026-06-${(dueSeed % 28 + 1).toString().padLeft(2, '0')}';
  String get priority => 'P${prioritySeed % 4}';

  bool get includeDueDate => flags & 1 != 0;
  bool get includePriority => flags & 2 != 0;
  bool get firstTitlePadded => flags & 4 != 0;
  bool get secondTitlePadded => flags & 8 != 0;
  bool get firstDueDatePadded => flags & 16 != 0;
  bool get secondDueDatePadded => flags & 32 != 0;
  bool get firstPriorityLowercase => flags & 64 != 0;
  bool get secondPriorityLowercase => flags & 128 != 0;

  Map<String, dynamic> get firstArgs => _args(
    titlePadded: firstTitlePadded,
    dueDatePadded: firstDueDatePadded,
    priorityLowercase: firstPriorityLowercase,
  );

  Map<String, dynamic> get secondArgs => _args(
    titlePadded: secondTitlePadded,
    dueDatePadded: secondDueDatePadded,
    priorityLowercase: secondPriorityLowercase,
  );

  Map<String, dynamic> _args({
    required bool titlePadded,
    required bool dueDatePadded,
    required bool priorityLowercase,
  }) {
    final rawPriority = priorityLowercase ? priority.toLowerCase() : priority;
    return {
      'title': titlePadded ? '  $title  ' : title,
      if (includeDueDate) 'dueDate': dueDatePadded ? '  $dueDate  ' : dueDate,
      if (includePriority)
        'priority': priorityLowercase ? '  $rawPriority  ' : rawPriority,
    };
  }

  String expectedPlaceholder(String taskId) {
    return ChangeSetBuilder.deterministicPlaceholder(
      taskId,
      '$title|${includeDueDate ? dueDate : ''}|'
      '${includePriority ? priority : ''}',
    );
  }

  @override
  String toString() {
    return '_GeneratedFollowUpScenario('
        'firstArgs: $firstArgs, '
        'secondArgs: $secondArgs)';
  }
}

extension _AnyGeneratedFollowUpScenario on glados.Any {
  glados.Generator<_GeneratedFollowUpScenario> get followUpScenario =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 1000),
        glados.IntAnys(this).intInRange(0, 1000),
        glados.IntAnys(this).intInRange(0, 1000),
        glados.IntAnys(this).intInRange(0, 255),
        (
          int titleSeed,
          int dueSeed,
          int prioritySeed,
          int flags,
        ) => _GeneratedFollowUpScenario(
          titleSeed: titleSeed,
          dueSeed: dueSeed,
          prioritySeed: prioritySeed,
          flags: flags,
        ),
      );
}

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

typedef _GeneratedChecklistItemState = ({String? title, bool? isChecked});

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
      ),
      _GeneratedChecklistUpdateElementShape.checkUnchecked ||
      _GeneratedChecklistUpdateElementShape.uncheckAlreadyUnchecked ||
      _GeneratedChecklistUpdateElementShape.checkedDifferentTitleSame => (
        title: _currentTitle,
        isChecked: false,
      ),
      _GeneratedChecklistUpdateElementShape.titleSame ||
      _GeneratedChecklistUpdateElementShape.titleDifferent ||
      _GeneratedChecklistUpdateElementShape.idOnly ||
      _GeneratedChecklistUpdateElementShape.emptyTitle => (
        title: _currentTitle,
        isChecked: null,
      ),
      _GeneratedChecklistUpdateElementShape.duplicateExact => (
        title: 'Duplicate current',
        isChecked: false,
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
    final kept = <_ExpectedChecklistUpdateItem>[];
    var skipped = 0;
    var redundant = 0;

    for (final element in elements) {
      final value = element.value();
      if (value is! Map<String, dynamic>) {
        skipped++;
        continue;
      }

      final state = element.resolvedState;
      if (_isRedundant(value, state)) {
        redundant++;
        continue;
      }

      final fingerprint = ChangeItem.fingerprintFromParts(
        TaskAgentToolNames.updateChecklistItem,
        value,
      );
      if (!queuedFingerprints.add(fingerprint)) {
        redundant++;
        continue;
      }

      kept.add(
        _ExpectedChecklistUpdateItem(
          args: value,
          summary: _summary(value, state),
        ),
      );
    }

    return _ExpectedChecklistUpdateBatch(
      added: kept.length,
      skipped: skipped,
      redundant: redundant,
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
    required this.kept,
  });

  final int added;
  final int skipped;
  final int redundant;
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

enum _GeneratedBuildItemSlot {
  titleA,
  titleB,
  estimateA,
  estimateB,
  statusOpen,
  statusDone,
  nestedA,
  nestedB,
}

enum _GeneratedBuildSetSlot { alpha, beta, gamma }

enum _GeneratedBuildStatusSlot {
  pending,
  confirmed,
  rejected,
  deferred,
  retracted,
}

class _GeneratedBuildExistingItemSpec {
  const _GeneratedBuildExistingItemSpec({
    required this.itemSlot,
    required this.staleStatus,
    required this.freshStatus,
  });

  final _GeneratedBuildItemSlot itemSlot;
  final _GeneratedBuildStatusSlot staleStatus;
  final _GeneratedBuildStatusSlot freshStatus;

  ChangeItem get staleItem => _generatedBuildItem(
    itemSlot,
    status: _generatedBuildStatus(staleStatus),
  );

  ChangeItem get freshItem => _generatedBuildItem(
    itemSlot,
    status: _generatedBuildStatus(freshStatus),
  );

  @override
  String toString() {
    return '_GeneratedBuildExistingItemSpec('
        'itemSlot: $itemSlot, '
        'staleStatus: $staleStatus, '
        'freshStatus: $freshStatus)';
  }
}

class _GeneratedBuildExistingSetSpec {
  const _GeneratedBuildExistingSetSpec({
    required this.setSlot,
    required this.included,
    required this.createdAtOffset,
    required this.returnsFresh,
    required this.items,
  });

  final _GeneratedBuildSetSlot setSlot;
  final bool included;
  final int createdAtOffset;
  final bool returnsFresh;
  final List<_GeneratedBuildExistingItemSpec> items;

  String get id => 'generated-build-set-${setSlot.name}';

  DateTime get createdAt => DateTime(2024, 3, 15, 9 + createdAtOffset);

  ChangeSetEntity get staleSet => makeTestChangeSet(
    id: id,
    createdAt: createdAt,
    items: [for (final item in items) item.staleItem],
  );

  ChangeSetEntity get freshSet => staleSet.copyWith(
    items: [for (final item in items) item.freshItem],
  );

  ChangeSetEntity get currentSet => returnsFresh ? freshSet : staleSet;

  @override
  String toString() {
    return '_GeneratedBuildExistingSetSpec('
        'setSlot: $setSlot, '
        'included: $included, '
        'createdAtOffset: $createdAtOffset, '
        'returnsFresh: $returnsFresh, '
        'items: $items)';
  }
}

class _GeneratedBuildScenario {
  const _GeneratedBuildScenario({
    required this.alpha,
    required this.beta,
    required this.gamma,
    required this.proposedSlots,
    required this.rejectedSlots,
  });

  final _GeneratedBuildExistingSetSpec alpha;
  final _GeneratedBuildExistingSetSpec beta;
  final _GeneratedBuildExistingSetSpec gamma;
  final List<_GeneratedBuildItemSlot> proposedSlots;
  final List<_GeneratedBuildItemSlot> rejectedSlots;

  List<_GeneratedBuildExistingSetSpec> get includedSetSpecs => [
    if (alpha.included) alpha,
    if (beta.included) beta,
    if (gamma.included) gamma,
  ];

  List<ChangeSetEntity> get staleSets => [
    for (final spec in includedSetSpecs) spec.staleSet,
  ];

  Map<String, ChangeSetEntity> get freshById => {
    for (final spec in includedSetSpecs)
      if (spec.returnsFresh) spec.id: spec.freshSet,
  };

  Set<String> get rejectedFingerprints => {
    for (final slot in rejectedSlots)
      ChangeItem.fingerprint(_generatedBuildItem(slot)),
  };

  List<ChangeItem> get proposedItems {
    final fingerprints = <String>{};
    final items = <ChangeItem>[];
    for (final slot in proposedSlots) {
      final item = _generatedBuildItem(slot);
      if (fingerprints.add(ChangeItem.fingerprint(item))) {
        items.add(item);
      }
    }
    return items;
  }

  _ExpectedBuildResult expected() {
    final existingSets = includedSetSpecs;
    final proposed = proposedItems;
    if (proposed.isEmpty) {
      return const _ExpectedBuildResult();
    }

    final blockingFingerprints = {
      ...rejectedFingerprints,
      for (final spec in existingSets)
        for (final item in spec.currentSet.items)
          if (_blocksReproposal(item)) ChangeItem.fingerprint(item),
    };
    final deduped = proposed
        .where(
          (item) =>
              !blockingFingerprints.contains(ChangeItem.fingerprint(item)),
        )
        .toList();
    if (deduped.isEmpty) {
      return const _ExpectedBuildResult();
    }

    if (existingSets.isEmpty) {
      return _ExpectedBuildResult(resultItems: deduped);
    }

    final survivorSpec = _survivorSpec(existingSets);
    final survivor = survivorSpec.currentSet;
    final knownFingerprints = {
      ...survivor.items.map(ChangeItem.fingerprint),
      ...deduped.map(ChangeItem.fingerprint),
    };
    final otherItems = <ChangeItem>[];
    for (final spec in existingSets) {
      if (spec.id == survivorSpec.id) continue;
      for (final item in spec.currentSet.items) {
        if (knownFingerprints.add(ChangeItem.fingerprint(item))) {
          otherItems.add(item);
        }
      }
    }

    return _ExpectedBuildResult(
      survivorId: survivor.id,
      resultItems: [...survivor.items, ...otherItems, ...deduped],
      resolvedSets: [
        for (final spec in existingSets)
          if (spec.id != survivorSpec.id)
            _expectedRetiredConsolidatedSet(spec.currentSet),
      ],
    );
  }

  bool _blocksReproposal(ChangeItem item) {
    return item.status != ChangeItemStatus.confirmed &&
        item.status != ChangeItemStatus.retracted;
  }

  _GeneratedBuildExistingSetSpec _survivorSpec(
    List<_GeneratedBuildExistingSetSpec> specs,
  ) {
    return specs.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
  }

  @override
  String toString() {
    return '_GeneratedBuildScenario('
        'sets: $includedSetSpecs, '
        'proposedSlots: $proposedSlots, '
        'rejectedSlots: $rejectedSlots)';
  }
}

class _ExpectedBuildResult {
  const _ExpectedBuildResult({
    this.survivorId,
    this.resultItems = const [],
    this.resolvedSets = const [],
  });

  final String? survivorId;
  final List<ChangeItem> resultItems;
  final List<ChangeSetEntity> resolvedSets;

  bool get shouldBuild => resultItems.isNotEmpty;
  bool get createsNewSet => shouldBuild && survivorId == null;
}

ChangeSetEntity _expectedRetiredConsolidatedSet(ChangeSetEntity set) {
  return set.copyWith(
    items: [
      for (final item in set.items)
        item.status == ChangeItemStatus.pending
            ? item.copyWith(status: ChangeItemStatus.retracted)
            : item,
    ],
    status: ChangeSetStatus.resolved,
  );
}

ChangeItem _generatedBuildItem(
  _GeneratedBuildItemSlot slot, {
  ChangeItemStatus status = ChangeItemStatus.pending,
}) {
  final (toolName, args, summary) = switch (slot) {
    _GeneratedBuildItemSlot.titleA => (
      TaskAgentToolNames.setTaskTitle,
      <String, dynamic>{'title': 'Generated title A'},
      'Set title to A',
    ),
    _GeneratedBuildItemSlot.titleB => (
      TaskAgentToolNames.setTaskTitle,
      <String, dynamic>{'title': 'Generated title B'},
      'Set title to B',
    ),
    _GeneratedBuildItemSlot.estimateA => (
      TaskAgentToolNames.updateTaskEstimate,
      <String, dynamic>{'minutes': 15},
      'Set estimate to 15 minutes',
    ),
    _GeneratedBuildItemSlot.estimateB => (
      TaskAgentToolNames.updateTaskEstimate,
      <String, dynamic>{'minutes': 45},
      'Set estimate to 45 minutes',
    ),
    _GeneratedBuildItemSlot.statusOpen => (
      TaskAgentToolNames.setTaskStatus,
      <String, dynamic>{'status': 'OPEN'},
      'Set status to open',
    ),
    _GeneratedBuildItemSlot.statusDone => (
      TaskAgentToolNames.setTaskStatus,
      <String, dynamic>{'status': 'DONE'},
      'Set status to done',
    ),
    _GeneratedBuildItemSlot.nestedA => (
      TaskAgentToolNames.addChecklistItem,
      <String, dynamic>{
        'title': 'Generated checklist A',
        'metadata': <String, dynamic>{'priority': 'high', 'source': 'A'},
      },
      'Add generated checklist A',
    ),
    _GeneratedBuildItemSlot.nestedB => (
      TaskAgentToolNames.addChecklistItem,
      <String, dynamic>{
        'title': 'Generated checklist B',
        'metadata': <String, dynamic>{'priority': 'low', 'source': 'B'},
      },
      'Add generated checklist B',
    ),
  };
  return ChangeItem(
    toolName: toolName,
    args: args,
    humanSummary: summary,
    status: status,
  );
}

ChangeItemStatus _generatedBuildStatus(_GeneratedBuildStatusSlot slot) {
  return switch (slot) {
    _GeneratedBuildStatusSlot.pending => ChangeItemStatus.pending,
    _GeneratedBuildStatusSlot.confirmed => ChangeItemStatus.confirmed,
    _GeneratedBuildStatusSlot.rejected => ChangeItemStatus.rejected,
    _GeneratedBuildStatusSlot.deferred => ChangeItemStatus.deferred,
    _GeneratedBuildStatusSlot.retracted => ChangeItemStatus.retracted,
  };
}

extension _AnyGeneratedBuildScenario on glados.Any {
  glados.Generator<_GeneratedBuildItemSlot> get buildItemSlot =>
      glados.AnyUtils(this).choose(_GeneratedBuildItemSlot.values);

  glados.Generator<_GeneratedBuildStatusSlot> get buildStatusSlot =>
      glados.AnyUtils(this).choose(_GeneratedBuildStatusSlot.values);

  glados.Generator<_GeneratedBuildExistingItemSpec> get buildExistingItemSpec =>
      glados.CombinableAny(this).combine3(
        buildItemSlot,
        buildStatusSlot,
        buildStatusSlot,
        (
          _GeneratedBuildItemSlot itemSlot,
          _GeneratedBuildStatusSlot staleStatus,
          _GeneratedBuildStatusSlot freshStatus,
        ) => _GeneratedBuildExistingItemSpec(
          itemSlot: itemSlot,
          staleStatus: staleStatus,
          freshStatus: freshStatus,
        ),
      );

  glados.Generator<_GeneratedBuildExistingSetSpec> buildExistingSetSpec(
    _GeneratedBuildSetSlot setSlot,
  ) {
    return glados.CombinableAny(this).combine4(
      glados.AnyUtils(this).choose([false, true]),
      glados.IntAnys(this).intInRange(0, 3),
      glados.AnyUtils(this).choose([false, true]),
      glados.ListAnys(
        this,
      ).listWithLengthInRange(0, 4, buildExistingItemSpec),
      (
        bool included,
        int createdAtOffset,
        bool returnsFresh,
        List<_GeneratedBuildExistingItemSpec> items,
      ) => _GeneratedBuildExistingSetSpec(
        setSlot: setSlot,
        included: included,
        createdAtOffset: createdAtOffset,
        returnsFresh: returnsFresh,
        items: items,
      ),
    );
  }

  glados.Generator<_GeneratedBuildScenario> get buildScenario =>
      glados.CombinableAny(this).combine5(
        buildExistingSetSpec(_GeneratedBuildSetSlot.alpha),
        buildExistingSetSpec(_GeneratedBuildSetSlot.beta),
        buildExistingSetSpec(_GeneratedBuildSetSlot.gamma),
        glados.ListAnys(this).listWithLengthInRange(0, 6, buildItemSlot),
        glados.ListAnys(this).listWithLengthInRange(0, 4, buildItemSlot),
        (
          _GeneratedBuildExistingSetSpec alpha,
          _GeneratedBuildExistingSetSpec beta,
          _GeneratedBuildExistingSetSpec gamma,
          List<_GeneratedBuildItemSlot> proposedSlots,
          List<_GeneratedBuildItemSlot> rejectedSlots,
        ) => _GeneratedBuildScenario(
          alpha: alpha,
          beta: beta,
          gamma: gamma,
          proposedSlots: proposedSlots,
          rejectedSlots: rejectedSlots,
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

  group('addItem', () {
    test('adds a single item to the builder', () async {
      await builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 120},
        humanSummary: 'Set estimate to 2 hours',
      );

      expect(builder.hasItems, isTrue);
      expect(builder.items, hasLength(1));
      expect(builder.items.first.toolName, 'update_task_estimate');
      expect(builder.items.first.args, {'minutes': 120});
      expect(builder.items.first.humanSummary, 'Set estimate to 2 hours');
      expect(builder.items.first.status, ChangeItemStatus.pending);
    });

    test('accumulates multiple items in order', () async {
      await builder.addItem(
        toolName: 'set_task_title',
        args: {'title': 'Fix bug'},
        humanSummary: 'Set title',
      );
      await builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 60},
        humanSummary: 'Set estimate',
      );

      expect(builder.items, hasLength(2));
      expect(builder.items[0].toolName, 'set_task_title');
      expect(builder.items[1].toolName, 'update_task_estimate');
    });
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
            return (title: 'Buy groceries', isChecked: false);
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

    test('falls back to truncated ID when resolver returns null', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (_) async => null,
      );

      await resolverBuilder.addBatchItem(
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

      expect(resolverBuilder.items, hasLength(1));
      expect(
        resolverBuilder.items.first.humanSummary,
        'Uncheck item abcdefgh…',
      );
    });

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
      when(() => mockLogger.enabledDomains).thenReturn({'agent_workflow'});
      when(
        () => mockLogger.error(
          any(),
          any(),
          error: any(named: 'error'),
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
          'agent_workflow',
          any(that: contains('failed to resolve checklist item state')),
          error: any(named: 'error'),
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

    test('generates summary with ? when label ID is missing', () async {
      await builder.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'confidence': 'high'},
          ],
        },
        summaryPrefix: 'Label',
      );

      expect(
        builder.items[0].humanSummary,
        'Assign label: "?" (high)',
      );
    });
  });

  group('hasItems', () {
    test('returns false when no items added', () {
      expect(builder.hasItems, isFalse);
    });

    test('returns true after adding an item', () async {
      await builder.addItem(
        toolName: 'test',
        args: {},
        humanSummary: 'test',
      );
      expect(builder.hasItems, isTrue);
    });
  });

  group('build → notification fire-and-forget', () {
    late MockNotificationRepository notificationRepository;
    late MockJournalDb journalDb;

    setUp(() async {
      notificationRepository = MockNotificationRepository();
      // setUpTestGetIt already registers a MockJournalDb; capture it as the
      // local handle so the test's `when(...)` stubs land on the same
      // instance the production code looks up via getIt.
      final mocks = await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<NotificationRepository>(
            notificationRepository,
          );
        },
      );
      journalDb = mocks.journalDb;

      when(
        () => notificationRepository.createTaskSuggestion(
          linkedTaskId: any(named: 'linkedTaskId'),
          suggestionCount: any(named: 'suggestionCount'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledFor: any(named: 'scheduledFor'),
          category: any(named: 'category'),
          idSeed: any(named: 'idSeed'),
        ),
      ).thenAnswer((_) async => null);
      // setUpTestGetIt already returns null for journalEntityById; the
      // individual tests override per-id stubs.
    });

    tearDown(tearDownTestGetIt);

    test(
      'fires one createTaskSuggestion per build with the pending count, task '
      'title in the body, and the change-set id as the inbox row seed',
      () async {
        // Resolve the task so the body reads as the task title.
        when(() => journalDb.journalEntityById('task-001')).thenAnswer(
          (_) async => makeTestTask(id: 'task-001', title: 'Tidy backlog'),
        );

        await builder.addItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 30},
          humanSummary: 'Set estimate to 30 minutes',
        );
        await builder.addItem(
          toolName: 'set_task_title',
          args: {'title': 'Tidy backlog (revised)'},
          humanSummary: 'Rename to Tidy backlog (revised)',
        );

        final entity = await builder.build(mockSyncService);

        expect(entity, isNotNull);
        // idSeed must be the change-set id so a fresh wave (a new change set
        // after the previous one was resolved) lands on a fresh inbox row,
        // even when the user already tapped through the prior alert.
        verify(
          () => notificationRepository.createTaskSuggestion(
            linkedTaskId: 'task-001',
            suggestionCount: 2,
            title: '2 suggestions need your attention',
            body: 'Tidy backlog',
            category: any(named: 'category'),
            idSeed: entity!.id,
          ),
        ).called(1);
      },
    );

    test(
      'singularizes the title when only one item is pending',
      () async {
        await builder.addItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 15},
          humanSummary: 'Set estimate to 15 minutes',
        );

        await builder.build(mockSyncService);

        verify(
          () => notificationRepository.createTaskSuggestion(
            linkedTaskId: 'task-001',
            suggestionCount: 1,
            title: '1 suggestion needs your attention',
            body: any(named: 'body'),
            category: any(named: 'category'),
            idSeed: any(named: 'idSeed'),
          ),
        ).called(1);
      },
    );

    test(
      'falls back to a generic body when the task title cannot be resolved',
      () async {
        await builder.addItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 5},
          humanSummary: '5 minutes',
        );

        await builder.build(mockSyncService);

        verify(
          () => notificationRepository.createTaskSuggestion(
            linkedTaskId: 'task-001',
            suggestionCount: 1,
            title: any(named: 'title'),
            body: 'Open the task to review.',
            category: any(named: 'category'),
            idSeed: any(named: 'idSeed'),
          ),
        ).called(1);
      },
    );

    test('skips the notification entirely when build() returns null', () async {
      // No items added — build short-circuits before any side effects.
      final result = await builder.build(mockSyncService);

      expect(result, isNull);
      verifyNever(
        () => notificationRepository.createTaskSuggestion(
          linkedTaskId: any(named: 'linkedTaskId'),
          suggestionCount: any(named: 'suggestionCount'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          category: any(named: 'category'),
          idSeed: any(named: 'idSeed'),
        ),
      );
    });

    test('swallows repository failures without breaking build()', () async {
      when(
        () => notificationRepository.createTaskSuggestion(
          linkedTaskId: any(named: 'linkedTaskId'),
          suggestionCount: any(named: 'suggestionCount'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledFor: any(named: 'scheduledFor'),
          category: any(named: 'category'),
        ),
      ).thenThrow(StateError('notify-boom'));

      await builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 45},
        humanSummary: 'Set estimate to 45 minutes',
      );

      // Builds successfully even though the notification side road threw.
      final entity = await builder.build(mockSyncService);
      expect(entity, isNotNull);
    });
  });

  group('build', () {
    test('returns null when no items', () async {
      final result = await builder.build(mockSyncService);
      expect(result, isNull);
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    test('builds and persists change set entity', () async {
      await builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 120},
        humanSummary: 'Set estimate to 2 hours',
      );

      final result = await builder.build(mockSyncService);

      expect(result, isNotNull);
      expect(result!.agentId, 'agent-001');
      expect(result.taskId, 'task-001');
      expect(result.threadId, 'thread-001');
      expect(result.runKey, 'run-key-001');
      expect(result.status, ChangeSetStatus.pending);
      expect(result.items, hasLength(1));
      expect(result.vectorClock, isNull);

      // Verify it was persisted.
      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;
      expect(captured, hasLength(1));
      expect(captured.first, isA<ChangeSetEntity>());
    });

    test('builds entity with exploded batch items', () async {
      await builder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {
          'items': [
            {'title': 'Item A'},
            {'title': 'Item B'},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      final result = await builder.build(mockSyncService);

      expect(result, isNotNull);
      expect(result!.items, hasLength(2));
      expect(result.items[0].toolName, 'add_checklist_item');
      expect(result.items[1].toolName, 'add_checklist_item');
    });

    test('drops items that already exist in pending change sets', () async {
      await builder.addItem(
        toolName: 'set_task_title',
        args: {'title': 'Fix bug'},
        humanSummary: 'Set title to "Fix bug"',
      );
      await builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 120},
        humanSummary: 'Set estimate to 2 hours',
      );

      final existingSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Fix bug'},
            humanSummary: 'Different summary, same change',
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNotNull);
      // Merged into existing set: 1 existing + 1 new.
      expect(
        result!.items.where((i) => i.toolName == 'update_task_estimate'),
        hasLength(1),
      );
    });

    test('returns null when all items are duplicates', () async {
      await builder.addItem(
        toolName: 'set_task_title',
        args: {'title': 'Fix bug'},
        humanSummary: 'Set title',
      );

      final existingSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Fix bug'},
            humanSummary: 'Already proposed',
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNull);
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    test('keeps items when args differ from existing pending', () async {
      await builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 120},
        humanSummary: 'Set estimate to 2 hours',
      );

      final existingSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 60},
            humanSummary: 'Set estimate to 1 hour',
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNotNull);
      expect(
        result!.items.last.args['minutes'],
        120,
      );
    });

    test('dedupes with deep map equality in args', () async {
      await builder.addItem(
        toolName: 'add_checklist_item',
        args: {
          'title': 'Design mockup',
          'metadata': {'priority': 'high'},
        },
        humanSummary: 'Add checklist item',
      );

      final existingSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'add_checklist_item',
            args: {
              'title': 'Design mockup',
              'metadata': {'priority': 'high'},
            },
            humanSummary: 'Already proposed',
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNull);
    });

    test('does not dedupe when existing sets list is empty', () async {
      await builder.addItem(
        toolName: 'set_task_title',
        args: {'title': 'Fix bug'},
        humanSummary: 'Set title',
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [],
      );

      expect(result, isNotNull);
      expect(result!.items, hasLength(1));
    });

    test('merges new items into existing change set', () async {
      await builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 90},
        humanSummary: 'Set estimate to 1.5 hours',
      );

      final existingSet = makeTestChangeSet(
        id: 'cs-existing',
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Fix bug'},
            humanSummary: 'Set title',
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNotNull);
      expect(result!.id, 'cs-existing');
      expect(result.items, hasLength(2));
      expect(result.items[0].toolName, 'set_task_title');
      expect(result.items[1].toolName, 'update_task_estimate');
    });

    test('preserves existing item statuses when merging', () async {
      await builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 90},
        humanSummary: 'Set estimate',
      );

      final existingSet = makeTestChangeSet(
        id: 'cs-existing',
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Fix bug'},
            humanSummary: 'Set title',
            status: ChangeItemStatus.confirmed,
          ),
          ChangeItem(
            toolName: 'set_task_status',
            args: {'status': 'IN_PROGRESS'},
            humanSummary: 'Set status',
            status: ChangeItemStatus.rejected,
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNotNull);
      expect(result!.items, hasLength(3));
      expect(result.items[0].status, ChangeItemStatus.confirmed);
      expect(result.items[1].status, ChangeItemStatus.rejected);
      expect(result.items[2].status, ChangeItemStatus.pending);
    });

    test('blocks re-proposal of rejected items', () async {
      // The agent proposes the exact same mutation that was already rejected.
      await builder.addItem(
        toolName: 'update_checklist_item',
        args: {'id': 'item-1', 'isChecked': true},
        humanSummary: 'Check off: "Buy milk"',
      );

      final existingSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_checklist_item',
            args: {'id': 'item-1', 'isChecked': true},
            humanSummary: 'Check off: "Buy milk"',
            status: ChangeItemStatus.rejected,
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNull, reason: 'rejected items must not be re-proposed');
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    test('blocks re-proposal of deferred items', () async {
      await builder.addItem(
        toolName: 'set_task_status',
        args: {'status': 'IN_PROGRESS'},
        humanSummary: 'Set status',
      );

      final existingSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'set_task_status',
            args: {'status': 'IN_PROGRESS'},
            humanSummary: 'Set status',
            status: ChangeItemStatus.deferred,
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNull, reason: 'deferred items must not be re-proposed');
    });

    test(
      'allows proposal when same tool has different args than rejected',
      () async {
        // The agent proposes a different value than what was rejected.
        await builder.addItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 60},
          humanSummary: 'Set estimate to 1 hour',
        );

        final existingSet = makeTestChangeSet(
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 120},
              humanSummary: 'Set estimate to 2 hours',
              status: ChangeItemStatus.rejected,
            ),
          ],
        );

        final result = await builder.build(
          mockSyncService,
          existingPendingSets: [existingSet],
        );

        expect(
          result,
          isNotNull,
          reason: 'different args should not be blocked',
        );
      },
    );

    test('skips confirmed items during dedup (already applied)', () async {
      // The agent proposes the same mutation that was already confirmed.
      // Confirmed items have been applied — re-proposing is a no-op but
      // should not be blocked by dedup (the redundancy filter catches this
      // at the checklist-item level instead).
      await builder.addItem(
        toolName: 'set_task_title',
        args: {'title': 'Fix bug'},
        humanSummary: 'Set title',
      );

      final existingSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Fix bug'},
            humanSummary: 'Set title',
            status: ChangeItemStatus.confirmed,
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNotNull, reason: 'confirmed items are not in dedup set');
    });

    test(
      'allows re-proposal after the agent retracted an identical item',
      () async {
        // The agent retracted this exact proposal in an earlier wake (e.g.
        // it had inferred the task was already at this state). If the task
        // context has since changed such that the proposal is once again
        // valuable, the agent must be allowed to re-propose — retraction
        // is a self-correction, not a sticky veto like user rejection.
        await builder.addItem(
          toolName: 'update_task_priority',
          args: {'priority': 'P1'},
          humanSummary: 'Set priority to P1',
        );

        final existingSet = makeTestChangeSet(
          items: const [
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P1'},
              humanSummary: 'Set priority to P1',
              status: ChangeItemStatus.retracted,
            ),
          ],
        );

        final result = await builder.build(
          mockSyncService,
          existingPendingSets: [existingSet],
        );

        expect(
          result,
          isNotNull,
          reason: 'retracted items are not in the dedup set',
        );
        // The newly proposed pending item lands alongside the retained
        // retracted record from the prior wake.
        expect(result!.items, hasLength(2));
        expect(
          result.items.where((i) => i.status == ChangeItemStatus.pending),
          hasLength(1),
        );
        expect(
          result.items.where((i) => i.status == ChangeItemStatus.retracted),
          hasLength(1),
        );
      },
    );

    test('creates new entity when no existing pending set', () async {
      await builder.addItem(
        toolName: 'set_task_title',
        args: {'title': 'New task'},
        humanSummary: 'Set title',
      );

      final result = await builder.build(mockSyncService);

      expect(result, isNotNull);
      expect(result!.items, hasLength(1));
      expect(result.agentId, 'agent-001');
      expect(result.taskId, 'task-001');
      verify(() => mockSyncService.upsertEntity(any())).called(1);
    });

    test(
      'consolidates multiple existing sets into one and resolves surplus',
      () async {
        await builder.addItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 45},
          humanSummary: 'Set estimate to 45 min',
        );

        // Two racing sets with some overlapping items.
        final older = makeTestChangeSet(
          id: 'cs-older',
          createdAt: DateTime(2024, 3, 15, 10),
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Fix bug'},
              humanSummary: 'Set title',
            ),
          ],
        );
        final newer = makeTestChangeSet(
          id: 'cs-newer',
          createdAt: DateTime(2024, 3, 15, 11),
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Fix bug'},
              humanSummary: 'Set title',
            ),
            ChangeItem(
              toolName: 'set_task_status',
              args: {'status': 'IN_PROGRESS'},
              humanSummary: 'Set status',
            ),
          ],
        );

        final result = await builder.build(
          mockSyncService,
          existingPendingSets: [older, newer],
        );

        expect(result, isNotNull);
        // Survivor is the newer set. It keeps its own items + new items.
        // The older set's title item is a duplicate (already in newer) so
        // it's not added again.
        expect(result!.id, 'cs-newer');
        expect(result.items, hasLength(3));
        expect(result.items[0].toolName, 'set_task_title');
        expect(result.items[1].toolName, 'set_task_status');
        expect(result.items[2].toolName, 'update_task_estimate');

        // Verify: survivor updated + older marked as resolved = 2 upserts.
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        expect(captured, hasLength(2));

        // First upsert: the consolidated survivor.
        final survivor = captured[0] as ChangeSetEntity;
        expect(survivor.id, 'cs-newer');
        expect(survivor.items, hasLength(3));

        // Second upsert: the surplus set marked as resolved, with its
        // original pending items retired so they cannot reappear as open
        // ledger proposals.
        final resolved = captured[1] as ChangeSetEntity;
        expect(resolved.id, 'cs-older');
        expect(resolved.status, ChangeSetStatus.resolved);
        expect(resolved.resolvedAt, isNotNull);
        expect(
          resolved.items.single.status,
          ChangeItemStatus.retracted,
        );
      },
    );

    test(
      'build uses fresh items from DB, not stale snapshot',
      () async {
        await builder.addItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 90},
          humanSummary: 'Set estimate to 90 min',
        );

        // The stale snapshot passed to build() has both items pending.
        final staleSet = makeTestChangeSet(
          id: 'cs-stale',
          createdAt: DateTime(2024, 3, 15, 10),
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Old title'},
              humanSummary: 'Set title',
            ),
            ChangeItem(
              toolName: 'set_task_status',
              args: {'status': 'OPEN'},
              humanSummary: 'Set status',
            ),
          ],
        );

        // Simulate a mid-wake confirmation: the DB has item 0 confirmed.
        final freshSet = staleSet.copyWith(
          items: [
            staleSet.items[0].copyWith(status: ChangeItemStatus.confirmed),
            staleSet.items[1],
          ],
          status: ChangeSetStatus.partiallyResolved,
        );

        when(
          () => mockRepository.getEntity('cs-stale'),
        ).thenAnswer((_) async => freshSet);

        final result = await builder.build(
          mockSyncService,
          existingPendingSets: [staleSet],
        );

        expect(result, isNotNull);

        // The merged set should use the fresh items (with confirmed status)
        // not the stale snapshot's items.
        final confirmedItems = result!.items
            .where((i) => i.status == ChangeItemStatus.confirmed)
            .toList();
        expect(
          confirmedItems,
          hasLength(1),
          reason: 'Mid-wake confirmation should be preserved',
        );
        expect(confirmedItems.first.args, {'title': 'Old title'});

        // The new item should still be appended.
        expect(
          result.items.last.toolName,
          'update_task_estimate',
        );
      },
    );

    test(
      'build uses fresh entities where available and stale fallback otherwise',
      () async {
        await builder.addItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 45},
          humanSummary: 'Set estimate to 45 min',
        );

        final staleOlder = makeTestChangeSet(
          id: 'cs-older',
          createdAt: DateTime(2024, 3, 15, 10),
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'stale older title'},
              humanSummary: 'Stale title',
            ),
          ],
        );
        final freshOlder = staleOlder.copyWith(
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'fresh older title'},
              humanSummary: 'Fresh title',
              status: ChangeItemStatus.rejected,
            ),
          ],
          status: ChangeSetStatus.partiallyResolved,
        );
        final staleNewer = makeTestChangeSet(
          id: 'cs-newer',
          createdAt: DateTime(2024, 3, 15, 11),
          items: const [
            ChangeItem(
              toolName: 'set_task_status',
              args: {'status': 'OPEN'},
              humanSummary: 'Set status',
            ),
          ],
        );

        when(
          () => mockRepository.getEntity('cs-older'),
        ).thenAnswer((_) async => freshOlder);
        when(
          () => mockRepository.getEntity('cs-newer'),
        ).thenAnswer((_) async => null);

        final result = await builder.build(
          mockSyncService,
          existingPendingSets: [staleOlder, staleNewer],
        );

        expect(result, isNotNull);
        expect(result!.id, 'cs-newer');
        expect(
          result.items.map((item) => item.args).toList(),
          [
            {'status': 'OPEN'},
            {'title': 'fresh older title'},
            {'minutes': 45},
          ],
        );
        expect(result.items[1].status, ChangeItemStatus.rejected);
        expect(
          result.items.any(
            (item) => item.args['title'] == 'stale older title',
          ),
          isFalse,
        );

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured.cast<ChangeSetEntity>();
        expect(captured, hasLength(2));
        expect(captured[0].id, 'cs-newer');
        expect(captured[1].id, 'cs-older');
        expect(captured[1].status, ChangeSetStatus.resolved);
        expect(captured[1].items, freshOlder.items);
      },
    );

    test(
      'build preserves fresh survivor replacement during consolidation',
      () async {
        await builder.addItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 120},
          humanSummary: 'Set estimate to 120 min',
        );

        final older = makeTestChangeSet(
          id: 'cs-older',
          createdAt: DateTime(2024, 3, 15, 10),
          items: const [
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P2'},
              humanSummary: 'Set priority',
            ),
          ],
        );
        final staleNewer = makeTestChangeSet(
          id: 'cs-newer',
          createdAt: DateTime(2024, 3, 15, 11),
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Original title'},
              humanSummary: 'Set title',
            ),
          ],
        );
        final freshNewer = staleNewer.copyWith(
          items: [
            staleNewer.items.first.copyWith(
              status: ChangeItemStatus.confirmed,
            ),
            const ChangeItem(
              toolName: 'set_task_status',
              args: {'status': 'IN_PROGRESS'},
              humanSummary: 'Set status',
            ),
          ],
          status: ChangeSetStatus.partiallyResolved,
        );

        when(
          () => mockRepository.getEntity('cs-newer'),
        ).thenAnswer((_) async => freshNewer);

        final result = await builder.build(
          mockSyncService,
          existingPendingSets: [older, staleNewer],
        );

        expect(result, isNotNull);
        expect(result!.id, 'cs-newer');
        expect(result.status, ChangeSetStatus.partiallyResolved);
        expect(
          result.items.map((item) => item.args).toList(),
          [
            {'title': 'Original title'},
            {'status': 'IN_PROGRESS'},
            {'priority': 'P2'},
            {'minutes': 120},
          ],
        );
        expect(result.items.first.status, ChangeItemStatus.confirmed);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured.cast<ChangeSetEntity>();
        expect(captured, hasLength(2));
        expect(captured.first, result);
        expect(captured.first.items.take(2).toList(), freshNewer.items);
      },
    );

    test('build re-reads every existing pending set before merging', () async {
      await builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 30},
        humanSummary: 'Set estimate to 30 min',
      );

      final first = makeTestChangeSet(
        id: 'cs-first',
        createdAt: DateTime(2024, 3, 15, 9),
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'First'},
            humanSummary: 'Set first title',
          ),
        ],
      );
      final second = makeTestChangeSet(
        id: 'cs-second',
        createdAt: DateTime(2024, 3, 15, 10),
        items: const [
          ChangeItem(
            toolName: 'set_task_status',
            args: {'status': 'OPEN'},
            humanSummary: 'Set status',
          ),
        ],
      );
      final third = makeTestChangeSet(
        id: 'cs-third',
        createdAt: DateTime(2024, 3, 15, 11),
        items: const [
          ChangeItem(
            toolName: 'update_task_priority',
            args: {'priority': 'P1'},
            humanSummary: 'Set priority',
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [first, second, third],
      );

      expect(result, isNotNull);
      expect(result!.id, 'cs-third');
      verify(() => mockRepository.getEntity('cs-first')).called(1);
      verify(() => mockRepository.getEntity('cs-second')).called(1);
      verify(() => mockRepository.getEntity('cs-third')).called(1);
    });

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

    glados.Glados(
      glados.any.buildScenario,
      glados.ExploreConfig(numRuns: 220),
    ).test(
      'matches generated build consolidation semantics',
      (scenario) async {
        final generatedSyncService = MockAgentSyncService();
        final generatedRepository = MockAgentRepository();
        final upserts = <ChangeSetEntity>[];
        final expected = scenario.expected();

        when(
          () => generatedSyncService.repository,
        ).thenReturn(generatedRepository);
        when(
          () => generatedRepository.getEntity(any()),
        ).thenAnswer((invocation) async {
          final id = invocation.positionalArguments.single as String;
          return scenario.freshById[id];
        });
        when(
          () => generatedSyncService.upsertEntity(any()),
        ).thenAnswer((invocation) async {
          upserts.add(invocation.positionalArguments.single as ChangeSetEntity);
        });

        final generatedBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
        );
        for (final slot in scenario.proposedSlots) {
          await generatedBuilder.addItem(
            toolName: _generatedBuildItem(slot).toolName,
            args: _generatedBuildItem(slot).args,
            humanSummary: _generatedBuildItem(slot).humanSummary,
          );
        }

        final result = await generatedBuilder.build(
          generatedSyncService,
          existingPendingSets: scenario.staleSets,
          rejectedFingerprints: scenario.rejectedFingerprints,
        );

        if (!expected.shouldBuild) {
          expect(result, isNull, reason: '$scenario');
          expect(upserts, isEmpty, reason: '$scenario');
          return;
        }

        expect(result, isNotNull, reason: '$scenario');
        expect(result!.items, expected.resultItems, reason: '$scenario');

        if (expected.createsNewSet) {
          expect(result.agentId, 'agent-001', reason: '$scenario');
          expect(result.taskId, 'task-001', reason: '$scenario');
          expect(result.threadId, 'thread-001', reason: '$scenario');
          expect(result.runKey, 'run-key-001', reason: '$scenario');
          expect(result.status, ChangeSetStatus.pending, reason: '$scenario');
          expect(upserts, [result], reason: '$scenario');
          return;
        }

        expect(result.id, expected.survivorId, reason: '$scenario');
        expect(
          upserts,
          hasLength(1 + expected.resolvedSets.length),
          reason: '$scenario',
        );
        expect(upserts.first, result, reason: '$scenario');

        final resolvedUpserts = upserts.skip(1).toList();
        expect(
          resolvedUpserts.map((set) => set.id).toList(),
          expected.resolvedSets.map((set) => set.id).toList(),
          reason: '$scenario',
        );
        for (var index = 0; index < expected.resolvedSets.length; index++) {
          final expectedResolved = expected.resolvedSets[index];
          final actualResolved = resolvedUpserts[index];
          expect(
            actualResolved.status,
            ChangeSetStatus.resolved,
            reason: '$scenario',
          );
          expect(actualResolved.resolvedAt, isNotNull, reason: '$scenario');
          expect(
            actualResolved.items,
            expectedResolved.items,
            reason: '$scenario',
          );
        }
      },
      tags: 'glados',
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
            (title: 'Buy groceries', isChecked: true),
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
              (title: 'Write tests', isChecked: false),
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

    test('allows non-redundant check update to pass through', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async =>
            (title: 'Deploy app', isChecked: false),
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
          if (id == 'item-a') return (title: 'Already done', isChecked: true);
          if (id == 'item-b') return (title: 'Not done', isChecked: false);
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
              (title: 'Old title', isChecked: true),
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
            (title: 'Old title', isChecked: true),
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

    test('keeps item when resolver returns null (item not found)', () async {
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

      expect(resolverBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
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
              (title: 'Ambiguous item', isChecked: null),
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
              (title: 'Same title', isChecked: true),
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
              (title: 'Some item', isChecked: true),
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
              (title: 'Some item', isChecked: true),
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
            (title: 'Existing item', isChecked: true),
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

  group('add_checklist_item title-based dedup', () {
    test(
      'suppresses add when title already exists (case-insensitive)',
      () async {
        final titledBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          existingChecklistTitlesResolver: () async => {
            'buy groceries',
            'write tests',
          },
        );

        final result = await titledBuilder.addBatchItem(
          toolName: 'add_multiple_checklist_items',
          args: {
            'items': [
              {'title': 'Buy Groceries'}, // exists (case-insensitive)
              {'title': 'Deploy app'}, // novel
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(titledBuilder.items, hasLength(1));
        expect(titledBuilder.items.first.args['title'], 'Deploy app');
        expect(result.added, 1);
        expect(result.redundant, 1);
        expect(
          result.redundantDetails.first,
          contains('"Buy Groceries" already exists on the task'),
        );
      },
    );

    test('allows add when title is novel', () async {
      final titledBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingChecklistTitlesResolver: () async => {
          'buy groceries',
          'write tests',
        },
      );

      final result = await titledBuilder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {
          'items': [
            {'title': 'Deploy to production'},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(titledBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
    });

    test(
      'same-wake dedup: second add with same title in batch is suppressed',
      () async {
        final titledBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          existingChecklistTitlesResolver: () async => <String>{},
        );

        final result = await titledBuilder.addBatchItem(
          toolName: 'add_multiple_checklist_items',
          args: {
            'items': [
              {'title': 'Write tests'},
              {'title': 'write tests'}, // same title, different case
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(titledBuilder.items, hasLength(1));
        expect(result.added, 1);
        expect(result.redundant, 1);
      },
    );

    test('addItem suppresses add_checklist_item when title exists', () async {
      final titledBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingChecklistTitlesResolver: () async => {'buy milk'},
      );

      final redundancy = await titledBuilder.addItem(
        toolName: 'add_checklist_item',
        args: {'title': 'Buy Milk'},
        humanSummary: 'Add: "Buy Milk"',
      );

      expect(redundancy, isNotNull);
      expect(redundancy, contains('"Buy Milk" already exists'));
      expect(titledBuilder.items, isEmpty);
    });

    test('addItem allows novel add_checklist_item', () async {
      final titledBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingChecklistTitlesResolver: () async => {'buy milk'},
      );

      final redundancy = await titledBuilder.addItem(
        toolName: 'add_checklist_item',
        args: {'title': 'Write docs'},
        humanSummary: 'Add: "Write docs"',
      );

      expect(redundancy, isNull);
      expect(titledBuilder.items, hasLength(1));
    });

    test('gracefully handles resolver failure', () async {
      final titledBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingChecklistTitlesResolver: () async =>
            throw Exception('DB error'),
      );

      final result = await titledBuilder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {
          'items': [
            {'title': 'New item'},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      // Should keep the item (conservative fallback).
      expect(titledBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
    });

    test('logs resolved title count via domainLogger', () async {
      final mockLogger = MockDomainLogger();
      when(() => mockLogger.enabledDomains).thenReturn({'agent_workflow'});
      when(
        () => mockLogger.log(
          any(),
          any(),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      final titledBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingChecklistTitlesResolver: () async => {'item a', 'item b'},
        domainLogger: mockLogger,
      );

      await titledBuilder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {
          'items': [
            {'title': 'Novel item'},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      verify(
        () => mockLogger.log(
          LogDomains.agentWorkflow,
          any(that: contains('resolved 2 existing checklist')),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    });
  });

  group('rejected fingerprint dedup in build()', () {
    test('blocks re-proposal matching a rejected fingerprint', () async {
      await builder.addItem(
        toolName: 'add_checklist_item',
        args: {'title': 'Buy milk'},
        humanSummary: 'Add: "Buy milk"',
      );

      // Reconstruct the fingerprint as the workflow would.
      final rejectedFp = ChangeItem.fingerprint(
        const ChangeItem(
          toolName: 'add_checklist_item',
          args: {'title': 'Buy milk'},
          humanSummary: '',
        ),
      );

      final result = await builder.build(
        mockSyncService,
        rejectedFingerprints: {rejectedFp},
      );

      expect(
        result,
        isNull,
        reason: 'item matching a rejected fingerprint must be blocked',
      );
    });

    test('allows item that does not match any rejected fingerprint', () async {
      await builder.addItem(
        toolName: 'add_checklist_item',
        args: {'title': 'Buy milk'},
        humanSummary: 'Add: "Buy milk"',
      );

      // Different args → different fingerprint.
      final rejectedFp = ChangeItem.fingerprint(
        const ChangeItem(
          toolName: 'add_checklist_item',
          args: {'title': 'Buy eggs'},
          humanSummary: '',
        ),
      );

      final result = await builder.build(
        mockSyncService,
        rejectedFingerprints: {rejectedFp},
      );

      expect(result, isNotNull);
      expect(result!.items, hasLength(1));
    });
  });

  group('task splitting — addFollowUpTask', () {
    test(
      'generates deterministic placeholder from sourceTaskId + title',
      () async {
        final placeholder1 = await builder.addFollowUpTask(
          args: {'title': 'Follow-Up A'},
          humanSummary: 'Create follow-up task A',
        );

        // Same source task and title should produce the same placeholder.
        // The compound key includes title|dueDate|priority (empty when absent).
        final placeholder2 = ChangeSetBuilder.deterministicPlaceholder(
          'task-001',
          'Follow-Up A||',
        );

        expect(placeholder1, placeholder2);
        expect(placeholder1, isNotEmpty);
      },
    );

    test('adds item with _placeholderTaskId in args', () async {
      final placeholder = await builder.addFollowUpTask(
        args: {'title': 'Follow-Up B'},
        humanSummary: 'Create follow-up task B',
      );

      expect(builder.items, hasLength(1));
      final item = builder.items.first;
      expect(item.toolName, 'create_follow_up_task');
      expect(item.args['title'], 'Follow-Up B');
      expect(item.args['_placeholderTaskId'], placeholder);
    });

    test('uses placeholder as default groupId', () async {
      final placeholder = await builder.addFollowUpTask(
        args: {'title': 'Follow-Up C'},
        humanSummary: 'Create follow-up task C',
      );

      expect(builder.items.first.groupId, placeholder);
    });

    test('uses provided groupId over default', () async {
      await builder.addFollowUpTask(
        args: {'title': 'Follow-Up D'},
        humanSummary: 'Create follow-up task D',
        groupId: 'custom-group',
      );

      expect(builder.items.first.groupId, 'custom-group');
    });

    test('deterministic placeholder is stable across wakes', () {
      // Two different builder instances with the same task ID should
      // produce the same placeholder for the same title.
      final builder2 = ChangeSetBuilder(
        agentId: 'agent-002',
        taskId: 'task-001',
        threadId: 'thread-002',
        runKey: 'run-key-002',
      );

      final p1 = ChangeSetBuilder.deterministicPlaceholder(
        'task-001',
        'Refactor login',
      );
      final p2 = ChangeSetBuilder.deterministicPlaceholder(
        builder2.taskId,
        'Refactor login',
      );

      expect(p1, p2);
    });

    test('different titles produce different placeholders', () {
      final p1 = ChangeSetBuilder.deterministicPlaceholder(
        'task-001',
        'Follow-Up A',
      );
      final p2 = ChangeSetBuilder.deterministicPlaceholder(
        'task-001',
        'Follow-Up B',
      );

      expect(p1, isNot(p2));
    });

    test('followUpPlaceholderId returns null when no follow-up exists', () {
      expect(builder.followUpPlaceholderId, isNull);
    });

    test(
      'followUpPlaceholderId returns placeholder after addFollowUpTask',
      () async {
        final placeholder = await builder.addFollowUpTask(
          args: {'title': 'Follow-Up X'},
          humanSummary: 'Create follow-up task X',
        );

        expect(builder.followUpPlaceholderId, placeholder);
      },
    );

    glados.Glados(
      glados.any.followUpScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'dedupes generated canonical follow-up proposals',
      (scenario) async {
        final generatedBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
        );

        final firstPlaceholder = await generatedBuilder.addFollowUpTask(
          args: scenario.firstArgs,
          humanSummary: 'Create generated follow-up',
        );
        final secondPlaceholder = await generatedBuilder.addFollowUpTask(
          args: scenario.secondArgs,
          humanSummary: 'Create generated follow-up again',
        );

        expect(
          firstPlaceholder,
          scenario.expectedPlaceholder(generatedBuilder.taskId),
        );
        expect(secondPlaceholder, firstPlaceholder, reason: '$scenario');
        expect(generatedBuilder.items, hasLength(1), reason: '$scenario');
        expect(generatedBuilder.followUpPlaceholderId, firstPlaceholder);

        final args = generatedBuilder.items.single.args;
        expect(args['title'], scenario.title, reason: '$scenario');
        if (scenario.includeDueDate) {
          expect(args['dueDate'], scenario.dueDate, reason: '$scenario');
        } else {
          expect(args.containsKey('dueDate'), isFalse, reason: '$scenario');
        }
        if (scenario.includePriority) {
          expect(args['priority'], scenario.priority, reason: '$scenario');
        } else {
          expect(args.containsKey('priority'), isFalse, reason: '$scenario');
        }
        expect(args['_placeholderTaskId'], firstPlaceholder);
        expect(generatedBuilder.items.single.groupId, firstPlaceholder);
      },
      tags: 'glados',
    );
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
  });
}

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

    test('proposedFingerprints reflects every queued item', () async {
      expect(builder.proposedFingerprints, isEmpty);

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

      // These are what the workflow passes as skipFingerprints so an in-flight
      // retraction of an item being re-proposed this wake is suppressed.
      expect(builder.proposedFingerprints, {
        ChangeItem.fingerprintFromParts('set_task_title', {'title': 'Fix bug'}),
        ChangeItem.fingerprintFromParts('update_task_estimate', {
          'minutes': 60,
        }),
      });
    });

    test(
      'keeps only the latest running timer update per timer queued in a wake',
      () async {
        await builder.addItem(
          toolName: TaskAgentToolNames.updateRunningTimer,
          args: const {
            'timerId': 'timer-1',
            'summary': 'Earlier timer text',
          },
          humanSummary: 'Update running timer text: "Earlier timer text"',
        );
        await builder.addItem(
          toolName: TaskAgentToolNames.updateRunningTimer,
          args: const {
            'timerId': 'timer-1',
            'summary': 'Latest timer text',
          },
          humanSummary: 'Update running timer text: "Latest timer text"',
        );
        await builder.addItem(
          toolName: TaskAgentToolNames.updateRunningTimer,
          args: const {
            'timerId': 'timer-2',
            'summary': 'Other timer text',
          },
          humanSummary: 'Update running timer text: "Other timer text"',
        );

        expect(builder.items, hasLength(2));
        expect(
          builder.items.map((item) => item.args['timerId']),
          ['timer-1', 'timer-2'],
        );
        expect(builder.items.first.args['summary'], 'Latest timer text');
        expect(builder.items.last.args['summary'], 'Other timer text');
      },
    );

    test(
      'keeps same-summary running timer updates for different timers',
      () async {
        final firstResult = await builder.addItem(
          toolName: TaskAgentToolNames.updateRunningTimer,
          args: const {
            'timerId': 'timer-1',
            'summary': 'Focus block',
          },
          humanSummary: 'Update running timer text: "Focus block"',
        );
        final secondResult = await builder.addItem(
          toolName: TaskAgentToolNames.updateRunningTimer,
          args: const {
            'timerId': 'timer-2',
            'summary': 'Focus block',
          },
          humanSummary: 'Update running timer text: "Focus block"',
        );

        expect(firstResult, isNull);
        expect(secondResult, isNull);
        expect(builder.items, hasLength(2));
        expect(
          builder.items.map((item) => item.args['timerId']),
          ['timer-1', 'timer-2'],
        );
      },
    );
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

    test('logs notification failures with sanitized task id', () async {
      final mockLogger = MockDomainLogger();
      when(
        () => mockLogger.error(
          any(),
          any(),
          message: any(named: 'message'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);
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
      ).thenThrow(StateError('notify-boom'));

      final loggingBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        domainLogger: mockLogger,
      );

      await loggingBuilder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 45},
        humanSummary: 'Set estimate to 45 minutes',
      );

      final entity = await loggingBuilder.build(mockSyncService);

      expect(entity, isNotNull);
      final captured = verify(
        () => mockLogger.error(
          LogDomain.agentWorkflow,
          any(),
          message: captureAny(named: 'message'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'ChangeSetBuilder',
        ),
      ).captured;
      final message = captured.single as String;
      expect(message, contains('[id:task-0]'));
      expect(message, isNot(contains('task-001')));
    });

    test(
      'does not fire for a set whose items are all non-pending',
      () async {
        // build() can never hand the notifier a zero-pending set (an
        // all-deduped wake returns null before notifying), so exercise the
        // defensive guard through the test seam directly.
        final resolvedSet = makeTestChangeSet(
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Fix bug'},
              humanSummary: 'Set title to "Fix bug"',
              status: ChangeItemStatus.rejected,
            ),
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 30},
              humanSummary: 'Set estimate to 30 minutes',
              status: ChangeItemStatus.confirmed,
            ),
          ],
        );

        await builder.debugNotifyTaskNeedsAttention(resolvedSet);

        verifyNever(
          () => notificationRepository.createTaskSuggestion(
            linkedTaskId: any(named: 'linkedTaskId'),
            suggestionCount: any(named: 'suggestionCount'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledFor: any(named: 'scheduledFor'),
            category: any(named: 'category'),
            idSeed: any(named: 'idSeed'),
          ),
        );
      },
    );
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

    test(
      'drops verbatim visible duplicates even when tool args differ',
      () async {
        await builder.addItem(
          toolName: 'update_checklist_item',
          args: {'id': 'new-item-id', 'isChecked': true},
          humanSummary: 'Check off: "Address CodeRabbit review comments"',
        );

        final existingSet = makeTestChangeSet(
          items: const [
            ChangeItem(
              toolName: 'update_checklist_item',
              args: {'id': 'old-item-id', 'isChecked': true},
              humanSummary: 'Check off: "Address CodeRabbit review comments"',
            ),
          ],
        );

        final result = await builder.build(
          mockSyncService,
          existingPendingSets: [existingSet],
        );

        expect(
          result,
          isNull,
          reason: 'verbatim duplicate suggestions must not be persisted',
        );
        verifyNever(() => mockSyncService.upsertEntity(any()));
      },
    );

    test(
      'sticky-rejects verbatim visible duplicates by rejectedDisplayKeys',
      () async {
        const summary = 'Check off: "Address CodeRabbit review comments"';
        await builder.addItem(
          toolName: 'update_checklist_item',
          args: {'id': 'new-item-id', 'isChecked': true},
          humanSummary: summary,
        );

        final rejectedDisplayKey = ChangeItem.displayDuplicateKeyFromParts(
          'update_checklist_item',
          summary,
          args: {'id': 'rejected-item-id', 'isChecked': true},
        );

        final result = await builder.build(
          mockSyncService,
          existingPendingSets: [],
          rejectedDisplayKeys: {rejectedDisplayKey!},
        );

        expect(
          result,
          isNull,
          reason:
              'verbatim duplicate rejected suggestions must stay suppressed',
        );
        verifyNever(() => mockSyncService.upsertEntity(any()));
      },
    );

    test(
      'does not dedupe same-summary running timer updates for different timers',
      () async {
        await builder.addItem(
          toolName: TaskAgentToolNames.updateRunningTimer,
          args: const {
            'timerId': 'timer-2',
            'summary': 'Focus block',
          },
          humanSummary: 'Update running timer text: "Focus block"',
        );

        final existingSet = makeTestChangeSet(
          items: const [
            ChangeItem(
              toolName: TaskAgentToolNames.updateRunningTimer,
              args: {
                'timerId': 'timer-1',
                'summary': 'Focus block',
              },
              humanSummary: 'Update running timer text: "Focus block"',
            ),
          ],
        );

        final result = await builder.build(
          mockSyncService,
          existingPendingSets: [existingSet],
        );

        expect(result, isNotNull);
        final timerItems = result!.items
            .where(
              (item) => item.toolName == TaskAgentToolNames.updateRunningTimer,
            )
            .toList();
        expect(timerItems, hasLength(2));
        expect(
          timerItems.map((item) => item.args['timerId']),
          ['timer-1', 'timer-2'],
        );
      },
    );

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

    test(
      'retracts existing running timer update when newer text is proposed',
      () async {
        await builder.addItem(
          toolName: TaskAgentToolNames.updateRunningTimer,
          args: const {
            'timerId': 'timer-1',
            'summary': 'Latest timer text',
          },
          humanSummary: 'Update running timer text: "Latest timer text"',
        );

        final existingSet = makeTestChangeSet(
          id: 'cs-running',
          items: const [
            ChangeItem(
              toolName: TaskAgentToolNames.updateRunningTimer,
              args: {
                'timerId': 'timer-1',
                'summary': 'Earlier timer text',
              },
              humanSummary: 'Update running timer text: "Earlier timer text"',
            ),
            ChangeItem(
              toolName: TaskAgentToolNames.updateRunningTimer,
              args: {
                'timerId': 'timer-2',
                'summary': 'Other timer text',
              },
              humanSummary: 'Update running timer text: "Other timer text"',
            ),
          ],
        );

        final result = await builder.build(
          mockSyncService,
          existingPendingSets: [existingSet],
        );

        expect(result, isNotNull);
        expect(result!.id, 'cs-running');
        final runningTimerItems = result.items
            .where(
              (item) => item.toolName == TaskAgentToolNames.updateRunningTimer,
            )
            .toList();
        expect(runningTimerItems, hasLength(3));
        expect(runningTimerItems[0].status, ChangeItemStatus.retracted);
        expect(runningTimerItems[1].status, ChangeItemStatus.pending);
        expect(runningTimerItems[1].args['summary'], 'Other timer text');
        expect(runningTimerItems[2].status, ChangeItemStatus.pending);
        expect(runningTimerItems[2].args['summary'], 'Latest timer text');

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final decision = captured.whereType<ChangeDecisionEntity>().single;
        expect(decision.changeSetId, 'cs-running');
        expect(decision.itemIndex, 0);
        expect(decision.toolName, TaskAgentToolNames.updateRunningTimer);
        expect(decision.verdict, ChangeDecisionVerdict.retracted);
        expect(decision.actor, DecisionActor.agent);
        expect(
          decision.retractionReason,
          'Superseded by a newer running timer update proposal.',
        );

        final updatedSet = captured.whereType<ChangeSetEntity>().single;
        expect(updatedSet.items.first.status, ChangeItemStatus.retracted);
        expect(updatedSet.items[1].status, ChangeItemStatus.pending);
        expect(updatedSet.items[1].args['summary'], 'Other timer text');
        expect(updatedSet.items.last.args['summary'], 'Latest timer text');
      },
    );

    test(
      'leaves sets without superseded timer items untouched during merge',
      () async {
        // A new running-timer update for timer-1 supersedes a pending one in
        // the first existing set, while a second existing set carries only an
        // unrelated item and must pass through _markItemsRetracted unchanged.
        await builder.addItem(
          toolName: TaskAgentToolNames.updateRunningTimer,
          args: const {
            'timerId': 'timer-1',
            'summary': 'Newest timer text',
          },
          humanSummary: 'Update running timer text: "Newest timer text"',
        );

        final timerSet = makeTestChangeSet(
          id: 'cs-timer',
          createdAt: DateTime(2024, 3, 15, 10),
          items: const [
            ChangeItem(
              toolName: TaskAgentToolNames.updateRunningTimer,
              args: {'timerId': 'timer-1', 'summary': 'Stale timer text'},
              humanSummary: 'Update running timer text: "Stale timer text"',
            ),
          ],
        );
        final unrelatedSet = makeTestChangeSet(
          id: 'cs-unrelated',
          createdAt: DateTime(2024, 3, 15, 11),
          items: const [
            ChangeItem(
              toolName: 'set_task_status',
              args: {'status': 'IN_PROGRESS'},
              humanSummary: 'Set status',
            ),
          ],
        );

        final result = await builder.build(
          mockSyncService,
          existingPendingSets: [timerSet, unrelatedSet],
        );

        // The newer unrelated set is the survivor; its single item is
        // preserved verbatim (passed through _markItemsRetracted unchanged).
        expect(result, isNotNull);
        expect(result!.id, 'cs-unrelated');
        final statusItem = result.items.singleWhere(
          (i) => i.toolName == 'set_task_status',
        );
        expect(statusItem.status, ChangeItemStatus.pending);
        expect(statusItem.args, {'status': 'IN_PROGRESS'});

        // The stale timer item lands in the survivor as retracted, and the
        // new timer update is appended as pending.
        final timerItems = result.items
            .where((i) => i.toolName == TaskAgentToolNames.updateRunningTimer)
            .toList();
        expect(timerItems, hasLength(2));
        expect(
          timerItems
              .singleWhere((i) => i.args['summary'] == 'Stale timer text')
              .status,
          ChangeItemStatus.retracted,
        );
        expect(
          timerItems
              .singleWhere((i) => i.args['summary'] == 'Newest timer text')
              .status,
          ChangeItemStatus.pending,
        );

        // A retraction decision is recorded against the original timer set.
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final decision = captured.whereType<ChangeDecisionEntity>().single;
        expect(decision.changeSetId, 'cs-timer');
        expect(decision.verdict, ChangeDecisionVerdict.retracted);
      },
    );

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
      glados.any.buildScenario,
      glados.ExploreConfig(numRuns: 180),
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
      when(
        () => mockLogger.enabledDomains,
      ).thenReturn({LogDomain.agentWorkflow});
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
          LogDomain.agentWorkflow,
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

    test(
      'strips whitespace-only dueDate and priority from enriched args',
      () async {
        // dueDate and priority are present as strings but canonicalize to
        // empty, so they must be removed from the enriched args entirely
        // (rather than stored as empty strings).
        await builder.addFollowUpTask(
          args: {
            'title': 'Follow-Up E',
            'dueDate': '   ',
            'priority': '  ',
          },
          humanSummary: 'Create follow-up task E',
        );

        expect(builder.items, hasLength(1));
        final args = builder.items.first.args;
        expect(args.containsKey('dueDate'), isFalse);
        expect(args.containsKey('priority'), isFalse);
        expect(args['title'], 'Follow-Up E');
        // The placeholder is keyed on the canonical (empty) due/priority.
        expect(
          args['_placeholderTaskId'],
          ChangeSetBuilder.deterministicPlaceholder(
            'task-001',
            'Follow-Up E||',
          ),
        );
      },
    );

    test('keeps and canonicalizes non-empty dueDate and priority', () async {
      // Counterpart to the strip case: non-empty values must survive and be
      // canonicalized (trimmed, priority upper-cased).
      await builder.addFollowUpTask(
        args: {
          'title': 'Follow-Up F',
          'dueDate': '  2026-06-15  ',
          'priority': '  high  ',
        },
        humanSummary: 'Create follow-up task F',
      );

      final args = builder.items.single.args;
      expect(args['dueDate'], '2026-06-15');
      expect(args['priority'], 'HIGH');
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
}

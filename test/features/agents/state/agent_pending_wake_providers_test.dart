import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../projects/test_utils.dart';
import '../test_utils.dart';

enum _GeneratedPendingWakeStateShape { active, missing, deleted }

enum _GeneratedPendingWakeScheduleShape {
  none,
  pendingOnly,
  scheduledOnly,
  both,
}

enum _GeneratedPendingWakeOffsetSlot { overdue, now, soon, later, far }

enum _GeneratedOngoingWakeSubjectShape {
  task,
  project,
  noSubject,
  missingState,
  stateThrows,
}

enum _GeneratedOngoingWakeTitleShape {
  usable,
  blank,
  missing,
  lookupThrows,
  unsupported,
}

enum _GeneratedOngoingWakeIdentityShape {
  usable,
  blank,
  missing,
  lookupThrows,
}

enum _GeneratedOngoingWakeStartSlot { first, second, third, fourth, fifth }

enum _GeneratedWakeRunReasonSlot {
  subscription,
  creation,
  reanalysis,
  manual,
}

enum _GeneratedWakeRunHourOffsetSlot {
  beforeWindow,
  windowStart,
  earlyWindow,
  middleWindow,
  currentHour,
  future,
}

enum _GeneratedWakeRunMinuteSlot { zero, early, middle, late }

typedef _PendingWakeExpectation = ({
  String agentId,
  PendingWakeType type,
  DateTime dueAt,
  String id,
});

typedef _OngoingWakeExpectation = ({
  String agentId,
  String title,
  DateTime startedAt,
  String id,
});

final _generatedProviderBase = DateTime(2026, 5, 22, 10, 30);
final _generatedOngoingBase = DateTime(2026, 5, 22, 8);
final _generatedHourlyNow = DateTime(2026, 5, 22, 14, 45);

String _generatedPendingAgentId(int index) => 'generated-pending-agent-$index';

String _generatedOngoingAgentId(int index) => 'generated-ongoing-agent-$index';

String _generatedOngoingSubjectId(int index) =>
    'generated-ongoing-subject-$index';

String _generatedWakeRecordId(
  String agentId,
  PendingWakeType type,
  DateTime dueAt,
) => '$agentId:${type.name}:${dueAt.toIso8601String()}';

Duration _generatedPendingWakeOffset(
  _GeneratedPendingWakeOffsetSlot slot,
  int index,
  int disambiguator,
) {
  final base = switch (slot) {
    _GeneratedPendingWakeOffsetSlot.overdue => const Duration(minutes: -20),
    _GeneratedPendingWakeOffsetSlot.now => Duration.zero,
    _GeneratedPendingWakeOffsetSlot.soon => const Duration(minutes: 5),
    _GeneratedPendingWakeOffsetSlot.later => const Duration(minutes: 45),
    _GeneratedPendingWakeOffsetSlot.far => const Duration(hours: 3),
  };
  return base + Duration(seconds: index * 3 + disambiguator);
}

DateTime _generatedPendingWakeDueAt(
  _GeneratedPendingWakeOffsetSlot slot,
  int index,
  int disambiguator,
) => _generatedProviderBase.add(
  _generatedPendingWakeOffset(slot, index, disambiguator),
);

int _generatedOngoingStartOffset(_GeneratedOngoingWakeStartSlot slot) {
  return switch (slot) {
    _GeneratedOngoingWakeStartSlot.first => 0,
    _GeneratedOngoingWakeStartSlot.second => 12,
    _GeneratedOngoingWakeStartSlot.third => 24,
    _GeneratedOngoingWakeStartSlot.fourth => 36,
    _GeneratedOngoingWakeStartSlot.fifth => 48,
  };
}

DateTime _generatedOngoingStartedAt(
  _GeneratedOngoingWakeStartSlot slot,
  int index,
) => _generatedOngoingBase.add(
  Duration(minutes: _generatedOngoingStartOffset(slot), seconds: index),
);

String _generatedWakeRunReason(_GeneratedWakeRunReasonSlot slot) {
  return switch (slot) {
    _GeneratedWakeRunReasonSlot.subscription => 'subscription',
    _GeneratedWakeRunReasonSlot.creation => 'creation',
    _GeneratedWakeRunReasonSlot.reanalysis => 'reanalysis',
    _GeneratedWakeRunReasonSlot.manual => 'manual',
  };
}

int _generatedWakeRunHourOffset(_GeneratedWakeRunHourOffsetSlot slot) {
  return switch (slot) {
    _GeneratedWakeRunHourOffsetSlot.beforeWindow => -26,
    _GeneratedWakeRunHourOffsetSlot.windowStart => -23,
    _GeneratedWakeRunHourOffsetSlot.earlyWindow => -18,
    _GeneratedWakeRunHourOffsetSlot.middleWindow => -7,
    _GeneratedWakeRunHourOffsetSlot.currentHour => 0,
    _GeneratedWakeRunHourOffsetSlot.future => 2,
  };
}

int _generatedWakeRunMinute(_GeneratedWakeRunMinuteSlot slot) {
  return switch (slot) {
    _GeneratedWakeRunMinuteSlot.zero => 0,
    _GeneratedWakeRunMinuteSlot.early => 7,
    _GeneratedWakeRunMinuteSlot.middle => 31,
    _GeneratedWakeRunMinuteSlot.late => 58,
  };
}

class _GeneratedPendingWakeSpec {
  const _GeneratedPendingWakeSpec({
    required this.stateShape,
    required this.scheduleShape,
    required this.pendingOffset,
    required this.scheduledOffset,
  });

  final _GeneratedPendingWakeStateShape stateShape;
  final _GeneratedPendingWakeScheduleShape scheduleShape;
  final _GeneratedPendingWakeOffsetSlot pendingOffset;
  final _GeneratedPendingWakeOffsetSlot scheduledOffset;

  String agentId(int index) => _generatedPendingAgentId(index);

  AgentIdentityEntity identity(int index) {
    final id = agentId(index);
    return makeTestIdentity(
      id: 'generated-pending-identity-$index',
      agentId: id,
      displayName: 'Generated Pending Agent $index',
    );
  }

  DateTime? nextWakeAt(int index) {
    return switch (scheduleShape) {
      _GeneratedPendingWakeScheduleShape.pendingOnly ||
      _GeneratedPendingWakeScheduleShape.both => _generatedPendingWakeDueAt(
        pendingOffset,
        index,
        0,
      ),
      _GeneratedPendingWakeScheduleShape.none ||
      _GeneratedPendingWakeScheduleShape.scheduledOnly => null,
    };
  }

  DateTime? scheduledWakeAt(int index) {
    return switch (scheduleShape) {
      _GeneratedPendingWakeScheduleShape.scheduledOnly ||
      _GeneratedPendingWakeScheduleShape.both => _generatedPendingWakeDueAt(
        scheduledOffset,
        index,
        1,
      ),
      _GeneratedPendingWakeScheduleShape.none ||
      _GeneratedPendingWakeScheduleShape.pendingOnly => null,
    };
  }

  AgentStateEntity? state(int index) {
    if (stateShape == _GeneratedPendingWakeStateShape.missing) {
      return null;
    }

    final id = agentId(index);
    final state = makeTestState(
      id: 'generated-pending-state-$index',
      agentId: id,
      nextWakeAt: nextWakeAt(index),
      scheduledWakeAt: scheduledWakeAt(index),
    );
    if (stateShape == _GeneratedPendingWakeStateShape.deleted) {
      return state.copyWith(deletedAt: _generatedProviderBase);
    }
    return state;
  }

  List<_PendingWakeExpectation> expectedRecords(int index) {
    if (stateShape != _GeneratedPendingWakeStateShape.active) {
      return const [];
    }

    final id = agentId(index);
    return [
      if (nextWakeAt(index) case final dueAt?)
        (
          agentId: id,
          type: PendingWakeType.pending,
          dueAt: dueAt,
          id: _generatedWakeRecordId(id, PendingWakeType.pending, dueAt),
        ),
      if (scheduledWakeAt(index) case final dueAt?)
        (
          agentId: id,
          type: PendingWakeType.scheduled,
          dueAt: dueAt,
          id: _generatedWakeRecordId(id, PendingWakeType.scheduled, dueAt),
        ),
    ];
  }

  @override
  String toString() {
    return '_GeneratedPendingWakeSpec('
        'stateShape: $stateShape, scheduleShape: $scheduleShape, '
        'pendingOffset: $pendingOffset, scheduledOffset: $scheduledOffset)';
  }
}

class _GeneratedPendingWakeScenario {
  const _GeneratedPendingWakeScenario({required this.specs});

  final List<_GeneratedPendingWakeSpec> specs;

  List<AgentIdentityEntity> get identities => [
    for (final (index, spec) in specs.indexed) spec.identity(index),
  ];

  Map<String, AgentStateEntity> get statesByAgentId {
    final states = <String, AgentStateEntity>{};
    for (final (index, spec) in specs.indexed) {
      final state = spec.state(index);
      if (state != null) states[state.agentId] = state;
    }
    return states;
  }

  List<_PendingWakeExpectation> get expectedRecords {
    final records = [
      for (final (index, spec) in specs.indexed) ...spec.expectedRecords(index),
    ]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return records;
  }

  @override
  String toString() => '_GeneratedPendingWakeScenario(specs: $specs)';
}

class _GeneratedOngoingWakeSpec {
  const _GeneratedOngoingWakeSpec({
    required this.subjectShape,
    required this.titleShape,
    required this.identityShape,
    required this.startSlot,
  });

  final _GeneratedOngoingWakeSubjectShape subjectShape;
  final _GeneratedOngoingWakeTitleShape titleShape;
  final _GeneratedOngoingWakeIdentityShape identityShape;
  final _GeneratedOngoingWakeStartSlot startSlot;

  String agentId(int index) => _generatedOngoingAgentId(index);

  String subjectId(int index) => _generatedOngoingSubjectId(index);

  DateTime startedAt(int index) => _generatedOngoingStartedAt(
    startSlot,
    index,
  );

  AgentStateEntity? state(int index) {
    final id = agentId(index);
    return switch (subjectShape) {
      _GeneratedOngoingWakeSubjectShape.task => makeTestState(
        agentId: id,
        slots: AgentSlots(activeTaskId: subjectId(index)),
      ),
      _GeneratedOngoingWakeSubjectShape.project => makeTestState(
        agentId: id,
        slots: AgentSlots(activeProjectId: subjectId(index)),
      ),
      _GeneratedOngoingWakeSubjectShape.noSubject => makeTestState(
        agentId: id,
      ),
      _GeneratedOngoingWakeSubjectShape.missingState ||
      _GeneratedOngoingWakeSubjectShape.stateThrows => null,
    };
  }

  JournalEntity? subjectEntity(int index) {
    final title = switch (titleShape) {
      _GeneratedOngoingWakeTitleShape.usable =>
        '  Generated linked title $index  ',
      _GeneratedOngoingWakeTitleShape.blank => '   ',
      _GeneratedOngoingWakeTitleShape.missing ||
      _GeneratedOngoingWakeTitleShape.lookupThrows ||
      _GeneratedOngoingWakeTitleShape.unsupported => null,
    };

    if (titleShape == _GeneratedOngoingWakeTitleShape.unsupported) {
      return JournalEntity.journalEntry(
        meta: Metadata(
          id: subjectId(index),
          createdAt: _generatedOngoingBase,
          updatedAt: _generatedOngoingBase,
          dateFrom: _generatedOngoingBase,
          dateTo: _generatedOngoingBase,
        ),
      );
    }

    if (title == null) return null;
    return switch (subjectShape) {
      _GeneratedOngoingWakeSubjectShape.task => makeTestTask(
        id: subjectId(index),
        title: title,
      ),
      _GeneratedOngoingWakeSubjectShape.project => makeTestProject(
        id: subjectId(index),
        title: title,
      ),
      _ => null,
    };
  }

  AgentIdentityEntity? identity(int index) {
    final id = agentId(index);
    return switch (identityShape) {
      _GeneratedOngoingWakeIdentityShape.usable => makeTestIdentity(
        agentId: id,
        displayName: '  Generated display name $index  ',
      ),
      _GeneratedOngoingWakeIdentityShape.blank => makeTestIdentity(
        agentId: id,
        displayName: '   ',
      ),
      _GeneratedOngoingWakeIdentityShape.missing ||
      _GeneratedOngoingWakeIdentityShape.lookupThrows => null,
    };
  }

  String expectedTitle(int index) {
    final subjectTitle = switch (titleShape) {
      _GeneratedOngoingWakeTitleShape.usable
          when subjectShape == _GeneratedOngoingWakeSubjectShape.task ||
              subjectShape == _GeneratedOngoingWakeSubjectShape.project =>
        'Generated linked title $index',
      _ => null,
    };
    if (subjectTitle != null && subjectTitle.isNotEmpty) {
      return subjectTitle;
    }

    final identityTitle = switch (identityShape) {
      _GeneratedOngoingWakeIdentityShape.usable =>
        'Generated display name $index',
      _ => null,
    };
    return identityTitle ?? agentId(index);
  }

  _OngoingWakeExpectation expectedRecord(int index) {
    final id = agentId(index);
    return (
      agentId: id,
      title: expectedTitle(index),
      startedAt: startedAt(index),
      id: 'ongoing:$id',
    );
  }

  @override
  String toString() {
    return '_GeneratedOngoingWakeSpec('
        'subjectShape: $subjectShape, titleShape: $titleShape, '
        'identityShape: $identityShape, startSlot: $startSlot)';
  }
}

class _GeneratedOngoingWakeScenario {
  const _GeneratedOngoingWakeScenario({required this.specs});

  final List<_GeneratedOngoingWakeSpec> specs;

  List<_OngoingWakeExpectation> get expectedRecords {
    final records = [
      for (final (index, spec) in specs.indexed) spec.expectedRecord(index),
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return records;
  }

  @override
  String toString() => '_GeneratedOngoingWakeScenario(specs: $specs)';
}

class _GeneratedHourlyWakeRunSpec {
  const _GeneratedHourlyWakeRunSpec({
    required this.hourOffset,
    required this.minuteSlot,
    required this.reasonSlot,
  });

  final _GeneratedWakeRunHourOffsetSlot hourOffset;
  final _GeneratedWakeRunMinuteSlot minuteSlot;
  final _GeneratedWakeRunReasonSlot reasonSlot;

  DateTime createdAt(DateTime currentHour) {
    return currentHour.add(
      Duration(
        hours: _generatedWakeRunHourOffset(hourOffset),
        minutes: _generatedWakeRunMinute(minuteSlot),
      ),
    );
  }

  String get reason => _generatedWakeRunReason(reasonSlot);

  @override
  String toString() {
    return '_GeneratedHourlyWakeRunSpec('
        'hourOffset: $hourOffset, minuteSlot: $minuteSlot, '
        'reasonSlot: $reasonSlot)';
  }
}

class _GeneratedHourlyWakeActivityScenario {
  const _GeneratedHourlyWakeActivityScenario({required this.runs});

  final List<_GeneratedHourlyWakeRunSpec> runs;

  @override
  String toString() {
    return '_GeneratedHourlyWakeActivityScenario(runs: $runs)';
  }
}

extension _AnyGeneratedAgentPendingWakeProviderScenario on glados.Any {
  glados.Generator<_GeneratedPendingWakeStateShape> get pendingWakeStateShape =>
      glados.AnyUtils(this).choose(_GeneratedPendingWakeStateShape.values);

  glados.Generator<_GeneratedPendingWakeScheduleShape>
  get pendingWakeScheduleShape =>
      glados.AnyUtils(this).choose(_GeneratedPendingWakeScheduleShape.values);

  glados.Generator<_GeneratedPendingWakeOffsetSlot> get pendingWakeOffsetSlot =>
      glados.AnyUtils(this).choose(_GeneratedPendingWakeOffsetSlot.values);

  glados.Generator<_GeneratedPendingWakeSpec> get pendingWakeSpec =>
      glados.CombinableAny(this).combine4(
        pendingWakeStateShape,
        pendingWakeScheduleShape,
        pendingWakeOffsetSlot,
        pendingWakeOffsetSlot,
        (
          _GeneratedPendingWakeStateShape stateShape,
          _GeneratedPendingWakeScheduleShape scheduleShape,
          _GeneratedPendingWakeOffsetSlot pendingOffset,
          _GeneratedPendingWakeOffsetSlot scheduledOffset,
        ) => _GeneratedPendingWakeSpec(
          stateShape: stateShape,
          scheduleShape: scheduleShape,
          pendingOffset: pendingOffset,
          scheduledOffset: scheduledOffset,
        ),
      );

  glados.Generator<_GeneratedPendingWakeScenario> get pendingWakeScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 8, pendingWakeSpec)
          .map((specs) => _GeneratedPendingWakeScenario(specs: specs));

  glados.Generator<_GeneratedOngoingWakeSubjectShape>
  get ongoingWakeSubjectShape =>
      glados.AnyUtils(this).choose(_GeneratedOngoingWakeSubjectShape.values);

  glados.Generator<_GeneratedOngoingWakeTitleShape> get ongoingWakeTitleShape =>
      glados.AnyUtils(this).choose(_GeneratedOngoingWakeTitleShape.values);

  glados.Generator<_GeneratedOngoingWakeIdentityShape>
  get ongoingWakeIdentityShape =>
      glados.AnyUtils(this).choose(_GeneratedOngoingWakeIdentityShape.values);

  glados.Generator<_GeneratedOngoingWakeStartSlot> get ongoingWakeStartSlot =>
      glados.AnyUtils(this).choose(_GeneratedOngoingWakeStartSlot.values);

  glados.Generator<_GeneratedOngoingWakeSpec> get ongoingWakeSpec =>
      glados.CombinableAny(this).combine4(
        ongoingWakeSubjectShape,
        ongoingWakeTitleShape,
        ongoingWakeIdentityShape,
        ongoingWakeStartSlot,
        (
          _GeneratedOngoingWakeSubjectShape subjectShape,
          _GeneratedOngoingWakeTitleShape titleShape,
          _GeneratedOngoingWakeIdentityShape identityShape,
          _GeneratedOngoingWakeStartSlot startSlot,
        ) => _GeneratedOngoingWakeSpec(
          subjectShape: subjectShape,
          titleShape: titleShape,
          identityShape: identityShape,
          startSlot: startSlot,
        ),
      );

  glados.Generator<_GeneratedOngoingWakeScenario> get ongoingWakeScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 6, ongoingWakeSpec)
          .map((specs) => _GeneratedOngoingWakeScenario(specs: specs));

  glados.Generator<_GeneratedWakeRunReasonSlot> get wakeRunReasonSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeRunReasonSlot.values);

  glados.Generator<_GeneratedWakeRunHourOffsetSlot> get wakeRunHourOffsetSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeRunHourOffsetSlot.values);

  glados.Generator<_GeneratedWakeRunMinuteSlot> get wakeRunMinuteSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeRunMinuteSlot.values);

  glados.Generator<_GeneratedHourlyWakeRunSpec> get hourlyWakeRunSpec =>
      glados.CombinableAny(this).combine3(
        wakeRunHourOffsetSlot,
        wakeRunMinuteSlot,
        wakeRunReasonSlot,
        (
          _GeneratedWakeRunHourOffsetSlot hourOffset,
          _GeneratedWakeRunMinuteSlot minuteSlot,
          _GeneratedWakeRunReasonSlot reasonSlot,
        ) => _GeneratedHourlyWakeRunSpec(
          hourOffset: hourOffset,
          minuteSlot: minuteSlot,
          reasonSlot: reasonSlot,
        ),
      );

  glados.Generator<_GeneratedHourlyWakeActivityScenario>
  get hourlyWakeActivityScenario => glados.ListAnys(this)
      .listWithLengthInRange(0, 18, hourlyWakeRunSpec)
      .map((runs) => _GeneratedHourlyWakeActivityScenario(runs: runs));
}

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(<String>[]);
  });

  test(
    'batches agent state reads when building pending wake records',
    () async {
      final mockAgentService = MockAgentService();
      final mockRepository = MockAgentRepository();
      final notifications = UpdateNotifications();
      final firstIdentity = makeTestIdentity(
        agentId: 'agent-a',
        displayName: 'First',
      );
      final secondIdentity = makeTestIdentity(
        agentId: 'agent-b',
        displayName: 'Second',
      );
      final firstState = makeTestState(
        agentId: 'agent-a',
        nextWakeAt: kAgentTestDate.add(const Duration(minutes: 5)),
      );
      final secondState = makeTestState(
        agentId: 'agent-b',
        nextWakeAt: kAgentTestDate.add(const Duration(minutes: 15)),
        scheduledWakeAt: kAgentTestDate.add(const Duration(minutes: 10)),
      );

      when(
        mockAgentService.listAgents,
      ).thenAnswer((_) => Future.value([firstIdentity, secondIdentity]));
      when(
        () => mockRepository.getAgentStatesByAgentIds(any()),
      ).thenAnswer(
        (_) async => {
          'agent-a': firstState,
          'agent-b': secondState,
        },
      );

      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockAgentService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(() {
        notifications.dispose();
        container.dispose();
      });

      final records = await container.read(pendingWakeRecordsProvider.future);

      expect(records, hasLength(3));
      expect(records.first.type, PendingWakeType.pending);
      expect(records.first.agent.agentId, 'agent-a');
      expect(records[1].type, PendingWakeType.scheduled);
      expect(records[1].agent.agentId, 'agent-b');
      expect(records[2].type, PendingWakeType.pending);
      expect(records[2].agent.agentId, 'agent-b');
      final capturedAgentIds =
          verify(
                () => mockRepository.getAgentStatesByAgentIds(captureAny()),
              ).captured.single
              as List<String>;
      expect(capturedAgentIds, ['agent-a', 'agent-b']);
      verifyNever(() => mockRepository.getAgentState(any()));
    },
  );

  test(
    'filters deleted and missing states when building pending wake records',
    () async {
      final mockAgentService = MockAgentService();
      final mockRepository = MockAgentRepository();
      final notifications = UpdateNotifications();
      final activeIdentity = makeTestIdentity(
        agentId: 'agent-a',
        displayName: 'Active',
      );
      final deletedIdentity = makeTestIdentity(
        agentId: 'agent-b',
        displayName: 'Deleted',
      );
      final missingIdentity = makeTestIdentity(
        agentId: 'agent-c',
        displayName: 'Missing',
      );
      final deletedState =
          makeTestState(
            agentId: 'agent-b',
            id: 'deleted-state',
            nextWakeAt: kAgentTestDate.add(const Duration(minutes: 15)),
          ).copyWith(
            deletedAt: kAgentTestDate,
          );
      final activeState = makeTestState(
        agentId: 'agent-a',
        nextWakeAt: kAgentTestDate.add(const Duration(minutes: 5)),
      );

      when(
        mockAgentService.listAgents,
      ).thenAnswer(
        (_) => Future.value([activeIdentity, deletedIdentity, missingIdentity]),
      );
      when(
        () => mockRepository.getAgentStatesByAgentIds(any()),
      ).thenAnswer(
        (_) async => {
          'agent-a': activeState,
          'agent-b': deletedState,
        },
      );

      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockAgentService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(() {
        notifications.dispose();
        container.dispose();
      });

      final records = await container.read(pendingWakeRecordsProvider.future);

      expect(records, hasLength(1));
      expect(records.single.agent.agentId, 'agent-a');
    },
  );

  test(
    'omits agents whose states have no pending or scheduled wakes',
    () async {
      final mockAgentService = MockAgentService();
      final mockRepository = MockAgentRepository();
      final notifications = UpdateNotifications();
      final identity = makeTestIdentity(
        agentId: 'agent-a',
        displayName: 'Idle Agent',
      );
      final state = makeTestState(
        agentId: 'agent-a',
      );

      when(
        mockAgentService.listAgents,
      ).thenAnswer((_) => Future.value([identity]));
      when(
        () => mockRepository.getAgentStatesByAgentIds(any()),
      ).thenAnswer((_) async => {'agent-a': state});

      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockAgentService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(() {
        notifications.dispose();
        container.dispose();
      });

      final records = await container.read(pendingWakeRecordsProvider.future);

      expect(records, isEmpty);
    },
  );

  glados.Glados(
    glados.any.pendingWakeScenario,
    glados.ExploreConfig(numRuns: 180),
  ).test(
    'matches generated pending wake record filtering and ordering',
    (scenario) async {
      final mockAgentService = MockAgentService();
      final mockRepository = MockAgentRepository();
      final notifications = UpdateNotifications();
      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockAgentService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );

      when(
        mockAgentService.listAgents,
      ).thenAnswer((_) async => scenario.identities);
      when(
        () => mockRepository.getAgentStatesByAgentIds(any()),
      ).thenAnswer((_) async => scenario.statesByAgentId);

      try {
        final records = await container.read(
          pendingWakeRecordsProvider.future,
        );
        final actual = [
          for (final record in records)
            (
              agentId: record.agent.agentId,
              type: record.type,
              dueAt: record.dueAt,
              id: record.id,
            ),
        ];

        expect(actual, scenario.expectedRecords, reason: '$scenario');

        final capturedAgentIds =
            verify(
                  () => mockRepository.getAgentStatesByAgentIds(captureAny()),
                ).captured.single
                as List<String>;
        expect(
          capturedAgentIds,
          scenario.identities.map((identity) => identity.agentId).toList(),
          reason: '$scenario',
        );
        verifyNever(() => mockRepository.getAgentState(any()));
      } finally {
        container.dispose();
        await notifications.dispose();
      }
    },
    tags: 'glados',
  );

  group('ongoingWakeRecordsProvider', () {
    test('returns empty when nothing is running', () async {
      final runner = WakeRunner();
      addTearDown(runner.dispose);
      final container = ProviderContainer(
        overrides: [wakeRunnerProvider.overrideWithValue(runner)],
      );
      addTearDown(container.dispose);

      final records = await container.read(
        ongoingWakeRecordsProvider.future,
      );
      expect(records, isEmpty);
    });

    glados.Glados(
      glados.any.ongoingWakeScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'matches generated running wake title fallback and ordering semantics',
      (scenario) async {
        final runner = WakeRunner();
        final mockRepository = MockAgentRepository();
        final mockAgentService = MockAgentService();
        final mockJournalDb = MockJournalDb();
        final notifications = UpdateNotifications();

        for (final (index, spec) in scenario.specs.indexed) {
          final agentId = spec.agentId(index);
          await withClock(Clock.fixed(spec.startedAt(index)), () async {
            await runner.tryAcquire(agentId);
          });

          if (spec.subjectShape ==
              _GeneratedOngoingWakeSubjectShape.stateThrows) {
            when(
              () => mockRepository.getAgentState(agentId),
            ).thenThrow(StateError('generated state lookup failure $agentId'));
          } else {
            when(
              () => mockRepository.getAgentState(agentId),
            ).thenAnswer((_) async => spec.state(index));
          }

          final hasSubject =
              spec.subjectShape == _GeneratedOngoingWakeSubjectShape.task ||
              spec.subjectShape == _GeneratedOngoingWakeSubjectShape.project;
          if (hasSubject) {
            final subjectId = spec.subjectId(index);
            if (spec.titleShape ==
                _GeneratedOngoingWakeTitleShape.lookupThrows) {
              when(
                () => mockJournalDb.journalEntityById(subjectId),
              ).thenThrow(
                StateError('generated subject lookup failure $subjectId'),
              );
            } else {
              when(
                () => mockJournalDb.journalEntityById(subjectId),
              ).thenAnswer((_) async => spec.subjectEntity(index));
            }
          }

          if (spec.identityShape ==
              _GeneratedOngoingWakeIdentityShape.lookupThrows) {
            when(
              () => mockAgentService.getAgent(agentId),
            ).thenThrow(
              StateError('generated identity lookup failure $agentId'),
            );
          } else {
            when(
              () => mockAgentService.getAgent(agentId),
            ).thenAnswer((_) async => spec.identity(index));
          }
        }

        final container = ProviderContainer(
          overrides: [
            wakeRunnerProvider.overrideWithValue(runner),
            agentRepositoryProvider.overrideWithValue(mockRepository),
            agentServiceProvider.overrideWithValue(mockAgentService),
            journalDbProvider.overrideWithValue(mockJournalDb),
            updateNotificationsProvider.overrideWithValue(notifications),
          ],
        );

        try {
          final records = await container.read(
            ongoingWakeRecordsProvider.future,
          );
          final actual = [
            for (final record in records)
              (
                agentId: record.agentId,
                title: record.title,
                startedAt: record.startedAt,
                id: record.id,
              ),
          ];

          expect(actual, scenario.expectedRecords, reason: '$scenario');
        } finally {
          container.dispose();
          runner.dispose();
          await notifications.dispose();
        }
      },
      tags: 'glados',
    );

    test('uses linked task title when slots point at a task', () async {
      final fixed = DateTime(2026, 5, 5, 21);
      final runner = WakeRunner();
      addTearDown(runner.dispose);
      final mockRepository = MockAgentRepository();
      final mockAgentService = MockAgentService();
      final mockJournalDb = MockJournalDb();
      final notifications = UpdateNotifications();
      addTearDown(notifications.dispose);

      when(
        () => mockRepository.getAgentState('agent-a'),
      ).thenAnswer(
        (_) async => makeTestState(
          agentId: 'agent-a',
          slots: const AgentSlots(activeTaskId: 'task-1'),
        ),
      );
      when(() => mockJournalDb.journalEntityById('task-1')).thenAnswer(
        (_) async => makeTestTask(id: 'task-1', title: 'Refine sidebar'),
      );

      await withClock(Clock.fixed(fixed), () async {
        await runner.tryAcquire('agent-a');
      });

      final container = ProviderContainer(
        overrides: [
          wakeRunnerProvider.overrideWithValue(runner),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          agentServiceProvider.overrideWithValue(mockAgentService),
          journalDbProvider.overrideWithValue(mockJournalDb),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      final records = await container.read(
        ongoingWakeRecordsProvider.future,
      );
      expect(records, hasLength(1));
      expect(records.single.agentId, 'agent-a');
      expect(records.single.title, 'Refine sidebar');
      expect(records.single.startedAt, fixed);
      expect(records.single.id, 'ongoing:agent-a');
      verifyNever(() => mockAgentService.getAgent(any()));
    });

    test(
      'falls back to agent display name when no subject is linked',
      () async {
        final fixed = DateTime(2026, 5, 5, 21);
        final runner = WakeRunner();
        addTearDown(runner.dispose);
        final mockRepository = MockAgentRepository();
        final mockAgentService = MockAgentService();
        final mockJournalDb = MockJournalDb();
        final notifications = UpdateNotifications();
        addTearDown(notifications.dispose);

        when(
          () => mockRepository.getAgentState('agent-z'),
        ).thenAnswer(
          (_) async => makeTestState(agentId: 'agent-z'),
        );
        when(
          () => mockAgentService.getAgent('agent-z'),
        ).thenAnswer(
          (_) async => makeTestIdentity(
            agentId: 'agent-z',
            displayName: 'Improver',
          ),
        );

        await withClock(Clock.fixed(fixed), () async {
          await runner.tryAcquire('agent-z');
        });

        final container = ProviderContainer(
          overrides: [
            wakeRunnerProvider.overrideWithValue(runner),
            agentRepositoryProvider.overrideWithValue(mockRepository),
            agentServiceProvider.overrideWithValue(mockAgentService),
            journalDbProvider.overrideWithValue(mockJournalDb),
            updateNotificationsProvider.overrideWithValue(notifications),
          ],
        );
        addTearDown(container.dispose);

        final records = await container.read(
          ongoingWakeRecordsProvider.future,
        );
        expect(records.single.title, 'Improver');
      },
    );

    test(
      'falls back to the agentId when neither subject nor identity is found',
      () async {
        final runner = WakeRunner();
        addTearDown(runner.dispose);
        final mockRepository = MockAgentRepository();
        final mockAgentService = MockAgentService();
        final mockJournalDb = MockJournalDb();
        final notifications = UpdateNotifications();
        addTearDown(notifications.dispose);

        when(
          () => mockRepository.getAgentState('agent-missing'),
        ).thenAnswer((_) async => null);
        when(
          () => mockAgentService.getAgent('agent-missing'),
        ).thenAnswer((_) async => null);

        await runner.tryAcquire('agent-missing');

        final container = ProviderContainer(
          overrides: [
            wakeRunnerProvider.overrideWithValue(runner),
            agentRepositoryProvider.overrideWithValue(mockRepository),
            agentServiceProvider.overrideWithValue(mockAgentService),
            journalDbProvider.overrideWithValue(mockJournalDb),
            updateNotificationsProvider.overrideWithValue(notifications),
          ],
        );
        addTearDown(container.dispose);

        final records = await container.read(
          ongoingWakeRecordsProvider.future,
        );
        expect(records.single.title, 'agent-missing');
      },
    );

    test(
      'swallows subject lookup errors and falls back to display name',
      () async {
        final runner = WakeRunner();
        addTearDown(runner.dispose);
        final mockRepository = MockAgentRepository();
        final mockAgentService = MockAgentService();
        final mockJournalDb = MockJournalDb();
        final notifications = UpdateNotifications();
        addTearDown(notifications.dispose);

        when(
          () => mockRepository.getAgentState('agent-err'),
        ).thenThrow(StateError('db boom'));
        when(
          () => mockAgentService.getAgent('agent-err'),
        ).thenAnswer(
          (_) async => makeTestIdentity(
            agentId: 'agent-err',
            displayName: 'Backup name',
          ),
        );

        await runner.tryAcquire('agent-err');

        final container = ProviderContainer(
          overrides: [
            wakeRunnerProvider.overrideWithValue(runner),
            agentRepositoryProvider.overrideWithValue(mockRepository),
            agentServiceProvider.overrideWithValue(mockAgentService),
            journalDbProvider.overrideWithValue(mockJournalDb),
            updateNotificationsProvider.overrideWithValue(notifications),
          ],
        );
        addTearDown(container.dispose);

        final records = await container.read(
          ongoingWakeRecordsProvider.future,
        );
        expect(records.single.title, 'Backup name');
      },
    );

    test('sorts results by startedAt ascending', () async {
      final earlier = DateTime(2026, 5, 5, 20);
      final later = DateTime(2026, 5, 5, 21);
      final runner = WakeRunner();
      addTearDown(runner.dispose);
      final mockRepository = MockAgentRepository();
      final mockAgentService = MockAgentService();
      final mockJournalDb = MockJournalDb();
      final notifications = UpdateNotifications();
      addTearDown(notifications.dispose);

      for (final id in ['agent-late', 'agent-early']) {
        when(
          () => mockRepository.getAgentState(id),
        ).thenAnswer((_) async => makeTestState(agentId: id));
        when(() => mockAgentService.getAgent(id)).thenAnswer(
          (_) async => makeTestIdentity(agentId: id, displayName: id),
        );
      }

      await withClock(Clock.fixed(later), () async {
        await runner.tryAcquire('agent-late');
      });
      await withClock(Clock.fixed(earlier), () async {
        await runner.tryAcquire('agent-early');
      });

      final container = ProviderContainer(
        overrides: [
          wakeRunnerProvider.overrideWithValue(runner),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          agentServiceProvider.overrideWithValue(mockAgentService),
          journalDbProvider.overrideWithValue(mockJournalDb),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      final records = await container.read(
        ongoingWakeRecordsProvider.future,
      );
      expect(
        records.map((r) => r.agentId).toList(),
        ['agent-early', 'agent-late'],
      );
    });
  });

  group('pendingWakeTargetTitleProvider', () {
    late MockJournalDb mockJournalDb;

    setUp(() {
      mockJournalDb = MockJournalDb();
    });

    ProviderContainer createContainer() {
      final notifications = UpdateNotifications();
      final container = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(mockJournalDb),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(() {
        notifications.dispose();
        container.dispose();
      });
      return container;
    }

    test('returns null for null or empty entry IDs', () async {
      final container = createContainer();

      expect(
        await container.read(pendingWakeTargetTitleProvider(null).future),
        isNull,
      );
      expect(
        await container.read(pendingWakeTargetTitleProvider('').future),
        isNull,
      );
      verifyNever(() => mockJournalDb.journalEntityById(any()));
    });

    test('returns task and project titles from journal entities', () async {
      when(
        () => mockJournalDb.journalEntityById('task-1'),
      ).thenAnswer(
        (_) async => makeTestTask(id: 'task-1', title: 'Fix wake loop'),
      );
      when(
        () => mockJournalDb.journalEntityById('project-1'),
      ).thenAnswer(
        (_) async =>
            makeTestProject(id: 'project-1', title: 'Platform Refresh'),
      );

      final container = createContainer();

      expect(
        await container.read(pendingWakeTargetTitleProvider('task-1').future),
        'Fix wake loop',
      );
      expect(
        await container.read(
          pendingWakeTargetTitleProvider('project-1').future,
        ),
        'Platform Refresh',
      );
    });

    test('returns null for unsupported journal entity types', () async {
      when(
        () => mockJournalDb.journalEntityById('entry-1'),
      ).thenAnswer(
        (_) async => JournalEntity.journalEntry(
          meta: Metadata(
            id: 'entry-1',
            createdAt: kAgentTestDate,
            updatedAt: kAgentTestDate,
            dateFrom: kAgentTestDate,
            dateTo: kAgentTestDate,
          ),
        ),
      );

      final container = createContainer();

      expect(
        await container.read(pendingWakeTargetTitleProvider('entry-1').future),
        isNull,
      );
    });

    test(
      'returns null when no journal entity exists for the entry ID',
      () async {
        when(() => mockJournalDb.journalEntityById('missing')).thenAnswer(
          (_) async => null,
        );

        final container = createContainer();

        expect(
          await container.read(
            pendingWakeTargetTitleProvider('missing').future,
          ),
          isNull,
        );
      },
    );
  });

  group('hourlyWakeActivityProvider', () {
    glados.Glados(
      glados.any.hourlyWakeActivityScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated 24-hour wake activity aggregation', (
      scenario,
    ) async {
      final currentHour = DateTime(
        _generatedHourlyNow.year,
        _generatedHourlyNow.month,
        _generatedHourlyNow.day,
        _generatedHourlyNow.hour,
      );
      final expectedSince = currentHour.subtract(const Duration(hours: 23));
      final expectedReasonsByHour = {
        for (var i = 23; i >= 0; i--)
          currentHour.subtract(Duration(hours: i)): <String, int>{},
      };
      final runs = [
        for (final (index, spec) in scenario.runs.indexed)
          makeTestWakeRun(
            runKey: 'generated-hourly-run-$index',
            reason: spec.reason,
            createdAt: spec.createdAt(currentHour),
          ),
      ];

      for (final spec in scenario.runs) {
        final created = spec.createdAt(currentHour).toLocal();
        final hourKey = DateTime(
          created.year,
          created.month,
          created.day,
          created.hour,
        );
        final reasons = expectedReasonsByHour[hourKey];
        if (reasons != null) {
          reasons[spec.reason] = (reasons[spec.reason] ?? 0) + 1;
        }
      }

      final mockRepository = MockAgentRepository();
      final notifications = UpdateNotifications();
      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepository),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );

      when(
        () => mockRepository.getWakeRunsInWindow(
          since: any(named: 'since'),
          until: any(named: 'until'),
        ),
      ).thenAnswer((_) async => runs);

      try {
        final buckets = await withClock(
          Clock.fixed(_generatedHourlyNow),
          () => container.read(hourlyWakeActivityProvider.future),
        );

        verify(
          () => mockRepository.getWakeRunsInWindow(
            since: expectedSince,
            until: _generatedHourlyNow,
          ),
        ).called(1);
        expect(buckets, hasLength(24), reason: '$scenario');
        expect(
          buckets.map((bucket) => bucket.hour).toList(),
          expectedReasonsByHour.keys.toList(),
          reason: '$scenario',
        );

        for (final bucket in buckets) {
          final expectedReasons = expectedReasonsByHour[bucket.hour]!;
          final expectedCount = expectedReasons.values.fold<int>(
            0,
            (sum, count) => sum + count,
          );
          expect(bucket.count, expectedCount, reason: '$scenario');
          expect(bucket.reasons, expectedReasons, reason: '$scenario');
        }
      } finally {
        container.dispose();
        await notifications.dispose();
      }
    }, tags: 'glados');

    test('groups wake runs by hour with reason breakdown', () async {
      final now = DateTime(2026, 4, 4, 14);
      final mockRepository = MockAgentRepository();
      final notifications = UpdateNotifications();

      when(
        () => mockRepository.getWakeRunsInWindow(
          since: any(named: 'since'),
          until: any(named: 'until'),
        ),
      ).thenAnswer(
        (_) async => [
          makeTestWakeRun(
            runKey: 'run-1',
            createdAt: DateTime(2026, 4, 4, 10, 5),
          ),
          makeTestWakeRun(
            runKey: 'run-2',
            createdAt: DateTime(2026, 4, 4, 10, 30),
          ),
          makeTestWakeRun(
            runKey: 'run-3',
            reason: 'creation',
            createdAt: DateTime(2026, 4, 4, 10, 45),
          ),
          makeTestWakeRun(
            runKey: 'run-4',
            createdAt: DateTime(2026, 4, 4, 12, 15),
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepository),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(() {
        notifications.dispose();
        container.dispose();
      });

      final buckets = await withClock(
        Clock.fixed(now),
        () => container.read(hourlyWakeActivityProvider.future),
      );

      expect(buckets, hasLength(24));

      final hour10 = buckets.firstWhere(
        (b) => b.hour == DateTime(2026, 4, 4, 10),
      );
      expect(hour10.count, 3);
      expect(hour10.reasons['subscription'], 2);
      expect(hour10.reasons['creation'], 1);

      final hour12 = buckets.firstWhere(
        (b) => b.hour == DateTime(2026, 4, 4, 12),
      );
      expect(hour12.count, 1);
      expect(hour12.reasons['subscription'], 1);
    });

    test('returns empty buckets when no wake runs exist', () async {
      final now = DateTime(2026, 4, 4, 14);
      final mockRepository = MockAgentRepository();
      final notifications = UpdateNotifications();

      when(
        () => mockRepository.getWakeRunsInWindow(
          since: any(named: 'since'),
          until: any(named: 'until'),
        ),
      ).thenAnswer((_) async => []);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepository),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(() {
        notifications.dispose();
        container.dispose();
      });

      final buckets = await withClock(
        Clock.fixed(now),
        () => container.read(hourlyWakeActivityProvider.future),
      );

      expect(buckets, hasLength(24));
      expect(buckets.every((b) => b.count == 0), isTrue);
    });
  });
}

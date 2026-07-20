/// Screenshot harness for the Daily OS Day page — the agenda and the day
/// timeline (planned vs recorded lanes) plus the planner-knowledge
/// surfacing.
///
/// Renders a realistic "plan vs reality" day: a full day of planned blocks
/// and a full day of recorded sessions that diverge the way real days do
/// (late starts, an unplanned incident, a skipped block, one session still
/// running). PNGs land in `screenshots/daily_os_next/` (gitignored) for
/// design review. Not a golden test — assertions only guard that each
/// scenario renders.
///
/// Opt-in (real-font loading leaks process-wide — see the harness). Run:
/// `LOTTI_SCREENSHOT_DIR=/tmp/day_page fvm flutter test \
///   test/features/daily_os_next/ui/pages/day_page_screenshots_test.dart`
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/services/day_activity_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_activity_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/planner_knowledge_provider.dart';
import 'package:lotti/features/daily_os_next/state/refine_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/commit_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/shutdown_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/manual_demo_world.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../screenshot_harness.dart';

/// Mid-afternoon so the now-line sits inside the day and one recorded
/// session can be in progress.
final DateTime _now = DateTime(2026, 6, 8, 15, 55);
final DateTime _day = DateTime(2026, 6, 8);
late ManualDemoWorld _manualWorld;
Directory? _manualDocumentsDirectory;
String _t(String en, String de) => manualScreenshotText(en: en, de: de);

final _deepWork = DayAgentCategory(
  id: 'cat-penguin',
  name: _t('Penguin Operations', 'Pinguinbetrieb'),
  colorHex: '8B5CF6',
);
final _client = DayAgentCategory(
  id: 'cat-mission',
  name: _t('Mission Control', 'Missionskontrolle'),
  colorHex: '4F9DDE',
);
final _health = DayAgentCategory(
  id: 'cat-human',
  name: _t('Human Maintenance', 'Menschenwartung'),
  colorHex: '34D399',
);
final _admin = DayAgentCategory(
  id: 'cat-diplomacy',
  name: _t('Fish Diplomacy', 'Fischdiplomatie'),
  colorHex: 'E8A33D',
);

DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 6, 8, hour, minute);

TimeBlock _planned(
  String id,
  String title,
  DateTime start,
  DateTime end,
  DayAgentCategory category, {
  String? reason,
  int? sessionIndex,
  int? sessionTotal,
  String? taskId,
}) => TimeBlock(
  id: id,
  title: title,
  start: start,
  end: end,
  type: TimeBlockType.ai,
  state: TimeBlockState.drafted,
  category: category,
  reason: reason,
  sessionIndex: sessionIndex,
  sessionTotal: sessionTotal,
  taskId: taskId,
);

TimeBlock _tracked(
  String id,
  String title,
  DateTime start,
  DateTime end,
  DayAgentCategory category, {
  TimeBlockState state = TimeBlockState.completed,
}) => TimeBlock(
  id: 'actual:$id',
  title: title,
  start: start,
  end: end,
  type: TimeBlockType.manual,
  state: state,
  category: category,
);

/// A full planned day for the Director of Interplanetary Penguin Logistics.
DraftPlan _plan() {
  final blocks = [
    _planned(
      'blk-review',
      _t('Emperor penguin roll call', 'Kaiserpinguine durchzählen'),
      _at(8, 30),
      _at(9),
      _admin,
      taskId: manualRollCallTaskId,
    ),
    _planned(
      'blk-deep',
      _t(
        'Inspect orbital penguin habitat',
        'Pinguin-Habitat im Orbit inspizieren',
      ),
      _at(9),
      _at(11),
      _deepWork,
      reason: _t(
        'Best done before Mission Control and the penguins get chatty',
        'Am besten, bevor Missionskontrolle und Pinguine gesprächig werden',
      ),
      taskId: 'task-orbital-habitat',
    ),
    TimeBlock(
      id: 'blk-buffer',
      title: _t('Buffer', 'Puffer'),
      start: _at(11),
      end: _at(11, 15),
      type: TimeBlockType.buffer,
      state: TimeBlockState.drafted,
      category: _admin,
    ),
    _planned(
      'blk-design',
      _t('Project Waddle launch review', 'Startprüfung für Project Waddle'),
      _at(11, 15),
      _at(12),
      _client,
      taskId: manualLaunchReviewTaskId,
    ),
    _planned(
      'blk-lunch',
      _t(
        'Lunch (coffee is not a vegetable)',
        'Mittagspause (Kaffee ist kein Gemüse)',
      ),
      _at(12),
      _at(13),
      _health,
      taskId: manualLunchTaskId,
    ),
    _planned(
      'blk-followup',
      _t('Negotiate sardine futures', 'Sardinen-Futures verhandeln'),
      _at(13),
      _at(14, 30),
      _client,
      taskId: manualSardineFuturesTaskId,
    ),
    _planned(
      'blk-slides',
      _t('Zero-gravity fish feeder', 'Schwerelos-Futterautomat'),
      _at(14, 30),
      _at(16),
      _deepWork,
      sessionIndex: 1,
      sessionTotal: 2,
      reason: _t(
        'The fish are least suspicious immediately after lunch',
        'Direkt nach dem Mittagessen sind die Fische am wenigsten misstrauisch',
      ),
      taskId: manualFishFeederTaskId,
    ),
    _planned(
      'blk-email',
      _t(
        'Legal: Is a penguin a passenger?',
        'Rechtsfrage: Ist ein Pinguin ein Passagier?',
      ),
      _at(16, 15),
      _at(17),
      _admin,
      taskId: manualPenguinPassengerTaskId,
    ),
    _planned(
      'blk-run',
      _t('Walk without a headset', 'Spaziergang ohne Headset'),
      _at(17, 30),
      _at(18),
      _health,
      taskId: manualHeadsetWalkTaskId,
    ),
  ];

  return DraftPlan(
    dayDate: _day,
    blocks: blocks,
    bands: [
      EnergyBand(
        start: _at(9),
        end: _at(12),
        level: EnergyLevel.high,
        label: _t('HIGH ENERGY', 'HOHE ENERGIE'),
      ),
      EnergyBand(
        start: _at(13),
        end: _at(15),
        level: EnergyLevel.low,
        label: _t('POST-LUNCH DIP', 'MITTAGSTIEF'),
      ),
      EnergyBand(
        start: _at(16),
        end: _at(18),
        level: EnergyLevel.secondWind,
        label: _t('SECOND WIND', 'ZWEITER SCHWUNG'),
      ),
    ],
    // Blocks sum to 525m (8h45m) — capacity leaves an honest 15m gap.
    capacityMinutes: 540,
    scheduledMinutes: 525,
    agendaItems: [
      AgendaItem(
        id: 'ag-review',
        taskId: manualRollCallTaskId,
        title: _t(
          'Emperor penguin roll call',
          'Kaiserpinguine durchzählen',
        ),
        category: _admin,
        linkedBlockIds: const ['blk-review'],
        totalEstimateMinutes: 30,
        progress: 1,
        state: AgendaItemState.done,
      ),
      AgendaItem(
        id: 'ag-deep',
        taskId: 'task-orbital-habitat',
        title: _t(
          'Inspect orbital penguin habitat',
          'Pinguin-Habitat im Orbit inspizieren',
        ),
        category: _deepWork,
        linkedBlockIds: const ['blk-deep'],
        totalEstimateMinutes: 120,
        progress: 1,
        state: AgendaItemState.done,
        outcome: _t(
          'Habitat seals green; tiny helmets still pending',
          'Habitatdichtungen grün; winzige Helme noch ausstehend',
        ),
      ),
      AgendaItem(
        id: 'ag-design',
        taskId: manualLaunchReviewTaskId,
        title: _t(
          'Project Waddle launch review',
          'Startprüfung für Project Waddle',
        ),
        category: _client,
        linkedBlockIds: const ['blk-design'],
        totalEstimateMinutes: 45,
        progress: 1,
        state: AgendaItemState.done,
      ),
      AgendaItem(
        id: 'ag-lunch',
        taskId: manualLunchTaskId,
        title: _t(
          'Lunch (coffee is not a vegetable)',
          'Mittagspause (Kaffee ist kein Gemüse)',
        ),
        category: _health,
        linkedBlockIds: const ['blk-lunch'],
        totalEstimateMinutes: 60,
        progress: 1,
        state: AgendaItemState.done,
      ),
      // The 13:05–14:55 recording on the timeline closed this out — the
      // agenda must agree with the lane (no cross-view contradictions).
      AgendaItem(
        id: 'ag-followup',
        taskId: manualSardineFuturesTaskId,
        title: _t('Negotiate sardine futures', 'Sardinen-Futures verhandeln'),
        category: _client,
        linkedBlockIds: const ['blk-followup'],
        totalEstimateMinutes: 90,
        progress: 1,
        state: AgendaItemState.done,
        outcome: _t(
          'Locked Q3 sardines below the emergency fish ceiling',
          'Q3-Sardinen unter der Fisch-Notfallgrenze gesichert',
        ),
      ),
      AgendaItem(
        id: 'ag-slides',
        taskId: manualFishFeederTaskId,
        title: _t('Zero-gravity fish feeder', 'Schwerelos-Futterautomat'),
        category: _deepWork,
        linkedBlockIds: const ['blk-slides'],
        totalEstimateMinutes: 180,
        progress: 0.4,
        state: AgendaItemState.inProgress,
        outcome: _t(
          'Prototype ready for the live habitat demo',
          'Prototyp bereit für die Live-Demo des Habitats',
        ),
      ),
      AgendaItem(
        id: 'ag-email',
        taskId: manualPenguinPassengerTaskId,
        title: _t(
          'Legal: Is a penguin a passenger?',
          'Rechtsfrage: Ist ein Pinguin ein Passagier?',
        ),
        category: _admin,
        linkedBlockIds: const ['blk-email'],
        totalEstimateMinutes: 45,
      ),
      AgendaItem(
        id: 'ag-run',
        taskId: manualHeadsetWalkTaskId,
        title: _t('Walk without a headset', 'Spaziergang ohne Headset'),
        category: _health,
        linkedBlockIds: const ['blk-run'],
        totalEstimateMinutes: 30,
      ),
    ],
  );
}

List<DayActivityEntry> _activityEntries() {
  DayProcessingJob job({
    required String id,
    required DateTime createdAt,
    required DayProcessingJobStatus status,
    DayProcessingFailureClass? failureClass,
    String? transcript,
  }) => DayProcessingJob(
    id: 'job-$id',
    kind: DayProcessingJobKind.transcribeAudio,
    status: status,
    dayId: 'dayplan-2026-06-08',
    activityEntryId: id,
    recordingSessionId: 'session-$id',
    audioId: 'audio-$id',
    audioPath: '/tmp/$id.wav',
    createdAt: createdAt,
    updatedAt: createdAt,
    nextAttemptAt: createdAt,
    attempts: status == DayProcessingJobStatus.succeeded ? 1 : 3,
    generation: 2,
    lastFailureClass: failureClass,
    resultTranscript: transcript,
    completedAt: status == DayProcessingJobStatus.succeeded ? createdAt : null,
  );

  final readyAt = _at(8, 20);
  final waitingAt = _at(15, 35);
  return [
    DayActivityEntry(
      id: 'activity-gym-check-in',
      kind: DayActivityEntryKind.recording,
      createdAt: readyAt,
      activityEntryId: 'activity-gym-check-in',
      processingJob: job(
        id: 'activity-gym-check-in',
        createdAt: readyAt,
        status: DayProcessingJobStatus.succeeded,
        transcript: _t(
          'Protect the habitat inspection this morning and leave a buffer '
              'before Mission Control.',
          'Schütze heute Vormittag die Habitat-Inspektion und lasse einen '
              'Puffer vor der Missionskontrolle.',
        ),
      ),
    ),
    DayActivityEntry(
      id: 'activity-afternoon-check-in',
      kind: DayActivityEntryKind.recording,
      createdAt: waitingAt,
      activityEntryId: 'activity-afternoon-check-in',
      processingJob: job(
        id: 'activity-afternoon-check-in',
        createdAt: waitingAt,
        status: DayProcessingJobStatus.waitingForNetwork,
        failureClass: DayProcessingFailureClass.network,
      ),
    ),
  ];
}

/// Recorded reality: late starts, an escaped penguin nobody planned,
/// lunch without the walk, the afternoon running long, slides still in
/// progress under the now-line, email triage never happened (yet).
List<TimeBlock> _actuals() => [
  _tracked(
    'review',
    _t('Emperor penguin roll call', 'Kaiserpinguine durchzählen'),
    _at(8, 42),
    _at(9, 5),
    _admin,
  ),
  _tracked(
    'deep',
    _t(
      'Inspect orbital penguin habitat',
      'Pinguin-Habitat im Orbit inspizieren',
    ),
    _at(9, 5),
    _at(10, 38),
    _deepWork,
  ),
  _tracked(
    'incident',
    _t(
      'Retrieve penguin from ventilation duct',
      'Pinguin aus dem Lüftungsschacht holen',
    ),
    _at(10, 40),
    _at(11, 2),
    _client,
  ),
  _tracked(
    'design',
    _t('Project Waddle launch review', 'Startprüfung für Project Waddle'),
    _at(11, 18),
    _at(12, 5),
    _client,
  ),
  _tracked(
    'lunch',
    _t('Lunch, technically', 'Technisch gesehen Mittagspause'),
    _at(12, 10),
    _at(12, 50),
    _health,
  ),
  _tracked(
    'followup',
    _t('Negotiate sardine futures', 'Sardinen-Futures verhandeln'),
    _at(13, 5),
    _at(14, 55),
    _client,
  ),
  _tracked(
    'slides',
    _t('Zero-gravity fish feeder', 'Schwerelos-Futterautomat'),
    _at(15, 10),
    _at(15, 45),
    _deepWork,
    state: TimeBlockState.inProgress,
  ),
];

PlannerKnowledgeEntity _knowledge(
  String id,
  String key,
  String hook,
  String statement, {
  required KnowledgeStatus status,
  KnowledgeSource source = KnowledgeSource.agentInferred,
  List<String> tags = const [],
}) =>
    AgentDomainEntity.plannerKnowledge(
          id: id,
          agentId: 'planner-001',
          key: key,
          hook: hook,
          statementText: statement,
          source: source,
          status: status,
          createdAt: _now,
          updatedAt: _now,
          vectorClock: null,
          tags: tags,
        )
        as PlannerKnowledgeEntity;

PlannerKnowledgeView _knowledgeView() => PlannerKnowledgeView(
  proposed: [
    _knowledge(
      'kn-1',
      'habitat-before-mission-control',
      _t(
        'Habitat work lands before Mission Control wakes',
        'Habitatarbeit vor dem Aufwachen der Missionskontrolle',
      ),
      _t(
        'Habitat inspections started before the first call run 30% longer '
            'before a penguin or executive finds the red button.',
        'Habitatinspektionen vor dem ersten Anruf dauern 30 % länger, bevor '
            'ein Pinguin oder eine Führungskraft den roten Knopf findet.',
      ),
      status: KnowledgeStatus.proposed,
      tags: const ['penguins', 'mornings'],
    ),
    _knowledge(
      'kn-2',
      'walks-skipped-after-escapes',
      _t(
        'Walks get skipped after penguin escapes',
        'Spaziergänge entfallen nach Pinguinausbrüchen',
      ),
      _t(
        'When a penguin enters the ventilation system, the planned walk is '
            'usually dropped — protect it explicitly.',
        'Gerät ein Pinguin in die Lüftung, entfällt der geplante Spaziergang '
            'meistens – schütze ihn ausdrücklich.',
      ),
      status: KnowledgeStatus.proposed,
      tags: const ['health'],
    ),
  ],
  confirmed: [
    _knowledge(
      'kn-3',
      'no-briefings-before-ten',
      _t('No briefings before 10:00', 'Keine Briefings vor 10:00 Uhr'),
      _t(
        'Keep mornings briefing-free until 10:00 — stated preference.',
        'Vormittage bis 10:00 Uhr briefingfrei halten – geäußerte Präferenz.',
      ),
      status: KnowledgeStatus.confirmed,
      source: KnowledgeSource.userStated,
      tags: const ['mornings'],
    ),
  ],
);

CaptureController _stubCapture() {
  final recorder = MockAudioRecorderRepository();
  final transcriber = MockAudioTranscriptionService();
  when(recorder.stopRecording).thenAnswer((_) async {});
  return CaptureController(
    recorder: recorder,
    transcriber: transcriber,
    docDir: Directory.systemTemp.createTempSync,
    persistAudio: (_) async => null,
    now: () => _now,
  );
}

class _ScreenshotPreferencesController extends DailyOsPreferencesController {
  _ScreenshotPreferencesController({required this.retireDayFooterHint});

  final bool retireDayFooterHint;

  @override
  DailyOsPreferences build() => DailyOsPreferences(
    dayFooterHintRetired: retireDayFooterHint,
  );
}

/// Production-page data source for the manual's Refine and Shutdown routes.
///
/// The pages and controllers are real; only the durable backend responses are
/// deterministic so every capture tells the same connected Project Waddle
/// story.
class _ManualDailyOsAgent extends MockDayAgent {
  _ManualDailyOsAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
        clock: () => _now,
      );

  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
    bool Function()? isCancelled,
  }) async {
    final updatedBlocks = [
      for (final block in currentPlan.blocks)
        if (block.id == 'blk-followup')
          block.copyWith(start: _at(13, 30), end: _at(15))
        else if (block.id == 'blk-slides')
          block.copyWith(start: _at(15), end: _at(16, 30))
        else
          block,
    ];
    return PlanDiff(
      id: 'diff-project-waddle-launch-buffer',
      transcript: voiceTranscript,
      changes: [
        PlanDiffChange(
          id: 'change-protect-launch-review',
          kind: PlanDiffChangeKind.moved,
          title: _t(
            'Move sardine negotiations 30 minutes later',
            'Sardinenverhandlung um 30 Minuten verschieben',
          ),
          category: _client,
          reason: _t(
            'Protect the launch review and give Mission Control a buffer.',
            'Die Startprüfung schützen und der Missionskontrolle einen Puffer '
                'geben.',
          ),
          affectedBlockId: 'blk-followup',
          fromStart: _at(13),
          fromEnd: _at(14, 30),
          toStart: _at(13, 30),
          toEnd: _at(15),
        ),
        PlanDiffChange(
          id: 'change-protect-feeder-demo',
          kind: PlanDiffChangeKind.moved,
          title: _t(
            'Start the fish-feeder demo after the new buffer',
            'Futterautomaten-Demo nach dem neuen Puffer starten',
          ),
          category: _deepWork,
          reason: _t(
            'Keep the zero-gravity demo clear of the sardine negotiation.',
            'Die Schwerelos-Demo von der Sardinenverhandlung freihalten.',
          ),
          affectedBlockId: 'blk-slides',
          fromStart: _at(14, 30),
          fromEnd: _at(16),
          toStart: _at(15),
          toEnd: _at(16, 30),
        ),
      ],
      updatedPlan: currentPlan.copyWith(blocks: updatedBlocks),
    );
  }

  @override
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate}) async => (
    completed: [
      CompletedItem(
        taskId: manualOrbitalHabitatTaskId,
        title: _t(
          'Inspect orbital penguin habitat',
          'Pinguin-Habitat im Orbit inspizieren',
        ),
        category: _deepWork,
        durationMinutes: 93,
        note: _t(
          'Seals green; all 37 emperor penguins accounted for.',
          'Dichtungen grün; alle 37 Kaiserpinguine sind vollzählig.',
        ),
      ),
      CompletedItem(
        taskId: manualLaunchReviewTaskId,
        title: _t(
          'Project Waddle launch review',
          'Startprüfung für Project Waddle',
        ),
        category: _client,
        durationMinutes: 47,
        note: _t(
          'Mission Control approved the revised habitat checklist.',
          'Die Missionskontrolle genehmigte die überarbeitete Habitat-Checkliste.',
        ),
      ),
      CompletedItem(
        taskId: manualSardineFuturesTaskId,
        title: _t('Negotiate sardine futures', 'Sardinen-Futures verhandeln'),
        category: _client,
        durationMinutes: 110,
        note: _t(
          'Q3 supply secured below the emergency fish ceiling.',
          'Q3-Vorrat unter der Fisch-Notfallgrenze gesichert.',
        ),
      ),
    ],
    carryover: [
      CarryoverItem(
        taskId: manualFishFeederTaskId,
        title: _t('Zero-gravity fish feeder', 'Schwerelos-Futterautomat'),
        category: _deepWork,
        reason: _t(
          'Prototype calibrated; live habitat demo still pending.',
          'Prototyp kalibriert; Live-Demo des Habitats steht noch aus.',
        ),
        suggestedTarget: _t('→ tomorrow morning', '→ morgen Vormittag'),
      ),
      CarryoverItem(
        taskId: manualPenguinPassengerTaskId,
        title: _t(
          'Legal: Is a penguin a passenger?',
          'Rechtsfrage: Ist ein Pinguin ein Passagier?',
        ),
        category: _admin,
        reason: _t(
          'Mission Control review ran long.',
          'Die Prüfung der Missionskontrolle dauerte länger.',
        ),
        suggestedTarget: _t('→ tomorrow afternoon', '→ morgen Nachmittag'),
      ),
    ],
    metrics: const ShutdownMetrics(
      focusMinutes: 250,
      flowSessions: 4,
      contextSwitches: 3,
      contextSwitchesWeekAvg: 5.2,
      energyScore: 8.3,
      energyDeltaVsWeek: 1.1,
    ),
  );

  @override
  Future<TomorrowNote> generateTomorrowNote({
    required DateTime forDate,
  }) async => TomorrowNote(
    body: _t(
      'Start with the live fish-feeder demo at 09:00, then resolve the '
          'penguin passenger question before the launch window opens.',
      'Beginne um 09:00 Uhr mit der Live-Demo des Futterautomaten und kläre '
          'danach die Pinguin-Passagierfrage, bevor sich das Startfenster öffnet.',
    ),
    maturity: 3,
  );
}

enum _ManualDailyOsSurface { refine, commit, shutdown }

Widget _app({
  required Widget home,
  required Brightness brightness,
  required List<Override> overrides,
  required Size size,
  double textScale = 1.0,
}) {
  return RepaintBoundary(
    key: screenshotBoundaryKey,
    child: ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: manualScreenshotLocale,
          home: home,
        ),
      ),
    ),
  );
}

Widget _dayShell(ScreenshotDevice device, {required DraftPlan draft}) {
  final dayPage = DayPage(draft: draft);
  if (!device.isPhone) {
    DesktopSidebarDestination destination(
      String label,
      IconData icon,
      IconData activeIcon,
    ) => DesktopSidebarDestination(
      label: label,
      iconBuilder: ({required active}) => Icon(active ? activeIcon : icon),
    );

    return Row(
      children: [
        DesktopNavigationSidebar(
          destinations: [
            destination(
              _t('Tasks', 'Aufgaben'),
              Icons.check_circle_outline_rounded,
              Icons.check_circle_rounded,
            ),
            destination('Daily OS', Icons.today_outlined, Icons.today_rounded),
            destination(
              _t('Logbook', 'Logbuch'),
              Icons.menu_book_outlined,
              Icons.menu_book_rounded,
            ),
          ],
          activeIndex: 1,
          onDestinationSelected: (_) {},
          settingsDestination: destination(
            _t('Settings', 'Einstellungen'),
            Icons.settings_outlined,
            Icons.settings_rounded,
          ),
          onSettingsSelected: () {},
          utilityDestination: DesktopSidebarDestination(
            label: _t('Manual', 'Handbuch'),
            iconBuilder: ({required active}) =>
                const Icon(Icons.help_outline_rounded),
            trailingBuilder: ({required active}) =>
                const Icon(Icons.open_in_new_rounded),
            isLink: true,
            semanticsHint: _t(
              'Opens in your browser',
              'Wird im Browser geöffnet',
            ),
          ),
          onUtilitySelected: () {},
          onToggleCollapsed: () {},
        ),
        Expanded(child: dayPage),
      ],
    );
  }

  return Stack(
    children: [
      dayPage,
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: DesignSystemBottomNavigationBar(
          items: [
            const DesignSystemFiveSlotNavBarItem(
              label: 'Daily OS',
              icon: Icon(Icons.today_outlined),
              activeIcon: Icon(Icons.today_rounded),
              active: true,
            ),
            DesignSystemFiveSlotNavBarItem(
              label: _t('Tasks', 'Aufgaben'),
              icon: const Icon(Icons.check_circle_outline_rounded),
            ),
            DesignSystemFiveSlotNavBarItem(
              label: _t('Calendar', 'Kalender'),
              icon: const Icon(Icons.calendar_month_outlined),
            ),
            DesignSystemFiveSlotNavBarItem(
              label: _t('Settings', 'Einstellungen'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      ),
    ],
  );
}

Future<void> _pumpDayPage(
  WidgetTester tester, {
  required ScreenshotDevice device,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  bool showPlannerReview = true,
  List<DayActivityEntry> activityEntries = const [],
}) async {
  applyScreenshotDevice(tester, device);
  final documentsDirectory = _manualDocumentsDirectory;
  if (documentsDirectory == null) {
    throw StateError('Manual screenshot documents directory is unavailable.');
  }
  await withClock(Clock.fixed(_now), () async {
    final draft = showPlannerReview
        ? _plan()
        : _plan().copyWith(state: DayState.committed);
    await primeManualDemoCoverArt(
      tester,
      documentsDirectory: documentsDirectory,
      world: _manualWorld,
      extents: const [48, 96, 144, 216],
    );
    await tester.pumpWidget(
      _app(
        brightness: brightness,
        size: device.size,
        textScale: textScale,
        overrides: [
          capturesForDateProvider.overrideWith((ref, date) async => const []),
          dayActivityProvider.overrideWith(
            (ref, date) async => activityEntries,
          ),
          dailyOsActualTimeBlocksProvider.overrideWith(
            (ref, date) async => _actuals(),
          ),
          captureControllerProvider.overrideWith(_stubCapture),
          plannerKnowledgeProvider.overrideWith(
            (ref) async {
              final view = _knowledgeView();
              return showPlannerReview
                  ? view
                  : PlannerKnowledgeView(
                      proposed: const [],
                      confirmed: view.confirmed,
                    );
            },
          ),
          dailyOsPreferencesControllerProvider.overrideWith(
            () => _ScreenshotPreferencesController(
              retireDayFooterHint: !showPlannerReview,
            ),
          ),
          for (final coverImage in _manualWorld.coverImages)
            createEntryControllerOverride(coverImage),
        ],
        // DayPage lives inside the app shell in production. Reuse the real
        // design-system mobile bar / desktop sidebar so the captures reflect
        // each breakpoint instead of showing a hollow reserved band.
        home: _dayShell(device, draft: draft),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DayPage)),
    );
    await Future.wait(
      _manualWorld.coverImages.map(
        (image) =>
            container.read(entryControllerProvider(image.meta.id).future),
      ),
    );
    await settleFrames(tester);
  });
}

Future<void> _pumpManualDailyOsSurface(
  WidgetTester tester, {
  required _ManualDailyOsSurface surface,
  required ScreenshotDevice device,
  required Brightness brightness,
}) async {
  applyScreenshotDevice(tester, device);
  final draft = _plan();
  final agent = _ManualDailyOsAgent();
  final home = switch (surface) {
    _ManualDailyOsSurface.refine => RefinePage(draft: draft),
    _ManualDailyOsSurface.commit => CommitPage(draft: draft),
    _ManualDailyOsSurface.shutdown => ShutdownPage(forDate: _day),
  };

  await withClock(Clock.fixed(_now), () async {
    await tester.pumpWidget(
      _app(
        brightness: brightness,
        size: device.size,
        overrides: [
          captureControllerProvider.overrideWith(_stubCapture),
          dayAgentProvider.overrideWithValue(agent),
          plannerKnowledgeProvider.overrideWith(
            (ref) async => _knowledgeView(),
          ),
          dailyOsPreferencesControllerProvider.overrideWith(
            () => _ScreenshotPreferencesController(retireDayFooterHint: true),
          ),
        ],
        home: home,
      ),
    );
    await settleFrames(tester, 6);

    if (surface == _ManualDailyOsSurface.refine) {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RefinePage)),
      );
      final notifier = container.read(
        refineControllerProvider(draft).notifier,
      );
      await (notifier..reviewTranscript(
            _t(
              'Protect the launch review, move sardine negotiations later, '
                  'and keep the fish-feeder demo clear.',
              'Schütze die Startprüfung, verschiebe die Sardinenverhandlung '
                  'nach hinten und halte die Futterautomaten-Demo frei.',
            ),
          ))
          .submitReviewedTranscript();
      await settleFrames(tester, 6);
    }
  });
}

AppLocalizations _messages(WidgetTester tester) =>
    tester.element(find.byType(DayPage)).messages;

/// Taps a PlanViewToggle segment in either rendering mode: by visible label
/// when the toggle is wide enough for text (`.last` skips the invisible
/// width-reserving ghost label), or by glyph once the three-segment toggle
/// collapses to icons at narrow widths / large text scales.
Future<void> _tapPlanViewSegment(
  WidgetTester tester, {
  required String label,
  required IconData icon,
}) async {
  await withClock(Clock.fixed(_now), () async {
    final text = find.text(label);
    if (tester.any(text)) {
      await tester.tap(text.last);
    } else {
      await tester.tap(find.byIcon(icon).last);
    }
    await settleFrames(tester);
  });
}

Future<void> _switchToDayView(WidgetTester tester) => _tapPlanViewSegment(
  tester,
  label: _messages(tester).dailyOsNextPlanViewDay,
  icon: Icons.calendar_view_day_outlined,
);

Future<void> _switchToActivityView(WidgetTester tester) => _tapPlanViewSegment(
  tester,
  label: _messages(tester).dailyOsNextPlanViewActivity,
  icon: Icons.timeline_outlined,
);

Future<void> _enableArrangeMode(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('daily_os_timeline_arrange_toggle')));
  await settleFrames(tester);
  expect(
    find.byKey(const Key('daily_os_move_block_blk-review')),
    findsOneWidget,
  );
  expect(
    find.byKey(const Key('daily_os_resize_end_blk-review')),
    findsOneWidget,
  );
}

/// Pages the phone timeline to the recorded lane via the controller — a
/// gesture drag is text-scale-dependent (at 2x the same offset no longer
/// crosses the snap threshold and silently leaves the planned lane in
/// frame, producing a duplicate shot).
Future<void> _showRecordedLane(WidgetTester tester) async {
  await withClock(Clock.fixed(_now), () async {
    final pageView = tester.widget<PageView>(find.byType(PageView));
    pageView.controller!.jumpToPage(1);
    await settleFrames(tester);
  });
}

Future<void> _openBlockEditor(
  WidgetTester tester, {
  required String blockId,
}) async {
  await withClock(Clock.fixed(_now), () async {
    final editButton = find.byKey(Key('daily_os_edit_block_$blockId'));
    final iconButton = tester.widget<IconButton>(editButton);
    expect(iconButton.onPressed, isNotNull);
    iconButton.onPressed!();
    await settleFrames(tester);
  });
  expect(
    find.text(_messages(tester).dailyOsNextBlockEditTitle),
    findsOneWidget,
  );
}

void _expectAgendaThumbnails(WidgetTester tester) {
  final agendaThumbnails = find.descendant(
    of: find.byType(AgendaView),
    matching: find.byType(CoverArtThumbnail),
  );
  expect(agendaThumbnails, findsNWidgets(8));
  final thumbnails = tester
      .widgetList<CoverArtThumbnail>(agendaThumbnails)
      .toList();
  expect(
    thumbnails.map((thumbnail) => thumbnail.imageId).toSet(),
    <String>{
      manualRollCallCoverImageId,
      manualHabitatCoverImageId,
      manualLaunchReviewCoverImageId,
      manualLunchCoverImageId,
      manualSardineFuturesCoverImageId,
      manualFishFeederCoverImageId,
      manualPenguinPassengerCoverImageId,
      manualHeadsetWalkCoverImageId,
    },
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CoverArtThumbnail).first),
  );
  for (final thumbnail in thumbnails) {
    expect(
      container.read(entryControllerProvider(thumbnail.imageId)).value?.entry,
      _manualWorld.coverImageById(thumbnail.imageId),
    );
  }
  expect(
    find.descendant(
      of: agendaThumbnails,
      matching: find.byType(Image),
    ),
    findsNWidgets(8),
  );
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'day-page screenshot harness (opt-in)',
      () {},
      skip:
          'Design-review screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true) '
          'because the real-font loading leaks process-wide.',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  setUp(() async {
    _manualWorld = ManualDemoWorld.penguinLogistics();
    final documentsDirectory = Directory.systemTemp.createTempSync(
      'lotti-manual-daily-os-',
    );
    _manualDocumentsDirectory = documentsDirectory;
    await _manualWorld.installMedia(documentsDirectory);
    final mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<Directory>(documentsDirectory)
          ..registerSingleton<EditorStateService>(MockEditorStateService());
      },
    );
    when(
      () => mocks.journalDb.journalEntityById(any()),
    ).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as String;
      return _manualWorld.entityById(id);
    });
    when(
      () => mocks.journalDb.getCategoryById(manualDemoCategoryId),
    ).thenAnswer((_) async => _manualWorld.category);
  });

  tearDown(() async {
    await tearDownTestGetIt();
    final documentsDirectory = _manualDocumentsDirectory;
    _manualDocumentsDirectory = null;
    if (documentsDirectory?.existsSync() ?? false) {
      documentsDirectory!.deleteSync(recursive: true);
    }
  });

  for (final device in [miniDevice, proDevice, desktopDevice]) {
    testWidgets('${device.name} agenda — dark', (tester) async {
      await _pumpDayPage(
        tester,
        device: device,
        showPlannerReview: false,
      );
      expect(find.byType(AgendaView), findsOneWidget);
      _expectAgendaThumbnails(tester);
      await captureScreenshot(tester, 'day_${device.name}_01_agenda_dark');
    });

    testWidgets('${device.name} timeline — dark', (tester) async {
      await _pumpDayPage(tester, device: device);
      await _switchToDayView(tester);
      expect(find.byType(DayTimeline), findsOneWidget);
      await captureScreenshot(tester, 'day_${device.name}_02_timeline_dark');
    });
  }

  testWidgets('mini timeline recorded lane — dark', (tester) async {
    await _pumpDayPage(tester, device: miniDevice);
    await _switchToDayView(tester);
    // Mobile timeline pages between planned and recorded lanes.
    await _showRecordedLane(tester);
    await captureScreenshot(tester, 'day_mini_03_timeline_recorded_dark');
  });

  testWidgets('pro timeline arrange mode — dark', (tester) async {
    await _pumpDayPage(tester, device: proDevice);
    await _switchToDayView(tester);
    await _enableArrangeMode(tester);
    await captureScreenshot(tester, 'day_pro_03_timeline_arrange_dark');
  });

  testWidgets('desktop timeline arrange mode — dark', (tester) async {
    await _pumpDayPage(tester, device: desktopDevice);
    await _switchToDayView(tester);
    await _enableArrangeMode(tester);
    await captureScreenshot(tester, 'day_desktop_05_timeline_arrange_dark');
  });

  testWidgets('desktop activity recovery — dark', (tester) async {
    await _pumpDayPage(
      tester,
      device: desktopDevice,
      activityEntries: _activityEntries(),
    );
    await _switchToActivityView(tester);
    final messages = _messages(tester);
    expect(
      find.text(messages.dailyOsNextActivityWaitingForNetwork),
      findsOneWidget,
    );
    expect(find.text(messages.dailyOsNextActivityRetry), findsOneWidget);
    expect(find.text(messages.dailyOsNextActivityUseToRefine), findsOneWidget);
    await captureScreenshot(tester, 'daily_os_activity_desktop_dark');
  });

  testWidgets('pro block editor overview — dark', (tester) async {
    await _pumpDayPage(tester, device: proDevice);
    await _switchToDayView(tester);
    await _openBlockEditor(tester, blockId: 'blk-slides');
    expect(
      find.text(_t('Zero-gravity fish feeder', 'Schwerelos-Futterautomat')),
      findsWidgets,
    );
    expect(
      find.text(_messages(tester).dailyOsNextBlockEditTimeLabel),
      findsOneWidget,
    );
    await captureScreenshot(tester, 'day_pro_04_block_edit_overview_dark');
  });

  testWidgets('pro block editor start and end — dark', (tester) async {
    await _pumpDayPage(tester, device: proDevice);
    await _switchToDayView(tester);
    await _openBlockEditor(tester, blockId: 'blk-slides');
    final timeField = tester
        .widgetList<SettingsPickerField>(find.byType(SettingsPickerField))
        .singleWhere(
          (field) =>
              field.label == _messages(tester).dailyOsNextBlockEditTimeLabel,
        );
    timeField.onTap();
    await settleFrames(tester);
    expect(find.byType(DesignSystemTimeWheel), findsNWidgets(2));
    await captureScreenshot(tester, 'day_pro_05_block_edit_time_dark');
  });

  testWidgets('pro linked-task block editor — dark', (tester) async {
    await _pumpDayPage(tester, device: proDevice);
    await _switchToDayView(tester);
    await _openBlockEditor(tester, blockId: 'blk-deep');
    expect(
      find.text(_messages(tester).dailyOsNextBlockEditOpenTask),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    await captureScreenshot(tester, 'day_pro_06_block_edit_linked_dark');
  });

  testWidgets('mini agenda — light', (tester) async {
    await _pumpDayPage(
      tester,
      device: miniDevice,
      brightness: Brightness.light,
      showPlannerReview: false,
    );
    expect(find.byType(AgendaView), findsOneWidget);
    _expectAgendaThumbnails(tester);
    await captureScreenshot(tester, 'day_mini_04_agenda_light');
  });

  testWidgets('desktop agenda — light', (tester) async {
    await _pumpDayPage(
      tester,
      device: desktopDevice,
      brightness: Brightness.light,
      showPlannerReview: false,
    );
    expect(find.byType(AgendaView), findsOneWidget);
    _expectAgendaThumbnails(tester);
    await captureScreenshot(tester, 'day_desktop_03_agenda_light');
  });

  testWidgets('mini timeline — light', (tester) async {
    await _pumpDayPage(
      tester,
      device: miniDevice,
      brightness: Brightness.light,
    );
    await _switchToDayView(tester);
    expect(find.byType(DayTimeline), findsOneWidget);
    await captureScreenshot(tester, 'day_mini_05_timeline_light');
  });

  testWidgets('desktop timeline — light', (tester) async {
    await _pumpDayPage(
      tester,
      device: desktopDevice,
      brightness: Brightness.light,
    );
    await _switchToDayView(tester);
    expect(find.byType(DayTimeline), findsOneWidget);
    await captureScreenshot(tester, 'day_desktop_04_timeline_light');
  });

  testWidgets('pro timeline arrange mode — light', (tester) async {
    await _pumpDayPage(
      tester,
      device: proDevice,
      brightness: Brightness.light,
    );
    await _switchToDayView(tester);
    await _enableArrangeMode(tester);
    await captureScreenshot(tester, 'day_pro_07_timeline_arrange_light');
  });

  testWidgets('desktop timeline arrange mode — light', (tester) async {
    await _pumpDayPage(
      tester,
      device: desktopDevice,
      brightness: Brightness.light,
    );
    await _switchToDayView(tester);
    await _enableArrangeMode(tester);
    await captureScreenshot(tester, 'day_desktop_06_timeline_arrange_light');
  });

  for (final deviceCase in [
    (device: proDevice, viewport: 'mobile'),
    (device: desktopDevice, viewport: 'desktop'),
  ]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;

      for (final surface in _ManualDailyOsSurface.values) {
        testWidgets(
          'manual daily OS ${surface.name} ${deviceCase.viewport} — $theme',
          (tester) async {
            await _pumpManualDailyOsSurface(
              tester,
              surface: surface,
              device: deviceCase.device,
              brightness: brightness,
            );

            switch (surface) {
              case _ManualDailyOsSurface.refine:
                expect(find.byType(RefinePage), findsOneWidget);
                expect(
                  find.text(
                    _t(
                      'Move sardine negotiations 30 minutes later',
                      'Sardinenverhandlung um 30 Minuten verschieben',
                    ),
                  ),
                  findsOneWidget,
                );
              case _ManualDailyOsSurface.commit:
                expect(find.byType(CommitPage), findsOneWidget);
                expect(
                  find.text(
                    _t(
                      'Inspect orbital penguin habitat',
                      'Pinguin-Habitat im Orbit inspizieren',
                    ),
                  ),
                  findsOneWidget,
                );
                if (deviceCase.device.isPhone) {
                  await tester.ensureVisible(
                    find.byKey(const Key('hold-to-confirm-focus')),
                  );
                  await settleFrames(tester);
                }
                expect(
                  find.byKey(const Key('hold-to-confirm-focus')),
                  findsOneWidget,
                );
              case _ManualDailyOsSurface.shutdown:
                expect(find.byType(ShutdownPage), findsOneWidget);
                expect(
                  find.text(
                    _t(
                      'Zero-gravity fish feeder',
                      'Schwerelos-Futterautomat',
                    ),
                  ),
                  findsOneWidget,
                );
            }

            await captureScreenshot(
              tester,
              'daily_os_${surface.name}_${deviceCase.viewport}_$theme',
            );
          },
        );
      }

      testWidgets(
        'manual daily OS block editor ${deviceCase.viewport} — $theme',
        (tester) async {
          await _pumpDayPage(
            tester,
            device: deviceCase.device,
            brightness: brightness,
          );
          await _switchToDayView(tester);
          await _openBlockEditor(tester, blockId: 'blk-slides');
          expect(
            find.text(
              _t('Zero-gravity fish feeder', 'Schwerelos-Futterautomat'),
            ),
            findsWidgets,
          );
          expect(
            find.text(_messages(tester).dailyOsNextBlockEditTimeLabel),
            findsOneWidget,
          );
          await captureScreenshot(
            tester,
            'daily_os_block_editor_${deviceCase.viewport}_$theme',
          );
        },
      );
    }
  }

  testWidgets('mini agenda — dark, 1.3x text', (tester) async {
    await _pumpDayPage(tester, device: miniDevice, textScale: 1.3);
    await captureScreenshot(tester, 'day_mini_06_agenda_dark_ts13');
  });

  // 2.0x — the upper end of common accessibility text sizes.
  testWidgets('mini agenda — dark, 2.0x text', (tester) async {
    await _pumpDayPage(tester, device: miniDevice, textScale: 2);
    await captureScreenshot(tester, 'day_mini_07_agenda_dark_ts20');
  });

  testWidgets('mini timeline — dark, 2.0x text', (tester) async {
    await _pumpDayPage(tester, device: miniDevice, textScale: 2);
    await _switchToDayView(tester);
    await captureScreenshot(tester, 'day_mini_08_timeline_dark_ts20');
  });

  testWidgets('mini timeline recorded lane — dark, 2.0x text', (
    tester,
  ) async {
    await _pumpDayPage(tester, device: miniDevice, textScale: 2);
    await _switchToDayView(tester);
    await _showRecordedLane(tester);
    await captureScreenshot(tester, 'day_mini_09_timeline_recorded_ts20');
  });
}

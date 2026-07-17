/// Deterministic manual screenshots for the production Agents surfaces.
///
/// The fixture extends the Intergalactic Penguin Logistics demo world with
/// agent templates, personalities (souls), running instances, evolution
/// rituals, token activity, and scheduled wakes. Desktop list captures use
/// the real Settings V2 shell; mobile captures use the production tabbed
/// settings page. Editors, ritual reviews, and instance details are the real
/// routed pages at both sizes.
///
/// Generated PNGs are staging inputs for `lotti-docs` and are never committed
/// to this repository.
///
/// Opt in with:
/// `LOTTI_SCREENSHOT_DIR=/tmp/lotti_agents_manual fvm flutter test \
///   test/features/agents/ui/agents_manual_screenshots_test.dart`
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/model/hourly_wake_activity.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/model/task_resolution_time_series.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/token_stats_providers.dart';
import 'package:lotti/features/agents/state/wake_run_chart_providers.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/agents/ui/agent_soul_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_review_page.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_review_page.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/features/agents/ui/pending_wakes/wake_countdown_ticker.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/features/settings_v2/ui/pages/settings_v2_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/manual_demo_world.dart';
import '../../../helpers/target_platform.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../daily_os_next/screenshot_harness.dart';
import '../test_utils.dart';

const String _subdir = 'agents';
String _t(String en, String de) => manualScreenshotText(en: en, de: de);
AppLocalizations _messages(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
const String _habitatTemplateId = 'template-habitat-sentinel';
const String _dayPlannerTemplateId = 'template-waddle-day-planner';
const String _cargoTemplateId = 'template-sardine-cargo-watch';
const String _diplomacyTemplateId = 'template-fish-diplomacy-coach';
const String _pebbleSoulId = 'soul-admiral-pebble';
const String _flipperSoulId = 'soul-dr-flipper';
const String _sardinaSoulId = 'soul-captain-sardina';
const String _habitatAgentId = 'agent-habitat-seal-inspector';
const String _dayPlannerAgentId = 'agent-project-waddle-planner';
const String _cargoAgentId = 'agent-sardine-cargo-coordinator';

enum _AgentSurface {
  stats,
  templates,
  instances,
  souls,
  pendingWakes,
  templateEditor,
  templateReview,
  soulEditor,
  soulReview,
  instanceDetail,
}

final List<AgentTemplateEntity> _templates = [
  makeTestTemplate(
    id: _habitatTemplateId,
    agentId: _habitatTemplateId,
    displayName: _t(
      'Orbital Habitat Sentinel',
      'Wächter des Orbital-Habitats',
    ),
    modelId: _t('Waddle Command 70B', 'Watschelkommando 70B'),
    categoryIds: const {manualDemoCategoryId},
    profileId: manualProjectWaddleProfileId,
    createdAt: manualDemoNow.subtract(const Duration(days: 48)),
    updatedAt: manualDemoNow.subtract(const Duration(hours: 2)),
  ),
  makeTestTemplate(
    id: _dayPlannerTemplateId,
    agentId: _dayPlannerTemplateId,
    displayName: _t(
      'Project Waddle Day Planner',
      'Project-Waddle-Tagesplaner',
    ),
    kind: AgentTemplateKind.dayAgent,
    modelId: _t('Emperor Reasoning XL', 'Kaiserpinguin-Denken XL'),
    categoryIds: const {manualDemoCategoryId},
    profileId: manualProjectWaddleProfileId,
    createdAt: manualDemoNow.subtract(const Duration(days: 36)),
    updatedAt: manualDemoNow.subtract(const Duration(hours: 5)),
  ),
  makeTestTemplate(
    id: _cargoTemplateId,
    agentId: _cargoTemplateId,
    displayName: _t('Sardine Supply Watch', 'Sardinen-Vorratswache'),
    kind: AgentTemplateKind.projectAgent,
    modelId: _t('Sardine Logistics 14B', 'Sardinenlogistik 14B'),
    categoryIds: const {manualDemoCategoryId},
    profileId: manualHabitatLocalProfileId,
    createdAt: manualDemoNow.subtract(const Duration(days: 29)),
    updatedAt: manualDemoNow.subtract(const Duration(days: 1)),
  ),
  makeTestTemplate(
    id: _diplomacyTemplateId,
    agentId: _diplomacyTemplateId,
    displayName: _t('Fish Diplomacy Coach', 'Fischdiplomatie-Coach'),
    kind: AgentTemplateKind.templateImprover,
    modelId: _t('Emperor Reasoning XL', 'Kaiserpinguin-Denken XL'),
    profileId: manualFishDiplomacyProfileId,
    createdAt: manualDemoNow.subtract(const Duration(days: 21)),
    updatedAt: manualDemoNow.subtract(const Duration(days: 3)),
  ),
];

final Map<String, AgentTemplateVersionEntity> _templateVersions = {
  _habitatTemplateId: makeTestTemplateVersion(
    id: 'version-habitat-v4',
    agentId: _habitatTemplateId,
    version: 4,
    generalDirective: _t(
      'Protect Project Waddle by checking pressure seals, habitat telemetry, '
          'and every suspiciously cheerful penguin before launch.',
      'Schütze Project Waddle, indem du vor dem Start Druckdichtungen, '
          'Habitattelemetrie und jeden verdächtig fröhlichen Pinguin prüfst.',
    ),
    reportDirective: _t(
      'End with a concise go/no-go recommendation and list any seals that '
          'need a human inspection.',
      'Schließe mit einer knappen Start-oder-Stopp-Empfehlung und liste alle '
          'Dichtungen auf, die ein Mensch inspizieren muss.',
    ),
    authoredBy: _t('Mission Control', 'Missionskontrolle'),
    profileId: manualProjectWaddleProfileId,
    createdAt: manualDemoNow.subtract(const Duration(days: 2)),
  ),
  _dayPlannerTemplateId: makeTestTemplateVersion(
    id: 'version-day-planner-v3',
    agentId: _dayPlannerTemplateId,
    version: 3,
    generalDirective: _t(
      'Build a realistic day around energy, fixed launch windows, and the '
          'colony rule that lunch still counts even during a sardine emergency.',
      'Baue einen realistischen Tag um Energie, feste Startfenster und die '
          'Kolonieregel, dass die Mittagspause auch bei einem '
          'Sardinennotfall zählt.',
    ),
    reportDirective: _t(
      'Call out over-capacity plans before asking for commitment.',
      'Benenne überladene Pläne, bevor du um eine Zusage bittest.',
    ),
    authoredBy: _t('Project Waddle Operations', 'Project-Waddle-Betrieb'),
    profileId: manualProjectWaddleProfileId,
    createdAt: manualDemoNow.subtract(const Duration(days: 4)),
  ),
  _cargoTemplateId: makeTestTemplateVersion(
    id: 'version-cargo-v2',
    agentId: _cargoTemplateId,
    version: 2,
    generalDirective: _t(
      'Track sardine cargo pods, cold-chain handoffs, and zero-gravity feeder '
          'stock without sending private manifests to a cloud model.',
      'Verfolge Sardinen-Frachtkapseln, Kühlkettenübergaben und den Bestand '
          'des Schwerelos-Futterautomaten, ohne private Frachtlisten an ein '
          'Cloud-Modell zu senden.',
    ),
    reportDirective: _t(
      'Report shortages by habitat, pod, and expected penguin impact.',
      'Melde Engpässe nach Habitat, Kapsel und erwarteter Auswirkung auf '
          'die Pinguine.',
    ),
    authoredBy: _t('Cargo Bay', 'Frachtbucht'),
    profileId: manualHabitatLocalProfileId,
    createdAt: manualDemoNow.subtract(const Duration(days: 6)),
  ),
  _diplomacyTemplateId: makeTestTemplateVersion(
    id: 'version-diplomacy-v2',
    agentId: _diplomacyTemplateId,
    version: 2,
    generalDirective: _t(
      'Coach agent templates to be clear, skeptical, and gracious during '
          'high-stakes fish negotiations.',
      'Trainiere Agentenvorlagen, bei wichtigen Fischverhandlungen klar, '
          'skeptisch und höflich zu sein.',
    ),
    reportDirective: _t(
      'Explain each proposed wording change without flattery.',
      'Erkläre jede vorgeschlagene Formulierungsänderung ohne Schmeichelei.',
    ),
    authoredBy: _t('Interplanetary Relations', 'Interplanetare Beziehungen'),
    profileId: manualFishDiplomacyProfileId,
    createdAt: manualDemoNow.subtract(const Duration(days: 8)),
  ),
};

final List<SoulDocumentEntity> _souls = [
  makeTestSoulDocument(
    id: _pebbleSoulId,
    agentId: _pebbleSoulId,
    displayName: _t('Admiral Pebble', 'Admiral Kiesel'),
    createdAt: manualDemoNow.subtract(const Duration(days: 44)),
    updatedAt: manualDemoNow.subtract(const Duration(hours: 3)),
  ),
  makeTestSoulDocument(
    id: _flipperSoulId,
    agentId: _flipperSoulId,
    displayName: _t('Dr. Flipper', 'Dr. Flosse'),
    createdAt: manualDemoNow.subtract(const Duration(days: 31)),
    updatedAt: manualDemoNow.subtract(const Duration(days: 1)),
  ),
  makeTestSoulDocument(
    id: _sardinaSoulId,
    agentId: _sardinaSoulId,
    displayName: _t('Captain Sardina', 'Kapitän Sardina'),
    createdAt: manualDemoNow.subtract(const Duration(days: 25)),
    updatedAt: manualDemoNow.subtract(const Duration(days: 2)),
  ),
];

final Map<String, SoulDocumentVersionEntity> _soulVersions = {
  _pebbleSoulId: makeTestSoulDocumentVersion(
    id: 'soul-version-pebble-v5',
    agentId: _pebbleSoulId,
    version: 5,
    authoredBy: _t('Mission Control', 'Missionskontrolle'),
    voiceDirective: _t(
      'Speak like a calm flight director who respects both evidence and '
          'penguins. Put the operational decision first.',
      'Sprich wie ein ruhiger Flugleiter, der Belege und Pinguine respektiert. '
          'Stelle die betriebliche Entscheidung an den Anfang.',
    ),
    toneBounds: _t(
      'Dry warmth is welcome. Never turn a safety warning into a joke.',
      'Trockene Wärme ist willkommen. Mache aus einer Sicherheitswarnung '
          'niemals einen Witz.',
    ),
    coachingStyle: _t(
      'Ask one clarifying question when telemetry is ambiguous, then propose '
          'the smallest safe next step.',
      'Stelle bei mehrdeutiger Telemetrie eine klärende Frage und schlage '
          'dann den kleinsten sicheren nächsten Schritt vor.',
    ),
    antiSycophancyPolicy: _t(
      'Challenge optimistic launch assumptions and cite the observation that '
          'changed your conclusion.',
      'Hinterfrage optimistische Startannahmen und nenne die Beobachtung, '
          'die deine Schlussfolgerung verändert hat.',
    ),
    createdAt: manualDemoNow.subtract(const Duration(days: 3)),
  ),
  _flipperSoulId: makeTestSoulDocumentVersion(
    id: 'soul-version-flipper-v3',
    agentId: _flipperSoulId,
    version: 3,
    authoredBy: _t('Habitat Science', 'Habitatforschung'),
    voiceDirective: _t(
      'Be curious, precise, and delighted by useful anomalies.',
      'Sei neugierig, präzise und erfreut über nützliche Anomalien.',
    ),
    toneBounds: _t(
      'No alarmism; distinguish measurements from hypotheses.',
      'Kein Alarmismus; unterscheide Messungen von Hypothesen.',
    ),
    coachingStyle: _t(
      'Turn vague concerns into an observable test.',
      'Mache aus vagen Bedenken einen beobachtbaren Test.',
    ),
    antiSycophancyPolicy: _t(
      'Prefer an awkward fact over an elegant story.',
      'Bevorzuge eine unbequeme Tatsache gegenüber einer eleganten Geschichte.',
    ),
    createdAt: manualDemoNow.subtract(const Duration(days: 7)),
  ),
  _sardinaSoulId: makeTestSoulDocumentVersion(
    id: 'soul-version-sardina-v2',
    agentId: _sardinaSoulId,
    version: 2,
    authoredBy: _t('Cargo Bay', 'Frachtbucht'),
    voiceDirective: _t(
      'Be brisk, practical, and exact about quantities.',
      'Sei zügig, praktisch und bei Mengen exakt.',
    ),
    toneBounds: _t(
      'Never shame a penguin for an empty feeder.',
      'Beschäme keinen Pinguin wegen eines leeren Futterautomaten.',
    ),
    coachingStyle: _t(
      'Name the blocked handoff and the next owner.',
      'Benenne die blockierte Übergabe und die nächste verantwortliche Person.',
    ),
    antiSycophancyPolicy: _t(
      'Do not declare cargo healthy without pod counts.',
      'Erkläre Fracht nicht ohne Kapselzahlen für gesund.',
    ),
    createdAt: manualDemoNow.subtract(const Duration(days: 10)),
  ),
};

final List<AgentIdentityEntity> _agents = [
  makeTestIdentity(
    id: _habitatAgentId,
    agentId: _habitatAgentId,
    displayName: _t('Habitat Seal Inspector', 'Habitatdichtungs-Inspektor'),
    allowedCategoryIds: const {manualDemoCategoryId},
    currentStateId: 'state-habitat',
    config: const AgentConfig(profileId: manualProjectWaddleProfileId),
    createdAt: manualDemoNow.subtract(const Duration(days: 18)),
    updatedAt: manualDemoNow.subtract(const Duration(minutes: 7)),
  ),
  makeTestIdentity(
    id: _dayPlannerAgentId,
    agentId: _dayPlannerAgentId,
    kind: AgentKinds.dayAgent,
    displayName: _t('Project Waddle Planner', 'Project-Waddle-Planer'),
    allowedCategoryIds: const {manualDemoCategoryId},
    currentStateId: 'state-day-planner',
    config: const AgentConfig(profileId: manualProjectWaddleProfileId),
    createdAt: manualDemoNow.subtract(const Duration(days: 14)),
    updatedAt: manualDemoNow.subtract(const Duration(minutes: 19)),
  ),
  makeTestIdentity(
    id: _cargoAgentId,
    agentId: _cargoAgentId,
    kind: AgentKinds.projectAgent,
    displayName: _t('Sardine Cargo Coordinator', 'Sardinenfracht-Koordinator'),
    lifecycle: AgentLifecycle.dormant,
    allowedCategoryIds: const {manualDemoCategoryId},
    currentStateId: 'state-cargo',
    config: const AgentConfig(profileId: manualHabitatLocalProfileId),
    createdAt: manualDemoNow.subtract(const Duration(days: 12)),
    updatedAt: manualDemoNow.subtract(const Duration(hours: 6)),
  ),
];

final Map<String, AgentStateEntity> _agentStates = {
  _habitatAgentId: makeTestState(
    id: 'state-habitat',
    agentId: _habitatAgentId,
    revision: 17,
    slots: const AgentSlots(activeTaskId: manualOrbitalHabitatTaskId),
    wakeCounter: 42,
    lastWakeAt: manualDemoNow.subtract(const Duration(minutes: 7)),
    nextWakeAt: manualDemoNow.add(const Duration(minutes: 12, seconds: 8)),
    updatedAt: manualDemoNow.subtract(const Duration(minutes: 7)),
  ),
  _dayPlannerAgentId: makeTestState(
    id: 'state-day-planner',
    agentId: _dayPlannerAgentId,
    revision: 11,
    wakeCounter: 28,
    lastWakeAt: manualDemoNow.subtract(const Duration(minutes: 19)),
    scheduledWakeAt: manualDemoNow.add(const Duration(minutes: 35)),
    updatedAt: manualDemoNow.subtract(const Duration(minutes: 19)),
  ),
  _cargoAgentId: makeTestState(
    id: 'state-cargo',
    agentId: _cargoAgentId,
    revision: 8,
    slots: const AgentSlots(activeProjectId: 'project-waddle'),
    wakeCounter: 16,
    lastWakeAt: manualDemoNow.subtract(const Duration(hours: 6)),
    updatedAt: manualDemoNow.subtract(const Duration(hours: 6)),
  ),
};

final List<InstanceVm> _instanceVms = [
  InstanceVm(
    id: _habitatAgentId,
    displayName: _t('Habitat Seal Inspector', 'Habitatdichtungs-Inspektor'),
    type: InstanceType.taskAgent,
    status: AgentLifecycle.active,
    updatedAt: manualDemoNow.subtract(const Duration(minutes: 7)),
    soulName: _t('Admiral Pebble', 'Admiral Kiesel'),
    soulId: _pebbleSoulId,
    templateId: _habitatTemplateId,
    templateName: _t(
      'Orbital Habitat Sentinel',
      'Wächter des Orbital-Habitats',
    ),
    searchKey: 'habitat seal inspector admiral pebble orbital sentinel',
  ),
  InstanceVm(
    id: _dayPlannerAgentId,
    displayName: _t('Project Waddle Planner', 'Project-Waddle-Planer'),
    type: InstanceType.dayAgent,
    status: AgentLifecycle.active,
    updatedAt: manualDemoNow.subtract(const Duration(minutes: 19)),
    soulName: _t('Dr. Flipper', 'Dr. Flosse'),
    soulId: _flipperSoulId,
    templateId: _dayPlannerTemplateId,
    templateName: _t(
      'Project Waddle Day Planner',
      'Project-Waddle-Tagesplaner',
    ),
    searchKey: 'project waddle planner dr flipper day planner',
  ),
  InstanceVm(
    id: _cargoAgentId,
    displayName: _t('Sardine Cargo Coordinator', 'Sardinenfracht-Koordinator'),
    type: InstanceType.projectAgent,
    status: AgentLifecycle.dormant,
    updatedAt: manualDemoNow.subtract(const Duration(hours: 6)),
    soulName: _t('Captain Sardina', 'Kapitän Sardina'),
    soulId: _sardinaSoulId,
    templateId: _cargoTemplateId,
    templateName: _t('Sardine Supply Watch', 'Sardinen-Vorratswache'),
    searchKey: 'sardine cargo coordinator captain sardina supply watch',
  ),
  InstanceVm(
    id: 'evolution-fish-diplomacy-2',
    displayName: '',
    sessionNumber: 2,
    type: InstanceType.evolution,
    status: AgentLifecycle.created,
    updatedAt: manualDemoNow.subtract(const Duration(hours: 1)),
    templateId: _diplomacyTemplateId,
    searchKey: 'evolution 2 fish diplomacy coach',
  ),
];

final List<PendingWakeRecord> _pendingWakes = [
  PendingWakeRecord(
    agent: _agents[0],
    state: _agentStates[_habitatAgentId]!,
    type: PendingWakeType.pending,
    dueAt: manualDemoNow.add(const Duration(minutes: 12, seconds: 8)),
  ),
  PendingWakeRecord(
    agent: _agents[1],
    state: _agentStates[_dayPlannerAgentId]!,
    type: PendingWakeType.scheduled,
    dueAt: manualDemoNow.add(const Duration(minutes: 35)),
    subjectLabel: _t(
      'Project Waddle launch day · July 18',
      'Project-Waddle-Starttag · 18. Juli',
    ),
  ),
  PendingWakeRecord(
    agent: _agents[2],
    state: _agentStates[_cargoAgentId]!,
    type: PendingWakeType.scheduled,
    dueAt: manualDemoNow.add(const Duration(hours: 2, minutes: 5)),
  ),
];

final List<DailyTokenUsage> _dailyUsage = [
  for (var index = 6; index >= 0; index--)
    DailyTokenUsage(
      date: DateTime(2026, 7, 17 - index),
      totalTokens: 12200 + (6 - index) * 2300,
      tokensByTimeOfDay: 8100 + (6 - index) * 1700,
      isToday: index == 0,
      inputTokens: 7600 + (6 - index) * 1200,
      outputTokens: 3100 + (6 - index) * 700,
      thoughtsTokens: 1500 + (6 - index) * 400,
    ),
];

final List<HourlyWakeActivity> _hourlyActivity = [
  for (var hour = 0; hour < 24; hour++)
    HourlyWakeActivity(
      hour: DateTime(2026, 7, 16, 11).add(Duration(hours: hour)),
      count: switch (hour) {
        2 || 7 || 13 || 20 => 3,
        4 || 9 || 15 || 22 => 2,
        0 || 5 || 11 || 17 => 1,
        _ => 0,
      },
      reasons: switch (hour) {
        2 || 13 => const {'scheduled': 2, 'subscription': 1},
        7 || 20 => const {'manual': 1, 'subscription': 2},
        4 || 9 || 15 || 22 => const {'scheduled': 2},
        0 || 5 || 11 || 17 => const {'subscription': 1},
        _ => const {},
      },
    ),
];

final RitualSummaryMetrics _ritualMetrics = RitualSummaryMetrics(
  lifetimeWakeCount: 184,
  wakesSinceLastSession: 37,
  totalTokenUsageSinceLastSession: 128400,
  dailyWakeCounts: [
    for (var day = 11; day <= 17; day++)
      DailyWakeCountBucket(
        date: DateTime(2026, 7, day),
        wakeCount: 3 + (day % 5),
      ),
  ],
);

final EvolutionSessionEntity _templateReviewSession = makeTestEvolutionSession(
  id: 'evolution-habitat-v5',
  agentId: _habitatTemplateId,
  templateId: _habitatTemplateId,
  sessionNumber: 5,
  feedbackSummary: _t(
    'The sentinel caught the pressure anomaly, but its launch report '
        'buried the go/no-go decision beneath six paragraphs of fish trivia.',
    'Der Wächter erkannte die Druckanomalie, aber sein Startbericht vergrub '
        'die Start-oder-Stopp-Entscheidung unter sechs Absätzen Fischwissen.',
  ),
  createdAt: manualDemoNow.subtract(const Duration(minutes: 46)),
  updatedAt: manualDemoNow.subtract(const Duration(minutes: 12)),
);

final EvolutionSessionEntity _completedTemplateReview =
    makeTestEvolutionSession(
      id: 'evolution-habitat-v4',
      agentId: _habitatTemplateId,
      templateId: _habitatTemplateId,
      sessionNumber: 4,
      status: EvolutionSessionStatus.completed,
      feedbackSummary: _t(
        'Make seal evidence easier to scan.',
        'Belege zu Dichtungen leichter erfassbar machen.',
      ),
      userRating: 4.8,
      createdAt: manualDemoNow.subtract(const Duration(days: 8)),
      updatedAt: manualDemoNow.subtract(const Duration(days: 8)),
      completedAt: manualDemoNow.subtract(const Duration(days: 8)),
    );

final EvolutionSessionRecapEntity _completedTemplateRecap =
    makeTestEvolutionSessionRecap(
      id: 'recap-habitat-v4',
      agentId: _habitatTemplateId,
      sessionId: 'evolution-habitat-v4',
      tldr: _t(
        'Put seal anomalies first and make the final launch call explicit.',
        'Dichtungsanomalien zuerst nennen und die Startentscheidung klar '
            'aussprechen.',
      ),
      recapMarkdown: _t(
        '## Result\n\n- Evidence now leads each finding.\n'
            '- Reports end with a plain-language launch recommendation.',
        '## Ergebnis\n\n- Belege stehen jetzt vor jedem Befund.\n'
            '- Berichte enden mit einer klaren Startempfehlung.',
      ),
      approvedChangeSummary: _t(
        'Promoted pressure evidence and added an explicit go/no-go ending.',
        'Druckbelege vorangestellt und einen klaren Start-oder-Stopp-Abschluss '
            'ergänzt.',
      ),
      categoryRatings: {
        _t('language', 'Sprache'): 4,
      },
      createdAt: manualDemoNow.subtract(const Duration(days: 8)),
    );

Widget _app({
  required Widget home,
  required Brightness brightness,
  required ScreenshotDevice device,
  required List<Override> overrides,
}) {
  final baseTheme = brightness == Brightness.dark
      ? DesignSystemTheme.dark()
      : DesignSystemTheme.light();
  final theme = baseTheme.copyWith(
    textTheme: baseTheme.textTheme.apply(fontFamily: 'Inter'),
    primaryTextTheme: baseTheme.primaryTextTheme.apply(fontFamily: 'Inter'),
  );
  return RepaintBoundary(
    key: screenshotBoundaryKey,
    child: ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(size: device.size),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FormBuilderLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: manualScreenshotLocale,
          home: AppCommandHost(
            handlers: const <AppCommandId, AppCommandHandler>{},
            platform: device.isPhone
                ? TargetPlatform.android
                : TargetPlatform.linux,
            child: home,
          ),
        ),
      ),
    ),
  );
}

Widget _directPage(_AgentSurface surface) => switch (surface) {
  _AgentSurface.stats => const AgentSettingsPage(
    initialTab: AgentSettingsTab.stats,
  ),
  _AgentSurface.templates => const AgentSettingsPage(
    initialTab: AgentSettingsTab.templates,
  ),
  _AgentSurface.instances => const AgentSettingsPage(
    initialTab: AgentSettingsTab.instances,
  ),
  _AgentSurface.souls => const AgentSettingsPage(
    initialTab: AgentSettingsTab.souls,
  ),
  _AgentSurface.pendingWakes => const AgentSettingsPage(
    initialTab: AgentSettingsTab.pendingWakes,
  ),
  _AgentSurface.templateEditor => const AgentTemplateDetailPage(
    templateId: _habitatTemplateId,
  ),
  _AgentSurface.templateReview => const EvolutionReviewPage(
    templateId: _habitatTemplateId,
  ),
  _AgentSurface.soulEditor => const AgentSoulDetailPage(
    soulId: _pebbleSoulId,
  ),
  _AgentSurface.soulReview => const SoulEvolutionReviewPage(
    soulId: _pebbleSoulId,
  ),
  _AgentSurface.instanceDetail => const AgentDetailPage(
    agentId: _habitatAgentId,
  ),
};

bool _usesSettingsShell(_AgentSurface surface) => switch (surface) {
  _AgentSurface.stats ||
  _AgentSurface.templates ||
  _AgentSurface.instances ||
  _AgentSurface.souls ||
  _AgentSurface.pendingWakes ||
  _AgentSurface.templateEditor ||
  _AgentSurface.soulEditor ||
  _AgentSurface.instanceDetail => true,
  _AgentSurface.templateReview || _AgentSurface.soulReview => false,
};

Future<void> _selectDesktopSurface(
  WidgetTester tester, {
  required _AgentSurface surface,
  required ValueNotifier<DesktopSettingsRoute?> route,
}) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SettingsV2Page)),
    listen: false,
  );
  final tree = container.read(settingsTreePathProvider.notifier)
    ..syncFromUrl('/settings/agents');

  switch (surface) {
    case _AgentSurface.stats:
      tree.onNodeTap('agents/stats', depth: 1, hasChildren: false);
      route.value = (
        path: '/settings/agents/stats',
        pathParameters: const <String, String>{},
        queryParameters: const <String, String>{},
      );
    case _AgentSurface.templates:
      tree.onNodeTap('agents/templates', depth: 1, hasChildren: false);
      route.value = (
        path: '/settings/agents/templates',
        pathParameters: const <String, String>{},
        queryParameters: const <String, String>{},
      );
    case _AgentSurface.instances:
      tree.onNodeTap('agents/instances', depth: 1, hasChildren: false);
      route.value = (
        path: '/settings/agents/instances',
        pathParameters: const <String, String>{},
        queryParameters: const <String, String>{},
      );
    case _AgentSurface.souls:
      tree.onNodeTap('agents/souls', depth: 1, hasChildren: false);
      route.value = (
        path: '/settings/agents/souls',
        pathParameters: const <String, String>{},
        queryParameters: const <String, String>{},
      );
    case _AgentSurface.pendingWakes:
      tree.onNodeTap('agents/pending-wakes', depth: 1, hasChildren: false);
      route.value = (
        path: '/settings/agents/pending-wakes',
        pathParameters: const <String, String>{},
        queryParameters: const <String, String>{},
      );
    case _AgentSurface.templateEditor:
      tree.onNodeTap('agents/templates', depth: 1, hasChildren: false);
      route.value = (
        path: '/settings/agents/templates/$_habitatTemplateId',
        pathParameters: const {'templateId': _habitatTemplateId},
        queryParameters: const <String, String>{},
      );
    case _AgentSurface.soulEditor:
      tree.onNodeTap('agents/souls', depth: 1, hasChildren: false);
      route.value = (
        path: '/settings/agents/souls/$_pebbleSoulId',
        pathParameters: const {'soulId': _pebbleSoulId},
        queryParameters: const <String, String>{},
      );
    case _AgentSurface.instanceDetail:
      tree.onNodeTap('agents/instances', depth: 1, hasChildren: false);
      route.value = (
        path: '/settings/agents/instances/$_habitatAgentId',
        pathParameters: const {'agentId': _habitatAgentId},
        queryParameters: const <String, String>{},
      );
    case _AgentSurface.templateReview || _AgentSurface.soulReview:
      throw StateError('Review pages do not use the Settings V2 panel.');
  }
  await settleFrames(tester, 8);
}

Future<void> _withDevicePlatform(
  ScreenshotDevice device,
  Future<void> Function() body,
) => withTargetPlatform(
  device.isPhone ? TargetPlatform.android : TargetPlatform.linux,
  body,
);

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'Agents manual screenshot harness (opt-in)',
      () {},
      skip: 'Set LOTTI_SCREENSHOT_DIR to capture manual screenshots.',
    );
    return;
  }

  setUpAll(() async {
    registerAllFallbackValues();
    await loadScreenshotFonts();
  });

  late MockNavService navService;
  late MockAgentTemplateService templateService;
  late MockSoulDocumentService soulService;
  late TestGetItMocks mocks;
  late ValueNotifier<DesktopSettingsRoute?> desktopRoute;
  late bool desktopMode;

  setUp(() async {
    navService = MockNavService();
    templateService = MockAgentTemplateService();
    soulService = MockSoulDocumentService();
    desktopRoute = ValueNotifier<DesktopSettingsRoute?>(null);
    desktopMode = false;

    when(() => navService.desktopSelectedSettingsRoute).thenReturn(
      desktopRoute,
    );
    when(() => navService.isDesktopMode).thenAnswer((_) => desktopMode);
    when(() => navService.currentPath).thenReturn('/settings/agents');
    when(() => navService.beamToNamed(any())).thenReturn(null);
    when(() => navService.beamBack()).thenReturn(null);
    when(
      () => templateService.getAgentsForTemplate(any()),
    ).thenAnswer((_) async => _agents);

    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NavService>(navService);
      },
    );
    when(() => mocks.journalDb.watchConfigFlag(any())).thenAnswer(
      (_) => Stream.value(false),
    );
    when(() => mocks.settingsDb.itemByKey(any())).thenAnswer(
      (_) async => '2',
    );
  });

  tearDown(() async {
    desktopRoute.dispose();
    await tearDownTestGetIt();
  });

  List<Override> overrides() {
    final completedHistory = RitualSessionHistoryEntry(
      session: _completedTemplateReview,
      recap: _completedTemplateRecap,
    );
    final resolvedProfile = ResolvedProfile(
      thinkingModelId: 'meta-llama/llama-3.3-70b-instruct',
      thinkingProvider: manualDemoAiProviders.first,
      thinkingModel: manualDemoAiModels.first,
    );

    return [
      journalDbProvider.overrideWithValue(mocks.journalDb),
      agentTemplateServiceProvider.overrideWithValue(templateService),
      soulDocumentServiceProvider.overrideWithValue(soulService),
      agentTemplatesProvider.overrideWith((ref) async => _templates),
      agentTemplateProvider.overrideWith(
        (ref, id) async =>
            _templates.where((item) => item.id == id).firstOrNull,
      ),
      activeTemplateVersionProvider.overrideWith(
        (ref, id) async => _templateVersions[id],
      ),
      templateVersionHistoryProvider.overrideWith(
        (ref, id) async => [?_templateVersions[id]],
      ),
      templatesPendingReviewProvider.overrideWith(
        (ref) async => const {_habitatTemplateId, _diplomacyTemplateId},
      ),
      allSoulDocumentsProvider.overrideWith((ref) async => _souls),
      soulDocumentProvider.overrideWith(
        (ref, id) async => _souls.where((item) => item.id == id).firstOrNull,
      ),
      activeSoulVersionProvider.overrideWith(
        (ref, id) async => _soulVersions[id],
      ),
      soulVersionHistoryProvider.overrideWith(
        (ref, id) async => [?_soulVersions[id]],
      ),
      soulForTemplateProvider.overrideWith((ref, templateId) async {
        final soulId = switch (templateId) {
          _habitatTemplateId => _pebbleSoulId,
          _dayPlannerTemplateId => _flipperSoulId,
          _cargoTemplateId => _sardinaSoulId,
          _ => null,
        };
        return soulId == null ? null : _soulVersions[soulId];
      }),
      templatesUsingSoulProvider.overrideWith((ref, soulId) async {
        return switch (soulId) {
          _pebbleSoulId => [_habitatTemplateId],
          _flipperSoulId => [_dayPlannerTemplateId],
          _sardinaSoulId => [_cargoTemplateId],
          _ => <String>[],
        };
      }),
      allAgentInstancesProvider.overrideWith((ref) async => _agents),
      allEvolutionSessionsProvider.overrideWith(
        (ref) async => [_templateReviewSession, _completedTemplateReview],
      ),
      agentInstanceVmsProvider.overrideWith((ref) async => _instanceVms),
      agentIdentityProvider.overrideWith(
        (ref, id) async => _agents.where((item) => item.id == id).firstOrNull,
      ),
      agentStateProvider.overrideWith(
        (ref, id) async => _agentStates[id],
      ),
      agentIsRunningProvider.overrideWith(
        (ref, id) => Stream.value(id == _habitatAgentId),
      ),
      templateForAgentProvider.overrideWith((ref, id) async {
        return switch (id) {
          _habitatAgentId => _templates[0],
          _dayPlannerAgentId => _templates[1],
          _cargoAgentId => _templates[2],
          _ => null,
        };
      }),
      agentTokenUsageSummariesProvider.overrideWith(
        (ref, id) async => [
          AgentTokenUsageSummary(
            modelId: _t('Waddle Command 70B', 'Watschelkommando 70B'),
            inputTokens: 82400,
            outputTokens: 21600,
            thoughtsTokens: 12300,
            cachedInputTokens: 31700,
            wakeCount: 42,
          ),
          AgentTokenUsageSummary(
            modelId: _t(
              'Emperor Reasoning XL',
              'Kaiserpinguin-Denken XL',
            ),
            inputTokens: 18900,
            outputTokens: 7400,
            thoughtsTokens: 9100,
            cachedInputTokens: 3200,
            wakeCount: 6,
          ),
        ],
      ),
      agentResolvedSetupProvider.overrideWith(
        (ref, id) async => ResolvedAgentSetup(
          status: AgentSetupResolutionStatus.resolved,
          profile: resolvedProfile,
          source: AgentSetupResolutionSource.baseProfile,
        ),
      ),
      agentMessagesByThreadProvider.overrideWith(
        (ref, id) async => const <String, List<AgentDomainEntity>>{},
      ),
      agentRecentMessagesProvider.overrideWith(
        (ref, id) async => <AgentDomainEntity>[],
      ),
      agentObservationMessagesProvider.overrideWith(
        (ref, id) async => <AgentDomainEntity>[],
      ),
      agentReportHistoryProvider.overrideWith(
        (ref, id) async => <AgentDomainEntity>[],
      ),
      pendingWakeRecordsProvider.overrideWith((ref) async => _pendingWakes),
      ongoingWakeRecordsProvider.overrideWith(
        (ref) async => [
          OngoingWakeRecord(
            agentId: _habitatAgentId,
            title: _t(
              'Inspect orbital penguin habitat',
              'Pinguin-Habitat im Orbit inspizieren',
            ),
            subjectId: manualOrbitalHabitatTaskId,
            subjectRoute: '/tasks/$manualOrbitalHabitatTaskId',
            startedAt: manualDemoNow.subtract(const Duration(minutes: 7)),
          ),
        ],
      ),
      pendingWakeTargetTitleProvider.overrideWith((ref, entryId) async {
        return switch (entryId) {
          manualOrbitalHabitatTaskId => _t(
            'Inspect orbital penguin habitat',
            'Pinguin-Habitat im Orbit inspizieren',
          ),
          'project-waddle' => 'Project Waddle',
          _ => null,
        };
      }),
      wakeCountdownTickerProvider.overrideWith(
        (ref) => Stream.value(manualDemoNow),
      ),
      hourlyWakeActivityProvider.overrideWith((ref) async => _hourlyActivity),
      dailyTokenUsageProvider.overrideWith((ref, days) async => _dailyUsage),
      tokenUsageComparisonProvider.overrideWith(
        (ref, days) async => const TokenUsageComparison(
          averageTokensByTimeOfDay: 14800,
          todayTokens: 26000,
        ),
      ),
      dailyTokenUsageByModelProvider.overrideWith(
        (ref, days) async => {
          _t('Waddle Command 70B', 'Watschelkommando 70B'): _dailyUsage,
          _t('Emperor Reasoning XL', 'Kaiserpinguin-Denken XL'): [
            for (final item in _dailyUsage)
              DailyTokenUsage(
                date: item.date,
                totalTokens: item.totalTokens ~/ 3,
                tokensByTimeOfDay: item.tokensByTimeOfDay ~/ 3,
                isToday: item.isToday,
                wakeCount: item.wakeCount ~/ 2,
              ),
          ],
        },
      ),
      tokenSourceBreakdownProvider.overrideWith(
        (ref) async => [
          TokenSourceBreakdown(
            templateId: _habitatTemplateId,
            displayName: _t(
              'Orbital Habitat Sentinel',
              'Wächter des Orbital-Habitats',
            ),
            totalTokens: 14300,
            percentage: 55,
            wakeCount: 7,
            totalDuration: const Duration(minutes: 38),
            isHighUsage: false,
          ),
          TokenSourceBreakdown(
            templateId: _dayPlannerTemplateId,
            displayName: _t(
              'Project Waddle Day Planner',
              'Project-Waddle-Tagesplaner',
            ),
            totalTokens: 7800,
            percentage: 30,
            wakeCount: 4,
            totalDuration: const Duration(minutes: 21),
            isHighUsage: false,
          ),
          TokenSourceBreakdown(
            templateId: _cargoTemplateId,
            displayName: _t(
              'Sardine Supply Watch',
              'Sardinen-Vorratswache',
            ),
            totalTokens: 3900,
            percentage: 15,
            wakeCount: 3,
            totalDuration: const Duration(minutes: 12),
            isHighUsage: false,
          ),
        ],
      ),
      templateTokenUsageSummariesProvider.overrideWith(
        (ref, id) async => const <AgentTokenUsageSummary>[],
      ),
      templateInstanceTokenBreakdownProvider.overrideWith(
        (ref, id) async => const <InstanceTokenBreakdown>[],
      ),
      templateRecentReportsProvider.overrideWith(
        (ref, id) async => <AgentDomainEntity>[],
      ),
      evolutionSessionsProvider.overrideWith(
        (ref, id) async => <AgentDomainEntity>[],
      ),
      evolutionSessionStatsProvider.overrideWith(
        (ref, id) async => const EvolutionSessionStats(
          totalSessions: 4,
          approvalRate: 0.75,
        ),
      ),
      templateWakeRunTimeSeriesProvider.overrideWith(
        (ref, id) async => const WakeRunTimeSeries(
          dailyBuckets: [],
          versionBuckets: [],
        ),
      ),
      templateTaskResolutionTimeSeriesProvider.overrideWith(
        (ref, id) async => const TaskResolutionTimeSeries(dailyBuckets: []),
      ),
      pendingRitualReviewProvider.overrideWith(
        (ref, id) async => _templateReviewSession,
      ),
      ritualSummaryMetricsProvider.overrideWith(
        (ref, id) async => _ritualMetrics,
      ),
      ritualSessionHistoryProvider.overrideWith(
        (ref, id) async => [completedHistory],
      ),
      pendingSoulEvolutionProvider.overrideWith(
        (ref, id) async => makeTestEvolutionSession(
          id: 'evolution-soul-pebble-v6',
          agentId: _pebbleSoulId,
          templateId: _habitatTemplateId,
          sessionNumber: 6,
          feedbackSummary: _t(
            'Admiral Pebble is appropriately skeptical, but should ask fewer '
                'questions when a launch hold is already obvious.',
            'Admiral Kiesel ist angemessen skeptisch, sollte aber weniger '
                'Fragen stellen, wenn ein Startstopp bereits offensichtlich ist.',
          ),
          createdAt: manualDemoNow.subtract(const Duration(minutes: 33)),
          updatedAt: manualDemoNow.subtract(const Duration(minutes: 9)),
        ),
      ),
      soulEvolutionSessionHistoryProvider.overrideWith(
        (ref, id) async => [completedHistory],
      ),
      inferenceProfileControllerProvider.overrideWithBuild(
        (ref, notifier) => Stream.value(manualDemoAiProfiles),
      ),
      maybeUpdateNotificationsProvider.overrideWith((ref) => null),
    ];
  }

  Future<void> pumpSurface(
    WidgetTester tester, {
    required _AgentSurface surface,
    required ScreenshotDevice device,
    required Brightness brightness,
  }) async {
    desktopMode = !device.isPhone;
    applyScreenshotDevice(tester, device);
    final useShell = !device.isPhone && _usesSettingsShell(surface);
    await tester.pumpWidget(
      _app(
        home: useShell
            ? SettingsV2Page(beamToReplacementNamed: (_, _) {})
            : _directPage(surface),
        brightness: brightness,
        device: device,
        overrides: overrides(),
      ),
    );
    await settleFrames(tester, 8);
    if (useShell) {
      await _selectDesktopSurface(
        tester,
        surface: surface,
        route: desktopRoute,
      );
    }
  }

  for (final device in [proMaxDevice, desktopDevice]) {
    final viewport = device.isPhone ? 'mobile' : 'desktop';
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;

      testWidgets('$viewport agent statistics — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          await withClock(Clock.fixed(manualDemoNow), () async {
            await pumpSurface(
              tester,
              surface: _AgentSurface.stats,
              device: device,
              brightness: brightness,
            );
            final messages = _messages(tester);
            expect(
              find.text(messages.agentStatsUsageAboveAverage('10:30')),
              findsOneWidget,
            );
            expect(find.text('26K'), findsWidgets);
            await captureScreenshot(
              tester,
              'agents_stats_${viewport}_$theme',
              subdir: _subdir,
            );
          });
        });
      });

      testWidgets('$viewport agent templates — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          await pumpSurface(
            tester,
            surface: _AgentSurface.templates,
            device: device,
            brightness: brightness,
          );
          await captureScreenshot(
            tester,
            'agents_templates_${viewport}_$theme',
            subdir: _subdir,
          );
          expect(
            find.textContaining(
              _t(
                'Orbital Habitat Sentinel',
                'Wächter des Orbital-Habitats',
              ),
              findRichText: true,
            ),
            findsAtLeastNWidgets(1),
          );
          expect(
            find.textContaining(
              _t(
                'Project Waddle Day Planner',
                'Project-Waddle-Tagesplaner',
              ),
              findRichText: true,
            ),
            findsAtLeastNWidgets(1),
          );
          expect(
            find.textContaining(
              _t('Sardine Supply Watch', 'Sardinen-Vorratswache'),
              findRichText: true,
            ),
            findsAtLeastNWidgets(1),
          );
          expect(
            find.textContaining(
              _t('Fish Diplomacy Coach', 'Fischdiplomatie-Coach'),
              findRichText: true,
            ),
            findsAtLeastNWidgets(1),
          );
        });
      });

      testWidgets('$viewport agent instances — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          await pumpSurface(
            tester,
            surface: _AgentSurface.instances,
            device: device,
            brightness: brightness,
          );
          await captureScreenshot(
            tester,
            'agents_instances_${viewport}_$theme',
            subdir: _subdir,
          );
          expect(
            find.textContaining(
              _t(
                'Habitat Seal Inspector',
                'Habitatdichtungs-Inspektor',
              ),
              findRichText: true,
            ),
            findsAtLeastNWidgets(1),
          );
          expect(
            find.textContaining(
              _t('Project Waddle Planner', 'Project-Waddle-Planer'),
              findRichText: true,
            ),
            findsAtLeastNWidgets(1),
          );
          expect(
            find.textContaining(
              _t(
                'Sardine Cargo Coordinator',
                'Sardinenfracht-Koordinator',
              ),
              findRichText: true,
            ),
            findsAtLeastNWidgets(1),
          );
        });
      });

      testWidgets('$viewport agent souls — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          await pumpSurface(
            tester,
            surface: _AgentSurface.souls,
            device: device,
            brightness: brightness,
          );
          expect(
            find.text(_t('Admiral Pebble', 'Admiral Kiesel')),
            findsOneWidget,
          );
          expect(find.text(_t('Dr. Flipper', 'Dr. Flosse')), findsOneWidget);
          expect(
            find.text(_t('Captain Sardina', 'Kapitän Sardina')),
            findsOneWidget,
          );
          await captureScreenshot(
            tester,
            'agents_souls_${viewport}_$theme',
            subdir: _subdir,
          );
        });
      });

      testWidgets('$viewport pending agent wakes — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          await withClock(Clock.fixed(manualDemoNow), () async {
            await pumpSurface(
              tester,
              surface: _AgentSurface.pendingWakes,
              device: device,
              brightness: brightness,
            );
            expect(
              find.textContaining(
                _t(
                  'Inspect orbital penguin habitat',
                  'Pinguin-Habitat im Orbit inspizieren',
                ),
                findRichText: true,
              ),
              findsAtLeastNWidgets(1),
            );
            expect(
              find.textContaining(
                _t('Project Waddle launch day', 'Project-Waddle-Starttag'),
                findRichText: true,
              ),
              findsAtLeastNWidgets(1),
            );
            await captureScreenshot(
              tester,
              'agents_pending_wakes_${viewport}_$theme',
              subdir: _subdir,
            );
          });
        });
      });

      testWidgets('$viewport agent template editor — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          await pumpSurface(
            tester,
            surface: _AgentSurface.templateEditor,
            device: device,
            brightness: brightness,
          );
          expect(
            find.text(
              _t(
                'Orbital Habitat Sentinel',
                'Wächter des Orbital-Habitats',
              ),
            ),
            findsWidgets,
          );
          expect(
            find.text(
              _t('Project Waddle Command', 'Project-Waddle-Kommando'),
            ),
            findsWidgets,
          );
          expect(
            find.text(_t('Admiral Pebble', 'Admiral Kiesel')),
            findsWidgets,
          );
          await captureScreenshot(
            tester,
            'agents_template_editor_${viewport}_$theme',
            subdir: _subdir,
          );
        });
      });

      testWidgets('$viewport agent template ritual — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          await pumpSurface(
            tester,
            surface: _AgentSurface.templateReview,
            device: device,
            brightness: brightness,
          );
          expect(
            find.text(
              _t(
                'Orbital Habitat Sentinel',
                'Wächter des Orbital-Habitats',
              ),
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              _t(
                'The sentinel caught the pressure anomaly, but its launch '
                    'report buried the go/no-go decision beneath six '
                    'paragraphs of fish trivia.',
                'Der Wächter erkannte die Druckanomalie, aber sein '
                    'Startbericht vergrub die Start-oder-Stopp-Entscheidung '
                    'unter sechs Absätzen Fischwissen.',
              ),
            ),
            findsOneWidget,
          );
          await captureScreenshot(
            tester,
            'agents_template_review_${viewport}_$theme',
            subdir: _subdir,
          );
        });
      });

      testWidgets('$viewport agent soul editor — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          await pumpSurface(
            tester,
            surface: _AgentSurface.soulEditor,
            device: device,
            brightness: brightness,
          );
          expect(
            find.text(_t('Admiral Pebble', 'Admiral Kiesel')),
            findsWidgets,
          );
          expect(
            find.textContaining(
              _t(
                'Speak like a calm flight director who respects both evidence '
                    'and penguins. Put the operational decision first.',
                'Sprich wie ein ruhiger Flugleiter, der Belege und Pinguine '
                    'respektiert. Stelle die betriebliche Entscheidung an den '
                    'Anfang.',
              ),
            ),
            findsOneWidget,
          );
          await captureScreenshot(
            tester,
            'agents_soul_editor_${viewport}_$theme',
            subdir: _subdir,
          );
        });
      });

      testWidgets('$viewport agent soul ritual — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          await pumpSurface(
            tester,
            surface: _AgentSurface.soulReview,
            device: device,
            brightness: brightness,
          );
          expect(
            find.text(_t('Admiral Pebble', 'Admiral Kiesel')),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              _t(
                'Admiral Pebble is appropriately skeptical, but should ask '
                    'fewer questions when a launch hold is already obvious.',
                'Admiral Kiesel ist angemessen skeptisch, sollte aber weniger '
                    'Fragen stellen, wenn ein Startstopp bereits offensichtlich ist.',
              ),
            ),
            findsOneWidget,
          );
          await captureScreenshot(
            tester,
            'agents_soul_review_${viewport}_$theme',
            subdir: _subdir,
          );
        });
      });

      testWidgets('$viewport agent instance detail — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          await withClock(Clock.fixed(manualDemoNow), () async {
            await pumpSurface(
              tester,
              surface: _AgentSurface.instanceDetail,
              device: device,
              brightness: brightness,
            );
            expect(
              find.text(
                _t(
                  'Habitat Seal Inspector',
                  'Habitatdichtungs-Inspektor',
                ),
              ),
              findsOneWidget,
            );
            expect(
              find.text(
                _t(
                  'Orbital Habitat Sentinel',
                  'Wächter des Orbital-Habitats',
                ),
              ),
              findsOneWidget,
            );
            expect(
              find.textContaining(
                _t('Waddle Command', 'Watschelkommando'),
              ),
              findsWidgets,
            );
            await captureScreenshot(
              tester,
              'agents_instance_detail_${viewport}_$theme',
              subdir: _subdir,
            );
          });
        });
      });
    }
  }
}

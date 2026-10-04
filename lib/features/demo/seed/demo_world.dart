import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/media/demo_media_hydrator.dart';
import 'package:lotti/features/demo/seed/demo_dates.dart';
import 'package:lotti/features/demo/seed/demo_entity_factories.dart';
import 'package:lotti/features/demo/seed/demo_ids.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:path/path.dart' as p;

part 'demo_world_sections_part.dart';
part 'demo_world_tasks_part.dart';

/// Fixed clock shared by the manual screenshot fixtures — the anchor every
/// date in [ManualDemoWorld.penguinLogistics] is expressed against.
final manualDemoNow = DateTime(2026, 7, 17, 10, 30);

const manualDemoCategoryId = 'manual-penguin-ops';
const manualDemoProjectLabelId = 'manual-project-waddle';
const manualDemoCriticalLabelId = 'manual-habitat-critical';

const manualMissionControlProviderId = 'provider-mission-control-router';
const manualHabitatLabProviderId = 'provider-habitat-local-lab';
const manualOrbitalVisionProviderId = 'provider-orbital-vision';
const manualAudioBayProviderId = 'provider-penguin-audio-bay';

const manualWaddleCommandModelId = 'model-waddle-command-70b';
const manualEmperorReasoningModelId = 'model-emperor-reasoning-xl';
const manualSardineLogisticsModelId = 'model-sardine-logistics-14b';
const manualHabitatVisionModelId = 'model-habitat-vision-pro';
const manualPenguinBriefingsModelId = 'model-penguin-briefings';
const manualCoverArtistModelId = 'model-project-waddle-cover-artist';

const manualProjectWaddleProfileId = 'profile-project-waddle-command';
const manualHabitatLocalProfileId = 'profile-habitat-local-first';
const manualFishDiplomacyProfileId = 'profile-fish-diplomacy';

const manualHabitatBriefingSkillId = 'skill-habitat-briefing';
const manualHabitatPhotoSkillId = 'skill-habitat-photo';
const manualWaddleCoverArtSkillId = 'skill-waddle-cover-art';
const manualLaunchPromptSkillId = 'skill-launch-prompt';

final String manualOrbitalHabitatTaskId = demoUuid('task-orbital-habitat');
final String manualHabitatChecklistId = demoUuid('manual-habitat-checklist');
final String manualHabitatSealsItemId = demoUuid('manual-habitat-item-seals');
final String manualHabitatRollCallItemId = demoUuid(
  'manual-habitat-item-roll-call',
);
final String manualHabitatCargoItemId = demoUuid('manual-habitat-item-cargo');
final String manualHabitatClearanceItemId = demoUuid(
  'manual-habitat-item-clearance',
);
final String manualHabitatTimeRecordId = demoUuid('manual-habitat-time-record');
final String manualRollCallTaskId = demoUuid('task-emperor-penguin-roll-call');
final String manualLaunchReviewTaskId = demoUuid(
  'task-project-waddle-launch-review',
);
final String manualLunchTaskId = demoUuid('task-coffee-is-not-a-vegetable');
final String manualSardineFuturesTaskId = demoUuid(
  'task-negotiate-sardine-futures',
);
final String manualFishFeederTaskId = demoUuid('task-zero-gravity-feeder');
final String manualSardineCargoTaskId = demoUuid('task-sardine-cargo');
final String manualPenguinPassengerTaskId = demoUuid('task-penguin-passenger');
final String manualHeadsetWalkTaskId = demoUuid('task-walk-without-headset');
final String manualHabitatCoverImageId = demoUuid(
  'manual-penguin-habitat-cover',
);
final String manualRollCallCoverImageId = demoUuid(
  'manual-penguin-roll-call-cover',
);
final String manualLaunchReviewCoverImageId = demoUuid(
  'manual-penguin-launch-review-cover',
);
final String manualLunchCoverImageId = demoUuid('manual-penguin-lunch-cover');
final String manualSardineFuturesCoverImageId = demoUuid(
  'manual-penguin-sardine-futures-cover',
);
final String manualFishFeederCoverImageId = demoUuid(
  'manual-penguin-feeder-cover',
);
final String manualSardineCargoCoverImageId = demoUuid(
  'manual-penguin-cargo-cover',
);
final String manualPenguinPassengerCoverImageId = demoUuid(
  'manual-penguin-legal-cover',
);
final String manualHeadsetWalkCoverImageId = demoUuid(
  'manual-penguin-headset-walk-cover',
);

// ---------------------------------------------------------------------------
// Expansion: the walkable world.
//
// Everything below is ADDITIVE. Eight manual pages quote the nine original
// task names as literal text and the screenshot suites reference them by id,
// so ids, names and list order above never change — the world only grows.
// ---------------------------------------------------------------------------

/// Habitat engineering: the pressure/air/water/power side of the colony.
const demoHabitatCategoryId = 'manual-habitat-engineering';

/// Habit definition ids. Plain slugs rather than [demoUuid] values, like the
/// category and label ids beside them: habits are reached through
/// `/settings/habits/by_id/:habitId`, and settings routes carry no `isUuid`
/// gate. Only journal entities — including the completions below — need a
/// real UUID.
/// Days of habit completion history seeded before today. Comfortably beyond
/// the habits page's own 14-day window so the chart is full at either edge.
const _habitHistoryDays = 28;

const manualRollCallHabitId = 'habit-emperor-roll-call';
const manualHabitatSealsHabitId = 'habit-habitat-seals';
const manualSardineForecastHabitId = 'habit-sardine-forecast';
const demoColdChainTelemetryHabitId = 'habit-cold-chain-telemetry';
const demoOutboundManifestHabitId = 'habit-outbound-manifest';
const demoShiftHandoffHabitId = 'habit-shift-handoff';
const demoFlipperMobilityHabitId = 'habit-flipper-mobility';

/// Logistics & supply: everything that moves fish and parts between moons.
const demoLogisticsCategoryId = 'manual-logistics-supply';

const demoBlockedLabelId = 'manual-label-blocked';
const demoWaitingLabelId = 'manual-label-waiting-on';
const demoResearchLabelId = 'manual-label-research';

// Cluster 1 — launch readiness, orbiting the launch review.
final String demoLaunchCommsTaskId = demoUuid('task-launch-comms-plan');
final String demoIcePadWeatherTaskId = demoUuid('task-ice-pad-weather');
final String demoColdChainAuditTaskId = demoUuid('task-cold-chain-audit');
final String demoLaunchRehearsalTaskId = demoUuid('task-launch-rehearsal');
final String demoFlightSuitTaskId = demoUuid('task-flight-suit-fitting');

// Cluster 2 — habitat engineering, orbiting the habitat inspection.
final String demoAirScrubbersTaskId = demoUuid('task-air-scrubbers');
final String demoHumiditySpikeTaskId = demoUuid('task-humidity-spike');
final String demoIceRinkTaskId = demoUuid('task-ice-rink-resurface');
final String demoSolarArrayTaskId = demoUuid('task-solar-array-tilt');
final String demoWaterRecyclerTaskId = demoUuid('task-water-recycler');

// Cluster 3 — logistics & supply, orbiting the sardine cargo pods.
final String demoSquidPalletTaskId = demoUuid('task-squid-pallet');
final String demoKrillSupplierTaskId = demoUuid('task-krill-supplier');
final String demoShuttleManifestTaskId = demoUuid('task-shuttle-manifest');
final String demoPodSealOrderTaskId = demoUuid('task-pod-seal-order');
final String demoCustomsEuropaTaskId = demoUuid('task-customs-europa');

// Cluster 4 — colony life, orbiting the roll call.
final String demoColonyNewsletterTaskId = demoUuid('task-colony-newsletter');
final String demoChickDaycareTaskId = demoUuid('task-chick-daycare');
final String demoMovieNightTaskId = demoUuid('task-movie-night');
final String demoTobogganingTaskId = demoUuid('task-tobogganing-league');

final String demoRehearsalChecklistId = demoUuid('manual-rehearsal-checklist');
final String demoScrubberChecklistId = demoUuid('manual-scrubber-checklist');
final String demoPalletChecklistId = demoUuid('manual-pallet-checklist');
final String demoNewsletterChecklistId = demoUuid(
  'manual-newsletter-checklist',
);
final String demoFreezerChecklistId = demoUuid('manual-freezer-checklist');
final String demoManifestChecklistId = demoUuid('manual-manifest-checklist');

/// Id of the link that attaches the habitat time record to the hero task.
final String demoHabitatTimeLinkId = demoUuid('manual-habitat-time-link');

/// Task-to-task links: four clusters around their hubs, plus the deliberate
/// cross-cluster bridges that turn four stars into one web.
///
/// The knowledge graph walks `linked_entries` bidirectionally to depth two, so
/// this table is what decides whether the explorer has anywhere to go. Every
/// task appears at least twice; the four hubs (habitat inspection, launch
/// review, sardine cargo, roll call) carry six or more.
final List<(String, String)> _demoTaskPairs = <(String, String)>[
  // Cluster 1 — launch readiness.
  (manualLaunchReviewTaskId, demoLaunchCommsTaskId),
  (manualLaunchReviewTaskId, demoIcePadWeatherTaskId),
  (manualLaunchReviewTaskId, demoColdChainAuditTaskId),
  (manualLaunchReviewTaskId, demoLaunchRehearsalTaskId),
  (manualLaunchReviewTaskId, demoFlightSuitTaskId),
  (manualLaunchReviewTaskId, manualOrbitalHabitatTaskId),
  (manualLaunchReviewTaskId, manualSardineFuturesTaskId),
  (manualLaunchReviewTaskId, manualPenguinPassengerTaskId),
  (demoLaunchRehearsalTaskId, manualOrbitalHabitatTaskId),
  (demoIcePadWeatherTaskId, demoLaunchRehearsalTaskId),
  (demoFlightSuitTaskId, demoLaunchRehearsalTaskId),
  (demoColdChainAuditTaskId, manualSardineFuturesTaskId),
  (demoColdChainAuditTaskId, manualSardineCargoTaskId),
  (demoLaunchCommsTaskId, demoColonyNewsletterTaskId),
  // Cluster 2 — habitat engineering.
  (manualOrbitalHabitatTaskId, demoAirScrubbersTaskId),
  (manualOrbitalHabitatTaskId, demoHumiditySpikeTaskId),
  (manualOrbitalHabitatTaskId, demoIceRinkTaskId),
  (manualOrbitalHabitatTaskId, demoSolarArrayTaskId),
  (manualOrbitalHabitatTaskId, demoWaterRecyclerTaskId),
  (manualOrbitalHabitatTaskId, manualFishFeederTaskId),
  (manualOrbitalHabitatTaskId, manualSardineCargoTaskId),
  (manualOrbitalHabitatTaskId, manualRollCallTaskId),
  (demoAirScrubbersTaskId, demoHumiditySpikeTaskId),
  (demoHumiditySpikeTaskId, demoWaterRecyclerTaskId),
  (demoSolarArrayTaskId, demoWaterRecyclerTaskId),
  (demoIceRinkTaskId, manualHeadsetWalkTaskId),
  (demoAirScrubbersTaskId, demoPodSealOrderTaskId),
  // Cluster 3 — logistics & supply.
  (manualSardineCargoTaskId, demoSquidPalletTaskId),
  (manualSardineCargoTaskId, demoKrillSupplierTaskId),
  (manualSardineCargoTaskId, demoShuttleManifestTaskId),
  (manualSardineCargoTaskId, demoPodSealOrderTaskId),
  (manualSardineCargoTaskId, demoCustomsEuropaTaskId),
  (demoSquidPalletTaskId, demoShuttleManifestTaskId),
  (demoShuttleManifestTaskId, demoCustomsEuropaTaskId),
  (demoKrillSupplierTaskId, manualSardineFuturesTaskId),
  (demoKrillSupplierTaskId, demoColdChainAuditTaskId),
  (demoCustomsEuropaTaskId, manualPenguinPassengerTaskId),
  (demoPodSealOrderTaskId, manualFishFeederTaskId),
  (demoSquidPalletTaskId, manualSardineFuturesTaskId),
  // Cluster 4 — colony life.
  (manualRollCallTaskId, demoColonyNewsletterTaskId),
  (manualRollCallTaskId, demoChickDaycareTaskId),
  (manualRollCallTaskId, demoMovieNightTaskId),
  (manualRollCallTaskId, demoTobogganingTaskId),
  (manualRollCallTaskId, manualLaunchReviewTaskId),
  (demoColonyNewsletterTaskId, demoMovieNightTaskId),
  (demoChickDaycareTaskId, demoTobogganingTaskId),
  (demoMovieNightTaskId, manualLunchTaskId),
  (demoTobogganingTaskId, manualHeadsetWalkTaskId),
  (demoChickDaycareTaskId, demoIceRinkTaskId),
  // Connective tissue among the original nine, so none of them is a leaf.
  (manualLunchTaskId, manualHeadsetWalkTaskId),
  (manualFishFeederTaskId, manualSardineFuturesTaskId),
];

/// Task-to-entry links: notes, logged time and cover photos hanging off the
/// tasks they belong to. Several notes deliberately bridge two tasks — that is
/// what makes an observation findable from either side in the graph.
final List<(String, String)> _demoEntryPairs = <(String, String)>[
  // Observations.
  (manualOrbitalHabitatTaskId, demoUuid('note-seal-pressure')),
  (demoAirScrubbersTaskId, demoUuid('note-scrubber-order')),
  (demoPodSealOrderTaskId, demoUuid('note-scrubber-order')),
  (demoHumiditySpikeTaskId, demoUuid('note-humidity-reading')),
  (manualFishFeederTaskId, demoUuid('note-feeder-trajectory')),
  (demoSquidPalletTaskId, demoUuid('note-pallet-search')),
  (manualSardineCargoTaskId, demoUuid('note-pallet-search')),
  (demoKrillSupplierTaskId, demoUuid('note-krill-quote')),
  (manualSardineFuturesTaskId, demoUuid('note-krill-quote')),
  (demoCustomsEuropaTaskId, demoUuid('note-customs-form')),
  (demoPodSealOrderTaskId, demoUuid('note-customs-form')),
  (demoIcePadWeatherTaskId, demoUuid('note-weather-window')),
  (demoLaunchRehearsalTaskId, demoUuid('note-weather-window')),
  (demoLaunchRehearsalTaskId, demoUuid('note-rehearsal-gap')),
  (demoFlightSuitTaskId, demoUuid('note-suit-sizes')),
  (demoColonyNewsletterTaskId, demoUuid('note-newsletter-draft')),
  (demoChickDaycareTaskId, demoUuid('note-daycare-rota')),
  (demoMovieNightTaskId, demoUuid('note-movie-vote')),
  (demoTobogganingTaskId, demoUuid('note-toboggan-injury')),
  (manualHeadsetWalkTaskId, demoUuid('note-toboggan-injury')),
  (demoIceRinkTaskId, demoUuid('note-toboggan-injury')),
  (demoSolarArrayTaskId, demoUuid('note-solar-tilt')),
  (demoWaterRecyclerTaskId, demoUuid('note-recycler-filter')),
  (demoColdChainAuditTaskId, demoUuid('note-freezer-log')),
  (manualSardineCargoTaskId, demoUuid('note-freezer-log')),
  (demoShuttleManifestTaskId, demoUuid('note-manifest-mismatch')),
  (manualSardineCargoTaskId, demoUuid('note-manifest-mismatch')),
  (demoLaunchCommsTaskId, demoUuid('note-comms-tone')),
  (manualLaunchReviewTaskId, demoUuid('note-comms-tone')),
  (manualRollCallTaskId, demoUuid('note-roll-call-late')),
  (manualOrbitalHabitatTaskId, demoUuid('note-roll-call-late')),
  (manualPenguinPassengerTaskId, demoUuid('note-customs-form')),
  (manualLunchTaskId, demoUuid('note-lunch-wellness')),
  // Logged work.
  (demoAirScrubbersTaskId, demoUuid('time-scrubber-swap')),
  (demoHumiditySpikeTaskId, demoUuid('time-humidity-hunt')),
  (demoSquidPalletTaskId, demoUuid('time-pallet-walk')),
  (demoLaunchRehearsalTaskId, demoUuid('time-rehearsal-run')),
  (demoColdChainAuditTaskId, demoUuid('time-freezer-audit')),
  (demoColonyNewsletterTaskId, demoUuid('time-newsletter-draft')),
  (demoSolarArrayTaskId, demoUuid('time-solar-measure')),
  (demoWaterRecyclerTaskId, demoUuid('time-recycler-clean')),
  (demoShuttleManifestTaskId, demoUuid('time-manifest-count')),
  (demoLaunchCommsTaskId, demoUuid('time-comms-rewrite')),
];

/// One deterministic, production-shaped data set reused across manual pages
/// AND as the production demo-world seed.
///
/// Keeping tasks, categories, labels, and cover images here prevents the task
/// list, task detail, and Daily OS agenda screenshots from drifting into
/// unrelated demo universes — and guarantees the in-app demo world matches
/// what the manual documents.
class ManualDemoWorld {
  ManualDemoWorld._({
    required this.category,
    required this.categories,
    required this.labels,
    required this.images,
    required this.coverImages,
    required this.tasks,
    required this.checklists,
    required this.checklistItems,
    required this.timeRecords,
    required this.entries,
    required this.links,
    required this.habits,
    required this.habitCompletions,
  });

  /// Builds the Intergalactic Penguin Logistics world.
  ///
  /// [translate] resolves every user-visible string; it defaults to the
  /// manual screenshot suites' `LOTTI_MANUAL_LOCALE` environment contract
  /// (English when unset).
  ///
  /// [now] is the clock the whole world is expressed against, defaulting to
  /// the fixed [manualDemoNow] so screenshot output stays byte-identical to
  /// the historical fixture. Creation and tracking timestamps follow [now]
  /// exactly; **due dates are semantic** — "today at 12:00", "next Monday",
  /// "overdue by two days" — resolved through [DemoDates] against [now]'s
  /// calendar day. That is what keeps a world seeded at 23:00 from showing a
  /// due-today chip as tomorrow, and it is byte-identical under the fixed
  /// clock, where every authored due date already meant exactly that.
  factory ManualDemoWorld.penguinLogistics({
    DemoSeedText? translate,
    DateTime? now,
  }) {
    final t = translate ?? demoSeedTextFromEnvironment();
    final anchor = now ?? manualDemoNow;
    final dates = DemoDates(anchor);
    final supplementalChecklistIds = <String, String>{
      manualRollCallTaskId: demoUuid('manual-roll-call-checklist'),
      manualLaunchReviewTaskId: demoUuid('manual-launch-review-checklist'),
      manualLunchTaskId: demoUuid('manual-lunch-checklist'),
      manualSardineFuturesTaskId: demoUuid('manual-sardine-futures-checklist'),
      manualFishFeederTaskId: demoUuid('manual-fish-feeder-checklist'),
      manualSardineCargoTaskId: demoUuid('manual-sardine-cargo-checklist'),
      manualPenguinPassengerTaskId: demoUuid(
        'manual-penguin-passenger-checklist',
      ),
      manualHeadsetWalkTaskId: demoUuid('manual-headset-walk-checklist'),
      demoLaunchCommsTaskId: demoUuid('manual-launch-comms-plan-checklist'),
      demoIcePadWeatherTaskId: demoUuid('manual-ice-pad-weather-checklist'),
      demoFlightSuitTaskId: demoUuid('manual-flight-suit-fitting-checklist'),
      demoHumiditySpikeTaskId: demoUuid('manual-humidity-spike-checklist'),
      demoIceRinkTaskId: demoUuid('manual-ice-rink-resurface-checklist'),
      demoSolarArrayTaskId: demoUuid('manual-solar-array-tilt-checklist'),
      demoWaterRecyclerTaskId: demoUuid('manual-water-recycler-checklist'),
      demoKrillSupplierTaskId: demoUuid('manual-krill-supplier-checklist'),
      demoPodSealOrderTaskId: demoUuid('manual-pod-seal-order-checklist'),
      demoCustomsEuropaTaskId: demoUuid('manual-customs-europa-checklist'),
      demoChickDaycareTaskId: demoUuid('manual-chick-daycare-checklist'),
      demoMovieNightTaskId: demoUuid('manual-movie-night-checklist'),
      demoTobogganingTaskId: demoUuid('manual-tobogganing-league-checklist'),
    };

    final category = CategoryDefinition(
      id: manualDemoCategoryId,
      createdAt: anchor,
      updatedAt: anchor,
      name: t('Penguin Operations', 'Pinguinbetrieb'),
      vectorClock: null,
      private: false,
      active: true,
      favorite: true,
      color: '#4AB6E8',
    );
    final labels = <LabelDefinition>[
      LabelDefinition(
        id: manualDemoProjectLabelId,
        name: 'Project Waddle',
        color: '#1F9CF5',
        createdAt: anchor,
        updatedAt: anchor,
        vectorClock: null,
        private: false,
      ),
      LabelDefinition(
        id: manualDemoCriticalLabelId,
        name: t('Habitat critical', 'Habitat kritisch'),
        color: '#FBA337',
        createdAt: anchor,
        updatedAt: anchor,
        vectorClock: null,
        private: false,
      ),
      // Appended, never reordered: the manual quotes the first two by name.
      LabelDefinition(
        id: demoBlockedLabelId,
        name: t('Blocked', 'Blockiert'),
        color: '#E5484D',
        createdAt: anchor,
        updatedAt: anchor,
        vectorClock: null,
        private: false,
      ),
      LabelDefinition(
        id: demoWaitingLabelId,
        name: t('Waiting on', 'Wartet auf'),
        color: '#8E8CD8',
        createdAt: anchor,
        updatedAt: anchor,
        vectorClock: null,
        private: false,
      ),
      LabelDefinition(
        id: demoResearchLabelId,
        name: t('Research', 'Recherche'),
        color: '#30A46C',
        createdAt: anchor,
        updatedAt: anchor,
        vectorClock: null,
        private: false,
      ),
    ];
    final originalCoverIds = <String>{
      manualHabitatCoverImageId,
      manualRollCallCoverImageId,
      manualLaunchReviewCoverImageId,
      manualLunchCoverImageId,
      manualSardineFuturesCoverImageId,
      manualFishFeederCoverImageId,
      manualSardineCargoCoverImageId,
      manualPenguinPassengerCoverImageId,
      manualHeadsetWalkCoverImageId,
    };
    final imageAssets = demoMediaAssets
        .where((asset) => asset.taskId != demoUuid('demo-tutorial-first-steps'))
        .toList();
    final images = imageAssets.map((asset) {
      final capturedAt = originalCoverIds.contains(asset.id)
          ? anchor
          : dates.daysAgo(asset.capturedDaysAgo, asset.capturedHour);
      final caption = asset.caption(t);
      return JournalImage(
        meta: Metadata(
          id: asset.id,
          createdAt: capturedAt,
          updatedAt: capturedAt,
          dateFrom: capturedAt,
          dateTo: capturedAt,
          categoryId: asset.categoryId,
        ),
        data: ImageData(
          capturedAt: capturedAt,
          imageId: '${asset.id}-file',
          imageFile: asset.fileName,
          imageDirectory: asset.imageDirectory,
          thumbHash: asset.thumbHash,
        ),
        entryText: caption == null ? null : EntryText(plainText: caption),
      );
    }).toList();
    final coverImages = images
        .where((image) => originalCoverIds.contains(image.meta.id))
        .toList();

    Task task({
      required String id,
      required String title,
      required String description,
      required TaskStatus status,
      required TaskPriority priority,
      required DateTime? due,
      required String? coverArtId,
      required List<String> labelIds,
      required Duration estimate,
      List<String>? checklistIds,
      String categoryId = manualDemoCategoryId,
      DateTime? createdAt,
      DateTime? dateFrom,
    }) {
      final from = dateFrom ?? anchor;
      final base = TestTaskFactory.create(
        id: id,
        title: title,
        plainText: description,
        createdAt: createdAt ?? anchor.subtract(const Duration(days: 2)),
        dateFrom: from,
        dateTo: from.add(estimate),
        status: status,
        statusHistory: [status],
        categoryId: categoryId,
        estimate: estimate,
        checklistIds: checklistIds ?? [supplementalChecklistIds[id]!],
      );
      return base.copyWith(
        meta: base.meta.copyWith(labelIds: labelIds),
        data: base.data.copyWith(
          due: due,
          priority: priority,
          coverArtId: coverArtId,
          coverArtCropX: 0.5,
        ),
      );
    }

    final orbitalStatus = TaskStatus.inProgress(
      id: 'status-orbital-in-progress',
      createdAt: anchor.subtract(const Duration(hours: 2)),
      utcOffset: 120,
    );
    final feederStatus = TaskStatus.open(
      id: 'status-feeder-open',
      createdAt: anchor.subtract(const Duration(days: 1)),
      utcOffset: 120,
    );
    final cargoStatus = TaskStatus.groomed(
      id: 'status-cargo-groomed',
      createdAt: anchor.subtract(const Duration(hours: 20)),
      utcOffset: 120,
    );
    final passengerStatus = TaskStatus.open(
      id: 'status-passenger-open',
      createdAt: anchor.subtract(const Duration(hours: 10)),
      utcOffset: 120,
    );
    final agendaStatus = TaskStatus.open(
      id: 'status-agenda-open',
      createdAt: anchor.subtract(const Duration(days: 1)),
      utcOffset: 120,
    );

    ChecklistItem checklistItem({
      required String id,
      required String title,
      required bool isChecked,
      required Duration checkedAgo,
      String? checklistId,
      String categoryId = manualDemoCategoryId,
      DateTime? createdAt,
    }) {
      final owningChecklistId = checklistId ?? manualHabitatChecklistId;
      return ChecklistItem(
        meta: TestMetadataFactory.create(
          id: id,
          createdAt: createdAt ?? anchor.subtract(const Duration(days: 1)),
          categoryId: categoryId,
        ),
        data: ChecklistItemData(
          id: id,
          title: title,
          isChecked: isChecked,
          linkedChecklists: [owningChecklistId],
          checkedAt: isChecked ? anchor.subtract(checkedAgo) : null,
        ),
      );
    }

    // The habitat inspection is the task the manual follows end to end, so it
    // is the one fixture that carries a checklist and a time record: the
    // screenshots have to show a task as a *record of work*, not an empty
    // shell.
    final habitatChecklistItems = <ChecklistItem>[
      checklistItem(
        id: manualHabitatSealsItemId,
        title: t(
          'Walk pressure seals A–F',
          'Druckdichtungen A–F abgehen',
        ),
        isChecked: true,
        checkedAgo: const Duration(hours: 1, minutes: 18),
      ),
      checklistItem(
        id: manualHabitatRollCallItemId,
        title: t(
          'Count all 37 emperor penguins',
          'Alle 37 Kaiserpinguine zählen',
        ),
        isChecked: true,
        checkedAgo: const Duration(minutes: 52),
      ),
      checklistItem(
        id: manualHabitatCargoItemId,
        title: t(
          'Route the sardine cargo pods',
          'Sardinen-Frachtkapseln routen',
        ),
        isChecked: false,
        checkedAgo: Duration.zero,
      ),
      checklistItem(
        id: manualHabitatClearanceItemId,
        title: t(
          'Request Mission Control clearance',
          'Freigabe der Missionskontrolle anfordern',
        ),
        isChecked: false,
        checkedAgo: Duration.zero,
      ),
    ];

    final habitatChecklist = Checklist(
      meta: TestMetadataFactory.create(
        id: manualHabitatChecklistId,
        createdAt: anchor.subtract(const Duration(days: 1)),
        categoryId: manualDemoCategoryId,
      ),
      data: ChecklistData(
        title: t('Pre-launch checks', 'Checks vor dem Start'),
        linkedChecklistItems: [
          for (final item in habitatChecklistItems) item.meta.id,
        ],
        linkedTasks: [manualOrbitalHabitatTaskId],
      ),
    );

    final habitatTimeRecord = JournalEntry(
      meta: TestMetadataFactory.create(
        id: manualHabitatTimeRecordId,
        createdAt: anchor.subtract(
          const Duration(hours: 1, minutes: 18),
        ),
        dateFrom: anchor.subtract(const Duration(hours: 1, minutes: 18)),
        dateTo: anchor.subtract(const Duration(minutes: 8)),
        categoryId: manualDemoCategoryId,
      ),
      entryText: EntryText(
        plainText: t(
          'Seal walk complete: A–F held at 101.3 kPa overnight. Roll call '
              'confirmed all 37 penguins, including the one asleep in the '
              'cargo netting.',
          'Dichtungsrundgang abgeschlossen: A–F hielten über Nacht 101,3 kPa. '
              'Der Zählappell bestätigte alle 37 Pinguine, auch den, der im '
              'Frachtnetz schlief.',
        ),
      ),
    );

    // ----------------------------------------------------------------------
    // Expansion content: four clusters of linked work around the original
    // nine, so the knowledge graph has somewhere to walk.
    // ----------------------------------------------------------------------

    TaskStatus openAt(String slug, int daysBack) => TaskStatus.open(
      id: 'status-$slug',
      createdAt: dates.daysAgo(daysBack),
      utcOffset: 120,
    );
    TaskStatus groomedAt(String slug, int daysBack) => TaskStatus.groomed(
      id: 'status-$slug',
      createdAt: dates.daysAgo(daysBack),
      utcOffset: 120,
    );
    TaskStatus runningAt(String slug, int daysBack) => TaskStatus.inProgress(
      id: 'status-$slug',
      createdAt: dates.daysAgo(daysBack),
      utcOffset: 120,
    );
    TaskStatus doneAt(String slug, int daysBack) => TaskStatus.done(
      id: 'status-$slug',
      createdAt: dates.daysAgo(daysBack),
      utcOffset: 120,
    );

    JournalEntry note({
      required String id,
      required String text,
      required DateTime from,
      DateTime? to,
      String categoryId = manualDemoCategoryId,
    }) {
      return JournalEntry(
        meta: TestMetadataFactory.create(
          id: id,
          createdAt: from,
          dateFrom: from,
          dateTo: to ?? from,
          categoryId: categoryId,
        ),
        entryText: EntryText(plainText: text),
      );
    }

    Checklist checklist({
      required String id,
      required String title,
      required String taskId,
      required List<ChecklistItem> items,
      String categoryId = manualDemoCategoryId,
    }) {
      return Checklist(
        meta: TestMetadataFactory.create(
          id: id,
          createdAt: dates.daysAgo(3),
          categoryId: categoryId,
        ),
        data: ChecklistData(
          title: title,
          linkedChecklistItems: [for (final item in items) item.meta.id],
          linkedTasks: [taskId],
        ),
      );
    }

    // Checklists — each owned by one expansion task, mixed checked state.
    final rehearsalItems = [
      for (final (index, spec) in <(String, String, bool)>[
        ('Brief the boarding crew', 'Die Einsteigemannschaft briefen', true),
        ('Time the hatch sequence', 'Die Lukensequenz stoppen', true),
        ('Test the intercom', 'Die Gegensprechanlage testen', false),
        ('Rehearse the abort call', 'Den Abbruchruf proben', false),
      ].indexed)
        checklistItem(
          id: demoUuid('manual-rehearsal-item-$index'),
          title: t(spec.$1, spec.$2),
          isChecked: spec.$3,
          checkedAgo: Duration(hours: 26 + index),
          checklistId: demoRehearsalChecklistId,
          createdAt: dates.daysAgo(3),
        ),
    ];
    final scrubberItems = [
      for (final (index, spec) in <(String, String, bool)>[
        ('Vent Bay A', 'Bucht A entlüften', true),
        ('Swap cartridges A1–A4', 'Patronen A1–A4 tauschen', true),
        ('Log the CO2 baseline', 'CO2-Ausgangswert notieren', false),
        (
          'Return the used cartridges',
          'Die alten Patronen zurückgeben',
          false,
        ),
      ].indexed)
        checklistItem(
          id: demoUuid('manual-scrubber-item-$index'),
          title: t(spec.$1, spec.$2),
          isChecked: spec.$3,
          checkedAgo: Duration(hours: 4 + index),
          checklistId: demoScrubberChecklistId,
          categoryId: demoHabitatCategoryId,
          createdAt: dates.daysAgo(2),
        ),
    ];
    final palletItems = [
      for (final (index, spec) in <(String, String, bool)>[
        ('Check bay two', 'Bucht zwei prüfen', true),
        ('Check the cold ring', 'Den Kühlring prüfen', true),
        ('Ask the dock crew', 'Die Dockmannschaft fragen', false),
        ('File a loss report', 'Verlustmeldung einreichen', false),
      ].indexed)
        checklistItem(
          id: demoUuid('manual-pallet-item-$index'),
          title: t(spec.$1, spec.$2),
          isChecked: spec.$3,
          checkedAgo: Duration(hours: 6 + index),
          checklistId: demoPalletChecklistId,
          categoryId: demoLogisticsCategoryId,
          createdAt: dates.daysAgo(2),
        ),
    ];
    final newsletterItems = [
      for (final (index, spec) in <(String, String, bool)>[
        ('Colony news', 'Neues aus der Kolonie', true),
        ('Launch update', 'Neues zum Start', false),
        ('Chick of the month', 'Küken des Monats', true),
        ('Sardine recipe', 'Sardinenrezept', false),
      ].indexed)
        checklistItem(
          id: demoUuid('manual-newsletter-item-$index'),
          title: t(spec.$1, spec.$2),
          isChecked: spec.$3,
          checkedAgo: Duration(hours: 30 + index),
          checklistId: demoNewsletterChecklistId,
          createdAt: dates.daysAgo(4),
        ),
    ];
    // Every box ticked — this is why the cold-chain audit is already done.
    final freezerItems = [
      for (final (index, spec) in <(String, String, bool)>[
        ('Pull the log exports', 'Die Protokollexporte ziehen', true),
        ('Flag every gap', 'Jede Lücke markieren', true),
        ('Recheck freezer 3', 'Kühler 3 erneut prüfen', true),
        ('Sign off the audit', 'Die Prüfung abzeichnen', true),
      ].indexed)
        checklistItem(
          id: demoUuid('manual-freezer-item-$index'),
          title: t(spec.$1, spec.$2),
          isChecked: spec.$3,
          checkedAgo: Duration(hours: 50 + index),
          checklistId: demoFreezerChecklistId,
          createdAt: dates.daysAgo(6),
        ),
    ];
    final manifestItems = [
      for (final (index, spec) in <(String, String, bool)>[
        ('Count pods on the dock', 'Kapseln am Dock zählen', true),
        ('Match against the manifest', 'Mit der Frachtliste abgleichen', true),
        (
          'Confirm the cold-chain seals',
          'Die Kühlkettensiegel bestätigen',
          false,
        ),
        ('Send the corrected list', 'Die korrigierte Liste senden', false),
      ].indexed)
        checklistItem(
          id: demoUuid('manual-manifest-item-$index'),
          title: t(spec.$1, spec.$2),
          isChecked: spec.$3,
          checkedAgo: Duration(hours: 12 + index),
          checklistId: demoManifestChecklistId,
          categoryId: demoLogisticsCategoryId,
          createdAt: dates.daysAgo(1),
        ),
    ];

    final expansionChecklists = <Checklist>[
      checklist(
        id: demoRehearsalChecklistId,
        title: t('Rehearsal script', 'Probenskript'),
        taskId: demoLaunchRehearsalTaskId,
        items: rehearsalItems,
      ),
      checklist(
        id: demoScrubberChecklistId,
        title: t('Scrubber swap', 'Filtertausch'),
        taskId: demoAirScrubbersTaskId,
        items: scrubberItems,
        categoryId: demoHabitatCategoryId,
      ),
      checklist(
        id: demoPalletChecklistId,
        title: t('Pallet search', 'Palettensuche'),
        taskId: demoSquidPalletTaskId,
        items: palletItems,
        categoryId: demoLogisticsCategoryId,
      ),
      checklist(
        id: demoNewsletterChecklistId,
        title: t('Newsletter sections', 'Abschnitte des Koloniebriefs'),
        taskId: demoColonyNewsletterTaskId,
        items: newsletterItems,
      ),
      checklist(
        id: demoFreezerChecklistId,
        title: t('Freezer log audit', 'Prüfung der Kühlprotokolle'),
        taskId: demoColdChainAuditTaskId,
        items: freezerItems,
      ),
      checklist(
        id: demoManifestChecklistId,
        title: t('Manifest checks', 'Prüfungen der Frachtliste'),
        taskId: demoShuttleManifestTaskId,
        items: manifestItems,
        categoryId: demoLogisticsCategoryId,
      ),
    ];

    // Every task is a small, usable piece of penguin logistics work. The
    // original fixture predates the expanded task world, so these runbooks
    // give its remaining tasks — and the expansion tasks without bespoke
    // checklists above — the same interactive, mixed-progress experience.
    String supplementalChecklistId(String slug) =>
        demoUuid('manual-$slug-checklist');

    final launchRunbook = <(String, String)>[
      ('Brief the boarding crew', 'Die Einsteigemannschaft briefen'),
      ('Time the hatch sequence', 'Die Lukensequenz stoppen'),
      ('Test the intercom', 'Die Gegensprechanlage testen'),
      ('Rehearse the abort call', 'Den Abbruchruf proben'),
    ];
    final habitatRunbook = <(String, String)>[
      ('Vent Bay A', 'Bucht A entlüften'),
      ('Swap cartridges A1–A4', 'Patronen A1–A4 tauschen'),
      ('Log the CO2 baseline', 'CO2-Ausgangswert notieren'),
      ('Return the used cartridges', 'Die alten Patronen zurückgeben'),
    ];
    final logisticsRunbook = <(String, String)>[
      ('Check bay two', 'Bucht zwei prüfen'),
      ('Check the cold ring', 'Den Kühlring prüfen'),
      ('Ask the dock crew', 'Die Dockmannschaft fragen'),
      ('File a loss report', 'Verlustmeldung einreichen'),
    ];
    final colonyRunbook = <(String, String)>[
      ('Colony news', 'Neues aus der Kolonie'),
      ('Launch update', 'Neues zum Start'),
      ('Chick of the month', 'Küken des Monats'),
      ('Sardine recipe', 'Sardinenrezept'),
    ];

    ({Checklist checklist, List<ChecklistItem> items}) supplementalChecklist({
      required String slug,
      required String taskId,
      required (String, String) taskTitle,
      List<(String, String)>? runbook,
      List<(String, String)>? steps,
      int checkedCount = 1,
      String categoryId = manualDemoCategoryId,
    }) {
      assert(
        (steps == null) != (runbook == null),
        'Pass exactly one of runbook (shared vocabulary) or steps (bespoke).',
      );
      final id = supplementalChecklistId(slug);
      // Bespoke steps describe the task's own work; the shared runbooks keep
      // the original fixture's checklists visibly tied to their owning task
      // while retaining the localized operational vocabulary.
      final taskRunbook = steps ?? [taskTitle, ...runbook!.take(3)];
      final items = [
        for (final (index, spec) in taskRunbook.indexed)
          checklistItem(
            id: demoUuid('manual-$slug-item-$index'),
            title: t(spec.$1, spec.$2),
            isChecked: index < checkedCount,
            checkedAgo: Duration(hours: 18 + index),
            checklistId: id,
            categoryId: categoryId,
            createdAt: dates.daysAgo(2),
          ),
      ];
      return (
        checklist: checklist(
          id: id,
          title: t(taskTitle.$1, taskTitle.$2),
          taskId: taskId,
          items: items,
          categoryId: categoryId,
        ),
        items: items,
      );
    }

    final supplementalChecklists = [
      supplementalChecklist(
        slug: 'roll-call',
        taskId: manualRollCallTaskId,
        taskTitle: ('Emperor penguin roll call', 'Kaiserpinguine durchzählen'),
        runbook: colonyRunbook,
      ),
      supplementalChecklist(
        slug: 'launch-review',
        taskId: manualLaunchReviewTaskId,
        taskTitle: (
          'Project Waddle launch review',
          'Startprüfung für Project Waddle',
        ),
        runbook: launchRunbook,
      ),
      supplementalChecklist(
        slug: 'lunch',
        taskId: manualLunchTaskId,
        taskTitle: (
          'Lunch (coffee is not a vegetable)',
          'Mittagessen (Kaffee ist kein Gemüse)',
        ),
        runbook: colonyRunbook,
      ),
      supplementalChecklist(
        slug: 'sardine-futures',
        taskId: manualSardineFuturesTaskId,
        taskTitle: ('Negotiate sardine futures', 'Sardinen-Futures verhandeln'),
        runbook: logisticsRunbook,
        categoryId: demoLogisticsCategoryId,
      ),
      supplementalChecklist(
        slug: 'fish-feeder',
        taskId: manualFishFeederTaskId,
        taskTitle: (
          'Recalibrate the zero-gravity fish feeder',
          'Schwerelosen Fischfütterer neu kalibrieren',
        ),
        runbook: habitatRunbook,
      ),
      supplementalChecklist(
        slug: 'sardine-cargo',
        taskId: manualSardineCargoTaskId,
        taskTitle: (
          'Confirm the interplanetary sardine cargo pods',
          'Interplanetare Sardinen-Frachtkapseln bestätigen',
        ),
        runbook: logisticsRunbook,
        categoryId: demoLogisticsCategoryId,
      ),
      supplementalChecklist(
        slug: 'penguin-passenger',
        taskId: manualPenguinPassengerTaskId,
        taskTitle: (
          'Ask Legal whether a penguin is a passenger',
          'Rechtsabteilung fragen, ob ein Pinguin Passagier ist',
        ),
        runbook: logisticsRunbook,
        categoryId: demoLogisticsCategoryId,
      ),
      supplementalChecklist(
        slug: 'headset-walk',
        taskId: manualHeadsetWalkTaskId,
        taskTitle: ('Walk without a headset', 'Spaziergang ohne Headset'),
        runbook: colonyRunbook,
      ),
      supplementalChecklist(
        slug: 'launch-comms-plan',
        taskId: demoLaunchCommsTaskId,
        taskTitle: (
          'Draft the launch comms plan',
          'Kommunikationsplan entwerfen',
        ),
        steps: [
          (
            'List every launch-day announcement',
            'Alle Ansagen des Starttags auflisten',
          ),
          (
            'Name a speaker for each slot',
            'Für jeden Slot eine Stimme benennen',
          ),
          (
            'Write the fallback script for a hold',
            'Das Ersatzskript für einen Halt schreiben',
          ),
          (
            'Get sign-off from Flight Direction',
            'Das Okay der Flugleitung einholen',
          ),
        ],
      ),
      supplementalChecklist(
        slug: 'ice-pad-weather',
        taskId: demoIcePadWeatherTaskId,
        taskTitle: (
          'Check the ice-pad weather window',
          'Wetterfenster am Eisstartplatz prüfen',
        ),
        steps: [
          ('Pull the morning soundings', 'Die Morgensondierungen ziehen'),
          (
            'Compare the three forecast models',
            'Die drei Wettermodelle vergleichen',
          ),
          (
            'Check the crosswind against the 18-knot limit',
            'Den Seitenwind gegen das 18-Knoten-Limit prüfen',
          ),
          (
            'Send the go or no-go call to Flight Direction',
            'Das Go oder No-Go an die Flugleitung melden',
          ),
        ],
      ),
      supplementalChecklist(
        slug: 'flight-suit-fitting',
        taskId: demoFlightSuitTaskId,
        taskTitle: (
          'Fit the penguin flight suits',
          'Pinguin-Fluganzüge anpassen',
        ),
        steps: [
          ('Remeasure all twelve flyers', 'Alle zwölf Flieger neu vermessen'),
          (
            'Tag the three wide-flipper returns',
            'Die drei Rückläufer mit weiten Flossen kennzeichnen',
          ),
          ('Book the courier pickup', 'Die Kurierabholung buchen'),
          (
            'Confirm the replacement delivery date',
            'Den Liefertermin des Ersatzes bestätigen',
          ),
        ],
      ),
      supplementalChecklist(
        slug: 'humidity-spike',
        taskId: demoHumiditySpikeTaskId,
        taskTitle: (
          'Trace the humidity spike in Bay C',
          'Feuchtigkeitsspitze in Bucht C aufspüren',
        ),
        steps: [
          (
            'Chart the humidity readings by day',
            'Die Feuchtigkeitswerte nach Tagen aufzeichnen',
          ),
          (
            'Wait for the Bay C sensor swap',
            'Auf den Sensortausch in Bucht C warten',
          ),
          (
            'Walk the seam line with the thermal camera',
            'Die Nahtlinie mit der Wärmebildkamera ablaufen',
          ),
          (
            'Report the leak or clear the bay',
            'Das Leck melden oder die Bucht freigeben',
          ),
        ],
        categoryId: demoHabitatCategoryId,
      ),
      supplementalChecklist(
        slug: 'ice-rink-resurface',
        taskId: demoIceRinkTaskId,
        taskTitle: (
          'Resurface the habitat ice rink',
          'Eisbahn im Habitat neu aufbereiten',
        ),
        steps: [
          (
            'Book the resurfacer for an evening slot',
            'Die Maschine für einen Abendtermin buchen',
          ),
          (
            'Announce the one-session closure',
            'Die Sperrung für eine Einheit ankündigen',
          ),
          (
            'Resurface and inspect the ice',
            'Die Bahn aufbereiten und das Eis abnehmen',
          ),
          ('Post the new ice rules', 'Die neuen Eisregeln aushängen'),
        ],
        categoryId: demoHabitatCategoryId,
      ),
      supplementalChecklist(
        slug: 'solar-array-tilt',
        taskId: demoSolarArrayTaskId,
        taskTitle: (
          'Retune the solar array tilt',
          'Neigung der Solarfläche justieren',
        ),
        steps: [
          (
            'Recalibrate against the noon reference',
            'Am Mittagsreferenzpunkt neu kalibrieren',
          ),
          (
            'Verify the tracking curve for a full day',
            'Die Nachführkurve einen ganzen Tag prüfen',
          ),
          (
            'Log the recovered wattage',
            'Die zurückgewonnene Leistung protokollieren',
          ),
          (
            'Close the storm-damage ticket',
            'Das Sturmschaden-Ticket schließen',
          ),
        ],
        categoryId: demoHabitatCategoryId,
      ),
      supplementalChecklist(
        slug: 'water-recycler',
        taskId: demoWaterRecyclerTaskId,
        taskTitle: ('Service the water recycler', 'Wasseraufbereiter warten'),
        steps: [
          ('Flush the recycler loop', 'Den Kreislauf der Anlage spülen'),
          ('Clean the filter housing', 'Das Filtergehäuse reinigen'),
          ('Swap the pre-filter', 'Den Vorfilter tauschen'),
          ('Log the throughput numbers', 'Die Durchsatzwerte protokollieren'),
        ],
        // The task is done, so its checklist reads as finished work.
        checkedCount: 4,
        categoryId: demoHabitatCategoryId,
      ),
      supplementalChecklist(
        slug: 'krill-supplier',
        taskId: demoKrillSupplierTaskId,
        taskTitle: (
          'Shortlist a second krill supplier',
          'Zweiten Krill-Lieferanten finden',
        ),
        steps: [
          (
            'Write down the selection criteria',
            'Die Auswahlkriterien aufschreiben',
          ),
          (
            'Collect quotes from three candidates',
            'Angebote von drei Kandidaten einholen',
          ),
          (
            'Order sample crates from the best two',
            'Bei den besten zwei Probekisten bestellen',
          ),
          (
            'Put a recommendation to the council',
            'Dem Rat eine Empfehlung vorlegen',
          ),
        ],
        categoryId: demoLogisticsCategoryId,
      ),
      supplementalChecklist(
        slug: 'pod-seal-order',
        taskId: demoPodSealOrderTaskId,
        taskTitle: (
          'Order replacement pod seals',
          'Ersatzdichtungen für Kapseln bestellen',
        ),
        steps: [
          (
            'Confirm seal sizes against the pod register',
            'Die Dichtungsgrößen mit dem Kapselregister abgleichen',
          ),
          ('Place the rush order', 'Die Eilbestellung aufgeben'),
          (
            'Chase the delivery confirmation',
            'Die Lieferbestätigung nachfassen',
          ),
          (
            'Warn Logistics about the affected pods',
            'Die Logistik über die betroffenen Kapseln warnen',
          ),
        ],
        categoryId: demoLogisticsCategoryId,
      ),
      supplementalChecklist(
        slug: 'customs-europa',
        taskId: demoCustomsEuropaTaskId,
        taskTitle: ('Clear customs on Europa', 'Zoll auf Europa erledigen'),
        steps: [
          (
            'Assemble the certificate folder',
            'Den Zertifikatsordner zusammenstellen',
          ),
          (
            'Draft the passenger ruling request',
            'Die Anfrage zur Passagierfrage aufsetzen',
          ),
          ('Copy the current manifest', 'Die aktuelle Frachtliste kopieren'),
          ('Book the Monday customs slot', 'Den Zolltermin am Montag buchen'),
        ],
        categoryId: demoLogisticsCategoryId,
      ),
      supplementalChecklist(
        slug: 'chick-daycare',
        taskId: demoChickDaycareTaskId,
        taskTitle: (
          'Refill the chick daycare rota',
          'Dienstplan der Kükenbetreuung füllen',
        ),
        steps: [
          (
            'Ask the reserve list for Thursday',
            'Die Reserveliste für Donnerstag fragen',
          ),
          (
            'Post the open shifts on the colony board',
            'Die offenen Schichten ans Koloniebrett hängen',
          ),
          (
            'Confirm two names per shift',
            'Zwei Namen pro Schicht bestätigen',
          ),
          (
            'Publish the full week by Friday',
            'Den vollen Wochenplan bis Freitag aushängen',
          ),
        ],
      ),
      supplementalChecklist(
        slug: 'movie-night',
        taskId: demoMovieNightTaskId,
        taskTitle: (
          'Pick the film for colony night',
          'Film für den Kolonieabend wählen',
        ),
        steps: [
          ('Request the screening licence', 'Die Vorführlizenz anfragen'),
          (
            'Reserve the dome for the evening',
            'Die Kuppel für den Abend reservieren',
          ),
          (
            'Schedule the heater shutdown',
            'Das Abschalten der Heizung einplanen',
          ),
          (
            'Post the start time on the colony board',
            'Die Anfangszeit ans Koloniebrett schreiben',
          ),
        ],
      ),
      supplementalChecklist(
        slug: 'tobogganing-league',
        taskId: demoTobogganingTaskId,
        taskTitle: (
          'Restart the tobogganing league',
          'Rodel-Liga wieder starten',
        ),
        steps: [
          (
            'Pile fresh snow on the run-out',
            'Frischen Schnee in den Auslauf schaufeln',
          ),
          (
            'Set the doubles-sled weight limit',
            'Das Gewichtslimit für den Doppelschlitten festlegen',
          ),
          (
            'Draft the new season schedule',
            'Den neuen Saisonplan entwerfen',
          ),
          (
            'Send the rematch challenge to Bay C',
            'Die Revanche-Anfrage an Bucht C schicken',
          ),
        ],
      ),
    ];

    // Short observations, spread over the past six weeks so the journal
    // timeline reads as lived-in rather than seeded in one burst.
    final notes = _penguinNotes(t: t, dates: dates, note: note);

    // Logged work: real spans on past weekdays, so time tracking has data.
    JournalEntry timeRecord({
      required String id,
      required String text,
      required int weekdaysBack,
      required int hour,
      required Duration duration,
      String categoryId = manualDemoCategoryId,
    }) {
      final from = dates.pastWeekday(weekdaysBack, hour);
      return note(
        id: id,
        text: text,
        from: from,
        to: from.add(duration),
        categoryId: categoryId,
      );
    }

    final expansionTimeRecords = _penguinExpansionTimeRecords(
      t: t,
      timeRecord: timeRecord,
    );

    final expansionTasks = _penguinExpansionTasks(
      t: t,
      dates: dates,
      task: task,
      note: note,
      openAt: openAt,
      groomedAt: groomedAt,
      runningAt: runningAt,
      doneAt: doneAt,
    );

    EntryLink link(String fromId, String toId) => EntryLink.basic(
      id: demoUuid('link-$fromId-$toId'),
      fromId: fromId,
      toId: toId,
      createdAt: anchor,
      updatedAt: anchor,
      vectorClock: null,
    );

    final links = <EntryLink>[
      // The historical hero link keeps its own id.
      EntryLink.basic(
        id: demoHabitatTimeLinkId,
        fromId: manualOrbitalHabitatTaskId,
        toId: manualHabitatTimeRecordId,
        createdAt: anchor,
        updatedAt: anchor,
        vectorClock: null,
      ),
      for (final (from, to) in _demoTaskPairs) link(from, to),
      for (final (from, to) in _demoEntryPairs) link(from, to),
      for (final asset in imageAssets) link(asset.taskId, asset.id),
    ];

    HabitDefinition habit({
      required String id,
      required String name,
      required String description,
      String? categoryId,
      HabitSchedule? schedule,
      DateTime? activeFrom,
      bool priority = false,
      bool private = false,
      bool active = true,
    }) => HabitDefinition(
      id: id,
      name: name,
      description: description,
      createdAt: anchor,
      updatedAt: anchor,
      vectorClock: null,
      habitSchedule:
          schedule ?? const HabitSchedule.daily(requiredCompletions: 1),
      activeFrom: activeFrom,
      active: active,
      private: private,
      priority: priority,
      categoryId: categoryId,
    );

    final habits = _penguinHabits(t: t, dates: dates, habit: habit);

    HabitCompletionEntry completion({
      required String habitId,
      required int daysAgo,
      required HabitCompletionType type,
      required int hour,
      String categoryId = manualDemoCategoryId,
    }) {
      final at = dates.daysAgo(daysAgo, hour);
      return HabitCompletionEntry(
        meta: TestMetadataFactory.create(
          id: demoUuid('habit-completion-$habitId-$daysAgo'),
          createdAt: at,
          categoryId: categoryId,
        ),
        data: HabitCompletionData(
          dateFrom: at,
          dateTo: at,
          habitId: habitId,
          completionType: type,
        ),
      );
    }

    // A history that reads as lived-in rather than perfect: the roll call is
    // near-unbroken with one skipped day, the seal walk is patchier and has
    // a genuine failure. Both stop short of today, so the demo opens with
    // something the user can actually tick off.
    final habitCompletions = <HabitCompletionEntry>[
      for (var day = _habitHistoryDays; day >= 1; day--)
        if (day != 5)
          completion(
            habitId: manualRollCallHabitId,
            daysAgo: day,
            type: day == 9
                ? HabitCompletionType.skip
                : (HabitCompletionType.success),
            hour: 6,
          ),
      for (var day = _habitHistoryDays; day >= 1; day--)
        if (day % 3 != 0)
          completion(
            habitId: manualHabitatSealsHabitId,
            daysAgo: day,
            type: day == 4
                ? HabitCompletionType.fail
                : (HabitCompletionType.success),
            hour: 7,
          ),
      for (var day = _habitHistoryDays; day >= 1; day--)
        if (day % 7 != 0)
          completion(
            habitId: demoColdChainTelemetryHabitId,
            daysAgo: day,
            type: day == 11
                ? HabitCompletionType.skip
                : HabitCompletionType.success,
            hour: 7,
            categoryId: demoLogisticsCategoryId,
          ),
      for (var day = _habitHistoryDays; day >= 1; day--)
        if (day % 4 != 0)
          completion(
            habitId: demoOutboundManifestHabitId,
            daysAgo: day,
            type: day == 13
                ? HabitCompletionType.fail
                : HabitCompletionType.success,
            hour: 8,
            categoryId: demoLogisticsCategoryId,
          ),
      for (var day = _habitHistoryDays; day >= 1; day--)
        if (day % 5 != 0)
          completion(
            habitId: demoShiftHandoffHabitId,
            daysAgo: day,
            type: day == 6
                ? HabitCompletionType.skip
                : HabitCompletionType.success,
            hour: 17,
          ),
      for (final day in const [27, 25, 22, 20, 18, 15, 13, 11, 8, 6, 4, 2])
        completion(
          habitId: demoFlipperMobilityHabitId,
          daysAgo: day,
          type: day == 13
              ? HabitCompletionType.skip
              : HabitCompletionType.success,
          hour: 18,
        ),
    ];

    return ManualDemoWorld._(
      category: category,
      categories: [
        category,
        CategoryDefinition(
          id: demoHabitatCategoryId,
          createdAt: anchor,
          updatedAt: anchor,
          name: t('Habitat Engineering', 'Habitat-Technik'),
          vectorClock: null,
          private: false,
          active: true,
          favorite: false,
          color: '#7BD3A0',
        ),
        CategoryDefinition(
          id: demoLogisticsCategoryId,
          createdAt: anchor,
          updatedAt: anchor,
          name: t('Logistics & Supply', 'Logistik & Nachschub'),
          vectorClock: null,
          private: false,
          active: true,
          favorite: false,
          color: '#F2A65A',
        ),
      ],
      labels: labels,
      habits: habits,
      habitCompletions: habitCompletions,
      images: images,
      coverImages: coverImages,
      checklists: [
        habitatChecklist,
        ...expansionChecklists,
        for (final seed in supplementalChecklists) seed.checklist,
      ],
      checklistItems: [
        ...habitatChecklistItems,
        ...rehearsalItems,
        ...scrubberItems,
        ...palletItems,
        ...newsletterItems,
        ...freezerItems,
        ...manifestItems,
        for (final seed in supplementalChecklists) ...seed.items,
      ],
      timeRecords: [habitatTimeRecord, ...expansionTimeRecords],
      entries: notes,
      links: links,
      tasks: [
        task(
          id: manualRollCallTaskId,
          title: t('Emperor penguin roll call', 'Kaiserpinguine durchzählen'),
          description: t(
            'Count every expedition penguin, check the tiny oxygen packs, '
                'and record any suspiciously formal salutes.',
            'Zähle alle Expeditionspinguine, prüfe die winzigen Sauerstoffpacks '
                'und notiere verdächtig förmliche Grüße.',
          ),
          status: agendaStatus,
          priority: TaskPriority.p2Medium,
          due: dates.today(9),
          coverArtId: manualRollCallCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(minutes: 30),
        ),
        task(
          id: manualOrbitalHabitatTaskId,
          title: t(
            'Inspect orbital penguin habitat',
            'Pinguin-Habitat im Orbit inspizieren',
          ),
          description: t(
            'Inspect pressure seals, confirm all 37 emperor penguins are '
                'present, and route the sardine cargo pods before the live '
                'Project Waddle demonstration.',
            'Prüfe die Druckdichtungen, bestätige alle 37 Kaiserpinguine und '
                'route die Sardinen-Frachtkapseln vor der Live-Demo von '
                'Project Waddle.',
          ),
          status: orbitalStatus,
          priority: TaskPriority.p1High,
          due: dates.today(12),
          coverArtId: manualHabitatCoverImageId,
          labelIds: const [
            manualDemoProjectLabelId,
            manualDemoCriticalLabelId,
          ],
          estimate: const Duration(hours: 2),
          checklistIds: [manualHabitatChecklistId],
        ),
        task(
          id: manualLaunchReviewTaskId,
          title: t(
            'Project Waddle launch review',
            'Startprüfung für Project Waddle',
          ),
          description: t(
            'Review the ice-pad trajectory, confirm the snack manifest, '
                'and make sure Mission Control has removed the fish-shaped '
                'cursor from the launch display.',
            'Prüfe die Flugbahn vom Eisstartplatz, bestätige die Snackliste '
                'und stelle sicher, dass die Missionskontrolle den '
                'fischförmigen Mauszeiger entfernt hat.',
          ),
          status: agendaStatus,
          priority: TaskPriority.p1High,
          due: dates.today(12),
          coverArtId: manualLaunchReviewCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(minutes: 45),
        ),
        task(
          id: manualLunchTaskId,
          title: t(
            'Lunch (coffee is not a vegetable)',
            'Mittagessen (Kaffee ist kein Gemüse)',
          ),
          description: t(
            'Eat something recognizable as food before the robot '
                'nutritionist files another orbital wellness incident.',
            'Iss etwas, das als Essen erkennbar ist, bevor der '
                'Roboter-Ernährungsberater den nächsten orbitalen '
                'Gesundheitsvorfall meldet.',
          ),
          status: agendaStatus,
          priority: TaskPriority.p3Low,
          due: dates.today(13),
          coverArtId: manualLunchCoverImageId,
          labelIds: const [],
          estimate: const Duration(hours: 1),
        ),
        task(
          id: manualSardineFuturesTaskId,
          title: t('Negotiate sardine futures', 'Sardinen-Futures verhandeln'),
          description: t(
            "Lock the colony's Q3 sardine price before the Europa exchange "
                'discovers why the emergency fish ceiling is shaped like a '
                'penguin.',
            'Sichere den Sardinenpreis der Kolonie für Q3, bevor die Europa-Börse '
                'entdeckt, warum der Notfall-Fischdeckel wie ein Pinguin aussieht.',
          ),
          status: agendaStatus,
          priority: TaskPriority.p1High,
          due: dates.today(14, 30),
          coverArtId: manualSardineFuturesCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(hours: 1, minutes: 30),
        ),
        task(
          id: manualFishFeederTaskId,
          title: t(
            'Recalibrate the zero-gravity fish feeder',
            'Schwerelosen Fischfütterer neu kalibrieren',
          ),
          description: t(
            'Run the low-orbit sardine test and stop the feeder from '
                'launching lunch toward Mission Control.',
            'Führe den Sardinentest im niedrigen Orbit aus und hindere den '
                'Fütterer daran, das Mittagessen zur Missionskontrolle zu schießen.',
          ),
          status: feederStatus,
          priority: TaskPriority.p0Urgent,
          due: dates.today(15),
          coverArtId: manualFishFeederCoverImageId,
          labelIds: const [manualDemoCriticalLabelId],
          estimate: const Duration(hours: 1, minutes: 30),
        ),
        task(
          id: manualSardineCargoTaskId,
          title: t(
            'Confirm the interplanetary sardine cargo pods',
            'Interplanetare Sardinen-Frachtkapseln bestätigen',
          ),
          description: t(
            'Reconcile the cold-chain manifest with the colony dashboard '
                'before the next supply shuttle leaves Europa.',
            'Gleiche die Kühlketten-Frachtliste mit dem Kolonie-Dashboard ab, '
                'bevor das nächste Versorgungsshuttle Europa verlässt.',
          ),
          status: cargoStatus,
          priority: TaskPriority.p2Medium,
          due: dates.tomorrow(9),
          coverArtId: manualSardineCargoCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(minutes: 45),
        ),
        task(
          id: manualPenguinPassengerTaskId,
          title: t(
            'Ask Legal whether a penguin is a passenger',
            'Rechtsabteilung fragen, ob ein Pinguin Passagier ist',
          ),
          description: t(
            'Resolve whether Sir Flaps-a-Lot needs a boarding pass or a '
                'cargo declaration before launch.',
            'Kläre, ob Sir Flatterviel vor dem Start eine Bordkarte oder eine '
                'Frachtdeklaration braucht.',
          ),
          status: passengerStatus,
          priority: TaskPriority.p3Low,
          due: dates.nextMonday(16),
          coverArtId: manualPenguinPassengerCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(minutes: 30),
        ),
        task(
          id: manualHeadsetWalkTaskId,
          title: t('Walk without a headset', 'Spaziergang ohne Headset'),
          description: t(
            'Take one quiet lap around the orbital ice garden without '
                'turning it into a briefing, podcast, or emergency call.',
            'Dreh eine ruhige Runde durch den orbitalen Eisgarten, ohne daraus '
                'ein Briefing, einen Podcast oder einen Notruf zu machen.',
          ),
          status: agendaStatus,
          priority: TaskPriority.p3Low,
          due: dates.today(18),
          coverArtId: manualHeadsetWalkCoverImageId,
          labelIds: const [],
          estimate: const Duration(minutes: 30),
        ),
        // The original nine keep their positions; growth is appended.
        ...expansionTasks,
      ],
    );
  }

  /// The world's primary category, Penguin Operations — the one the manual's
  /// screenshots are composed around. See [categories] for the full set.
  final CategoryDefinition category;

  /// Every category in the world, [category] first: Penguin Operations plus
  /// Habitat Engineering and Logistics & Supply, so the graph and the task
  /// lists have real area colouring rather than one flat colour.
  final List<CategoryDefinition> categories;

  final List<LabelDefinition> labels;

  /// Every R2-backed image entity in the manual world. The first nine remain
  /// separately exposed through [coverImages] for existing screenshot
  /// composition, while seeded demo worlds write this complete collection.
  final List<JournalImage> images;

  /// The original nine manual covers, retained as a stable screenshot subset.
  final List<JournalImage> coverImages;
  final List<Task> tasks;

  /// Checklists owned by tasks in this world, keyed into tasks through
  /// `TaskData.checklistIds`.
  final List<Checklist> checklists;

  /// Every checklist item referenced by [checklists].
  final List<ChecklistItem> checklistItems;

  /// Text entries with a `dateFrom`/`dateTo` span, linked from a task so the
  /// task shows logged time rather than `0m of 2h`.
  final List<JournalEntry> timeRecords;

  /// Short observations — one or two sentences each — linked to the tasks
  /// they belong to. They are what a task's linked-entries list, and the
  /// knowledge graph around it, actually has to show.
  final List<JournalEntry> entries;

  /// Expedition habits: two live daily habits under Penguin Operations and
  /// one retired habit, so the habits page has an inactive row to render as
  /// well as active ones.
  final List<HabitDefinition> habits;

  /// Completion history for the live habits, ending yesterday. The habits
  /// page reads a 14-day window, so [_habitHistoryDays] covers it with room
  /// left for the streak counts to be real.
  final List<HabitCompletionEntry> habitCompletions;

  /// Every `linked_entries` row in the world: task↔task, task↔note,
  /// task↔logged time and task↔photo. Written by the seeder after the
  /// entities themselves, since both endpoints must already exist.
  final List<EntryLink> links;

  /// Every journal entity in the world, in seeding (reference) order.
  List<JournalEntity> get journalEntities => [
    ...images,
    ...checklistItems,
    ...checklists,
    ...tasks,
    ...timeRecords,
    ...entries,
    ...habitCompletions,
  ];

  Task get orbitalHabitatTask => taskById(manualOrbitalHabitatTaskId);

  /// The single checklist attached to [orbitalHabitatTask].
  Checklist get habitatChecklist => checklists.singleWhere(
    (list) => list.meta.id == manualHabitatChecklistId,
  );

  /// The single time record linked from [orbitalHabitatTask].
  JournalEntry get habitatTimeRecord => timeRecords.singleWhere(
    (entry) => entry.meta.id == manualHabitatTimeRecordId,
  );
  Task get fishFeederTask => taskById(manualFishFeederTaskId);
  Task get sardineCargoTask => taskById(manualSardineCargoTaskId);
  Task get penguinPassengerTask => taskById(manualPenguinPassengerTaskId);

  /// Curated first page used by the Tasks manual screenshots.
  ///
  /// The Daily OS fixture resolves the remaining task entities through
  /// [entityById] without crowding this browse-page composition.
  List<Task> get taskBrowseTasks => [
    orbitalHabitatTask,
    fishFeederTask,
    sardineCargoTask,
    penguinPassengerTask,
  ];

  Task taskById(String id) => tasks.singleWhere((task) => task.meta.id == id);

  JournalImage coverImageById(String id) =>
      images.singleWhere((image) => image.meta.id == id);

  JournalEntity? entityById(String id) {
    for (final image in images) {
      if (id == image.meta.id) return image;
    }
    for (final task in tasks) {
      if (task.meta.id == id) return task;
    }
    for (final checklist in checklists) {
      if (checklist.meta.id == id) return checklist;
    }
    for (final item in checklistItems) {
      if (item.meta.id == id) return item;
    }
    for (final entry in timeRecords) {
      if (entry.meta.id == id) return entry;
    }
    for (final entry in entries) {
      if (entry.meta.id == id) return entry;
    }
    return null;
  }

  /// Materializes the original manual-cover subset from the same R2 catalog
  /// used in production.
  ///
  /// This synchronous helper is only for screenshot capture, which needs the
  /// pixels before its first frame. Production demo startup uses the
  /// fire-and-forget [DemoMediaHydrator] registration instead. [download] is
  /// injectable so focused fixture tests never need the network.
  Future<List<File>> installMedia(
    Directory documentsDirectory, {
    required Future<Uint8List> Function(Uri uri) download,
    required List<DemoMediaAsset> catalog,
  }) async {
    // The hydrator reports per-asset failures through a callback and
    // returns a count; without the first cause in the message, a screenshot
    // suite failing on a device only says "incomplete" and nothing about the
    // DNS, TLS or checksum problem behind it.
    Object? firstError;
    DemoMediaAsset? firstFailed;
    final hydrator = DemoMediaHydrator(
      root: documentsDirectory,
      assets: catalog,
      download: download,
      onError: (asset, error, _) {
        firstError ??= error;
        firstFailed ??= asset;
      },
    );
    try {
      final result = await hydrator.hydrate();
      if (!result.isComplete) {
        throw StateError(
          'Unable to hydrate every manual demo cover '
          '(${result.failed} failed, ${result.cancelled} cancelled)'
          '${firstFailed == null ? '' : ': ${firstFailed!.fileName}: $firstError'}',
        );
      }
    } finally {
      hydrator.dispose();
    }
    return [
      for (final asset in catalog)
        File(
          p.joinAll([
            documentsDirectory.path,
            ...asset.relativePath.split('/'),
          ]),
        ),
    ];
  }
}

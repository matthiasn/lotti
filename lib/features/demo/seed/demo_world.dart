import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/demo/seed/demo_dates.dart';
import 'package:lotti/features/demo/seed/demo_entity_factories.dart';
import 'package:lotti/features/demo/seed/demo_ids.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/utils/image_utils.dart';

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

final Map<String, String> manualDemoCoverAssets = <String, String>{
  manualHabitatCoverImageId:
      'assets/design_system/manual_task_cover_habitat.webp',
  manualRollCallCoverImageId:
      'assets/design_system/manual_task_cover_roll_call.webp',
  manualLaunchReviewCoverImageId:
      'assets/design_system/manual_task_cover_launch_review.webp',
  manualLunchCoverImageId: 'assets/design_system/manual_task_cover_lunch.webp',
  manualSardineFuturesCoverImageId:
      'assets/design_system/manual_task_cover_sardine_futures.webp',
  manualFishFeederCoverImageId:
      'assets/design_system/manual_task_cover_feeder.webp',
  manualSardineCargoCoverImageId:
      'assets/design_system/manual_task_cover_cargo.webp',
  manualPenguinPassengerCoverImageId:
      'assets/design_system/manual_task_cover_legal.webp',
  manualHeadsetWalkCoverImageId:
      'assets/design_system/manual_task_cover_headset_walk.webp',
};

// ---------------------------------------------------------------------------
// Expansion: the walkable world.
//
// Everything below is ADDITIVE. Eight manual pages quote the nine original
// task names as literal text and the screenshot suites reference them by id,
// so ids, names and list order above never change — the world only grows.
// ---------------------------------------------------------------------------

/// Habitat engineering: the pressure/air/water/power side of the colony.
const demoHabitatCategoryId = 'manual-habitat-engineering';

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
  // Photos: the nine bundled covers, attached to the task they picture and
  // to the expansion task that inherited the same artwork.
  (manualOrbitalHabitatTaskId, manualHabitatCoverImageId),
  (demoAirScrubbersTaskId, manualHabitatCoverImageId),
  (manualRollCallTaskId, manualRollCallCoverImageId),
  (demoChickDaycareTaskId, manualRollCallCoverImageId),
  (manualLaunchReviewTaskId, manualLaunchReviewCoverImageId),
  (demoLaunchRehearsalTaskId, manualLaunchReviewCoverImageId),
  (manualLunchTaskId, manualLunchCoverImageId),
  (demoMovieNightTaskId, manualLunchCoverImageId),
  (manualSardineFuturesTaskId, manualSardineFuturesCoverImageId),
  (demoKrillSupplierTaskId, manualSardineFuturesCoverImageId),
  (manualFishFeederTaskId, manualFishFeederCoverImageId),
  (demoWaterRecyclerTaskId, manualFishFeederCoverImageId),
  (manualSardineCargoTaskId, manualSardineCargoCoverImageId),
  (demoShuttleManifestTaskId, manualSardineCargoCoverImageId),
  (manualPenguinPassengerTaskId, manualPenguinPassengerCoverImageId),
  (demoCustomsEuropaTaskId, manualPenguinPassengerCoverImageId),
  (manualHeadsetWalkTaskId, manualHeadsetWalkCoverImageId),
  (demoIceRinkTaskId, manualHeadsetWalkCoverImageId),
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
    required this.coverImages,
    required this.tasks,
    required this.checklists,
    required this.checklistItems,
    required this.timeRecords,
    required this.entries,
    required this.links,
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
    final coverImages = manualDemoCoverAssets.entries.map((entry) {
      return JournalImage(
        meta: Metadata(
          id: entry.key,
          createdAt: anchor,
          updatedAt: anchor,
          dateFrom: anchor,
          dateTo: anchor,
          categoryId: manualDemoCategoryId,
        ),
        data: ImageData(
          capturedAt: anchor,
          imageId: '${entry.key}-file',
          imageFile: entry.value.split('/').last,
          imageDirectory: '/manual_demo/',
        ),
      );
    }).toList();

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
        checklistIds: checklistIds,
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

    // Short observations, spread over the past six weeks so the journal
    // timeline reads as lived-in rather than seeded in one burst.
    final notes = <JournalEntry>[
      note(
        id: demoUuid('note-seal-pressure'),
        from: dates.daysAgo(1, 8),
        text: t(
          'Bay A seals held 101.3 kPa all night.',
          'Die Dichtungen in Bucht A hielten die ganze Nacht 101,3 kPa.',
        ),
      ),
      note(
        id: demoUuid('note-scrubber-order'),
        from: dates.daysAgo(2, 11),
        categoryId: demoHabitatCategoryId,
        text: t(
          'Cartridge order confirmed, arrives on the next shuttle.',
          'Patronenbestellung bestätigt, kommt mit dem nächsten Shuttle.',
        ),
      ),
      note(
        id: demoUuid('note-humidity-reading'),
        from: dates.daysAgo(3, 15),
        categoryId: demoHabitatCategoryId,
        text: t(
          'Bay C is at 78% humidity, nine points up since Tuesday.',
          'Bucht C liegt bei 78 % Luftfeuchte, neun Punkte mehr als am Dienstag.',
        ),
      ),
      note(
        id: demoUuid('note-feeder-trajectory'),
        from: dates.daysAgo(4, 10),
        text: t(
          'The feeder still aims lunch at Mission Control.',
          'Der Automat zielt mit dem Mittagessen weiter auf die '
              'Missionskontrolle.',
        ),
      ),
      note(
        id: demoUuid('note-pallet-search'),
        from: dates.daysAgo(5, 14),
        categoryId: demoLogisticsCategoryId,
        text: t(
          'Pallet 14 is not in bay two. Checking the cold ring next.',
          'Palette 14 ist nicht in Bucht zwei. Als Nächstes prüfe ich den '
              'Kühlring.',
        ),
      ),
      note(
        id: demoUuid('note-krill-quote'),
        from: dates.daysAgo(7),
        categoryId: demoLogisticsCategoryId,
        text: t(
          'Europa Krill quoted 12% below our current supplier.',
          'Europa Krill bietet 12 % unter unserem jetzigen Lieferanten.',
        ),
      ),
      note(
        id: demoUuid('note-customs-form'),
        from: dates.daysAgo(8, 16),
        categoryId: demoLogisticsCategoryId,
        text: t(
          'Customs wants the pod seal certificates before Friday.',
          'Der Zoll will die Zertifikate der Kapseldichtungen vor Freitag.',
        ),
      ),
      note(
        id: demoUuid('note-weather-window'),
        from: dates.daysAgo(9, 7),
        text: t(
          'The ice pad clears at 06:40 with a light crosswind.',
          'Der Eisstartplatz ist ab 06:40 frei, bei leichtem Seitenwind.',
        ),
      ),
      note(
        id: demoUuid('note-rehearsal-gap'),
        from: dates.daysAgo(10, 17),
        text: t(
          'Rehearsal ran nine minutes long on the boarding step.',
          'Die Probe dauerte beim Einsteigen neun Minuten zu lang.',
        ),
      ),
      note(
        id: demoUuid('note-suit-sizes'),
        from: dates.daysAgo(12, 13),
        text: t(
          'Three flight suits need a wider flipper cut.',
          'Drei Fluganzüge brauchen einen weiteren Flossenschnitt.',
        ),
      ),
      note(
        id: demoUuid('note-newsletter-draft'),
        from: dates.daysAgo(14, 20),
        text: t(
          'The draft is done except for the launch section.',
          'Der Entwurf steht, bis auf den Startabschnitt.',
        ),
      ),
      note(
        id: demoUuid('note-daycare-rota'),
        from: dates.daysAgo(16, 8),
        text: t(
          'Two volunteers dropped out of the Thursday slot.',
          'Zwei Freiwillige sind für den Donnerstag abgesprungen.',
        ),
      ),
      note(
        id: demoUuid('note-movie-vote'),
        from: dates.daysAgo(18, 21),
        text: t(
          'The colony voted for the documentary about ice.',
          'Die Kolonie hat für die Doku über Eis gestimmt.',
        ),
      ),
      note(
        id: demoUuid('note-toboggan-injury'),
        from: dates.daysAgo(21, 15),
        text: t(
          'One sprained flipper, so we need softer landings.',
          'Eine verstauchte Flosse, wir brauchen weichere Landungen.',
        ),
      ),
      note(
        id: demoUuid('note-solar-tilt'),
        from: dates.daysAgo(24, 11),
        categoryId: demoHabitatCategoryId,
        text: t(
          'Tilt is four degrees off after the last burn.',
          'Die Neigung liegt nach dem letzten Manöver vier Grad daneben.',
        ),
      ),
      note(
        id: demoUuid('note-recycler-filter'),
        from: dates.daysAgo(27),
        categoryId: demoHabitatCategoryId,
        text: t(
          'The recycler filter was clogged with feather down.',
          'Der Filter des Aufbereiters war mit Daunen verstopft.',
        ),
      ),
      note(
        id: demoUuid('note-freezer-log'),
        from: dates.daysAgo(30, 12),
        text: t(
          'Freezer 3 logged a two-hour gap on Sunday.',
          'Kühler 3 hat am Sonntag eine Lücke von zwei Stunden protokolliert.',
        ),
      ),
      note(
        id: demoUuid('note-manifest-mismatch'),
        from: dates.daysAgo(33, 10),
        categoryId: demoLogisticsCategoryId,
        text: t(
          'The manifest says 40 pods, the dock counted 39.',
          'Die Frachtliste nennt 40 Kapseln, am Dock wurden 39 gezählt.',
        ),
      ),
      note(
        id: demoUuid('note-comms-tone'),
        from: dates.daysAgo(37, 18),
        text: t(
          'Mission Control wants fewer fish puns in the launch script.',
          'Die Missionskontrolle will weniger Fischwitze im Startskript.',
        ),
      ),
      note(
        id: demoUuid('note-roll-call-late'),
        from: dates.daysAgo(40, 19),
        text: t(
          'Sir Flaps-a-Lot answered roll call from the cargo netting.',
          'Sir Flatterviel meldete sich beim Appell aus dem Frachtnetz.',
        ),
      ),
    ];

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

    final expansionTimeRecords = <JournalEntry>[
      timeRecord(
        id: demoUuid('time-scrubber-swap'),
        weekdaysBack: 1,
        hour: 9,
        duration: const Duration(hours: 1, minutes: 25),
        categoryId: demoHabitatCategoryId,
        text: t(
          'Swapped cartridges in Bay A and B.',
          'Patronen in Bucht A und B getauscht.',
        ),
      ),
      timeRecord(
        id: demoUuid('time-humidity-hunt'),
        weekdaysBack: 1,
        hour: 14,
        duration: const Duration(hours: 2),
        categoryId: demoHabitatCategoryId,
        text: t(
          'Two hours chasing the humidity leak, no source yet.',
          'Zwei Stunden dem Feuchtigkeitsleck nachgejagt, noch keine Quelle.',
        ),
      ),
      timeRecord(
        id: demoUuid('time-pallet-walk'),
        weekdaysBack: 2,
        hour: 10,
        duration: const Duration(minutes: 50),
        categoryId: demoLogisticsCategoryId,
        text: t(
          'Walked the whole cold ring looking for pallet 14.',
          'Den ganzen Kühlring nach Palette 14 abgelaufen.',
        ),
      ),
      timeRecord(
        id: demoUuid('time-rehearsal-run'),
        weekdaysBack: 2,
        hour: 15,
        duration: const Duration(hours: 1, minutes: 40),
        text: t(
          'Full rehearsal run with the boarding crew.',
          'Komplette Probe mit der Einsteigemannschaft.',
        ),
      ),
      timeRecord(
        id: demoUuid('time-freezer-audit'),
        weekdaysBack: 3,
        hour: 11,
        duration: const Duration(hours: 2, minutes: 15),
        text: t(
          'Reconciled two weeks of freezer logs.',
          'Zwei Wochen Kühlprotokolle abgeglichen.',
        ),
      ),
      timeRecord(
        id: demoUuid('time-newsletter-draft'),
        weekdaysBack: 4,
        hour: 16,
        duration: const Duration(minutes: 45),
        text: t(
          'Wrote the colony newsletter draft.',
          'Den Entwurf für den Koloniebrief geschrieben.',
        ),
      ),
      timeRecord(
        id: demoUuid('time-solar-measure'),
        weekdaysBack: 5,
        hour: 9,
        duration: const Duration(hours: 1),
        categoryId: demoHabitatCategoryId,
        text: t(
          'Measured the array tilt against the sun sensor.',
          'Die Neigung der Solarfläche am Sonnensensor gemessen.',
        ),
      ),
      timeRecord(
        id: demoUuid('time-recycler-clean'),
        weekdaysBack: 6,
        hour: 13,
        duration: const Duration(hours: 1, minutes: 10),
        categoryId: demoHabitatCategoryId,
        text: t(
          'Cleaned the recycler filter housing.',
          'Das Filtergehäuse des Aufbereiters gereinigt.',
        ),
      ),
      timeRecord(
        id: demoUuid('time-manifest-count'),
        weekdaysBack: 7,
        hour: 10,
        duration: const Duration(minutes: 55),
        categoryId: demoLogisticsCategoryId,
        text: t(
          'Counted pods on the dock with the shuttle crew.',
          'Kapseln am Dock mit der Shuttle-Crew gezählt.',
        ),
      ),
      timeRecord(
        id: demoUuid('time-comms-rewrite'),
        weekdaysBack: 8,
        hour: 14,
        duration: const Duration(minutes: 35),
        text: t(
          'Rewrote the launch script intro.',
          'Die Einleitung des Startskripts neu geschrieben.',
        ),
      ),
    ];

    final expansionTasks = <Task>[
      // --- Cluster 1: launch readiness -----------------------------------
      task(
        id: demoLaunchCommsTaskId,
        title: t('Draft the launch comms plan', 'Kommunikationsplan entwerfen'),
        description: t(
          'Agree who announces what on launch day, and in which order.',
          'Klärt, wer am Starttag was verkündet — und in welcher Reihenfolge.',
        ),
        status: openAt('launch-comms', 9),
        priority: TaskPriority.p2Medium,
        due: dates.tomorrow(9),
        coverArtId: null,
        labelIds: const [manualDemoProjectLabelId],
        estimate: const Duration(minutes: 45),
        createdAt: dates.daysAgo(9),
        dateFrom: dates.daysAgo(9),
      ),
      task(
        id: demoIcePadWeatherTaskId,
        title: t(
          'Check the ice-pad weather window',
          'Wetterfenster am Eisstartplatz prüfen',
        ),
        description: t(
          'Confirm the crosswind stays under limits for the launch slot.',
          'Bestätigt, dass der Seitenwind im Startfenster unter dem Limit '
              'bleibt.',
        ),
        status: runningAt('ice-pad-weather', 2),
        priority: TaskPriority.p1High,
        due: dates.today(17),
        coverArtId: null,
        labelIds: const [manualDemoProjectLabelId, demoResearchLabelId],
        estimate: const Duration(minutes: 30),
        createdAt: dates.daysAgo(11),
        dateFrom: dates.daysAgo(2),
      ),
      task(
        id: demoColdChainAuditTaskId,
        title: t(
          'Audit the cold-chain freezer logs',
          'Kühlketten-Protokolle prüfen',
        ),
        description: t(
          'Find every gap in the freezer logs before the sardines ship.',
          'Findet jede Lücke in den Kühlprotokollen, bevor die Sardinen '
              'verschifft werden.',
        ),
        status: doneAt('cold-chain-audit', 1),
        priority: TaskPriority.p2Medium,
        due: dates.inDays(2, 12),
        coverArtId: null,
        labelIds: const [manualDemoProjectLabelId],
        estimate: const Duration(hours: 2),
        createdAt: dates.daysAgo(30),
        dateFrom: dates.daysAgo(6),
        checklistIds: [demoFreezerChecklistId],
      ),
      task(
        id: demoLaunchRehearsalTaskId,
        title: t('Run the launch-day rehearsal', 'Startprobe durchführen'),
        description: t(
          'Walk the whole launch morning once, at full speed, with the crew.',
          'Geht den ganzen Startmorgen einmal in Echtzeit mit der Crew durch.',
        ),
        status: groomedAt('launch-rehearsal', 4),
        priority: TaskPriority.p1High,
        due: dates.inDays(3, 9),
        coverArtId: manualLaunchReviewCoverImageId,
        labelIds: const [manualDemoProjectLabelId],
        estimate: const Duration(hours: 3),
        createdAt: dates.daysAgo(13),
        dateFrom: dates.daysAgo(4),
        checklistIds: [demoRehearsalChecklistId],
      ),
      task(
        id: demoFlightSuitTaskId,
        title: t('Fit the penguin flight suits', 'Pinguin-Fluganzüge anpassen'),
        description: t(
          'Measure every flyer and send the three wide-flipper suits back.',
          'Vermesst jeden Flieger und schickt die drei Anzüge mit weiten '
              'Flossen zurück.',
        ),
        status: openAt('flight-suit', 12),
        priority: TaskPriority.p3Low,
        due: dates.nextMonday(9),
        coverArtId: null,
        labelIds: const [manualDemoProjectLabelId, demoWaitingLabelId],
        estimate: const Duration(hours: 1, minutes: 30),
        createdAt: dates.daysAgo(12),
        dateFrom: dates.daysAgo(12),
      ),
      // --- Cluster 2: habitat engineering --------------------------------
      task(
        id: demoAirScrubbersTaskId,
        title: t(
          'Replace the air scrubber cartridges',
          'Filterpatronen der Luftreinigung tauschen',
        ),
        description: t(
          'Swap all four cartridges in Bay A before the CO2 alarm gets bored.',
          'Tauscht alle vier Patronen in Bucht A, bevor dem CO2-Alarm '
              'langweilig wird.',
        ),
        status: runningAt('air-scrubbers', 2),
        priority: TaskPriority.p0Urgent,
        due: dates.today(17),
        coverArtId: manualHabitatCoverImageId,
        labelIds: const [manualDemoCriticalLabelId],
        estimate: const Duration(hours: 2),
        categoryId: demoHabitatCategoryId,
        createdAt: dates.daysAgo(5),
        dateFrom: dates.daysAgo(2),
        checklistIds: [demoScrubberChecklistId],
      ),
      task(
        id: demoHumiditySpikeTaskId,
        title: t(
          'Trace the humidity spike in Bay C',
          'Feuchtigkeitsspitze in Bucht C aufspüren',
        ),
        description: t(
          'Nine points in three days is a leak, not weather.',
          'Neun Punkte in drei Tagen sind ein Leck, kein Wetter.',
        ),
        status: TaskStatus.blocked(
          id: 'status-humidity-spike',
          createdAt: dates.daysAgo(3),
          utcOffset: 120,
          reason: t(
            'Waiting on the Bay C sensor swap',
            'Wartet auf den Sensortausch in Bucht C',
          ),
        ),
        priority: TaskPriority.p1High,
        due: dates.overdue(2),
        coverArtId: null,
        labelIds: const [manualDemoCriticalLabelId, demoBlockedLabelId],
        estimate: const Duration(hours: 3),
        categoryId: demoHabitatCategoryId,
        createdAt: dates.daysAgo(8),
        dateFrom: dates.daysAgo(3),
      ),
      task(
        id: demoIceRinkTaskId,
        title: t(
          'Resurface the habitat ice rink',
          'Eisbahn im Habitat neu aufbereiten',
        ),
        description: t(
          'The colony rink has more grooves than ice. Book the resurfacer.',
          'Die Kolonie-Eisbahn hat mehr Rillen als Eis. Bucht die Maschine.',
        ),
        status: openAt('ice-rink', 15),
        priority: TaskPriority.p3Low,
        due: dates.nextMonday(15),
        coverArtId: manualHeadsetWalkCoverImageId,
        labelIds: const [],
        estimate: const Duration(hours: 2),
        categoryId: demoHabitatCategoryId,
        createdAt: dates.daysAgo(15),
        dateFrom: dates.daysAgo(15),
      ),
      task(
        id: demoSolarArrayTaskId,
        title: t(
          'Retune the solar array tilt',
          'Neigung der Solarfläche justieren',
        ),
        description: t(
          'Four degrees of drift is costing the habitat a third of its power.',
          'Vier Grad Abweichung kosten das Habitat ein Drittel seiner '
              'Leistung.',
        ),
        status: groomedAt('solar-array', 6),
        priority: TaskPriority.p2Medium,
        due: dates.inDays(4, 12),
        coverArtId: null,
        labelIds: const [demoResearchLabelId],
        estimate: const Duration(hours: 1, minutes: 30),
        categoryId: demoHabitatCategoryId,
        createdAt: dates.daysAgo(24),
        dateFrom: dates.daysAgo(6),
      ),
      task(
        id: demoWaterRecyclerTaskId,
        title: t('Service the water recycler', 'Wasseraufbereiter warten'),
        description: t(
          'Clean the filter housing and log the throughput afterwards.',
          'Reinigt das Filtergehäuse und protokolliert danach den Durchsatz.',
        ),
        status: doneAt('water-recycler', 5),
        priority: TaskPriority.p2Medium,
        due: dates.inDays(5, 9),
        coverArtId: manualFishFeederCoverImageId,
        labelIds: const [],
        estimate: const Duration(hours: 1, minutes: 30),
        categoryId: demoHabitatCategoryId,
        createdAt: dates.daysAgo(27),
        dateFrom: dates.daysAgo(6, 13),
      ),
      // --- Cluster 3: logistics & supply ---------------------------------
      task(
        id: demoSquidPalletTaskId,
        title: t(
          'Find the missing squid pallet',
          'Verschwundene Tintenfisch-Palette finden',
        ),
        description: t(
          'Pallet 14 left Europa and never reached the cold ring.',
          'Palette 14 hat Europa verlassen und den Kühlring nie erreicht.',
        ),
        status: runningAt('squid-pallet', 5),
        priority: TaskPriority.p1High,
        due: dates.today(17),
        coverArtId: null,
        labelIds: const [manualDemoProjectLabelId],
        estimate: const Duration(hours: 1),
        categoryId: demoLogisticsCategoryId,
        createdAt: dates.daysAgo(6),
        dateFrom: dates.daysAgo(5),
        checklistIds: [demoPalletChecklistId],
      ),
      task(
        id: demoKrillSupplierTaskId,
        title: t(
          'Shortlist a second krill supplier',
          'Zweiten Krill-Lieferanten finden',
        ),
        description: t(
          'One supplier for the whole colony is one storm away from trouble.',
          'Ein Lieferant für die ganze Kolonie ist einen Sturm vom Problem '
              'entfernt.',
        ),
        status: openAt('krill-supplier', 7),
        priority: TaskPriority.p2Medium,
        due: null,
        coverArtId: manualSardineFuturesCoverImageId,
        labelIds: const [demoResearchLabelId],
        estimate: const Duration(hours: 2),
        categoryId: demoLogisticsCategoryId,
        createdAt: dates.daysAgo(20),
        dateFrom: dates.daysAgo(7),
      ),
      task(
        id: demoShuttleManifestTaskId,
        title: t(
          'Reconcile the shuttle manifest',
          'Frachtliste des Shuttles abgleichen',
        ),
        description: t(
          'The manifest and the dock disagree by one pod. Find out which.',
          'Frachtliste und Dock unterscheiden sich um eine Kapsel. Findet '
              'heraus, welche.',
        ),
        status: openAt('shuttle-manifest', 1),
        priority: TaskPriority.p2Medium,
        due: dates.tomorrow(9),
        coverArtId: manualSardineCargoCoverImageId,
        labelIds: const [manualDemoProjectLabelId],
        estimate: const Duration(hours: 1),
        categoryId: demoLogisticsCategoryId,
        createdAt: dates.daysAgo(33),
        dateFrom: dates.daysAgo(1),
        checklistIds: [demoManifestChecklistId],
      ),
      task(
        id: demoPodSealOrderTaskId,
        title: t(
          'Order replacement pod seals',
          'Ersatzdichtungen für Kapseln bestellen',
        ),
        description: t(
          'Customs will not clear a pod whose seal certificate has expired.',
          'Der Zoll gibt keine Kapsel frei, deren Dichtungszertifikat '
              'abgelaufen ist.',
        ),
        status: openAt('pod-seal-order', 10),
        priority: TaskPriority.p1High,
        due: dates.overdue(5),
        coverArtId: null,
        labelIds: const [demoWaitingLabelId],
        estimate: const Duration(minutes: 30),
        categoryId: demoLogisticsCategoryId,
        createdAt: dates.daysAgo(10),
        dateFrom: dates.daysAgo(10),
      ),
      task(
        id: demoCustomsEuropaTaskId,
        title: t('Clear customs on Europa', 'Zoll auf Europa erledigen'),
        description: t(
          'File the seal certificates and the passenger question together.',
          'Reicht die Dichtungszertifikate und die Passagierfrage zusammen '
              'ein.',
        ),
        status: TaskStatus.onHold(
          id: 'status-customs-europa',
          createdAt: dates.daysAgo(8),
          utcOffset: 120,
          reason: t(
            'Europa customs is closed until Monday',
            'Der Zoll von Europa ist bis Montag geschlossen',
          ),
        ),
        priority: TaskPriority.p2Medium,
        due: dates.inDays(3, 17),
        coverArtId: manualPenguinPassengerCoverImageId,
        labelIds: const [demoWaitingLabelId],
        estimate: const Duration(hours: 1),
        categoryId: demoLogisticsCategoryId,
        createdAt: dates.daysAgo(18),
        dateFrom: dates.daysAgo(8),
      ),
      // --- Cluster 4: colony life ----------------------------------------
      task(
        id: demoColonyNewsletterTaskId,
        title: t('Write the colony newsletter', 'Koloniebrief schreiben'),
        description: t(
          'Four sections, one photo, and no more than one fish pun.',
          'Vier Abschnitte, ein Foto und höchstens ein Fischwitz.',
        ),
        status: openAt('colony-newsletter', 4),
        priority: TaskPriority.p3Low,
        due: dates.tomorrow(9),
        coverArtId: null,
        labelIds: const [],
        estimate: const Duration(hours: 1),
        createdAt: dates.daysAgo(14),
        dateFrom: dates.daysAgo(4),
        checklistIds: [demoNewsletterChecklistId],
      ),
      task(
        id: demoChickDaycareTaskId,
        title: t(
          'Refill the chick daycare rota',
          'Dienstplan der Kükenbetreuung füllen',
        ),
        description: t(
          'Thursday lost two volunteers and the chicks noticed immediately.',
          'Am Donnerstag fehlen zwei Freiwillige, und die Küken haben es '
              'sofort gemerkt.',
        ),
        status: groomedAt('chick-daycare', 16),
        priority: TaskPriority.p2Medium,
        due: dates.inDays(5, 17),
        coverArtId: manualRollCallCoverImageId,
        labelIds: const [demoWaitingLabelId],
        estimate: const Duration(minutes: 45),
        createdAt: dates.daysAgo(16),
        dateFrom: dates.daysAgo(16),
      ),
      task(
        id: demoMovieNightTaskId,
        title: t(
          'Pick the film for colony night',
          'Film für den Kolonieabend wählen',
        ),
        description: t(
          'The colony voted for the ice documentary. Book the dome.',
          'Die Kolonie hat für die Eis-Doku gestimmt. Bucht die Kuppel.',
        ),
        status: openAt('movie-night', 18),
        priority: TaskPriority.p3Low,
        due: dates.nextMonday(12, plusDays: 2),
        coverArtId: manualLunchCoverImageId,
        labelIds: const [],
        estimate: const Duration(minutes: 20),
        createdAt: dates.daysAgo(18),
        dateFrom: dates.daysAgo(18),
      ),
      task(
        id: demoTobogganingTaskId,
        title: t('Restart the tobogganing league', 'Rodel-Liga wieder starten'),
        description: t(
          'Softer landings first, then a rematch against Bay C.',
          'Erst weichere Landungen, dann ein Rückspiel gegen Bucht C.',
        ),
        status: groomedAt('tobogganing', 21),
        priority: TaskPriority.p3Low,
        due: null,
        coverArtId: null,
        labelIds: const [],
        estimate: const Duration(hours: 1),
        createdAt: dates.daysAgo(21),
        dateFrom: dates.daysAgo(21),
      ),
    ];

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
      coverImages: coverImages,
      checklists: [habitatChecklist, ...expansionChecklists],
      checklistItems: [
        ...habitatChecklistItems,
        ...rehearsalItems,
        ...scrubberItems,
        ...palletItems,
        ...newsletterItems,
        ...freezerItems,
        ...manifestItems,
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

  /// Every `linked_entries` row in the world: task↔task, task↔note,
  /// task↔logged time and task↔photo. Written by the seeder after the
  /// entities themselves, since both endpoints must already exist.
  final List<EntryLink> links;

  /// Every journal entity in the world, in seeding (reference) order.
  List<JournalEntity> get journalEntities => [
    ...coverImages,
    ...checklistItems,
    ...checklists,
    ...tasks,
    ...timeRecords,
    ...entries,
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
      coverImages.singleWhere((image) => image.meta.id == id);

  JournalEntity? entityById(String id) {
    for (final coverImage in coverImages) {
      if (id == coverImage.meta.id) return coverImage;
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

  /// Copies the bundled artwork into the same document-relative path used by
  /// production cover-art widgets.
  ///
  /// Reads asset files straight from the working directory, which is where
  /// `flutter test` runs — production seeding uses [installMediaFromBundle]
  /// instead, because a packaged app has no `assets/` directory on disk.
  Future<List<File>> installMedia(Directory documentsDirectory) async {
    final installedFiles = <File>[];
    for (final coverImage in coverImages) {
      final target = File(
        getFullImagePath(
          coverImage,
          documentsDirectory: documentsDirectory.path,
        ),
      );
      await target.parent.create(recursive: true);
      installedFiles.add(
        await File(
          manualDemoCoverAssets[coverImage.meta.id]!,
        ).copy(target.path),
      );
    }
    return installedFiles;
  }

  /// Copies the bundled artwork out of [bundle] (e.g. `rootBundle`) into the
  /// document-relative paths used by production cover-art widgets.
  ///
  /// The production twin of [installMedia]: the nine cover webp files ship
  /// inside the app bundle (`assets/design_system/`), so seeding a demo world
  /// on a device must read them through the asset bundle rather than dart:io.
  Future<List<File>> installMediaFromBundle(
    AssetBundle bundle,
    Directory documentsDirectory,
  ) async {
    final installedFiles = <File>[];
    for (final coverImage in coverImages) {
      final target = File(
        getFullImagePath(
          coverImage,
          documentsDirectory: documentsDirectory.path,
        ),
      );
      await target.parent.create(recursive: true);
      final data = await bundle.load(
        manualDemoCoverAssets[coverImage.meta.id]!,
      );
      await target.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      installedFiles.add(target);
    }
    return installedFiles;
  }
}

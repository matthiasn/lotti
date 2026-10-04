part of 'demo_world.dart';

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

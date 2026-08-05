import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/demo/seed/demo_entity_factories.dart';
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

const manualOrbitalHabitatTaskId = 'task-orbital-habitat';
const manualHabitatChecklistId = 'manual-habitat-checklist';
const manualHabitatSealsItemId = 'manual-habitat-item-seals';
const manualHabitatRollCallItemId = 'manual-habitat-item-roll-call';
const manualHabitatCargoItemId = 'manual-habitat-item-cargo';
const manualHabitatClearanceItemId = 'manual-habitat-item-clearance';
const manualHabitatTimeRecordId = 'manual-habitat-time-record';
const manualRollCallTaskId = 'task-emperor-penguin-roll-call';
const manualLaunchReviewTaskId = 'task-project-waddle-launch-review';
const manualLunchTaskId = 'task-coffee-is-not-a-vegetable';
const manualSardineFuturesTaskId = 'task-negotiate-sardine-futures';
const manualFishFeederTaskId = 'task-zero-gravity-feeder';
const manualSardineCargoTaskId = 'task-sardine-cargo';
const manualPenguinPassengerTaskId = 'task-penguin-passenger';
const manualHeadsetWalkTaskId = 'task-walk-without-headset';
const manualHabitatCoverImageId = 'manual-penguin-habitat-cover';
const manualRollCallCoverImageId = 'manual-penguin-roll-call-cover';
const manualLaunchReviewCoverImageId = 'manual-penguin-launch-review-cover';
const manualLunchCoverImageId = 'manual-penguin-lunch-cover';
const manualSardineFuturesCoverImageId = 'manual-penguin-sardine-futures-cover';
const manualFishFeederCoverImageId = 'manual-penguin-feeder-cover';
const manualSardineCargoCoverImageId = 'manual-penguin-cargo-cover';
const manualPenguinPassengerCoverImageId = 'manual-penguin-legal-cover';
const manualHeadsetWalkCoverImageId = 'manual-penguin-headset-walk-cover';

const manualDemoCoverAssets = <String, String>{
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
    required this.labels,
    required this.coverImages,
    required this.tasks,
    required this.checklists,
    required this.checklistItems,
    required this.timeRecords,
  });

  /// Builds the Intergalactic Penguin Logistics world.
  ///
  /// [translate] resolves every user-visible string; it defaults to the
  /// manual screenshot suites' `LOTTI_MANUAL_LOCALE` environment contract
  /// (English when unset). [now] rebases every date in the world by the same
  /// delta relative to [manualDemoNow]; it defaults to the fixed clock, so
  /// screenshot output stays byte-identical to the historical fixture.
  factory ManualDemoWorld.penguinLogistics({
    DemoSeedText? translate,
    DateTime? now,
  }) {
    final t = translate ?? demoSeedTextFromEnvironment();
    final anchor = now ?? manualDemoNow;

    /// Shifts a date authored against the fixed [manualDemoNow] clock onto
    /// the [anchor] timeline. Identity when [now] is not supplied.
    DateTime rebase(DateTime original) =>
        anchor.add(original.difference(manualDemoNow));

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
      required DateTime due,
      required String coverArtId,
      required List<String> labelIds,
      required Duration estimate,
      List<String>? checklistIds,
    }) {
      final base = TestTaskFactory.create(
        id: id,
        title: title,
        plainText: description,
        createdAt: anchor.subtract(const Duration(days: 2)),
        dateFrom: anchor,
        dateTo: anchor.add(estimate),
        status: status,
        statusHistory: [status],
        categoryId: manualDemoCategoryId,
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
    }) {
      return ChecklistItem(
        meta: TestMetadataFactory.create(
          id: id,
          createdAt: anchor.subtract(const Duration(days: 1)),
          categoryId: manualDemoCategoryId,
        ),
        data: ChecklistItemData(
          id: id,
          title: title,
          isChecked: isChecked,
          linkedChecklists: const [manualHabitatChecklistId],
          checkedAt: isChecked ? anchor.subtract(checkedAgo) : null,
        ),
      );
    }

    // The habitat inspection is the task the manual follows end to end, so it
    // is the one fixture that carries a checklist and a time record: the
    // screenshots have to show a task as a *record of work*, not an empty
    // shell.
    final checklistItems = <ChecklistItem>[
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
          for (final item in checklistItems) item.meta.id,
        ],
        linkedTasks: const [manualOrbitalHabitatTaskId],
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

    return ManualDemoWorld._(
      category: category,
      labels: labels,
      coverImages: coverImages,
      checklists: [habitatChecklist],
      checklistItems: checklistItems,
      timeRecords: [habitatTimeRecord],
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
          due: rebase(DateTime(2026, 7, 17, 9)),
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
          due: rebase(DateTime(2026, 7, 17, 12)),
          coverArtId: manualHabitatCoverImageId,
          labelIds: const [
            manualDemoProjectLabelId,
            manualDemoCriticalLabelId,
          ],
          estimate: const Duration(hours: 2),
          checklistIds: const [manualHabitatChecklistId],
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
          due: rebase(DateTime(2026, 7, 17, 12)),
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
          due: rebase(DateTime(2026, 7, 17, 13)),
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
          due: rebase(DateTime(2026, 7, 17, 14, 30)),
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
          due: rebase(DateTime(2026, 7, 17, 15)),
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
          due: rebase(DateTime(2026, 7, 18, 9)),
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
          due: rebase(DateTime(2026, 7, 20, 16)),
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
          due: rebase(DateTime(2026, 7, 17, 18)),
          coverArtId: manualHeadsetWalkCoverImageId,
          labelIds: const [],
          estimate: const Duration(minutes: 30),
        ),
      ],
    );
  }

  final CategoryDefinition category;
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

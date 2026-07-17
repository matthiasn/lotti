import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/utils/image_utils.dart';

import 'entity_factories.dart';

/// Fixed clock shared by the manual screenshot fixtures.
final manualDemoNow = DateTime(2026, 7, 17, 10, 30);

const manualDemoCategoryId = 'manual-penguin-ops';
const manualDemoProjectLabelId = 'manual-project-waddle';
const manualDemoCriticalLabelId = 'manual-habitat-critical';

const manualOrbitalHabitatTaskId = 'task-orbital-habitat';
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

/// One deterministic, production-shaped data set reused across manual pages.
///
/// Keeping tasks, categories, labels, and cover images here prevents the task
/// list, task detail, and Daily OS agenda screenshots from drifting into
/// unrelated demo universes.
class ManualDemoWorld {
  ManualDemoWorld._({
    required this.category,
    required this.labels,
    required this.coverImages,
    required this.tasks,
  });

  factory ManualDemoWorld.penguinLogistics() {
    final category = CategoryDefinition(
      id: manualDemoCategoryId,
      createdAt: manualDemoNow,
      updatedAt: manualDemoNow,
      name: 'Penguin Operations',
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
        createdAt: manualDemoNow,
        updatedAt: manualDemoNow,
        vectorClock: null,
        private: false,
      ),
      LabelDefinition(
        id: manualDemoCriticalLabelId,
        name: 'Habitat critical',
        color: '#FBA337',
        createdAt: manualDemoNow,
        updatedAt: manualDemoNow,
        vectorClock: null,
        private: false,
      ),
    ];
    final coverImages = manualDemoCoverAssets.entries.map((entry) {
      return JournalImage(
        meta: Metadata(
          id: entry.key,
          createdAt: manualDemoNow,
          updatedAt: manualDemoNow,
          dateFrom: manualDemoNow,
          dateTo: manualDemoNow,
          categoryId: manualDemoCategoryId,
        ),
        data: ImageData(
          capturedAt: manualDemoNow,
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
    }) {
      final base = TestTaskFactory.create(
        id: id,
        title: title,
        plainText: description,
        createdAt: manualDemoNow.subtract(const Duration(days: 2)),
        dateFrom: manualDemoNow,
        dateTo: manualDemoNow.add(estimate),
        status: status,
        statusHistory: [status],
        categoryId: manualDemoCategoryId,
        estimate: estimate,
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
      createdAt: manualDemoNow.subtract(const Duration(hours: 2)),
      utcOffset: 120,
    );
    final feederStatus = TaskStatus.open(
      id: 'status-feeder-open',
      createdAt: manualDemoNow.subtract(const Duration(days: 1)),
      utcOffset: 120,
    );
    final cargoStatus = TaskStatus.groomed(
      id: 'status-cargo-groomed',
      createdAt: manualDemoNow.subtract(const Duration(hours: 20)),
      utcOffset: 120,
    );
    final passengerStatus = TaskStatus.open(
      id: 'status-passenger-open',
      createdAt: manualDemoNow.subtract(const Duration(hours: 10)),
      utcOffset: 120,
    );
    final agendaStatus = TaskStatus.open(
      id: 'status-agenda-open',
      createdAt: manualDemoNow.subtract(const Duration(days: 1)),
      utcOffset: 120,
    );

    return ManualDemoWorld._(
      category: category,
      labels: labels,
      coverImages: coverImages,
      tasks: [
        task(
          id: manualRollCallTaskId,
          title: 'Emperor penguin roll call',
          description:
              'Count every expedition penguin, check the tiny oxygen packs, '
              'and record any suspiciously formal salutes.',
          status: agendaStatus,
          priority: TaskPriority.p2Medium,
          due: DateTime(2026, 7, 17, 9),
          coverArtId: manualRollCallCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(minutes: 30),
        ),
        task(
          id: manualOrbitalHabitatTaskId,
          title: 'Inspect orbital penguin habitat',
          description:
              'Inspect pressure seals, confirm all 37 emperor penguins are '
              'present, and route the sardine cargo pods before the live '
              'Project Waddle demonstration.',
          status: orbitalStatus,
          priority: TaskPriority.p1High,
          due: DateTime(2026, 7, 17, 12),
          coverArtId: manualHabitatCoverImageId,
          labelIds: const [
            manualDemoProjectLabelId,
            manualDemoCriticalLabelId,
          ],
          estimate: const Duration(hours: 2),
        ),
        task(
          id: manualLaunchReviewTaskId,
          title: 'Project Waddle launch review',
          description:
              'Review the ice-pad trajectory, confirm the snack manifest, '
              'and make sure Mission Control has removed the fish-shaped '
              'cursor from the launch display.',
          status: agendaStatus,
          priority: TaskPriority.p1High,
          due: DateTime(2026, 7, 17, 12),
          coverArtId: manualLaunchReviewCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(minutes: 45),
        ),
        task(
          id: manualLunchTaskId,
          title: 'Lunch (coffee is not a vegetable)',
          description:
              'Eat something recognizable as food before the robot '
              'nutritionist files another orbital wellness incident.',
          status: agendaStatus,
          priority: TaskPriority.p3Low,
          due: DateTime(2026, 7, 17, 13),
          coverArtId: manualLunchCoverImageId,
          labelIds: const [],
          estimate: const Duration(hours: 1),
        ),
        task(
          id: manualSardineFuturesTaskId,
          title: 'Negotiate sardine futures',
          description:
              "Lock the colony's Q3 sardine price before the Europa exchange "
              'discovers why the emergency fish ceiling is shaped like a '
              'penguin.',
          status: agendaStatus,
          priority: TaskPriority.p1High,
          due: DateTime(2026, 7, 17, 14, 30),
          coverArtId: manualSardineFuturesCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(hours: 1, minutes: 30),
        ),
        task(
          id: manualFishFeederTaskId,
          title: 'Recalibrate the zero-gravity fish feeder',
          description:
              'Run the low-orbit sardine test and stop the feeder from '
              'launching lunch toward Mission Control.',
          status: feederStatus,
          priority: TaskPriority.p0Urgent,
          due: DateTime(2026, 7, 17, 15),
          coverArtId: manualFishFeederCoverImageId,
          labelIds: const [manualDemoCriticalLabelId],
          estimate: const Duration(hours: 1, minutes: 30),
        ),
        task(
          id: manualSardineCargoTaskId,
          title: 'Confirm the interplanetary sardine cargo pods',
          description:
              'Reconcile the cold-chain manifest with the colony dashboard '
              'before the next supply shuttle leaves Europa.',
          status: cargoStatus,
          priority: TaskPriority.p2Medium,
          due: DateTime(2026, 7, 18, 9),
          coverArtId: manualSardineCargoCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(minutes: 45),
        ),
        task(
          id: manualPenguinPassengerTaskId,
          title: 'Ask Legal whether a penguin is a passenger',
          description:
              'Resolve whether Sir Flaps-a-Lot needs a boarding pass or a '
              'cargo declaration before launch.',
          status: passengerStatus,
          priority: TaskPriority.p3Low,
          due: DateTime(2026, 7, 20, 16),
          coverArtId: manualPenguinPassengerCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(minutes: 30),
        ),
        task(
          id: manualHeadsetWalkTaskId,
          title: 'Walk without a headset',
          description:
              'Take one quiet lap around the orbital ice garden without '
              'turning it into a briefing, podcast, or emergency call.',
          status: agendaStatus,
          priority: TaskPriority.p3Low,
          due: DateTime(2026, 7, 17, 18),
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

  Task get orbitalHabitatTask => taskById(manualOrbitalHabitatTaskId);
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
    return null;
  }

  /// Copies the bundled artwork into the same document-relative path used by
  /// production cover-art widgets.
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
}

/// Primes the exact production [ResizeImage] keys with the decoded cover art.
///
/// The headless Flutter test engine can leave resized WebP decoding pending
/// indefinitely even though the raw file decodes successfully. Production
/// widgets still construct and resolve their normal providers; this helper
/// only seeds the test image cache before the first frame so screenshots paint
/// the same bitmap deterministically.
Future<void> primeManualDemoCoverArt(
  WidgetTester tester, {
  required Directory documentsDirectory,
  required ManualDemoWorld world,
  List<int> extents = const [48, 96, 144, 216, 1280, 2048, 3072],
  Set<String>? imageIds,
}) async {
  await tester.runAsync(() async {
    final coverImages = imageIds == null
        ? world.coverImages
        : world.coverImages.where(
            (coverImage) => imageIds.contains(coverImage.meta.id),
          );
    for (final coverImage in coverImages) {
      final file = File(
        getFullImagePath(
          coverImage,
          documentsDirectory: documentsDirectory.path,
        ),
      );
      final fileImage = FileImage(file);
      final bytes = await file.readAsBytes();
      final cache = PaintingBinding.instance.imageCache;
      for (final extent in extents) {
        final provider = ResizeImage(
          fileImage,
          width: extent,
          height: extent,
          policy: ResizeImagePolicy.fit,
        );
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: extent,
          allowUpscaling: false,
        );
        final frame = await codec.getNextFrame();
        final key = await provider.obtainKey(ImageConfiguration.empty);
        cache
          ..evict(key)
          ..putIfAbsent(
            key,
            () => OneFrameImageStreamCompleter(
              SynchronousFuture(
                ImageInfo(image: frame.image.clone()),
              ),
            ),
          );
        frame.image.dispose();
        codec.dispose();
      }
    }
  });
}

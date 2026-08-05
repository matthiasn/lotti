import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/seed/demo_entity_factories.dart';
import 'package:lotti/features/demo/seed/demo_ids.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';

final String demoTutorialTaskId = demoUuid('demo-tutorial-first-steps');
final String demoTutorialChecklistId = demoUuid('demo-tutorial-checklist');
final String demoTutorialCheckItemId = demoUuid('demo-tutorial-item-check');
final String demoTutorialTimerItemId = demoUuid('demo-tutorial-item-timer');
final String demoTutorialAddItemItemId = demoUuid(
  'demo-tutorial-item-add-item',
);
final String demoTutorialCreateTaskItemId = demoUuid(
  'demo-tutorial-item-create-task',
);
final String demoTutorialVoiceNoteItemId = demoUuid(
  'demo-tutorial-item-voice-note',
);

/// The guided "first steps" content seeded into the demo world ON TOP of
/// [ManualDemoWorld.penguinLogistics].
///
/// Deliberately NOT part of the penguin-logistics fixture: the manual
/// screenshot suites must stay pixel-identical, so this task exists only in
/// the seeded demo world, where it gives a new user five concrete things to
/// try.
class DemoTutorialContent {
  DemoTutorialContent._({
    required this.task,
    required this.checklist,
    required this.checklistItems,
    required this.images,
    required this.links,
  });

  /// Builds the tutorial task with its "Learn the ropes" checklist.
  ///
  /// [translate] and [now] follow the same contract as
  /// [ManualDemoWorld.penguinLogistics]: environment-resolved locale and the
  /// fixed [manualDemoNow] clock by default, with [now] shifting every date
  /// by the same delta.
  factory DemoTutorialContent.build({
    DemoSeedText? translate,
    DateTime? now,
  }) {
    final t = translate ?? demoSeedTextFromEnvironment();
    final anchor = now ?? manualDemoNow;
    final imageAssets = demoMediaForTask(demoTutorialTaskId).toList();
    final images = <JournalImage>[
      for (var index = 0; index < imageAssets.length; index++)
        () {
          final asset = imageAssets[index];
          final capturedAt = asset.isCover
              ? anchor
              : anchor.subtract(Duration(minutes: (index + 1) * 5));
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
            ),
            entryText: caption == null ? null : EntryText(plainText: caption),
          );
        }(),
    ];
    final image = images.singleWhere(
      (candidate) =>
          candidate.meta.id == demoMediaCoverForTask(demoTutorialTaskId).id,
    );

    ChecklistItem item(String id, String title) {
      return ChecklistItem(
        meta: TestMetadataFactory.create(
          id: id,
          createdAt: anchor,
          categoryId: manualDemoCategoryId,
        ),
        data: ChecklistItemData(
          id: id,
          title: title,
          isChecked: false,
          linkedChecklists: [demoTutorialChecklistId],
        ),
      );
    }

    final checklistItems = <ChecklistItem>[
      item(
        demoTutorialCheckItemId,
        t('Check this item off', 'Hake diesen Punkt ab'),
      ),
      item(
        demoTutorialTimerItemId,
        t(
          'Start the timer on this task',
          'Starte den Timer für diese Aufgabe',
        ),
      ),
      item(
        demoTutorialAddItemItemId,
        t(
          'Add your own checklist item',
          'Füge einen eigenen Checklistenpunkt hinzu',
        ),
      ),
      item(
        demoTutorialCreateTaskItemId,
        t('Create a brand-new task', 'Erstelle eine ganz neue Aufgabe'),
      ),
      item(
        demoTutorialVoiceNoteItemId,
        t('Record a voice note', 'Nimm eine Sprachnotiz auf'),
      ),
    ];

    final checklist = Checklist(
      meta: TestMetadataFactory.create(
        id: demoTutorialChecklistId,
        createdAt: anchor,
        categoryId: manualDemoCategoryId,
      ),
      data: ChecklistData(
        title: t('Learn the ropes', 'Lerne die Grundlagen'),
        linkedChecklistItems: [
          for (final checklistItem in checklistItems) checklistItem.meta.id,
        ],
        linkedTasks: [demoTutorialTaskId],
      ),
    );

    final status = TaskStatus.open(
      id: 'status-tutorial-open',
      createdAt: anchor,
      utcOffset: 120,
    );
    const estimate = Duration(minutes: 15);
    final base = TestTaskFactory.create(
      id: demoTutorialTaskId,
      title: t('Your first mission', 'Deine erste Mission'),
      plainText: t(
        'Work through the checklist below to learn the basics — everything '
            'in this demo world is safe to try.',
        'Arbeite die Checkliste unten durch, um die Grundlagen '
            'kennenzulernen — in dieser Demo-Welt kannst du alles gefahrlos '
            'ausprobieren.',
      ),
      createdAt: anchor,
      dateFrom: anchor,
      dateTo: anchor.add(estimate),
      status: status,
      statusHistory: [status],
      categoryId: manualDemoCategoryId,
      estimate: estimate,
      checklistIds: [demoTutorialChecklistId],
    );
    final task = base.copyWith(
      data: base.data.copyWith(
        priority: TaskPriority.p2Medium,
        coverArtId: image.meta.id,
        coverArtCropX: 0.5,
      ),
    );
    final links = <EntryLink>[
      for (final tutorialImage in images)
        EntryLink.basic(
          id: demoUuid('demo-tutorial-image-link-${tutorialImage.meta.id}'),
          fromId: demoTutorialTaskId,
          toId: tutorialImage.meta.id,
          createdAt: anchor,
          updatedAt: anchor,
          vectorClock: null,
        ),
    ];

    return DemoTutorialContent._(
      task: task,
      checklist: checklist,
      checklistItems: checklistItems,
      images: images,
      links: links,
    );
  }

  /// The open, medium-priority "Your first mission" task in the Penguin
  /// Operations category.
  final Task task;

  /// The "Learn the ropes" checklist attached to [task].
  final Checklist checklist;

  /// Five unchecked starter steps, wired into [checklist].
  final List<ChecklistItem> checklistItems;

  /// R2-backed cover and supporting mission artifacts attached to [task].
  final List<JournalImage> images;

  JournalImage get image => images.singleWhere(
    (candidate) => candidate.meta.id == task.data.coverArtId,
  );

  /// Links owned by the tutorial fixture, written after all endpoints exist.
  final List<EntryLink> links;

  /// Every journal entity in seed-write order: image and items before the
  /// checklist/task records that reference them.
  List<JournalEntity> get journalEntities => [
    ...images,
    ...checklistItems,
    checklist,
    task,
  ];
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/modern_action_items.dart';
import 'package:lotti/widgets/modal/modern_modal_action_item.dart';

import '../../../../../../helpers/fake_entry_controller.dart';
import '../../../../../../test_helper.dart';

void main() {
  final now = DateTime(2025, 12, 31, 12);

  JournalAudio buildAudioEntry({String id = 'audio-1'}) {
    return JournalAudio(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: AudioData(
        audioFile: 'test.m4a',
        audioDirectory: '/tmp',
        dateFrom: now,
        dateTo: now,
        duration: const Duration(seconds: 30),
      ),
    );
  }

  Task buildTask({String id = 'task-1'}) {
    return Task(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
        categoryId: 'category-1',
      ),
      data: TaskData(
        title: 'Test Task',
        checklistIds: const [],
        status: TaskStatus.open(
          id: 'status',
          createdAt: now,
          utcOffset: 0,
        ),
        statusHistory: const [],
        dateFrom: now,
        dateTo: now,
      ),
    );
  }

  JournalImage buildImageEntry({String id = 'image-1'}) {
    return JournalImage(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: ImageData(
        imageId: 'img-uuid',
        imageFile: 'test.jpg',
        imageDirectory: '/tmp',
        capturedAt: now,
      ),
    );
  }

  group('ModernGenerateCoverArtItem', () {
    testWidgets('shows SizedBox.shrink for non-audio entry', (tester) async {
      final imageEntry = buildImageEntry();
      final task = buildTask();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            createEntryControllerOverride(imageEntry),
            createEntryControllerOverride(task),
          ],
          child: const Scaffold(
            body: ModernGenerateCoverArtItem(
              entryId: 'image-1',
              linkedFromId: 'task-1',
            ),
          ),
        ),
      );
      await tester.pump();

      // Should not find any action item
      expect(find.byType(ModernModalActionItem), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('shows SizedBox.shrink when linkedFromId is null',
        (tester) async {
      final audioEntry = buildAudioEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            createEntryControllerOverride(audioEntry),
          ],
          child: const Scaffold(
            body: ModernGenerateCoverArtItem(
              entryId: 'audio-1',
              linkedFromId: null,
            ),
          ),
        ),
      );
      await tester.pump();

      // Should not find any action item
      expect(find.byType(ModernModalActionItem), findsNothing);
    });

    testWidgets('shows SizedBox.shrink when linked entry is not a Task',
        (tester) async {
      final audioEntry = buildAudioEntry();
      final linkedImage = buildImageEntry(id: 'linked-image');

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            createEntryControllerOverride(audioEntry),
            createEntryControllerOverride(linkedImage),
          ],
          child: const Scaffold(
            body: ModernGenerateCoverArtItem(
              entryId: 'audio-1',
              linkedFromId: 'linked-image',
            ),
          ),
        ),
      );
      await tester.pump();

      // Should not find any action item
      expect(find.byType(ModernModalActionItem), findsNothing);
    });

    testWidgets('renders without error when audio linked to task',
        (tester) async {
      final audioEntry = buildAudioEntry();
      final task = buildTask();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            createEntryControllerOverride(audioEntry),
            createEntryControllerOverride(task),
          ],
          child: const Scaffold(
            body: ModernGenerateCoverArtItem(
              entryId: 'audio-1',
              linkedFromId: 'task-1',
            ),
          ),
        ),
      );
      await tester.pump();

      // Widget should render without error
      expect(find.byType(ModernGenerateCoverArtItem), findsOneWidget);
    });
  });

  group('ModernGenerateCoverArtItem widget properties', () {
    test('requires entryId parameter', () {
      const widget = ModernGenerateCoverArtItem(
        entryId: 'audio-1',
        linkedFromId: 'task-1',
      );

      expect(widget.entryId, 'audio-1');
      expect(widget.linkedFromId, 'task-1');
    });

    test('linkedFromId can be null', () {
      const widget = ModernGenerateCoverArtItem(
        entryId: 'audio-1',
        linkedFromId: null,
      );

      expect(widget.entryId, 'audio-1');
      expect(widget.linkedFromId, isNull);
    });
  });
}

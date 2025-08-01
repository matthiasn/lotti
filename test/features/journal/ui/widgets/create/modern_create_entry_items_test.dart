import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_items.dart';
import 'package:lotti/widgets/modal/modern_modal_entry_type_item.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('ModernCreateTaskItem Tests', () {
    testWidgets('renders task item correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateTaskItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the task item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
    });

    testWidgets('shows task item in modal', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => const CreateTaskItem(
                        'linked-id',
                        categoryId: 'category-id',
                      ),
                    );
                  },
                  child: const Text('Show Modal'),
                ),
              ],
            ),
          ),
        ),
      );

      // Open the modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify the task item is shown
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
    });
  });

  group('ModernCreateEventItem Tests', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateEventItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the event item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
    });
  });

  group('ModernCreateAudioItem Tests', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateAudioItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the audio item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });

    // NOTE: This test is removed because AudioRecordingModal has complex
    // dependencies that are difficult to mock properly in unit tests.
    // Consider integration tests for testing the full audio recording flow.
  });

  // ModernCreateTimerItem requires GetIt services and EntryController
  // which makes it more complex to test. Consider integration tests
  // or a more complete test setup for this widget.

  group('ModernCreateTextItem Tests', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateTextItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the text item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
      expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    });
  });

  group('ModernImportImageItem Tests', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ImportImageItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the import image item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Import Image'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
    });
  });

  group('ModernCreateScreenshotItem Tests', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateScreenshotItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the screenshot item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Screenshot'), findsOneWidget);
      expect(find.byIcon(Icons.screenshot_monitor_rounded), findsOneWidget);
    });
  });
}

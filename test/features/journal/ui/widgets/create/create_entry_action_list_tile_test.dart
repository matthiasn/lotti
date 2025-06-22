import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_list_tile.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../../test_helper.dart';

void main() {
  group('CreateTextEntryListTile', () {
    testWidgets('renders correctly with text icon and title', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateTextEntryListTile(
              'testLinkedId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      );

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(MdiIcons.textLong), findsOneWidget);
      expect(find.text('Text Entry'), findsOneWidget);
    });

    testWidgets('handles null linkedId and categoryId', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateTextEntryListTile(null),
          ),
        ),
      );

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(MdiIcons.textLong), findsOneWidget);
      expect(find.text('Text Entry'), findsOneWidget);
    });

    testWidgets('ListTile has correct properties', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateTextEntryListTile(
              'testLinkedId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      );

      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTile.leading, isA<Icon>());
      expect(listTile.title, isA<Text>());
      expect(listTile.onTap, isNotNull);
    });
  });

  group('CreateScreenshotListTile', () {
    testWidgets('renders correctly with screenshot icon and title',
        (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateScreenshotListTile(
              'testLinkedId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      );

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(MdiIcons.monitorScreenshot), findsOneWidget);
      expect(find.text('Screenshot'), findsOneWidget);
    });

    testWidgets('handles null linkedId and categoryId', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateScreenshotListTile(null),
          ),
        ),
      );

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(MdiIcons.monitorScreenshot), findsOneWidget);
      expect(find.text('Screenshot'), findsOneWidget);
    });

    testWidgets('ListTile has correct properties', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateScreenshotListTile(
              'testLinkedId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      );

      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTile.leading, isA<Icon>());
      expect(listTile.title, isA<Text>());
      expect(listTile.onTap, isNotNull);
    });
  });

  group('CreateAudioRecordingListTile', () {
    testWidgets('renders correctly with microphone icon and title',
        (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateAudioRecordingListTile(
              'testLinkedId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      );

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.text('Audio Recording'), findsOneWidget);
    });

    testWidgets('handles null linkedId and categoryId', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateAudioRecordingListTile(null),
          ),
        ),
      );

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.text('Audio Recording'), findsOneWidget);
    });

    testWidgets('ListTile has correct properties', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateAudioRecordingListTile(
              'testLinkedId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      );

      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTile.leading, isA<Icon>());
      expect(listTile.title, isA<Text>());
      expect(listTile.onTap, isNotNull);
    });
  });

  group('CreateTaskListTile', () {
    testWidgets('renders correctly with task icon and title', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateTaskListTile(
              'testLinkedId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      );

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(Icons.task_outlined), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
    });

    testWidgets('handles null linkedId and categoryId', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateTaskListTile(null),
          ),
        ),
      );

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(Icons.task_outlined), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
    });

    testWidgets('ListTile has correct properties', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateTaskListTile(
              'testLinkedId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      );

      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTile.leading, isA<Icon>());
      expect(listTile.title, isA<Text>());
      expect(listTile.onTap, isNotNull);
    });
  });

  group('CreateEventListTile', () {
    testWidgets('renders correctly with event icon and title', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateEventListTile(
              'testLinkedId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      );

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(Icons.event_outlined), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
    });

    testWidgets('handles null linkedId and categoryId', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateEventListTile(null),
          ),
        ),
      );

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(Icons.event_outlined), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
    });

    testWidgets('ListTile has correct properties', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CreateEventListTile(
              'testLinkedId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      );

      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTile.leading, isA<Icon>());
      expect(listTile.title, isA<Text>());
      // CreateEventListTile uses InkWell wrapper, so onTap is on the InkWell, not ListTile
      // Find the InkWell that is an ancestor of the ListTile
      final inkWellFinder = find.ancestor(
        of: find.byType(ListTile),
        matching: find.byType(InkWell),
      );
      expect(inkWellFinder, findsOneWidget);
      final inkWell = tester.widget<InkWell>(inkWellFinder);
      expect(inkWell.onTap, isNotNull);
    });
  });

  group('ImportImageAssetsListTile', () {
    testWidgets('renders correctly with photo icon and title', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: ImportImageAssetsListTile(
              'testLinkedId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      );

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
      expect(find.text('Photo(s)'), findsOneWidget);
    });

    testWidgets('handles null linkedId and categoryId', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: ImportImageAssetsListTile(null),
          ),
        ),
      );

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
      expect(find.text('Photo(s)'), findsOneWidget);
    });

    testWidgets('ListTile has correct properties', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: ImportImageAssetsListTile(
              'testLinkedId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      );

      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTile.leading, isA<Icon>());
      expect(listTile.title, isA<Text>());
      expect(listTile.onTap, isNotNull);
    });
  });

  group('Widget Integration Tests', () {
    testWidgets('multiple widgets can be rendered together', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: Column(
              children: [
                CreateTextEntryListTile('testLinkedId'),
                CreateScreenshotListTile('testLinkedId'),
                CreateAudioRecordingListTile('testLinkedId'),
                CreateTaskListTile('testLinkedId'),
                CreateEventListTile('testLinkedId'),
                ImportImageAssetsListTile('testLinkedId'),
              ],
            ),
          ),
        ),
      );

      // Verify all widgets are rendered
      expect(find.byType(CreateTextEntryListTile), findsOneWidget);
      expect(find.byType(CreateScreenshotListTile), findsOneWidget);
      expect(find.byType(CreateAudioRecordingListTile), findsOneWidget);
      expect(find.byType(CreateTaskListTile), findsOneWidget);
      expect(find.byType(CreateEventListTile), findsOneWidget);
      expect(find.byType(ImportImageAssetsListTile), findsOneWidget);

      // Verify all expected icons are present
      expect(find.byIcon(MdiIcons.textLong), findsOneWidget);
      expect(find.byIcon(MdiIcons.monitorScreenshot), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.task_outlined), findsOneWidget);
      expect(find.byIcon(Icons.event_outlined), findsOneWidget);
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);

      // Verify all ListTiles are present
      expect(find.byType(ListTile), findsNWidgets(6));
    });

    testWidgets('all widgets have unique text labels', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: Column(
              children: [
                CreateTextEntryListTile('testLinkedId'),
                CreateScreenshotListTile('testLinkedId'),
                CreateAudioRecordingListTile('testLinkedId'),
                CreateTaskListTile('testLinkedId'),
                CreateEventListTile('testLinkedId'),
                ImportImageAssetsListTile('testLinkedId'),
              ],
            ),
          ),
        ),
      );

      // Verify all text labels are unique and present
      expect(find.text('Text Entry'), findsOneWidget);
      expect(find.text('Screenshot'), findsOneWidget);
      expect(find.text('Audio Recording'), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
      expect(find.text('Photo(s)'), findsOneWidget);
    });

    testWidgets('widgets with different parameters render correctly',
        (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: Column(
              children: [
                CreateTextEntryListTile('linkedId1', categoryId: 'cat1'),
                CreateTextEntryListTile('linkedId2', categoryId: 'cat2'),
                CreateTextEntryListTile(null),
              ],
            ),
          ),
        ),
      );

      // All should render with the same text and icon
      expect(find.byType(CreateTextEntryListTile), findsNWidgets(3));
      expect(find.byIcon(MdiIcons.textLong), findsNWidgets(3));
      expect(find.text('Text Entry'), findsNWidgets(3));
    });
  });
}

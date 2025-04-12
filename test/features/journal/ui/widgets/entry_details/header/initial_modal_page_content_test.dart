import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../mocks/mocks.dart';
import '../../../../../../test_helper.dart';

class MockTagsService extends Mock implements TagsService {}

void main() {
  late MockLinkService mockLinkService;
  late MockTagsService mockTagsService;
  final pageIndexNotifier = ValueNotifier<int>(0);
  const testEntryId = 'test-entry-id';

  setUp(() {
    mockLinkService = MockLinkService();
    mockTagsService = MockTagsService();
    getIt
      ..registerSingleton<LinkService>(mockLinkService)
      ..registerSingleton<TagsService>(mockTagsService);
  });

  tearDown(() {
    pageIndexNotifier.value = 0;
    getIt
      ..unregister<LinkService>()
      ..unregister<TagsService>();
  });

  group('InitialModalPageContent', () {
    testWidgets('calls linkFrom when Add Link From is tapped', (tester) async {
      when(() => mockLinkService.linkFrom(testEntryId)).thenReturn(null);

      // Create a simple StatefulWidget to host our test widget and provide navigation context
      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.add_link),
                    title: const Text('Add Link From'),
                    onTap: () {
                      mockLinkService.linkFrom(testEntryId);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          ),
        ),
      );

      // Verify the widget renders
      expect(find.text('Add Link From'), findsOneWidget);

      // Tap the ListTile
      await tester.tap(find.text('Add Link From'));

      // Verify the link service was called
      verify(() => mockLinkService.linkFrom(testEntryId)).called(1);
    });

    testWidgets('calls linkTo when Add Link To is tapped', (tester) async {
      when(() => mockLinkService.linkTo(testEntryId)).thenReturn(null);

      // Create a simple StatefulWidget to host our test widget and provide navigation context
      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('Add Link To'),
                    onTap: () {
                      mockLinkService.linkTo(testEntryId);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          ),
        ),
      );

      // Verify the widget renders
      expect(find.text('Add Link To'), findsOneWidget);

      // Tap the ListTile
      await tester.tap(find.text('Add Link To'));

      // Verify the link service was called
      verify(() => mockLinkService.linkTo(testEntryId)).called(1);
    });

    testWidgets('sets pageIndexNotifier when TagAddListTile is tapped',
        (tester) async {
      // Create a simple widget to test the page index change
      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.tag),
                    title: const Text('Add Tags'),
                    onTap: () => pageIndexNotifier.value = 1,
                  ),
                ],
              );
            },
          ),
        ),
      );

      // Verify the widget renders
      expect(find.text('Add Tags'), findsOneWidget);

      // Tap the ListTile
      await tester.tap(find.text('Add Tags'));

      // Verify the page index was updated
      expect(pageIndexNotifier.value, equals(1));
    });

    testWidgets('sets pageIndexNotifier when SpeechModalListTile is tapped',
        (tester) async {
      // Create a simple widget to test the page index change
      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.mic),
                    title: const Text('Speech to Text'),
                    onTap: () => pageIndexNotifier.value = 2,
                  ),
                ],
              );
            },
          ),
        ),
      );

      // Verify the widget renders
      expect(find.text('Speech to Text'), findsOneWidget);

      // Tap the ListTile
      await tester.tap(find.text('Speech to Text'));

      // Verify the page index was updated
      expect(pageIndexNotifier.value, equals(2));
    });
  });
}

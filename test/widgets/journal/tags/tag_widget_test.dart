import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tag_widget.dart';
import 'package:lotti/themes/colors.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

class TestCallbackClass {
  void onTapRemove() {}
}

class TestMock extends Mock implements TestCallbackClass {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final testMock = TestMock();

  group('TagWidget Widget Tests -', () {
    setUpAll(() {
      when(testMock.onTapRemove).thenAnswer((_) {});
    });

    testWidgets('GenericTag is rendered and callback called', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TagWidget(
            onTapRemove: testMock.onTapRemove,
            tagEntity: testTag1,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // displays expected tag text
      expect(find.text(testTag1.tag), findsOneWidget);

      // tag has expected color
      expect(
        (tester.firstWidget(find.byType(Chip)) as Chip).backgroundColor,
        tagColor,
      );

      // onTapRemove is called
      final closeIconFinder = find.byIcon(Icons.close_rounded);
      expect(closeIconFinder, findsOneWidget);

      await tester.tap(closeIconFinder);
      await tester.pump();

      verify(testMock.onTapRemove).called(1);
    });

    testWidgets('StoryTag is rendered and callback called', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TagWidget(
            onTapRemove: testMock.onTapRemove,
            tagEntity: testStoryTag1,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // displays expected tag text
      expect(find.text(testStoryTag1.tag), findsOneWidget);

      // tag has expected color
      expect(
        (tester.firstWidget(find.byType(Chip)) as Chip).backgroundColor,
        storyTagColor,
      );

      // onTapRemove is called
      final closeIconFinder = find.byIcon(Icons.close_rounded);
      expect(closeIconFinder, findsOneWidget);

      await tester.tap(closeIconFinder);
      await tester.pump();

      verify(testMock.onTapRemove).called(1);
    });

    testWidgets('PersonTag is rendered and callback called', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TagWidget(
            onTapRemove: testMock.onTapRemove,
            tagEntity: testPersonTag1,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // displays expected tag text
      expect(find.text(testPersonTag1.tag), findsOneWidget);

      // tag has expected color
      expect(
        (tester.firstWidget(find.byType(Chip)) as Chip).backgroundColor,
        personTagColor,
      );

      // onTapRemove is called
      final closeIconFinder = find.byIcon(Icons.close_rounded);
      expect(closeIconFinder, findsOneWidget);

      await tester.tap(closeIconFinder);
      await tester.pump();

      verify(testMock.onTapRemove).called(1);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/tags/tag_widget.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
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
      getIt.registerSingleton<ThemesService>(ThemesService(watch: false));
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
        (tester.firstWidget(find.byType(Container)) as Container).color,
        colorConfig().tagColor,
      );

      // onTapRemove is called
      final closeIconFinder = find.byIcon(MdiIcons.close);
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
            tagEntity: testStoryTagReading,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // displays expected tag text
      expect(find.text(testStoryTagReading.tag), findsOneWidget);

      // tag has expected color
      expect(
        (tester.firstWidget(find.byType(Container)) as Container).color,
        colorConfig().storyTagColor,
      );

      // onTapRemove is called
      final closeIconFinder = find.byIcon(MdiIcons.close);
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
        (tester.firstWidget(find.byType(Container)) as Container).color,
        colorConfig().personTagColor,
      );

      // onTapRemove is called
      final closeIconFinder = find.byIcon(MdiIcons.close);
      expect(closeIconFinder, findsOneWidget);

      await tester.tap(closeIconFinder);
      await tester.pump();

      verify(testMock.onTapRemove).called(1);
    });
  });
}

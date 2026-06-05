import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  group('TitleAppBar', () {
    Future<void> pumpAppBar(
      WidgetTester tester, {
      required bool showBackButton,
      List<Widget>? actions,
    }) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          Scaffold(
            appBar: TitleAppBar(
              title: 'Page Title',
              showBackButton: showBackButton,
              actions: actions,
            ),
          ),
        ),
      );
      // Let the BackWidget fadeIn animation finish (1s).
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('renders title text with app bar style', (tester) async {
      await pumpAppBar(tester, showBackButton: false);

      expect(find.text('Page Title'), findsOneWidget);
      final text = tester.widget<Text>(find.text('Page Title'));
      expect(text.style, appBarTextStyleNew);
    });

    testWidgets('shows BackWidget when showBackButton is true', (
      tester,
    ) async {
      await pumpAppBar(tester, showBackButton: true);

      expect(find.byType(BackWidget), findsOneWidget);
    });

    testWidgets('hides BackWidget when showBackButton is false', (
      tester,
    ) async {
      await pumpAppBar(tester, showBackButton: false);

      expect(find.byType(BackWidget), findsNothing);
    });

    testWidgets('renders actions', (tester) async {
      await pumpAppBar(
        tester,
        showBackButton: false,
        actions: const [Icon(Icons.settings)],
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  group('TitleWidgetAppBar', () {
    testWidgets('renders arbitrary title widget with custom margin', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          const Scaffold(
            appBar: TitleWidgetAppBar(
              title: Icon(Icons.star),
              showBackButton: false,
              margin: EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.star), findsOneWidget);

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byIcon(Icons.star),
          matching: find.byType(Container),
        ),
      );
      expect(
        container.margin,
        const EdgeInsets.symmetric(horizontal: 10),
      );
    });

    testWidgets('preferredSize is toolbar height', (tester) async {
      const bar = TitleWidgetAppBar(title: Text('t'));
      expect(bar.preferredSize, const Size.fromHeight(kToolbarHeight));
      expect(
        const TitleAppBar(title: 't').preferredSize,
        const Size.fromHeight(kToolbarHeight),
      );
    });
  });

  group('BackWidget', () {
    testWidgets('tapping calls NavService.beamBack by default', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      getIt.registerSingleton<NavService>(mockNavService);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const BackWidget()),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      verify(mockNavService.beamBack).called(1);
    });

    testWidgets('tapping calls onPressed override instead of NavService', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      getIt.registerSingleton<NavService>(mockNavService);
      var pressed = 0;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(BackWidget(onPressed: () => pressed++)),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(pressed, 1);
      verifyNever(mockNavService.beamBack);
    });

    testWidgets('renders chevron icon with semantic label', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const BackWidget(onPressed: _noop)),
      );
      await tester.pump(const Duration(seconds: 1));

      final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(icon.semanticLabel, 'Navigate back');
      expect(icon.size, 30);
    });
  });
}

void _noop() {}

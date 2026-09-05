import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/whats_new/ui/whats_new_navigation_footer.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('two release indicators fit an iPhone SE footer', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) => NavigationFooter(
            totalReleases: 2,
            currentRelease: 1,
            colorScheme: Theme.of(context).colorScheme,
            onNavigate: (_) {},
            onMarkAllSeen: () {},
          ),
        ),
        mediaQueryData: phoneMediaQueryData.copyWith(
          size: const Size(320, 568),
        ),
      ),
    );

    expect(find.text('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('German skip action fits and marks releases as seen', (
    tester,
  ) async {
    var markAllSeenCalls = 0;

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: const Locale('de'),
            child: NavigationFooter(
              totalReleases: 2,
              currentRelease: 0,
              colorScheme: Theme.of(context).colorScheme,
              onNavigate: (_) {},
              onMarkAllSeen: () => markAllSeenCalls++,
            ),
          ),
        ),
        mediaQueryData: phoneMediaQueryData.copyWith(
          size: const Size(320, 640),
        ),
      ),
    );

    expect(find.text('Überspringen'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Überspringen'));
    expect(markAllSeenCalls, 1);
  });
}

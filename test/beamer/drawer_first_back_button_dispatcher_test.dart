import 'package:beamer/beamer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/drawer_first_back_button_dispatcher.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_drawer.dart';
import 'package:material_ui/material_ui.dart';

import '_beamer_test_utils.dart';

/// A root router whose one page hosts a tab's own nested `Beamer`, configured
/// as the app's tab delegates are — the arrangement in which the tab's child
/// dispatcher hears a back press before the root navigator does.
class _Bench {
  final drawer = MobileNavigationDrawerController();

  final tab = BeamerDelegate(
    setBrowserTabTitle: false,
    initialPath: '/tasks',
    updateParent: false,
    updateFromParent: false,
    locationBuilder: (routeInformation, _) =>
        EmptyTestLocation(routeInformation),
  );

  late final root = BeamerDelegate(
    setBrowserTabTitle: false,
    locationBuilder: RoutesLocationBuilder(
      routes: {'*': (context, state, data) => Beamer(routerDelegate: tab)},
    ).call,
  );

  String get tabPath => tab.configuration.uri.path;

  /// Where the tab stood before the one beam [pump] makes: what a walk back
  /// returns it to.
  late final String previousTabPath;

  Future<void> pump(WidgetTester tester) async {
    addTearDown(root.dispose);
    addTearDown(tab.dispose);
    addTearDown(drawer.dispose);
    await root.setNewRoutePath(RouteInformation(uri: Uri.parse('/')));
    await tab.setNewRoutePath(RouteInformation(uri: Uri.parse('/tasks')));

    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: root,
        routeInformationParser: BeamerParser(),
        backButtonDispatcher: DrawerFirstBackButtonDispatcher(
          delegate: root,
          drawer: drawer,
        ),
      ),
    );
    await tester.pump();

    // One step of history on the tab, so it has somewhere to go back to.
    previousTabPath = tabPath;
    tab.beamToNamed('/tasks/penguin');
    await tester.pump();
    expect(tabPath, '/tasks/penguin');
  }
}

void main() {
  group('DrawerFirstBackButtonDispatcher', () {
    testWidgets('an open drawer takes the back press and closes, and no tab '
        'moves', (tester) async {
      final bench = _Bench();
      await bench.pump(tester);
      bench.drawer.open();

      final handled = await tester.binding.handlePopRoute();
      await tester.pump();

      expect(handled, isTrue);
      expect(bench.drawer.isOpen, isFalse);
      // The tab could have beamed back, and would have taken the press
      // first: the drawer is checked ahead of every child dispatcher.
      expect(bench.tabPath, '/tasks/penguin');
    });

    testWidgets('a closed drawer leaves the press to Beamer, which walks the '
        'tab back', (tester) async {
      final bench = _Bench();
      await bench.pump(tester);

      final handled = await tester.binding.handlePopRoute();
      await tester.pump();

      expect(handled, isTrue);
      expect(bench.drawer.isOpen, isFalse);
      expect(bench.tabPath, bench.previousTabPath);
    });
  });
}

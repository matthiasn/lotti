import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/bottom_nav_safe_navigator.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';

void main() {
  group('bottomNavSafeNavigatorOf', () {
    final rootKey = GlobalKey<NavigatorState>();
    final nestedKey = GlobalKey<NavigatorState>();

    // A root MaterialApp navigator with a nested Navigator beneath it,
    // mirroring the production layout: the bottom nav lives on the root
    // shell, while each tab pushes onto its own nested navigator. The
    // returned navigator tells us which one a settings editor would escape
    // to.
    Future<BuildContext> pumpNested(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: rootKey,
          home: Navigator(
            key: nestedKey,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Center(child: Text('nested home')),
              ),
            ),
          ),
        ),
      );
      return tester.element(find.text('nested home'));
    }

    tearDown(() {
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
    });

    testWidgets(
      'returns the ROOT navigator when no NavService is bound — single-surface '
      'widget tests default to mobile so editors clear the bottom nav',
      (tester) async {
        final context = await pumpNested(tester);
        expect(
          bottomNavSafeNavigatorOf(context),
          same(rootKey.currentState),
        );
      },
    );

    testWidgets(
      'returns the ROOT navigator on mobile (isDesktopMode == false) so the '
      'pushed editor lifts above the floating bottom nav',
      (tester) async {
        final mockNavService = MockNavService();
        when(() => mockNavService.isDesktopMode).thenReturn(false);
        getIt.registerSingleton<NavService>(mockNavService);

        final context = await pumpNested(tester);
        expect(
          bottomNavSafeNavigatorOf(context),
          same(rootKey.currentState),
        );
      },
    );

    testWidgets(
      'returns the NESTED navigator on desktop (isDesktopMode == true) so the '
      'editor overlays only its panel — there is no bottom nav to escape',
      (tester) async {
        final mockNavService = MockNavService();
        when(() => mockNavService.isDesktopMode).thenReturn(true);
        getIt.registerSingleton<NavService>(mockNavService);

        final context = await pumpNested(tester);
        expect(
          bottomNavSafeNavigatorOf(context),
          same(nestedKey.currentState),
        );
      },
    );
  });
}

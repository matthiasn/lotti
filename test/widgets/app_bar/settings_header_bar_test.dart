import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/settings_header_bar.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  testWidgets(
    'back pops the visible page stack when it can (the drill-down back)',
    (tester) async {
      // A launcher route that pushes a settings leaf carrying the header — the
      // mobile settings drill-down shape (root → … → leaf on one Navigator).
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: SettingsHeaderBar(
                      title: 'Maintenance',
                      showBackButton: true,
                    ),
                  ),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('go'), findsNothing);

      // Tapping back returns to the launcher: the page stack popped (mirroring
      // the system back gesture) instead of a URL-history beamBack that no-ops
      // on the drill-down.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('go'), findsOneWidget);
      expect(find.text('Maintenance'), findsNothing);
    },
  );

  testWidgets('an explicit onBack overrides the default back action', (
    tester,
  ) async {
    var backs = 0;
    await tester.pumpWidget(
      makeTestableWidget2(
        Scaffold(
          body: SettingsHeaderBar(
            title: 'Detail',
            showBackButton: true,
            onBack: () => backs++,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(backs, 1);
  });

  testWidgets(
    'at the root (nothing to pop) it falls back to NavService.beamBack',
    (tester) async {
      final nav = MockNavService();
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
      getIt.registerSingleton<NavService>(nav);
      addTearDown(getIt.unregister<NavService>);

      // The header is the sole route, so there is nothing to pop locally.
      await tester.pumpWidget(
        makeTestableWidget2(
          const Scaffold(
            body: SettingsHeaderBar(title: 'Root', showBackButton: true),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      // ignore: unnecessary_lambdas
      verify(() => nav.beamBack()).called(1);
    },
  );
}

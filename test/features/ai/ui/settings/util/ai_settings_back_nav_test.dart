import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_settings_back_nav.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;

/// Helper that wraps [child] in a [MaterialApp] + an outer route so that
/// `Navigator.canPop` is `true` for pages mounted below the route — this
/// simulates the mobile push behaviour. When [withOuterRoute] is `false`
/// the page is the [MaterialApp.home] root, and `canPop` is `false` —
/// this simulates the desktop master/detail panel slot where the page
/// is rendered as a static child of `AiPanelDispatch`, not pushed onto
/// any Navigator.
Widget _buildHost({
  required Widget child,
  required bool withOuterRoute,
}) {
  return MaterialApp(
    home: withOuterRoute
        ? Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => child),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          )
        : child,
  );
}

class _ProbeBackPage extends StatelessWidget {
  const _ProbeBackPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => popAiSettingsDetail(context),
          child: const Text('back'),
        ),
      ),
    );
  }
}

void main() {
  group('popAiSettingsDetail', () {
    tearDown(() {
      nav_service.beamToNamedOverride = null;
    });

    testWidgets(
      'pops the local Navigator when the page was pushed (mobile / pushed) '
      '— the inner page disappears, the outer button stays mounted',
      (tester) async {
        await tester.pumpWidget(
          _buildHost(
            child: const _ProbeBackPage(),
            withOuterRoute: true,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('back'), findsOneWidget);
        expect(find.text('open'), findsNothing);

        await tester.tap(find.text('back'));
        await tester.pumpAndSettle();

        expect(find.text('back'), findsNothing);
        expect(find.text('open'), findsOneWidget);
      },
    );

    testWidgets(
      'calls the configured beam override when the page is the Navigator '
      'root (desktop panel slot) — proves the helper falls through to the '
      'parent-route beam when canPop returns false',
      (tester) async {
        final beamedTo = <String>[];
        nav_service.beamToNamedOverride = beamedTo.add;

        await tester.pumpWidget(
          _buildHost(
            child: const _ProbeBackPage(),
            withOuterRoute: false,
          ),
        );

        await tester.tap(find.text('back'));
        await tester.pump();

        expect(beamedTo, [aiSettingsParentRoute]);
        // The page stays mounted because the override does not actually
        // navigate — it just records the intent.
        expect(find.text('back'), findsOneWidget);
      },
    );

    testWidgets(
      'is a silent no-op when canPop is false and neither a beam override '
      'nor a registered NavService is available — proves the guard added '
      'to keep widget tests from crashing on the GetIt lookup',
      (tester) async {
        await tester.pumpWidget(
          _buildHost(
            child: const _ProbeBackPage(),
            withOuterRoute: false,
          ),
        );

        // No override set + no NavService registered with GetIt. The
        // helper must not throw — it should bail out silently.
        await tester.tap(find.text('back'));
        await tester.pump();

        expect(find.text('back'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

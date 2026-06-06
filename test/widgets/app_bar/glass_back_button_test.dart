import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:lotti/widgets/app_bar/glass_back_button.dart';
import 'package:lotti/widgets/app_bar/glass_icon_container.dart';

import '../../widget_test_utils.dart';

Future<void> _pump(WidgetTester tester, Widget widget) =>
    tester.pumpWidget(makeTestableWidgetWithScaffold(widget));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GlassBackButton', () {
    testWidgets('renders chevron_left icon', (tester) async {
      await _pump(tester, const GlassBackButton());

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });

    testWidgets('uses white icon color by default', (tester) async {
      await _pump(tester, const GlassBackButton());

      final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(icon.color, Colors.white);
    });

    testWidgets('uses custom icon color when provided', (tester) async {
      await _pump(tester, const GlassBackButton(iconColor: Colors.red));

      final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(icon.color, Colors.red);
    });

    testWidgets('uses default icon size of 24', (tester) async {
      await _pump(tester, const GlassBackButton());

      final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(icon.size, 24);
    });

    testWidgets('uses default container size of 34', (tester) async {
      await _pump(tester, const GlassBackButton());

      final actionButton = tester.widget<GlassActionButton>(
        find.byType(GlassActionButton),
      );
      expect(actionButton.size, 34);
    });

    testWidgets('uses custom icon size when provided', (tester) async {
      await _pump(tester, const GlassBackButton(iconSize: 32));

      final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(icon.size, 32);
    });

    testWidgets('contains GlassIconContainer', (tester) async {
      await _pump(tester, const GlassBackButton());

      expect(find.byType(GlassIconContainer), findsOneWidget);
    });

    testWidgets('contains Material with transparency', (tester) async {
      await _pump(tester, const GlassBackButton());

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(GlassBackButton),
          matching: find.byType(Material),
        ),
      );

      expect(material.type, MaterialType.transparency);
    });

    testWidgets('contains InkWell for tap feedback', (tester) async {
      await _pump(tester, const GlassBackButton());

      expect(
        find.descendant(
          of: find.byType(GlassBackButton),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    });

    testWidgets('calls custom onPressed when tapped', (tester) async {
      var tapped = false;

      await _pump(
        tester,
        GlassBackButton(
          onPressed: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(GlassBackButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('pops the current route via Navigator.maybePop by default', (
      tester,
    ) async {
      // Push a second route hosting the back button, then verify tapping it
      // actually pops back to the first route (not merely "does not throw").
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: GlassBackButton()),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(GlassBackButton), findsOneWidget);

      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();

      // Route was popped — back on the first page.
      expect(find.byType(GlassBackButton), findsNothing);
      expect(find.text('go'), findsOneWidget);
    });

    testWidgets('uses GlassActionButton internally', (tester) async {
      await _pump(tester, const GlassBackButton());

      expect(find.byType(GlassActionButton), findsOneWidget);
    });
  });
}

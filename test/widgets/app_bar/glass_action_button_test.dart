import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:lotti/widgets/app_bar/glass_icon_container.dart';
import 'package:material_ui/material_ui.dart';

import '../../test_utils/material_ui_finders.dart';
import '../../widget_test_utils.dart';

Future<void> _pump(WidgetTester tester, Widget widget) =>
    tester.pumpWidget(makeTestableWidgetWithScaffold(widget));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GlassActionButton', () {
    testWidgets('renders child widget', (tester) async {
      await _pump(
        tester,
        GlassActionButton(
          onTap: () {},
          child: const Icon(LottiIcons.more),
        ),
      );

      expect(find.byIcon(LottiIcons.more), findsOneWidget);
    });

    testWidgets('calls onTap when pressed', (tester) async {
      var tapped = false;

      await _pump(
        tester,
        GlassActionButton(
          onTap: () => tapped = true,
          child: const Icon(LottiIcons.settings),
        ),
      );

      await tester.tap(find.byType(GlassActionButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('activates from keyboard focus', (tester) async {
      var tapped = false;

      await _pump(
        tester,
        GlassActionButton(
          semanticLabel: 'Open menu',
          onTap: () => tapped = true,
          child: const Icon(LottiIcons.menu),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('exposes button semantics and optional tooltip', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await _pump(
        tester,
        GlassActionButton(
          semanticLabel: 'Open menu',
          onTap: () {},
          child: const Icon(LottiIcons.menu),
        ),
      );

      expect(findMaterialTooltip('Open menu'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('Open menu'));
      expect(node.label, 'Open menu');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.flagsCollection.isButton, isTrue);

      handle.dispose();
    });

    testWidgets('contains GlassIconContainer', (tester) async {
      await _pump(
        tester,
        GlassActionButton(
          onTap: () {},
          child: const Icon(LottiIcons.add),
        ),
      );

      expect(find.byType(GlassIconContainer), findsOneWidget);
    });

    testWidgets('uses default size of 40', (tester) async {
      await _pump(
        tester,
        GlassActionButton(
          onTap: () {},
          child: const Icon(LottiIcons.star),
        ),
      );

      final glassContainer = tester.widget<GlassIconContainer>(
        find.byType(GlassIconContainer),
      );

      expect(glassContainer.size, 40);
    });

    testWidgets('uses custom size when provided', (tester) async {
      await _pump(
        tester,
        GlassActionButton(
          onTap: () {},
          size: 50,
          child: const Icon(LottiIcons.favorite),
        ),
      );

      final glassContainer = tester.widget<GlassIconContainer>(
        find.byType(GlassIconContainer),
      );

      expect(glassContainer.size, 50);
    });

    testWidgets('contains Material with transparency', (tester) async {
      await _pump(
        tester,
        GlassActionButton(
          onTap: () {},
          child: const Icon(LottiIcons.menu),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(GlassActionButton),
          matching: find.byType(Material),
        ),
      );

      expect(material.type, MaterialType.transparency);
    });

    testWidgets('contains InkWell for tap feedback', (tester) async {
      await _pump(
        tester,
        GlassActionButton(
          onTap: () {},
          child: const Icon(LottiIcons.edit),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(GlassActionButton),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Material has rounded border radius', (tester) async {
      await _pump(
        tester,
        GlassActionButton(
          onTap: () {},
          child: const Icon(LottiIcons.close),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(GlassActionButton),
          matching: find.byType(Material),
        ),
      );

      expect(material.borderRadius, BorderRadius.circular(20));
    });

    testWidgets('renders any widget as child', (tester) async {
      await _pump(
        tester,
        GlassActionButton(
          onTap: () {},
          child: const Text('A'),
        ),
      );

      expect(find.text('A'), findsOneWidget);
    });
  });
}

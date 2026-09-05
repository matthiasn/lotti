import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

DsTokens _tokens(WidgetTester tester, Finder anchor) =>
    tester.element(anchor.first).designTokens;

Widget _row(String title, {DsActionRowTone tone = DsActionRowTone.neutral}) {
  return DsActionRow(
    icon: LottiIcons.link,
    title: title,
    tone: tone,
    onTap: () {},
  );
}

void main() {
  group('DsActionModalHeader', () {
    testWidgets('sets the title on the leading edge with a trailing close', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DsActionModalHeader(title: 'Actions'),
        ),
      );

      final header = tester.getRect(find.byType(DsActionModalHeader));
      final title = tester.getRect(find.text('Actions'));
      final close = tester.getRect(find.byIcon(LottiIcons.close));

      // The title starts on the sheet's own gutter, not centred over it.
      expect(
        title.left - header.left,
        _tokens(tester, find.byType(DsActionModalHeader)).spacing.step5,
      );
      expect(close.center.dx, greaterThan(title.right));
      // No rule under the header — the size ramp does that work.
      expect(
        find.descendant(
          of: find.byType(DsActionModalHeader),
          matching: find.byType(Divider),
        ),
        findsNothing,
      );
    });

    testWidgets('carries no back affordance until one is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DsActionModalHeader(title: 'Actions'),
        ),
      );
      expect(find.byIcon(LottiIcons.back), findsNothing);

      var backs = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionModalHeader(
            title: 'Speech recognition',
            onTapBack: () => backs++,
          ),
        ),
      );

      expect(find.byIcon(LottiIcons.back), findsOneWidget);
      // It leads the header, ahead of the title it returns from.
      expect(
        tester.getRect(find.byIcon(LottiIcons.back)).right,
        lessThan(tester.getRect(find.text('Speech recognition')).left),
      );

      await tester.tap(find.byIcon(LottiIcons.back));
      await tester.pump();
      expect(backs, 1);
    });

    testWidgets('the close glyph pops the route', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              builder: (_) => const DsActionModalHeader(title: 'Actions'),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(LottiIcons.close));
      await tester.pumpAndSettle();

      // Popping the last route leaves the navigator empty rather than
      // throwing — proof the tap reached Navigator.pop.
      expect(find.byType(DsActionModalHeader), findsNothing);
    });
  });

  group('DsActionModal metrics', () {
    testWidgets('falls back to the brightness-matched token set when the '
        'theme carries none', (tester) async {
      // The shell is reached from `ModalUtils`, which builds pages against a
      // modal context whose theme may not carry the DsTokens extension. It
      // must not throw there — it has to fall back the same way ModalUtils
      // itself does.
      late EdgeInsets darkPadding;
      late double darkHeader;
      late EdgeInsets lightPadding;
      late double lightHeader;

      for (final (brightness, theme) in [
        (Brightness.dark, ThemeData.dark()),
        (Brightness.light, ThemeData.light()),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            builder: LegacyMaterialBridge.builder,
            theme: theme,
            home: Builder(
              builder: (context) {
                if (brightness == Brightness.dark) {
                  darkPadding = DsActionModal.bodyPadding(context);
                  darkHeader = DsActionModal.headerHeight(context);
                } else {
                  lightPadding = DsActionModal.bodyPadding(context);
                  lightHeader = DsActionModal.headerHeight(context);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }

      // Spacing and type are brightness-invariant, so both fallbacks must
      // land on the same geometry — the point of the fallback is that a
      // missing extension changes nothing but colour.
      expect(darkPadding, lightPadding);
      expect(darkHeader, lightHeader);
      expect(
        darkPadding,
        EdgeInsets.fromLTRB(
          dsTokensDark.spacing.step5,
          dsTokensDark.spacing.step2,
          dsTokensDark.spacing.step5,
          dsTokensDark.spacing.step4,
        ),
      );
      expect(
        darkHeader,
        dsTokensDark.spacing.step5 +
            dsTokensDark.typography.lineHeight.heading3 +
            dsTokensDark.spacing.step4,
      );
    });
  });

  group('DsActionModalList', () {
    testWidgets('adds no spacing of its own between rows', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionModalList(children: [_row('Link from'), _row('Link to')]),
        ),
      );

      final first = tester.getRect(find.byType(DsActionRow).first);
      final second = tester.getRect(find.byType(DsActionRow).at(1));
      expect(second.top, first.bottom);
    });

    testWidgets('a row that renders nothing costs nothing', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionModalList(
            children: [
              _row('Link from'),
              const SizedBox.shrink(),
              _row('Link to'),
            ],
          ),
        ),
      );
      final withHidden = tester.getSize(find.byType(DsActionModalList)).height;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionModalList(children: [_row('Link from'), _row('Link to')]),
        ),
      );

      expect(
        tester.getSize(find.byType(DsActionModalList)).height,
        withHidden,
      );
    });

    testWidgets('the destructive row sits last, below the only divider', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionModalList(
            header: const Text('chips'),
            destructive: DsActionRow(
              icon: LottiIcons.delete,
              title: 'Delete entry',
              tone: DsActionRowTone.destructive,
              onTap: () {},
            ),
            children: [_row('Link from'), _row('Link to')],
          ),
        ),
      );

      final rule = find.descendant(
        of: find.byType(DsActionModalList),
        matching: find.byType(ColoredBox),
      );
      expect(rule, findsOneWidget);

      final ruleRect = tester.getRect(rule);
      expect(ruleRect.height, BorderWidths.hairline);
      expect(
        ruleRect.top,
        greaterThan(tester.getRect(find.text('Link to')).bottom),
      );
      expect(
        tester.getRect(find.text('Delete entry')).top,
        greaterThan(ruleRect.bottom),
      );
      // And the header leads everything.
      expect(
        tester.getRect(find.text('chips')).bottom,
        lessThan(tester.getRect(find.text('Link from')).top),
      );
    });

    testWidgets('no divider is drawn when there is nothing destructive', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DsActionModalList(children: [_row('Link from'), _row('Link to')]),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(DsActionModalList),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });
  });
}

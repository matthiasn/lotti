import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/ui/backfill_settings_stats.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';

// Both surfaces here render counts, and both used to weight them at
// `FontWeight.w500` — a step that does not exist on the design system's
// regular/semiBold/bold ramp. The dotted leader between a ledger label and its
// value additionally faded `text.lowEmphasis` by a further 0.45, re-deriving a
// step of the emphasis ramp that already existed.

void main() {
  const stats = BackfillStats(
    hostStats: [],
    totalReceived: 120,
    totalMissing: 4,
    totalRequested: 7,
    totalBackfilled: 96,
    totalDeleted: 3,
    totalUnresolvable: 1,
    totalBurned: 2,
  );

  group('StatusRow', () {
    Future<DsTokens> pumpRow(WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const StatusRow(inbound: 120, missing: 4, skipped: 2),
        ),
      );
      await tester.pump();
      return tester.element(find.byType(StatusRow)).designTokens;
    }

    testWidgets('shows each count it was given', (tester) async {
      await pumpRow(tester);

      expect(find.text('120'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('weights its values on the type ramp, not at w500', (
      tester,
    ) async {
      final tokens = await pumpRow(tester);

      for (final value in ['120', '4', '2']) {
        final text = tester.widget<Text>(find.text(value));
        expect(
          text.style!.fontWeight,
          tokens.typography.weight.semiBold,
          reason: "$value should take the ramp's semiBold step",
        );
      }
    });

    testWidgets('keeps its counts on tabular figures', (tester) async {
      // Without these the digits have unequal widths, so a changing count
      // shifts the label beside it.
      await pumpRow(tester);

      final text = tester.widget<Text>(find.text('120'));
      expect(
        text.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    // The next two pin values a revert would reproduce (IconSizes.xs is the
    // 12 the cells carried as a literal; the ramp's semiBold is w600), so
    // they hold the contract going forward rather than catch the literals.
    testWidgets('rides its cell glyphs on the caption icon tier', (
      tester,
    ) async {
      await pumpRow(tester);

      final glyphs = tester
          .widgetList<Icon>(
            find.descendant(
              of: find.byType(StatusRow),
              matching: find.byType(Icon),
            ),
          )
          .toList();
      expect(glyphs, hasLength(3));
      for (final glyph in glyphs) {
        expect(glyph.size, IconSizes.xs);
      }
    });

    testWidgets('weights its labels from the ramp', (tester) async {
      final tokens = await pumpRow(tester);
      final messages = tester.element(find.byType(StatusRow)).messages;

      for (final label in [
        messages.backfillStatusInboundQueue,
        messages.backfillStatusMissing,
        messages.backfillStatusSkipped,
      ]) {
        final text = tester.widget<Text>(find.text(label));
        expect(
          text.style!.fontWeight,
          tokens.typography.weight.semiBold,
          reason:
              '"$label" caption is deliberately raised to semiBold — '
              'from the ramp, not a literal',
        );
      }
    });
  });

  group('SyncStatsCard ledger', () {
    Future<DsTokens> pumpCard(WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: SyncStatsCard(
              stats: stats,
              missingCount: 4,
              isLoading: false,
              onRefresh: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.element(find.byType(SyncStatsCard)).designTokens;
    }

    testWidgets('renders the totals it was handed', (tester) async {
      await pumpCard(tester);

      expect(find.text('120'), findsOneWidget);
      expect(find.text('96'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('leads its header with a control-tier glyph', (tester) async {
      // Pins IconSizes.m, which equals the raw 18 it replaced.
      await pumpCard(tester);

      final glyph = tester.widget<Icon>(find.byIcon(LottiIcons.chart));
      expect(glyph.size, IconSizes.m);
    });

    testWidgets('takes its header weight from subtitle2 itself', (
      tester,
    ) async {
      final tokens = await pumpCard(tester);
      final messages = tester.element(find.byType(SyncStatsCard)).messages;

      final title = tester.widget<Text>(find.text(messages.backfillStatsTitle));
      expect(title.style!.fontWeight, tokens.typography.weight.semiBold);
      expect(
        title.style!.fontWeight,
        tokens.typography.styles.subtitle.subtitle2.fontWeight,
        reason: 'the weight must come from the style, not a layered override',
      );
    });

    testWidgets('weights every ledger value on the type ramp', (tester) async {
      final tokens = await pumpCard(tester);

      // The ledger rows are the only bodyMedium texts carrying tabular
      // figures, which is what separates a value from its label.
      final values = tester
          .widgetList<Text>(find.byType(Text))
          .where(
            (t) =>
                t.style?.fontFeatures?.contains(
                  const FontFeature.tabularFigures(),
                ) ??
                false,
          )
          .toList();

      expect(values, isNotEmpty);
      for (final value in values) {
        expect(value.style!.fontWeight, tokens.typography.weight.semiBold);
      }
    });

    testWidgets('draws the dotted leader from a theme-derived colour', (
      tester,
    ) async {
      // `_DottedLeaderPainter` is private, so its colour cannot be read
      // directly. `shouldRepaint` compares exactly that field, which makes it
      // a usable probe: render the card under both brightnesses and ask the
      // dark painter whether it differs from the light one. A colour pinned to
      // a literal alpha over a fixed base would answer no.
      // Reads whatever is mounted *right now* — the brightness it belongs to
      // is decided by the preceding pump, not by an argument.
      List<CustomPainter> currentLeaders() => tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(SyncStatsCard),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((p) => p.painter)
          .whereType<CustomPainter>()
          .where((p) => p.runtimeType.toString().contains('DottedLeader'))
          .toList();

      Future<List<CustomPainter>> pumpAt(Brightness brightness) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            SingleChildScrollView(
              child: SyncStatsCard(
                stats: stats,
                missingCount: 4,
                isLoading: false,
                onRefresh: () {},
              ),
            ),
            theme: ThemeData(useMaterial3: true, brightness: brightness),
          ),
        );
        // MaterialApp lerps between themes, and `DsTokens.lerp` at t≈0 still
        // returns the outgoing palette. Without settling the transition both
        // reads come back light and the comparison below passes vacuously.
        await tester.pump(const Duration(seconds: 1));
        return currentLeaders();
      }

      final light = await pumpAt(Brightness.light);
      final dark = await pumpAt(Brightness.dark);

      expect(light, isNotEmpty);
      expect(dark, hasLength(light.length));

      // Same painter, no repaint; across brightnesses, a repaint — which only
      // holds while the colour tracks the token rather than a fixed value.
      expect(light.first.shouldRepaint(light.first), isFalse);
      expect(
        dark.first.shouldRepaint(light.first),
        isTrue,
        reason: 'the leader colour does not follow the emphasis ramp',
      );
    });
  });
}

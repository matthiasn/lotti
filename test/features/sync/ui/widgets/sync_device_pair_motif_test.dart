import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/widgets/sync_device_pair_motif.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpMotif(
    WidgetTester tester,
    SyncDevicePairMotifState state, {
    bool disableAnimations = false,
  }) => tester.pumpWidget(
    makeTestableWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: SyncDevicePairMotif(state: state),
      ),
    ),
  );

  /// The colors of the circular dots between the two device glyphs.
  List<Color> dotColors(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(SyncDevicePairMotif),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .where((d) => d.shape == BoxShape.circle)
      .map((d) => d.color!)
      .toList();

  group('SyncDevicePairMotif', () {
    testWidgets('always draws the two machines', (tester) async {
      await pumpMotif(tester, SyncDevicePairMotifState.idle);

      expect(find.byIcon(Icons.smartphone_rounded), findsOneWidget);
      expect(find.byIcon(Icons.laptop_mac_rounded), findsOneWidget);
    });

    testWidgets('idle leaves the gap open: hollow neutral dots', (
      tester,
    ) async {
      await pumpMotif(tester, SyncDevicePairMotifState.idle);

      final tokens = tester
          .element(find.byType(SyncDevicePairMotif))
          .designTokens;
      final dots = dotColors(tester);
      expect(dots, hasLength(3));
      for (final color in dots) {
        expect(color, tokens.colors.decorative.level02);
      }
    });

    testWidgets('connecting streams accent dots toward the other machine', (
      tester,
    ) async {
      await pumpMotif(tester, SyncDevicePairMotifState.connecting);

      final before = dotColors(tester);
      expect(before, hasLength(4));

      // The pulse travels: after a partial cycle the per-dot alphas differ
      // from the first frame.
      await tester.pump(const Duration(milliseconds: 300));
      final after = dotColors(tester);
      expect(after, isNot(equals(before)));
    });

    testWidgets('the pulse stops when the connection completes', (
      tester,
    ) async {
      // The repeating controller must not outlive the connecting state: a
      // motif updated to linked keeps ticking invisibly otherwise, burning
      // frames on a screen that reads as finished.
      await pumpMotif(tester, SyncDevicePairMotifState.connecting);
      await tester.pump(const Duration(milliseconds: 300));

      await pumpMotif(tester, SyncDevicePairMotifState.linked);
      // Settles only if didUpdateWidget stopped the repeat — a live
      // repeating controller would make this time out.
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.smartphone_rounded), findsOneWidget);
    });

    testWidgets('reduced motion parks the stream at steady mid-strength', (
      tester,
    ) async {
      await pumpMotif(
        tester,
        SyncDevicePairMotifState.connecting,
        disableAnimations: true,
      );

      final before = dotColors(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(dotColors(tester), equals(before));

      final tokens = tester
          .element(find.byType(SyncDevicePairMotif))
          .designTokens;
      for (final color in before) {
        expect(
          color,
          tokens.colors.interactive.enabled.withValues(alpha: 0.6),
        );
      }
    });

    testWidgets('linked closes the gap into one solid accent line', (
      tester,
    ) async {
      await pumpMotif(tester, SyncDevicePairMotifState.linked);

      final tokens = tester
          .element(find.byType(SyncDevicePairMotif))
          .designTokens;
      // No dots left — the space between the machines is a filled bar.
      expect(dotColors(tester), isEmpty);
      final bar = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(SyncDevicePairMotif),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .single;
      expect(bar.color, tokens.colors.interactive.enabled);
      // Trust established: the machines take full ink.
      expect(
        tester.widget<Icon>(find.byIcon(Icons.smartphone_rounded)).color,
        tokens.colors.text.highEmphasis,
      );
    });
  });
}

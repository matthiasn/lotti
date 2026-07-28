import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_callout.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  /// The tokens the widget itself resolves, read from the same theme the test
  /// pumps, so the assertions compare against the design system rather than
  /// against a copied literal.
  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(SyncCallout)).designTokens;

  BoxDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: find.byType(SyncCallout),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration
          as BoxDecoration;

  group('SyncCallout', () {
    testWidgets('shows its icon and message', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncCallout(
            icon: Icons.pause_circle_outline,
            text: 'Sync is paused for one device.',
          ),
        ),
      );

      expect(find.text('Sync is paused for one device.'), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
    });

    testWidgets('carries the warning tone by default', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncCallout(icon: Icons.warning_amber_rounded, text: 'Careful'),
        ),
      );

      final tokens = tokensOf(tester);
      final warning = tokens.colors.alert.warning.defaultColor;

      // Border and icon share one colour: the tone is what makes a callout
      // read as a warning rather than as a card.
      expect(
        (decorationOf(tester).border! as Border).top.color,
        warning,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded)).color,
        warning,
      );
    });

    testWidgets('honours an explicit tone', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncCallout(
            icon: Icons.info_outline,
            text: 'Just so you know',
            tone: Colors.teal,
          ),
        ),
      );

      expect(
        (decorationOf(tester).border! as Border).top.color,
        Colors.teal,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.info_outline)).color,
        Colors.teal,
      );
    });

    testWidgets('sits on the level02 surface with the section-card radius', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncCallout(icon: Icons.info_outline, text: 'Message'),
        ),
      );

      final tokens = tokensOf(tester);
      final decoration = decorationOf(tester);

      expect(decoration.color, tokens.colors.background.level02);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(tokens.radii.sectionCards),
      );
    });

    testWidgets('applies calloutKey to the callout itself', (tester) async {
      // Callers assert presence by key; if it landed on an inner node the
      // widget would still find it, but removing the callout would not.
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncCallout(
            icon: Icons.info_outline,
            text: 'Message',
            calloutKey: Key('security_note'),
          ),
        ),
      );

      expect(
        find.byKey(const Key('security_note')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SyncCallout),
          matching: find.byKey(const Key('security_note')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('lets long copy wrap instead of overflowing', (tester) async {
      // The security warning is two full sentences; on a phone it must wrap.
      // Centered so the width constraint actually applies (a MaterialApp home
      // is tight-constrained to the screen), and asserted on the wrap
      // *contract* rather than a pixel height — line metrics vary with which
      // fonts earlier suites in the batched CI process have loaded.
      await tester.pumpWidget(
        makeTestableWidget(
          const Center(
            child: SizedBox(
              width: 300,
              child: SyncCallout(
                icon: Icons.warning_amber_rounded,
                text:
                    'This code unlocks your sync account. Show it only to a '
                    'device you own, and never share a picture of it.',
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'no overflow');
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(SyncCallout),
          matching: find.byType(Text),
        ),
      );
      expect(text.softWrap ?? true, isTrue);
      expect(text.maxLines, isNull, reason: 'long copy must be able to wrap');
    });
  });
}

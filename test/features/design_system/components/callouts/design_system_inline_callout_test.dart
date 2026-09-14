import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  /// The tokens the widget itself resolves, read from the same theme the test
  /// pumps, so the assertions compare against the design system rather than
  /// against a copied literal.
  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(DesignSystemInlineCallout)).designTokens;

  BoxDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: find.byType(DesignSystemInlineCallout),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration
          as BoxDecoration;

  group('DesignSystemInlineCallout', () {
    testWidgets('shows its icon and message', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DesignSystemInlineCallout(
            icon: LottiIcons.pauseCircled,
            text: 'Sync is paused for one device.',
          ),
        ),
      );

      expect(find.text('Sync is paused for one device.'), findsOneWidget);
      expect(find.byIcon(LottiIcons.pauseCircled), findsOneWidget);
    });

    testWidgets('a title sits above the message and the actions end on the '
        'trailing edge, quietest first', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DesignSystemInlineCallout(
            icon: LottiIcons.pauseCircled,
            title: 'Transcript not received',
            text: 'Your recording is saved.',
            actions: [
              TextButton(
                key: const ValueKey('quiet'),
                onPressed: () {},
                child: const Text('Type instead'),
              ),
              FilledButton(
                key: const ValueKey('primary'),
                onPressed: () {},
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
      final title = tester.getRect(find.text('Transcript not received'));
      final body = tester.getRect(find.text('Your recording is saved.'));
      final quiet = tester.getRect(find.byKey(const ValueKey('quiet')));
      final primary = tester.getRect(find.byKey(const ValueKey('primary')));
      final callout = tester.getRect(find.byType(DesignSystemInlineCallout));
      expect(title.bottom, lessThanOrEqualTo(body.top));
      expect(quiet.top, greaterThanOrEqualTo(body.bottom));
      expect(primary.left, greaterThan(quiet.right));
      final inset = tokensOf(tester).spacing.step4;
      expect(primary.right, closeTo(callout.right - inset, 1));
    });

    testWidgets('announce reads the title and message as one live node', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DesignSystemInlineCallout(
            icon: LottiIcons.pauseCircled,
            title: 'Transcript not received',
            text: 'Your recording is saved.',
            announce: true,
          ),
        ),
      );
      final node = tester.getSemantics(find.text('Transcript not received'));
      expect(node.flagsCollection.isLiveRegion, isTrue);
      expect(node.label, contains('Transcript not received'));
      expect(node.label, contains('Your recording is saved.'));
    });

    testWidgets('carries the warning tone by default', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DesignSystemInlineCallout(
            icon: LottiIcons.warning,
            text: 'Careful',
          ),
        ),
      );

      final tokens = tokensOf(tester);
      final warning = tokens.colors.alert.warning.defaultColor;

      // Border and icon share one colour: the tone is what makes a callout
      // read as a warning rather than as a card.
      expect((decorationOf(tester).border! as Border).top.color, warning);
      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.warning)).color,
        warning,
      );
    });

    testWidgets('honours an explicit tone', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DesignSystemInlineCallout(
            icon: LottiIcons.info,
            text: 'Just so you know',
            tone: Colors.teal,
          ),
        ),
      );

      expect((decorationOf(tester).border! as Border).top.color, Colors.teal);
      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.info)).color,
        Colors.teal,
      );
    });

    testWidgets('sits on the level02 surface with the section-card radius', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DesignSystemInlineCallout(
            icon: LottiIcons.info,
            text: 'Message',
          ),
        ),
      );

      final tokens = tokensOf(tester);
      final decoration = decorationOf(tester);

      expect(decoration.color, tokens.colors.background.level02);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(tokens.radii.sectionCards),
      );
      expect(
        (decoration.border! as Border).top.width,
        BorderWidths.hairline,
      );
    });

    testWidgets('keeps the message on high-emphasis ink, never the tone', (
      tester,
    ) async {
      // The alert-ramp contract: the tone rides the border and glyph
      // (non-text, ≥3:1), while the message itself must not depend on an
      // alert hue for legibility.
      await tester.pumpWidget(
        makeTestableWidget(
          const DesignSystemInlineCallout(
            icon: LottiIcons.info,
            text: 'Message',
            tone: Colors.teal,
          ),
        ),
      );

      final tokens = tokensOf(tester);
      final label = tester.widget<Text>(find.text('Message'));
      expect(label.style?.color, tokens.colors.text.highEmphasis);
      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.info)).size,
        IconSizes.l,
      );
    });
  });
}

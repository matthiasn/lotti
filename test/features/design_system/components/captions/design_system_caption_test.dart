import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/captions/design_system_caption.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemCaption', () {
    testWidgets('renders title and description without icon or actions', (
      tester,
    ) async {
      const captionKey = Key('basic-caption');

      await _pumpCaption(
        tester,
        const DesignSystemCaption(
          key: captionKey,
          title: 'Caption title',
          description: 'Caption description text.',
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(captionKey),
          matching: find.text('Caption title'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(captionKey),
          matching: find.text('Caption description text.'),
        ),
        findsOneWidget,
      );
      // No icon
      expect(
        find.descendant(
          of: find.byKey(captionKey),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });

    testWidgets('renders with left icon position', (tester) async {
      const captionKey = Key('left-icon-caption');

      await _pumpCaption(
        tester,
        const DesignSystemCaption(
          key: captionKey,
          title: 'With icon',
          description: 'Description text.',
          iconPosition: DesignSystemCaptionIconPosition.left,
          icon: Icons.info_rounded,
        ),
      );

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(captionKey),
          matching: find.byIcon(Icons.info_rounded),
        ),
      );

      expect(icon.size, dsTokensLight.spacing.step6);
      expect(icon.color, dsTokensLight.colors.interactive.enabled);

      // Layout: Row with icon + content
      expect(
        find.descendant(
          of: find.byKey(captionKey),
          matching: find.byType(Row),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders with top icon position', (tester) async {
      const captionKey = Key('top-icon-caption');

      await _pumpCaption(
        tester,
        const DesignSystemCaption(
          key: captionKey,
          title: 'Top icon',
          description: 'Description text.',
          iconPosition: DesignSystemCaptionIconPosition.top,
          icon: Icons.error_rounded,
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(captionKey),
          matching: find.byIcon(Icons.error_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses custom icon color when provided', (tester) async {
      const captionKey = Key('custom-color-caption');

      await _pumpCaption(
        tester,
        const DesignSystemCaption(
          key: captionKey,
          title: 'Error caption',
          description: 'Something went wrong.',
          iconPosition: DesignSystemCaptionIconPosition.left,
          icon: Icons.error_rounded,
          iconColor: Colors.red,
        ),
      );

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(captionKey),
          matching: find.byIcon(Icons.error_rounded),
        ),
      );

      expect(icon.color, Colors.red);
    });

    testWidgets('renders action buttons when provided', (tester) async {
      const captionKey = Key('actions-caption');
      var primaryTapped = false;
      var secondaryTapped = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 472,
            child: DesignSystemCaption(
              key: captionKey,
              title: 'With actions',
              description: 'Description.',
              primaryAction: TextButton(
                onPressed: () => primaryTapped = true,
                child: const Text('Primary'),
              ),
              secondaryAction: TextButton(
                onPressed: () => secondaryTapped = true,
                child: const Text('Secondary'),
              ),
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Secondary'), findsOneWidget);

      await tester.tap(find.text('Primary'));
      await tester.pump();
      expect(primaryTapped, isTrue);

      await tester.tap(find.text('Secondary'));
      await tester.pump();
      expect(secondaryTapped, isTrue);
    });

    testWidgets('applies token-driven card styling', (tester) async {
      const captionKey = Key('styled-caption');

      await _pumpCaption(
        tester,
        const DesignSystemCaption(
          key: captionKey,
          title: 'Styled',
          description: 'Description.',
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(captionKey),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.color, dsTokensLight.colors.surface.enabled);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(dsTokensLight.radii.s),
      );
      expect(decoration.border, isNotNull);
    });

    testWidgets('provides semantics label', (tester) async {
      const captionKey = Key('semantics-caption');

      await _pumpCaption(
        tester,
        const DesignSystemCaption(
          key: captionKey,
          title: 'Accessible',
          description: 'Description.',
          semanticsLabel: 'Important notice',
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(captionKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Important notice',
          ),
        ),
      );

      expect(semantics.properties.label, 'Important notice');
    });

    testWidgets('title truncates with ellipsis on overflow', (tester) async {
      const captionKey = Key('overflow-caption');

      await _pumpCaption(
        tester,
        const DesignSystemCaption(
          key: captionKey,
          title:
              'A very long title that should truncate after two lines '
              'of text because it is extremely verbose',
          description: 'Short description.',
        ),
      );

      final titleText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(captionKey),
          matching: find.text(
            'A very long title that should truncate after two lines '
            'of text because it is extremely verbose',
          ),
        ),
      );

      expect(titleText.maxLines, 2);
      expect(titleText.overflow, TextOverflow.ellipsis);
    });
  });
}

Future<void> _pumpCaption(
  WidgetTester tester,
  Widget child,
) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SizedBox(width: 472, child: child),
      theme: DesignSystemTheme.light(),
    ),
  );
}

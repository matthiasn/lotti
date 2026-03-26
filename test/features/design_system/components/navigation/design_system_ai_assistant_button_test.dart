import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_ai_assistant_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(Widget child, {ThemeData? theme}) {
    return makeTestableWidgetWithScaffold(
      child,
      theme: theme ?? DesignSystemTheme.light(),
    );
  }

  group('DesignSystemAiAssistantButton', () {
    testWidgets('invokes onPressed when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrap(
          DesignSystemAiAssistantButton(
            assetName: 'assets/design_system/ai_assistant_variant_1.png',
            semanticLabel: 'AI Assistant',
            onPressed: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DesignSystemAiAssistantButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('exposes button semantics when enabled', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          wrap(
            DesignSystemAiAssistantButton(
              assetName: 'assets/design_system/ai_assistant_variant_1.png',
              semanticLabel: 'AI Assistant',
              onPressed: () {},
            ),
          ),
        );
        await tester.pump();

        final semanticsNode = tester.getSemantics(
          find.bySemanticsLabel('AI Assistant'),
        );

        expect(semanticsNode.label, 'AI Assistant');
        expect(
          semanticsNode.getSemanticsData().flagsCollection.isButton,
          anyOf(isTrue, Tristate.isTrue),
        );
        expect(
          semanticsNode.getSemanticsData().flagsCollection.isEnabled,
          anyOf(isTrue, Tristate.isTrue),
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('exposes disabled button semantics when disabled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          wrap(
            const DesignSystemAiAssistantButton(
              assetName: 'assets/design_system/ai_assistant_variant_1.png',
              semanticLabel: 'AI Assistant',
            ),
          ),
        );
        await tester.pump();

        final semanticsNode = tester.getSemantics(
          find.bySemanticsLabel('AI Assistant'),
        );

        expect(semanticsNode.label, 'AI Assistant');
        expect(
          semanticsNode.getSemanticsData().flagsCollection.isButton,
          anyOf(isTrue, Tristate.isTrue),
        );
        expect(
          semanticsNode.getSemanticsData().flagsCollection.isEnabled,
          anyOf(isFalse, Tristate.isFalse),
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('shows circular hover background on mouse enter', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          DesignSystemAiAssistantButton(
            assetName: 'assets/design_system/ai_assistant_variant_1.png',
            semanticLabel: 'AI Assistant',
            onPressed: () {},
          ),
        ),
      );

      // Simulate mouse hover via MouseRegion
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(
        tester.getCenter(find.byType(DesignSystemAiAssistantButton)),
      );
      await tester.pump();

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, dsTokensLight.colors.surface.hover);
    });

    testWidgets('hover background is transparent when not hovered', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          DesignSystemAiAssistantButton(
            assetName: 'assets/design_system/ai_assistant_variant_1.png',
            semanticLabel: 'AI Assistant',
            onPressed: () {},
          ),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.color, Colors.transparent);
    });

    testWidgets('does not show hover when disabled', (tester) async {
      await tester.pumpWidget(
        wrap(
          const DesignSystemAiAssistantButton(
            assetName: 'assets/design_system/ai_assistant_variant_1.png',
            semanticLabel: 'AI Assistant',
          ),
        ),
      );

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(
        tester.getCenter(find.byType(DesignSystemAiAssistantButton)),
      );
      await tester.pump();

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.color, Colors.transparent);
    });

    testWidgets('resets hover state when becoming disabled', (tester) async {
      var enabled = true;

      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  DesignSystemAiAssistantButton(
                    assetName:
                        'assets/design_system/ai_assistant_variant_1.png',
                    semanticLabel: 'AI Assistant',
                    onPressed: enabled ? () {} : null,
                  ),
                  TextButton(
                    onPressed: () => setState(() => enabled = false),
                    child: const Text('Disable'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      // Hover the button
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(
        tester.getCenter(find.byType(DesignSystemAiAssistantButton)),
      );
      await tester.pump();

      // Now disable
      await tester.tap(find.text('Disable'));
      await tester.pump();

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.color, Colors.transparent);
    });

    testWidgets('is focusable via keyboard when enabled', (tester) async {
      await tester.pumpWidget(
        wrap(
          DesignSystemAiAssistantButton(
            assetName: 'assets/design_system/ai_assistant_variant_1.png',
            semanticLabel: 'AI Assistant',
            onPressed: () {},
          ),
        ),
      );

      // The Focus widget inside the button should allow focus
      final focusFinder = find.descendant(
        of: find.byType(DesignSystemAiAssistantButton),
        matching: find.byType(Focus),
      );
      expect(focusFinder, findsOneWidget);

      final focus = tester.widget<Focus>(focusFinder);
      expect(focus.canRequestFocus, isTrue);
    });

    testWidgets('is not focusable when disabled', (tester) async {
      await tester.pumpWidget(
        wrap(
          const DesignSystemAiAssistantButton(
            assetName: 'assets/design_system/ai_assistant_variant_1.png',
            semanticLabel: 'AI Assistant',
          ),
        ),
      );

      final focus = tester.widget<Focus>(
        find.descendant(
          of: find.byType(DesignSystemAiAssistantButton),
          matching: find.byType(Focus),
        ),
      );
      expect(focus.canRequestFocus, isFalse);
    });
  });
}

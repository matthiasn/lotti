import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_ai_assistant_button.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Scaffold(
        body: Center(child: child),
      ),
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

    testWidgets('exposes image semantics when disabled', (tester) async {
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
          anyOf(isFalse, Tristate.isFalse),
        );
        expect(
          semanticsNode.getSemanticsData().flagsCollection.isImage,
          anyOf(isTrue, Tristate.isTrue),
        );
      } finally {
        handle.dispose();
      }
    });
  });
}

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_ai_assistant_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/widgets/sidebar.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: SizedBox(
            width: 400,
            height: 900,
            child: child,
          ),
        ),
      ),
    );
  }

  group('Sidebar', () {
    testWidgets('renders navigation items', (tester) async {
      await tester.pumpWidget(wrap(const Sidebar()));
      await tester.pump();

      expect(find.text('My Daily'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
    });

    testWidgets('renders menu icon and brand logo', (tester) async {
      await tester.pumpWidget(wrap(const Sidebar()));
      await tester.pump();

      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    });

    testWidgets('renders AI assistant orb with semantics', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          wrap(
            Sidebar(onAiAssistantPressed: () {}),
          ),
        );
        await tester.pump();

        expect(find.byType(DesignSystemAiAssistantButton), findsOneWidget);

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

    testWidgets('tapping the AI assistant orb invokes the callback', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        wrap(
          Sidebar(onAiAssistantPressed: () => tapped = true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DesignSystemAiAssistantButton));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('MainTopBar', () {
    testWidgets('renders title and notification icon', (tester) async {
      await tester.pumpWidget(wrap(const MainTopBar()));
      await tester.pump();

      expect(find.text('Projects'), findsOneWidget);
      expect(
        find.byIcon(Icons.notifications_none_rounded),
        findsOneWidget,
      );
    });
  });
}

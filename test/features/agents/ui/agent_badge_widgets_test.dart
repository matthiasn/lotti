import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/agent_badge_widgets.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('AgentBadge', () {
    testWidgets('renders the label tinted with the given color', (
      tester,
    ) async {
      const badgeColor = Color(0xFF1CB0F6);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Scaffold(
            body: AgentBadge(label: 'Running', color: badgeColor),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Running'), findsOneWidget);

      // The pill container derives both fill and border from the color.
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('Running'),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, badgeColor.withValues(alpha: 0.12));
      expect(
        decoration.border!.top.color,
        badgeColor.withValues(alpha: 0.4),
      );

      final text = tester.widget<Text>(find.text('Running'));
      expect(text.style?.color, badgeColor);
    });
  });

  group('AgentLifecycleBadge', () {
    testWidgets('maps every lifecycle to its localized label', (tester) async {
      const expectedLabels = {
        AgentLifecycle.created: 'Created',
        AgentLifecycle.active: 'Active',
        AgentLifecycle.dormant: 'Dormant',
        AgentLifecycle.destroyed: 'Destroyed',
      };

      // Exhaustive over the enum: a new lifecycle must be mapped here.
      for (final lifecycle in AgentLifecycle.values) {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Scaffold(body: AgentLifecycleBadge(lifecycle: lifecycle)),
          ),
        );
        await tester.pump();

        expect(
          find.text(expectedLabels[lifecycle]!),
          findsOneWidget,
          reason: '$lifecycle',
        );
        expect(find.byType(AgentBadge), findsOneWidget);
      }
    });

    testWidgets('destroyed uses the error color, active the primary color', (
      tester,
    ) async {
      Future<Color> badgeColorFor(AgentLifecycle lifecycle) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Scaffold(body: AgentLifecycleBadge(lifecycle: lifecycle)),
          ),
        );
        await tester.pump();
        return tester.widget<AgentBadge>(find.byType(AgentBadge)).color;
      }

      final destroyedColor = await badgeColorFor(AgentLifecycle.destroyed);
      final scheme = Theme.of(
        tester.element(find.byType(Scaffold)),
      ).colorScheme;

      expect(destroyedColor, scheme.error);
      expect(await badgeColorFor(AgentLifecycle.active), scheme.primary);
      expect(await badgeColorFor(AgentLifecycle.dormant), scheme.outline);
      expect(await badgeColorFor(AgentLifecycle.created), scheme.tertiary);
    });
  });
}

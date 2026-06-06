import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_floating_action_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('AiSettingsFloatingActionButton', () {
    late bool buttonPressed;

    setUp(() {
      buttonPressed = false;
    });

    Future<void> pumpFab(
      WidgetTester tester, {
      required AiSettingsTab activeTab,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            floatingActionButton: AiSettingsFloatingActionButton(
              activeTab: activeTab,
              onPressed: () => buttonPressed = true,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    DesignSystemFloatingActionButton readFab(WidgetTester tester) {
      return tester.widget<DesignSystemFloatingActionButton>(
        find.byType(DesignSystemFloatingActionButton),
      );
    }

    testWidgets(
      'wraps a DesignSystemFloatingActionButton inside the standard '
      'bottom-nav padding helper',
      (tester) async {
        await pumpFab(tester, activeTab: AiSettingsTab.models);

        expect(
          find.byType(DesignSystemBottomNavigationFabPadding),
          findsOneWidget,
        );
        expect(find.byType(DesignSystemFloatingActionButton), findsOneWidget);
      },
    );

    testWidgets(
      'each tab uses its own icon and a non-empty localized label',
      (tester) async {
        for (final (tab, icon) in [
          (AiSettingsTab.providers, Icons.add_link_rounded),
          (AiSettingsTab.models, Icons.auto_awesome_rounded),
          (AiSettingsTab.profiles, Icons.tune_rounded),
        ]) {
          await pumpFab(tester, activeTab: tab);

          final fab = readFab(tester);
          expect(fab.icon, icon, reason: 'icon for $tab');
          expect(fab.semanticLabel, isNotEmpty, reason: 'label for $tab');
        }
      },
    );

    testWidgets('per-tab labels are distinct, not a hard-coded string', (
      tester,
    ) async {
      final labels = <String>[];
      for (final tab in AiSettingsTab.values) {
        await pumpFab(tester, activeTab: tab);
        labels.add(readFab(tester).semanticLabel);
      }

      expect(labels.toSet(), hasLength(AiSettingsTab.values.length));
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      await pumpFab(tester, activeTab: AiSettingsTab.providers);

      await tester.tap(find.byType(DesignSystemFloatingActionButton));
      await tester.pump();

      expect(buttonPressed, isTrue);
    });

    testWidgets('changing active tab swaps the rendered icon', (tester) async {
      await pumpFab(tester, activeTab: AiSettingsTab.providers);

      expect(find.byIcon(Icons.add_link_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);

      await pumpFab(tester, activeTab: AiSettingsTab.models);

      expect(find.byIcon(Icons.add_link_rounded), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });
  });
}

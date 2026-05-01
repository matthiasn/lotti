import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_floating_action_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('AiSettingsFloatingActionButton', () {
    late bool buttonPressed;

    setUp(() {
      buttonPressed = false;
    });

    Widget createWidget({
      required AiSettingsTab activeTab,
    }) {
      return MaterialApp(
        theme: resolveTestTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          floatingActionButton: AiSettingsFloatingActionButton(
            activeTab: activeTab,
            onPressed: () => buttonPressed = true,
          ),
        ),
      );
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
        await tester.pumpWidget(createWidget(activeTab: AiSettingsTab.models));
        await tester.pumpAndSettle();

        expect(
          find.byType(DesignSystemBottomNavigationFabPadding),
          findsOneWidget,
        );
        expect(find.byType(DesignSystemFloatingActionButton), findsOneWidget);
      },
    );

    testWidgets(
      'providers tab uses the add-link icon and the localized provider label',
      (tester) async {
        await tester.pumpWidget(
          createWidget(activeTab: AiSettingsTab.providers),
        );
        await tester.pumpAndSettle();

        final fab = readFab(tester);
        expect(fab.icon, Icons.add_link_rounded);
        expect(fab.semanticLabel, isNotEmpty);
      },
    );

    testWidgets(
      'models tab uses the auto-awesome icon and the localized model label',
      (tester) async {
        await tester.pumpWidget(createWidget(activeTab: AiSettingsTab.models));
        await tester.pumpAndSettle();

        final fab = readFab(tester);
        expect(fab.icon, Icons.auto_awesome_rounded);
        expect(fab.semanticLabel, isNotEmpty);
      },
    );

    testWidgets(
      'profiles tab uses the tune icon and the localized profile label',
      (tester) async {
        await tester.pumpWidget(
          createWidget(activeTab: AiSettingsTab.profiles),
        );
        await tester.pumpAndSettle();

        final fab = readFab(tester);
        expect(fab.icon, Icons.tune_rounded);
        expect(fab.semanticLabel, isNotEmpty);
      },
    );

    testWidgets('per-tab labels are distinct, not a hard-coded string', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidget(activeTab: AiSettingsTab.providers),
      );
      await tester.pumpAndSettle();
      final providerLabel = readFab(tester).semanticLabel;

      await tester.pumpWidget(createWidget(activeTab: AiSettingsTab.models));
      await tester.pumpAndSettle();
      final modelLabel = readFab(tester).semanticLabel;

      await tester.pumpWidget(createWidget(activeTab: AiSettingsTab.profiles));
      await tester.pumpAndSettle();
      final profileLabel = readFab(tester).semanticLabel;

      expect(providerLabel, isNot(equals(modelLabel)));
      expect(modelLabel, isNot(equals(profileLabel)));
      expect(providerLabel, isNot(equals(profileLabel)));
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      await tester.pumpWidget(
        createWidget(activeTab: AiSettingsTab.providers),
      );

      await tester.tap(find.byType(DesignSystemFloatingActionButton));
      await tester.pump();

      expect(buttonPressed, isTrue);
    });

    testWidgets('changing active tab swaps the rendered icon', (tester) async {
      await tester.pumpWidget(
        createWidget(activeTab: AiSettingsTab.providers),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_link_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);

      await tester.pumpWidget(createWidget(activeTab: AiSettingsTab.models));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_link_rounded), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });
  });
}

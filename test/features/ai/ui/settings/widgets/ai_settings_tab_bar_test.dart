import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_tab_bar.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('AiSettingsTabBar', () {
    late TabController tabController;
    late List<AiSettingsTab> tabChanges;

    setUp(() {
      tabChanges = [];
    });

    // The TabController is owned by DefaultTabController; no manual disposal.

    Future<void> pumpTabBar(
      WidgetTester tester, {
      int initialIndex = 0,
      ThemeData? theme,
      bool withCallback = true,
      MediaQueryData? mediaQueryData,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          DefaultTabController(
            length: AiSettingsTab.values.length,
            initialIndex: initialIndex,
            child: Builder(
              builder: (context) {
                tabController = DefaultTabController.of(context);
                return Scaffold(
                  body: AiSettingsTabBar(
                    controller: tabController,
                    onTabChanged: withCallback ? tabChanges.add : null,
                  ),
                );
              },
            ),
          ),
          theme: theme,
          mediaQueryData: mediaQueryData,
        ),
      );
      await tester.pump();
    }

    group('rendering', () {
      testWidgets(
        'renders one tab per AiSettingsTab with distinct non-empty '
        'localized labels',
        (tester) async {
          await pumpTabBar(tester);

          final tabs = tester.widgetList<Tab>(find.byType(Tab)).toList();
          expect(tabs, hasLength(AiSettingsTab.values.length));

          final labels = tabs.map((tab) => tab.text).toList();
          for (final label in labels) {
            expect(label, isNotNull);
            expect(label, isNotEmpty);
          }
          expect(labels.toSet(), hasLength(AiSettingsTab.values.length));
        },
      );

      testWidgets('adapts to narrow screen widths', (tester) async {
        await pumpTabBar(
          tester,
          mediaQueryData: const MediaQueryData(size: Size(400, 800)),
        );

        expect(find.byType(Tab), findsNWidgets(AiSettingsTab.values.length));
      });
    });

    group('tab selection', () {
      testWidgets('calls onTabChanged with the tapped tab, for every tab', (
        tester,
      ) async {
        await pumpTabBar(tester);

        // Tap a non-initial tab first so every tap is a real change.
        for (final tab in [
          AiSettingsTab.models,
          AiSettingsTab.profiles,
          AiSettingsTab.providers,
        ]) {
          await tester.tap(find.byType(Tab).at(tab.index));
          await tester.pump();
          expect(tabChanges.last, tab);
        }
        expect(tabChanges, hasLength(3));
      });

      testWidgets('updates controller index when a tab is tapped', (
        tester,
      ) async {
        await pumpTabBar(tester);
        expect(tabController.index, 0);

        await tester.tap(find.byType(Tab).at(1));
        await tester.pump();

        expect(tabController.index, 1);
      });
    });

    group('controller integration', () {
      testWidgets('respects initial tab controller index', (tester) async {
        await pumpTabBar(tester, initialIndex: 1);

        final tabBarWidget = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBarWidget.controller?.index, 1);
      });

      testWidgets('syncs with external controller changes', (tester) async {
        late TabController externalController;

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            DefaultTabController(
              length: AiSettingsTab.values.length,
              child: Builder(
                builder: (context) {
                  externalController = DefaultTabController.of(context);
                  return Scaffold(
                    body: Column(
                      children: [
                        AiSettingsTabBar(
                          controller: externalController,
                          onTabChanged: (_) {},
                        ),
                        ElevatedButton(
                          onPressed: () => externalController.animateTo(2),
                          child: const Text('Go to Profiles'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );

        expect(externalController.index, 0);

        await tester.tap(find.text('Go to Profiles'));
        // animateTo runs the tab transition (kTabScrollDuration = 300ms).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(externalController.index, 2);
      });
    });

    group('edge cases', () {
      testWidgets('tab switching still works without onTabChanged', (
        tester,
      ) async {
        await pumpTabBar(tester, withCallback: false);

        await tester.tap(find.byType(Tab).at(1));
        await tester.pump();

        expect(tabController.index, 1);
      });

      testWidgets('handles rapid tab switching', (tester) async {
        await pumpTabBar(tester);

        await tester.tap(find.byType(Tab).at(1)); // Models
        await tester.tap(find.byType(Tab).at(2)); // Profiles
        await tester.tap(find.byType(Tab).at(0)); // Providers
        await tester.pump();

        expect(tabChanges, [
          AiSettingsTab.models,
          AiSettingsTab.profiles,
          AiSettingsTab.providers,
        ]);
      });

      testWidgets('maintains selection across rebuilds', (tester) async {
        await pumpTabBar(tester);

        await tester.tap(find.byType(Tab).at(1));
        await tester.pump();
        expect(tabController.index, 1);

        await pumpTabBar(tester);

        expect(tabController.index, 1);
      });
    });

    group('theme variations', () {
      testWidgets(
        'indicator has no shadow in light theme and a shadow in dark theme',
        (tester) async {
          for (final (theme, shadowMatcher) in [
            (ThemeData.light(), isEmpty),
            (ThemeData.dark(), isNotEmpty),
          ]) {
            await pumpTabBar(tester, theme: theme);
            // Let the AnimatedTheme transition inside MaterialApp finish so
            // Theme.of reflects the new brightness, not a mid-lerp value.
            await tester.pump(const Duration(milliseconds: 300));

            final tabBar = tester.widget<TabBar>(find.byType(TabBar));
            final indicatorDecoration = tabBar.indicator as BoxDecoration?;
            expect(
              indicatorDecoration?.boxShadow,
              shadowMatcher,
              reason: 'brightness ${theme.brightness}',
            );
          }
        },
      );
    });
  });
}

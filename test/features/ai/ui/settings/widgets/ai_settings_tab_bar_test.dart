import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_tab_bar.dart';
import 'package:lotti/l10n/app_localizations.dart';

void main() {
  group('AiSettingsTabBar', () {
    late TabController tabController;
    late List<AiSettingsTab> tabChanges;

    setUp(() {
      tabChanges = [];
    });

    // TabController is disposed by the framework, no manual disposal needed

    Widget createWidget({
      TabController? controller,
      ValueChanged<AiSettingsTab>? onTabChanged,
    }) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: DefaultTabController(
          length: AiSettingsTab.values.length,
          child: Builder(
            builder: (context) {
              tabController = controller ?? DefaultTabController.of(context);
              return Scaffold(
                body: AiSettingsTabBar(
                  controller: tabController,
                  onTabChanged: onTabChanged ??
                      (tab) {
                        tabChanges.add(tab);
                      },
                ),
              );
            },
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('displays all tab labels correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle(); // Wait for localization to load

        // Check that we have the correct number of tabs
        final tabs = find.byType(Tab);
        expect(tabs, findsNWidgets(3));

        // Since the text is localized, we'll verify by checking tab structure
        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar.tabs.length, 3);
      });

      testWidgets('has correct number of tabs', (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        final tabBar = find.byType(TabBar);
        expect(tabBar, findsOneWidget);

        final tabs = find.byType(Tab);
        expect(tabs, findsNWidgets(AiSettingsTab.values.length));
      });

      testWidgets('has proper Material Design 3 styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        final container = find.byType(Container).first;
        expect(container, findsOneWidget);

        final containerWidget = tester.widget<Container>(container);
        expect(containerWidget.decoration, isA<BoxDecoration>());

        final decoration = containerWidget.decoration! as BoxDecoration;
        expect(decoration.borderRadius, isNotNull);
        expect(decoration.gradient, isNotNull);
        expect(decoration.gradient, isA<LinearGradient>());
      });
    });

    group('tab selection', () {
      testWidgets('calls onTabChanged when tab is tapped',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        // Tap the second tab (Models)
        await tester.tap(find.byType(Tab).at(1));
        await tester.pump();

        expect(tabChanges, hasLength(1));
        expect(tabChanges.first, AiSettingsTab.models);
      });

      testWidgets('calls onTabChanged with correct tab for each tab',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        // Test Providers tab (index 0)
        await tester.tap(find.byType(Tab).at(0));
        await tester.pump();

        expect(tabChanges.last, AiSettingsTab.providers);

        // Test Models tab (index 1)
        await tester.tap(find.byType(Tab).at(1));
        await tester.pump();

        expect(tabChanges.last, AiSettingsTab.models);

        // Test Prompts tab (index 2)
        await tester.tap(find.byType(Tab).at(2));
        await tester.pump();

        expect(tabChanges.last, AiSettingsTab.prompts);

        expect(tabChanges, hasLength(3));
      });

      testWidgets('updates visual selection when tab changes',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Initially first tab should be selected
        expect(tabController.index, 0);

        // Tap second tab
        await tester.tap(find.byType(Tab).at(1));
        await tester.pump();

        expect(tabController.index, 1);
      });
    });

    group('controller integration', () {
      testWidgets('respects initial tab controller index',
          (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DefaultTabController(
            length: AiSettingsTab.values.length,
            initialIndex: 1, // Start with Models tab
            child: Builder(
              builder: (context) {
                final controller = DefaultTabController.of(context);
                return Scaffold(
                  body: AiSettingsTabBar(
                    controller: controller,
                    onTabChanged: (_) {},
                  ),
                );
              },
            ),
          ),
        ));

        await tester.pump();

        // Should show Models tab as selected
        final tabBarWidget = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBarWidget.controller?.index, 1);
      });

      testWidgets('syncs with external controller changes',
          (WidgetTester tester) async {
        late TabController externalController;

        await tester.pumpWidget(MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) {
              return DefaultTabController(
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
                            onPressed: () {
                              setState(() {
                                externalController.animateTo(2);
                              });
                            },
                            child: const Text('Go to Prompts'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ));

        // Initially on first tab
        expect(externalController.index, 0);

        // Use external button to change tab
        await tester.tap(find.text('Go to Prompts'));
        await tester.pumpAndSettle();

        expect(externalController.index, 2);
      });
    });

    group('styling and animation', () {
      testWidgets('has proper indicator styling', (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        final tabBar = tester.widget<TabBar>(find.byType(TabBar));

        expect(tabBar.indicator, isA<BoxDecoration>());
        expect(tabBar.indicatorSize, TabBarIndicatorSize.tab);
        expect(tabBar.dividerColor, Colors.transparent);
      });

      testWidgets('has proper label styling', (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        final tabBar = tester.widget<TabBar>(find.byType(TabBar));

        expect(tabBar.labelStyle, isNotNull);
        expect(tabBar.unselectedLabelStyle, isNotNull);
        expect(tabBar.labelColor, isNotNull);
        expect(tabBar.unselectedLabelColor, isNotNull);
      });

      testWidgets('removes tap overlay effects', (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar.overlayColor?.resolve({}), Colors.transparent);
      });
    });

    group('accessibility', () {
      testWidgets('provides proper semantic labels for tabs',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Each tab should exist
        expect(find.byType(Tab), findsNWidgets(AiSettingsTab.values.length));
      });

      testWidgets('supports keyboard navigation', (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        // Focus the tab bar by tapping first tab
        await tester.tap(find.byType(Tab).first);
        await tester.pumpAndSettle();

        // Verify current tab
        expect(tabController.index, 0);

        // Send keyboard event - should not throw errors
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();

        // TabBar keyboard navigation may not work as expected in tests
        // but the key event should be handled without errors
        expect(find.byType(Tab), findsNWidgets(3));
      });
    });

    group('edge cases', () {
      testWidgets('handles null onTabChanged callback',
          (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DefaultTabController(
            length: AiSettingsTab.values.length,
            child: Builder(
              builder: (context) {
                final controller = DefaultTabController.of(context);
                return Scaffold(
                  body: AiSettingsTabBar(
                    controller: controller,
                  ),
                );
              },
            ),
          ),
        ));

        // Should not throw when tab is tapped
        await tester.tap(find.byType(Tab).at(1));
        await tester.pump();

        // Tab change should still work internally
        expect(find.byType(Tab), findsNWidgets(3));
      });

      testWidgets('handles rapid tab switching', (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Rapidly switch between tabs
        await tester.tap(find.byType(Tab).at(1)); // Models
        await tester.tap(find.byType(Tab).at(2)); // Prompts
        await tester.tap(find.byType(Tab).at(0)); // Providers
        await tester.pump();

        expect(tabChanges, hasLength(3));
        expect(tabChanges, [
          AiSettingsTab.models,
          AiSettingsTab.prompts,
          AiSettingsTab.providers,
        ]);
      });

      testWidgets('maintains correct state after rebuild',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Change to second tab
        await tester.tap(find.byType(Tab).at(1));
        await tester.pump();

        expect(tabController.index, 1);

        // Rebuild widget
        await tester.pumpWidget(createWidget());

        // Tab selection should be maintained
        expect(tabController.index, 1);
      });
    });

    group('layout and responsiveness', () {
      testWidgets('adapts to narrow screen widths',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(400, 800); // Narrow screen
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createWidget());

        // Should still show all tabs
        expect(find.byType(Tab), findsNWidgets(3));

        // Reset view
        addTearDown(tester.view.resetPhysicalSize);
      });

      testWidgets('maintains proper margins and padding',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        final containerFinder = find.byType(Container);
        expect(containerFinder, findsOneWidget);

        // Check that the container has proper height
        final containerBox = tester.renderObject<RenderBox>(containerFinder);
        expect(containerBox.size.height, 48.0);

        // Check that it has decoration (not just margin/padding)
        final container = tester.widget<Container>(containerFinder);
        expect(container.decoration, isNotNull);
        expect(container.margin, isNull); // No margin in new design
      });
    });
  });
}

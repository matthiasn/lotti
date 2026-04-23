import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/pages/settings_column_scope.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';

import '../../../../widget_test_utils.dart';

/// Tests the InheritedWidget contract that lets the desktop multi-
/// column settings stack tell child pages to skip their own headers.
///
/// The scope itself is trivial — the behaviour under test is that
/// [SliverBoxAdapterPage] reads it and skips the
/// [SettingsPageHeader] sliver when the scope is present.
void main() {
  setUp(() async {
    await setUpTestGetIt();
    getIt.registerSingleton<UserActivityService>(UserActivityService());
  });
  tearDown(tearDownTestGetIt);

  group('SettingsColumnScope + SliverBoxAdapterPage integration', () {
    testWidgets(
      'SliverBoxAdapterPage renders its SettingsPageHeader sliver by '
      'default (outside a SettingsColumnScope) — preserves the existing '
      'single-page behaviour everywhere except the desktop multi-column '
      'stack',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const SliverBoxAdapterPage(
              title: 'Default page title',
              child: SizedBox(height: 100),
            ),
            mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SettingsPageHeader), findsOneWidget);
        // And the title itself is on screen via the header.
        expect(find.text('Default page title'), findsOneWidget);
      },
    );

    testWidgets(
      'SliverBoxAdapterPage skips its SettingsPageHeader sliver when '
      'rendered inside a SettingsColumnScope — the multi-column root '
      'page already names the leaf at the top of the stack, so a '
      'per-column header is redundant',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const SettingsColumnScope(
              child: SliverBoxAdapterPage(
                title: 'Should not appear as page header',
                child: SizedBox(height: 100),
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(SettingsPageHeader),
          findsNothing,
          reason:
              'SettingsColumnScope signals the parent already owns the '
              'header; SliverBoxAdapterPage must not render its own.',
        );
      },
    );

    testWidgets(
      'SettingsColumnScope.of returns the nearest enclosing scope or '
      'null — the core InheritedWidget contract the page relies on',
      (tester) async {
        SettingsColumnScope? insideScope;
        SettingsColumnScope? outsideScope;

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                Builder(
                  builder: (context) {
                    outsideScope = SettingsColumnScope.of(context);
                    return const SizedBox.shrink();
                  },
                ),
                SettingsColumnScope(
                  child: Builder(
                    builder: (context) {
                      insideScope = SettingsColumnScope.of(context);
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
        );

        expect(outsideScope, isNull);
        expect(insideScope, isNotNull);
      },
    );
  });
}

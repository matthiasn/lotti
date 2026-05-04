import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/settings/ui/pages/definitions_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

/// Builds a list of [configFlagProvider] overrides that map each
/// flag to a constant boolean value. Mirrors the helper used in
/// `logging_settings_page_test.dart` so tests stay consistent.
List<Override> _flagOverrides(Map<String, bool> flags) => flags.entries
    .map(
      (e) => configFlagProvider(
        e.key,
      ).overrideWith((ref) => Stream.value(e.value)),
    )
    .toList();

Future<void> _pumpPage(
  WidgetTester tester, {
  required bool enableHabits,
  required bool enableDashboards,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      const Material(child: DefinitionsPage()),
      overrides: _flagOverrides({
        enableHabitsPageFlag: enableHabits,
        enableDashboardsPageFlag: enableDashboards,
      }),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the page inside a real `BeamerDelegate` so `onTap` callbacks
/// that call `context.beamToNamed(...)` succeed and the resulting URL
/// is observable from the test. Routes are no-op stubs — the
/// destination doesn't matter, only that the beam request happened.
Future<BeamerDelegate> _pumpPageWithBeamer(
  WidgetTester tester, {
  bool enableHabits = true,
  bool enableDashboards = true,
}) async {
  final delegate = BeamerDelegate(
    locationBuilder: RoutesLocationBuilder(
      routes: <String, Widget Function(BuildContext, BeamState, Object?)>{
        '/': (_, _, _) => const Material(child: DefinitionsPage()),
        '/settings/habits': (_, _, _) => const SizedBox.shrink(),
        '/settings/categories': (_, _, _) => const SizedBox.shrink(),
        '/settings/labels': (_, _, _) => const SizedBox.shrink(),
        '/settings/dashboards': (_, _, _) => const SizedBox.shrink(),
        '/settings/measurables': (_, _, _) => const SizedBox.shrink(),
      },
    ).call,
  );

  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      BeamerProvider(
        routerDelegate: delegate,
        child: const Material(child: DefinitionsPage()),
      ),
      overrides: _flagOverrides({
        enableHabitsPageFlag: enableHabits,
        enableDashboardsPageFlag: enableDashboards,
      }),
    ),
  );
  await tester.pumpAndSettle();
  return delegate;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // `setUpTestGetIt()` registers the canonical mocks (JournalDb,
    // SettingsDb, UpdateNotifications, LoggingService, …) used across
    // the suite. We extend it with the extras DefinitionsPage needs
    // (UserActivityService) and stub `watchConfigFlag` on the
    // already-registered mock so flag-gated rows resolve.
    final mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<UserActivityService>(UserActivityService());
      },
    );
    when(
      () => mocks.journalDb.watchConfigFlag(any()),
    ).thenAnswer((_) => Stream.value(false));
  });

  tearDown(tearDownTestGetIt);

  group('DefinitionsPage', () {
    testWidgets(
      'with both flags ON, shows habits / categories / labels / '
      'dashboards / measurables in that order',
      (tester) async {
        await _pumpPage(tester, enableHabits: true, enableDashboards: true);

        expect(find.byType(DesignSystemListItem), findsNWidgets(5));

        final context = tester.element(find.byType(DefinitionsPage));
        // Title comes from the dedicated localization key, not from
        // any of the entity titles below.
        expect(
          find.text(context.messages.settingsDefinitionsTitle),
          findsOneWidget,
        );
        // Each row's title and subtitle must render once — covers the
        // localization wiring as well as the row count.
        for (final entry in <(String, String)>[
          (
            context.messages.settingsHabitsTitle,
            context.messages.settingsHabitsSubtitle,
          ),
          (
            context.messages.settingsCategoriesTitle,
            context.messages.settingsCategoriesSubtitle,
          ),
          (
            context.messages.settingsLabelsTitle,
            context.messages.settingsLabelsSubtitle,
          ),
          (
            context.messages.settingsDashboardsTitle,
            context.messages.settingsDashboardsSubtitle,
          ),
          (
            context.messages.settingsMeasurablesTitle,
            context.messages.settingsMeasurablesSubtitle,
          ),
        ]) {
          expect(find.text(entry.$1), findsOneWidget);
          expect(find.text(entry.$2), findsOneWidget);
        }

        // Visual order locks with rows.indexOf — habits sits above
        // categories which sits above labels … etc.
        final rows = tester
            .widgetList<DesignSystemListItem>(
              find.byType(DesignSystemListItem),
            )
            .toList();
        expect(rows.map((r) => r.title), [
          context.messages.settingsHabitsTitle,
          context.messages.settingsCategoriesTitle,
          context.messages.settingsLabelsTitle,
          context.messages.settingsDashboardsTitle,
          context.messages.settingsMeasurablesTitle,
        ]);
      },
    );

    testWidgets(
      'with habits OFF, drops the habits row but keeps every other entry',
      (tester) async {
        await _pumpPage(tester, enableHabits: false, enableDashboards: true);

        expect(find.byType(DesignSystemListItem), findsNWidgets(4));

        final context = tester.element(find.byType(DefinitionsPage));
        expect(find.text(context.messages.settingsHabitsTitle), findsNothing);
        expect(
          find.text(context.messages.settingsCategoriesTitle),
          findsOneWidget,
        );
        expect(
          find.text(context.messages.settingsDashboardsTitle),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'with dashboards OFF, drops the dashboards row but keeps measurables',
      (tester) async {
        // Measurables is unconditional even though dashboards is gated
        // — this guards the regression where measurables used to share
        // the dashboards flag.
        await _pumpPage(tester, enableHabits: true, enableDashboards: false);

        expect(find.byType(DesignSystemListItem), findsNWidgets(4));

        final context = tester.element(find.byType(DefinitionsPage));
        expect(
          find.text(context.messages.settingsDashboardsTitle),
          findsNothing,
        );
        expect(
          find.text(context.messages.settingsMeasurablesTitle),
          findsOneWidget,
        );
        expect(find.text(context.messages.settingsHabitsTitle), findsOneWidget);
      },
    );

    testWidgets(
      'with both flags OFF, shows just the always-on trio',
      (tester) async {
        await _pumpPage(tester, enableHabits: false, enableDashboards: false);

        expect(find.byType(DesignSystemListItem), findsNWidgets(3));

        final context = tester.element(find.byType(DefinitionsPage));
        final rows = tester
            .widgetList<DesignSystemListItem>(
              find.byType(DesignSystemListItem),
            )
            .toList();
        expect(rows.map((r) => r.title), [
          context.messages.settingsCategoriesTitle,
          context.messages.settingsLabelsTitle,
          context.messages.settingsMeasurablesTitle,
        ]);
      },
    );

    testWidgets('uses SettingsIcon for the leading widget on every row', (
      tester,
    ) async {
      await _pumpPage(tester, enableHabits: true, enableDashboards: true);

      // One leading SettingsIcon per row; the trailing chevron is a
      // plain Icon, not another SettingsIcon, so we assert it
      // separately by icon data.
      expect(find.byType(SettingsIcon), findsNWidgets(5));
      expect(
        find.byIcon(Icons.chevron_right_rounded),
        findsNWidgets(5),
      );
    });

    testWidgets(
      'every row beams to its canonical /settings/<entity> URL on tap',
      (tester) async {
        // Each row must beam to the matching entity-list page —
        // covers the onTap closures, which would otherwise be
        // unreachable code under coverage.
        final delegate = await _pumpPageWithBeamer(tester);
        final context = tester.element(find.byType(DefinitionsPage));

        for (final entry in <(String, String)>[
          (context.messages.settingsHabitsTitle, '/settings/habits'),
          (
            context.messages.settingsCategoriesTitle,
            '/settings/categories',
          ),
          (context.messages.settingsLabelsTitle, '/settings/labels'),
          (
            context.messages.settingsDashboardsTitle,
            '/settings/dashboards',
          ),
          (
            context.messages.settingsMeasurablesTitle,
            '/settings/measurables',
          ),
        ]) {
          await tester.tap(find.text(entry.$1));
          await tester.pumpAndSettle();
          expect(
            delegate.configuration.uri.toString(),
            entry.$2,
            reason: 'tapping "${entry.$1}" should beam to ${entry.$2}',
          );
        }
      },
    );

    testWidgets(
      'every row except the last reserves a divider; last row does not',
      (tester) async {
        await _pumpPage(tester, enableHabits: true, enableDashboards: true);

        final rows = tester
            .widgetList<DesignSystemListItem>(
              find.byType(DesignSystemListItem),
            )
            .toList();
        for (var i = 0; i < rows.length; i++) {
          expect(
            rows[i].showDivider,
            i < rows.length - 1,
            reason: 'row $i divider visibility',
          );
        }
      },
    );
  });
}

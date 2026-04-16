import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

/// Finds both [Switch] and [CupertinoSwitch] widgets, since
/// `Switch.adaptive` renders platform-specifically.
Finder findSwitches() =>
    find.byWidgetPredicate((w) => w is Switch || w is CupertinoSwitch);

/// Extracts (value, onChanged != null) from a switch widget regardless of
/// whether it rendered as [Switch] or [CupertinoSwitch].
({bool value, bool enabled}) switchState(Widget w) {
  if (w is Switch) return (value: w.value, enabled: w.onChanged != null);
  if (w is CupertinoSwitch) {
    return (value: w.value, enabled: w.onChanged != null);
  }
  throw ArgumentError('Not a switch widget: ${w.runtimeType}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;

  setUp(() {
    mockJournalDb = MockJournalDb();

    when(
      () => mockJournalDb.watchConfigFlag(any()),
    ).thenAnswer((_) => Stream.value(true));

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UserActivityService>(UserActivityService());

    ensureThemingServicesRegistered();
  });

  tearDown(getIt.reset);

  /// Builds overrides for [configFlagProvider] with the given flag values.
  List<Override> flagOverrides(Map<String, bool> flags) {
    return flags.entries
        .map(
          (e) => configFlagProvider(e.key).overrideWith(
            (ref) => Stream.value(e.value),
          ),
        )
        .toList();
  }

  /// Default overrides: all flags enabled.
  List<Override> allEnabledOverrides() => flagOverrides({
    enableLoggingFlag: true,
    logAgentRuntimeFlag: true,
    logAgentWorkflowFlag: true,
    logSyncFlag: true,
    logSlowQueriesFlag: true,
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const Material(child: LoggingSettingsPage()),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('LoggingSettingsPage', () {
    testWidgets('renders all toggle cards', (tester) async {
      await pumpPage(tester, overrides: allEnabledOverrides());

      final context = tester.element(find.byType(LoggingSettingsPage));

      expect(
        find.text(context.messages.settingsLoggingGlobalToggle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsLoggingAgentRuntime),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsLoggingAgentWorkflow),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsLoggingSync),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsLoggingSlowQueries),
        findsOneWidget,
      );
    });

    testWidgets('renders subtitles for all cards', (tester) async {
      await pumpPage(tester, overrides: allEnabledOverrides());

      final context = tester.element(find.byType(LoggingSettingsPage));

      expect(
        find.text(context.messages.settingsLoggingGlobalToggleSubtitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsLoggingAgentRuntimeSubtitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsLoggingAgentWorkflowSubtitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsLoggingSyncSubtitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsLoggingSlowQueriesSubtitle),
        findsOneWidget,
      );
    });

    testWidgets('shows five switch toggles', (tester) async {
      await pumpPage(tester, overrides: allEnabledOverrides());

      // Global + 4 domain toggles = 5 switches
      expect(findSwitches(), findsNWidgets(5));
    });

    testWidgets('domain switches are disabled when global logging is off', (
      tester,
    ) async {
      final overrides = flagOverrides({
        enableLoggingFlag: false,
        logAgentRuntimeFlag: true,
        logAgentWorkflowFlag: true,
        logSyncFlag: true,
        logSlowQueriesFlag: true,
      });

      await pumpPage(tester, overrides: overrides);

      final switches = tester.widgetList(findSwitches()).toList();
      expect(switches, hasLength(5));

      final states = switches.map(switchState).toList();

      // The global toggle (first) should still be enabled.
      expect(states[0].enabled, isTrue);

      // Domain toggles (indices 1-4) should be disabled.
      for (var i = 1; i < states.length; i++) {
        expect(
          states[i].enabled,
          isFalse,
          reason: 'Domain switch $i should be disabled when logging is off',
        );
      }
    });

    testWidgets('tapping global toggle calls toggleConfigFlag', (tester) async {
      when(
        () => mockJournalDb.toggleConfigFlag(any()),
      ).thenAnswer((_) async {});

      await pumpPage(tester, overrides: allEnabledOverrides());

      await tester.tap(findSwitches().first);
      await tester.pump();

      verify(() => mockJournalDb.toggleConfigFlag(enableLoggingFlag)).called(1);
    });

    testWidgets('tapping domain toggles calls correct toggleConfigFlag', (
      tester,
    ) async {
      when(
        () => mockJournalDb.toggleConfigFlag(any()),
      ).thenAnswer((_) async {});

      await pumpPage(tester, overrides: allEnabledOverrides());

      // Tap agent runtime toggle (index 1).
      await tester.tap(findSwitches().at(1));
      await tester.pump();
      verify(
        () => mockJournalDb.toggleConfigFlag(logAgentRuntimeFlag),
      ).called(1);

      // Tap agent workflow toggle (index 2).
      await tester.tap(findSwitches().at(2));
      await tester.pump();
      verify(
        () => mockJournalDb.toggleConfigFlag(logAgentWorkflowFlag),
      ).called(1);

      // Tap sync toggle (index 3).
      await tester.tap(findSwitches().at(3));
      await tester.pump();
      verify(() => mockJournalDb.toggleConfigFlag(logSyncFlag)).called(1);

      // Tap slow query toggle (index 4).
      await tester.tap(findSwitches().at(4));
      await tester.pump();
      verify(
        () => mockJournalDb.toggleConfigFlag(logSlowQueriesFlag),
      ).called(1);
    });

    testWidgets('switch values reflect mixed flag state', (tester) async {
      final overrides = flagOverrides({
        enableLoggingFlag: true,
        logAgentRuntimeFlag: true,
        logAgentWorkflowFlag: false,
        logSyncFlag: false,
        logSlowQueriesFlag: true,
      });

      await pumpPage(tester, overrides: overrides);

      final states = tester
          .widgetList(findSwitches())
          .map(switchState)
          .toList();
      expect(states, hasLength(5));

      expect(states[0].value, isTrue, reason: 'Global should be on');
      expect(states[1].value, isTrue, reason: 'Agent runtime should be on');
      expect(states[2].value, isFalse, reason: 'Agent workflow should be off');
      expect(states[3].value, isFalse, reason: 'Sync should be off');
      expect(
        states[4].value,
        isTrue,
        reason: 'Slow query logging should be on',
      );
    });

    testWidgets('renders correct icons for each card', (tester) async {
      await pumpPage(tester, overrides: allEnabledOverrides());

      expect(find.byIcon(Icons.article_rounded), findsAtLeast(1));
      expect(find.byIcon(Icons.memory_rounded), findsAtLeast(1));
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsAtLeast(1));
      expect(find.byIcon(Icons.sync_rounded), findsAtLeast(1));
      expect(find.byIcon(Icons.speed_rounded), findsAtLeast(1));
    });

    testWidgets('uses design system grouped list layout', (tester) async {
      await pumpPage(tester, overrides: allEnabledOverrides());

      expect(find.byType(DesignSystemGroupedList), findsOneWidget);
      // 5 fixed items: global toggle + 4 domain toggles.
      expect(find.byType(DesignSystemListItem), findsNWidgets(5));
      expect(find.byType(SettingsIcon), findsNWidgets(5));
    });

    testWidgets('shows dividers between items but not after last', (
      tester,
    ) async {
      await pumpPage(tester, overrides: allEnabledOverrides());
      expectDividersOnAllButLast(tester);
    });

    testWidgets('items do not appear dimmed despite having no onTap', (
      tester,
    ) async {
      await pumpPage(tester, overrides: allEnabledOverrides());

      final items = tester.widgetList<DesignSystemListItem>(
        find.byType(DesignSystemListItem),
      );

      for (final item in items) {
        expect(
          item.forcedState,
          DesignSystemListItemVisualState.idle,
          reason: 'Toggle rows should not appear disabled',
        );
      }
    });
  });
}

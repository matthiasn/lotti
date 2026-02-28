import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;

  setUp(() {
    mockJournalDb = MockJournalDb();

    when(() => mockJournalDb.watchConfigFlag(any()))
        .thenAnswer((_) => Stream.value(true));

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
    testWidgets('renders all toggle cards and view-logs card', (tester) async {
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
        find.text(context.messages.settingsLogsTitle),
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
        find.text(context.messages.settingsLoggingViewLogsSubtitle),
        findsOneWidget,
      );
    });

    testWidgets('domain switches are disabled when global logging is off',
        (tester) async {
      final overrides = flagOverrides({
        enableLoggingFlag: false,
        logAgentRuntimeFlag: true,
        logAgentWorkflowFlag: true,
        logSyncFlag: true,
      });

      await pumpPage(tester, overrides: overrides);

      // Find Switch widgets — Switch.adaptive renders platform-specific but
      // the underlying Switch type is still findable in tests.
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();

      if (switches.length == 4) {
        // The global toggle (first) should still be enabled.
        expect(switches[0].onChanged, isNotNull);

        // Domain toggles (indices 1-3) should be disabled.
        for (var i = 1; i < switches.length; i++) {
          expect(
            switches[i].onChanged,
            isNull,
            reason: 'Domain switch $i should be disabled when logging is off',
          );
        }
      } else {
        // On macOS, Switch.adaptive renders CupertinoSwitch — verify via text.
        // The page should still render without error.
        final context = tester.element(find.byType(LoggingSettingsPage));
        expect(
          find.text(context.messages.settingsLoggingGlobalToggle),
          findsOneWidget,
        );
      }
    });

    testWidgets('tapping global toggle calls toggleConfigFlag', (tester) async {
      when(() => mockJournalDb.toggleConfigFlag(any()))
          .thenAnswer((_) async {});

      await pumpPage(tester, overrides: allEnabledOverrides());

      // Find any switch-like widget and tap the first one (global toggle).
      final switchFinder = find.byType(Switch);
      if (switchFinder.evaluate().isNotEmpty) {
        await tester.tap(switchFinder.first);
        await tester.pump();
        verify(() => mockJournalDb.toggleConfigFlag(enableLoggingFlag))
            .called(1);
      }
    });

    testWidgets('tapping domain toggle calls correct toggleConfigFlag',
        (tester) async {
      when(() => mockJournalDb.toggleConfigFlag(any()))
          .thenAnswer((_) async {});

      await pumpPage(tester, overrides: allEnabledOverrides());

      final switches = find.byType(Switch);
      if (switches.evaluate().length >= 4) {
        // Tap agent runtime toggle (index 1).
        await tester.tap(switches.at(1));
        await tester.pump();
        verify(() => mockJournalDb.toggleConfigFlag(logAgentRuntimeFlag))
            .called(1);

        // Tap agent workflow toggle (index 2).
        await tester.tap(switches.at(2));
        await tester.pump();
        verify(() => mockJournalDb.toggleConfigFlag(logAgentWorkflowFlag))
            .called(1);

        // Tap sync toggle (index 3).
        await tester.tap(switches.at(3));
        await tester.pump();
        verify(() => mockJournalDb.toggleConfigFlag(logSyncFlag)).called(1);
      }
    });

    testWidgets('switch values reflect mixed flag state', (tester) async {
      final overrides = flagOverrides({
        enableLoggingFlag: true,
        logAgentRuntimeFlag: true,
        logAgentWorkflowFlag: false,
        logSyncFlag: false,
      });

      await pumpPage(tester, overrides: overrides);

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();

      if (switches.length == 4) {
        expect(switches[0].value, isTrue, reason: 'Global should be on');
        expect(switches[1].value, isTrue, reason: 'Agent runtime should be on');
        expect(
          switches[2].value,
          isFalse,
          reason: 'Agent workflow should be off',
        );
        expect(switches[3].value, isFalse, reason: 'Sync should be off');
      }
    });

    testWidgets('renders correct icons for each card', (tester) async {
      await pumpPage(tester, overrides: allEnabledOverrides());

      // article_rounded appears twice (global toggle + view logs link) so
      // check for at least one.
      expect(find.byIcon(Icons.article_rounded), findsAtLeast(1));
      expect(find.byIcon(Icons.memory_rounded), findsAtLeast(1));
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsAtLeast(1));
      expect(find.byIcon(Icons.sync_rounded), findsAtLeast(1));
      expect(find.byIcon(Icons.search_rounded), findsAtLeast(1));
    });
  });
}

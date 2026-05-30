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
import 'package:lotti/services/logging_domains.dart';
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

// 1 global toggle + one per LogDomain + 1 slow-query toggle.
final int _expectedSwitchCount = LogDomain.values.length + 2;

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
  /// Flags not listed fall back to the mocked JournalDb (true).
  List<Override> flagOverrides(Map<String, bool> flags) {
    return flags.entries
        .map(
          (e) => configFlagProvider(e.key).overrideWith(
            (ref) => Stream.value(e.value),
          ),
        )
        .toList();
  }

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
    testWidgets('renders global, every domain, and slow-query toggle', (
      tester,
    ) async {
      await pumpPage(tester);

      final context = tester.element(find.byType(LoggingSettingsPage));

      expect(
        find.text(context.messages.settingsLoggingGlobalToggle),
        findsOneWidget,
      );
      // A representative sample of domain labels (localized).
      expect(find.text(context.messages.loggingDomainSync), findsOneWidget);
      expect(find.text(context.messages.loggingDomainAi), findsOneWidget);
      expect(
        find.text(context.messages.loggingDomainAgentWorkflow),
        findsOneWidget,
      );
      expect(find.text(context.messages.loggingDomainGeneral), findsOneWidget);
      expect(
        find.text(context.messages.settingsLoggingSlowQueries),
        findsOneWidget,
      );
    });

    testWidgets('shows one switch per row', (tester) async {
      await pumpPage(tester);
      expect(findSwitches(), findsNWidgets(_expectedSwitchCount));
    });

    testWidgets('domain + slow-query switches disabled when global is off', (
      tester,
    ) async {
      await pumpPage(
        tester,
        overrides: flagOverrides({enableLoggingFlag: false}),
      );

      final states = tester
          .widgetList(findSwitches())
          .map(switchState)
          .toList();
      expect(states, hasLength(_expectedSwitchCount));

      // The global toggle (first) stays enabled.
      expect(states.first.enabled, isTrue);
      // All others (domains + slow query) are disabled.
      for (var i = 1; i < states.length; i++) {
        expect(
          states[i].enabled,
          isFalse,
          reason: 'switch $i should be disabled when global logging is off',
        );
      }
    });

    testWidgets('tapping global toggle calls toggleConfigFlag', (tester) async {
      when(
        () => mockJournalDb.toggleConfigFlag(any()),
      ).thenAnswer((_) async {});

      await pumpPage(tester);

      await tester.tap(findSwitches().first);
      await tester.pump();

      verify(() => mockJournalDb.toggleConfigFlag(enableLoggingFlag)).called(1);
    });

    testWidgets('tapping a domain toggle calls its flag', (tester) async {
      when(
        () => mockJournalDb.toggleConfigFlag(any()),
      ).thenAnswer((_) async {});

      await pumpPage(
        tester,
        overrides: flagOverrides({enableLoggingFlag: true}),
      );

      // Index 0 is the global toggle; index 1 is the first domain (sync).
      await tester.tap(findSwitches().at(1));
      await tester.pump();
      verify(
        () => mockJournalDb.toggleConfigFlag(LogDomain.values.first.flagName),
      ).called(1);
    });

    testWidgets('tapping slow-query toggle calls its flag', (tester) async {
      when(
        () => mockJournalDb.toggleConfigFlag(any()),
      ).thenAnswer((_) async {});

      await pumpPage(
        tester,
        overrides: flagOverrides({enableLoggingFlag: true}),
      );

      // The slow-query toggle is the last row and may be off-screen.
      final slowQuery = findSwitches().at(_expectedSwitchCount - 1);
      await tester.ensureVisible(slowQuery);
      await tester.pumpAndSettle();
      await tester.tap(slowQuery);
      await tester.pump();
      verify(
        () => mockJournalDb.toggleConfigFlag(logSlowQueriesFlag),
      ).called(1);
    });

    testWidgets('switch values reflect mixed flag state', (tester) async {
      await pumpPage(
        tester,
        overrides: flagOverrides({
          enableLoggingFlag: true,
          LogDomain.sync.flagName: false,
          LogDomain.ai.flagName: true,
          logSlowQueriesFlag: false,
        }),
      );

      final states = tester
          .widgetList(findSwitches())
          .map(switchState)
          .toList();
      expect(states, hasLength(_expectedSwitchCount));

      expect(states.first.value, isTrue, reason: 'global on');
      // index 1 == sync (off), index 2 == ai (on).
      expect(states[1].value, isFalse, reason: 'sync off');
      expect(states[2].value, isTrue, reason: 'ai on');
      expect(states.last.value, isFalse, reason: 'slow queries off');
    });

    testWidgets('renders global, domain, and slow-query icons', (tester) async {
      await pumpPage(tester);

      expect(find.byIcon(Icons.article_rounded), findsOneWidget);
      // One tune icon per domain.
      expect(
        find.byIcon(Icons.tune_rounded),
        findsNWidgets(LogDomain.values.length),
      );
      expect(find.byIcon(Icons.speed_rounded), findsOneWidget);
    });

    testWidgets('uses design system grouped list layout', (tester) async {
      await pumpPage(tester);

      expect(find.byType(DesignSystemGroupedList), findsOneWidget);
      expect(
        find.byType(DesignSystemListItem),
        findsNWidgets(_expectedSwitchCount),
      );
      expect(find.byType(SettingsIcon), findsNWidgets(_expectedSwitchCount));
    });

    testWidgets('shows dividers between items but not after last', (
      tester,
    ) async {
      await pumpPage(tester);
      expectDividersOnAllButLast(tester);
    });

    testWidgets('items do not appear dimmed despite having no onTap', (
      tester,
    ) async {
      await pumpPage(tester);

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

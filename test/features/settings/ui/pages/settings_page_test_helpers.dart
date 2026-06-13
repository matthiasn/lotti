import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Test controller that returns empty state (no infinite animation).
class TestWhatsNewController extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async => const WhatsNewState();
}

/// Shared test fixture for `SettingsPage` tests that need the desktop
/// layout: a journal-db mock, a settings-db mock, a desktop-mode
/// `NavService`, a `UserActivityService`, themed theming services, and
/// a pump helper that wires the standard Riverpod overrides. The two
/// desktop-mode groups in this file used to duplicate this setup line
/// for line — they share it now instead.
class DesktopSettingsBench {
  DesktopSettingsBench._({
    required this.mockDb,
    required this.mockSettingsDb,
    required this.navService,
  });

  static Future<DesktopSettingsBench> create() async {
    await getIt.reset();

    final mockDb = MockJournalDb();
    final mockSettingsDb = MockSettingsDb();

    when(mockDb.getJournalCount).thenAnswer((_) async => 0);
    when(mockDb.watchConfigFlags).thenAnswer(
      (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
    );
    when(
      () => mockDb.watchConfigFlag(any()),
    ).thenAnswer((_) => Stream.value(false));
    when(
      () => mockSettingsDb.itemByKey(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockSettingsDb.itemsByKeys(any()),
    ).thenAnswer((_) async => <String, String?>{});
    when(
      () => mockSettingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);

    final navService = NavService(
      journalDb: mockDb,
      settingsDb: mockSettingsDb,
    )..isDesktopMode = true;

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<NavService>(navService)
      ..registerSingleton<UserActivityService>(UserActivityService());

    ensureThemingServicesRegistered();

    return DesktopSettingsBench._(
      mockDb: mockDb,
      mockSettingsDb: mockSettingsDb,
      navService: navService,
    );
  }

  final MockJournalDb mockDb;
  final MockSettingsDb mockSettingsDb;
  final NavService navService;

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SettingsPage(),
        theme: DesignSystemTheme.light(),
        mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
        overrides: [
          journalDbProvider.overrideWithValue(mockDb),
          whatsNewControllerProvider.overrideWith(
            TestWhatsNewController.new,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose() async {
    await getIt.reset();
  }
}

/// Creates a [BeamerDelegate] that recognises every settings sub-route so
/// that `context.beamToNamed(...)` calls inside [SettingsPage] succeed and
/// the resulting URL can be read back in navigation-tap tests.
BeamerDelegate hMakeBeamerDelegate() {
  return BeamerDelegate(
    locationBuilder: RoutesLocationBuilder(
      routes: <String, Widget Function(BuildContext, BeamState, Object?)>{
        '/': (_, _, _) => const SettingsPage(),
        '/settings/ai': (_, _, _) => const SizedBox.shrink(),
        '/settings/agents': (_, _, _) => const SizedBox.shrink(),
        '/settings/sync': (_, _, _) => const SizedBox.shrink(),
        '/settings/definitions': (_, _, _) => const SizedBox.shrink(),
        '/settings/theming': (_, _, _) => const SizedBox.shrink(),
        '/settings/advanced': (_, _, _) => const SizedBox.shrink(),
      },
    ).call,
  );
}

Future<void> hPumpSettingsPage(
  WidgetTester tester,
  MockJournalDb mockJournalDb,
) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      const SettingsPage(),
      theme: DesignSystemTheme.light(),
      overrides: [
        journalDbProvider.overrideWithValue(mockJournalDb),
        whatsNewControllerProvider.overrideWith(
          TestWhatsNewController.new,
        ),
      ],
    ),
  );

  await tester.pumpAndSettle();
}

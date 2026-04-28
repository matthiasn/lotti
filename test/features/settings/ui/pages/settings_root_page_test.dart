import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/settings/ui/pages/settings_root_page.dart';
import 'package:lotti/features/settings_v2/ui/pages/settings_v2_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class _TestWhatsNewController extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async => const WhatsNewState();
}

const _desktopMediaQuery = MediaQueryData(size: Size(1600, 900));
const _mobileMediaQuery = MediaQueryData(size: Size(800, 600));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockSettingsDb mockSettingsDb;
  late NavService navService;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockSettingsDb = MockSettingsDb();

    when(mockJournalDb.watchConfigFlags).thenAnswer(
      (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
    );
    when(mockJournalDb.getJournalCount).thenAnswer((_) async => 0);
    when(
      () => mockJournalDb.watchConfigFlag(any()),
    ).thenAnswer((_) => Stream.value(false));
    when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
    when(
      () => mockSettingsDb.itemsByKeys(any()),
    ).thenAnswer((_) async => <String, String?>{});
    when(
      () => mockSettingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);

    navService = NavService(
      journalDb: mockJournalDb,
      settingsDb: mockSettingsDb,
    );

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<SettingsDb>(mockSettingsDb)
      ..registerSingleton<NavService>(navService)
      ..registerSingleton<UserActivityService>(UserActivityService());

    ensureThemingServicesRegistered();
  });

  tearDown(() async {
    await navService.dispose();
    await getIt.reset();
  });

  List<Override> buildOverrides() => [
    journalDbProvider.overrideWithValue(mockJournalDb),
    whatsNewControllerProvider.overrideWith(_TestWhatsNewController.new),
    paneWidthControllerProvider.overrideWith(PaneWidthController.new),
  ];

  Future<void> pumpRoot(
    WidgetTester tester, {
    MediaQueryData mediaQuery = _desktopMediaQuery,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const SettingsRootPage(),
        mediaQueryData: mediaQuery,
        overrides: buildOverrides(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SettingsRootPage', () {
    testWidgets(
      'mobile viewport falls back to the single-pane SettingsPage',
      (tester) async {
        await pumpRoot(tester, mediaQuery: _mobileMediaQuery);

        expect(find.byType(SettingsPage), findsOneWidget);
        expect(
          find.byType(SettingsV2Page),
          findsNothing,
          reason:
              'Mobile is gated to the legacy single-page push-navigation '
              'flow; the V2 tree-nav layout is desktop-only.',
        );
      },
    );

    testWidgets(
      'desktop viewport renders the SettingsV2 tree-nav layout',
      (tester) async {
        navService.isDesktopMode = true;

        await pumpRoot(tester);

        expect(find.byType(SettingsV2Page), findsOneWidget);
        expect(
          find.byType(SettingsPage),
          findsNothing,
          reason:
              'Desktop must mount only V2 — the legacy SettingsPage chrome '
              'belongs to mobile and would compete for the same viewport.',
        );
      },
    );
  });
}

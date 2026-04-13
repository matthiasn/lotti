import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/settings/ui/pages/settings_content_pane.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/settings/ui/pages/settings_root_page.dart';
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

/// Desktop-sized media query (wide enough for desktop layout).
const _desktopMediaQuery = MediaQueryData(size: Size(1600, 900));

/// Mobile-sized media query (below 960px breakpoint).
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

  group('SettingsRootPage mobile layout', () {
    testWidgets('shows SettingsPage directly on narrow screens', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const SettingsRootPage(),
          mediaQueryData: _mobileMediaQuery,
          overrides: buildOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(ResizableDivider), findsNothing);
      expect(find.byType(DesktopDetailEmptyState), findsNothing);
    });
  });

  group('SettingsRootPage desktop layout', () {
    testWidgets('shows split pane with empty state when no route selected', (
      tester,
    ) async {
      navService.isDesktopMode = true;

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const SettingsRootPage(),
          mediaQueryData: _desktopMediaQuery,
          overrides: buildOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(ResizableDivider), findsOneWidget);
      expect(find.byType(DesktopDetailEmptyState), findsOneWidget);
      expect(find.byType(SettingsContentPane), findsNothing);
    });

    testWidgets('shows content pane when a settings route is selected', (
      tester,
    ) async {
      navService.isDesktopMode = true;
      navService.desktopSelectedSettingsRoute.value = (
        path: '/settings/theming',
        pathParameters: <String, String>{},
        queryParameters: <String, String>{},
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const SettingsRootPage(),
          mediaQueryData: _desktopMediaQuery,
          overrides: buildOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(ResizableDivider), findsOneWidget);
      expect(find.byType(DesktopDetailEmptyState), findsNothing);
      expect(find.byType(SettingsContentPane), findsOneWidget);
    });

    testWidgets('shows empty state when route is /settings (root)', (
      tester,
    ) async {
      navService.isDesktopMode = true;
      navService.desktopSelectedSettingsRoute.value = (
        path: '/settings',
        pathParameters: <String, String>{},
        queryParameters: <String, String>{},
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const SettingsRootPage(),
          mediaQueryData: _desktopMediaQuery,
          overrides: buildOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesktopDetailEmptyState), findsOneWidget);
      expect(find.byType(SettingsContentPane), findsNothing);
    });

    testWidgets('has settings icon in empty state', (tester) async {
      navService.isDesktopMode = true;

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const SettingsRootPage(),
          mediaQueryData: _desktopMediaQuery,
          overrides: buildOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('dragging ResizableDivider updates pane width', (
      tester,
    ) async {
      navService.isDesktopMode = true;

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const SettingsRootPage(),
          mediaQueryData: _desktopMediaQuery,
          overrides: buildOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      final divider = find.byType(ResizableDivider);
      expect(divider, findsOneWidget);

      // Perform a horizontal drag on the divider to exercise the onDrag
      // callback which calls updateListPaneWidth.
      await tester.drag(divider, const Offset(50, 0));
      await tester.pumpAndSettle();

      // The drag should not crash — the pane width controller handles it.
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });
}

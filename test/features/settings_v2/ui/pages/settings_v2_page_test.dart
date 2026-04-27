import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_width_controller.dart';
import 'package:lotti/features/settings_v2/ui/detail/settings_detail_pane.dart';
import 'package:lotti/features/settings_v2/ui/pages/settings_v2_page.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_view.dart';
import 'package:lotti/features/settings_v2/ui/widgets/settings_tree_resize_handle.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class _FakeNavService implements NavService {
  @override
  final ValueNotifier<DesktopSettingsRoute?> desktopSelectedSettingsRoute =
      ValueNotifier<DesktopSettingsRoute?>(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Unexpected NavService call: ${invocation.memberName}',
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final mocks = await setUpTestGetIt();
  addTearDown(tearDownTestGetIt);
  when(
    () => mocks.journalDb.watchConfigFlag(any()),
  ).thenAnswer((_) => Stream.value(false));

  // SettingsTreeUrlSync reads NavService from getIt on mount.
  final nav = _FakeNavService();
  getIt.registerSingleton<NavService>(nav);
  addTearDown(() {
    if (getIt.isRegistered<NavService>()) {
      getIt.unregister<NavService>();
    }
    nav.desktopSelectedSettingsRoute.dispose();
  });

  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      const SettingsV2Page(),
      overrides: [journalDbProvider.overrideWithValue(mocks.journalDb)],
    ),
  );
  await tester.pump();
}

void main() {
  group('SettingsV2Page — structure', () {
    testWidgets('renders a Scaffold so ScaffoldMessenger lookups succeed', (
      tester,
    ) async {
      await _pumpPage(tester);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders the header with the Settings title', (tester) async {
      await _pumpPage(tester);
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('the header sits at the fixed 56 dp height', (tester) async {
      await _pumpPage(tester);
      final headerHeight = find
          .descendant(
            of: find.byType(SettingsV2Page),
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.height == kSettingsV2HeaderHeight,
            ),
          )
          .first;
      expect(
        tester.getSize(headerHeight).height,
        kSettingsV2HeaderHeight,
      );
    });

    testWidgets('renders a SettingsTreeView in the left column', (
      tester,
    ) async {
      await _pumpPage(tester);
      expect(find.byType(SettingsTreeView), findsOneWidget);
    });

    testWidgets('renders the SettingsDetailPane in the right column', (
      tester,
    ) async {
      await _pumpPage(tester);
      expect(find.byType(SettingsDetailPane), findsOneWidget);
    });

    testWidgets('includes a SettingsTreeResizeHandle between the columns', (
      tester,
    ) async {
      await _pumpPage(tester);
      expect(find.byType(SettingsTreeResizeHandle), findsOneWidget);
    });
  });

  group('SettingsV2Page — tree column width', () {
    testWidgets('sizes the tree column to the current width provider value', (
      tester,
    ) async {
      await _pumpPage(tester);
      final sized = find
          .descendant(
            of: find.byType(SettingsV2Page),
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.width == defaultSettingsTreeNavWidth,
            ),
          )
          .first;
      expect(
        tester.getSize(sized).width,
        defaultSettingsTreeNavWidth,
      );
    });

    testWidgets(
      'column width follows the provider across rebuilds',
      (tester) async {
        await _pumpPage(tester);
        final element = tester.element(find.byType(SettingsV2Page));
        final container = ProviderScope.containerOf(element, listen: false);
        container.read(settingsTreeNavWidthProvider.notifier).setTo(400);
        await tester.pump();

        final sized = find
            .descendant(
              of: find.byType(SettingsV2Page),
              matching: find.byWidgetPredicate(
                (w) => w is SizedBox && w.width == 400,
              ),
            )
            .first;
        expect(tester.getSize(sized).width, 400);
      },
    );
  });
}

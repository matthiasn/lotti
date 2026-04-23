import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class MockUserActivityService extends Mock implements UserActivityService {}

class FakeConfigFlag extends Fake implements ConfigFlag {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockJournalDb mockDb;
  late MockUserActivityService mockUserActivityService;
  late MockPersistenceLogic mockPersistenceLogic;
  final mockUpdateNotifications = MockUpdateNotifications();

  setUpAll(() {
    registerFallbackValue(FakeConfigFlag());
  });

  setUp(() async {
    mockDb = MockJournalDb();
    mockUserActivityService = MockUserActivityService();
    mockPersistenceLogic = MockPersistenceLogic();

    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );

    when(() => mockDb.watchConfigFlags()).thenAnswer(
      (_) => Stream<Set<ConfigFlag>>.fromIterable([
        {
          const ConfigFlag(
            name: privateFlag,
            description: 'Show private entries?',
            status: true,
          ),
          const ConfigFlag(
            name: enableNotificationsFlag,
            description: 'Enable notifications?',
            status: false,
          ),
          const ConfigFlag(
            name: enableEventsFlag,
            description: 'Enable Events?',
            status: false,
          ),
          const ConfigFlag(
            name: enableDailyOsPageFlag,
            description: 'Enable DailyOS Page?',
            status: true,
          ),
          const ConfigFlag(
            name: enableAiStreamingFlag,
            description: 'Enable AI streaming responses?',
            status: false,
          ),
          const ConfigFlag(
            name: enableAgentsFlag,
            description: 'Enable Agents?',
            status: false,
          ),
          const ConfigFlag(
            name: enableEmbeddingsFlag,
            description: 'Generate Embeddings?',
            status: false,
          ),
          const ConfigFlag(
            name: enableVectorSearchFlag,
            description: 'Enable Vector Search?',
            status: false,
          ),
        },
      ]),
    );

    when(() => mockUserActivityService.updateActivity()).thenReturn(null);

    when(
      () => mockPersistenceLogic.setConfigFlag(any()),
    ).thenAnswer((_) async {});

    GetIt.I
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<UserActivityService>(mockUserActivityService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

    ensureThemingServicesRegistered();
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  group('FlagsPage', () {
    testWidgets('renders DesignSystemListItem for each flag', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      // 8 flags in the mock data
      expect(find.byType(DesignSystemListItem), findsNWidgets(8));
    });

    testWidgets('uses SettingsIcon as leading widget', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsIcon), findsNWidgets(8));
    });

    testWidgets('shows correct title and description for private flag', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));
      expect(find.text(context.messages.configFlagPrivate), findsOneWidget);
      expect(
        find.text(context.messages.configFlagPrivateDescription),
        findsOneWidget,
      );
    });

    testWidgets('shows correct switch state for enabled flag', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));
      final privateFlagItem = find.widgetWithText(
        DesignSystemListItem,
        context.messages.configFlagPrivate,
      );
      final privateFlagSwitch = tester.widget<Switch>(
        find.descendant(of: privateFlagItem, matching: find.byType(Switch)),
      );
      expect(privateFlagSwitch.value, isTrue);
    });

    testWidgets('shows correct switch state for disabled flag', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));
      final notificationsItem = find.widgetWithText(
        DesignSystemListItem,
        context.messages.configFlagEnableNotifications,
      );
      final notificationsSwitch = tester.widget<Switch>(
        find.descendant(
          of: notificationsItem,
          matching: find.byType(Switch),
        ),
      );
      expect(notificationsSwitch.value, isFalse);
    });

    testWidgets('toggles flag when switch is tapped', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));
      final privateFlagItem = find.widgetWithText(
        DesignSystemListItem,
        context.messages.configFlagPrivate,
      );
      await tester.tap(
        find.descendant(of: privateFlagItem, matching: find.byType(Switch)),
      );
      await tester.pump();

      const expectedFlag = ConfigFlag(
        name: privateFlag,
        description: 'Show private entries?',
        status: false,
      );
      verify(() => mockPersistenceLogic.setConfigFlag(expectedFlag)).called(1);
    });

    testWidgets('toggles flag when row is tapped', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));

      // Tap the row itself (not the switch) — the onTap should toggle
      await tester.tap(
        find.text(context.messages.configFlagEnableNotifications),
      );
      await tester.pump();

      const expectedFlag = ConfigFlag(
        name: enableNotificationsFlag,
        description: 'Enable notifications?',
        status: true,
      );
      verify(() => mockPersistenceLogic.setConfigFlag(expectedFlag)).called(1);
    });

    testWidgets('shows correct icons for specific flags', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline_rounded), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.event_rounded), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.bolt_rounded), findsAtLeastNWidgets(1));
      expect(
        find.byIcon(Icons.calendar_today_rounded),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('wraps items in decorated box with border', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DecoratedBox), findsAtLeastNWidgets(1));
      expect(find.byType(ClipRRect), findsAtLeastNWidgets(1));
    });
  });
}

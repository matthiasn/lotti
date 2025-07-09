import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/flags_page.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/settings/animated_settings_cards.dart';
import 'package:mocktail/mocktail.dart';

// Showcase is no longer used

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockUserActivityService extends Mock implements UserActivityService {}

class FakeConfigFlag extends Fake implements ConfigFlag {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockJournalDb mockDb;
  late MockUserActivityService mockUserActivityService;
  final mockUpdateNotifications = MockUpdateNotifications();

  setUpAll(() {
    registerFallbackValue(FakeConfigFlag());
  });

  setUp(() async {
    mockDb = MockJournalDb();
    mockUserActivityService = MockUserActivityService();

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
        },
      ]),
    );

    when(() => mockUserActivityService.updateActivity()).thenReturn(null);

    GetIt.I
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<UserActivityService>(mockUserActivityService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  group('FlagsPage Widget Tests - ', () {
    testWidgets('page is displayed', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const FlagsPage(),
        ),
      );

      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));

      // The card title is now the localized flag name
      expect(find.text(context.messages.configFlagPrivate), findsOneWidget);
      // The subtitle/description should be present somewhere in the card
      expect(
        find.descendant(
          of: find.byType(AnimatedModernSettingsCardWithIcon),
          matching: find.text(context.messages.configFlagPrivateDescription),
        ),
        findsOneWidget,
      );
      // The icon should be present (may appear more than once)
      expect(find.byIcon(Icons.lock_outline_rounded), findsAtLeastNWidgets(1));
    });

    testWidgets('displays multiple flags with correct switch states',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const FlagsPage(),
        ),
      );

      await tester.pumpAndSettle();
      final context = tester.element(find.byType(FlagsPage));

      // Verify privateFlag is on
      final privateFlagCard = find.widgetWithText(
          AnimatedModernSettingsCardWithIcon,
          context.messages.configFlagPrivate);
      expect(privateFlagCard, findsOneWidget);
      final privateFlagSwitch = tester.widget<Switch>(
          find.descendant(of: privateFlagCard, matching: find.byType(Switch)));
      expect(privateFlagSwitch.value, isTrue);

      // Verify enableNotificationsFlag is off
      final notificationsCard = find.widgetWithText(
          AnimatedModernSettingsCardWithIcon,
          context.messages.configFlagEnableNotifications);
      expect(notificationsCard, findsOneWidget);
      final notificationsSwitch = tester.widget<Switch>(find.descendant(
          of: notificationsCard, matching: find.byType(Switch)));
      expect(notificationsSwitch.value, isFalse);
    });

    testWidgets('toggles a flag when switch is tapped', (tester) async {
      const initialFlag = ConfigFlag(
        name: privateFlag,
        description: 'Show private entries?',
        status: true,
      );
      final updatedFlag = initialFlag.copyWith(status: false);

      when(() => mockDb.upsertConfigFlag(any())).thenAnswer((_) async => 1);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const FlagsPage(),
        ),
      );

      await tester.pumpAndSettle();
      final context = tester.element(find.byType(FlagsPage));

      final privateFlagCard = find.widgetWithText(
          AnimatedModernSettingsCardWithIcon,
          context.messages.configFlagPrivate);
      await tester.tap(
          find.descendant(of: privateFlagCard, matching: find.byType(Switch)));
      await tester.pump();

      verify(() => mockDb.upsertConfigFlag(updatedFlag)).called(1);
    });
  });
}

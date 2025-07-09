import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockJournalDb mockDb;
  late MockUserActivityService mockUserActivityService;
  final mockUpdateNotifications = MockUpdateNotifications();

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
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const FlagsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The card title is now the localized flag name
      expect(find.text('Show private entries?'), findsOneWidget);
      // The subtitle/description should be present somewhere in the card
      expect(
        find.descendant(
          of: find.byType(AnimatedModernSettingsCardWithIcon),
          matching: find.text(
              'Enable this to make your entries private by default. Private entries are only visible to you.'),
        ),
        findsOneWidget,
      );
      // The toggle switch should be present
      expect(find.byType(Switch), findsOneWidget);
      // The icon should be present (may appear more than once)
      expect(find.byIcon(Icons.lock_outline_rounded), findsAtLeastNWidgets(1));
    });
  });
}

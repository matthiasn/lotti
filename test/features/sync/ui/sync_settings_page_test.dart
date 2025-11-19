import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/features/sync/ui/sync_settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class MockSyncDatabase extends Mock implements SyncDatabase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncSettingsPage', () {
    late MockJournalDb mockJournalDb;
    late MockSyncDatabase mockSyncDb;

    setUp(() {
      mockJournalDb = MockJournalDb();
      mockSyncDb = MockSyncDatabase();

      when(() => mockJournalDb.watchConfigFlag(enableMatrixFlag))
          .thenAnswer((_) => Stream<bool>.value(true));
      when(mockSyncDb.watchOutboxCount).thenAnswer((_) => Stream<int>.value(0));

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SyncDatabase>(mockSyncDb)
        ..registerSingleton<UserActivityService>(UserActivityService());
    });

    tearDown(getIt.reset);

    testWidgets('renders setup, outbox, conflicts, and stats cards',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SyncSettingsPage()),
      );

      await tester.pumpAndSettle();

      // Assert the card title specifically (not the page app bar)
      final pageContext = tester.element(find.byType(SyncSettingsPage));
      expect(
        find.descendant(
          of: find.byType(AnimatedModernSettingsCardWithIcon),
          matching: find.text(pageContext.messages.navTabTitleSettings),
        ),
        findsOneWidget,
      );
      expect(
        find.text(pageContext.messages.settingsMatrixMaintenanceTitle),
        findsOneWidget,
      );
      expect(find.text('Sync Outbox'), findsOneWidget);
      expect(find.text('Matrix Stats'), findsOneWidget);
    });

    testWidgets('gate hides page when Matrix flag is OFF', (tester) async {
      // Re-register with flag disabled
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      mockSyncDb = MockSyncDatabase();
      when(() => mockJournalDb.watchConfigFlag(enableMatrixFlag))
          .thenAnswer((_) => Stream<bool>.value(false));
      when(mockSyncDb.watchOutboxCount).thenAnswer((_) => Stream<int>.value(0));
      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SyncDatabase>(mockSyncDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SyncSettingsPage()),
      );
      await tester.pump();

      final pageContext = tester.element(find.byType(SyncSettingsPage));
      expect(find.text(pageContext.messages.navTabTitleSettings), findsNothing);
      expect(find.text(pageContext.messages.settingsMatrixMaintenanceTitle),
          findsNothing);
      expect(find.text('Matrix Stats'), findsNothing);
    });
  });
}

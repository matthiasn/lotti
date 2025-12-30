import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_badge.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../mocks/sync_config_test_mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  group('OutboxBadge Widget Tests - ', () {
    testWidgets('Badge shows count 999 when logged in', (tester) async {
      const testCount = 999;
      final syncDbMock = mockSyncDatabaseWithCount(testCount);
      final dbMock = mockJournalDbWithSyncFlag(enabled: true);

      const testIcon = Icons.settings_outlined;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const OutboxBadgeIcon(icon: Icon(testIcon)),
          overrides: [
            journalDbProvider.overrideWithValue(dbMock),
            syncDatabaseProvider.overrideWithValue(syncDbMock),
            loginStateStreamProvider.overrideWith(
                (ref) => Stream<LoginState>.value(LoginState.loggedIn)),
          ],
        ),
      );

      await tester.pumpAndSettle();

      final iconFinder = find.byIcon(testIcon);
      expect(iconFinder, findsOneWidget);

      final countFinder = find.text(testCount.toString());
      expect(countFinder, findsOneWidget);
    });

    testWidgets('Badge dims and greys when not logged in', (tester) async {
      const testCount = 5;
      final syncDbMock = mockSyncDatabaseWithCount(testCount);
      final dbMock = mockJournalDbWithSyncFlag(enabled: true);

      const testIcon = Icons.settings_outlined;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const OutboxBadgeIcon(icon: Icon(testIcon)),
          overrides: [
            journalDbProvider.overrideWithValue(dbMock),
            syncDatabaseProvider.overrideWithValue(syncDbMock),
            loginStateStreamProvider.overrideWith(
              (ref) => Stream<LoginState>.value(LoginState.loggedOut),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Icon should be present
      expect(find.byIcon(testIcon), findsOneWidget);
      // Greyscale + opacity wrapper should be applied
      expect(find.byType(Opacity), findsWidgets);
      expect(find.byType(ColorFiltered), findsWidgets);

      // Count still visible
      expect(find.text(testCount.toString()), findsOneWidget);
    });

    testWidgets('returns plain icon when sync is disabled', (tester) async {
      final syncDbMock = mockSyncDatabaseWithCount(5);
      final dbMock = mockJournalDbWithSyncFlag(enabled: false);

      const testIcon = Icons.settings_outlined;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const OutboxBadgeIcon(icon: Icon(testIcon)),
          overrides: [
            journalDbProvider.overrideWithValue(dbMock),
            syncDatabaseProvider.overrideWithValue(syncDbMock),
            loginStateStreamProvider.overrideWith(
              (ref) => Stream<LoginState>.value(LoginState.loggedIn),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Icon should be present
      expect(find.byIcon(testIcon), findsOneWidget);
      // No badge should be shown
      expect(find.byType(Badge), findsNothing);
      // No count text
      expect(find.text('5'), findsNothing);
    });

    testWidgets('badge label hidden when count is 0', (tester) async {
      final syncDbMock = mockSyncDatabaseWithCount(0);
      final dbMock = mockJournalDbWithSyncFlag(enabled: true);

      const testIcon = Icons.settings_outlined;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const OutboxBadgeIcon(icon: Icon(testIcon)),
          overrides: [
            journalDbProvider.overrideWithValue(dbMock),
            syncDatabaseProvider.overrideWithValue(syncDbMock),
            loginStateStreamProvider.overrideWith(
              (ref) => Stream<LoginState>.value(LoginState.loggedIn),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Icon should be present
      expect(find.byIcon(testIcon), findsOneWidget);
      // Badge widget exists but label should be hidden (count is 0)
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isFalse);
    });

    testWidgets('shows plain icon during loading state', (tester) async {
      final syncDbMock = mockSyncDatabaseWithCount(5);
      final dbMock = MockJournalDb();
      // Don't emit any values - stream stays in loading state
      when(() => dbMock.watchConfigFlag(any()))
          .thenAnswer((_) => const Stream<bool>.empty());

      const testIcon = Icons.settings_outlined;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const OutboxBadgeIcon(icon: Icon(testIcon)),
          overrides: [
            journalDbProvider.overrideWithValue(dbMock),
            syncDatabaseProvider.overrideWithValue(syncDbMock),
            loginStateStreamProvider.overrideWith(
              (ref) => Stream<LoginState>.value(LoginState.loggedIn),
            ),
          ],
        ),
      );

      // Don't pumpAndSettle - check during loading
      await tester.pump();

      // Icon should be present
      expect(find.byIcon(testIcon), findsOneWidget);
      // During loading, syncEnabled is false, so plain icon returned
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('shows plain icon on provider error', (tester) async {
      final syncDbMock = mockSyncDatabaseWithCount(5);
      final dbMock = MockJournalDb();
      // Emit an error
      when(() => dbMock.watchConfigFlag(any()))
          .thenAnswer((_) => Stream<bool>.error(Exception('test error')));

      const testIcon = Icons.settings_outlined;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const OutboxBadgeIcon(icon: Icon(testIcon)),
          overrides: [
            journalDbProvider.overrideWithValue(dbMock),
            syncDatabaseProvider.overrideWithValue(syncDbMock),
            loginStateStreamProvider.overrideWith(
              (ref) => Stream<LoginState>.value(LoginState.loggedIn),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Icon should be present
      expect(find.byIcon(testIcon), findsOneWidget);
      // On error, valueOrNull is null so syncEnabled is false
      expect(find.byType(Badge), findsNothing);
    });
  });
}

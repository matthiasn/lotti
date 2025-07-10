import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_badge.dart';
import 'package:lotti/get_it.dart';

import '../../mocks/mocks.dart';
import '../../mocks/sync_config_test_mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  group('OutboxBadge Widget Tests - ', () {
    setUp(() {});
    tearDown(getIt.reset);

    testWidgets('Badge shows count 999', (tester) async {
      const testCount = 999;
      final syncDbMock = mockSyncDatabaseWithCount(testCount);
      final dbMock = mockJournalDbWithSyncFlag(enabled: true);
      getIt
        ..registerSingleton<SyncDatabase>(syncDbMock)
        ..registerSingleton<JournalDb>(dbMock);

      const testIcon = Icons.settings_outlined;

      await tester.pumpWidget(
        makeTestableWidget(
          OutboxBadgeIcon(
            icon: const Icon(testIcon),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final iconFinder = find.byIcon(testIcon);
      expect(iconFinder, findsOneWidget);

      final countFinder = find.text(testCount.toString());
      expect(countFinder, findsOneWidget);
    });
  });
}

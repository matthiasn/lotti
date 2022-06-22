import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';

import '../../widget_test_utils.dart';
import '../sync_config_test_mocks.dart';

void main() {
  var mock = MockSyncDatabase();

  group('OutboxBadge Widget Tests - ', () {
    setUp(() {});
    tearDown(getIt.reset);

    testWidgets('Badge shows count 999', (tester) async {
      const testCount = 999;
      mock = mockSyncDatabaseWithCount(testCount);
      getIt.registerSingleton<SyncDatabase>(mock);

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

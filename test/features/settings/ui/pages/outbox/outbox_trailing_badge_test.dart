import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_trailing_badge.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../mocks/sync_config_test_mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  group('OutboxTrailingBadge', () {
    testWidgets('renders a danger-tone number badge when count > 0', (
      tester,
    ) async {
      final syncDbMock = mockSyncDatabaseWithCount(4);
      final dbMock = mockJournalDbWithSyncFlag(enabled: true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const OutboxTrailingBadge(),
          overrides: [
            journalDbProvider.overrideWithValue(dbMock),
            syncDatabaseProvider.overrideWithValue(syncDbMock),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4'), findsOneWidget);
      final badge = tester.widget<DesignSystemBadge>(
        find.byType(DesignSystemBadge),
      );
      expect(badge.tone, DesignSystemBadgeTone.danger);
    });

    testWidgets('renders nothing when sync is disabled', (tester) async {
      final syncDbMock = mockSyncDatabaseWithCount(9);
      final dbMock = mockJournalDbWithSyncFlag(enabled: false);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const OutboxTrailingBadge(),
          overrides: [
            journalDbProvider.overrideWithValue(dbMock),
            syncDatabaseProvider.overrideWithValue(syncDbMock),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemBadge), findsNothing);
      expect(find.text('9'), findsNothing);
    });

    testWidgets('renders nothing when count is 0', (tester) async {
      final syncDbMock = mockSyncDatabaseWithCount(0);
      final dbMock = mockJournalDbWithSyncFlag(enabled: true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const OutboxTrailingBadge(),
          overrides: [
            journalDbProvider.overrideWithValue(dbMock),
            syncDatabaseProvider.overrideWithValue(syncDbMock),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemBadge), findsNothing);
    });

    testWidgets(
      'renders nothing when sidebar sync activity indicator is enabled',
      (tester) async {
        // Even with sync online and a non-zero count, the badge must
        // disappear once the sidebar sync activity indicator is on —
        // the indicator already surfaces the same number, so doubling
        // up would be visual noise.
        final syncDbMock = mockSyncDatabaseWithCount(7);
        final dbMock = mockJournalDbWithSyncFlag(enabled: true);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const OutboxTrailingBadge(),
            overrides: [
              journalDbProvider.overrideWithValue(dbMock),
              syncDatabaseProvider.overrideWithValue(syncDbMock),
              configFlagProvider(
                showSyncActivityIndicatorFlag,
              ).overrideWith((_) => Stream<bool>.value(true)),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemBadge), findsNothing);
        expect(find.text('7'), findsNothing);
      },
    );
  });
}

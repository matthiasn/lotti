import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_trailing_badge.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../mocks/sync_config_test_mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  group('OutboxTrailingBadge', () {
    testWidgets('renders a neutral outlined outgoing badge when count > 0', (
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
            inboundQueueDepthProvider.overrideWith(
              (_) => Stream<int>.value(0),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('↑ 4'), findsOneWidget);
      final badge = tester.widget<DesignSystemBadge>(
        find.byType(DesignSystemBadge),
      );
      expect(badge.tone, DesignSystemBadgeTone.neutral);

      final decoratedBox = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(DesignSystemBadge),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, isNull);
      expect(decoration.border, isNotNull);
    });

    testWidgets('renders a neutral outlined incoming badge when count > 0', (
      tester,
    ) async {
      final syncDbMock = mockSyncDatabaseWithCount(0);
      final dbMock = mockJournalDbWithSyncFlag(enabled: true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const OutboxTrailingBadge(),
          overrides: [
            journalDbProvider.overrideWithValue(dbMock),
            syncDatabaseProvider.overrideWithValue(syncDbMock),
            inboundQueueDepthProvider.overrideWith(
              (_) => Stream<int>.value(3),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('↓ 3'), findsOneWidget);
      final badge = tester.widget<DesignSystemBadge>(
        find.byType(DesignSystemBadge),
      );
      expect(badge.tone, DesignSystemBadgeTone.neutral);
      final context = tester.element(find.byType(OutboxTrailingBadge));
      expect(
        badge.semanticLabel,
        '${context.messages.syncActivityInboxLabel}: 3',
      );
    });

    testWidgets('renders separate incoming and outgoing badges together', (
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
            inboundQueueDepthProvider.overrideWith(
              (_) => Stream<int>.value(3),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('↓ 3'), findsOneWidget);
      expect(find.text('↑ 4'), findsOneWidget);
      final badges = tester.widgetList<DesignSystemBadge>(
        find.byType(DesignSystemBadge),
      );
      expect(badges, hasLength(2));
      expect(
        badges.map((badge) => badge.tone),
        everyElement(DesignSystemBadgeTone.neutral),
      );

      final context = tester.element(find.byType(OutboxTrailingBadge));
      expect(
        badges.map((badge) => badge.semanticLabel),
        [
          '${context.messages.syncActivityInboxLabel}: 3',
          '${context.messages.syncActivityOutboxLabel}: 4',
        ],
      );
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
            inboundQueueDepthProvider.overrideWith(
              (_) => Stream<int>.value(6),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemBadge), findsNothing);
      expect(find.text('↑ 9'), findsNothing);
      expect(find.text('↓ 6'), findsNothing);
    });

    testWidgets('renders nothing when both counts are 0', (tester) async {
      final syncDbMock = mockSyncDatabaseWithCount(0);
      final dbMock = mockJournalDbWithSyncFlag(enabled: true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const OutboxTrailingBadge(),
          overrides: [
            journalDbProvider.overrideWithValue(dbMock),
            syncDatabaseProvider.overrideWithValue(syncDbMock),
            inboundQueueDepthProvider.overrideWith(
              (_) => Stream<int>.value(0),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemBadge), findsNothing);
    });
  });
}

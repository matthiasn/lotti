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

    testWidgets('renders large counts compactly rather than in full', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const OutboxTrailingBadge(),
          overrides: [
            journalDbProvider.overrideWithValue(
              mockJournalDbWithSyncFlag(enabled: true),
            ),
            syncDatabaseProvider.overrideWithValue(
              mockSyncDatabaseWithCount(1204),
            ),
            inboundQueueDepthProvider.overrideWith(
              (_) => Stream<int>.value(18342),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The uncapped form ('↓ 18342') is what let a busy queue take the
      // Settings label's width until the label wrapped into a column of
      // letters.
      expect(find.text('↓ 18K'), findsOneWidget);
      expect(find.text('↑ 1.2K'), findsOneWidget);
      expect(find.text('↓ 18342'), findsNothing);
    });

    testWidgets('keeps the exact count in the accessible label', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const OutboxTrailingBadge(),
          overrides: [
            journalDbProvider.overrideWithValue(
              mockJournalDbWithSyncFlag(enabled: true),
            ),
            syncDatabaseProvider.overrideWithValue(
              mockSyncDatabaseWithCount(1204),
            ),
            inboundQueueDepthProvider.overrideWith(
              (_) => Stream<int>.value(18342),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Compaction serves the row's width budget; a screen reader has no such
      // constraint and should hear the real figure.
      final context = tester.element(find.byType(OutboxTrailingBadge));
      expect(
        tester
            .widgetList<DesignSystemBadge>(find.byType(DesignSystemBadge))
            .map((badge) => badge.semanticLabel),
        [
          '${context.messages.syncActivityInboxLabel}: 18342',
          '${context.messages.syncActivityOutboxLabel}: 1204',
        ],
      );
    });

    testWidgets('shapes both pills as counts so their digits do not jitter', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const OutboxTrailingBadge(),
          overrides: [
            journalDbProvider.overrideWithValue(
              mockJournalDbWithSyncFlag(enabled: true),
            ),
            syncDatabaseProvider.overrideWithValue(
              mockSyncDatabaseWithCount(4),
            ),
            inboundQueueDepthProvider.overrideWith(
              (_) => Stream<int>.value(3),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<DesignSystemBadge>(find.byType(DesignSystemBadge))
            .map((badge) => badge.numeric),
        everyElement(isTrue),
      );
    });

    testWidgets('the pills share a too-narrow slot instead of overflowing it', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 40,
            child: OutboxTrailingBadge(),
          ),
          overrides: [
            journalDbProvider.overrideWithValue(
              mockJournalDbWithSyncFlag(enabled: true),
            ),
            syncDatabaseProvider.overrideWithValue(
              mockSyncDatabaseWithCount(999999),
            ),
            inboundQueueDepthProvider.overrideWith(
              (_) => Stream<int>.value(999999),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Six-figure queues in both directions on a 200 px rail is the case the
      // sidebar clamps. Both directions shorten together rather than one
      // winning the row and the other spilling out of it.
      expect(tester.takeException(), isNull);
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

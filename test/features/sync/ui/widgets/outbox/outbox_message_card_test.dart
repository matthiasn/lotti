import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_message_card.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

import '../../../../../widget_test_utils.dart';

OutboxItem _item({
  required OutboxStatus status,
  int retries = 0,
  int? payloadSize,
}) => OutboxItem(
  id: 1,
  createdAt: DateTime(2024, 3, 15, 12),
  updatedAt: DateTime(2024, 3, 15, 12),
  status: status.index,
  retries: retries,
  message: jsonEncode({'runtimeType': 'aiConfigDelete', 'id': 'c1'}),
  subject: 'subj',
  payloadSize: payloadSize,
  priority: OutboxPriority.low.index,
);

void main() {
  final l10n = AppLocalizationsEn();

  Future<void> pump(
    WidgetTester tester,
    OutboxItem item, {
    bool showDetails = false,
    VoidCallback? onRetry,
    VoidCallback? onRemove,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        OutboxMessageCard(
          item: item,
          showDetails: showDetails,
          onRetry: onRetry,
          onRemove: onRemove,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('each status renders its plain-language badge', (tester) async {
    await pump(tester, _item(status: OutboxStatus.pending));
    expect(find.text(l10n.outboxStatusWaiting), findsOneWidget);

    await pump(tester, _item(status: OutboxStatus.sending));
    expect(find.text(l10n.outboxStatusSending), findsOneWidget);

    await pump(tester, _item(status: OutboxStatus.sent));
    expect(find.text(l10n.outboxStatusSent), findsOneWidget);
  });

  testWidgets('failed items explain themselves and offer actions', (
    tester,
  ) async {
    var retried = false;
    var removed = false;
    await pump(
      tester,
      _item(status: OutboxStatus.error, retries: 3),
      onRetry: () => retried = true,
      onRemove: () => removed = true,
    );

    expect(find.text(l10n.outboxStatusFailed), findsOneWidget);
    expect(find.text(l10n.outboxFailedReassurance), findsOneWidget);
    expect(find.text(l10n.outboxTriedTimes(3)), findsOneWidget);

    await tester.tap(
      find.widgetWithText(DesignSystemButton, l10n.outboxActionRetry),
    );
    await tester.pump();
    expect(retried, isTrue);

    await tester.tap(
      find.widgetWithText(DesignSystemButton, l10n.outboxActionRemove),
    );
    await tester.pump();
    expect(removed, isTrue);
  });

  testWidgets('no actions render when no callbacks are provided', (
    tester,
  ) async {
    await pump(tester, _item(status: OutboxStatus.error, retries: 1));
    expect(
      find.widgetWithText(DesignSystemButton, l10n.outboxActionRetry),
      findsNothing,
    );
    expect(
      find.widgetWithText(DesignSystemButton, l10n.outboxActionRemove),
      findsNothing,
    );
  });

  testWidgets('diagnostic details are gated behind showDetails', (
    tester,
  ) async {
    await pump(tester, _item(status: OutboxStatus.pending, payloadSize: 2048));
    expect(find.text('2.0 KB'), findsNothing);

    await pump(
      tester,
      _item(status: OutboxStatus.pending, payloadSize: 2048),
      showDetails: true,
    );
    expect(find.text('2.0 KB'), findsOneWidget);
  });
}

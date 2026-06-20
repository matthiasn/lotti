import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/sync/ui/view_models/outbox_status_presentation.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_summary_header.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  final l10n = AppLocalizationsEn();

  Future<void> pump(
    WidgetTester tester,
    QueueSummary summary, {
    VoidCallback? onRetryAll,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        OutboxSummaryHeader(summary: summary, onRetryAll: onRetryAll),
      ),
    );
    await tester.pump();
  }

  testWidgets('synced state shows the calm all-clear line, no retry-all', (
    tester,
  ) async {
    await pump(
      tester,
      const QueueSummary(
        state: QueueState.synced,
        activeCount: 0,
        failedCount: 0,
      ),
      onRetryAll: () {},
    );
    expect(find.text(l10n.outboxSummarySynced), findsOneWidget);
    expect(
      find.widgetWithText(DesignSystemButton, l10n.outboxRetryAll),
      findsNothing,
    );
  });

  testWidgets('waiting and offline states show their own lines', (
    tester,
  ) async {
    await pump(
      tester,
      const QueueSummary(
        state: QueueState.waiting,
        activeCount: 3,
        failedCount: 0,
      ),
    );
    expect(find.text(l10n.outboxSummaryWaiting(3)), findsOneWidget);

    await pump(
      tester,
      const QueueSummary(
        state: QueueState.offline,
        activeCount: 2,
        failedCount: 1,
      ),
    );
    // Offline count combines active + failed stranded work.
    expect(find.text(l10n.outboxSummaryOffline(3)), findsOneWidget);
  });

  testWidgets('failed state shows the failure line and a working Retry all', (
    tester,
  ) async {
    var retriedAll = false;
    await pump(
      tester,
      const QueueSummary(
        state: QueueState.failed,
        activeCount: 0,
        failedCount: 2,
      ),
      onRetryAll: () => retriedAll = true,
    );

    expect(find.text(l10n.outboxSummaryFailed(2)), findsOneWidget);
    await tester.tap(
      find.widgetWithText(DesignSystemButton, l10n.outboxRetryAll),
    );
    await tester.pump();
    expect(retriedAll, isTrue);
  });

  testWidgets('retry-all is hidden when no callback is given', (tester) async {
    await pump(
      tester,
      const QueueSummary(
        state: QueueState.failed,
        activeCount: 0,
        failedCount: 2,
      ),
    );
    expect(
      find.widgetWithText(DesignSystemButton, l10n.outboxRetryAll),
      findsNothing,
    );
  });
}

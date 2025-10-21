import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_list_item.dart';
import 'package:lotti/features/sync/ui/widgets/sync_list_scaffold.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';

enum _OutboxListFilter {
  pending,
  success,
  error,
}

class OutboxMonitorPage extends StatefulWidget {
  const OutboxMonitorPage({super.key});

  @override
  State<OutboxMonitorPage> createState() => _OutboxMonitorPageState();
}

class _OutboxMonitorPageState extends State<OutboxMonitorPage> {
  final SyncDatabase _db = getIt<SyncDatabase>();

  late final Stream<List<OutboxItem>> _stream = _db.watchOutboxItems();

  Future<void> _retryItem(BuildContext context, OutboxItem item) async {
    final confirmed = await showConfirmationModal(
      context: context,
      message: context.messages.outboxMonitorRetryConfirmMessage,
      confirmLabel: context.messages.outboxMonitorRetryConfirmLabel,
      cancelLabel: context.messages.cancelButton,
      isDestructive: false,
    );
    if (!confirmed) return;

    try {
      await _db.updateOutboxItem(
        OutboxCompanion(
          id: drift.Value(item.id),
          status: drift.Value(OutboxStatus.pending.index),
          retries: drift.Value(item.retries + 1),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.messages.outboxMonitorRetryQueued),
        ),
      );
    } catch (error, stackTrace) {
      getIt<LoggingService>().captureException(
        error,
        domain: 'OUTBOX',
        subDomain: 'retry_item',
        stackTrace: stackTrace,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.messages.outboxMonitorRetryFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filters = <_OutboxListFilter, SyncFilterOption<OutboxItem>>{
      _OutboxListFilter.pending: SyncFilterOption<OutboxItem>(
        labelBuilder: (context) => context.messages.outboxMonitorLabelPending,
        predicate: (OutboxItem item) =>
            OutboxStatus.values[item.status] == OutboxStatus.pending,
        icon: Icons.schedule_rounded,
        selectedColor: Colors.orange,
        selectedForegroundColor: Colors.white,
      ),
      _OutboxListFilter.success: SyncFilterOption<OutboxItem>(
        labelBuilder: (context) => context.messages.outboxMonitorLabelSuccess,
        predicate: (OutboxItem item) =>
            OutboxStatus.values[item.status] == OutboxStatus.sent,
        icon: Icons.check_circle_outline_rounded,
        selectedColor: Colors.green,
        selectedForegroundColor: Colors.white,
      ),
      _OutboxListFilter.error: SyncFilterOption<OutboxItem>(
        labelBuilder: (context) => context.messages.outboxMonitorLabelError,
        predicate: (OutboxItem item) =>
            OutboxStatus.values[item.status] == OutboxStatus.error,
        icon: Icons.error_outline_rounded,
        selectedColor: colorScheme.error,
        selectedForegroundColor: colorScheme.onError,
      ),
    };

    return SyncListScaffold<OutboxItem, _OutboxListFilter>(
      title: context.messages.settingsSyncOutboxTitle,
      stream: _stream,
      filters: filters,
      initialFilter: _OutboxListFilter.pending,
      emptyIcon: Icons.inbox_rounded,
      emptyTitleBuilder: (ctx) => ctx.messages.outboxMonitorEmptyTitle,
      emptyDescriptionBuilder: (ctx) =>
          ctx.messages.outboxMonitorEmptyDescription,
      countSummaryBuilder: (ctx, label, count) =>
          ctx.messages.syncListCountSummary(label, count),
      itemBuilder: (ctx, OutboxItem item) => OutboxListItem(
        item: item,
        showRetry: OutboxStatus.values[item.status] == OutboxStatus.error,
        onRetry: () => _retryItem(ctx, item),
      ),
    );
  }
}

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_list_item.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_volume_chart.dart';
import 'package:lotti/features/sync/ui/widgets/sync_list_scaffold.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';

enum _OutboxListFilter {
  pending,
  success,
  error,
}

/// Full-page outbox monitor — used by the V1 beamer route and kept
/// as the entry-point class so existing callers and tests continue
/// to work unchanged.
class OutboxMonitorPage extends StatefulWidget {
  const OutboxMonitorPage({super.key});

  @override
  State<OutboxMonitorPage> createState() => _OutboxMonitorPageState();
}

/// Content body for the Settings V2 detail pane (plan step 7).
///
/// [OutboxMonitorPage] owns its own full-surface `SyncListScaffold`
/// with a page header; embedding it inside the V2 leaf panel would
/// double the title bar. The polish pass (plan step 10) will refactor
/// `SyncListScaffold` to support a headerless embedded mode. Until
/// then this wrapper re-uses the page verbatim so the panel is
/// functional; the resulting minor title duplication is a known
/// cosmetic issue tracked for polish.
class OutboxMonitorBody extends StatelessWidget {
  const OutboxMonitorBody({super.key});

  @override
  Widget build(BuildContext context) => const OutboxMonitorPage();
}

class _OutboxMonitorPageState extends State<OutboxMonitorPage> {
  final SyncDatabase _db = getIt<SyncDatabase>();

  // The page deliberately does NOT subscribe to a live `watch()` stream.
  // The outbox grows by hundreds of rows per minute during sync; a live
  // watcher with the CASE-WHEN ORDER BY required for this page forces
  // SQLite into a temp B-tree sort on every write and dominates CPU
  // for as long as the page is open. Snapshot + pull-to-refresh
  // matches what an operator actually needs here.
  static const int _fetchLimit = 2500;

  List<OutboxItem>? _items;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    // Defer the first fetch to after the first frame so the localization
    // and toast dependencies are wired up before any error path runs —
    // a synchronous DB throw inside initState would otherwise touch
    // `context.messages` before dependencies are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetch();
    });
  }

  Future<void> _fetch() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final items = await _db.getOutboxItems(limit: _fetchLimit);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error, stackTrace) {
      getIt<LoggingService>().captureException(
        error,
        domain: 'OUTBOX',
        subDomain: 'fetch',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      // Surface the failure to the user — on the initial load, this is
      // the only signal that something went wrong (otherwise the page
      // would just render the same "Outbox is clear" empty state as a
      // legitimately empty outbox). On a refresh failure, leave the
      // prior snapshot in place so the user does not lose context.
      setState(() => _items ??= const <OutboxItem>[]);
      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.outboxMonitorFetchFailed,
      );
    } finally {
      _isFetching = false;
    }
  }

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

      await _fetch();

      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: context.messages.outboxMonitorRetryQueued,
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
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.outboxMonitorRetryFailed,
      );
    }
  }

  Future<void> _deleteItem(BuildContext context, OutboxItem item) async {
    final confirmed = await showConfirmationModal(
      context: context,
      message: context.messages.outboxMonitorDeleteConfirmMessage,
      confirmLabel: context.messages.outboxMonitorDeleteConfirmLabel,
      cancelLabel: context.messages.cancelButton,
    );
    if (!confirmed) return;

    try {
      await _db.deleteOutboxItemById(item.id);

      await _fetch();

      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: context.messages.outboxMonitorDeleteSuccess,
      );
    } catch (error, stackTrace) {
      getIt<LoggingService>().captureException(
        error,
        domain: 'OUTBOX',
        subDomain: 'delete_item',
        stackTrace: stackTrace,
      );
      if (!context.mounted) {
        return;
      }
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.outboxMonitorDeleteFailed,
      );
    }
  }

  OutboxStatus? _statusFromIndex(int statusIndex) {
    if (statusIndex < 0 || statusIndex >= OutboxStatus.values.length) {
      return null;
    }
    return OutboxStatus.values[statusIndex];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filters = <_OutboxListFilter, SyncFilterOption<OutboxItem>>{
      _OutboxListFilter.pending: SyncFilterOption<OutboxItem>(
        labelBuilder: (context) => context.messages.outboxMonitorLabelPending,
        predicate: (OutboxItem item) {
          final status = _statusFromIndex(item.status);
          return status == OutboxStatus.pending ||
              status == OutboxStatus.sending;
        },
        icon: Icons.schedule_rounded,
        selectedColor: syncPendingAccentColor,
        selectedForegroundColor: syncPendingForegroundColor,
        hideCountWhenZero: true,
        countAccentColor: syncPendingCountAccentColor,
        countAccentForegroundColor: syncPendingForegroundColor,
      ),
      _OutboxListFilter.success: SyncFilterOption<OutboxItem>(
        labelBuilder: (context) => context.messages.outboxMonitorLabelSuccess,
        predicate: (OutboxItem item) =>
            _statusFromIndex(item.status) == OutboxStatus.sent,
        icon: Icons.check_circle_outline_rounded,
        selectedColor: syncSuccessAccentColor,
        selectedForegroundColor: syncSuccessForegroundColor,
        showCount: false,
      ),
      _OutboxListFilter.error: SyncFilterOption<OutboxItem>(
        labelBuilder: (context) => context.messages.outboxMonitorLabelError,
        predicate: (OutboxItem item) =>
            _statusFromIndex(item.status) == OutboxStatus.error,
        icon: Icons.error_outline_rounded,
        selectedColor: colorScheme.error,
        selectedForegroundColor: colorScheme.onError,
        hideCountWhenZero: true,
        countAccentColor: syncErrorCountAccentColor(colorScheme),
        countAccentForegroundColor: colorScheme.onError,
      ),
    };

    return SyncListScaffold<OutboxItem, _OutboxListFilter>(
      title: context.messages.settingsSyncOutboxTitle,
      subtitle: context.messages.settingsAdvancedOutboxSubtitle,
      items: _items,
      isLoading: _items == null,
      onRefresh: _fetch,
      headerSliver: const OutboxVolumeChart(),
      filters: filters,
      initialFilter: _OutboxListFilter.pending,
      emptyIcon: Icons.inbox_rounded,
      emptyTitleBuilder: (ctx) => ctx.messages.outboxMonitorEmptyTitle,
      emptyDescriptionBuilder: (ctx) =>
          ctx.messages.outboxMonitorEmptyDescription,
      countSummaryBuilder: (ctx, label, count) =>
          ctx.messages.syncListCountSummary(label, count),
      itemBuilder: (ctx, OutboxItem item) {
        final isError = _statusFromIndex(item.status) == OutboxStatus.error;
        return OutboxListItem(
          item: item,
          showRetry: isError,
          onRetry: () => _retryItem(ctx, item),
          showDelete: isError,
          onDelete: () => _deleteItem(ctx, item),
        );
      },
    );
  }
}

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/ui/view_models/outbox_status_presentation.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_message_card.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_summary_header.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_volume_chart.dart';
import 'package:lotti/features/sync/ui/widgets/sync_list_scaffold.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';

enum _OutboxListFilter { waiting, failed, sent }

/// Full-page outbox monitor — used by the V1 beamer route and kept as the
/// entry-point class so existing callers and tests continue to work.
class OutboxMonitorPage extends StatefulWidget {
  const OutboxMonitorPage({super.key});

  @override
  State<OutboxMonitorPage> createState() => _OutboxMonitorPageState();
}

/// Content body for the Settings V2 detail pane. Re-uses the page verbatim;
/// the minor title duplication inside the V2 leaf panel is a known cosmetic
/// issue tracked for polish.
class OutboxMonitorBody extends StatelessWidget {
  const OutboxMonitorBody({super.key});

  @override
  Widget build(BuildContext context) => const OutboxMonitorPage();
}

class _OutboxMonitorPageState extends State<OutboxMonitorPage> {
  final SyncDatabase _db = getIt<SyncDatabase>();

  // The page deliberately does NOT subscribe to a live `watch()` stream: the
  // outbox grows by hundreds of rows per minute during sync, and a live
  // watcher with the CASE-WHEN ORDER BY this page needs forces SQLite into a
  // temp B-tree sort on every write. Snapshot + pull-to-refresh is what an
  // operator actually needs here.
  static const int _fetchLimit = 2500;

  List<OutboxItem>? _items;
  bool _isFetching = false;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
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
      getIt<DomainLogger>().error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'fetch',
      );
      if (!mounted) return;
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

  OutboxStatus? _statusFromIndex(int statusIndex) {
    if (statusIndex < 0 || statusIndex >= OutboxStatus.values.length) {
      return null;
    }
    return OutboxStatus.values[statusIndex];
  }

  _OutboxCounts _counts() {
    var pending = 0;
    var sending = 0;
    var error = 0;
    for (final item in _items ?? const <OutboxItem>[]) {
      switch (_statusFromIndex(item.status)) {
        case OutboxStatus.pending:
          pending++;
        case OutboxStatus.sending:
          sending++;
        case OutboxStatus.error:
          error++;
        case OutboxStatus.sent:
        case null:
          break;
      }
    }
    return _OutboxCounts(pending: pending, sending: sending, error: error);
  }

  Future<void> _retryItem(OutboxItem item) => _requeue([item]);

  Future<void> _retryAll() {
    final errors = (_items ?? const <OutboxItem>[])
        .where((i) => _statusFromIndex(i.status) == OutboxStatus.error)
        .toList();
    return _requeue(errors);
  }

  /// Re-queues failed items by flipping them back to pending so the runner
  /// picks them up again. Non-destructive and idempotent, so each row is
  /// retried independently — one bad write doesn't strand the rest, and the
  /// user can simply tap again. Reports overall success/failure.
  Future<void> _requeue(List<OutboxItem> items) async {
    if (items.isEmpty) return;
    var failed = 0;
    for (final item in items) {
      try {
        await _db.updateOutboxItem(
          OutboxCompanion(
            id: drift.Value(item.id),
            status: drift.Value(OutboxStatus.pending.index),
            retries: drift.Value(item.retries + 1),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
      } catch (error, stackTrace) {
        failed++;
        getIt<DomainLogger>().error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: 'retry',
        );
      }
    }
    await _fetch();
    if (!mounted) return;
    context.showToast(
      tone: failed == 0
          ? DesignSystemToastTone.success
          : DesignSystemToastTone.error,
      title: failed == 0
          ? context.messages.outboxMonitorRetryQueued
          : context.messages.outboxMonitorRetryFailed,
    );
  }

  Future<void> _removeItem(OutboxItem item) async {
    final confirmed = await showConfirmationModal(
      context: context,
      title: context.messages.outboxRemoveConfirmTitle,
      message: context.messages.outboxRemoveConfirmMessage,
      confirmLabel: context.messages.outboxActionRemove,
      cancelLabel: context.messages.cancelButton,
    );
    if (!confirmed || !mounted) return;

    try {
      await _db.deleteOutboxItemById(item.id);
      await _fetch();
      if (!mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: context.messages.outboxMonitorDeleteSuccess,
      );
    } catch (error, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'remove_item',
      );
      if (!mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.outboxMonitorDeleteFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.designTokens.colors;
    final onAlert = colors.text.onInteractiveAlert;
    final filters = <_OutboxListFilter, SyncFilterOption<OutboxItem>>{
      _OutboxListFilter.waiting: SyncFilterOption<OutboxItem>(
        labelBuilder: (ctx) => ctx.messages.outboxFilterWaiting,
        predicate: (item) {
          final status = _statusFromIndex(item.status);
          // Unknown/corrupt status indices fall here too, so a row is never
          // invisible across every filter.
          return status == OutboxStatus.pending ||
              status == OutboxStatus.sending ||
              status == null;
        },
        icon: Icons.schedule_rounded,
        selectedColor: colors.alert.warning.defaultColor,
        selectedForegroundColor: onAlert,
        hideCountWhenZero: true,
        countAccentColor: colors.alert.warning.defaultColor,
        countAccentForegroundColor: onAlert,
      ),
      _OutboxListFilter.failed: SyncFilterOption<OutboxItem>(
        labelBuilder: (ctx) => ctx.messages.outboxFilterFailed,
        predicate: (item) =>
            _statusFromIndex(item.status) == OutboxStatus.error,
        icon: Icons.error_outline_rounded,
        selectedColor: colors.alert.error.defaultColor,
        selectedForegroundColor: onAlert,
        hideCountWhenZero: true,
        countAccentColor: colors.alert.error.defaultColor,
        countAccentForegroundColor: onAlert,
      ),
      _OutboxListFilter.sent: SyncFilterOption<OutboxItem>(
        labelBuilder: (ctx) => ctx.messages.outboxStatusSent,
        predicate: (item) => _statusFromIndex(item.status) == OutboxStatus.sent,
        icon: Icons.check_circle_outline_rounded,
        selectedColor: colors.alert.success.defaultColor,
        selectedForegroundColor: onAlert,
        showCount: false,
      ),
    };

    return SyncListScaffold<OutboxItem, _OutboxListFilter>(
      title: context.messages.settingsSyncOutboxTitle,
      subtitle: context.messages.settingsAdvancedOutboxSubtitle,
      items: _items,
      isLoading: _items == null,
      onRefresh: _fetch,
      headerSliver: _OutboxHeader(
        counts: _counts(),
        showDetails: _showDetails,
        onToggleDetails: (value) => setState(() => _showDetails = value),
        onRetryAll: _retryAll,
      ),
      filters: filters,
      initialFilter: _OutboxListFilter.waiting,
      emptyIcon: Icons.inbox_rounded,
      emptyTitleBuilder: (ctx) => ctx.messages.outboxMonitorEmptyTitle,
      emptyDescriptionBuilder: (ctx) =>
          ctx.messages.outboxMonitorEmptyDescription,
      countSummaryBuilder: (ctx, label, count) =>
          ctx.messages.syncListCountSummary(label, count),
      itemBuilder: (ctx, item) {
        final isError = _statusFromIndex(item.status) == OutboxStatus.error;
        return OutboxMessageCard(
          item: item,
          showDetails: _showDetails,
          onRetry: isError ? () => _retryItem(item) : null,
          onRemove: isError ? () => _removeItem(item) : null,
        );
      },
    );
  }
}

class _OutboxCounts {
  const _OutboxCounts({
    required this.pending,
    required this.sending,
    required this.error,
  });

  final int pending;
  final int sending;
  final int error;
}

/// The page header: a plain-language summary line (which reads sign-in state to
/// distinguish "offline" from "failed") plus a "show technical details" toggle
/// that reveals the per-row diagnostics and the volume chart.
class _OutboxHeader extends ConsumerWidget {
  const _OutboxHeader({
    required this.counts,
    required this.showDetails,
    required this.onToggleDetails,
    required this.onRetryAll,
  });

  final _OutboxCounts counts;
  final bool showDetails;
  final ValueChanged<bool> onToggleDetails;
  final VoidCallback onRetryAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final online =
        ref.watch(outboxConnectionStateProvider).value ==
        OutboxConnectionState.online;
    final summary = summarizeOutbox(
      pendingCount: counts.pending,
      sendingCount: counts.sending,
      failedCount: counts.error,
      syncEnabled: true,
      signedIn: online,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutboxSummaryHeader(summary: summary, onRetryAll: onRetryAll),
        SizedBox(height: tokens.spacing.step2),
        Row(
          children: [
            Expanded(
              child: Text(
                context.messages.outboxShowDetails,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: colors.text.mediumEmphasis,
                ),
              ),
            ),
            Switch.adaptive(value: showDetails, onChanged: onToggleDetails),
          ],
        ),
        if (showDetails) ...[
          SizedBox(height: tokens.spacing.step2),
          const OutboxVolumeChart(),
        ],
      ],
    );
  }
}

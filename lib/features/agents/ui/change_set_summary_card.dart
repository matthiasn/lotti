import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

/// Displays pending change sets for a task, allowing the user to confirm
/// or reject individual items via swipe gestures or buttons.
///
/// Renders nothing when no pending change sets exist.
class ChangeSetSummaryCard extends ConsumerWidget {
  const ChangeSetSummaryCard({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changeSetsAsync = ref.watch(pendingChangeSetsProvider(taskId));

    return changeSetsAsync.when(
      data: (entities) {
        final changeSets = entities.whereType<ChangeSetEntity>().toList();
        if (changeSets.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              for (final changeSet in changeSets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ChangeSetCard(changeSet: changeSet),
                ),
            ],
          ),
        );
      },
      error: (_, __) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}

class _ChangeSetCard extends ConsumerStatefulWidget {
  const _ChangeSetCard({required this.changeSet});

  final ChangeSetEntity changeSet;

  @override
  ConsumerState<_ChangeSetCard> createState() => _ChangeSetCardState();
}

class _ChangeSetCardState extends ConsumerState<_ChangeSetCard> {
  bool _confirmAllBusy = false;

  @override
  Widget build(BuildContext context) {
    final pendingCount = widget.changeSet.items
        .where((item) => item.status == ChangeItemStatus.pending)
        .length;

    return ModernBaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.pending_actions,
                size: 20,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.messages.changeSetCardTitle,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    context.messages.changeSetPendingCount(pendingCount),
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Item list
          for (var i = 0; i < widget.changeSet.items.length; i++)
            _ChangeItemTile(
              changeSet: widget.changeSet,
              itemIndex: i,
            ),

          // Confirm All button (only if there are pending items)
          if (pendingCount > 0) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: _confirmAllBusy ? null : () => _confirmAll(context),
                child: _confirmAllBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.messages.changeSetConfirmAll),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmAll(BuildContext context) async {
    if (_confirmAllBusy) return;
    setState(() => _confirmAllBusy = true);

    // Capture ref-dependent values before the async gap so we don't
    // access ref after the widget is unmounted.
    final service = ref.read(changeSetConfirmationServiceProvider);
    final notifier = ref.read(updateNotificationsProvider);
    final agentId = widget.changeSet.agentId;

    try {
      final results = await service.confirmAll(widget.changeSet);

      // Trigger provider invalidation.
      notifier.notify({agentId});

      final anyFailed = results.any((r) => !r.success);
      if (anyFailed && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.messages.changeSetConfirmError)),
        );
      }
    } catch (e) {
      developer.log(
        'confirmAll failed: $e',
        name: 'ChangeSetSummaryCard',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.messages.changeSetConfirmError)),
        );
      }
    } finally {
      if (mounted) setState(() => _confirmAllBusy = false);
    }
  }
}

class _ChangeItemTile extends ConsumerStatefulWidget {
  const _ChangeItemTile({
    required this.changeSet,
    required this.itemIndex,
  });

  final ChangeSetEntity changeSet;
  final int itemIndex;

  @override
  ConsumerState<_ChangeItemTile> createState() => _ChangeItemTileState();
}

class _ChangeItemTileState extends ConsumerState<_ChangeItemTile> {
  bool _busy = false;

  ChangeSetEntity get _changeSet => widget.changeSet;
  int get _itemIndex => widget.itemIndex;
  ChangeItem get _item => _changeSet.items[_itemIndex];

  @override
  Widget build(BuildContext context) {
    final isPending = _item.status == ChangeItemStatus.pending;

    if (!isPending) {
      return _buildResolvedTile(context);
    }

    return Dismissible(
      key: Key('${_changeSet.id}_$_itemIndex'),
      dismissThresholds: const {
        DismissDirection.endToStart: 0.25,
        DismissDirection.startToEnd: 0.25,
      },
      confirmDismiss: (direction) async {
        if (_busy) return false;
        if (direction == DismissDirection.startToEnd) {
          await _confirm(context);
        } else {
          await _reject(context);
        }
        // Don't actually dismiss — state update handles the visual change.
        return false;
      },
      // Confirm background (swipe right) — green
      background: ColoredBox(
        color: Colors.green.shade700,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: AppTheme.cardPadding),
            child: Row(
              children: [
                const Icon(Icons.check, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  context.messages.changeSetSwipeConfirm,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Reject background (swipe left) — red
      secondaryBackground: ColoredBox(
        color: context.colorScheme.error,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: AppTheme.cardPadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.messages.changeSetSwipeReject,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.close, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
      child: _buildPendingTile(context),
    );
  }

  Widget _buildPendingTile(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        _item.humanSummary,
        style: context.textTheme.bodyMedium,
      ),
      subtitle: Text(
        _item.toolName,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade700,
                  ),
                  tooltip: context.messages.changeSetSwipeConfirm,
                  onPressed: () => _confirm(context),
                ),
                IconButton(
                  icon: Icon(
                    Icons.cancel_outlined,
                    color: context.colorScheme.error,
                  ),
                  tooltip: context.messages.changeSetSwipeReject,
                  onPressed: () => _reject(context),
                ),
              ],
            ),
    );
  }

  Widget _buildResolvedTile(BuildContext context) {
    final isConfirmed = _item.status == ChangeItemStatus.confirmed;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        _item.humanSummary,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
          decoration: TextDecoration.lineThrough,
        ),
      ),
      trailing: Icon(
        isConfirmed ? Icons.check_circle : Icons.cancel,
        size: 20,
        color: isConfirmed ? Colors.green.shade700 : context.colorScheme.error,
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);

    // Capture ref-dependent values before the async gap.
    final service = ref.read(changeSetConfirmationServiceProvider);
    final notifier = ref.read(updateNotificationsProvider);
    final agentId = _changeSet.agentId;

    try {
      final result = await service.confirmItem(_changeSet, _itemIndex);
      notifier.notify({agentId});

      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                result.success
                    ? context.messages.changeSetItemConfirmed
                    : context.messages.changeSetConfirmError,
              ),
            ),
          );
      }
    } catch (e) {
      developer.log(
        'confirmItem failed: $e',
        name: 'ChangeSetSummaryCard',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text(context.messages.changeSetConfirmError)),
          );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);

    // Capture ref-dependent values before the async gap.
    final service = ref.read(changeSetConfirmationServiceProvider);
    final notifier = ref.read(updateNotificationsProvider);
    final agentId = _changeSet.agentId;

    try {
      final applied = await service.rejectItem(_changeSet, _itemIndex);
      notifier.notify({agentId});

      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                applied
                    ? context.messages.changeSetItemRejected
                    : context.messages.changeSetConfirmError,
              ),
            ),
          );
      }
    } catch (e) {
      developer.log(
        'rejectItem failed: $e',
        name: 'ChangeSetSummaryCard',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text(context.messages.changeSetConfirmError)),
          );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

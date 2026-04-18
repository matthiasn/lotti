import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/time_entry_datetime.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Renders a single open proposal as a swipeable, tappable row inside the
/// consolidated agent suggestion list.
///
/// Swipe-right / tap-✓ confirms the item via
/// `ChangeSetConfirmationService.confirmItem`. Swipe-left / tap-✗ rejects
/// it. Time-entry items get a specialized two-line timer layout; every
/// other tool uses a generic summary tile.
class SuggestionRow extends ConsumerStatefulWidget {
  const SuggestionRow({required this.suggestion, super.key});

  final PendingSuggestion suggestion;

  @override
  ConsumerState<SuggestionRow> createState() => _SuggestionRowState();
}

class _SuggestionRowState extends ConsumerState<SuggestionRow> {
  bool _busy = false;

  PendingSuggestion get _suggestion => widget.suggestion;

  static const _borderRadius = BorderRadius.all(Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: _borderRadius,
      child: Dismissible(
        key: Key(
          'suggestion_${_suggestion.changeSet.id}_${_suggestion.itemIndex}',
        ),
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
          // Never actually dismiss — the provider-level state update drives
          // the visual removal when the item transitions out of pending.
          return false;
        },
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
        child: _buildTile(context),
      ),
    );
  }

  Widget _buildTile(BuildContext context) {
    if (_suggestion.item.toolName == TaskAgentToolNames.createTimeEntry) {
      return _buildTimeEntryTile(context);
    }
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(
        _suggestion.item.humanSummary,
        style: context.textTheme.bodyMedium,
      ),
      subtitle: Text(
        _suggestion.item.toolName,
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
          : null,
    );
  }

  Widget _buildTimeEntryTile(BuildContext context) {
    final args = _suggestion.item.args;
    final startRawValue = args['startTime'];
    final startRaw = startRawValue is String && startRawValue.trim().isNotEmpty
        ? startRawValue.trim()
        : null;
    final hasEndTime = args.containsKey('endTime');
    final endRawValue = args['endTime'];
    final endRaw = endRawValue is String && endRawValue.trim().isNotEmpty
        ? endRawValue.trim()
        : null;
    final summary = args['summary'] is String
        ? (args['summary'] as String).trim()
        : '';

    final start = startRaw != null
        ? parseTimeEntryLocalDateTime(startRaw)
        : null;
    final end = endRaw != null ? parseTimeEntryLocalDateTime(endRaw) : null;

    final startStr = start != null
        ? formatTimeEntryHhMm(start)
        : (startRaw ?? '?');
    final endStr = end != null
        ? formatTimeEntryHhMm(end)
        : hasEndTime
        ? (endRaw ?? '?')
        : context.messages.timeEntryItemRunning;

    final dimStyle = context.textTheme.bodySmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    final valueStyle = context.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.timer_outlined,
              size: 16,
              color: context.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _timeFieldRow(
                  label: context.messages.timeEntryItemStart,
                  value: startStr,
                  dimStyle: dimStyle,
                  valueStyle: valueStyle,
                ),
                const SizedBox(height: 4),
                _timeFieldRow(
                  label: context.messages.timeEntryItemEnd,
                  value: endStr,
                  dimStyle: dimStyle,
                  valueStyle: valueStyle,
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _timeFieldRow({
    required String label,
    required String value,
    required TextStyle? dimStyle,
    required TextStyle? valueStyle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: dimStyle),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: valueStyle,
          ),
        ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);

    final service = ref.read(changeSetConfirmationServiceProvider);
    final notifier = ref.read(updateNotificationsProvider);
    final agentId = _suggestion.changeSet.agentId;

    try {
      final result = await service.confirmItem(
        _suggestion.changeSet,
        _suggestion.itemIndex,
      );
      notifier.notify({agentId});

      if (context.mounted) {
        final message = !result.success
            ? context.messages.changeSetConfirmError
            : result.errorMessage != null
            ? context.messages.changeSetItemConfirmedWithWarning(
                result.errorMessage!,
              )
            : context.messages.changeSetItemConfirmed;

        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      developer.log('confirmItem failed: $e', name: 'SuggestionRow');
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

    final service = ref.read(changeSetConfirmationServiceProvider);
    final notifier = ref.read(updateNotificationsProvider);
    final agentId = _suggestion.changeSet.agentId;

    try {
      final applied = await service.rejectItem(
        _suggestion.changeSet,
        _suggestion.itemIndex,
      );
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
      developer.log('rejectItem failed: $e', name: 'SuggestionRow');
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

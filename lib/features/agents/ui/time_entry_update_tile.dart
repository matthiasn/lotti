import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/time_entry_datetime.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

// ignore: specify_nonobvious_property_types
final timeEntryUpdateTileEntryProvider = FutureProvider.autoDispose
    .family<JournalEntity?, String>((ref, entryId) {
      return ref.watch(journalRepositoryProvider).getJournalEntityById(entryId);
    });

/// Review presentation for a pending `update_time_entry` proposal.
///
/// Renders the current persisted values next to the proposed values so the
/// user can confirm historical edits without opening the journal entry.
class TimeEntryUpdateTile extends ConsumerWidget {
  const TimeEntryUpdateTile({
    required this.args,
    required this.busy,
    super.key,
  });

  final Map<String, dynamic> args;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryId = _trimmedString(args['entryId']);
    final entryAsync = entryId == null
        ? const AsyncData<JournalEntity?>(null)
        : ref.watch(timeEntryUpdateTileEntryProvider(entryId));

    return entryAsync.when(
      data: (entry) => _TimeEntryUpdateContent(
        args: args,
        busy: busy,
        entry: entry is JournalEntry ? entry : null,
        currentUnavailable: entry is! JournalEntry,
      ),
      loading: () => _TimeEntryUpdateContent(
        args: args,
        busy: busy,
        entry: null,
        currentUnavailable: false,
      ),
      error: (_, _) => _TimeEntryUpdateContent(
        args: args,
        busy: busy,
        entry: null,
        currentUnavailable: true,
      ),
    );
  }

  static String? _trimmedString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _TimeEntryUpdateContent extends StatelessWidget {
  const _TimeEntryUpdateContent({
    required this.args,
    required this.busy,
    required this.entry,
    required this.currentUnavailable,
  });

  final Map<String, dynamic> args;
  final bool busy;
  final JournalEntry? entry;
  final bool currentUnavailable;

  @override
  Widget build(BuildContext context) {
    final dimStyle = context.textTheme.bodySmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    final valueStyle = context.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final fields = [
      _DiffField(
        label: context.messages.timeEntryItemStart,
        currentValue: _formatDateTime(entry?.meta.dateFrom, null),
        proposedValue: _formatDateTime(
          _parseDateTime(args['startTime']),
          _trimmedString(args['startTime']),
        ),
        touched: args.containsKey('startTime'),
        currentUnavailable: currentUnavailable,
        dimStyle: dimStyle,
        valueStyle: valueStyle,
      ),
      _DiffField(
        label: context.messages.timeEntryItemEnd,
        currentValue: _formatDateTime(entry?.meta.dateTo, null),
        proposedValue: _formatDateTime(
          _parseDateTime(args['endTime']),
          _trimmedString(args['endTime']),
        ),
        touched: args.containsKey('endTime'),
        currentUnavailable: currentUnavailable,
        dimStyle: dimStyle,
        valueStyle: valueStyle,
      ),
      _DiffField(
        label: context.messages.agentMessageKindSummary,
        currentValue: _displayText(entry?.entryText?.plainText),
        proposedValue: _displayText(_trimmedString(args['summary'])),
        touched: args.containsKey('summary'),
        currentUnavailable: currentUnavailable,
        dimStyle: dimStyle,
        valueStyle: valueStyle,
        maxLines: 2,
      ),
    ].where((field) => field.shouldRender).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.edit_calendar_outlined,
              size: 16,
              color: context.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentUnavailable) ...[
                  Text(
                    context.messages.agentSuggestionTimeEntryUpdateUnavailable,
                    style: dimStyle,
                  ),
                  const SizedBox(height: 4),
                ],
                for (var index = 0; index < fields.length; index++) ...[
                  if (index > 0) const SizedBox(height: 4),
                  fields[index],
                ],
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    final raw = _trimmedString(value);
    return raw == null ? null : parseTimeEntryLocalDateTime(raw);
  }

  static String _formatDateTime(DateTime? dateTime, String? raw) {
    if (dateTime == null) return raw ?? '-';
    final date =
        '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')}';
    return '$date ${formatTimeEntryHhMm(dateTime)}';
  }

  static String _displayText(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? '-' : trimmed;
  }

  static String? _trimmedString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _DiffField extends StatelessWidget {
  const _DiffField({
    required this.label,
    required this.currentValue,
    required this.proposedValue,
    required this.touched,
    required this.currentUnavailable,
    required this.dimStyle,
    required this.valueStyle,
    this.maxLines = 1,
  });

  final String label;
  final String currentValue;
  final String proposedValue;
  final bool touched;
  final bool currentUnavailable;
  final TextStyle? dimStyle;
  final TextStyle? valueStyle;
  final int maxLines;

  bool get shouldRender => touched || !currentUnavailable;

  @override
  Widget build(BuildContext context) {
    if (!shouldRender) return const SizedBox.shrink();

    final messages = context.messages;
    final currentLabel = messages.agentSuggestionTimeEntryUpdateCurrent;
    final proposedLabel = messages.agentSuggestionTimeEntryUpdateProposed;
    final noChangeLabel = messages.agentSuggestionTimeEntryUpdateNoChange;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: dimStyle),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!currentUnavailable)
                Text(
                  touched
                      ? '$currentLabel: $currentValue'
                      : '$currentLabel: $currentValue $noChangeLabel',
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  softWrap: maxLines > 1,
                  style: dimStyle,
                ),
              if (touched) ...[
                if (!currentUnavailable) const SizedBox(height: 2),
                Text(
                  '$proposedLabel: $proposedValue',
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  softWrap: maxLines > 1,
                  style: valueStyle,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

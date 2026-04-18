import 'package:flutter/material.dart';
import 'package:lotti/features/agents/time_entry_datetime.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Shared presentation for a pending `create_time_entry` proposal.
///
/// Renders the start/end labels (falling back to the raw string when the
/// timestamp is unparseable, or "running" when `endTime` is absent),
/// optional session summary, and a trailing progress indicator while the
/// parent widget is busy.
class TimeEntryTile extends StatelessWidget {
  const TimeEntryTile({
    required this.args,
    required this.busy,
    super.key,
  });

  final Map<String, dynamic> args;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final startRaw = _trimmedString(args['startTime']);
    final endRaw = _trimmedString(args['endTime']);
    final summary = _trimmedString(args['summary']) ?? '';

    final start = startRaw != null
        ? parseTimeEntryLocalDateTime(startRaw)
        : null;
    final end = endRaw != null ? parseTimeEntryLocalDateTime(endRaw) : null;

    final startStr = start != null
        ? formatTimeEntryHhMm(start)
        : (startRaw ?? '?');
    final endStr = end != null
        ? formatTimeEntryHhMm(end)
        : endRaw ?? context.messages.timeEntryItemRunning;

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
                _TimeField(
                  label: context.messages.timeEntryItemStart,
                  value: startStr,
                  dimStyle: dimStyle,
                  valueStyle: valueStyle,
                ),
                const SizedBox(height: 4),
                _TimeField(
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

  static String? _trimmedString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.dimStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? dimStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
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
}

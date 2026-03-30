import 'package:flutter/material.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_time_picker.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/date_utils_extension.dart';

enum _EditingField { none, start, end }

/// Inline editor for a single time block: start/end labels + delete + inline picker.
class TimeBlockEditor extends StatefulWidget {
  const TimeBlockEditor({
    required this.block,
    required this.planDate,
    required this.onChanged,
    required this.onDelete,
    super.key,
  });

  final PlannedBlock block;
  final DateTime planDate;
  final ValueChanged<PlannedBlock> onChanged;
  final VoidCallback onDelete;

  @override
  State<TimeBlockEditor> createState() => _TimeBlockEditorState();
}

class _TimeBlockEditorState extends State<TimeBlockEditor> {
  _EditingField _editingField = _EditingField.none;

  TimeOfDay get _startTime => TimeOfDay(
    hour: widget.block.startTime.hour,
    minute: widget.block.startTime.minute,
  );

  TimeOfDay get _endTime => TimeOfDay(
    hour: widget.block.endTime.hour,
    minute: widget.block.endTime.minute,
  );

  void _updateTime(_EditingField field, TimeOfDay time) {
    final midnight = widget.planDate.dayAtMidnight;
    final dayEnd = midnight.add(const Duration(days: 1));
    var newStart = field == _EditingField.start
        ? midnight.add(Duration(hours: time.hour, minutes: time.minute))
        : widget.block.startTime;
    var newEnd = field == _EditingField.end
        ? midnight.add(Duration(hours: time.hour, minutes: time.minute))
        : widget.block.endTime;

    // Auto-adjust the opposite bound to keep a valid range.
    if (!newEnd.isAfter(newStart)) {
      if (field == _EditingField.start) {
        newEnd = newStart.add(const Duration(hours: 1));
      } else {
        newStart = newEnd.subtract(const Duration(hours: 1));
      }
    }

    // Clamp to plan day boundaries.
    if (newStart.isBefore(midnight)) newStart = midnight;
    if (newEnd.isAfter(dayEnd)) newEnd = dayEnd;
    if (!newEnd.isAfter(newStart)) return;

    widget.onChanged(
      widget.block.copyWith(startTime: newStart, endTime: newEnd),
    );
  }

  String _formatTime(BuildContext context, TimeOfDay time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step3,
          ),
          child: Row(
            children: [
              // Rounded container wrapping start/end time labels
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step3,
                  vertical: tokens.spacing.step2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(tokens.radii.l),
                  border: Border.all(
                    color: tokens.colors.decorative.level01,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TimeLabel(
                      label: _formatTime(context, _startTime),
                      isActive: _editingField == _EditingField.start,
                      tokens: tokens,
                      onTap: () => setState(() {
                        _editingField = _editingField == _EditingField.start
                            ? _EditingField.none
                            : _EditingField.start;
                      }),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.spacing.step3,
                      ),
                      child: Text(
                        '-',
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ),
                    _TimeLabel(
                      label: _formatTime(context, _endTime),
                      isActive: _editingField == _EditingField.end,
                      tokens: tokens,
                      onTap: () => setState(() {
                        _editingField = _editingField == _EditingField.end
                            ? _EditingField.none
                            : _EditingField.end;
                      }),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: tokens.colors.alert.error.defaultColor,
                ),
                onPressed: widget.onDelete,
                tooltip: context.messages.dailyOsDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: _editingField != _EditingField.none
              ? DesignSystemTimePicker(
                  key: ValueKey(_editingField),
                  initialTime: _editingField == _EditingField.start
                      ? _startTime
                      : _endTime,
                  format: MediaQuery.alwaysUse24HourFormatOf(context)
                      ? DesignSystemTimeFormat.twentyFourHour
                      : DesignSystemTimeFormat.twelveHour,
                  onTimeChanged: (time) => _updateTime(_editingField, time),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({
    required this.label,
    required this.isActive,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final DsTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(tokens.radii.s);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step3,
            vertical: tokens.spacing.step2,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? tokens.colors.interactive.enabled.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: borderRadius,
            border: Border.all(
              color: isActive
                  ? tokens.colors.interactive.enabled
                  : tokens.colors.decorative.level01,
            ),
          ),
          child: Text(
            label,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: isActive
                  ? tokens.colors.interactive.enabled
                  : tokens.colors.text.highEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}

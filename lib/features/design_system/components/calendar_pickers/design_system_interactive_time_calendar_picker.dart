import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_time_calendar_picker.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class DesignSystemInteractiveTimeCalendarPicker extends StatefulWidget {
  const DesignSystemInteractiveTimeCalendarPicker({
    required this.mode,
    required this.presentation,
    required this.initialSelectedDate,
    required this.currentDate,
    super.key,
  }) : assert(
         presentation != DesignSystemTimeCalendarPickerPresentation.monthDialog,
         'Use DesignSystemTimeCalendarPicker for standalone month dialogs.',
       );

  final DesignSystemTimeCalendarPickerMode mode;
  final DesignSystemTimeCalendarPickerPresentation presentation;
  final DateTime initialSelectedDate;
  final DateTime currentDate;

  @override
  State<DesignSystemInteractiveTimeCalendarPicker> createState() =>
      _DesignSystemInteractiveTimeCalendarPickerState();
}

class _DesignSystemInteractiveTimeCalendarPickerState
    extends State<DesignSystemInteractiveTimeCalendarPicker> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = dateOnly(widget.initialSelectedDate);
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  Future<void> _showMonthDialog() async {
    final nextMonth = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 150),
      barrierColor: Colors.black.withValues(
        alpha: widget.mode == DesignSystemTimeCalendarPickerMode.dark
            ? 0.24
            : 0.16,
      ),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final geometry = TimeCalendarGeometry.fromTokens(
          dialogContext.designTokens,
        );

        return SizedBox.expand(
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: const SizedBox.expand(),
                ),
                Center(
                  child: Padding(
                    padding: geometry.dialogInsetPadding,
                    child: GestureDetector(
                      behavior: HitTestBehavior.deferToChild,
                      onTap: () {},
                      child: DesignSystemTimeCalendarPicker(
                        mode: widget.mode,
                        presentation: DesignSystemTimeCalendarPickerPresentation
                            .monthDialog,
                        visibleMonth: _visibleMonth,
                        selectedDate: _selectedDate,
                        currentDate: dateOnly(widget.currentDate),
                        onMonthPressed: Navigator.of(dialogContext).pop,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (nextMonth == null || !mounted) {
      return;
    }

    _updateVisibleMonth(nextMonth);
  }

  void _updateVisibleMonth(DateTime nextMonth) {
    setState(() {
      _visibleMonth = DateTime(nextMonth.year, nextMonth.month);
      final clampedDay = math.min(
        _selectedDate.day,
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day,
      );
      _selectedDate = DateTime(
        _visibleMonth.year,
        _visibleMonth.month,
        clampedDay,
      );
    });
  }

  void _changeMonth(int delta) {
    _updateVisibleMonth(
      DateTime(_visibleMonth.year, _visibleMonth.month + delta),
    );
  }

  void _selectDay(DateTime date) {
    setState(() {
      _selectedDate = dateOnly(date);
      _visibleMonth = DateTime(date.year, date.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DesignSystemTimeCalendarPicker(
      mode: widget.mode,
      presentation: widget.presentation,
      visibleMonth: _visibleMonth,
      selectedDate: _selectedDate,
      currentDate: dateOnly(widget.currentDate),
      onMonthYearPressed: _showMonthDialog,
      onPreviousPressed: () => _changeMonth(-1),
      onNextPressed: () => _changeMonth(1),
      onDayPressed: _selectDay,
    );
  }
}

class MonthSelectionDialogCard extends StatefulWidget {
  const MonthSelectionDialogCard({
    required this.mode,
    required this.visibleMonth,
    required this.selectedMonth,
    this.onMonthPressed,
    super.key,
  });

  final DesignSystemTimeCalendarPickerMode mode;
  final DateTime visibleMonth;
  final int selectedMonth;
  final ValueChanged<DateTime>? onMonthPressed;

  @override
  State<MonthSelectionDialogCard> createState() =>
      _MonthSelectionDialogCardState();
}

class _MonthSelectionDialogCardState extends State<MonthSelectionDialogCard> {
  late int _visibleYear;

  @override
  void initState() {
    super.initState();
    _visibleYear = widget.visibleMonth.year;
  }

  @override
  Widget build(BuildContext context) {
    final palette = TimeCalendarPalette.fromMode(widget.mode);
    final geometry = TimeCalendarGeometry.fromTokens(context.designTokens);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final months = List.generate(
      12,
      (index) =>
          DateFormat.MMM(localeTag).format(DateTime(_visibleYear, index + 1)),
    );

    return CalendarMaterialCard(
      palette: palette,
      geometry: geometry,
      padding: geometry.monthDialogPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonthHeader(
            palette: palette,
            geometry: geometry,
            label: '$_visibleYear',
            showDisclosure: false,
            onPreviousPressed: () => setState(() => _visibleYear -= 1),
            onNextPressed: () => setState(() => _visibleYear += 1),
          ),
          SizedBox(height: context.designTokens.spacing.step4),
          for (var row = 0; row < 3; row++)
            Row(
              children: [
                for (var column = 0; column < 4; column++)
                  MonthButton(
                    palette: palette,
                    label: months[row * 4 + column],
                    selected:
                        _visibleYear == widget.visibleMonth.year &&
                        row * 4 + column + 1 == widget.selectedMonth,
                    onPressed: () {
                      final nextMonth = DateTime(
                        _visibleYear,
                        row * 4 + column + 1,
                      );
                      widget.onMonthPressed?.call(nextMonth);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

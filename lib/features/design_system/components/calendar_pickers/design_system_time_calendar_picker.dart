import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

part 'design_system_time_calendar_picker_components.dart';

part 'design_system_interactive_time_calendar_picker.dart';

enum DesignSystemTimeCalendarPickerMode { light, dark }

enum DesignSystemTimeCalendarPickerPresentation {
  regular,
  compact,
  monthDialog,
}

@immutable
class _TimeCalendarGeometry {
  const _TimeCalendarGeometry({
    required this.dialogInsetPadding,
    required this.compactWidth,
    required this.compactHeight,
    required this.cardWidth,
    required this.cardRadius,
    required this.cardShadowBlur,
    required this.cardShadowOffsetY,
    required this.contentPadding,
    required this.monthDialogPadding,
    required this.headerHeight,
    required this.sectionGap,
    required this.labelDisclosureGap,
    required this.labelTapRadius,
    required this.headerIconClusterWidth,
    required this.headerIconSize,
    required this.headerIconConstraint,
    required this.headerIconSplashRadius,
    required this.weekdayColumnWidth,
    required this.dayCellWidth,
    required this.dayCellHeight,
    required this.selectedDayDiameter,
    required this.selectedDayRadius,
    required this.monthButtonWidth,
    required this.monthButtonHeight,
    required this.monthButtonRadius,
  });

  factory _TimeCalendarGeometry.fromTokens(DsTokens tokens) {
    final cardRadius = tokens.radii.m + (tokens.spacing.step1 / 2);
    final cardWidth =
        (7 * tokens.spacing.step9) +
        (tokens.spacing.step5 * 2) +
        tokens.spacing.step1;

    return _TimeCalendarGeometry(
      dialogInsetPadding: EdgeInsets.all(tokens.spacing.step6),
      compactWidth: 288,
      compactHeight: 256,
      cardWidth: cardWidth,
      cardRadius: cardRadius,
      cardShadowBlur: 60,
      cardShadowOffsetY: 10,
      contentPadding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step4,
        tokens.spacing.step5,
        tokens.spacing.step4,
      ),
      monthDialogPadding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step4,
        tokens.spacing.step5,
        tokens.spacing.step5,
      ),
      headerHeight: tokens.spacing.step9,
      sectionGap: tokens.spacing.step3,
      labelDisclosureGap: tokens.spacing.step2,
      labelTapRadius: tokens.radii.badgesPills,
      headerIconClusterWidth: tokens.spacing.step10 + tokens.spacing.step2,
      headerIconSize: 28,
      headerIconConstraint: tokens.spacing.step9,
      headerIconSplashRadius: tokens.spacing.step6,
      weekdayColumnWidth: tokens.spacing.step9,
      dayCellWidth: tokens.spacing.step9,
      dayCellHeight: tokens.spacing.step9,
      selectedDayDiameter: tokens.spacing.step8,
      selectedDayRadius: tokens.spacing.step6 - tokens.spacing.step1,
      monthButtonWidth: (cardWidth - (tokens.spacing.step5 * 2)) / 4,
      monthButtonHeight: tokens.spacing.step11 - tokens.spacing.step1,
      monthButtonRadius: tokens.radii.l,
    );
  }

  final EdgeInsets dialogInsetPadding;
  final double compactWidth;
  final double compactHeight;
  final double cardWidth;
  final double cardRadius;
  final double cardShadowBlur;
  final double cardShadowOffsetY;
  final EdgeInsets contentPadding;
  final EdgeInsets monthDialogPadding;
  final double headerHeight;
  final double sectionGap;
  final double labelDisclosureGap;
  final double labelTapRadius;
  final double headerIconClusterWidth;
  final double headerIconSize;
  final double headerIconConstraint;
  final double headerIconSplashRadius;
  final double weekdayColumnWidth;
  final double dayCellWidth;
  final double dayCellHeight;
  final double selectedDayDiameter;
  final double selectedDayRadius;
  final double monthButtonWidth;
  final double monthButtonHeight;
  final double monthButtonRadius;
}

class DesignSystemTimeCalendarPicker extends StatelessWidget {
  const DesignSystemTimeCalendarPicker({
    required this.mode,
    required this.presentation,
    required this.visibleMonth,
    required this.selectedDate,
    required this.currentDate,
    this.onMonthYearPressed,
    this.onPreviousPressed,
    this.onNextPressed,
    this.onDayPressed,
    this.onMonthPressed,
    super.key,
  });

  final DesignSystemTimeCalendarPickerMode mode;
  final DesignSystemTimeCalendarPickerPresentation presentation;
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final DateTime currentDate;
  final VoidCallback? onMonthYearPressed;
  final VoidCallback? onPreviousPressed;
  final VoidCallback? onNextPressed;
  final ValueChanged<DateTime>? onDayPressed;
  final ValueChanged<DateTime>? onMonthPressed;

  @override
  Widget build(BuildContext context) {
    final geometry = _TimeCalendarGeometry.fromTokens(context.designTokens);

    switch (presentation) {
      case DesignSystemTimeCalendarPickerPresentation.regular:
        return _MonthCalendarCard(
          mode: mode,
          visibleMonth: visibleMonth,
          selectedDate: selectedDate,
          currentDate: currentDate,
          onMonthYearPressed: onMonthYearPressed,
          onPreviousPressed: onPreviousPressed,
          onNextPressed: onNextPressed,
          onDayPressed: onDayPressed,
        );
      case DesignSystemTimeCalendarPickerPresentation.compact:
        return SizedBox(
          width: geometry.compactWidth,
          height: geometry.compactHeight,
          child: FittedBox(
            alignment: Alignment.topLeft,
            fit: BoxFit.scaleDown,
            child: _MonthCalendarCard(
              mode: mode,
              visibleMonth: visibleMonth,
              selectedDate: selectedDate,
              currentDate: currentDate,
              onMonthYearPressed: onMonthYearPressed,
              onPreviousPressed: onPreviousPressed,
              onNextPressed: onNextPressed,
              onDayPressed: onDayPressed,
            ),
          ),
        );
      case DesignSystemTimeCalendarPickerPresentation.monthDialog:
        return _MonthSelectionDialogCard(
          mode: mode,
          visibleMonth: visibleMonth,
          selectedMonth: selectedDate.month,
          onMonthPressed: onMonthPressed,
        );
    }
  }
}

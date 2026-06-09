import 'package:flutter/material.dart';

/// A `builder` for [showDatePicker] / [showDateRangePicker] that makes the
/// picker's calendar start the week on [firstDayOfWeekIndex] (the device
/// region's first weekday, `0 = Sunday` … `6 = Saturday`).
///
/// Material pickers read the first day only from [MaterialLocalizations] and
/// expose no override. Among the app's supported UI languages only English
/// defaults to Sunday — de/fr/es/ro/cs already start on Monday — so the only
/// mismatch correctable without changing the displayed language is English →
/// its Monday variant (`en_GB`, whose picker labels are identical to `en_US`).
/// Any locale that already matches the desired first day is left untouched.
TransitionBuilder firstDayOfWeekPickerBuilder(int firstDayOfWeekIndex) {
  return (context, child) {
    final picker = child ?? const SizedBox.shrink();
    if (MaterialLocalizations.of(context).firstDayOfWeekIndex ==
        firstDayOfWeekIndex) {
      return picker;
    }
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    if (isEnglish && firstDayOfWeekIndex == DateTime.monday % 7) {
      return Localizations.override(
        context: context,
        locale: const Locale('en', 'GB'),
        child: picker,
      );
    }
    return picker;
  };
}

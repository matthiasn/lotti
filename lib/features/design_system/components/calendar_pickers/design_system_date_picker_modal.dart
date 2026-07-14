import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// The outcome of a design-system calendar modal.
@immutable
class DesignSystemDatePickerResult {
  const DesignSystemDatePickerResult.selected(this.date) : cleared = false;

  const DesignSystemDatePickerResult.cleared() : date = null, cleared = true;

  final DateTime? date;
  final bool cleared;
}

/// Opens the app-wide date-only picker.
///
/// The modal uses Material's accessible calendar engine, including weekday
/// headers and locale-aware month navigation, inside the app's token-backed
/// sheet chrome. A null result means the sheet was dismissed; [allowClear]
/// adds an explicit result that callers can distinguish from cancellation.
Future<DesignSystemDatePickerResult?> showDesignSystemDatePicker({
  required BuildContext context,
  required String title,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  bool allowClear = false,
}) async {
  final tokens = context.designTokens;
  final selectedDate = ValueNotifier(_dateOnly(initialDate));

  final result =
      await ModalUtils.showSinglePageModal<DesignSystemDatePickerResult>(
        context: context,
        title: title,
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.step5,
          tokens.spacing.step5,
          tokens.spacing.step5,
          tokens.spacing.step11 + tokens.spacing.step6,
        ),
        builder: (_) => ValueListenableBuilder(
          valueListenable: selectedDate,
          builder: (context, date, _) => DesignSystemCalendarPicker(
            selectedDate: date,
            firstDate: firstDate,
            lastDate: lastDate,
            onDateChanged: (value) => selectedDate.value = value,
          ),
        ),
        stickyActionBarBuilder: (modalContext) => ValueListenableBuilder(
          valueListenable: selectedDate,
          builder: (context, date, _) => DesignSystemDatePickerActionBar(
            onClear: allowClear
                ? () => Navigator.of(
                    modalContext,
                  ).pop(const DesignSystemDatePickerResult.cleared())
                : null,
            onDone: () => Navigator.of(
              modalContext,
            ).pop(DesignSystemDatePickerResult.selected(date)),
          ),
        ),
      );

  selectedDate.dispose();
  return result;
}

/// The token-backed calendar content shared by standalone and multi-page
/// date-picking sheets.
class DesignSystemCalendarPicker extends StatelessWidget {
  const DesignSystemCalendarPicker({
    required this.selectedDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateChanged,
    super.key,
  });

  final DateTime selectedDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SelectedDateHeader(
              date: selectedDate,
              onTodayPressed:
                  _isToday(selectedDate) || !_containsToday(firstDate, lastDate)
                  ? null
                  : () => onDateChanged(_today()),
            ),
            SizedBox(height: tokens.spacing.step3),
            DatePickerTheme(
              data: DatePickerTheme.of(context).copyWith(
                toggleButtonTextStyle: tokens
                    .typography
                    .styles
                    .subtitle
                    .subtitle1
                    .copyWith(color: tokens.colors.text.highEmphasis),
              ),
              child: CalendarDatePicker(
                key: ValueKey(selectedDate),
                initialDate: selectedDate,
                currentDate: _today(),
                firstDate: firstDate,
                lastDate: lastDate,
                onDateChanged: (value) => onDateChanged(_dateOnly(value)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDateHeader extends StatelessWidget {
  const _SelectedDateHeader({required this.date, this.onTodayPressed});

  final DateTime date;
  final VoidCallback? onTodayPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Row(
      children: [
        Expanded(
          child: Text(
            DateFormat.yMMMMEEEEd(locale).format(date),
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        DesignSystemButton(
          label: context.messages.journalTodayButton,
          variant: DesignSystemButtonVariant.tertiary,
          size: DesignSystemButtonSize.medium,
          onPressed: onTodayPressed,
        ),
      ],
    );
  }
}

/// Calendar footer shared by standalone and embedded date-picker pages.
class DesignSystemDatePickerActionBar extends StatelessWidget {
  const DesignSystemDatePickerActionBar({
    required this.onClear,
    required this.onDone,
    super.key,
  });

  final VoidCallback? onClear;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemModalActionBar(
      glass: true,
      padding: EdgeInsets.all(tokens.spacing.step5),
      secondary: [
        if (onClear != null)
          DesignSystemButton(
            label: context.messages.clearButton,
            variant: DesignSystemButtonVariant.secondary,
            size: DesignSystemButtonSize.large,
            onPressed: onClear,
          ),
      ],
      primary: DesignSystemButton(
        label: context.messages.doneButton,
        leadingIcon: Icons.check_rounded,
        size: DesignSystemButtonSize.large,
        fullWidth: true,
        onPressed: onDone,
      ),
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _today() => _dateOnly(clock.now());

bool _containsToday(DateTime firstDate, DateTime lastDate) {
  final today = _today();
  return !today.isBefore(_dateOnly(firstDate)) &&
      !today.isAfter(_dateOnly(lastDate));
}

bool _isToday(DateTime date) => _sameDate(date, _today());

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_range.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_status_bar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class EntryDateTimeMultiPageModal {
  static Future<void> show({
    required BuildContext context,
    required JournalEntity entry,
  }) async {
    final tokens = context.designTokens;
    final stateNotifier = ValueNotifier(
      EntryDateTimeRange.fromBounds(entry.meta.dateFrom, entry.meta.dateTo),
    );
    final pageIndexNotifier = ValueNotifier(0);
    final activeDateEndpoint = ValueNotifier(_DateEndpoint.start);

    try {
      await ModalUtils.showMultiPageModal<void>(
        context: context,
        pageIndexNotifier: pageIndexNotifier,
        modalTypeBuilderOverride: _modalTypeBuilder,
        pageListBuilder: (modalContext) => [
          ModalUtils.modalSheetPage(
            context: modalContext,
            titleWidget: _modalTitle(modalContext),
            showCloseButton: true,
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step3,
              tokens.spacing.step5,
              DesignSystemGlassActionFooter.reservedHeight,
            ),
            stickyActionBar: _SaveActionBar(
              entry: entry,
              stateNotifier: stateNotifier,
            ),
            child: _EntryDateTimeEditor(
              stateNotifier,
              onPickStartDate: () {
                activeDateEndpoint.value = _DateEndpoint.start;
                pageIndexNotifier.value = 1;
              },
              onPickEndDate: () {
                activeDateEndpoint.value = _DateEndpoint.end;
                pageIndexNotifier.value = 1;
              },
            ),
          ),
          ModalUtils.modalSheetPage(
            context: modalContext,
            titleWidget: ValueListenableBuilder<_DateEndpoint>(
              valueListenable: activeDateEndpoint,
              builder: (context, endpoint, _) => Text(
                switch (endpoint) {
                  _DateEndpoint.start => context.messages.journalStartDateLabel,
                  _DateEndpoint.end => context.messages.journalEndDateLabel,
                },
                style: ModalUtils.modalTitleStyle(context),
              ),
            ),
            showCloseButton: true,
            onTapBack: () => pageIndexNotifier.value = 0,
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step5,
              tokens.spacing.step5,
              tokens.spacing.step11 + tokens.spacing.step6,
            ),
            stickyActionBar: DesignSystemDatePickerActionBar(
              onClear: null,
              onDone: () => pageIndexNotifier.value = 0,
            ),
            child: _EntryDateCalendarPage(
              stateNotifier: stateNotifier,
              activeEndpoint: activeDateEndpoint,
            ),
          ),
        ],
      );
    } finally {
      stateNotifier.dispose();
      pageIndexNotifier.dispose();
      activeDateEndpoint.dispose();
    }
  }

  static Widget _modalTitle(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          MdiIcons.calendarClock,
          size: tokens.spacing.step6,
          color: tokens.colors.interactive.enabled,
        ),
        SizedBox(width: tokens.spacing.step3),
        Text(
          context.messages.journalDateTimeRangeTitle,
          style: ModalUtils.modalTitleStyle(context),
        ),
      ],
    );
  }
}

enum _DateEndpoint { start, end }

WoltModalType _modalTypeBuilder(BuildContext context) {
  if (ModalUtils.shouldUseRootNavigatorForBottomSheet(context)) {
    return WoltModalType.bottomSheet();
  }
  return const _EntryDateTimeDialogType();
}

/// Uses the screen space available to this dense editor instead of the
/// standard Wolt dialog's 80% height cap.
class _EntryDateTimeDialogType extends WoltDialogType {
  const _EntryDateTimeDialogType();

  @override
  BoxConstraints layoutModal(Size availableSize) {
    final base = super.layoutModal(availableSize);
    final maxHeight = (availableSize.height - WoltDialogType.minPadding).clamp(
      base.minHeight,
      availableSize.height,
    );
    return base.copyWith(maxHeight: maxHeight);
  }
}

class _EntryDateTimeEditor extends StatefulWidget {
  const _EntryDateTimeEditor(
    this.stateNotifier, {
    required this.onPickStartDate,
    required this.onPickEndDate,
  });

  final ValueNotifier<EntryDateTimeRange> stateNotifier;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;

  @override
  State<_EntryDateTimeEditor> createState() => _EntryDateTimeEditorState();
}

class _EntryDateTimeEditorState extends State<_EntryDateTimeEditor> {
  var _startTimeSeed = 0;
  var _endTimeSeed = 0;

  EntryDateTimeRange get _state => widget.stateNotifier.value;
  set _state(EntryDateTimeRange value) => widget.stateNotifier.value = value;

  @override
  void initState() {
    super.initState();
    widget.stateNotifier.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.stateNotifier.removeListener(_onStateChanged);
    super.dispose();
  }

  /// Rebuilds the draft readout while stateful fixed-extent wheels retain their
  /// scroll positions across range changes.
  void _onStateChanged() {
    setState(() {});
  }

  void _toggleDifferentDates({required bool value}) {
    if (value) {
      // Freeze the current effective end day so the reveal seeds to the right
      // date (start + 1 for an overnight, otherwise the start day).
      _state = _state.copyWith(
        differentDates: true,
        endDateOverride: _state.dateTo,
      );
    } else {
      _state = _state.copyWith(differentDates: false, clearOverride: true);
    }
  }

  void _setStartNow() {
    _startTimeSeed += 1;
    _state = _state.withStart(_nowInZoneOf(_state.dateFrom));
  }

  void _setEndNow() {
    _endTimeSeed += 1;
    _state = _state.withEnd(_nowInZoneOf(_state.dateTo));
  }

  void _setStartDateToday() {
    final today = _nowInZoneOf(_state.startDate).dateOnly;
    _state = _state.copyWith(startDate: today);
  }

  void _setEndDateToday() {
    final reference = _state.endDateOverride ?? _state.startDate;
    final today = _nowInZoneOf(reference).dateOnly;
    _state = _state.copyWith(endDateOverride: today);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final state = _state;
    final compact = state.differentDates;
    final stackTimes = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final timeColumns = <Widget>[
      _TimeColumn(
        label: context.messages.journalStartTimeLabel,
        initial: state.startTime,
        wheelSeed: _startTimeSeed,
        nowSemanticsLabel: context.messages.journalSetStartDateTimeNowSemantic,
        onNow: _setStartNow,
        onChanged: (time) => _state = _state.copyWith(startTime: time),
      ),
      _TimeColumn(
        label: context.messages.journalEndTimeLabel,
        initial: state.endTime,
        wheelSeed: _endTimeSeed,
        nowSemanticsLabel: context.messages.journalSetEndDateTimeNowSemantic,
        onNow: _setEndNow,
        onChanged: (time) => _state = _state.copyWith(endTime: time),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignSystemPickerSection(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Caption(
                label: compact
                    ? context.messages.journalStartDateLabel
                    : context.messages.journalDateLabel,
                trailing: _QuickAction(
                  label: context.messages.journalTodayButton,
                  semanticsLabel:
                      '${compact ? context.messages.journalStartDateLabel : context.messages.journalDateLabel}, '
                      '${context.messages.journalTodayButton}',
                  onPressed: _isToday(state.startDate)
                      ? null
                      : _setStartDateToday,
                ),
              ),
              _DateSelectionButton(
                date: state.startDate,
                onPressed: widget.onPickStartDate,
              ),
              SizedBox(height: tokens.spacing.step3),
              Divider(height: 1, color: tokens.colors.decorative.level01),
              SizedBox(height: tokens.spacing.step3),
              DesignSystemToggle(
                value: state.differentDates,
                label: context.messages.journalEndsAnotherDayHint,
                onChanged: (value) => _toggleDifferentDates(value: value),
              ),
              if (compact) ...[
                SizedBox(height: tokens.spacing.step6),
                _Caption(
                  label: context.messages.journalEndDateLabel,
                  trailing: _QuickAction(
                    label: context.messages.journalTodayButton,
                    semanticsLabel:
                        '${context.messages.journalEndDateLabel}, '
                        '${context.messages.journalTodayButton}',
                    onPressed:
                        _isToday(
                          state.endDateOverride ?? state.startDate,
                        )
                        ? null
                        : _setEndDateToday,
                  ),
                ),
                _DateSelectionButton(
                  date: state.endDateOverride ?? state.startDate,
                  onPressed: widget.onPickEndDate,
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.step6),
        DesignSystemPickerSection(
          child: stackTimes
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    timeColumns.first,
                    SizedBox(height: tokens.spacing.sectionGap),
                    timeColumns.last,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: timeColumns.first),
                    SizedBox(width: tokens.spacing.step3),
                    Expanded(child: timeColumns.last),
                  ],
                ),
        ),
        SizedBox(height: tokens.spacing.step6),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.cardPadding),
          child: EntryDateTimeStatusBar(range: state),
        ),
      ],
    );
  }
}

class _EntryDateCalendarPage extends StatelessWidget {
  const _EntryDateCalendarPage({
    required this.stateNotifier,
    required this.activeEndpoint,
  });

  final ValueNotifier<EntryDateTimeRange> stateNotifier;
  final ValueNotifier<_DateEndpoint> activeEndpoint;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_DateEndpoint>(
      valueListenable: activeEndpoint,
      builder: (context, endpoint, _) {
        return ValueListenableBuilder<EntryDateTimeRange>(
          valueListenable: stateNotifier,
          builder: (context, state, _) {
            final selectedDate = switch (endpoint) {
              _DateEndpoint.start => state.startDate,
              _DateEndpoint.end => state.endDateOverride ?? state.startDate,
            };
            return DesignSystemCalendarPicker(
              selectedDate: selectedDate,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              onDateChanged: (date) {
                stateNotifier.value = switch (endpoint) {
                  _DateEndpoint.start => state.copyWith(startDate: date),
                  _DateEndpoint.end => state.copyWith(endDateOverride: date),
                };
              },
            );
          },
        );
      },
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
          if (trailing != null) SizedBox(width: tokens.spacing.step2),
          ?trailing,
        ],
      ),
    );
  }
}

/// Full localized date button that opens the calendar page in this sheet.
class _DateSelectionButton extends StatelessWidget {
  const _DateSelectionButton({required this.date, required this.onPressed});

  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DesignSystemButton(
      label: _formatFullDate(context, date),
      leadingIcon: Icons.calendar_month_rounded,
      variant: DesignSystemButtonVariant.secondary,
      size: DesignSystemButtonSize.large,
      fullWidth: true,
      onPressed: onPressed,
    );
  }
}

String _formatFullDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMMEEEEd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(date);

/// Text-first shortcut with a full-size design-system button hit target.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DesignSystemButton(
      label: label,
      semanticsLabel: semanticsLabel,
      variant: DesignSystemButtonVariant.tertiary,
      size: DesignSystemButtonSize.medium,
      onPressed: onPressed,
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({
    required this.label,
    required this.initial,
    required this.wheelSeed,
    required this.nowSemanticsLabel,
    required this.onNow,
    required this.onChanged,
  });

  final String label;
  final TimeOfDay initial;
  final int wheelSeed;
  final String nowSemanticsLabel;
  final VoidCallback onNow;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Caption(
          label: label,
          trailing: _QuickAction(
            label: context.messages.journalDateNowButton,
            semanticsLabel: nowSemanticsLabel,
            onPressed: onNow,
          ),
        ),
        DesignSystemTimeWheel(
          key: ValueKey('time-wheel-$wheelSeed'),
          initialDateTime: DateTime(
            2020,
            1,
            1,
            initial.hour,
            initial.minute,
          ),
          use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          semanticsLabel: label,
          onDateTimeChanged: (dateTime) => onChanged(
            TimeOfDay(hour: dateTime.hour, minute: dateTime.minute),
          ),
        ),
      ],
    );
  }
}

DateTime _nowInZoneOf(DateTime reference) {
  final now = clock.now();
  return reference.isUtc ? now.toUtc() : now.toLocal();
}

bool _isToday(DateTime date) => date.isSameCalendarDay(_nowInZoneOf(date));

class _SaveActionBar extends ConsumerWidget {
  const _SaveActionBar({required this.entry, required this.stateNotifier});

  final JournalEntity entry;
  final ValueNotifier<EntryDateTimeRange> stateNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(entry.meta.id);

    return ValueListenableBuilder<EntryDateTimeRange>(
      valueListenable: stateNotifier,
      builder: (context, state, _) {
        final changed =
            state.dateFrom != entry.meta.dateFrom ||
            state.dateTo != entry.meta.dateTo;
        final canSave = state.valid && changed;

        return DesignSystemGlassActionFooter(
          child: DesignSystemButton(
            label: context.messages.journalDateSaveButton,
            leadingIcon: Icons.check_rounded,
            size: DesignSystemButtonSize.large,
            fullWidth: true,
            onPressed: canSave
                ? () async {
                    try {
                      await ref
                          .read(provider.notifier)
                          .updateFromTo(
                            dateFrom: state.dateFrom,
                            dateTo: state.dateTo,
                          );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      DevLogger.warning(
                        name: 'EntryDateTimeMultiPageModal',
                        message: 'Error updating date range: $e',
                      );
                    }
                  }
                : null,
          ),
        );
      },
    );
  }
}

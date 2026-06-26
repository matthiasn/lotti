import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_range.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_status_bar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class EntryDateTimeMultiPageModal {
  static Future<void> show({
    required BuildContext context,
    required JournalEntity entry,
  }) async {
    final stateNotifier = ValueNotifier(
      EntryDateTimeRange.fromBounds(entry.meta.dateFrom, entry.meta.dateTo),
    );

    await ModalUtils.showSinglePageModal<void>(
      context: context,
      titleWidget: Builder(
        builder: (context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MdiIcons.calendarClock,
              size: 22,
              color: context.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Text(
              context.messages.journalDateTimeRangeTitle,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      navBarHeight: 65,
      builder: (modalContext) => _EntryDateTimeEditor(stateNotifier),
      stickyActionBarBuilder: (modalContext) =>
          _SaveActionBar(entry: entry, stateNotifier: stateNotifier),
    );

    stateNotifier.dispose();
  }
}

class _EntryDateTimeEditor extends StatefulWidget {
  const _EntryDateTimeEditor(this.stateNotifier);

  final ValueNotifier<EntryDateTimeRange> stateNotifier;

  @override
  State<_EntryDateTimeEditor> createState() => _EntryDateTimeEditorState();
}

class _EntryDateTimeEditorState extends State<_EntryDateTimeEditor> {
  late bool _differentDates;

  EntryDateTimeRange get _state => widget.stateNotifier.value;
  set _state(EntryDateTimeRange value) => widget.stateNotifier.value = value;

  @override
  void initState() {
    super.initState();
    _differentDates = _state.differentDates;
    widget.stateNotifier.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.stateNotifier.removeListener(_onStateChanged);
    super.dispose();
  }

  /// Only the mode flip changes the *layout* (and therefore which wheels exist),
  /// so only that triggers a rebuild. Time/date spins update the shared state
  /// for the live readouts without rebuilding — otherwise the uncontrolled
  /// Cupertino wheels would jump back to their initial position on every tick.
  void _onStateChanged() {
    if (_state.differentDates != _differentDates) {
      setState(() => _differentDates = _state.differentDates);
    }
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final state = _state;
    // In different-dates mode two date wheels coexist with the time wheels, so
    // every wheel shrinks to keep the duration + toggle above the sticky bar.
    final compact = state.differentDates;
    final dateHeight = compact ? 148.0 : 180.0;
    final timeHeight = compact ? 132.0 : 160.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Caption(
            emphasized: true,
            label: compact
                ? context.messages.journalStartDateLabel
                : context.messages.journalDateLabel,
            trailing: _TodayPill(
              onTap: () {
                final now = DateTime.now();
                _state = _state.copyWith(
                  startDate: DateTime(now.year, now.month, now.day),
                );
                setState(() {}); // re-seed the date wheel to today
              },
            ),
          ),
          _DateWheel(
            key: ValueKey('start-date-${state.startDate}'),
            height: dateHeight,
            initial: state.startDate,
            onChanged: (date) =>
                _state = _state.copyWith(startDate: _dateOnly(date)),
          ),
          SizedBox(height: tokens.spacing.step4),
          // The toggle sits high — right under the (start) date wheel and where
          // its revealed End date appears — so the control that drives the mode
          // is always on screen, never occluded by the pinned bar.
          DesignSystemToggle(
            value: state.differentDates,
            label: context.messages.journalEndsAnotherDayLabel,
            onChanged: (value) => _toggleDifferentDates(value: value),
          ),
          if (!compact)
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step2),
              child: Text(
                context.messages.journalEndsAnotherDayHint,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (compact) ...[
            SizedBox(height: tokens.spacing.step4),
            _Caption(
              emphasized: true,
              label: context.messages.journalEndDateLabel,
            ),
            _DateWheel(
              key: ValueKey('end-date-${state.endDateOverride}'),
              height: dateHeight,
              initial: state.endDateOverride ?? state.startDate,
              onChanged: (date) =>
                  _state = _state.copyWith(endDateOverride: _dateOnly(date)),
            ),
          ],
          // A deliberate section gap separates the date block from the time
          // block (mirrors the same-day rhythm even when stacked in multi-day).
          SizedBox(height: tokens.spacing.step6),
          // Start/end times stay paired side by side in both modes — the
          // standout density + "same range" clarity win from round 1.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TimeColumn(
                  label: context.messages.journalStartTimeLabel,
                  height: timeHeight,
                  initial: state.startTime,
                  onChanged: (time) =>
                      _state = _state.copyWith(startTime: time),
                ),
              ),
              SizedBox(width: tokens.spacing.step4),
              Expanded(
                child: _TimeColumn(
                  label: context.messages.journalEndTimeLabel,
                  height: timeHeight,
                  initial: state.endTime,
                  onChanged: (time) => _state = _state.copyWith(endTime: time),
                ),
              ),
            ],
          ),
          // Keep content clear of the glass status + Save bar.
          const SizedBox(height: 124),
        ],
      ),
    );
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class _Caption extends StatelessWidget {
  const _Caption({
    required this.label,
    this.trailing,
    this.emphasized = false,
  });

  final String label;
  final Widget? trailing;

  /// Primary captions (the date sections) read a step heavier than the
  /// secondary time captions, reinforcing the "one date contains the times"
  /// containment the design relies on.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final style = emphasized
        ? context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colorScheme.onSurface,
          )
        : context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          );
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _TodayPill extends StatelessWidget {
  const _TodayPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A neutral grey pill (high-emphasis white tinted at 18%) — visibly filled
    // above the sheet background and distinct from the teal overnight chip, so
    // the two capsules read as one family differentiated by meaning.
    return DsPill(
      variant: DsPillVariant.tinted,
      color: context.designTokens.colors.text.highEmphasis,
      label: context.messages.journalTodayButton,
      onTap: onTap,
    );
  }
}

class _DateWheel extends StatelessWidget {
  const _DateWheel({
    required this.height,
    required this.initial,
    required this.onChanged,
    super.key,
  });

  final double height;
  final DateTime initial;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CupertinoTheme(
        data: CupertinoThemeData(
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: context.textTheme.titleMedium,
          ),
        ),
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: initial,
          onDateTimeChanged: onChanged,
        ),
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({
    required this.label,
    required this.height,
    required this.initial,
    required this.onChanged,
  });

  final String label;
  final double height;
  final TimeOfDay initial;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Caption(label: label),
        SizedBox(
          height: height,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle:
                    context.textTheme.titleLarge?.withTabularFigures,
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              initialDateTime: DateTime(
                2020,
                1,
                1,
                initial.hour,
                initial.minute,
              ),
              onDateTimeChanged: (dateTime) => onChanged(
                TimeOfDay(hour: dateTime.hour, minute: dateTime.minute),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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

        return DesignSystemGlassStrip(
          child: Padding(
            padding: EdgeInsets.all(context.designTokens.spacing.step5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EntryDateTimeStatusBar(range: state),
                SizedBox(height: context.designTokens.spacing.step4),
                DesignSystemButton(
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
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

enum DateTimeFieldType { from, to }

class EntryDateTimeMultiPageModal {
  static Future<void> show({
    required BuildContext context,
    required JournalEntity entry,
  }) async {
    final dateFromNotifier = ValueNotifier(entry.meta.dateFrom);
    final dateToNotifier = ValueNotifier(entry.meta.dateTo);
    final pageIndexNotifier = ValueNotifier(0);
    final selectedFieldNotifier = ValueNotifier<DateTimeFieldType?>(null);

    await ModalUtils.showMultiPageModal<void>(
      context: context,
      pageIndexNotifier: pageIndexNotifier,
      pageListBuilder: (modalContext) {
        return [
          // Page 0: Date range selection
          ModalUtils.modalSheetPage(
            context: modalContext,
            titleWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  MdiIcons.calendarRange,
                  size: 22,
                  color: modalContext.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Date & Time Range',
                  style: modalContext.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            navBarHeight: 65,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: _DateRangeSelectionPage(
                entry: entry,
                dateFromNotifier: dateFromNotifier,
                dateToNotifier: dateToNotifier,
                onFieldTapped: (fieldType) {
                  selectedFieldNotifier.value = fieldType;
                  pageIndexNotifier.value = 1;
                },
              ),
            ),
            stickyActionBar: _DateTimeRangeStickyActionBar(
              entry: entry,
              dateFromNotifier: dateFromNotifier,
              dateToNotifier: dateToNotifier,
            ),
          ),
          // Page 1: Date/time picker
          ModalUtils.modalSheetPage(
            context: modalContext,
            onTapBack: () => pageIndexNotifier.value = 0,
            title: '',
            titleWidget: ValueListenableBuilder<DateTimeFieldType?>(
              valueListenable: selectedFieldNotifier,
              builder: (context, selectedField, _) {
                final label = selectedField == DateTimeFieldType.from
                    ? context.messages.journalDateFromLabel
                    : context.messages.journalDateToLabel;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      MdiIcons.clockEdit,
                      size: 22,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
            navBarHeight: 65,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: _DateTimePickerPage(
                dateFromNotifier: dateFromNotifier,
                dateToNotifier: dateToNotifier,
                selectedFieldNotifier: selectedFieldNotifier,
              ),
            ),
            stickyActionBar: _DateTimePickerStickyActionBar(
              dateFromNotifier: dateFromNotifier,
              dateToNotifier: dateToNotifier,
              selectedFieldNotifier: selectedFieldNotifier,
              onCancel: () => pageIndexNotifier.value = 0,
              onDone: () => pageIndexNotifier.value = 0,
              onNow: () {
                final selectedField = selectedFieldNotifier.value;
                final now = DateTime.now();
                if (selectedField == DateTimeFieldType.from) {
                  dateFromNotifier.value = now;
                } else if (selectedField == DateTimeFieldType.to) {
                  dateToNotifier.value = now;
                }
                pageIndexNotifier.value = 0;
              },
            ),
          ),
        ];
      },
    );

    dateFromNotifier.dispose();
    dateToNotifier.dispose();
    pageIndexNotifier.dispose();
    selectedFieldNotifier.dispose();
  }
}

class _DateRangeSelectionPage extends ConsumerWidget {
  const _DateRangeSelectionPage({
    required this.entry,
    required this.dateFromNotifier,
    required this.dateToNotifier,
    required this.onFieldTapped,
  });

  final JournalEntity entry;
  final ValueNotifier<DateTime> dateFromNotifier;
  final ValueNotifier<DateTime> dateToNotifier;
  final void Function(DateTimeFieldType) onFieldTapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryId = entry.meta.id;
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;
    final liveEntity = entryState?.entry;

    if (liveEntity == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<DateTime>(
      valueListenable: dateFromNotifier,
      builder: (context, dateFrom, _) {
        return ValueListenableBuilder<DateTime>(
          valueListenable: dateToNotifier,
          builder: (context, dateTo, _) {
            final valid = dateTo.isAfter(dateFrom) || dateTo == dateFrom;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Date range selection
                Row(
                  children: [
                    Expanded(
                      child: _TappableDateTimeField(
                        dateTime: dateFrom,
                        labelText: context.messages.journalDateFromLabel,
                        onTap: () => onFieldTapped(DateTimeFieldType.from),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _TappableDateTimeField(
                        dateTime: dateTo,
                        labelText: context.messages.journalDateToLabel,
                        onTap: () => onFieldTapped(DateTimeFieldType.to),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Duration display
                Row(
                  children: [
                    Icon(
                      MdiIcons.clockTimeFour,
                      size: 20,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.messages.journalDurationLabel,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatDuration(dateFrom.difference(dateTo).abs()),
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colorScheme.primary,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (!valid) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colorScheme.errorContainer
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.colorScheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          size: 20,
                          color: context.colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.messages.journalDateInvalid,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Add bottom padding to ensure content isn't hidden by sticky action bar
                const SizedBox(height: 80),
              ],
            );
          },
        );
      },
    );
  }
}

class _TappableDateTimeField extends StatelessWidget {
  const _TappableDateTimeField({
    required this.dateTime,
    required this.labelText,
    required this.onTap,
  });

  final DateTime dateTime;
  final String labelText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.titleMedium;

    return TextField(
      decoration: createDialogInputDecoration(
        labelText: labelText,
        style: style,
        themeData: Theme.of(context),
      ).copyWith(
        suffixIcon: Icon(
          Icons.edit_calendar_rounded,
          color: context.colorScheme.primary,
        ),
      ),
      style: style,
      readOnly: true,
      controller: TextEditingController(
        text: dfShorter.format(dateTime),
      ),
      onTap: onTap,
    );
  }
}

class _DateTimePickerPage extends StatelessWidget {
  const _DateTimePickerPage({
    required this.dateFromNotifier,
    required this.dateToNotifier,
    required this.selectedFieldNotifier,
  });

  final ValueNotifier<DateTime> dateFromNotifier;
  final ValueNotifier<DateTime> dateToNotifier;
  final ValueNotifier<DateTimeFieldType?> selectedFieldNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTimeFieldType?>(
      valueListenable: selectedFieldNotifier,
      builder: (context, selectedField, _) {
        if (selectedField == null) {
          return const SizedBox.shrink();
        }

        final initialDateTime = selectedField == DateTimeFieldType.from
            ? dateFromNotifier.value
            : dateToNotifier.value;

        return CupertinoTheme(
          data: CupertinoThemeData(
            textTheme: CupertinoTextThemeData(
              dateTimePickerTextStyle:
                  context.textTheme.titleLarge?.withTabularFigures,
            ),
          ),
          child: SizedBox(
            height: 265,
            child: CupertinoDatePicker(
              initialDateTime: initialDateTime,
              use24hFormat: true,
              onDateTimeChanged: (dateTime) {
                if (selectedField == DateTimeFieldType.from) {
                  dateFromNotifier.value = dateTime;
                } else {
                  dateToNotifier.value = dateTime;
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class _DateTimeRangeStickyActionBar extends ConsumerWidget {
  const _DateTimeRangeStickyActionBar({
    required this.entry,
    required this.dateFromNotifier,
    required this.dateToNotifier,
  });

  final JournalEntity entry;
  final ValueNotifier<DateTime> dateFromNotifier;
  final ValueNotifier<DateTime> dateToNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryId = entry.meta.id;
    final provider = entryControllerProvider(id: entryId);

    return ValueListenableBuilder<DateTime>(
      valueListenable: dateFromNotifier,
      builder: (context, dateFrom, _) {
        return ValueListenableBuilder<DateTime>(
          valueListenable: dateToNotifier,
          builder: (context, dateTo, _) {
            final valid = dateTo.isAfter(dateFrom) || dateTo == dateFrom;
            final changed =
                dateFrom != entry.meta.dateFrom || dateTo != entry.meta.dateTo;

            return Container(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: valid && changed
                      ? () async {
                          try {
                            await ref.read(provider.notifier).updateFromTo(
                                  dateFrom: dateFrom,
                                  dateTo: dateTo,
                                );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          } catch (e) {
                            debugPrint('Error updating date range: $e');
                          }
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colorScheme.primary,
                    foregroundColor: context.colorScheme.onPrimary,
                    disabledBackgroundColor:
                        context.colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: valid && changed
                            ? context.colorScheme.onPrimary
                            : context.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.messages.journalDateSaveButton,
                        style: context.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DateTimePickerStickyActionBar extends StatelessWidget {
  const _DateTimePickerStickyActionBar({
    required this.dateFromNotifier,
    required this.dateToNotifier,
    required this.selectedFieldNotifier,
    required this.onCancel,
    required this.onDone,
    required this.onNow,
  });

  final ValueNotifier<DateTime> dateFromNotifier;
  final ValueNotifier<DateTime> dateToNotifier;
  final ValueNotifier<DateTimeFieldType?> selectedFieldNotifier;
  final VoidCallback onCancel;
  final VoidCallback onDone;
  final VoidCallback onNow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: context.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                context.messages.cancelButton,
                style: TextStyle(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: onNow,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: context.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                context.messages.journalDateNowButton,
                style: TextStyle(
                  color: context.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(context.messages.doneButton),
            ),
          ),
        ],
      ),
    );
  }
}

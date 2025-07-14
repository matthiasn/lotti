import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class EntryDateTimeModal {
  static Future<void> show({
    required BuildContext context,
    required JournalEntity entry,
  }) async {
    final dateFromNotifier = ValueNotifier(entry.meta.dateFrom);
    final dateToNotifier = ValueNotifier(entry.meta.dateTo);

    await ModalUtils.showSinglePageModal<void>(
      context: context,
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            MdiIcons.calendarRange,
            size: 22,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Text(
            'Date & Time Range',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      navBarHeight: 65,
      builder: (BuildContext modalContext) {
        return EntryDateTimeModalContent(
          item: entry,
          dateFromNotifier: dateFromNotifier,
          dateToNotifier: dateToNotifier,
        );
      },
      stickyActionBar: _DateTimeRangeStickyActionBar(
        entry: entry,
        dateFromNotifier: dateFromNotifier,
        dateToNotifier: dateToNotifier,
      ),
    );

    dateFromNotifier.dispose();
    dateToNotifier.dispose();
  }
}

class EntryDateTimeModalContent extends ConsumerWidget {
  const EntryDateTimeModalContent({
    required this.item,
    required this.dateFromNotifier,
    required this.dateToNotifier,
    super.key,
  });

  final JournalEntity item;
  final ValueNotifier<DateTime> dateFromNotifier;
  final ValueNotifier<DateTime> dateToNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryId = item.meta.id;
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
                      child: DateTimeField(
                        dateTime: dateFrom,
                        labelText: context.messages.journalDateFromLabel,
                        setDateTime: (picked) {
                          dateFromNotifier.value = picked;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DateTimeField(
                        dateTime: dateTo,
                        labelText: context.messages.journalDateToLabel,
                        setDateTime: (picked) {
                          dateToNotifier.value = picked;
                        },
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

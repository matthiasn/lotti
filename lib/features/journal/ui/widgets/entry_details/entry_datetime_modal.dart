import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';

class EntryDateTimeModal extends ConsumerStatefulWidget {
  const EntryDateTimeModal({
    required this.item,
    super.key,
    this.readOnly = false,
  });

  final JournalEntity item;
  final bool readOnly;

  @override
  ConsumerState<EntryDateTimeModal> createState() => _EntryDateTimeModalState();
}

class _EntryDateTimeModalState extends ConsumerState<EntryDateTimeModal> {
  late DateTime dateFrom;
  late DateTime dateTo;

  @override
  void initState() {
    super.initState();
    dateFrom = widget.item.meta.dateFrom;
    dateTo = widget.item.meta.dateTo;
  }

  @override
  Widget build(BuildContext _) {
    final entryId = widget.item.meta.id;
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;
    final liveEntity = entryState?.entry;

    final valid = dateTo.isAfter(dateFrom) || dateTo == dateFrom;
    final changed = dateFrom != widget.item.meta.dateFrom ||
        dateTo != widget.item.meta.dateTo;

    void pop() => Navigator.pop(context);

    if (liveEntity == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IntrinsicWidth(
              child: DateTimeField(
                dateTime: dateFrom,
                labelText: context.messages.journalDateFromLabel,
                setDateTime: (picked) {
                  setState(() {
                    dateFrom = picked;
                  });
                },
              ),
            ),
            IntrinsicWidth(
              child: DateTimeField(
                dateTime: dateTo,
                labelText: context.messages.journalDateToLabel,
                setDateTime: (picked) {
                  setState(() {
                    dateTo = picked;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              context.messages.journalDurationLabel,
              textAlign: TextAlign.end,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                formatDuration(dateFrom.difference(dateTo).abs()),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Visibility(
                visible: valid && changed,
                child: TextButton(
                  onPressed: () async {
                    await ref.read(provider.notifier).updateFromTo(
                          dateFrom: dateFrom,
                          dateTo: dateTo,
                        );
                    pop();
                  },
                  child: Text(
                    context.messages.journalDateSaveButton,
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              Visibility(
                visible: !valid,
                child: Text(
                  context.messages.journalDateInvalid,
                  style: TextStyle(
                    color: context.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

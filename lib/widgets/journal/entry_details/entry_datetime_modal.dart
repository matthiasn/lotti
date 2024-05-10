import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

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
    final valid = dateTo.isAfter(dateFrom) || dateTo == dateFrom;
    final changed = dateFrom != widget.item.meta.dateFrom ||
        dateTo != widget.item.meta.dateTo;

    void pop() {
      Navigator.pop(context);
    }

    return BlocBuilder<EntryCubit, EntryState>(
      builder: (
        _,
        EntryState state,
      ) {
        final cubit = context.read<EntryCubit>();
        final liveEntity = state.entry;

        if (liveEntity == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 20),
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
                          await cubit.updateFromTo(
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
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

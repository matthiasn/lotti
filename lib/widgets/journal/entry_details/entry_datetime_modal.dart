import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/misc/datetime_bottom_sheet.dart';

class EntryDateTimeModal extends StatefulWidget {
  const EntryDateTimeModal({
    required this.item,
    super.key,
    this.readOnly = false,
  });

  final JournalEntity item;
  final bool readOnly;

  @override
  State<EntryDateTimeModal> createState() => _EntryDateTimeModalState();
}

class _EntryDateTimeModalState extends State<EntryDateTimeModal> {
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
    final localizations = AppLocalizations.of(context)!;

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
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 170,
                    child: DateTimeField(
                      dateTime: dateFrom,
                      labelText: localizations.journalDateFromLabel,
                      setDateTime: (picked) {
                        setState(() {
                          dateFrom = picked;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: DateTimeField(
                      dateTime: dateTo,
                      labelText: localizations.journalDateToLabel,
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
                    localizations.journalDurationLabel,
                    textAlign: TextAlign.end,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      formatDuration(dateFrom.difference(dateTo).abs()),
                      style: monospaceTextStyle().copyWith(
                        fontWeight: FontWeight.w100,
                      ),
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
                          localizations.journalDateSaveButton,
                          style: textStyleLarger().copyWith(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    Visibility(
                      visible: !valid,
                      child: Text(
                        localizations.journalDateInvalid,
                        style: textStyleLarger().copyWith(
                          color: styleConfig().alarm,
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

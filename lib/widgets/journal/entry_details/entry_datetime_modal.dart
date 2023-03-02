import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

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

  void showDatePicker({
    required void Function(DateTime) onConfirm,
    required DateTime currentTime,
  }) {
    DatePicker.showDateTimePicker(
      context,
      theme: datePickerTheme(),
      onConfirm: onConfirm,
      currentTime: currentTime,
    );
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
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: [
                  Text(
                    localizations.journalDateFromLabel,
                    textAlign: TextAlign.end,
                    style: labelStyleLarger(),
                  ),
                  TextButton(
                    onPressed: () {
                      showDatePicker(
                        onConfirm: (DateTime date) {
                          setState(() {
                            dateFrom = date;
                          });
                        },
                        currentTime: dateFrom,
                      );
                    },
                    child: Text(
                      dfShorter.format(dateFrom),
                      style: textStyleLargerUnderlined(),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    localizations.journalDateToLabel,
                    textAlign: TextAlign.end,
                    style: labelStyleLarger(),
                  ),
                  TextButton(
                    onPressed: () {
                      showDatePicker(
                        onConfirm: (DateTime date) {
                          setState(() {
                            dateTo = date;
                          });
                        },
                        currentTime: dateTo,
                      );
                    },
                    child: Text(
                      dfShorter.format(dateTo),
                      style: textStyleLargerUnderlined(),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        dateTo = DateTime.now();
                      });
                    },
                    child: Text(
                      localizations.journalDateNowButton,
                      style: textStyleLarger()
                          .copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    localizations.journalDurationLabel,
                    textAlign: TextAlign.end,
                    style: labelStyleLarger(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      formatDuration(dateFrom.difference(dateTo).abs()),
                      style: monospaceTextStyleLarge().copyWith(
                        fontWeight: FontWeight.w100,
                        fontSize: 20,
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

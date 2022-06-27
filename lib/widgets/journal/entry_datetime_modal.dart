import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class EntryDateTimeModal extends StatefulWidget {
  const EntryDateTimeModal({
    super.key,
    required this.item,
    this.readOnly = false,
  });

  final JournalEntity item;
  final bool readOnly;

  @override
  State<EntryDateTimeModal> createState() => _EntryDateTimeModalState();
}

class _EntryDateTimeModalState extends State<EntryDateTimeModal> {
  final JournalDb db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  late final Stream<JournalEntity?> stream =
      db.watchEntityById(widget.item.meta.id);

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
      theme: DatePickerTheme(
        headerColor: AppColors.entryCardColor,
        backgroundColor: AppColors.bodyBgColor,
        itemStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        doneStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      onConfirm: onConfirm,
      currentTime: currentTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    final valid = dateTo.isAfter(dateFrom) || dateTo == dateFrom;
    final changed = dateFrom != widget.item.meta.dateFrom ||
        dateTo != widget.item.meta.dateTo;

    return StreamBuilder<JournalEntity?>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        final liveEntity = snapshot.data;
        if (liveEntity == null) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 200,
          color: AppColors.bodyBgColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        localizations.journalDateFromLabel,
                        textAlign: TextAlign.end,
                        style: labelStyleLarger,
                      ),
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
                        df.format(dateFrom),
                        style: textStyleLarger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 8,
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        localizations.journalDateToLabel,
                        textAlign: TextAlign.end,
                        style: labelStyleLarger,
                      ),
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
                        df.format(dateTo),
                        style: textStyleLarger,
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
                        style: textStyleLarger,
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
                            setState(() {});

                            await persistenceLogic.updateJournalEntityDate(
                              widget.item.meta.id,
                              dateFrom: dateFrom,
                              dateTo: dateTo,
                            );
                            await getIt<AppRouter>().pop();
                          },
                          child: Text(
                            localizations.journalDateSaveButton,
                            style: textStyleLarger,
                          ),
                        ),
                      ),
                      Visibility(
                        visible: !valid,
                        child: Text(
                          localizations.journalDateInvalid,
                          style:
                              textStyleLarger.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

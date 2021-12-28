import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:provider/src/provider.dart';

class EntryDateTimeModal extends StatefulWidget {
  final JournalEntity item;
  final bool readOnly;
  const EntryDateTimeModal({
    Key? key,
    required this.item,
    this.readOnly = false,
  }) : super(key: key);

  @override
  _EntryDateTimeModalState createState() => _EntryDateTimeModalState();
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
    required Function(DateTime) onConfirm,
    required DateTime currentTime,
  }) {
    DatePicker.showDateTimePicker(
      context,
      showTitleActions: true,
      theme: DatePickerTheme(
        headerColor: AppColors.headerBgColor,
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
      locale: LocaleType.en,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool valid = dateTo.isAfter(dateFrom) || dateTo == dateFrom;
    bool changed = dateFrom != widget.item.meta.dateFrom ||
        dateTo != widget.item.meta.dateTo;

    return Container(
      height: 150,
      color: AppColors.bodyBgColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    'Date from: ',
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
                    'Date to:',
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
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Visibility(
                    visible: valid && changed,
                    child: TextButton(
                      onPressed: () async {
                        await context
                            .read<PersistenceCubit>()
                            .updateJournalEntityDate(
                              widget.item,
                              dateFrom: dateFrom,
                              dateTo: dateTo,
                            );
                        Navigator.pop(context);
                      },
                      child: Text(
                        'SAVE',
                        style: textStyleLarger,
                      ),
                    ),
                  ),
                  Visibility(
                    visible: !valid,
                    child: Text(
                      'Invalid Date Range',
                      style: textStyleLarger.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

import '../../../get_it.dart';
import '../../../routes/router.gr.dart';

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
        headerColor: colorConfig().entryCardColor,
        backgroundColor: colorConfig().bodyBgColor,
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
  Widget build(BuildContext _) {
    final localizations = AppLocalizations.of(context)!;

    final valid = dateTo.isAfter(dateFrom) || dateTo == dateFrom;
    final changed = dateFrom != widget.item.meta.dateFrom ||
        dateTo != widget.item.meta.dateTo;

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

        return ColoredBox(
          color: colorConfig().bodyBgColor,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 24,
              bottom: 40,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        localizations.journalDateFromLabel,
                        textAlign: TextAlign.end,
                        style: labelStyleLarger(),
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
                        style: textStyleLargerUnderlined(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        localizations.journalDateToLabel,
                        textAlign: TextAlign.end,
                        style: labelStyleLarger(),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        localizations.journalDurationLabel,
                        textAlign: TextAlign.end,
                        style: labelStyleLarger(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        formatDuration(dateFrom.difference(dateTo).abs()),
                        style: textStyleLarger().copyWith(
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
                            await getIt<AppRouter>().pop();
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
                            color: colorConfig().error,
                          ),
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

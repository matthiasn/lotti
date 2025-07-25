import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/date_time/datetime_bottom_sheet.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class DateTimeField extends StatefulWidget {
  const DateTimeField({
    required this.dateTime,
    required this.labelText,
    required this.setDateTime,
    this.clear,
    this.mode = CupertinoDatePickerMode.dateAndTime,
    super.key,
  });

  final DateTime? dateTime;
  final String labelText;
  final void Function(DateTime) setDateTime;
  final void Function()? clear;
  final CupertinoDatePickerMode mode;

  @override
  State<DateTimeField> createState() => _DateTimeFieldState();
}

class _DateTimeFieldState extends State<DateTimeField> {
  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.titleMedium;

    final df = widget.mode == CupertinoDatePickerMode.date
        ? dfYmd
        : widget.mode == CupertinoDatePickerMode.time
            ? hhMmFormat
            : dfShorter;

    return TextField(
      decoration: createDialogInputDecoration(
        labelText: widget.labelText,
        style: style,
        themeData: Theme.of(context),
      ).copyWith(
        suffixIcon: widget.clear != null
            ? IconButton(
                onPressed: widget.clear,
                icon: const Icon(Icons.clear),
              )
            : null,
      ),
      style: style,
      readOnly: true,
      controller: TextEditingController(
        text: widget.dateTime != null ? df.format(widget.dateTime!) : '',
      ),
      onTap: () async {
        var selectedDateTime = widget.dateTime ?? DateTime.now();

        await ModalUtils.showSinglePageModal<void>(
          context: context,
          builder: (modalContext) {
            return DateTimeBottomSheet(
              selectedDateTime,
              mode: widget.mode,
              onDateTimeSelected: (dateTime) {
                if (dateTime != null) {
                  selectedDateTime = dateTime;
                }
              },
            );
          },
          title: widget.labelText,
          stickyActionBar: DateTimeStickyActionBar(
            onCancel: () => Navigator.of(context).pop(),
            onNow: () {
              widget.setDateTime(DateTime.now());
              Navigator.of(context).pop();
            },
            onDone: () {
              widget.setDateTime(selectedDateTime);
              Navigator.of(context).pop();
            },
          ),
          navBarHeight: 65,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        );
      },
    );
  }
}

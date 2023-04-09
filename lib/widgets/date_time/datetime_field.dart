import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/date_time/datetime_bottom_sheet.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class DateTimeField extends StatefulWidget {
  const DateTimeField({
    required this.dateTime,
    required this.labelText,
    required this.setDateTime,
    this.mode = CupertinoDatePickerMode.dateAndTime,
    this.style,
    super.key,
  });

  final DateTime? dateTime;
  final String labelText;
  final void Function(DateTime) setDateTime;
  final TextStyle? style;
  final CupertinoDatePickerMode mode;

  @override
  State<DateTimeField> createState() => _DateTimeFieldState();
}

class _DateTimeFieldState extends State<DateTimeField> {
  @override
  Widget build(BuildContext context) {
    final df = widget.mode == CupertinoDatePickerMode.date
        ? dfYmd
        : widget.mode == CupertinoDatePickerMode.time
            ? hhMmFormat
            : dfShorter;

    return TextField(
      decoration: createDialogInputDecoration(
        labelText: widget.labelText,
        style: widget.style,
      ),
      style: widget.style,
      readOnly: true,
      controller: TextEditingController(
        text: widget.dateTime != null ? df.format(widget.dateTime!) : '',
      ),
      onTap: () async {
        final newDateTime = await showModalBottomSheet<DateTime>(
          context: context,
          builder: (context) {
            return DateTimeBottomSheet(
              widget.dateTime ?? DateTime.now(),
              mode: widget.mode,
            );
          },
        );

        if (newDateTime != null) {
          widget.setDateTime(newDateTime);
        }
      },
    );
  }
}

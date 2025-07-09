import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/date_time/datetime_bottom_sheet.dart';
import 'package:lotti/widgets/modal/modern_modal_utils.dart';

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
        final newDateTime = await ModernModalUtils.showModernModal<DateTime>(
          context: context,
          builder: (_) {
            return DateTimeBottomSheet(
              widget.dateTime ?? DateTime.now(),
              mode: widget.mode,
            );
          },
          padding:
              const EdgeInsets.only(left: 20, top: 20, right: 20, bottom: 40),
          navBarHeight: 5,
        );

        if (newDateTime != null) {
          widget.setDateTime(newDateTime);
        }
      },
    );
  }
}

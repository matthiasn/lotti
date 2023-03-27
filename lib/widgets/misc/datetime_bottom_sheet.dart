import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/themes/theme.dart';

class DateTimeBottomSheet extends StatefulWidget {
  const DateTimeBottomSheet(this.initial, {super.key});

  final DateTime? initial;

  @override
  State<DateTimeBottomSheet> createState() => _DateTimeBottomSheetState();
}

class _DateTimeBottomSheetState extends State<DateTimeBottomSheet> {
  DateTime? dateTime = DateTime.now();

  @override
  void initState() {
    dateTime = widget.initial;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          color: styleConfig().primaryColor.withOpacity(0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  localizations.cancelButton,
                  style: buttonLabelStyle().copyWith(
                    color: styleConfig().secondaryTextColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, dateTime);
                },
                child: Text(
                  localizations.doneButton,
                  style: buttonLabelStyle().copyWith(
                    color: styleConfig().primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        CupertinoTheme(
          data: CupertinoThemeData(
            textTheme: CupertinoTextThemeData(
              pickerTextStyle: formLabelStyle().copyWith(
                fontSize: fontSizeLarge,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          child: SizedBox(
            height: 300,
            child: CupertinoDatePicker(
              initialDateTime: widget.initial,
              use24hFormat: true,
              onDateTimeChanged: (DateTime value) {
                dateTime = value;
              },
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/themes/theme.dart';

class DateTimeBottomSheet extends StatefulWidget {
  const DateTimeBottomSheet(
    this.initial, {
    required this.mode,
    super.key,
  });

  final DateTime? initial;
  final CupertinoDatePickerMode mode;

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
          color: Theme.of(context).primaryColor.withOpacity(0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(localizations.cancelButton),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, DateTime.now());
                },
                child: Text(localizations.journalDateNowButton),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, dateTime);
                },
                child: Text(localizations.doneButton),
              ),
            ],
          ),
        ),
        CupertinoTheme(
          data: CupertinoThemeData(
            textTheme: CupertinoTextThemeData(
              dateTimePickerTextStyle: TextStyle(
                color: Theme.of(context).textTheme.titleLarge?.color ??
                    Colors.grey,
                fontSize: fontSizeLarge,
                fontWeight: FontWeight.w300,
                fontFamily: mainFont,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          child: SizedBox(
            height: 265,
            child: CupertinoDatePicker(
              initialDateTime: widget.initial,
              mode: widget.mode,
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

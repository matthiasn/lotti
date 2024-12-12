import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class DurationBottomSheet extends StatefulWidget {
  const DurationBottomSheet(this.initial, {super.key});

  final Duration? initial;

  @override
  State<DurationBottomSheet> createState() => _DurationBottomSheetState();
}

class _DurationBottomSheetState extends State<DurationBottomSheet> {
  Duration? duration;

  @override
  void initState() {
    duration = widget.initial;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          color: Theme.of(context).primaryColor.withAlpha(77),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(context.messages.cancelButton),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, duration);
                },
                child: Text(context.messages.doneButton),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 500,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Theme.of(context).brightness,
              textTheme: CupertinoTextThemeData(
                pickerTextStyle:
                    context.textTheme.titleLarge?.withTabularFigures,
              ),
            ),
            child: CupertinoTimerPicker(
              onTimerDurationChanged: (Duration value) {
                duration = value;
              },
              initialTimerDuration: widget.initial ?? Duration.zero,
              mode: CupertinoTimerPickerMode.hm,
            ),
          ),
        ),
      ],
    );
  }
}

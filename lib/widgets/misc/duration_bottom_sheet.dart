import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
                  style: buttonLabelStyleLarger().copyWith(
                    color: styleConfig().secondaryTextColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, duration);
                },
                child: Text(
                  localizations.doneButton,
                  style: buttonLabelStyleLarger().copyWith(
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
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          child: SizedBox(
            width: 500,
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

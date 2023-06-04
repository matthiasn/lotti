import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
                  Navigator.pop(context, duration);
                },
                child: Text(localizations.doneButton),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 500,
          child: CupertinoTimerPicker(
            onTimerDurationChanged: (Duration value) {
              duration = value;
            },
            initialTimerDuration: widget.initial ?? Duration.zero,
            mode: CupertinoTimerPickerMode.hm,
          ),
        ),
      ],
    );
  }
}

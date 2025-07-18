import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/lotti_primary_button.dart';

class DateTimeBottomSheet extends StatefulWidget {
  const DateTimeBottomSheet(
    this.initial, {
    required this.mode,
    required this.onDateTimeSelected,
    super.key,
  });

  final DateTime? initial;
  final CupertinoDatePickerMode mode;
  final void Function(DateTime?) onDateTimeSelected;

  @override
  State<DateTimeBottomSheet> createState() => _DateTimeBottomSheetState();
}

class _DateTimeBottomSheetState extends State<DateTimeBottomSheet> {
  @override
  void initState() {
    super.initState();
    // Pass initial value to callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initial = widget.initial;
      if (initial != null) {
        widget.onDateTimeSelected(initial);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          dateTimePickerTextStyle:
              context.textTheme.titleLarge?.withTabularFigures,
        ),
      ),
      child: SizedBox(
        height: 265,
        child: CupertinoDatePicker(
          initialDateTime: widget.initial,
          mode: widget.mode,
          use24hFormat: true,
          onDateTimeChanged: widget.onDateTimeSelected,
        ),
      ),
    );
  }
}

/// Sticky action bar for the date time selection modal
class DateTimeStickyActionBar extends StatelessWidget {
  const DateTimeStickyActionBar({
    required this.onCancel,
    required this.onNow,
    required this.onDone,
    super.key,
  });

  final VoidCallback onCancel;
  final VoidCallback onNow;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: context.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                context.messages.cancelButton,
                style: TextStyle(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: onNow,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: context.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                context.messages.journalDateNowButton,
                style: TextStyle(
                  color: context.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LottiPrimaryButton(
              onPressed: onDone,
              label: context.messages.doneButton,
            ),
          ),
        ],
      ),
    );
  }
}

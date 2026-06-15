import 'package:flutter/cupertino.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

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
    final tokens = context.designTokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: DesignSystemButton(
              label: context.messages.cancelButton,
              variant: DesignSystemButtonVariant.secondary,
              size: DesignSystemButtonSize.large,
              onPressed: onCancel,
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Flexible(
            child: DesignSystemButton(
              label: context.messages.journalDateNowButton,
              variant: DesignSystemButtonVariant.secondary,
              size: DesignSystemButtonSize.large,
              onPressed: onNow,
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Flexible(
            child: DesignSystemButton(
              label: context.messages.doneButton,
              size: DesignSystemButtonSize.large,
              onPressed: onDone,
            ),
          ),
        ],
      ),
    );
  }
}

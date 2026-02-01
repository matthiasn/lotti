import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Button to navigate back to today.
class TodayButton extends StatelessWidget {
  const TodayButton({
    required this.onPressed,
    super.key,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        MdiIcons.calendarToday,
        size: 16,
        color: context.colorScheme.primary,
      ),
      label: Text(
        context.messages.dailyOsTodayButton,
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colorScheme.primary,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSmall,
          vertical: 4,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

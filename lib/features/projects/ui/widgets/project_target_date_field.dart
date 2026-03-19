import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/date_utils_extension.dart';

/// Shared target date display/picker used on both the project create and
/// detail pages.
class ProjectTargetDateField extends StatelessWidget {
  const ProjectTargetDateField({
    required this.targetDate,
    required this.onDatePicked,
    required this.onCleared,
    super.key,
  });

  final DateTime? targetDate;
  final VoidCallback onDatePicked;
  final VoidCallback? onCleared;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final dateText = targetDate?.ymd ?? '';

    return InkWell(
      onTap: onDatePicked,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: messages.projectTargetDateLabel,
          prefixIcon: const Icon(Icons.calendar_today, size: 20),
          suffixIcon: targetDate != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: onCleared,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          dateText,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

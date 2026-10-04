part of 'create_measurement_dialog.dart';

/// A tappable, clearly-editable summary of the observed-at timestamp. Carries a
/// trailing edit-calendar glyph so it never reads as a locked, read-only value,
/// and opens the shared date/time picker on tap.
class _ObservedAtField extends StatelessWidget {
  const _ObservedAtField({
    required this.dateTime,
    required this.focusNode,
    required this.autofocus,
    required this.onTap,
    super.key,
  });

  final DateTime dateTime;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.m);
    final formatted = _formatDateTime(context, dateTime);

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: context.messages.measurementObservedAtChangeSemantic(formatted),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          focusNode: focusNode,
          autofocus: autofocus,
          borderRadius: radius,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: tokens.colors.decorative.level01),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatted,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                  ),
                  Icon(
                    LottiIcons.calendarEdit,
                    size: tokens.spacing.step6,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(BuildContext context, DateTime dateTime) {
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatFullDate(dateTime);
  final time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(dateTime),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '$date, $time';
}

import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Sticky glass footer for the AI Settings edit forms.
///
/// Shows a status line on the leading edge — "no changes", a fix-errors hint,
/// or nothing — and Cancel / Save on the trailing edge. Save is only enabled
/// when the form is both [isDirty] and [isFormValid] (and not [isLoading]); an
/// unchanged or invalid form keeps it disabled.
///
/// Built from the design system's sticky-bar parts: a [DesignSystemGlassStrip]
/// surface, and two nested measured [DesignSystemModalActionBar]s. The outer
/// one keeps the status and the action pair on one row while they fit and
/// moves the actions below the status when they do not; the inner one does the
/// same for Cancel and Save. The bar grows instead of overflowing, so Save
/// stays on screen at narrow widths and in long translations.
class FormBottomBar extends StatelessWidget {
  const FormBottomBar({
    required this.onSave,
    required this.onCancel,
    required this.isFormValid,
    required this.isDirty,
    super.key,
    this.isLoading = false,
  });

  final VoidCallback? onSave;
  final VoidCallback onCancel;
  final bool isFormValid;
  final bool isDirty;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final canSave = isDirty && isFormValid && !isLoading;

    final actions = DesignSystemModalActionBar(
      layout: DesignSystemModalActionBarLayout.compactPrimary,
      secondary: [
        DesignSystemButton(
          label: messages.aiFormCancel,
          onPressed: onCancel,
          variant: DesignSystemButtonVariant.tertiary,
          size: DesignSystemButtonSize.large,
        ),
      ],
      // The status line explains a disabled Save to sighted users, but it
      // isn't linked to the button — mirror the reason into a tooltip +
      // semantics so it's perceivable on hover and by screen readers.
      primary: Tooltip(
        message: !isDirty
            ? messages.aiFormNoChanges
            : !isFormValid
            ? messages.aiFormFixErrors
            : messages.saveLabel,
        child: DesignSystemButton(
          label: messages.saveLabel,
          onPressed: canSave ? onSave : null,
          leadingIcon: LottiIcons.save,
          size: DesignSystemButtonSize.large,
        ),
      ),
    );

    final status = !isDirty
        ? _StatusLine(
            icon: LottiIcons.confirmCircled,
            message: messages.aiFormNoChanges,
            color: tokens.colors.text.mediumEmphasis,
          )
        : !isFormValid
        ? _StatusLine(
            icon: LottiIcons.info,
            message: messages.aiFormFixErrors,
            color: tokens.colors.alert.error.defaultColor,
          )
        : null;

    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step3,
        ),
        child: status == null
            // Nothing to explain: the action pair keeps its own width on the
            // trailing edge rather than spreading across the bar.
            ? Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IntrinsicWidth(child: actions),
              )
            : DesignSystemModalActionBar(
                layout: DesignSystemModalActionBarLayout.compactPrimary,
                secondary: [status],
                primary: actions,
              ),
      ),
    );
  }
}

/// Icon + message explaining the current Save state.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: IconSizes.s, color: color),
        SizedBox(width: tokens.spacing.step3),
        Flexible(
          child: Text(
            message,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

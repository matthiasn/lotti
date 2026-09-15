import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// The sticky Clear / Apply footer every filter modal commits its draft with.
///
/// One glass bar in the `compactPrimary` layout, the same padding and the
/// confirm glyph on Apply, so the task list, the projects list and the
/// linked-entries filter close their drafts through an identical footer. The
/// caller owns the draft: [onClearPressed] resets it and [onApplyPressed]
/// commits it. Pass `null` for either handler to disable that button instead
/// of hiding it — a Clear with nothing to clear stays visible but inert.
///
/// [extraSecondary] slots further secondary actions after Clear (the task
/// filter's Save); Apply always stays the trailing primary.
class DesignSystemFilterActionBar extends StatelessWidget {
  const DesignSystemFilterActionBar({
    required this.clearLabel,
    required this.applyLabel,
    required this.onClearPressed,
    required this.onApplyPressed,
    this.clearKey,
    this.applyKey,
    this.extraSecondary = const [],
    super.key,
  });

  final String clearLabel;
  final String applyLabel;
  final VoidCallback? onClearPressed;
  final VoidCallback? onApplyPressed;
  final Key? clearKey;
  final Key? applyKey;
  final List<Widget> extraSecondary;

  /// Scroll clearance a modal body reserves below its last control so it can
  /// move fully above this sticky bar. A bottom sheet needs the bar's full
  /// height, with a larger allowance once large text stacks the bar; a dialog
  /// needs less because its page grows around the footer.
  static double stickyClearance(BuildContext context) {
    final spacing = context.designTokens.spacing;
    if (!ModalUtils.shouldUseRootNavigatorForBottomSheet(context)) {
      return spacing.step12;
    }
    final hasLargeText =
        MediaQuery.textScalerOf(context).scale(1) > TextScales.large;
    return hasLargeText ? spacing.step13 + spacing.step12 : spacing.step13;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    return DesignSystemModalActionBar(
      glass: true,
      layout: DesignSystemModalActionBarLayout.compactPrimary,
      padding: EdgeInsets.fromLTRB(
        spacing.step5,
        spacing.step4,
        spacing.step5,
        spacing.step5,
      ),
      secondary: [
        DesignSystemButton(
          key: clearKey,
          label: clearLabel,
          variant: DesignSystemButtonVariant.secondary,
          size: DesignSystemButtonSize.large,
          onPressed: onClearPressed,
        ),
        ...extraSecondary,
      ],
      primary: DesignSystemButton(
        key: applyKey,
        label: applyLabel,
        leadingIcon: LottiIcons.confirm,
        size: DesignSystemButtonSize.large,
        onPressed: onApplyPressed,
      ),
    );
  }
}

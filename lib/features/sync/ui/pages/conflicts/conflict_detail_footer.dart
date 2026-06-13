import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class ConflictFooter extends StatelessWidget {
  const ConflictFooter({
    required this.selected,
    required this.isStacked,
    required this.applyEnabled,
    required this.onApply,
    required this.onCancel,
    required this.onEditMerge,
    super.key,
  });

  final ConflictSide? selected;
  final bool isStacked;
  final bool applyEnabled;
  final VoidCallback onApply;
  final VoidCallback onCancel;
  final VoidCallback onEditMerge;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;
    final helperColor = switch (selected) {
      ConflictSide.local => colors.conflict.local.color,
      ConflictSide.remote => colors.conflict.remote.color,
      null => colors.text.lowEmphasis,
    };
    final helperText = switch (selected) {
      ConflictSide.local => messages.conflictFooterHelperLocalSelected,
      ConflictSide.remote => messages.conflictFooterHelperRemoteSelected,
      null => messages.conflictFooterHelperPickASide,
    };
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step3,
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Left slot is `Expanded` on both layouts so the buttons
              // own their intrinsic widths on the right and the helper
              // text / Edit-and-merge link absorbs the leftover width
              // (and ellipsizes on phone-width screens).
              Expanded(
                child: isStacked
                    ? _FooterEditMergeLink(onTap: onEditMerge)
                    : Text(
                        helperText,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: helperColor,
                        ),
                      ),
              ),
              SizedBox(width: tokens.spacing.step3),
              DesignSystemButton(
                label: messages.cancelButton,
                variant: DesignSystemButtonVariant.secondary,
                size: DesignSystemButtonSize.large,
                onPressed: onCancel,
              ),
              SizedBox(width: tokens.spacing.step3),
              DesignSystemButton(
                label: messages.conflictApplyButton,
                size: DesignSystemButtonSize.large,
                onPressed: applyEnabled ? onApply : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterEditMergeLink extends StatelessWidget {
  const _FooterEditMergeLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
        child: Text(
          context.messages.conflictPickerEditMerge,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ),
    );
  }
}

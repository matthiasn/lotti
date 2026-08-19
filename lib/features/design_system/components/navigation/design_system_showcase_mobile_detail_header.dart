import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Shared back control used by mobile detail headers.
///
/// The label is intentionally locked to body-small regular so individual detail
/// surfaces do not drift into heavier one-off back-button typography.
class DesignSystemBackControl extends StatelessWidget {
  const DesignSystemBackControl({
    required this.foregroundColor,
    this.onTap,
    super.key,
  });

  final Color foregroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final backLabel = context.messages.designSystemBackLabel;

    return Semantics(
      button: onTap != null,
      label: backLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LottiIcons.chevronLeft,
              size: 20,
              color: foregroundColor,
            ),
            SizedBox(width: tokens.spacing.step2),
            Text(
              backLabel,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: foregroundColor,
                fontWeight: tokens.typography.weight.regular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top bar for a detail screen: an optional leading [DesignSystemBackControl]
/// and a trailing slot defaulting to an overflow (more) icon.
///
/// Both the back label/icon and the default trailing icon are tinted with
/// [foregroundColor]; pass [trailing] to override the default action. Embedded
/// desktop splits set [showBackControl] to false because their sibling list is
/// not navigation history.
class DesignSystemShowcaseMobileDetailHeader extends StatelessWidget {
  const DesignSystemShowcaseMobileDetailHeader({
    required this.foregroundColor,
    this.onBack,
    this.showBackControl = true,
    this.trailing,
    super.key,
  });

  final Color foregroundColor;
  final VoidCallback? onBack;
  final bool showBackControl;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBackControl)
          DesignSystemBackControl(
            foregroundColor: foregroundColor,
            onTap: onBack,
          ),
        const Spacer(),
        trailing ??
            Icon(
              LottiIcons.moreVertical,
              size: 24,
              color: foregroundColor,
            ),
      ],
    );
  }
}

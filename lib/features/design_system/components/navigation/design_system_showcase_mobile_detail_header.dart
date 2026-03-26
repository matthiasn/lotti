import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class DesignSystemShowcaseMobileDetailHeader extends StatelessWidget {
  const DesignSystemShowcaseMobileDetailHeader({
    required this.foregroundColor,
    this.onBack,
    this.trailing,
    super.key,
  });

  final Color foregroundColor;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final backLabel = MaterialLocalizations.of(context).backButtonTooltip;

    return Row(
      children: [
        Semantics(
          button: true,
          label: backLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack ?? () {},
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios,
                  size: 20,
                  color: foregroundColor,
                ),
                SizedBox(width: tokens.spacing.step2),
                Text(
                  backLabel,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: foregroundColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        trailing ??
            Icon(
              Icons.more_vert_rounded,
              size: 24,
              color: foregroundColor,
            ),
      ],
    );
  }
}

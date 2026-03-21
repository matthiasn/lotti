import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemDividerOrientation {
  horizontal,
  vertical,
}

class DesignSystemDivider extends StatelessWidget {
  const DesignSystemDivider({
    this.orientation = DesignSystemDividerOrientation.horizontal,
    this.label,
    this.length,
    super.key,
  }) : assert(
         orientation == DesignSystemDividerOrientation.horizontal ||
             label == null,
         'Vertical dividers do not support labels.',
       );

  final DesignSystemDividerOrientation orientation;
  final String? label;
  final double? length;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = tokens.colors.decorative.level01;

    return switch (orientation) {
      DesignSystemDividerOrientation.horizontal => _HorizontalDivider(
        color: color,
        label: label,
      ),
      DesignSystemDividerOrientation.vertical => SizedBox(
        width: 1,
        height: length ?? 256,
        child: ColoredBox(color: color),
      ),
    };
  }
}

class _HorizontalDivider extends StatelessWidget {
  const _HorizontalDivider({
    required this.color,
    this.label,
  });

  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (label == null || label == '') {
      return SizedBox(
        height: 1,
        child: ColoredBox(color: color),
      );
    }

    return SizedBox(
      height: 16,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: color),
            ),
          ),
          SizedBox(width: tokens.spacing.step5),
          Text(
            label!,
            style: tokens.typography.styles.others.overline.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(width: tokens.spacing.step5),
          Expanded(
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

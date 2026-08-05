import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemDividerOrientation {
  horizontal,
  vertical,
}

/// The design-system's separator line — a 1px rule in the decorative token
/// color.
///
/// [orientation] selects a horizontal or vertical rule; horizontal dividers may
/// carry an inline centered [label] (vertical ones may not, asserted). [length]
/// overrides the default extent along the rule's axis. [color] overrides the
/// rule's ink.
class DesignSystemDivider extends StatelessWidget {
  const DesignSystemDivider({
    this.orientation = DesignSystemDividerOrientation.horizontal,
    this.label,
    this.length,
    this.indent,
    this.color,
    super.key,
  }) : assert(
         orientation == DesignSystemDividerOrientation.horizontal ||
             label == null,
         'Vertical dividers do not support labels.',
       ),
       assert(
         orientation == DesignSystemDividerOrientation.horizontal ||
             indent == null,
         'Vertical dividers do not support an indent.',
       );

  final DesignSystemDividerOrientation orientation;
  final String? label;
  final double? length;

  /// Horizontal leading/trailing inset for the rule. List surfaces pass
  /// their content gutter so the divider respects the same rail the rows
  /// align to instead of running full-bleed under it.
  final double? indent;

  /// Overrides the rule's ink. Null keeps the decorative token default.
  ///
  /// Same escape hatch as `DesignSystemListItem.dividerColor`, for the lists
  /// that stand their dividers up as siblings of the rows rather than letting
  /// each row draw its own: pass [Colors.transparent] to suppress the line
  /// without collapsing its 1&nbsp;px of vertical space, so hover treatments
  /// (`HoverDividerIndex`) never shift the layout beneath the pointer.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = this.color ?? tokens.colors.decorative.level01;

    final divider = switch (orientation) {
      DesignSystemDividerOrientation.horizontal => _HorizontalDivider(
        color: color,
        label: label,
        length: length,
      ),
      DesignSystemDividerOrientation.vertical => SizedBox(
        width: 1,
        height: length ?? 256,
        child: ColoredBox(color: color),
      ),
    };
    final indent = this.indent;
    if (indent == null) return divider;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: divider,
    );
  }
}

class _HorizontalDivider extends StatelessWidget {
  const _HorizontalDivider({
    required this.color,
    this.label,
    this.length,
  });

  static const double _defaultUnboundedWidth = 320;

  final Color color;
  final String? label;
  final double? length;

  @override
  Widget build(BuildContext context) {
    if (length != null) {
      return _buildContent(context, length!);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : _defaultUnboundedWidth;
        return _buildContent(context, resolvedWidth);
      },
    );
  }

  Widget _buildContent(BuildContext context, double resolvedWidth) {
    final tokens = context.designTokens;

    if (label == null || label == '') {
      return SizedBox(
        width: resolvedWidth,
        height: 1,
        child: ColoredBox(color: color),
      );
    }

    return SizedBox(
      width: resolvedWidth,
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
            label!.toUpperCase(),
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

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// The app's standard modal/sheet action bar.
///
/// Layout rule (selected by the design panel as the "dominant primary" / V3
/// pattern): [secondary] actions keep their intrinsic width on the leading
/// edge, and the [primary] action flexes to fill the trailing width with its
/// label centered — so the primary is signalled three ways at once (size,
/// colour, trailing position) rather than relying on colour alone.
///
/// A larger gutter (`spacing.step5`) separates the last secondary from the
/// primary so a mildly-destructive secondary (e.g. a "Clear" button) is harder
/// to fat-finger when reaching to confirm; secondaries are spaced from each
/// other by the smaller `spacing.step3`.
///
/// Pass [primary] as a `DesignSystemButton` with `fullWidth: true` (the bar
/// wraps it in [Expanded], and `fullWidth` keeps its content centred rather
/// than left-aligned). Each [secondary] is laid out at its intrinsic width.
/// [padding] is applied around the row when provided — sticky action bars pass
/// their sheet padding here; bars embedded in an existing padded column leave
/// it null.
class DesignSystemModalActionBar extends StatelessWidget {
  const DesignSystemModalActionBar({
    required this.primary,
    this.secondary = const [],
    this.padding,
    this.glass = false,
    super.key,
  });

  /// The primary (confirming) action. Should be a `DesignSystemButton` with
  /// `fullWidth: true`.
  final Widget primary;

  /// Leading secondary actions, laid out at intrinsic width in order.
  final List<Widget> secondary;

  /// Optional padding around the row.
  final EdgeInsetsGeometry? padding;

  /// When true, the bar is rendered on a [DesignSystemGlassStrip] — a blurred
  /// "glass" surface with a hairline top divider and theme-aware scrim. Use for
  /// sticky action bars that float above scrolling/picker content (e.g. the
  /// date/time picker sheets).
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final children = <Widget>[];
    for (var i = 0; i < secondary.length; i++) {
      children.add(secondary[i]);
      // Widen the gap just before the primary so the dominant action is set
      // clearly apart from the (possibly destructive) last secondary.
      final isLast = i == secondary.length - 1;
      children.add(
        SizedBox(
          width: isLast ? tokens.spacing.step5 : tokens.spacing.step3,
        ),
      );
    }
    children.add(Expanded(child: primary));

    final row = Row(children: children);
    final padded = padding == null
        ? row
        : Padding(padding: padding!, child: row);
    return glass ? DesignSystemGlassStrip(child: padded) : padded;
  }
}

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Controls how the confirming action uses the available footer width.
enum DesignSystemModalActionBarLayout {
  /// The primary action fills the remaining width and stacks on narrow or
  /// large-text layouts.
  dominantPrimary,

  /// Secondary actions stay grouped at the leading edge while the primary
  /// keeps its intrinsic width at the trailing edge. The bar stays horizontal
  /// whenever the rendered labels actually fit and wraps the intrinsic groups
  /// when they do not.
  compactPrimary,
}

/// The app's standard modal/sheet action bar.
///
/// Layout rule (selected by the design panel as the "dominant primary" / V3
/// pattern): at comfortable widths [secondary] actions keep their intrinsic
/// width on the leading edge, and the [primary] action flexes to fill the
/// trailing width. On narrow or large-text layouts, the secondaries wrap above
/// a full-width primary so translations never squeeze or clip the actions.
///
/// A larger gutter (`spacing.step5`) separates the last secondary from the
/// primary so a mildly-destructive secondary (e.g. a "Clear" button) is harder
/// to fat-finger when reaching to confirm; secondaries are spaced from each
/// other by the smaller `spacing.step3`.
///
/// Pass [primary] as a `DesignSystemButton` with `fullWidth: true` (`fullWidth`
/// keeps its content centred when dominant or overflow layouts stretch it).
/// Each [secondary] is laid out at its intrinsic width.
/// [padding] is applied around the row when provided — sticky action bars pass
/// their sheet padding here; bars embedded in an existing padded column leave
/// it null.
class DesignSystemModalActionBar extends StatelessWidget {
  const DesignSystemModalActionBar({
    required this.primary,
    this.secondary = const [],
    this.padding,
    this.glass = false,
    this.layout = DesignSystemModalActionBarLayout.dominantPrimary,
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

  /// Width treatment for the primary action.
  final DesignSystemModalActionBarLayout layout;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final content = LayoutBuilder(
      builder: (context, constraints) {
        if (layout == DesignSystemModalActionBarLayout.compactPrimary) {
          return textScale > 1.3
              ? _StackedActionLayout(primary: primary, secondary: secondary)
              : _CompactActionLayout(primary: primary, secondary: secondary);
        }
        final narrowBreakpoint = secondary.length > 1
            ? tokens.spacing.step13 * 2 + tokens.spacing.step11
            : tokens.spacing.step13 * 2;
        final stacked =
            constraints.maxWidth < narrowBreakpoint || textScale > 1.3;
        return stacked
            ? _StackedActionLayout(primary: primary, secondary: secondary)
            : _WideActionLayout(primary: primary, secondary: secondary);
      },
    );
    final padded = padding == null
        ? content
        : Padding(padding: padding!, child: content);
    return glass ? DesignSystemGlassStrip(child: padded) : padded;
  }
}

class _CompactActionLayout extends StatelessWidget {
  const _CompactActionLayout({required this.primary, required this.secondary});

  final Widget primary;
  final List<Widget> secondary;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    return OverflowBar(
      alignment: MainAxisAlignment.spaceBetween,
      spacing: spacing.step3,
      overflowSpacing: spacing.step3,
      overflowAlignment: OverflowBarAlignment.end,
      children: [
        for (final action in secondary) _IntrinsicAction(child: action),
        _IntrinsicAction(child: primary),
      ],
    );
  }
}

/// Keeps an action's visual button intrinsic even when [OverflowBar] gives its
/// overflow run the full available width.
class _IntrinsicAction extends StatelessWidget {
  const _IntrinsicAction({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [child],
    );
  }
}

class _WideActionLayout extends StatelessWidget {
  const _WideActionLayout({required this.primary, required this.secondary});

  final Widget primary;
  final List<Widget> secondary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      children: [
        for (var i = 0; i < secondary.length; i++) ...[
          secondary[i],
          // Widen the gap just before the primary so the dominant action is set
          // clearly apart from the (possibly destructive) last secondary.
          SizedBox(
            width: i == secondary.length - 1
                ? tokens.spacing.step5
                : tokens.spacing.step3,
          ),
        ],
        Expanded(child: primary),
      ],
    );
  }
}

class _StackedActionLayout extends StatelessWidget {
  const _StackedActionLayout({required this.primary, required this.secondary});

  final Widget primary;
  final List<Widget> secondary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (secondary.isNotEmpty) ...[
          Wrap(
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step3,
            children: secondary,
          ),
          SizedBox(height: tokens.spacing.step3),
        ],
        primary,
      ],
    );
  }
}

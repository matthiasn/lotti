import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    return _CompactActionFlow(
      spacing: spacing.step3,
      secondary: secondary.isEmpty
          ? null
          : Wrap(
              spacing: spacing.step3,
              runSpacing: spacing.step3,
              children: secondary,
            ),
      primary: IntrinsicWidth(child: primary),
    );
  }
}

/// Keeps secondary actions grouped on the leading edge and the primary action
/// on the trailing edge, including when the groups need separate rows.
class _CompactActionFlow extends MultiChildRenderObjectWidget {
  _CompactActionFlow({
    required this.spacing,
    required Widget primary,
    Widget? secondary,
  }) : hasSecondary = secondary != null,
       super(children: [?secondary, primary]);

  final double spacing;
  final bool hasSecondary;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderCompactActionFlow(
      spacing: spacing,
      hasSecondary: hasSecondary,
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCompactActionFlow renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..hasSecondary = hasSecondary
      ..textDirection = Directionality.of(context);
  }
}

class _CompactActionParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderCompactActionFlow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CompactActionParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CompactActionParentData> {
  _RenderCompactActionFlow({
    required this._spacing,
    required this._hasSecondary,
    required this._textDirection,
  });

  double get spacing => _spacing;
  double _spacing;

  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  bool get hasSecondary => _hasSecondary;
  bool _hasSecondary;

  set hasSecondary(bool value) {
    if (_hasSecondary == value) return;
    _hasSecondary = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox? get _secondary => hasSecondary ? firstChild : null;
  RenderBox get _primary => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CompactActionParentData) {
      child.parentData = _CompactActionParentData();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final childConstraints = constraints.loosen();
    return _flowSize(
      constraints: constraints,
      secondarySize: _secondary?.getDryLayout(childConstraints),
      primarySize: _primary.getDryLayout(childConstraints),
    );
  }

  @override
  void performLayout() {
    final childConstraints = constraints.loosen();
    final secondary = _secondary;
    secondary?.layout(childConstraints, parentUsesSize: true);
    final primary = _primary..layout(childConstraints, parentUsesSize: true);
    final secondarySize = secondary?.size;
    final primarySize = primary.size;
    size = _flowSize(
      constraints: constraints,
      secondarySize: secondarySize,
      primarySize: primarySize,
    );

    final gap = secondarySize == null ? 0.0 : spacing;
    final combinedWidth = (secondarySize?.width ?? 0) + gap + primarySize.width;
    final wraps = combinedWidth > size.width;

    if (secondary != null && secondarySize != null) {
      (secondary.parentData! as _CompactActionParentData).offset = Offset(
        _leadingOffset(size.width, secondarySize.width),
        wraps ? 0 : (size.height - secondarySize.height) / 2,
      );
    }

    (primary.parentData! as _CompactActionParentData).offset = Offset(
      _trailingOffset(size.width, primarySize.width),
      wraps
          ? (secondarySize?.height ?? 0) + gap
          : (size.height - primarySize.height) / 2,
    );
  }

  Size _flowSize({
    required BoxConstraints constraints,
    required Size? secondarySize,
    required Size primarySize,
  }) {
    final gap = secondarySize == null ? 0.0 : spacing;
    final combinedWidth = (secondarySize?.width ?? 0) + gap + primarySize.width;
    final availableWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : combinedWidth;
    final wraps = combinedWidth > availableWidth;
    final height = wraps
        ? (secondarySize?.height ?? 0) + gap + primarySize.height
        : (secondarySize == null
              ? primarySize.height
              : math.max(secondarySize.height, primarySize.height));
    return constraints.constrain(Size(availableWidth, height));
  }

  double _leadingOffset(double width, double childWidth) {
    return textDirection == TextDirection.ltr ? 0 : width - childWidth;
  }

  double _trailingOffset(double width, double childWidth) {
    return textDirection == TextDirection.ltr ? width - childWidth : 0;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
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

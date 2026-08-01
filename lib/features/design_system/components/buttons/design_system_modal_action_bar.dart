import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Controls how the confirming action uses the available footer width.
enum DesignSystemModalActionBarLayout {
  /// The primary action fills the width the secondaries leave, and stretches
  /// full width above them once the rendered labels no longer share a row.
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
/// pattern): while the rendered labels fit, [secondary] actions keep their
/// intrinsic width on the leading edge and the [primary] action flexes to fill
/// the trailing width. When they do not fit — or on large-text layouts — the
/// secondaries wrap above a full-width primary so translations never squeeze or
/// clip the actions.
///
/// The fit is decided by measuring the actions themselves, not by comparing the
/// available width against a breakpoint: a long translated label must wrap the
/// bar rather than overflow the row or collapse the primary to zero width.
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    // Large-text layouts always stack: at that scale a horizontal bar is
    // reachable-but-cramped even on the rare width where it still fits.
    final content = textScale > 1.3
        ? _StackedActionLayout(primary: primary, secondary: secondary)
        : _MeasuredActionLayout(
            primary: primary,
            secondary: secondary,
            primaryFills:
                layout == DesignSystemModalActionBarLayout.dominantPrimary,
          );
    final padded = padding == null
        ? content
        : Padding(padding: padding!, child: content);
    return glass ? DesignSystemGlassStrip(child: padded) : padded;
  }
}

/// Groups the actions and hands them to [_ActionFlow], which decides between a
/// single row and stacked groups by measuring the rendered labels.
class _MeasuredActionLayout extends StatelessWidget {
  const _MeasuredActionLayout({
    required this.primary,
    required this.secondary,
    required this.primaryFills,
  });

  final Widget primary;
  final List<Widget> secondary;

  /// Whether the primary expands into the width the secondaries leave (the
  /// "dominant primary" pattern) or keeps its intrinsic width.
  final bool primaryFills;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    return _ActionFlow(
      // A wider gutter sets the dominant primary apart from a possibly
      // destructive last secondary; the compact pattern uses the plain gap.
      gutter: primaryFills ? spacing.step5 : spacing.step3,
      runGap: spacing.step3,
      primaryFills: primaryFills,
      secondary: secondary.isEmpty
          ? null
          : Wrap(
              spacing: spacing.step3,
              runSpacing: spacing.step3,
              children: secondary,
            ),
      primary: primaryFills ? primary : IntrinsicWidth(child: primary),
    );
  }
}

/// Keeps secondary actions grouped on the leading edge and the primary action
/// on the trailing edge, including when the groups need separate rows.
///
/// The single row is chosen by measuring the groups' own intrinsic widths, not
/// by thresholding on the available width: a long translated label therefore
/// wraps instead of overflowing the row or squeezing the primary to nothing.
class _ActionFlow extends MultiChildRenderObjectWidget {
  _ActionFlow({
    required this.gutter,
    required this.runGap,
    required this.primaryFills,
    required Widget primary,
    Widget? secondary,
  }) : hasSecondary = secondary != null,
       super(children: [?secondary, primary]);

  /// Horizontal gap between the secondary group and the primary.
  final double gutter;

  /// Vertical gap between the groups once they no longer share a row.
  final double runGap;

  /// Whether the primary takes the width the secondaries leave (and stretches
  /// full width when the groups wrap) or keeps its intrinsic width.
  final bool primaryFills;

  final bool hasSecondary;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderActionFlow(
      gutter: gutter,
      runGap: runGap,
      primaryFills: primaryFills,
      hasSecondary: hasSecondary,
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderActionFlow renderObject,
  ) {
    renderObject
      ..gutter = gutter
      ..runGap = runGap
      ..primaryFills = primaryFills
      ..hasSecondary = hasSecondary
      ..textDirection = Directionality.of(context);
  }
}

class _ActionFlowParentData extends ContainerBoxParentData<RenderBox> {}

/// The width each group wants, and whether both still fit on one row.
class _FlowPlan {
  const _FlowPlan({
    required this.availableWidth,
    required this.secondaryIntrinsic,
    required this.gap,
    required this.wraps,
  });

  final double availableWidth;
  final double secondaryIntrinsic;

  /// The gutter, or zero when there is no secondary group to separate.
  final double gap;
  final bool wraps;

  /// The width left for a filling primary once the secondaries are placed.
  double get remainingForPrimary =>
      math.max(0, availableWidth - secondaryIntrinsic - gap);
}

class _RenderActionFlow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ActionFlowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ActionFlowParentData> {
  _RenderActionFlow({
    required this._gutter,
    required this._runGap,
    required this._primaryFills,
    required this._hasSecondary,
    required this._textDirection,
  });

  double get gutter => _gutter;
  double _gutter;

  set gutter(double value) {
    if (_gutter == value) return;
    _gutter = value;
    markNeedsLayout();
  }

  double get runGap => _runGap;
  double _runGap;

  set runGap(double value) {
    if (_runGap == value) return;
    _runGap = value;
    markNeedsLayout();
  }

  bool get primaryFills => _primaryFills;
  bool _primaryFills;

  set primaryFills(bool value) {
    if (_primaryFills == value) return;
    _primaryFills = value;
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
    if (child.parentData is! _ActionFlowParentData) {
      child.parentData = _ActionFlowParentData();
    }
  }

  /// The width a group takes when nothing constrains it — its labels on one
  /// row, including any spacing the group puts between its own children.
  ///
  /// Measured by dry layout rather than by [getMaxIntrinsicWidth] for two
  /// reasons: a `fullWidth` primary centres its content, so laying it out
  /// against loose constraints reports the width it was *offered* rather than
  /// the width it needs; and `RenderWrap` leaves its own `spacing` out of its
  /// intrinsic width, which would under-measure a multi-action secondary group
  /// and let the primary encroach on the gutter.
  static double _naturalWidth(RenderBox child) =>
      child.getDryLayout(const BoxConstraints()).width;

  /// Measures both groups at the width their own labels ask for.
  _FlowPlan _plan(BoxConstraints constraints) {
    final secondary = _secondary;
    final secondaryIntrinsic = secondary == null
        ? 0.0
        : _naturalWidth(secondary);
    final primaryIntrinsic = _naturalWidth(_primary);
    final gap = hasSecondary ? gutter : 0.0;
    final combined = secondaryIntrinsic + gap + primaryIntrinsic;
    final availableWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : combined;
    return _FlowPlan(
      availableWidth: availableWidth,
      secondaryIntrinsic: secondaryIntrinsic,
      gap: gap,
      // Wrapping means "the groups take separate rows", so it needs two groups.
      // A lone primary that cannot fit is bounded to the available width, not
      // pushed below an empty leading row.
      wraps: secondary != null && combined > availableWidth,
    );
  }

  BoxConstraints _secondaryConstraints(
    BoxConstraints constraints,
    _FlowPlan plan,
  ) {
    if (plan.wraps && primaryFills) {
      return BoxConstraints.tightFor(width: plan.availableWidth);
    }
    return constraints.loosen();
  }

  BoxConstraints _primaryConstraints(
    BoxConstraints constraints,
    _FlowPlan plan,
  ) {
    if (!primaryFills) return constraints.loosen();
    return BoxConstraints.tightFor(
      width: plan.wraps ? plan.availableWidth : plan.remainingForPrimary,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final plan = _plan(constraints);
    return _flowSize(
      constraints: constraints,
      plan: plan,
      secondarySize: _secondary?.getDryLayout(
        _secondaryConstraints(constraints, plan),
      ),
      primarySize: _primary.getDryLayout(
        _primaryConstraints(constraints, plan),
      ),
    );
  }

  @override
  void performLayout() {
    final plan = _plan(constraints);
    final secondary = _secondary
      ?..layout(_secondaryConstraints(constraints, plan), parentUsesSize: true);
    final primary = _primary
      ..layout(_primaryConstraints(constraints, plan), parentUsesSize: true);
    final secondarySize = secondary?.size;
    final primarySize = primary.size;
    size = _flowSize(
      constraints: constraints,
      plan: plan,
      secondarySize: secondarySize,
      primarySize: primarySize,
    );

    if (secondary != null && secondarySize != null) {
      (secondary.parentData! as _ActionFlowParentData).offset = Offset(
        _leadingOffset(size.width, secondarySize.width),
        plan.wraps ? 0 : (size.height - secondarySize.height) / 2,
      );
    }

    (primary.parentData! as _ActionFlowParentData).offset = Offset(
      _trailingOffset(size.width, primarySize.width),
      plan.wraps
          ? (secondarySize?.height ?? 0) + runGap
          : (size.height - primarySize.height) / 2,
    );
  }

  Size _flowSize({
    required BoxConstraints constraints,
    required _FlowPlan plan,
    required Size? secondarySize,
    required Size primarySize,
  }) {
    final height = plan.wraps
        ? (secondarySize?.height ?? 0) + runGap + primarySize.height
        : (secondarySize == null
              ? primarySize.height
              : math.max(secondarySize.height, primarySize.height));
    return constraints.constrain(Size(plan.availableWidth, height));
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    // Wrapped, the groups sit on their own rows, so the bar can shrink to the
    // wider of the two.
    return math.max(
      _secondary?.getMinIntrinsicWidth(height) ?? 0.0,
      _primary.getMinIntrinsicWidth(height),
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    // Measured the same way layout measures, so a parent that sizes the bar to
    // its maximum intrinsic width gets exactly the width at which it keeps a
    // single row.
    final secondary = _secondary;
    if (secondary == null) return _naturalWidth(_primary);
    return _naturalWidth(secondary) + gutter + _naturalWidth(_primary);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child, w) => child.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child, w) => child.getMaxIntrinsicHeight(w));

  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double width) measure,
  ) {
    final plan = _plan(BoxConstraints(maxWidth: width));
    final secondary = _secondary;
    if (secondary == null) return measure(_primary, plan.availableWidth);
    if (plan.wraps) {
      return measure(secondary, plan.availableWidth) +
          runGap +
          measure(_primary, plan.availableWidth);
    }
    return math.max(
      measure(secondary, plan.secondaryIntrinsic),
      measure(_primary, plan.remainingForPrimary),
    );
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

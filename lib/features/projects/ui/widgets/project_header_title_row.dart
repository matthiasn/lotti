import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// The project header's title beside a trailing action rail, laid out so the
/// rail never sets the header's height.
///
/// A plain `Row` would. The overflow menu is a fixed 48 pt tap target and the
/// title around 32 pt, so the row would grow to 48 and open an empty band
/// between the title and the status pills beneath it — the "empty toolbar row"
/// this header has always avoided, back when the menu was a `Stack` overlay.
/// Explore project joined the same rail and needed the same treatment, but a
/// labelled button's width is not known in advance, so a fixed overlay inset
/// could no longer keep the title clear of it.
///
/// So: the header is exactly as tall as its title; the action rail is
/// measured first, gets the trailing corner, and the title gets what is left
/// minus [gap] — long project names wrap or ellipsize against the rail instead
/// of running under it. [lift] raises the rail so its glyphs sit nearer the
/// title's optical centre than its box top.
///
/// A rail taller than the title hangs below the header, exactly as the
/// overlaid menu did, and the overhanging part is not tappable — the trade the
/// header already made for a compact title band.
class ProjectHeaderTitleRow extends MultiChildRenderObjectWidget {
  ProjectHeaderTitleRow({
    required Widget title,
    required Widget actions,
    required this.gap,
    required this.lift,
    super.key,
  }) : super(children: [title, actions]);

  /// Horizontal space kept clear between the title and the rail.
  final double gap;

  /// How far the rail is raised above the header's top edge.
  final double lift;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderProjectHeaderTitleRow(
        gap: gap,
        lift: lift,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderProjectHeaderTitleRow renderObject,
  ) {
    renderObject
      ..gap = gap
      ..lift = lift
      ..textDirection = Directionality.of(context);
  }
}

class _TitleRowParentData extends ContainerBoxParentData<RenderBox> {}

/// Render object for [ProjectHeaderTitleRow]. Public so a widget test can
/// address it directly.
class RenderProjectHeaderTitleRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TitleRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TitleRowParentData> {
  RenderProjectHeaderTitleRow({
    required this._gap,
    required this._lift,
    required this._textDirection,
  });

  double get gap => _gap;
  double _gap;

  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  double get lift => _lift;
  double _lift;

  set lift(double value) {
    if (_lift == value) return;
    _lift = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _title => firstChild!;
  RenderBox get _actions => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TitleRowParentData) {
      child.parentData = _TitleRowParentData();
    }
  }

  /// The width the header can use. An unbounded parent gets the two children
  /// side by side at their natural widths rather than an infinity.
  double _availableWidth(BoxConstraints constraints) =>
      constraints.hasBoundedWidth
      ? constraints.maxWidth
      : _title.getMaxIntrinsicWidth(double.infinity) +
            gap +
            _actions.getMaxIntrinsicWidth(double.infinity);

  BoxConstraints _titleConstraints(
    BoxConstraints constraints,
    double actions,
  ) => BoxConstraints(
    maxWidth: math.max(0, _availableWidth(constraints) - actions - gap),
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final actions = _actions.getDryLayout(constraints.loosen());
    final title = _title.getDryLayout(
      _titleConstraints(constraints, actions.width),
    );
    return constraints.constrain(
      Size(_availableWidth(constraints), title.height),
    );
  }

  @override
  void performLayout() {
    // Loosened rather than unbounded: a rail whose labels outgrow the header
    // is squeezed by its own `Row` instead of painting past the right edge.
    _actions.layout(constraints.loosen(), parentUsesSize: true);
    final actionsSize = _actions.size;
    _title.layout(
      _titleConstraints(constraints, actionsSize.width),
      parentUsesSize: true,
    );
    final titleSize = _title.size;
    final width = _availableWidth(constraints);
    size = constraints.constrain(Size(width, titleSize.height));

    final rtl = textDirection == TextDirection.rtl;
    (_title.parentData! as _TitleRowParentData).offset = Offset(
      rtl ? size.width - titleSize.width : 0,
      0,
    );
    (_actions.parentData! as _TitleRowParentData).offset = Offset(
      rtl ? 0 : size.width - actionsSize.width,
      -lift,
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _title.getMinIntrinsicWidth(height) +
      gap +
      _actions.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _title.getMaxIntrinsicWidth(height) +
      gap +
      _actions.getMaxIntrinsicWidth(height);

  // Height is the title's alone: that is the whole point of this layout.
  @override
  double computeMinIntrinsicHeight(double width) =>
      _title.getMinIntrinsicHeight(
        math.max(
          0,
          width - _actions.getMaxIntrinsicWidth(double.infinity) - gap,
        ),
      );

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _title.getMaxIntrinsicHeight(
        math.max(
          0,
          width - _actions.getMaxIntrinsicWidth(double.infinity) - gap,
        ),
      );

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  /// Accepts a pointer anywhere on the action rail, including the part that
  /// hangs below the header.
  ///
  /// `RenderBox.hitTest` rejects a position outside the box before it reaches
  /// any child, and the box is deliberately only as tall as the title — so
  /// without this the bottom third of two 48 pt controls would be dead, which
  /// is below the touch target the design system asks for. Sizing the box to
  /// the rail instead is what opens the empty band this layout exists to
  /// avoid, so the rail keeps its own bounds for hit testing while the header
  /// keeps the title's for layout.
  ///
  /// Only the rail's own rectangle is claimed. Everything below the header
  /// outside it still falls through to the siblings underneath, which are
  /// hit-tested first anyway.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (super.hitTest(result, position: position)) return true;

    final actionsData = _actions.parentData! as _TitleRowParentData;
    if (!(actionsData.offset & _actions.size).contains(position)) return false;

    final hit = result.addWithPaintOffset(
      offset: actionsData.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) =>
          _actions.hitTest(result, position: transformed),
    );
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }
}

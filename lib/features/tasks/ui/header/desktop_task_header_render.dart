part of 'desktop_task_header.dart';

/// Wrap-style horizontal layout where the **last child** is pinned to the
/// right edge of whichever row it lands on. If the trailing child doesn't
/// fit in the same row as the leading chips, it falls onto its own row,
/// still right-aligned.
///
/// Used by the meta row so the status pill always sits at the end of the
/// final visible row, without snapping to a separate column at an arbitrary
/// breakpoint.
class _TrailingAlignedWrap extends MultiChildRenderObjectWidget {
  const _TrailingAlignedWrap({
    required this.spacing,
    required this.runSpacing,
    required super.children,
  });

  final double spacing;
  final double runSpacing;

  @override
  _RenderTrailingAlignedWrap createRenderObject(BuildContext context) {
    return _RenderTrailingAlignedWrap(
      spacing: spacing,
      runSpacing: runSpacing,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTrailingAlignedWrap renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing;
  }
}

class _TrailingAlignedWrapParentData
    extends ContainerBoxParentData<RenderBox> {}

class _RenderTrailingAlignedWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TrailingAlignedWrapParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _TrailingAlignedWrapParentData
        > {
  _RenderTrailingAlignedWrap({
    required this._spacing,
    required this._runSpacing,
  });

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _runSpacing;
  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(covariant RenderBox child) {
    if (child.parentData is! _TrailingAlignedWrapParentData) {
      child.parentData = _TrailingAlignedWrapParentData();
    }
  }

  // Typed accessor for the parentData. `setupParentData` guarantees every
  // child has been outfitted with our parent-data type by the time layout /
  // intrinsics run, so `parentData!` is sound here. Keeping the bang inside
  // a single helper avoids `cast_nullable_to_non_nullable` warnings at every
  // call site.
  _TrailingAlignedWrapParentData _pd(RenderBox child) =>
      child.parentData! as _TrailingAlignedWrapParentData;

  @override
  void performLayout() {
    final maxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : double.infinity;

    final boxes = <RenderBox>[];
    var cursor = firstChild;
    while (cursor != null) {
      boxes.add(cursor);
      cursor = _pd(cursor).nextSibling;
    }
    if (boxes.isEmpty) {
      size = constraints.constrain(Size.zero);
      return;
    }

    for (final child in boxes) {
      child.layout(
        BoxConstraints(maxWidth: maxWidth),
        parentUsesSize: true,
      );
    }

    final trailing = boxes.last;
    final leading = boxes.sublist(0, boxes.length - 1);

    // Greedy pack leading children into rows.
    final rowIndex = <int>[];
    final rowWidth = <double>[0];
    final rowHeight = <double>[0];
    var currentRow = 0;
    for (var i = 0; i < leading.length; i++) {
      final w = leading[i].size.width;
      final h = leading[i].size.height;
      final isFirstInRow = rowWidth[currentRow] == 0;
      final candidate = isFirstInRow ? w : rowWidth[currentRow] + _spacing + w;
      if (candidate <= maxWidth || isFirstInRow) {
        rowIndex.add(currentRow);
        rowWidth[currentRow] = candidate;
        rowHeight[currentRow] = math.max(rowHeight[currentRow], h);
      } else {
        currentRow += 1;
        rowWidth.add(w);
        rowHeight.add(h);
        rowIndex.add(currentRow);
      }
    }

    // Place trailing on the last row if it fits, otherwise on a new row.
    final tw = trailing.size.width;
    final th = trailing.size.height;
    final lastRowEmpty = rowWidth[currentRow] == 0;
    final fitsLast = lastRowEmpty
        ? tw <= maxWidth
        : (rowWidth[currentRow] + _spacing + tw) <= maxWidth;
    final int trailingRow;
    if (fitsLast) {
      trailingRow = currentRow;
      rowHeight[currentRow] = math.max(rowHeight[currentRow], th);
    } else {
      trailingRow = currentRow + 1;
      rowWidth.add(tw);
      rowHeight.add(th);
    }

    // Compute row Y origins.
    final rowY = <double>[];
    var y = 0.0;
    for (var r = 0; r < rowHeight.length; r++) {
      rowY.add(y);
      y += rowHeight[r];
      if (r < rowHeight.length - 1) y += _runSpacing;
    }
    final totalHeight = y;

    // Position leading children left-to-right with center vertical alignment.
    final cursorX = List<double>.filled(rowHeight.length, 0);
    for (var i = 0; i < leading.length; i++) {
      final r = rowIndex[i];
      final isFirst = cursorX[r] == 0;
      final x = isFirst ? 0.0 : cursorX[r] + _spacing;
      final h = leading[i].size.height;
      final dy = rowY[r] + (rowHeight[r] - h) / 2;
      _pd(leading[i]).offset = Offset(x, dy);
      cursorX[r] = x + leading[i].size.width;
    }

    // Pin trailing child to the right edge of its row.
    final boundedWidth = maxWidth.isFinite
        ? maxWidth
        : (cursorX[trailingRow] +
              (cursorX[trailingRow] > 0 ? _spacing : 0) +
              tw);
    final tx = boundedWidth - tw;
    final ty = rowY[trailingRow] + (rowHeight[trailingRow] - th) / 2;
    _pd(trailing).offset = Offset(tx, ty);

    size = constraints.constrain(Size(boundedWidth, totalHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    var width = 0.0;
    var c = firstChild;
    while (c != null) {
      width = math.max(width, c.getMinIntrinsicWidth(double.infinity));
      c = _pd(c).nextSibling;
    }
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var width = 0.0;
    var c = firstChild;
    while (c != null) {
      width += c.getMaxIntrinsicWidth(double.infinity);
      c = _pd(c).nextSibling;
    }
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    var height = 0.0;
    var c = firstChild;
    while (c != null) {
      height = math.max(height, c.getMaxIntrinsicHeight(width));
      c = _pd(c).nextSibling;
    }
    return height;
  }
}

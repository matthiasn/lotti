import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A custom layout widget that behaves like Row with MainAxisAlignment.spaceBetween
/// when children fit on one line, but wraps like Wrap when they don't.
class SpaceBetweenWrap extends MultiChildRenderObjectWidget {
  const SpaceBetweenWrap({
    required this.spacing,
    required this.runSpacing,
    required super.children,
    super.key,
  });
  final double spacing;
  final double runSpacing;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderSpaceBetweenWrap(
      spacing: spacing,
      runSpacing: runSpacing,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderSpaceBetweenWrap renderObject) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing;
  }
}

class RenderSpaceBetweenWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, FlexParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, FlexParentData> {
  RenderSpaceBetweenWrap({
    required double spacing,
    required double runSpacing,
  })  : _spacing = spacing,
        _runSpacing = runSpacing;

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing != value) {
      _spacing = value;
      markNeedsLayout();
    }
  }

  double _runSpacing;
  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing != value) {
      _runSpacing = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! FlexParentData) {
      child.parentData = FlexParentData();
    }
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    final maxWidth = constraints.maxWidth;

    // First pass: measure all children
    final childSizes = <Size>[];
    double totalChildrenWidth = 0;
    double maxChildHeight = 0;

    var child = firstChild;
    while (child != null) {
      child.layout(constraints.loosen(), parentUsesSize: true);
      final size = child.size;
      childSizes.add(size);
      totalChildrenWidth += size.width;
      maxChildHeight =
          maxChildHeight > size.height ? maxChildHeight : size.height;
      child = childAfter(child);
    }

    final childCount = childSizes.length;
    if (childCount == 0) {
      size = constraints.smallest;
      return;
    }

    // Check if all children fit on one line with minimum spacing
    final minRequiredWidth = totalChildrenWidth + (childCount - 1) * spacing;

    if (minRequiredWidth <= maxWidth) {
      // Use spaceBetween layout (single row)
      final availableSpace = maxWidth - totalChildrenWidth;
      final spaceBetween =
          childCount > 1 ? availableSpace / (childCount - 1) : 0;

      double x = 0;
      child = firstChild;
      var index = 0;
      while (child != null) {
        (child.parentData! as FlexParentData).offset = Offset(x, 0);
        x += childSizes[index].width + spaceBetween;
        child = childAfter(child);
        index++;
      }

      size = constraints.constrain(Size(maxWidth, maxChildHeight));
    } else {
      // Use wrap layout
      double x = 0;
      double y = 0;
      double rowHeight = 0;
      double maxRowWidth = 0;

      child = firstChild;
      var index = 0;
      while (child != null) {
        final size = childSizes[index];

        // Check if we need to wrap to next line
        if (x > 0 && x + size.width > maxWidth) {
          y += rowHeight + runSpacing;
          x = 0;
          rowHeight = 0;
        }

        (child.parentData! as FlexParentData).offset = Offset(x, y);

        x += size.width + spacing;
        rowHeight = rowHeight > size.height ? rowHeight : size.height;
        maxRowWidth = maxRowWidth > x ? maxRowWidth : x;

        child = childAfter(child);
        index++;
      }

      final finalWidth =
          maxRowWidth > spacing ? maxRowWidth - spacing : maxRowWidth;
      final finalHeight = y + rowHeight;
      size = constraints.constrain(Size(finalWidth, finalHeight));
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }
}

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// How tall a timeline slot usually is: the mean, over every slot the list
/// has laid out, of the least height each was seen at.
///
/// The least, so a row the reader opened still counts as the folded row it
/// was; every slot, so headings and rows weigh as they occur. A row that
/// grows for good — its words arriving — keeps its earlier height here,
/// which is close enough for a guess.
///
/// Heights hold for the layout they were measured under: at another width
/// or text scale every row is a different height, so the first measurement
/// under a new [measure] `layout` forgets the ones before it.
class TimelineSlotExtents {
  final _leanest = <Key, double>{};
  double _sum = 0;
  Object? _layout;

  void measure(Key slot, double height, {required Object layout}) {
    if (layout != _layout) {
      _layout = layout;
      _leanest.clear();
      _sum = 0;
    }
    final seen = _leanest[slot];
    if (seen != null && seen <= height) return;
    _sum += height - (seen ?? 0);
    _leanest[slot] = height;
  }

  /// The usual height; only asked for once a slot has been measured.
  double get mean => _sum / _leanest.length;
}

/// Reports the size its [child] is laid out at.
class MeasuredSlot extends SingleChildRenderObjectWidget {
  const MeasuredSlot({required this.onSize, super.child, super.key});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasuredSlot(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    // The override narrows the parameter to the object this widget creates.
    // ignore: library_private_types_in_public_api
    _RenderMeasuredSlot renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderMeasuredSlot extends RenderProxyBox {
  _RenderMeasuredSlot(this.onSize);

  ValueChanged<Size> onSize;

  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
  }
}

/// Estimates the rows not built yet from [TimelineSlotExtents] rather than
/// from the rows on stage right now.
///
/// A lazy list guesses its length as the on-stage rows' average height times
/// the rows left. A recording's opened words are twenty rows tall, so while
/// one was on stage — the newest, at the top, as the reader scrolled back up
/// to it — the page claimed many times its real length: the scrollbar thumb
/// shrank and leapt, and dragging it or jumping to the end overshot.
class TimelineChildDelegate extends SliverChildBuilderDelegate {
  TimelineChildDelegate(
    super.builder, {
    required this.extents,
    required int super.childCount,
    super.findChildIndexCallback,
  });

  final TimelineSlotExtents extents;

  @override
  double estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) => trailingScrollOffset + extents.mean * (childCount! - lastIndex - 1);
}

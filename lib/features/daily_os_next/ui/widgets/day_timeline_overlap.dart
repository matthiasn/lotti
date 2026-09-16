/// Overlap layout for one lane of the Day timeline.
///
/// Blocks that share a stretch of the day used to stack full-width in start
/// order, so a call taken during a tracked session painted over the session
/// and took its taps. This module decides, from the blocks' spans alone,
/// where each block sits across the lane:
///
/// - A block that starts a peer window or more after a block still running
///   is **raised** one level above it: inset from the left of the block it
///   rises above so that block keeps its stripe and title, and painted on
///   top. Nested interruptions rise one level each.
/// - Blocks that start within the same window are **peers**: stacked, one
///   would hide the other's title, so they share the level side by side in
///   columns, longest first.
///
/// Pure Dart, like the folding model, so the clustering rules and the pixel
/// geometry ([resolveTimelineBlockInsets]) are unit-testable; the pane owns
/// the token values it feeds in.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';

/// Insets from a lane's left and right edges, in px.
typedef TimelineBlockInsets = ({double left, double right});

/// The most of its parent's width a raised block may give up to its indent.
/// A cascade therefore narrows geometrically and never to nothing: every
/// raised block keeps at least half of the block it rises above.
const double kTimelineMaxIndentOfParentWidth = 0.5;

/// Where one block sits across its lane once overlaps are resolved.
///
/// Only [layoutTimelineBlocks] builds these in production; the constructor
/// asserts what it guarantees, because a slot with no columns or a column
/// outside them would resolve to NaN geometry in [horizontalInsets].
@immutable
class TimelineBlockSlot {
  const TimelineBlockSlot({
    required this.block,
    required this.depth,
    required this.column,
    required this.columnCount,
    this.parentId,
  }) : assert(depth >= 0, 'depth must not be negative'),
       assert(columnCount >= 1, 'a slot always has at least one column'),
       assert(
         column >= 0 && column < columnCount,
         'column must lie inside columnCount',
       ),
       assert(
         (depth == 0) == (parentId == null),
         'a raised slot names the block it rises above; a floor slot none',
       );

  final TimeBlock block;

  /// How many levels of earlier-started, still-running blocks this one sits
  /// on. `0` is the lane floor.
  final int depth;

  /// The column this block takes among the peers of its level.
  final int column;

  /// How many columns the level ended up with; every peer reports the same.
  final int columnCount;

  /// The id of the block one level down that this slot's level is measured
  /// from: the leftmost column still running when the level opened. Null on
  /// the floor. A raised block is indented from *that* block's left edge, so
  /// rising above the right-hand peer of a pair leaves the left-hand peer
  /// alone and keeps the right-hand one's stripe.
  final String? parentId;

  /// Whether the block is painted on top of a block it overlaps.
  bool get isRaised => depth > 0;

  /// The block's insets from the lane's left and right edges.
  ///
  /// [edgeInset] is the gutter every floor block keeps from the lane edges,
  /// [indent] how far a raised level starts right of [parent] — at most
  /// [kTimelineMaxIndentOfParentWidth] of the parent's width — and
  /// [columnGap] the space between peer columns. A raised level runs to the
  /// lane's right gutter whatever its parent's right edge, so the title has
  /// the room. The result always satisfies `left >= 0`, `right >= 0` and
  /// `left + right <= laneWidth`, so a `Positioned` built from it never asks
  /// for a negative width. [resolveTimelineBlockInsets] supplies [parent]
  /// for a whole lane; a null parent lays the slot out on the floor.
  TimelineBlockInsets horizontalInsets({
    required double laneWidth,
    required double edgeInset,
    required double indent,
    required double columnGap,
    TimelineBlockInsets? parent,
  }) {
    final double regionLeft;
    if (parent == null) {
      regionLeft = edgeInset;
    } else {
      final parentWidth = math.max<double>(
        0,
        laneWidth - parent.left - parent.right,
      );
      regionLeft =
          parent.left +
          math.min(indent, parentWidth * kTimelineMaxIndentOfParentWidth);
    }
    final available = math.max<double>(0, laneWidth - edgeInset - regionLeft);
    final columnWidth = math.max<double>(
      0,
      (available - columnGap * (columnCount - 1)) / columnCount,
    );
    final left = math.min(
      laneWidth,
      regionLeft + column * (columnWidth + columnGap),
    );
    final right = math.max<double>(0, laneWidth - left - columnWidth);
    return (left: left, right: right);
  }

  @override
  String toString() =>
      'TimelineBlockSlot(${block.id}, depth: $depth, '
      'column: $column/$columnCount'
      '${parentId == null ? '' : ', above: $parentId'})';
}

/// Resolves [blocks] into slots, returned in paint order: lane-floor blocks
/// first, deeper levels later, so a `Stack` built in this order paints every
/// raised block above what it interrupts — and every slot's parent precedes
/// it, which [resolveTimelineBlockInsets] relies on.
///
/// [peerWindow] is how long after a block's start another block must begin
/// before the first one's title has had room to render above it; the pane
/// derives it from the readable block height and the current zoom. Two
/// blocks starting the same minute are peers whatever the window.
List<TimelineBlockSlot> layoutTimelineBlocks(
  List<TimeBlock> blocks, {
  required Duration peerWindow,
}) {
  final ordered = blocks.toList()..sort(_byStartThenLongestThenId);
  final levels = <_CascadeLevel>[];
  final placed = <_PlacedBlock>[];

  for (final (order, block) in ordered.indexed) {
    // Levels with nothing still running at this start are over; drop them
    // from the deepest up. Dropping every level ends the cluster.
    var deepestActive = -1;
    for (var i = 0; i < levels.length; i++) {
      if (levels[i].isActiveAt(block.start)) deepestActive = i;
    }
    levels.length = deepestActive + 1;

    final _CascadeLevel level;
    if (levels.isEmpty) {
      level = _CascadeLevel(anchor: block.start, parentId: null);
      levels.add(level);
    } else {
      final sinceAnchor = block.start.difference(levels.last.anchor);
      if (sinceAnchor == Duration.zero || sinceAnchor < peerWindow) {
        level = levels.last;
      } else {
        level = _CascadeLevel(
          anchor: block.start,
          // The deepest level is active here, so it has a running column.
          parentId: levels.last.leftmostRunningBlockId(block.start),
        );
        levels.add(level);
      }
    }

    placed.add(
      _PlacedBlock(
        block: block,
        order: order,
        depth: levels.length - 1,
        column: level.claimColumn(block),
        level: level,
      ),
    );
  }

  placed.sort((a, b) {
    final byDepth = a.depth.compareTo(b.depth);
    return byDepth != 0 ? byDepth : a.order.compareTo(b.order);
  });
  return [
    for (final entry in placed)
      TimelineBlockSlot(
        block: entry.block,
        depth: entry.depth,
        column: entry.column,
        columnCount: entry.level.columnCount,
        parentId: entry.level.parentId,
      ),
  ];
}

/// The insets of every slot in [slots], by block id — each raised slot
/// measured from its parent's, which is why [slots] must be in the paint
/// order [layoutTimelineBlocks] returns (a parent always precedes its
/// children there). The token arguments are those of
/// [TimelineBlockSlot.horizontalInsets].
Map<String, TimelineBlockInsets> resolveTimelineBlockInsets(
  List<TimelineBlockSlot> slots, {
  required double laneWidth,
  required double edgeInset,
  required double indent,
  required double columnGap,
}) {
  final insets = <String, TimelineBlockInsets>{};
  for (final slot in slots) {
    final parentId = slot.parentId;
    insets[slot.block.id] = slot.horizontalInsets(
      laneWidth: laneWidth,
      edgeInset: edgeInset,
      indent: indent,
      columnGap: columnGap,
      parent: parentId == null ? null : insets[parentId],
    );
  }
  return insets;
}

int _byStartThenLongestThenId(TimeBlock a, TimeBlock b) {
  final byStart = a.start.compareTo(b.start);
  if (byStart != 0) return byStart;
  final byLongest = b.end.compareTo(a.end);
  if (byLongest != 0) return byLongest;
  return a.id.compareTo(b.id);
}

/// A block whose end precedes its start holds no time; it is placed at its
/// start and keeps nothing open.
DateTime _endOf(TimeBlock block) =>
    block.end.isBefore(block.start) ? block.start : block.end;

/// One level of the cascade: the blocks that started within one peer window
/// of its [anchor], packed into columns.
class _CascadeLevel {
  _CascadeLevel({required this.anchor, required this.parentId});

  /// Start of the level's first block; peers are judged against it, not
  /// against whichever peer came last, so a chain of near-starts cannot
  /// creep a level indefinitely.
  final DateTime anchor;

  /// See [TimelineBlockSlot.parentId]. Fixed when the level opens, so every
  /// peer of the level shares one region and their columns agree.
  final String? parentId;

  /// When the latest block in each column ends, and which block that is.
  final List<DateTime> _columnEnds = [];
  final List<String> _columnBlockIds = [];

  int get columnCount => _columnEnds.length;

  bool isActiveAt(DateTime time) => _columnEnds.any((end) => end.isAfter(time));

  /// The block in the leftmost column still running at [time], or null when
  /// the level is over by then.
  String? leftmostRunningBlockId(DateTime time) {
    for (var i = 0; i < _columnEnds.length; i++) {
      if (_columnEnds[i].isAfter(time)) return _columnBlockIds[i];
    }
    return null;
  }

  /// The first column free at the block's start, or a new one.
  int claimColumn(TimeBlock block) {
    for (var i = 0; i < _columnEnds.length; i++) {
      if (!_columnEnds[i].isAfter(block.start)) {
        _columnEnds[i] = _endOf(block);
        _columnBlockIds[i] = block.id;
        return i;
      }
    }
    _columnEnds.add(_endOf(block));
    _columnBlockIds.add(block.id);
    return _columnEnds.length - 1;
  }
}

class _PlacedBlock {
  const _PlacedBlock({
    required this.block,
    required this.order,
    required this.depth,
    required this.column,
    required this.level,
  });

  final TimeBlock block;
  final int order;
  final int depth;
  final int column;
  final _CascadeLevel level;
}

import 'dart:collection';

import 'package:lotti/database/sync_db.dart';

typedef _GapRange = ({String hostId, int startCounter, int endCounter});

/// Collects detected sequence gaps as compact `(hostId, start..end)` ranges
/// and exposes them, lazily, as a flat per-counter list.
///
/// Storing ranges instead of individual counters keeps memory bounded even for
/// a pathological jump of millions of counters; [toGapList] returns a lazy view
/// that expands ranges to `(hostId, counter)` pairs only as they are iterated.
class GapAccumulator {
  final List<_GapRange> _ranges = [];
  int _count = 0;

  bool get isNotEmpty => _count > 0;
  int get count => _count;

  void addRange({
    required String hostId,
    required int startCounter,
    required int endCounter,
  }) {
    if (endCounter < startCounter) return;
    _ranges.add((
      hostId: hostId,
      startCounter: startCounter,
      endCounter: endCounter,
    ));
    _count += endCounter - startCounter + 1;
  }

  List<({String hostId, int counter})> toGapList() => _GapEntriesView(_ranges);
}

class _GapEntriesView extends ListBase<({String hostId, int counter})> {
  _GapEntriesView(List<_GapRange> ranges)
    : _ranges = List.unmodifiable(ranges),
      _rangeEnds = _buildRangeEnds(ranges),
      _length = _computeLength(ranges);

  final List<_GapRange> _ranges;
  final List<int> _rangeEnds;
  final int _length;

  static List<int> _buildRangeEnds(List<_GapRange> ranges) {
    final ends = <int>[];
    var total = 0;
    for (final range in ranges) {
      total += range.endCounter - range.startCounter + 1;
      ends.add(total);
    }
    return ends;
  }

  static int _computeLength(List<_GapRange> ranges) {
    var total = 0;
    for (final range in ranges) {
      total += range.endCounter - range.startCounter + 1;
    }
    return total;
  }

  @override
  int get length => _length;

  @override
  set length(int newLength) {
    throw UnsupportedError('GapEntriesView is read-only');
  }

  @override
  ({String hostId, int counter}) operator [](int index) {
    RangeError.checkValidIndex(index, this, null, _length);
    var low = 0;
    var high = _rangeEnds.length - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (index < _rangeEnds[mid]) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }

    final rangeIndex = low;
    final previousEnd = rangeIndex == 0 ? 0 : _rangeEnds[rangeIndex - 1];
    final range = _ranges[rangeIndex];
    return (
      hostId: range.hostId,
      counter: range.startCounter + index - previousEnd,
    );
  }

  @override
  void operator []=(int index, ({String hostId, int counter}) value) {
    throw UnsupportedError('GapEntriesView is read-only');
  }
}

// Delegates to [SyncSequenceStatusX.isResolved] (the single source of truth in
// sync_db.dart) so the watermark "resolved" set is defined in exactly one place.
bool isResolvedSequenceStatusIndex(int status) =>
    status >= 0 &&
    status < SyncSequenceStatus.values.length &&
    SyncSequenceStatus.values[status].isResolved;

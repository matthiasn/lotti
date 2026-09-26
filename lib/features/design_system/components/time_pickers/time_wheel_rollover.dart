/// Clock arithmetic and per-column state shared by the design-system time
/// drums, so a minute drum rolling past 59 → 00 (or back past 00 → 59) carries
/// into the hour drum — and, on a 12-hour drum, across the AM/PM column — the
/// way a real clock does.
library;

import 'package:flutter/widgets.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// The hour-side state of a time drum: the hour row and, for 12-hour drums,
/// the AM/PM row (0 = AM, 1 = PM).
///
/// A 24-hour drum's `hourIndex` is the hour itself (0–23) and its
/// `periodIndex` is always 0. A 12-hour drum's `hourIndex` is 0–11 for the
/// labels 1–12.
typedef TimeWheelHour = ({int hourIndex, int periodIndex});

/// Whether a looping wheel of [itemCount] rows wrapped when its selected row
/// moved from [from] to [to] (both `0..itemCount-1`): 1 when it moved
/// forwards past its last row into row 0, -1 when it moved backwards past row
/// 0 into its last row, 0 otherwise.
///
/// The wheel is assumed to have moved the shorter way round, which holds for
/// every scroll frame: `ListWheelScrollView` only reports normalized rows, and
/// never skips half a turn between two reports.
int wheelWrapBetween(int from, int to, int itemCount) =>
    _floorDiv(from + shortestWheelDelta(from, to, itemCount), itemCount);

/// The drum rows showing [hour24] (0–23).
TimeWheelHour timeWheelHourFrom24(int hour24, {required bool use24h}) {
  if (use24h) return (hourIndex: hour24, periodIndex: 0);
  final hourOfPeriod = hour24 % 12;
  return (
    hourIndex: (hourOfPeriod == 0 ? 12 : hourOfPeriod) - 1,
    periodIndex: hour24 < 12 ? 0 : 1,
  );
}

/// The hour of day (0–23) the drum rows in [wheel] show.
int timeWheelHourTo24(TimeWheelHour wheel, {required bool use24h}) => use24h
    ? wheel.hourIndex
    : (wheel.hourIndex + 1) % 12 + wheel.periodIndex * 12;

/// [wheel] moved by [hours] (negative moves back), wrapping around midnight.
///
/// The date is deliberately not touched: the drums pick a time of day, and
/// their callers own the date.
TimeWheelHour rollTimeWheelHour(
  TimeWheelHour wheel,
  int hours, {
  required bool use24h,
}) => timeWheelHourFrom24(
  (timeWheelHourTo24(wheel, use24h: use24h) + hours) % 24,
  use24h: use24h,
);

/// The signed row distance from [from] to [to] on a looping wheel of
/// [itemCount] rows, taking the shorter way round (forwards on a tie).
int shortestWheelDelta(int from, int to, int itemCount) {
  final forward = (to - from) % itemCount;
  return forward > itemCount ~/ 2 ? forward - itemCount : forward;
}

/// A looping column moved onto row `index` by wrapping: `direction` is 1 when
/// it went forwards from its last row into row 0, -1 when it went backwards
/// from row 0 into its last row.
typedef TimeWheelWrapped = void Function(int index, int direction);

/// The state behind one drum column: its scroll controller, the selected row,
/// how many times a looping column has wrapped, and the programmatic
/// animation a neighbouring column's wrap asks for.
///
/// Wire [handleSelectedItemChanged] to the wheel's `onSelectedItemChanged`
/// and use [controller] as its controller. [selectedIndex] always follows the
/// row under the selection band; [onSelectedIndexChanged] only reports rows
/// the user chose, plus the row a programmatic animation settled on — the
/// rows it passes on the way are not reported, because whoever started it
/// already holds the destination.
class TimeWheelColumnDriver {
  TimeWheelColumnDriver({
    required this.itemCount,
    required int initialIndex,
    required this.onSelectedIndexChanged,
    this.onWrapped,
    this.looping = true,
  }) : selectedIndex = ValueNotifier(initialIndex) {
    controller = FixedExtentScrollController(
      initialItem: looping
          ? itemCount * _loopingTurns + initialIndex
          : initialIndex,
    );
  }

  /// How many turns a looping column starts in, so it can be scrolled back
  /// past row 0 without the raw index going negative in practice.
  static const _loopingTurns = 1000;

  final int itemCount;
  final bool looping;

  /// Called with the row the user chose, and with the row a programmatic
  /// [animateToIndex] settled on.
  final ValueChanged<int> onSelectedIndexChanged;

  /// Called **instead of** [onSelectedIndexChanged] for a row change that
  /// wraps, so the owner learns the new row and the wrap together and can
  /// roll the hour before anything reports the time. Without it, a wrapping
  /// change goes to [onSelectedIndexChanged] like any other.
  final TimeWheelWrapped? onWrapped;

  late final FixedExtentScrollController controller;

  /// The row currently under the selection band, normalized to
  /// `0..itemCount-1`.
  final ValueNotifier<int> selectedIndex;

  /// The controller item an [animateToIndex] call is heading for, while it
  /// runs.
  int? _programmaticTarget;

  /// Bumped by every [animateToIndex] animation, so a superseded one — whose
  /// future completes when the next one interrupts it — can tell it is stale
  /// even when a later call aims at the same item.
  var _animationGeneration = 0;
  var _disposed = false;

  /// The row [delta] rows from the current one, or `null` when a non-looping
  /// column has no such row.
  int? indexFor(int delta) {
    if (looping) return (selectedIndex.value + delta) % itemCount;
    final next = selectedIndex.value + delta;
    return next >= 0 && next < itemCount ? next : null;
  }

  /// Jumps [delta] rows (keyboard and accessibility adjustment), wrapping
  /// like a drag would. Returns false when a non-looping column has no row
  /// there.
  bool stepBy(int delta) {
    final next = indexFor(delta);
    if (next == null) return false;
    controller.jumpToItem(
      looping ? controller.selectedItem + delta : next,
    );
    handleSelectedItemChanged(next);
    return true;
  }

  /// Records that the wheel now shows row [index], reporting a user-chosen
  /// row — together with its wrap, when it wrapped. Indices outside
  /// `0..itemCount-1` are normalized.
  void handleSelectedItemChanged(int index) {
    final normalized = looping ? index % itemCount : index;
    final previous = selectedIndex.value;
    if (previous == normalized) return;
    selectedIndex.value = normalized;
    final wrap = looping
        ? wheelWrapBetween(previous, normalized, itemCount)
        : 0;
    final wrapped = onWrapped;
    if (wrap != 0 && wrapped != null) {
      // One callback for both: reporting the row and the wrap separately
      // lets whichever goes first announce a time that is half updated.
      wrapped(normalized, wrap);
    } else if (_programmaticTarget == null) {
      onSelectedIndexChanged(normalized);
    }
  }

  /// Moves the column to row [index], taking the shorter way round a looping
  /// column. Repeated calls chain from the previous destination, so a burst
  /// of wraps is not lost to an animation still in flight. With [animate]
  /// false (reduced motion) the column jumps.
  void animateToIndex(int index, {required bool animate}) {
    if (!controller.hasClients) return;
    final base =
        _programmaticTarget ??
        (looping ? controller.selectedItem : selectedIndex.value);
    final target = looping
        ? base + shortestWheelDelta(base % itemCount, index, itemCount)
        : index;
    if (target == base) return;
    if (!animate) {
      controller.jumpToItem(target);
      handleSelectedItemChanged(index);
      return;
    }
    _programmaticTarget = target;
    final generation = ++_animationGeneration;
    controller
        .animateToItem(
          target,
          duration: MotionDurations.medium1,
          curve: MotionCurves.standard,
        )
        .whenComplete(() {
          // A newer call or the user's own drag took over; it reports.
          if (_disposed || generation != _animationGeneration) return;
          _programmaticTarget = null;
          // Report where the column actually settled: the destination, unless
          // the user grabbed the wheel mid-animation.
          onSelectedIndexChanged(selectedIndex.value);
        });
  }

  void dispose() {
    _disposed = true;
    controller.dispose();
    selectedIndex.dispose();
  }
}

int _floorDiv(int value, int divisor) => (value - value % divisor) ~/ divisor;

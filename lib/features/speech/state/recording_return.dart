import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scroll positions pages report while a take could start on them, and the
/// one restore owed after the recording strip's way back.
///
/// A page opts in by reporting its primary scroll offset under its route
/// (`RecordingOriginScrollAnchor`). A take started there captures that
/// offset in its origin; going back asks the page to restore it once, on
/// its first frame. A page that does not opt in lands at its top.
final recordingOriginScrollProvider = Provider<RecordingOriginScroll>(
  (ref) => RecordingOriginScroll(),
  name: 'recordingOriginScrollProvider',
);

class RecordingOriginScroll {
  final Map<String, double> _offsets = {};
  ({String route, double offset})? _pending;

  /// Records how far the page at [route] has scrolled.
  void report(String route, double offset) => _offsets[route] = offset;

  /// Forgets [route]'s offset, when its page goes away.
  void forget(String route) => _offsets.remove(route);

  /// The last offset the page at [route] reported, if it reported one.
  double? offsetFor(String route) => _offsets[route];

  /// Asks the page at [route] to come back at [offset].
  void requestRestore(String route, double offset) =>
      _pending = (route: route, offset: offset);

  /// The offset owed to the page at [route], handed over once: a second
  /// call, or a call for another route, gets null.
  double? takeRestore(String route) {
    final pending = _pending;
    if (pending == null || pending.route != route) return null;
    _pending = null;
    return pending.offset;
  }
}

/// The subject the user was just taken back to by the recording strip,
/// with a serial so the same subject twice is two arrivals. The subject's
/// live record button highlights once for each.
typedef RecordingArrival = ({String subjectId, int serial});

final recordingArrivalProvider =
    NotifierProvider<RecordingArrivalController, RecordingArrival?>(
      RecordingArrivalController.new,
      name: 'recordingArrivalProvider',
    );

class RecordingArrivalController extends Notifier<RecordingArrival?> {
  @override
  RecordingArrival? build() => null;

  /// Marks an arrival back at [subjectId].
  void arrive(String subjectId) =>
      state = (subjectId: subjectId, serial: (state?.serial ?? 0) + 1);
}

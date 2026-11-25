import 'package:freezed_annotation/freezed_annotation.dart';

part 'recording_origin.freezed.dart';

/// Where a take was started, so the recording strip can say what it is for
/// and take the user back there in one tap.
@freezed
abstract class RecordingOrigin with _$RecordingOrigin {
  const factory RecordingOrigin({
    /// The app route on screen when the take started, as the navigation
    /// service reports it (`/tasks/<id>`, `/calendar`, …).
    required String route,

    /// The entry the take is linked to — the same value as the recorder's
    /// `linkedId`; null for a voice note that stands on its own.
    String? subjectId,

    /// How far the origin page had scrolled, for a page that reports it;
    /// null where the page does not, which lands at its top.
    double? scrollOffset,
  }) = _RecordingOrigin;
}

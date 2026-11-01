import 'package:flutter/widgets.dart';
import 'package:lotti/widgets/transcript/transcript_status.dart';

/// Presentation-only view models for the event detail page's vertical
/// timeline.
///
/// Deliberately free of persistence and feature dependencies: a caller resolves
/// its own entities into these plain, immutable shapes and the widgets render
/// them, which lets a screenshot harness drive the component with real images
/// and players without touching a database. Events are its only caller: Goals
/// and People render their timelines on the design system's
/// `DesignSystemTimelineRow`, and moving Events onto it too is planned in
/// `docs/implementation_plans/2026-11-01_event_agent_record.md`.
///
/// Anything the component cannot render generically — an audio player, a
/// verdict pill — arrives as a caller-supplied [Widget]. The component owns the
/// *chrome* (rail, dot, connector, time label, kind label, open affordance) and
/// the shared behaviours (folded words, transcription status, paging);
/// the caller owns what its own domain looks like.

/// A single photo on a [TimelineBeatContent.photos] beat.
@immutable
class TimelinePhoto {
  const TimelinePhoto(this.image, {this.cropX = 0.5});

  final ImageProvider image;
  final double cropX;
}

/// The body of one beat.
///
/// The first four variants are the shapes Events established. `custom` is the
/// escape hatch: a caller-supplied body rendered inside the shared chrome, so a
/// feature can add a beat kind — a reflection verdict, a questionnaire result,
/// a milestone — without editing this component.
@immutable
sealed class TimelineBeatContent {
  const TimelineBeatContent();

  /// Plain prose.
  const factory TimelineBeatContent.text(String text) = TimelineTextContent;

  /// A lead frame plus a supporting cluster.
  const factory TimelineBeatContent.photos({
    required List<TimelinePhoto> photos,
    String? caption,
  }) = TimelinePhotosContent;

  /// A recording. [player] is supplied by the caller so this library needs no
  /// audio dependency; the component owns the transcript's fold and its
  /// [TranscriptStatus] affordances.
  const factory TimelineBeatContent.audio({
    required Widget player,
    String? transcript,
    TranscriptStatus transcriptStatus,
  }) = TimelineAudioContent;

  /// A span with a start, an end and an elapsed duration.
  const factory TimelineBeatContent.timeSpan({
    required Widget bar,
    String? text,
  }) = TimelineTimeSpanContent;

  /// A caller-supplied body inside the shared chrome.
  const factory TimelineBeatContent.custom(Widget child) =
      TimelineCustomContent;
}

@immutable
class TimelineTextContent extends TimelineBeatContent {
  const TimelineTextContent(this.text);

  final String text;
}

@immutable
class TimelinePhotosContent extends TimelineBeatContent {
  const TimelinePhotosContent({required this.photos, this.caption});

  final List<TimelinePhoto> photos;
  final String? caption;
}

@immutable
class TimelineAudioContent extends TimelineBeatContent {
  const TimelineAudioContent({
    required this.player,
    this.transcript,
    this.transcriptStatus = TranscriptStatus.heard,
  });

  final Widget player;
  final String? transcript;
  final TranscriptStatus transcriptStatus;
}

@immutable
class TimelineTimeSpanContent extends TimelineBeatContent {
  const TimelineTimeSpanContent({required this.bar, this.text});

  final Widget bar;
  final String? text;
}

@immutable
class TimelineCustomContent extends TimelineBeatContent {
  const TimelineCustomContent(this.child);

  final Widget child;
}

/// One dated item on the rail.
@immutable
class TimelineBeat {
  const TimelineBeat({
    required this.timeLabel,
    required this.content,
    this.id,
    this.entryId,
    this.kindLabel,
    this.glyph,
    this.accent,
    this.trailing,
    this.onTap,
  });

  /// Already-formatted clock (or clock-and-date) label. Formatting needs a
  /// locale and the device's 24-hour setting, so it is resolved by the caller
  /// rather than guessed here.
  final String timeLabel;

  final TimelineBeatContent content;

  /// Stable identity for keys, when the caller has one.
  final String? id;

  /// The entry this beat opens. Null means the beat is not navigable — and the
  /// component then renders no chevron and no ink response, so the affordance
  /// can never promise something that does not happen.
  final String? entryId;

  /// Short uppercase label naming the kind ("VOICE CHECK-IN"). Null renders no
  /// label, which is what keeps Events visually unchanged.
  final String? kindLabel;

  /// Glyph drawn inside the rail dot. Null renders the plain dot Events has
  /// always had.
  final IconData? glyph;

  /// Tints the dot and the kind label. Null falls back to the theme's primary,
  /// again preserving the Events appearance.
  final Color? accent;

  /// Caller-supplied widget pinned to the trailing edge of the header row —
  /// a verdict pill, a count. Keeps a beat to ONE tight row where its whole
  /// payload is a status: leading time and kind, trailing state, nothing
  /// stacked beneath. Null renders the header exactly as before.
  final Widget? trailing;

  /// Row-level tap for beats that open something other than a journal entry
  /// (a reflection sheet, a picker). Takes precedence over the [entryId]
  /// navigation; the chevron affordance follows whichever is active.
  final VoidCallback? onTap;
}

/// A labelled run of beats — one day, one month, or an unlabelled single run.
///
/// Grouping is decided by the caller's pure mapping layer, not by the widget: a
/// timeline spanning months needs day dividers, while an event's own timeline
/// spans one day and wants none. A null [label] renders no divider node.
@immutable
class TimelineGroup {
  const TimelineGroup({required this.beats, this.label});

  final String? label;
  final List<TimelineBeat> beats;
}

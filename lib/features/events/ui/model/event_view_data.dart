import 'package:flutter/widgets.dart';
import 'package:lotti/classes/event_status.dart';

/// Presentation-only view models for the Events surfaces.
///
/// These deliberately carry no persistence dependency: a provider resolves a
/// `JournalEvent` plus its linked entries/tasks/cover image into these plain,
/// immutable shapes, and the widgets render them. That keeps the visual layer
/// fully deterministic and trivially testable (and lets screenshot harnesses
/// feed real photos via [ImageProvider] without touching the database).

/// Everything an `EventCard` needs to render one event in the overview, and
/// the essentials the detail hero reuses.
@immutable
class EventCardData {
  const EventCardData({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.status,
    required this.stars,
    required this.categoryColor,
    this.sortDate,
    this.categoryName,
    this.coverImage,
    this.coverCropX = 0.5,
    this.summary,
    this.location,
    this.photoCount = 0,
    this.taskCount = 0,
  });

  final String id;
  final String title;

  /// Pre-formatted, glanceable date (e.g. `Sat, 12 May` or `in 3 weeks`).
  final String dateLabel;

  /// Underlying instant, used by providers for grouping/sorting only.
  final DateTime? sortDate;

  final EventStatus status;
  final double stars;

  final String? categoryName;
  final Color categoryColor;

  /// Cover photo. `null` falls back to a category-tinted gradient + glyph.
  final ImageProvider? coverImage;
  final double coverCropX;

  /// One-line AI/manual summary shown beneath the cover.
  final String? summary;
  final String? location;

  final int photoCount;
  final int taskCount;

  bool get isUpcoming =>
      status == EventStatus.planned || status == EventStatus.tentative;
}

/// A titled group of events in the overview (e.g. `Upcoming`, `2026`).
///
/// A [featured] section renders its events as full-width hero cards (used for
/// Upcoming), so a single item never strands empty grid columns on desktop.
@immutable
class EventSection {
  const EventSection({
    required this.title,
    required this.events,
    this.featured = false,
  });

  final String title;
  final List<EventCardData> events;
  final bool featured;
}

/// A category choice in the overview filter row.
@immutable
class EventCategoryFilter {
  const EventCategoryFilter({
    required this.id,
    required this.label,
    required this.color,
  });

  final String? id; // null = "All"
  final String label;
  final Color color;
}

enum EventTimelineKind { photo, note, audio }

@immutable
class EventPhoto {
  const EventPhoto(this.image, {this.cropX = 0.5});

  final ImageProvider image;
  final double cropX;
}

/// One item on an event's vertical timeline of linked entries.
@immutable
class EventTimelineEntry {
  const EventTimelineEntry({
    required this.timeLabel,
    required this.kind,
    this.entryId,
    this.text,
    this.photos = const [],
    this.durationLabel,
  });

  final String timeLabel;
  final EventTimelineKind kind;

  /// Id of the linked journal entry this beat was built from, so the detail
  /// view can open its source. `null` when the source isn't navigable.
  final String? entryId;

  final String? text;
  final List<EventPhoto> photos;
  final String? durationLabel;
}

/// A prep/follow-up task linked to the event.
@immutable
class EventTaskRef {
  const EventTaskRef({
    required this.title,
    required this.done,
    this.statusLabel,
    this.statusColor,
    this.dueLabel,
  });

  final String title;
  final bool done;
  final String? statusLabel;
  final Color? statusColor;
  final String? dueLabel;
}

/// Everything the detail view renders for one event.
@immutable
class EventDetailData {
  const EventDetailData({
    required this.card,
    this.whenLabel,
    this.summary,
    this.timeline = const [],
    this.tasks = const [],
    this.photos = const [],
  });

  final EventCardData card;

  /// Full date/time line for the facts row (e.g. `Sat, 12 May 2026 · 19:30`).
  final String? whenLabel;
  final String? summary;
  final List<EventTimelineEntry> timeline;
  final List<EventTaskRef> tasks;

  /// Every linked photo, oldest first — the source for the Photos gallery
  /// (a flat grid, distinct from the narrative [timeline]).
  final List<EventPhoto> photos;
}

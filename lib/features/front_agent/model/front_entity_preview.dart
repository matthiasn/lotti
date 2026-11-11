import 'package:collection/collection.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_timeline_models.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:meta/meta.dart';

/// The kinds of entity her chat draws a preview card for.
///
/// Its own set, not the router's destinations: an event is something a tap
/// makes, never somewhere the router sends words, and a day's plan is named
/// by its date rather than an id.
enum FrontEntityKind {
  task,
  event,

  /// A project her words list, or one a tap made.
  project,

  /// A person a turn was handed to.
  person,

  /// The plan of one day, named by its date (`YYYY-MM-DD`).
  dayPlan,
}

/// The id a day's plan is referred to by: its date, `YYYY-MM-DD`.
String frontDayPlanId(DateTime day) => day.ymd;

/// An entity a reply of hers shows as a preview card: which it is, and the
/// title it had when the turn was walked — what the card says until the
/// live preview has loaded, and still says if the entity is gone.
///
/// The thread stores only this, never the preview itself: the card reads
/// the entity as it is now ([FrontEntityPreview]), so a status changed after
/// the turn is shown changed.
@immutable
class FrontEntityReference {
  const FrontEntityReference({
    required this.kind,
    required this.id,
    required this.title,
    this.note,
  });

  final FrontEntityKind kind;
  final String id;
  final String title;

  /// A few words she attached to this card — the time logged on it, why it
  /// is listed — shown on a task's card; null when she gave none.
  final String? note;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'id': id,
    'title': title,
    'note': ?note,
  };

  /// Reads a reference a reply stored; null for a shape this build does
  /// not know, such as a kind a newer build added.
  static FrontEntityReference? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = FrontEntityKind.values.asNameMap()[json['kind']];
    final id = json['id'];
    final title = json['title'];
    if (kind == null || id is! String || id.isEmpty || title is! String) {
      return null;
    }
    final note = json['note'];
    return FrontEntityReference(
      kind: kind,
      id: id,
      title: title,
      note: note is String && note.trim().isNotEmpty ? note.trim() : null,
    );
  }

  /// Reads a stored list, skipping what [fromJson] does not know.
  static List<FrontEntityReference> listFromJson(Object? json) => [
    if (json is List)
      for (final item in json) ?fromJson(item),
  ];

  @override
  bool operator ==(Object other) =>
      other is FrontEntityReference &&
      other.kind == kind &&
      other.id == id &&
      other.title == title &&
      other.note == note;

  @override
  int get hashCode => Object.hash(kind, id, title, note);

  @override
  String toString() => 'FrontEntityReference(${kind.name}, $id, $title)';
}

/// What a glance at an entity shows in her chat, before opening it: what its
/// card draws — a task's glance-level fields; an event, a project or a
/// person as the app's own card or row for it reads them.
@immutable
sealed class FrontEntityPreview {
  const FrontEntityPreview({required this.entityId, required this.entityKind});

  final String entityId;
  final FrontEntityKind entityKind;
}

/// A task as its preview card shows it: its cover, title, its agent's
/// one-liner, status, category, when it is due and how long it is estimated
/// to take.
class FrontTaskPreview extends FrontEntityPreview {
  const FrontTaskPreview({
    required super.entityId,
    required this.title,
    required this.status,
    this.oneLiner,
    this.due,
    this.estimate,
    this.categoryId,
    this.coverArtId,
    this.coverArtCropX = 0.5,
    this.priority = TaskPriority.p2Medium,
  }) : super(entityKind: FrontEntityKind.task);

  final String title;
  final TaskStatus status;

  /// The latest report's one-line subtitle; null when there is none.
  final String? oneLiner;
  final DateTime? due;
  final Duration? estimate;
  final String? categoryId;
  final String? coverArtId;

  /// Horizontal crop of the cover (0 left, 0.5 centre, 1 right).
  final double coverArtCropX;

  /// How urgent it is, shown while it is still to do.
  final TaskPriority priority;

  /// Done or rejected: nothing about it is still to do, so neither when it
  /// is due nor how long it should take is worth showing.
  bool get settled => status is TaskDone || status is TaskRejected;

  @override
  bool operator ==(Object other) =>
      other is FrontTaskPreview &&
      other.entityId == entityId &&
      other.title == title &&
      other.status == status &&
      other.oneLiner == oneLiner &&
      other.due == due &&
      other.estimate == estimate &&
      other.categoryId == categoryId &&
      other.coverArtId == coverArtId &&
      other.coverArtCropX == coverArtCropX &&
      other.priority == priority;

  @override
  int get hashCode => Object.hash(
    entityId,
    title,
    status,
    oneLiner,
    due,
    estimate,
    categoryId,
    coverArtId,
    coverArtCropX,
    priority,
  );

  @override
  String toString() => 'FrontTaskPreview($entityId, $title)';
}

/// An event as its preview card shows it: the event itself, because the
/// card is the event card the app draws everywhere else an event is linked
/// — cover, rating, category, date, status and summary resolved from it and
/// its links the way its own page resolves them, so the two never disagree.
class FrontEventPreview extends FrontEntityPreview {
  FrontEventPreview(this.event)
    : super(entityId: event.meta.id, entityKind: FrontEntityKind.event);

  final JournalEvent event;

  @override
  bool operator ==(Object other) =>
      other is FrontEventPreview && other.event == event;

  @override
  int get hashCode => event.hashCode;

  @override
  String toString() => 'FrontEventPreview($entityId, ${event.data.title})';
}

/// One block of a day's plan, as its card lists it.
@immutable
class FrontPlanBlock {
  const FrontPlanBlock({
    required this.title,
    required this.start,
    required this.end,
    required this.state,
    this.taskId,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final TimeBlockState state;

  /// The task the block is time for, when it is one.
  final String? taskId;

  @override
  bool operator ==(Object other) =>
      other is FrontPlanBlock &&
      other.title == title &&
      other.start == start &&
      other.end == end &&
      other.state == state &&
      other.taskId == taskId;

  @override
  int get hashCode => Object.hash(title, start, end, state, taskId);
}

/// A day's plan as its preview card shows it: the day, and its blocks in the
/// order they run.
class FrontDayPlanPreview extends FrontEntityPreview {
  FrontDayPlanPreview({required this.day, required this.blocks})
    : super(entityId: frontDayPlanId(day), entityKind: FrontEntityKind.dayPlan);

  /// The planned day, at local midnight.
  final DateTime day;
  final List<FrontPlanBlock> blocks;

  @override
  bool operator ==(Object other) =>
      other is FrontDayPlanPreview &&
      other.day == day &&
      const ListEquality<FrontPlanBlock>().equals(other.blocks, blocks);

  @override
  int get hashCode => Object.hash(day, Object.hashAll(blocks));

  @override
  String toString() => 'FrontDayPlanPreview($entityId, ${blocks.length})';
}

/// A project as its preview card shows it: the project, and how many of its
/// tasks there are and how many are done — the row the Projects list draws
/// for it.
class FrontProjectPreview extends FrontEntityPreview {
  FrontProjectPreview({
    required this.project,
    required this.totalTaskCount,
    required this.completedTaskCount,
  }) : super(entityId: project.meta.id, entityKind: FrontEntityKind.project);

  final ProjectEntry project;
  final int totalTaskCount;
  final int completedTaskCount;

  @override
  bool operator ==(Object other) =>
      other is FrontProjectPreview &&
      other.project == project &&
      other.totalTaskCount == totalTaskCount &&
      other.completedTaskCount == completedTaskCount;

  @override
  int get hashCode => Object.hash(project, totalTaskCount, completedTaskCount);

  @override
  String toString() =>
      'FrontProjectPreview($entityId, $completedTaskCount/$totalTaskCount)';
}

/// A person as their preview card shows them: the person, and their newest
/// check-in — the row the People list draws for them.
class FrontPersonPreview extends FrontEntityPreview {
  FrontPersonPreview({required this.person, this.lastCheckIn})
    : super(entityId: person.meta.id, entityKind: FrontEntityKind.person);

  final RelationshipEntry person;

  /// Null for a person with no check-in yet.
  final CheckInEntry? lastCheckIn;

  @override
  bool operator ==(Object other) =>
      other is FrontPersonPreview &&
      other.person == person &&
      other.lastCheckIn == lastCheckIn;

  @override
  int get hashCode => Object.hash(person, lastCheckIn);

  @override
  String toString() => 'FrontPersonPreview($entityId, ${person.data.title})';
}

/// The front agent's one terminal artifact: where each part of what the user
/// said belongs.
///
/// A `dispatch` is a list of [FrontDispatchSegment]s that together cover the
/// user's input. Every segment names a verbatim span of the input by offset,
/// what kind of thing it is, and the destination it belongs to — an existing
/// task, project, goal or person, today's plan, something new, a journal
/// note, or nothing the agent could place. The validator
/// (`front_dispatch_validator.dart`) enforces the shape; the model only
/// proposes it.
library;

/// A match this confident is routed without asking (the day agent's rule,
/// `seeded_directive_content.dart`: `>= 0.75` strong).
const double frontStrongConfidence = 0.75;

/// Below this a destination is not a match at all: the segment is new,
/// a note, or unrouted (`< 0.5` new).
const double frontLowConfidence = 0.5;

/// The most segments one input may split into.
const int frontMaxSegments = 8;

/// The share of the input's non-whitespace characters a gap between spans
/// may hold before it becomes an `unrouted` segment of its own.
const double frontUnroutedGapShare = 0.2;

/// What the user is doing in a segment.
enum FrontSegmentIntent {
  /// Asks for something the destination knows.
  question,

  /// Tells the destination something that happened or is true.
  statement,

  /// Asks the destination to change something.
  instruction;

  static FrontSegmentIntent? fromName(Object? name) =>
      values.where((value) => value.name == name).firstOrNull;
}

/// Where a segment belongs.
enum FrontDestinationKind {
  task('task', needsId: true),
  project('project', needsId: true),
  goal('goal', needsId: true),
  person('person', needsId: true),

  /// Today's plan — the Daily OS refine door.
  day('day'),

  /// Nothing owns it yet; [FrontDispatchSegment.newKind] says what it would
  /// become.
  newThing('new'),

  /// Worth keeping as a note, owned by nothing.
  journal('journal'),

  /// The agent could not place it; it waits in the inbox.
  unrouted('unrouted');

  const FrontDestinationKind(this.wireName, {this.needsId = false});

  /// The name the model writes and the record stores.
  final String wireName;

  /// Whether the destination is one existing thing, named by id.
  final bool needsId;

  static FrontDestinationKind? fromWireName(Object? name) =>
      values.where((value) => value.wireName == name).firstOrNull;
}

/// What a `new` segment would become if the user agrees.
enum FrontNewKind {
  task,
  goal,
  project;

  static FrontNewKind? fromName(Object? name) =>
      values.where((value) => value.name == name).firstOrNull;
}

/// One part of the input and where it goes.
class FrontDispatchSegment {
  const FrontDispatchSegment({
    required this.start,
    required this.end,
    required this.text,
    required this.intent,
    required this.kind,
    required this.confidence,
    this.destinationId,
    this.newKind,
    this.note,
  });

  /// Offsets into the input; `text` is exactly `input.substring(start, end)`.
  final int start;
  final int end;
  final String text;
  final FrontSegmentIntent intent;
  final FrontDestinationKind kind;

  /// The owner's id for a [FrontDestinationKind.needsId] kind, else null.
  final String? destinationId;

  /// For [FrontDestinationKind.newThing]: what it would become.
  final FrontNewKind? newKind;

  /// How sure the model is of the destination, `0..1`; `0` for a segment
  /// the validator inserted.
  final double confidence;

  /// One line the companion says about this segment, if any.
  final String? note;

  /// Whether this segment is routed to one existing thing.
  bool get hasDestination => kind.needsId && destinationId != null;

  Map<String, Object?> toJson() => {
    'start': start,
    'end': end,
    'text': text,
    'intent': intent.name,
    'destination': {
      'kind': kind.wireName,
      if (destinationId != null) 'id': destinationId,
      if (newKind != null) 'newKind': newKind!.name,
    },
    'confidence': confidence,
    if (note != null) 'note': note,
  };

  /// Reads a segment the record stored; null when the shape is not one
  /// [toJson] wrote, so a retired kind degrades to nothing rather than a
  /// crash.
  static FrontDispatchSegment? fromJson(Map<String, Object?> json) {
    final destination = json['destination'];
    final kind = destination is Map<String, Object?>
        ? FrontDestinationKind.fromWireName(destination['kind'])
        : null;
    final intent = FrontSegmentIntent.fromName(json['intent']);
    final start = json['start'];
    final end = json['end'];
    final text = json['text'];
    final confidence = json['confidence'];
    if (kind == null ||
        intent == null ||
        start is! int ||
        end is! int ||
        text is! String ||
        confidence is! num) {
      return null;
    }
    final destinationMap = destination! as Map<String, Object?>;
    return FrontDispatchSegment(
      start: start,
      end: end,
      text: text,
      intent: intent,
      kind: kind,
      confidence: confidence.toDouble(),
      destinationId: destinationMap['id'] as String?,
      newKind: FrontNewKind.fromName(destinationMap['newKind']),
      note: json['note'] as String?,
    );
  }
}

/// A validated dispatch: ordered, disjoint segments covering the input.
class FrontDispatch {
  const FrontDispatch({required this.segments});

  /// Reads a stored dispatch, dropping segments that no longer parse.
  factory FrontDispatch.fromJson(Map<String, Object?> json) {
    final raw = json['segments'];
    return FrontDispatch(
      segments: [
        if (raw is List)
          for (final item in raw)
            if (item is Map<String, Object?>)
              ?FrontDispatchSegment.fromJson(item),
      ],
    );
  }

  final List<FrontDispatchSegment> segments;

  /// The segments routed to an existing thing.
  Iterable<FrontDispatchSegment> get routed =>
      segments.where((segment) => segment.hasDestination);

  /// The segments the agent could not place.
  Iterable<FrontDispatchSegment> get unrouted => segments.where(
    (segment) => segment.kind == FrontDestinationKind.unrouted,
  );

  Map<String, Object?> toJson() => {
    'segments': [for (final segment in segments) segment.toJson()],
  };
}

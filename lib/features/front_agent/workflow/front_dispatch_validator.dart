import 'package:lotti/features/front_agent/model/front_dispatch.dart';

/// Whether a destination the model named exists in the index or in a
/// lookup result this turn.
typedef FrontDestinationCheck =
    bool Function(FrontDestinationKind kind, String id);

/// What validating a `dispatch` call yields: the normalised dispatch, or
/// the one error string the model reads back.
typedef FrontDispatchValidation = ({FrontDispatch? dispatch, String? error});

/// Validates a `dispatch` tool call's arguments against the input it claims
/// to cover.
///
/// The rules the plan states in code, not prompt: at most
/// [frontMaxSegments] segments; spans by offset, ordered and non-overlapping,
/// `text` equal to the input slice, so a repeated or overlapping phrase can
/// never stand in for words the model skipped; a destination id only where
/// [destinationExists] says so; a `new` segment names what it would become;
/// a routed destination at or above [frontLowConfidence]. The spans and the
/// gaps between them partition the input, and any gap holding at least
/// [frontUnroutedGapShare] of its non-whitespace characters becomes an
/// `unrouted` segment of its own, so the words the model left out are kept
/// and shown, never dropped.
FrontDispatchValidation validateFrontDispatch({
  required Map<String, dynamic> args,
  required String input,
  required FrontDestinationCheck destinationExists,
}) {
  final raw = args['segments'];
  if (raw is! List || raw.isEmpty) {
    return (
      dispatch: null,
      error: 'Error: dispatch needs a non-empty segments array.',
    );
  }
  if (raw.length > frontMaxSegments) {
    return (
      dispatch: null,
      error:
          'Error: at most $frontMaxSegments segments; merge parts that '
          'go to the same destination.',
    );
  }

  final segments = <FrontDispatchSegment>[];
  var cursor = 0;
  for (var i = 0; i < raw.length; i++) {
    final item = raw[i];
    if (item is! Map) {
      return (dispatch: null, error: 'Error: segment $i is not an object.');
    }
    final segment = Map<String, dynamic>.from(item);
    final start = segment['start'];
    final end = segment['end'];
    if (start is! int || end is! int) {
      return (
        dispatch: null,
        error: 'Error: segment $i needs integer start and end offsets.',
      );
    }
    if (start < cursor || end <= start || end > input.length) {
      return (
        dispatch: null,
        error:
            'Error: segment $i span [$start, $end) must lie inside the '
            'pending message (length ${input.length}), after the previous '
            'segment, and must not overlap it.',
      );
    }
    final expected = input.substring(start, end);
    if (segment['text'] != expected) {
      return (
        dispatch: null,
        error:
            'Error: segment $i text must equal the pending message '
            'between $start and $end verbatim: "$expected".',
      );
    }
    final intent = FrontSegmentIntent.fromName(segment['intent']);
    if (intent == null) {
      return (
        dispatch: null,
        error:
            'Error: segment $i intent must be one of '
            '${FrontSegmentIntent.values.map((FrontSegmentIntent v) => v.name).join('|')}.',
      );
    }
    final destination = segment['destination'];
    final destinationMap = destination is Map
        ? Map<String, dynamic>.from(destination)
        : const <String, dynamic>{};
    final kind = FrontDestinationKind.fromWireName(destinationMap['kind']);
    if (kind == null) {
      return (
        dispatch: null,
        error:
            'Error: segment $i destination.kind must be one of '
            '${FrontDestinationKind.values.map((FrontDestinationKind v) => v.wireName).join('|')}.',
      );
    }
    final confidence = segment['confidence'];
    if (confidence is! num || confidence < 0 || confidence > 1) {
      return (
        dispatch: null,
        error: 'Error: segment $i confidence must be a number from 0 to 1.',
      );
    }
    String? id;
    FrontNewKind? newKind;
    if (kind.needsId) {
      final rawId = destinationMap['id'];
      id = rawId is String ? rawId.trim() : '';
      if (id.isEmpty) {
        return (
          dispatch: null,
          error: 'Error: segment $i destination ${kind.wireName} needs an id.',
        );
      }
      if (!destinationExists(kind, id)) {
        return (
          dispatch: null,
          error:
              'Error: segment $i names ${kind.wireName}:$id, which is not '
              'in <routing_index> or a lookup result this turn. Use only '
              'listed ids, look the name up, or ask the user.',
        );
      }
      if (confidence < frontLowConfidence) {
        return (
          dispatch: null,
          error:
              'Error: segment $i routes to ${kind.wireName}:$id at '
              'confidence $confidence, below $frontLowConfidence. Below that '
              'a destination is not a match: ask the user, or mark the '
              'segment new, journal or unrouted.',
        );
      }
    } else if (kind == FrontDestinationKind.newThing) {
      newKind = FrontNewKind.fromName(destinationMap['newKind']);
      if (newKind == null) {
        return (
          dispatch: null,
          error:
              'Error: segment $i destination "new" needs newKind, one of '
              '${FrontNewKind.values.map((FrontNewKind v) => v.name).join('|')}.',
        );
      }
    }
    final note = segment['note'];
    segments.add(
      FrontDispatchSegment(
        start: start,
        end: end,
        text: expected,
        intent: intent,
        kind: kind,
        confidence: confidence.toDouble(),
        destinationId: id,
        newKind: newKind,
        note: note is String && note.trim().isNotEmpty ? note.trim() : null,
      ),
    );
    cursor = end;
  }

  return (
    dispatch: FrontDispatch(segments: _withUnroutedGaps(segments, input)),
    error: null,
  );
}

/// The segments with every large gap between them made an `unrouted`
/// segment, so the result partitions the input and the user sees what
/// the model skipped.
List<FrontDispatchSegment> _withUnroutedGaps(
  List<FrontDispatchSegment> segments,
  String input,
) {
  final totalNonWhitespace = _nonWhitespace(input);
  if (totalNonWhitespace == 0) return segments;
  final threshold = frontUnroutedGapShare * totalNonWhitespace;

  final result = <FrontDispatchSegment>[];
  var cursor = 0;
  void gap(int from, int to) {
    if (to <= from) return;
    final slice = input.substring(from, to);
    if (_nonWhitespace(slice) < threshold) return;
    result.add(
      FrontDispatchSegment(
        start: from,
        end: to,
        text: slice,
        intent: FrontSegmentIntent.statement,
        kind: FrontDestinationKind.unrouted,
        confidence: 0,
      ),
    );
  }

  for (final segment in segments) {
    gap(cursor, segment.start);
    result.add(segment);
    cursor = segment.end;
  }
  gap(cursor, input.length);
  return result;
}

int _nonWhitespace(String text) =>
    text.runes.where((rune) => !_isWhitespace(rune)).length;

bool _isWhitespace(int rune) =>
    rune == 0x20 || rune == 0x09 || rune == 0x0A || rune == 0x0D;

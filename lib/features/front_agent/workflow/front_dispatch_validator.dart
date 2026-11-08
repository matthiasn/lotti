import 'package:clock/clock.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_task_draft.dart';

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
/// never stand in for words the model skipped — and where the offsets
/// miscount, the `text` found verbatim after the previous segment places
/// the span instead; a destination id only where
/// [destinationExists] says so; a `new` segment names what it would become;
/// a routed destination at or above [frontLowConfidence]. A `new` task's
/// `task` object is read leniently ([FrontTaskDraft.fromModel]): a field the
/// model got wrong, or a category [categoryExists] does not know, is left
/// out, never fatal, and so is a `followsUpTaskId` [followUpExists] does not
/// know; its start counts back from [now], the routing turn's
/// clock the model saw. The spans and the gaps between them partition the
/// input, and any gap holding at least
/// [frontUnroutedGapShare] of its non-whitespace characters becomes an
/// `unrouted` segment of its own, so the words the model left out are kept
/// and shown, never dropped.
FrontDispatchValidation validateFrontDispatch({
  required Map<String, dynamic> args,
  required String input,
  required FrontDestinationCheck destinationExists,
  bool Function(String categoryId)? categoryExists,
  bool Function(String taskId)? followUpExists,
  DateTime? now,
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
    final text = segment['text'];
    final anchored = _anchored(input, cursor, text);
    var start = segment['start'];
    var end = segment['end'];
    if (start is int &&
        end is int &&
        start >= cursor &&
        end > start &&
        end <= input.length &&
        input.substring(start, end) == text) {
      // The offsets and the words agree: taken as given, so a phrase said
      // twice is the occurrence the model meant.
    } else if (anchored != null) {
      // The words are the user's, verbatim, where the count is not: a model
      // copies text far better than it counts characters (Mistral Large 4
      // put a 63-character message at [0, 54), then at [0, 64)). The words
      // are placed where they stand after the previous segment.
      (start, end) = anchored;
    } else if (start is! int || end is! int) {
      return (
        dispatch: null,
        error: 'Error: segment $i needs integer start and end offsets.',
      );
    } else if (start < cursor || end <= start || end > input.length) {
      return (
        dispatch: null,
        error:
            'Error: segment $i span [$start, $end) must lie inside the '
            'pending message (length ${input.length}), after the previous '
            'segment, and must not overlap it.',
      );
    } else {
      return (
        dispatch: null,
        error:
            'Error: segment $i text must equal the pending message '
            'between $start and $end verbatim: '
            '"${input.substring(start, end)}".',
      );
    }
    final expected = input.substring(start, end);
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
    final task = segment['task'];
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
        task: newKind == FrontNewKind.task && task is Map
            ? FrontTaskDraft.fromModel(
                Map<String, dynamic>.from(task),
                categoryExists: categoryExists ?? (_) => false,
                followUpExists: followUpExists,
                now: now ?? clock.now(),
              )
            : null,
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

  // Several small omissions must not add up to uncovered text: when the
  // gaps together reach the share, every gap that holds a word is kept,
  // not only the ones that reach it alone.
  var gapsTogether = 0;
  var previousEnd = 0;
  for (final segment in segments) {
    gapsTogether += _nonWhitespace(input.substring(previousEnd, segment.start));
    previousEnd = segment.end;
  }
  gapsTogether += _nonWhitespace(input.substring(previousEnd));
  final keepEveryWordedGap = gapsTogether >= threshold;

  final result = <FrontDispatchSegment>[];
  var cursor = 0;
  void gap(int from, int to) {
    if (to <= from) return;
    final slice = input.substring(from, to);
    final keep =
        _nonWhitespace(slice) >= threshold ||
        (keepEveryWordedGap && _hasWord(slice));
    if (!keep) return;
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

/// Where [text] stands in [input] at or after [cursor], its first
/// occurrence there; null when it is not a non-empty string found there.
(int, int)? _anchored(String input, int cursor, Object? text) {
  if (text is! String || text.isEmpty) return null;
  final at = input.indexOf(text, cursor);
  return at < 0 ? null : (at, at + text.length);
}

int _nonWhitespace(String text) =>
    text.runes.where((rune) => !_isWhitespace(rune)).length;

/// Whether [text] holds a letter or a digit — punctuation alone is not a
/// word the user said and is absorbed.
bool _hasWord(String text) => _word.hasMatch(text);

final RegExp _word = RegExp(r'[\p{L}\p{N}]', unicode: true);

bool _isWhitespace(int rune) =>
    rune == 0x20 || rune == 0x09 || rune == 0x0A || rune == 0x0D;

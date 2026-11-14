import 'package:collection/collection.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_points.dart';
import 'package:meta/meta.dart';

/// One entry a point of a journal answer rests on: what to open, how to
/// name it, and the words of it the answer quotes.
@immutable
class FrontCitedSource {
  const FrontCitedSource({
    required this.id,
    required this.kind,
    required this.label,
    required this.date,
    this.quote = '',
    this.transcript = false,
  });

  /// From the piece of evidence the answer cites.
  factory FrontCitedSource.fromEvidence(QueryEvidence evidence) =>
      FrontCitedSource(
        id: evidence.source.id,
        kind: evidence.kind,
        label: evidence.label,
        date: evidence.sourceDate,
        quote: evidence.quote.trim(),
        transcript: evidence.textVersion.startsWith('transcript:'),
      );

  final String id;
  final QuerySourceKind kind;

  /// The entry's own name — for a recording, its file name.
  final String label;
  final DateTime date;
  final String quote;

  /// The quote is from a recording's transcript.
  final bool transcript;

  Map<String, Object> toJson() => {
    'id': id,
    'kind': kind.name,
    'label': label,
    'date': date.toUtc().toIso8601String(),
    if (quote.isNotEmpty) 'quote': quote,
    if (transcript) 'transcript': true,
  };

  /// Reads a stored source; null for a shape this build does not know.
  static FrontCitedSource? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final label = json['label'];
    final kind = QuerySourceKind.values.firstWhereOrNull(
      (kind) => kind.name == json['kind'],
    );
    final date = DateTime.tryParse('${json['date']}');
    final quote = json['quote'];
    if (id is! String || label is! String || kind == null || date == null) {
      return null;
    }
    return FrontCitedSource(
      id: id,
      kind: kind,
      label: label,
      date: date,
      quote: quote is String ? quote : '',
      transcript: json['transcript'] == true,
    );
  }
}

/// One point of a journal answer and the entries it rests on.
@immutable
class FrontCitedPoint {
  const FrontCitedPoint({required this.text, this.sources = const []});

  final String text;
  final List<FrontCitedSource> sources;

  Map<String, Object> toJson() => {
    'text': text,
    if (sources.isNotEmpty)
      'sources': [for (final source in sources) source.toJson()],
  };

  /// Reads a stored point; null for a shape this build does not know.
  static FrontCitedPoint? fromJson(Object? json) {
    if (json is! Map || json['text'] is! String) return null;
    return FrontCitedPoint(
      text: json['text'] as String,
      sources: [
        if (json['sources'] case final List<Object?> sources)
          for (final source in sources) ?FrontCitedSource.fromJson(source),
      ],
    );
  }

  /// [text]'s points, each with the [evidence] it cites: what the
  /// `CitedPoints` component draws for a journal answer.
  static List<FrontCitedPoint> fromAnswer(
    String text,
    List<QueryEvidence> evidence,
  ) => [
    for (final point in queryAnswerPoints(text, evidence.length))
      FrontCitedPoint(
        text: point.text,
        sources: [
          for (final number in point.sources)
            FrontCitedSource.fromEvidence(evidence[number - 1]),
        ],
      ),
  ];

  /// Reads a stored list of points, dropping any it does not know.
  static List<FrontCitedPoint> listFromJson(Object? json) => [
    if (json is List)
      for (final item in json) ?fromJson(item),
  ];
}

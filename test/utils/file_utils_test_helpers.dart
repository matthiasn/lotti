import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';

enum GeneratedPathSegmentShape {
  alpha,
  numeric,
  dashed,
  underscored,
  dotted,
}

enum GeneratedPathSeparator {
  slash,
  backslash,
}

class GeneratedPathSegment {
  const GeneratedPathSegment({
    required this.seed,
    required this.shape,
  });

  final int seed;
  final GeneratedPathSegmentShape shape;

  String get text => switch (shape) {
    GeneratedPathSegmentShape.alpha => 'segment$seed',
    GeneratedPathSegmentShape.numeric => '42$seed',
    GeneratedPathSegmentShape.dashed => 'segment-$seed',
    GeneratedPathSegmentShape.underscored => 'segment_$seed',
    GeneratedPathSegmentShape.dotted => 'segment.$seed.json',
  };

  @override
  String toString() {
    return 'GeneratedPathSegment(seed: $seed, shape: $shape)';
  }
}

class GeneratedAttachmentIndexKey {
  const GeneratedAttachmentIndexKey({
    required this.segments,
    required this.leadingSeparatorCount,
    required this.leadingSeparator,
    required this.innerSeparator,
  });

  final List<GeneratedPathSegment> segments;
  final int leadingSeparatorCount;
  final GeneratedPathSeparator leadingSeparator;
  final GeneratedPathSeparator innerSeparator;

  String get rawPath {
    final leading = hSeparatorText(leadingSeparator) * leadingSeparatorCount;
    return '$leading${segments.map((segment) => segment.text).join(
      hSeparatorText(innerSeparator),
    )}';
  }

  String get expectedKey =>
      '/${segments.map((segment) => segment.text).join('/')}';

  @override
  String toString() {
    return 'GeneratedAttachmentIndexKey('
        'segments: $segments, '
        'leadingSeparatorCount: $leadingSeparatorCount, '
        'leadingSeparator: $leadingSeparator, '
        'innerSeparator: $innerSeparator)';
  }
}

class GeneratedPayloadId {
  const GeneratedPayloadId({
    required this.parts,
    required this.separator,
    required this.prefix,
    required this.suffix,
  });

  final List<GeneratedPathSegment> parts;
  final String separator;
  final String prefix;
  final String suffix;

  String get text =>
      '$prefix${parts.map((part) => part.text).join(separator)}'
      '$suffix';

  String get encoded => Uri.encodeComponent(text);

  @override
  String toString() {
    return 'GeneratedPayloadId('
        'parts: $parts, '
        'separator: $separator, '
        'prefix: $prefix, '
        'suffix: $suffix)';
  }
}

String hSeparatorText(GeneratedPathSeparator separator) {
  return switch (separator) {
    GeneratedPathSeparator.slash => '/',
    GeneratedPathSeparator.backslash => r'\',
  };
}

extension AnyFileUtilsPath on glados.Any {
  glados.Generator<GeneratedPathSegmentShape> get pathSegmentShape =>
      glados.AnyUtils(this).choose(GeneratedPathSegmentShape.values);

  glados.Generator<GeneratedPathSeparator> get pathSeparator =>
      glados.AnyUtils(this).choose(GeneratedPathSeparator.values);

  glados.Generator<String> get payloadAffix =>
      glados.AnyUtils(this).choose(const ['', 'id ', '#', '%']);

  glados.Generator<String> get payloadSeparator =>
      glados.AnyUtils(this).choose(const ['', '-', '_', ' ', '/', '?']);

  glados.Generator<GeneratedPathSegment> get pathSegment =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 10000),
        pathSegmentShape,
        (int seed, GeneratedPathSegmentShape shape) =>
            GeneratedPathSegment(seed: seed, shape: shape),
      );

  glados.Generator<GeneratedAttachmentIndexKey> get attachmentIndexKey =>
      glados.CombinableAny(this).combine4(
        glados.ListAnys(this).listWithLengthInRange(1, 7, pathSegment),
        glados.IntAnys(this).intInRange(0, 5),
        pathSeparator,
        pathSeparator,
        (
          List<GeneratedPathSegment> segments,
          int leadingSeparatorCount,
          GeneratedPathSeparator leadingSeparator,
          GeneratedPathSeparator innerSeparator,
        ) => GeneratedAttachmentIndexKey(
          segments: segments,
          leadingSeparatorCount: leadingSeparatorCount,
          leadingSeparator: leadingSeparator,
          innerSeparator: innerSeparator,
        ),
      );

  glados.Generator<GeneratedPayloadId> get payloadId =>
      glados.CombinableAny(this).combine4(
        glados.ListAnys(this).listWithLengthInRange(0, 5, pathSegment),
        payloadSeparator,
        payloadAffix,
        payloadAffix,
        (
          List<GeneratedPathSegment> parts,
          String separator,
          String prefix,
          String suffix,
        ) => GeneratedPayloadId(
          parts: parts,
          separator: separator,
          prefix: prefix,
          suffix: suffix,
        ),
      );
}

// ---------------------------------------------------------------------------
// Extra generators for the relativeEntityPath and resolveJsonCandidateFile
// Glados property tests added below main().
// ---------------------------------------------------------------------------

class GeneratedEntityScenario {
  const GeneratedEntityScenario({required this.meta});

  final Metadata meta;

  @override
  String toString() =>
      'GeneratedEntityScenario(id=${meta.id}, createdAt=${meta.createdAt})';
}

extension AnyEntityScenario on glados.Any {
  /// Generates a valid calendar date in the range [2000, 2030].
  /// Day is capped at 28 to sidestep month-end edge cases.
  glados.Generator<DateTime> get _entityDate =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(2000, 2030),
        glados.IntAnys(this).intInRange(1, 12),
        glados.IntAnys(this).intInRange(1, 28),
        DateTime.new,
      );

  /// Produces an entity scenario with a generated non-empty alphanumeric id
  /// and a generated creation date.
  glados.Generator<GeneratedEntityScenario> get generatedEntityScenario =>
      glados.CombinableAny(this).combine2(
        glados.StringAnys(this).nonEmptyLetterOrDigits,
        _entityDate,
        (String id, DateTime createdAt) => GeneratedEntityScenario(
          meta: Metadata(
            id: id,
            createdAt: createdAt,
            dateTo: createdAt,
            dateFrom: createdAt,
            updatedAt: createdAt,
          ),
        ),
      );

  /// Generates a "safe" relative path from two segment tokens joined by `/`.
  /// The [pathSegment] generator (from [AnyFileUtilsPath]) never produces
  /// `..`, so the result is always a sandbox-safe relative path.
  glados.Generator<String> get safeRelativePath =>
      glados.CombinableAny(this).combine2(
        pathSegment,
        pathSegment,
        (GeneratedPathSegment a, GeneratedPathSegment b) =>
            '${a.text}/${b.text}',
      );
}

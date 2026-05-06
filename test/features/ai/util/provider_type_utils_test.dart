import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/provider_type_utils.dart';

enum _GeneratedProviderTypeStringShape {
  valid,
  unknown,
  empty,
  uppercaseValid,
  paddedValid,
  invalid,
}

class _GeneratedProviderTypeString {
  const _GeneratedProviderTypeString({
    required this.shape,
    required this.providerType,
    required this.seed,
  });

  final _GeneratedProviderTypeStringShape shape;
  final InferenceProviderType providerType;
  final int seed;

  String get input => switch (shape) {
    _GeneratedProviderTypeStringShape.valid => providerType.name,
    _GeneratedProviderTypeStringShape.unknown => 'unknown',
    _GeneratedProviderTypeStringShape.empty => '',
    _GeneratedProviderTypeStringShape.uppercaseValid =>
      providerType.name.toUpperCase(),
    _GeneratedProviderTypeStringShape.paddedValid => ' ${providerType.name} ',
    _GeneratedProviderTypeStringShape.invalid =>
      'generated-provider-type-$seed',
  };

  String get expected => shape == _GeneratedProviderTypeStringShape.valid
      ? providerType.name
      : InferenceProviderType.genericOpenAi.name;

  @override
  String toString() {
    return '_GeneratedProviderTypeString('
        'shape: $shape, providerType: $providerType, seed: $seed)';
  }
}

extension _AnyGeneratedProviderTypeString on glados.Any {
  glados.Generator<_GeneratedProviderTypeStringShape>
  get providerTypeStringShape =>
      glados.AnyUtils(this).choose(_GeneratedProviderTypeStringShape.values);

  glados.Generator<InferenceProviderType> get inferenceProviderType =>
      glados.AnyUtils(this).choose(InferenceProviderType.values);

  glados.Generator<_GeneratedProviderTypeString> get providerTypeString =>
      glados.CombinableAny(this).combine3(
        providerTypeStringShape,
        inferenceProviderType,
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedProviderTypeStringShape shape,
          InferenceProviderType providerType,
          int seed,
        ) => _GeneratedProviderTypeString(
          shape: shape,
          providerType: providerType,
          seed: seed,
        ),
      );
}

void main() {
  group('normalizeProviderType', () {
    test('returns the same for all valid enum names', () {
      for (final t in InferenceProviderType.values) {
        expect(
          normalizeProviderType(t.name),
          t.name,
          reason: 'Should keep valid provider type name: ${t.name}',
        );
      }
    });

    test("maps 'unknown' to genericOpenAi", () {
      expect(
        normalizeProviderType('unknown'),
        InferenceProviderType.genericOpenAi.name,
      );
    });

    test('defaults invalid strings to genericOpenAi', () {
      expect(
        normalizeProviderType(''),
        InferenceProviderType.genericOpenAi.name,
      );
      expect(
        normalizeProviderType('not-a-real-type'),
        InferenceProviderType.genericOpenAi.name,
      );
      // Case-sensitive check: enum names are lowerCamelCase; uppercase should not match
      expect(
        normalizeProviderType('OPENAI'),
        InferenceProviderType.genericOpenAi.name,
      );
    });

    glados.Glados(
      glados.any.providerTypeString,
      glados.ExploreConfig(numRuns: 160),
    ).test('matches generated provider type normalization semantics', (
      providerTypeString,
    ) {
      expect(
        normalizeProviderType(providerTypeString.input),
        providerTypeString.expected,
        reason: '$providerTypeString',
      );
    });
  });
}

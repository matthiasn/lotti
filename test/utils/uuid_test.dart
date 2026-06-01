import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/uuid.dart';

void main() {
  group('UUID test', () {
    test('Generated UUID is valid', () {
      expect(isUuid(uuid.v1()), true);
    });

    test('Returns true for valid UUID', () {
      expect(isUuid('123e4567-e89b-12d3-a456-426614174000'), true);
    });

    test('Returns false for null', () {
      expect(isUuid(null), false);
    });

    test('Returns false for empty string', () {
      expect(isUuid(''), false);
    });

    test('Returns false for string without hyphens', () {
      expect(isUuid('123e4567e89b12d3a456426614174000'), false);
    });

    test('Returns false for string with invalid length', () {
      expect(isUuid('123e4567-e89b-12d3-a456-42661417400'), false);
    });

    test('Returns false for string with invalid characters', () {
      expect(isUuid('123e4567-e89b-12d3-a456-42661417400g'), false);
    });

    glados.Glados(
      glados.any.generatedUuid,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'accepts generated UUIDs independent of hex letter casing',
      (scenario) {
        expect(isUuid(scenario.lowerCase), isTrue, reason: '$scenario');
        expect(isUuid(scenario.upperCase), isTrue, reason: '$scenario');
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.invalidUuidScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'rejects generated malformed UUID strings',
      (scenario) {
        expect(isUuid(scenario.value), isFalse, reason: '$scenario');
      },
      tags: 'glados',
    );
  });
}

enum _GeneratedUuidMutation {
  missingHyphen,
  extraHyphen,
  invalidHex,
  tooShort,
  tooLong,
  prefix,
  suffix,
}

class _GeneratedUuid {
  const _GeneratedUuid(this.nibbles);

  final List<int> nibbles;

  String get lowerCase {
    final hex = nibbles.map((nibble) => nibble.toRadixString(16)).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  String get upperCase => lowerCase.toUpperCase();

  @override
  String toString() => '_GeneratedUuid($lowerCase)';
}

class _GeneratedInvalidUuidScenario {
  const _GeneratedInvalidUuidScenario({
    required this.uuid,
    required this.mutation,
  });

  final _GeneratedUuid uuid;
  final _GeneratedUuidMutation mutation;

  String get value {
    final valid = uuid.lowerCase;
    return switch (mutation) {
      _GeneratedUuidMutation.missingHyphen => valid.replaceFirst('-', ''),
      _GeneratedUuidMutation.extraHyphen => '$valid-',
      _GeneratedUuidMutation.invalidHex => 'g${valid.substring(1)}',
      _GeneratedUuidMutation.tooShort => valid.substring(0, valid.length - 1),
      _GeneratedUuidMutation.tooLong => '${valid}0',
      _GeneratedUuidMutation.prefix => 'x$valid',
      _GeneratedUuidMutation.suffix => '${valid}x',
    };
  }

  @override
  String toString() =>
      '_GeneratedInvalidUuidScenario(value: $value, mutation: $mutation)';
}

extension _AnyUuid on glados.Any {
  glados.Generator<int> get _hexNibble =>
      glados.IntAnys(this).intInRange(0, 15);

  glados.Generator<_GeneratedUuid> get generatedUuid => glados.ListAnys(
    this,
  ).listWithLengthInRange(32, 32, _hexNibble).map(_GeneratedUuid.new);

  glados.Generator<_GeneratedUuidMutation> get _uuidMutation =>
      glados.AnyUtils(this).choose(_GeneratedUuidMutation.values);

  glados.Generator<_GeneratedInvalidUuidScenario> get invalidUuidScenario =>
      glados.CombinableAny(this).combine2(
        generatedUuid,
        _uuidMutation,
        (
          _GeneratedUuid uuid,
          _GeneratedUuidMutation mutation,
        ) => _GeneratedInvalidUuidScenario(uuid: uuid, mutation: mutation),
      );
}

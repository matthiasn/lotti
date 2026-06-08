import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/genui/evolution_catalog_helpers.dart';

import '../../../widget_test_utils.dart';

// ── Generators ────────────────────────────────────────────────────────────────

extension _AnyJsonValue on glados.Any {
  /// Generates a key for a JSON map.
  glados.Generator<String> get jsonKey => glados.any.letterOrDigits;

  /// Generates a non-negative int for use in JSON values.
  glados.Generator<int> get nonNegativeInt =>
      glados.IntAnys(this).intInRange(0, 10000);

  /// Generates an int (may be negative) for use in JSON values.
  glados.Generator<int> get anyInt =>
      glados.IntAnys(this).intInRange(-10000, 10000);

  /// Generates a non-negative double by combining two int ranges.
  glados.Generator<double> get nonNegativeDouble =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 9999),
        glados.IntAnys(this).intInRange(0, 99),
        (int whole, int frac) => whole + frac / 100,
      );

  /// Generates a non-empty string of lower-case letter/digit chars.
  glados.Generator<String> get shortAlphanumString =>
      glados.any.stringOf('abcdefghijklmnopqrstuvwxyz0123456789');

  /// Generates an arbitrary JSON-ish value across seven kinds: int, double,
  /// bool, String, null, List (with a nested map), and Map.
  glados.Generator<Object?> get mixedJsonValue =>
      glados.IntAnys(this).intInRange(0, 1 << 16).map((seed) {
        switch (seed % 7) {
          case 0:
            return seed - 5000;
          case 1:
            return seed / 7;
          case 2:
            return seed.isEven;
          case 3:
            return 'str$seed';
          case 4:
            return null;
          case 5:
            return <Object?>[
              seed,
              'x',
              <String, Object?>{'nested': seed},
            ];
          default:
            return <String, Object?>{'k': seed};
        }
      });
}

void main() {
  // ── readInt ─────────────────────────────────────────────────────────────────

  group('readInt', () {
    test('returns int value when key exists and value is an int', () {
      expect(readInt({'a': 42}, 'a'), 42);
    });

    test('coerces a double to int (truncation)', () {
      expect(readInt({'a': 3.9}, 'a'), 3);
    });

    test('returns fallback (default 0) when key is absent', () {
      expect(readInt({'b': 1}, 'a'), 0);
    });

    test('returns custom fallback when key is absent', () {
      expect(readInt({}, 'k', -7), -7);
    });

    test('returns fallback when value is a string', () {
      expect(readInt(<String, Object?>{'a': 'hello'}, 'a', 99), 99);
    });

    test('returns fallback when value is null', () {
      expect(readInt(<String, Object?>{'a': null}, 'a', 5), 5);
    });

    test('returns fallback when value is a bool', () {
      expect(readInt(<String, Object?>{'a': true}, 'a', 3), 3);
    });

    glados.Glados2(
      glados.any.nonNegativeInt,
      glados.any.jsonKey,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'round-trips any non-negative int through a single-entry map',
      (value, key) {
        final result = readInt({key: value}, key);
        expect(result, value, reason: 'key=$key value=$value');
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.anyInt,
      glados.any.jsonKey,
      glados.ExploreConfig(numRuns: 120),
    ).test('returns the fallback when the key is absent', (fallback, key) {
      final result = readInt({}, key, fallback);
      expect(result, fallback, reason: 'key=$key fallback=$fallback');
    }, tags: 'glados');
  });

  // ── readDouble ───────────────────────────────────────────────────────────────

  group('readDouble', () {
    test('returns double value when key exists and value is a double', () {
      expect(readDouble({'x': 2.5}, 'x'), 2.5);
    });

    test('coerces an int to double', () {
      expect(readDouble({'x': 7}, 'x'), 7.0);
    });

    test('returns fallback (default 0.0) when key is absent', () {
      expect(readDouble({'y': 1.0}, 'x'), 0.0);
    });

    test('returns custom fallback when key is absent', () {
      expect(readDouble({}, 'k', -1.5), -1.5);
    });

    test('returns fallback when value is a string', () {
      expect(readDouble(<String, Object?>{'x': 'nope'}, 'x', 9.9), 9.9);
    });

    test('returns fallback when value is null', () {
      expect(readDouble(<String, Object?>{'x': null}, 'x', 3), 3.0);
    });

    glados.Glados2(
      glados.any.nonNegativeDouble,
      glados.any.jsonKey,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'round-trips any non-negative double through a single-entry map',
      (value, key) {
        final result = readDouble({key: value}, key);
        expect(result, closeTo(value, 1e-9), reason: 'key=$key value=$value');
      },
      tags: 'glados',
    );
  });

  // ── readNumOrNull ─────────────────────────────────────────────────────────────

  group('readNumOrNull', () {
    test('returns int value as num', () {
      expect(readNumOrNull({'n': 5}, 'n'), 5);
    });

    test('returns double value as num', () {
      expect(readNumOrNull({'n': 1.5}, 'n'), 1.5);
    });

    test('returns null when key is absent', () {
      expect(readNumOrNull({}, 'n'), isNull);
    });

    test('returns null when value is a string', () {
      expect(readNumOrNull(<String, Object?>{'n': 'hello'}, 'n'), isNull);
    });

    test('returns null when value is null', () {
      expect(readNumOrNull(<String, Object?>{'n': null}, 'n'), isNull);
    });

    test('returns null when value is a bool', () {
      expect(readNumOrNull(<String, Object?>{'n': false}, 'n'), isNull);
    });

    glados.Glados2(
      glados.any.nonNegativeInt,
      glados.any.jsonKey,
      glados.ExploreConfig(numRuns: 120),
    ).test('is non-null for any int in the map', (value, key) {
      final result = readNumOrNull({key: value}, key);
      expect(result, isNotNull, reason: 'key=$key value=$value');
      expect(result!.toInt(), value);
    }, tags: 'glados');
  });

  // ── readString ────────────────────────────────────────────────────────────────

  group('readString', () {
    test('returns string value when key exists and value is a string', () {
      expect(readString({'s': 'hello'}, 's'), 'hello');
    });

    test('returns fallback (default empty string) when key is absent', () {
      expect(readString({'t': 'x'}, 's'), '');
    });

    test('returns custom fallback when key is absent', () {
      expect(readString({}, 'k', 'default'), 'default');
    });

    test('returns fallback when value is an int', () {
      expect(readString(<String, Object?>{'s': 42}, 's', 'fb'), 'fb');
    });

    test('returns fallback when value is null', () {
      expect(readString(<String, Object?>{'s': null}, 's', 'fb'), 'fb');
    });

    test('returns fallback when value is a bool', () {
      expect(readString(<String, Object?>{'s': true}, 's', 'fb'), 'fb');
    });

    test('returns empty string when value is empty string', () {
      expect(readString({'s': ''}, 's', 'fb'), '');
    });

    glados.Glados2(
      glados.any.shortAlphanumString,
      glados.any.jsonKey,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'round-trips any alphanumeric string through a single-entry map',
      (value, key) {
        final result = readString({key: value}, key);
        expect(result, value, reason: 'key=$key value=$value');
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.shortAlphanumString,
      glados.any.jsonKey,
      glados.ExploreConfig(numRuns: 120),
    ).test('returns the fallback string when the key is absent', (
      fallback,
      key,
    ) {
      final result = readString({}, key, fallback);
      expect(result, fallback, reason: 'key=$key fallback=$fallback');
    }, tags: 'glados');
  });

  // ── readStringOrNull ─────────────────────────────────────────────────────────

  group('readStringOrNull', () {
    test('returns string value when key exists and value is a string', () {
      expect(readStringOrNull({'s': 'abc'}, 's'), 'abc');
    });

    test('returns null when key is absent', () {
      expect(readStringOrNull({}, 's'), isNull);
    });

    test('returns null when value is an int', () {
      expect(readStringOrNull(<String, Object?>{'s': 10}, 's'), isNull);
    });

    test('returns null when value is null', () {
      expect(readStringOrNull(<String, Object?>{'s': null}, 's'), isNull);
    });

    test('returns null when value is a bool', () {
      expect(readStringOrNull(<String, Object?>{'s': false}, 's'), isNull);
    });

    test('returns empty string when value is empty string', () {
      expect(readStringOrNull({'s': ''}, 's'), '');
    });

    glados.Glados2(
      glados.any.shortAlphanumString,
      glados.any.jsonKey,
      glados.ExploreConfig(numRuns: 120),
    ).test('is non-null for any string in the map', (value, key) {
      final result = readStringOrNull({key: value}, key);
      expect(result, isNotNull, reason: 'key=$key value=$value');
      expect(result, value);
    }, tags: 'glados');

    glados.Glados(
      glados.any.jsonKey,
      glados.ExploreConfig(numRuns: 120),
    ).test('is null when key is absent', (key) {
      final result = readStringOrNull({}, key);
      expect(result, isNull, reason: 'key=$key');
    }, tags: 'glados');
  });

  // ── readMapList ───────────────────────────────────────────────────────────────

  group('readMapList', () {
    test('returns list of maps when all elements are maps', () {
      final data = <String, Object?>{
        'items': <Map<String, Object?>>[
          {'a': 1},
          {'b': 2},
        ],
      };
      final result = readMapList(data, 'items');
      expect(result, hasLength(2));
      expect(result[0], <String, Object?>{'a': 1});
      expect(result[1], <String, Object?>{'b': 2});
    });

    test('filters out non-map items (strings, ints, nulls)', () {
      final data = <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'a': 1},
          'string',
          null,
          42,
          <String, Object?>{'b': 2},
        ],
      };
      final result = readMapList(data, 'items');
      // Only the two maps survive the whereType<Map> filter.
      expect(result, hasLength(2));
      expect(result[0], <String, Object?>{'a': 1});
      expect(result[1], <String, Object?>{'b': 2});
    });

    test('returns empty list when key is absent', () {
      expect(readMapList({}, 'items'), isEmpty);
    });

    test('returns empty list when value is null', () {
      expect(readMapList(<String, Object?>{'items': null}, 'items'), isEmpty);
    });

    test('returns empty list when value is not a list', () {
      expect(
        readMapList(<String, Object?>{'items': 'not-a-list'}, 'items'),
        isEmpty,
      );
      expect(readMapList(<String, Object?>{'items': 42}, 'items'), isEmpty);
      expect(readMapList(<String, Object?>{'items': true}, 'items'), isEmpty);
    });

    test('returns empty list when list contains no maps', () {
      final data = <String, Object?>{
        'items': <Object?>['a', 1, null, true],
      };
      expect(readMapList(data, 'items'), isEmpty);
    });

    test('returns empty list when the list itself is empty', () {
      expect(readMapList({'items': <Object?>[]}, 'items'), isEmpty);
    });

    test('handles a list with only one map correctly', () {
      final data = <String, Object?>{
        'items': <Map<String, Object?>>[
          {'key': 'val'},
        ],
      };
      final result = readMapList(data, 'items');
      expect(result, hasLength(1));
      expect(result.first, <String, Object?>{'key': 'val'});
    });

    test('all non-map items are filtered — output length equals map count', () {
      final data = <String, Object?>{
        'list': <Object?>[
          <String, Object?>{'x': 1},
          'drop',
          <String, Object?>{'y': 2},
          99,
          <String, Object?>{'z': 3},
        ],
      };
      final result = readMapList(data, 'list');
      expect(result, hasLength(3));
    });
  });

  group('type-confusion property (all readers)', () {
    glados.Glados2(
      glados.any.mixedJsonValue,
      glados.any.jsonKey,
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'every reader applies exactly its own type gate over arbitrary values',
      (value, key) {
        final json = <String, Object?>{key: value};
        final reason = 'key=$key value=$value (${value.runtimeType})';

        expect(
          readInt(json, key, -7),
          value is num ? value.toInt() : -7,
          reason: reason,
        );
        expect(
          readDouble(json, key, -7.5),
          value is num ? value.toDouble() : -7.5,
          reason: reason,
        );
        expect(
          readNumOrNull(json, key),
          value is num ? value : isNull,
          reason: reason,
        );
        expect(
          readString(json, key, 'fb'),
          value is String ? value : 'fb',
          reason: reason,
        );
        expect(
          readStringOrNull(json, key),
          value is String ? value : isNull,
          reason: reason,
        );
        expect(
          readMapList(json, key),
          value is List
              ? value.whereType<Map<String, Object?>>().toList()
              : isEmpty,
          reason: reason,
        );
      },
      tags: 'glados',
    );
  });

  // ── Shared widget helpers ─────────────────────────────────────────────────

  group('metricChip', () {
    testWidgets('renders both the value and the label', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(metricChip('Wakes', '42')),
      );

      expect(find.text('42'), findsOneWidget);
      expect(find.text('Wakes'), findsOneWidget);
    });

    testWidgets('styles the value as bold white and the label as faded', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(metricChip('Failures', '7')),
      );

      final valueStyle = tester.widget<Text>(find.text('7')).style!;
      expect(valueStyle.color, Colors.white);
      expect(valueStyle.fontWeight, FontWeight.w700);

      // The label is rendered at reduced opacity (alpha 0.5), distinguishing
      // it from the prominent value above it.
      final labelStyle = tester.widget<Text>(find.text('Failures')).style!;
      expect(labelStyle.color, Colors.white.withValues(alpha: 0.5));
      expect(labelStyle.fontWeight, isNot(FontWeight.w700));
    });
  });

  group('sectionLabel', () {
    testWidgets('renders the provided text with an emphasized weight', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) => sectionLabel(context, 'Current Directives'),
          ),
        ),
      );

      expect(find.text('Current Directives'), findsOneWidget);
      final style = tester.widget<Text>(find.text('Current Directives')).style!;
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, 0.2);
    });
  });

  group('directiveBox', () {
    testWidgets('renders the directive text', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) =>
                directiveBox(context: context, text: 'Be concise'),
          ),
        ),
      );

      expect(find.text('Be concise'), findsOneWidget);
    });

    testWidgets('uses a different background when highlighted', (tester) async {
      // Render the plain and highlighted variants side by side so their
      // decorations can be compared within one pump.
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) => Column(
              children: [
                directiveBox(context: context, text: 'plain'),
                directiveBox(
                  context: context,
                  text: 'highlighted',
                  isHighlighted: true,
                ),
              ],
            ),
          ),
        ),
      );

      // The outer directiveBox Containers are the only ones with the helper's
      // signature padding (EdgeInsets.all(14)); GptMarkdown internals do not
      // use it. Collect their decoration colors in render order.
      final boxColors = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.padding == const EdgeInsets.all(14))
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toList();

      expect(boxColors, hasLength(2));
      // The highlighted variant derives its fill from the primary container,
      // while the plain variant derives it from a neutral surface; the two
      // must not be equal.
      expect(boxColors[0], isNot(boxColors[1]));
    });
  });
}

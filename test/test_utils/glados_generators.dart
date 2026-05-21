import 'package:glados/glados.dart';

/// Number of days in the given Gregorian month. Equivalent to
/// `DateTime(year, month + 1, 0).day` but factored out so test files don't
/// each re-derive it.
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Zero-pad to 2 digits — the only width ISO 8601 ever asks for on month,
/// day, hour, minute, second.
String twoDigits(int value) => value.toString().padLeft(2, '0');

/// Zero-pad to 4 digits — the only width ISO 8601 ever asks for on year.
String fourDigits(int value) => value.toString().padLeft(4, '0');

/// A generated calendar date in the range supported by the parsers under
/// test. `daySeed` is mapped through [daysInMonth] so every emitted triple
/// is a legal date even when the day is sampled blindly.
///
/// `text` returns the canonical `YYYY-MM-DD` rendering; `dateTime` returns
/// the equivalent local-time DateTime at midnight.
class IsoDateComponents {
  const IsoDateComponents({
    required this.year,
    required this.month,
    required this._daySeed,
  });

  final int year;
  final int month;
  final int _daySeed;

  int get day => (_daySeed % daysInMonth(year, month)) + 1;

  String get text =>
      '${fourDigits(year)}-${twoDigits(month)}-${twoDigits(day)}';

  DateTime get dateTime => DateTime(year, month, day);

  @override
  String toString() => 'IsoDateComponents($text)';
}

extension AnyGladosShared on Any {
  /// Generates valid `(year, month, day)` triples in `[2000, 2030]`.
  /// The shrinker converges to `2000-01-01`.
  Generator<IsoDateComponents> get isoDate => combine3(
    intInRange(2000, 2030),
    intInRange(1, 12),
    intInRange(0, 400),
    (int year, int month, int daySeed) => IsoDateComponents(
      year: year,
      month: month,
      daySeed: daySeed,
    ),
  );

  /// Three-way `{'', ' ', '\n'}` choice — used to wrap a payload in
  /// whitespace to ensure parsers / canonicalizers handle trimming.
  /// The shrinker converges to `''` (no whitespace).
  Generator<String> get singleWhitespace => choose(const ['', ' ', '\n']);

  /// Like [singleWhitespace] but with a tab variant — used where the parser
  /// also has to survive mixed indentation.
  Generator<String> get singleWhitespaceWithTab =>
      choose(const ['', ' ', '\n\t']);
}

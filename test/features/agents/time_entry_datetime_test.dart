import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/time_entry_datetime.dart';

enum _InvalidLocalTimestampShape {
  monthZero,
  monthThirteen,
  dayZero,
  dayAfterMonth,
  hourTwentyFour,
  minuteSixty,
  secondSixty,
}

enum _TimezoneSuffixShape {
  upperZ,
  lowerZ,
  colonPositive,
  colonNegative,
  compactPositive,
  compactNegative,
}

class _GeneratedLocalTimestamp {
  const _GeneratedLocalTimestamp({
    required this.year,
    required this.month,
    required this.daySeed,
    required this.hour,
    required this.minute,
    required this.second,
    required this.withSeconds,
  });

  final int year;
  final int month;
  final int daySeed;
  final int hour;
  final int minute;
  final int second;
  final bool withSeconds;

  int get day => (daySeed % _daysInMonth(year, month)) + 1;

  String get text {
    final date = '${_fourDigits(year)}-${_twoDigits(month)}-${_twoDigits(day)}';
    final time = '${_twoDigits(hour)}:${_twoDigits(minute)}';
    if (!withSeconds) return '${date}T$time';
    return '${date}T$time:${_twoDigits(second)}';
  }

  DateTime get expected => DateTime(
    year,
    month,
    day,
    hour,
    minute,
    withSeconds ? second : 0,
  );

  @override
  String toString() {
    return '_GeneratedLocalTimestamp('
        'text: $text, '
        'expected: $expected)';
  }
}

class _GeneratedInvalidLocalTimestamp {
  const _GeneratedInvalidLocalTimestamp({
    required this.shape,
    required this.year,
    required this.month,
    required this.daySeed,
    required this.hour,
    required this.minute,
    required this.second,
  });

  final _InvalidLocalTimestampShape shape;
  final int year;
  final int month;
  final int daySeed;
  final int hour;
  final int minute;
  final int second;

  int get _validDay => (daySeed % _daysInMonth(year, month)) + 1;

  String get text {
    final invalidMonth = switch (shape) {
      _InvalidLocalTimestampShape.monthZero => 0,
      _InvalidLocalTimestampShape.monthThirteen => 13,
      _ => month,
    };
    final invalidDay = switch (shape) {
      _InvalidLocalTimestampShape.dayZero => 0,
      _InvalidLocalTimestampShape.dayAfterMonth =>
        _daysInMonth(year, month) + 1,
      _ => _validDay,
    };
    final invalidHour = switch (shape) {
      _InvalidLocalTimestampShape.hourTwentyFour => 24,
      _ => hour,
    };
    final invalidMinute = switch (shape) {
      _InvalidLocalTimestampShape.minuteSixty => 60,
      _ => minute,
    };
    final invalidSecond = switch (shape) {
      _InvalidLocalTimestampShape.secondSixty => 60,
      _ => second,
    };

    return '${_fourDigits(year)}-${_twoDigits(invalidMonth)}-'
        '${_twoDigits(invalidDay)}T${_twoDigits(invalidHour)}:'
        '${_twoDigits(invalidMinute)}:${_twoDigits(invalidSecond)}';
  }

  @override
  String toString() {
    return '_GeneratedInvalidLocalTimestamp('
        'shape: $shape, '
        'text: $text)';
  }
}

class _GeneratedTimezoneTimestamp {
  const _GeneratedTimezoneTimestamp({
    required this.base,
    required this.suffixShape,
  });

  final _GeneratedLocalTimestamp base;
  final _TimezoneSuffixShape suffixShape;

  String get suffix => switch (suffixShape) {
    _TimezoneSuffixShape.upperZ => 'Z',
    _TimezoneSuffixShape.lowerZ => 'z',
    _TimezoneSuffixShape.colonPositive => '+01:00',
    _TimezoneSuffixShape.colonNegative => '-05:30',
    _TimezoneSuffixShape.compactPositive => '+0100',
    _TimezoneSuffixShape.compactNegative => '-0530',
  };

  String get text => '${base.text}$suffix';

  @override
  String toString() {
    return '_GeneratedTimezoneTimestamp('
        'suffixShape: $suffixShape, '
        'text: $text)';
  }
}

class _GeneratedTimeOfDay {
  const _GeneratedTimeOfDay({
    required this.hour,
    required this.minute,
  });

  final int hour;
  final int minute;

  DateTime get value => DateTime(2026, 3, 17, hour, minute);
  String get expected => '${_twoDigits(hour)}:${_twoDigits(minute)}';

  @override
  String toString() {
    return '_GeneratedTimeOfDay(hour: $hour, minute: $minute)';
  }
}

extension _AnyTimeEntryDateTime on glados.Any {
  glados.Generator<_InvalidLocalTimestampShape>
  get invalidLocalTimestampShape =>
      glados.AnyUtils(this).choose(_InvalidLocalTimestampShape.values);

  glados.Generator<_TimezoneSuffixShape> get timezoneSuffixShape =>
      glados.AnyUtils(this).choose(_TimezoneSuffixShape.values);

  glados.Generator<_GeneratedLocalTimestamp> get localTimestamp =>
      glados.CombinableAny(this).combine7(
        glados.IntAnys(this).intInRange(2000, 2030),
        glados.IntAnys(this).intInRange(1, 12),
        glados.IntAnys(this).intInRange(0, 400),
        glados.IntAnys(this).intInRange(0, 23),
        glados.IntAnys(this).intInRange(0, 59),
        glados.IntAnys(this).intInRange(0, 59),
        glados.BoolAny(this).bool,
        (
          int year,
          int month,
          int daySeed,
          int hour,
          int minute,
          int second,
          bool withSeconds,
        ) => _GeneratedLocalTimestamp(
          year: year,
          month: month,
          daySeed: daySeed,
          hour: hour,
          minute: minute,
          second: second,
          withSeconds: withSeconds,
        ),
      );

  glados.Generator<_GeneratedInvalidLocalTimestamp> get invalidLocalTimestamp =>
      glados.CombinableAny(this).combine7(
        invalidLocalTimestampShape,
        glados.IntAnys(this).intInRange(2000, 2030),
        glados.IntAnys(this).intInRange(1, 12),
        glados.IntAnys(this).intInRange(0, 400),
        glados.IntAnys(this).intInRange(0, 23),
        glados.IntAnys(this).intInRange(0, 59),
        glados.IntAnys(this).intInRange(0, 59),
        (
          _InvalidLocalTimestampShape shape,
          int year,
          int month,
          int daySeed,
          int hour,
          int minute,
          int second,
        ) => _GeneratedInvalidLocalTimestamp(
          shape: shape,
          year: year,
          month: month,
          daySeed: daySeed,
          hour: hour,
          minute: minute,
          second: second,
        ),
      );

  glados.Generator<_GeneratedTimezoneTimestamp> get timezoneTimestamp =>
      glados.CombinableAny(this).combine2(
        localTimestamp,
        timezoneSuffixShape,
        (
          _GeneratedLocalTimestamp base,
          _TimezoneSuffixShape suffixShape,
        ) => _GeneratedTimezoneTimestamp(
          base: base,
          suffixShape: suffixShape,
        ),
      );

  glados.Generator<_GeneratedTimeOfDay> get timeOfDay =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 23),
        glados.IntAnys(this).intInRange(0, 59),
        (int hour, int minute) => _GeneratedTimeOfDay(
          hour: hour,
          minute: minute,
        ),
      );
}

int _daysInMonth(int year, int month) {
  final lastDay = DateTime(year, month + 1, 0);
  return lastDay.day;
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
String _fourDigits(int value) => value.toString().padLeft(4, '0');

void main() {
  group('parseTimeEntryLocalDateTime', () {
    test('parses a valid local ISO 8601 datetime', () {
      final result = parseTimeEntryLocalDateTime('2026-03-17T14:00:00');
      expect(result, equals(DateTime(2026, 3, 17, 14)));
    });

    test('parses datetime with seconds', () {
      final result = parseTimeEntryLocalDateTime('2026-03-17T09:05:30');
      expect(result, equals(DateTime(2026, 3, 17, 9, 5, 30)));
    });

    test('returns null for date-only string', () {
      expect(parseTimeEntryLocalDateTime('2026-03-17'), isNull);
    });

    test('returns null for UTC string with Z suffix', () {
      expect(parseTimeEntryLocalDateTime('2026-03-17T14:00:00Z'), isNull);
    });

    test('returns null for UTC string with lowercase z suffix', () {
      expect(parseTimeEntryLocalDateTime('2026-03-17T14:00:00z'), isNull);
    });

    test('returns null for string with positive timezone offset', () {
      expect(parseTimeEntryLocalDateTime('2026-03-17T14:00:00+01:00'), isNull);
    });

    test('returns null for string with negative timezone offset', () {
      expect(parseTimeEntryLocalDateTime('2026-03-17T14:00:00-05:00'), isNull);
    });

    test('returns null for string with compact timezone offset', () {
      expect(parseTimeEntryLocalDateTime('2026-03-17T14:00:00+0100'), isNull);
    });

    test('returns null for completely invalid string', () {
      expect(parseTimeEntryLocalDateTime('not-a-date'), isNull);
    });

    test('returns null for empty string', () {
      expect(parseTimeEntryLocalDateTime(''), isNull);
    });

    glados.Glados(
      glados.any.localTimestamp,
      glados.ExploreConfig(numRuns: 180),
    ).test('parses generated strict local ISO timestamps', (scenario) {
      expect(
        parseTimeEntryLocalDateTime(scenario.text),
        scenario.expected,
        reason: '$scenario',
      );
    });

    glados.Glados(
      glados.any.invalidLocalTimestamp,
      glados.ExploreConfig(numRuns: 180),
    ).test('rejects generated invalid local timestamp components', (scenario) {
      expect(
        parseTimeEntryLocalDateTime(scenario.text),
        isNull,
        reason: '$scenario',
      );
    });

    glados.Glados(
      glados.any.timezoneTimestamp,
      glados.ExploreConfig(numRuns: 120),
    ).test('rejects generated timezone-qualified timestamps', (scenario) {
      expect(
        parseTimeEntryLocalDateTime(scenario.text),
        isNull,
        reason: '$scenario',
      );
    });
  });

  group('formatTimeEntryHhMm', () {
    test('formats midnight as 00:00', () {
      expect(formatTimeEntryHhMm(DateTime(2026, 3, 17)), equals('00:00'));
    });

    test('pads single-digit hour and minute', () {
      expect(formatTimeEntryHhMm(DateTime(2026, 3, 17, 9, 5)), equals('09:05'));
    });

    test('formats noon correctly', () {
      expect(
        formatTimeEntryHhMm(DateTime(2026, 3, 17, 12)),
        equals('12:00'),
      );
    });

    test('formats end of day', () {
      expect(
        formatTimeEntryHhMm(DateTime(2026, 3, 17, 23, 59)),
        equals('23:59'),
      );
    });

    glados.Glados(
      glados.any.timeOfDay,
      glados.ExploreConfig(numRuns: 120),
    ).test('formats generated wall-clock times as padded HH:mm', (scenario) {
      expect(
        formatTimeEntryHhMm(scenario.value),
        scenario.expected,
        reason: '$scenario',
      );
    });
  });
}

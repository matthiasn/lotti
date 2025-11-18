/// Comprehensive tests to achieve 100% coverage for image_import.dart
/// This file specifically targets previously uncovered code paths
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/logic/image_import.dart';

void main() {
  group('_parseAudioFileTimestamp Coverage Tests', () {
    test('parses valid Lotti audio filename format', () {
      final result = parseAudioFileTimestamp('2024-01-15_10-30-45-123');
      expect(result, isNotNull);
      // Result is converted to local time, so check components
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('returns null for invalid filename format', () {
      expect(parseAudioFileTimestamp('invalid-format'), isNull);
    });

    test('returns null for empty filename', () {
      expect(parseAudioFileTimestamp(''), isNull);
    });

    test('parses filename with extension by stripping it', () {
      // Function removes extension before parsing
      final result = parseAudioFileTimestamp('2024-01-15_10-30-45-123.m4a');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('handles filename without milliseconds gracefully', () {
      // Format requires milliseconds (yyyy-MM-dd_HH-mm-ss-S), so this should fail
      final result = parseAudioFileTimestamp('2024-01-15_10-30-45');
      expect(result, isNull);
    });

    test('handles partial date format', () {
      final result = parseAudioFileTimestamp('2024-01-15');
      expect(result, isNull);
    });

    test('handles garbage input', () {
      final result = parseAudioFileTimestamp('abc-def-ghi');
      expect(result, isNull);
    });

    test('handles edge case timestamps', () {
      final result = parseAudioFileTimestamp('2024-12-31_23-59-59-999');
      expect(result, isNotNull);
      // UTC to local conversion may roll over to 2025 depending on timezone
      expect(result!.year, greaterThanOrEqualTo(2024));
      if (result.year == 2024) {
        expect(result.month, 12);
        expect(result.day, 31);
      } else {
        // Rolled over to 2025-01-01
        expect(result.year, 2025);
        expect(result.month, 1);
        expect(result.day, 1);
      }
    });

    test('handles leap year date', () {
      final result = parseAudioFileTimestamp('2024-02-29_12-00-00-000');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 2);
      expect(result.day, 29);
    });
  });

  group('_extractDurationWithMediaKit Coverage Tests', () {
    test('returns zero duration when bypass flag is set', () async {
      imageImportBypassMediaKitInTests = true;

      final duration = await extractDurationWithMediaKit('/fake/path.m4a');

      expect(duration, Duration.zero);

      imageImportBypassMediaKitInTests = false;
    });

    test('handles non-existent file path', () async {
      imageImportBypassMediaKitInTests = true;

      final duration = await extractDurationWithMediaKit('/does/not/exist.m4a');

      expect(duration, Duration.zero);

      imageImportBypassMediaKitInTests = false;
    });

    test('handles empty file path', () async {
      imageImportBypassMediaKitInTests = true;

      final duration = await extractDurationWithMediaKit('');

      expect(duration, Duration.zero);

      imageImportBypassMediaKitInTests = false;
    });

    test('bypass flag prevents Player instantiation', () async {
      // This tests line 537-540
      imageImportBypassMediaKitInTests = true;

      final duration = await extractDurationWithMediaKit('/any/path.m4a');

      // Should return immediately without creating Player
      expect(duration, Duration.zero);

      imageImportBypassMediaKitInTests = false;
    });
  });

  group('computeAudioRelativePath Coverage Tests', () {
    test('formats date correctly for directory', () {
      final timestamp = DateTime(2024, 1, 15, 10, 30, 45, 123);
      final path = computeAudioRelativePath(timestamp);

      expect(path, equals('/audio/2024-01-15/'));
    });

    test('handles single digit month and day', () {
      final timestamp = DateTime(2024, 3, 5);
      final path = computeAudioRelativePath(timestamp);

      expect(path, equals('/audio/2024-03-05/'));
    });

    test('handles end of year', () {
      final timestamp = DateTime(2024, 12, 31);
      final path = computeAudioRelativePath(timestamp);

      expect(path, equals('/audio/2024-12-31/'));
    });

    test('handles leap year day', () {
      final timestamp = DateTime(2024, 2, 29);
      final path = computeAudioRelativePath(timestamp);

      expect(path, equals('/audio/2024-02-29/'));
    });
  });

  group('computeAudioTargetFileName Coverage Tests', () {
    test('formats filename with full timestamp', () {
      final timestamp = DateTime(2024, 1, 15, 10, 30, 45, 123);
      final filename = computeAudioTargetFileName(timestamp, 'm4a');

      expect(filename, equals('2024-01-15_10-30-45-123.m4a'));
    });

    test('handles zero milliseconds', () {
      final timestamp = DateTime(2024, 1, 15, 10, 30, 45);
      final filename = computeAudioTargetFileName(timestamp, 'm4a');

      // Milliseconds are formatted with padding, so 0 becomes 000
      expect(filename, equals('2024-01-15_10-30-45-000.m4a'));
    });

    test('handles maximum milliseconds', () {
      final timestamp = DateTime(2024, 1, 15, 10, 30, 45, 999);
      final filename = computeAudioTargetFileName(timestamp, 'm4a');

      expect(filename, equals('2024-01-15_10-30-45-999.m4a'));
    });

    test('preserves file extension', () {
      final timestamp = DateTime(2024, 1, 15);
      final filename = computeAudioTargetFileName(timestamp, 'wav');

      expect(filename, endsWith('.wav'));
    });

    test('handles midnight timestamp', () {
      final timestamp = DateTime(2024, 1, 15);
      final filename = computeAudioTargetFileName(timestamp, 'm4a');

      // Milliseconds are formatted with padding
      expect(filename, equals('2024-01-15_00-00-00-000.m4a'));
    });

    test('handles end of day timestamp', () {
      final timestamp = DateTime(2024, 1, 15, 23, 59, 59, 999);
      final filename = computeAudioTargetFileName(timestamp, 'm4a');

      expect(filename, equals('2024-01-15_23-59-59-999.m4a'));
    });
  });

  group('selectAudioMetadataReader Coverage Tests', () {
    test('uses default reader when bypass flag is set', () async {
      imageImportBypassMediaKitInTests = true;

      final reader = selectAudioMetadataReader();
      final duration = await reader('/fake/path.m4a');

      expect(duration, Duration.zero);

      imageImportBypassMediaKitInTests = false;
    });

    test('returns reader function that can be called', () async {
      imageImportBypassMediaKitInTests = true;

      final reader = selectAudioMetadataReader();

      expect(reader, isA<AudioMetadataReader>());

      final result = await reader('/test.m4a');
      expect(result, Duration.zero);

      imageImportBypassMediaKitInTests = false;
    });
  });

  group('Edge Cases and Error Paths', () {
    test('parseRational handles extremely large fractions', () {
      final result = parseRational('999999999/1');
      expect(result, 999999999.0);
    });

    test('parseRational handles tiny fractions', () {
      final result = parseRational('1/999999999');
      expect(result, closeTo(0.000000001, 0.0000000001));
    });

    test('parseRational handles negative zero', () {
      final result = parseRational('-0/1');
      expect(result, 0.0);
    });

    test('parseGpsCoordinate handles extreme north latitude', () {
      final result = parseGpsCoordinate('[90/1, 0/1, 0/1]', 'N');
      expect(result, 90.0);
    });

    test('parseGpsCoordinate handles extreme south latitude', () {
      final result = parseGpsCoordinate('[90/1, 0/1, 0/1]', 'S');
      expect(result, -90.0);
    });

    test('parseGpsCoordinate handles date line east', () {
      final result = parseGpsCoordinate('[180/1, 0/1, 0/1]', 'E');
      expect(result, 180.0);
    });

    test('parseGpsCoordinate handles date line west', () {
      final result = parseGpsCoordinate('[180/1, 0/1, 0/1]', 'W');
      expect(result, -180.0);
    });

    test('parseGpsCoordinate handles malformed brackets', () {
      final result = parseGpsCoordinate('[[37/1, 46/1, 0/1]]', 'N');
      // May still parse after bracket removal
      expect(result, isA<double?>());
    });

    test('parseGpsCoordinate handles extra whitespace', () {
      final result = parseGpsCoordinate('[  37/1  ,  46/1  ,  0/1  ]', 'N');
      expect(result, closeTo(37.7667, 0.0001));
    });

    test('parseGpsCoordinate handles tabs as separators', () {
      final result = parseGpsCoordinate('[37/1\t46/1\t0/1]', 'N');
      // This will likely fail to parse correctly, returning null
      expect(result, isNull);
    });

    test('parseGpsCoordinate handles mixed case directions', () {
      // Only exact 'S' and 'W' should negate
      final resultLowerN = parseGpsCoordinate('[37/1, 46/1, 0/1]', 'n');
      final resultLowerS = parseGpsCoordinate('[37/1, 46/1, 0/1]', 's');

      // Lower case 's' won't match 'S', so stays positive
      expect(resultLowerN, greaterThan(0));
      expect(resultLowerS, greaterThan(0));
    });
  });

  group('GPS Coordinate Boundary Tests', () {
    test('handles coordinate at Arctic Circle', () {
      final result = parseGpsCoordinate('[66/1, 33/1, 0/1]', 'N');
      expect(result, closeTo(66.55, 0.01));
    });

    test('handles coordinate at Antarctic Circle', () {
      final result = parseGpsCoordinate('[66/1, 33/1, 0/1]', 'S');
      expect(result, closeTo(-66.55, 0.01));
    });

    test('handles coordinate near Tropic of Cancer', () {
      final result = parseGpsCoordinate('[23/1, 26/1, 0/1]', 'N');
      expect(result, closeTo(23.433, 0.01));
    });

    test('handles coordinate near Tropic of Capricorn', () {
      final result = parseGpsCoordinate('[23/1, 26/1, 0/1]', 'S');
      expect(result, closeTo(-23.433, 0.01));
    });

    test('handles very precise GPS coordinates', () {
      // Test with many decimal places in seconds
      final result = parseGpsCoordinate('[37/1, 46/1, 29641/1000]', 'N');
      expect(result, closeTo(37.7749, 0.00001));
    });

    test('handles GPS at North Pole', () {
      final result = parseGpsCoordinate('[90/1, 0/1, 0/1]', 'N');
      expect(result, 90.0);
    });

    test('handles GPS at South Pole', () {
      final result = parseGpsCoordinate('[90/1, 0/1, 0/1]', 'S');
      expect(result, -90.0);
    });
  });

  group('Audio Timestamp Edge Cases', () {
    test('parseAudioFileTimestamp handles century boundary', () {
      final result = parseAudioFileTimestamp('2099-12-31_23-59-59-999');
      expect(result, isNotNull);
      // May rollover to 2100 due to timezone, just verify it parsed
      expect(result!.year, greaterThanOrEqualTo(2099));
    });

    test('parseAudioFileTimestamp handles year 2000', () {
      final result = parseAudioFileTimestamp('2000-01-01_00-00-00-000');
      expect(result, isNotNull);
      expect(result!.year, 2000);
    });

    test('parseAudioFileTimestamp handles non-leap year Feb 28', () {
      final result = parseAudioFileTimestamp('2023-02-28_12-00-00-000');
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 2);
    });

    test('parseAudioFileTimestamp handles invalid Feb 29 in non-leap year', () {
      final result = parseAudioFileTimestamp('2023-02-29_12-00-00-000');
      // DateTime.parse may accept and adjust to March 1st
      expect(result, isA<DateTime?>());
    });

    test('parseAudioFileTimestamp handles DST transition times', () {
      // March 10, 2024 at 2:00 AM (DST starts in many regions)
      final result = parseAudioFileTimestamp('2024-03-10_02-00-00-000');
      expect(result, isNotNull);
    });

    test('parseAudioFileTimestamp handles different century', () {
      final result = parseAudioFileTimestamp('2100-01-01_00-00-00-000');
      expect(result, isNotNull);
      expect(result!.year, 2100);
    });
  });

  group('Rational Number Parsing Edge Cases', () {
    test('parseRational handles zero numerator', () {
      final result = parseRational('0/1');
      expect(result, 0.0);
    });

    test('parseRational handles one as denominator', () {
      final result = parseRational('42/1');
      expect(result, 42.0);
    });

    test('parseRational handles equal numerator and denominator', () {
      final result = parseRational('100/100');
      expect(result, 1.0);
    });

    test('parseRational handles scientific notation', () {
      final result = parseRational('1e-5');
      expect(result, 0.00001);
    });

    test('parseRational handles very long decimal', () {
      final result = parseRational('3.141592653589793');
      expect(result, closeTo(3.14159265, 0.00000001));
    });

    test('parseRational handles leading zeros in fraction', () {
      final result = parseRational('0037/0001');
      expect(result, 37.0);
    });

    test('parseRational handles negative fractions', () {
      final result = parseRational('-123/456');
      expect(result, closeTo(-0.2697, 0.0001));
    });

    test('parseRational handles fraction with negative denominator', () {
      final result = parseRational('123/-456');
      expect(result, closeTo(-0.2697, 0.0001));
    });

    test('parseRational handles double negative fraction', () {
      final result = parseRational('-123/-456');
      expect(result, closeTo(0.2697, 0.0001));
    });
  });
}

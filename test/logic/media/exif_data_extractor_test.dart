import 'package:exif/exif.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/logic/media/exif_data_extractor.dart';

void main() {
  group('ExifDataExtractor', () {
    group('parseRational', () {
      test('parses valid fraction with denominator 1', () {
        expect(ExifDataExtractor.parseRational('37/1'), equals(37.0));
      });

      test('parses valid fraction with larger denominator', () {
        expect(ExifDataExtractor.parseRational('2964/100'), equals(29.64));
      });

      test('parses decimal number', () {
        expect(ExifDataExtractor.parseRational('37.7749'), equals(37.7749));
      });

      test('handles division by zero', () {
        expect(ExifDataExtractor.parseRational('37/0'), isNull);
      });

      test('handles invalid fraction format with too many parts', () {
        expect(ExifDataExtractor.parseRational('37/1/2'), isNull);
      });

      test('handles invalid fraction format with too few parts', () {
        expect(ExifDataExtractor.parseRational('37/'), isNull);
      });

      test('handles non-numeric fraction', () {
        expect(ExifDataExtractor.parseRational('abc/def'), isNull);
      });

      test('handles empty string', () {
        expect(ExifDataExtractor.parseRational(''), isNull);
      });

      test('handles invalid decimal', () {
        expect(ExifDataExtractor.parseRational('not_a_number'), isNull);
      });

      test('parses zero fraction', () {
        expect(ExifDataExtractor.parseRational('0/1'), equals(0.0));
      });

      test('parses negative fraction', () {
        expect(ExifDataExtractor.parseRational('-37/1'), equals(-37.0));
      });

      test('parses negative decimal', () {
        expect(ExifDataExtractor.parseRational('-122.4194'), equals(-122.4194));
      });

      test('handles whitespace', () {
        expect(ExifDataExtractor.parseRational('  37/1  '), equals(37.0));
      });

      test('handles very small fraction', () {
        expect(
          ExifDataExtractor.parseRational('1/1000000'),
          closeTo(0.000001, 0.0000001),
        );
      });

      test('handles large numerator', () {
        expect(ExifDataExtractor.parseRational('999999/1'), equals(999999.0));
      });
    });

    group('parseGpsCoordinate', () {
      test('parses North latitude correctly', () {
        // San Francisco: 37° 46' 29.64" N
        final result =
            ExifDataExtractor.parseGpsCoordinate('[37/1, 46/1, 2964/100]', 'N');
        expect(result, closeTo(37.7749, 0.0001));
      });

      test('parses South latitude with negative sign', () {
        // Sydney: 33° 52' 0" S
        final result =
            ExifDataExtractor.parseGpsCoordinate('[33/1, 52/1, 0/1]', 'S');
        expect(result, closeTo(-33.8667, 0.0001));
      });

      test('parses East longitude correctly', () {
        // Sydney: 151° 12' 0" E
        final result =
            ExifDataExtractor.parseGpsCoordinate('[151/1, 12/1, 0/1]', 'E');
        expect(result, closeTo(151.2, 0.0001));
      });

      test('parses West longitude with negative sign', () {
        // San Francisco: 122° 25' 9.84" W
        final result =
            ExifDataExtractor.parseGpsCoordinate('[122/1, 25/1, 984/100]', 'W');
        expect(result, closeTo(-122.4194, 0.0001));
      });

      test('handles null coordinate data', () {
        expect(ExifDataExtractor.parseGpsCoordinate(null, 'N'), isNull);
      });

      test('handles invalid parts count - too few', () {
        expect(
          ExifDataExtractor.parseGpsCoordinate('[37/1, 46/1]', 'N'),
          isNull,
        );
      });

      test('handles invalid parts count - too many', () {
        expect(
          ExifDataExtractor.parseGpsCoordinate('[37/1, 46/1, 0/1, 0/1]', 'N'),
          isNull,
        );
      });

      test('handles invalid rational in degrees', () {
        expect(
          ExifDataExtractor.parseGpsCoordinate('[abc/1, 46/1, 0/1]', 'N'),
          isNull,
        );
      });

      test('handles invalid rational in minutes', () {
        expect(
          ExifDataExtractor.parseGpsCoordinate('[37/1, xyz/1, 0/1]', 'N'),
          isNull,
        );
      });

      test('handles invalid rational in seconds', () {
        expect(
          ExifDataExtractor.parseGpsCoordinate('[37/1, 46/1, bad/1]', 'N'),
          isNull,
        );
      });

      test('handles empty string', () {
        expect(ExifDataExtractor.parseGpsCoordinate('', 'N'), isNull);
      });

      test('handles coordinates at equator', () {
        final result =
            ExifDataExtractor.parseGpsCoordinate('[0/1, 0/1, 0/1]', 'N');
        expect(result, equals(0.0));
      });

      test('handles coordinates at prime meridian', () {
        final result =
            ExifDataExtractor.parseGpsCoordinate('[0/1, 0/1, 0/1]', 'E');
        expect(result, equals(0.0));
      });

      test('handles maximum latitude North Pole', () {
        final result =
            ExifDataExtractor.parseGpsCoordinate('[90/1, 0/1, 0/1]', 'N');
        expect(result, equals(90.0));
      });

      test('handles maximum latitude South Pole', () {
        final result =
            ExifDataExtractor.parseGpsCoordinate('[90/1, 0/1, 0/1]', 'S');
        expect(result, equals(-90.0));
      });

      test('handles date line crossing West', () {
        final result =
            ExifDataExtractor.parseGpsCoordinate('[180/1, 0/1, 0/1]', 'W');
        expect(result, equals(-180.0));
      });

      test('handles date line crossing East', () {
        final result =
            ExifDataExtractor.parseGpsCoordinate('[180/1, 0/1, 0/1]', 'E');
        expect(result, equals(180.0));
      });

      test('handles whitespace in coordinates', () {
        final result = ExifDataExtractor.parseGpsCoordinate(
          '[  37/1  ,  46/1  ,  0/1  ]',
          'N',
        );
        expect(result, closeTo(37.7667, 0.0001));
      });

      test('handles coordinates without brackets', () {
        final result =
            ExifDataExtractor.parseGpsCoordinate('37/1, 46/1, 0/1', 'N');
        expect(result, closeTo(37.7667, 0.0001));
      });

      test('handles fractional seconds', () {
        // 37° 46' 29.64" N (with fractional seconds)
        final result =
            ExifDataExtractor.parseGpsCoordinate('[37/1, 46/1, 2964/100]', 'N');
        expect(result, closeTo(37.7749, 0.0001));
      });

      test('handles high precision coordinates', () {
        // High precision: 37° 46' 29.999" N
        final result = ExifDataExtractor.parseGpsCoordinate(
          '[37/1, 46/1, 29999/1000]',
          'N',
        );
        expect(result, closeTo(37.774999, 0.000001));
      });

      test('handles malformed input gracefully', () {
        expect(ExifDataExtractor.parseGpsCoordinate('[error', 'N'), isNull);
      });
    });

    group('parseExifDateString', () {
      test('parses valid EXIF datetime format', () {
        final result =
            ExifDataExtractor.parseExifDateString('2023:12:25 14:30:45');
        expect(result, DateTime(2023, 12, 25, 14, 30, 45));
      });

      test('parses midnight timestamp', () {
        final result =
            ExifDataExtractor.parseExifDateString('2024:01:15 00:00:00');
        expect(result, DateTime(2024, 1, 15));
      });

      test('parses end of day timestamp', () {
        final result =
            ExifDataExtractor.parseExifDateString('2024:12:31 23:59:59');
        expect(result, DateTime(2024, 12, 31, 23, 59, 59));
      });

      test('returns null for null input', () {
        expect(ExifDataExtractor.parseExifDateString(null), isNull);
      });

      test('returns null for empty string', () {
        expect(ExifDataExtractor.parseExifDateString(''), isNull);
      });

      test('returns null for invalid format - no space', () {
        expect(
          ExifDataExtractor.parseExifDateString('2023:12:25T14:30:45'),
          isNull,
        );
      });

      test('returns null for invalid format - only date', () {
        expect(ExifDataExtractor.parseExifDateString('2023:12:25'), isNull);
      });

      test('returns null for invalid format - only time', () {
        expect(ExifDataExtractor.parseExifDateString('14:30:45'), isNull);
      });

      test('returns null for non-numeric date values', () {
        // Non-numeric values should return null
        expect(
          ExifDataExtractor.parseExifDateString('abcd:ef:gh ij:kl:mn'),
          isNull,
        );
      });

      test('returns null for non-date string', () {
        expect(ExifDataExtractor.parseExifDateString('not a date'), isNull);
      });

      test('parses ISO-like format if it happens to be valid', () {
        // The function converts ':' to '-' in date part, so if input already
        // has dashes, they remain. This happens to parse successfully.
        // This is acceptable behavior - the function is designed for EXIF format
        // but doesn't strictly reject other formats that happen to parse.
        final result =
            ExifDataExtractor.parseExifDateString('2023-12-25 14:30:45');
        expect(result, DateTime(2023, 12, 25, 14, 30, 45));
      });
    });

    group('extractTimestamp', () {
      test('returns null for null exifData', () {
        expect(ExifDataExtractor.extractTimestamp(null), isNull);
      });

      test('returns null for empty exifData', () {
        expect(ExifDataExtractor.extractTimestamp({}), isNull);
      });

      test('returns null when no timestamp keys present', () {
        final exifData = <String, IfdTag>{
          'Image Width': _createMockIfdTag('1920'),
          'Image Height': _createMockIfdTag('1080'),
        };
        expect(ExifDataExtractor.extractTimestamp(exifData), isNull);
      });

      test('extracts DateTimeOriginal when present', () {
        final exifData = <String, IfdTag>{
          'EXIF DateTimeOriginal': _createMockIfdTag('2024:01:15 10:20:30'),
        };
        final result = ExifDataExtractor.extractTimestamp(exifData);
        expect(result, DateTime(2024, 1, 15, 10, 20, 30));
      });

      test('extracts Image DateTime when DateTimeOriginal missing', () {
        final exifData = <String, IfdTag>{
          'Image DateTime': _createMockIfdTag('2022:06:10 08:15:22'),
        };
        final result = ExifDataExtractor.extractTimestamp(exifData);
        expect(result, DateTime(2022, 6, 10, 8, 15, 22));
      });

      test('prefers DateTimeOriginal over Image DateTime', () {
        final exifData = <String, IfdTag>{
          'EXIF DateTimeOriginal': _createMockIfdTag('2024:01:15 10:20:30'),
          'Image DateTime': _createMockIfdTag('2022:06:10 08:15:22'),
        };
        final result = ExifDataExtractor.extractTimestamp(exifData);
        // DateTimeOriginal should be preferred
        expect(result, DateTime(2024, 1, 15, 10, 20, 30));
      });

      test('returns null for malformed timestamp value', () {
        final exifData = <String, IfdTag>{
          'EXIF DateTimeOriginal': _createMockIfdTag('invalid'),
        };
        expect(ExifDataExtractor.extractTimestamp(exifData), isNull);
      });

      test('falls back to Image DateTime when DateTimeOriginal is malformed',
          () {
        final exifData = <String, IfdTag>{
          'EXIF DateTimeOriginal': _createMockIfdTag('invalid'),
          'Image DateTime': _createMockIfdTag('2022:06:10 08:15:22'),
        };
        final result = ExifDataExtractor.extractTimestamp(exifData);
        expect(result, DateTime(2022, 6, 10, 8, 15, 22));
      });
    });

    group('extractGpsCoordinates', () {
      test('returns null for null exifData', () {
        expect(
          ExifDataExtractor.extractGpsCoordinates(
            null,
            DateTime(2024, 1, 15),
          ),
          isNull,
        );
      });

      test('returns null for empty exifData', () {
        expect(
          ExifDataExtractor.extractGpsCoordinates({}, DateTime(2024, 1, 15)),
          isNull,
        );
      });

      test('returns null when GPS latitude is missing', () {
        final exifData = <String, IfdTag>{
          'GPS GPSLongitude': _createMockIfdTag('[122/1, 25/1, 984/100]'),
          'GPS GPSLatitudeRef': _createMockIfdTag('N'),
          'GPS GPSLongitudeRef': _createMockIfdTag('W'),
        };
        expect(
          ExifDataExtractor.extractGpsCoordinates(
            exifData,
            DateTime(2024, 1, 15),
          ),
          isNull,
        );
      });

      test('returns null when GPS longitude is missing', () {
        final exifData = <String, IfdTag>{
          'GPS GPSLatitude': _createMockIfdTag('[37/1, 46/1, 2964/100]'),
          'GPS GPSLatitudeRef': _createMockIfdTag('N'),
          'GPS GPSLongitudeRef': _createMockIfdTag('W'),
        };
        expect(
          ExifDataExtractor.extractGpsCoordinates(
            exifData,
            DateTime(2024, 1, 15),
          ),
          isNull,
        );
      });

      test('returns null when latitude ref is missing', () {
        final exifData = <String, IfdTag>{
          'GPS GPSLatitude': _createMockIfdTag('[37/1, 46/1, 2964/100]'),
          'GPS GPSLongitude': _createMockIfdTag('[122/1, 25/1, 984/100]'),
          'GPS GPSLongitudeRef': _createMockIfdTag('W'),
        };
        expect(
          ExifDataExtractor.extractGpsCoordinates(
            exifData,
            DateTime(2024, 1, 15),
          ),
          isNull,
        );
      });

      test('returns null when longitude ref is missing', () {
        final exifData = <String, IfdTag>{
          'GPS GPSLatitude': _createMockIfdTag('[37/1, 46/1, 2964/100]'),
          'GPS GPSLongitude': _createMockIfdTag('[122/1, 25/1, 984/100]'),
          'GPS GPSLatitudeRef': _createMockIfdTag('N'),
        };
        expect(
          ExifDataExtractor.extractGpsCoordinates(
            exifData,
            DateTime(2024, 1, 15),
          ),
          isNull,
        );
      });

      test('extracts valid GPS coordinates - San Francisco', () {
        final exifData = <String, IfdTag>{
          'GPS GPSLatitude': _createMockIfdTag('[37/1, 46/1, 2964/100]'),
          'GPS GPSLongitude': _createMockIfdTag('[122/1, 25/1, 984/100]'),
          'GPS GPSLatitudeRef': _createMockIfdTag('N'),
          'GPS GPSLongitudeRef': _createMockIfdTag('W'),
        };
        final timestamp = DateTime(2024, 1, 15, 10, 20, 30);

        final result =
            ExifDataExtractor.extractGpsCoordinates(exifData, timestamp);

        expect(result, isNotNull);
        expect(result!.latitude, closeTo(37.7749, 0.0001));
        expect(result.longitude, closeTo(-122.4194, 0.0001));
        expect(result.createdAt, equals(timestamp));
        expect(result.geohashString, isNotEmpty);
      });

      test('extracts valid GPS coordinates - Sydney', () {
        final exifData = <String, IfdTag>{
          'GPS GPSLatitude': _createMockIfdTag('[33/1, 52/1, 0/1]'),
          'GPS GPSLongitude': _createMockIfdTag('[151/1, 12/1, 0/1]'),
          'GPS GPSLatitudeRef': _createMockIfdTag('S'),
          'GPS GPSLongitudeRef': _createMockIfdTag('E'),
        };
        final timestamp = DateTime(2024, 6, 15);

        final result =
            ExifDataExtractor.extractGpsCoordinates(exifData, timestamp);

        expect(result, isNotNull);
        expect(result!.latitude, closeTo(-33.8667, 0.0001));
        expect(result.longitude, closeTo(151.2, 0.0001));
      });

      test('extracts coordinates at equator/prime meridian', () {
        final exifData = <String, IfdTag>{
          'GPS GPSLatitude': _createMockIfdTag('[0/1, 0/1, 0/1]'),
          'GPS GPSLongitude': _createMockIfdTag('[0/1, 0/1, 0/1]'),
          'GPS GPSLatitudeRef': _createMockIfdTag('N'),
          'GPS GPSLongitudeRef': _createMockIfdTag('E'),
        };
        final timestamp = DateTime(2024);

        final result =
            ExifDataExtractor.extractGpsCoordinates(exifData, timestamp);

        expect(result, isNotNull);
        expect(result!.latitude, equals(0.0));
        expect(result.longitude, equals(0.0));
      });

      test('returns null when latitude coordinate is invalid', () {
        final exifData = <String, IfdTag>{
          'GPS GPSLatitude': _createMockIfdTag('invalid'),
          'GPS GPSLongitude': _createMockIfdTag('[122/1, 25/1, 984/100]'),
          'GPS GPSLatitudeRef': _createMockIfdTag('N'),
          'GPS GPSLongitudeRef': _createMockIfdTag('W'),
        };
        expect(
          ExifDataExtractor.extractGpsCoordinates(
            exifData,
            DateTime(2024, 1, 15),
          ),
          isNull,
        );
      });

      test('returns null when longitude coordinate is invalid', () {
        final exifData = <String, IfdTag>{
          'GPS GPSLatitude': _createMockIfdTag('[37/1, 46/1, 2964/100]'),
          'GPS GPSLongitude': _createMockIfdTag('invalid'),
          'GPS GPSLatitudeRef': _createMockIfdTag('N'),
          'GPS GPSLongitudeRef': _createMockIfdTag('W'),
        };
        expect(
          ExifDataExtractor.extractGpsCoordinates(
            exifData,
            DateTime(2024, 1, 15),
          ),
          isNull,
        );
      });

      test('geolocation includes geohash string', () {
        final exifData = <String, IfdTag>{
          'GPS GPSLatitude': _createMockIfdTag('[37/1, 46/1, 2964/100]'),
          'GPS GPSLongitude': _createMockIfdTag('[122/1, 25/1, 984/100]'),
          'GPS GPSLatitudeRef': _createMockIfdTag('N'),
          'GPS GPSLongitudeRef': _createMockIfdTag('W'),
        };
        final timestamp = DateTime(2024, 1, 15);

        final result =
            ExifDataExtractor.extractGpsCoordinates(exifData, timestamp);

        expect(result, isNotNull);
        // San Francisco geohash starts with '9q8'
        expect(result!.geohashString, startsWith('9q8'));
      });
    });

    group('constants', () {
      test('GPS keys are correctly defined', () {
        expect(ExifDataExtractor.exifGpsLatitudeKey, 'GPS GPSLatitude');
        expect(ExifDataExtractor.exifGpsLongitudeKey, 'GPS GPSLongitude');
        expect(ExifDataExtractor.exifGpsLatitudeRefKey, 'GPS GPSLatitudeRef');
        expect(ExifDataExtractor.exifGpsLongitudeRefKey, 'GPS GPSLongitudeRef');
      });

      test('timestamp keys are in priority order', () {
        expect(ExifDataExtractor.exifTimestampKeys.length, 2);
        expect(
          ExifDataExtractor.exifTimestampKeys[0],
          'EXIF DateTimeOriginal',
        );
        expect(ExifDataExtractor.exifTimestampKeys[1], 'Image DateTime');
      });
    });
  });
}

/// Creates an IfdTag that returns the given value when toString() is called.
///
/// Uses the printable field of IfdTag which is returned by toString().
IfdTag _createMockIfdTag(String value) {
  return IfdTag(
    tag: 0,
    tagType: 'String',
    printable: value,
    values: const IfdNone(),
  );
}

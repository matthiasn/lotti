import 'package:exif/exif.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/utils/geohash.dart';

/// Pure utility class for extracting and parsing EXIF metadata.
///
/// All methods are static and have no side effects - they either return
/// parsed data or null for invalid/missing data. No logging or external
/// dependencies, making this class easily testable.
///
/// ## Usage
///
/// ```dart
/// final exifData = await readExifFromBytes(imageBytes);
/// final timestamp = ExifDataExtractor.extractTimestamp(exifData);
/// final geolocation = ExifDataExtractor.extractGpsCoordinates(
///   exifData,
///   timestamp ?? DateTime.now(),
/// );
/// ```
class ExifDataExtractor {
  const ExifDataExtractor._();

  // EXIF GPS keys
  static const String exifGpsLatitudeKey = 'GPS GPSLatitude';
  static const String exifGpsLongitudeKey = 'GPS GPSLongitude';
  static const String exifGpsLatitudeRefKey = 'GPS GPSLatitudeRef';
  static const String exifGpsLongitudeRefKey = 'GPS GPSLongitudeRef';

  // EXIF timestamp keys in order of preference
  static const List<String> exifTimestampKeys = [
    'EXIF DateTimeOriginal', // Preferred for photos
    'Image DateTime', // Fallback to file modification time
  ];

  /// Parses a rational number from EXIF format.
  ///
  /// EXIF rational numbers can be in fraction format (e.g., "123/456")
  /// or decimal format (e.g., "45.67").
  ///
  /// Returns the numeric value as a double, or null if parsing fails.
  ///
  /// Examples:
  /// - "37/1" → 37.0
  /// - "2964/100" → 29.64
  /// - "37.7749" → 37.7749
  /// - "37/0" → null (division by zero)
  /// - "abc/def" → null (non-numeric)
  static double? parseRational(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    try {
      if (trimmed.contains('/')) {
        // Parse fraction format
        final parts = trimmed.split('/');
        if (parts.length != 2) {
          return null;
        }
        final numerator = double.parse(parts[0]);
        final denominator = double.parse(parts[1]);
        if (denominator == 0) {
          return null;
        }
        return numerator / denominator;
      } else {
        // Parse decimal format
        return double.parse(trimmed);
      }
    } catch (e) {
      return null;
    }
  }

  /// Parses GPS coordinate from EXIF data to decimal degrees.
  ///
  /// Converts EXIF GPS format (degrees, minutes, seconds) to decimal degrees.
  /// The coordinate data is typically in the format "[deg/1, min/1, sec/100]".
  /// The reference indicates direction: 'N', 'S' for latitude, 'E', 'W' for longitude.
  ///
  /// Returns decimal degrees as a double, or null if parsing fails.
  ///
  /// Examples:
  /// - ("[37/1, 46/1, 2964/100]", "N") → 37.7749 (San Francisco latitude)
  /// - ("[122/1, 25/1, 984/100]", "W") → -122.4194 (San Francisco longitude)
  /// - (null, "N") → null
  static double? parseGpsCoordinate(dynamic coordData, String ref) {
    if (coordData == null) {
      return null;
    }

    try {
      // Convert to string and clean up brackets
      final coordStr =
          coordData.toString().replaceAll('[', '').replaceAll(']', '');
      final parts = coordStr.split(',');

      if (parts.length != 3) {
        return null;
      }

      // Parse degrees, minutes, seconds using rational parser
      final degrees = parseRational(parts[0].trim());
      final minutes = parseRational(parts[1].trim());
      final seconds = parseRational(parts[2].trim());

      if (degrees == null || minutes == null || seconds == null) {
        return null;
      }

      // Convert to decimal degrees
      var decimal = degrees + (minutes / 60.0) + (seconds / 3600.0);

      // Apply directional sign (South and West are negative)
      if (ref == 'S' || ref == 'W') {
        decimal = -decimal;
      }

      return decimal;
    } catch (e) {
      return null;
    }
  }

  /// Parses EXIF DateTime string format to DateTime.
  ///
  /// EXIF format is "yyyy:MM:dd HH:mm:ss" (e.g., "2023:12:25 14:30:45").
  /// Returns the parsed DateTime if successful, null otherwise.
  ///
  /// Examples:
  /// - "2023:12:25 14:30:45" → DateTime(2023, 12, 25, 14, 30, 45)
  /// - "invalid" → null
  /// - null → null
  static DateTime? parseExifDateString(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return null;
    }

    try {
      // EXIF format: "2023:12:25 14:30:45"
      // Replace colons in date part with dashes for standard parsing
      final parts = dateString.split(' ');
      if (parts.length != 2) {
        return null;
      }
      final datePart = parts[0].replaceAll(':', '-');
      final timePart = parts[1];
      final standardFormat = '$datePart $timePart';
      return DateTime.parse(standardFormat);
    } catch (e) {
      return null;
    }
  }

  /// Extracts timestamp from EXIF data.
  ///
  /// Attempts to read DateTimeOriginal or DateTime from EXIF metadata.
  /// Returns the parsed DateTime if found, null otherwise.
  ///
  /// The method tries keys in this order:
  /// 1. EXIF DateTimeOriginal (preferred for photos)
  /// 2. Image DateTime (file modification time fallback)
  static DateTime? extractTimestamp(Map<String, IfdTag>? exifData) {
    if (exifData == null) {
      return null;
    }

    for (final key in exifTimestampKeys) {
      if (exifData.containsKey(key)) {
        final dateTimeStr = exifData[key].toString();
        final parsed = parseExifDateString(dateTimeStr);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  /// Extracts GPS coordinates from EXIF data.
  ///
  /// Returns a [Geolocation] object if valid GPS data is found in the EXIF
  /// metadata, null otherwise. Missing GPS data is common and not considered
  /// an error.
  ///
  /// The returned Geolocation includes:
  /// - latitude and longitude in decimal degrees
  /// - geohash string for the location
  /// - createdAt timestamp (passed as parameter)
  static Geolocation? extractGpsCoordinates(
    Map<String, IfdTag>? exifData,
    DateTime createdAt,
  ) {
    if (exifData == null) {
      return null;
    }

    // Check for required GPS keys
    if (!exifData.containsKey(exifGpsLatitudeKey) ||
        !exifData.containsKey(exifGpsLongitudeKey) ||
        !exifData.containsKey(exifGpsLatitudeRefKey) ||
        !exifData.containsKey(exifGpsLongitudeRefKey)) {
      return null;
    }

    // Extract GPS data
    final latitudeData = exifData[exifGpsLatitudeKey];
    final longitudeData = exifData[exifGpsLongitudeKey];
    final latitudeRef = exifData[exifGpsLatitudeRefKey].toString();
    final longitudeRef = exifData[exifGpsLongitudeRefKey].toString();

    // Parse coordinates
    final latitude = parseGpsCoordinate(latitudeData, latitudeRef);
    final longitude = parseGpsCoordinate(longitudeData, longitudeRef);

    if (latitude == null || longitude == null) {
      return null;
    }

    // Create Geolocation object with geohash
    return Geolocation(
      createdAt: createdAt,
      latitude: latitude,
      longitude: longitude,
      geohashString: getGeoHash(
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:exif/exif.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/media/audio_metadata_extractor.dart';
import 'package:lotti/logic/media/exif_data_extractor.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/geohash.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// Creates an onCreated callback for automatic image analysis.
///
/// Returns null if [analysisTrigger] is null, otherwise returns a callback
/// that triggers automatic image analysis in a fire-and-forget manner.
void Function(JournalEntity)? _createAnalysisCallback(
  AutomaticImageAnalysisTrigger? analysisTrigger,
  String? categoryId,
  String? linkedId,
) {
  if (analysisTrigger == null) return null;
  return (entity) => unawaited(
        analysisTrigger.triggerAutomaticImageAnalysis(
          imageEntryId: entity.id,
          categoryId: categoryId,
          linkedTaskId: linkedId,
        ),
      );
}

/// Constants for media import operations
class MediaImportConstants {
  const MediaImportConstants._();

  // Supported file extensions
  static const Set<String> supportedImageExtensions = {'jpg', 'jpeg', 'png'};
  static const Set<String> supportedAudioExtensions = {'m4a'};

  // Directory paths
  static const String imagesDirectoryPrefix = '/images/';

  // File size limits (in bytes)
  static const int maxAudioFileSizeBytes = 500 * 1024 * 1024; // 500 MB
  static const int maxImageFileSizeBytes = 50 * 1024 * 1024; // 50 MB

  // Logging domain
  static const String loggingDomain = 'media_import';
}

/// Imports images from the device's photo library.
///
/// Opens a photo picker UI and creates journal entries for selected images.
/// If [analysisTrigger] is provided, triggers automatic image analysis
/// for each imported image (fire-and-forget, doesn't block import).
Future<void> importImageAssets(
  BuildContext context, {
  String? linkedId,
  String? categoryId,
  AutomaticImageAnalysisTrigger? analysisTrigger,
}) async {
  final ps = await PhotoManager.requestPermissionExtend();
  if (!ps.isAuth) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  final assets = await AssetPicker.pickAssets(
    context,
    pickerConfig: const AssetPickerConfig(
      maxAssets: 50,
      requestType: RequestType.image,
      textDelegate: EnglishAssetPickerTextDelegate(),
    ),
  );

  if (assets != null) {
    for (final asset in assets.toList(growable: false)) {
      Geolocation? geolocation;
      final latLng = await asset.latlngAsync();
      final latitude = latLng?.latitude ?? asset.latitude;
      final longitude = latLng?.longitude ?? asset.longitude;

      if (latitude != null &&
          longitude != null &&
          latitude != 0 &&
          longitude != 0) {
        geolocation = Geolocation(
          createdAt: asset.createDateTime,
          latitude: latitude,
          longitude: longitude,
          geohashString: getGeoHash(
            latitude: latitude,
            longitude: longitude,
          ),
        );
      }

      final createdAt = asset.createDateTime;
      final file = await asset.file;

      if (file != null) {
        final idNamePart = asset.id.split('/').first;
        final originalName = file.path.split('/').last;
        final imageFileName = '$idNamePart.$originalName'
            .replaceAll(
              'HEIC',
              'JPG',
            )
            .replaceAll(
              'PNG',
              'JPG',
            );
        final day = DateFormat(AudioRecorderConstants.directoryDateFormat)
            .format(createdAt);
        final relativePath =
            '${MediaImportConstants.imagesDirectoryPrefix}$day/';
        final directory = await createAssetDirectory(relativePath);
        final targetFilePath = '$directory$imageFileName';
        await compressAndSave(file, targetFilePath);
        final created = asset.createDateTime;

        final imageData = ImageData(
          imageId: asset.id,
          imageFile: imageFileName,
          imageDirectory: relativePath,
          capturedAt: created,
          geolocation: geolocation,
        );

        await JournalRepository.createImageEntry(
          imageData,
          linkedId: linkedId,
          categoryId: categoryId,
          onCreated:
              _createAnalysisCallback(analysisTrigger, categoryId, linkedId),
        );
      }
    }
  }
}

/// Imports dropped image files and creates journal entries.
///
/// Validates file extensions and size limits before importing.
/// Only processes files with supported image extensions.
/// If [analysisTrigger] is provided, triggers automatic image analysis
/// for each imported image (fire-and-forget, doesn't block import).
///
/// Throws exceptions on file system errors which should be handled by caller.
Future<void> importDroppedImages({
  required DropDoneDetails data,
  String? linkedId,
  String? categoryId,
  AutomaticImageAnalysisTrigger? analysisTrigger,
}) async {
  for (final file in data.files) {
    try {
      final lastModified = await file.lastModified();
      final id = uuid.v1();
      final srcPath = file.path;
      final fileExtension = file.name.split('.').last.toLowerCase();

      // Skip non-image files
      if (!MediaImportConstants.supportedImageExtensions
          .contains(fileExtension)) {
        continue;
      }

      // Validate file size
      final fileSize = await File(srcPath).length();
      if (fileSize > MediaImportConstants.maxImageFileSizeBytes) {
        getIt<LoggingService>().captureException(
          'Image file too large: $fileSize bytes',
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importDroppedImages',
        );
        continue;
      }

      final day = DateFormat(AudioRecorderConstants.directoryDateFormat)
          .format(lastModified);
      final relativePath = '${MediaImportConstants.imagesDirectoryPrefix}$day/';
      final directory = await createAssetDirectory(relativePath);
      final targetFileName = '$id.$fileExtension';
      final targetFilePath = '$directory$targetFileName';

      await File(srcPath).copy(targetFilePath);

      final imageData = ImageData(
        imageId: id,
        imageFile: targetFileName,
        imageDirectory: relativePath,
        capturedAt: lastModified,
      );

      await JournalRepository.createImageEntry(
        imageData,
        linkedId: linkedId,
        categoryId: categoryId,
        onCreated:
            _createAnalysisCallback(analysisTrigger, categoryId, linkedId),
      );
    } catch (exception, stackTrace) {
      getIt<LoggingService>().captureException(
        exception,
        domain: MediaImportConstants.loggingDomain,
        subDomain: 'importDroppedImages',
        stackTrace: stackTrace,
      );
      // Continue processing other files even if one fails
    }
  }
}

/// Extracts original timestamp from image EXIF data
///
/// Attempts to read DateTimeOriginal or DateTime from EXIF metadata.
/// Returns the parsed DateTime if found, otherwise returns current time.
Future<DateTime> _extractImageTimestamp(Uint8List data) async {
  try {
    final exifData = await readExifFromBytes(data);
    final timestamp = ExifDataExtractor.extractTimestamp(exifData);
    if (timestamp != null) {
      return timestamp;
    }
  } catch (exception, stackTrace) {
    // Log but don't fail - return current time as fallback
    getIt<LoggingService>().captureException(
      exception,
      domain: MediaImportConstants.loggingDomain,
      subDomain: 'extractImageTimestamp',
      stackTrace: stackTrace,
    );
  }

  // Fallback to current time if EXIF extraction fails
  return DateTime.now();
}

/// Parses a rational number from EXIF format
///
/// EXIF rational numbers can be in fraction format (e.g., "123/456")
/// or decimal format (e.g., "45.67").
/// Returns the numeric value as a double, or null if parsing fails.
///
/// Delegates to [ExifDataExtractor.parseRational].
@visibleForTesting
double? parseRational(String value) => ExifDataExtractor.parseRational(value);

/// Parses GPS coordinate from EXIF data to decimal degrees
///
/// Converts EXIF GPS format (degrees, minutes, seconds) to decimal degrees.
/// The coordinate data is typically in the format "[deg/1, min/1, sec/100]".
/// The reference indicates direction: 'N', 'S' for latitude, 'E', 'W' for longitude.
/// Returns decimal degrees as a double, or null if parsing fails.
///
/// Delegates to [ExifDataExtractor.parseGpsCoordinate].
@visibleForTesting
double? parseGpsCoordinate(dynamic coordData, String ref) =>
    ExifDataExtractor.parseGpsCoordinate(coordData, ref);

/// Extracts GPS coordinates from image EXIF data
///
/// Attempts to read GPS latitude and longitude from EXIF metadata.
/// Returns a Geolocation object if valid GPS data is found, otherwise returns null.
/// Missing GPS data is common and not considered an error.
///
/// Delegates to [ExifDataExtractor.extractGpsCoordinates] for parsing.
@visibleForTesting
Future<Geolocation?> extractGpsCoordinates(
  Uint8List data,
  DateTime createdAt,
) async {
  try {
    final exifData = await readExifFromBytes(data);
    return ExifDataExtractor.extractGpsCoordinates(exifData, createdAt);
  } catch (exception, stackTrace) {
    // Log but don't fail - missing/invalid GPS is common
    getIt<LoggingService>().captureException(
      exception,
      domain: MediaImportConstants.loggingDomain,
      subDomain: 'extractGpsCoordinates',
      stackTrace: stackTrace,
    );
    return null;
  }
}

/// Imports pasted image data from clipboard and creates journal entry.
///
/// Validates file size before importing.
/// If [analysisTrigger] is provided, triggers automatic image analysis
/// for the imported image (fire-and-forget, doesn't block import).
Future<void> importPastedImages({
  required Uint8List data,
  required String fileExtension,
  String? linkedId,
  String? categoryId,
  AutomaticImageAnalysisTrigger? analysisTrigger,
}) async {
  // Validate file size
  if (data.length > MediaImportConstants.maxImageFileSizeBytes) {
    getIt<LoggingService>().captureException(
      'Pasted image too large: ${data.length} bytes',
      domain: MediaImportConstants.loggingDomain,
      subDomain: 'importPastedImages',
    );
    return;
  }

  // Extract original timestamp from EXIF data, fallback to current time
  final capturedAt = await _extractImageTimestamp(data);
  final geolocation = await extractGpsCoordinates(data, capturedAt);
  final id = uuid.v1();

  final day =
      DateFormat(AudioRecorderConstants.directoryDateFormat).format(capturedAt);
  final relativePath = '${MediaImportConstants.imagesDirectoryPrefix}$day/';
  final directory = await createAssetDirectory(relativePath);
  final targetFileName = '$id.$fileExtension';
  final targetFilePath = '$directory$targetFileName';

  final file = await File(targetFilePath).create(recursive: true);
  await file.writeAsBytes(data);

  final imageData = ImageData(
    imageId: id,
    imageFile: targetFileName,
    imageDirectory: relativePath,
    capturedAt: capturedAt,
    geolocation: geolocation,
  );

  await JournalRepository.createImageEntry(
    imageData,
    linkedId: linkedId,
    categoryId: categoryId,
    onCreated: _createAnalysisCallback(analysisTrigger, categoryId, linkedId),
  );
}

/// Imports AI-generated image bytes and creates journal entry.
///
/// This is specifically designed for images generated by AI (like cover art)
/// that need to be saved and optionally set as cover art for a task.
///
/// Parameters:
/// - [data]: The raw image bytes to save.
/// - [fileExtension]: The file extension (e.g., 'png', 'jpg').
/// - [linkedId]: The entity ID to link the image to.
/// - [categoryId]: Optional category ID for the image entry.
///
/// Returns the ID of the created image entry, or null if creation failed.
Future<String?> importGeneratedImageBytes({
  required Uint8List data,
  required String fileExtension,
  String? linkedId,
  String? categoryId,
}) async {
  // Validate file size
  if (data.length > MediaImportConstants.maxImageFileSizeBytes) {
    getIt<LoggingService>().captureException(
      'Generated image too large: ${data.length} bytes',
      domain: MediaImportConstants.loggingDomain,
      subDomain: 'importGeneratedImageBytes',
    );
    return null;
  }

  final capturedAt = DateTime.now();
  final id = uuid.v1();

  final day =
      DateFormat(AudioRecorderConstants.directoryDateFormat).format(capturedAt);
  final relativePath = '${MediaImportConstants.imagesDirectoryPrefix}$day/';
  final directory = await createAssetDirectory(relativePath);
  final targetFileName = '$id.$fileExtension';
  final targetFilePath = '$directory$targetFileName';

  final file = await File(targetFilePath).create(recursive: true);
  await file.writeAsBytes(data);

  final imageData = ImageData(
    imageId: id,
    imageFile: targetFileName,
    imageDirectory: relativePath,
    capturedAt: capturedAt,
  );

  final createdEntity = await JournalRepository.createImageEntry(
    imageData,
    linkedId: linkedId,
    categoryId: categoryId,
  );

  if (createdEntity == null) {
    return null;
  }

  return createdEntity.id;
}

/// Handles dropped files and routes them to appropriate import functions.
///
/// Examines file extensions and calls the correct import function based on
/// file type. Supports both images and audio files.
/// If [analysisTrigger] is provided, triggers automatic image analysis
/// for each imported image (fire-and-forget, doesn't block import).
Future<void> handleDroppedMedia({
  required DropDoneDetails data,
  required String linkedId,
  String? categoryId,
  AutomaticImageAnalysisTrigger? analysisTrigger,
}) async {
  // Group files by type for efficient processing
  final hasImages = data.files.any((file) {
    final ext = file.name.split('.').last.toLowerCase();
    return MediaImportConstants.supportedImageExtensions.contains(ext);
  });

  final hasAudio = data.files.any((file) {
    final ext = file.name.split('.').last.toLowerCase();
    return MediaImportConstants.supportedAudioExtensions.contains(ext);
  });

  // Process each type once
  if (hasImages) {
    await importDroppedImages(
      data: data,
      linkedId: linkedId,
      categoryId: categoryId,
      analysisTrigger: analysisTrigger,
    );
  }

  if (hasAudio) {
    await importDroppedAudio(
      data: data,
      linkedId: linkedId,
      categoryId: categoryId,
    );
  }
}

/// Parses timestamp from audio filename if it matches Lotti's format
///
/// Expected format: yyyy-MM-dd_HH-mm-ss-S.extension (e.g., 2025-10-20_16-49-32-203.m4a)
/// Returns the parsed DateTime if successful, null otherwise.
///
/// Delegates to [AudioMetadataExtractor.parseFilenameTimestamp].
@visibleForTesting
DateTime? parseAudioFileTimestamp(String filename) =>
    AudioMetadataExtractor.parseFilenameTimestamp(filename);

/// Function type for reading audio duration from a file.
///
/// Re-exported from [AudioMetadataExtractor] for backward compatibility.
typedef AudioMetadataReader = Future<Duration> Function(String filePath);

/// Test bypass flag - when true, duration extraction returns Duration.zero.
///
/// Delegates to [AudioMetadataExtractor.bypassMediaKitInTests].
@visibleForTesting
bool get imageImportBypassMediaKitInTests =>
    AudioMetadataExtractor.bypassMediaKitInTests;

@visibleForTesting
set imageImportBypassMediaKitInTests(bool value) =>
    AudioMetadataExtractor.bypassMediaKitInTests = value;

/// Selects the appropriate audio metadata reader based on environment.
///
/// Delegates to [AudioMetadataExtractor.selectReader].
@visibleForTesting
AudioMetadataReader selectAudioMetadataReader() {
  // Check for registered reader via GetIt for backward compatibility
  AudioMetadataReader? registeredReader;
  if (getIt.isRegistered<AudioMetadataReader>()) {
    registeredReader = getIt<AudioMetadataReader>();
  }
  return AudioMetadataExtractor.selectReader(
      registeredReader: registeredReader);
}

/// Extracts audio duration from file using MediaKit.
///
/// Delegates to [AudioMetadataExtractor.extractDuration].
@visibleForTesting
Future<Duration> extractDurationWithMediaKit(String filePath) =>
    AudioMetadataExtractor.extractDuration(filePath);

/// Computes the relative directory path for storing audio files.
///
/// Delegates to [AudioMetadataExtractor.computeRelativePath].
@visibleForTesting
String computeAudioRelativePath(DateTime timestamp) =>
    AudioMetadataExtractor.computeRelativePath(timestamp);

/// Computes the target filename for an audio file.
///
/// Delegates to [AudioMetadataExtractor.computeTargetFileName].
@visibleForTesting
String computeAudioTargetFileName(DateTime timestamp, String extension) =>
    AudioMetadataExtractor.computeTargetFileName(timestamp, extension);

/// Imports dropped audio files and creates audio journal entries
///
/// Validates file extensions, size limits, and extracts audio duration before
/// importing. Only processes files with supported audio extensions.
///
/// If duration extraction fails, continues with zero duration which can be
/// updated later. If journal entry creation fails, cleans up the copied file.
Future<void> importDroppedAudio({
  required DropDoneDetails data,
  String? linkedId,
  String? categoryId,
}) async {
  for (final file in data.files) {
    String? copiedFilePath;

    try {
      final lastModified = await file.lastModified();

      // Try to parse timestamp from filename, fall back to lastModified
      final parsedTimestamp = parseAudioFileTimestamp(file.name);
      final timestamp = parsedTimestamp ?? lastModified;

      final srcPath = file.path;

      // Validate file name has extension
      final nameParts = file.name.split('.');
      if (nameParts.length < 2) {
        getIt<LoggingService>().captureException(
          'Audio file has no extension: ${file.name}',
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importDroppedAudio',
        );
        continue;
      }

      final fileExtension = nameParts.last.toLowerCase();

      // Skip non-audio files
      if (!MediaImportConstants.supportedAudioExtensions
          .contains(fileExtension)) {
        continue;
      }

      // Validate file size
      final fileSize = await File(srcPath).length();
      if (fileSize > MediaImportConstants.maxAudioFileSizeBytes) {
        getIt<LoggingService>().captureException(
          'Audio file too large: $fileSize bytes',
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importDroppedAudio',
        );
        continue;
      }

      final relativePath = computeAudioRelativePath(timestamp);
      final directory = await createAssetDirectory(relativePath);
      final targetFileName =
          computeAudioTargetFileName(timestamp, fileExtension);
      final targetFilePath = '$directory$targetFileName';

      // Copy file first
      await File(srcPath).copy(targetFilePath);
      copiedFilePath = targetFilePath;

      // Extract audio duration using injected metadata reader.
      var duration = Duration.zero;
      try {
        final reader = selectAudioMetadataReader();
        duration = await reader(targetFilePath);
      } catch (exception, stackTrace) {
        // Log but continue with zero duration - can be updated later
        getIt<LoggingService>().captureException(
          exception,
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importDroppedAudio_duration',
          stackTrace: stackTrace,
        );
      }

      final audioNote = AudioNote(
        createdAt: timestamp,
        audioFile: targetFileName,
        audioDirectory: relativePath,
        duration: duration,
      );

      // Create journal entry
      final result = await SpeechRepository.createAudioEntry(
        audioNote,
        linkedId: linkedId,
        categoryId: categoryId,
      );

      // If entry creation failed, clean up the copied file
      if (result == null) {
        try {
          await File(copiedFilePath).delete();
        } catch (deleteException, deleteStackTrace) {
          getIt<LoggingService>().captureException(
            deleteException,
            domain: MediaImportConstants.loggingDomain,
            subDomain: 'importDroppedAudio_cleanup',
            stackTrace: deleteStackTrace,
          );
        }
      }
    } catch (exception, stackTrace) {
      // Log and clean up on any error
      getIt<LoggingService>().captureException(
        exception,
        domain: MediaImportConstants.loggingDomain,
        subDomain: 'importDroppedAudio',
        stackTrace: stackTrace,
      );

      // Clean up copied file if it exists
      if (copiedFilePath != null) {
        try {
          await File(copiedFilePath).delete();
        } catch (deleteException, deleteStackTrace) {
          getIt<LoggingService>().captureException(
            deleteException,
            domain: MediaImportConstants.loggingDomain,
            subDomain: 'importDroppedAudio_cleanup',
            stackTrace: deleteStackTrace,
          );
        }
      }
      // Continue processing other files even if one fails
    }
  }
}

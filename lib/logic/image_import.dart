import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/geohash.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

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

Future<void> importImageAssets(
  BuildContext context, {
  String? linkedId,
  String? categoryId,
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
      final latitude = latLng.latitude ?? asset.latitude;
      final longitude = latLng.longitude ?? asset.longitude;

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
        );
      }
    }
  }
}

/// Imports dropped image files and creates journal entries
///
/// Validates file extensions and size limits before importing.
/// Only processes files with supported image extensions.
///
/// Throws exceptions on file system errors which should be handled by caller.
Future<void> importDroppedImages({
  required DropDoneDetails data,
  String? linkedId,
  String? categoryId,
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

/// Imports pasted image data from clipboard and creates journal entry
///
/// Validates file size before importing.
Future<void> importPastedImages({
  required Uint8List data,
  required String fileExtension,
  String? linkedId,
  String? categoryId,
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

  await JournalRepository.createImageEntry(
    imageData,
    linkedId: linkedId,
    categoryId: categoryId,
  );
}

/// Handles dropped files and routes them to appropriate import functions
///
/// Examines file extensions and calls the correct import function based on
/// file type. Supports both images and audio files.
Future<void> handleDroppedMedia({
  required DropDoneDetails data,
  required String linkedId,
  String? categoryId,
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
DateTime? _parseAudioFileTimestamp(String filename) {
  try {
    // Remove file extension
    final nameWithoutExtension = filename.split('.').first;

    // Try to parse using Lotti's audio filename format
    return DateFormat(AudioRecorderConstants.fileNameDateFormat)
        .parse(nameWithoutExtension);
  } catch (_) {
    // Return null if parsing fails
    return null;
  }
}

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
      final parsedTimestamp = _parseAudioFileTimestamp(file.name);
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

      final day = DateFormat(AudioRecorderConstants.directoryDateFormat)
          .format(timestamp);
      final relativePath =
          '${AudioRecorderConstants.audioDirectoryPrefix}$day/';
      final directory = await createAssetDirectory(relativePath);
      final targetFileName =
          '${DateFormat(AudioRecorderConstants.fileNameDateFormat).format(timestamp)}.$fileExtension';
      final targetFilePath = '$directory$targetFileName';

      // Copy file first
      await File(srcPath).copy(targetFilePath);
      copiedFilePath = targetFilePath;

      // Extract audio duration using MediaKit with proper resource management
      var duration = Duration.zero;
      Player? player;
      try {
        player = Player();
        await player.open(Media(targetFilePath), play: false);

        // Wait for the duration to become available
        // MediaKit needs time to parse the media file metadata
        duration = await player.stream.duration
            .firstWhere(
              (d) => d > Duration.zero,
              orElse: () => Duration.zero,
            )
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => Duration.zero,
            );
      } catch (exception, stackTrace) {
        // Log but continue with zero duration - can be updated later
        getIt<LoggingService>().captureException(
          exception,
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importDroppedAudio_duration',
          stackTrace: stackTrace,
        );
      } finally {
        // Always dispose player to prevent resource leak
        await player?.dispose();
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
        language: null,
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

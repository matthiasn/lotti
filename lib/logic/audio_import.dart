import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/media/audio_metadata_extractor.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as path;

/// Constants for audio import operations.
class AudioImportConstants {
  const AudioImportConstants._();

  /// Supported audio file extensions for import.
  static const Set<String> supportedExtensions = {'m4a'};

  /// Maximum audio file size in bytes (500 MB).
  static const int maxFileSizeBytes = 500 * 1024 * 1024;

  /// Logging domain for audio import operations.
  static const String loggingDomain = 'audio_import';
}

/// Imports dropped audio files and creates audio journal entries.
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
      final parsedTimestamp =
          AudioMetadataExtractor.parseFilenameTimestamp(file.name);
      final timestamp = parsedTimestamp ?? lastModified;

      final srcPath = file.path;

      // Validate file name has extension
      final nameParts = file.name.split('.');
      if (nameParts.length < 2) {
        getIt<LoggingService>().captureException(
          'Audio file has no extension: ${file.name}',
          domain: AudioImportConstants.loggingDomain,
          subDomain: 'importDroppedAudio',
        );
        continue;
      }

      final fileExtension = nameParts.last.toLowerCase();

      // Skip non-audio files
      if (!AudioImportConstants.supportedExtensions.contains(fileExtension)) {
        continue;
      }

      // Validate file size
      final fileSize = await File(srcPath).length();
      if (fileSize > AudioImportConstants.maxFileSizeBytes) {
        getIt<LoggingService>().captureException(
          'Audio file too large: $fileSize bytes',
          domain: AudioImportConstants.loggingDomain,
          subDomain: 'importDroppedAudio',
        );
        continue;
      }

      final relativePath =
          AudioMetadataExtractor.computeRelativePath(timestamp);
      final directory = await createAssetDirectory(relativePath);
      final targetFileName = AudioMetadataExtractor.computeTargetFileName(
          timestamp, fileExtension);
      final targetFilePath = path.join(directory, targetFileName);

      // Copy file first
      await File(srcPath).copy(targetFilePath);
      copiedFilePath = targetFilePath;

      // Extract audio duration
      var duration = Duration.zero;
      try {
        final reader = AudioMetadataExtractor.selectReader(
          registeredReader: _getRegisteredReader(),
        );
        duration = await reader(targetFilePath);
      } catch (exception, stackTrace) {
        // Log but continue with zero duration - can be updated later
        getIt<LoggingService>().captureException(
          exception,
          domain: AudioImportConstants.loggingDomain,
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
            domain: AudioImportConstants.loggingDomain,
            subDomain: 'importDroppedAudio_cleanup',
            stackTrace: deleteStackTrace,
          );
        }
      }
    } catch (exception, stackTrace) {
      // Log and clean up on any error
      getIt<LoggingService>().captureException(
        exception,
        domain: AudioImportConstants.loggingDomain,
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
            domain: AudioImportConstants.loggingDomain,
            subDomain: 'importDroppedAudio_cleanup',
            stackTrace: deleteStackTrace,
          );
        }
      }
      // Continue processing other files even if one fails
    }
  }
}

/// Gets the registered audio metadata reader from GetIt, if any.
AudioMetadataReader? _getRegisteredReader() {
  if (getIt.isRegistered<AudioMetadataReader>()) {
    return getIt<AudioMetadataReader>();
  }
  return null;
}

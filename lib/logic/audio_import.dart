import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/logic/media/audio_metadata_extractor.dart';
import 'package:lotti/logic/repositories/speech_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as path;

/// Constants for audio import operations.
abstract final class AudioImportConstants {
  /// Supported audio file extensions for import.
  static const Set<String> supportedExtensions = {'m4a'};

  /// Maximum audio file size in bytes (500 MB).
  static const int maxFileSizeBytes = 500 * 1024 * 1024;
}

/// Imports audio [files] (from a media drop) and creates audio journal
/// entries.
///
/// Validates file extensions, size limits, and extracts audio duration before
/// importing. Only processes files with supported audio extensions.
///
/// If duration extraction fails, continues with zero duration which can be
/// updated later. If journal entry creation fails, cleans up the copied file.
///
/// Entries are written through [speechRepository]; [metadataReader] replaces
/// the platform duration reader (see [AudioMetadataExtractor.selectReader]).
Future<void> importAudioXFiles(
  List<XFile> files, {
  required SpeechRepository speechRepository,
  required DomainLogger domainLogger,
  String? linkedId,
  String? categoryId,
  AudioMetadataReader? metadataReader,
}) async {
  for (final file in files) {
    String? copiedFilePath;

    try {
      final lastModified = await file.lastModified();

      // Try to parse timestamp from filename, fall back to lastModified
      final parsedTimestamp = AudioMetadataExtractor.parseFilenameTimestamp(
        file.name,
      );
      final timestamp = parsedTimestamp ?? lastModified;

      final srcPath = file.path;

      // Validate file name has extension
      final nameParts = file.name.split('.');
      if (nameParts.length < 2) {
        domainLogger.error(
          LogDomain.speech,
          'Audio file has no extension: ${file.name}',
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
        domainLogger.error(
          LogDomain.speech,
          'Audio file too large: $fileSize bytes',
          subDomain: 'importDroppedAudio',
        );
        continue;
      }

      final relativePath = AudioMetadataExtractor.computeRelativePath(
        timestamp,
      );
      final directory = await createAssetDirectory(relativePath);
      // Never reuse an occupied name: the copy below would overwrite an
      // earlier recording that an existing journal entry still points at.
      // The claim creates the file, so it is already this import's to clean
      // up before the copy has written a single byte into it.
      final targetFileName = AudioMetadataExtractor.claimAvailableFileName(
        directory: directory,
        preferredFileName: AudioMetadataExtractor.computeTargetFileName(
          timestamp,
          fileExtension,
        ),
      );
      final targetFilePath = path.join(directory, targetFileName);
      copiedFilePath = targetFilePath;

      // Copy file first
      await File(srcPath).copy(targetFilePath);

      // Extract audio duration
      var duration = Duration.zero;
      try {
        final reader = AudioMetadataExtractor.selectReader(
          registeredReader: metadataReader,
        );
        duration = await reader(targetFilePath);
      } catch (exception, stackTrace) {
        // Log but continue with zero duration - can be updated later
        domainLogger.error(
          LogDomain.speech,
          exception,
          stackTrace: stackTrace,
          subDomain: 'importDroppedAudio_duration',
        );
      }

      final audioNote = AudioNote(
        createdAt: timestamp,
        audioFile: targetFileName,
        audioDirectory: relativePath,
        duration: duration,
      );

      // Create journal entry
      final result = await speechRepository.createAudioEntry(
        audioNote,
        linkedId: linkedId,
        categoryId: categoryId,
      );

      // If entry creation failed, clean up the copied file
      if (result == null) {
        try {
          await File(copiedFilePath).delete();
        } catch (deleteException, deleteStackTrace) {
          domainLogger.error(
            LogDomain.speech,
            deleteException,
            stackTrace: deleteStackTrace,
            subDomain: 'importDroppedAudio_cleanup',
          );
        }
      }
    } catch (exception, stackTrace) {
      // Log and clean up on any error
      domainLogger.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'importDroppedAudio',
      );

      // Clean up copied file if it exists
      if (copiedFilePath != null) {
        try {
          await File(copiedFilePath).delete();
        } catch (deleteException, deleteStackTrace) {
          domainLogger.error(
            LogDomain.speech,
            deleteException,
            stackTrace: deleteStackTrace,
            subDomain: 'importDroppedAudio_cleanup',
          );
        }
      }
      // Continue processing other files even if one fails
    }
  }
}

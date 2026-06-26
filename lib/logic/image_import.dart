import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'
    show CompressFormat;
import 'package:intl/intl.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/media/exif_data_extractor.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/geohash.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:path/path.dart' as p;
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// Creates an onCreated callback for automatic image analysis.
///
/// - [analysisTrigger]: The trigger service. If null, this function returns null.
/// - [linkedId]: The ID of a linked entity (e.g., a task). This is passed as
///   `linkedTaskId` to the trigger.
///
/// Returns null if [analysisTrigger] is null, otherwise returns a callback
/// that triggers automatic image analysis in a fire-and-forget manner.
void Function(JournalEntity)? createAnalysisCallback(
  AutomaticImageAnalysisTrigger? analysisTrigger,
  String? linkedId,
) {
  if (analysisTrigger == null) return null;
  return (entity) => unawaited(
    analysisTrigger.triggerAutomaticImageAnalysis(
      imageEntryId: entity.id,
      linkedTaskId: linkedId,
    ),
  );
}

/// Constants for image import operations.
class ImageImportConstants {
  const ImageImportConstants._();

  /// Supported image file extensions for import.
  static Set<String> get supportedExtensions =>
      supportedExtensionsForPlatform();

  /// Image file extensions that can be imported without conversion.
  static const Set<String> standardExtensions = {
    'jpg',
    'jpeg',
    'png',
  };

  /// HEIC/HEIF extensions accepted only where conversion support is available.
  static const Set<String> highEfficiencyExtensions = {
    'heic',
    'heif',
  };

  /// Source image extensions that are converted before storage.
  static const Set<String> sourceExtensionsRequiringConversion = {
    'heic',
    'heif',
  };

  /// Extension used for converted images in Lotti's storage.
  static const String convertedImageExtension = 'jpg';

  /// Returns image extensions supported on [targetPlatform].
  static Set<String> supportedExtensionsForPlatform([
    TargetPlatform? targetPlatform,
  ]) {
    if (supportsHighEfficiencyImageConversion(targetPlatform)) {
      return {...standardExtensions, ...highEfficiencyExtensions};
    }
    return standardExtensions;
  }

  /// Whether HEIC/HEIF inputs can be converted before storage.
  static bool supportsHighEfficiencyImageConversion([
    TargetPlatform? targetPlatform,
  ]) {
    return switch (targetPlatform ?? defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows => false,
    };
  }

  /// Directory prefix for storing imported images.
  static const String directoryPrefix = '/images/';

  /// Maximum image file size in bytes (50 MB).
  static const int maxFileSizeBytes = 50 * 1024 * 1024;

  /// Logging domain for image import operations.
  static const String loggingDomain = 'image_import';
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
      final file = await _bestAvailableAssetFile(asset);

      if (file != null) {
        final sourceExtension = await _sourceExtensionForAssetFile(asset, file);
        if (!ImageImportConstants.supportedExtensions.contains(
          sourceExtension,
        )) {
          continue;
        }

        final bytes = _requiresConversion(sourceExtension)
            ? await file.readAsBytes()
            : null;
        final idNamePart = asset.id.split('/').first;
        final targetFileExtension = _targetImageExtension(
          sourceExtension,
          sourceBytes: bytes,
        );
        final imageFileName = '$idNamePart.$targetFileExtension';
        final day = DateFormat(
          AudioRecorderConstants.directoryDateFormat,
        ).format(createdAt);
        final relativePath = '${ImageImportConstants.directoryPrefix}$day/';
        final directory = await createAssetDirectory(relativePath);
        final targetFilePath = p.join(directory, imageFileName);
        await _copyOrConvertImageFile(
          sourceFile: file,
          sourceExtension: sourceExtension,
          sourceBytes: bytes,
          targetFilePath: targetFilePath,
        );
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
          onCreated: createAnalysisCallback(
            analysisTrigger,
            linkedId,
          ),
        );
      }
    }
  }
}

/// Imports image files picked from a desktop file dialog (Linux/Windows),
/// where the gallery picker (`importImageAssets`) is unavailable.
Future<void> importImagePickerFiles({
  String? linkedId,
  String? categoryId,
  AutomaticImageAnalysisTrigger? analysisTrigger,
}) async {
  final group = XTypeGroup(
    extensions: ImageImportConstants.supportedExtensions.toList(
      growable: false,
    ),
  );
  final files = await openFiles(acceptedTypeGroups: [group]);
  if (files.isEmpty) return;
  await importImageXFiles(
    files,
    linkedId: linkedId,
    categoryId: categoryId,
    analysisTrigger: analysisTrigger,
  );
}

/// Shared importer for a list of image [files] — used by both drag-and-drop
/// and the desktop file picker. Validates extension + size, copies into the
/// app's image directory, and creates a linked image entry. Per-file failures
/// are logged and skipped so one bad file doesn't abort the batch.
Future<void> importImageXFiles(
  List<XFile> files, {
  String? linkedId,
  String? categoryId,
  AutomaticImageAnalysisTrigger? analysisTrigger,
}) async {
  for (final file in files) {
    try {
      final id = uuid.v1();
      final srcPath = file.path;
      final fileExtension =
          _extensionFromPath(file.name) ?? _extensionFromPath(srcPath) ?? '';

      // Skip non-image files
      if (!ImageImportConstants.supportedExtensions.contains(fileExtension)) {
        continue;
      }

      // Validate file size before reading the bytes into memory.
      final fileSize = await File(srcPath).length();
      if (fileSize > ImageImportConstants.maxFileSizeBytes) {
        getIt<DomainLogger>().error(
          LogDomain.ai,
          'Image file too large: $fileSize bytes',
          subDomain: 'importDroppedImages',
        );
        continue;
      }

      final bytes = await File(srcPath).readAsBytes();
      final lastModified = await file.lastModified();

      // Prefer the photo's original capture time from EXIF; fall back to the
      // file's last-modified time when the image carries no timestamp. Drag and
      // drop streams each file into a fresh temp file, so its mtime is the drop
      // time rather than when the photo was taken — only the EXIF metadata
      // preserves the real moment.
      final capturedAt = await _extractImageTimestamp(
        bytes,
        fallback: lastModified,
      );
      final geolocation = await extractGpsCoordinates(bytes, capturedAt);

      final day = DateFormat(
        AudioRecorderConstants.directoryDateFormat,
      ).format(capturedAt);
      final relativePath = '${ImageImportConstants.directoryPrefix}$day/';
      final directory = await createAssetDirectory(relativePath);
      final targetFileExtension = _targetImageExtension(
        fileExtension,
        sourceBytes: bytes,
      );
      final targetFileName = '$id.$targetFileExtension';
      final targetFilePath = p.join(directory, targetFileName);

      await _copyOrConvertImageFile(
        sourceFile: File(srcPath),
        sourceExtension: fileExtension,
        sourceBytes: bytes,
        targetFilePath: targetFilePath,
      );

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
        onCreated: createAnalysisCallback(
          analysisTrigger,
          linkedId,
        ),
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.ai,
        exception,
        stackTrace: stackTrace,
        subDomain: 'importDroppedImages',
      );
      // Continue processing other files even if one fails
    }
  }
}

enum _ImageStorageFormat { original, jpeg, png }

Future<File?> _bestAvailableAssetFile(AssetEntity asset) async {
  try {
    final origin = await asset.originFile;
    if (origin != null) {
      return origin;
    }
  } catch (_) {
    // Fall back to the platform-provided derivative if original lookup fails.
  }
  return asset.file;
}

Future<String> _sourceExtensionForAssetFile(
  AssetEntity asset,
  File file,
) async {
  return _extensionFromMimeType(asset.mimeType) ??
      await _extensionFromAssetTitle(asset) ??
      _extensionFromPath(file.path) ??
      ImageImportConstants.convertedImageExtension;
}

Future<String?> _extensionFromAssetTitle(AssetEntity asset) async {
  try {
    return _extensionFromPath(await asset.titleAsync);
  } catch (_) {
    return null;
  }
}

String? _extensionFromPath(String path) {
  final extension = p.extension(path).replaceFirst('.', '').toLowerCase();
  return extension.isEmpty ? null : extension;
}

String? _extensionFromMimeType(String? mimeType) {
  return switch (mimeType?.toLowerCase()) {
    'image/jpeg' || 'image/jpg' => 'jpg',
    'image/png' => 'png',
    'image/heic' => 'heic',
    'image/heif' => 'heif',
    _ => null,
  };
}

String _targetImageExtension(
  String sourceExtension, {
  Uint8List? sourceBytes,
}) {
  final normalizedExtension = sourceExtension.toLowerCase();
  return switch (_storageFormatForSource(
    normalizedExtension,
    sourceBytes: sourceBytes,
  )) {
    _ImageStorageFormat.original => normalizedExtension,
    _ImageStorageFormat.jpeg => ImageImportConstants.convertedImageExtension,
    _ImageStorageFormat.png => 'png',
  };
}

_ImageStorageFormat _storageFormatForSource(
  String sourceExtension, {
  Uint8List? sourceBytes,
}) {
  final normalizedExtension = sourceExtension.toLowerCase();
  if (!_requiresConversion(normalizedExtension)) {
    return _ImageStorageFormat.original;
  }
  if (sourceBytes != null && heifContainsAlphaAuxiliaryImage(sourceBytes)) {
    return _ImageStorageFormat.png;
  }
  return _ImageStorageFormat.jpeg;
}

bool _requiresConversion(String sourceExtension) =>
    ImageImportConstants.sourceExtensionsRequiringConversion.contains(
      sourceExtension.toLowerCase(),
    );

Future<void> _copyOrConvertImageFile({
  required File sourceFile,
  required String sourceExtension,
  required String targetFilePath,
  Uint8List? sourceBytes,
}) async {
  final storageFormat = _storageFormatForSource(
    sourceExtension,
    sourceBytes: sourceBytes,
  );
  if (storageFormat == _ImageStorageFormat.original) {
    await sourceFile.copy(targetFilePath);
    return;
  }

  final convertedFile = await compressAndSave(
    sourceFile,
    targetFilePath,
    format: switch (storageFormat) {
      _ImageStorageFormat.jpeg => CompressFormat.jpeg,
      _ImageStorageFormat.png => CompressFormat.png,
      _ImageStorageFormat.original => throw StateError(
        'Original image storage does not require conversion',
      ),
    },
  );
  if (convertedFile == null) {
    throw StateError(
      'Failed to convert $sourceExtension image to '
      '${storageFormat.name.toUpperCase()}',
    );
  }
}

Future<void> _writeOrConvertPastedImageBytes({
  required Uint8List data,
  required String sourceExtension,
  required String targetFilePath,
}) async {
  if (!_requiresConversion(sourceExtension)) {
    final file = await File(targetFilePath).create(recursive: true);
    await file.writeAsBytes(data);
    return;
  }

  final tempDirectory = await Directory.systemTemp.createTemp(
    'lotti_pasted_image_',
  );
  try {
    final sourceFile = File(
      p.join(tempDirectory.path, 'pasted.$sourceExtension'),
    );
    await sourceFile.writeAsBytes(data);
    await _copyOrConvertImageFile(
      sourceFile: sourceFile,
      sourceExtension: sourceExtension,
      sourceBytes: data,
      targetFilePath: targetFilePath,
    );
  } finally {
    try {
      await tempDirectory.delete(recursive: true);
    } catch (_) {
      // Best-effort cleanup for a temp file that no longer affects import.
    }
  }
}

/// Returns true when HEIF/HEIC metadata declares an auxiliary alpha image.
///
/// HEIF stores this as an `auxC` box whose auxiliary type is a
/// null-terminated URN. A byte-level check is enough here because this only
/// chooses a lossless output format; the native image codec still performs the
/// actual decode/encode work.
@visibleForTesting
bool heifContainsAlphaAuxiliaryImage(Uint8List data) {
  if (!_containsAsciiString(data, 'auxC')) {
    return false;
  }

  return _heifAlphaAuxiliaryTypes.any(
    (auxiliaryType) => _containsAsciiString(data, auxiliaryType),
  );
}

const _heifAlphaAuxiliaryTypes = [
  'urn:mpeg:hevc:2015:auxid:1',
  'urn:mpeg:mpegB:cicp:systems:auxiliary:alpha',
];

bool _containsAsciiString(Uint8List data, String value) {
  final pattern = value.codeUnits;
  if (pattern.isEmpty || data.length < pattern.length) {
    return false;
  }

  final firstByte = pattern.first;
  final lastPossibleIndex = data.length - pattern.length;
  var index = 0;

  while (index <= lastPossibleIndex) {
    index = data.indexOf(firstByte, index);
    if (index == -1 || index > lastPossibleIndex) {
      return false;
    }

    var matched = true;
    for (var patternIndex = 1; patternIndex < pattern.length; patternIndex++) {
      if (data[index + patternIndex] != pattern[patternIndex]) {
        matched = false;
        break;
      }
    }

    if (matched) return true;

    index++;
  }

  return false;
}

/// Extracts original timestamp from image EXIF data
///
/// Attempts to read DateTimeOriginal or DateTime from EXIF metadata.
/// Returns the parsed DateTime if found, otherwise returns [fallback] when
/// provided (e.g. the file's last-modified time), or the current time.
Future<DateTime> _extractImageTimestamp(
  Uint8List data, {
  DateTime? fallback,
}) async {
  try {
    final exifData = await readExifFromBytes(data);
    final timestamp = ExifDataExtractor.extractTimestamp(exifData);
    if (timestamp != null) {
      return timestamp;
    }
  } catch (exception, stackTrace) {
    // Log but don't fail - return the fallback timestamp instead.
    getIt<DomainLogger>().error(
      LogDomain.ai,
      exception,
      stackTrace: stackTrace,
      subDomain: 'extractImageTimestamp',
    );
  }

  // Fallback when no EXIF timestamp is available.
  return fallback ?? DateTime.now();
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
    getIt<DomainLogger>().error(
      LogDomain.ai,
      exception,
      stackTrace: stackTrace,
      subDomain: 'extractGpsCoordinates',
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
  if (data.length > ImageImportConstants.maxFileSizeBytes) {
    getIt<DomainLogger>().error(
      LogDomain.ai,
      'Pasted image too large: ${data.length} bytes',
      subDomain: 'importPastedImages',
    );
    return;
  }

  // Extract original timestamp from EXIF data, fallback to current time
  final capturedAt = await _extractImageTimestamp(data);
  final geolocation = await extractGpsCoordinates(data, capturedAt);
  final id = uuid.v1();

  final day = DateFormat(
    AudioRecorderConstants.directoryDateFormat,
  ).format(capturedAt);
  final relativePath = '${ImageImportConstants.directoryPrefix}$day/';
  final directory = await createAssetDirectory(relativePath);
  final sourceExtension = fileExtension.toLowerCase();
  final targetFileExtension = _targetImageExtension(
    fileExtension,
    sourceBytes: data,
  );
  final targetFileName = '$id.$targetFileExtension';
  final targetFilePath = p.join(directory, targetFileName);

  await _writeOrConvertPastedImageBytes(
    data: data,
    sourceExtension: sourceExtension,
    targetFilePath: targetFilePath,
  );

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
    onCreated: createAnalysisCallback(analysisTrigger, linkedId),
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
  if (data.length > ImageImportConstants.maxFileSizeBytes) {
    getIt<DomainLogger>().error(
      LogDomain.ai,
      'Generated image too large: ${data.length} bytes',
      subDomain: 'importGeneratedImageBytes',
    );
    return null;
  }

  final capturedAt = DateTime.now();
  final id = uuid.v1();

  final day = DateFormat(
    AudioRecorderConstants.directoryDateFormat,
  ).format(capturedAt);
  final relativePath = '${ImageImportConstants.directoryPrefix}$day/';
  final directory = await createAssetDirectory(relativePath);
  final targetFileName = '$id.$fileExtension';
  final targetFilePath = p.join(directory, targetFileName);

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

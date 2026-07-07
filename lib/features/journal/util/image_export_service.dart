import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:gal/gal.dart';
import 'package:lotti/utils/platform.dart';
import 'package:path/path.dart' as p;

/// How an image save attempt resolved, mapped to a user-facing message by the
/// image viewer.
enum ImageExportStatus {
  /// Copied to a user-chosen file location via the desktop save panel.
  savedToFile,

  /// Saved to the platform photo library / camera roll on mobile.
  savedToGallery,

  /// The user dismissed the save panel without choosing a location.
  cancelled,

  /// The OS denied photo-library access on mobile.
  permissionDenied,
}

/// Result of an [ImageExporter] call.
///
/// [savedName] is only populated for [ImageExportStatus.savedToFile], where the
/// viewer echoes the chosen file name back to the user.
class ImageExportResult {
  const ImageExportResult(this.status, {this.savedName});

  const ImageExportResult.savedToFile(String name)
    : this(ImageExportStatus.savedToFile, savedName: name);

  const ImageExportResult.savedToGallery()
    : this(ImageExportStatus.savedToGallery);

  const ImageExportResult.cancelled() : this(ImageExportStatus.cancelled);

  const ImageExportResult.permissionDenied()
    : this(ImageExportStatus.permissionDenied);

  final ImageExportStatus status;

  /// File name shown back to the user for [ImageExportStatus.savedToFile].
  final String? savedName;
}

/// Saves a source image [file] to a platform-appropriate destination.
///
/// `getDownloadsDirectory()` is desktop-only, so the previous single-path
/// implementation always failed on iOS (no user-facing downloads directory) and
/// on the sandboxed macOS build (no write access to `~/Downloads`). The two
/// real destinations are split into separate implementations:
///
/// * mobile → the OS photo library / camera roll ([saveImageToGallery]),
/// * desktop → a user-chosen location via the native save panel
///   ([saveImageViaDialog]).
///
/// Implementations let genuinely unexpected errors propagate so the caller can
/// distinguish a real failure from a user cancellation via [ImageExportResult].
typedef ImageExporter = Future<ImageExportResult> Function(File file);

/// Saves to the OS photo library via `gal` (iOS camera roll / Android gallery).
Future<ImageExportResult> saveImageToGallery(File file) async {
  try {
    if (!await Gal.hasAccess()) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        return const ImageExportResult.permissionDenied();
      }
    }
    await Gal.putImage(file.path);
    return const ImageExportResult.savedToGallery();
  } on GalException catch (e) {
    if (e.type == GalExceptionType.accessDenied) {
      return const ImageExportResult.permissionDenied();
    }
    rethrow;
  }
}

/// Copies the image to a user-chosen location via the native save panel
/// (`file_selector`), the sandbox-friendly way to write files on desktop: the
/// OS grants write access to exactly the location the user picked.
Future<ImageExportResult> saveImageViaDialog(File file) async {
  final suggestedName = p.basename(file.path);
  final extension = p.extension(suggestedName).replaceFirst('.', '');
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: [
      if (extension.isNotEmpty)
        XTypeGroup(label: 'Image', extensions: [extension]),
    ],
  );
  if (location == null) {
    return const ImageExportResult.cancelled();
  }
  final saved = await file.copy(location.path);
  return ImageExportResult.savedToFile(p.basename(saved.path));
}

/// The exporter appropriate for the current platform: the photo library on
/// mobile, the native save panel on desktop.
ImageExporter defaultImageExporter() =>
    isMobile ? saveImageToGallery : saveImageViaDialog;

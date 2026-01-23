import 'package:desktop_drop/desktop_drop.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/logic/audio_import.dart';
import 'package:lotti/logic/image_import.dart';

/// Handles dropped files and routes them to appropriate import functions.
///
/// Examines file extensions and calls the correct import function based on
/// file type. Supports both images and audio files.
///
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
    return ImageImportConstants.supportedExtensions.contains(ext);
  });

  final hasAudio = data.files.any((file) {
    final ext = file.name.split('.').last.toLowerCase();
    return AudioImportConstants.supportedExtensions.contains(ext);
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

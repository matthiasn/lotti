import 'package:file_selector/file_selector.dart' show XFile;
import 'package:lotti/logic/audio_import.dart';
import 'package:lotti/logic/image_analysis_trigger.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/media/audio_metadata_extractor.dart';
import 'package:lotti/logic/repositories/speech_repository.dart';
import 'package:lotti/services/domain_logging.dart';

/// Routes dropped media [files] (from `MediaDropTarget`) to the image/audio
/// importers by extension. Supports both images and audio files; if
/// [analysisTrigger] is provided, imported images are queued for automatic
/// analysis (fire-and-forget). Audio entries are written through
/// [speechRepository].
Future<void> handleDroppedMediaFiles(
  List<XFile> files, {
  required String linkedId,
  required SpeechRepository speechRepository,
  required DomainLogger domainLogger,
  String? categoryId,
  ImageAnalysisTrigger? analysisTrigger,
  AudioMetadataReader? audioMetadataReader,
}) async {
  bool hasExt(Set<String> exts) =>
      files.any((f) => exts.contains(f.name.split('.').last.toLowerCase()));

  if (hasExt(ImageImportConstants.supportedExtensions)) {
    await importImageXFiles(
      files,
      linkedId: linkedId,
      categoryId: categoryId,
      analysisTrigger: analysisTrigger,
    );
  }
  if (hasExt(AudioImportConstants.supportedExtensions)) {
    await importAudioXFiles(
      files,
      speechRepository: speechRepository,
      domainLogger: domainLogger,
      linkedId: linkedId,
      categoryId: categoryId,
      metadataReader: audioMetadataReader,
    );
  }
}

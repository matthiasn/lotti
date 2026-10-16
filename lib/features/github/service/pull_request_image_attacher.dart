import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:lotti/logic/image_analysis_trigger.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/image_format.dart';
import 'package:path/path.dart' as p;

/// Imports image bytes as a journal image entry: [importPastedImages] by
/// default, which saves the bytes, writes the entry, links it to
/// `linkedId` and starts analysis through `analysisTrigger`.
typedef PastedImageImport =
    Future<ImportedImage?> Function({
      required Uint8List data,
      required String fileExtension,
      String? linkedId,
      String? categoryId,
      ImageAnalysisTrigger? analysisTrigger,
      bool linkCollapsed,
    });

/// Records an image of a pull request description on the task that holds
/// the pull request, as an image entry like one the user pasted.
///
/// The entry takes the task's category ([categoryOf]) and the
/// [analysisTrigger] every pasted or dropped picture is given, so it is
/// analysed when the category and the task's profile automate image
/// analysis, and only then. Nothing else in the description is ever
/// analysed: the user chose this image.
class PullRequestImageAttacher {
  PullRequestImageAttacher({
    required this.categoryOf,
    this.analysisTrigger,
    this.logger,
    PastedImageImport? import,
  }) : _import = import ?? importPastedImages;

  /// The category of the task the image is recorded on.
  final Future<String?> Function(String taskId) categoryOf;

  /// Starts the analysis of the entry once written; null never analyses.
  final ImageAnalysisTrigger? analysisTrigger;

  /// Where a failed write is reported; null reports nowhere.
  final DomainLogger? logger;

  final PastedImageImport _import;

  /// Attaches [bytes] to [taskId]. True when the entry was written; false
  /// when the bytes are not an image the app stores, or the write failed.
  Future<bool> attach({
    required Uint8List bytes,
    required String taskId,
  }) async {
    final extension = ImageFormat.fromBytes(bytes)?.extension;
    if (extension == null) return false;
    try {
      final imported = await _import(
        data: bytes,
        fileExtension: extension,
        linkedId: taskId,
        categoryId: await categoryOf(taskId),
        analysisTrigger: analysisTrigger,
        linkCollapsed: false,
      );
      return imported != null;
    } on Object catch (error, stackTrace) {
      logger?.error(
        LogDomain.persistence,
        error,
        stackTrace: stackTrace,
        subDomain: 'pullRequestImageAttach',
      );
      return false;
    }
  }
}

/// [bytes], the image at [url], as a file the full-size viewer can show:
/// under [root] (the system temp directory by default), named by the URL so
/// the same image written again lands on the same file — and written every
/// time, so the file is always what was last fetched, never a same-length
/// predecessor.
///
/// Written synchronously: it is a screenshot's worth of bytes on the way to
/// a viewer the user just asked for, and a tap handler with nothing to
/// await stays one that tests and the Hero transition can follow.
File pullRequestImageFile(
  Uint8List bytes, {
  required String url,
  Directory? root,
}) {
  final extension = ImageFormat.fromBytes(bytes)?.extension ?? 'img';
  final name = '${sha1.convert(utf8.encode(url))}.$extension';
  final directory = Directory(
    p.join((root ?? Directory.systemTemp).path, 'lotti_pull_request_images'),
  )..createSync(recursive: true);
  return File(p.join(directory.path, name))
    ..writeAsBytesSync(bytes, flush: true);
}

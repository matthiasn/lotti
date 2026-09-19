import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/repository/clipboard_repository.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// The format a clipboard item's image is read in, with the file extension
/// the import stores it under.
typedef ClipboardImageFormat = ({FileFormat format, String extension});

/// The format [item]'s image is best read in, or null when it carries no
/// image the import accepts.
///
/// PNG before JPEG — a screenshot is lossless and a copied photo is usually
/// offered as both — then HEIC and HEIF, only where the platform can convert
/// them.
ClipboardImageFormat? clipboardImageFormatOf(DataReader item) {
  if (item.canProvide(Formats.png)) {
    return (format: Formats.png, extension: 'png');
  }
  if (item.canProvide(Formats.jpeg)) {
    return (format: Formats.jpeg, extension: 'jpg');
  }
  if (!ImageImportConstants.supportsHighEfficiencyImageConversion()) {
    return null;
  }
  if (item.canProvide(Formats.heic)) {
    return (format: Formats.heic, extension: 'heic');
  }
  if (item.canProvide(Formats.heif)) {
    return (format: Formats.heif, extension: 'heif');
  }
  return null;
}

/// The bytes of [item]'s image in [format]. Fails when the platform reports
/// a read error; completes with null when it has no file for that format.
Future<Uint8List?> readClipboardImage(
  DataReader item,
  FileFormat format,
) {
  final completer = Completer<Uint8List?>();
  var delivered = false;
  final progress = item.getFile(
    format,
    (file) async {
      delivered = true;
      try {
        completer.complete(await file.readAll());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    },
    onError: (error) {
      if (!completer.isCompleted) completer.completeError(error);
    },
  );
  // No progress means the platform will not deliver a file — unless it
  // already has, synchronously, and the read is still in flight.
  if (progress == null && !delivered) completer.complete(null);
  return completer.future;
}

/// Whether the clipboard currently holds an image the import accepts.
///
/// Read once per listener: a menu or form that offers a paste watches it
/// while open, and a fresh open reads the clipboard again.
final FutureProvider<bool> clipboardHasImageProvider =
    FutureProvider.autoDispose<bool>(
      (ref) async {
        final clipboard = ref.watch(clipboardRepositoryProvider);
        if (clipboard == null) return false;
        final reader = await clipboard.read();
        return reader.items.any(
          (item) => clipboardImageFormatOf(item) != null,
        );
      },
      name: 'clipboardHasImageProvider',
    );

/// Imports the clipboard's first image as a journal image linked to
/// [linkedId] — for a paste that makes *one* picture something's cover or
/// banner — and returns it, or null when the clipboard holds no image or the
/// import refused it.
///
/// [linkCollapsed] keeps the picture out of the host's timeline as an
/// expanded card; a cover or banner is already on screen as itself.
Future<ImportedImage?> importFirstClipboardImage(
  SystemClipboard? clipboard, {
  required String linkedId,
  String? categoryId,
  bool linkCollapsed = false,
}) async {
  if (clipboard == null) return null;
  final reader = await clipboard.read();
  for (final item in reader.items) {
    final format = clipboardImageFormatOf(item);
    if (format == null) continue;
    final data = await readClipboardImage(item, format.format);
    if (data == null) continue;
    return importPastedImages(
      data: data,
      fileExtension: format.extension,
      linkedId: linkedId,
      categoryId: categoryId,
      linkCollapsed: linkCollapsed,
    );
  }
  return null;
}

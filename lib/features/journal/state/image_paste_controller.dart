import 'dart:async';

import 'package:lotti/features/journal/repository/clipboard_repository.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:super_clipboard/super_clipboard.dart';

part 'image_paste_controller.g.dart';

@riverpod
class ImagePasteController extends _$ImagePasteController {
  @override
  Future<bool> build({
    required String? linkedFromId,
    required String? categoryId,
  }) async {
    final clipboard = ref.read(clipboardRepositoryProvider);
    if (clipboard == null) {
      return false;
    }
    final reader = await clipboard.read();
    return reader.items.any(
      (item) => item.canProvide(Formats.png) || item.canProvide(Formats.jpeg),
    );
  }

  Future<void> paste() async {
    final clipboard = ref.read(clipboardRepositoryProvider);
    if (clipboard == null) {
      return;
    }
    final reader = await clipboard.read();

    // Process all clipboard items (supports multiple photos)
    final futures = <Future<void>>[];
    for (final item in reader.items) {
      if (item.canProvide(Formats.jpeg)) {
        futures.add(_processPastedItem(item, Formats.jpeg, 'jpg'));
      } else if (item.canProvide(Formats.png)) {
        futures.add(_processPastedItem(item, Formats.png, 'png'));
      }
    }
    await Future.wait(futures);
  }

  Future<void> _processPastedItem(
    ClipboardDataReader item,
    FileFormat format,
    String fileExtension,
  ) {
    final completer = Completer<void>();
    item.getFile(format, (file) async {
      try {
        await importPastedImages(
          data: await file.readAll(),
          fileExtension: fileExtension,
          linkedId: linkedFromId,
          categoryId: categoryId,
        );
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}

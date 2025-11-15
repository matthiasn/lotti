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
    return reader.canProvide(Formats.png) || reader.canProvide(Formats.jpeg);
  }

  Future<void> paste() async {
    final clipboard = ref.read(clipboardRepositoryProvider);
    if (clipboard == null) {
      return;
    }
    final reader = await clipboard.read();

    // Process all clipboard items (supports multiple photos)
    for (final item in reader.items) {
      if (item.canProvide(Formats.jpeg)) {
        item.getFile(Formats.jpeg, (file) async {
          await importPastedImages(
            data: await file.readAll(),
            fileExtension: 'jpg',
            linkedId: linkedFromId,
            categoryId: categoryId,
          );
        });
      } else if (item.canProvide(Formats.png)) {
        item.getFile(Formats.png, (file) async {
          await importPastedImages(
            data: await file.readAll(),
            fileExtension: 'png',
            linkedId: linkedFromId,
            categoryId: categoryId,
          );
        });
      }
    }
  }
}

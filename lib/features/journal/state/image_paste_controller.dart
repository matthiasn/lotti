import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/journal/repository/clipboard_repository.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:super_clipboard/super_clipboard.dart';

final AsyncNotifierProviderFamily<
  ImagePasteController,
  bool,
  ({String? categoryId, String? linkedFromId})
>
imagePasteControllerProvider = AsyncNotifierProvider.autoDispose
    .family<
      ImagePasteController,
      bool,
      ({String? linkedFromId, String? categoryId})
    >(
      ImagePasteController.new,
      name: 'imagePasteControllerProvider',
    );

class ImagePasteController extends AsyncNotifier<bool> {
  ImagePasteController([
    this._providerArgs = (linkedFromId: null, categoryId: null),
  ]);

  final ({String? linkedFromId, String? categoryId}) _providerArgs;
  String? get linkedFromId => _providerArgs.linkedFromId;
  String? get categoryId => _providerArgs.categoryId;

  @override
  Future<bool> build() async {
    final clipboard = ref.read(clipboardRepositoryProvider);
    if (clipboard == null) {
      return false;
    }
    final reader = await clipboard.read();
    return reader.items.any(_canProvideSupportedImage);
  }

  Future<void> paste() async {
    final clipboard = ref.read(clipboardRepositoryProvider);
    if (clipboard == null) {
      return;
    }
    final reader = await clipboard.read();

    // Process all clipboard items (supports multiple photos)
    final futures = <Future<void>>[];
    final supportsHighEfficiencyImages =
        ImageImportConstants.supportsHighEfficiencyImageConversion();
    for (final item in reader.items) {
      if (item.canProvide(Formats.png)) {
        futures.add(_processPastedItem(item, Formats.png, 'png'));
      } else if (item.canProvide(Formats.jpeg)) {
        futures.add(_processPastedItem(item, Formats.jpeg, 'jpg'));
      } else if (supportsHighEfficiencyImages &&
          item.canProvide(Formats.heic)) {
        futures.add(_processPastedItem(item, Formats.heic, 'heic'));
      } else if (supportsHighEfficiencyImages &&
          item.canProvide(Formats.heif)) {
        futures.add(_processPastedItem(item, Formats.heif, 'heif'));
      }
    }
    await Future.wait(futures);
  }

  bool _canProvideSupportedImage(ClipboardDataReader item) =>
      item.canProvide(Formats.jpeg) ||
      item.canProvide(Formats.png) ||
      (ImageImportConstants.supportsHighEfficiencyImageConversion() &&
          (item.canProvide(Formats.heic) || item.canProvide(Formats.heif)));

  Future<void> _processPastedItem(
    ClipboardDataReader item,
    FileFormat format,
    String fileExtension,
  ) {
    final completer = Completer<void>();
    final analysisTrigger = ref.read(automaticImageAnalysisTriggerProvider);
    item.getFile(format, (file) async {
      try {
        await importPastedImages(
          data: await file.readAll(),
          fileExtension: fileExtension,
          linkedId: linkedFromId,
          categoryId: categoryId,
          analysisTrigger: analysisTrigger,
        );
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}

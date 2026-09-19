import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/journal/repository/clipboard_images.dart';
import 'package:lotti/features/journal/repository/clipboard_repository.dart';
import 'package:lotti/logic/image_import.dart';

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
  Future<bool> build() => ref.watch(clipboardHasImageProvider.future);

  Future<void> paste() async {
    final clipboard = ref.read(clipboardRepositoryProvider);
    if (clipboard == null) {
      return;
    }
    final reader = await clipboard.read();

    // Process all clipboard items (supports multiple photos)
    final analysisTrigger = ref.read(automaticImageAnalysisTriggerProvider);
    final futures = <Future<void>>[];
    for (final item in reader.items) {
      final format = clipboardImageFormatOf(item);
      if (format == null) continue;
      futures.add(() async {
        final data = await readClipboardImage(item, format.format);
        if (data == null) return;
        await importPastedImages(
          data: data,
          fileExtension: format.extension,
          linkedId: linkedFromId,
          categoryId: categoryId,
          analysisTrigger: analysisTrigger,
        );
      }());
    }
    await Future.wait(futures);
  }
}

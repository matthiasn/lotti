import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/image_paste_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class PasteImageListTile extends ConsumerWidget {
  const PasteImageListTile(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = imagePasteControllerProvider(
      linkedFromId: linkedFromId,
      categoryId: categoryId,
    );
    final canPasteImage = ref.watch(provider).valueOrNull ?? false;

    if (!canPasteImage) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: const Icon(Icons.paste),
      title: Text(context.messages.addActionAddImageFromClipboard),
      onTap: () {
        Navigator.of(context).pop();
        ref.read(provider.notifier).paste();
      },
    );
  }
}

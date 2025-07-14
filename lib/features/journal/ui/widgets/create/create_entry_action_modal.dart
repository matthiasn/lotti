import 'package:flutter/material.dart';
import 'package:lotti/features/journal/ui/widgets/create/modern_create_entry_items.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/modal/index.dart';

class CreateEntryModal {
  static Future<void> show({
    required BuildContext context,
    required String? linkedFromId,
    required String? categoryId,
  }) async {
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.createEntryTitle,
      padding: const EdgeInsetsGeometry.only(bottom: 20),
      builder: (_) => Column(
        children: [
          ModernCreateEventItem(linkedFromId, categoryId: categoryId),
          ModernCreateTaskItem(linkedFromId, categoryId: categoryId),
          ModernCreateAudioItem(linkedFromId, categoryId: categoryId),
          if (linkedFromId != null) ModernCreateTimerItem(linkedFromId),
          ModernCreateTextItem(linkedFromId, categoryId: categoryId),
          ModernImportImageItem(linkedFromId, categoryId: categoryId),
          if (isMacOS)
            ModernCreateScreenshotItem(linkedFromId, categoryId: categoryId),
          ModernPasteImageItem(linkedFromId, categoryId: categoryId),
        ],
      ),
    );
  }
}

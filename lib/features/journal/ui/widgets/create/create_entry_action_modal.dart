import 'package:flutter/material.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_items.dart';
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
      padding: const EdgeInsets.only(bottom: 30, top: 10),
      builder: (_) => Column(
        children: [
          CreateEventItem(linkedFromId, categoryId: categoryId),
          CreateTaskItem(linkedFromId, categoryId: categoryId),
          CreateAudioItem(linkedFromId, categoryId: categoryId),
          if (linkedFromId != null) CreateTimerItem(linkedFromId),
          CreateTextItem(linkedFromId, categoryId: categoryId),
          ImportImageItem(linkedFromId, categoryId: categoryId),
          if (isDesktop)
            CreateScreenshotItem(linkedFromId, categoryId: categoryId),
          PasteImageItem(linkedFromId, categoryId: categoryId),
        ],
      ),
    );
  }
}

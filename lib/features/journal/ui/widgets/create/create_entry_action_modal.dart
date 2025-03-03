import 'package:flutter/material.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_list_tile.dart';
import 'package:lotti/features/journal/ui/widgets/create/paste_image_list_tile.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:lotti/utils/platform.dart';

class CreateEntryModal {
  static Future<void> show({
    required BuildContext context,
    required String? linkedFromId,
    required String? categoryId,
  }) async {
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.createEntryTitle,
      builder: (_) => Column(
        children: [
          CreateEventListTile(linkedFromId, categoryId: categoryId),
          CreateTaskListTile(linkedFromId, categoryId: categoryId),
          CreateAudioRecordingListTile(linkedFromId, categoryId: categoryId),
          if (linkedFromId != null) CreateTimerListTile(linkedFromId),
          CreateTextEntryListTile(linkedFromId, categoryId: categoryId),
          ImportImageAssetsListTile(linkedFromId, categoryId: categoryId),
          if (isMacOS)
            CreateScreenshotListTile(linkedFromId, categoryId: categoryId),
          PasteImageListTile(linkedFromId, categoryId: categoryId),
          verticalModalSpacer,
        ],
      ),
    );
  }
}

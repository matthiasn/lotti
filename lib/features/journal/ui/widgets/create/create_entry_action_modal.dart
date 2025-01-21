import 'package:flutter/material.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_list_tile.dart';
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
    await ModalUtils.showSinglePageModal(
      context: context,
      title: context.messages.createEntryTitle,
      builder: (_) => Column(
        children: [
          CreateEventListTile(linkedFromId),
          CreateTaskListTile(linkedFromId, categoryId: categoryId),
          CreateAudioRecordingListTile(linkedFromId),
          if (linkedFromId != null) CreateTimerListTile(linkedFromId),
          CreateTextEntryListTile(linkedFromId),
          ImportImageAssetsListTile(linkedFromId),
          if (isMacOS) CreateScreenshotListTile(linkedFromId),
          verticalModalSpacer,
        ],
      ),
    );
  }
}

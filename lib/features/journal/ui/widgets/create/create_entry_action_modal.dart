import 'package:flutter/material.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_list_tiles.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/modals.dart';
import 'package:lotti/utils/platform.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class CreateEntryModal {
  static Future<void> show({
    required BuildContext context,
    required String? linkedFromId,
    required String? categoryId,
  }) async {
    await WoltModalSheet.show<void>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        return [
          ModalUtils.modalSheetPage(
            context: modalSheetContext,
            title: modalSheetContext.messages.createEntryTitle,
            child: Column(
              children: [
                CreateEventListTile(linkedFromId: linkedFromId),
                CreateTaskListTile(
                  linkedFromId: linkedFromId,
                  categoryId: categoryId,
                ),
                CreateAudioRecordingListTile(linkedFromId: linkedFromId),
                if (linkedFromId != null)
                  CreateTimerListTile(linkedFromId: linkedFromId),
                CreateTextEntryListTile(linkedFromId: linkedFromId),
                ImportImageAssetsListTile(linkedFromId: linkedFromId),
                if (isMacOS)
                  CreateScreenshotListTile(
                    linkedFromId: linkedFromId,
                  ),
              ],
            ),
          ),
        ];
      },
      modalTypeBuilder: ModalUtils.modalTypeBuilder,
      barrierDismissible: true,
    );
  }
}

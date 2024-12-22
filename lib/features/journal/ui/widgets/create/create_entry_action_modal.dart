import 'package:flutter/material.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_list_tiles.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class CreateEntryModal {
  static Future<void> show({
    required BuildContext context,
    required String? linkedFromId,
    required String? categoryId,
  }) async {
    final theme = Theme.of(context);
    await WoltModalSheet.show<void>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        final textTheme = context.textTheme;
        return [
          WoltModalSheetPage(
            hasSabGradient: false,
            topBarTitle: Text(
              modalSheetContext.messages.createEntryTitle,
              style: textTheme.titleLarge,
            ),
            isTopBarLayerAlwaysVisible: true,
            trailingNavBarWidget: IconButton(
              padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
              icon: const Icon(Icons.close),
              onPressed: Navigator.of(modalSheetContext).pop,
            ),
            child: Theme(
              data: theme.copyWith(
                iconTheme: theme.iconTheme.copyWith(size: 30),
                listTileTheme: theme.listTileTheme.copyWith(
                  titleTextStyle: theme.textTheme.titleLarge,
                  minTileHeight: 60,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
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
            ),
          ),
        ];
      },
      modalTypeBuilder: (context) {
        final size = MediaQuery.of(context).size.width;
        if (size < WoltModalConfig.pageBreakpoint) {
          return WoltModalType.bottomSheet();
        } else {
          return WoltModalType.dialog();
        }
      },
      barrierDismissible: true,
    );
  }
}

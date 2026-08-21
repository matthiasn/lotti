import 'package:flutter/material.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/speech_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/index.dart';

/// The entry `•••` menu — one of the app's two action modals, on the shared
/// [DsActionModal] shell.
///
/// Two pages: the action list, and the speech-recognition page an audio entry
/// can push. Both are headed the same way, so stepping into the second page
/// does not change what the sheet looks like above the content.
class ExtendedHeaderModal {
  static Future<void> show({
    required BuildContext context,
    required String entryId,
    required String? linkedFromId,
    required EntryLink? link,
    required bool inLinkedEntries,
  }) async {
    final pageIndexNotifier = ValueNotifier(0);

    return ModalUtils.showMultiPageModal<void>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        return [
          DsActionModal.page(
            context: modalSheetContext,
            title: context.messages.entryActions,
            builder: (_) => InitialModalPageContent(
              entryId: entryId,
              linkedFromId: linkedFromId,
              inLinkedEntries: inLinkedEntries,
              link: link,
              pageIndexNotifier: pageIndexNotifier,
            ),
          ),
          DsActionModal.page(
            context: modalSheetContext,
            title: context.messages.speechModalTitle,
            onTapBack: () => pageIndexNotifier.value = 0,
            builder: (_) => SpeechModalContent(entryId: entryId),
          ),
        ];
      },
      pageIndexNotifier: pageIndexNotifier,
    );
  }
}

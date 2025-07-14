import 'package:flutter/material.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_modal.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/speech_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/index.dart';

class ExtendedHeaderModal {
  static Future<void> show({
    required BuildContext context,
    required String entryId,
    required String? linkedFromId,
    required EntryLink? link,
    required bool inLinkedEntries,
  }) async {
    final pageIndexNotifier = ValueNotifier(0);

    final initialModalPage = ModalUtils.modalSheetPage(
      context: context,
      padding: const EdgeInsetsGeometry.only(bottom: 20),
      title: context.messages.entryActions,
      child: InitialModalPageContent(
        entryId: entryId,
        linkedFromId: linkedFromId,
        inLinkedEntries: inLinkedEntries,
        link: link,
        pageIndexNotifier: pageIndexNotifier,
      ),
    );

    final tagsModalPage = ModalUtils.modalSheetPage(
      context: context,
      title: context.messages.journalTagPlusHint,
      child: TagsModal(entryId: entryId),
      onTapBack: () => pageIndexNotifier.value = 0,
    );

    final speechRecognitionModalPage = ModalUtils.modalSheetPage(
      context: context,
      title: context.messages.speechModalTitle,
      child: SpeechModalContent(entryId: entryId),
      onTapBack: () => pageIndexNotifier.value = 0,
    );

    return ModalUtils.showMultiPageModal<void>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        return [
          initialModalPage,
          tagsModalPage,
          speechRecognitionModalPage,
        ];
      },
      pageIndexNotifier: pageIndexNotifier,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/ollama_prompt.dart';
import 'package:lotti/features/ai/state/ollama_prompt_checklist.dart';
import 'package:lotti/features/ai/ui/ai_response_preview.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class AiPopUpMenu extends StatelessWidget {
  const AiPopUpMenu({
    required this.journalEntity,
    required this.linkedFromId,
    super.key,
  });

  final JournalEntity? journalEntity;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.assistant_rounded),
      onPressed: () => AiAssistantModal.show(
        context: context,
        journalEntity: journalEntity,
        linkedFromId: linkedFromId,
      ),
    );
  }
}

class AiPromptListTile extends ConsumerWidget {
  const AiPromptListTile({
    required this.journalEntity,
    this.linkedFromId,
    super.key,
  });

  final JournalEntity? journalEntity;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.chat_rounded),
      title: Text(context.messages.aiAssistantRunPrompt),
      onTap: () {
        ref.read(aiResponseProvider.notifier).prompt(
              journalEntity,
              linkedFromId: linkedFromId,
            );
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) => const AiResponsePreview(),
        );
      },
    );
  }
}

class AiChecklistListTile extends ConsumerWidget {
  const AiChecklistListTile({
    required this.journalEntity,
    this.linkedFromId,
    super.key,
  });

  final JournalEntity? journalEntity;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.checklist_rounded),
      title: Text(context.messages.aiAssistantCreateChecklist),
      onTap: () {
        ref.read(aiChecklistResponseProvider.notifier).createChecklistItems(
              journalEntity,
              linkedFromId: linkedFromId,
            );
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) => AiChecklistResponsePreview(
            linkedFromId: linkedFromId,
          ),
        );
      },
    );
  }
}

class AiAssistantModal {
  static SliverWoltModalSheetPage page1({
    required BuildContext modalSheetContext,
    required TextTheme textTheme,
    required JournalEntity? journalEntity,
    required String? linkedFromId,
  }) {
    return WoltModalSheetPage(
      hasSabGradient: false,
      topBarTitle: Text(
        modalSheetContext.messages.aiAssistantTitle,
        style: textTheme.titleLarge,
      ),
      isTopBarLayerAlwaysVisible: true,
      trailingNavBarWidget: IconButton(
        padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
        icon: const Icon(Icons.close),
        onPressed: Navigator.of(modalSheetContext).pop,
      ),
      child: Padding(
        padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
        child: Column(
          children: [
            AiPromptListTile(
              journalEntity: journalEntity,
              linkedFromId: linkedFromId,
            ),
            AiChecklistListTile(
              journalEntity: journalEntity,
              linkedFromId: linkedFromId,
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> show({
    required BuildContext context,
    required JournalEntity? journalEntity,
    required String? linkedFromId,
  }) async {
    await WoltModalSheet.show<void>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        final textTheme = context.textTheme;
        return [
          page1(
            modalSheetContext: modalSheetContext,
            textTheme: textTheme,
            journalEntity: journalEntity,
            linkedFromId: linkedFromId,
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
      onModalDismissedWithBarrierTap: () {
        Navigator.of(context).pop();
      },
    );
  }
}

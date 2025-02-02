import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/image_analysis/ai_image_analysis_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/modals.dart';

class AiImageAnalysisListTile extends ConsumerWidget {
  const AiImageAnalysisListTile({
    required this.journalImage,
    this.linkedFromId,
    super.key,
  });

  final JournalImage journalImage;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.chat_rounded),
      title: Text(
        context.messages.aiAssistantAnalyzeImage,
      ),
      onTap: () {
        Navigator.of(context).pop();
        ModalUtils.showSinglePageModal(
          context: context,
          title: context.messages.aiAssistantTitle,
          builder: (_) => AiImageAnalysisView(
            id: journalImage.id,
          ),
        );
      },
    );
  }
}

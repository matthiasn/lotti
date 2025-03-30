import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/image_analysis.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class AiImageAnalysisListTile extends ConsumerWidget {
  const AiImageAnalysisListTile({
    required this.journalImage,
    required this.onTap,
    this.linkedFromId,
    super.key,
  });

  final JournalImage journalImage;
  final String? linkedFromId;
  final void Function() onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.assistant),
      title: Text(
        context.messages.aiAssistantAnalyzeImage,
      ),
      onTap: () {
        final provider = aiImageAnalysisControllerProvider(id: journalImage.id);
        ref.invalidate(provider);
        ref.read(provider.notifier).analyzeImage();
        onTap();
      },
    );
  }
}

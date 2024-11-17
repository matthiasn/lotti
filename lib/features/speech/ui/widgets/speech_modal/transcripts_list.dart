import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/transcripts_list_item.dart';

class TranscriptsList extends ConsumerWidget {
  const TranscriptsList({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null || item is! JournalAudio) {
      return const SizedBox.shrink();
    }

    final transcripts = item.data.transcripts;

    return Column(
      children: [
        const SizedBox(height: 10),
        ...?transcripts?.map(
          (transcript) => TranscriptListItem(
            transcript,
            entryId: item.meta.id,
          ),
        ),
      ],
    );
  }
}

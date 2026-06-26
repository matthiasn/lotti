import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/transcripts_list_item.dart';

/// Renders one [TranscriptListItem] per transcript stored on an audio entry.
///
/// Watches the entry via `entryControllerProvider` and renders nothing for
/// non-audio entries or entries without transcripts.
class TranscriptsList extends ConsumerWidget {
  const TranscriptsList({
    required this.entryId,
    super.key,
  });

  /// Id of the `JournalAudio` entry whose transcripts are listed.
  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(entryId);
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

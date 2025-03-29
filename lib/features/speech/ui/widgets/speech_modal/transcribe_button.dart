import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/state/asr_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class TranscribeButton extends ConsumerWidget {
  const TranscribeButton({
    required this.entryId,
    required this.navigateToProgressModal,
    super.key,
  });

  final String entryId;
  final void Function() navigateToProgressModal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(Platform.isMacOS || Platform.isIOS)) {
      return const SizedBox.shrink();
    }

    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null || item is! JournalAudio) {
      return const SizedBox.shrink();
    }

    return TextButton(
      onPressed: () async {
        final isQueueEmpty = getIt<AsrService>().enqueue(entry: item);

        if (await isQueueEmpty) {
          navigateToProgressModal();
        }

        await Future<void>.delayed(
          const Duration(milliseconds: 100),
        );
        notifier
          ..setController()
          ..emitState();
      },
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.transcribe_rounded),
            const SizedBox(width: 10),
            Text(context.messages.speechModalAddTranscription),
          ],
        ),
      ),
    );
  }
}

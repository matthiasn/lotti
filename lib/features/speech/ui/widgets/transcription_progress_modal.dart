import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/speech/state/asr_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';

class TranscriptionProgressModalContent extends StatelessWidget {
  const TranscriptionProgressModalContent({super.key});

  @override
  Widget build(BuildContext context) {
    final asrService = getIt<AsrService>();

    return StreamBuilder<(String, TranscriptionStatus)>(
      stream: asrService.progressController.stream,
      builder: (context, snapshot) {
        final text = snapshot.data?.$1 ?? '';
        final status = snapshot.data?.$2;
        final hasError = status == TranscriptionStatus.error;

        void pop() => Navigator.of(context).pop();

        if (status == TranscriptionStatus.done) {
          Future<void>.delayed(const Duration(seconds: 3))
              .then((value) => pop());
        }

        if (hasError) {
          Future<void>.delayed(const Duration(seconds: 5))
              .then((value) => pop());
        }

        return Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarkdownBody(
                data: text,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: hasError ? context.colorScheme.error : null,
                  ),
                ),
              ),
              verticalModalSpacer,
              const Center(child: AiRunningAnimation(height: 50)),
            ],
          ),
        );
      },
    );
  }
}

class TranscriptionProgressModal {
  static Future<void> show(BuildContext context) async {
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.speechModalTranscriptionProgress,
      builder: (_) => const TranscriptionProgressModalContent(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lotti/features/speech/state/asr_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class TranscriptionProgressView extends StatelessWidget {
  const TranscriptionProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    final asrService = getIt<AsrService>();

    return StreamBuilder<(String, TranscriptionStatus)>(
      stream: asrService.progressController.stream,
      builder: (context, snapshot) {
        final text = snapshot.data?.$1;
        final status = snapshot.data?.$2;
        final hasError = status == TranscriptionStatus.error;

        if (text == null) {
          return const SizedBox();
        }

        return ListTile(
          title: Text(
            context.messages.settingsSpeechLastActivity,
          ),
          subtitle: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: context.colorScheme.inverseSurface.withOpacity(0.1),
            child: MarkdownBody(
              data: text,
              styleSheet: MarkdownStyleSheet(
                p: monospaceTextStyle.copyWith(
                  color: hasError ? context.colorScheme.error : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

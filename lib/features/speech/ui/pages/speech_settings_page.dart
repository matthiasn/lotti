import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/speech/state/speech_settings_cubit.dart';
import 'package:lotti/features/speech/state/speech_settings_state.dart';
import 'package:lotti/features/speech/ui/widgets/whisper_model_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';

class SpeechSettingsPage extends StatelessWidget {
  const SpeechSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SpeechSettingsCubit>(
      create: (BuildContext context) => SpeechSettingsCubit(),
      child: BlocBuilder<SpeechSettingsCubit, SpeechSettingsState>(
        builder: (context, snapshot) {
          return SliverBoxAdapterPage(
            title: context.messages.settingsSpeechTitle,
            showBackButton: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  ListTile(
                    title: Text(
                      context.messages.settingsSpeechModelSelectionTitle,
                    ),
                  ),
                  ...snapshot.availableModels.map(WhisperModelCard.new),
                  const SizedBox(height: 30),
                  ListTile(
                    title: Text(
                      context.messages.settingsSpeechAudioWithoutTranscript,
                    ),
                    trailing: FilledButton(
                      onPressed: () => getIt<Maintenance>()
                          .transcribeAudioWithoutTranscript(),
                      child: Text(
                        context.messages
                            .settingsSpeechAudioWithoutTranscriptButton,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

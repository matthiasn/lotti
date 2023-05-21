import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/settings/speech/speech_settings_cubit.dart';
import 'package:lotti/blocs/settings/speech/speech_settings_state.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/settings/speech/whisper_model_card.dart';

class SpeechSettingsPage extends StatelessWidget {
  const SpeechSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocProvider<SpeechSettingsCubit>(
      create: (BuildContext context) => SpeechSettingsCubit(),
      child: Scaffold(
        backgroundColor: styleConfig().negspace,
        body: BlocBuilder<SpeechSettingsCubit, SpeechSettingsState>(
          builder: (context, snapshot) {
            return SliverBoxAdapterPage(
              title: localizations.settingsSpeechTitle,
              showBackButton: true,
              child: Column(
                children: [
                  ...snapshot.availableModels.map(WhisperModelCard.new),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

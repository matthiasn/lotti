import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/features/speech/state/speech_settings_cubit.dart';
import 'package:lotti/features/speech/state/speech_settings_state.dart';

class WhisperModelCard extends StatelessWidget {
  const WhisperModelCard(this.model, {super.key});

  final String model;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SpeechSettingsCubit, SpeechSettingsState>(
      builder: (context, snapshot) {
        final cubit = context.read<SpeechSettingsCubit>();

        return CheckboxListTile(
          value: model == snapshot.selectedModel,
          onChanged: (_) => cubit.selectModel(model),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(model),
        );
      },
    );
  }
}

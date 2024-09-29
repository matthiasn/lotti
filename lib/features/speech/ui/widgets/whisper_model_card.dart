import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/features/speech/state/speech_settings_cubit.dart';
import 'package:lotti/features/speech/state/speech_settings_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class WhisperModelCard extends StatelessWidget {
  const WhisperModelCard(this.model, {super.key});

  final String model;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SpeechSettingsCubit, SpeechSettingsState>(
      builder: (context, snapshot) {
        final cubit = context.read<SpeechSettingsCubit>();

        final progress = snapshot.downloadProgress[model] ?? 0.0;
        final downloaded = progress == 1.0;

        final textColor = downloaded ? null : context.colorScheme.outline;

        return Card(
          margin: const EdgeInsets.all(5),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            child: Row(
              children: [
                IgnorePointer(
                  ignoring: !downloaded,
                  child: IconButton(
                    color: model == snapshot.selectedModel
                        ? Theme.of(context).primaryColor
                        : textColor,
                    onPressed: () => cubit.selectModel(model),
                    icon: model == snapshot.selectedModel
                        ? const Icon(
                            Icons.check_box_outlined,
                            size: 30,
                          )
                        : const Icon(
                            Icons.check_box_outline_blank,
                            size: 30,
                          ),
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  model,
                  style: settingsCardTextStyle.copyWith(
                    color: textColor,
                  ),
                ),
                const Spacer(),
                if (progress == 0.0)
                  TextButton(
                    child: Text(
                      context.messages.settingsSpeechDownloadButton,
                      semanticsLabel: 'download $model',
                    ),
                    onPressed: () {},
                  ),
                if (progress == 1.0)
                  Text(
                    '${(snapshot.downloadedModelSizes[model] ?? 0).round()} MB',
                  ),
                if (progress == 1.0)
                  IconButton(
                    padding: const EdgeInsets.all(10),
                    icon: Semantics(
                      label: 'delete whisper model',
                      child: Icon(MdiIcons.trashCanOutline),
                    ),
                    onPressed: () => cubit.deleteModel(model),
                  ),
                if (progress > 0.0 && progress < 1.0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 80,
                      child: LinearProgressIndicator(
                        value: progress,
                        color: Theme.of(context).primaryColor,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.5),
                        minHeight: 15,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

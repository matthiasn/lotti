import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/settings/speech/speech_settings_cubit.dart';
import 'package:lotti/blocs/settings/speech/speech_settings_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

class SpeechSettingsPage extends StatefulWidget {
  const SpeechSettingsPage({super.key});

  @override
  State<SpeechSettingsPage> createState() => _SpeechSettingsPageState();
}

class _SpeechSettingsPageState extends State<SpeechSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocProvider<SpeechSettingsCubit>(
      create: (BuildContext context) => SpeechSettingsCubit(),
      child: Scaffold(
        backgroundColor: styleConfig().negspace,
        appBar: TitleAppBar(title: localizations.settingsSpeechTitle),
        body: BlocBuilder<SpeechSettingsCubit, SpeechSettingsState>(
          builder: (context, snapshot) {
            final cubit = context.read<SpeechSettingsCubit>();

            return ListView(
              shrinkWrap: true,
              children: [
                ...snapshot.availableModels.map(
                  (model) {
                    final downloaded =
                        snapshot.downloadedModels.contains(model);

                    final textColor = downloaded
                        ? styleConfig().primaryTextColor
                        : styleConfig().secondaryTextColor;

                    return Card(
                      margin: const EdgeInsets.all(5),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            IgnorePointer(
                              ignoring: !downloaded,
                              child: IconButton(
                                color: model == snapshot.selectedModel
                                    ? styleConfig().primaryColor
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
                              style: settingsCardTextStyle().copyWith(
                                color: textColor,
                              ),
                            ),
                            const Spacer(),
                            if (!downloaded)
                              TextButton(
                                child: Text(
                                  'download',
                                  style: buttonLabelStyle(),
                                ),
                                onPressed: () => cubit.downloadModel(model),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              ],
            );
          },
        ),
      ),
    );
  }
}

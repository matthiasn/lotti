import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/audio/audio_recorder.dart';

class RecordAudioPage extends StatelessWidget {
  const RecordAudioPage({
    super.key,
    this.linkedId,
  });
  final String? linkedId;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: TitleAppBar(title: localizations.addAudioTitle),
      backgroundColor: colorConfig().bodyBgColor,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [AudioRecorderWidget(linkedId: linkedId)],
      ),
    );
  }
}

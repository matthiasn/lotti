import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
    return Scaffold(
      appBar: TitleAppBar(title: context.messages.addAudioTitle),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [AudioRecorderWidget(linkedId: linkedId)],
      ),
    );
  }
}

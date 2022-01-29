import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/audio/audio_recorder.dart';
import 'package:lotti/widgets/misc/app_bar_version.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({
    Key? key,
    this.linked,
  }) : super(key: key);
  final JournalEntity? linked;

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const VersionAppBar(title: 'Record Audio'),
      backgroundColor: AppColors.bodyBgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AudioRecorderWidget(
              linked: widget.linked,
            ),
          ],
        ),
      ),
    );
  }
}

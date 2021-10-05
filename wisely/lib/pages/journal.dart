import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wisely/blocs/audio_notes_cubit.dart';
import 'package:wisely/blocs/audio_player_cubit.dart';
import 'package:wisely/db/audio_note.dart';
import 'package:wisely/theme.dart';
import 'package:wisely/widgets/audio_player.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({Key? key}) : super(key: key);

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
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
    return BlocBuilder<AudioNotesCubit, AudioNotesCubitState>(
        builder: (context, audioNotesState) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'Audio Recordings',
                  style: TextStyle(
                    color: AppColors.inactiveAudioControl,
                    fontFamily: 'Oswald',
                    fontSize: 24.0,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                itemCount: audioNotesState.audioNotesMap.length,
                itemBuilder: (BuildContext context, int index) {
                  return AudioNoteListItem(
                    audioNote:
                        audioNotesState.audioNotesMap.values.elementAt(index),
                  );
                },
              )
            ],
          ),
        ),
      );
    });
  }
}

class AudioNoteListItem extends StatelessWidget {
  AudioNote audioNote;
  AudioNoteListItem({required this.audioNote});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: TextButton(
        child: Padding(
          padding: const EdgeInsets.only(
              left: 16.0, right: 16.0, top: 8.0, bottom: 8.0),
          child: Row(
            children: [
              Text(
                '${audioNote.createdAt.toString().substring(0, 16)} - ',
                style: TextStyle(
                  fontFamily: 'ShareTechMono',
                  fontSize: 16.0,
                ),
              ),
              Text(
                audioNote.duration.toString().split('.')[0],
                style: TextStyle(
                  fontFamily: 'ShareTechMono',
                  fontSize: 16.0,
                ),
              ),
            ],
          ),
        ),
        style: TextButton.styleFrom(
          primary: AppColors.inactiveAudioControl,
          onSurface: Colors.yellow,
          side: BorderSide(color: AppColors.inactiveAudioControl, width: 0.5),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8))),
        ),
        onPressed: () {
          context.read<AudioPlayerCubit>().setAudioNote(audioNote);
          showModalBottomSheet<void>(
            context: context,
            builder: (BuildContext context) {
              return Container(
                height: 200,
                color: AppColors.bodyBgColor,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AudioPlayerWidget(),
                      ElevatedButton(
                        child: const Text('Close BottomSheet'),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

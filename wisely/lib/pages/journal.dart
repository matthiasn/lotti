import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wisely/blocs/audio/player_cubit.dart';
import 'package:wisely/blocs/journal_entities_cubit.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/theme.dart';
import 'package:wisely/utils/image_utils.dart';
import 'package:wisely/widgets/audio_player.dart';
import 'package:wisely/widgets/map_widget.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({Key? key}) : super(key: key);

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  Directory? _docDir;

  @override
  void initState() {
    super.initState();
    setDocDir();
  }

  void setDocDir() async {
    Directory docDir = await getApplicationDocumentsDirectory();

    setState(() {
      _docDir = docDir;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalEntitiesCubit, JournalEntitiesState>(
        builder: (context, journalEntitiesState) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: journalEntitiesState.journalEntitiesMap.length,
                itemBuilder: (BuildContext context, int index) {
                  JournalEntity item = journalEntitiesState
                      .journalEntitiesMap.values
                      .elementAt(index);
                  return Dismissible(
                    key: Key(index.toString()),
                    background: Container(color: Colors.red),
                    child: item.map(
                      journalEntry: (JournalEntry journalEntry) =>
                          const Text('implement JournalEntry view'),
                      journalImage: (JournalImage journalImage) => Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: (_docDir != null)
                            ? Image.file(
                                File(getFullImagePathWithDocDir(
                                    journalImage, _docDir)),
                                width: 300,
                                height: 300,
                                fit: BoxFit.contain,
                              )
                            : null,
                      ),
                      audioNote: (audioNote) => AudioNoteListItem(
                        audioNote: audioNote,
                      ),
                    ),
                    onDismissed: (DismissDirection direction) {
                      context.read<JournalEntitiesCubit>().delete(item);
                    },
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
  AudioNoteListItem({Key? key, required this.audioNote}) : super(key: key);

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
                style: const TextStyle(
                  fontFamily: 'ShareTechMono',
                  fontSize: 16.0,
                ),
              ),
              Text(
                audioNote.duration.toString().split('.')[0],
                style: const TextStyle(
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
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            clipBehavior: Clip.antiAliasWithSaveLayer,
            builder: (BuildContext context) {
              return Container(
                height: 312,
                color: AppColors.bodyBgColor,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const MapWidget(),
                      const AudioPlayerWidget(),
                      ElevatedButton(
                        child: const Text('Close'),
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

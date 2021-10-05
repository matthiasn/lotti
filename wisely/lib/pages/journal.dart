import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wisely/blocs/audio_notes_cubit.dart';
import 'package:wisely/blocs/counter_bloc.dart';
import 'package:wisely/blocs/vector_clock_counter_cubit.dart';
import 'package:wisely/db/audio_note.dart';

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
    return BlocBuilder<CounterBloc, int>(builder: (context, count) {
      return BlocBuilder<AudioNotesCubit, AudioNotesCubitState>(
          builder: (context, audioNotesState) {
        return Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      tooltip: 'Decrement',
                      onPressed: () =>
                          context.read<CounterBloc>().add(Decrement()),
                    ),
                    IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Increment',
                        onPressed: () {
                          context.read<VectorClockCubit>().increment();
                          context.read<CounterBloc>().add(Increment());
                        }),
                  ],
                ),
                Text('$count', style: Theme.of(context).textTheme.headline1),
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
    });
  }
}

class AudioNoteListItem extends StatelessWidget {
  AudioNote audioNote;
  AudioNoteListItem({required this.audioNote});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Row(
        children: [
          Text(
            '${audioNote.createdAt.toString().substring(0, 19)} - ',
          ),
          Text(
            '${audioNote.duration.inSeconds} - ',
          ),
          Text(
            '${audioNote.updatedAt.toString().substring(0, 19)} ',
          ),
        ],
      ),
    );
  }
}

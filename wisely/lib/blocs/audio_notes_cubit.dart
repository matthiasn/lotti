import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:wisely/db/audio_note.dart';

part 'audio_notes_cubit.g.dart';

@JsonSerializable()
class AudioNotesCubitState {
  Map<String, AudioNote> audioNotesMap = <String, AudioNote>{};

  AudioNotesCubitState();

  AudioNotesCubitState.save(AudioNotesCubitState state, AudioNote audioNote) {
    Map<String, AudioNote> newAudioNotesMap = Map.from(state.audioNotesMap);
    newAudioNotesMap[audioNote.id] = audioNote;
    newAudioNotesMap.addEntries([MapEntry(audioNote.id, audioNote)]);
    audioNotesMap = newAudioNotesMap;
  }

  AudioNotesCubitState.delete(AudioNotesCubitState state, AudioNote audioNote) {
    Map<String, AudioNote> newAudioNotesMap = Map.from(state.audioNotesMap);
    newAudioNotesMap.remove(audioNote.id);
    audioNotesMap = newAudioNotesMap;
  }

  factory AudioNotesCubitState.fromJson(Map<String, dynamic> json) =>
      _$AudioNotesCubitStateFromJson(json);

  Map<String, dynamic> toJson() => _$AudioNotesCubitStateToJson(this);

  @override
  List<Object?> get props => [audioNotesMap];

  @override
  String toString() {
    return 'AudioNotesCubitState ${audioNotesMap.values} entries';
  }
}

class AudioNotesCubit extends HydratedCubit<AudioNotesCubitState> {
  AudioNotesCubit() : super(AudioNotesCubitState());

  void save(AudioNote audioNote) {
    AudioNotesCubitState next = AudioNotesCubitState.save(state, audioNote);
    emit(next);
  }

  void delete(AudioNote audioNote) {
    AudioNotesCubitState next = AudioNotesCubitState.delete(state, audioNote);
    emit(next);
  }

  @override
  AudioNotesCubitState fromJson(Map<String, dynamic> json) =>
      AudioNotesCubitState.fromJson(json);

  @override
  Map<String, dynamic> toJson(AudioNotesCubitState state) => state.toJson();
}

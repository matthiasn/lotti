import 'package:flutter/services.dart';
import 'package:geocoder_offline/geocoder_offline.dart';
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
  GeocodeData? geocoder;

  Future<void> loadData() async {
    String data =
        await rootBundle.loadString('assets/geocoder/cities15000.txt');
    geocoder = GeocodeData(data, 'FEATURE_NAME', 'STATE_ALPHA',
        'PRIMARY_LATITUDE', 'PRIMARY_LONGITUDE',
        fieldDelimiter: ',', eol: '\n');
    print('GEOCODER loaded');
  }

  AudioNotesCubit() : super(AudioNotesCubitState()) {
    loadData();
  }

  void save(AudioNote audioNote) {
    AudioNotesCubitState next = AudioNotesCubitState.save(state, audioNote);
    print(next);
    if (audioNote.latitude != null && audioNote.longitude != null) {
      var geoRes = geocoder?.search(audioNote.latitude!, audioNote.longitude!);
      print('GEOCODER $geoRes');
    }
    emit(next);
  }

  @override
  AudioNotesCubitState fromJson(Map<String, dynamic> json) =>
      AudioNotesCubitState.fromJson(json);

  @override
  Map<String, dynamic> toJson(AudioNotesCubitState state) => state.toJson();
}

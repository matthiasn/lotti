// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_notes_cubit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AudioNotesCubitState _$AudioNotesCubitStateFromJson(
        Map<String, dynamic> json) =>
    AudioNotesCubitState()
      ..audioNotesMap = (json['audioNotesMap'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, AudioNote.fromJson(e as Map<String, dynamic>)),
      );

Map<String, dynamic> _$AudioNotesCubitStateToJson(
        AudioNotesCubitState instance) =>
    <String, dynamic>{
      'audioNotesMap': instance.audioNotesMap,
    };

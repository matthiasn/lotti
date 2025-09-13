// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_text.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EntryText _$EntryTextFromJson(Map<String, dynamic> json) => _EntryText(
      plainText: json['plainText'] as String,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      markdown: json['markdown'] as String?,
      quill: json['quill'] as String?,
    );

Map<String, dynamic> _$EntryTextToJson(_EntryText instance) =>
    <String, dynamic>{
      'plainText': instance.plainText,
      'geolocation': instance.geolocation,
      'markdown': instance.markdown,
      'quill': instance.quill,
    };

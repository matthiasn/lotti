// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_text.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EntryTextImpl _$$EntryTextImplFromJson(Map<String, dynamic> json) =>
    _$EntryTextImpl(
      plainText: json['plainText'] as String,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      markdown: json['markdown'] as String?,
      quill: json['quill'] as String?,
    );

Map<String, dynamic> _$$EntryTextImplToJson(_$EntryTextImpl instance) =>
    <String, dynamic>{
      'plainText': instance.plainText,
      'geolocation': instance.geolocation,
      'markdown': instance.markdown,
      'quill': instance.quill,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'whats_new_release.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WhatsNewRelease _$WhatsNewReleaseFromJson(Map<String, dynamic> json) =>
    _WhatsNewRelease(
      version: json['version'] as String,
      date: DateTime.parse(json['date'] as String),
      title: json['title'] as String,
      folder: json['folder'] as String,
    );

Map<String, dynamic> _$WhatsNewReleaseToJson(_WhatsNewRelease instance) =>
    <String, dynamic>{
      'version': instance.version,
      'date': instance.date.toIso8601String(),
      'title': instance.title,
      'folder': instance.folder,
    };

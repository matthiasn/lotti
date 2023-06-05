// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_ImapConfig _$$_ImapConfigFromJson(Map<String, dynamic> json) =>
    _$_ImapConfig(
      host: json['host'] as String,
      folder: json['folder'] as String,
      userName: json['userName'] as String,
      password: json['password'] as String,
      port: json['port'] as int,
    );

Map<String, dynamic> _$$_ImapConfigToJson(_$_ImapConfig instance) =>
    <String, dynamic>{
      'host': instance.host,
      'folder': instance.folder,
      'userName': instance.userName,
      'password': instance.password,
      'port': instance.port,
    };

_$_SyncConfig _$$_SyncConfigFromJson(Map<String, dynamic> json) =>
    _$_SyncConfig(
      imapConfig:
          ImapConfig.fromJson(json['imapConfig'] as Map<String, dynamic>),
      sharedSecret: json['sharedSecret'] as String,
    );

Map<String, dynamic> _$$_SyncConfigToJson(_$_SyncConfig instance) =>
    <String, dynamic>{
      'imapConfig': instance.imapConfig,
      'sharedSecret': instance.sharedSecret,
    };

_$_StyleConfig _$$_StyleConfigFromJson(Map<String, dynamic> json) =>
    _$_StyleConfig(
      tagColor: const ColorConverter().fromJson(json['tagColor'] as String),
      tagTextColor:
          const ColorConverter().fromJson(json['tagTextColor'] as String),
      personTagColor:
          const ColorConverter().fromJson(json['personTagColor'] as String),
      storyTagColor:
          const ColorConverter().fromJson(json['storyTagColor'] as String),
      starredGold:
          const ColorConverter().fromJson(json['starredGold'] as String),
      selectedChoiceChipColor: const ColorConverter()
          .fromJson(json['selectedChoiceChipColor'] as String),
      selectedChoiceChipTextColor: const ColorConverter()
          .fromJson(json['selectedChoiceChipTextColor'] as String),
      unselectedChoiceChipColor: const ColorConverter()
          .fromJson(json['unselectedChoiceChipColor'] as String),
      unselectedChoiceChipTextColor: const ColorConverter()
          .fromJson(json['unselectedChoiceChipTextColor'] as String),
      secondaryTextColor:
          const ColorConverter().fromJson(json['secondaryTextColor'] as String),
      chartTextColor:
          const ColorConverter().fromJson(json['chartTextColor'] as String),
      textEditorBackground: const ColorConverter()
          .fromJson(json['textEditorBackground'] as String),
      keyboardAppearance:
          $enumDecode(_$BrightnessEnumMap, json['keyboardAppearance']),
    );

Map<String, dynamic> _$$_StyleConfigToJson(_$_StyleConfig instance) =>
    <String, dynamic>{
      'tagColor': const ColorConverter().toJson(instance.tagColor),
      'tagTextColor': const ColorConverter().toJson(instance.tagTextColor),
      'personTagColor': const ColorConverter().toJson(instance.personTagColor),
      'storyTagColor': const ColorConverter().toJson(instance.storyTagColor),
      'starredGold': const ColorConverter().toJson(instance.starredGold),
      'selectedChoiceChipColor':
          const ColorConverter().toJson(instance.selectedChoiceChipColor),
      'selectedChoiceChipTextColor':
          const ColorConverter().toJson(instance.selectedChoiceChipTextColor),
      'unselectedChoiceChipColor':
          const ColorConverter().toJson(instance.unselectedChoiceChipColor),
      'unselectedChoiceChipTextColor':
          const ColorConverter().toJson(instance.unselectedChoiceChipTextColor),
      'secondaryTextColor':
          const ColorConverter().toJson(instance.secondaryTextColor),
      'chartTextColor': const ColorConverter().toJson(instance.chartTextColor),
      'textEditorBackground':
          const ColorConverter().toJson(instance.textEditorBackground),
      'keyboardAppearance': _$BrightnessEnumMap[instance.keyboardAppearance]!,
    };

const _$BrightnessEnumMap = {
  Brightness.dark: 'dark',
  Brightness.light: 'light',
};

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
      privateTagColor:
          const ColorConverter().fromJson(json['privateTagColor'] as String),
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
      activeAudioControl:
          const ColorConverter().fromJson(json['activeAudioControl'] as String),
      audioMeterBar:
          const ColorConverter().fromJson(json['audioMeterBar'] as String),
      audioMeterTooHotBar: const ColorConverter()
          .fromJson(json['audioMeterTooHotBar'] as String),
      audioMeterPeakedBar: const ColorConverter()
          .fromJson(json['audioMeterPeakedBar'] as String),
      private: const ColorConverter().fromJson(json['private'] as String),
      negspace: const ColorConverter().fromJson(json['negspace'] as String),
      primaryTextColor:
          const ColorConverter().fromJson(json['primaryTextColor'] as String),
      secondaryTextColor:
          const ColorConverter().fromJson(json['secondaryTextColor'] as String),
      primaryColor:
          const ColorConverter().fromJson(json['primaryColor'] as String),
      primaryColorLight:
          const ColorConverter().fromJson(json['primaryColorLight'] as String),
      hover: const ColorConverter().fromJson(json['hover'] as String),
      alarm: const ColorConverter().fromJson(json['alarm'] as String),
      cardColor: const ColorConverter().fromJson(json['cardColor'] as String),
      chartTextColor:
          const ColorConverter().fromJson(json['chartTextColor'] as String),
      textEditorBackground: const ColorConverter()
          .fromJson(json['textEditorBackground'] as String),
      navHomeIcon: json['navHomeIcon'] as String,
      navHomeIconActive: json['navHomeIconActive'] as String,
      navJournalIcon: json['navJournalIcon'] as String,
      navJournalIconActive: json['navJournalIconActive'] as String,
      navTasksIcon: json['navTasksIcon'] as String,
      navTasksIconActive: json['navTasksIconActive'] as String,
      navSettingsIcon: json['navSettingsIcon'] as String,
      navSettingsIconActive: json['navSettingsIconActive'] as String,
      micIcon: json['micIcon'] as String,
      micHotIcon: json['micHotIcon'] as String,
      micRecIcon: json['micRecIcon'] as String,
      keyboardAppearance:
          $enumDecode(_$BrightnessEnumMap, json['keyboardAppearance']),
    );

Map<String, dynamic> _$$_StyleConfigToJson(_$_StyleConfig instance) =>
    <String, dynamic>{
      'tagColor': const ColorConverter().toJson(instance.tagColor),
      'tagTextColor': const ColorConverter().toJson(instance.tagTextColor),
      'personTagColor': const ColorConverter().toJson(instance.personTagColor),
      'storyTagColor': const ColorConverter().toJson(instance.storyTagColor),
      'privateTagColor':
          const ColorConverter().toJson(instance.privateTagColor),
      'starredGold': const ColorConverter().toJson(instance.starredGold),
      'selectedChoiceChipColor':
          const ColorConverter().toJson(instance.selectedChoiceChipColor),
      'selectedChoiceChipTextColor':
          const ColorConverter().toJson(instance.selectedChoiceChipTextColor),
      'unselectedChoiceChipColor':
          const ColorConverter().toJson(instance.unselectedChoiceChipColor),
      'unselectedChoiceChipTextColor':
          const ColorConverter().toJson(instance.unselectedChoiceChipTextColor),
      'activeAudioControl':
          const ColorConverter().toJson(instance.activeAudioControl),
      'audioMeterBar': const ColorConverter().toJson(instance.audioMeterBar),
      'audioMeterTooHotBar':
          const ColorConverter().toJson(instance.audioMeterTooHotBar),
      'audioMeterPeakedBar':
          const ColorConverter().toJson(instance.audioMeterPeakedBar),
      'private': const ColorConverter().toJson(instance.private),
      'negspace': const ColorConverter().toJson(instance.negspace),
      'primaryTextColor':
          const ColorConverter().toJson(instance.primaryTextColor),
      'secondaryTextColor':
          const ColorConverter().toJson(instance.secondaryTextColor),
      'primaryColor': const ColorConverter().toJson(instance.primaryColor),
      'primaryColorLight':
          const ColorConverter().toJson(instance.primaryColorLight),
      'hover': const ColorConverter().toJson(instance.hover),
      'alarm': const ColorConverter().toJson(instance.alarm),
      'cardColor': const ColorConverter().toJson(instance.cardColor),
      'chartTextColor': const ColorConverter().toJson(instance.chartTextColor),
      'textEditorBackground':
          const ColorConverter().toJson(instance.textEditorBackground),
      'navHomeIcon': instance.navHomeIcon,
      'navHomeIconActive': instance.navHomeIconActive,
      'navJournalIcon': instance.navJournalIcon,
      'navJournalIconActive': instance.navJournalIconActive,
      'navTasksIcon': instance.navTasksIcon,
      'navTasksIconActive': instance.navTasksIconActive,
      'navSettingsIcon': instance.navSettingsIcon,
      'navSettingsIconActive': instance.navSettingsIconActive,
      'micIcon': instance.micIcon,
      'micHotIcon': instance.micHotIcon,
      'micRecIcon': instance.micRecIcon,
      'keyboardAppearance': _$BrightnessEnumMap[instance.keyboardAppearance]!,
    };

const _$BrightnessEnumMap = {
  Brightness.dark: 'dark',
  Brightness.light: 'light',
};

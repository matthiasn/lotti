import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/utils/color.dart';

part 'config.freezed.dart';
part 'config.g.dart';

@freezed
class ImapConfig with _$ImapConfig {
  factory ImapConfig({
    required String host,
    required String folder,
    required String userName,
    required String password,
    required int port,
  }) = _ImapConfig;

  factory ImapConfig.fromJson(Map<String, dynamic> json) =>
      _$ImapConfigFromJson(json);
}

@freezed
class SyncConfig with _$SyncConfig {
  factory SyncConfig({
    required ImapConfig imapConfig,
    required String sharedSecret,
  }) = _SyncConfig;

  factory SyncConfig.fromJson(Map<String, dynamic> json) =>
      _$SyncConfigFromJson(json);
}

@freezed
class StyleConfig with _$StyleConfig {
  factory StyleConfig({
    @ColorConverter() required Color tagColor,
    @ColorConverter() required Color tagTextColor,
    @ColorConverter() required Color personTagColor,
    @ColorConverter() required Color storyTagColor,
    @ColorConverter() required Color privateTagColor,
    @ColorConverter() required Color starredGold,
    @ColorConverter() required Color selectedChoiceChipColor,
    @ColorConverter() required Color selectedChoiceChipTextColor,
    @ColorConverter() required Color unselectedChoiceChipColor,
    @ColorConverter() required Color unselectedChoiceChipTextColor,
    @ColorConverter() required Color outboxSuccessColor,
    @ColorConverter() required Color outboxPendingColor,
    @ColorConverter() required Color activeAudioControl,
    @ColorConverter() required Color audioMeterBar,
    @ColorConverter() required Color audioMeterTooHotBar,
    @ColorConverter() required Color audioMeterPeakedBar,
    @ColorConverter() required Color private,
    @ColorConverter() required Color audioMeterBarBackground,
    // new colors
    @ColorConverter() required Color negspace,
    @ColorConverter() required Color primaryTextColor,
    @ColorConverter() required Color secondaryTextColor,
    @ColorConverter() required Color primaryColor,
    @ColorConverter() required Color primaryColorLight,
    @ColorConverter() required Color hover,
    @ColorConverter() required Color alarm,
    @ColorConverter() required Color cardColor,
    @ColorConverter() required Color chartTextColor,
    required String navHomeIcon,
    required String navHomeIconActive,
    required String navJournalIcon,
    required String navJournalIconActive,
    required String navTasksIcon,
    required String navTasksIconActive,
    required String navSettingsIcon,
    required String navSettingsIconActive,
    required String searchIcon,
    required String actionAddIcon,
    required String addIcon,
    required String backIcon,
    required String closeIcon,
    required String filterIcon,
    required String stopIcon,
    required String pauseIcon,
    required String micIcon,
    required String micHotIcon,
    required String micRecIcon,
    required String cardStarIcon,
    required String cardStarIconActive,
    required String cardFlagIcon,
    required String cardFlagIconActive,
    required String cardShieldIcon,
    required String cardShieldIconActive,
    required String cardEditorIcon,
    required String cardEditorIconActive,
    required String cardMapIcon,
    required String cardMapIconActive,
    required String cardTrashIcon,
    required String cardTagIcon,
  }) = _StyleConfig;

  factory StyleConfig.fromJson(Map<String, dynamic> json) =>
      _$StyleConfigFromJson(json);
}

class ColorConverter implements JsonConverter<Color, String> {
  const ColorConverter();

  @override
  Color fromJson(String hexColor) {
    return colorFromCssHex(hexColor);
  }

  @override
  String toJson(Color color) => colorToCssHex(color);
}

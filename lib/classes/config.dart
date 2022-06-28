import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/widgets/misc/color_utils.dart';

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
class ColorConfig with _$ColorConfig {
  factory ColorConfig({
    @ColorConverter() required Color entryBgColor,
    @ColorConverter() required Color actionColor,
    @ColorConverter() required Color tagColor,
    @ColorConverter() required Color tagTextColor,
    @ColorConverter() required Color personTagColor,
    @ColorConverter() required Color storyTagColor,
    @ColorConverter() required Color privateTagColor,
    @ColorConverter() required Color bottomNavIconUnselected,
    @ColorConverter() required Color bottomNavIconSelected,
    @ColorConverter() required Color editorTextColor,
    @ColorConverter() required Color starredGold,
    @ColorConverter() required Color editorBgColor,
    @ColorConverter() required Color baseColor,
    @ColorConverter() required Color bodyBgColor,
    @ColorConverter() required Color headerBgColor,
    @ColorConverter() required Color entryCardColor,
    @ColorConverter() required Color entryTextColor,
    @ColorConverter() required Color searchBgColor,
    @ColorConverter() required Color appBarFgColor,
    @ColorConverter() required Color codeBlockBackground,
    @ColorConverter() required Color unselectedChoiceChipColor,
    @ColorConverter() required Color unselectedChoiceChipTextColor,
    @ColorConverter() required Color timeRecording,
    @ColorConverter() required Color timeRecordingBg,
    @ColorConverter() required Color outboxSuccessColor,
    @ColorConverter() required Color outboxPendingColor,
    @ColorConverter() required Color outboxErrorColor,
    @ColorConverter() required Color headerFontColor,
    @ColorConverter() required Color activeAudioControl,
    @ColorConverter() required Color audioMeterBar,
    @ColorConverter() required Color audioMeterTooHotBar,
    @ColorConverter() required Color audioMeterPeakedBar,
    @ColorConverter() required Color error,
    @ColorConverter() required Color private,
    @ColorConverter() required Color audioMeterBarBackground,
    @ColorConverter() required Color inactiveAudioControl,
  }) = _ColorConfig;

  factory ColorConfig.fromJson(Map<String, dynamic> json) =>
      _$ColorConfigFromJson(json);
}

class ColorConverter implements JsonConverter<Color, String> {
  const ColorConverter();

  @override
  Color fromJson(String hexColor) {
    return HexColor.fromHex(hexColor);
  }

  @override
  String toJson(Color color) => color.toHex(color);
}

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
class ColorConfig with _$ColorConfig {
  factory ColorConfig({
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
    @ColorConverter() required Color timeRecording,
    @ColorConverter() required Color timeRecordingBg,
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
    @ColorConverter() required Color coal,
    @ColorConverter() required Color iron,
    @ColorConverter() required Color riptide,
    @ColorConverter() required Color riplight,
    @ColorConverter() required Color ripIce,
    @ColorConverter() required Color alarm,
    @ColorConverter() required Color ice,
  }) = _ColorConfig;

  factory ColorConfig.fromJson(Map<String, dynamic> json) =>
      _$ColorConfigFromJson(json);
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

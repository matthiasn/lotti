// ignore_for_file: equal_keys_in_map
import 'package:flutter/material.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/utils/color.dart';
import 'package:tinycolor2/tinycolor2.dart';

const defaultBaseColor = Color.fromRGBO(51, 77, 118, 1);
const brightBaseColor = Color.fromRGBO(244, 187, 41, 1);

final Color white = colorFromCssHex('#FFFFFF');
final Color coal = colorFromCssHex('#000000');
final Color iron = colorFromCssHex('#909090');
final Color primaryColor = colorFromCssHex('#82E6CE');

final MaterialColor primaryColorMaterial = MaterialColor(
  primaryColor.value,
  {
    50: primaryColor.withOpacity(.1),
    100: primaryColor.withOpacity(.2),
    200: primaryColor.withOpacity(.3),
    300: primaryColor.withOpacity(.4),
    400: primaryColor.withOpacity(.5),
    500: primaryColor.withOpacity(.6),
    600: primaryColor.withOpacity(.7),
    700: primaryColor.withOpacity(.8),
    800: primaryColor.withOpacity(.9),
    900: primaryColor.withOpacity(1),
  },
);

final Color primaryColorLight = colorFromCssHex('#CFF3EA');
final Color ripIce = colorFromCssHex('#EFFFFB');
final Color alarm = colorFromCssHex('#FF7373');
final Color ice = colorFromCssHex('#F5F5F5');
final Color nickel = colorFromCssHex('#B4B2B2');
final Color mineShaft = colorFromCssHex('#313131');

final darkTheme = StyleConfig(
  tagColor: const Color.fromRGBO(155, 200, 246, 1),
  tagTextColor: const Color.fromRGBO(51, 51, 51, 1),
  personTagColor: const Color.fromRGBO(55, 201, 154, 1),
  storyTagColor: const Color.fromRGBO(200, 120, 0, 1),
  privateTagColor: alarm,
  starredGold: const Color.fromRGBO(255, 215, 0, 1),
  activeAudioControl: alarm,
  audioMeterBar: Colors.blue,
  audioMeterTooHotBar: Colors.orange,
  audioMeterPeakedBar: alarm,
  private: alarm,
  audioMeterBarBackground:
      TinyColor.fromColor(defaultBaseColor).lighten(30).color,
  selectedChoiceChipColor: primaryColor,
  selectedChoiceChipTextColor: const Color.fromRGBO(33, 33, 33, 1),
  unselectedChoiceChipColor: colorFromCssHex('#BBBBBB'),
  unselectedChoiceChipTextColor: const Color.fromRGBO(255, 245, 240, 1),
  negspace: coal,
  primaryTextColor: white,
  secondaryTextColor: iron,
  primaryColor: primaryColor,
  primaryColorLight: primaryColorLight,
  hover: iron,
  alarm: alarm,
  cardColor: mineShaft,
  chartTextColor: nickel,
  navHomeIcon: 'assets/icons/nav_home_dark.svg',
  navHomeIconActive: 'assets/icons/nav_home_active.svg',
  navJournalIcon: 'assets/icons/nav_journal_dark.svg',
  navJournalIconActive: 'assets/icons/nav_journal_active.svg',
  navTasksIcon: 'assets/icons/nav_tasks_dark.svg',
  navTasksIconActive: 'assets/icons/nav_tasks_active.svg',
  navSettingsIcon: 'assets/icons/nav_settings_dark.svg',
  navSettingsIconActive: 'assets/icons/nav_settings_active.svg',
  micIcon: 'assets/icons/mic_dark.svg',
  micHotIcon: 'assets/icons/mic_hot_dark.svg',
  micRecIcon: 'assets/icons/mic_rec_dark.svg',
  keyboardAppearance: Brightness.dark,
  textEditorBackground: Colors.white.withOpacity(0.1),
);

final brightTheme = StyleConfig(
  tagColor: colorFromCssHex('#89BE2E'),
  tagTextColor: colorFromCssHex('#474B40'),
  personTagColor: const Color.fromRGBO(55, 201, 154, 1),
  storyTagColor: colorFromCssHex('#E27930'),
  privateTagColor: alarm,
  starredGold: const Color.fromRGBO(255, 215, 0, 1),
  activeAudioControl: colorFromCssHex('#CF322F'),
  audioMeterBar: Colors.blue,
  audioMeterTooHotBar: Colors.orange,
  audioMeterPeakedBar: alarm,
  private: alarm,
  audioMeterBarBackground:
      TinyColor.fromColor(defaultBaseColor).lighten(30).color,
  selectedChoiceChipColor: primaryColor,
  selectedChoiceChipTextColor: const Color.fromRGBO(33, 33, 33, 1),
  unselectedChoiceChipColor: colorFromCssHex('#BBBBBB'),
  unselectedChoiceChipTextColor: const Color.fromRGBO(255, 245, 240, 1),
  negspace: white,
  primaryTextColor: coal,
  secondaryTextColor: iron,
  primaryColor: primaryColor,
  primaryColorLight: primaryColorLight,
  hover: ripIce,
  alarm: alarm,
  cardColor: ice,
  chartTextColor: iron,
  navHomeIcon: 'assets/icons/nav_home.svg',
  navHomeIconActive: 'assets/icons/nav_home_active.svg',
  navJournalIcon: 'assets/icons/nav_journal.svg',
  navJournalIconActive: 'assets/icons/nav_journal_active.svg',
  navTasksIcon: 'assets/icons/nav_tasks.svg',
  navTasksIconActive: 'assets/icons/nav_tasks_active.svg',
  navSettingsIcon: 'assets/icons/nav_settings.svg',
  navSettingsIconActive: 'assets/icons/nav_settings_active.svg',
  micIcon: 'assets/icons/mic.svg',
  micHotIcon: 'assets/icons/mic_hot.svg',
  micRecIcon: 'assets/icons/mic_rec.svg',
  keyboardAppearance: Brightness.light,
  textEditorBackground: Colors.white,
);

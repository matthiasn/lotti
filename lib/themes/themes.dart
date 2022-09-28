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
final Color riptide = colorFromCssHex('#82E6CE');
final Color riplight = colorFromCssHex('#CFF3EA');
final Color ripIce = colorFromCssHex('#EFFFFB');
final Color alarm = colorFromCssHex('#FF7373');
final Color ice = colorFromCssHex('#F5F5F5');
final Color nickel = colorFromCssHex('#B4B2B2');

final darkTheme = StyleConfig(
  tagColor: const Color.fromRGBO(155, 200, 246, 1),
  tagTextColor: const Color.fromRGBO(51, 51, 51, 1),
  personTagColor: const Color.fromRGBO(55, 201, 154, 1),
  storyTagColor: const Color.fromRGBO(200, 120, 0, 1),
  privateTagColor: Colors.red,
  starredGold: const Color.fromRGBO(255, 215, 0, 1),
  timeRecording: const Color.fromRGBO(255, 22, 22, 1),
  timeRecordingBg: const Color.fromRGBO(255, 44, 44, 0.95),
  outboxSuccessColor: const Color.fromRGBO(50, 120, 50, 1),
  outboxPendingColor: const Color.fromRGBO(200, 120, 0, 1),
  activeAudioControl: Colors.red,
  audioMeterBar: Colors.blue,
  audioMeterTooHotBar: Colors.orange,
  audioMeterPeakedBar: Colors.red,
  private: Colors.red,
  audioMeterBarBackground:
      TinyColor.fromColor(defaultBaseColor).lighten(30).color,
  selectedChoiceChipColor: Colors.lightBlue,
  selectedChoiceChipTextColor: const Color.fromRGBO(200, 195, 190, 1),
  unselectedChoiceChipColor: colorFromCssHex('#BBBBBB'),
  unselectedChoiceChipTextColor: colorFromCssHex('#474b40'),
  negspace: coal,
  primaryTextColor: white,
  secondaryTextColor: iron,
  riptide: riptide,
  riplight: riplight,
  hover: iron,
  alarm: alarm,
  cardBg: colorFromCssHex('#313131'),
  chartTextColor: nickel,
  navHomeIcon: 'assets/icons/nav_home_dark.svg',
  navHomeIconActive: 'assets/icons/nav_home_active.svg',
  navJournalIcon: 'assets/icons/nav_journal_dark.svg',
  navJournalIconActive: 'assets/icons/nav_journal_active.svg',
  navTasksIcon: 'assets/icons/nav_tasks_dark.svg',
  navTasksIconActive: 'assets/icons/nav_tasks_active.svg',
  navSettingsIcon: 'assets/icons/nav_settings_dark.svg',
  navSettingsIconActive: 'assets/icons/nav_settings_active.svg',
  searchIcon: 'assets/icons/search_dark.svg',
  actionAddIcon: 'assets/icons/action_add_dark.svg',
  addIcon: 'assets/icons/add_dark.svg',
  backIcon: 'assets/icons/back_dark.svg',
  closeIcon: 'assets/icons/close_dark.svg',
  filterIcon: 'assets/icons/filter_dark.svg',
  stopIcon: 'assets/icons/stop_dark.svg',
  pauseIcon: 'assets/icons/pause_dark.svg',
  micIcon: 'assets/icons/mic_dark.svg',
  micHotIcon: 'assets/icons/mic_hot_dark.svg',
  micRecIcon: 'assets/icons/mic_rec_dark.svg',
);

final brightTheme = StyleConfig(
  tagColor: colorFromCssHex('#89BE2E'),
  tagTextColor: colorFromCssHex('#474B40'),
  personTagColor: const Color.fromRGBO(55, 201, 154, 1),
  storyTagColor: colorFromCssHex('#E27930'),
  privateTagColor: colorFromCssHex('#CF322F'),
  starredGold: const Color.fromRGBO(255, 215, 0, 1),
  timeRecording: colorFromCssHex('#CF322F'),
  timeRecordingBg: colorFromCssHex('#CF322FEE'),
  outboxSuccessColor: const Color.fromRGBO(50, 120, 50, 1),
  outboxPendingColor: const Color.fromRGBO(200, 120, 0, 1),
  activeAudioControl: colorFromCssHex('#CF322F'),
  audioMeterBar: Colors.blue,
  audioMeterTooHotBar: Colors.orange,
  audioMeterPeakedBar: colorFromCssHex('#CF322F'),
  private: colorFromCssHex('#CF322F'),
  audioMeterBarBackground:
      TinyColor.fromColor(defaultBaseColor).lighten(30).color,
  selectedChoiceChipColor: Colors.lightBlue,
  selectedChoiceChipTextColor: const Color.fromRGBO(200, 195, 190, 1),
  unselectedChoiceChipColor: colorFromCssHex('#BBBBBB'),
  unselectedChoiceChipTextColor: colorFromCssHex('#474b40'),
  negspace: white,
  primaryTextColor: coal,
  secondaryTextColor: iron,
  riptide: riptide,
  riplight: riplight,
  hover: ripIce,
  alarm: alarm,
  cardBg: ice,
  chartTextColor: iron,
  navHomeIcon: 'assets/icons/nav_home.svg',
  navHomeIconActive: 'assets/icons/nav_home_active.svg',
  navJournalIcon: 'assets/icons/nav_journal.svg',
  navJournalIconActive: 'assets/icons/nav_journal_active.svg',
  navTasksIcon: 'assets/icons/nav_tasks.svg',
  navTasksIconActive: 'assets/icons/nav_tasks_active.svg',
  navSettingsIcon: 'assets/icons/nav_settings.svg',
  navSettingsIconActive: 'assets/icons/nav_settings_active.svg',
  searchIcon: 'assets/icons/search.svg',
  actionAddIcon: 'assets/icons/action_add.svg',
  addIcon: 'assets/icons/add.svg',
  backIcon: 'assets/icons/back.svg',
  closeIcon: 'assets/icons/close.svg',
  filterIcon: 'assets/icons/filter.svg',
  stopIcon: 'assets/icons/stop.svg',
  pauseIcon: 'assets/icons/pause.svg',
  micIcon: 'assets/icons/mic.svg',
  micHotIcon: 'assets/icons/mic_hot.svg',
  micRecIcon: 'assets/icons/mic_rec.svg',
);

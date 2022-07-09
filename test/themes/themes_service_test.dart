import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/consts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemesService test -', () {
    setUpAll(() {
      final db = JournalDb(inMemoryDatabase: true);

      getIt.registerSingleton<JournalDb>(db);

      db.insertFlagIfNotExists(
        ConfigFlag(
          name: showBrightSchemeFlag,
          description: 'Show Bright ☀️ scheme?',
          status: false,
        ),
      );
    });
    tearDownAll(() async {
      await getIt.reset();
    });

    test('updated color by key appears in stream after theme toggle', () async {
      final themesService = ThemesService();

      expect(
        await themesService.watchColorByKey('bodyBgColor').first,
        darkTheme.bodyBgColor,
      );

      await getIt<JournalDb>().toggleConfigFlag(showBrightSchemeFlag);

      expect(
        await themesService.watchColorByKey('bodyBgColor').first,
        brightTheme.bodyBgColor,
      );
    });

    test('updated color config appears in stream after setting theme',
        () async {
      final themesService = ThemesService();

      await getIt<JournalDb>()
          .setConfigFlag(showBrightSchemeFlag, value: false);

      expect(
        await themesService.getColorConfigStream().first,
        darkTheme,
      );

      await getIt<JournalDb>().toggleConfigFlag(showBrightSchemeFlag);

      expect(
        await themesService.getColorConfigStream().first,
        brightTheme,
      );
    });

    test('color is updated after setting theme', () async {
      final themesService = ThemesService();

      await getIt<JournalDb>()
          .setConfigFlag(showBrightSchemeFlag, value: false);

      expect(
        await themesService.getColorConfigStream().first,
        darkTheme,
      );

      expect(
        themesService.current.bodyBgColor,
        darkTheme.bodyBgColor,
      );

      themesService.setTheme(brightTheme);

      expect(
        themesService.current.bodyBgColor,
        brightTheme.bodyBgColor,
      );
    });

    test('color is updated with setColor', () async {
      final themesService = ThemesService();

      await getIt<JournalDb>()
          .setConfigFlag(showBrightSchemeFlag, value: false);

      await getIt<JournalDb>().toggleConfigFlag(showBrightSchemeFlag);
      await getIt<JournalDb>().toggleConfigFlag(showBrightSchemeFlag);

      expect(
        await themesService.watchColorByKey('bodyBgColor').first,
        darkTheme.bodyBgColor,
      );

      expect(
        themesService.current.bodyBgColor,
        darkTheme.bodyBgColor,
      );

      final testColor = colorFromCssHex('#FF0000');
      themesService.setColor('bodyBgColor', testColor);

      expect(
        themesService.current.bodyBgColor,
        testColor,
      );

      expect(
        await themesService.watchColorByKey('bodyBgColor').first,
        testColor,
      );
    });

    test('latest update DateTime is published on stream after setting theme',
        () async {
      final start = DateTime.now();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      final themesService = ThemesService();

      await getIt<JournalDb>()
          .setConfigFlag(showBrightSchemeFlag, value: false);

      await getIt<JournalDb>().toggleConfigFlag(showBrightSchemeFlag);

      expect(
        (await themesService.getLastUpdateStream().first)
            .millisecondsSinceEpoch,
        greaterThan(start.millisecondsSinceEpoch),
      );

      await getIt<JournalDb>().toggleConfigFlag(showBrightSchemeFlag);

      expect(
        (await themesService.getLastUpdateStream().first)
            .millisecondsSinceEpoch,
        greaterThan(start.millisecondsSinceEpoch),
      );
    });

    test('sorted color names are returned', () async {
      final themesService = ThemesService();

      expect(themesService.colorNames(), [
        'actionColor',
        'activeAudioControl',
        'appBarFgColor',
        'audioMeterBar',
        'audioMeterBarBackground',
        'audioMeterPeakedBar',
        'audioMeterTooHotBar',
        'baseColor',
        'bodyBgColor',
        'bottomNavBackground',
        'bottomNavIconSelected',
        'bottomNavIconUnselected',
        'codeBlockBackground',
        'editorBgColor',
        'editorTextColor',
        'entryBgColor',
        'entryCardColor',
        'entryTextColor',
        'error',
        'headerBgColor',
        'headerFontColor',
        'inactiveAudioControl',
        'outboxErrorColor',
        'outboxPendingColor',
        'outboxSuccessColor',
        'personTagColor',
        'private',
        'privateTagColor',
        'searchBgColor',
        'selectedChoiceChipColor',
        'selectedChoiceChipTextColor',
        'starredGold',
        'storyTagColor',
        'tagColor',
        'tagTextColor',
        'timeRecording',
        'timeRecordingBg',
        'unselectedChoiceChipColor',
        'unselectedChoiceChipTextColor',
      ]);
    });
  });
}

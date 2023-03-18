import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/themes/utils.dart';
import 'package:lotti/utils/consts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now();

  group('Theme Utils test -', () {
    setUpAll(() {
      final db = JournalDb(inMemoryDatabase: true);

      getIt
        ..registerSingleton<JournalDb>(db)
        ..registerSingleton(
          ThemesService(
            debounceSeconds: 0,
            saveThemeAsJson: false,
          ),
        );

      db.insertFlagIfNotExists(
        const ConfigFlag(
          name: showBrightSchemeFlag,
          description: 'Show Bright ☀️ scheme?',
          status: false,
        ),
      );
    });
    tearDownAll(() async {
      await getIt.reset();
    });

    test('getTagColor returns expected generic tag colors', () async {
      final testTag = GenericTag(
        vectorClock: null,
        updatedAt: now,
        createdAt: now,
        tag: '',
        id: '',
        private: false,
      );

      expect(
        getTagColor(testTag),
        getIt<ThemesService>().current.tagColor,
      );

      expect(
        getTagColor(testTag.copyWith(private: true)),
        getIt<ThemesService>().current.privateTagColor,
      );
    });

    test('getTagColor returns expected person tag colors', () async {
      final testTag = PersonTag(
        vectorClock: null,
        updatedAt: now,
        createdAt: now,
        tag: '',
        id: '',
        private: false,
      );

      expect(
        getTagColor(testTag),
        getIt<ThemesService>().current.personTagColor,
      );

      expect(
        getTagColor(testTag.copyWith(private: true)),
        getIt<ThemesService>().current.privateTagColor,
      );
    });

    test('getTagColor returns expected story tag colors', () async {
      final testTag = StoryTag(
        vectorClock: null,
        updatedAt: now,
        createdAt: now,
        tag: '',
        id: '',
        private: false,
      );

      expect(
        getTagColor(testTag),
        getIt<ThemesService>().current.storyTagColor,
      );

      expect(
        getTagColor(testTag.copyWith(private: true)),
        getIt<ThemesService>().current.privateTagColor,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/colors.dart';
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
          ThemesService(),
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
        tagColor,
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
        personTagColor,
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
        storyTagColor,
      );
    });
  });
}

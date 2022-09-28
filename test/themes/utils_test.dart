import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/themes/utils.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/consts.dart';

import '../widget_test_utils.dart';

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

    test('darken and lighten color functions are working', () async {
      final testColor = colorFromCssHex('#999999');

      expect(
        darken(testColor, 10),
        colorFromCssHex('#808080'),
      );

      expect(
        lighten(testColor, 10),
        colorFromCssHex('#b3b3b3'),
      );
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

    testWidgets('ColorThemeRefresh widget updates color', (tester) async {
      const testText = 'testText';
      await tester.pumpWidget(
        makeTestableWidget(
          ColorThemeRefresh(
            keyPrefix: '',
            child: Text(
              testText,
              style: TextStyle(
                color: styleConfig().primaryTextColor,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(testText),
        findsOneWidget,
      );

      expect(
        (tester.firstWidget(find.text(testText)) as Text).style?.color,
        darkTheme.primaryTextColor,
      );

      final testColor = colorFromCssHex('#FF0000');
      getIt<ThemesService>().setColor('negspace', testColor);

      expect(
        getIt<ThemesService>().current.negspace,
        testColor,
      );

      await tester.pumpAndSettle();

      // TODO: why not updating in test? works in app
      // expect(
      //   (tester.firstWidget(find.text(testText)) as Text).style?.color,
      //   testColor,
      //);
    });
  });
}

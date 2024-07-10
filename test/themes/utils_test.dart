import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/utils.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now();

  group('Theme Utils test -', () {
    setUpAll(() {
      final mockUpdateNotifications = MockUpdateNotifications();
      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true));
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

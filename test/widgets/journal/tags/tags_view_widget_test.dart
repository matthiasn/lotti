import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/tags/tags_view_widget.dart';
import 'package:mocktail/mocktail.dart';

import '../../../journal_test_data/test_data.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TagsViewWidget Tests -', () {
    final mockTagsService = MockTagsService();

    when(mockTagsService.watchTags).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([
        [
          testTag1,
          testStoryTagReading,
          testPersonTag1,
        ]
      ]),
    );

    when(() => mockTagsService.getTagById(testTag1.id)).thenAnswer(
      (_) => testTag1,
    );

    when(() => mockTagsService.getTagById(testPersonTag1.id)).thenAnswer(
      (_) => testPersonTag1,
    );

    when(() => mockTagsService.getTagById(testStoryTagReading.id)).thenAnswer(
      (_) => testStoryTagReading,
    );

    setUpAll(() {
      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<TagsService>(mockTagsService);
    });

    testWidgets('Tags are displayed', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TagsViewWidget(
            item: testTextEntry.copyWith(
              meta: testTextEntry.meta.copyWith(
                tagIds: [
                  testTag1.id,
                  testStoryTagReading.id,
                  testPersonTag1.id,
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // displays expected tag texts
      expect(find.text(testTag1.tag), findsOneWidget);
      expect(find.text(testPersonTag1.tag), findsOneWidget);
      expect(find.text(testStoryTagReading.tag), findsOneWidget);

      await tester.pump();
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_view_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TagsViewWidget Tests -', () {
    final mockTagsService = MockTagsService();

    when(mockTagsService.watchTags).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([
        [
          testTag1,
          testStoryTag1,
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

    when(() => mockTagsService.getTagById(testStoryTag1.id)).thenAnswer(
      (_) => testStoryTag1,
    );

    setUpAll(() {
      getIt.registerSingleton<TagsService>(mockTagsService);
    });

    testWidgets('Tags are displayed', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TagsViewWidget(
            item: testTextEntry.copyWith(
              meta: testTextEntry.meta.copyWith(
                tagIds: [
                  testTag1.id,
                  testStoryTag1.id,
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
      expect(find.text(testStoryTag1.tag), findsOneWidget);

      await tester.pump();
    });
  });
}

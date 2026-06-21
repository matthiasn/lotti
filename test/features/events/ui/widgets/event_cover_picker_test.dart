import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_image.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_picker.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  group('EventCoverPicker', () {
    List<EventCoverChoice> choices() => [
      EventCoverChoice(id: 'a', image: testImage()),
      EventCoverChoice(id: 'b', image: testImage()),
    ];

    testWidgets('renders a cover tile per choice plus an add-photo tile', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventCoverPicker(
          choices: choices(),
          onSelect: (_) {},
          onAddPhoto: () {},
        ),
        height: 240,
      );

      expect(find.byType(EventCoverImage), findsNWidgets(2));
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
    });

    testWidgets('selecting a tile reports its id', (tester) async {
      final selected = <String>[];
      await pumpEventComponent(
        tester,
        EventCoverPicker(
          choices: choices(),
          onSelect: selected.add,
          onAddPhoto: () {},
        ),
        height: 240,
      );

      await tester.tap(find.byType(EventCoverImage).last);
      expect(selected, ['b']);
    });

    testWidgets('tapping the add tile invokes onAddPhoto', (tester) async {
      var added = 0;
      await pumpEventComponent(
        tester,
        EventCoverPicker(
          choices: choices(),
          onSelect: (_) {},
          onAddPhoto: () => added++,
        ),
        height: 240,
      );

      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      expect(added, 1);
    });

    testWidgets('omits the add tile when onAddPhoto is null', (tester) async {
      await pumpEventComponent(
        tester,
        EventCoverPicker(choices: choices(), onSelect: (_) {}),
        height: 240,
      );

      expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
    });

    testWidgets('rings the current cover with a thicker border', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventCoverPicker(
          choices: choices(),
          currentCoverId: 'a',
          onSelect: (_) {},
          onAddPhoto: () {},
        ),
        height: 240,
      );

      // The selected tile carries a 3px ring; the unselected one a hairline.
      final borderWidths = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.border)
          .whereType<Border>()
          .map((b) => b.top.width)
          .toList();
      expect(borderWidths, containsAll(<double>[3, 1]));
    });

    group('showEventCoverPicker', () {
      Future<void> open(
        WidgetTester tester, {
        required ValueChanged<String> onSelect,
        required VoidCallback onAddPhoto,
      }) async {
        await tester.pumpWidget(
          makeTestableWidget2(
            Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showEventCoverPicker(
                    context: context,
                    choices: choices(),
                    onSelect: onSelect,
                    onAddPhoto: onAddPhoto,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      testWidgets('selecting a tile reports the id and dismisses the sheet', (
        tester,
      ) async {
        final selected = <String>[];
        await open(tester, onSelect: selected.add, onAddPhoto: () {});
        expect(find.byType(EventCoverPicker), findsOneWidget);

        await tester.tap(find.byType(EventCoverImage).first);
        await tester.pumpAndSettle();

        expect(selected, ['a']);
        expect(find.byType(EventCoverPicker), findsNothing);
      });

      testWidgets('tapping add invokes onAddPhoto and dismisses the sheet', (
        tester,
      ) async {
        var added = 0;
        await open(tester, onSelect: (_) {}, onAddPhoto: () => added++);

        await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
        await tester.pumpAndSettle();

        expect(added, 1);
        expect(find.byType(EventCoverPicker), findsNothing);
      });
    });
  });
}

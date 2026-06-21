import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_image.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_picker.dart';

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
  });
}

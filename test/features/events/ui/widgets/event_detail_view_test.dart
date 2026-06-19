import 'package:flutter/material.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/events/ui/widgets/event_detail_view.dart';

import '../../test_utils.dart';

const _tallMobile = Size(390, 1640);
const _tallDesktop = Size(1280, 1480);

void main() {
  group('EventDetailView', () {
    testWidgets('renders hero identity: title, category, date, rating', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallMobile,
      );

      expect(find.text("Anna's 30th Birthday"), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.textContaining('Rooftop Bar'), findsWidgets);
      expect(find.byType(StarRating), findsOneWidget); // stars > 0
    });

    testWidgets('shows a status pill only for non-completed events', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(
            card: buildEventCardData(
              status: EventStatus.ongoing,
              coverImage: testImage(),
            ),
          ),
        ),
        size: _tallMobile,
      );
      expect(find.text('Ongoing'), findsOneWidget);
    });

    testWidgets('renders the meta line and AI summary card', (tester) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallMobile,
      );
      expect(find.text('19:30 – 02:00 · 18 friends'), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
      expect(
        find.text('A surprise 30th for Anna on the rooftop.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.refresh), findsOneWidget); // regenerate
    });

    testWidgets('renders all three timeline entry kinds', (tester) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallMobile,
      );

      expect(find.text('Timeline'), findsOneWidget);
      // photo entry: italic authored caption
      final caption = tester.widget<Text>(find.text('The reveal moment.'));
      expect(caption.style?.fontStyle, FontStyle.italic);
      // note entry
      expect(find.text("Anna's speech."), findsOneWidget);
      // audio entry
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      expect(find.text('Voice note · 0:42'), findsOneWidget);
      expect(find.text('Toast from Dad'), findsOneWidget);
      // each timeline row has an "open" chevron
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
    });

    testWidgets('renders tasks with done/undone states and due labels', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallMobile,
      );
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Book the venue'), findsOneWidget);
      expect(find.text('Share the album'), findsOneWidget);
      expect(find.text('Due Fri'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // done
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget); // not
    });

    testWidgets('renders tasks in both one- and two-column layouts', (
      tester,
    ) async {
      // Narrow → one column.
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallMobile,
      );
      expect(find.text('Book the venue'), findsOneWidget);

      // Wide → two-column body with a tasks rail.
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallDesktop,
      );
      expect(find.text('Book the venue'), findsOneWidget);
    });

    testWidgets('wires hero, summary and section add callbacks', (
      tester,
    ) async {
      var back = false;
      var edit = false;
      var regen = false;
      var addTimeline = false;
      var addTask = false;

      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(),
          onBack: () => back = true,
          onEdit: () => edit = true,
          onRegenerateSummary: () => regen = true,
          onAddToTimeline: () => addTimeline = true,
          onAddTask: () => addTask = true,
        ),
        size: _tallMobile,
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.tap(find.byIcon(Icons.refresh));
      // Two "Add" actions: first = Timeline, last = Tasks.
      await tester.tap(find.text('Add').first);
      await tester.tap(find.text('Add').last);

      expect(back, isTrue);
      expect(edit, isTrue);
      expect(regen, isTrue);
      expect(addTimeline, isTrue);
      expect(addTask, isTrue);
    });

    testWidgets('hides summary when none is provided', (tester) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData(summary: null)),
        size: _tallMobile,
      );
      expect(find.text('Summary'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
    });
  });
}

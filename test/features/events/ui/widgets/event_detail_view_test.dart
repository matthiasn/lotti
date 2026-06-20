import 'package:flutter/material.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_detail_view.dart';

import '../../test_utils.dart';

const _tallMobile = Size(390, 1640);
const _tallDesktop = Size(1280, 1480);

/// An empty (just-created) event: status only, no cover, summary, timeline or
/// tasks — the case that must still offer affordances rather than a blank void.
EventDetailData _emptyData() => EventDetailData(
  card: buildEventCardData(
    title: 'Test Event',
    status: EventStatus.tentative,
    stars: 0,
    categoryName: null,
    summary: null,
    location: null,
  ),
  whenLabel: 'Sat, 20 Jun 2026 · 18:22',
);

void main() {
  group('EventDetailView', () {
    testWidgets('renders hero identity: title, category, status, rating', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallMobile,
      );

      expect(find.text("Anna's 30th Birthday"), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      // Status is always shown now (it's editable); default is completed.
      expect(find.text('Completed'), findsOneWidget);
      // The hero carries the single date/time line (from whenLabel).
      expect(find.text('19:30 – 02:00 · 18 friends'), findsOneWidget);
      // A completed event shows its rating.
      expect(find.byType(StarRating), findsOneWidget);
    });

    testWidgets('hides the rating on a fresh, not-yet-happened event', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: _emptyData()),
        size: _tallMobile,
      );
      // A tentative event with no rating yet shows no stars.
      expect(find.byType(StarRating), findsNothing);
    });

    testWidgets('tapping the date opens the date-time picker', (tester) async {
      var dateTaps = 0;
      await pumpEventScreen(
        tester,
        EventDetailView(data: _emptyData(), onTapDateTime: () => dateTaps++),
        size: _tallMobile,
      );
      await tester.tap(find.text('Sat, 20 Jun 2026 · 18:22'));
      expect(dateTaps, 1);
    });

    testWidgets('capitalizes the status label for any status', (tester) async {
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
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('renders all three timeline entry kinds', (tester) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallMobile,
      );

      expect(find.text('Timeline'), findsOneWidget);
      final caption = tester.widget<Text>(find.text('The reveal moment.'));
      expect(caption.style?.fontStyle, FontStyle.italic);
      expect(find.text("Anna's speech."), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      expect(find.text('Voice note · 0:42'), findsOneWidget);
      expect(find.text('Toast from Dad'), findsOneWidget);
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
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('renders a task status label in its status colour', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(
            tasks: const [
              EventTaskRef(
                title: 'Confirm caterer',
                done: false,
                statusLabel: 'IN PROGRESS',
                statusColor: Color(0xFF22C55E),
              ),
            ],
          ),
        ),
        size: _tallMobile,
      );

      expect(find.text('Confirm caterer'), findsOneWidget);
      final statusText = tester.widget<Text>(find.text('IN PROGRESS'));
      expect(statusText.style?.color, const Color(0xFF22C55E));
    });

    testWidgets('renders tasks in both one- and two-column layouts', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallMobile,
      );
      expect(find.text('Book the venue'), findsOneWidget);

      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallDesktop,
      );
      expect(find.text('Book the venue'), findsOneWidget);
    });

    testWidgets('an empty event shows section scaffolding with add hints', (
      tester,
    ) async {
      final timelineAdds = <int>[];
      final taskAdds = <int>[];
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: _emptyData(),
          onAddToTimeline: () => timelineAdds.add(1),
          onAddTask: () => taskAdds.add(1),
        ),
        size: _tallMobile,
      );

      // Both sections render even with nothing in them, with tappable hints.
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Add photos, notes or a voice memo'), findsOneWidget);
      expect(find.text('Link a prep or follow-up task'), findsOneWidget);

      await tester.tap(find.text('Add photos, notes or a voice memo'));
      await tester.tap(find.text('Link a prep or follow-up task'));
      expect(timelineAdds, [1]);
      expect(taskAdds, [1]);
    });

    testWidgets('offers an add-cover affordance only when there is no cover', (
      tester,
    ) async {
      var coverAdds = 0;
      await pumpEventScreen(
        tester,
        EventDetailView(data: _emptyData(), onAddCover: () => coverAdds++),
        size: _tallMobile,
      );
      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      expect(coverAdds, 1);

      // With a cover present, the add-cover affordance is gone.
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData(), onAddCover: () {}),
        size: _tallMobile,
      );
      expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
    });

    testWidgets('tapping the category and status pills opens their pickers', (
      tester,
    ) async {
      var categoryTaps = 0;
      var statusTaps = 0;
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(),
          onTapCategory: () => categoryTaps++,
          onTapStatus: () => statusTaps++,
        ),
        size: _tallMobile,
      );

      await tester.tap(find.text('Friends'));
      await tester.tap(find.text('Completed'));
      expect(categoryTaps, 1);
      expect(statusTaps, 1);
    });

    testWidgets('tapping the title swaps in a field that commits a rename', (
      tester,
    ) async {
      final renames = <String>[];
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(),
          onRenameTitle: renames.add,
        ),
        size: _tallMobile,
      );

      await tester.tap(find.text("Anna's 30th Birthday"));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Anna turns 30');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(renames, ['Anna turns 30']);
    });

    testWidgets('setting a star rating reports the new value', (tester) async {
      final ratings = <double>[];
      await pumpEventScreen(
        tester,
        // A completed event surfaces the (interactive) rating.
        EventDetailView(data: buildEventDetailData(), onSetRating: ratings.add),
        size: _tallMobile,
      );

      await tester.tap(find.byType(StarRating));
      expect(ratings, isNotEmpty);
    });

    testWidgets('the overflow menu deletes the event', (tester) async {
      var deletes = 0;
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(),
          onDelete: () => deletes++,
        ),
        size: _tallMobile,
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete event'));
      await tester.pumpAndSettle();

      expect(deletes, 1);
    });

    testWidgets('wires back, regenerate and section add callbacks', (
      tester,
    ) async {
      var back = false;
      var regen = false;
      var addTimeline = false;
      var addTask = false;

      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(),
          onBack: () => back = true,
          onRegenerateSummary: () => regen = true,
          onAddToTimeline: () => addTimeline = true,
          onAddTask: () => addTask = true,
        ),
        size: _tallMobile,
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.tap(find.text('Add').first);
      await tester.tap(find.text('Add').last);

      expect(back, isTrue);
      expect(regen, isTrue);
      expect(addTimeline, isTrue);
      expect(addTask, isTrue);
    });

    testWidgets('shows no row chevron when timeline rows are not openable', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallMobile,
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('tapping a timeline row opens its source entry', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(),
          onOpenTimelineEntry: opened.add,
        ),
        size: _tallMobile,
      );

      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
      await tester.tap(find.text("Anna's speech."));
      await tester.pump();

      expect(opened, ['note-1']);
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

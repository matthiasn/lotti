import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/timeline/design_system_timeline_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_detail_view.dart';
import 'package:lotti/features/events/ui/widgets/event_passive_summary_card.dart';
import 'package:lotti/features/events/ui/widgets/event_people_row.dart';
import 'package:lotti/features/events/ui/widgets/event_photo_gallery.dart';
import 'package:lotti/features/events/ui/widgets/event_star_rating.dart';
import 'package:lotti/features/events/ui/widgets/event_timeline.dart';
import 'package:lotti/features/journal/ui/widgets/time_span_bar.dart';
import 'package:material_ui/material_ui.dart';

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
      expect(find.byType(EventStarRating), findsOneWidget);
    });

    testWidgets('the rating shares one row with the category and status '
        'pills, not a row of its own under the date', (tester) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallDesktop,
      );

      final stars = tester.getRect(find.byType(EventStarRating));
      final status = tester.getRect(find.text('Completed'));
      final category = tester.getRect(find.text('Friends'));
      final date = tester.getRect(find.text('19:30 – 02:00 · 18 friends'));

      // Same row: the stars' vertical band overlaps the pills' centre line,
      // and they sit to the right of the status pill.
      expect(stars.top, lessThan(status.center.dy));
      expect(stars.bottom, greaterThan(status.center.dy));
      expect(stars.left, greaterThan(status.right));
      expect(status.left, greaterThan(category.right));
      // …and that row is above the title and date, not below the date line
      // as the stars used to be.
      expect(stars.bottom, lessThan(date.top));
      // Left-aligned with the hero content rather than centred on it.
      expect(stars.left - status.right, lessThan(category.width));
    });

    testWidgets('the recap one-liner reads under the title', (tester) async {
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(),
          recapOneLiner: 'Rooftop surprise, cake at midnight.',
        ),
        size: _tallMobile,
      );

      final oneLiner = find.text('Rooftop surprise, cake at midnight.');
      expect(oneLiner, findsOneWidget);
      final title = tester.getRect(find.text("Anna's 30th Birthday"));
      final line = tester.getRect(oneLiner);
      final date = tester.getRect(find.text('19:30 – 02:00 · 18 friends'));
      expect(line.top, greaterThanOrEqualTo(title.bottom));
      expect(line.bottom, lessThanOrEqualTo(date.top));
    });

    testWidgets('a blank recap one-liner renders exactly like none', (
      tester,
    ) async {
      List<String?> heroTexts() => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(FlexibleSpaceBar),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data)
          .toList();

      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallMobile,
      );
      final withoutRecap = heroTexts();

      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData(), recapOneLiner: '  \n '),
        size: _tallMobile,
      );

      expect(heroTexts(), withoutRecap);
    });

    group('people', () {
      const people = [
        EventPerson(id: 'pip', name: 'Pip Penguin'),
        EventPerson(id: 'rocko', name: 'Rocko'),
      ];

      testWidgets('who it was with sits between the summary and the timeline', (
        tester,
      ) async {
        await pumpEventScreen(
          tester,
          EventDetailView(
            data: buildEventDetailData(),
            people: people,
            onEditPeople: () {},
          ),
          size: _tallMobile,
        );

        expect(find.text('People'), findsOneWidget);
        expect(find.byType(EventPeopleRow), findsOneWidget);
        final header = tester.getRect(find.text('People'));
        final summary = tester.getRect(
          find.text('A surprise 30th for Anna on the rooftop.'),
        );
        final timeline = tester.getRect(find.text('Timeline'));
        expect(header.top, greaterThan(summary.bottom));
        expect(header.bottom, lessThan(timeline.top));
        expect(
          tester.widget<EventPeopleRow>(find.byType(EventPeopleRow)).people,
          people,
        );
      });

      testWidgets('with no one linked only the Add people chip shows', (
        tester,
      ) async {
        await pumpEventScreen(
          tester,
          EventDetailView(data: buildEventDetailData(), onEditPeople: () {}),
          size: _tallMobile,
        );

        expect(find.text('People'), findsNothing);
        expect(find.text('Add people'), findsOneWidget);
      });

      testWidgets('read-only with no one linked shows nothing of it', (
        tester,
      ) async {
        await pumpEventScreen(
          tester,
          EventDetailView(data: buildEventDetailData()),
          size: _tallMobile,
        );

        expect(find.byType(EventPeopleRow), findsNothing);
        expect(find.text('Add people'), findsNothing);
      });

      testWidgets('a person chip opens that person', (tester) async {
        final opened = <String>[];
        await pumpEventScreen(
          tester,
          EventDetailView(
            data: buildEventDetailData(),
            people: people,
            onOpenPerson: opened.add,
          ),
          size: _tallMobile,
        );

        await tester.tap(find.text('Rocko'));

        expect(opened, ['rocko']);
      });
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
      expect(find.byType(EventStarRating), findsNothing);
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

    testWidgets('renders the meta line and the passive summary', (
      tester,
    ) async {
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
      expect(find.byIcon(LottiIcons.playCircled), findsOneWidget);
      expect(find.text('Voice note · 0:42'), findsOneWidget);
      expect(find.text('Toast from Dad'), findsOneWidget);
    });

    testWidgets('renders a time-recording beat as a span with its duration', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(
            timeline: const [
              EventTimelineEntry(
                timeLabel: '13:00',
                kind: EventTimelineKind.timeRecording,
                entryId: 'tr-1',
                endTimeLabel: '15:30',
                durationLabel: '2h 30m',
                text: 'Wandered the festival.',
              ),
            ],
          ),
        ),
        size: _tallMobile,
      );

      expect(find.byType(TimeSpanBar), findsOneWidget);
      expect(find.text('2h 30m'), findsOneWidget);
      expect(find.text('15:30'), findsOneWidget);
      expect(find.text('Wandered the festival.'), findsOneWidget);
    });

    testWidgets(
      'a time-recording beat without span labels falls back to text',
      (
        tester,
      ) async {
        await pumpEventScreen(
          tester,
          EventDetailView(
            data: buildEventDetailData(
              timeline: const [
                EventTimelineEntry(
                  timeLabel: '13:00',
                  kind: EventTimelineKind.timeRecording,
                  entryId: 'tr-x',
                  text: 'A note with no span labels.',
                  // endTimeLabel / durationLabel intentionally omitted.
                ),
              ],
            ),
          ),
          size: _tallMobile,
        );

        expect(find.text('A note with no span labels.'), findsOneWidget);
        expect(find.byType(TimeSpanBar), findsNothing);
      },
    );

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
      expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
      expect(find.byIcon(LottiIcons.radioUnselected), findsOneWidget);
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

    testWidgets('renders a Photos gallery section when photos are present', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(
            photos: [EventPhoto(testImage()), EventPhoto(testImage())],
          ),
        ),
        size: _tallMobile,
      );
      expect(find.text('Photos'), findsOneWidget);
      expect(find.byType(EventPhotoGrid), findsOneWidget);
    });

    testWidgets('omits the Photos section when there are no photos', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallMobile,
      );
      expect(find.text('Photos'), findsNothing);
      expect(find.byType(EventPhotoGrid), findsNothing);
    });

    testWidgets(
      'an empty event keeps the Timeline header over a quiet hint and shows '
      'no Tasks section',
      (tester) async {
        await pumpEventScreen(
          tester,
          EventDetailView(data: _emptyData()),
          size: _tallMobile,
        );

        expect(find.text('Timeline'), findsOneWidget);
        final hint = find.text('Add photos, notes or a voice memo');
        expect(hint, findsOneWidget);
        // The hint points at the bottom bar; it is not an add button itself.
        expect(
          find.ancestor(of: hint, matching: find.byType(InkWell)),
          findsNothing,
        );
        expect(find.byIcon(LottiIcons.add), findsNothing);
        // The hint spans the column like the cards above it, not a pill
        // hugging its sentence.
        final hintRect = tester.getRect(
          find.ancestor(of: hint, matching: find.byType(Material)).first,
        );
        final viewRect = tester.getRect(find.byType(EventDetailView));
        final inset = tester.element(hint).designTokens.spacing.step4;
        expect(hintRect.left, viewRect.left + inset);
        expect(hintRect.right, viewRect.right - inset);
        // Nothing to list, nothing to invite: the section waits for the
        // first task, which the bar adds.
        expect(find.text('Tasks'), findsNothing);
        expect(find.text('Link a prep or follow-up task'), findsNothing);
      },
    );

    testWidgets('no section carries an add button of its own', (tester) async {
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(photos: [EventPhoto(testImage())]),
        ),
        size: _tallMobile,
      );

      // Photos, Timeline and Tasks all render — none with an "Add".
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Add'), findsNothing);
    });

    testWidgets(
      'a wide body splits into a tasks rail only once there are tasks',
      (tester) async {
        await pumpEventScreen(
          tester,
          EventDetailView(data: buildEventDetailData()),
          size: _tallDesktop,
        );
        final tokens = tester
            .element(find.byType(EventDetailView))
            .designTokens;
        // The 1080 content cap minus the body's side insets; the rail is its
        // fixed 320 plus the gutter beside it.
        final contentWidth = 1080 - 2 * tokens.spacing.step4;
        final railWidth = 320 + tokens.spacing.step6;

        // Tasks beside the timeline, which gives up the rail's width.
        expect(
          tester.getRect(find.text('Tasks')).left,
          greaterThan(tester.getRect(find.text('Timeline')).right),
        );
        expect(
          tester.getSize(find.byType(EventTimeline)).width,
          contentWidth - railWidth,
        );

        await pumpEventScreen(
          tester,
          EventDetailView(data: buildEventDetailData(tasks: const [])),
          size: _tallDesktop,
        );
        // No tasks: one column at full width, no empty rail beside it.
        expect(find.text('Tasks'), findsNothing);
        expect(tester.getSize(find.byType(EventTimeline)).width, contentWidth);
      },
    );

    testWidgets('offers an add-cover affordance only when there is no cover', (
      tester,
    ) async {
      var coverAdds = 0;
      await pumpEventScreen(
        tester,
        EventDetailView(data: _emptyData(), onAddCover: () => coverAdds++),
        size: _tallMobile,
      );
      await tester.tap(find.byIcon(LottiIcons.addPhoto));
      expect(coverAdds, 1);

      // With a cover present, the add-cover affordance is gone.
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData(), onAddCover: () {}),
        size: _tallMobile,
      );
      expect(find.byIcon(LottiIcons.addPhoto), findsNothing);
    });

    testWidgets(
      'shows an additive "+ Category" placeholder when uncategorized',
      (
        tester,
      ) async {
        var categoryTaps = 0;
        await pumpEventScreen(
          tester,
          // _emptyData has no category; with onTapCategory wired the placeholder
          // chip appears.
          EventDetailView(
            data: _emptyData(),
            onTapCategory: () => categoryTaps++,
          ),
          size: _tallMobile,
        );
        expect(find.text('Category'), findsOneWidget);
        await tester.tap(find.text('Category'));
        expect(categoryTaps, 1);
      },
    );

    testWidgets('reflects an external title change (rename round-trip)', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(
            card: buildEventCardData(title: 'First', coverImage: testImage()),
          ),
        ),
        size: _tallMobile,
      );
      expect(find.text('First'), findsOneWidget);

      // Re-pump with a new title (as after a rename persists) — the title field
      // syncs to the new value while not editing.
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(
            card: buildEventCardData(title: 'Second', coverImage: testImage()),
          ),
        ),
        size: _tallMobile,
      );
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets(
      'a photo timeline beat with no images degrades to its caption',
      (
        tester,
      ) async {
        await pumpEventScreen(
          tester,
          EventDetailView(
            data: buildEventDetailData(
              timeline: const [
                EventTimelineEntry(
                  timeLabel: '20:00',
                  kind: EventTimelineKind.photo,
                  entryId: 'x',
                  text: 'just a caption, no image',
                ),
              ],
            ),
          ),
          size: _tallMobile,
        );
        expect(find.text('just a caption, no image'), findsOneWidget);
      },
    );

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

      // The third star sets three stars.
      await tester.tap(find.bySemanticsLabel('Rate 3 of 5 stars'));
      expect(ratings, [3.0]);
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

      await tester.tap(find.byIcon(LottiIcons.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete event'));
      await tester.pumpAndSettle();

      expect(deletes, 1);
    });

    // Until a cover is chosen, the hero photo is only the newest one and
    // would move with the next photo added; the chip says so and opens the
    // same picker the overflow menu does.
    testWidgets('offers Set cover on the hero only while the cover is the '
        'automatic default', (tester) async {
      var picks = 0;
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(
            card: buildEventCardData(coverImage: testImage()),
          ),
          onChangeCover: () => picks++,
        ),
        size: _tallMobile,
      );
      await tester.tap(find.text('Set cover'));
      expect(picks, 1);

      // Chosen: the chip is gone, the menu item remains.
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(
            card: buildEventCardData(
              coverImage: testImage(),
              coverChosen: true,
            ),
          ),
          onChangeCover: () => picks++,
        ),
        size: _tallMobile,
      );
      expect(find.text('Set cover'), findsNothing);

      // No cover at all: "Add cover photo" is the affordance, not this.
      await pumpEventScreen(
        tester,
        EventDetailView(data: _emptyData(), onChangeCover: () => picks++),
        size: _tallMobile,
      );
      expect(find.text('Set cover'), findsNothing);

      // Read-only view: nothing to open.
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(
            card: buildEventCardData(coverImage: testImage()),
          ),
        ),
        size: _tallMobile,
      );
      expect(find.text('Set cover'), findsNothing);
    });

    testWidgets('the photo grid receives the set-cover handler', (
      tester,
    ) async {
      Future<bool> setCover(String id) async => true;
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(
            photos: [EventPhoto(testImage(), id: 'p1')],
          ),
          onSetCover: setCover,
        ),
        size: _tallMobile,
      );

      final grid = tester.widget<EventPhotoGrid>(find.byType(EventPhotoGrid));
      expect(grid.onSetCover, same(setCover));
    });

    testWidgets('the overflow menu changes the cover', (tester) async {
      var changes = 0;
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(),
          onChangeCover: () => changes++,
        ),
        size: _tallMobile,
      );

      await tester.tap(find.byIcon(LottiIcons.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change cover'));
      await tester.pumpAndSettle();

      expect(changes, 1);
    });

    testWidgets('wires the back callback', (tester) async {
      var back = false;

      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(),
          onBack: () => back = true,
        ),
        size: _tallMobile,
      );

      await tester.tap(find.byIcon(LottiIcons.back));

      expect(back, isTrue);
    });

    testWidgets('the passive summary sits on the flat section card, with no '
        'refresh it cannot honour', (tester) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallMobile,
      );

      final card = find.byType(EventPassiveSummaryCard);
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.text('A surprise 30th for Anna on the rooftop.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byType(DesignSystemSectionCard),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(LottiIcons.refresh), findsNothing);
    });

    testWidgets('timeline rows are inert when nothing opens them', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData()),
        size: _tallMobile,
      );
      final rows = tester.widgetList<DesignSystemTimelineRow>(
        find.byType(DesignSystemTimelineRow),
      );
      expect(rows, isNotEmpty);
      expect(rows.every((row) => row.onTap == null), isTrue);
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

      // Every row with a source entry is a door to it; the whole row is the
      // target, as on a goal's or a person's timeline.
      final rows = tester
          .widgetList<DesignSystemTimelineRow>(
            find.byType(DesignSystemTimelineRow),
          )
          .toList();
      expect(rows.where((row) => row.onTap != null), hasLength(3));
      await tester.tap(find.text("Anna's speech."));
      await tester.pump();

      expect(opened, ['note-1']);
    });

    testWidgets('tapping a linked task row opens that task', (tester) async {
      final opened = <String>[];
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(
            tasks: const [
              EventTaskRef(id: 'task-1', title: 'Book the venue', done: true),
              EventTaskRef(id: 'task-2', title: 'Share the album', done: false),
            ],
          ),
          onOpenTask: opened.add,
        ),
        size: _tallMobile,
      );

      // Each openable task row carries an "open" chevron and is tappable.
      expect(find.byIcon(LottiIcons.chevronRight), findsNWidgets(2));
      await tester.tap(find.text('Share the album'));
      await tester.pump();
      expect(opened, ['task-2']);
    });

    testWidgets('a linked task row without an id stays static', (tester) async {
      var opens = 0;
      await pumpEventScreen(
        tester,
        EventDetailView(
          data: buildEventDetailData(
            tasks: const [EventTaskRef(title: 'No id task', done: false)],
          ),
          onOpenTask: (_) => opens++,
        ),
        size: _tallMobile,
      );

      expect(find.byIcon(LottiIcons.chevronRight), findsNothing);
      await tester.tap(find.text('No id task'));
      await tester.pump();
      expect(opens, 0);
    });

    group('bottom bar', () {
      const barKey = ValueKey('bar');
      const barHeight = 72.0;

      Scaffold scaffoldOf(WidgetTester tester) => tester.widget<Scaffold>(
        find.descendant(
          of: find.byType(EventDetailView),
          matching: find.byType(Scaffold),
        ),
      );

      /// The bottom inset the scroll view reserves: its last sliver.
      double reservedBottom(WidgetTester tester) {
        final scrollView = tester.widget<CustomScrollView>(
          find.descendant(
            of: find.byType(EventDetailView),
            matching: find.byType(CustomScrollView),
          ),
        );
        final trailing = scrollView.slivers.last;
        expect(trailing, isA<SliverPadding>());
        return ((trailing as SliverPadding).padding as EdgeInsets).bottom;
      }

      testWidgets(
        "docks the bar in the Scaffold's bottom slot over an extended body, "
        'flush with the bottom edge',
        (tester) async {
          await pumpEventScreen(
            tester,
            EventDetailView(
              data: buildEventDetailData(),
              bottomBar: const SizedBox(key: barKey, height: barHeight),
            ),
            size: _tallMobile,
          );

          final scaffold = scaffoldOf(tester);
          // The bar's glass blur samples the body painting behind it.
          expect(scaffold.extendBody, isTrue);
          expect(scaffold.bottomNavigationBar, isA<SizedBox>());
          final viewRect = tester.getRect(find.byType(EventDetailView));
          final barRect = tester.getRect(find.byKey(barKey));
          expect(barRect.bottom, viewRect.bottom);
          expect(barRect.left, viewRect.left);
          expect(barRect.right, viewRect.right);
        },
      );

      testWidgets("the trailing sliver consumes exactly the bar's height", (
        tester,
      ) async {
        await pumpEventScreen(
          tester,
          EventDetailView(
            data: buildEventDetailData(),
            bottomBar: const SizedBox(key: barKey, height: barHeight),
          ),
          size: _tallMobile,
        );

        // With extendBody the Scaffold publishes the bar's height as the
        // body's bottom inset; the last section scrolls clear of the bar.
        expect(reservedBottom(tester), barHeight);
      });

      testWidgets('without a bar the bottom edge is bare and nothing is '
          'reserved', (tester) async {
        await pumpEventScreen(
          tester,
          EventDetailView(data: buildEventDetailData()),
          size: _tallMobile,
        );

        expect(scaffoldOf(tester).bottomNavigationBar, isNull);
        expect(reservedBottom(tester), 0);
      });
    });

    testWidgets('hides summary when none is provided', (tester) async {
      await pumpEventScreen(
        tester,
        EventDetailView(data: buildEventDetailData(summary: null)),
        size: _tallMobile,
      );
      expect(find.text('Summary'), findsNothing);
      expect(find.byIcon(LottiIcons.refresh), findsNothing);
    });
  });
}

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/components/timeline/design_system_timeline_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/person_timeline.dart';
import 'package:lotti/features/relationships/state/relationship_proposal_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/person_timeline_view.dart';
import 'package:lotti/get_it.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  // Thursday 13 August 2026, 14:05.
  final now = DateTime(2026, 8, 13, 14, 5);

  Metadata meta(String id, DateTime at, {bool? starred, DateTime? to}) =>
      Metadata(
        id: id,
        createdAt: at,
        updatedAt: at,
        dateFrom: at,
        dateTo: to ?? at,
        starred: starred,
      );

  final call = CheckInEntry(
    meta: meta(
      'call',
      DateTime(2026, 8, 1, 12, 44),
      to: DateTime(2026, 8, 1, 12, 55),
    ),
    data: const CheckInData(
      relationshipId: 'pip',
      interactionType: CheckInInteractionType.call,
      sentiment: CheckInSentiment.good,
      topics: ['launch window'],
    ),
    entryText: const EntryText(plainText: 'Walked through the launch window.'),
  );
  final quiet = CheckInEntry(
    meta: meta('quiet', DateTime(2026, 7, 11, 18)),
    data: const CheckInData(
      relationshipId: 'pip',
      interactionType: CheckInInteractionType.message,
      sentiment: CheckInSentiment.neutral,
    ),
  );
  final note =
      JournalEntity.journalEntry(
            meta: meta('note', DateTime(2026, 8, 11, 8, 30)),
            entryText: const EntryText(plainText: 'Ask about the sled race.'),
          )
          as JournalEntry;
  final pinned =
      JournalEntity.journalEntry(
            meta: meta('pinned', DateTime(2025, 3, 2), starred: true),
            entryText: const EntryText(plainText: 'Met at the ice summit.'),
          )
          as JournalEntry;
  final coffee = JournalEntity.event(
    meta: meta(
      'coffee',
      DateTime(2026, 8, 16, 15),
      to: DateTime(2026, 8, 16, 17),
    ),
    data: const EventData(
      title: 'Coffee at the ice garden',
      stars: 0,
      status: EventStatus.planned,
    ),
  );
  final draft = testTask.copyWith(
    meta: meta('draft', DateTime(2026, 8, 10)),
    data: testTask.data.copyWith(
      title: 'Send the contract draft',
      due: DateTime(2026, 8, 28),
    ),
  );

  late List<String> opened;

  PersonTimelineActions actions() => (
    openCheckIn: (c) => opened.add('check-in ${c.meta.id}'),
    openNote: (n) => opened.add('note ${n.meta.id}'),
    openEntry: (e) => opened.add('entry ${e.meta.id}'),
    openTask: (t) => opened.add('task ${t.meta.id}'),
    unlinkTask: (t) => opened.add('unlink ${t.meta.id}'),
    sortVoiceNote: (a) => opened.add('sort ${a.meta.id}'),
  );

  setUp(() => opened = []);

  PersonTimeline timeline({
    List<CheckInEntry>? checkIns,
    List<JournalEntity>? entries,
    List<Task>? tasks,
    PersonTimelineFilter filter = PersonTimelineFilter.all,
  }) => buildPersonTimeline(
    now: now,
    checkIns: checkIns ?? [call, quiet],
    entries: entries ?? [note, pinned, coffee],
    tasks: tasks ?? [draft],
    filter: filter,
  );

  Future<void> pump(
    WidgetTester tester,
    PersonTimeline t, {
    ValueChanged<PersonTimelineFilter>? onFilter,
  }) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      CustomScrollView(
        slivers: [
          PersonTimelineSliver(
            timeline: t,
            personName: 'Pip',
            filter: PersonTimelineFilter.all,
            onFilter: onFilter ?? (_) {},
            actions: actions(),
            now: now,
          ),
        ],
      ),
    ),
  );

  testWidgets('a heading, then upcoming first and the months after, each row '
      'saying when and what it is', (tester) async {
    await pump(tester, timeline());

    expect(find.text('Timeline'), findsOneWidget);
    final headers = tester
        .widgetList<DesignSystemTimelineSectionHeader>(
          find.byType(DesignSystemTimelineSectionHeader),
        )
        .map((h) => h.label)
        .toList();
    expect(headers, ['Upcoming', 'This week', 'August', 'July']);
    expect(find.text('Coffee at the ice garden'), findsOneWidget);
    expect(find.text('Send the contract draft'), findsOneWidget);
    expect(find.textContaining('Due Fri 28 Aug'), findsOneWidget);
    expect(find.textContaining('15:00 – 17:00'), findsOneWidget);
    // A pinned note lives under About, not on the timeline.
    expect(find.text('Met at the ice summit.'), findsNothing);
  });

  testWidgets('a check-in says how it felt in a word and its topics as '
      'words; neutral says nothing', (tester) async {
    await pump(tester, timeline());

    expect(find.text('Good · launch window'), findsOneWidget);
    expect(find.textContaining('Neutral'), findsNothing);
  });

  testWidgets('every kind opens where it belongs, and a long press on a task '
      'offers to unlink it', (tester) async {
    await pump(tester, timeline());

    await tester.tap(find.text('Walked through the launch window.'));
    await tester.tap(find.text('Ask about the sled race.'));
    await tester.tap(find.text('Coffee at the ice garden'));
    await tester.tap(find.text('Send the contract draft'));
    await tester.longPress(find.text('Send the contract draft'));

    expect(opened, [
      'check-in call',
      'note note',
      'entry coffee',
      'task draft',
      'unlink draft',
    ]);
  });

  testWidgets('a row speaks as one sentence', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, timeline());

    expect(
      find.bySemanticsLabel(
        RegExp(r'^Note, Tue 11 Aug 08:30\. Ask about the sled race\.$'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the filter appears only once there is enough to filter, and '
      'reports the choice', (tester) async {
    await pump(tester, timeline());
    expect(find.byKey(const ValueKey('person-timeline-filter')), findsNothing);

    PersonTimelineFilter? chosen;
    final many = [
      for (var i = 0; i < personTimelineFiltersFrom; i++)
        JournalEntity.journalEntry(
          meta: meta('n$i', DateTime(2026, 6, 1, i)),
          entryText: EntryText(plainText: 'note $i'),
        ),
    ];
    await pump(
      tester,
      timeline(entries: many),
      onFilter: (f) => chosen = f,
    );
    await tester.tap(find.text('Notes'));

    expect(chosen, PersonTimelineFilter.notes);
  });

  testWidgets('a task just confirmed from a suggestion is marked', (
    tester,
  ) async {
    await pump(tester, timeline());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PersonTimelineSliver)),
    );
    container
        .read(relationshipTaskHighlightProvider.notifier)
        .highlight('draft');
    await tester.pump();

    final row = tester.widget<DesignSystemTimelineRow>(
      find.ancestor(
        of: find.text('Send the contract draft'),
        matching: find.byType(DesignSystemTimelineRow),
      ),
    );
    expect(row.highlighted, isTrue);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('an empty timeline teaches what to do, naming the person', (
    tester,
  ) async {
    await pump(tester, timeline(checkIns: [], entries: [], tasks: []));

    expect(
      find.text(
        'Nothing here yet. Speak after you talk to Pip, or add a note, a task '
        'or photos.',
      ),
      findsOneWidget,
    );
  });

  group('rows say what each kind is', () {
    /// The widest form of a row's meta line.
    DsTieredText metaOf(WidgetTester tester, String id) =>
        tester.widget<DsTieredText>(
          find.descendant(
            of: find.byKey(ValueKey('person-timeline-row-$id')),
            matching: find.byType(DsTieredText),
          ),
        );

    JournalAudio audio(String id, DateTime at, {String? words}) =>
        testAudioEntry.copyWith(
          meta: meta(id, at),
          entryText: words == null ? null : EntryText(plainText: words),
          data: testAudioEntry.data.copyWith(
            duration: const Duration(minutes: 1),
          ),
        );

    Task task(
      String id, {
      String title = 'A task',
      DateTime? due,
      bool done = false,
    }) => testTask.copyWith(
      meta: meta(id, DateTime(2026, 8)),
      data: testTask.data.copyWith(
        title: title,
        due: due,
        status: done
            ? TaskStatus.done(
                id: 'done-$id',
                createdAt: DateTime(2026, 8, 12, 10),
                utcOffset: 0,
              )
            : testTask.data.status,
      ),
    );

    testWidgets('a voice note says how long it ran and what was said, or '
        'that its words are still coming, in the quiet ink', (tester) async {
      await pump(
        tester,
        timeline(
          checkIns: [],
          tasks: [],
          entries: [
            audio('spoken', DateTime(2026, 8, 12, 19, 10), words: 'Send-off.'),
            audio('waiting', DateTime(2026, 8, 11, 9)),
          ],
        ),
      );

      expect(
        metaOf(tester, 'spoken').tiers.first,
        'Yesterday 19:10 · Voice note · 1 min',
      );
      expect(find.text('Send-off.'), findsOneWidget);
      final waiting = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('person-timeline-row-waiting')),
          matching: find.text('Transcribing…'),
        ),
      );
      final tokens = tester
          .element(find.byType(PersonTimelineRow).first)
          .designTokens;
      expect(waiting.style?.color, tokens.colors.text.lowEmphasis);

      await tester.tap(find.text('Send-off.'));
      expect(opened, ['entry spoken']);
    });

    testWidgets('a voice note with words offers Sort this, which sorts it; '
        'one still waiting for its words does not', (tester) async {
      await pump(
        tester,
        timeline(
          checkIns: [],
          tasks: [],
          entries: [
            audio('spoken', DateTime(2026, 8, 12, 19, 10), words: 'Send-off.'),
            audio('waiting', DateTime(2026, 8, 11, 9)),
          ],
        ),
      );

      expect(find.byKey(const ValueKey('person-sort-waiting')), findsNothing);
      final sort = find.byKey(const ValueKey('person-sort-spoken'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('person-timeline-row-spoken')),
          matching: sort,
        ),
        findsOneWidget,
      );
      await tester.tap(sort);
      expect(opened, ['sort spoken']);
    });

    testWidgets('an overdue task says since when in the warning ink, a done '
        'one when it was done, and an untitled one that it is untitled', (
      tester,
    ) async {
      await pump(
        tester,
        timeline(
          checkIns: [],
          entries: [],
          tasks: [
            task('late', title: 'Return the sled', due: DateTime(2026, 8, 10)),
            task('finished', title: 'Book the walkthrough', done: true),
            task('nameless', title: ''),
          ],
        ),
      );
      final tokens = tester
          .element(find.byType(PersonTimelineRow).first)
          .designTokens;

      final late = metaOf(tester, 'late');
      expect(late.tiers.first, 'Overdue since Mon 10 Aug · Task');
      expect(late.style.color, tokens.colors.alert.warning.ink);
      expect(
        metaOf(tester, 'finished').tiers.first,
        'Done Yesterday 10:00 · Task',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('person-timeline-row-nameless')),
          matching: find.text('(untitled)'),
        ),
        findsOneWidget,
      );
    });

    testWidgets("a check-in saved without words reads its entries' words, and "
        'says the words are coming while only a recording holds them', (
      tester,
    ) async {
      final bare = CheckInEntry(
        meta: meta('bare', DateTime(2026, 8, 12, 9)),
        data: const CheckInData(
          relationshipId: 'pip',
          interactionType: CheckInInteractionType.call,
        ),
      );
      final pending = CheckInEntry(
        meta: meta('pending', DateTime(2026, 8, 11, 9)),
        data: const CheckInData(
          relationshipId: 'pip',
          interactionType: CheckInInteractionType.call,
        ),
      );
      final photo = testImageEntry.copyWith(
        meta: meta('photo', DateTime(2026, 8, 12, 9)),
      );
      final comment =
          JournalEntity.journalEntry(
                meta: meta('comment', DateTime(2026, 8, 12, 9)),
                entryText: const EntryText(plainText: 'Talked logistics.'),
              )
              as JournalEntry;
      await pump(
        tester,
        buildPersonTimeline(
          now: now,
          checkIns: [bare, pending],
          entries: const [],
          tasks: const [],
          checkInEntries: {
            // A photo has no words to offer; the comment after it does.
            'bare': [photo, comment],
            'pending': [audio('take', DateTime(2026, 8, 11, 9))],
          },
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('person-timeline-row-bare')),
          matching: find.text('Talked logistics.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('person-timeline-row-pending')),
          matching: find.text('Transcribing…'),
        ),
        findsOneWidget,
      );
    });
  });

  group('the photo strip', () {
    // The thumbnails resolve their files under the documents directory,
    // which the image fixtures expect registered (journal_image_fixtures).
    late Directory documents;
    setUp(() {
      documents = Directory.systemTemp.createTempSync('person_timeline_');
      getIt.registerSingleton<Directory>(documents);
    });
    tearDown(() async {
      await getIt.unregister<Directory>();
      documents.deleteSync(recursive: true);
    });

    List<JournalEntity> photos(int n) => [
      for (var i = 0; i < n; i++)
        testImageEntry.copyWith(
          meta: meta('photo-$i', DateTime(2026, 8, 2, i)),
        ),
    ];

    testWidgets('shows four, the last saying how many more, and each opens '
        'its own photo', (tester) async {
      await pump(tester, timeline(checkIns: [], tasks: [], entries: photos(6)));

      expect(find.text('+2'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('person-timeline-photo-photo-4')),
      );
      expect(opened, ['entry photo-4']);
    });

    testWidgets('the row itself opens the photo its strip starts with', (
      tester,
    ) async {
      await pump(tester, timeline(checkIns: [], tasks: [], entries: photos(2)));

      await tester.tap(find.textContaining('2 photos'));
      // Newest first, as the strip shows them.
      expect(opened, ['entry photo-1']);
    });

    testWidgets('three photos need no count', (tester) async {
      await pump(tester, timeline(checkIns: [], tasks: [], entries: photos(3)));

      expect(find.textContaining('+'), findsNothing);
    });
  });

  group('About', () {
    final more = [
      for (var i = 0; i < 4; i++)
        TimelineNote(
          JournalEntity.journalEntry(
                meta: meta('p$i', DateTime(2026, 1, i + 1), starred: true),
                entryText: EntryText(plainText: 'pinned $i'),
              )
              as JournalEntry,
        ),
    ];

    Future<void> pumpAbout(WidgetTester tester, {bool compact = false}) =>
        tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            PersonAboutSection(
              personName: 'Pip',
              pinned: more,
              onOpen: (n) => opened.add(n.meta.id),
              compact: compact,
            ),
          ),
        );

    testWidgets('shows three and folds the rest behind Show all', (
      tester,
    ) async {
      await pumpAbout(tester);

      expect(find.text('About Pip'), findsOneWidget);
      expect(find.text('pinned 3'), findsNothing);
      await tester.tap(find.text('Show all (4)'));
      await tester.pump();
      expect(find.text('pinned 3'), findsOneWidget);

      await tester.tap(find.text('pinned 3'));
      expect(opened, ['p3']);
    });

    testWidgets('on a phone it is its heading alone — the count and a '
        'chevron — and opens in place to every note', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAbout(tester, compact: true);

      expect(find.text('About Pip'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('person-about-count')))
            .data,
        '· 4',
      );
      expect(find.text('pinned 0'), findsNothing);
      expect(find.bySemanticsLabel('About Pip · Show all (4)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('person-about')));
      await tester.pump();

      for (var i = 0; i < 4; i++) {
        expect(find.text('pinned $i'), findsOneWidget);
      }
      expect(find.text('Show less'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a pinned note answers a hover in the action ink', (
      tester,
    ) async {
      await pumpAbout(tester);
      final tokens = tester
          .element(find.byType(PersonAboutSection))
          .designTokens;
      final first = find.text('pinned 0');
      expect(
        tester.widget<Text>(first).style?.color,
        tokens.colors.text.highEmphasis,
      );

      await _hover(tester, first);

      expect(
        tester.widget<Text>(first).style?.color,
        tokens.colors.interactive.enabled,
      );
    });

    testWidgets('renders nothing when nothing is pinned', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          PersonAboutSection(
            personName: 'Pip',
            pinned: const [],
            onOpen: (_) {},
          ),
        ),
      );

      expect(find.byKey(const ValueKey('person-about')), findsNothing);
    });
  });
}

/// Puts a mouse over [target] and settles, so hover styling shows.
Future<void> _hover(WidgetTester tester, Finder target) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(target));
  await tester.pumpAndSettle();
}

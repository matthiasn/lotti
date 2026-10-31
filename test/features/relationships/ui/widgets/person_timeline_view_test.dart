import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/components/timeline/design_system_timeline_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/person_timeline.dart';
import 'package:lotti/features/relationships/state/relationship_proposal_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/person_timeline_view.dart';
import 'package:lotti/features/speech/ui/widgets/recording_playback.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/transcript/folded_words.dart';
import 'package:lotti/widgets/transcript/recording_transcript.dart';
import 'package:lotti/widgets/transcript/transcript_status.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/mocks.dart';
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
    retryTranscript: (a) => opened.add('retry ${a.meta.id}'),
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
    List<Override> overrides = const [],
    Map<String, String> summaries = const {},
  }) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      overrides: overrides,
      CustomScrollView(
        slivers: [
          PersonTimelineSliver(
            timeline: t,
            summaries: summaries,
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

    testWidgets('a voice note says how long it ran and what was said — or, '
        'through the shared status, that its words are coming while they '
        'may be, and that they are not once the grace window has closed', (
      tester,
    ) async {
      // The rows read the clock themselves, so the page's `now` is the clock.
      await withClock(
        Clock.fixed(now),
        () => pump(
          tester,
          timeline(
            checkIns: [],
            tasks: [],
            entries: [
              audio(
                'spoken',
                DateTime(2026, 8, 12, 19, 10),
                words: 'Send-off.',
              ),
              // Two minutes ago: still inside the window.
              audio('fresh', now.subtract(const Duration(minutes: 2))),
              // Two days ago, never transcribed: it must stop promising words.
              audio('stale', DateTime(2026, 8, 11, 9)),
            ],
          ),
        ),
      );

      expect(
        metaOf(tester, 'spoken').tiers.first,
        'Yesterday 19:10 · Voice note · 1 min',
      );
      expect(find.text('Send-off.'), findsOneWidget);

      TranscriptStatus statusOf(String id) => tester
          .widget<RecordingTranscript>(
            find.descendant(
              of: find.byKey(ValueKey('person-timeline-row-$id')),
              matching: find.byType(RecordingTranscript),
            ),
          )
          .status;
      expect(statusOf('fresh'), TranscriptStatus.transcribing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('person-timeline-row-fresh')),
          matching: find.text('Transcribing…'),
        ),
        findsOneWidget,
      );
      expect(statusOf('stale'), TranscriptStatus.notTranscribed);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('person-timeline-row-stale')),
          matching: find.text('Not transcribed'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Send-off.'));
      expect(opened, ['entry spoken']);
    });

    testWidgets('a page left open turns a waiting recording to Not '
        'transcribed when its window closes — nothing else would', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pump(
          tester,
          timeline(
            checkIns: [],
            tasks: [],
            entries: [audio('fresh', now.subtract(const Duration(minutes: 2)))],
          ),
        );
        expect(find.text('Transcribing…'), findsOneWidget);
      });

      // No transcript, no status change, no database write: only the row's
      // own timer ends the wait.
      await withClock(Clock.fixed(now.add(kTranscriptGrace)), () async {
        await tester.pump(kTranscriptGrace);
        await tester.pump();
      });

      expect(find.text('Not transcribed'), findsOneWidget);
      expect(find.text('Transcribing…'), findsNothing);
    });

    testWidgets("a waiting row's status reaches a screen reader, not only "
        "the row's sentence", (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        timeline(
          checkIns: [],
          tasks: [],
          entries: [audio('stale', DateTime(2026, 8, 11, 9))],
        ),
      );

      expect(find.bySemanticsLabel('Not transcribed'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a check-in holding several wordless recordings waits on the '
        'newest', (tester) async {
      final spoken = call.copyWith(entryText: const EntryText(plainText: ''));
      await pump(
        tester,
        buildPersonTimeline(
          now: now,
          checkIns: [spoken],
          entries: const [],
          tasks: const [],
          checkInEntries: {
            'call': [
              audio('newer-take', DateTime(2026, 8, 1, 12, 50)),
              audio('older-take', DateTime(2026, 8, 1, 12, 44)),
            ],
          },
        ),
      );

      expect(
        tester.widget<RecordingTranscript>(find.byType(RecordingTranscript)).id,
        'newer-take',
      );
    });

    testWidgets('a recording whose words never came offers Retry, which asks '
        'for that recording again — as a goal rail does', (tester) async {
      await pump(
        tester,
        timeline(
          checkIns: [],
          tasks: [],
          entries: [audio('stale', DateTime(2026, 8, 11, 9))],
        ),
      );

      await tester.tap(find.byKey(const ValueKey('transcript-retry-stale')));
      expect(opened, ['retry stale']);
    });

    testWidgets('a transcription running past the window still says it is '
        'transcribing, and a failed one says so', (tester) async {
      for (final (status, label) in [
        (InferenceStatus.running, 'Transcribing…'),
        (InferenceStatus.error, 'Transcription failed'),
      ]) {
        await pump(
          tester,
          timeline(
            checkIns: [],
            tasks: [],
            entries: [audio('stale', DateTime(2026, 8, 11, 9))],
          ),
          overrides: [
            inferenceStatusControllerProvider((
              id: 'stale',
              aiResponseType: AiResponseType.audioTranscription,
            )).overrideWith(() => FixedInferenceStatusController(status)),
          ],
        );
        expect(find.text(label), findsOneWidget, reason: '$status');
        // A fresh scope for the next status.
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('a voice note and a spoken check-in each play lightly in '
        'place; a written check-in has nothing to play', (tester) async {
      final spoken = call.copyWith(entryText: const EntryText(plainText: ''));
      await pump(
        tester,
        buildPersonTimeline(
          now: now,
          checkIns: [spoken, quiet],
          entries: [
            audio('spoken-note', DateTime(2026, 8, 12, 19, 10), words: 'Hi.'),
          ],
          tasks: const [],
          checkInEntries: {
            'call': [
              audio('older-take', DateTime(2026, 8, 1, 12, 44), words: 'A.'),
              audio('newer-take', DateTime(2026, 8, 1, 12, 50), words: 'B.'),
            ],
          },
        ),
      );

      List<String> played(String rowId) => tester
          .widgetList<RecordingPlayback>(
            find.descendant(
              of: find.byKey(ValueKey('person-timeline-row-$rowId')),
              matching: find.byType(RecordingPlayback),
            ),
          )
          .map((p) => p.audio.meta.id)
          .toList();
      expect(played('spoken-note'), ['spoken-note']);
      expect(played('call'), ['newer-take'], reason: 'the newest it holds');
      expect(played('quiet'), isEmpty);
    });

    final longWords = [
      for (var i = 1; i <= 12; i++) 'Sentence $i of what Pip said.',
    ].join(' ');

    testWidgets('a voice note with a summary leads with it, and Show more '
        'opens the whole transcript in place; Show less folds it', (
      tester,
    ) async {
      await pump(
        tester,
        timeline(
          checkIns: [],
          tasks: [],
          entries: [
            audio('spoken', DateTime(2026, 8, 12, 19, 10), words: longWords),
          ],
        ),
        summaries: {'spoken': 'Pip wants a crew send-off.'},
      );
      await tester.pumpAndSettle();

      Text words() => tester.widget<Text>(
        find.byKey(const ValueKey('folded-words-spoken')),
      );
      expect(words().data, 'Pip wants a crew send-off.');
      expect(words().maxLines, FoldedWords.foldedLines);

      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(words().data, longWords);
      expect(words().maxLines, isNull);
      expect(opened, isEmpty, reason: 'expanding is not opening the entry');

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(words().data, 'Pip wants a crew send-off.');
      // A way in, and it says so under a pointer.
      final tokens = tester.element(find.byType(FoldedWords)).designTokens;
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Show more')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Show more')).style?.color,
        tokens.colors.interactive.hover,
      );
    });

    testWidgets('a check-in holding a summarised recording leads with that '
        'summary and opens to its own words', (tester) async {
      final spoken = call.copyWith(
        entryText: EntryText(plainText: longWords),
      );
      await pump(
        tester,
        buildPersonTimeline(
          now: now,
          checkIns: [spoken],
          entries: const [],
          tasks: const [],
          checkInEntries: {
            spoken.meta.id: [audio('take-1', DateTime(2026, 8, 1, 12, 44))],
          },
        ),
        summaries: {'take-1': 'Pip is calm about the slip.'},
      );
      await tester.pumpAndSettle();

      Text words() => tester.widget<Text>(
        find.byKey(ValueKey('folded-words-${spoken.meta.id}')),
      );
      expect(words().data, 'Pip is calm about the slip.');
      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(words().data, longWords);
    });

    testWidgets('a check-in without a recording folds its long words to '
        'three lines, and opens them on Show more', (tester) async {
      setTestSurfaceSize(tester, const Size(390, 2400));
      final typed = call.copyWith(
        entryText: EntryText(plainText: longWords),
      );
      await pump(tester, timeline(checkIns: [typed], entries: [], tasks: []));
      await tester.pumpAndSettle();

      final words = find.byKey(
        ValueKey('folded-words-${typed.meta.id}'),
      );
      expect(tester.widget<Text>(words).data, longWords);
      expect(tester.widget<Text>(words).maxLines, 3);
      await tester.tap(
        find.byKey(ValueKey('folded-words-more-${typed.meta.id}')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(words).maxLines, isNull);
    });

    testWidgets('without a summary a long transcript folds to three lines '
        'and opens on Show more; a short one offers nothing to open', (
      tester,
    ) async {
      setTestSurfaceSize(tester, const Size(390, 2400));
      await pump(
        tester,
        timeline(
          checkIns: [],
          tasks: [],
          entries: [
            audio('long', DateTime(2026, 8, 12, 19, 10), words: longWords),
            audio('short', DateTime(2026, 8, 11, 9), words: 'Send-off.'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('folded-words-more-short')),
        findsNothing,
      );
      final more = find.byKey(const ValueKey('folded-words-more-long'));
      expect(more, findsOneWidget);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('folded-words-long')),
            )
            .maxLines,
        isNull,
      );
    });

    testWidgets('a check-in landing above keeps every row below it: opened '
        'words stay open, and no row is built again', (tester) async {
      setTestSurfaceSize(tester, const Size(390, 2400));
      final long = audio(
        'long',
        DateTime(2026, 8, 12, 19, 10),
        words: longWords,
      );
      await pump(
        tester,
        timeline(checkIns: [quiet], tasks: [], entries: [long]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('folded-words-more-long')));
      await tester.pumpAndSettle();
      Element row(String id) => tester.element(
        find.byKey(ValueKey('person-timeline-row-$id')),
      );
      final longRow = row('long');
      final quietRow = row('quiet');

      // The reload a new check-in brings: the same rows, one more above them.
      final fresh = CheckInEntry(
        meta: meta('fresh', DateTime(2026, 8, 13, 13)),
        data: const CheckInData(
          relationshipId: 'pip',
          interactionType: CheckInInteractionType.call,
        ),
      );
      await pump(
        tester,
        timeline(checkIns: [fresh, quiet], tasks: [], entries: [long]),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('person-timeline-row-fresh')), findsOne);
      // Found again by key at their new places, not rebuilt from scratch:
      // a rebuilt row re-resolves and re-decodes its photos, which is what
      // made the page flicker after every check-in.
      expect(identical(row('long'), longRow), isTrue);
      expect(identical(row('quiet'), quietRow), isTrue);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('folded-words-long')),
            )
            .maxLines,
        isNull,
        reason: 'the words the reader opened stay open',
      );
    });

    testWidgets('rows come back into view at their height: a jump down the '
        'history leaves the scroll extent where it is', (tester) async {
      // Thirty long recordings, each with a summary line to lead with — as
      // the page's detail supplies them. Rows the lazy list drops and builds
      // again must lay out at their final height the first time: a row that
      // fetched its own line was laid out three lines tall and shrank when
      // the line arrived, and the extent shrank under the reader.
      final many = [
        for (var i = 0; i < 30; i++)
          audio(
            'many-$i',
            DateTime(2026, 8, 12).subtract(Duration(hours: 7 * i)),
            words: longWords,
          ),
      ];
      final summaries = {for (final a in many) a.meta.id: 'Line ${a.meta.id}.'};
      const phone = Size(390, 844);
      setTestSurfaceSize(tester, phone);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CustomScrollView(
            controller: controller,
            slivers: [
              PersonTimelineSliver(
                timeline: timeline(checkIns: [], tasks: [], entries: many),
                summaries: summaries,
                personName: 'Pip',
                filter: PersonTimelineFilter.all,
                onFilter: (_) {},
                actions: actions(),
                now: now,
              ),
            ],
          ),
          mediaQueryData: const MediaQueryData(size: phone),
        ),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final end = controller.position.maxScrollExtent;

      // Far away, so the rows at the end are dropped; then back to them.
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      controller.jumpTo(end);
      final extents = <double>[];
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump();
        extents.add(controller.position.maxScrollExtent);
      }

      expect(extents, everyElement(end));
      expect(controller.position.pixels, end);
      expect(find.text('Line many-29.'), findsOneWidget);
    });

    testWidgets('a row the reader opened stays open when the history is '
        'scrolled far past it and back', (tester) async {
      // Thirty long recordings; the first is opened, then dropped by the
      // lazy list on a jump to the end. Built again on the way back it would
      // be folded — the reader's Show more undone, and a row above the
      // viewport suddenly shorter, moving the history under them.
      final many = [
        for (var i = 0; i < 30; i++)
          audio(
            'many-$i',
            DateTime(2026, 8, 12).subtract(Duration(hours: 7 * i)),
            words: longWords,
          ),
      ];
      final summaries = {for (final a in many) a.meta.id: 'Line ${a.meta.id}.'};
      const phone = Size(390, 844);
      setTestSurfaceSize(tester, phone);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CustomScrollView(
            controller: controller,
            slivers: [
              PersonTimelineSliver(
                timeline: timeline(checkIns: [], tasks: [], entries: many),
                summaries: summaries,
                personName: 'Pip',
                filter: PersonTimelineFilter.all,
                onFilter: (_) {},
                actions: actions(),
                now: now,
              ),
            ],
          ),
          mediaQueryData: const MediaQueryData(size: phone),
        ),
      );
      await tester.pumpAndSettle();
      const words = ValueKey('folded-words-many-0');
      const row = ValueKey('person-timeline-row-many-0');
      await tester.tap(find.byKey(const ValueKey('folded-words-more-many-0')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(words)).maxLines, isNull);
      final opened = tester.getSize(find.byKey(row)).height;
      final folded = tester
          .getSize(find.byKey(const ValueKey('person-timeline-row-many-1')))
          .height;
      expect(opened, greaterThan(folded), reason: 'the words are out');

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.byKey(row), findsNothing, reason: 'far away: not on stage');
      controller.jumpTo(0);
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(words)).maxLines, isNull);
      expect(tester.getSize(find.byKey(row)).height, opened);
      expect(find.text('Line many-0.'), findsNothing);
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
      // Beside the meta line, so the action costs the row no height.
      final tile = tester.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('person-timeline-row-spoken')),
          matching: find.byType(DesignSystemTimelineTile),
        ),
      );
      expect(tester.getCenter(sort).dy, closeTo(tile.center.dy, 1));
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
        'while only a recording holds them says where its words are', (
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
      // The recording is two days old and nothing transcribed it.
      final status = tester.widget<RecordingTranscript>(
        find.descendant(
          of: find.byKey(const ValueKey('person-timeline-row-pending')),
          matching: find.byType(RecordingTranscript),
        ),
      );
      expect(status.id, 'take', reason: "the recording's own status");
      expect(status.status, TranscriptStatus.notTranscribed);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('person-timeline-row-pending')),
          matching: find.text('Not transcribed'),
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

/// Serves fixed linked responses, so a test states the summary it asserts
/// about instead of standing up a database.

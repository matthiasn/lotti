import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/front_agent/model/front_cited_answer.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/model/front_due_section.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/ui/a2ui/front_reply_catalog.dart';
import 'package:lotti/features/front_agent/ui/front_cited_source_row.dart';
import 'package:lotti/features/front_agent/ui/front_entity_preview_card.dart';
import 'package:lotti/features/front_agent/ui/front_logged_time_chart_card.dart';
import 'package:lotti/features/front_agent/ui/front_pull_request_cards.dart';
import 'package:lotti/features/front_agent/ui/front_pull_request_chart_card.dart';
import 'package:lotti/features/front_agent/ui/front_task_list.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:material_ui/material_ui.dart';

import 'front_reply_test_harness.dart';

void main() {
  const ice = FrontEntityReference(
    kind: FrontEntityKind.task,
    id: 't-ice',
    title: 'Check the ice-pad weather window',
    note: '2h 10m',
  );
  const feed = FrontEntityReference(
    kind: FrontEntityKind.task,
    id: 't-feed',
    title: 'Feed the rescued chicks',
  );
  const range = InsightsRange(startDay: 20396, endDayExclusive: 20403);
  const loggedTime = FrontLoggedTimeChart(range: range, categoryIds: {});
  const pullRequests = FrontPullRequestChart(range: range, categoryIds: {});
  final closed = [
    FrontClosedTaskCard(
      id: 't-sweep',
      title: 'Sweep the ice',
      closedAt: DateTime.utc(2026, 11, 8, 10),
    ),
  ];
  final due = FrontDueSection(
    window: FrontDueWindow.today,
    today: DateTime(2026, 11, 10),
    through: DateTime(2026, 11, 10),
  );

  Map<String, Object?> cards(List<FrontEntityReference> references) => {
    'component': FrontReplyComponents.taskCards,
    'items': [for (final reference in references) reference.toJson()],
  };

  /// A reply of every component the catalog has.
  FrontReplySurface everything() => FrontReplySurface.compose(
    surfaceId: 'a1',
    components: [
      const {'component': FrontReplyComponents.text, 'text': 'Two are due:'},
      cards([ice, feed]),
      const {'component': FrontReplyComponents.closedTasks},
      const {'component': FrontReplyComponents.loggedTimeChart},
      const {'component': FrontReplyComponents.pullRequestChart},
      const {
        'component': FrontReplyComponents.quickReplies,
        'options': ['Break it down', 'No thanks'],
      },
    ],
    due: due,
    closedTasks: closed,
    loggedTime: loggedTime,
    pullRequests: pullRequests,
  );

  Finder part(String id) => find.byKey(ValueKey('front-reply-a1-$id'));

  testWidgets("every component draws the chat's own widget, in her order: "
      'cards from her items, the rest from the data the app bound', (
    tester,
  ) async {
    await pumpReplySurfaces(tester, {
      'a1': everything(),
    }, taps: FrontReplyTaps());

    double top(Finder finder) => tester.getTopLeft(finder).dy;
    expect(
      tester
          .widget<FrontEntityPreviewList>(
            find.descendant(
              of: part('c1'),
              matching: find.byType(FrontEntityPreviewList),
            ),
          )
          .references,
      [ice, feed],
    );
    // The window comes through the data model, bound at /due.
    expect(
      tester
          .widget<FrontDueSectionLabel>(
            find.descendant(
              of: part('c1'),
              matching: find.byType(FrontDueSectionLabel),
            ),
          )
          .section,
      due,
    );
    expect(tester.widget<FrontClosedTaskList>(part('c2')).tasks, closed);
    expect(
      tester.widget<FrontLoggedTimeChartCard>(part('c3')).chart,
      loggedTime,
    );
    expect(
      tester.widget<FrontPullRequestChartCard>(part('c4')).chart,
      pullRequests,
    );
    expect(
      tester
          .widgetList<DesignSystemChip>(
            find.descendant(
              of: part('c5'),
              matching: find.byType(DesignSystemChip),
            ),
          )
          .map((chip) => chip.label),
      ['Break it down', 'No thanks'],
    );
    final order = [
      top(find.text('words: Two are due:')),
      for (final id in ['c1', 'c2', 'c3', 'c4', 'c5']) top(part(id)),
    ];
    expect(order, [...order]..sort());
    expect(order.toSet(), hasLength(order.length));
  });

  testWidgets('pull request cards draw the chat cards of what she placed, '
      'a task header opening the task through the chat', (tester) async {
    final taps = FrontReplyTaps();
    const placed = [
      (key: 'penguin/colony#7', taskId: 'ledger'),
      (key: 'penguin/colony#2', taskId: 'igloo'),
    ];
    await pumpReplySurfaces(tester, {
      'a1': FrontReplySurface.compose(
        surfaceId: 'a1',
        components: [
          {
            'component': FrontReplyComponents.pullRequestCards,
            'items': [
              for (final card in placed) frontPullRequestCardToJson(card),
            ],
            'caption': 'Pull requests found',
          },
          const {
            'component': FrontReplyComponents.pullRequestCards,
            'items': <Object?>[],
          },
        ],
      ),
    }, taps: taps);

    final drawn = tester.widget<FrontPullRequestCards>(part('c0'));
    expect(drawn.cards, placed);
    drawn.onOpenTask('ledger');
    expect(taps.openedTasks, ['ledger']);
    // An empty list draws no cards.
    expect(find.byType(FrontPullRequestCards), findsOneWidget);
    expect(
      tester.getSemantics(part('c0')),
      matchesSemantics(label: 'Pull requests found'),
    );
  });

  testWidgets('a caption she gave is the screen-reader label of its '
      'component, and is never shown', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpReplySurfaces(tester, {
      'a1': FrontReplySurface.compose(
        surfaceId: 'a1',
        components: [
          const {
            'component': FrontReplyComponents.text,
            'text': 'Two are due:',
          },
          {
            ...cards(const [ice, feed]),
            'caption': 'Tasks due today',
          },
          const {
            'component': FrontReplyComponents.loggedTimeChart,
            'caption': 'Logged time this week',
          },
        ],
        loggedTime: loggedTime,
      ),
    }, taps: FrontReplyTaps());

    expect(find.bySemanticsLabel('Tasks due today'), findsOneWidget);
    expect(find.bySemanticsLabel('Logged time this week'), findsOneWidget);
    expect(find.text('Tasks due today'), findsNothing);
    expect(find.text('Logged time this week'), findsNothing);
    handle.dispose();
  });

  testWidgets('a tap on a card or a closed task goes to the chat', (
    tester,
  ) async {
    final taps = FrontReplyTaps();
    await pumpReplySurfaces(tester, {'a1': everything()}, taps: taps);

    await tester.tap(find.byKey(FrontEntityPreviewKeys.card('t-ice')));
    await tester.pump();
    final row = find.byKey(FrontTaskListKeys.closedRow('t-sweep'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump();

    expect(taps.opened, [ice]);
    expect(taps.openedTasks, ['t-sweep']);
  });

  testWidgets('a tapped quick reply comes back through the surface as an '
      'action, in its own words', (tester) async {
    final taps = FrontReplyTaps();
    await pumpReplySurfaces(tester, {'a1': everything()}, taps: taps);

    final chip = find.byKey(const ValueKey('front-quick-reply-Break it down'));
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pump();

    expect(taps.quickReplies, ['Break it down']);
  });

  testWidgets('quick replies cannot be tapped while the chat cannot take '
      'one', (tester) async {
    final taps = FrontReplyTaps();
    await pumpReplySurfaces(
      tester,
      {'a1': everything()},
      taps: taps,
      canReply: false,
    );

    final chips = tester.widgetList<DesignSystemChip>(
      find.byType(DesignSystemChip),
    );
    expect(chips, hasLength(2));
    expect(chips.every((chip) => chip.onPressed == null), isTrue);
    expect(taps.quickReplies, isEmpty);
  });

  testWidgets("a card a door's preview already shows is left out of her "
      'list, and a list left empty is not drawn', (tester) async {
    await pumpReplySurfaces(
      tester,
      {
        'a1': FrontReplySurface.compose(
          surfaceId: 'a1',
          components: [
            const {'component': FrontReplyComponents.text, 'text': 'Made it.'},
            cards([ice, feed]),
            const {'component': FrontReplyComponents.text, 'text': 'Also:'},
            cards([ice]),
          ],
        ),
      },
      taps: FrontReplyTaps(),
      shownIds: {'t-ice'},
    );

    final lists = tester.widgetList<FrontEntityPreviewList>(
      find.byType(FrontEntityPreviewList),
    );
    expect(lists.single.references, [feed]);
    expect(find.text('words: Also:'), findsOneWidget);
  });

  testWidgets("a lookup's data that cannot be read draws nothing", (
    tester,
  ) async {
    await pumpReplySurfaces(tester, {
      'a1': const FrontReplySurface({
        'version': '1.0',
        'createSurface': {
          'surfaceId': 'a1',
          'catalogId': frontReplyCatalogId,
          'dataModel': {
            'loggedTime': {'range': 'soon'},
            'pullRequests': {'range': 'soon'},
            'closedTasks': 'none',
          },
          'components': [
            {
              'id': 'root',
              'component': 'Reply',
              'children': ['c0', 'c1', 'c2', 'c3'],
            },
            {'id': 'c0', 'component': 'Text', 'text': 'Hm.'},
            {
              'id': 'c1',
              'component': 'LoggedTimeChart',
              'data': {'@path': '/loggedTime'},
            },
            {
              'id': 'c2',
              'component': 'PullRequestChart',
              'data': {'@path': '/pullRequests'},
            },
            {
              'id': 'c3',
              'component': 'ClosedTasks',
              'data': {'@path': '/closedTasks'},
            },
          ],
        },
      }),
    }, taps: FrontReplyTaps());

    expect(find.text('words: Hm.'), findsOneWidget);
    expect(find.byType(FrontLoggedTimeChartCard), findsNothing);
    expect(find.byType(FrontPullRequestChartCard), findsNothing);
    expect(find.byType(FrontClosedTaskList), findsNothing);
  });

  test('the scope tells its dependents only when what it does changes', () {
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [frontReplyCatalog],
    );
    addTearDown(processor.dispose);
    SurfaceModel<ComponentImplementation> surface(String id) {
      processor.processMessages([
        FrontReplySurface.compose(surfaceId: id, components: const []).message,
      ]);
      return processor.model.getSurface(id)!;
    }

    final surfaceA = surface('a');
    final surfaceB = surface('b');
    Widget prose(String markdown) => Text(markdown);
    void open(FrontEntityReference _) {}
    void openTask(String _) {}
    FrontReplyScope scope({
      SurfaceModel<ComponentImplementation>? on,
      Widget Function(String)? words,
      Set<String> shown = const {'t-1'},
      bool canReply = true,
    }) => FrontReplyScope(
      surface: on ?? surfaceA,
      prose: words ?? prose,
      onOpen: open,
      onOpenTask: openTask,
      shownIds: shown,
      canReply: canReply,
      child: const SizedBox.shrink(),
    );

    final base = scope();
    expect(base.updateShouldNotify(scope(shown: {'t-1'})), isFalse);
    expect(base.updateShouldNotify(scope(on: surfaceB)), isTrue);
    expect(base.updateShouldNotify(scope(words: Text.new)), isTrue);
    expect(base.updateShouldNotify(scope(shown: {'t-2'})), isTrue);
    expect(base.updateShouldNotify(scope(canReply: false)), isTrue);
  });

  group('CitedPoints', () {
    final note = FrontCitedSource(
      id: 'e-hinge',
      kind: QuerySourceKind.text,
      label: 'Colony chores',
      date: DateTime.utc(2026, 10, 27, 17),
      quote: 'Feeder hinge: this week, for real.',
    );
    final memo = FrontCitedSource(
      id: 'e-memo',
      kind: QuerySourceKind.recording,
      label: '2026-10-20_07-15-02-311.m4a',
      date: DateTime.utc(2026, 10, 20, 7),
      quote: 'I really do need to fix that hinge.',
      transcript: true,
    );
    FrontReplySurface answer(List<FrontCitedPoint> points) =>
        FrontReplySurface.citedAnswer(surfaceId: 'j1', points: points);

    testWidgets('draws each point in her words with the entries it rests on '
        'right under it, in order', (tester) async {
      await pumpReplySurfaces(tester, {
        'j1': answer([
          FrontCitedPoint(text: 'Promised twice.', sources: [note, memo]),
          const FrontCitedPoint(text: 'And no plan since.'),
        ]),
      }, taps: FrontReplyTaps());

      double top(Finder finder) => tester.getTopLeft(finder).dy;
      final first = find.text('words: Promised twice.');
      final second = find.text('words: And no plan since.');
      final noteRow = find.byKey(const ValueKey('front-cited-source-0-0'));
      final memoRow = find.byKey(const ValueKey('front-cited-source-0-1'));
      expect(top(first), lessThan(top(noteRow)));
      expect(top(noteRow), lessThan(top(memoRow)));
      expect(top(memoRow), lessThan(top(second)));
      // The recording is named for what it is, never its file name.
      expect(find.textContaining('.m4a', findRichText: true), findsNothing);
      expect(
        find.descendant(
          of: memoRow,
          matching: find.textContaining(
            'Recording transcript',
            findRichText: true,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a tap on an entry opens it', (tester) async {
      final taps = FrontReplyTaps();
      await pumpReplySurfaces(tester, {
        'j1': answer([
          FrontCitedPoint(text: 'Promised.', sources: [note, memo]),
        ]),
      }, taps: taps);

      await tester.tap(find.byKey(const ValueKey('front-cited-source-0-1')));

      expect(taps.openedSources.map((s) => s.id), ['e-memo']);
    });

    testWidgets('without a way to open them the entries are still named, '
        'just not tappable', (tester) async {
      await pumpReplySurfaces(
        tester,
        {
          'j1': answer([
            FrontCitedPoint(text: 'Promised.', sources: [note]),
          ]),
        },
        taps: FrontReplyTaps(),
        canOpenSources: false,
      );

      final row = find.byKey(const ValueKey('front-cited-source-0-0'));
      expect(row, findsOneWidget);
      expect(
        tester
            .widget<InkWell>(
              find.descendant(of: row, matching: find.byType(InkWell)),
            )
            .onTap,
        isNull,
      );
    });

    testWidgets('two passages of one entry under one point are both '
        'drawn', (tester) async {
      await pumpReplySurfaces(tester, {
        'j1': answer([
          FrontCitedPoint(
            text: 'Promised twice.',
            sources: [
              note,
              FrontCitedSource(
                id: note.id,
                kind: note.kind,
                label: note.label,
                date: note.date,
                quote: 'Hinge, for real this time.',
              ),
            ],
          ),
        ]),
      }, taps: FrontReplyTaps());

      expect(tester.takeException(), isNull);
      expect(find.byType(FrontCitedSourceRow), findsNWidgets(2));
      expect(find.text('Hinge, for real this time.'), findsOneWidget);
    });

    testWidgets('no points draw nothing', (tester) async {
      await pumpReplySurfaces(tester, {
        'j1': answer(const []),
      }, taps: FrontReplyTaps());

      expect(find.byType(FrontCitedSourceRow), findsNothing);
      expect(find.textContaining('words:'), findsNothing);
    });
  });
}

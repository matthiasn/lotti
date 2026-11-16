import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_inbox_way.dart';
import 'package:lotti/features/front_agent/model/front_task_draft.dart';
import 'package:lotti/features/front_agent/ui/a2ui/front_reply_catalog.dart';
import 'package:lotti/features/front_agent/ui/a2ui/front_reply_surfaces.dart';
import 'package:lotti/features/front_agent/ui/front_cited_source_row.dart';
import 'package:lotti/features/front_agent/ui/front_door_card.dart';
import 'package:lotti/features/front_agent/ui/front_door_ways.dart';
import 'package:lotti/features/front_agent/ui/front_task_setup.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:lotti/widgets/markdown/citation_badge.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  final claimedAt = DateTime.utc(2026, 10, 24, 9);

  FrontDoorRecord record({
    required int index,
    required String text,
    FrontDestinationKind kind = FrontDestinationKind.task,
    String? ownerTitle = 'Garden',
    FrontDoorOutcome? outcome,
    FrontTaskDraft? task,
    List<FrontInboxWay>? ways,
  }) => FrontDoorRecord(
    segmentIndex: index,
    text: text,
    kind: kind,
    destinationId: kind.needsId ? 'id-$index' : null,
    ownerTitle: ownerTitle,
    status: outcome == null ? FrontDoorStatus.claimed : FrontDoorStatus.done,
    claimedAt: claimedAt,
    outcome: outcome,
    task: task,
    ways: ways,
  );

  FrontDoorEntry entry(FrontDoorRecord record, {String? specialistReply}) =>
      FrontDoorEntry(
        doorId: 'd:door:${record.segmentIndex}',
        record: record,
        specialistReply: specialistReply,
      );

  late List<(String, String)> acted;

  /// How each task made from the card was set up.
  late List<FrontTaskChoices> madeWith;

  FrontDoorActions actions() => FrontDoorActions(
    onFile: (id) => acted.add(('file', id)),
    onDecline: (id) => acted.add(('decline', id)),
    onUndoDecline: (id) => acted.add(('undo', id)),
    onTakeBack: (id) => acted.add(('take-back', id)),
    onOpen: (door) => acted.add(('open', door.doorId)),
    onMakeTask: (id, choices) {
      acted.add(('task', id));
      madeWith.add(choices);
    },
    onMakePrompt: (id, choices) {
      acted.add(('prompt', id));
      madeWith.add(choices);
    },
    onMakeEvent: (id) => acted.add(('event', id)),
    onSaveNote: (id) => acted.add(('note', id)),
    onStartGoal: (door) => acted.add(('goal', door.doorId)),
    onNewProject: (door) => acted.add(('project', door.doorId)),
    onPlanDay: (door) => acted.add(('day', door.doorId)),
    onOpenEvidence: (evidence) => acted.add(('source', evidence.source.id)),
    onOpenLink: (url) => acted.add(('link', url)),
  );

  setUp(() {
    acted = [];
    madeWith = [];
  });

  Future<void> pump(
    WidgetTester tester,
    List<FrontDoorEntry> doors, {
    bool withActions = true,
    Set<String> busy = const {},
    Set<String> failed = const {},
    QueryAccessSnapshot? journalAccess,
    // The items a cover can be drawn for: by default, the first.
    Set<String> coverArtDoorIds = const {'d:door:0'},
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        FrontDoorCard(
          doors: doors,
          actions: withActions ? actions() : null,
          busyDoorIds: busy,
          failedDoorIds: failed,
          coverArtDoorIds: coverArtDoorIds,
          journalAccess: journalAccess,
        ),
      ),
    );
    await tester.pump();
  }

  /// The card's words: the user's as text, an answer as its Markdown.
  String titleOf(WidgetTester tester, int index) =>
      switch (tester.widget(find.byKey(ValueKey('front-door-text-$index')))) {
        final Text text => text.data!,
        final AgentMarkdownView markdown => markdown.text,
        final other => throw StateError('unexpected ${other.runtimeType}'),
      };
  Text statusWidget(WidgetTester tester, int index) =>
      tester.widget<Text>(find.byKey(ValueKey('front-door-status-$index')));
  String statusOf(WidgetTester tester, int index) =>
      statusWidget(tester, index).data!;
  Icon glyph(WidgetTester tester, int index) =>
      tester.widget<Icon>(find.byKey(ValueKey('front-door-glyph-$index')));
  Finder menu(int index) => find.byKey(ValueKey('front-door-menu-$index'));
  DesignSystemButton button(WidgetTester tester, String name, int index) =>
      tester.widget<DesignSystemButton>(
        find.byKey(ValueKey('front-door-$name-$index')),
      );

  /// The other ways an inbox item's card lists, once opened.
  /// The choices of the waiting inbox item at [index].
  FrontDoorWays waysOf(WidgetTester tester, [int index = 0]) =>
      tester.widget<FrontDoorWays>(
        find.descendant(
          of: find.byKey(ValueKey('front-door-$index')),
          matching: find.byType(FrontDoorWays),
        ),
      );

  /// What the card offers for the item at [index]: a waiting inbox item's
  /// choices, which are in sight, with its way out last — or, for any other
  /// card, the rows of its overflow menu, which this opens.
  Future<List<String>> openMenu(WidgetTester tester, int index) async {
    if (menu(index).evaluate().isEmpty) {
      final ways = waysOf(tester, index);
      return [for (final way in ways.ways) way.label, ways.leave.label];
    }
    await tester.tap(menu(index));
    await tester.pumpAndSettle();
    final trigger = tester.widget<DesignSystemContextMenuButton>(menu(index));
    return [for (final item in trigger.items) item.label];
  }

  Future<void> tapItem(WidgetTester tester, String name, int index) async {
    await tester.tap(find.byKey(ValueKey('front-door-$name-$index')));
    await tester.pumpAndSettle();
  }

  group('an answer is Markdown', () {
    const owners = FrontDoorAnswer(
      text:
          '**Two steps** left:\n\n- Count the rookery\n'
          '- Tell [Feed the penguins](lotti://task/feed-1)',
      summaryBased: false,
      incomplete: false,
    );

    testWidgets('an owner answer shows its formatting, not its marks, and '
        'the user words stay plain text', (tester) async {
      await pump(tester, [
        entry(record(index: 0, text: 'What is left?', outcome: owners)),
        entry(record(index: 1, text: 'Paint **the** shed')),
      ]);

      final answer = find.byKey(const ValueKey('front-door-text-0'));
      expect(tester.widget(answer), isA<AgentMarkdownView>());
      // The marks are gone from what is drawn; the words remain.
      expect(
        find.descendant(of: answer, matching: find.textContaining('**')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: answer,
          matching: find.textContaining('Two steps', findRichText: true),
        ),
        findsWidgets,
      );
      // A waiting door's words are the user's, verbatim: text, marks kept.
      final words = find.byKey(const ValueKey('front-door-text-1'));
      expect(tester.widget<Text>(words).data, 'Paint **the** shed');
    });

    testWidgets('a link in an answer opens through the surface', (
      tester,
    ) async {
      await pump(tester, [
        entry(record(index: 0, text: 'What is left?', outcome: owners)),
      ]);

      await tester.tap(
        find
            .descendant(
              of: find.byKey(const ValueKey('front-door-text-0')),
              matching: find.textContaining(
                'Feed the penguins',
                findRichText: true,
              ),
            )
            .last,
      );
      await tester.pump();

      expect(acted, [('link', 'lotti://task/feed-1')]);
    });

    testWidgets("a specialist's mirrored reply is Markdown too", (
      tester,
    ) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'How is the swim goal?',
            kind: FrontDestinationKind.goal,
            outcome: const FrontDoorChatTurn(
              specialistAgentId: 'goal-agent',
              specialistMessageId: 'm-1',
            ),
          ),
          specialistReply: '*On track* this week.',
        ),
      ]);

      expect(
        tester
            .widget<AgentMarkdownView>(
              find.byKey(const ValueKey('front-door-text-0')),
            )
            .text,
        '*On track* this week.',
      );
    });
  });

  group('her journal answer', () {
    final category = categoryMindfulness;
    final note = testTextEntry.copyWith(
      meta: testTextEntry.meta.copyWith(
        id: 'feeder-note',
        categoryId: category.id,
        private: false,
      ),
    );
    final source = QuerySourceRef(
      id: note.meta.id,
      private: false,
      categoryPrivate: false,
      categoryId: category.id,
    );
    final evidence = QueryEvidence(
      source: source,
      kind: QuerySourceKind.text,
      label: 'Feeder note',
      sourceDate: DateTime(2026, 10, 20),
      textVersion: 'entryText',
      fingerprint: 'f',
      sourceText: 'The seam walk comes after the feeder repair.',
      start: 0,
      end: 13,
      summary: 'The order of the work',
    );
    QueryAccessSnapshot access({bool privateNote = false}) =>
        QueryAccessSnapshot(
          showPrivate: false,
          categories: {category.id: category},
          entries: {
            note.meta.id: note.copyWith(
              meta: note.meta.copyWith(private: privateNote),
            ),
          },
        );
    FrontDoorEntry answered({bool incomplete = false}) => entry(
      record(
        index: 0,
        text: 'How is the garden?',
        kind: FrontDestinationKind.journal,
        ownerTitle: null,
        outcome: FrontDoorAnswer(
          text: 'After the feeder repair [1].',
          summaryBased: false,
          incomplete: incomplete,
          fromJournal: true,
          evidence: [evidence],
          dependencies: [source],
        ),
      ),
    );

    testWidgets('shows her answer, attributed to the journal, with the '
        'passages it cites; a source opens on a tap', (tester) async {
      await pump(tester, [answered(incomplete: true)], journalAccess: access());

      expect(titleOf(tester, 0), 'After the feeder repair [1].');
      expect(statusOf(tester, 0), 'From your journal · may be incomplete');
      expect(glyph(tester, 0).icon, LottiIcons.search);
      final number = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('front-door-source-0-0')),
          matching: find.text('1'),
        ),
      );
      expect(
        number.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
        reason: 'numbers of different widths would stagger the passages',
      );
      expect(
        find.text('Feeder note · Oct 20, 2026 00:00', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('The seam walk'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('front-door-source-0-0')));
      expect(acted, [('source', 'feeder-note')]);
    });

    testWidgets('sets its sources apart under a heading, and a citation in '
        'the words opens the source it names', (tester) async {
      await pump(tester, [answered()], journalAccess: access());

      final heading = find.byKey(const ValueKey('front-door-sources-0'));
      expect(tester.widget<Text>(heading).data, 'Sources');
      expect(
        tester.getTopLeft(heading).dy,
        greaterThan(
          tester
              .getBottomLeft(find.byKey(const ValueKey('front-door-text-0')))
              .dy,
        ),
      );
      expect(
        tester.getTopLeft(heading).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('front-door-source-0-0')))
              .dy,
        ),
      );

      // The badge in the words, not the one before the listed source.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('front-door-text-0')),
          matching: find.byType(CitationBadge),
        ),
      );
      expect(acted, [('source', 'feeder-note')]);
    });

    testWidgets('a citation naming no listed source opens nothing', (
      tester,
    ) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'How is the garden?',
            kind: FrontDestinationKind.journal,
            ownerTitle: null,
            outcome: FrontDoorAnswer(
              text: 'After the feeder repair [2].',
              summaryBased: false,
              incomplete: false,
              fromJournal: true,
              evidence: [evidence],
              dependencies: [source],
            ),
          ),
        ),
      ], journalAccess: access());

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('front-door-text-0')),
          matching: find.byType(CitationBadge),
        ),
      );
      expect(acted, isEmpty);
    });

    testWidgets('names a recording by what it is and when, never by its file '
        'name', (tester) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'How is the garden?',
            kind: FrontDestinationKind.journal,
            ownerTitle: null,
            outcome: FrontDoorAnswer(
              text: 'After the feeder repair [1].',
              summaryBased: false,
              incomplete: false,
              fromJournal: true,
              evidence: [
                evidence.copyWith(
                  kind: QuerySourceKind.recording,
                  label: '2026-10-20_07-15-02-311.m4a',
                  textVersion: 'transcript:t1',
                ),
              ],
              dependencies: [source],
            ),
          ),
        ),
      ], journalAccess: access());

      final title = tester.widget<Text>(
        find
            .descendant(
              of: find.byKey(const ValueKey('front-door-source-0-0')),
              matching: find.byType(Text),
            )
            .at(1),
      );
      expect(
        title.textSpan!.toPlainText(),
        'Recording transcript · '
        'Oct 20, 2026 00:00',
      );
      expect(find.textContaining('.m4a'), findsNothing);
    });

    /// The card as the chat draws it: inside the thread's surfaces, which
    /// hold the one composed for this answer's points.
    Future<void> pumpInThread(
      WidgetTester tester,
      FrontDoorEntry door,
      QueryAccessSnapshot journalAccess,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          FrontReplySurfaces(
            surfaces: FrontChatThread(
              messages: const [],
              doorsByMessageId: {
                'u1': [door],
              },
            ).surfaces,
            logger: MockDomainLogger(),
            onQuickReply: (_) {},
            child: FrontDoorCard(
              doors: [door],
              actions: actions(),
              journalAccess: journalAccess,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('in the chat, draws as its points through the reply '
        'catalog, each with the entry it rests on, which opens on a tap', (
      tester,
    ) async {
      await pumpInThread(tester, answered(), access());

      expect(find.byType(A2uiSurface), findsOneWidget);
      expect(
        tester
            .widget<AgentMarkdownView>(
              find.descendant(
                of: find.byType(A2uiSurface),
                matching: find.byType(AgentMarkdownView),
              ),
            )
            .text,
        'After the feeder repair.',
      );
      // The entry sits with its point; no list of sources after the words.
      expect(find.byKey(const ValueKey('front-door-sources-0')), findsNothing);
      expect(find.byType(CitationBadge), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('front-cited-source-0-0')),
      );
      expect(acted, [('source', 'feeder-note')]);
    });

    testWidgets('in the chat, a link in a point opens as any link of hers '
        'does, and the surface opens nothing but links and its sources', (
      tester,
    ) async {
      await pumpInThread(
        tester,
        entry(
          record(
            index: 0,
            text: 'How is the garden?',
            kind: FrontDestinationKind.journal,
            ownerTitle: null,
            outcome: FrontDoorAnswer(
              text: 'After the [feeder](/journal/feeder-note) repair [1].',
              summaryBased: false,
              incomplete: false,
              fromJournal: true,
              evidence: [evidence],
              dependencies: [source],
            ),
          ),
        ),
        access(),
      );

      await tester.tap(find.text('feeder'));
      expect(acted, [('link', '/journal/feeder-note')]);

      // Its points carry no entity cards: those callbacks do nothing.
      final scope = tester.widget<FrontReplyScope>(
        find.byType(FrontReplyScope),
      );
      scope.onOpen(
        const FrontEntityReference(
          kind: FrontEntityKind.task,
          id: 't',
          title: 'T',
        ),
      );
      scope.onOpenTask('t');
      expect(acted, [('link', '/journal/feeder-note')]);
    });

    testWidgets('in the chat, a hidden answer draws no points at all', (
      tester,
    ) async {
      await pumpInThread(tester, answered(), access(privateNote: true));

      expect(find.byType(A2uiSurface), findsNothing);
      expect(find.byType(FrontCitedSourceRow), findsNothing);
      expect(
        titleOf(tester, 0),
        'Hidden: it draws on something you can no longer see.',
      );
    });

    testWidgets('is hidden once a source it rests on is no longer visible, '
        'and until that is known', (tester) async {
      for (final journalAccess in [access(privateNote: true), null]) {
        await pump(tester, [answered()], journalAccess: journalAccess);

        expect(
          titleOf(tester, 0),
          'Hidden: it draws on something you can no longer see.',
        );
        expect(find.text('Feeder note'), findsNothing);
      }
    });

    testWidgets('while it searches, and with no model to answer, says so in '
        "the journal's words", (tester) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'How is the garden?',
            kind: FrontDestinationKind.journal,
            ownerTitle: null,
          ),
        ),
        entry(
          record(
            index: 1,
            text: 'And the feeder?',
            kind: FrontDestinationKind.journal,
            ownerTitle: null,
            outcome: const FrontDoorSkipped(
              FrontDoorSkipReason.inferenceUnavailable,
            ),
          ),
        ),
      ]);

      expect(statusOf(tester, 0), 'Searching your journal…');
      expect(statusOf(tester, 1), 'No AI setup can answer from your journal.');
    });
  });

  testWidgets('every card is a tile, the words, a status line; an answer is '
      "the owner's text with its attribution and caveats, and offers "
      'nothing to do', (tester) async {
    await pump(tester, [
      entry(
        record(
          index: 0,
          text: 'How is the garden?',
          outcome: const FrontDoorAnswer(
            text: 'The seam walk is next.',
            summaryBased: true,
            incomplete: true,
          ),
        ),
      ),
      entry(
        record(
          index: 1,
          text: 'And the fence?',
          kind: FrontDestinationKind.project,
          ownerTitle: 'Fence',
          outcome: const FrontDoorAnswer(
            text: 'Painted on Tuesday.',
            summaryBased: false,
            incomplete: false,
          ),
        ),
      ),
    ]);

    expect(titleOf(tester, 0), 'The seam walk is next.');
    expect(
      statusOf(tester, 0),
      'From Garden · from summaries · may be incomplete',
    );
    expect(glyph(tester, 0).icon, LottiIcons.checkboxChecked);
    expect(titleOf(tester, 1), 'Painted on Tuesday.');
    expect(statusOf(tester, 1), 'From Fence');
    expect(glyph(tester, 1).icon, LottiIcons.folder);
    // The words outrank the status by size.
    final title = tester.widget<AgentMarkdownView>(
      find.byKey(const ValueKey('front-door-text-0')),
    );
    expect(
      title.style!.fontSize,
      greaterThan(statusWidget(tester, 0).style!.fontSize!),
    );
    // One hairline between two cards.
    expect(find.byType(DesignSystemDivider), findsOneWidget);
    expect(find.byType(DesignSystemButton), findsNothing);
    expect(find.byType(DesignSystemContextMenuButton), findsNothing);
  });

  testWidgets("a specialist's reply is the card's text once it has landed, "
      'and the words await it until then', (tester) async {
    await pump(tester, [
      entry(
        record(
          index: 0,
          text: 'Swim?',
          kind: FrontDestinationKind.goal,
          ownerTitle: 'Swim 2 km a day',
          outcome: const FrontDoorChatTurn(
            specialistAgentId: 'goal-swim',
            specialistMessageId: 'gm-1',
          ),
        ),
        specialistReply: 'Two of three swims done.',
      ),
      entry(
        record(
          index: 1,
          text: 'Pip?',
          kind: FrontDestinationKind.person,
          ownerTitle: 'Pip',
          outcome: const FrontDoorChatTurn(
            specialistAgentId: 'relationship_agent:pip',
            specialistMessageId: 'pm-1',
          ),
        ),
      ),
    ]);

    expect(titleOf(tester, 0), 'Two of three swims done.');
    expect(statusOf(tester, 0), 'From Swim 2 km a day');
    expect(glyph(tester, 0).icon, LottiIcons.focus);
    expect(titleOf(tester, 1), 'Pip?');
    expect(statusOf(tester, 1), 'Pip is still replying…');
    expect(glyph(tester, 1).icon, LottiIcons.person);
  });

  testWidgets('every way a segment went nowhere is its status, and a failed '
      'door carries the warning', (tester) async {
    await pump(tester, [
      entry(record(index: 0, text: 'Garden?')),
      entry(
        record(
          index: 2,
          text: 'Pip?',
          kind: FrontDestinationKind.person,
          ownerTitle: 'Pip',
          outcome: const FrontDoorSkipped(FrontDoorSkipReason.noAgent),
        ),
      ),
      entry(
        record(
          index: 3,
          text: 'Relocation?',
          kind: FrontDestinationKind.project,
          ownerTitle: 'Relocation',
          outcome: const FrontDoorSkipped(
            FrontDoorSkipReason.inferenceUnavailable,
          ),
        ),
      ),
      entry(
        record(
          index: 4,
          text: 'Move the dentist to tomorrow.',
          kind: FrontDestinationKind.day,
          ownerTitle: null,
          outcome: const FrontDoorSkipped(FrontDoorSkipReason.noDoor),
        ),
      ),
      entry(
        record(
          index: 5,
          text: 'Fence?',
          outcome: const FrontDoorFailed('StateError'),
        ),
      ),
    ]);

    expect(statusOf(tester, 0), 'Asking Garden…');
    expect(statusOf(tester, 2), 'Pip has no agent to ask yet.');
    expect(statusOf(tester, 3), 'Relocation has no working AI setup.');
    expect(statusOf(tester, 4), 'Nowhere to take this yet.');
    expect(glyph(tester, 4).icon, LottiIcons.calendar);
    expect(statusOf(tester, 5), 'Asking Garden failed.');
    expect(glyph(tester, 5).icon, LottiIcons.warning);
    for (final index in [0, 2, 3, 4, 5]) {
      expect(titleOf(tester, index), isNot(contains('StateError')));
    }
    expect(find.textContaining('StateError'), findsNothing);
    expect(find.byType(DesignSystemButton), findsNothing);
    expect(find.byType(DesignSystemContextMenuButton), findsNothing);
  });

  testWidgets('words meant for her, should their door reach the card past '
      'the thread builder, settle quietly: no task, no tap, no overflow', (
    tester,
  ) async {
    await pump(tester, [
      entry(
        record(
          index: 0,
          text: 'Who said I was recalibrating them?',
          kind: FrontDestinationKind.you,
          ownerTitle: null,
          outcome: const FrontDoorSkipped(FrontDoorSkipReason.noDoor),
        ),
      ),
    ]);

    expect(statusOf(tester, 0), 'Nowhere to take this yet.');
    expect(glyph(tester, 0).icon, LottiIcons.inbox);
    expect(find.text('Make it a task'), findsNothing);
    expect(find.byType(DesignSystemButton), findsNothing);
    expect(find.byType(DesignSystemContextMenuButton), findsNothing);
  });

  group('a proposal', () {
    testWidgets('shows the words, names the task, files on the one filled '
        'tap, and keeps the way out in the overflow', (tester) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'The hinge arrived.',
            outcome: const FrontDoorProposal(ownerId: 'id-0'),
          ),
        ),
      ]);

      expect(titleOf(tester, 0), 'The hinge arrived.');
      expect(statusOf(tester, 0), 'File this under Garden?');
      expect(glyph(tester, 0).icon, LottiIcons.checkboxChecked);
      final file = button(tester, 'file', 0);
      expect(file.variant, DesignSystemButtonVariant.primary);
      expect(file.label, 'File it');
      expect(find.byType(DesignSystemButton), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('front-door-file-0')));
      expect(await openMenu(tester, 0), ['Somewhere else']);
      await tapItem(tester, 'decline', 0);
      expect(acted, [('file', 'd:door:0'), ('decline', 'd:door:0')]);
    });

    testWidgets('that was taken back says so and offers the tap again', (
      tester,
    ) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'The hinge arrived.',
            outcome: const FrontDoorProposal(ownerId: 'id-0', generation: 1),
          ),
        ),
      ]);
      expect(statusOf(tester, 0), 'Taken back out of Garden. File it again?');
      expect(find.byKey(const ValueKey('front-door-file-0')), findsOneWidget);
    });

    testWidgets('while its action is in flight the tap is loading and the '
        'overflow inert; after a failure the status says so in the error '
        'ink and the tap reads as a retry', (tester) async {
      final doors = [
        entry(
          record(
            index: 0,
            text: 'The hinge arrived.',
            outcome: const FrontDoorProposal(ownerId: 'id-0'),
          ),
        ),
      ];
      await pump(tester, doors, busy: {'d:door:0'});
      expect(button(tester, 'file', 0).isLoading, isTrue);
      expect(button(tester, 'file', 0).onPressed, isNull);
      // The loading tap animates, so no settle: a few frames open the menu.
      await tester.tap(menu(0));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byKey(const ValueKey('front-door-decline-0')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(acted, isEmpty);

      await pump(tester, doors, failed: {'d:door:0'});
      expect(statusOf(tester, 0), 'That did not go through.');
      final status = statusWidget(tester, 0);
      final tokens = tester.element(find.byType(FrontDoorCard)).designTokens;
      expect(status.style!.color, tokens.colors.alert.error.ink);
      expect(button(tester, 'file', 0).label, 'Try again');
      await tester.tap(find.byKey(const ValueKey('front-door-file-0')));
      expect(acted, [('file', 'd:door:0')]);
    });
  });

  group('making an inbox item a task', () {
    // A task the user asked for: she drafted it.
    FrontDoorEntry waiting({
      FrontTaskDraft? task = const FrontTaskDraft(title: 'Count the chicks'),
      FrontDoorOutcome outcome = const FrontDoorInbox(
        newKind: FrontNewKind.task,
      ),
      int index = 0,
    }) => entry(
      record(
        index: index,
        text: 'Count the chicks, urgent.',
        kind: FrontDestinationKind.newThing,
        ownerTitle: null,
        outcome: outcome,
        task: task,
      ),
    );

    testWidgets('asks how in place of its status, action and overflow, set '
        'to what she read, and nothing is made until create', (tester) async {
      await pump(tester, [
        waiting(
          task: const FrontTaskDraft(
            title: 'Count the chicks',
            priority: TaskPriority.p0Urgent,
          ),
        ),
      ]);

      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await tester.pump();

      expect(find.byKey(FrontTaskSetupKeys.ask(0)), findsOne);
      expect(find.byKey(const ValueKey('front-door-status-0')), findsNothing);
      expect(find.byKey(const ValueKey('front-door-task-0')), findsNothing);
      expect(menu(0), findsNothing);
      final setup = tester.widget<FrontTaskSetup>(find.byType(FrontTaskSetup));
      expect(
        setup.initial,
        const FrontTaskChoices(
          start: FrontTaskStart.open,
          priority: TaskPriority.p0Urgent,
        ),
      );
      expect(acted, isEmpty);
      // She heard a priority, and says so.
      expect(setup.heard, isTrue);

      await tester.tap(find.byKey(FrontTaskSetupKeys.create(0)));
      expect(acted, [('task', 'd:door:0')]);
      expect(madeWith, [setup.initial]);
    });

    group('the cover art chip', () {
      FrontDoorEntry inbox() => entry(
        record(
          index: 0,
          text: 'Check the ice-pad weather window.',
          kind: FrontDestinationKind.newThing,
          ownerTitle: null,
          outcome: const FrontDoorInbox(newKind: FrontNewKind.task),
          task: const FrontTaskDraft(
            title: 'Check the ice-pad weather window',
          ),
        ),
      );

      Future<void> openSetup(WidgetTester tester) async {
        await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
        await tester.pump();
        await tester.pump();
      }

      testWidgets('is offered for an item a cover can be drawn for', (
        tester,
      ) async {
        await pump(tester, [inbox()]);
        await openSetup(tester);

        expect(find.byKey(FrontTaskSetupKeys.cover(0)), findsOne);
      });

      testWidgets('is not offered for one it cannot, and the task is made '
          'without one', (tester) async {
        await pump(tester, [inbox()], coverArtDoorIds: const {});
        await openSetup(tester);

        expect(find.byKey(FrontTaskSetupKeys.cover(0)), findsNothing);
        await tester.tap(find.byKey(FrontTaskSetupKeys.create(0)));
        await tester.pump();
        expect(madeWith.single.coverArt, isFalse);
      });

      testWidgets('is per item: another item on the card being drawable '
          'offers this one nothing', (tester) async {
        await pump(
          tester,
          [inbox()],
          coverArtDoorIds: const {'d:door:1'},
        );
        await openSetup(tester);

        expect(find.byKey(FrontTaskSetupKeys.cover(0)), findsNothing);
      });

      testWidgets('appears in a setup already open once it is known one can '
          'be drawn', (tester) async {
        await pump(tester, [inbox()], coverArtDoorIds: const {});
        await openSetup(tester);
        expect(find.byKey(FrontTaskSetupKeys.cover(0)), findsNothing);
        // The setup is there and usable meanwhile.
        expect(find.byKey(FrontTaskSetupKeys.create(0)), findsOne);

        await pump(tester, [inbox()]);

        expect(find.byKey(FrontTaskSetupKeys.cover(0)), findsOne);
        // Still the setup that was open, not a card pumped afresh.
        expect(find.byKey(FrontTaskSetupKeys.ask(0)), findsOne);
      });
    });

    testWidgets('cancel goes back to the card as it was', (tester) async {
      await pump(tester, [waiting()]);
      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await tester.pump();

      await tester.tap(find.byKey(FrontTaskSetupKeys.back(0)));
      await tester.pump();

      expect(find.byType(FrontTaskSetup), findsNothing);
      expect(statusOf(tester, 0), 'Where should this go?');
      expect(find.byType(FrontDoorWays), findsOne);
      expect(acted, isEmpty);
    });

    testWidgets('the setup spins while the task is made and says so when it '
        'was not', (tester) async {
      await pump(tester, [waiting()]);
      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await tester.pump();

      await pump(tester, [waiting()], busy: {'d:door:0'});
      var setup = tester.widget<FrontTaskSetup>(find.byType(FrontTaskSetup));
      expect(setup.busy, isTrue);
      expect(setup.failed, isFalse);

      await pump(tester, [waiting()], failed: {'d:door:0'});
      setup = tester.widget<FrontTaskSetup>(find.byType(FrontTaskSetup));
      expect(setup.busy, isFalse);
      expect(setup.failed, isTrue);
    });

    testWidgets('an item made, then taken back, offers make it a task '
        'afresh rather than the setup it left', (tester) async {
      await pump(tester, [waiting()]);
      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await tester.pump();

      await pump(tester, [
        waiting(outcome: const FrontDoorTaskCreated(taskId: 't-1')),
      ]);
      expect(find.byType(FrontTaskSetup), findsNothing);

      await pump(tester, [waiting()]);
      expect(find.byType(FrontTaskSetup), findsNothing);
      expect(find.byKey(const ValueKey('front-door-task-0')), findsOne);
    });

    testWidgets('a drafted task is headed by the title she read, set up or '
        'not, so a "yes, make it a task" is never the headline', (
      tester,
    ) async {
      await pump(tester, [waiting()]);
      expect(titleOf(tester, 0), 'Count the chicks');

      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await tester.pump();
      expect(titleOf(tester, 0), 'Count the chicks');

      await tester.tap(find.byKey(FrontTaskSetupKeys.back(0)));
      await tester.pump();
      expect(titleOf(tester, 0), 'Count the chicks');
    });

    testWidgets('with no title read, the setup — opened from the overflow — '
        'keeps the words as they were', (tester) async {
      await pump(tester, [waiting(task: null)]);
      expect(titleOf(tester, 0), 'Count the chicks, urgent.');
      await openMenu(tester, 0);
      await tapItem(tester, 'task', 0);
      expect(find.byType(FrontTaskSetup), findsOne);
      expect(titleOf(tester, 0), 'Count the chicks, urgent.');
    });

    testWidgets('words that set nothing get a plain ask, not a claim she '
        'heard something', (tester) async {
      for (final task in [null, const FrontTaskDraft(title: 'Count')]) {
        await pump(tester, [waiting(task: task)]);
        if (task == null) {
          await openMenu(tester, 0);
          await tapItem(tester, 'task', 0);
        } else {
          await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
          await tester.pump();
        }
        expect(
          tester.widget<FrontTaskSetup>(find.byType(FrontTaskSetup)).heard,
          isFalse,
        );
        await tester.tap(find.byKey(FrontTaskSetupKeys.back(0)));
        await tester.pump();
      }
    });

    testWidgets('while one item is set up, its create is the one filled '
        'button on the card: no other item has one', (tester) async {
      await pump(tester, [waiting(), waiting(index: 1)]);
      List<DesignSystemButton> filled() => [
        for (final button in tester.widgetList<DesignSystemButton>(
          find.byType(DesignSystemButton),
        ))
          if (button.variant == DesignSystemButtonVariant.primary) button,
      ];
      expect(filled(), isEmpty);

      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await tester.pump();

      expect(filled().single.label, 'Create task');
      // The other item still offers its ways.
      expect(waysOf(tester, 1).ways.first.onTap, isNotNull);
    });

    testWidgets("on a phone, create task ends at the card's edge, where "
        "another item's rows end", (tester) async {
      // A phone's width with room for the two buttons side by side in the
      // test font, whose glyphs are a full em wide.
      tester.view
        ..physicalSize = const Size(430, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, [waiting(), waiting(index: 1)]);
      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await tester.pump();

      // Stacked under the chips, as on a phone.
      expect(
        tester.getRect(find.byKey(FrontTaskSetupKeys.create(0))).top,
        greaterThan(
          tester.getRect(find.byKey(FrontTaskSetupKeys.status(0))).bottom,
        ),
      );
      expect(
        tester.getRect(find.byKey(FrontTaskSetupKeys.create(0))).right,
        moreOrLessEquals(
          tester.getRect(find.byKey(const ValueKey('front-door-task-1'))).right,
        ),
      );
    });

    testWidgets('one item is set up at a time: opening another leaves the '
        'first, and Enter makes the one just opened', (tester) async {
      await pump(tester, [waiting(), waiting(index: 1)]);
      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('front-door-task-1')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(FrontTaskSetupKeys.ask(0)), findsNothing);
      expect(find.byKey(FrontTaskSetupKeys.ask(1)), findsOne);
      // The first is its choices again.
      expect(waysOf(tester).ways.first.name, 'task');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(acted, [('task', 'd:door:1')]);
    });

    testWidgets('leaving a setup that is no longer open changes nothing', (
      tester,
    ) async {
      await pump(tester, [waiting(), waiting(index: 1)]);
      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await tester.pump();
      final leaveFirst = tester
          .widget<FrontTaskSetup>(find.byType(FrontTaskSetup))
          .onBack;
      await tester.tap(find.byKey(const ValueKey('front-door-task-1')));
      await tester.pump();

      leaveFirst();
      await tester.pump();
      expect(find.byKey(FrontTaskSetupKeys.ask(1)), findsOne);
    });

    testWidgets('an item gone from the card and back offers make it a task '
        'afresh', (tester) async {
      await pump(tester, [waiting()]);
      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await tester.pump();

      await pump(tester, [waiting(index: 1)]);
      await pump(tester, [waiting()]);
      expect(find.byType(FrontTaskSetup), findsNothing);
      expect(find.byKey(const ValueKey('front-door-task-0')), findsOne);
    });

    testWidgets('a reload of the item keeps the setup open', (tester) async {
      await pump(tester, [waiting()]);
      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await tester.pump();

      await pump(tester, [waiting()]);
      expect(find.byType(FrontTaskSetup), findsOne);
    });
  });

  group('a settled card', () {
    testWidgets("filed under its task is one row under its owner's glyph in "
        'the success ink: the words on one line, what became of them under '
        'it, open at the end and undo in the overflow', (tester) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'The hinge arrived.',
            outcome: const FrontDoorFiled(entryId: 'e-1', ownerId: 'id-0'),
          ),
        ),
      ]);
      final success = tester
          .element(find.byType(FrontDoorCard))
          .designTokens
          .colors
          .alert
          .success
          .ink;
      expect(statusOf(tester, 0), 'Filed under Garden');
      expect(statusWidget(tester, 0).style!.color, success);
      expect(glyph(tester, 0).icon, LottiIcons.checkboxChecked);
      expect(glyph(tester, 0).color, success);
      final words = tester.widget<Text>(
        find.byKey(const ValueKey('front-door-text-0')),
      );
      expect(words.maxLines, 1);
      expect(words.overflow, TextOverflow.ellipsis);
      final open = button(tester, 'open', 0);
      expect(open.variant, DesignSystemButtonVariant.tertiary);
      expect(open.trailingIcon, LottiIcons.chevronRight);
      expect(open.label, 'Open');
      expect(
        tester.getRect(find.byKey(const ValueKey('front-door-open-0'))).left,
        greaterThan(
          tester
              .getRect(find.byKey(const ValueKey('front-door-status-0')))
              .left,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('front-door-open-0')));
      expect(await openMenu(tester, 0), ['Undo']);
      await tapItem(tester, 'take-back', 0);
      expect(acted, [('open', 'd:door:0'), ('take-back', 'd:door:0')]);
    });

    testWidgets('saved as a note, or made into a task, reads the same', (
      tester,
    ) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'Learn accordion.',
            kind: FrontDestinationKind.unrouted,
            ownerTitle: null,
            outcome: const FrontDoorFiled(entryId: 'e-1'),
          ),
        ),
        entry(
          record(
            index: 1,
            text: 'Buy a hose.',
            kind: FrontDestinationKind.unrouted,
            ownerTitle: null,
            outcome: const FrontDoorTaskCreated(taskId: 't-1'),
          ),
        ),
      ]);
      expect(statusOf(tester, 0), 'Saved as a note');
      expect(statusOf(tester, 1), 'Made into a task');
      // Each under the glyph of the way it went.
      expect(glyph(tester, 0).icon, LottiIcons.note);
      expect(glyph(tester, 1).icon, LottiIcons.checkboxChecked);
      await tester.tap(find.byKey(const ValueKey('front-door-open-1')));
      await openMenu(tester, 0);
      await tapItem(tester, 'take-back', 0);
      expect(acted, [('open', 'd:door:1'), ('take-back', 'd:door:0')]);
    });

    group('a task made with something asked for', () {
      Future<void> pumpMade(
        WidgetTester tester,
        Set<FrontTaskExtra> extras,
      ) => pump(tester, [
        entry(
          record(
            index: 0,
            text: 'Check the ice-pad weather window.',
            kind: FrontDestinationKind.newThing,
            ownerTitle: null,
            outcome: FrontDoorTaskCreated(taskId: 't-1', extras: extras),
          ),
        ),
      ]);

      for (final (extras, status) in [
        (<FrontTaskExtra>{}, 'Made into a task'),
        (
          {FrontTaskExtra.codingPrompt},
          'Made into a task · coding prompt requested',
        ),
        (
          {FrontTaskExtra.coverArt},
          'Made into a task · cover art requested',
        ),
        (
          {FrontTaskExtra.coverArt, FrontTaskExtra.codingPrompt},
          'Made into a task · coding prompt requested · '
              'cover art requested',
        ),
      ]) {
        testWidgets('says "$status"', (tester) async {
          await pumpMade(tester, extras);

          expect(statusOf(tester, 0), status);
        });
      }

      testWidgets("is a settled card like any task: the task's glyph, open "
          'on its one control, undo in the overflow', (tester) async {
        await pumpMade(tester, {FrontTaskExtra.coverArt});

        expect(glyph(tester, 0).icon, LottiIcons.checkboxChecked);
        expect(button(tester, 'open', 0).label, 'Open');
        await tester.tap(find.byKey(const ValueKey('front-door-open-0')));
        expect(await openMenu(tester, 0), ['Undo']);
        await tapItem(tester, 'take-back', 0);
        expect(acted, [('open', 'd:door:0'), ('take-back', 'd:door:0')]);
      });

      testWidgets('read-only, it still says what was asked for and offers '
          'nothing', (tester) async {
        await pump(
          tester,
          [
            entry(
              record(
                index: 0,
                text: 'Check the ice-pad weather window.',
                kind: FrontDestinationKind.newThing,
                ownerTitle: null,
                outcome: const FrontDoorTaskCreated(
                  taskId: 't-1',
                  extras: {FrontTaskExtra.codingPrompt},
                ),
              ),
            ),
          ],
          withActions: false,
        );

        expect(
          statusOf(tester, 0),
          'Made into a task · coding prompt requested',
        );
        expect(find.byType(DesignSystemButton), findsNothing);
        expect(menu(0), findsNothing);
      });
    });

    testWidgets('made into an event shows the done tile and says so, opens '
        'on its one control, and undoes from the overflow', (tester) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'Launch-day rehearsal on Friday.',
            kind: FrontDestinationKind.unrouted,
            ownerTitle: null,
            outcome: const FrontDoorEventCreated(eventId: 'ev-1'),
          ),
        ),
      ]);

      expect(titleOf(tester, 0), 'Launch-day rehearsal on Friday.');
      expect(statusOf(tester, 0), 'Made into an event');
      expect(glyph(tester, 0).icon, LottiIcons.calendar);
      expect(button(tester, 'open', 0).label, 'Open');
      await tester.tap(find.byKey(const ValueKey('front-door-open-0')));
      expect(await openMenu(tester, 0), ['Undo']);
      await tapItem(tester, 'take-back', 0);
      expect(acted, [('open', 'd:door:0'), ('take-back', 'd:door:0')]);
    });

    testWidgets('a proposal said no to, and an item left where it is, each '
        'say so with no control but an undo in the overflow', (tester) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'The hinge arrived.',
            outcome: const FrontDoorDeclined(ownerId: 'id-0'),
          ),
        ),
        entry(
          record(
            index: 1,
            text: 'Hm.',
            kind: FrontDestinationKind.unrouted,
            ownerTitle: null,
            outcome: const FrontDoorDeclined(),
          ),
        ),
      ]);
      expect(statusOf(tester, 0), 'Not filed');
      expect(statusOf(tester, 1), 'Left here in the thread');
      expect(glyph(tester, 0).icon, LottiIcons.checkboxChecked);
      expect(glyph(tester, 1).icon, LottiIcons.inbox);
      expect(find.byType(DesignSystemButton), findsNothing);
      expect(await openMenu(tester, 1), ['Undo']);
      await tapItem(tester, 'undo', 1);
      expect(acted, [('undo', 'd:door:1')]);
    });
  });

  group('a change to today', () {
    testWidgets('asks to change the plan, takes it there on the one filled '
        'tap, and offers somewhere else instead', (tester) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'Move the colony count to the afternoon.',
            kind: FrontDestinationKind.day,
            ownerTitle: null,
            outcome: const FrontDoorDay(),
          ),
        ),
      ]);
      expect(statusOf(tester, 0), "Change today's plan?");
      expect(button(tester, 'day', 0).label, 'Change today');
      await tester.tap(find.byKey(const ValueKey('front-door-day-0')));
      expect(acted, [('day', 'd:door:0')]);

      expect(await openMenu(tester, 0), ['Somewhere else']);
      await tapItem(tester, 'decline', 0);
      expect(acted.last, ('decline', 'd:door:0'));
    });

    testWidgets('once planned, and a project made of an item, each say so '
        'with Open and nothing to take back here', (tester) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'Move the colony count to the afternoon.',
            kind: FrontDestinationKind.day,
            ownerTitle: null,
            outcome: FrontDoorDayPlanned(day: DateTime(2026, 11)),
          ),
        ),
        entry(
          record(
            index: 1,
            text: 'Rebuild the feeding stations.',
            kind: FrontDestinationKind.newThing,
            ownerTitle: null,
            outcome: const FrontDoorProjectCreated(projectId: 'p-1'),
          ),
        ),
      ]);
      expect(statusOf(tester, 0), "Today's plan changed");
      expect(statusOf(tester, 1), 'Made into a project');
      expect(glyph(tester, 0).icon, LottiIcons.confirmCircled);
      expect(glyph(tester, 1).icon, LottiIcons.folder);
      for (final index in [0, 1]) {
        expect(menu(index), findsNothing);
      }
      await tester.tap(find.byKey(const ValueKey('front-door-open-1')));
      expect(acted, [('open', 'd:door:1')]);
    });
  });

  group('an inbox item', () {
    testWidgets('a task she drafted — one the user asked for — leads with '
        'make it a task as the suggested way, under the title she read', (
      tester,
    ) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'Yes, make it a task.',
            kind: FrontDestinationKind.newThing,
            ownerTitle: null,
            outcome: const FrontDoorInbox(newKind: FrontNewKind.task),
            task: const FrontTaskDraft(title: 'Check the snow fences'),
          ),
        ),
      ]);

      expect(titleOf(tester, 0), 'Check the snow fences');
      expect(await openMenu(tester, 0), [
        'Make it a task',
        'Task with a coding prompt',
        'Start a goal…',
        'Make it an event',
        'Save as a note',
        'Leave it, nothing is made',
      ]);
      expect(
        [for (final way in waysOf(tester).ways) way.suggested],
        [
          true,
          false,
          false,
          false,
          false,
        ],
      );
    });

    testWidgets('nobody asked to be a task asks where it should go: every '
        'way, make it a task among them and not the suggested one, with the '
        'guess first and leaving it last', (tester) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'Swim every morning.',
            kind: FrontDestinationKind.newThing,
            ownerTitle: null,
            outcome: const FrontDoorInbox(newKind: FrontNewKind.goal),
          ),
        ),
      ]);

      expect(titleOf(tester, 0), 'Swim every morning.');
      expect(statusOf(tester, 0), 'Where should this go?');

      expect(await openMenu(tester, 0), [
        'Start a goal…',
        'Make it a task',
        'Task with a coding prompt',
        'Make it an event',
        'Save as a note',
        'Leave it, nothing is made',
      ]);
      expect(
        [
          for (final way in waysOf(tester).ways)
            if (way.suggested) way.name,
        ],
        ['goal'],
      );
      await tapItem(tester, 'task', 0);
      // The setup opens as from the filled tap, and nothing is made yet.
      expect(find.byKey(FrontTaskSetupKeys.ask(0)), findsOne);
      expect(acted, isEmpty);
      await tester.tap(find.byKey(FrontTaskSetupKeys.back(0)));
      await tester.pump();
      await tapItem(tester, 'goal', 0);
      await tapItem(tester, 'event', 0);
      await tapItem(tester, 'note', 0);
      await tapItem(tester, 'decline', 0);
      expect(acted, [
        ('goal', 'd:door:0'),
        ('event', 'd:door:0'),
        ('note', 'd:door:0'),
        ('decline', 'd:door:0'),
      ]);
    });

    testWidgets('without a way to make an event — events are off — an item '
        'offers every other way', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          FrontDoorCard(
            doors: [
              entry(
                record(
                  index: 0,
                  text: 'Hm.',
                  kind: FrontDestinationKind.unrouted,
                  ownerTitle: null,
                  outcome: const FrontDoorInbox(),
                ),
              ),
            ],
            actions: FrontDoorActions(
              onFile: (_) {},
              onDecline: (_) {},
              onUndoDecline: (_) {},
              onTakeBack: (_) {},
              onOpen: (_) {},
              onMakeTask: (_, _) {},
              onMakePrompt: (_, _) {},
              onSaveNote: (_) {},
              onStartGoal: (_) {},
              onNewProject: (_) {},
              onPlanDay: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(await openMenu(tester, 0), [
        'Make it a task',
        'Task with a coding prompt',
        'Start a goal…',
        'Save as a note',
        'Leave it, nothing is made',
      ]);
      // Nothing was guessed: no way is the suggested one.
      expect(waysOf(tester).ways.any((way) => way.suggested), isFalse);
    });

    testWidgets('a new project leads the choices with its own way; an '
        'unrouted one has no project way; one sent back from a proposal asks '
        'where instead', (tester) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'Relocate the colony.',
            kind: FrontDestinationKind.newThing,
            ownerTitle: null,
            outcome: const FrontDoorInbox(newKind: FrontNewKind.project),
          ),
        ),
        entry(
          record(
            index: 1,
            text: 'Hm.',
            kind: FrontDestinationKind.unrouted,
            ownerTitle: null,
            outcome: const FrontDoorInbox(),
          ),
        ),
        entry(
          record(
            index: 2,
            text: 'The hinge arrived.',
            outcome: const FrontDoorInbox(ownerId: 'id-2'),
          ),
        ),
      ]);

      expect(statusOf(tester, 2), 'Where should this go instead?');
      expect(await openMenu(tester, 0), [
        'New project…',
        'Make it a task',
        'Task with a coding prompt',
        'Start a goal…',
        'Make it an event',
        'Save as a note',
        'Leave it, nothing is made',
      ]);
      expect(waysOf(tester).ways.first.suggested, isTrue);
      expect(await openMenu(tester, 1), [
        'Make it a task',
        'Task with a coding prompt',
        'Start a goal…',
        'Make it an event',
        'Save as a note',
        'Leave it, nothing is made',
      ]);
      await tapItem(tester, 'project', 0);
      expect(acted, [('project', 'd:door:0')]);
    });

    group('its choices', () {
      const drafted = FrontTaskDraft(title: 'Check the ice-pad weather window');

      FrontDoorEntry inbox({
        int index = 0,
        FrontNewKind? newKind = FrontNewKind.task,
        FrontTaskDraft? task = drafted,
        String? ownerId,
      }) => entry(
        record(
          index: index,
          text: 'Check the ice-pad weather window.',
          kind: FrontDestinationKind.newThing,
          ownerTitle: null,
          outcome: FrontDoorInbox(newKind: newKind, ownerId: ownerId),
          task: task,
        ),
      );
      Finder way(String name, [int index = 0]) =>
          find.byKey(ValueKey('front-door-$name-$index'));

      testWidgets('are in sight without a tap: the question, the words as '
          'the headline under no glyph, every way as a row, and the way '
          'out last — no button, toggle or menu beside them', (tester) async {
        double top(Finder finder) => tester.getTopLeft(finder).dy;
        await pump(tester, [inbox()]);

        expect(statusOf(tester, 0), 'Where should this go?');
        expect(titleOf(tester, 0), 'Check the ice-pad weather window');
        expect(find.byKey(const ValueKey('front-door-glyph-0')), findsNothing);
        expect(menu(0), findsNothing);
        expect(find.byType(DesignSystemContextMenuButton), findsNothing);

        final tops = [
          top(find.byKey(const ValueKey('front-door-status-0'))),
          top(find.byKey(const ValueKey('front-door-text-0'))),
          for (final name in ['task', 'prompt', 'goal', 'event', 'note'])
            top(way(name)),
          top(way('decline')),
        ];
        expect(tops, [...tops]..sort());
        expect(tops.toSet(), hasLength(tops.length));
        // The headline outweighs the question over it.
        final tokens = tester.element(find.byType(FrontDoorCard)).designTokens;
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('front-door-text-0')))
              .style,
          tokens.typography.styles.subtitle.subtitle1.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        );
        expect(
          statusWidget(tester, 0).style!.color,
          tokens.colors.text.mediumEmphasis,
        );
      });

      testWidgets("the router's guess is the first row and the one "
          'suggested: a goal, a project, or a task she drafted', (
        tester,
      ) async {
        for (final (newKind, name) in [
          (FrontNewKind.task, 'task'),
          (FrontNewKind.goal, 'goal'),
          (FrontNewKind.project, 'project'),
        ]) {
          await pump(tester, [inbox(newKind: newKind)]);

          final ways = waysOf(tester).ways;
          expect(ways.first.name, name);
          expect(
            [
              for (final way in ways)
                if (way.suggested) way.name,
            ],
            [name],
          );
          expect(
            tester.widget<Semantics>(way(name)).properties.label,
            '${ways.first.label}. Suggested',
          );
        }
      });

      testWidgets('with nothing guessed, or a task nobody asked for, no row '
          'is suggested: make it a task is first and says what it does', (
        tester,
      ) async {
        for (final newKind in [FrontNewKind.task, null]) {
          await pump(tester, [inbox(newKind: newKind, task: null)]);

          final ways = waysOf(tester).ways;
          expect(ways.any((way) => way.suggested), isFalse);
          expect(ways.first.name, 'task');
          expect(
            tester.widget<Semantics>(way('task')).properties.label,
            'Make it a task. A task from your words, after a few choices',
          );
        }
      });

      testWidgets('every other way says what choosing it does', (
        tester,
      ) async {
        await pump(tester, [inbox(newKind: FrontNewKind.project, task: null)]);

        expect(
          {
            for (final way in waysOf(tester).ways)
              if (!way.suggested) way.label: way.hint,
          },
          {
            'Make it a task': 'A task from your words, after a few choices',
            'Task with a coding prompt': 'A task, and a prompt from your words',
            'Start a goal…': 'Opens the goal wizard with your words',
            'Make it an event': 'A tentative event titled with your words',
            'Save as a note': 'Keeps your words as they are',
          },
        );
        expect(waysOf(tester).leave.label, 'Leave it, nothing is made');
      });

      testWidgets('a tap on a row does that way, once, and nothing else', (
        tester,
      ) async {
        for (final name in [
          'prompt',
          'goal',
          'project',
          'event',
          'note',
          'decline',
        ]) {
          acted.clear();
          await pump(tester, [inbox(newKind: FrontNewKind.project)]);

          await tapItem(tester, name, 0);

          expect(acted, [(name, 'd:door:0')], reason: name);
        }
      });

      testWidgets('make it a task asks how first, in place: the setup '
          'stands where the choices stood, under the title, and going back '
          'returns them', (tester) async {
        await pump(tester, [inbox()]);

        await tapItem(tester, 'task', 0);

        expect(acted, isEmpty);
        expect(find.byType(FrontTaskSetup), findsOne);
        expect(find.byType(FrontDoorWays), findsNothing);
        expect(find.byKey(const ValueKey('front-door-status-0')), findsNothing);
        expect(titleOf(tester, 0), 'Check the ice-pad weather window');

        await tester.tap(find.byKey(FrontTaskSetupKeys.back(0)));
        await tester.pumpAndSettle();

        expect(find.byType(FrontTaskSetup), findsNothing);
        expect(statusOf(tester, 0), 'Where should this go?');
        expect(way('task'), findsOne);
      });

      testWidgets('while a way is being done its row shows the progress, '
          'no row takes a tap, and the card is as tall as before', (
        tester,
      ) async {
        final door = inbox();
        await pump(tester, [door]);
        final before = tester.getSize(find.byType(FrontDoorCard));
        await tapItem(tester, 'note', 0);

        await pump(tester, [door], busy: {'d:door:0'});

        expect(tester.getSize(find.byType(FrontDoorCard)), before);
        final ways = waysOf(tester);
        expect(
          [
            for (final way in ways.ways)
              if (way.inFlight) way.name,
          ],
          ['note'],
        );
        expect(ways.ways.map((way) => way.onTap), everyElement(isNull));
        expect(ways.leave.onTap, isNull);
        expect(ways.leave.inFlight, isFalse);
        expect(
          find.byKey(const ValueKey('front-door-note-progress-0')),
          findsOne,
        );
        // Nothing more is done by a tap meanwhile.
        acted.clear();
        await tester.tap(way('goal'), warnIfMissed: false);
        await tester.tap(way('decline'), warnIfMissed: false);
        expect(acted, isEmpty);
      });

      testWidgets('leaving it in flight is the way out that shows it; one '
          "item's progress is not another's", (tester) async {
        final doors = [inbox(), inbox(index: 1)];
        await pump(tester, doors);
        await tapItem(tester, 'decline', 0);

        await pump(tester, doors, busy: {'d:door:0'});

        expect(waysOf(tester).leave.inFlight, isTrue);
        expect(waysOf(tester).ways.any((way) => way.inFlight), isFalse);
        expect(waysOf(tester, 1).leave.inFlight, isFalse);
        expect(waysOf(tester, 1).ways.first.onTap, isNotNull);
      });

      testWidgets('a way that failed says so over the words, in the error '
          'ink, and every way can be taken again', (tester) async {
        await pump(tester, [inbox()], failed: {'d:door:0'});

        expect(statusOf(tester, 0), 'That did not go through.');
        expect(
          statusWidget(tester, 0).style!.color,
          tester
              .element(find.byType(FrontDoorCard))
              .designTokens
              .colors
              .alert
              .error
              .ink,
        );
        await tapItem(tester, 'note', 0);
        expect(acted, [('note', 'd:door:0')]);
      });

      testWidgets('one sent back from a proposal asks where instead', (
        tester,
      ) async {
        await pump(tester, [inbox(ownerId: 'id-0')]);

        expect(statusOf(tester, 0), 'Where should this go instead?');
        expect(way('note'), findsOne);
      });

      testWidgets('an item that went somewhere and waits again is its '
          'choices again, not a setup left open', (tester) async {
        await pump(tester, [inbox()]);
        await tapItem(tester, 'task', 0);
        expect(find.byType(FrontTaskSetup), findsOne);

        await pump(tester, [
          entry(
            record(
              index: 0,
              text: 'Check the ice-pad weather window.',
              kind: FrontDestinationKind.newThing,
              ownerTitle: null,
              outcome: const FrontDoorTaskCreated(taskId: 't'),
            ),
          ),
        ]);
        expect(find.byType(FrontTaskSetup), findsNothing);
        expect(find.byType(FrontDoorWays), findsNothing);

        await pump(tester, [inbox()]);
        expect(find.byType(FrontTaskSetup), findsNothing);
        expect(way('task'), findsOne);
      });

      testWidgets('fits a 360 wide phone with every way listed', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(360, 1400)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await pump(tester, [
          entry(
            record(
              index: 0,
              text:
                  'Relocate the whole colony to the northern ice shelf '
                  'before the midwinter storms close the pass.',
              kind: FrontDestinationKind.newThing,
              ownerTitle: null,
              outcome: const FrontDoorInbox(newKind: FrontNewKind.project),
            ),
          ),
        ]);

        expect(tester.takeException(), isNull);
        for (final name in [
          'project',
          'task',
          'prompt',
          'goal',
          'event',
          'note',
          'decline',
        ]) {
          final rect = tester.getRect(way(name));
          expect(rect.left, greaterThanOrEqualTo(0), reason: name);
          expect(rect.right, lessThanOrEqualTo(360), reason: name);
        }
      });
    });

    group('the ways she picked for its words', () {
      FrontDoorEntry inbox({
        required List<FrontInboxWay>? ways,
        FrontNewKind? newKind = FrontNewKind.task,
        FrontTaskDraft? task,
      }) => entry(
        record(
          index: 0,
          text: 'Fix the crash on the login screen.',
          kind: FrontDestinationKind.newThing,
          ownerTitle: null,
          outcome: FrontDoorInbox(newKind: newKind),
          task: task,
          ways: ways,
        ),
      );

      /// The card as the chat draws it: inside the thread's surfaces, which
      /// hold the one composed from the ways the item's record keeps.
      Future<void> pumpInThread(
        WidgetTester tester,
        FrontDoorEntry door, {
        Set<String> busy = const {},
      }) async {
        await tester.pumpWidget(
          makeTestableWidget(
            FrontReplySurfaces(
              surfaces: FrontChatThread(
                messages: const [],
                doorsByMessageId: {
                  'u1': [door],
                },
              ).surfaces,
              logger: MockDomainLogger(),
              onQuickReply: (_) {},
              child: FrontDoorCard(
                doors: [door],
                actions: actions(),
                busyDoorIds: busy,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      testWidgets('are the ones listed, with making it a task and keeping '
          'it as a note, which are never hers to leave out — drawn through '
          'the reply catalog', (tester) async {
        await pumpInThread(tester, inbox(ways: const [FrontInboxWay.prompt]));

        expect(await openMenu(tester, 0), [
          'Make it a task',
          'Task with a coding prompt',
          'Save as a note',
          'Leave it, nothing is made',
        ]);
        expect(
          find.descendant(
            of: find.byType(A2uiSurface),
            matching: find.byType(FrontDoorWays),
          ),
          findsOne,
        );
      });

      testWidgets('none picked leaves what the card always offers, on a '
          'task she drafted too', (tester) async {
        await pumpInThread(tester, inbox(ways: const []));
        expect(await openMenu(tester, 0), [
          'Make it a task',
          'Save as a note',
          'Leave it, nothing is made',
        ]);

        await pumpInThread(
          tester,
          inbox(
            ways: const [],
            task: const FrontTaskDraft(title: 'Buy milk'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          [
            for (final way in waysOf(tester).ways) way.label,
            waysOf(tester).leave.label,
          ],
          ['Make it a task', 'Save as a note', 'Leave it, nothing is made'],
        );
      });

      testWidgets("the router's guess is offered and leads, picked or not; "
          "the rest keep the card's order, not hers", (tester) async {
        await pumpInThread(
          tester,
          inbox(
            newKind: FrontNewKind.goal,
            ways: const [FrontInboxWay.event, FrontInboxWay.prompt],
          ),
        );

        expect(await openMenu(tester, 0), [
          'Start a goal…',
          'Make it a task',
          'Task with a coding prompt',
          'Make it an event',
          'Save as a note',
          'Leave it, nothing is made',
        ]);
      });

      testWidgets('a project is offered when she picks it, guessed or not, '
          'and not when she picks other ways', (tester) async {
        await pumpInThread(tester, inbox(ways: const [FrontInboxWay.project]));
        expect(await openMenu(tester, 0), [
          'Make it a task',
          'New project…',
          'Save as a note',
          'Leave it, nothing is made',
        ]);
        await tapItem(tester, 'project', 0);
        expect(acted, [('project', 'd:door:0')]);

        await pumpInThread(tester, inbox(ways: const [FrontInboxWay.goal]));
        expect(await openMenu(tester, 0), isNot(contains('New project…')));
      });

      testWidgets('a picked way is taken as any other: it runs, once', (
        tester,
      ) async {
        await pumpInThread(tester, inbox(ways: const [FrontInboxWay.prompt]));

        await tapItem(tester, 'prompt', 0);

        expect(acted, [('prompt', 'd:door:0')]);
      });

      testWidgets('the list follows the card: once the item is busy, '
          'its rows take no tap', (tester) async {
        final door = inbox(ways: const [FrontInboxWay.prompt]);
        await pumpInThread(tester, door);
        await openMenu(tester, 0);
        expect(waysOf(tester).ways.first.onTap, isNotNull);

        await pumpInThread(tester, door, busy: {'d:door:0'});

        expect(
          waysOf(tester).ways.map((way) => way.onTap),
          everyElement(isNull),
        );
        expect(waysOf(tester).leave.onTap, isNull);
      });

      testWidgets('outside a thread there is no surface to draw them on: '
          'every way is offered, as for an item she picked none for', (
        tester,
      ) async {
        await pump(tester, [inbox(ways: const [])]);

        expect(await openMenu(tester, 0), [
          'Make it a task',
          'Task with a coding prompt',
          'Start a goal…',
          'Make it an event',
          'Save as a note',
          'Leave it, nothing is made',
        ]);
        expect(find.byType(A2uiSurface), findsNothing);
      });
    });

    group('with a coding prompt', () {
      FrontDoorEntry inbox({FrontTaskDraft? task}) => entry(
        record(
          index: 0,
          text: 'Check the ice-pad weather window, high priority.',
          kind: FrontDestinationKind.newThing,
          ownerTitle: null,
          outcome: const FrontDoorInbox(newKind: FrontNewKind.task),
          task: task,
        ),
      );

      testWidgets('is the second way of an item she read as a task, after '
          'making it one, under the code glyph', (tester) async {
        await pump(tester, [
          inbox(
            task: const FrontTaskDraft(
              title: 'Check the ice-pad weather window',
            ),
          ),
        ]);

        final items = await openMenu(tester, 0);
        expect(items.take(2), ['Make it a task', 'Task with a coding prompt']);
        final way = waysOf(tester).ways[1];
        expect(way.icon, LottiIcons.code);
        expect(way.name, 'prompt');
        expect(find.byKey(const ValueKey('front-door-prompt-0')), findsOne);
      });

      testWidgets('makes the task as she read it, with no setup in between', (
        tester,
      ) async {
        await pump(tester, [
          inbox(
            task: FrontTaskDraft(
              title: 'Check the ice-pad weather window',
              priority: TaskPriority.p1High,
              due: DateTime(2026, 11, 20),
              coverArt: true,
            ),
          ),
        ]);

        await openMenu(tester, 0);
        await tapItem(tester, 'prompt', 0);

        expect(acted, [('prompt', 'd:door:0')]);
        expect(
          madeWith.single,
          FrontTaskChoices(
            start: FrontTaskStart.open,
            priority: TaskPriority.p1High,
            due: DateTime(2026, 11, 20),
            coverArt: true,
          ),
        );
        // Asked from the list: the setup never opened.
        expect(find.byType(FrontTaskSetup), findsNothing);
      });

      testWidgets('words she read nothing from make a plain open task', (
        tester,
      ) async {
        await pump(tester, [inbox()]);

        await openMenu(tester, 0);
        await tapItem(tester, 'prompt', 0);

        expect(
          madeWith.single,
          const FrontTaskChoices(
            start: FrontTaskStart.open,
            priority: TaskPriority.p2Medium,
          ),
        );
      });

      testWidgets('takes no tap once the item is busy', (tester) async {
        await pump(tester, [inbox()]);
        await openMenu(tester, 0);
        await pump(tester, [inbox()], busy: {'d:door:0'});

        expect(waysOf(tester).ways.first.onTap, isNull);
        await tapItem(tester, 'prompt', 0);
        expect(acted, isEmpty);
      });
    });

    testWidgets('without actions the cards are read-only', (tester) async {
      await pump(
        tester,
        [
          entry(
            record(
              index: 0,
              text: 'Hm.',
              kind: FrontDestinationKind.unrouted,
              ownerTitle: null,
              outcome: const FrontDoorInbox(),
            ),
          ),
          entry(
            record(
              index: 1,
              text: 'The hinge arrived.',
              outcome: const FrontDoorProposal(ownerId: 'id-1'),
            ),
          ),
          entry(
            record(
              index: 2,
              text: 'Buy a hose.',
              kind: FrontDestinationKind.unrouted,
              ownerTitle: null,
              outcome: const FrontDoorTaskCreated(taskId: 't-1'),
            ),
          ),
        ],
        withActions: false,
      );
      expect(find.byType(DesignSystemButton), findsNothing);
      expect(find.byType(DesignSystemContextMenuButton), findsNothing);
      expect(statusOf(tester, 2), 'Made into a task');
    });
  });

  testWidgets('without an owner title the status names the kind of thing, '
      'never an id', (tester) async {
    await pump(tester, [
      for (final (index, kind) in [
        FrontDestinationKind.task,
        FrontDestinationKind.project,
        FrontDestinationKind.goal,
        FrontDestinationKind.person,
        FrontDestinationKind.day,
        FrontDestinationKind.newThing,
        FrontDestinationKind.journal,
        FrontDestinationKind.unrouted,
      ].indexed)
        entry(
          record(
            index: index,
            text: 'segment $index',
            kind: kind,
            ownerTitle: index.isEven ? null : '  ',
          ),
        ),
    ]);

    expect(statusOf(tester, 0), 'Asking the task…');
    expect(statusOf(tester, 1), 'Asking the project…');
    expect(statusOf(tester, 2), 'Asking the goal…');
    expect(statusOf(tester, 3), 'Asking the person…');
    for (final index in [4, 5, 7]) {
      expect(statusOf(tester, index), 'Asking this…');
    }
    // Her own door searches the journal rather than asking anyone.
    expect(statusOf(tester, 6), 'Searching your journal…');
    expect(glyph(tester, 6).icon, LottiIcons.search);
    for (final index in [5, 7]) {
      expect(glyph(tester, index).icon, LottiIcons.inbox);
    }
    expect(find.textContaining('id-'), findsNothing);
  });
}

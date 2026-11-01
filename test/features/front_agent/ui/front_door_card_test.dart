import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/ui/front_door_card.dart';
import 'package:material_ui/material_ui.dart';

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
  }) => FrontDoorRecord(
    segmentIndex: index,
    text: text,
    kind: kind,
    destinationId: kind.needsId ? 'id-$index' : null,
    ownerTitle: ownerTitle,
    status: outcome == null ? FrontDoorStatus.claimed : FrontDoorStatus.done,
    claimedAt: claimedAt,
    outcome: outcome,
  );

  FrontDoorEntry entry(FrontDoorRecord record, {String? specialistReply}) =>
      FrontDoorEntry(
        doorId: 'd:door:${record.segmentIndex}',
        record: record,
        specialistReply: specialistReply,
      );

  late List<(String, String)> acted;

  FrontDoorActions actions() => FrontDoorActions(
    onFile: (id) => acted.add(('file', id)),
    onDecline: (id) => acted.add(('decline', id)),
    onUndoDecline: (id) => acted.add(('undo', id)),
    onTakeBack: (id) => acted.add(('take-back', id)),
    onOpen: (door) => acted.add(('open', door.doorId)),
    onMakeTask: (id) => acted.add(('task', id)),
    onSaveNote: (id) => acted.add(('note', id)),
    onStartGoal: (door) => acted.add(('goal', door.doorId)),
    onNewProject: (door) => acted.add(('project', door.doorId)),
    onPlanDay: (door) => acted.add(('day', door.doorId)),
    onOpenEvidence: (evidence) => acted.add(('source', evidence.source.id)),
  );

  setUp(() => acted = []);

  Future<void> pump(
    WidgetTester tester,
    List<FrontDoorEntry> doors, {
    bool withActions = true,
    Set<String> busy = const {},
    Set<String> failed = const {},
    QueryAccessSnapshot? journalAccess,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        FrontDoorCard(
          doors: doors,
          actions: withActions ? actions() : null,
          busyDoorIds: busy,
          failedDoorIds: failed,
          journalAccess: journalAccess,
        ),
      ),
    );
    await tester.pump();
  }

  String titleOf(WidgetTester tester, int index) =>
      tester.widget<Text>(find.byKey(ValueKey('front-door-text-$index'))).data!;
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

  /// Opens the card's overflow and returns the labels it offers.
  Future<List<String>> openMenu(WidgetTester tester, int index) async {
    await tester.tap(menu(index));
    await tester.pumpAndSettle();
    final items = tester
        .widget<DesignSystemContextMenuButton>(menu(index))
        .items
        .map((item) => item.label)
        .toList();
    return items;
  }

  Future<void> tapItem(WidgetTester tester, String name, int index) async {
    await tester.tap(find.byKey(ValueKey('front-door-$name-$index')));
    await tester.pumpAndSettle();
  }

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
      expect(find.text('Feeder note'), findsOneWidget);
      expect(find.text('The seam walk'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('front-door-source-0-0')));
      expect(acted, [('source', 'feeder-note')]);
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
    final title = tester.widget<Text>(
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

  group('a settled card', () {
    testWidgets('filed under its task shows the done tile, opens on its one '
        'control, and undoes from the overflow', (tester) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'The hinge arrived.',
            outcome: const FrontDoorFiled(entryId: 'e-1', ownerId: 'id-0'),
          ),
        ),
      ]);
      expect(statusOf(tester, 0), 'Filed under Garden');
      expect(glyph(tester, 0).icon, LottiIcons.confirmCircled);
      final open = button(tester, 'open', 0);
      expect(open.variant, DesignSystemButtonVariant.secondary);
      expect(open.label, 'Open');
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
      expect(glyph(tester, 1).icon, LottiIcons.confirmCircled);
      await tester.tap(find.byKey(const ValueKey('front-door-open-1')));
      await openMenu(tester, 0);
      await tapItem(tester, 'take-back', 0);
      expect(acted, [('open', 'd:door:1'), ('take-back', 'd:door:0')]);
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
      for (final index in [0, 1]) {
        expect(glyph(tester, index).icon, LottiIcons.confirmCircled);
        expect(menu(index), findsNothing);
      }
      await tester.tap(find.byKey(const ValueKey('front-door-open-1')));
      expect(acted, [('open', 'd:door:1')]);
    });
  });

  group('an inbox item', () {
    testWidgets('asks where it should go, makes a task on the one filled '
        'tap, and keeps the other ways in the overflow with the guess '
        'first and leaving it last', (tester) async {
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
      expect(glyph(tester, 0).icon, LottiIcons.focus);
      final task = button(tester, 'task', 0);
      expect(task.variant, DesignSystemButtonVariant.primary);
      expect(task.label, 'Make it a task');
      expect(find.byType(DesignSystemButton), findsOneWidget);

      expect(await openMenu(tester, 0), [
        'Start a goal…',
        'Save as a note',
        'Leave it',
      ]);
      await tapItem(tester, 'goal', 0);
      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await openMenu(tester, 0);
      await tapItem(tester, 'note', 0);
      await openMenu(tester, 0);
      await tapItem(tester, 'decline', 0);
      expect(acted, [
        ('goal', 'd:door:0'),
        ('task', 'd:door:0'),
        ('note', 'd:door:0'),
        ('decline', 'd:door:0'),
      ]);
    });

    testWidgets('a new project leads the overflow with its own way; an '
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

      expect(glyph(tester, 0).icon, LottiIcons.folder);
      expect(glyph(tester, 1).icon, LottiIcons.inbox);
      expect(statusOf(tester, 2), 'Where should this go instead?');
      expect(await openMenu(tester, 0), [
        'New project…',
        'Start a goal…',
        'Save as a note',
        'Leave it',
      ]);
      await tapItem(tester, 'project', 0);
      expect(await openMenu(tester, 1), [
        'Start a goal…',
        'Save as a note',
        'Leave it',
      ]);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      expect(acted, [('project', 'd:door:0')]);
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

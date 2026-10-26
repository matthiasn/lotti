import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/ui/front_door_card.dart';
import 'package:material_ui/material_ui.dart';

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
    onUnfile: (id) => acted.add(('unfile', id)),
    onMakeTask: (id) => acted.add(('task', id)),
    onSaveNote: (id) => acted.add(('note', id)),
    onStartGoal: (id) => acted.add(('goal', id)),
    onNewProject: (id) => acted.add(('project', id)),
  );

  setUp(() => acted = []);

  Future<void> pump(
    WidgetTester tester,
    List<FrontDoorEntry> doors, {
    bool withActions = true,
    Set<String> busy = const {},
    Set<String> failed = const {},
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        FrontDoorCard(
          doors: doors,
          actions: withActions ? actions() : null,
          busyDoorIds: busy,
          failedDoorIds: failed,
        ),
      ),
    );
    await tester.pump();
  }

  String statusOf(WidgetTester tester, int index) => tester
      .widget<Text>(find.byKey(ValueKey('front-door-status-$index')))
      .data!;

  testWidgets('quotes each segment and shows an answer under its owner, '
      'with its caveats', (tester) async {
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
          ownerTitle: 'Fence',
          outcome: const FrontDoorAnswer(
            text: 'Painted on Tuesday.',
            summaryBased: false,
            incomplete: false,
          ),
        ),
      ),
    ]);

    expect(find.text('“How is the garden?”'), findsOneWidget);
    expect(find.text('The seam walk is next.'), findsOneWidget);
    expect(
      statusOf(tester, 0),
      'From Garden · from summaries · may be incomplete',
    );
    expect(find.text('Painted on Tuesday.'), findsOneWidget);
    expect(statusOf(tester, 1), 'From Fence');
    // Answers offer nothing to do.
    expect(find.byType(DesignSystemButton), findsNothing);
    expect(find.byType(DesignSystemChip), findsNothing);
  });

  testWidgets("a specialist's reply is shown as theirs once it has landed, "
      'and awaited until then', (tester) async {
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

    expect(find.text('Two of three swims done.'), findsOneWidget);
    expect(statusOf(tester, 0), 'From Swim 2 km a day');
    expect(find.byKey(const ValueKey('front-door-text-1')), findsNothing);
    expect(statusOf(tester, 1), 'Pip is still replying…');
  });

  testWidgets('every way a segment went nowhere reads as one line', (
    tester,
  ) async {
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
    expect(statusOf(tester, 5), 'Asking Garden failed.');
    expect(find.byKey(const ValueKey('front-door-text-0')), findsNothing);
    // The error type never reaches the user.
    expect(find.textContaining('StateError'), findsNothing);
    expect(find.byType(DesignSystemButton), findsNothing);
  });

  group('a proposal', () {
    testWidgets('asks for the one tap, files on it, and takes a no', (
      tester,
    ) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'The hinge arrived.',
            outcome: const FrontDoorProposal(ownerId: 'id-0'),
          ),
        ),
      ]);

      expect(statusOf(tester, 0), 'File this under Garden?');
      await tester.tap(find.byKey(const ValueKey('front-door-file-0')));
      await tester.tap(find.byKey(const ValueKey('front-door-decline-0')));
      expect(acted, [('file', 'd:door:0'), ('decline', 'd:door:0')]);
    });

    testWidgets('that was unfiled says so and offers the tap again', (
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

    testWidgets('while its action is in flight the tap is disabled; after a '
        'failure the line says so and the tap is back', (tester) async {
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
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const ValueKey('front-door-file-0')),
            )
            .onPressed,
        isNull,
      );

      await pump(tester, doors, failed: {'d:door:0'});
      expect(
        statusOf(tester, 0),
        'File this under Garden? · that did not go through, try again',
      );
      await tester.tap(find.byKey(const ValueKey('front-door-file-0')));
      expect(acted, [('file', 'd:door:0')]);
    });
  });

  group('a filed segment', () {
    testWidgets('names where it went and can be taken back out', (
      tester,
    ) async {
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
      await tester.tap(find.byKey(const ValueKey('front-door-unfile-0')));
      expect(acted, [('unfile', 'd:door:0')]);
    });

    testWidgets('saved as a note has nothing to take it out of', (
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
      ]);
      expect(statusOf(tester, 0), 'Saved as a note');
      expect(find.byType(DesignSystemButton), findsNothing);
    });

    testWidgets('declined, or made into a task, is settled', (tester) async {
      await pump(tester, [
        entry(
          record(
            index: 0,
            text: 'The hinge arrived.',
            outcome: const FrontDoorDeclined(),
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
      expect(statusOf(tester, 0), 'Not filed, as you said');
      expect(statusOf(tester, 1), 'Made into a task');
      expect(find.byType(DesignSystemButton), findsNothing);
      expect(find.byType(DesignSystemChip), findsNothing);
    });
  });

  group('an inbox item', () {
    testWidgets('offers the chips, the likeliest first, and each one acts on '
        'the door', (tester) async {
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

      expect(statusOf(tester, 0), 'Nothing owns this yet — your call');
      final chips = tester
          .widgetList<DesignSystemChip>(find.byType(DesignSystemChip))
          .map((c) => c.label)
          .toList();
      expect(chips, ['Start a goal', 'Make it a task', 'Save as a note']);

      await tester.tap(find.byKey(const ValueKey('front-door-goal-0')));
      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await tester.tap(find.byKey(const ValueKey('front-door-note-0')));
      expect(acted, [
        ('goal', 'd:door:0'),
        ('task', 'd:door:0'),
        ('note', 'd:door:0'),
      ]);
    });

    testWidgets('a new project leads with its chip; an unrouted one leads '
        'with the task', (tester) async {
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
      ]);

      final labels = tester
          .widgetList<DesignSystemChip>(find.byType(DesignSystemChip))
          .map((c) => c.label)
          .toList();
      expect(labels, [
        'New project',
        'Make it a task',
        'Start a goal',
        'Save as a note',
        'Make it a task',
        'Start a goal',
        'Save as a note',
      ]);
      await tester.tap(find.byKey(const ValueKey('front-door-project-0')));
      expect(acted, [('project', 'd:door:0')]);
    });

    testWidgets('without actions the card is read-only', (tester) async {
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
        ],
        withActions: false,
      );
      expect(find.byType(DesignSystemChip), findsNothing);
      expect(find.byType(DesignSystemButton), findsNothing);
    });
  });

  testWidgets('without an owner title the line names the kind of thing, '
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
    for (final index in [4, 5, 6, 7]) {
      expect(statusOf(tester, index), 'Asking this…');
    }
    expect(find.textContaining('id-'), findsNothing);
  });
}

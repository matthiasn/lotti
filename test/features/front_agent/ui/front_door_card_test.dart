import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
    onUndoDecline: (id) => acted.add(('undo', id)),
    onTakeBack: (id) => acted.add(('take-back', id)),
    onOpen: (door) => acted.add(('open', door.doorId)),
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
    bool embedded = false,
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
          embedded: embedded,
        ),
      ),
    );
    await tester.pump();
  }

  /// The door's one line that outranks the rest.
  Text lineWidget(WidgetTester tester, int index) =>
      tester.widget<Text>(find.byKey(ValueKey('front-door-text-$index')));
  String lineOf(WidgetTester tester, int index) => lineWidget(
    tester,
    index,
  ).textSpan!.toPlainText(includePlaceholders: false).trim();

  /// What sits a tier below the line: attribution and caveats.
  Finder asidesFinder(int index) =>
      find.byKey(ValueKey('front-door-status-$index'));
  String asidesOf(WidgetTester tester, int index) =>
      tester.widget<Text>(asidesFinder(index)).data!;

  Finder glyph(int index) => find.byKey(ValueKey('front-door-glyph-$index'));

  DesignSystemButton button(WidgetTester tester, String name, int index) =>
      tester.widget<DesignSystemButton>(
        find.byKey(ValueKey('front-door-$name-$index')),
      );

  List<DesignSystemButton> buttons(WidgetTester tester) => tester
      .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
      .toList();

  group('frontDoorQuote', () {
    test('frames a short segment whole', () {
      expect(frontDoorQuote(' The hinge arrived. '), '“The hinge arrived.”');
    });

    test('cuts a long one at a word boundary and closes the frame', () {
      const text =
          'The hinge for the nest box arrived, I fitted it this '
          'morning before the fish delivery.';
      final quote = frontDoorQuote(text, budget: 40);
      expect(quote, '“The hinge for the nest box arrived, I…”');
      expect(quote.length, lessThanOrEqualTo(40 + 3));
      // No space to cut at: the budget itself is the cut.
      expect(
        frontDoorQuote('a' * 60, budget: 10),
        '“${'a' * 10}…”',
      );
      // A cut that lands on a space keeps no trailing blank.
      expect(frontDoorQuote('one two three', budget: 7), '“one two…”');
    });
  });

  testWidgets('shows an answer as the line, its owner and caveats a tier '
      'below, and quotes each segment of a multi-part turn on one line '
      'between hairlines', (tester) async {
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

    final quote = tester.widget<Text>(
      find.byKey(const ValueKey('front-door-segment-0')),
    );
    expect(quote.data, '“How is the garden?”');
    expect(quote.maxLines, 1);
    expect(quote.overflow, TextOverflow.ellipsis);
    expect(quote.semanticsLabel, 'How is the garden?');
    expect(find.text('“And the fence?”'), findsOneWidget);
    expect(find.byType(DesignSystemDivider), findsOneWidget);
    expect(lineOf(tester, 0), 'The seam walk is next.');
    expect(
      asidesOf(tester, 0),
      'From Garden · from summaries · may be incomplete',
    );
    expect(lineOf(tester, 1), 'Painted on Tuesday.');
    expect(asidesOf(tester, 1), 'From Fence');
    // A real size step between the answer and what reports on it, and the
    // label is told from both by weight.
    final line = lineWidget(tester, 0).style!;
    final aside = tester.widget<Text>(asidesFinder(0)).style!;
    expect(line.fontSize, greaterThan(aside.fontSize!));
    expect(quote.style!.fontWeight, isNot(line.fontWeight));
    expect(quote.style!.fontSize, lessThan(line.fontSize!));
    // Answers offer nothing to do, and settle without a glyph.
    expect(find.byType(DesignSystemButton), findsNothing);
    expect(glyph(0), findsNothing);
  });

  testWidgets('hangs off the user bubble on a rail, or sits embedded in her '
      'reply without one', (tester) async {
    final doors = [
      entry(
        record(
          index: 0,
          text: 'How is the garden?',
          outcome: const FrontDoorAnswer(
            text: 'Fine.',
            summaryBased: false,
            incomplete: false,
          ),
        ),
      ),
    ];
    await pump(tester, doors);
    final card = find.byType(FrontDoorCard);
    final railed = tester.getTopLeft(
      find.byKey(const ValueKey('front-door-0')),
    );
    expect(railed.dx, greaterThan(tester.getTopLeft(card).dx));

    expect(find.byType(DesignSystemDivider), findsNothing);

    await pump(tester, doors, embedded: true);
    final flush = tester.getTopLeft(find.byKey(const ValueKey('front-door-0')));
    expect(flush.dx, tester.getTopLeft(card).dx);
    // Embedded under her line, a hairline tells the two apart.
    expect(find.byType(DesignSystemDivider), findsOneWidget);
    // One door is the bubble right above it and is not quoted again.
    expect(find.byKey(const ValueKey('front-door-segment-0')), findsNothing);
    expect(lineOf(tester, 0), 'Fine.');
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

    expect(lineOf(tester, 0), 'Two of three swims done.');
    expect(asidesOf(tester, 0), 'From Swim 2 km a day');
    expect(lineOf(tester, 1), 'Pip is still replying…');
    expect(asidesFinder(1), findsNothing);
    // A report sits a tier under an answer, and above the asides.
    final answer = lineWidget(tester, 0).style!.fontSize!;
    final report = lineWidget(tester, 1).style!.fontSize!;
    final aside = tester.widget<Text>(asidesFinder(0)).style!.fontSize!;
    expect(report, lessThan(answer));
    expect(report, greaterThan(aside));
  });

  testWidgets('every way a segment went nowhere reads as one line, and a '
      'failed door carries the error glyph', (tester) async {
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

    expect(lineOf(tester, 0), 'Asking Garden…');
    expect(lineOf(tester, 2), 'Pip has no agent to ask yet.');
    expect(lineOf(tester, 3), 'Relocation has no working AI setup.');
    expect(lineOf(tester, 4), 'Nowhere to take this yet.');
    expect(lineOf(tester, 5), 'Asking Garden failed.');
    for (final index in [0, 2, 3, 4]) {
      expect(glyph(index), findsNothing);
      expect(asidesFinder(index), findsNothing);
    }
    expect(tester.widget<Icon>(glyph(5)).icon, LottiIcons.warning);
    // The error type never reaches the user.
    expect(find.textContaining('StateError'), findsNothing);
    expect(find.byType(DesignSystemButton), findsNothing);
  });

  group('a proposal', () {
    testWidgets('asks for the one tap under the segment it answers, files '
        'on it, and takes a quiet no at the far edge on the same size', (
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

      final line = lineWidget(tester, 0);
      expect(lineOf(tester, 0), 'File this under Garden?');
      // One semibold per door — the label — so the owner is named in the
      // question, not set apart in it.
      final spans = <InlineSpan>[];
      line.textSpan!.visitChildren((span) {
        spans.add(span);
        return true;
      });
      expect(
        spans.whereType<TextSpan>().where((s) => s.text == 'Garden'),
        isEmpty,
      );
      // One accent per door: the tap is filled, the no is quiet, both on
      // one size with a padded hit area.
      final file = button(tester, 'file', 0);
      final decline = button(tester, 'decline', 0);
      expect(file.variant, DesignSystemButtonVariant.primary);
      expect(file.label, 'File it');
      expect(decline.variant, DesignSystemButtonVariant.quiet);
      expect(decline.label, 'Somewhere else');
      expect(file.size, decline.size);
      // The way out sits at the far edge, away from the tap that writes.
      final fileRect = tester.getRect(
        find.byKey(const ValueKey('front-door-file-0')),
      );
      final declineRect = tester.getRect(
        find.byKey(const ValueKey('front-door-decline-0')),
      );
      final card = tester.getRect(find.byType(FrontDoorCard));
      expect(declineRect.right, closeTo(card.right, 1));
      expect(declineRect.left - fileRect.right, greaterThan(card.width / 4));

      await tester.tap(find.byKey(const ValueKey('front-door-file-0')));
      await tester.tap(find.byKey(const ValueKey('front-door-decline-0')));
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
      expect(lineOf(tester, 0), 'Taken back out of Garden. File it again?');
      expect(find.byKey(const ValueKey('front-door-file-0')), findsOneWidget);
    });

    testWidgets('while its action is in flight the tap is disabled; after a '
        'failure the door says so and the tap reads as a retry', (
      tester,
    ) async {
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
      expect(button(tester, 'file', 0).onPressed, isNull);
      expect(button(tester, 'decline', 0).onPressed, isNull);
      expect(find.byKey(const ValueKey('front-door-failed-0')), findsNothing);

      await pump(tester, doors, failed: {'d:door:0'});
      expect(lineOf(tester, 0), 'File this under Garden?');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('front-door-failed-0')))
            .textSpan!
            .toPlainText(includePlaceholders: false)
            .trim(),
        'That did not go through.',
      );
      expect(
        tester
            .widget<Icon>(
              find.byKey(const ValueKey('front-door-failed-glyph-0')),
            )
            .icon,
        LottiIcons.warning,
      );
      expect(button(tester, 'file', 0).label, 'Try again');
      await tester.tap(find.byKey(const ValueKey('front-door-file-0')));
      expect(acted, [('file', 'd:door:0')]);
    });
  });

  group('a settled door', () {
    testWidgets('filed under its task carries the done glyph and offers an '
        'open at the text and an undo at the far edge', (
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
      expect(lineOf(tester, 0), 'Filed under Garden');
      expect(tester.widget<Icon>(glyph(0)).icon, LottiIcons.confirmCircled);
      final open = button(tester, 'open', 0);
      final undo = button(tester, 'take-back', 0);
      expect(open.variant, DesignSystemButtonVariant.quiet);
      expect(open.label, 'Open');
      expect(open.alignsLabelToLeadingEdge, isTrue);
      expect(undo.variant, DesignSystemButtonVariant.quiet);
      expect(undo.size, open.size);
      expect(undo.label, 'Undo');
      // The undo sits away from the tap that merely looks.
      final openRect = tester.getRect(
        find.byKey(const ValueKey('front-door-open-0')),
      );
      final undoRect = tester.getRect(
        find.byKey(const ValueKey('front-door-take-back-0')),
      );
      final card = tester.getRect(find.byType(FrontDoorCard));
      expect(undoRect.left - openRect.right, greaterThan(card.width / 3));
      await tester.tap(find.byKey(const ValueKey('front-door-open-0')));
      await tester.tap(find.byKey(const ValueKey('front-door-take-back-0')));
      expect(acted, [('open', 'd:door:0'), ('take-back', 'd:door:0')]);
    });

    testWidgets('saved as a note, or made into a task, offers the same', (
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
      expect(lineOf(tester, 0), 'Saved as a note');
      expect(lineOf(tester, 1), 'Made into a task');
      expect(tester.widget<Icon>(glyph(1)).icon, LottiIcons.confirmCircled);
      await tester.tap(find.byKey(const ValueKey('front-door-open-1')));
      await tester.tap(find.byKey(const ValueKey('front-door-take-back-0')));
      expect(acted, [('open', 'd:door:1'), ('take-back', 'd:door:0')]);
    });

    testWidgets('a proposal said no to, and an item left where it is, each '
        'say so and offer an undo', (tester) async {
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
      expect(lineOf(tester, 0), 'Not filed');
      expect(lineOf(tester, 1), 'Left here in the thread');
      expect(glyph(0), findsNothing);
      expect(glyph(1), findsNothing);
      for (final index in [0, 1]) {
        final undo = button(tester, 'undo', index);
        expect(undo.variant, DesignSystemButtonVariant.quiet);
        expect(undo.label, 'Undo');
        expect(undo.alignsLabelToLeadingEdge, isTrue);
      }
      await tester.tap(find.byKey(const ValueKey('front-door-undo-1')));
      expect(acted, [('undo', 'd:door:1')]);
      expect(find.byType(DesignSystemButton), findsNWidgets(2));
    });
  });

  group('an inbox item', () {
    testWidgets('asks where it should go, leads with the tap that writes a '
        'task, puts leaving it at the far edge, and the other ways out on '
        'their own line as quiet iconed buttons with the guess first', (
      tester,
    ) async {
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

      expect(lineOf(tester, 0), 'Where should this go?');
      final all = buttons(tester);
      expect(all.map((b) => b.label), [
        'Make it a task',
        'Leave it',
        'Start a goal…',
        'Save as a note',
      ]);
      expect(all.first.variant, DesignSystemButtonVariant.primary);
      for (final other in all.skip(1)) {
        expect(other.variant, DesignSystemButtonVariant.quiet);
        expect(other.size, all.first.size);
      }
      expect(all[1].leadingIcon, isNull);
      expect(all[2].leadingIcon, LottiIcons.focus);
      expect(all[2].alignsLabelToLeadingEdge, isTrue);
      expect(all[3].leadingIcon, LottiIcons.note);
      final leave = tester.getRect(
        find.byKey(const ValueKey('front-door-decline-0')),
      );
      final task = tester.getRect(
        find.byKey(const ValueKey('front-door-task-0')),
      );
      final goal = tester.getRect(
        find.byKey(const ValueKey('front-door-goal-0')),
      );
      expect(leave.top, closeTo(task.top, 1));
      expect(
        leave.right,
        closeTo(tester.getRect(find.byType(FrontDoorCard)).right, 1),
      );
      expect(goal.top, greaterThan(task.bottom));

      await tester.tap(find.byKey(const ValueKey('front-door-goal-0')));
      await tester.tap(find.byKey(const ValueKey('front-door-task-0')));
      await tester.tap(find.byKey(const ValueKey('front-door-note-0')));
      await tester.tap(find.byKey(const ValueKey('front-door-decline-0')));
      expect(acted, [
        ('goal', 'd:door:0'),
        ('task', 'd:door:0'),
        ('note', 'd:door:0'),
        ('decline', 'd:door:0'),
      ]);
    });

    testWidgets('a new project leads the ways out with its own; an unrouted '
        'one has no project way; one sent back from a proposal asks where '
        'instead', (tester) async {
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

      expect(buttons(tester).map((b) => b.label), [
        'Make it a task',
        'Leave it',
        'New project…',
        'Start a goal…',
        'Save as a note',
        'Make it a task',
        'Leave it',
        'Start a goal…',
        'Save as a note',
        'Make it a task',
        'Leave it',
        'Start a goal…',
        'Save as a note',
      ]);
      expect(button(tester, 'project', 0).leadingIcon, LottiIcons.folder);
      expect(lineOf(tester, 2), 'Where should this go instead?');
      await tester.tap(find.byKey(const ValueKey('front-door-project-0')));
      expect(acted, [('project', 'd:door:0')]);
    });

    testWidgets('while its action is in flight the controls are disabled', (
      tester,
    ) async {
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
        ],
        busy: {'d:door:0'},
      );
      for (final control in buttons(tester)) {
        expect(control.onPressed, isNull);
      }
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

    expect(lineOf(tester, 0), 'Asking the task…');
    expect(lineOf(tester, 1), 'Asking the project…');
    expect(lineOf(tester, 2), 'Asking the goal…');
    expect(lineOf(tester, 3), 'Asking the person…');
    for (final index in [4, 5, 6, 7]) {
      expect(lineOf(tester, index), 'Asking this…');
    }
    expect(find.textContaining('id-'), findsNothing);
  });
}

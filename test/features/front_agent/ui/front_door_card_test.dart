import 'package:flutter_test/flutter_test.dart';
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

  Future<void> pump(WidgetTester tester, List<FrontDoorEntry> doors) async {
    await tester.pumpWidget(
      makeTestableWidget(FrontDoorCard(doors: doors)),
    );
    await tester.pump();
  }

  String statusOf(WidgetTester tester, int index) => tester
      .widget<Text>(find.byKey(ValueKey('front-door-status-$index')))
      .data!;

  testWidgets('quotes each segment and shows an answer under its owner, '
      'with its caveats', (tester) async {
    await pump(tester, [
      FrontDoorEntry(
        record: record(
          index: 0,
          text: 'How is the garden?',
          outcome: const FrontDoorAnswer(
            text: 'The seam walk is next.',
            summaryBased: true,
            incomplete: true,
          ),
        ),
      ),
      FrontDoorEntry(
        record: record(
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
  });

  testWidgets("a specialist's reply is shown as theirs once it has landed, "
      'and awaited until then', (tester) async {
    await pump(tester, [
      FrontDoorEntry(
        record: record(
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
      FrontDoorEntry(
        record: record(
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
      FrontDoorEntry(record: record(index: 0, text: 'Garden?')),
      FrontDoorEntry(
        record: record(
          index: 1,
          text: 'Buy a hose.',
          outcome: const FrontDoorSkipped(FrontDoorSkipReason.statementsLater),
        ),
      ),
      FrontDoorEntry(
        record: record(
          index: 2,
          text: 'Pip?',
          kind: FrontDestinationKind.person,
          ownerTitle: 'Pip',
          outcome: const FrontDoorSkipped(FrontDoorSkipReason.noAgent),
        ),
      ),
      FrontDoorEntry(
        record: record(
          index: 3,
          text: 'Relocation?',
          kind: FrontDestinationKind.project,
          ownerTitle: 'Relocation',
          outcome: const FrontDoorSkipped(
            FrontDoorSkipReason.inferenceUnavailable,
          ),
        ),
      ),
      FrontDoorEntry(
        record: record(
          index: 4,
          text: 'Learn accordion.',
          kind: FrontDestinationKind.newThing,
          ownerTitle: null,
          outcome: const FrontDoorSkipped(FrontDoorSkipReason.noDoor),
        ),
      ),
      FrontDoorEntry(
        record: record(
          index: 5,
          text: 'Fence?',
          outcome: const FrontDoorFailed('StateError'),
        ),
      ),
    ]);

    expect(statusOf(tester, 0), 'Asking Garden…');
    expect(
      statusOf(tester, 1),
      'Not filed: for now she only answers questions.',
    );
    expect(statusOf(tester, 2), 'Pip has no agent to ask yet.');
    expect(statusOf(tester, 3), 'Relocation has no working AI setup.');
    expect(statusOf(tester, 4), 'Nowhere to take this yet.');
    expect(statusOf(tester, 5), 'Asking Garden failed.');
    expect(find.byKey(const ValueKey('front-door-text-0')), findsNothing);
    // The error type never reaches the user.
    expect(find.textContaining('StateError'), findsNothing);
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
      ].indexed)
        FrontDoorEntry(
          record: record(
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
    expect(statusOf(tester, 4), 'Asking this…');
    expect(find.textContaining('id-'), findsNothing);
  });
}

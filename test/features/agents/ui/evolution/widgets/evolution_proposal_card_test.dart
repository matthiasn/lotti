import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_proposal_card.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  const testProposal = PendingProposal(
    directives: 'New improved directives.',
    rationale: 'Better error handling and retries.',
  );

  var approvePressed = false;
  var rejectPressed = false;

  Widget buildSubject({
    PendingProposal proposal = testProposal,
    String? currentDirectives = 'You are a helpful agent.',
    bool isWaiting = false,
  }) {
    approvePressed = false;
    rejectPressed = false;
    return makeTestableWidgetWithScaffold(
      EvolutionProposalCard(
        proposal: proposal,
        currentDirectives: currentDirectives,
        onApprove: () => approvePressed = true,
        onReject: () => rejectPressed = true,
        isWaiting: isWaiting,
      ),
    );
  }

  group('EvolutionProposalCard', () {
    testWidgets('shows proposal title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionProposalCard));
      expect(
        find.text(context.messages.agentEvolutionProposalTitle),
        findsOneWidget,
      );
    });

    testWidgets('shows current and proposed directives', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionProposalCard));
      expect(
        find.text(context.messages.agentEvolutionCurrentDirectives),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentEvolutionProposedDirectives),
        findsOneWidget,
      );
      expect(find.text('You are a helpful agent.'), findsOneWidget);
      expect(find.text('New improved directives.'), findsOneWidget);
    });

    testWidgets('shows rationale when present', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionProposalCard));
      expect(
        find.text(context.messages.agentEvolutionProposalRationale),
        findsOneWidget,
      );
      expect(
        find.text('Better error handling and retries.'),
        findsOneWidget,
      );
    });

    testWidgets('hides rationale when empty', (tester) async {
      const emptyRationale = PendingProposal(
        directives: 'New directives.',
        rationale: '',
      );
      await tester.pumpWidget(buildSubject(proposal: emptyRationale));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionProposalCard));
      expect(
        find.text(context.messages.agentEvolutionProposalRationale),
        findsNothing,
      );
    });

    testWidgets('hides current directives when null', (tester) async {
      await tester.pumpWidget(buildSubject(currentDirectives: null));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionProposalCard));
      expect(
        find.text(context.messages.agentEvolutionCurrentDirectives),
        findsNothing,
      );
    });

    testWidgets('approve button calls onApprove', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionProposalCard));
      await tester.tap(find.text(context.messages.agentTemplateEvolveApprove));
      await tester.pump();

      expect(approvePressed, isTrue);
    });

    testWidgets('reject button calls onReject', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionProposalCard));
      await tester.tap(find.text(context.messages.agentTemplateEvolveReject));
      await tester.pump();

      expect(rejectPressed, isTrue);
    });

    testWidgets('buttons are disabled when isWaiting', (tester) async {
      await tester.pumpWidget(buildSubject(isWaiting: true));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionProposalCard));

      // Reject button should be disabled
      final rejectButton = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text(context.messages.agentTemplateEvolveReject),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(rejectButton.onPressed, isNull);
    });
  });
}

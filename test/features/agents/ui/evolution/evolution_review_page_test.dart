import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_review_page.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_summary_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    String templateId = kTestTemplateId,
    FutureOr<AgentDomainEntity?> Function(Ref, String)? templateOverride,
    FutureOr<ClassifiedFeedback?> Function(Ref, String)? feedbackOverride,
    FutureOr<AgentDomainEntity?> Function(Ref, String)? pendingOverride,
    FutureOr<List<AgentDomainEntity>> Function(Ref, String)? sessionsOverride,
    List<Override> extraOverrides = const [],
  }) {
    final template = makeTestTemplate(
      id: templateId,
      agentId: templateId,
      displayName: 'Daily Standup',
    );

    return makeTestableWidgetNoScroll(
      EvolutionReviewPage(templateId: templateId),
      overrides: [
        agentTemplateProvider.overrideWith(
          templateOverride ?? (ref, id) async => template,
        ),
        ritualFeedbackProvider.overrideWith(
          feedbackOverride ?? (ref, id) async => null,
        ),
        pendingRitualReviewProvider.overrideWith(
          pendingOverride ?? (ref, id) async => null,
        ),
        evolutionSessionsProvider.overrideWith(
          sessionsOverride ?? (ref, id) async => [],
        ),
        ...extraOverrides,
      ],
    );
  }

  group('EvolutionReviewPage', () {
    testWidgets('shows "Ritual Review" title in app bar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionReviewPage));
      expect(
        find.text(context.messages.agentRitualReviewTitle),
        findsOneWidget,
      );
    });

    testWidgets('shows template display name', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Daily Standup'), findsOneWidget);
    });

    testWidgets('shows Feedback Signals section header', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionReviewPage));
      expect(
        find.text(context.messages.agentRitualReviewFeedbackTitle),
        findsOneWidget,
      );
    });

    testWidgets('shows no-feedback empty state when feedback is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionReviewPage));
      expect(
        find.text(context.messages.agentRitualReviewNoFeedback),
        findsOneWidget,
      );
    });

    testWidgets('shows FeedbackSummarySection when feedback has items', (
      tester,
    ) async {
      final feedback = makeTestClassifiedFeedback(
        items: [
          makeTestClassifiedFeedbackItem(detail: 'Agent was accurate'),
        ],
      );

      await tester.pumpWidget(
        buildSubject(feedbackOverride: (ref, id) async => feedback),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FeedbackSummarySection), findsOneWidget);
    });

    testWidgets('shows feedbackSummary text when active session has one', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        feedbackSummary: 'Agent performed well in most areas.',
      );

      await tester.pumpWidget(
        buildSubject(pendingOverride: (ref, id) async => session),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Agent performed well in most areas.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows proposal section label inside summary card when session has '
      'feedbackSummary',
      (tester) async {
        final session = makeTestEvolutionSession(
          feedbackSummary: 'Summary text here.',
        );

        await tester.pumpWidget(
          buildSubject(pendingOverride: (ref, id) async => session),
        );
        await tester.pump();

        final context = tester.element(find.byType(EvolutionReviewPage));
        expect(
          find.text(context.messages.agentRitualReviewProposalSection),
          findsOneWidget,
        );
      },
    );

    testWidgets('summary text is bounded with ellipsis overflow', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        feedbackSummary: 'Summary text here.',
      );

      await tester.pumpWidget(
        buildSubject(pendingOverride: (ref, id) async => session),
      );
      await tester.pump();

      final summaryText = tester.widget<Text>(find.text('Summary text here.'));
      expect(summaryText.maxLines, 8);
      expect(summaryText.overflow, TextOverflow.ellipsis);
    });

    testWidgets('does not show proposal card when pending session is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final context = tester.element(find.byType(EvolutionReviewPage));
      // No proposal section label should appear (it's part of the card)
      expect(
        find.text(context.messages.agentRitualReviewProposalSection),
        findsNothing,
      );
    });

    testWidgets(
      'FAB with "Start Conversation" appears when there is an active session',
      (tester) async {
        final session = makeTestEvolutionSession();

        await tester.pumpWidget(
          buildSubject(pendingOverride: (ref, id) async => session),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FloatingActionButton), findsOneWidget);
        final context = tester.element(find.byType(EvolutionReviewPage));
        expect(
          find.text(context.messages.agentRitualReviewAction),
          findsOneWidget,
        );
      },
    );

    testWidgets('FAB appears when there is no active session', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      final context = tester.element(find.byType(EvolutionReviewPage));
      expect(
        find.text(context.messages.agentRitualReviewAction),
        findsOneWidget,
      );
    });

    testWidgets(
      'ignores non-session pending entities for FAB and proposal card',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            pendingOverride: (ref, id) async => makeTestTemplate(
              id: 'not-a-session',
              agentId: id,
            ),
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(EvolutionReviewPage));
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(
          find.text(context.messages.agentRitualReviewProposalSection),
          findsNothing,
        );
      },
    );

    testWidgets(
      'renders SizedBox.shrink when pending session provider has error',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            pendingOverride: (ref, id) =>
                Future<AgentDomainEntity?>.error(Exception('fail')),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(EvolutionReviewPage));
        expect(find.text(context.messages.commonError), findsNothing);
      },
    );

    testWidgets(
      'does not show feedbackSummary box when session has null feedbackSummary',
      (tester) async {
        // makeTestEvolutionSession defaults feedbackSummary to null.
        final session = makeTestEvolutionSession();

        await tester.pumpWidget(
          buildSubject(pendingOverride: (ref, id) async => session),
        );
        await tester.pumpAndSettle();

        // The FAB should still be present.
        expect(find.byType(FloatingActionButton), findsOneWidget);
        final context = tester.element(find.byType(EvolutionReviewPage));
        // Proposal section label exists only inside the summary card.
        expect(
          find.text(context.messages.agentRitualReviewProposalSection),
          findsNothing,
        );
      },
    );

    testWidgets('shows empty template name when template is not loaded', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(templateOverride: (ref, id) async => null),
      );
      await tester.pumpAndSettle();

      // Template name should be empty — 'Daily Standup' must not appear.
      expect(find.text('Daily Standup'), findsNothing);
    });

    testWidgets('shows loading indicator while feedback is loading', (
      tester,
    ) async {
      // Use a Completer so no timer is left pending after the test.
      final completer = Completer<ClassifiedFeedback?>();

      await tester.pumpWidget(
        buildSubject(feedbackOverride: (ref, id) => completer.future),
      );
      // One pump to start the async operation — provider stays in loading.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets(
      'shows common error text when feedback provider emits an error',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            feedbackOverride: (ref, id) => Future<ClassifiedFeedback?>.error(
              Exception('extraction failed'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(EvolutionReviewPage));
        expect(find.text(context.messages.commonError), findsOneWidget);
      },
    );
  });
}

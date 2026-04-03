import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_review_page.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/ritual_session_history_card.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/ritual_summary_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  final summaryMetrics = RitualSummaryMetrics(
    lifetimeWakeCount: 40,
    wakesSinceLastSession: 6,
    totalTokenUsageSinceLastSession: 888,
    meanTimeToResolution: const Duration(hours: 3),
    dailyWakeCounts: List.generate(
      5,
      (index) => DailyWakeCountBucket(
        date: DateTime(2024, 3, 20 + index),
        wakeCount: index + 1,
      ),
    ),
  );

  Widget buildSubject({
    String templateId = kTestTemplateId,
    FutureOr<AgentDomainEntity?> Function()? templateOverride,
    FutureOr<AgentDomainEntity?> Function()? pendingOverride,
    FutureOr<RitualSummaryMetrics> Function()? summaryOverride,
    FutureOr<List<RitualSessionHistoryEntry>> Function()? historyOverride,
    MediaQueryData? mediaQueryData,
    List<Override> extraOverrides = const [],
  }) {
    final template = makeTestTemplate(
      id: templateId,
      agentId: templateId,
      displayName: 'Daily Standup',
    );

    return makeTestableWidgetNoScroll(
      EvolutionReviewPage(templateId: templateId),
      mediaQueryData: mediaQueryData,
      overrides: [
        agentTemplateProvider.overrideWith(
          (ref, id) async => await (templateOverride?.call() ?? template),
        ),
        pendingRitualReviewProvider.overrideWith(
          (ref, id) async => await pendingOverride?.call(),
        ),
        ritualSummaryMetricsProvider.overrideWith(
          (ref, id) async => await (summaryOverride?.call() ?? summaryMetrics),
        ),
        ritualSessionHistoryProvider.overrideWith(
          (ref, id) async => await (historyOverride?.call() ?? const []),
        ),
        ...extraOverrides,
      ],
    );
  }

  group('EvolutionReviewPage', () {
    testWidgets('shows template name plus ritual home copy', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionReviewPage));

      expect(find.text('Daily Standup'), findsOneWidget);
      expect(
        find.text(context.messages.agentRitualReviewTitle),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.text(context.messages.agentRitualSummarySubtitle),
        findsAtLeastNWidgets(1),
      );
      expect(find.byType(RitualSummaryCard), findsOneWidget);
    });

    testWidgets('shows start card when no ritual is pending', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          mediaQueryData: phoneMediaQueryData.copyWith(
            size: const Size(390, 1600),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionReviewPage));

      expect(
        find.text(context.messages.agentRitualSummaryStartHint),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentRitualReviewAction),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text(context.messages.agentEvolutionNoSessions),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(context.messages.agentEvolutionNoSessions),
        findsOneWidget,
      );
    });

    testWidgets('shows pending session card details when ritual is active', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        sessionNumber: 3,
        feedbackSummary: 'The user wants less self-congratulation.',
      );

      await tester.pumpWidget(
        buildSubject(
          pendingOverride: () async => session,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('The user wants less self-congratulation.'),
        findsOneWidget,
      );
      expect(find.textContaining('3'), findsWidgets);
    });

    testWidgets('renders persisted session history entries', (tester) async {
      final session = makeTestEvolutionSession(
        id: 'session-1',
        sessionNumber: 2,
        status: EvolutionSessionStatus.completed,
        completedAt: DateTime(2024, 3, 18, 9),
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: session.id,
        tldr: 'Short recap of what changed.',
      );

      await tester.pumpWidget(
        buildSubject(
          historyOverride: () async => [
            RitualSessionHistoryEntry(
              session: session,
              recap: recap,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Short recap of what changed.'),
        200,
      );
      expect(find.byType(RitualSessionHistoryCard), findsOneWidget);
      expect(find.text('Short recap of what changed.'), findsOneWidget);
    });

    testWidgets('shows loading card while summary metrics load', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          summaryOverride: () => Completer<RitualSummaryMetrics>().future,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('keeps the review page usable when history loading fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          mediaQueryData: phoneMediaQueryData.copyWith(
            size: const Size(390, 1600),
          ),
          historyOverride: () async => throw Exception('fail'),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionReviewPage));
      expect(
        find.text(context.messages.agentRitualReviewAction),
        findsOneWidget,
      );
      expect(find.byType(RitualSessionHistoryCard), findsNothing);
    });

    testWidgets('shows SizedBox.shrink when summary metrics fail', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          mediaQueryData: phoneMediaQueryData.copyWith(
            size: const Size(390, 1600),
          ),
          summaryOverride: () async => throw Exception('summary failed'),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the summary card is NOT rendered.
      expect(find.byType(RitualSummaryCard), findsNothing);

      // Verify no summary-specific text appears (e.g. "Total Wakes").
      expect(find.text('Total Wakes'), findsNothing);

      // Page is still usable — the start card and hero panel are present.
      final context = tester.element(find.byType(EvolutionReviewPage));
      expect(
        find.text(context.messages.agentRitualReviewAction),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentRitualSummarySubtitle),
        findsOneWidget,
      );
    });

    testWidgets('shows session badge with number in pending card', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        sessionNumber: 5,
      );

      await tester.pumpWidget(
        buildSubject(
          pendingOverride: () async => session,
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionReviewPage));

      // Proposal section title should appear.
      expect(
        find.text(context.messages.agentRitualReviewProposalSection),
        findsOneWidget,
      );
      // Session badge should show the session number.
      expect(
        find.text(
          context.messages.agentEvolutionSessionProgress(5, 5),
        ),
        findsOneWidget,
      );
      // Action button should appear.
      expect(
        find.text(context.messages.agentRitualReviewAction),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows pending session card without feedback summary',
      (tester) async {
        final session = makeTestEvolutionSession(
          sessionNumber: 2,
        );

        await tester.pumpWidget(
          buildSubject(
            pendingOverride: () async => session,
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(EvolutionReviewPage));

        // The proposal section title and action button should be present.
        expect(
          find.text(context.messages.agentRitualReviewProposalSection),
          findsOneWidget,
        );
        expect(
          find.text(context.messages.agentRitualReviewAction),
          findsOneWidget,
        );

        // Session badge should display the session progress.
        expect(
          find.text(context.messages.agentEvolutionSessionProgress(2, 2)),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows loading placeholder while history loads', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          mediaQueryData: phoneMediaQueryData.copyWith(
            size: const Size(390, 1600),
          ),
          historyOverride: () =>
              Completer<List<RitualSessionHistoryEntry>>().future,
        ),
      );
      // Allow summary and other providers to settle, but history stays
      // loading because its Completer never completes.
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byType(CircularProgressIndicator),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byType(CircularProgressIndicator),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('renders SizedBox.shrink while pending session loads', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          pendingOverride: () => Completer<AgentDomainEntity?>().future,
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(EvolutionReviewPage));

      // While the pending provider is loading, neither the start card nor
      // the pending session card should appear.
      expect(
        find.text(context.messages.agentRitualSummaryStartHint),
        findsNothing,
      );
      expect(
        find.text(context.messages.agentRitualReviewProposalSection),
        findsNothing,
      );
    });
  });
}

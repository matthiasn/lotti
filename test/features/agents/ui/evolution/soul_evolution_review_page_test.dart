import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_review_page.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/ritual_session_history_card.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    SoulDocumentEntity? soul,
    FutureOr<AgentDomainEntity?> Function()? pendingOverride,
    FutureOr<List<RitualSessionHistoryEntry>> Function()? historyOverride,
    List<String> templateIds = const ['template-1'],
    MediaQueryData? mediaQueryData,
    List<Override> extraOverrides = const [],
  }) {
    final defaultSoul = soul ?? makeTestSoulDocument(displayName: 'Laura');

    return makeTestableWidgetNoScroll(
      const SoulEvolutionReviewPage(soulId: kTestSoulId),
      mediaQueryData: mediaQueryData,
      overrides: [
        soulDocumentProvider.overrideWith(
          (ref, id) async => defaultSoul,
        ),
        pendingSoulEvolutionProvider.overrideWith(
          (ref, id) async => await pendingOverride?.call(),
        ),
        soulEvolutionSessionHistoryProvider.overrideWith(
          (ref, id) async => await (historyOverride?.call() ?? const []),
        ),
        templatesUsingSoulProvider.overrideWith(
          (ref, id) async => templateIds,
        ),
        ...extraOverrides,
      ],
    );
  }

  group('SoulEvolutionReviewPage', () {
    testWidgets('shows soul name in app bar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Laura'), findsOneWidget);
    });

    testWidgets('shows hero panel with subtitle text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(
        find.byType(SoulEvolutionReviewPage),
      );
      expect(
        find.text(context.messages.agentSoulReviewHeroSubtitle),
        findsOneWidget,
      );
    });

    testWidgets('shows template count badge', (tester) async {
      await tester.pumpWidget(
        buildSubject(templateIds: ['template-1', 'template-2']),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SoulEvolutionReviewPage));
      expect(
        find.text(context.messages.agentSoulReviewTemplateCount(2)),
        findsOneWidget,
      );
    });

    testWidgets('shows start card when no pending session', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(
        find.byType(SoulEvolutionReviewPage),
      );
      expect(
        find.text(context.messages.agentSoulReviewStartAction),
        findsOneWidget,
      );
    });

    testWidgets('start card disabled when no templates use soul', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(templateIds: []));
      await tester.pumpAndSettle();

      final button = tester.widget<DesignSystemButton>(
        find.byType(DesignSystemButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('shows pending session card when session is active', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        agentId: kTestSoulId,
        templateId: kTestSoulId,
      );

      await tester.pumpWidget(
        buildSubject(pendingOverride: () async => session),
      );
      await tester.pumpAndSettle();

      final context = tester.element(
        find.byType(SoulEvolutionReviewPage),
      );
      expect(
        find.text(context.messages.agentSoulReviewStartAction),
        findsOneWidget,
      );
    });

    testWidgets('shows empty history message when no sessions', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          mediaQueryData: phoneMediaQueryData.copyWith(
            size: const Size(390, 1600),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(
        find.byType(SoulEvolutionReviewPage),
      );
      await tester.scrollUntilVisible(
        find.text(context.messages.agentSoulEvolutionNoSessions),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(context.messages.agentSoulEvolutionNoSessions),
        findsOneWidget,
      );
    });

    testWidgets('shows session history cards', (tester) async {
      final session = makeTestEvolutionSession(
        id: 'session-1',
        agentId: kTestSoulId,
        templateId: kTestSoulId,
        sessionNumber: 2,
        status: EvolutionSessionStatus.completed,
        completedAt: DateTime(2024, 3, 18, 9),
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: 'session-1',
        tldr: 'Refined the voice directive.',
      );

      await tester.pumpWidget(
        buildSubject(
          historyOverride: () async => [
            RitualSessionHistoryEntry(session: session, recap: recap),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Refined the voice directive.'),
        200,
      );
      expect(find.byType(RitualSessionHistoryCard), findsOneWidget);
      expect(find.text('Refined the voice directive.'), findsOneWidget);
    });

    testWidgets('shows loading card during async load', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          mediaQueryData: phoneMediaQueryData.copyWith(
            size: const Size(390, 1600),
          ),
          historyOverride: () =>
              Completer<List<RitualSessionHistoryEntry>>().future,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byType(CircularProgressIndicator),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    });
  });
}

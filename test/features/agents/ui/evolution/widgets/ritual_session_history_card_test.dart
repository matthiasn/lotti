import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/ritual_session_history_card.dart';

import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject(RitualSessionHistoryEntry entry) {
    return makeTestableWidgetWithScaffold(
      RitualSessionHistoryCard(entry: entry),
    );
  }

  group('RitualSessionHistoryCard', () {
    testWidgets('renders recap tldr when present', (tester) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
        feedbackSummary: 'Legacy fallback summary.',
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: session.id,
        tldr: 'This recap summary should be shown.',
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session, recap: recap),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This recap summary should be shown.'), findsOneWidget);
      expect(find.text('Legacy fallback summary.'), findsNothing);
    });

    testWidgets('falls back to feedbackSummary when recap tldr is blank', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
        feedbackSummary: 'Legacy fallback summary.',
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: session.id,
        tldr: '   ',
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session, recap: recap),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Legacy fallback summary.'), findsOneWidget);
    });

    testWidgets('renders no summary when both tldr and feedbackSummary empty', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: session.id,
        tldr: '',
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session, recap: recap),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is Text && w.maxLines == 3),
        findsNothing,
      );
    });

    testWidgets('renders human-readable rating labels from stored recap keys', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: session.id,
        categoryRatings: const {
          'internal_alignment': 4,
          'cleanAchievements': 3,
          'communication': 5,
        },
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session, recap: recap),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Internal Alignment 4/5'), findsOneWidget);
      expect(find.text('Clean Achievements 3/5'), findsOneWidget);
      expect(find.text('Communication 5/5'), findsOneWidget);
      expect(find.text('General 4/5'), findsNothing);
      expect(find.text('General 3/5'), findsNothing);
    });
  });
}

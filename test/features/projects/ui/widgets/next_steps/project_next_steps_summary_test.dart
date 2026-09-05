import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/projects/ui/widgets/next_steps/project_next_steps_summary.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../../widget_test_utils.dart';
import '../../../../agents/test_data/change_set_factories.dart';

void main() {
  final now = DateTime(2026, 9, 5, 12);
  final steps = [
    makeTestProjectRecommendation(
      id: 'added-1',
      title: 'Confirm the escort',
      status: ProjectRecommendationStatus.resolved,
      createdTaskId: 'task-1',
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
    makeTestProjectRecommendation(
      id: 'added-2',
      title: 'Split the first wave',
      position: 1,
      status: ProjectRecommendationStatus.resolved,
      createdTaskId: 'task-2',
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
    makeTestProjectRecommendation(
      id: 'done-1',
      title: 'Brief the elders',
      position: 2,
      status: ProjectRecommendationStatus.resolved,
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
    makeTestProjectRecommendation(
      id: 'dismissed-1',
      title: 'Retire the April tasks',
      position: 3,
      status: ProjectRecommendationStatus.dismissed,
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
  ];

  testWidgets('the summary line tallies the run and dates the agent', (
    tester,
  ) async {
    var toggles = 0;
    await tester.pumpWidget(
      makeTestableWidget2(
        ProjectNextStepsSummary(
          steps: steps,
          runCreatedAt: now.subtract(const Duration(minutes: 40)),
          now: now,
          historyOpen: false,
          onToggleHistory: () => toggles++,
        ),
      ),
    );

    expect(
      find.text('Last run: 2 added, 1 done, 1 dismissed · 40 min ago'),
      findsOneWidget,
    );
    expect(find.text('Confirm the escort'), findsNothing);
    await tester.tap(find.text('Show history'));
    expect(toggles, 1);
  });

  testWidgets('open history lists every step with its outcome', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        ProjectNextStepsSummary(
          steps: steps,
          runCreatedAt: now.subtract(const Duration(hours: 5)),
          now: now,
          historyOpen: true,
          onToggleHistory: () {},
        ),
      ),
    );

    expect(find.text('Hide history'), findsOneWidget);
    for (final title in [
      'Confirm the escort',
      'Split the first wave',
      'Brief the elders',
      'Retire the April tasks',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Added'), findsNWidgets(2));
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Dismissed'), findsOneWidget);
    expect(find.textContaining('5 h ago'), findsOneWidget);
  });

  testWidgets('an open step in the history reads as pending', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        ProjectNextStepsSummary(
          steps: [
            ...steps,
            makeTestProjectRecommendation(id: 'open', title: 'Still open'),
          ],
          runCreatedAt: now,
          now: now,
          historyOpen: true,
          onToggleHistory: () {},
        ),
      ),
    );

    expect(find.text('Still open'), findsOneWidget);
    expect(find.text('1 pending'), findsOneWidget);
  });

  testWidgets('a legacy run without a snapshot dates itself by its newest '
      'step', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        ProjectNextStepsSummary(
          steps: steps,
          runCreatedAt: null,
          now: now,
          historyOpen: false,
          onToggleHistory: () {},
        ),
      ),
    );

    expect(find.textContaining('· 2 h ago'), findsOneWidget);
  });

  testWidgets('the empty band says when the agent last looked', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        ProjectNextStepsEmpty(
          runCreatedAt: now.subtract(const Duration(days: 3)),
          now: now,
        ),
      ),
    );
    expect(
      find.text('No open suggestions. Last looked 3 days ago.'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      makeTestableWidget2(ProjectNextStepsEmpty(runCreatedAt: null, now: now)),
    );
    expect(find.text('No open suggestions.'), findsOneWidget);
  });

  test('formatProjectNextStepsAge buckets into the band wording', () async {
    final messages = await AppLocalizations.delegate.load(const Locale('en'));
    String age(Duration elapsed) =>
        formatProjectNextStepsAge(messages, elapsed);

    expect(age(Duration.zero), 'just now');
    expect(age(const Duration(seconds: 59)), 'just now');
    expect(age(const Duration(seconds: -30)), 'just now');
    expect(age(const Duration(minutes: 1)), '1 min ago');
    expect(age(const Duration(minutes: 59, seconds: 59)), '59 min ago');
    expect(age(const Duration(hours: 1)), '1 h ago');
    expect(age(const Duration(hours: 23, minutes: 59)), '23 h ago');
    expect(age(const Duration(days: 1)), '1 day ago');
    expect(age(const Duration(days: 45)), '45 days ago');
  });
}

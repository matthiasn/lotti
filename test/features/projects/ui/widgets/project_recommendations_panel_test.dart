import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/projects/ui/widgets/project_recommendations_panel.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_utils.dart';

void main() {
  const projectId = 'project-1';

  Widget subject({required MockProjectRecommendationService service}) {
    return makeTestableWidgetWithScaffold(
      const ProjectRecommendationsPanel(projectId: projectId),
      overrides: [
        projectRecommendationsProvider(projectId).overrideWith((ref) async {
          return [
            makeTestProjectRecommendation(
              id: 'recommendation-1',
              agentId: 'agent-1',
              projectId: projectId,
              title: 'Unblock launch QA',
              rationale: 'The staging dataset is incomplete.',
            ),
          ];
        }),
        projectRecommendationServiceProvider.overrideWithValue(service),
      ],
    );
  }

  testWidgets('renders durable recommendations as an actionable DS section', (
    tester,
  ) async {
    final service = MockProjectRecommendationService();
    await tester.pumpWidget(subject(service: service));
    await tester.pumpAndSettle();

    expect(find.byType(DesignSystemSectionCard), findsOneWidget);
    expect(find.text('Recommended next steps'), findsOneWidget);
    expect(find.text('Unblock launch QA'), findsOneWidget);
    expect(find.text('The staging dataset is incomplete.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('resolve and dismiss actions call the recommendation service', (
    tester,
  ) async {
    final service = MockProjectRecommendationService();
    when(() => service.markResolved(any())).thenAnswer((_) async => true);
    when(
      () => service.dismissRecommendation(any()),
    ).thenAnswer((_) async => true);
    await tester.pumpWidget(subject(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mark resolved'));
    await tester.pump();
    verify(() => service.markResolved('recommendation-1')).called(1);

    await tester.pumpWidget(subject(service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    verify(
      () => service.dismissRecommendation('recommendation-1'),
    ).called(1);
  });

  testWidgets('keeps both actions inert while an update is pending', (
    tester,
  ) async {
    final completer = Completer<bool>();
    final service = MockProjectRecommendationService();
    when(() => service.markResolved(any())).thenAnswer((_) => completer.future);
    await tester.pumpWidget(subject(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mark resolved'));
    await tester.pump();

    final busyActions = tester
        .widgetList<DesignSystemIconAction>(
          find.byType(DesignSystemIconAction),
        )
        .toList();
    expect(busyActions.first.isBusy, isTrue);
    expect(busyActions.every((action) => action.onPressed == null), isTrue);

    completer.complete(true);
    await tester.pumpAndSettle();
    final idleActions = tester
        .widgetList<DesignSystemIconAction>(
          find.byType(DesignSystemIconAction),
        )
        .toList();
    expect(idleActions.every((action) => action.onPressed != null), isTrue);
  });

  testWidgets('shows the localized error for false and throwing updates', (
    tester,
  ) async {
    final service = MockProjectRecommendationService();
    when(() => service.markResolved(any())).thenAnswer((_) async => false);
    when(
      () => service.dismissRecommendation(any()),
    ).thenThrow(StateError('persistence failed'));
    await tester.pumpWidget(subject(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mark resolved'));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't update the recommendation. Please try again."),
      findsOneWidget,
    );

    await tester.pumpWidget(subject(service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't update the recommendation. Please try again."),
      findsOneWidget,
    );
  });

  testWidgets('renders nothing when there are no active recommendations', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ProjectRecommendationsPanel(projectId: projectId),
        overrides: [
          projectRecommendationsProvider(
            projectId,
          ).overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DesignSystemSectionCard), findsNothing);
    expect(find.text('Recommended next steps'), findsNothing);
  });

  testWidgets('separates multiple recommendations without duplicating header', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ProjectRecommendationsPanel(projectId: projectId),
        overrides: [
          projectRecommendationsProvider(projectId).overrideWith((ref) async {
            return [
              makeTestProjectRecommendation(
                id: 'recommendation-1',
                agentId: 'agent-1',
                projectId: projectId,
                title: 'Unblock launch QA',
              ),
              makeTestProjectRecommendation(
                id: 'recommendation-2',
                agentId: 'agent-1',
                projectId: projectId,
                title: 'Confirm the launch manifest',
              ),
            ];
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DesignSystemDivider), findsNWidgets(2));
    expect(find.text('Recommended next steps'), findsOneWidget);
    expect(find.text('Unblock launch QA'), findsOneWidget);
    expect(find.text('Confirm the launch manifest'), findsOneWidget);
  });

  testWidgets('collapses when recommendation loading fails', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ProjectRecommendationsPanel(projectId: projectId),
        overrides: [
          projectRecommendationsProvider(projectId).overrideWith((ref) async {
            throw StateError('agent database unavailable');
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DesignSystemSectionCard), findsNothing);
    expect(find.text('Recommended next steps'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/template_instance_overview.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/agents/ui/template_instances_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';

const _templateId = 'template-001';
final _now = DateTime(2026, 8, 8, 12);

TemplateInstanceOverview _instance({
  String agentId = 'agent-001',
  String displayName = 'Laura on task',
  String? taskId = 'task-001',
  DateTime? lastWakeAt,
  int totalTokens = 0,
  AgentLifecycle lifecycle = AgentLifecycle.active,
}) {
  return TemplateInstanceOverview(
    agentId: agentId,
    displayName: displayName,
    lifecycle: lifecycle,
    createdAt: _now.subtract(const Duration(days: 3)),
    lastWakeAt: lastWakeAt,
    taskId: taskId,
    totalTokens: totalTokens,
  );
}

Widget _buildSubject({
  required List<TemplateInstanceOverview> instances,
  String? taskTitle = 'Ship the release notes',
}) {
  return makeTestableWidgetWithScaffold(
    const CustomScrollView(
      slivers: [TemplateInstancesSliver(templateId: _templateId)],
    ),
    overrides: [
      templateInstanceOverviewProvider.overrideWith(
        (ref, id) async => instances,
      ),
      pendingWakeTargetTitleProvider.overrideWith(
        (ref, id) async => taskTitle,
      ),
    ],
  );
}

void main() {
  group('TemplateInstancesSliver', () {
    testWidgets('names each instance by its task, not by the agent', (
      tester,
    ) async {
      // The agent's display name is the same on every row of a template, so
      // it identifies nothing. The task is what the user recognises.
      await tester.pumpWidget(_buildSubject(instances: [_instance()]));
      await tester.pumpAndSettle();

      // The shared row merges title and subtitle into one rich span on wide
      // layouts, so an exact-text finder would miss it.
      expect(find.textContaining('Ship the release notes'), findsOneWidget);
      expect(find.textContaining('Laura on task'), findsNothing);
    });

    testWidgets('falls back to the agent name when there is no task', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(instances: [_instance(taskId: null)]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Laura on task'), findsOneWidget);
    });

    testWidgets('shows when the instance started and when it last woke', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          instances: [
            _instance(lastWakeAt: _now.subtract(const Duration(hours: 5))),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TemplateInstancesSliver));
      final subtitle = find.textContaining('2026-08-05 12:00');
      expect(
        subtitle,
        findsOneWidget,
        reason:
            'the start date is what separates a long-lived agent from a '
            'fresh one',
      );
      expect(
        find.textContaining('2026-08-08 07:00'),
        findsOneWidget,
        reason: 'and the last wake says whether it is still working',
      );
      expect(
        find.textContaining(context.messages.agentTemplateInstanceNeverActive),
        findsNothing,
      );
    });

    testWidgets('says so explicitly when an instance has never woken', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject(instances: [_instance()]));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TemplateInstancesSliver));
      expect(
        find.textContaining(context.messages.agentTemplateInstanceNeverActive),
        findsOneWidget,
      );
    });

    testWidgets('offers the task link only for an instance that has one', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          instances: [
            _instance(),
            _instance(agentId: 'a-2', taskId: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    });

    testWidgets('builds only the rows on screen', (tester) async {
      // The defect this list replaces: a Column materialised every instance,
      // and a template collects one per task. With 500 rows a lazy sliver
      // must build a small fraction of them.
      final instances = List.generate(
        500,
        (i) => _instance(agentId: 'agent-$i', displayName: 'Agent $i'),
      );

      await tester.pumpWidget(
        _buildSubject(instances: instances, taskTitle: null),
      );
      await tester.pumpAndSettle();

      final built = tester
          .widgetList<TemplateInstanceRow>(find.byType(TemplateInstanceRow))
          .length;
      expect(built, lessThan(50), reason: 'built $built of 500 rows');
      expect(built, greaterThan(0));
    });

    testWidgets('says when a template has no instances at all', (tester) async {
      await tester.pumpWidget(_buildSubject(instances: const []));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TemplateInstancesSliver));
      expect(
        find.text(context.messages.agentTemplateInstancesEmpty),
        findsOneWidget,
      );
    });
  });
}

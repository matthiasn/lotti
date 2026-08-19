import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/template_instance_overview.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/features/agents/ui/listing/widgets/agent_list_row.dart';
import 'package:lotti/features/agents/ui/template_instances_section.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
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
  late MockNavService nav;
  late RecordingBeamerDelegate delegate;

  setUp(() async {
    nav = MockNavService();
    delegate = RecordingBeamerDelegate();
    when(() => nav.index).thenReturn(0);
    when(() => nav.settingsIndex).thenReturn(5);
    when(() => nav.setIndex(any())).thenReturn(null);
    when(() => nav.settingsDelegate).thenReturn(delegate);
    when(() => nav.persistNamedRoute(any())).thenAnswer((_) async {});
    when(() => nav.beamToNamed(any())).thenReturn(null);
    await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<NavService>(nav),
    );
  });

  tearDown(tearDownTestGetIt);

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

      expect(find.byIcon(LottiIcons.openExternal), findsOneWidget);
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

    testWidgets('opens the agent internals when the row is tapped', (
      tester,
    ) async {
      // The row is the way into "why did this agent do that" — state,
      // conversation log, reports.
      await tester.pumpWidget(_buildSubject(instances: [_instance()]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TemplateInstanceRow));
      await tester.pump();

      verify(() => nav.setIndex(5)).called(1);
      expect(
        delegate.beamed,
        contains('/settings/agents/instances/agent-001'),
      );
    });

    testWidgets('opens the task from the trailing button', (tester) async {
      await tester.pumpWidget(_buildSubject(instances: [_instance()]));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LottiIcons.openExternal));
      await tester.pump();

      verify(() => nav.beamToNamed('/tasks/task-001')).called(1);
    });

    testWidgets('shows the token total, and nothing for an unused instance', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          instances: [
            _instance(totalTokens: 12345),
            _instance(agentId: 'agent-002', taskId: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Both halves of the claim: the used instance shows its total, and the
      // unused one shows nothing rather than a bare "0". Asserted on the row
      // data, since an absent meta cell has no text to search for.
      final rows = tester
          .widgetList<AgentListRow>(find.byType(AgentListRow))
          .toList();
      expect(rows, hasLength(2));
      expect(rows.first.data.metaRight, '12,345');
      expect(rows.last.data.metaRight, isNull);
    });

    testWidgets('renders a pill for every lifecycle', (tester) async {
      // The switch has an arm per lifecycle; a missing one is a wrong colour
      // on a row the user reads as status.
      await tester.pumpWidget(
        _buildSubject(
          instances: [
            for (final lifecycle in AgentLifecycle.values)
              _instance(
                agentId: 'agent-${lifecycle.name}',
                lifecycle: lifecycle,
              ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TemplateInstancesSliver));
      for (final lifecycle in AgentLifecycle.values) {
        expect(
          find.text(agentLifecycleLabel(context.messages, lifecycle)),
          findsOneWidget,
          reason: lifecycle.name,
        );
      }
    });

    testWidgets('surfaces a load failure instead of an empty list', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CustomScrollView(
            slivers: [TemplateInstancesSliver(templateId: _templateId)],
          ),
          overrides: [
            templateInstanceOverviewProvider.overrideWith(
              (ref, id) async => throw StateError('agent db unavailable'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('agent db unavailable'), findsOneWidget);
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

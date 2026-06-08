import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/agent_instances_list.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../widget_test_utils.dart';
import 'agent_instances_list_test_helpers.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required List<InstanceVm> vms,
  }) async {
    // Toolbar (filter / group / sort + search) is laid out inline. The
    // default 800px test surface squeezes the search field below its
    // minimum content width — match the desktop settings-pane width so
    // the layout matches what the page is designed for.
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: AgentInstancesList()),
        mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
        overrides: [
          agentInstanceVmsProvider.overrideWith((ref) async => vms),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('AgentInstancesList — rendering', () {
    testWidgets('renders one row per VM with title, ID, and time portion', (
      tester,
    ) async {
      await pumpPage(
        tester,
        vms: [
          hVm(
            id: 'agent-1',
            name: 'Task Laura',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026, 5, 4, 19, 25),
            soulName: 'Laura',
            soulId: 'soul-laura',
          ),
        ],
      );

      expect(find.text('Task Laura'), findsOneWidget);
      expect(find.text('agent-1'), findsOneWidget);
      expect(find.text('19:25'), findsOneWidget);
    });

    testWidgets('evolution row uses localized title from sessionNumber', (
      tester,
    ) async {
      await pumpPage(
        tester,
        vms: [
          hVm(
            id: 'evo-1',
            name: '',
            type: InstanceType.evolution,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026, 5, 4, 18),
            sessionNumber: 7,
          ),
        ],
      );

      final ctx = tester.element(find.byType(AgentInstancesList));
      expect(
        find.text(ctx.messages.agentEvolutionSessionTitle(7)),
        findsOneWidget,
      );
    });

    testWidgets('result count reads "N instances" with no filters', (
      tester,
    ) async {
      await pumpPage(
        tester,
        vms: [
          hVm(
            id: 'a',
            name: 'A',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
          ),
          hVm(
            id: 'b',
            name: 'B',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026, 1, 2),
          ),
        ],
      );

      final ctx = tester.element(find.byType(AgentInstancesList));
      expect(
        find.text(ctx.messages.agentInstancesResultCountAll(2)),
        findsOneWidget,
      );
    });
  });

  group('AgentInstancesList — search', () {
    testWidgets('typing in search narrows the list and updates the count', (
      tester,
    ) async {
      await pumpPage(
        tester,
        vms: [
          hVm(
            id: 'a',
            name: 'Alpha',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
          ),
          hVm(
            id: 'b',
            name: 'Bravo',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026, 1, 2),
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'alp');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Bravo'), findsNothing);

      final ctx = tester.element(find.byType(AgentInstancesList));
      expect(
        find.text(ctx.messages.agentInstancesResultCountFiltered(1, 2)),
        findsOneWidget,
      );
    });

    testWidgets('search chip shows the query in curly quotes', (tester) async {
      await pumpPage(
        tester,
        vms: [
          hVm(
            id: 'a',
            name: 'Alpha',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'alp');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('“alp”'), findsOneWidget);
    });

    testWidgets('search-field clear icon resets the query', (tester) async {
      await pumpPage(
        tester,
        vms: [
          hVm(
            id: 'a',
            name: 'Alpha',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
          ),
          hVm(
            id: 'b',
            name: 'Bravo',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026, 1, 2),
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'alp');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Bravo'), findsNothing);

      await tester.tap(
        find.byTooltip(
          tester
              .element(find.byType(AgentInstancesList))
              .messages
              .agentInstancesSearchClear,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Bravo'), findsOneWidget);
    });
  });

  group('AgentInstancesList — empty / error states', () {
    testWidgets(
      'empty filtered state shows the empty message and clears via "Clear all"',
      (tester) async {
        await pumpPage(
          tester,
          vms: [
            hVm(
              id: 'a',
              name: 'Alpha',
              type: InstanceType.taskAgent,
              status: AgentLifecycle.active,
              updatedAt: DateTime(2026),
            ),
          ],
        );

        await tester.enterText(find.byType(TextField), 'no-such-thing');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final ctx = tester.element(find.byType(AgentInstancesList));
        expect(
          find.text(ctx.messages.agentInstancesEmptyFiltered),
          findsOneWidget,
        );

        // Two "Clear all" affordances appear (chip-row text button + empty
        // state TextButton). Tapping either restores the row.
        final clearAll = find.text(
          ctx.messages.agentInstancesFilterClearAll,
        );
        expect(clearAll, findsAtLeast(1));
        await tester.tap(clearAll.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Alpha'), findsOneWidget);
      },
    );

    testWidgets('renders error state when the VM provider fails', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Scaffold(body: AgentInstancesList()),
          overrides: [
            agentInstanceVmsProvider.overrideWith(
              (ref) async => throw Exception('boom'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(AgentInstancesList));
      expect(find.text(ctx.messages.commonError), findsOneWidget);
    });
  });

  group('AgentInstancesList — sticky group sections', () {
    testWidgets('groups by Soul by default with active count + total', (
      tester,
    ) async {
      await pumpPage(
        tester,
        vms: [
          hVm(
            id: 'a',
            name: 'Task A',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026, 1, 3),
            soulName: 'Laura',
            soulId: 'soul-laura',
          ),
          hVm(
            id: 'b',
            name: 'Task B',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.dormant,
            updatedAt: DateTime(2026, 1, 2),
            soulName: 'Laura',
            soulId: 'soul-laura',
          ),
          hVm(
            id: 'c',
            name: 'Task C',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
            soulName: 'Iris',
            soulId: 'soul-iris',
          ),
        ],
      );

      expect(find.text('Laura'), findsOneWidget);
      expect(find.text('Iris'), findsOneWidget);

      final ctx = tester.element(find.byType(AgentInstancesList));
      expect(
        find.text(ctx.messages.agentInstancesGroupActiveCount(1)),
        findsAtLeast(2),
      );

      expect(find.text('· 2'), findsOneWidget);
      expect(find.text('· 1'), findsOneWidget);
    });

    testWidgets('clicking a group header collapses its rows', (tester) async {
      await pumpPage(
        tester,
        vms: [
          hVm(
            id: 'a',
            name: 'Task A',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
            soulName: 'Laura',
            soulId: 'soul-laura',
          ),
        ],
      );

      expect(find.text('Task A'), findsOneWidget);
      await tester.tap(find.text('Laura'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Task A'), findsNothing);
    });
  });

  group('AgentInstancesList — navigation', () {
    testWidgets('tapping a row beams to /settings/agents/instances/{id}', (
      tester,
    ) async {
      String? navigated;
      beamToNamedOverride = (path) => navigated = path;

      await pumpPage(
        tester,
        vms: [
          hVm(
            id: 'agent-nav',
            name: 'Nav Agent',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
          ),
        ],
      );

      await tester.tap(find.text('Nav Agent'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(navigated, '/settings/agents/instances/agent-nav');
    });
  });

  group('AgentInstancesList — Filters popover', () {
    testWidgets(
      'tapping a type row toggles a chip and shows it in the active row',
      (tester) async {
        await pumpPage(
          tester,
          vms: [
            hVm(
              id: 'a',
              name: 'Alpha',
              type: InstanceType.taskAgent,
              status: AgentLifecycle.active,
              updatedAt: DateTime(2026),
              soulName: 'Laura',
              soulId: 'soul-laura',
            ),
            hVm(
              id: 'b',
              name: 'Bravo',
              type: InstanceType.evolution,
              status: AgentLifecycle.active,
              updatedAt: DateTime(2026),
              sessionNumber: 1,
            ),
          ],
        );

        final ctx = tester.element(find.byType(AgentInstancesList));
        await tester.tap(
          find.text(ctx.messages.agentInstancesToolbarFilters),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Section header is visible.
        expect(
          find.text(
            ctx.messages.agentInstancesFilterSectionType.toUpperCase(),
          ),
          findsOneWidget,
        );

        // Tap the "Task Agent" row in the popover (its label is the
        // localized type label).
        await tester.tap(
          find.text(ctx.messages.agentTemplateKindTaskAgent).last,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Dismiss popover so the chip below renders without the panel.
        await tester.tapAt(const Offset(20, 20));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Filtered list shows only the task agent.
        expect(find.text('Alpha'), findsOneWidget);
        expect(
          find.text(ctx.messages.agentEvolutionSessionTitle(1)),
          findsNothing,
        );
        // Result count reflects the filtered total.
        expect(
          find.text(ctx.messages.agentInstancesResultCountFiltered(1, 2)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'section "Clear" link drops a per-axis filter without touching others',
      (tester) async {
        await pumpPage(
          tester,
          vms: [
            hVm(
              id: 'a',
              name: 'Alpha',
              type: InstanceType.taskAgent,
              status: AgentLifecycle.active,
              updatedAt: DateTime(2026),
            ),
          ],
        );

        final ctx = tester.element(find.byType(AgentInstancesList));
        await tester.tap(
          find.text(ctx.messages.agentInstancesToolbarFilters),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Toggle a Type filter, then a Status filter.
        await tester.tap(
          find.text(ctx.messages.agentTemplateKindTaskAgent).last,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text(ctx.messages.agentLifecycleActive).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The Type section's "Clear" appears (it has a selection).
        // There may be two Clear links (Type + Status) — tap the first.
        final clears = find.text(
          ctx.messages.agentInstancesFilterClearSection,
        );
        expect(clears, findsAtLeast(1));
        await tester.tap(clears.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Dismiss popover and inspect chips.
        await tester.tapAt(const Offset(20, 20));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // Status chip ("Active") still rendered; Task Agent chip gone.
        expect(
          find.text(ctx.messages.agentLifecycleActive),
          findsAtLeast(1),
        );
      },
    );

    testWidgets('tapping a soul swatch row toggles a soul filter', (
      tester,
    ) async {
      await pumpPage(
        tester,
        vms: [
          hVm(
            id: 'a',
            name: 'Alpha',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
            soulName: 'Laura',
            soulId: 'soul-laura',
          ),
          hVm(
            id: 'b',
            name: 'Bravo',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
            soulName: 'Iris',
            soulId: 'soul-iris',
          ),
        ],
      );

      final ctx = tester.element(find.byType(AgentInstancesList));
      await tester.tap(
        find.text(ctx.messages.agentInstancesToolbarFilters),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The Soul section header lights up only when at least one soul is
      // present in the data — sanity check it.
      expect(
        find.text(
          ctx.messages.agentInstancesFilterSectionSoul.toUpperCase(),
        ),
        findsOneWidget,
      );

      // Tap "Laura" row inside the popover.
      await tester.tap(find.text('Laura').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Bravo'), findsNothing);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/agent_instances_list.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../widget_test_utils.dart';

InstanceVm _vm({
  required String id,
  required String name,
  required InstanceType type,
  required AgentLifecycle status,
  required DateTime updatedAt,
  String? soulName,
  String? soulId,
  String? templateName,
  String? templateId,
  int? sessionNumber,
}) {
  return InstanceVm(
    id: id,
    displayName: name,
    type: type,
    status: status,
    updatedAt: updatedAt,
    sessionNumber: sessionNumber,
    soulName: soulName,
    soulId: soulId,
    templateId: templateId,
    templateName: templateName,
    searchKey: '$name $id ${soulName ?? ''} ${templateName ?? ''}'
        .toLowerCase(),
  );
}

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
    await tester.pumpAndSettle();
  }

  group('AgentInstancesList — rendering', () {
    testWidgets('renders one row per VM with title, ID, and time portion', (
      tester,
    ) async {
      await pumpPage(
        tester,
        vms: [
          _vm(
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
          _vm(
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
          _vm(
            id: 'a',
            name: 'A',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
          ),
          _vm(
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
          _vm(
            id: 'a',
            name: 'Alpha',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
          ),
          _vm(
            id: 'b',
            name: 'Bravo',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026, 1, 2),
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'alp');
      await tester.pumpAndSettle();

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
          _vm(
            id: 'a',
            name: 'Alpha',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'alp');
      await tester.pumpAndSettle();
      expect(find.text('“alp”'), findsOneWidget);
    });

    testWidgets('search-field clear icon resets the query', (tester) async {
      await pumpPage(
        tester,
        vms: [
          _vm(
            id: 'a',
            name: 'Alpha',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
          ),
          _vm(
            id: 'b',
            name: 'Bravo',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026, 1, 2),
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'alp');
      await tester.pumpAndSettle();
      expect(find.text('Bravo'), findsNothing);

      await tester.tap(
        find.byTooltip(
          tester
              .element(find.byType(AgentInstancesList))
              .messages
              .agentInstancesSearchClear,
        ),
      );
      await tester.pumpAndSettle();

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
            _vm(
              id: 'a',
              name: 'Alpha',
              type: InstanceType.taskAgent,
              status: AgentLifecycle.active,
              updatedAt: DateTime(2026),
            ),
          ],
        );

        await tester.enterText(find.byType(TextField), 'no-such-thing');
        await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();
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
          _vm(
            id: 'a',
            name: 'Task A',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026, 1, 3),
            soulName: 'Laura',
            soulId: 'soul-laura',
          ),
          _vm(
            id: 'b',
            name: 'Task B',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.dormant,
            updatedAt: DateTime(2026, 1, 2),
            soulName: 'Laura',
            soulId: 'soul-laura',
          ),
          _vm(
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
          _vm(
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
      await tester.pumpAndSettle();
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
          _vm(
            id: 'agent-nav',
            name: 'Nav Agent',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
          ),
        ],
      );

      await tester.tap(find.text('Nav Agent'));
      await tester.pumpAndSettle();
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
            _vm(
              id: 'a',
              name: 'Alpha',
              type: InstanceType.taskAgent,
              status: AgentLifecycle.active,
              updatedAt: DateTime(2026),
              soulName: 'Laura',
              soulId: 'soul-laura',
            ),
            _vm(
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
        await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

        // Dismiss popover so the chip below renders without the panel.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

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
            _vm(
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
        await tester.pumpAndSettle();

        // Toggle a Type filter, then a Status filter.
        await tester.tap(
          find.text(ctx.messages.agentTemplateKindTaskAgent).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(ctx.messages.agentLifecycleActive).last);
        await tester.pumpAndSettle();

        // The Type section's "Clear" appears (it has a selection).
        // There may be two Clear links (Type + Status) — tap the first.
        final clears = find.text(
          ctx.messages.agentInstancesFilterClearSection,
        );
        expect(clears, findsAtLeast(1));
        await tester.tap(clears.first);
        await tester.pumpAndSettle();

        // Dismiss popover and inspect chips.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
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
          _vm(
            id: 'a',
            name: 'Alpha',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
            soulName: 'Laura',
            soulId: 'soul-laura',
          ),
          _vm(
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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Bravo'), findsNothing);
    });
  });

  group('AgentInstancesList — Group by / Sort popovers', () {
    testWidgets('switching Group by to Type re-groups under the Type label', (
      tester,
    ) async {
      await pumpPage(
        tester,
        vms: [
          _vm(
            id: 'a',
            name: 'Alpha',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
            soulName: 'Laura',
            soulId: 'soul-laura',
          ),
          _vm(
            id: 'b',
            name: 'Bravo',
            type: InstanceType.evolution,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
            sessionNumber: 2,
          ),
        ],
      );

      final ctx = tester.element(find.byType(AgentInstancesList));

      // The Group by button: title contains a static prefix and the
      // current axis label. Tap the button by finding the prefix text.
      await tester.tap(
        find.textContaining(ctx.messages.agentInstancesToolbarGroupBy),
      );
      await tester.pumpAndSettle();

      // Pick "Type" from the menu (single-select; closes on tap).
      await tester.tap(
        find.text(ctx.messages.agentInstancesGroupByType).last,
      );
      await tester.pumpAndSettle();

      // Group headers now show the localized type label, not the raw
      // enum name.
      expect(
        find.text(ctx.messages.agentTemplateKindTaskAgent),
        findsAtLeast(1),
      );
      expect(
        find.text(ctx.messages.agentInstancesKindEvolution),
        findsAtLeast(1),
      );
    });

    testWidgets(
      'switching Group by to Status updates the trigger label and groups',
      (tester) async {
        await pumpPage(
          tester,
          vms: [
            _vm(
              id: 'a',
              name: 'Alpha',
              type: InstanceType.taskAgent,
              status: AgentLifecycle.active,
              updatedAt: DateTime(2026),
            ),
            _vm(
              id: 'b',
              name: 'Bravo',
              type: InstanceType.taskAgent,
              status: AgentLifecycle.dormant,
              updatedAt: DateTime(2026),
            ),
          ],
        );

        final ctx = tester.element(find.byType(AgentInstancesList));
        await tester.tap(
          find.textContaining(ctx.messages.agentInstancesToolbarGroupBy),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(ctx.messages.agentInstancesGroupByStatus).last,
        );
        await tester.pumpAndSettle();

        // The Group by button now shows the Status label as its trailing
        // value (the switch arm covered by this test).
        expect(
          find.textContaining(ctx.messages.agentInstancesGroupByStatus),
          findsAtLeast(1),
        );
        // Status group headers paint the localized lifecycle label.
        expect(
          find.text(ctx.messages.agentLifecycleActive),
          findsAtLeast(1),
        );
        expect(
          find.text(ctx.messages.agentLifecycleDormant),
          findsAtLeast(1),
        );
      },
    );

    testWidgets(
      'Status and Soul "Clear" links each clear their own section',
      (tester) async {
        await pumpPage(
          tester,
          vms: [
            _vm(
              id: 'a',
              name: 'Alpha',
              type: InstanceType.taskAgent,
              status: AgentLifecycle.active,
              updatedAt: DateTime(2026),
              soulName: 'Laura',
              soulId: 'soul-laura',
            ),
          ],
        );

        final ctx = tester.element(find.byType(AgentInstancesList));
        await tester.tap(
          find.text(ctx.messages.agentInstancesToolbarFilters),
        );
        await tester.pumpAndSettle();

        // Toggle a status, toggle a soul.
        await tester.tap(find.text(ctx.messages.agentLifecycleActive).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Laura').last);
        await tester.pumpAndSettle();

        // Two "Clear" links appear (Status + Soul). Tap them in turn —
        // the first hits the Status onClear callback, the second hits
        // the Soul one.
        var clears = find.text(
          ctx.messages.agentInstancesFilterClearSection,
        );
        expect(clears, findsNWidgets(2));
        await tester.tap(clears.first);
        await tester.pumpAndSettle();

        clears = find.text(ctx.messages.agentInstancesFilterClearSection);
        expect(clears, findsOneWidget);
        await tester.tap(clears);
        await tester.pumpAndSettle();

        // Both sections cleared → no Clear links left.
        expect(
          find.text(ctx.messages.agentInstancesFilterClearSection),
          findsNothing,
        );
      },
    );

    testWidgets(
      'switching Sort to Name reorders the rows alphabetically',
      (tester) async {
        await pumpPage(
          tester,
          vms: [
            _vm(
              id: 'b',
              name: 'Bravo',
              type: InstanceType.taskAgent,
              status: AgentLifecycle.active,
              updatedAt: DateTime(2026),
              soulName: 'Solo',
              soulId: 'soul-solo',
            ),
            _vm(
              id: 'a',
              name: 'Alpha',
              type: InstanceType.taskAgent,
              status: AgentLifecycle.active,
              updatedAt: DateTime(2026, 1, 2),
              soulName: 'Solo',
              soulId: 'soul-solo',
            ),
          ],
        );

        final ctx = tester.element(find.byType(AgentInstancesList));
        await tester.tap(find.text(ctx.messages.agentInstancesSortRecent));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(ctx.messages.agentInstancesSortName).last,
        );
        await tester.pumpAndSettle();

        // Both rows render; confirm Alpha exists then Bravo (paint order).
        expect(find.text('Alpha'), findsOneWidget);
        expect(find.text('Bravo'), findsOneWidget);
        final alphaY = tester.getTopLeft(find.text('Alpha')).dy;
        final bravoY = tester.getTopLeft(find.text('Bravo')).dy;
        expect(alphaY < bravoY, isTrue);
      },
    );
  });

  group('AgentInstancesList — active filter chips', () {
    testWidgets(
      'each chip variant (type / soul / search) removes its own filter',
      (tester) async {
        await pumpPage(
          tester,
          vms: [
            _vm(
              id: 'a',
              name: 'Alpha',
              type: InstanceType.taskAgent,
              status: AgentLifecycle.active,
              updatedAt: DateTime(2026),
              soulName: 'Laura',
              soulId: 'soul-laura',
            ),
          ],
        );

        final ctx = tester.element(find.byType(AgentInstancesList));

        // Type chip via popover.
        await tester.tap(
          find.text(ctx.messages.agentInstancesToolbarFilters),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(ctx.messages.agentTemplateKindTaskAgent).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Laura').last); // soul chip
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        // Search chip.
        await tester.enterText(find.byType(TextField), 'al');
        await tester.pumpAndSettle();

        // Three remove icons (type, soul, search) plus their chip
        // labels are visible.
        expect(find.byIcon(Icons.cancel_rounded), findsNWidgets(3));

        // Remove all three by tapping each cancel icon. Re-evaluate the
        // finder between taps since each removal shrinks the chip row.
        while (find.byIcon(Icons.cancel_rounded).evaluate().isNotEmpty) {
          await tester.tap(find.byIcon(Icons.cancel_rounded).first);
          await tester.pumpAndSettle();
        }

        // No chips left → result count is back to the unfiltered form.
        expect(
          find.text(ctx.messages.agentInstancesResultCountAll(1)),
          findsOneWidget,
        );
      },
    );

    testWidgets('removing a chip via its close icon clears just that filter', (
      tester,
    ) async {
      await pumpPage(
        tester,
        vms: [
          _vm(
            id: 'a',
            name: 'Alpha',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
            soulName: 'Laura',
            soulId: 'soul-laura',
          ),
        ],
      );

      final ctx = tester.element(find.byType(AgentInstancesList));
      await tester.tap(
        find.text(ctx.messages.agentInstancesToolbarFilters),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ctx.messages.agentLifecycleActive).last);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // ActiveFilterChip uses Icons.cancel_rounded — find the chip by its
      // label and tap the chip itself (whole chip is the remove target).
      expect(
        find.byIcon(Icons.cancel_rounded),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.cancel_rounded));
      await tester.pumpAndSettle();

      // No more active filter → result count is the unfiltered form.
      expect(
        find.text(ctx.messages.agentInstancesResultCountAll(1)),
        findsOneWidget,
      );
    });
  });

  group('AgentInstancesList — compact toolbar layout', () {
    testWidgets(
      'narrow surface lays toolbar buttons in a Wrap with search below',
      (tester) async {
        // 500px is below the 700px wide-toolbar threshold, so the toolbar
        // falls into the Wrap + full-width search branch.
        await tester.binding.setSurfaceSize(const Size(500, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const Scaffold(body: AgentInstancesList()),
            mediaQueryData: const MediaQueryData(size: Size(500, 900)),
            overrides: [
              agentInstanceVmsProvider.overrideWith(
                (ref) async => [
                  _vm(
                    id: 'a',
                    name: 'Alpha',
                    type: InstanceType.taskAgent,
                    status: AgentLifecycle.active,
                    updatedAt: DateTime(2026),
                  ),
                ],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final ctx = tester.element(find.byType(AgentInstancesList));

        // Wrap is the compact-mode toolbar wrapper.
        expect(find.byType(Wrap), findsAtLeast(1));

        // Search field still works at narrow width.
        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();
        // "1 vm total, 0 filtered" — counts diverge so the filtered form
        // renders.
        expect(
          find.text(ctx.messages.agentInstancesResultCountFiltered(0, 1)),
          findsOneWidget,
        );
      },
    );
  });

  group('AgentInstancesList — row content variants', () {
    testWidgets('wide row shows the template name as the task subtitle', (
      tester,
    ) async {
      await pumpPage(
        tester,
        vms: [
          _vm(
            id: 'agent-1',
            name: 'Task Laura',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026, 5, 4, 10, 30),
            soulName: 'Laura',
            soulId: 'soul-laura',
            templateId: 'tpl-laura',
            templateName: 'Laura template',
          ),
        ],
      );

      // The wide-layout row uses Text.rich; the template name appears as
      // a separate text run alongside the title.
      expect(
        find.textContaining('Laura template'),
        findsOneWidget,
      );
    });

    testWidgets(
      'compact row stacks template subtitle and ID under the title',
      (tester) async {
        // < 600px → instance row falls into the compact layout branch.
        await tester.binding.setSurfaceSize(const Size(560, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const Scaffold(body: AgentInstancesList()),
            mediaQueryData: const MediaQueryData(size: Size(560, 900)),
            overrides: [
              agentInstanceVmsProvider.overrideWith(
                (ref) async => [
                  _vm(
                    id: 'agent-c',
                    name: 'Task Iris',
                    type: InstanceType.taskAgent,
                    // Group by Type so showSoul=true and the avatar
                    // branch in the compact layout is hit.
                    status: AgentLifecycle.active,
                    updatedAt: DateTime(2026),
                    soulName: 'Iris',
                    soulId: 'soul-iris',
                    templateId: 'tpl-iris',
                    templateName: 'Iris template',
                  ),
                ],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final ctx = tester.element(find.byType(AgentInstancesList));

        // Switch group axis to Type so the row renders with showSoul=true,
        // exercising the compact-layout avatar branch.
        await tester.tap(
          find.textContaining(ctx.messages.agentInstancesToolbarGroupBy),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(ctx.messages.agentInstancesGroupByType).last,
        );
        await tester.pumpAndSettle();

        expect(find.text('Task Iris'), findsOneWidget);
        expect(find.text('Iris template'), findsOneWidget);
        expect(find.text('agent-c'), findsOneWidget);
      },
    );

    testWidgets(
      'status pill paints destroyed and created accents',
      (tester) async {
        await pumpPage(
          tester,
          vms: [
            _vm(
              id: 'a',
              name: 'Old Agent',
              type: InstanceType.taskAgent,
              status: AgentLifecycle.destroyed,
              updatedAt: DateTime(2026),
            ),
            _vm(
              id: 'b',
              name: 'New Agent',
              type: InstanceType.taskAgent,
              status: AgentLifecycle.created,
              updatedAt: DateTime(2026, 1, 2),
            ),
          ],
        );

        final ctx = tester.element(find.byType(AgentInstancesList));
        // Both arms render their localized labels (the destroyed/created
        // arms of the status switch are the only way to hit those lines).
        expect(
          find.text(ctx.messages.agentLifecycleDestroyed),
          findsOneWidget,
        );
        expect(
          find.text(ctx.messages.agentLifecycleCreated),
          findsOneWidget,
        );
      },
    );
  });

  group('AgentInstancesList — search no-op guard', () {
    testWidgets(
      'entering the same value twice does not strip group rows below',
      (tester) async {
        // Regression guard for the no-op search guard: when the controller
        // re-fires the same value, the page must not collapse / lose
        // existing rows (which would happen if the guard mistakenly
        // wiped state).
        await pumpPage(
          tester,
          vms: [
            _vm(
              id: 'a',
              name: 'Alpha',
              type: InstanceType.taskAgent,
              status: AgentLifecycle.active,
              updatedAt: DateTime(2026),
              soulName: 'Laura',
              soulId: 'soul-laura',
            ),
          ],
        );

        await tester.enterText(find.byType(TextField), 'alp');
        await tester.pumpAndSettle();
        // Re-enter the same query — controller fires onChanged with the
        // unchanged value; the guard skips the rebuild path but the row
        // must still be there.
        await tester.enterText(find.byType(TextField), 'alp');
        await tester.pumpAndSettle();

        expect(find.text('Alpha'), findsOneWidget);
      },
    );
  });
}

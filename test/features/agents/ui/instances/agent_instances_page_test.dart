import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/instances/agent_instances_page.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/widgets/agent_list_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../../widget_test_utils.dart';

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

/// A simple soul-bearing task-agent VM. The page always renders an avatar
/// leading for these, which is what most tests want.
InstanceVm _soulVm({
  required String id,
  required String name,
  required DateTime updatedAt,
  String soulName = 'Solo',
  String soulId = 'soul-solo',
  AgentLifecycle status = AgentLifecycle.active,
}) {
  return _vm(
    id: id,
    name: name,
    type: InstanceType.taskAgent,
    status: status,
    updatedAt: updatedAt,
    soulName: soulName,
    soulId: soulId,
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
    // The inline toolbar squeezes the search field below its minimum width
    // on the default 800px surface; match the desktop settings-pane width.
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: AgentInstancesPage()),
        mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
        overrides: [
          agentInstanceVmsProvider.overrideWith((ref) async => vms),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Selects a sort axis through the real toolbar popover. The Sort button's
  /// child text is the *current* axis label, so we tap that to open the menu
  /// then tap the requested label.
  Future<void> selectSort(
    WidgetTester tester, {
    required String currentLabel,
    required String nextLabel,
  }) async {
    await tester.tap(find.text(currentLabel).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(nextLabel).last);
    await tester.pumpAndSettle();
  }

  group('AgentInstancesPage — Oldest sort axis', () {
    testWidgets(
      'switching Sort to Oldest orders rows by ascending updatedAt',
      (tester) async {
        await pumpPage(
          tester,
          vms: [
            // Bravo is the most recent; under default Recent sort it leads.
            _soulVm(
              id: 'b',
              name: 'Bravo',
              updatedAt: DateTime(2026, 5, 10),
            ),
            _soulVm(
              id: 'a',
              name: 'Alpha',
              updatedAt: DateTime(2026),
            ),
          ],
        );

        final ctx = tester.element(find.byType(AgentInstancesPage));

        // Default Recent sort: newest (Bravo) is above oldest (Alpha).
        expect(
          tester.getTopLeft(find.text('Bravo')).dy,
          lessThan(tester.getTopLeft(find.text('Alpha')).dy),
        );

        // Switch to Oldest — the ascending comparator (line 266) now puts
        // the oldest row (Alpha) on top.
        await selectSort(
          tester,
          currentLabel: ctx.messages.agentInstancesSortRecent,
          nextLabel: ctx.messages.agentInstancesSortOldest,
        );

        expect(
          tester.getTopLeft(find.text('Alpha')).dy,
          lessThan(tester.getTopLeft(find.text('Bravo')).dy),
        );
      },
    );
  });

  group('AgentInstancesPage — Name sort id tiebreaker', () {
    testWidgets(
      'two rows with identical titles fall through to the id comparator',
      (tester) async {
        String? navigated;
        beamToNamedOverride = (path) => navigated = path;

        await pumpPage(
          tester,
          vms: [
            // Identical display names so the Name comparator's `byName` is 0
            // and ordering must fall through to `a.id.compareTo(b.id)`
            // (line 274). Listed b-id first to prove the sort reorders them.
            _soulVm(
              id: 'b-id',
              name: 'Twin',
              updatedAt: DateTime(2026, 5, 10),
            ),
            _soulVm(
              id: 'a-id',
              name: 'Twin',
              updatedAt: DateTime(2026, 5),
            ),
          ],
        );

        final ctx = tester.element(find.byType(AgentInstancesPage));
        await selectSort(
          tester,
          currentLabel: ctx.messages.agentInstancesSortRecent,
          nextLabel: ctx.messages.agentInstancesSortName,
        );

        // Both rows render the identical "Twin" title; identify ordering by
        // position, then confirm the topmost row is a-id by tapping it and
        // checking the beam target — proving the id tiebreaker (not the
        // pre-sort insertion order) placed a-id first.
        final titles = find.text('Twin');
        expect(titles, findsNWidgets(2));
        expect(
          tester.getTopLeft(titles.first).dy,
          lessThan(tester.getTopLeft(titles.last).dy),
        );

        await tester.tap(titles.first);
        await tester.pumpAndSettle();
        expect(navigated, '/settings/agents/instances/a-id');
      },
    );
  });

  group('AgentInstancesPage — evolution session rows', () {
    testWidgets(
      'renders the localized session title with no template subtitle and '
      'beams to the instance route',
      (tester) async {
        String? navigated;
        beamToNamedOverride = (path) => navigated = path;

        await pumpPage(
          tester,
          vms: [
            _vm(
              id: 'evo-7',
              name: 'raw display name (must not render)',
              type: InstanceType.evolution,
              status: AgentLifecycle.active,
              updatedAt: DateTime(2026, 5, 25, 9, 30),
              sessionNumber: 7,
              templateName: 'Some Template',
            ),
          ],
        );

        // Evolution rows use the localized session title, not displayName,
        // and suppress the template-name subtitle.
        expect(find.text('Evolution #7'), findsOneWidget);
        expect(find.text('raw display name (must not render)'), findsNothing);
        expect(find.text('Some Template'), findsNothing);

        // Without a soul, the avatar leadings fall back to the '?' label
        // (the row avatar plus grouped-header copies render several).
        expect(find.text('?'), findsWidgets);

        await tester.tap(find.text('Evolution #7'));
        await tester.pumpAndSettle();
        expect(navigated, '/settings/agents/instances/evo-7');
      },
    );
  });
  group('AgentInstancesPage — lifecycle pill tones', () {
    testWidgets(
      'each lifecycle renders a status pill with its mapped tone',
      (tester) async {
        await pumpPage(
          tester,
          vms: [
            _soulVm(
              id: 'act',
              name: 'ActiveRow',
              updatedAt: DateTime(2026, 5, 4),
            ),
            _soulVm(
              id: 'dor',
              name: 'DormantRow',
              updatedAt: DateTime(2026, 5, 3),
              status: AgentLifecycle.dormant,
            ),
            _soulVm(
              id: 'des',
              name: 'DestroyedRow',
              updatedAt: DateTime(2026, 5, 2),
              status: AgentLifecycle.destroyed,
            ),
          ],
        );

        final ctx = tester.element(find.byType(AgentInstancesPage));
        final messages = ctx.messages;

        AgentListPill statusPill(String label) {
          final row = tester
              .widgetList<AgentListRow>(find.byType(AgentListRow))
              .firstWhere((r) => r.data.title == label);
          // Status is the second pill (after the type pill).
          return row.data.pills[1];
        }

        // Distinct, mapped tones per lifecycle — a visual regression where
        // dormant/destroyed render like active fails here.
        expect(
          statusPill('ActiveRow').tone,
          AgentListPillTone.interactive,
        );
        expect(statusPill('DormantRow').tone, AgentListPillTone.muted);
        expect(statusPill('DestroyedRow').tone, AgentListPillTone.error);
        expect(
          statusPill('DormantRow').label,
          agentLifecycleLabel(messages, AgentLifecycle.dormant),
        );
        expect(
          statusPill('DestroyedRow').label,
          agentLifecycleLabel(messages, AgentLifecycle.destroyed),
        );
      },
    );
  });

  group('AgentInstancesPage — empty dataset', () {
    testWidgets(
      'an empty VM list renders the page-supplied localized empty message',
      (tester) async {
        await pumpPage(tester, vms: const []);

        final ctx = tester.element(find.byType(AgentInstancesPage));

        // The page wires `messages.agentInstancesEmptyFiltered` into the
        // shell's emptyMessage; an empty dataset must surface that exact
        // localized copy rather than a generic placeholder. No rows means
        // no AgentListRow widgets are built.
        expect(
          find.text(ctx.messages.agentInstancesEmptyFiltered),
          findsOneWidget,
        );
        expect(find.byType(AgentListRow), findsNothing);
      },
    );
  });
}

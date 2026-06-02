import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/instances/agent_instances_page.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
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
}

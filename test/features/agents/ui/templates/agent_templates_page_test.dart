import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/ui/agent_palette.dart';
import 'package:lotti/features/agents/ui/templates/agent_templates_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

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
    required List<AgentDomainEntity> templates,
    Set<String> pending = const {},
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: AgentTemplatesPage()),
        mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
        overrides: [
          agentTemplatesProvider.overrideWith((ref) async => templates),
          activeTemplateVersionProvider.overrideWith(
            (ref, templateId) async =>
                makeTestTemplateVersion(agentId: templateId),
          ),
          templatesPendingReviewProvider.overrideWith((ref) async => pending),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders templates with name + model + version', (tester) async {
    await pumpPage(
      tester,
      templates: [
        makeTestTemplate(
          id: 'tpl-laura',
          agentId: 'tpl-laura',
          displayName: 'Laura',
          modelId: 'gemini-3-pro',
        ),
      ],
    );

    // Title + subtitle are rendered together via `Text.rich`, so the
    // text widget's plain text is `'Laura  ·  gemini-3-pro'`. Use
    // `findRichText: true` + `findTextContaining` to match through it.
    expect(
      find.textContaining('Laura', findRichText: true),
      findsAtLeast(1),
    );
    expect(
      find.textContaining('gemini-3-pro', findRichText: true),
      findsAtLeast(1),
    );
    expect(find.text('v1'), findsOneWidget);
  });

  testWidgets('pending-review template gets a purple leading icon', (
    tester,
  ) async {
    await pumpPage(
      tester,
      templates: [
        makeTestTemplate(
          id: 'tpl-pending',
          agentId: 'tpl-pending',
          displayName: 'Needs review',
        ),
      ],
      pending: const {'tpl-pending'},
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Icon && w.color == AgentPalette.purple,
      ),
      findsOneWidget,
    );
  });

  testWidgets('Kind filter axis only appears when 2+ kinds exist', (
    tester,
  ) async {
    // Single-kind dataset → Filters button should not be in the toolbar.
    await pumpPage(
      tester,
      templates: [
        makeTestTemplate(
          id: 'a',
          agentId: 'a',
          displayName: 'A',
        ),
        makeTestTemplate(
          id: 'b',
          agentId: 'b',
          displayName: 'B',
        ),
      ],
    );
    final ctx = tester.element(find.byType(AgentTemplatesPage));
    expect(
      find.text(ctx.messages.agentInstancesToolbarFilters),
      findsNothing,
    );
  });

  testWidgets(
    'Kind filter axis appears when multiple kinds are present',
    (tester) async {
      await pumpPage(
        tester,
        templates: [
          makeTestTemplate(id: 'a', agentId: 'a', displayName: 'Task A'),
          makeTestTemplate(
            id: 'b',
            agentId: 'b',
            displayName: 'Project B',
            kind: AgentTemplateKind.projectAgent,
          ),
        ],
      );
      final ctx = tester.element(find.byType(AgentTemplatesPage));
      expect(
        find.text(ctx.messages.agentInstancesToolbarFilters),
        findsOneWidget,
      );
    },
  );

  testWidgets('switching Group by Kind clusters rows by their kind label', (
    tester,
  ) async {
    await pumpPage(
      tester,
      templates: [
        makeTestTemplate(id: 'a', agentId: 'a', displayName: 'Task A'),
        makeTestTemplate(
          id: 'b',
          agentId: 'b',
          displayName: 'Project B',
          kind: AgentTemplateKind.projectAgent,
        ),
      ],
    );

    final ctx = tester.element(find.byType(AgentTemplatesPage));
    await tester.tap(
      find.textContaining(ctx.messages.agentInstancesToolbarGroupBy),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(ctx.messages.agentTemplatesGroupByKind).last,
    );
    await tester.pumpAndSettle();

    expect(
      find.text(ctx.messages.agentTemplateKindTaskAgent),
      findsAtLeast(1),
    );
    expect(
      find.text(ctx.messages.agentTemplateKindProjectAgent),
      findsAtLeast(1),
    );
  });

  testWidgets('tapping a row beams to the template detail route', (
    tester,
  ) async {
    String? navigated;
    beamToNamedOverride = (path) => navigated = path;

    await pumpPage(
      tester,
      templates: [
        makeTestTemplate(
          id: 'tpl-nav',
          agentId: 'tpl-nav',
          displayName: 'Nav',
        ),
      ],
    );
    await tester.tap(find.textContaining('Nav', findRichText: true));
    await tester.pumpAndSettle();
    expect(navigated, '/settings/agents/templates/tpl-nav');
  });

  testWidgets(
    'empty data shows the localized empty-state copy',
    (tester) async {
      await pumpPage(tester, templates: const []);
      final ctx = tester.element(find.byType(AgentTemplatesPage));
      expect(
        find.text(ctx.messages.agentTemplatesEmptyFiltered),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'selecting a Kind filter hides rows of other kinds via the matcher',
    (tester) async {
      await pumpPage(
        tester,
        templates: [
          makeTestTemplate(id: 'a', agentId: 'a', displayName: 'Task A'),
          makeTestTemplate(
            id: 'b',
            agentId: 'b',
            displayName: 'Project B',
            kind: AgentTemplateKind.projectAgent,
          ),
        ],
      );

      final ctx = tester.element(find.byType(AgentTemplatesPage));

      // Open the Filters popover and tick "Project agent" so the axis
      // matcher (`_matchRow`) gets exercised against every row.
      await tester.tap(find.text(ctx.messages.agentInstancesToolbarFilters));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(ctx.messages.agentTemplateKindProjectAgent).last,
      );
      await tester.pumpAndSettle();
      // Dismiss the popover by tapping outside.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Project B', findRichText: true),
        findsAtLeast(1),
      );
      expect(
        find.textContaining('Task A', findRichText: true),
        findsNothing,
      );
    },
  );

  testWidgets('switching Sort to Recent orders newest updates first', (
    tester,
  ) async {
    await pumpPage(
      tester,
      templates: [
        makeTestTemplate(
          id: 'old',
          agentId: 'old',
          displayName: 'Older',
          updatedAt: DateTime(2025),
        ),
        makeTestTemplate(
          id: 'new',
          agentId: 'new',
          displayName: 'Newer',
          updatedAt: DateTime(2026, 6),
        ),
      ],
    );

    final ctx = tester.element(find.byType(AgentTemplatesPage));
    await tester.tap(find.text(ctx.messages.agentInstancesSortName));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(ctx.messages.agentInstancesSortRecent).last,
    );
    await tester.pumpAndSettle();

    final newerY = tester
        .getTopLeft(find.textContaining('Newer', findRichText: true))
        .dy;
    final olderY = tester
        .getTopLeft(find.textContaining('Older', findRichText: true))
        .dy;
    expect(newerY < olderY, isTrue);
  });

  testWidgets('switching Sort to Oldest orders earliest updates first', (
    tester,
  ) async {
    await pumpPage(
      tester,
      templates: [
        makeTestTemplate(
          id: 'new',
          agentId: 'new',
          displayName: 'Newer',
          updatedAt: DateTime(2026, 6),
        ),
        makeTestTemplate(
          id: 'old',
          agentId: 'old',
          displayName: 'Older',
          updatedAt: DateTime(2025),
        ),
      ],
    );

    final ctx = tester.element(find.byType(AgentTemplatesPage));
    await tester.tap(find.text(ctx.messages.agentInstancesSortName));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(ctx.messages.agentInstancesSortOldest).last,
    );
    await tester.pumpAndSettle();

    final newerY = tester
        .getTopLeft(find.textContaining('Newer', findRichText: true))
        .dy;
    final olderY = tester
        .getTopLeft(find.textContaining('Older', findRichText: true))
        .dy;
    expect(olderY < newerY, isTrue);
  });

  testWidgets(
    'name sort falls back to id when two templates share a display name',
    (tester) async {
      // Identical display names force the secondary `a.id.compareTo(b.id)`
      // tiebreaker in the name sort comparator.
      await pumpPage(
        tester,
        templates: [
          makeTestTemplate(
            id: 'tpl-zeta',
            agentId: 'tpl-zeta',
            displayName: 'Same Name',
          ),
          makeTestTemplate(
            id: 'tpl-alpha',
            agentId: 'tpl-alpha',
            displayName: 'Same Name',
          ),
        ],
      );

      // Default sort is by name; with identical names the lower id wins.
      final matches = find.textContaining('Same Name', findRichText: true);
      expect(matches, findsNWidgets(2));
      final firstY = tester.getTopLeft(matches.at(0)).dy;
      final secondY = tester.getTopLeft(matches.at(1)).dy;
      expect(firstY < secondY, isTrue);
      // The version pill (`v1`) is keyed off the id, but the row's
      // ordering is what we actually want — confirm it via the leading
      // icon's onTap target. Tapping the first row should beam to the
      // alpha id (alphabetically smaller).
      String? navigated;
      beamToNamedOverride = (path) => navigated = path;
      await tester.tap(matches.first);
      await tester.pumpAndSettle();
      expect(navigated, '/settings/agents/templates/tpl-alpha');
    },
  );
}

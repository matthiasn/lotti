import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/listing/widgets/soul_avatar.dart';
import 'package:lotti/features/agents/ui/souls/agent_souls_page.dart';
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
    required List<AgentDomainEntity> souls,
    Map<String, AgentDomainEntity?> versionsBySoulId = const {},
  }) async {
    // setSurfaceSize asserts `inTest`, so it must run per test — a
    // setUpAll hoist is not possible with the test binding.
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: AgentSoulsPage()),
        mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
        overrides: [
          allSoulDocumentsProvider.overrideWith((ref) async => souls),
          activeSoulVersionProvider.overrideWith(
            (ref, soulId) async => versionsBySoulId[soulId],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders souls with name + version', (tester) async {
    await pumpPage(
      tester,
      souls: [
        makeTestSoulDocument(
          id: 'soul-laura',
          agentId: 'soul-laura',
          displayName: 'Laura',
        ),
      ],
      versionsBySoulId: {
        'soul-laura': makeTestSoulDocumentVersion(
          agentId: 'soul-laura',
          version: 4,
        ),
      },
    );

    expect(find.text('Laura'), findsOneWidget);
    expect(find.text('v4'), findsOneWidget);
    expect(find.byType(SoulAvatar), findsOneWidget);
  });

  testWidgets('soul without an active version omits the metaRight cell', (
    tester,
  ) async {
    await pumpPage(
      tester,
      souls: [
        makeTestSoulDocument(
          id: 'soul-empty',
          agentId: 'soul-empty',
          displayName: 'Untouched',
        ),
      ],
    );

    expect(find.text('Untouched'), findsOneWidget);
    // No `vN` mono cell when there's no active version yet.
    expect(find.textContaining(RegExp(r'^v\d+$')), findsNothing);
  });

  testWidgets('tapping a row beams to the soul detail route', (tester) async {
    String? navigated;
    beamToNamedOverride = (path) => navigated = path;

    await pumpPage(
      tester,
      souls: [
        makeTestSoulDocument(
          id: 'soul-nav',
          agentId: 'soul-nav',
          displayName: 'Nav',
        ),
      ],
    );

    await tester.tap(find.text('Nav'));
    await tester.pumpAndSettle();
    expect(navigated, '/settings/agents/souls/soul-nav');
  });

  testWidgets('empty data shows the localized empty-state copy', (
    tester,
  ) async {
    await pumpPage(tester, souls: const []);
    final ctx = tester.element(find.byType(AgentSoulsPage));
    expect(
      find.text(ctx.messages.agentSoulsEmptyFiltered),
      findsOneWidget,
    );
  });

  testWidgets('search filters rows by name', (tester) async {
    await pumpPage(
      tester,
      souls: [
        makeTestSoulDocument(
          id: 'soul-a',
          agentId: 'soul-a',
          displayName: 'Alpha',
        ),
        makeTestSoulDocument(
          id: 'soul-b',
          agentId: 'soul-b',
          displayName: 'Beta',
        ),
      ],
    );

    final ctx = tester.element(find.byType(AgentSoulsPage));
    final placeholder = ctx.messages.agentSoulsSearchPlaceholder;

    await tester.enterText(
      find.widgetWithText(TextField, placeholder),
      'Alp',
    );
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
  });

  testWidgets('switching Sort to Recent orders newest updates first', (
    tester,
  ) async {
    // Names are deliberately the inverse of recency: "Alpha" is the
    // *oldest* and "Zeta" the *newest*. Under the default Name sort
    // "Alpha" renders above "Zeta", so switching to Recent (which must
    // surface the newest first) flips the order observably — proving the
    // page's recent sort-axis wiring actually drives the ordering.
    await pumpPage(
      tester,
      souls: [
        makeTestSoulDocument(
          id: 'soul-alpha',
          agentId: 'soul-alpha',
          displayName: 'Alpha',
          updatedAt: DateTime(2025),
        ),
        makeTestSoulDocument(
          id: 'soul-zeta',
          agentId: 'soul-zeta',
          displayName: 'Zeta',
          updatedAt: DateTime(2026, 6),
        ),
      ],
    );

    final ctx = tester.element(find.byType(AgentSoulsPage));

    // Default Name sort: alphabetical, so "Alpha" is above "Zeta".
    expect(
      tester.getTopLeft(find.text('Alpha')).dy <
          tester.getTopLeft(find.text('Zeta')).dy,
      isTrue,
    );

    // Open the Sort popover (the button shows the current axis label,
    // "Name") and switch to Recent. `.last` targets the popover entry
    // rather than the toolbar button that still shows the old label.
    await tester.tap(find.text(ctx.messages.agentInstancesSortName));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(ctx.messages.agentInstancesSortRecent).last,
    );
    await tester.pumpAndSettle();

    // Recent sort: newest (Zeta, 2026) is now above oldest (Alpha, 2025).
    expect(
      tester.getTopLeft(find.text('Zeta')).dy <
          tester.getTopLeft(find.text('Alpha')).dy,
      isTrue,
    );
  });

  testWidgets('switching Sort to Oldest orders earliest updates first', (
    tester,
  ) async {
    // Names match recency here so the default Name sort already happens to
    // agree with Recent; switching to Oldest must invert to earliest-first.
    await pumpPage(
      tester,
      souls: [
        makeTestSoulDocument(
          id: 'soul-alpha',
          agentId: 'soul-alpha',
          displayName: 'Alpha',
          updatedAt: DateTime(2026, 6),
        ),
        makeTestSoulDocument(
          id: 'soul-zeta',
          agentId: 'soul-zeta',
          displayName: 'Zeta',
          updatedAt: DateTime(2025),
        ),
      ],
    );

    final ctx = tester.element(find.byType(AgentSoulsPage));

    // Default Name sort: "Alpha" above "Zeta".
    expect(
      tester.getTopLeft(find.text('Alpha')).dy <
          tester.getTopLeft(find.text('Zeta')).dy,
      isTrue,
    );

    await tester.tap(find.text(ctx.messages.agentInstancesSortName));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(ctx.messages.agentInstancesSortOldest).last,
    );
    await tester.pumpAndSettle();

    // Oldest sort: earliest (Zeta, 2025) is now above latest (Alpha, 2026).
    expect(
      tester.getTopLeft(find.text('Zeta')).dy <
          tester.getTopLeft(find.text('Alpha')).dy,
      isTrue,
    );
  });

  testWidgets('default name sort orders souls case-insensitively', (
    tester,
  ) async {
    // Three souls with mixed-case names. The default sort axis is Name,
    // whose comparator lower-cases both titles, so the rendered order must
    // be alphabetical irrespective of letter case: apple < Banana < cherry.
    await pumpPage(
      tester,
      souls: [
        makeTestSoulDocument(
          id: 'soul-cherry',
          agentId: 'soul-cherry',
          displayName: 'cherry',
        ),
        makeTestSoulDocument(
          id: 'soul-apple',
          agentId: 'soul-apple',
          displayName: 'apple',
        ),
        makeTestSoulDocument(
          id: 'soul-banana',
          agentId: 'soul-banana',
          displayName: 'Banana',
        ),
      ],
    );

    final appleY = tester.getTopLeft(find.text('apple')).dy;
    final bananaY = tester.getTopLeft(find.text('Banana')).dy;
    final cherryY = tester.getTopLeft(find.text('cherry')).dy;
    expect(appleY < bananaY, isTrue);
    expect(bananaY < cherryY, isTrue);
  });
}

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
}

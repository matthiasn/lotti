import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_briefing_card.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(
      RelationshipEntry(
        meta: Metadata(
          id: 'fallback',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          dateFrom: DateTime(2026),
          dateTo: DateTime(2026),
        ),
        data: RelationshipData(
          title: 'fallback',
          status: RelationshipStatus.active(
            id: 's',
            createdAt: DateTime(2026),
            utcOffset: 0,
          ),
        ),
      ),
    );
  });

  const relationshipId = 'person-1';
  final agentId = relationshipAgentIdFor(relationshipId);
  final testDate = DateTime(2026, 8, 1, 9);

  late MockRelationshipAgentService agentService;

  RelationshipEntry relationship({bool important = true}) => RelationshipEntry(
    meta: Metadata(
      id: relationshipId,
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: RelationshipData(
      title: 'Anna',
      important: important,
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      ),
    ),
  );

  AgentReportEntity report({
    String? tldr,
    String content = 'Full briefing.',
    String band = 'needsAttention',
  }) =>
      AgentDomainEntity.agentReport(
            id: 'report-1',
            agentId: agentId,
            scope: AgentReportScopes.current,
            createdAt: DateTime(2026, 8, 15),
            vectorClock: null,
            content: content,
            tldr: tldr,
            provenance: {
              RelationshipReportProvenanceKeys.healthBand: band,
              RelationshipReportProvenanceKeys.healthRationale:
                  'Two difficult calls in a row.',
            },
          )
          as AgentReportEntity;

  setUp(() {
    agentService = MockRelationshipAgentService();
    when(
      () => agentService.requestBriefing(any()),
    ).thenAnswer((_) async {});
  });

  Widget build({
    RelationshipEntry? entry,
    AgentReportEntity? current,
    String? disclosureProviderName,
  }) => makeTestableWidgetWithScaffold(
    RelationshipBriefingCard(relationship: entry ?? relationship()),
    overrides: [
      agentReportProvider(agentId).overrideWith((ref) async => current),
      relationshipAgentServiceProvider.overrideWithValue(agentService),
      relationshipBriefingDisclosureProvider(
        relationshipId,
      ).overrideWith((ref) async => disclosureProviderName),
    ],
  );

  testWidgets('renders nothing for an unimportant person with no briefing — '
      'no advertising a feature they are not enrolled in', (tester) async {
    await tester.pumpWidget(
      build(entry: relationship(important: false)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('relationship-briefing-card')),
      findsNothing,
    );
  });

  testWidgets('shows the health chip with its localized band label and the '
      'rationale as tooltip, plus the collapsed TLDR', (tester) async {
    await tester.pumpWidget(
      build(current: report(tldr: 'You last spoke two weeks ago.')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('You last spoke two weeks ago.'), findsOneWidget);
    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const ValueKey('relationship-health-chip')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, 'Two difficult calls in a row.');
  });

  testWidgets('the thriving band gets its own label, and the content '
      'stands in when the tldr is absent', (tester) async {
    await tester.pumpWidget(build(current: report(band: 'thriving')));
    await tester.pumpAndSettle();
    expect(find.text('Thriving'), findsOneWidget);
    expect(
      find.text('Full briefing.'),
      findsOneWidget,
      reason: 'no tldr: the collapsed slot falls back to the content',
    );
  });

  testWidgets('the strained band gets its own label', (tester) async {
    await tester.pumpWidget(build(current: report(band: 'strained')));
    await tester.pumpAndSettle();
    expect(find.text('Strained'), findsOneWidget);
  });

  testWidgets('Show more expands the full briefing', (tester) async {
    await tester.pumpWidget(
      build(current: report(tldr: 'Short version.')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('relationship-briefing-content')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('relationship-briefing-expand')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Full briefing.'), findsOneWidget);
  });

  testWidgets('Brief me on a LOCAL route runs without any dialog', (
    tester,
  ) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('relationship-brief-me')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    verify(() => agentService.requestBriefing(any())).called(1);
  });

  testWidgets('Brief me on a CLOUD route names the provider first and only '
      'proceeds on consent (ADR 0037)', (tester) async {
    await tester.pumpWidget(build(disclosureProviderName: 'Melious'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('relationship-brief-me')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Melious'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => agentService.requestBriefing(any()));

    await tester.tap(find.byKey(const ValueKey('relationship-brief-me')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    verify(() => agentService.requestBriefing(any())).called(1);
  });

  testWidgets('the chat entry beams to the person-scoped chat route', (
    tester,
  ) async {
    final beamedTo = <String>[];
    beamToNamedOverride = beamedTo.add;
    addTearDown(() => beamToNamedOverride = null);
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('relationship-chat-button')));
    expect(beamedTo, ['/people/$relationshipId/chat']);
  });

  testWidgets('a failed request surfaces the error toast instead of '
      'silence', (tester) async {
    when(
      () => agentService.requestBriefing(any()),
    ).thenAnswer((_) async => throw StateError('wake enqueue failed'));
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('relationship-brief-me')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not request'), findsOneWidget);
  });
}

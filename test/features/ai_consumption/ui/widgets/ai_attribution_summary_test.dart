import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_attribution_summary.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Future<void> pumpSummary(
    WidgetTester tester, {
    required AiAttributionDetails? details,
    bool includeCarrier = true,
  }) async {
    final attribution = makeAiWorkAttribution();
    await tester.pumpWidget(
      makeTestableWidget(
        AiAttributionSummary(
          artifact: makeAiArtifact(),
          attribution: includeCarrier ? attribution : null,
        ),
        overrides: [
          aiAttributionDetailsProvider.overrideWith(
            (ref, id) async => details,
          ),
          aiAttributionForArtifactProvider.overrideWith(
            (ref, artifact) async => details,
          ),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('shows creator, model, call count, and actual Melious cost', (
    tester,
  ) async {
    final attribution = makeAiWorkAttribution();
    final details = AiAttributionDetails(
      attribution: attribution,
      interactions: [
        makeConsumptionEvent(
          attributionId: attribution.id,
          providerModelId: 'gpt-5',
          credits: 0.25,
          costCreditsDecimal: '0.25',
        ),
      ],
    );

    await pumpSummary(tester, details: details);

    expect(find.textContaining('Ada'), findsOneWidget);
    expect(find.textContaining('gpt-5'), findsOneWidget);
    expect(find.textContaining('1 call'), findsOneWidget);
    expect(find.textContaining('€0.25'), findsOneWidget);
  });

  testWidgets('details expose token usage and request/response digests', (
    tester,
  ) async {
    final attribution = makeAiWorkAttribution();
    final details = AiAttributionDetails(
      attribution: attribution,
      interactions: [
        makeConsumptionEvent(
          attributionId: attribution.id,
          requestDigest: 'request-sha',
          responseDigest: 'response-sha',
        ),
      ],
    );
    await pumpSummary(tester, details: details);

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pump();

    expect(find.text('1,500'), findsOneWidget);
    expect(find.text('request-sha'), findsOneWidget);
    expect(find.text('response-sha'), findsOneWidget);
  });

  testWidgets('renders nothing when neither carrier nor projection exists', (
    tester,
  ) async {
    await pumpSummary(tester, details: null, includeCarrier: false);

    expect(find.byType(AiAttributionSummary), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });
}

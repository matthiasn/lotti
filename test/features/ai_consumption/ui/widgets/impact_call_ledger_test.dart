// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_call_ledger.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  // 2026-06-01 .. 2026-06-08 (epoch days for a June 2026 week).
  const range = InsightsRange(startDay: 20605, endDayExclusive: 20612);

  late MockConsumptionRepository repository;

  setUp(() {
    repository = MockConsumptionRepository();
  });

  void stubEvents(List<AiConsumptionEvent> events) {
    when(
      () => repository.newestEventsInRange(
        start: any(named: 'start'),
        end: any(named: 'end'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => events);
  }

  Future<void> pumpLedger(
    WidgetTester tester, {
    String? modelFilter,
    String? categoryFilter,
    double width = 900,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: ImpactCallLedger(
                range: range,
                modelFilter: modelFilter,
                categoryFilter: categoryFilter,
              ),
            ),
          ),
        ),
        overrides: [
          consumptionRepositoryProvider.overrideWithValue(repository),
          consumptionRefetchThrottleProvider.overrideWithValue(null),
          maybeUpdateNotificationsProvider.overrideWith((ref) => null),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renders nothing when the period has no calls', (tester) async {
    stubEvents(const []);
    await pumpLedger(tester);

    expect(find.text('Recent calls'), findsNothing);
  });

  testWidgets('a model filter keeps only that model, following isolation', (
    tester,
  ) async {
    stubEvents([
      makeConsumptionEvent(
        id: 'a',
        createdAt: DateTime(2026, 6, 3, 10),
        providerModelId: 'claude-opus-4',
        responseType: AiConsumptionResponseType.agentTurn,
        totalTokens: 3800,
        credits: 0.02,
      ),
      makeConsumptionEvent(
        id: 'b',
        createdAt: DateTime(2026, 6, 3, 9),
        providerModelId: 'glm-5.2',
        responseType: AiConsumptionResponseType.textGeneration,
        totalTokens: 2500,
        credits: 0.01,
      ),
    ]);
    await pumpLedger(tester, modelFilter: 'claude-opus-4');

    // Only the isolated model's calls remain in the ledger.
    expect(find.text('claude-opus-4'), findsOneWidget);
    expect(find.text('glm-5.2'), findsNothing);
  });

  testWidgets('the truncation notice survives a filter that shrinks the list', (
    tester,
  ) async {
    // A full (capped) fetch of 100, half of which are the filtered model.
    stubEvents([
      for (var i = 0; i < 100; i++)
        makeConsumptionEvent(
          id: 'evt-$i',
          createdAt: DateTime(2026, 6, 3, 12).subtract(Duration(minutes: i)),
          providerModelId: i.isEven ? 'claude-opus-4' : 'glm-5.2',
          totalTokens: 1000,
        ),
    ]);
    await pumpLedger(tester, modelFilter: 'claude-opus-4');

    // The cap notice is gated on the unfiltered fetch, so it still discloses
    // that the underlying 100-call page was truncated.
    expect(
      find.textContaining('Showing the newest 100 calls'),
      findsOneWidget,
    );
  });

  testWidgets('renders model, type, time, and full metrics for a measured '
      'call', (tester) async {
    stubEvents([
      makeConsumptionEvent(
        id: 'evt-1',
        createdAt: DateTime(2026, 6, 3, 14, 30),
        providerModelId: 'glm-5.2',
        responseType: AiConsumptionResponseType.agentTurn,
        totalTokens: 1500,
        credits: 0.42,
        energyKwh: 0.012,
      ),
    ]);
    await pumpLedger(tester);

    expect(find.text('Recent calls'), findsOneWidget);
    expect(find.text('glm-5.2'), findsOneWidget);
    // Expected time computed via the same locale-aware formatter the widget
    // uses (locale data is initialized by the pumped localization delegates).
    final time = DateFormat.MMMd(
      'en',
    ).add_Hm().format(DateTime(2026, 6, 3, 14, 30));
    expect(find.text('Agent turn · $time'), findsOneWidget);
    // 1500 tokens compact + credits + energy (0.012 kWh → 12 Wh).
    expect(find.text('1.5K tokens · €0.42 · 12 Wh'), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    // Under the cap → no truncation caption.
    expect(
      find.textContaining('Showing the newest'),
      findsNothing,
    );
  });

  testWidgets('stacks the row on narrow (phone) width so the model name gets '
      'its own line above the metrics', (tester) async {
    stubEvents([
      makeConsumptionEvent(
        id: 'evt-narrow',
        createdAt: DateTime(2026, 6, 3, 14, 30),
        providerModelId: 'a-very-long-provider-model-id-2507',
        responseType: AiConsumptionResponseType.agentTurn,
        totalTokens: 1500,
        credits: 0.42,
        energyKwh: 0.012,
      ),
    ]);
    await pumpLedger(tester, width: 360);

    final modelFinder = find.text('a-very-long-provider-model-id-2507');
    final metricsFinder = find.text('1.5K tokens · €0.42 · 12 Wh');
    expect(modelFinder, findsOneWidget);
    expect(metricsFinder, findsOneWidget);
    // Narrow layout stacks vertically: the metric string sits BELOW the model
    // name rather than trailing it on the same line (which is what would
    // truncate the name on a phone).
    expect(
      tester.getTopLeft(metricsFinder).dy,
      greaterThan(tester.getTopLeft(modelFinder).dy),
    );
  });

  testWidgets('omits cost/energy parts for unmeasured calls and falls back '
      'to modelId', (tester) async {
    stubEvents([
      makeConsumptionEvent(
        id: 'evt-2',
        createdAt: DateTime(2026, 6, 4, 9, 5),
        providerModelId: null,
        modelId: 'models/config-id-1',
        responseType: AiConsumptionResponseType.audioTranscription,
        totalTokens: 800,
        credits: null,
        energyKwh: null,
      ),
    ]);
    await pumpLedger(tester);

    expect(find.text('models/config-id-1'), findsOneWidget);
    final time = DateFormat.MMMd(
      'en',
    ).add_Hm().format(DateTime(2026, 6, 4, 9, 5));
    expect(find.text('Transcription · $time'), findsOneWidget);
    expect(find.text('800 tokens'), findsOneWidget);
    expect(find.byIcon(Icons.mic_outlined), findsOneWidget);
  });

  testWidgets('labels calls whose provider did not report metrics', (
    tester,
  ) async {
    stubEvents([
      makeConsumptionEvent(
        id: 'evt-usage-missing',
        createdAt: DateTime(2026, 6, 4, 9, 5),
        providerModelId: 'whisper-1',
        responseType: AiConsumptionResponseType.audioTranscription,
        totalTokens: null,
        credits: null,
        energyKwh: null,
      ),
    ]);
    await pumpLedger(tester);

    expect(find.text('whisper-1'), findsOneWidget);
    expect(find.text('Not reported'), findsOneWidget);
    expect(find.byIcon(Icons.mic_outlined), findsOneWidget);
  });

  testWidgets('maps every response type to its icon and localized label', (
    tester,
  ) async {
    const cases = <AiConsumptionResponseType, (IconData, String)>{
      AiConsumptionResponseType.agentTurn: (
        Icons.smart_toy_outlined,
        'Agent turn',
      ),
      AiConsumptionResponseType.textGeneration: (
        Icons.notes_outlined,
        'Text generation',
      ),
      AiConsumptionResponseType.audioTranscription: (
        Icons.mic_outlined,
        'Transcription',
      ),
      AiConsumptionResponseType.imageAnalysis: (
        Icons.image_search_outlined,
        'Image analysis',
      ),
      AiConsumptionResponseType.imageGeneration: (
        Icons.brush_outlined,
        'Image generation',
      ),
      AiConsumptionResponseType.promptGeneration: (
        Icons.edit_note_outlined,
        'Prompt generation',
      ),
      AiConsumptionResponseType.embeddingIndexing: (
        Icons.hub_outlined,
        'Embedding indexing',
      ),
    };
    stubEvents([
      for (final type in cases.keys)
        makeConsumptionEvent(
          id: 'evt-${type.name}',
          createdAt: DateTime(2026, 6, 3, 12),
          responseType: type,
        ),
    ]);
    await pumpLedger(tester);

    for (final MapEntry(key: type, value: (icon, label)) in cases.entries) {
      expect(
        find.byIcon(icon),
        findsOneWidget,
        reason: 'icon for ${type.name}',
      );
      expect(
        find.textContaining(label),
        findsWidgets,
        reason: 'label for ${type.name}',
      );
    }
  });

  testWidgets('surfaces the cap caption when the page hits the ledger limit', (
    tester,
  ) async {
    stubEvents([
      for (var i = 0; i < kConsumptionLedgerLimit; i++)
        makeConsumptionEvent(
          id: 'evt-$i',
          createdAt: DateTime(2026, 6, 3, 10).add(Duration(minutes: i)),
        ),
    ]);
    await pumpLedger(tester);

    expect(
      find.text(
        'Showing the newest $kConsumptionLedgerLimit calls in this period',
      ),
      findsOneWidget,
    );
  });
}

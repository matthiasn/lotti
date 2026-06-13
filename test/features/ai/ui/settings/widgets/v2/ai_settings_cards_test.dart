import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';

import '../../../../../../widget_test_utils.dart';
import 'ai_settings_cards_test_helpers.dart';

void main() {
  group('AiProviderCard.statusFor', () {
    test('cloud provider with non-empty API key → connected', () {
      expect(
        AiProviderCard.statusFor(
          provider: hProvider(
            type: InferenceProviderType.anthropic,
            apiKey: 'sk-ant-test',
          ),
          modelCount: 2,
        ),
        equals(AiProviderCardStatus.connected),
      );
    });

    test('cloud provider with blank API key → invalidKey', () {
      expect(
        AiProviderCard.statusFor(
          provider: hProvider(
            type: InferenceProviderType.openAi,
            apiKey: '   ',
          ),
          modelCount: 0,
        ),
        equals(AiProviderCardStatus.invalidKey),
      );
    });

    test('Ollama with base URL + at least one model → connected', () {
      expect(
        AiProviderCard.statusFor(
          provider: hProvider(
            type: InferenceProviderType.ollama,
            apiKey: '',
            baseUrl: 'http://localhost:11434',
          ),
          modelCount: 1,
        ),
        equals(AiProviderCardStatus.connected),
      );
    });

    test('Ollama with no models → offline (even with base URL)', () {
      expect(
        AiProviderCard.statusFor(
          provider: hProvider(
            type: InferenceProviderType.ollama,
            apiKey: '',
            baseUrl: 'http://localhost:11434',
          ),
          modelCount: 0,
        ),
        equals(AiProviderCardStatus.offline),
      );
    });

    test('Ollama with blank base URL → offline', () {
      expect(
        AiProviderCard.statusFor(
          provider: hProvider(
            type: InferenceProviderType.ollama,
            apiKey: '',
            baseUrl: '',
          ),
          modelCount: 5,
        ),
        equals(AiProviderCardStatus.offline),
      );
    });

    // Local providers (`ProviderConfig.noApiKeyRequired`) all share the
    // base-URL + model-count gate. Voxtral and Whisper used to fall
    // through the cloud branch and surface `invalidKey` because they
    // never carry an API key — same shape as Ollama, different enum.
    for (final type in const [
      InferenceProviderType.voxtral,
      InferenceProviderType.whisper,
    ]) {
      test('$type with base URL + at least one model → connected', () {
        expect(
          AiProviderCard.statusFor(
            provider: hProvider(
              type: type,
              apiKey: '',
              baseUrl: 'http://localhost:11344',
            ),
            modelCount: 2,
          ),
          equals(AiProviderCardStatus.connected),
        );
      });

      test('$type with no models → offline (never invalidKey)', () {
        expect(
          AiProviderCard.statusFor(
            provider: hProvider(
              type: type,
              apiKey: '',
              baseUrl: 'http://localhost:11344',
            ),
            modelCount: 0,
          ),
          equals(AiProviderCardStatus.offline),
        );
      });

      test('$type with blank base URL → offline (never invalidKey)', () {
        expect(
          AiProviderCard.statusFor(
            provider: hProvider(type: type, apiKey: '', baseUrl: ''),
            modelCount: 5,
          ),
          equals(AiProviderCardStatus.offline),
        );
      });
    }
  });

  group('AiProviderCard rendering', () {
    testWidgets(
      'connected variant shows the provider name, tagline, and connected '
      'status with a model count',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderCard(
              provider: hProvider(
                type: InferenceProviderType.gemini,
                name: 'My Google Gemini',
              ),
              modelCount: 3,
              status: AiProviderCardStatus.connected,
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.text('My Google Gemini'), findsOneWidget);
        expect(
          find.textContaining('Multimodal'),
          findsOneWidget,
          reason: 'Gemini tagline should render',
        );
        expect(find.text('Connected'), findsOneWidget);
        expect(find.textContaining('3 models'), findsOneWidget);
      },
    );

    testWidgets(
      'invalidKey variant shows the generic "Invalid key" copy and exposes '
      'the inline Fix CTA when onFix is non-null',
      (tester) async {
        var fixTaps = 0;
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderCard(
              provider: hProvider(
                type: InferenceProviderType.openAi,
                apiKey: '',
              ),
              modelCount: 0,
              status: AiProviderCardStatus.invalidKey,
              onTap: () {},
              onFix: () => fixTaps++,
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Invalid key'), findsOneWidget);
        expect(find.text('Fix'), findsOneWidget);

        await tester.tap(find.text('Fix'));
        await tester.pump();
        expect(fixTaps, equals(1));
      },
    );

    testWidgets(
      'invalidKey variant hides the Fix CTA when onFix is null',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderCard(
              provider: hProvider(
                type: InferenceProviderType.openAi,
                apiKey: '',
              ),
              modelCount: 0,
              status: AiProviderCardStatus.invalidKey,
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Invalid key'), findsOneWidget);
        expect(find.text('Fix'), findsNothing);
      },
    );

    testWidgets(
      'offline variant shows the Ollama hint instead of a model-count tail',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderCard(
              provider: hProvider(
                type: InferenceProviderType.ollama,
                apiKey: '',
              ),
              modelCount: 0,
              status: AiProviderCardStatus.offline,
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Offline'), findsOneWidget);
        expect(
          find.textContaining('Ollama is running'),
          findsOneWidget,
          reason: 'The offline-variant card surfaces the Ollama hint.',
        );
      },
    );

    testWidgets('tapping anywhere on the card body fires onTap', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        makeTestableWidget(
          AiProviderCard(
            provider: hProvider(type: InferenceProviderType.gemini),
            modelCount: 1,
            status: AiProviderCardStatus.connected,
            onTap: () => tapped++,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(AiProviderCard));
      await tester.pump();
      expect(tapped, equals(1));
    });

    testWidgets(
      'a provider record with an empty `name` falls back to the visual '
      'displayName (the localised provider label)',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderCard(
              provider: hProvider(
                type: InferenceProviderType.anthropic,
                name: '',
              ),
              modelCount: 0,
              status: AiProviderCardStatus.connected,
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        // Falls back to the visual.displayName mapping in
        // aihProvider_visual.dart, which for Anthropic is
        // `aiProviderAnthropicName` ("Anthropic Claude" in en).
        expect(find.text('Anthropic Claude'), findsOneWidget);
      },
    );

    testWidgets(
      'connected variant with a lastUsedLabel renders the "{n} models · '
      '{label}" tail copy',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderCard(
              provider: hProvider(type: InferenceProviderType.gemini),
              modelCount: 2,
              status: AiProviderCardStatus.connected,
              onTap: () {},
              lastUsedLabel: 'last 2m ago',
            ),
          ),
        );
        await tester.pump();
        // The combined-tail localisation pairs the model count and the
        // last-used clause.
        expect(find.textContaining('2 models'), findsOneWidget);
        expect(find.textContaining('last 2m ago'), findsOneWidget);
      },
    );
  });
}

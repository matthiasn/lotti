import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_empty_view.dart';

import '../../../../../../widget_test_utils.dart';

void main() {
  group('AiSettingsFtueBanner', () {
    testWidgets(
      'renders the FTUE title + description + Start setup button',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiSettingsFtueBanner(onStartSetup: () {}),
          ),
        );
        await tester.pump();
        expect(find.text('Add your first AI provider'), findsOneWidget);
        expect(find.textContaining('Takes about a minute'), findsOneWidget);
        expect(find.text('Start setup'), findsOneWidget);
      },
    );

    testWidgets('tapping Start setup fires onStartSetup', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        makeTestableWidget(
          AiSettingsFtueBanner(onStartSetup: () => taps++),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Start setup'));
      await tester.pump();
      expect(taps, equals(1));
    });
  });

  group('AiSettingsNoProvidersCard', () {
    testWidgets(
      'renders the No-providers title + subtitle + a chip for each of the '
      'five first-class providers '
      '(Gemini / OpenAI / Anthropic / Alibaba / Ollama)',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiSettingsNoProvidersCard(onProviderChipTap: (_) {}),
          ),
        );
        await tester.pump();
        expect(find.text('No providers yet'), findsOneWidget);
        expect(
          find.textContaining('Add one to unlock'),
          findsOneWidget,
        );
        expect(find.text('Google Gemini'), findsOneWidget);
        expect(find.text('OpenAI'), findsOneWidget);
        expect(find.text('Anthropic Claude'), findsOneWidget);
        expect(find.text('Alibaba Cloud (Qwen)'), findsOneWidget);
        expect(find.text('Ollama'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a chip fires onProviderChipTap with that provider type',
      (tester) async {
        final tapped = <InferenceProviderType>[];
        await tester.pumpWidget(
          makeTestableWidget(
            AiSettingsNoProvidersCard(
              onProviderChipTap: tapped.add,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Anthropic Claude'));
        await tester.pump();
        expect(tapped, equals([InferenceProviderType.anthropic]));

        await tester.tap(find.text('Ollama'));
        await tester.pump();
        expect(
          tapped,
          equals([
            InferenceProviderType.anthropic,
            InferenceProviderType.ollama,
          ]),
        );
      },
    );
  });
}

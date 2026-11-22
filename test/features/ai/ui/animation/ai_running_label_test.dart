import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_label.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(WidgetTester tester, AiResponseType? type) => tester
      .pumpWidget(makeTestableWidgetWithScaffold(AiRunningLabel(type: type)));

  for (final (type, words) in [
    (AiResponseType.imageAnalysis, 'Analyzing image'),
    (AiResponseType.audioTranscription, 'Transcribing audio'),
    (AiResponseType.audioSummary, 'Summarizing recording'),
    (AiResponseType.promptGeneration, 'Writing a prompt'),
    (AiResponseType.imagePromptGeneration, 'Writing a prompt'),
    (AiResponseType.imageGeneration, 'Generating image'),
    (null, 'AI is working'),
  ]) {
    testWidgets('$type reads "$words" behind its own glyph', (tester) async {
      await pump(tester, type);

      expect(find.text(words), findsOneWidget);
      expect(find.byIcon(type?.icon ?? LottiIcons.aiSpark), findsOneWidget);
      // The chevron says the band opens the progress view.
      expect(find.byIcon(LottiIcons.chevronRight), findsOneWidget);
    });
  }

  testWidgets('the glyph wears agent violet: the agent is speaking', (
    tester,
  ) async {
    await pump(tester, AiResponseType.imageGeneration);

    final glyph = tester.widget<Icon>(find.byIcon(LottiIcons.aiSpark));
    expect(
      glyph.color,
      tester
          .element(find.byType(AiRunningLabel))
          .designTokens
          .colors
          .aiCard
          .accent,
    );
  });
}

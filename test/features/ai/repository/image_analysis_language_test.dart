import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

void main() {
  group('Image Analysis Language Support', () {
    test('image analysis in task context includes language instructions', () {
      // Should include prominent language instructions at the start of system message
      expect(
        imageAnalysisInTaskContextPrompt.systemMessage,
        contains('IMPORTANT - RESPONSE LANGUAGE REQUIREMENT'),
      );
      expect(
        imageAnalysisInTaskContextPrompt.systemMessage,
        contains('You MUST generate your ENTIRE response in the language'),
      );
      expect(
        imageAnalysisInTaskContextPrompt.systemMessage,
        contains('languageCode'),
      );
      // Should include specific language examples
      expect(
        imageAnalysisInTaskContextPrompt.systemMessage,
        contains('If languageCode is "de", respond entirely in German'),
      );
      expect(
        imageAnalysisInTaskContextPrompt.systemMessage,
        contains('Only default to English if languageCode is null'),
      );
      // Should include guidelines about not mentioning missing items
      expect(
        imageAnalysisInTaskContextPrompt.systemMessage,
        contains('Never mention what is NOT present or missing'),
      );
    });

    test('image analysis in task context includes language in user message',
        () {
      // Should include language reminder in user message
      expect(
        imageAnalysisInTaskContextPrompt.userMessage,
        contains('REMINDER: Generate your ENTIRE response in the language'),
      );
      expect(
        imageAnalysisInTaskContextPrompt.userMessage,
        contains('languageCode'),
      );
      // Should include guidelines about not mentioning missing items
      expect(
        imageAnalysisInTaskContextPrompt.userMessage,
        contains('Do NOT mention what is absent or missing'),
      );
    });

    test('regular image analysis includes language support via placeholder',
        () {
      // Regular image analysis now supports language via {{languageCode}} placeholder
      // This allows it to respect the task's language when called from a task context
      expect(
        imageAnalysisPrompt.systemMessage,
        contains('RESPONSE LANGUAGE'),
      );
      expect(
        imageAnalysisPrompt.userMessage,
        contains('{{languageCode}}'),
      );
      // Should instruct to use English as fallback when no language code provided
      expect(
        imageAnalysisPrompt.systemMessage,
        contains('respond in English'),
      );
    });

    test('image analysis prompts have correct metadata', () {
      // Image analysis without task context
      expect(imageAnalysisPrompt.name, equals('Image Analysis'));
      expect(
        imageAnalysisPrompt.requiredInputData,
        equals([InputDataType.images]),
      );

      // Image analysis with task context
      expect(
        imageAnalysisInTaskContextPrompt.name,
        equals('Image Analysis in Task Context'),
      );
      expect(
        imageAnalysisInTaskContextPrompt.requiredInputData,
        equals([InputDataType.images, InputDataType.task]),
      );
    });
  });
}

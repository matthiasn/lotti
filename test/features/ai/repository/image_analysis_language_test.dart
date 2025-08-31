import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

void main() {
  group('Image Analysis Language Support', () {
    test('image analysis in task context includes language instructions', () {
      // Should include language instructions in system message
      expect(
        imageAnalysisInTaskContextPrompt.systemMessage,
        contains('Generate the analysis in the language specified'),
      );
      expect(
        imageAnalysisInTaskContextPrompt.systemMessage,
        contains("task's languageCode field"),
      );
      expect(
        imageAnalysisInTaskContextPrompt.systemMessage,
        contains('If no languageCode is set, default to English'),
      );
    });

    test('image analysis in task context includes language in user message',
        () {
      // Should include language instructions in user message
      expect(
        imageAnalysisInTaskContextPrompt.userMessage,
        contains('Generate the analysis in the language specified'),
      );
      expect(
        imageAnalysisInTaskContextPrompt.userMessage,
        contains("task's languageCode field"),
      );
      expect(
        imageAnalysisInTaskContextPrompt.userMessage,
        contains('If no languageCode is set, default to English'),
      );
    });

    test('regular image analysis does not include language instructions', () {
      // Regular image analysis (without task context) should not have language instructions
      expect(
        imageAnalysisPrompt.systemMessage,
        isNot(contains('languageCode')),
      );
      expect(
        imageAnalysisPrompt.userMessage,
        isNot(contains('languageCode')),
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

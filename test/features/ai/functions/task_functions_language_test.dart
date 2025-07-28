import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/ai/functions/task_functions.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  group('TaskFunctions language detection', () {
    test('getTools returns language detection function', () {
      final tools = TaskFunctions.getTools();

      expect(tools, isNotEmpty);
      expect(
          tools.any(
              (tool) => tool.function.name == TaskFunctions.setTaskLanguage),
          isTrue);
    });

    test('set_task_language function has correct schema', () {
      final tools = TaskFunctions.getTools();
      final languageTool = tools.firstWhere(
        (tool) => tool.function.name == TaskFunctions.setTaskLanguage,
      );

      expect(languageTool.type, equals(ChatCompletionToolType.function));
      expect(
          languageTool.function.description,
          equals(
              'Set the detected language for the task based on the content analysis'));

      final parameters = languageTool.function.parameters;
      expect(parameters, isNotNull);
      expect(parameters!['type'], equals('object'));
      expect(parameters['required'],
          equals(['languageCode', 'confidence', 'reason']));

      final properties = parameters['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('languageCode'), isTrue);
      expect(properties.containsKey('confidence'), isTrue);
      expect(properties.containsKey('reason'), isTrue);
    });

    test('languageCode parameter accepts all supported languages', () {
      final tools = TaskFunctions.getTools();
      final languageTool = tools.firstWhere(
        (tool) => tool.function.name == TaskFunctions.setTaskLanguage,
      );

      final parameters = languageTool.function.parameters!;
      final properties = parameters['properties'] as Map<String, dynamic>;
      final languageCodeSchema =
          properties['languageCode'] as Map<String, dynamic>;

      expect(languageCodeSchema['type'], equals('string'));
      expect(
          languageCodeSchema['description'], equals('ISO 639-1 language code'));

      final enumValues = languageCodeSchema['enum'] as List<dynamic>;
      expect(enumValues.length, equals(SupportedLanguage.values.length));

      // Verify all supported language codes are included
      for (final lang in SupportedLanguage.values) {
        expect(enumValues.contains(lang.code), isTrue);
      }
    });

    test('confidence parameter has correct values', () {
      final tools = TaskFunctions.getTools();
      final languageTool = tools.firstWhere(
        (tool) => tool.function.name == TaskFunctions.setTaskLanguage,
      );

      final parameters = languageTool.function.parameters!;
      final properties = parameters['properties'] as Map<String, dynamic>;
      final confidenceSchema = properties['confidence'] as Map<String, dynamic>;

      expect(confidenceSchema['type'], equals('string'));
      expect(confidenceSchema['description'],
          equals('Confidence level of language detection'));
      expect(confidenceSchema['enum'], equals(['high', 'medium', 'low']));
    });

    test('reason parameter is a string', () {
      final tools = TaskFunctions.getTools();
      final languageTool = tools.firstWhere(
        (tool) => tool.function.name == TaskFunctions.setTaskLanguage,
      );

      final parameters = languageTool.function.parameters!;
      final properties = parameters['properties'] as Map<String, dynamic>;
      final reasonSchema = properties['reason'] as Map<String, dynamic>;

      expect(reasonSchema['type'], equals('string'));
      expect(reasonSchema['description'],
          equals('Brief explanation of why this language was detected'));
    });

    test('SetTaskLanguageResult can be created from JSON', () {
      final json = {
        'languageCode': 'es',
        'confidence': 'high',
        'reason': 'All audio transcripts and text entries are in Spanish'
      };

      final result = SetTaskLanguageResult.fromJson(json);

      expect(result.languageCode, equals('es'));
      expect(result.confidence, equals(LanguageDetectionConfidence.high));
      expect(result.reason,
          equals('All audio transcripts and text entries are in Spanish'));
    });

    test('SetTaskLanguageResult serializes to JSON correctly', () {
      const result = SetTaskLanguageResult(
        languageCode: 'fr',
        confidence: LanguageDetectionConfidence.medium,
        reason: 'Mixed content but predominantly French',
      );

      final json = result.toJson();

      expect(json['languageCode'], equals('fr'));
      expect(json['confidence'], equals('medium'));
      expect(json['reason'], equals('Mixed content but predominantly French'));
    });

    test('tool function name is correctly defined', () {
      expect(TaskFunctions.setTaskLanguage, equals('set_task_language'));
    });
  });
}

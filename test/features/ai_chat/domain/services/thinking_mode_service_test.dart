import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/domain/services/thinking_mode_service.dart';

void main() {
  group('ThinkingModeService', () {
    late ThinkingModeService service;

    setUp(() {
      service = ThinkingModeServiceImpl();
    });

    group('enhanceSystemPrompt', () {
      test('returns original prompt when thinking is disabled', () {
        const basePrompt = 'You are a helpful assistant.';

        final result =
            service.enhanceSystemPrompt(basePrompt, useThinking: false);

        expect(result, equals(basePrompt));
      });

      test('adds thinking instructions when thinking is enabled', () {
        const basePrompt = 'You are a helpful assistant.';

        final result =
            service.enhanceSystemPrompt(basePrompt, useThinking: true);

        expect(result, contains(basePrompt));
        expect(result, contains('<thinking_mode>'));
        expect(result, contains('<think>'));
        expect(result, contains('analyze the query'));
        expect(result, contains('plan your response'));
      });
    });

    group('extractThinkingContent', () {
      test('extracts content between think tags', () {
        const response = '''
        Here's my analysis:
        <think>
        The user is asking about productivity patterns.
        I should analyze their task history and identify trends.
        Let me structure this response with insights and recommendations.
        </think>
        Based on your task data, I can see several patterns.
        ''';

        final result = service.extractThinkingContent(response);

        expect(result, isNotNull);
        expect(
            result, contains('The user is asking about productivity patterns'));
        expect(result, contains('I should analyze their task history'));
        expect(result, contains('Let me structure this response'));
        expect(result, isNot(contains('<think>')));
        expect(result, isNot(contains('</think>')));
      });

      test('returns null when no think tags present', () {
        const response = 'This is a regular response without thinking tags.';

        final result = service.extractThinkingContent(response);

        expect(result, isNull);
      });

      test('returns null when only opening tag is present', () {
        const response = 'This response has <think> but no closing tag.';

        final result = service.extractThinkingContent(response);

        expect(result, isNull);
      });

      test('returns null when only closing tag is present', () {
        const response = 'This response has </think> but no opening tag.';

        final result = service.extractThinkingContent(response);

        expect(result, isNull);
      });

      test('extracts first occurrence when multiple think blocks exist', () {
        const response = '''
        <think>First thinking block</think>
        Some regular text
        <think>Second thinking block</think>
        ''';

        final result = service.extractThinkingContent(response);

        expect(result, equals('First thinking block'));
      });
    });

    group('removeThinkingTags', () {
      test('removes think tags and content from response', () {
        const response = '''
        Here's my analysis:
        <think>
        Internal thinking process...
        Multiple lines of thinking...
        </think>
        This is the final response.
        ''';

        final result = service.removeThinkingTags(response);

        expect(result, isNot(contains('<think>')));
        expect(result, isNot(contains('</think>')));
        expect(result, isNot(contains('Internal thinking process')));
        expect(result, contains("Here's my analysis:"));
        expect(result, contains('This is the final response.'));
      });

      test('handles multiple think blocks', () {
        const response = '''
        Start
        <think>First block</think>
        Middle
        <think>Second block</think>
        End
        ''';

        final result = service.removeThinkingTags(response);

        expect(result, isNot(contains('<think>')));
        expect(result, isNot(contains('</think>')));
        expect(result, isNot(contains('First block')));
        expect(result, isNot(contains('Second block')));
        expect(result, contains('Start'));
        expect(result, contains('Middle'));
        expect(result, contains('End'));
      });

      test('returns original text when no think tags present', () {
        const response = 'This is a regular response without thinking tags.';

        final result = service.removeThinkingTags(response);

        expect(result, equals(response));
      });

      test('handles malformed tags gracefully', () {
        const response = 'Text with <think> but no closing tag.';

        final result = service.removeThinkingTags(response);

        expect(result, equals(response));
      });
    });

    group('containsThinkingTags', () {
      test('returns true when both opening and closing tags are present', () {
        const content = '<think>Some thinking</think>';

        final result = service.containsThinkingTags(content);

        expect(result, isTrue);
      });

      test('returns false when only opening tag is present', () {
        const content = 'Text with <think> but no closing tag.';

        final result = service.containsThinkingTags(content);

        expect(result, isFalse);
      });

      test('returns false when only closing tag is present', () {
        const content = 'Text with </think> but no opening tag.';

        final result = service.containsThinkingTags(content);

        expect(result, isFalse);
      });

      test('returns false when no tags are present', () {
        const content = 'Regular text without any thinking tags.';

        final result = service.containsThinkingTags(content);

        expect(result, isFalse);
      });

      test('returns true when tags are in different lines', () {
        const content = '''
        Some text
        <think>
        Multi-line thinking
        </think>
        More text
        ''';

        final result = service.containsThinkingTags(content);

        expect(result, isTrue);
      });
    });

    group('analyzeThinking', () {
      test('identifies time-related keywords', () {
        const thinking = '''
        Looking at this week's data and last month's patterns,
        I can see trends from yesterday and today that suggest
        quarterly improvements this year.
        ''';

        final analysis = service.analyzeThinking(thinking);

        expect(analysis.timePeriodsIdentified, contains('week'));
        expect(analysis.timePeriodsIdentified, contains('last'));
        expect(analysis.timePeriodsIdentified, contains('this'));
        expect(analysis.timePeriodsIdentified, contains('month'));
        expect(analysis.timePeriodsIdentified, contains('yesterday'));
        expect(analysis.timePeriodsIdentified, contains('today'));
        expect(analysis.timePeriodsIdentified, contains('quarter'));
        expect(analysis.timePeriodsIdentified, contains('year'));
        expect(analysis.hasTimeAnalysis, isTrue);
      });

      test('identifies category-related keywords', () {
        const thinking = '''
        I need to analyze the categories and types of tasks,
        looking at different areas and domains of work.
        ''';

        final analysis = service.analyzeThinking(thinking);

        expect(analysis.categoriesIdentified, contains('categories'));
        expect(analysis.categoriesIdentified, contains('type'));
        expect(analysis.categoriesIdentified, contains('area'));
        expect(analysis.categoriesIdentified, contains('domain'));
        expect(analysis.hasCategoryAnalysis, isTrue);
      });

      test('identifies insight-related keywords', () {
        const thinking = '''
        I can see patterns in the data that reveal insights
        and trends. My analysis shows achievements that
        provide a good summary of progress.
        ''';

        final analysis = service.analyzeThinking(thinking);

        expect(analysis.insightsPlanned, contains('pattern'));
        expect(analysis.insightsPlanned, contains('insight'));
        expect(analysis.insightsPlanned, contains('trend'));
        expect(analysis.insightsPlanned, contains('analysis'));
        expect(analysis.insightsPlanned, contains('achievement'));
        expect(analysis.insightsPlanned, contains('summary'));
        expect(analysis.hasInsights, isTrue);
      });

      test('detects structured response planning', () {
        const structuredThinking1 = '''
        1. First, I'll analyze the data
        2. Then I'll identify patterns
        ''';

        const structuredThinking2 = '''
        I need to plan the structure of my response
        and organize the information logically.
        ''';

        const unstructuredThinking = '''
        Just some random thoughts about the task.
        ''';

        final analysis1 = service.analyzeThinking(structuredThinking1);
        final analysis2 = service.analyzeThinking(structuredThinking2);
        final analysis3 = service.analyzeThinking(unstructuredThinking);

        expect(analysis1.responseStructurePlanned, isTrue);
        expect(analysis1.isStructuredResponse, isTrue);
        expect(analysis2.responseStructurePlanned, isTrue);
        expect(analysis2.isStructuredResponse, isTrue);
        expect(analysis3.responseStructurePlanned, isFalse);
        expect(analysis3.isStructuredResponse, isFalse);
      });

      test('handles empty thinking content', () {
        const emptyThinking = '';

        final analysis = service.analyzeThinking(emptyThinking);

        expect(analysis.timePeriodsIdentified, isEmpty);
        expect(analysis.categoriesIdentified, isEmpty);
        expect(analysis.insightsPlanned, isEmpty);
        expect(analysis.responseStructurePlanned, isFalse);
        expect(analysis.hasTimeAnalysis, isFalse);
        expect(analysis.hasCategoryAnalysis, isFalse);
        expect(analysis.hasInsights, isFalse);
        expect(analysis.isStructuredResponse, isFalse);
      });

      test('is case insensitive for keyword matching', () {
        const thinking = '''
        WEEK and Month and TODAY
        CATEGORY and Type
        PATTERN and INSIGHT
        ''';

        final analysis = service.analyzeThinking(thinking);

        expect(analysis.timePeriodsIdentified, contains('week'));
        expect(analysis.timePeriodsIdentified, contains('month'));
        expect(analysis.timePeriodsIdentified, contains('today'));
        expect(analysis.categoriesIdentified, contains('category'));
        expect(analysis.categoriesIdentified, contains('type'));
        expect(analysis.insightsPlanned, contains('pattern'));
        expect(analysis.insightsPlanned, contains('insight'));
      });
    });
  });

  group('ThinkingAnalysis', () {
    test('creates analysis with all properties', () {
      const analysis = ThinkingAnalysis(
        timePeriodsIdentified: ['week', 'month'],
        categoriesIdentified: ['category', 'type'],
        insightsPlanned: ['pattern', 'trend'],
        responseStructurePlanned: true,
        thinkingDuration: Duration(seconds: 5),
      );

      expect(analysis.timePeriodsIdentified, equals(['week', 'month']));
      expect(analysis.categoriesIdentified, equals(['category', 'type']));
      expect(analysis.insightsPlanned, equals(['pattern', 'trend']));
      expect(analysis.responseStructurePlanned, isTrue);
      expect(analysis.thinkingDuration, equals(const Duration(seconds: 5)));

      expect(analysis.hasTimeAnalysis, isTrue);
      expect(analysis.hasCategoryAnalysis, isTrue);
      expect(analysis.hasInsights, isTrue);
      expect(analysis.isStructuredResponse, isTrue);
    });

    test('handles empty analysis correctly', () {
      const analysis = ThinkingAnalysis(
        timePeriodsIdentified: [],
        categoriesIdentified: [],
        insightsPlanned: [],
        responseStructurePlanned: false,
        thinkingDuration: null,
      );

      expect(analysis.hasTimeAnalysis, isFalse);
      expect(analysis.hasCategoryAnalysis, isFalse);
      expect(analysis.hasInsights, isFalse);
      expect(analysis.isStructuredResponse, isFalse);
      expect(analysis.thinkingDuration, isNull);
    });
  });
}

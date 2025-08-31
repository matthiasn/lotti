abstract class ThinkingModeService {
  String enhanceSystemPrompt(String basePrompt, {required bool useThinking});

  String? extractThinkingContent(String aiResponse);

  String removeThinkingTags(String aiResponse);

  bool containsThinkingTags(String content);

  ThinkingAnalysis analyzeThinking(String thinkingContent);
}

class ThinkingAnalysis {
  const ThinkingAnalysis({
    required this.timePeriodsIdentified,
    required this.categoriesIdentified,
    required this.insightsPlanned,
    required this.responseStructurePlanned,
    required this.thinkingDuration,
  });

  final List<String> timePeriodsIdentified;
  final List<String> categoriesIdentified;
  final List<String> insightsPlanned;
  final bool responseStructurePlanned;
  final Duration? thinkingDuration;

  bool get hasTimeAnalysis => timePeriodsIdentified.isNotEmpty;
  bool get hasCategoryAnalysis => categoriesIdentified.isNotEmpty;
  bool get hasInsights => insightsPlanned.isNotEmpty;
  bool get isStructuredResponse => responseStructurePlanned;
}

class ThinkingModeServiceImpl implements ThinkingModeService {
  static const String _thinkingInstruction = '''
<thinking_mode>
You are an AI assistant helping users understand their task history and productivity patterns.
Before responding, use the <think> tags to analyze the query and plan your response.

Inside <think> tags:
1. Identify the time period and categories being queried
2. Consider what insights would be most valuable
3. Look for patterns, achievements, and learnings
4. Plan a structured, helpful response

After thinking, provide a clear, insightful summary.
</thinking_mode>
''';

  @override
  String enhanceSystemPrompt(String basePrompt, {required bool useThinking}) {
    if (!useThinking) return basePrompt;
    return '$basePrompt\n\n$_thinkingInstruction';
  }

  @override
  String? extractThinkingContent(String aiResponse) {
    const startTag = '<think>';
    const endTag = '</think>';

    final startIndex = aiResponse.indexOf(startTag);
    if (startIndex == -1) return null;

    final endIndex = aiResponse.indexOf(endTag, startIndex + startTag.length);
    if (endIndex == -1) return null;

    return aiResponse.substring(startIndex + startTag.length, endIndex).trim();
  }

  @override
  String removeThinkingTags(String aiResponse) {
    return aiResponse
        .replaceAll(RegExp('<think>.*?</think>', dotAll: true), '')
        .trim();
  }

  @override
  bool containsThinkingTags(String content) {
    return content.contains('<think>') && content.contains('</think>');
  }

  @override
  ThinkingAnalysis analyzeThinking(String thinkingContent) {
    final timeKeywords = [
      'today',
      'yesterday',
      'week',
      'month',
      'quarter',
      'year',
      'last',
      'this'
    ];
    final timePeriodsFound = <String>[];

    for (final keyword in timeKeywords) {
      if (thinkingContent.toLowerCase().contains(keyword)) {
        timePeriodsFound.add(keyword);
      }
    }

    final categoryKeywords = [
      'category',
      'categories',
      'type',
      'area',
      'domain'
    ];
    final categoriesFound = <String>[];

    for (final keyword in categoryKeywords) {
      if (thinkingContent.toLowerCase().contains(keyword)) {
        categoriesFound.add(keyword);
      }
    }

    final insightKeywords = [
      'pattern',
      'insight',
      'trend',
      'analysis',
      'summary',
      'achievement'
    ];
    final insightsFound = <String>[];

    for (final keyword in insightKeywords) {
      if (thinkingContent.toLowerCase().contains(keyword)) {
        insightsFound.add(keyword);
      }
    }

    final hasStructure = thinkingContent.contains('1.') ||
        thinkingContent.contains('2.') ||
        thinkingContent.contains('plan') ||
        thinkingContent.contains('structure');

    return ThinkingAnalysis(
      timePeriodsIdentified: timePeriodsFound,
      categoriesIdentified: categoriesFound,
      insightsPlanned: insightsFound,
      responseStructurePlanned: hasStructure,
      thinkingDuration: null, // Could be calculated based on response time
    );
  }
}

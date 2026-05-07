import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/daily_token_usage.dart';

class _GeneratedDailyTokenUsageScenario {
  const _GeneratedDailyTokenUsageScenario({
    required this.totalTokens,
    required this.tokensByTimeOfDay,
    required this.inputTokens,
    required this.outputTokens,
    required this.thoughtsTokens,
    required this.cachedInputTokens,
    required this.wakeCount,
    required this.isToday,
  });

  final int totalTokens;
  final int tokensByTimeOfDay;
  final int inputTokens;
  final int outputTokens;
  final int thoughtsTokens;
  final int cachedInputTokens;
  final int wakeCount;
  final bool isToday;

  double get expectedCacheRate =>
      inputTokens > 0 ? cachedInputTokens / inputTokens : 0;

  int get expectedTokensPerWake => wakeCount > 0 ? totalTokens ~/ wakeCount : 0;

  DailyTokenUsage get usage => DailyTokenUsage(
    date: DateTime(2024, 3, 15),
    totalTokens: totalTokens,
    tokensByTimeOfDay: tokensByTimeOfDay,
    isToday: isToday,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    thoughtsTokens: thoughtsTokens,
    cachedInputTokens: cachedInputTokens,
    wakeCount: wakeCount,
  );

  @override
  String toString() {
    return '_GeneratedDailyTokenUsageScenario('
        'totalTokens: $totalTokens, '
        'tokensByTimeOfDay: $tokensByTimeOfDay, '
        'inputTokens: $inputTokens, outputTokens: $outputTokens, '
        'thoughtsTokens: $thoughtsTokens, '
        'cachedInputTokens: $cachedInputTokens, wakeCount: $wakeCount, '
        'isToday: $isToday)';
  }
}

class _GeneratedTokenUsageComparisonScenario {
  const _GeneratedTokenUsageComparisonScenario({
    required this.averageTokensByTimeOfDay,
    required this.todayTokens,
  });

  final int averageTokensByTimeOfDay;
  final int todayTokens;

  TokenUsageComparison get comparison => TokenUsageComparison(
    averageTokensByTimeOfDay: averageTokensByTimeOfDay,
    todayTokens: todayTokens,
  );

  @override
  String toString() {
    return '_GeneratedTokenUsageComparisonScenario('
        'averageTokensByTimeOfDay: $averageTokensByTimeOfDay, '
        'todayTokens: $todayTokens)';
  }
}

extension _AnyGeneratedDailyTokenUsage on glados.Any {
  glados.Generator<_GeneratedDailyTokenUsageScenario>
  get dailyTokenUsageScenario => glados.CombinableAny(this).combine6(
    glados.IntAnys(this).intInRange(0, 200000),
    glados.IntAnys(this).intInRange(0, 200000),
    glados.IntAnys(this).intInRange(0, 200000),
    glados.IntAnys(this).intInRange(0, 200000),
    glados.IntAnys(this).intInRange(0, 200000),
    glados.any.bool,
    (
      int totalTokens,
      int tokensByTimeOfDay,
      int inputTokens,
      int cachedInputTokens,
      int wakeCount,
      bool isToday,
    ) => _GeneratedDailyTokenUsageScenario(
      totalTokens: totalTokens,
      tokensByTimeOfDay: tokensByTimeOfDay,
      inputTokens: inputTokens,
      outputTokens: totalTokens,
      thoughtsTokens: tokensByTimeOfDay,
      cachedInputTokens: cachedInputTokens,
      wakeCount: wakeCount,
      isToday: isToday,
    ),
  );

  glados.Generator<_GeneratedTokenUsageComparisonScenario>
  get tokenUsageComparisonScenario => glados.CombinableAny(this).combine2(
    glados.IntAnys(this).intInRange(0, 200000),
    glados.IntAnys(this).intInRange(0, 200000),
    (
      int averageTokensByTimeOfDay,
      int todayTokens,
    ) => _GeneratedTokenUsageComparisonScenario(
      averageTokensByTimeOfDay: averageTokensByTimeOfDay,
      todayTokens: todayTokens,
    ),
  );
}

void main() {
  group('DailyTokenUsage', () {
    test('equality holds for identical values', () {
      final a = DailyTokenUsage(
        date: DateTime(2024, 3, 15),
        totalTokens: 1000,
        tokensByTimeOfDay: 600,
        isToday: false,
      );
      final b = DailyTokenUsage(
        date: DateTime(2024, 3, 15),
        totalTokens: 1000,
        tokensByTimeOfDay: 600,
        isToday: false,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when totalTokens differ', () {
      final a = DailyTokenUsage(
        date: DateTime(2024, 3, 15),
        totalTokens: 1000,
        tokensByTimeOfDay: 600,
        isToday: false,
      );
      final b = DailyTokenUsage(
        date: DateTime(2024, 3, 15),
        totalTokens: 2000,
        tokensByTimeOfDay: 600,
        isToday: false,
      );

      expect(a, isNot(equals(b)));
    });

    test('inequality when isToday differs', () {
      final a = DailyTokenUsage(
        date: DateTime(2024, 3, 15),
        totalTokens: 1000,
        tokensByTimeOfDay: 1000,
        isToday: true,
      );
      final b = DailyTokenUsage(
        date: DateTime(2024, 3, 15),
        totalTokens: 1000,
        tokensByTimeOfDay: 1000,
        isToday: false,
      );

      expect(a, isNot(equals(b)));
    });

    glados.Glados(
      glados.any.dailyTokenUsageScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('matches generated derived token usage semantics', (scenario) {
      final usage = scenario.usage;

      expect(
        usage.cacheRate,
        closeTo(scenario.expectedCacheRate, 0.000000000001),
        reason: '$scenario',
      );
      expect(
        usage.tokensPerWake,
        scenario.expectedTokensPerWake,
        reason: '$scenario',
      );
    });
  });

  group('TokenSourceBreakdown', () {
    test('equality holds for identical values', () {
      const a = TokenSourceBreakdown(
        templateId: 'tpl-1',
        displayName: 'Agent A',
        totalTokens: 5000,
        percentage: 50,
        wakeCount: 10,
        totalDuration: Duration(hours: 1),
        isHighUsage: true,
      );
      const b = TokenSourceBreakdown(
        templateId: 'tpl-1',
        displayName: 'Agent A',
        totalTokens: 5000,
        percentage: 50,
        wakeCount: 10,
        totalDuration: Duration(hours: 1),
        isHighUsage: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when percentage differs', () {
      const a = TokenSourceBreakdown(
        templateId: 'tpl-1',
        displayName: 'Agent A',
        totalTokens: 5000,
        percentage: 50,
        wakeCount: 10,
        totalDuration: Duration(hours: 1),
        isHighUsage: true,
      );
      const b = TokenSourceBreakdown(
        templateId: 'tpl-1',
        displayName: 'Agent A',
        totalTokens: 5000,
        percentage: 30,
        wakeCount: 10,
        totalDuration: Duration(hours: 1),
        isHighUsage: false,
      );

      expect(a, isNot(equals(b)));
    });

    test('inequality when displayName differs', () {
      const a = TokenSourceBreakdown(
        templateId: 'tpl-1',
        displayName: 'Agent A',
        totalTokens: 5000,
        percentage: 50,
        wakeCount: 10,
        totalDuration: Duration(hours: 1),
        isHighUsage: true,
      );
      const b = TokenSourceBreakdown(
        templateId: 'tpl-1',
        displayName: 'Agent B',
        totalTokens: 5000,
        percentage: 50,
        wakeCount: 10,
        totalDuration: Duration(hours: 1),
        isHighUsage: true,
      );

      expect(a, isNot(equals(b)));
    });

    test('inequality when wakeCount differs', () {
      const a = TokenSourceBreakdown(
        templateId: 'tpl-1',
        displayName: 'Agent A',
        totalTokens: 5000,
        percentage: 50,
        wakeCount: 10,
        totalDuration: Duration(hours: 1),
        isHighUsage: true,
      );
      const b = TokenSourceBreakdown(
        templateId: 'tpl-1',
        displayName: 'Agent A',
        totalTokens: 5000,
        percentage: 50,
        wakeCount: 5,
        totalDuration: Duration(hours: 1),
        isHighUsage: true,
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('TokenUsageComparison', () {
    test('isAboveAverage derived as getter', () {
      const above = TokenUsageComparison(
        averageTokensByTimeOfDay: 1000,
        todayTokens: 2000,
      );

      expect(above.isAboveAverage, isTrue);
      expect(above.todayTokens, greaterThan(above.averageTokensByTimeOfDay));
    });

    test('below average case', () {
      const below = TokenUsageComparison(
        averageTokensByTimeOfDay: 2000,
        todayTokens: 500,
      );

      expect(below.isAboveAverage, isFalse);
      expect(below.todayTokens, lessThan(below.averageTokensByTimeOfDay));
    });

    test('equality and hashCode', () {
      const a = TokenUsageComparison(
        averageTokensByTimeOfDay: 1000,
        todayTokens: 2000,
      );
      const b = TokenUsageComparison(
        averageTokensByTimeOfDay: 1000,
        todayTokens: 2000,
      );
      const c = TokenUsageComparison(
        averageTokensByTimeOfDay: 1000,
        todayTokens: 3000,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    glados.Glados(
      glados.any.tokenUsageComparisonScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('matches generated comparison getter semantics', (scenario) {
      final comparison = scenario.comparison;

      expect(
        comparison.isAboveAverage,
        scenario.todayTokens > scenario.averageTokensByTimeOfDay,
        reason: '$scenario',
      );
      expect(
        comparison.hasBaseline,
        scenario.averageTokensByTimeOfDay > 0,
        reason: '$scenario',
      );
      expect(
        comparison.isAtAverage,
        scenario.todayTokens == scenario.averageTokensByTimeOfDay,
        reason: '$scenario',
      );
    });
  });
}

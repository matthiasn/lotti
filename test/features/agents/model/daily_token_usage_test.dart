import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';

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
  });

  group('TokenUsageComparison', () {
    test('isAboveAverage reflects relationship', () {
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
  });
}

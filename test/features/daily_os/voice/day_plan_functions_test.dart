import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/voice/day_plan_functions.dart';

void main() {
  group('DayPlanFunctions', () {
    group('getTools', () {
      test('returns all five function definitions', () {
        final tools = DayPlanFunctions.getTools();

        expect(tools.length, 5);
      });

      test('includes add_time_block function', () {
        final tools = DayPlanFunctions.getTools();
        final addTool = tools.firstWhere(
          (t) => t.function.name == DayPlanFunctions.addTimeBlock,
        );

        expect(addTool.function.name, 'add_time_block');
        expect(addTool.function.description, isNotNull);
        expect(addTool.function.parameters, isNotNull);

        final params = addTool.function.parameters!;
        expect(params['required'], contains('categoryName'));
        expect(params['required'], contains('startTime'));
        expect(params['required'], contains('endTime'));
      });

      test('includes resize_time_block function', () {
        final tools = DayPlanFunctions.getTools();
        final resizeTool = tools.firstWhere(
          (t) => t.function.name == DayPlanFunctions.resizeTimeBlock,
        );

        expect(resizeTool.function.name, 'resize_time_block');
        expect(
            resizeTool.function.parameters!['required'], contains('blockId'));
      });

      test('includes move_time_block function', () {
        final tools = DayPlanFunctions.getTools();
        final moveTool = tools.firstWhere(
          (t) => t.function.name == DayPlanFunctions.moveTimeBlock,
        );

        expect(moveTool.function.name, 'move_time_block');
        expect(moveTool.function.parameters!['required'], contains('blockId'));
        expect(
          moveTool.function.parameters!['required'],
          contains('newStartTime'),
        );
      });

      test('includes delete_time_block function', () {
        final tools = DayPlanFunctions.getTools();
        final deleteTool = tools.firstWhere(
          (t) => t.function.name == DayPlanFunctions.deleteTimeBlock,
        );

        expect(deleteTool.function.name, 'delete_time_block');
        expect(
          deleteTool.function.parameters!['required'],
          contains('blockId'),
        );
      });

      test('includes link_task_to_day function', () {
        final tools = DayPlanFunctions.getTools();
        final linkTool = tools.firstWhere(
          (t) => t.function.name == DayPlanFunctions.linkTaskToDay,
        );

        expect(linkTool.function.name, 'link_task_to_day');
        expect(
          linkTool.function.parameters!['required'],
          contains('taskTitle'),
        );
      });
    });
  });

  group('parseTimeForDate', () {
    final testDate = DateTime(2026, 1, 15);

    group('HH:mm format', () {
      test('parses 09:00 correctly', () {
        final result = parseTimeForDate('09:00', testDate);

        expect(result, isNotNull);
        expect(result!.year, 2026);
        expect(result.month, 1);
        expect(result.day, 15);
        expect(result.hour, 9);
        expect(result.minute, 0);
      });

      test('parses 14:30 correctly', () {
        final result = parseTimeForDate('14:30', testDate);

        expect(result, isNotNull);
        expect(result!.hour, 14);
        expect(result.minute, 30);
      });

      test('parses 23:59 correctly', () {
        final result = parseTimeForDate('23:59', testDate);

        expect(result, isNotNull);
        expect(result!.hour, 23);
        expect(result.minute, 59);
      });

      test('parses 00:00 correctly', () {
        final result = parseTimeForDate('00:00', testDate);

        expect(result, isNotNull);
        expect(result!.hour, 0);
        expect(result.minute, 0);
      });
    });

    group('H:mm format (single digit hour)', () {
      test('parses 9:00 correctly', () {
        final result = parseTimeForDate('9:00', testDate);

        expect(result, isNotNull);
        expect(result!.hour, 9);
        expect(result.minute, 0);
      });

      test('parses 7:30 correctly', () {
        final result = parseTimeForDate('7:30', testDate);

        expect(result, isNotNull);
        expect(result!.hour, 7);
        expect(result.minute, 30);
      });
    });

    group('plain hour format', () {
      test('parses "9" as 09:00', () {
        final result = parseTimeForDate('9', testDate);

        expect(result, isNotNull);
        expect(result!.hour, 9);
        expect(result.minute, 0);
      });

      test('parses "14" as 14:00', () {
        final result = parseTimeForDate('14', testDate);

        expect(result, isNotNull);
        expect(result!.hour, 14);
        expect(result.minute, 0);
      });

      test('parses "0" as 00:00', () {
        final result = parseTimeForDate('0', testDate);

        expect(result, isNotNull);
        expect(result!.hour, 0);
        expect(result.minute, 0);
      });

      test('parses "23" as 23:00', () {
        final result = parseTimeForDate('23', testDate);

        expect(result, isNotNull);
        expect(result!.hour, 23);
        expect(result.minute, 0);
      });
    });

    group('whitespace handling', () {
      test('trims leading whitespace', () {
        final result = parseTimeForDate('  09:00', testDate);

        expect(result, isNotNull);
        expect(result!.hour, 9);
      });

      test('trims trailing whitespace', () {
        final result = parseTimeForDate('09:00  ', testDate);

        expect(result, isNotNull);
        expect(result!.hour, 9);
      });

      test('trims both leading and trailing whitespace', () {
        final result = parseTimeForDate('  09:00  ', testDate);

        expect(result, isNotNull);
        expect(result!.hour, 9);
      });
    });

    group('invalid inputs', () {
      test('returns null for empty string', () {
        final result = parseTimeForDate('', testDate);

        expect(result, isNull);
      });

      test('returns null for invalid format', () {
        final result = parseTimeForDate('abc', testDate);

        expect(result, isNull);
      });

      test('returns null for invalid hour (25)', () {
        final result = parseTimeForDate('25:00', testDate);

        expect(result, isNull);
      });

      test('returns null for invalid minute (60)', () {
        final result = parseTimeForDate('09:60', testDate);

        expect(result, isNull);
      });

      test('returns null for negative hour', () {
        final result = parseTimeForDate('-1:00', testDate);

        expect(result, isNull);
      });

      test('returns null for time with seconds', () {
        final result = parseTimeForDate('09:00:00', testDate);

        expect(result, isNull);
      });

      test('returns null for AM/PM format', () {
        final result = parseTimeForDate('9:00 AM', testDate);

        expect(result, isNull);
      });
    });

    group('date preservation', () {
      test('preserves year from input date', () {
        final date = DateTime(2025, 6, 20);
        final result = parseTimeForDate('10:00', date);

        expect(result!.year, 2025);
      });

      test('preserves month from input date', () {
        final date = DateTime(2026, 12, 25);
        final result = parseTimeForDate('10:00', date);

        expect(result!.month, 12);
      });

      test('preserves day from input date', () {
        final date = DateTime(2026, 1, 31);
        final result = parseTimeForDate('10:00', date);

        expect(result!.day, 31);
      });
    });
  });
}

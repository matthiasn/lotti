import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/task.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/themes/colors.dart';

void main() {
  group('TaskPriority parsing', () {
    test('parses P0..P3 correctly', () {
      expect(taskPriorityFromString('P0'), TaskPriority.p0Urgent);
      expect(taskPriorityFromString('P1'), TaskPriority.p1High);
      expect(taskPriorityFromString('P2'), TaskPriority.p2Medium);
      expect(taskPriorityFromString('P3'), TaskPriority.p3Low);
    });

    test('falls back to P2 for unknown', () {
      expect(taskPriorityFromString('Px'), TaskPriority.p2Medium);
    });

    glados.Glados(
      glados.any.generatedTaskPriorityInput,
      glados.ExploreConfig(numRuns: 160),
    ).test('matches generated trim/case/fallback parsing model', (scenario) {
      expect(
        taskPriorityFromString(scenario.input, fallback: scenario.fallback),
        scenario.expected,
        reason: '$scenario',
      );
    }, tags: 'glados');
  });

  group('TaskPriority ext helpers', () {
    test('rank and short mapping', () {
      expect(TaskPriority.p0Urgent.rank, 0);
      expect(TaskPriority.p0Urgent.short, 'P0');
      expect(TaskPriority.p3Low.rank, 3);
      expect(TaskPriority.p3Low.short, 'P3');
    });

    test('color mapping (light mode)', () {
      expect(
        TaskPriority.p0Urgent.colorForBrightness(Brightness.light),
        taskStatusDarkRed,
      );
      expect(
        TaskPriority.p1High.colorForBrightness(Brightness.light),
        taskStatusDarkOrange,
      );
      expect(
        TaskPriority.p2Medium.colorForBrightness(Brightness.light),
        taskStatusDarkBlue,
      );
      expect(
        TaskPriority.p3Low.colorForBrightness(Brightness.light),
        Colors.grey,
      );
    });

    test('color mapping (dark mode)', () {
      expect(
        TaskPriority.p0Urgent.colorForBrightness(Brightness.dark),
        taskStatusRed,
      );
      expect(
        TaskPriority.p1High.colorForBrightness(Brightness.dark),
        taskStatusOrange,
      );
      expect(
        TaskPriority.p2Medium.colorForBrightness(Brightness.dark),
        taskStatusBlue,
      );
      expect(
        TaskPriority.p3Low.colorForBrightness(Brightness.dark),
        Colors.grey,
      );
    });

    glados.Glados(
      glados.any.generatedTaskPriority,
      glados.ExploreConfig(numRuns: 80),
    ).test('round-trips generated priorities through short labels', (priority) {
      expect(priority.short, 'P${priority.rank}', reason: '$priority');
      expect(priority.rank, priority.index, reason: '$priority');
      expect(taskPriorityFromString(priority.short), priority);
    }, tags: 'glados');
  });

  group('TaskPriority localizedLabel', () {
    testWidgets('spells out each priority (Urgent/High/Medium/Low)', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(TaskPriority.p0Urgent.localizedLabel(ctx), 'Urgent');
      expect(TaskPriority.p1High.localizedLabel(ctx), 'High');
      expect(TaskPriority.p2Medium.localizedLabel(ctx), 'Medium');
      expect(TaskPriority.p3Low.localizedLabel(ctx), 'Low');
    });
  });
}

enum _GeneratedPriorityInputKind {
  known,
  unknownEmpty,
  unknownLetter,
  unknownRank,
  unknownSpaced,
  unknownWord,
}

enum _GeneratedPriorityCaseStyle { upper, lower, mixed }

enum _GeneratedPriorityWhitespace {
  none,
  leading,
  trailing,
  surrounding,
  tabsAndNewlines,
}

class _GeneratedTaskPriorityInput {
  const _GeneratedTaskPriorityInput({
    required this.kind,
    required this.priority,
    required this.caseStyle,
    required this.whitespace,
    required this.fallback,
  });

  final _GeneratedPriorityInputKind kind;
  final TaskPriority priority;
  final _GeneratedPriorityCaseStyle caseStyle;
  final _GeneratedPriorityWhitespace whitespace;
  final TaskPriority fallback;

  String get input {
    final raw = switch (kind) {
      _GeneratedPriorityInputKind.known => priority.short,
      _GeneratedPriorityInputKind.unknownEmpty => '',
      _GeneratedPriorityInputKind.unknownLetter => 'PX',
      _GeneratedPriorityInputKind.unknownRank => 'P4',
      _GeneratedPriorityInputKind.unknownSpaced => 'P 1',
      _GeneratedPriorityInputKind.unknownWord => 'priority',
    };
    return whitespace.apply(caseStyle.apply(raw));
  }

  TaskPriority get expected =>
      kind == _GeneratedPriorityInputKind.known ? priority : fallback;

  @override
  String toString() {
    return '_GeneratedTaskPriorityInput('
        'input: "$input", '
        'kind: $kind, '
        'priority: $priority, '
        'caseStyle: $caseStyle, '
        'whitespace: $whitespace, '
        'fallback: $fallback, '
        'expected: $expected)';
  }
}

extension on _GeneratedPriorityCaseStyle {
  String apply(String value) => switch (this) {
    _GeneratedPriorityCaseStyle.upper => value.toUpperCase(),
    _GeneratedPriorityCaseStyle.lower => value.toLowerCase(),
    _GeneratedPriorityCaseStyle.mixed =>
      value
          .split('')
          .indexed
          .map((item) => item.$1.isEven ? item.$2.toUpperCase() : item.$2)
          .join(),
  };
}

extension on _GeneratedPriorityWhitespace {
  String apply(String value) => switch (this) {
    _GeneratedPriorityWhitespace.none => value,
    _GeneratedPriorityWhitespace.leading => '  $value',
    _GeneratedPriorityWhitespace.trailing => '$value  ',
    _GeneratedPriorityWhitespace.surrounding => ' $value ',
    _GeneratedPriorityWhitespace.tabsAndNewlines => '\t$value\n',
  };
}

extension _AnyTaskPriority on glados.Any {
  glados.Generator<TaskPriority> get generatedTaskPriority =>
      glados.AnyUtils(this).choose(TaskPriority.values);

  glados.Generator<_GeneratedPriorityInputKind> get _priorityInputKind =>
      glados.AnyUtils(this).choose(_GeneratedPriorityInputKind.values);

  glados.Generator<_GeneratedPriorityCaseStyle> get _priorityCaseStyle =>
      glados.AnyUtils(this).choose(_GeneratedPriorityCaseStyle.values);

  glados.Generator<_GeneratedPriorityWhitespace> get _priorityWhitespace =>
      glados.AnyUtils(this).choose(_GeneratedPriorityWhitespace.values);

  glados.Generator<_GeneratedTaskPriorityInput>
  get generatedTaskPriorityInput => glados.CombinableAny(this).combine5(
    _priorityInputKind,
    generatedTaskPriority,
    _priorityCaseStyle,
    _priorityWhitespace,
    generatedTaskPriority,
    (
      _GeneratedPriorityInputKind kind,
      TaskPriority priority,
      _GeneratedPriorityCaseStyle caseStyle,
      _GeneratedPriorityWhitespace whitespace,
      TaskPriority fallback,
    ) => _GeneratedTaskPriorityInput(
      kind: kind,
      priority: priority,
      caseStyle: caseStyle,
      whitespace: whitespace,
      fallback: fallback,
    ),
  );
}

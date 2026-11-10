import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/front_agent/model/front_task_draft.dart';

void main() {
  final now = DateTime(2026, 11, 8, 14, 30);

  FrontTaskDraft? read(Map<String, dynamic> args) => FrontTaskDraft.fromModel(
    args,
    categoryExists: (id) => id == 'work',
    followUpExists: (id) => id == 'task-roses',
    now: now,
  );

  group('fromModel', () {
    test('reads every field the words gave, the start resolved against the '
        "routing turn's clock", () {
      final draft = read({
        'title': '  Fix the login bug ',
        'instructions': 'Reproduce on Android first.',
        'categoryId': 'work',
        'priority': 'p1',
        'due': '2026-11-10',
        'estimateMinutes': 90,
        'startedMinutesAgo': 10,
      })!;
      expect(draft.title, 'Fix the login bug');
      expect(draft.instructions, 'Reproduce on Android first.');
      expect(draft.categoryId, 'work');
      expect(draft.priority, TaskPriority.p1High);
      expect(draft.due, DateTime(2026, 11, 10));
      expect(draft.estimate, const Duration(minutes: 90));
      expect(draft.startedAt, DateTime(2026, 11, 8, 14, 20));
    });

    test('is nothing without a title', () {
      expect(read({'title': '   '}), isNull);
      expect(read({'priority': 'P0'}), isNull);
    });

    test('leaves out what the model got wrong and keeps the task', () {
      final draft = read({
        'title': 'Call the vet',
        'categoryId': 'unlisted',
        'priority': 'urgent',
        'due': '2026-02-30',
        'estimateMinutes': 0,
        'startedMinutesAgo': -5,
      })!;
      expect(draft.title, 'Call the vet');
      expect(draft.categoryId, isNull);
      expect(draft.priority, isNull);
      expect(draft.due, isNull, reason: 'February has no 30th');
      expect(draft.estimate, isNull);
      expect(draft.startedAt, isNull);
    });

    test('a start of 0 is now; one past a day back is refused', () {
      expect(
        read({'title': 'x', 'startedMinutesAgo': 0})!.startedAt,
        now,
      );
      expect(
        read({
          'title': 'x',
          'startedMinutesAgo': frontTaskMaxStartedMinutesAgo + 1,
        })!.startedAt,
        isNull,
      );
    });

    test('in progress is a status apart from a start: it sets no timer', () {
      final inProgress = read({'title': 'x', 'inProgress': true})!;
      expect(inProgress.inProgress, isTrue);
      expect(inProgress.startedAt, isNull);

      final started = read({'title': 'x', 'startedMinutesAgo': 0})!;
      expect(started.inProgress, isFalse);
      expect(started.startedAt, now);
    });

    test('in progress is only a true the model gave', () {
      for (final value in <Object?>[null, false, 'true', 1]) {
        expect(
          read({'title': 'x', 'inProgress': value})!.inProgress,
          isFalse,
          reason: '$value',
        );
      }
    });

    test('a follow-up stands only on a task the turn may name', () {
      expect(
        read({
          'title': 'x',
          'followsUpTaskId': ' task-roses ',
        })!.followsUpTaskId,
        'task-roses',
      );
      expect(
        read({
          'title': 'x',
          'followsUpTaskId': 'task-invented',
        })!.followsUpTaskId,
        isNull,
      );
      expect(
        FrontTaskDraft.fromModel(
          {'title': 'x', 'followsUpTaskId': 'task-roses'},
          categoryExists: (_) => true,
          now: now,
        )!.followsUpTaskId,
        isNull,
        reason: 'without a check, no follow-up id stands',
      );
    });

    test('caps an overlong title', () {
      final draft = read({'title': 'a' * (frontTaskTitleMaxLength + 50)})!;
      expect(draft.title.length, frontTaskTitleMaxLength);
    });
  });

  test('round-trips through the stored record, the start as an instant', () {
    final draft = FrontTaskDraft(
      title: 'Fix the login bug',
      instructions: 'Reproduce first.',
      categoryId: 'work',
      priority: TaskPriority.p0Urgent,
      due: DateTime(2026, 11, 10),
      estimate: const Duration(minutes: 45),
      startedAt: DateTime(2026, 11, 8, 14, 20),
      followsUpTaskId: 'task-roses',
    );
    final json = draft.toJson();
    expect(json['priority'], 'P0');
    expect(json['due'], '2026-11-10');

    final read = FrontTaskDraft.fromJson(json)!;
    expect(read.title, draft.title);
    expect(read.instructions, draft.instructions);
    expect(read.categoryId, draft.categoryId);
    expect(read.priority, draft.priority);
    expect(read.due, draft.due);
    expect(read.estimate, draft.estimate);
    expect(read.startedAt, draft.startedAt);
    expect(read.followsUpTaskId, 'task-roses');
    expect(read.inProgress, isFalse);
    expect(json.containsKey('inProgress'), isFalse);
    expect(FrontTaskDraft.fromJson({'title': ''}), isNull);
    expect(FrontTaskDraft.fromJson('nope'), isNull);
  });

  test('round-trips a draft in progress without a start', () {
    const draft = FrontTaskDraft(title: 'Pack', inProgress: true);
    final json = draft.toJson();
    expect(json, {'title': 'Pack', 'inProgress': true});

    final read = FrontTaskDraft.fromJson(json)!;
    expect(read.inProgress, isTrue);
    expect(read.startedAt, isNull);
  });
}

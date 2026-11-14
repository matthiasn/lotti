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

  group('status', () {
    test('is the one chosen, else in progress when the words say so or a '
        'timer runs, else open', () {
      expect(
        const FrontTaskDraft(
          title: 'Pack',
          inProgress: true,
          start: FrontTaskStart.groomed,
        ).status,
        FrontTaskStart.groomed,
      );
      expect(
        const FrontTaskDraft(title: 'Pack', inProgress: true).status,
        FrontTaskStart.inProgress,
      );
      expect(
        FrontTaskDraft(title: 'Pack', startedAt: DateTime(2026, 11, 11)).status,
        FrontTaskStart.inProgress,
      );
      expect(const FrontTaskDraft(title: 'Pack').status, FrontTaskStart.open);
    });

    test('each reads back as the task status it names', () {
      expect(
        {for (final s in FrontTaskStart.values) s: s.dbStatus},
        {
          FrontTaskStart.open: 'OPEN',
          FrontTaskStart.groomed: 'GROOMED',
          FrontTaskStart.inProgress: 'IN PROGRESS',
        },
      );
    });
  });

  group('FrontTaskChoices', () {
    test('starts at what the words said', () {
      final draft = FrontTaskDraft(
        title: 'Pack',
        priority: TaskPriority.p0Urgent,
        due: DateTime(2026, 11, 12),
        inProgress: true,
      );
      expect(
        FrontTaskChoices.of(draft),
        FrontTaskChoices(
          start: FrontTaskStart.inProgress,
          priority: TaskPriority.p0Urgent,
          due: DateTime(2026, 11, 12),
        ),
      );
    });

    test('for bare words, open at medium priority with no due day', () {
      const plain = FrontTaskChoices(
        start: FrontTaskStart.open,
        priority: TaskPriority.p2Medium,
      );
      expect(FrontTaskChoices.of(null), plain);
      expect(FrontTaskChoices.of(const FrontTaskDraft(title: 'Pack')), plain);
    });

    test('copyWith changes only what it is given; a due day can be '
        'cleared', () {
      final choices = FrontTaskChoices(
        start: FrontTaskStart.open,
        priority: TaskPriority.p3Low,
        due: DateTime(2026, 11, 12),
      );
      expect(choices.copyWith(), choices);
      expect(choices.copyWith(), isNot(same(choices)));
      expect(
        choices.copyWith(start: FrontTaskStart.groomed).start,
        FrontTaskStart.groomed,
      );
      expect(
        choices.copyWith(priority: TaskPriority.p1High).priority,
        TaskPriority.p1High,
      );
      expect(choices.copyWith(due: () => null).due, isNull);
      expect(choices.copyWith(due: () => null).priority, TaskPriority.p3Low);
    });

    test('are equal by value', () {
      final a = FrontTaskChoices(
        start: FrontTaskStart.open,
        priority: TaskPriority.p1High,
        due: DateTime(2026, 11, 12),
      );
      final b = FrontTaskChoices(
        start: FrontTaskStart.open,
        priority: TaskPriority.p1High,
        due: DateTime(2026, 11, 12),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(b.copyWith(start: FrontTaskStart.inProgress)));
      expect(a, isNot(b.copyWith(priority: TaskPriority.p0Urgent)));
      expect(a, isNot(b.copyWith(due: () => null)));
      expect(a == Object(), isFalse);
    });
  });

  group('withChoices', () {
    final draft = FrontTaskDraft(
      title: 'Fix the login bug',
      instructions: 'Reproduce first.',
      categoryId: 'work',
      priority: TaskPriority.p3Low,
      estimate: const Duration(minutes: 45),
      startedAt: DateTime(2026, 11, 11, 9),
      followsUpTaskId: 'task-roses',
    );

    test('sets what the user set up over what the words said, and keeps '
        'the rest', () {
      final set = draft.withChoices(
        FrontTaskChoices(
          start: FrontTaskStart.inProgress,
          priority: TaskPriority.p0Urgent,
          due: DateTime(2026, 11, 11),
        ),
      );
      expect(set.status, FrontTaskStart.inProgress);
      expect(set.priority, TaskPriority.p0Urgent);
      expect(set.due, DateTime(2026, 11, 11));
      expect(set.title, draft.title);
      expect(set.instructions, draft.instructions);
      expect(set.categoryId, 'work');
      expect(set.estimate, draft.estimate);
      expect(set.followsUpTaskId, 'task-roses');
      // In progress, the dictated timer still runs.
      expect(set.startedAt, draft.startedAt);
    });

    test('a task set up as not in progress runs no timer', () {
      for (final start in [FrontTaskStart.open, FrontTaskStart.groomed]) {
        final set = draft.withChoices(
          FrontTaskChoices(start: start, priority: TaskPriority.p2Medium),
        );
        expect(set.status, start);
        expect(set.startedAt, isNull);
        expect(set.inProgress, isFalse);
      }
    });
  });

  test('namesChoices: only words that set a status, priority, due day or '
      'start name any', () {
    expect(const FrontTaskDraft(title: 'Count').namesChoices, isFalse);
    for (final draft in [
      const FrontTaskDraft(title: 'Count', start: FrontTaskStart.groomed),
      const FrontTaskDraft(title: 'Count', priority: TaskPriority.p3Low),
      FrontTaskDraft(title: 'Count', due: DateTime(2026, 11, 11)),
      const FrontTaskDraft(title: 'Count', inProgress: true),
      FrontTaskDraft(title: 'Count', startedAt: DateTime(2026, 11, 11, 9)),
      const FrontTaskDraft(title: 'Count', coverArt: true),
    ]) {
      expect(draft.namesChoices, isTrue, reason: '${draft.toJson()}');
    }
  });

  group('cover art', () {
    FrontTaskDraft? read(Object? coverArt) => FrontTaskDraft.fromModel(
      {'title': 'Count the penguins', 'coverArt': coverArt},
      categoryExists: (_) => true,
      now: DateTime(2026, 11, 14, 9),
    );

    test('is only a true the model gave', () {
      expect(read(true)!.coverArt, isTrue);
      for (final other in [false, null, 'true', 1]) {
        expect(read(other)!.coverArt, isFalse, reason: '$other');
      }
    });

    test('is stored only when asked for, and reads back', () {
      const asked = FrontTaskDraft(title: 'Count', coverArt: true);
      expect(asked.toJson()['coverArt'], isTrue);
      expect(FrontTaskDraft.fromJson(asked.toJson())!.coverArt, isTrue);

      const plain = FrontTaskDraft(title: 'Count');
      expect(plain.toJson().containsKey('coverArt'), isFalse);
      expect(FrontTaskDraft.fromJson(plain.toJson())!.coverArt, isFalse);
      // A record from before the field was kept reads as none asked for.
      expect(FrontTaskDraft.fromJson({'title': 'Count'})!.coverArt, isFalse);
    });

    test('the choices start at what the words asked for', () {
      expect(
        FrontTaskChoices.of(
          const FrontTaskDraft(title: 'Count', coverArt: true),
        ).coverArt,
        isTrue,
      );
      expect(
        FrontTaskChoices.of(const FrontTaskDraft(title: 'Count')).coverArt,
        isFalse,
      );
      expect(FrontTaskChoices.of(null).coverArt, isFalse);
    });

    test('copyWith sets it and leaves it alone when not given', () {
      const none = FrontTaskChoices(
        start: FrontTaskStart.open,
        priority: TaskPriority.p2Medium,
      );
      final on = none.copyWith(coverArt: true);
      expect(on.coverArt, isTrue);
      expect(on.copyWith(priority: TaskPriority.p0Urgent).coverArt, isTrue);
      expect(on.copyWith(coverArt: false).coverArt, isFalse);
    });

    test('two choices that differ only in it are not equal', () {
      const none = FrontTaskChoices(
        start: FrontTaskStart.open,
        priority: TaskPriority.p2Medium,
      );
      final on = none.copyWith(coverArt: true);
      expect(on, isNot(none));
      expect(on.hashCode, isNot(none.hashCode));
      expect(on, none.copyWith(coverArt: true));
    });

    test("withChoices takes the user's choice over the words, either way", () {
      const none = FrontTaskChoices(
        start: FrontTaskStart.open,
        priority: TaskPriority.p2Medium,
      );
      const asked = FrontTaskDraft(title: 'Count', coverArt: true);
      const plain = FrontTaskDraft(title: 'Count');
      expect(asked.withChoices(none).coverArt, isFalse);
      expect(
        plain.withChoices(none.copyWith(coverArt: true)).coverArt,
        isTrue,
      );
    });
  });

  group('FrontTaskExtra.fromNames', () {
    test('reads the names it knows, in the order they are offered', () {
      expect(FrontTaskExtra.fromNames(['codingPrompt', 'coverArt']).toList(), [
        FrontTaskExtra.coverArt,
        FrontTaskExtra.codingPrompt,
      ]);
      expect(FrontTaskExtra.fromNames(['codingPrompt']), {
        FrontTaskExtra.codingPrompt,
      });
    });

    test('leaves out a name it does not know, and reads no list as none', () {
      expect(FrontTaskExtra.fromNames(['hologram', 'coverArt', 3]), {
        FrontTaskExtra.coverArt,
      });
      for (final other in [null, 'coverArt', <String, Object?>{}]) {
        expect(FrontTaskExtra.fromNames(other), isEmpty, reason: '$other');
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_reply_parts.dart';

void main() {
  const hatchlings = FrontTaskMention(id: 't1', title: 'Count the hatchlings');
  const cameras = FrontTaskMention(id: 't2', title: 'Check the nest cameras');

  test('a reply with no list of tasks is her words alone', () {
    expect(frontReplyParts('Nothing is due today.'), const [
      FrontReplyText('Nothing is due today.'),
    ]);
  });

  test('two task lines or more are a list, her words kept around it, in '
      'order', () {
    const reply = '''
Two things are due today:

- [Count the hatchlings](lotti://task/t1)
- [Check the nest cameras](lotti://task/t2)

Start with the cameras.''';

    expect(frontReplyParts(reply), const [
      FrontReplyText('Two things are due today:'),
      FrontReplyTasks([hatchlings, cameras]),
      FrontReplyText('Start with the cameras.'),
    ]);
  });

  test('takes every bullet she might write, numbers too, and the plural '
      'path', () {
    const reply = '''
* [Count the hatchlings](lotti://task/t1)
1. [Check the nest cameras](lotti://tasks/t2)''';

    expect(frontReplyParts(reply), const [
      FrontReplyTasks([hatchlings, cameras]),
    ]);
  });

  test('a task named twice in one list is one row, and one task named twice '
      'stays a link in her words', () {
    const twice = '''
- [Count the hatchlings](lotti://task/t1)
- [Check the nest cameras](lotti://task/t2)
- [Count the hatchlings](lotti://task/t1)''';
    expect(frontReplyParts(twice), const [
      FrontReplyTasks([hatchlings, cameras]),
    ]);

    const same = '''
- [Count the hatchlings](lotti://task/t1)
- [Count the hatchlings](lotti://task/t1)''';
    expect(frontReplyParts(same), const [FrontReplyText(same)]);
  });

  test('a single task stays a link in her words', () {
    const reply = 'Only one:\n- [Count the hatchlings](lotti://task/t1)';
    expect(frontReplyParts(reply), const [FrontReplyText(reply)]);
  });

  test('whatever she writes after the link, the line is a row: how she '
      'phrases it varies, the list must not', () {
    const reply = '''
- [Count the hatchlings](lotti://task/t1), before noon
- **[Check the nest cameras](lotti://task/t2)** — in progress, Colony''';
    expect(frontReplyParts(reply), const [
      FrontReplyTasks([hatchlings, cameras]),
    ]);
  });

  test('blank lines between the items keep them one list, and words after '
      'the list are hers', () {
    const reply = '''
- [Count the hatchlings](lotti://task/t1)

- [Check the nest cameras](lotti://task/t2)

Start with the cameras.''';
    expect(frontReplyParts(reply), const [
      FrontReplyTasks([hatchlings, cameras]),
      FrontReplyText('Start with the cameras.'),
    ]);
  });

  test('a line with words before the link is hers', () {
    const reply = '''
- First [Count the hatchlings](lotti://task/t1)
- [Check the nest cameras](lotti://task/t2)''';
    // Only one task leads a line, so nothing is drawn as rows.
    expect(frontReplyParts(reply), const [FrontReplyText(reply)]);
  });

  test('an overdue list is a list too: an emphasised link, and when it was '
      'due after it — the row shows that itself', () {
    const reply = '''
Overdue:
- **[Count the hatchlings](lotti://task/t1)**, due 2026-10-30
- *[Check the nest cameras](lotti://task/t2)* (due 2026-10-28)
- [Feed the chicks](lotti://task/t3) — fällig 2026-10-27
- [Clean the burrow](lotti://task/t4) (overdue)''';
    expect(frontReplyParts(reply), const [
      FrontReplyText('Overdue:'),
      FrontReplyTasks([
        hatchlings,
        cameras,
        FrontTaskMention(id: 't3', title: 'Feed the chicks'),
        FrontTaskMention(id: 't4', title: 'Clean the burrow'),
      ]),
    ]);
  });

  test('emphasis that does not close keeps the line hers', () {
    const unbalanced = '''
- **[Count the hatchlings](lotti://task/t1)
- [Check the nest cameras](lotti://task/t2)''';
    expect(frontReplyParts(unbalanced), const [FrontReplyText(unbalanced)]);
  });

  test('what a search found is a list too, projects beside tasks, each '
      'opening as what it is', () {
    const reply = '''
- [Census](lotti://project/p1)
- [Count the hatchlings](lotti://task/t1)''';
    expect(frontReplyParts(reply), const [
      FrontReplyTasks([
        FrontTaskMention(
          id: 'p1',
          title: 'Census',
          kind: FrontDestinationKind.project,
        ),
        hatchlings,
      ]),
    ]);
  });

  test('an overdue-and-due list echoing the lookup — a date and the '
      'overdue mark both — is a list', () {
    const reply = '''
- [Count the hatchlings](lotti://task/t1) — due 2026-10-30 (overdue)
- [Check the nest cameras](lotti://task/t2), due 2026-11-08''';
    expect(frontReplyParts(reply), const [
      FrontReplyTasks([hatchlings, cameras]),
    ]);
  });

  test('overdue and due split under two headings, one task each, are rows '
      'under each, since the reply names two tasks', () {
    const reply = '''
Overdue:
- [Count the hatchlings](lotti://task/t1)

Due today:
- [Check the nest cameras](lotti://task/t2)''';
    expect(frontReplyParts(reply), const [
      FrontReplyText('Overdue:'),
      FrontReplyTasks([hatchlings]),
      FrontReplyText('Due today:'),
      FrontReplyTasks([cameras]),
    ]);
  });

  test('two lists apart are two lists', () {
    const reply = '''
- [Count the hatchlings](lotti://task/t1)
- [Check the nest cameras](lotti://task/t2)
And overdue:
- [Count the hatchlings](lotti://task/t1)
- [Check the nest cameras](lotti://task/t2)''';

    expect(frontReplyParts(reply), const [
      FrontReplyTasks([hatchlings, cameras]),
      FrontReplyText('And overdue:'),
      FrontReplyTasks([hatchlings, cameras]),
    ]);
  });

  test('parts compare by what they hold', () {
    expect(const FrontReplyText('a'), const FrontReplyText('a'));
    expect(
      const FrontReplyText('a').hashCode,
      const FrontReplyText('a').hashCode,
    );
    expect(
      const FrontReplyTasks([hatchlings]),
      isNot(const FrontReplyTasks([cameras])),
    );
    expect(
      const FrontReplyTasks([hatchlings]),
      isNot(const FrontReplyTasks([hatchlings, cameras])),
    );
    expect(
      const FrontReplyTasks([hatchlings]).hashCode,
      const FrontReplyTasks([hatchlings]).hashCode,
    );
    expect(
      hatchlings.hashCode,
      Object.hash('t1', 'Count the hatchlings', FrontDestinationKind.task),
    );
    expect(hatchlings.toString(), contains('t1'));
    expect(const FrontReplyText('a').toString(), contains('a'));
    expect(const FrontReplyTasks([hatchlings]).toString(), contains('t1'));
  });
}

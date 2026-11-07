import 'package:flutter_test/flutter_test.dart';
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

  test('a single task stays a link in her words', () {
    const reply = 'Only one:\n- [Count the hatchlings](lotti://task/t1)';
    expect(frontReplyParts(reply), const [FrontReplyText(reply)]);
  });

  test('a line that says more than the link is her words, and breaks the '
      'list', () {
    const reply = '''
- [Count the hatchlings](lotti://task/t1), before noon
- [Check the nest cameras](lotti://task/t2)''';
    expect(frontReplyParts(reply), const [FrontReplyText(reply)]);
  });

  test('a project link is not a task', () {
    const reply = '''
- [Census](lotti://project/p1)
- [Survey](lotti://project/p2)''';
    expect(frontReplyParts(reply), const [FrontReplyText(reply)]);
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
    expect(hatchlings.hashCode, Object.hash('t1', 'Count the hatchlings'));
    expect(hatchlings.toString(), contains('t1'));
    expect(const FrontReplyText('a').toString(), contains('a'));
    expect(const FrontReplyTasks([hatchlings]).toString(), contains('t1'));
  });
}

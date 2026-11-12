import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/workflow/front_reply_stream.dart';

void main() {
  test('one block, then her prose: the component without its wiring, the '
      'prose apart', () {
    final reply = parseFrontReplyStream('''
<a2ui>
surface("reply")
root = TaskCards("Due today", ["task:t-ice", "task:t-feed"])
</a2ui>

You have two tasks due today.''');

    expect(reply.components, [
      {
        'component': 'TaskCards',
        'caption': 'Due today',
        'ids': ['task:t-ice', 'task:t-feed'],
      },
    ]);
    expect(reply.prose, 'You have two tasks due today.');
    expect(reply.errors, isEmpty);
  });

  test("a root Reply's children are the parts, top to bottom", () {
    final reply = parseFrontReplyStream('''
<a2ui>
surface("reply")
root = Reply([
  Text("Overdue"),
  TaskCards("Overdue tasks", ["task:t-ice"], ["since Friday"]),
  LoggedTimeChart("Time this week"),
  QuickReplies(["Break it down"])
])
</a2ui>
One is overdue.''');

    expect(reply.components, [
      {'component': 'Text', 'text': 'Overdue'},
      {
        'component': 'TaskCards',
        'caption': 'Overdue tasks',
        'ids': ['task:t-ice'],
        'notes': ['since Friday'],
      },
      {'component': 'LoggedTimeChart', 'caption': 'Time this week'},
      {
        'component': 'QuickReplies',
        'options': ['Break it down'],
      },
    ]);
    expect(reply.prose, 'One is overdue.');
  });

  test('a Reply inside a Reply stands for its children, in order', () {
    final reply = parseFrontReplyStream('''
<a2ui>
surface("reply")
root = Reply([
  Text("Overdue"),
  Reply([TaskCards("Overdue tasks", ["task:t-ice"]), Text("Due today")]),
  TaskCards("Tasks due today", ["task:t-seal"])
])
</a2ui>
One is overdue, one is due.''');

    expect(reply.errors, isEmpty);
    expect(
      [
        for (final component in reply.components)
          component['text'] ?? component['caption'],
      ],
      ['Overdue', 'Overdue tasks', 'Due today', 'Tasks due today'],
    );
  });

  group('a message still being written', () {
    FrontStreamedReply sofar(String content) =>
        parseFrontReplyStream(content, complete: false);

    test('the start of a tag is held back, not shown as prose', () {
      for (final content in ['<', '<a2', '<a2ui', '<a2ui>']) {
        final reply = sofar(content);
        expect(reply.prose, isEmpty, reason: content);
        expect(reply.components, isEmpty, reason: content);
        expect(reply.errors, isEmpty, reason: content);
      }
    });

    test('a block left open is not an error yet, and draws nothing', () {
      final reply = sofar('<a2ui>\nsurface("reply")\nroot = TaskCards("Due');

      expect(reply.components, isEmpty);
      expect(reply.errors, isEmpty);
      expect(reply.prose, isEmpty);
    });

    test('a closed block is drawn before a word of prose has come, and the '
        'prose grows after it', () {
      const block =
          '<a2ui>\nsurface("reply")\n'
          'root = TaskCards("Due today", ["task:t-ice"])\n</a2ui>\n';
      const cards = {
        'component': 'TaskCards',
        'caption': 'Due today',
        'ids': ['task:t-ice'],
      };

      expect(sofar(block).components, [cards]);
      expect(sofar(block).prose, isEmpty);

      final later = sofar('${block}One thing is');
      expect(later.components, [cards]);
      expect(later.prose, 'One thing is');
    });

    test('prose alone grows as it comes', () {
      expect(sofar('Nothing').prose, 'Nothing');
      expect(sofar('Nothing is due today.').prose, 'Nothing is due today.');
    });
  });

  test('a plain answer is prose alone', () {
    final reply = parseFrontReplyStream('All right, talk soon.');

    expect(reply.prose, 'All right, talk soon.');
    expect(reply.components, isEmpty);
    expect(reply.errors, isEmpty);
  });

  test('a block that names what the catalog does not have is left out and '
      'reported; her prose and the block after it are kept', () {
    final reply = parseFrontReplyStream('''
<a2ui>
surface("bad")
root = Hologram("Nope")
</a2ui>
<a2ui>
surface("good")
root = ClosedTasks("Closed this week")
</a2ui>
Three were closed.''');

    expect(reply.components, [
      {'component': 'ClosedTasks', 'caption': 'Closed this week'},
    ]);
    expect(reply.prose, 'Three were closed.');
    expect(reply.errors.single, contains('Hologram'));
  });

  test('a block left open is reported, and what came before it stands', () {
    final reply = parseFrontReplyStream('''
Here you go.
<a2ui>
surface("reply")
root = TaskCards("Due", ["task:t-ice"''');

    expect(reply.prose, 'Here you go.');
    expect(reply.components, isEmpty);
    expect(reply.errors, isNotEmpty);
  });

  test('the prompt snippet teaches the notation, the catalog and both '
      'examples', () {
    expect(frontReplyPromptSnippet, contains('<a2ui>'));
    for (final name in [
      'Reply',
      'Text',
      'TaskCards',
      'ClosedTasks',
      'LoggedTimeChart',
      'PullRequestChart',
      'QuickReplies',
    ]) {
      expect(frontReplyPromptSnippet, contains(name), reason: name);
    }
    expect(frontReplyPromptSnippet, contains('Tasks found'));
    expect(frontReplyPromptSnippet, contains('Logged time this week'));
  });
}

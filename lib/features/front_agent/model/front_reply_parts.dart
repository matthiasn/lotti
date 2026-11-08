import 'package:meta/meta.dart';

/// One task her words name in a list: its id and the title she gave it.
@immutable
class FrontTaskMention {
  const FrontTaskMention({required this.id, required this.title});

  final String id;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is FrontTaskMention && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);

  @override
  String toString() => 'FrontTaskMention($id, $title)';
}

/// A stretch of her reply: words, or a list of tasks.
@immutable
sealed class FrontReplyPart {
  const FrontReplyPart();
}

/// Words, as the Markdown she wrote them in.
class FrontReplyText extends FrontReplyPart {
  const FrontReplyText(this.markdown);

  final String markdown;

  @override
  bool operator ==(Object other) =>
      other is FrontReplyText && other.markdown == markdown;

  @override
  int get hashCode => markdown.hashCode;

  @override
  String toString() => 'FrontReplyText($markdown)';
}

/// A list of tasks, drawn as task rows rather than as links.
class FrontReplyTasks extends FrontReplyPart {
  const FrontReplyTasks(this.tasks);

  final List<FrontTaskMention> tasks;

  @override
  bool operator ==(Object other) =>
      other is FrontReplyTasks &&
      other.tasks.length == tasks.length &&
      Iterable<int>.generate(
        tasks.length,
      ).every((i) => other.tasks[i] == tasks[i]);

  @override
  int get hashCode => Object.hashAll(tasks);

  @override
  String toString() => 'FrontReplyTasks($tasks)';
}

/// A Markdown list line that is one task link and nothing else:
/// `- [title](lotti://task/<id>)` — `*` or `+` bullets, or `1.`, and the
/// plural `tasks` path the app also opens.
///
/// The link may be emphasised (`**[title](…)**`) and followed by when it was
/// due — a few words around a `YYYY-MM-DD` date, or the lookup's
/// `(overdue)` mark — as she tends to write an overdue list: the row shows
/// the due date itself, so nothing she said is lost. Any other words after
/// the link are hers, and keep the line out of the list.
final RegExp _taskLine = RegExp(
  r'^\s*(?:[-*+]|\d+[.)])\s+(\*\*|\*|__|_)?'
  r'\[([^\]\n]+)\]\(lotti://tasks?/([^)\s/]+)\)\1'
  r'(?:[\s,;:—–-]*\(?[\p{L}\s]{0,24}\d{4}-\d{2}-\d{2}\)?|\s*\(overdue\))?'
  r'\s*$',
  unicode: true,
);

/// The fewest task lines that make a list worth drawing as one: a single
/// task stays a link in her words.
const int frontTaskListMinimum = 2;

/// [markdown] cut into her words and the lists of tasks in them, in order.
///
/// A list is consecutive list lines naming [frontTaskListMinimum] or more
/// distinct tasks, each line one task link and at most when it is due
/// ([_taskLine]) — what the prompt asks her to write when she names tasks,
/// due today or overdue alike. Everything else, a line that says more than
/// the link included, stays her words. A reply with no such list is one
/// [FrontReplyText].
List<FrontReplyPart> frontReplyParts(String markdown) {
  final lines = markdown.split('\n');
  final parts = <FrontReplyPart>[];
  final words = <String>[];
  var run = <({String line, FrontTaskMention task})>[];

  void flushWords() {
    final text = words.join('\n').trim();
    if (text.isNotEmpty) parts.add(FrontReplyText(text));
    words.clear();
  }

  void flushRun() {
    // A task named twice in one list is one row: rows are keyed by task id.
    final seen = <String>{};
    final tasks = [
      for (final r in run)
        if (seen.add(r.task.id)) r.task,
    ];
    if (tasks.length >= frontTaskListMinimum) {
      flushWords();
      parts.add(FrontReplyTasks(tasks));
    } else {
      words.addAll([for (final r in run) r.line]);
    }
    run = [];
  }

  for (final line in lines) {
    final match = _taskLine.firstMatch(line);
    if (match != null) {
      run.add((
        line: line,
        task: FrontTaskMention(
          id: match.group(3)!,
          title: match.group(2)!.trim(),
        ),
      ));
      continue;
    }
    flushRun();
    words.add(line);
  }
  flushRun();
  flushWords();
  return parts;
}

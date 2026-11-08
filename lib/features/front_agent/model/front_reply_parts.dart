import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:meta/meta.dart';

/// One task — or project, as a search answer lists them side by side — her
/// words name in a list: its id, the title she gave it, and which it is.
@immutable
class FrontTaskMention {
  const FrontTaskMention({
    required this.id,
    required this.title,
    this.kind = FrontDestinationKind.task,
  });

  final String id;
  final String title;

  /// [FrontDestinationKind.task] or [FrontDestinationKind.project]: the
  /// kinds her words link to.
  final FrontDestinationKind kind;

  @override
  bool operator ==(Object other) =>
      other is FrontTaskMention &&
      other.id == id &&
      other.title == title &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(id, title, kind);

  @override
  String toString() => 'FrontTaskMention(${kind.wireName}, $id, $title)';
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

/// A list of tasks (and projects), drawn as rows rather than as links.
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

/// A Markdown list line that leads with a task or project link:
/// `- [title](lotti://task/<id>)`, `lotti://project/<id>` — `*` or `+`
/// bullets, or `1.`, the plural paths the app also opens, and the link
/// emphasised or not (`**[title](…)**`).
///
/// Whatever she writes after the link — when it is due, its status, a few
/// words of why — is left out: the row shows the task as it is now, and its
/// one-liner, which is what those words would say. How she phrases a line
/// varies from turn to turn, so the list must not hinge on it.
final RegExp _taskLine = RegExp(
  r'^\s*(?:[-*+]|\d+[.)])\s+(\*\*|\*|__|_)?'
  r'\[([^\]\n]+)\]\(lotti://(task|project)s?/([^)\s/]+)\)\1'
  r'.*$',
  unicode: true,
);

/// One list line as she wrote it, and the task it links.
typedef _TaskLine = ({String line, FrontTaskMention task});

/// The fewest distinct tasks or projects a reply's list lines must name before they are
/// drawn as rows: a single one stays a link in her words.
const int frontTaskListMinimum = 2;

/// [markdown] cut into her words and the lists of tasks in them, in order.
///
/// A list is consecutive list lines that each lead with a task or project
/// link ([_taskLine]), blank lines between them included — what the prompt
/// asks her to write when she names tasks, due today or overdue alike, or
/// what a search found. The lists are drawn as rows once the
/// reply's list lines name [frontTaskListMinimum] distinct records between
/// them, so an overdue-and-due answer split under two headings, one task
/// each, is rows too. Everything else stays her words. A reply with no such list is one
/// [FrontReplyText].
List<FrontReplyPart> frontReplyParts(String markdown) {
  // Her words and runs of task lines, in order, before deciding what a run
  // is drawn as.
  final segments = <Object>[]; // String | List<_TaskLine>
  var run = <_TaskLine>[];
  // Blank lines after a task line: inside the list if another follows.
  final blanks = <String>[];
  for (final line in markdown.split('\n')) {
    if (run.isNotEmpty && line.trim().isEmpty) {
      blanks.add(line);
      continue;
    }
    final match = _taskLine.firstMatch(line);
    if (match != null) {
      run.add((
        line: line,
        task: FrontTaskMention(
          id: match.group(4)!,
          title: match.group(2)!.trim(),
          kind: match.group(3) == 'project'
              ? FrontDestinationKind.project
              : FrontDestinationKind.task,
        ),
      ));
      blanks.clear();
      continue;
    }
    if (run.isNotEmpty) segments.add(run);
    run = [];
    segments
      ..addAll(blanks)
      ..add(line);
    blanks.clear();
  }
  if (run.isNotEmpty) segments.add(run);
  segments.addAll(blanks);

  final runs = segments.whereType<List<_TaskLine>>();
  final asRows =
      {
        for (final r in runs.expand((r) => r)) (r.task.kind, r.task.id),
      }.length >=
      frontTaskListMinimum;

  final parts = <FrontReplyPart>[];
  final words = <String>[];
  void flushWords() {
    final text = words.join('\n').trim();
    if (text.isNotEmpty) parts.add(FrontReplyText(text));
    words.clear();
  }

  for (final segment in segments) {
    switch (segment) {
      case final String line:
        words.add(line);
      case final List<_TaskLine> lines when !asRows:
        words.addAll([for (final r in lines) r.line]);
      case final List<_TaskLine> lines:
        // A task named twice in one list is one row: rows are keyed by id.
        final seen = <(FrontDestinationKind, String)>{};
        flushWords();
        parts.add(
          FrontReplyTasks([
            for (final r in lines)
              if (seen.add((r.task.kind, r.task.id))) r.task,
          ]),
        );
    }
  }
  flushWords();
  return parts;
}

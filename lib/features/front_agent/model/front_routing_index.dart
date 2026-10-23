import 'package:lotti/features/front_agent/model/front_dispatch.dart';

/// Caps per kind. Deterministic, so the rendered block stays under ~400
/// rows whatever the workspace holds; a truncated kind says so in the block.
const int frontIndexMaxTasks = 200;
const int frontIndexMaxProjects = 50;
const int frontIndexMaxGoals = 50;
const int frontIndexMaxPeople = 100;

/// How many open tasks one `match_to_corpus` may return.
const int frontCorpusMatchLimit = 8;

/// One destination the front agent may route to: enough to recognise it by
/// name and by what it is about right now, never its raw content.
class FrontIndexRow {
  const FrontIndexRow({
    required this.kind,
    required this.id,
    required this.title,
    this.oneLiner,
    this.tldr,
    this.status,
    this.categoryId,
    this.due,
  });

  final FrontDestinationKind kind;
  final String id;
  final String title;

  /// The owner agent's one-liner — what it is about right now — when a
  /// report exists.
  final String? oneLiner;

  /// The owner agent's TL;DR, held for `read_tldr` and never rendered into
  /// the index block.
  final String? tldr;
  final String? status;
  final String? categoryId;
  final DateTime? due;
}

/// The bounded, deterministic catalogue a front wake routes against.
///
/// Rows are sorted by id within each kind and rendered in one fixed format,
/// so the block is byte-identical between two wakes unless the record
/// changed — which is what lets a provider's prefix cache pay. One-liners
/// are rendered on purpose: they are the sentence that says what a task is
/// about right now, the routing signal; TL;DRs stay behind `read_tldr`.
class FrontRoutingIndex {
  FrontRoutingIndex({
    List<FrontIndexRow> tasks = const [],
    List<FrontIndexRow> projects = const [],
    List<FrontIndexRow> goals = const [],
    List<FrontIndexRow> people = const [],
    this.tasksTruncated = false,
    this.omittedProjects = 0,
    this.omittedGoals = 0,
    this.omittedPeople = 0,
  }) : tasks = _sorted(tasks),
       projects = _sorted(projects),
       goals = _sorted(goals),
       people = _sorted(people);

  final List<FrontIndexRow> tasks;
  final List<FrontIndexRow> projects;
  final List<FrontIndexRow> goals;
  final List<FrontIndexRow> people;

  /// The task query stops at its cap, so beyond it only "more exist" is
  /// known; the other kinds are read whole and capped in memory, so their
  /// omitted counts are exact.
  final bool tasksTruncated;
  final int omittedProjects;
  final int omittedGoals;
  final int omittedPeople;

  static List<FrontIndexRow> _sorted(List<FrontIndexRow> rows) =>
      [...rows]..sort((a, b) => a.id.compareTo(b.id));

  /// The row for one destination, or null when the index does not list it.
  FrontIndexRow? row(FrontDestinationKind kind, String id) =>
      _rowsOf(kind).where((row) => row.id == id).firstOrNull;

  /// Whether the index lists [id] as a destination of [kind].
  bool contains(FrontDestinationKind kind, String id) => row(kind, id) != null;

  /// Every listed destination id, by kind.
  Iterable<FrontIndexRow> get rows => [
    ...tasks,
    ...projects,
    ...goals,
    ...people,
  ];

  List<FrontIndexRow> _rowsOf(FrontDestinationKind kind) => switch (kind) {
    FrontDestinationKind.task => tasks,
    FrontDestinationKind.project => projects,
    FrontDestinationKind.goal => goals,
    FrontDestinationKind.person => people,
    _ => const [],
  };

  /// The prompt block. Stable formatting is the contract: do not add a
  /// field that changes between wakes without the record changing.
  String render() {
    final buffer = StringBuffer()..writeln('<routing_index>');
    _renderKind(
      buffer,
      heading: 'Tasks',
      rows: tasks,
      omitted: tasksTruncated ? null : 0,
    );
    _renderKind(
      buffer,
      heading: 'Projects',
      rows: projects,
      omitted: omittedProjects,
    );
    _renderKind(buffer, heading: 'Goals', rows: goals, omitted: omittedGoals);
    _renderKind(
      buffer,
      heading: 'People',
      rows: people,
      omitted: omittedPeople,
    );
    buffer.write('</routing_index>');
    return buffer.toString();
  }

  /// [omitted] `null` means "more exist, count unknown".
  void _renderKind(
    StringBuffer buffer, {
    required String heading,
    required List<FrontIndexRow> rows,
    required int? omitted,
  }) {
    final suffix = omitted == null
        ? ', more exist but are not shown'
        : omitted > 0
        ? ', +$omitted not shown'
        : '';
    buffer.writeln('## $heading (${rows.length} shown$suffix)');
    for (final row in rows) {
      buffer
        ..write('- ')
        ..write(row.kind.wireName)
        ..write(':')
        ..write(row.id)
        ..write(' | ')
        ..write(_oneLine(row.title));
      if (row.status != null) buffer.write(' | ${row.status}');
      if (row.due case final due?) {
        buffer.write(' | due ${_isoDay(due)}');
      }
      if (row.oneLiner case final oneLiner? when oneLiner.trim().isNotEmpty) {
        buffer.write(' | ${_oneLine(oneLiner)}');
      }
      buffer.writeln();
    }
  }

  static String _oneLine(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _isoDay(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

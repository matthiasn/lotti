import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/insights/logic/period_navigation.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

/// Caps per kind. Deterministic, so the rendered block is bounded whatever
/// the workspace holds; a truncated kind says so in the block. At every
/// cap the block is ~7.5k tokens — 200 task rows at ~25, 50 project and 50
/// goal rows at ~20, 50 name-only people rows at ~8 — which with the ~1k
/// contract above it lands near the 8k cold-prefill target of ADR 0057.
const int frontIndexMaxTasks = 200;
const int frontIndexMaxProjects = 50;
const int frontIndexMaxGoals = 50;
const int frontIndexMaxPeople = 50;

/// How many open tasks one `match_to_corpus` may return.
const int frontCorpusMatchLimit = 8;

/// How many tasks one `list_due_tasks` may return.
const int frontDueTaskLimit = 30;

/// How many tasks with logged time one `summarize_logged_time` may return.
const int frontLoggedTaskLimit = 30;

/// Which due tasks one `list_due_tasks` asks for, split at local midnight
/// as the task list's *Due today* and *Overdue* views split them: a
/// question about one of them is answered with that one alone.
enum FrontDueWindow {
  /// Due on today's local day; nothing overdue.
  today,

  /// Due on an earlier day than today.
  overdue,

  /// Due from today through `daysAhead` days past it; nothing overdue.
  upcoming,

  /// Overdue, and due from today through `daysAhead` days past it.
  all;

  /// The name the tool contract uses, or null for none of them.
  static FrontDueWindow? fromWire(Object? value) =>
      values.where((window) => window.name == value).firstOrNull;
}

/// One `list_due_tasks` call, validated: the `window`, how many days past
/// today `upcoming` and `all` reach, and the categories a category named in
/// the question narrows it to — empty for the turn's whole scope.
typedef FrontDueQuery = ({
  FrontDueWindow window,
  int daysAhead,
  Set<String> categoryIds,
});

/// What one `list_due_tasks` found: the open tasks in its [window], [today]
/// the local day the question was asked on, each row a destination the turn
/// may now route to and link.
class FrontDueTasks {
  const FrontDueTasks({
    required this.window,
    required this.today,
    required this.through,
    required this.rows,
    this.omitted = 0,
    this.categoryNames = const {},
    this.narrowedTo = const [],
  });

  final FrontDueWindow window;

  /// Local midnights; [through] is [today] for `today` and `overdue`.
  final DateTime today;
  final DateTime through;

  /// Soonest due first; in `all`, the overdue ones lead.
  final List<FrontIndexRow> rows;

  /// How many more were in the window than [frontDueTaskLimit] let through.
  final int omitted;

  /// Each row's category by id, so a row says where it belongs.
  final Map<String, String> categoryNames;

  /// The names of the categories the call was narrowed to by a category
  /// named in the question; empty when it was not.
  final List<String> narrowedTo;

  /// The tool's answer: a heading naming the window and any category it was
  /// narrowed to, then one row per task as the index renders one — in `all`,
  /// an overdue task marked.
  String render() {
    const day = FrontRoutingIndex._isoDay;
    final what = switch (window) {
      FrontDueWindow.today => 'due today (${day(today)})',
      FrontDueWindow.overdue => 'overdue (due before ${day(today)})',
      FrontDueWindow.upcoming when through == today =>
        'due today (${day(today)})',
      FrontDueWindow.upcoming => 'due ${day(today)} through ${day(through)}',
      FrontDueWindow.all when through == today =>
        'overdue or due today (${day(today)})',
      FrontDueWindow.all => 'overdue or due through ${day(through)}',
    };
    final within = narrowedTo.isEmpty ? '' : ' in ${narrowedTo.join(', ')}';
    if (rows.isEmpty) return 'None: no open task $what$within.';
    final buffer = StringBuffer(
      'Open tasks $what$within (${rows.length}'
      '${omitted > 0 ? ', +$omitted not shown' : ''}):\n',
    );
    for (final row in rows) {
      buffer.write(
        '- task:${row.id} | ${FrontRoutingIndex._oneLine(row.title)}',
      );
      if (row.status != null) buffer.write(' | ${row.status}');
      if (row.due case final due?) {
        buffer.write(' | due ${day(due)}');
        if (window == FrontDueWindow.all && due.isBefore(today)) {
          buffer.write(' (overdue)');
        }
      }
      if (categoryNames[row.categoryId] case final name?) {
        buffer.write(' | ${FrontRoutingIndex._oneLine(name)}');
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }
}

/// The periods one `summarize_logged_time` may sum, each a run of whole
/// local days resolved against the day the question was asked on.
enum FrontTimePeriod {
  today('today'),
  yesterday('yesterday'),
  thisWeek('this_week'),
  past7Days('past_7_days'),
  past30Days('past_30_days'),
  thisMonth('this_month'),
  lastMonth('last_month');

  const FrontTimePeriod(this.wireName);

  /// The name the tool contract uses.
  final String wireName;

  /// The period [value] names on the wire, or null for none of them.
  static FrontTimePeriod? fromWire(Object? value) =>
      values.where((period) => period.wireName == value).firstOrNull;

  /// The local days this period covers on [now]'s day. The past N days end
  /// with today; a week or month still running ends with today too, never
  /// in the future. Weeks start on [firstDayOfWeekIndex] (`0 = Sunday` …
  /// `6 = Saturday`), as the Insights page starts them.
  InsightsRange rangeOn(
    DateTime now, {
    int firstDayOfWeekIndex = defaultFirstDayOfWeekIndex,
  }) {
    final day = epochDay(now);
    InsightsRange lastDays(int count) =>
        InsightsRange(startDay: day - count + 1, endDayExclusive: day + 1);
    InsightsRange soFar(InsightsRange period) =>
        InsightsRange(startDay: period.startDay, endDayExclusive: day + 1);
    return switch (this) {
      FrontTimePeriod.today => lastDays(1),
      FrontTimePeriod.yesterday => InsightsRange(
        startDay: day - 1,
        endDayExclusive: day,
      ),
      FrontTimePeriod.thisWeek => soFar(
        periodContaining(
          InsightsPeriodUnit.week,
          now,
          firstDayOfWeekIndex: firstDayOfWeekIndex,
        ),
      ),
      FrontTimePeriod.past7Days => lastDays(7),
      FrontTimePeriod.past30Days => lastDays(30),
      FrontTimePeriod.thisMonth => soFar(
        periodContaining(InsightsPeriodUnit.month, now),
      ),
      FrontTimePeriod.lastMonth => periodContaining(
        InsightsPeriodUnit.month,
        DateTime(now.year, now.month - 1),
      ),
    };
  }
}

/// One `summarize_logged_time` call, validated: the `period` and the
/// categories the user named — empty when they named none.
typedef FrontTimeQuery = ({FrontTimePeriod period, Set<String> categoryIds});

/// What one `summarize_logged_time` found: the time logged in [period],
/// per category, largest first, and the tasks that time went to.
class FrontLoggedTime {
  const FrontLoggedTime({
    required this.period,
    required this.from,
    required this.through,
    required this.byCategory,
    required this.chart,
    this.named = const [],
    this.tasks = const [],
    this.omittedTasks = 0,
  });

  final FrontTimePeriod period;

  /// The days summed and the turn's category scope, for her reply's chart.
  final FrontLoggedTimeChart chart;

  /// Local midnights of the first and the last day summed.
  final DateTime from;
  final DateTime through;

  /// Each category's name — null for time in no category — and its seconds,
  /// largest first, none of them zero. When the user [named] categories,
  /// only those are by name; the rest is one entry, [otherCategories].
  final List<({String? name, int seconds})> byCategory;

  /// The names of the categories the user named; empty when none.
  final List<String> named;

  /// The tasks the time went to and each one's seconds, largest first, at
  /// most [frontLoggedTaskLimit] — in the named categories when some are.
  final List<({FrontIndexRow row, int seconds})> tasks;

  /// How many more tasks had time than [frontLoggedTaskLimit] let through.
  final int omittedTasks;

  /// The [byCategory] name of every category the user did not name.
  static const otherCategories = 'Other categories';

  /// The tool's answer: a heading naming the period, its days, any named
  /// category and the total, one line per category, then one per task.
  String render() {
    const day = FrontRoutingIndex._isoDay;
    const oneLine = FrontRoutingIndex._oneLine;
    final days = from == through
        ? day(from)
        : '${day(from)} through ${day(through)}';
    final what = '${period.wireName.replaceAll('_', ' ')} ($days)';
    if (byCategory.isEmpty) return 'None: no time logged $what.';
    final total = byCategory.fold(0, (sum, entry) => sum + entry.seconds);
    final against = named.isEmpty
        ? ''
        : ' (${named.map(oneLine).join(', ')} named; every other category '
              'is "$otherCategories", never to be broken down)';
    final buffer = StringBuffer(
      'Time logged $what: ${_hoursMinutes(total)} in total, by category, '
      'largest first$against:\n',
    );
    for (final (:name, :seconds) in byCategory) {
      final label = name == null ? 'No category' : oneLine(name);
      buffer.writeln('- $label: ${_hoursMinutes(seconds)}');
    }
    if (tasks.isNotEmpty) {
      buffer.writeln(
        'Tasks the time went to${named.isEmpty ? '' : ' in ${named.join(', ')}'}'
        ' (${tasks.length}'
        '${omittedTasks > 0 ? ', +$omittedTasks not shown' : ''}), '
        'largest first:',
      );
      for (final (:row, :seconds) in tasks) {
        buffer.write('- task:${row.id} | ${oneLine(row.title)}');
        if (row.status != null) buffer.write(' | ${row.status}');
        buffer.writeln(' | ${_hoursMinutes(seconds)}');
      }
    }
    return buffer.toString().trimRight();
  }

  /// `45m`, `2h`, `31h 5m`: hours never roll into days, so a month's total
  /// reads as the hours it is.
  static String _hoursMinutes(int seconds) {
    final minutes = (seconds / 60).round();
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '${rest}m';
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }
}

/// One category she may see, as the routing index names it: [chosen] when
/// the conversation's chips narrow the turn to it.
class FrontCategory {
  const FrontCategory({
    required this.id,
    required this.name,
    this.chosen = false,
  });

  final String id;
  final String name;
  final bool chosen;
}

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
    List<FrontCategory> categories = const [],
    this.tasksTruncated = false,
    this.omittedProjects = 0,
    this.omittedGoals = 0,
    this.omittedPeople = 0,
  }) : tasks = _sorted(tasks),
       projects = _sorted(projects),
       goals = _sorted(goals),
       people = _sorted(people),
       categories = [...categories]
         ..sort((a, b) {
           final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
           return byName != 0 ? byName : a.id.compareTo(b.id);
         });

  /// The categories she may see, by name — what a category the user names
  /// resolves against. Never destinations.
  final List<FrontCategory> categories;

  /// The category with [id], or null when she may not see it.
  FrontCategory? category(String id) =>
      categories.where((category) => category.id == id).firstOrNull;

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
    _renderCategories(buffer);
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

  /// The categories by name, those the conversation's chips chose marked —
  /// the rest of the index is narrowed to them then.
  void _renderCategories(StringBuffer buffer) {
    if (categories.isEmpty) return;
    final narrowed = categories.any((category) => category.chosen);
    buffer.writeln(
      '## Categories (${categories.length}'
      '${narrowed ? '; this conversation is narrowed to the chosen ones' : ''})',
    );
    for (final category in categories) {
      buffer.write('- category:${category.id} | ${_oneLine(category.name)}');
      if (category.chosen) buffer.write(' | chosen');
      buffer.writeln();
    }
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
      buffer.writeln(renderRow(row));
    }
  }

  /// One row as the index lists it: `kind:id | title | status | due |
  /// one-liner`, the parts it lacks left out. [withCategory] appends
  /// `category:id` — what `<conversation_tasks>` carries, so the category a
  /// conversation has been working in informs a new task's; the index leaves
  /// it out, a few tokens on every row of every wake.
  static String renderRow(FrontIndexRow row, {bool withCategory = false}) {
    final buffer = StringBuffer()
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
    final categoryId = row.categoryId;
    if (withCategory && categoryId != null && categoryId.isNotEmpty) {
      buffer.write(' | category:$categoryId');
    }
    return buffer.toString();
  }

  static String _oneLine(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _isoDay(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

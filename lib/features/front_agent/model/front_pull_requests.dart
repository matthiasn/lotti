import 'package:collection/collection.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:meta/meta.dart';

/// How many days one `summarize_pull_requests` may span: a month, so every
/// bar of its chart is one day and still readable inside a reply.
const int frontPullRequestMaxDays = 31;

/// How many pull requests one `summarize_pull_requests` lists by name.
const int frontPullRequestListLimit = 30;

/// One validated `summarize_pull_requests` call: a named `period`, resolved
/// on the device's first weekday, or days the call spelled out — the past
/// N days, or a first and last day — already resolved to `range`.
typedef FrontPullRequestQuery = ({
  FrontTimePeriod? period,
  InsightsRange? range,
});

/// Reads the window of one `summarize_pull_requests` call made on [now]'s
/// day: exactly one of a `period`, `pastDays` — the past N days, ending
/// today — or `from` with `through`, two `YYYY-MM-DD` days, both included.
/// Null when it names none, more than one, or one that is malformed, runs
/// backwards or spans more than [maxDays] days.
FrontPullRequestQuery? frontPullRequestQuery(
  Map<String, dynamic> args,
  DateTime now, {
  int maxDays = frontPullRequestMaxDays,
}) {
  final period = args['period'];
  final pastDays = args['pastDays'];
  final from = args['from'];
  final through = args['through'];
  final forms = [
    period != null,
    pastDays != null,
    from != null || through != null,
  ].where((given) => given).length;
  if (forms != 1) return null;
  if (period != null) {
    final named = FrontTimePeriod.fromWire(period);
    return named == null ? null : (period: named, range: null);
  }
  final today = epochDay(now);
  if (pastDays != null) {
    // A model may send 14.0 for 14.
    final days = pastDays is num && pastDays == pastDays.roundToDouble()
        ? pastDays.toInt()
        : null;
    if (days == null || days < 1 || days > maxDays) {
      return null;
    }
    return (
      period: null,
      range: InsightsRange(
        startDay: today - days + 1,
        endDayExclusive: today + 1,
      ),
    );
  }
  final first = _epochDayOf(from);
  final last = _epochDayOf(through);
  if (first == null ||
      last == null ||
      last < first ||
      last - first + 1 > maxDays) {
    return null;
  }
  return (
    period: null,
    range: InsightsRange(startDay: first, endDayExclusive: last + 1),
  );
}

/// The epoch day of a `YYYY-MM-DD` [value]; null for anything else,
/// including a day the month does not have.
int? _epochDayOf(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final [year, month, day] = [
    for (var group = 1; group <= 3; group++) int.parse(match.group(group)!),
  ];
  final date = DateTime(year, month, day);
  if (date.month != month || date.day != day) return null;
  return epochDay(date);
}

/// One pull request as the statistics count it: when it was opened and
/// merged on GitHub, in UTC, and its size as its last refresh saw it.
@immutable
class FrontPullRequest {
  const FrontPullRequest({
    required this.key,
    required this.title,
    this.createdAt,
    this.mergedAt,
    this.additions = 0,
    this.deletions = 0,
  });

  /// `owner/repo#number`.
  final String key;
  final String title;

  /// Null for a snapshot stored before it carried the opening: such a pull
  /// request can count as merged, never as opened on a day.
  final DateTime? createdAt;
  final DateTime? mergedAt;
  final int additions;
  final int deletions;
}

/// The pull requests opened on each local day of a range, with the lines
/// they added and deleted: one value per day, oldest first, an empty day a
/// zero. What her chart draws, per day and as running totals.
@immutable
class FrontPullRequestDays {
  const FrontPullRequestDays({
    required this.days,
    required this.opened,
    required this.additions,
    required this.deletions,
  });

  /// Local midnight of each day.
  final List<DateTime> days;
  final List<int> opened;
  final List<int> additions;
  final List<int> deletions;

  /// Whether no pull request was opened on any day.
  bool get isEmpty => opened.every((count) => count == 0);
}

/// [pullRequests] opened inside [range], summed per local day of opening:
/// a pull request counts once, on the day it was opened, with all its
/// lines.
FrontPullRequestDays frontPullRequestDays(
  Iterable<FrontPullRequest> pullRequests,
  InsightsRange range,
) {
  final length = range.endDayExclusive - range.startDay;
  final opened = List.filled(length, 0);
  final additions = List.filled(length, 0);
  final deletions = List.filled(length, 0);
  for (final pr in pullRequests) {
    final createdAt = pr.createdAt;
    if (createdAt == null) continue;
    final index = epochDay(createdAt.toLocal()) - range.startDay;
    if (index < 0 || index >= length) continue;
    opened[index]++;
    additions[index] += pr.additions;
    deletions[index] += pr.deletions;
  }
  return FrontPullRequestDays(
    days: [for (var i = 0; i < length; i++) dayStart(range.startDay + i)],
    opened: opened,
    additions: additions,
    deletions: deletions,
  );
}

/// What her reply to a pull request question charts: the days one
/// `summarize_pull_requests` read, the categories the turn could see and
/// whose pull requests counted.
///
/// The reply stores this, never the figures: the chart reads them again
/// when drawn, so a private task's pull requests show only while private
/// entries do.
@immutable
class FrontPullRequestChart {
  const FrontPullRequestChart({
    required this.range,
    required this.categoryIds,
    this.authorLogin,
  });

  final InsightsRange range;

  /// The turn's category scope, through the tasks holding the pull
  /// requests; empty for every category.
  final Set<String> categoryIds;

  /// The user's GitHub login when it was known: only their own pull
  /// requests count. Null counts every pull request their tasks hold.
  final String? authorLogin;

  Map<String, Object> toJson() => {
    'startDay': range.startDay,
    'endDayExclusive': range.endDayExclusive,
    'categoryIds': categoryIds.toList()..sort(),
    'authorLogin': ?authorLogin,
  };

  /// Reads a stored chart; null for none or a shape this build does not know.
  static FrontPullRequestChart? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = json['startDay'];
    final end = json['endDayExclusive'];
    final ids = json['categoryIds'];
    final login = json['authorLogin'];
    if (start is! int ||
        end is! int ||
        start >= end ||
        ids is! List ||
        (login != null && login is! String)) {
      return null;
    }
    return FrontPullRequestChart(
      range: InsightsRange(startDay: start, endDayExclusive: end),
      categoryIds: ids.whereType<String>().toSet(),
      authorLogin: login as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FrontPullRequestChart &&
      other.range == range &&
      other.authorLogin == authorLogin &&
      const SetEquality<String>().equals(other.categoryIds, categoryIds);

  @override
  int get hashCode => Object.hash(
    range,
    authorLogin,
    const SetEquality<String>().hash(categoryIds),
  );
}

/// What one `summarize_pull_requests` found in its days: the pull requests
/// opened there and those merged there, and how many it could not place.
class FrontPullRequests {
  const FrontPullRequests({
    required this.chart,
    required this.pullRequests,
    this.period,
    this.undated = 0,
  });

  /// The named period asked about; null for days the call spelled out.
  final FrontTimePeriod? period;

  /// The days read and whose pull requests count, for her reply's chart.
  final FrontPullRequestChart chart;

  /// Every pull request the turn may see that was opened or merged in the
  /// days, newest opened first.
  final List<FrontPullRequest> pullRequests;

  /// Pull requests her scope holds whose opening is not known yet — never
  /// refreshed since they were linked — so no day can count them.
  final int undated;

  DateTime get from => dayStart(chart.range.startDay);
  DateTime get through => dayStart(chart.range.endDayExclusive - 1);

  bool _inRange(DateTime? at) {
    if (at == null) return false;
    final day = epochDay(at.toLocal());
    return day >= chart.range.startDay && day < chart.range.endDayExclusive;
  }

  /// Those opened in the days, newest first.
  List<FrontPullRequest> get opened => [
    for (final pr in pullRequests)
      if (_inRange(pr.createdAt)) pr,
  ];

  /// Those merged in the days, whenever opened: what shipped.
  List<FrontPullRequest> get merged => [
    for (final pr in pullRequests)
      if (_inRange(pr.mergedAt)) pr,
  ];

  /// Whether her reply gets a chart: something was opened in the days.
  bool get hasChart => opened.isNotEmpty;

  /// The tool's answer: the days, the totals of what was opened and what
  /// was merged, then each pull request, newest opened first.
  String render() {
    final days = from == through
        ? _isoDay(from)
        : '${_isoDay(from)} through ${_isoDay(through)}';
    final what = period == null
        ? days
        : '${period!.wireName.replaceAll('_', ' ')} ($days)';
    final opened = this.opened;
    final merged = this.merged;
    final buffer = StringBuffer();
    if (opened.isEmpty && merged.isEmpty) {
      buffer.write('None: no pull request opened or merged $what.');
    } else {
      int sum(List<FrontPullRequest> prs, int Function(FrontPullRequest) f) =>
          prs.fold(0, (total, pr) => total + f(pr));
      buffer
        ..writeln('Pull requests $what:')
        ..writeln(
          '- opened: ${opened.length}, '
          '+${sum(opened, (pr) => pr.additions)} '
          '-${sum(opened, (pr) => pr.deletions)} lines',
        )
        ..writeln(
          '- merged: ${merged.length}, '
          '+${sum(merged, (pr) => pr.additions)} '
          '-${sum(merged, (pr) => pr.deletions)} lines',
        );
      final listed = pullRequests.take(frontPullRequestListLimit).toList();
      final more = pullRequests.length - listed.length;
      buffer.writeln(
        'Each, newest opened first'
        '${more > 0 ? ' (+$more not shown)' : ''}:',
      );
      for (final pr in listed) {
        buffer.write(
          '- ${pr.key} | ${_oneLine(pr.title)} | opened '
          '${pr.createdAt == null ? 'unknown' : _isoDay(pr.createdAt!.toLocal())}',
        );
        if (pr.mergedAt case final mergedAt?) {
          buffer.write(' | merged ${_isoDay(mergedAt.toLocal())}');
        }
        buffer.writeln(' | +${pr.additions} -${pr.deletions}');
      }
    }
    if (undated > 0) {
      buffer.write(
        '\n$undated linked pull request${undated == 1 ? ' was' : 's were'} '
        'never refreshed, so when ${undated == 1 ? 'it was' : 'they were'} '
        'opened is not known and ${undated == 1 ? 'it is' : 'they are'} '
        'not counted.',
      );
    }
    return buffer.toString().trimRight();
  }

  static String _oneLine(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _isoDay(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

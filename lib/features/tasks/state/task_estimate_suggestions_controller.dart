// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/date_utils_extension.dart';

/// How far back the ranking looks. Long enough that an occasional estimator
/// still has a history to rank, short enough that a changed way of working
/// pushes the old values out.
///
/// The window is measured against a task's own `date_from`, not against when
/// its estimate was set — so an estimate added today to a task dated last year
/// is outside it, and a task planned for next quarter is inside it. `date_from`
/// is the indexed column (`idx_journal_browse` covers deleted / type /
/// date_from); `updated_at` would express the intent more directly but has no
/// index, and this is a ranking rather than a ledger, so the approximation is
/// the deliberate trade.
const kEstimateSuggestionWindow = Duration(days: 90);

/// How many chips the estimate picker offers.
///
/// Four, not the measurement row's three: the estimate modal has a full-width
/// row to itself rather than sharing a compact signal card, and four covers
/// the usual "half an hour / an hour / an afternoon / a day's work" spread
/// without wrapping to a second line on a phone.
const kEstimateSuggestionCount = 4;

/// The ladder offered before a user has an estimating history of their own —
/// and used to top up a history too thin to fill the row.
///
/// A fresh install must not open a picker with no chips at all; these are the
/// values that make the feature explain itself on first use.
const kDefaultEstimateSuggestions = <Duration>[
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(hours: 2),
  Duration(hours: 4),
];

/// The estimate picker's quick-pick values. See
/// [TaskEstimateSuggestionsController].
final taskEstimateSuggestionsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      TaskEstimateSuggestionsController,
      List<Duration>
    >(TaskEstimateSuggestionsController.new);

/// Ranks the estimates this user actually sets and offers the top
/// [kEstimateSuggestionCount] as quick-pick chips.
///
/// The same idea as the measurement quick-add chips: the values on offer are
/// the ones already in the user's own history, so the row gets more useful the
/// more it is used. Two departures from that precedent, both deliberate:
///
/// * **A thin history is topped up** from [kDefaultEstimateSuggestions]. A
///   measurable with no history has nothing meaningful to guess; durations do
///   — everyone's first estimate is one of an hour or two.
/// * **Chips are displayed in ascending order**, not popularity order. The
///   selection is by popularity, but a duration row that reshuffles itself as
///   usage shifts is harder to aim at than a stable ladder.
///
/// The ranking is kept alive for `dashboardCacheDuration` so reopening the
/// picker is instant, which makes private visibility a live dependency rather
/// than a read-once one — see [build].
class TaskEstimateSuggestionsController extends AsyncNotifier<List<Duration>> {
  // Resolved on use, not in a field initializer: a test that overrides this
  // provider with a fixed row must be able to construct the notifier without
  // standing up a database.
  JournalDb get _journalDb => getIt<JournalDb>();

  @override
  Future<List<Duration>> build() async {
    ref.cacheFor(dashboardCacheDuration);

    // The keep-alive above makes private visibility a *live* dependency:
    // `getRankedTaskEstimates` resolves the flag itself, but a row already
    // cached would survive the flag being turned off and keep offering a
    // duration ranked from tasks that are now hidden. `watchConfigFlag`
    // replays the current value on subscribe, so the seed is skipped and only
    // an actual change re-derives the row.
    final flagSubscription = _journalDb
        .watchConfigFlag(privateFlag)
        .skip(1)
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(flagSubscription.cancel);

    final ranked = await _journalDb.getRankedTaskEstimates(
      since: clock.now().dayAtMidnight.subtract(kEstimateSuggestionWindow),
      limit: kEstimateSuggestionCount,
    );

    return toppedUpAndSorted(ranked);
  }

  /// Fills [ranked] up to [kEstimateSuggestionCount] from
  /// [kDefaultEstimateSuggestions] without repeating a value already ranked,
  /// then sorts the result shortest-first.
  ///
  /// Exposed for tests: it is the whole of the controller's logic that does
  /// not need a database.
  static List<Duration> toppedUpAndSorted(List<Duration> ranked) {
    final chosen = <Duration>{...ranked.take(kEstimateSuggestionCount)};
    for (final fallback in kDefaultEstimateSuggestions) {
      if (chosen.length >= kEstimateSuggestionCount) break;
      chosen.add(fallback);
    }
    return chosen.toList()..sort();
  }
}

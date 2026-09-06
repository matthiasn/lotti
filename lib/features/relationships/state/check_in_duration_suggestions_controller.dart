import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/date_utils_extension.dart';

/// How far back the duration picker looks for the lengths this user logs.
const kCheckInDurationWindow = Duration(days: 90);

/// How many quick picks the picker shows above the wheel.
const kCheckInDurationSuggestionCount = 6;

/// The design's wheel positions (2026-09-06 §5), shortest first: what a
/// user with no history is offered, and what tops a thin ranking up.
const kCheckInDurationPositions = <Duration>[
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 15),
  Duration(minutes: 20),
  Duration(minutes: 30),
  Duration(minutes: 45),
  Duration(hours: 1),
  Duration(hours: 1, minutes: 30),
  Duration(hours: 2),
  Duration(hours: 3),
];

/// Auto-disposed, with a five-minute keep-alive from the notifier: a
/// reopened picker is instant, and a check-in logged, edited or deleted
/// since is ranked into the next one instead of never — a kept-alive
/// provider would serve the first ranking for the container's whole life.
final AsyncNotifierProvider<
  CheckInDurationSuggestionsController,
  List<Duration>
>
checkInDurationSuggestionsControllerProvider =
    AsyncNotifierProvider.autoDispose(
      CheckInDurationSuggestionsController.new,
      name: 'checkInDurationSuggestionsControllerProvider',
    );

/// The check-in duration picker's quick picks: the lengths this user actually
/// logs, ranked by use over the last ninety days, topped up from the design's
/// positions and sorted shortest first — the task-estimate precedent, for
/// the same reason: a handful of one-tap answers over a wheel for the rest.
class CheckInDurationSuggestionsController
    extends AsyncNotifier<List<Duration>> {
  // Resolved on use, not in a field initializer: a test that overrides this
  // provider with a fixed row must be able to construct the notifier without
  // standing up a database.
  JournalDb get _journalDb => getIt<JournalDb>();

  @override
  Future<List<Duration>> build() async {
    ref.cacheFor(dashboardCacheDuration);
    // The keep-alive makes private visibility a live dependency: a cached
    // row would otherwise keep offering a length ranked from check-ins that
    // are now hidden. `watchConfigFlag` replays the current value on
    // subscribe, so the seed is skipped and only a change re-derives.
    final flagSubscription = _journalDb
        .watchConfigFlag(privateFlag)
        .skip(1)
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(flagSubscription.cancel);

    final ranked = await _journalDb.getRankedCheckInDurations(
      since: clock.now().dayAtMidnight.subtract(kCheckInDurationWindow),
      limit: kCheckInDurationSuggestionCount,
    );
    return toppedUpAndSorted(ranked);
  }

  /// Fills [ranked] up to [kCheckInDurationSuggestionCount] from
  /// [kCheckInDurationPositions] without repeating a value already ranked,
  /// then sorts shortest first. Exposed for tests: the whole of the logic
  /// that needs no database.
  static List<Duration> toppedUpAndSorted(List<Duration> ranked) {
    final chosen = <Duration>{...ranked.take(kCheckInDurationSuggestionCount)};
    for (final fallback in kCheckInDurationPositions) {
      if (chosen.length >= kCheckInDurationSuggestionCount) break;
      chosen.add(fallback);
    }
    return chosen.toList()..sort();
  }
}

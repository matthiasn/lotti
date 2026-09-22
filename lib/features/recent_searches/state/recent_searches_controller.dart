import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/recent_searches/domain/recent_search.dart';
import 'package:lotti/features/recent_searches/domain/recent_search_list.dart';
import 'package:lotti/features/recent_searches/state/recent_searches_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';

/// The Recents list, newest first: the searches run anywhere in the app that
/// the mobile sidebar offers to run again.
///
/// Kept alive for the session so a query typed on one tab is still pending —
/// and later still listed — after the user has moved to another.
final recentSearchesControllerProvider =
    NotifierProvider<RecentSearchesController, List<RecentSearch>>(
      RecentSearchesController.new,
    );

/// Records searches while the mobile sidebar navigation is switched on, and
/// remembers them across restarts.
///
/// **Everything follows the flag.** The list has exactly one reader, the
/// sidebar's Recents section, which exists only while
/// `enable_mobile_sidebar_navigation` is on — so with the flag off nothing is
/// timed, nothing is written and the settings store is not even read,
/// rather than a search history piling up for a surface the user never
/// sees. Every search field in the app calls into this controller, which
/// makes "off" meaning *no work at all* the property that keeps an
/// experiment from costing the users who never opted in. Whatever was
/// recorded earlier stays stored and returns with the flag; [clear] is how
/// a user removes it.
///
/// **A search is recorded once it rests.** Every search field in the app
/// filters as the user types, so [noteQuery] is called per keystroke and only
/// the text still standing after [settleWindow] is recorded. [record] skips
/// the wait for an explicit submit. What "one search" means once recorded —
/// repeats, continuations, the cap — is `recordRecentSearch`'s contract.
///
/// **A storage failure is reported, never thrown.** Every call arrives
/// unawaited from a search field, so a throw would surface as one uncaught
/// error per settled search. A failed read is not kept either: the next
/// caller reads again, and a search made while the stored list cannot be
/// read is dropped rather than written over a history that was never read.
class RecentSearchesController extends Notifier<List<RecentSearch>> {
  /// How long a query must stand unchanged before it counts as a search
  /// rather than a keystroke on the way to one.
  static const settleWindow = Duration(seconds: 2);

  final Map<RecentSearchSurface, Timer> _pending = {};

  /// Null until the flag's first value arrives: a query noted in that gap is
  /// still timed, and the decision is taken when its timer fires.
  bool? _enabled;

  /// The read of the stored list, started the first time the flag is known
  /// to be on and shared by everything that needs the list while it runs.
  /// Kept once it succeeds; dropped once it fails, so the next caller reads
  /// again instead of inheriting the failure.
  Future<bool>? _loaded;

  @override
  List<RecentSearch> build() {
    ref
      ..onDispose(_cancelPending)
      ..listen(
        configFlagProvider(enableMobileSidebarNavigationFlag),
        (_, next) {
          _enabled = switch (next) {
            AsyncData(:final value) => value,
            AsyncError() => false,
            _ => null,
          };
          if (_enabled == false) _cancelPending();
          if (_enabled ?? false) unawaited(_ensureLoaded());
        },
        fireImmediately: true,
      );
    return const [];
  }

  /// Whether the stored list is in [state], reading it if no read has
  /// succeeded yet.
  Future<bool> _ensureLoaded() async {
    final loading = _loaded ??= _load();
    final loaded = await loading;
    if (!loaded && identical(_loaded, loading)) _loaded = null;
    return loaded;
  }

  Future<bool> _load() async {
    try {
      final stored = await ref.read(recentSearchesRepositoryProvider).load();
      if (ref.mounted) state = stored;
      return true;
    } catch (error, stackTrace) {
      _report(error, stackTrace, subDomain: 'load');
      return false;
    }
  }

  /// The write most recently queued by [_save]; completes, never throws.
  Future<void> _lastSave = Future<void>.value();

  /// Writes [searches] as the stored list. A failed write keeps the list as
  /// recorded here, and the next write carries it.
  ///
  /// Writes are applied one at a time, in the order they were asked for.
  /// Overlapping writes are not safe to leave to the store: `SettingsDb`
  /// returns at once, without writing, when its cache already holds the
  /// value — so a Clear issued while a record's write is still in flight,
  /// against a cache still holding the empty list, would return before that
  /// write lands, and the search the user just cleared would be stored after
  /// all.
  Future<void> _save(List<RecentSearch> searches) {
    // Read now, while the notifier is certainly alive; the write itself may
    // run after it is gone.
    final repository = ref.read(recentSearchesRepositoryProvider);
    final previous = _lastSave;
    return _lastSave = () async {
      await previous;
      try {
        await repository.save(searches);
      } catch (error, stackTrace) {
        _report(error, stackTrace, subDomain: 'save');
      }
    }();
  }

  void _report(
    Object error,
    StackTrace stackTrace, {
    required String subDomain,
  }) {
    // A notifier already gone has nobody to report to; its caller's work
    // ended with it.
    if (!ref.mounted) return;
    ref
        .read(loggingServiceProvider)
        .captureException(
          error,
          domain: 'RecentSearchesController',
          subDomain: subDomain,
          stackTrace: stackTrace,
        );
  }

  /// Notes that [surface]'s search field now reads [query].
  ///
  /// Restarts that surface's settle timer; an unrecordable [query] — the
  /// field was cleared, or holds a single character — only cancels it, so a
  /// search abandoned inside the window is never recorded. Surfaces time
  /// independently: typing in one field does not reset another's.
  void noteQuery(RecentSearchSurface surface, String query) {
    _pending.remove(surface)?.cancel();
    if (_enabled == false || !isRecordableRecentSearchQuery(query)) return;
    _pending[surface] = Timer(settleWindow, () {
      _pending.remove(surface);
      unawaited(record(surface, query));
    });
  }

  /// Records [query] on [surface] now — the submit path, and what a settled
  /// [noteQuery] ends in. Supersedes anything still pending on [surface].
  ///
  /// A submit can be the very first thing this controller hears, before the
  /// flag has reported at all; it then waits for that first value instead of
  /// being dropped. The listener in [build] is what keeps the auto-disposing
  /// flag provider alive for that read.
  ///
  /// The flag is asked again once the stored list has loaded: that read can
  /// take long enough for the user to switch the sidebar off meanwhile, and a
  /// search must never be remembered after they have opted out.
  Future<void> record(RecentSearchSurface surface, String query) async {
    _pending.remove(surface)?.cancel();
    final enabled = _enabled ?? await _firstFlagValue();
    if (!enabled || !ref.mounted) return;
    if (!await _ensureLoaded() || !ref.mounted || _enabled != true) return;
    final next = recordRecentSearch(state, surface, query);
    if (identical(next, state)) return;
    state = next;
    await _save(next);
  }

  /// The flag's first value, for a submit that beats the listener in
  /// [build] to it. A failing read is off, as it is for the listener.
  Future<bool> _firstFlagValue() async {
    try {
      return await ref.read(
        configFlagProvider(enableMobileSidebarNavigationFlag).future,
      );
    } catch (_) {
      return false;
    }
  }

  /// Forgets every recorded search, and anything still settling.
  Future<void> clear() async {
    _cancelPending();
    // Awaited so a read still in flight cannot land after the clear and
    // bring the list back. A failed read leaves nothing to bring back, so
    // the clear goes ahead either way.
    await _ensureLoaded();
    if (!ref.mounted) return;
    state = const [];
    await _save(const []);
  }

  void _cancelPending() {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
  }
}

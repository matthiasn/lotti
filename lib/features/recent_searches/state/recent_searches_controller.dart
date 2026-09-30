import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/recent_searches/domain/recent_search.dart';
import 'package:lotti/features/recent_searches/domain/recent_search_list.dart';
import 'package:lotti/features/recent_searches/state/recent_searches_repository.dart';
import 'package:lotti/providers/service_providers.dart';

/// The Recents list, newest first: the searches run anywhere in the app that
/// the mobile sidebar offers to run again.
///
/// Kept alive for the session so a query typed on one tab is still pending —
/// and later still listed — after the user has moved to another.
final recentSearchesControllerProvider =
    NotifierProvider<RecentSearchesController, List<RecentSearch>>(
      RecentSearchesController.new,
    );

/// Records searches, and remembers them across restarts. The stored list is
/// read as soon as the controller is built, so the sidebar's Recents section
/// has it by the time the drawer first opens; [clear] is how a user removes
/// it.
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

  /// The read of the stored list, started when the controller is built and
  /// shared by everything that needs the list while it runs. Kept once it
  /// succeeds; dropped once it fails, so the next caller reads again instead
  /// of inheriting the failure.
  Future<bool>? _loaded;

  @override
  List<RecentSearch> build() {
    ref.onDispose(_cancelPending);
    unawaited(_ensureLoaded());
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
    if (!isRecordableRecentSearchQuery(query)) return;
    _pending[surface] = Timer(settleWindow, () {
      _pending.remove(surface);
      unawaited(record(surface, query));
    });
  }

  /// Records [query] on [surface] now — the submit path, and what a settled
  /// [noteQuery] ends in. Supersedes anything still pending on [surface].
  Future<void> record(RecentSearchSurface surface, String query) async {
    _pending.remove(surface)?.cancel();
    if (!await _ensureLoaded() || !ref.mounted) return;
    final next = recordRecentSearch(state, surface, query);
    if (identical(next, state)) return;
    state = next;
    await _save(next);
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

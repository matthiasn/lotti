import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/recent_searches/domain/recent_search.dart';
import 'package:lotti/features/recent_searches/state/recent_searches_controller.dart';

/// Riverpod stand-in for [RecentSearchesController]: serves a fixed list and
/// records what the UI asks of it, without a settings store, a config flag
/// or a timer. For widget tests of the surfaces that *show* or *feed*
/// Recents; the real controller has its own test file.
class FakeRecentSearchesController extends RecentSearchesController {
  FakeRecentSearchesController([this._initial = const []]);

  final List<RecentSearch> _initial;

  /// Every `noteQuery` call, in order, as `(surface, query)`.
  final List<(RecentSearchSurface, String)> noted = [];

  /// Every `record` call, in order, as `(surface, query)`.
  final List<(RecentSearchSurface, String)> recorded = [];

  int clearCalls = 0;

  @override
  List<RecentSearch> build() => _initial;

  @override
  void noteQuery(RecentSearchSurface surface, String query) =>
      noted.add((surface, query));

  @override
  Future<void> record(RecentSearchSurface surface, String query) async =>
      recorded.add((surface, query));

  @override
  Future<void> clear() async {
    clearCalls++;
    state = const [];
  }
}

/// Overrides [recentSearchesControllerProvider] with [controller].
Override fakeRecentSearches(FakeRecentSearchesController controller) =>
    recentSearchesControllerProvider.overrideWith(() => controller);

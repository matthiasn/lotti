import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/history/domain/history_entry.dart';
import 'package:lotti/features/history/domain/history_filter.dart';
import 'package:lotti/features/history/state/history_providers.dart';
import 'package:lotti/features/history/state/history_service.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/logging_domains.dart';

/// What the history page shows.
@immutable
class HistoryViewState {
  const HistoryViewState({
    this.filter = const HistoryFilter(),
    this.items = const [],
    this.hasMore = false,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasError = false,
  });

  final HistoryFilter filter;
  final List<ResolvedHistoryEntry> items;
  final bool hasMore;

  /// True while the first page for the current [filter] is being read. The
  /// previous [items] stay listed meanwhile, so narrowing a search never
  /// blanks the list between keystrokes.
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasError;

  HistoryViewState copyWith({
    HistoryFilter? filter,
    List<ResolvedHistoryEntry>? items,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasError,
  }) => HistoryViewState(
    filter: filter ?? this.filter,
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasError: hasError ?? this.hasError,
  );
}

/// Scoped to the open history page: disposed when it closes, so the next
/// opening starts from the newest visit with an empty search.
final NotifierProvider<HistoryController, HistoryViewState>
historyControllerProvider =
    NotifierProvider.autoDispose<HistoryController, HistoryViewState>(
      HistoryController.new,
      name: 'historyControllerProvider',
    );

/// Pages through history for the current filter.
///
/// Every filter change starts a new read; an answer for a filter that has
/// since changed is dropped, so a slow read for "bu" can never overwrite the
/// list for "bug".
class HistoryController extends Notifier<HistoryViewState> {
  int _generation = 0;
  int? _nextBeforeId;

  HistoryService get _service => ref.read(historyServiceProvider);

  @override
  HistoryViewState build() {
    // Not awaited: build returns the loading state at once, and _reload
    // reports its own failures into the state it publishes.
    _reload(const HistoryFilter(), fromBuild: true);
    return const HistoryViewState();
  }

  Future<void> setQuery(String query) {
    if (query == state.filter.query) return Future<void>.value();
    return _reload(state.filter.copyWith(query: query));
  }

  /// Switches to a preset window. [HistoryTimeRange.custom] goes through
  /// [setCustomRange], which carries its dates.
  Future<void> setRange(HistoryTimeRange range) {
    assert(range != HistoryTimeRange.custom, 'use setCustomRange');
    if (range == state.filter.range) return Future<void>.value();
    return _reload(
      HistoryFilter(query: state.filter.query, range: range),
    );
  }

  /// Shows visits from [start] through [end], both days included. The dates
  /// are put in order, so a range picked backwards still means the days
  /// between them.
  Future<void> setCustomRange(DateTime start, DateTime end) {
    final (first, last) = start.isAfter(end) ? (end, start) : (start, end);
    return _reload(
      HistoryFilter(
        query: state.filter.query,
        range: HistoryTimeRange.custom,
        customStart: first,
        customEnd: last,
      ),
    );
  }

  /// Appends the next page. A no-op while one is loading or none is left.
  Future<void> loadMore() async {
    final beforeId = _nextBeforeId;
    if (beforeId == null || state.isLoading || state.isLoadingMore) return;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _service.page(state.filter, beforeId: beforeId);
      if (!_isCurrent(generation)) return;
      _nextBeforeId = page.nextBeforeId;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } catch (error, stackTrace) {
      _report(error, stackTrace, 'loadMore');
      // Paging stops for this filter: the list asks for the next page from
      // its builder, so leaving one on offer would retry every frame.
      if (_isCurrent(generation)) {
        _nextBeforeId = null;
        state = state.copyWith(
          isLoadingMore: false,
          hasMore: false,
          hasError: true,
        );
      }
    }
  }

  /// Deletes [entry] for good and drops it from the list.
  Future<void> delete(HistoryEntry entry) async {
    await _service.delete(entry.id);
    if (!ref.mounted) return;
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.entry.id != entry.id) item,
      ],
    );
  }

  /// Reads the first page for [filter]. From [build], the loading state is
  /// the one build returns, and [state] may not be written before it has.
  Future<void> _reload(HistoryFilter filter, {bool fromBuild = false}) async {
    final generation = ++_generation;
    _nextBeforeId = null;
    if (!fromBuild) {
      state = state.copyWith(
        filter: filter,
        isLoading: true,
        isLoadingMore: false,
        hasError: false,
      );
    }
    try {
      final page = await _service.page(filter);
      if (!_isCurrent(generation)) return;
      _nextBeforeId = page.nextBeforeId;
      state = state.copyWith(
        items: page.items,
        hasMore: page.hasMore,
        isLoading: false,
      );
    } catch (error, stackTrace) {
      _report(error, stackTrace, 'load');
      // The rows already shown stay: a failed reload never takes content
      // off the screen. With no cursor for this filter there is no next page.
      if (_isCurrent(generation)) {
        state = state.copyWith(
          hasMore: false,
          isLoading: false,
          hasError: true,
        );
      }
    }
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  void _report(Object error, StackTrace stackTrace, String subDomain) {
    ref
        .read(domainLoggerProvider)
        .error(
          LogDomain.navigation,
          error,
          stackTrace: stackTrace,
          subDomain: 'history.$subDomain',
        );
  }
}

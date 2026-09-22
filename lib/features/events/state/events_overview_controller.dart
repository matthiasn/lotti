import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/events/state/events_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

/// Paged, filterable state for the Events overview: the events loaded so far
/// (newest first), whether more pages remain, the in-flight flag for the next
/// page, and the active search query and category filter.
///
/// The overview appends pages as the user scrolls rather than loading the whole
/// archive up front, so an account with hundreds of events doesn't query — or
/// resolve a cover for — every event on open.
@immutable
class EventsOverviewState {
  const EventsOverviewState({
    required this.events,
    required this.hasMore,
    this.isLoadingMore = false,
    this.categoryIds = const {},
    this.query = '',
  });

  final List<ResolvedEvent> events;
  final bool hasMore;
  final bool isLoadingMore;

  /// Selected categories (empty = all; `''` = events without a category).
  /// Applied at load time so filtering is correct across the whole archive,
  /// not just the pages already loaded.
  final Set<String> categoryIds;

  /// The search text as typed. Matching trims it; keeping it verbatim lets the
  /// search field round-trip exactly what the user entered.
  final String query;

  /// Whether a query or a category narrows the list below the full archive.
  bool get isFiltered => categoryIds.isNotEmpty || query.trim().isNotEmpty;

  EventsOverviewState copyWith({
    List<ResolvedEvent>? events,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return EventsOverviewState(
      events: events ?? this.events,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      categoryIds: categoryIds,
      query: query,
    );
  }
}

final eventsOverviewControllerProvider =
    AsyncNotifierProvider<EventsOverviewController, EventsOverviewState>(
      EventsOverviewController.new,
    );

class EventsOverviewController extends AsyncNotifier<EventsOverviewState> {
  /// Bumped whenever a reload supersedes in-flight work (a query or category
  /// change, or a sync refresh), so a late page — from `loadMore` or from an
  /// earlier keystroke — can't overwrite the newer state with a stale list.
  int _generation = 0;

  @override
  Future<EventsOverviewState> build() async {
    final sub = getIt<UpdateNotifications>().updateStream.listen((affected) {
      final loadedEventIds = state.value?.events
          .map((resolved) => resolved.event.meta.id)
          .toSet();
      final affectsLoadedEventLink =
          affected.contains(linkNotification) &&
          loadedEventIds != null &&
          affected.any(loadedEventIds.contains);
      if (affected.contains(eventNotification) || affectsLoadedEventLink) {
        unawaited(_refresh());
      }
    });
    ref.onDispose(sub.cancel);
    return _loadFirstPage(categoryIds: const {}, query: '');
  }

  Future<EventsOverviewState> _loadFirstPage({
    required Set<String> categoryIds,
    required String query,
  }) async {
    final page = await loadResolvedEventsPage(
      limit: eventsPageSize,
      offset: 0,
      categoryIds: categoryIds,
      query: query,
    );
    return EventsOverviewState(
      events: page,
      hasMore: page.length == eventsPageSize,
      categoryIds: categoryIds,
      query: query,
    );
  }

  /// Appends the next page. A no-op while a fetch is in flight or no more pages
  /// remain, so the scroll-triggered caller can fire it freely.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    final generation = _generation;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await loadResolvedEventsPage(
        limit: eventsPageSize,
        offset: current.events.length,
        categoryIds: current.categoryIds,
        query: current.query,
      );
      // Drop a page that arrived after a filter change / refresh, or after the
      // notifier was disposed — it would otherwise clobber newer state.
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        current.copyWith(
          events: [...current.events, ...next],
          hasMore: next.length == eventsPageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      // Always clear the in-flight flag so a failed page doesn't deadlock
      // pagination; keep the events already shown.
      if (ref.mounted && generation == _generation) {
        state = AsyncData(current.copyWith(isLoadingMore: false));
      }
    }
  }

  /// Replaces the search query and reloads from the first page. Called on
  /// every keystroke, like the Tasks search; the generation guard drops the
  /// result of any keystroke a later one has already superseded.
  Future<void> setQuery(String query) => _applyFilters(query: query);

  /// Replaces the selected categories and reloads from the first page.
  Future<void> setCategoryIds(Set<String> categoryIds) =>
      _applyFilters(categoryIds: categoryIds);

  /// Drops the query and every category, restoring the full archive.
  Future<void> clearFilters() =>
      _applyFilters(query: '', categoryIds: const {});

  /// Reloads the first page for the merged filter. The previous data stays on
  /// screen during the (fast, local) reload, so there is no full-screen
  /// spinner flash while typing.
  Future<void> _applyFilters({String? query, Set<String>? categoryIds}) async {
    final current = state.value;
    final nextQuery = query ?? current?.query ?? '';
    final nextCategories = categoryIds ?? current?.categoryIds ?? const {};
    if (current != null &&
        current.query == nextQuery &&
        setEquals(current.categoryIds, nextCategories)) {
      return;
    }
    final generation = ++_generation;
    final next = await AsyncValue.guard(
      () => _loadFirstPage(categoryIds: nextCategories, query: nextQuery),
    );
    if (!ref.mounted || generation != _generation) return;
    state = next;
  }

  /// Re-fetches the currently-loaded window after a sync/db change, so new or
  /// edited events show up without losing the user's scroll depth.
  Future<void> _refresh() async {
    final current = state.value;
    if (current == null) return;
    final generation = ++_generation;
    final count = current.events.length < eventsPageSize
        ? eventsPageSize
        : current.events.length;
    try {
      final reloaded = await loadResolvedEventsPage(
        limit: count,
        offset: 0,
        categoryIds: current.categoryIds,
        query: current.query,
      );
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        EventsOverviewState(
          events: reloaded,
          hasMore: reloaded.length == count,
          categoryIds: current.categoryIds,
          query: current.query,
        ),
      );
    } catch (_) {
      // A background refresh failure keeps the current list rather than
      // flashing an error over established content.
    }
  }
}

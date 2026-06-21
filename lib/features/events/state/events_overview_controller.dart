import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/events/state/events_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

/// Paged, filterable state for the Events overview: the events loaded so far
/// (newest first), whether more pages remain, the in-flight flag for the next
/// page, and the active category filter.
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
    this.categoryId,
  });

  final List<ResolvedEvent> events;
  final bool hasMore;
  final bool isLoadingMore;

  /// Active category filter (null = all). Applied server-side so filtering is
  /// correct across the whole archive, not just the pages already loaded.
  final String? categoryId;

  EventsOverviewState copyWith({
    List<ResolvedEvent>? events,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return EventsOverviewState(
      events: events ?? this.events,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      categoryId: categoryId,
    );
  }
}

final eventsOverviewControllerProvider =
    AsyncNotifierProvider<EventsOverviewController, EventsOverviewState>(
      EventsOverviewController.new,
    );

class EventsOverviewController extends AsyncNotifier<EventsOverviewState> {
  /// Bumped whenever a reload supersedes in-flight work (a category switch or a
  /// sync refresh), so a late `loadMore` page-append can't overwrite the newer
  /// state with a stale list.
  int _generation = 0;

  @override
  Future<EventsOverviewState> build() async {
    final sub = getIt<UpdateNotifications>().updateStream.listen((affected) {
      if (affected.contains(eventNotification)) {
        unawaited(_refresh());
      }
    });
    ref.onDispose(sub.cancel);
    return _loadFirstPage(null);
  }

  Future<EventsOverviewState> _loadFirstPage(String? categoryId) async {
    final page = await loadResolvedEventsPage(
      limit: eventsPageSize,
      offset: 0,
      categoryId: categoryId,
    );
    return EventsOverviewState(
      events: page,
      hasMore: page.length == eventsPageSize,
      categoryId: categoryId,
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
        categoryId: current.categoryId,
      );
      // Drop a page that arrived after a category switch / refresh, or after the
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

  /// Switches the category filter and reloads from the first page. The previous
  /// data stays on screen during the (fast, local) reload, so there's no
  /// full-screen spinner flash.
  Future<void> setCategory(String? categoryId) async {
    if (state.value?.categoryId == categoryId) return;
    _generation++;
    state = await AsyncValue.guard(() => _loadFirstPage(categoryId));
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
        categoryId: current.categoryId,
      );
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        EventsOverviewState(
          events: reloaded,
          hasMore: reloaded.length == count,
          categoryId: current.categoryId,
        ),
      );
    } catch (_) {
      // A background refresh failure keeps the current list rather than
      // flashing an error over established content.
    }
  }
}

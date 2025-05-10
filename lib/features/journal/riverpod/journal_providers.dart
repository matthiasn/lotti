import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/journal/data/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// Provider for JournalRepository
final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository(
    db: getIt<JournalDb>(),
    fts5Db: getIt<Fts5Db>(),
    updateNotifications: getIt<UpdateNotifications>(),
    entitiesCacheService: getIt<EntitiesCacheService>(),
  );
});

/// Class to hold journal filter settings
class JournalFilters {
  final bool showTasks;
  final bool showPrivateEntries;
  final Set<String> selectedEntryTypes;
  final Set<DisplayFilter> filters;
  final String searchQuery;
  final Set<String> selectedTaskStatuses;
  final Set<String> selectedCategoryIds;
  final bool taskAsListView;

  const JournalFilters({
    this.showTasks = false,
    this.showPrivateEntries = false,
    this.selectedEntryTypes = const {},
    this.filters = const {},
    this.searchQuery = '',
    this.selectedTaskStatuses = const {'OPEN', 'GROOMED', 'IN PROGRESS'},
    this.selectedCategoryIds = const {},
    this.taskAsListView = true,
  });

  JournalFilters copyWith({
    bool? showTasks,
    bool? showPrivateEntries,
    Set<String>? selectedEntryTypes,
    Set<DisplayFilter>? filters,
    String? searchQuery,
    Set<String>? selectedTaskStatuses,
    Set<String>? selectedCategoryIds,
    bool? taskAsListView,
  }) {
    return JournalFilters(
      showTasks: showTasks ?? this.showTasks,
      showPrivateEntries: showPrivateEntries ?? this.showPrivateEntries,
      selectedEntryTypes: selectedEntryTypes ?? this.selectedEntryTypes,
      filters: filters ?? this.filters,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTaskStatuses: selectedTaskStatuses ?? this.selectedTaskStatuses,
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      taskAsListView: taskAsListView ?? this.taskAsListView,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JournalFilters) return false;
    return showTasks == other.showTasks &&
        showPrivateEntries == other.showPrivateEntries &&
        setEquals(selectedEntryTypes, other.selectedEntryTypes) &&
        setEquals(filters, other.filters) &&
        searchQuery == other.searchQuery &&
        setEquals(selectedTaskStatuses, other.selectedTaskStatuses) &&
        setEquals(selectedCategoryIds, other.selectedCategoryIds) &&
        taskAsListView == other.taskAsListView;
  }

  @override
  int get hashCode =>
      showTasks.hashCode ^
      showPrivateEntries.hashCode ^
      selectedEntryTypes.hashCode ^
      filters.hashCode ^
      searchQuery.hashCode ^
      selectedTaskStatuses.hashCode ^
      selectedCategoryIds.hashCode ^
      taskAsListView.hashCode;
}

// Helper function to check if sets are equal
bool setEquals<T>(Set<T>? a, Set<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  return a.containsAll(b);
}

/// Provider for journal filters state
final journalFiltersProvider = StateProvider<JournalFilters>((ref) {
  return JournalFilters(
    selectedEntryTypes: entryTypes.toSet(),
  );
});

/// Command pattern for journal operations
sealed class JournalCommand {
  const JournalCommand();
}

/// Refresh command
class RefreshCommand extends JournalCommand {
  final bool isTaskView;
  const RefreshCommand({required this.isTaskView});
}

/// Load more command
class LoadMoreCommand extends JournalCommand {
  final bool isTaskView;
  const LoadMoreCommand({required this.isTaskView});
}

/// Provider for sending commands to the journal
final journalCommandProvider = Provider<void Function(JournalCommand)>((ref) {
  return (command) {
    // Get the appropriate data controller based on command type
    final dataController = switch (command) {
      RefreshCommand(isTaskView: var isTaskView) =>
        ref.read(_journalDataControllerProvider(isTaskView)),
      LoadMoreCommand(isTaskView: var isTaskView) =>
        ref.read(_journalDataControllerProvider(isTaskView)),
    };

    // Execute command
    switch (command) {
      case RefreshCommand():
        dataController.refresh();
      case LoadMoreCommand():
        dataController.loadMore();
    }
  };
});

/// State class for journal entries
class JournalEntriesState {
  final List<JournalEntity> items;
  final bool hasMore;
  final bool isLoading;
  final Object? error;

  const JournalEntriesState({
    this.items = const [],
    this.hasMore = true,
    this.isLoading = false,
    this.error,
  });

  JournalEntriesState copyWith({
    List<JournalEntity>? items,
    bool? hasMore,
    bool? isLoading,
    Object? error,
  }) {
    return JournalEntriesState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      error: error != _keepError ? error : this.error,
    );
  }

  JournalEntriesState setError(Object error) {
    return JournalEntriesState(
      items: items,
      hasMore: hasMore,
      isLoading: false,
      error: error,
    );
  }

  JournalEntriesState clearError() {
    return JournalEntriesState(
      items: items,
      hasMore: hasMore,
      isLoading: isLoading,
      error: null,
    );
  }
}

// Used to indicate we want to keep the current error
final _keepError = Object();

/// Internal controller for journal data
class JournalDataController {
  final bool isTaskView;
  final JournalRepository repository;
  final Ref ref;
  final void Function(JournalEntriesState state) updateState;

  bool _isLoading = false;
  bool _disposed = false;

  JournalDataController({
    required this.isTaskView,
    required this.repository,
    required this.ref,
    required this.updateState,
  }) {
    // Initialize with empty state
    updateState(const JournalEntriesState());
  }

  JournalFilters get _filters => ref.read(journalFiltersProvider);
  JournalEntriesState get _currentState =>
      ref.read(_journalDataStateProvider(isTaskView));

  void refresh() async {
    if (_isLoading || _disposed) return;

    _isLoading = true;

    // Update state to reflect loading
    updateState(_currentState.copyWith(isLoading: true));

    try {
      final items = await _fetchItems(0);

      if (_disposed) return;

      final hasMore = items.length >= JournalRepository.pageSize;

      updateState(JournalEntriesState(
        items: items,
        hasMore: hasMore,
        isLoading: false,
      ));
    } catch (e) {
      if (_disposed) return;

      updateState(_currentState.setError(e));
    } finally {
      _isLoading = false;
    }
  }

  void loadMore() async {
    if (_isLoading || _disposed || !_currentState.hasMore) return;

    _isLoading = true;

    // Update state to reflect loading
    updateState(_currentState.copyWith(isLoading: true));

    try {
      final offset = _currentState.items.length;

      debugPrint('Loading more items from offset $offset');
      final moreItems = await _fetchItems(offset);

      if (_disposed) return;

      debugPrint('Loaded ${moreItems.length} more items');

      if (moreItems.isEmpty) {
        updateState(_currentState.copyWith(
          hasMore: false,
          isLoading: false,
        ));
        return;
      }

      final allItems = [..._currentState.items, ...moreItems];
      final hasMore = moreItems.length >= JournalRepository.pageSize;

      updateState(_currentState.copyWith(
        items: allItems,
        hasMore: hasMore,
        isLoading: false,
      ));
    } catch (e) {
      if (_disposed) return;

      debugPrint('Error loading more items: $e');
      updateState(_currentState.copyWith(
        isLoading: false,
        error: e,
      ));
    } finally {
      _isLoading = false;
    }
  }

  Future<List<JournalEntity>> _fetchItems(int offset) async {
    final filters = _filters;

    final fullTextMatches =
        await repository.fullTextSearch(filters.searchQuery);
    final ids =
        filters.searchQuery.isNotEmpty ? fullTextMatches.toList() : null;

    final starredEntriesOnly =
        filters.filters.contains(DisplayFilter.starredEntriesOnly);
    final privateEntriesOnly =
        filters.filters.contains(DisplayFilter.privateEntriesOnly);
    final flaggedEntriesOnly =
        filters.filters.contains(DisplayFilter.flaggedEntriesOnly);

    if (isTaskView) {
      final allCategoryIds = repository.getAllCategoryIds();
      final categoryIds = filters.selectedCategoryIds.isEmpty
          ? allCategoryIds.toList()
          : filters.selectedCategoryIds.toList();

      return repository.getTasks(
        ids: ids,
        starredStatuses: starredEntriesOnly ? [true] : [true, false],
        taskStatuses: filters.selectedTaskStatuses.toList(),
        categoryIds: categoryIds,
        offset: offset,
      );
    } else {
      return repository.getJournalEntities(
        types: filters.selectedEntryTypes.toList(),
        ids: ids,
        starredStatuses: starredEntriesOnly ? [true] : [true, false],
        privateStatuses: privateEntriesOnly ? [true] : [true, false],
        flaggedStatuses: flaggedEntriesOnly ? [1] : [1, 0],
        categoryIds: filters.selectedCategoryIds.isEmpty
            ? null
            : filters.selectedCategoryIds.toList(),
        offset: offset,
      );
    }
  }

  void dispose() {
    _disposed = true;
  }
}

/// Provider for journal data state - separated from the controller to avoid recreation
final _journalDataStateProvider =
    StateProvider.family<JournalEntriesState, bool>((ref, _) {
  // This provider is kept alive forever to ensure state persistence
  ref.keepAlive();
  return const JournalEntriesState();
});

/// Provider for data controllers - created once per isTaskView value and cached
final _journalDataControllerProvider =
    Provider.family<JournalDataController, bool>((ref, isTaskView) {
  final repository = ref.watch(journalRepositoryProvider);

  debugPrint(
      'Creating stable JournalDataController for isTaskView=$isTaskView');

  final controller = JournalDataController(
    isTaskView: isTaskView,
    repository: repository,
    ref: ref,
    updateState: (state) {
      // Update state via the state provider
      ref.read(_journalDataStateProvider(isTaskView).notifier).state = state;
    },
  );

  // Keep this provider alive forever
  ref.keepAlive();

  // Clean up on disposal
  ref.onDispose(() {
    debugPrint('Disposing controller for isTaskView=$isTaskView');
    controller.dispose();
  });

  return controller;
});

/// Public provider for accessing journal data - read-only access to the state
final journalDataProvider =
    Provider.family<JournalEntriesState, bool>((ref, isTaskView) {
  // This will create the controller if it doesn't exist yet
  ref.watch(_journalDataControllerProvider(isTaskView));

  // Return the current state
  return ref.watch(_journalDataStateProvider(isTaskView));
});

/// Provider for watching update notifications
final journalUpdateStreamProvider = StreamProvider<Set<String>>((ref) {
  final repository = ref.watch(journalRepositoryProvider);
  return repository.updateStream;
});

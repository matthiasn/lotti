import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/riverpod/journal_providers.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_wrapper_widget.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/pages/settings/definitions_list_page.dart'; // For FloatingAddIcon
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A version of the Journal Page that uses Riverpod for state management
class RiverpodJournalPage extends ConsumerWidget {
  const RiverpodJournalPage({
    required this.showTasks,
    super.key,
    this.navigatorKey,
  });

  final GlobalKey? navigatorKey;
  final bool showTasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize the filters for this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentFilters = ref.read(journalFiltersProvider);
      if (currentFilters.showTasks != showTasks) {
        // Only update if necessary
        ref.read(journalFiltersProvider.notifier).update(
              (state) => state.copyWith(showTasks: showTasks),
            );
      }
    });

    return Scaffold(
      floatingActionButton: _buildFloatingActionButton(context, ref),
      body: RiverpodJournalPageBody(
        showTasks: showTasks,
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(journalFiltersProvider);
    final selectedCategoryIds = filters.selectedCategoryIds;
    final categoryId =
        selectedCategoryIds.length == 1 ? selectedCategoryIds.first : null;

    return showTasks
        ? FloatingAddIcon(
            createFn: () async {
              final task = await createTask(categoryId: categoryId);
              if (task != null) {
                getIt<NavService>().beamToNamed('/tasks/${task.meta.id}');
              }
            },
            semanticLabel: context.messages.addActionAddTask,
          )
        : FloatingAddActionButton(categoryId: categoryId);
  }
}

class RiverpodJournalPageBody extends ConsumerStatefulWidget {
  const RiverpodJournalPageBody({
    required this.showTasks,
    super.key,
  });

  final bool showTasks;

  @override
  ConsumerState<RiverpodJournalPageBody> createState() =>
      _RiverpodJournalPageBodyState();
}

class _RiverpodJournalPageBodyState
    extends ConsumerState<RiverpodJournalPageBody>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  bool _isVisible = false;
  final _visibilityKey = UniqueKey();
  bool _isDisposed = false;
  bool _initialLoadDone = false;

  // Keep this page alive when switching tabs
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController.addListener(listener);

    // Don't auto-load; wait for visibility
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _updateVisibility(VisibilityInfo visibilityInfo) {
    if (_isDisposed) return;

    final isVisible = visibilityInfo.visibleBounds.size.width > 0;
    if (!_isVisible && isVisible) {
      // Coming into view - trigger initial load if needed
      if (!_initialLoadDone) {
        _initialLoadDone = true;
        _refreshData();
      }
    }

    if (mounted) {
      setState(() {
        _isVisible = isVisible;
      });
    }
  }

  void _refreshData() {
    if (_isDisposed || !mounted) return;

    // Send refresh command
    ref.read(journalCommandProvider)(
      RefreshCommand(isTaskView: widget.showTasks),
    );
  }

  void _loadMoreData() {
    if (_isDisposed || !mounted) return;

    // Send load more command
    ref.read(journalCommandProvider)(
      LoadMoreCommand(isTaskView: widget.showTasks),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Watch journal data - this won't recreate the controller
    final journalState = ref.watch(journalDataProvider(widget.showTasks));
    final filters = ref.watch(journalFiltersProvider);

    // Listen to update stream for database changes
    ref.listen<AsyncValue<Set<String>>>(
      journalUpdateStreamProvider,
      (_, next) {
        if (_isDisposed || !mounted || !_isVisible) return;

        if (next is AsyncData<Set<String>> && next.value.isNotEmpty) {
          // Only refresh if we're visible and there are actual changes
          _refreshData();
        }
      },
    );

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _updateVisibility,
      child: RefreshIndicator(
        onRefresh: () {
          if (!_isDisposed && mounted) {
            _refreshData();
          }
          return Future<void>.value();
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            const RiverpodJournalSliverAppBar(),
            _buildContent(journalState, filters),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(JournalEntriesState state, JournalFilters filters) {
    // Show error state if needed
    if (state.error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Error loading data'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Initial loading state with no data yet
    if (state.items.isEmpty && state.isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Empty state with no data and not loading
    if (state.items.isEmpty && !state.isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('No entries found'),
        ),
      );
    }

    // Normal state with data
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // If near the end and has more data, load more
          if (index >= state.items.length - 10 &&
              state.hasMore &&
              !state.isLoading) {
            debugPrint(
                'Triggering load more at index $index of ${state.items.length}');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadMoreData();
            });
          }

          // Regular item
          if (index < state.items.length) {
            return CardWrapperWidget(
              item: state.items[index],
              taskAsListView: filters.taskAsListView,
              key: ValueKey(state.items[index].meta.id),
            );
          }

          // Loading indicator at the bottom
          if (state.hasMore && state.isLoading && index == state.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return null;
        },
        childCount: state.items.isEmpty
            ? 0
            : (state.hasMore && state.isLoading)
                ? state.items.length + 1
                : state.items.length,
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.dispose();
    super.dispose();
  }
}

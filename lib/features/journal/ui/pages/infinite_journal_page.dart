import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_wrapper_widget.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';

/// The infinitely-scrolling journal feed (the non-tasks list, `showTasks ==
/// false`).
///
/// Drives [journalPageControllerProvider] and overrides
/// [journalPageScopeProvider] to `false` for the subtree, so descendant
/// widgets (app bar, filters) resolve the journal-scoped controller without
/// threading the flag manually. The body wires the controller's paging
/// controller into `infinite_scroll_pagination`, rendering each page item
/// through [CardWrapperWidget] (optionally with a vector-search distance
/// badge), and exposes pull-to-refresh via `refreshQuery`.
class InfiniteJournalPage extends ConsumerWidget {
  const InfiniteJournalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journalPageControllerProvider(false));
    final selectedCategoryIds = state.selectedCategoryIds;
    final categoryId = selectedCategoryIds.length == 1
        ? selectedCategoryIds.first
        : null;

    return ProviderScope(
      overrides: [
        journalPageScopeProvider.overrideWithValue(false),
      ],
      child: Scaffold(
        // Adopt the shared "card-on-canvas" surface (as on Tasks, Habits and
        // Time Analysis): a calm page canvas a step darker than the cards,
        // instead of the near-black default scaffold.
        backgroundColor: dsPageSurface(context),
        floatingActionButton: FloatingAddActionButton(categoryId: categoryId),
        body: const _InfiniteJournalPageBody(),
      ),
    );
  }
}

class _InfiniteJournalPageBody extends ConsumerStatefulWidget {
  const _InfiniteJournalPageBody();

  @override
  ConsumerState<_InfiniteJournalPageBody> createState() =>
      _InfiniteJournalPageBodyState();
}

class _InfiniteJournalPageBodyState
    extends ConsumerState<_InfiniteJournalPageBody> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController.addListener(listener);
    super.initState();

    // Trigger initial fetch when widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(journalPageControllerProvider(false).notifier).refreshQuery();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journalPageControllerProvider(false));
    final controller = ref.read(
      journalPageControllerProvider(false).notifier,
    );

    return RefreshIndicator(
      onRefresh: controller.refreshQuery,
      child: CustomScrollView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(1500),
        controller: _scrollController,
        slivers: <Widget>[
          const JournalSliverAppBar(),
          if (state.pagingController != null)
            PagingListener<int, JournalEntity>(
              controller: state.pagingController!,
              builder: (context, pagingState, fetchNextPageFunction) {
                return PagedSliverList<int, JournalEntity>(
                  state: pagingState,
                  fetchNextPage: fetchNextPageFunction,
                  builderDelegate: PagedChildBuilderDelegate<JournalEntity>(
                    animateTransitions: true,
                    invisibleItemsThreshold: 10,
                    itemBuilder: (context, item, index) {
                      final distance = state.showDistances
                          ? state.vectorSearchDistances[item.meta.id]
                          : null;
                      return CardWrapperWidget(
                        item: item,
                        showCreationDate: state.showCreationDate,
                        showDueDate: state.showDueDate,
                        showCoverArt: state.showCoverArt,
                        vectorDistance: distance,
                        key: ValueKey(item.meta.id),
                      );
                    },
                  ),
                );
              },
            )
          else
            const SliverToBoxAdapter(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          // Ensure the final card can scroll above overlays (FAB/time indicator)
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }
}

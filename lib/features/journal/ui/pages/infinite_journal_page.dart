import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_wrapper_widget.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/features/tasks/ui/filtering/task_label_quick_filter.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:visibility_detector/visibility_detector.dart';

class InfiniteJournalPage extends StatelessWidget {
  const InfiniteJournalPage({
    required this.showTasks,
    super.key,
  });

  final bool showTasks;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<JournalPageCubit>(
      create: (BuildContext context) => JournalPageCubit(showTasks: showTasks),
      child: Scaffold(
        floatingActionButton: BlocBuilder<JournalPageCubit, JournalPageState>(
          builder: (context, snapshot) {
            final selectedCategoryIds = snapshot.selectedCategoryIds;
            final categoryId = selectedCategoryIds.length == 1
                ? selectedCategoryIds.first
                : null;

            return showTasks
                ? FloatingAddIcon(
                    createFn: () async {
                      final task = await createTask(categoryId: categoryId);
                      if (task != null) {
                        getIt<NavService>()
                            .beamToNamed('/tasks/${task.meta.id}');
                      }
                    },
                    semanticLabel: context.messages.addActionAddTask,
                  )
                : FloatingAddActionButton(categoryId: categoryId);
          },
        ),
        body: InfiniteJournalPageBody(showTasks: showTasks),
      ),
    );
  }
}

class InfiniteJournalPageBody extends StatefulWidget {
  const InfiniteJournalPageBody({
    required this.showTasks,
    super.key,
  });

  final bool showTasks;

  @override
  State<InfiniteJournalPageBody> createState() =>
      _InfiniteJournalPageBodyState();
}

class _InfiniteJournalPageBodyState extends State<InfiniteJournalPageBody> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController.addListener(listener);
    super.initState();

    // Trigger initial fetch when widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<JournalPageCubit>().refreshQuery();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<JournalPageCubit>();

    return VisibilityDetector(
      key: Key(widget.showTasks ? 'tasks_page' : 'journal_page'),
      onVisibilityChanged: cubit.updateVisibility,
      child: BlocBuilder<JournalPageCubit, JournalPageState>(
        builder: (context, snapshot) {
          return RefreshIndicator(
            onRefresh: cubit.refreshQuery,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                const JournalSliverAppBar(),
                // Quick filter section below the header with content-aligned padding
                if (snapshot.showTasks && snapshot.selectedLabelIds.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(40, 8, 40, 8),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: const TaskLabelQuickFilter(),
                        ),
                      ),
                    ),
                  ),
                if (snapshot.pagingController != null)
                  PagingListener<int, JournalEntity>(
                    controller: snapshot.pagingController!,
                    builder: (context, pagingState, fetchNextPageFunction) {
                      return PagedSliverList<int, JournalEntity>(
                        state: pagingState,
                        fetchNextPage: fetchNextPageFunction,
                        builderDelegate:
                            PagedChildBuilderDelegate<JournalEntity>(
                          animateTransitions: true,
                          invisibleItemsThreshold: 10,
                          itemBuilder: (context, item, index) {
                            return CardWrapperWidget(
                              item: item,
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
        },
      ),
    );
  }
}

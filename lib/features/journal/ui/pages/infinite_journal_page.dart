import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/journal_card.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/pages/settings/definitions_list_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:visibility_detector/visibility_detector.dart';

class InfiniteJournalPage extends StatefulWidget {
  const InfiniteJournalPage({
    required this.showTasks,
    super.key,
    this.navigatorKey,
  });

  final GlobalKey? navigatorKey;
  final bool showTasks;

  @override
  State<InfiniteJournalPage> createState() => _InfiniteJournalPageState();
}

class _InfiniteJournalPageState extends State<InfiniteJournalPage> {
  final _actionBtnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShowCaseWidget.of(context).startShowCase([_actionBtnKey]);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocProvider<JournalPageCubit>(
      create: (BuildContext context) => JournalPageCubit(showTasks: widget.showTasks),
      child: Scaffold(
        floatingActionButton: BlocBuilder<JournalPageCubit, JournalPageState>(
          builder: (context, snapshot) {
            final selectedCategoryIds = snapshot.selectedCategoryIds;
            final categoryId = selectedCategoryIds.length == 1
                ? selectedCategoryIds.first
                : null;

            return widget.showTasks
                ? FloatingAddIcon(
                  showcaseKey: _actionBtnKey,
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
        body: InfiniteJournalPageBody(
          showTasks: widget.showTasks,
        ),
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
            onRefresh: () => Future.sync(snapshot.pagingController.refresh),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                const JournalSliverAppBar(),
                PagedSliverList<int, JournalEntity>(
                  pagingController: snapshot.pagingController,
                  builderDelegate: PagedChildBuilderDelegate<JournalEntity>(
                    animateTransitions: true,
                    itemBuilder: (context, item, index) {
                      return EntryWrapperWidget(
                        item: item,
                        taskAsListView: snapshot.taskAsListView,
                        key: ValueKey(item.meta.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

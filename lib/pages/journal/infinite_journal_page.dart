import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/pages/settings/definitions_list_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:lotti/widgets/create/add_actions.dart';
import 'package:lotti/widgets/journal/journal_card.dart';
import 'package:visibility_detector/visibility_detector.dart';

class InfiniteJournalPage extends StatelessWidget {
  const InfiniteJournalPage({
    required this.showTasks,
    super.key,
    this.navigatorKey,
  });

  final GlobalKey? navigatorKey;
  final bool showTasks;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<JournalPageCubit>(
      create: (BuildContext context) => JournalPageCubit(showTasks: showTasks),
      child: Scaffold(
        floatingActionButton: showTasks
            ? BlocBuilder<JournalPageCubit, JournalPageState>(
                builder: (context, snapshot) {
                  return FloatingAddIcon(
                    createFn: () async {
                      final selectedCategoryIds = snapshot.selectedCategoryIds;
                      final task = await createTask(
                        categoryId: selectedCategoryIds.length == 1
                            ? selectedCategoryIds.first
                            : null,
                      );
                      if (task != null) {
                        getIt<NavService>()
                            .beamToNamed('/tasks/${task.meta.id}');
                      }
                    },
                    semanticLabel: context.messages.addActionAddTask,
                  );
                },
              )
            : RadialAddActionButtons(
                radius: isMobile ? 180 : 120,
                isMacOS: isMacOS,
                isIOS: isIOS,
                isAndroid: isAndroid,
              ),
        body: InfiniteJournalPageBody(
          showTasks: showTasks,
        ),
      ),
    );
  }
}

class InfiniteJournalPageBody extends StatelessWidget {
  const InfiniteJournalPageBody({
    required this.showTasks,
    super.key,
  });

  final bool showTasks;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<JournalPageCubit>();

    return VisibilityDetector(
      key: Key(showTasks ? 'tasks_page' : 'journal_page'),
      onVisibilityChanged: cubit.updateVisibility,
      child: BlocBuilder<JournalPageCubit, JournalPageState>(
        builder: (context, snapshot) {
          return RefreshIndicator(
            onRefresh: () => Future.sync(snapshot.pagingController.refresh),
            child: CustomScrollView(
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

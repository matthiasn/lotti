import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/pages/settings/definitions_list_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:lotti/widgets/create/add_actions.dart';
import 'package:lotti/widgets/journal/journal_card.dart';

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
    final localizations = AppLocalizations.of(context)!;

    return BlocProvider<JournalPageCubit>(
      create: (BuildContext context) => JournalPageCubit(showTasks: showTasks),
      child: Scaffold(
        backgroundColor: styleConfig().negspace,
        floatingActionButton: showTasks
            ? FloatingAddIcon(
                createFn: () async {
                  final task = await createTask();
                  if (task != null) {
                    getIt<NavService>().beamToNamed('/tasks/${task.meta.id}');
                  }
                },
                semanticLabel: localizations.addActionAddTask,
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
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        return RefreshIndicator(
          onRefresh: () => Future.sync(snapshot.pagingController.refresh),
          child: CustomScrollView(
            slivers: <Widget>[
              const JournalSliverAppBar(),
              PagedSliverList<int, JournalEntity>(
                pagingController: snapshot.pagingController,
                builderDelegate: PagedChildBuilderDelegate<JournalEntity>(
                  itemBuilder: (context, item, index) {
                    final valueKey = ValueKey(item.meta.id);
                    return item.maybeMap(
                      journalImage: (JournalImage image) =>
                          JournalImageCard(item: image, key: valueKey),
                      orElse: () => JournalCard(item: item, key: valueKey),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

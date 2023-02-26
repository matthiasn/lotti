import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/badges/flagged_badge.dart';
import 'package:lotti/widgets/badges/tasks_badge_icon.dart';
import 'package:lotti/widgets/search/entry_type_filter.dart';
import 'package:lotti/widgets/search/search_widget.dart';
import 'package:lotti/widgets/search/task_status_filter.dart';
import 'package:lotti/widgets/search/tasks_segmented_control.dart';

class JournalSliverAppBar extends StatelessWidget {
  const JournalSliverAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        return SliverAppBar(
          backgroundColor: styleConfig().negspace,
          expandedHeight: 280,
          flexibleSpace: FlexibleSpaceBar(
            background: Padding(
              padding: EdgeInsets.only(top: isIOS ? 30 : 0),
              child: Column(
                children: [
                  SearchWidget(
                    margin: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 40,
                    ),
                    text: snapshot.match,
                    onChanged: cubit.setSearchString,
                    hintText: 'Search...',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        TasksBadge(
                          child: TasksSegmentedControl(
                            showTasks: snapshot.showTasks,
                            onValueChanged: (showTasks) {
                              cubit.setShowTasks(showTasks: showTasks);
                            },
                          ),
                        ),
                        const SizedBox(width: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Visibility(
                              visible: snapshot.showPrivateEntries,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    localizations.journalPrivateTooltip,
                                    style: searchLabelStyle(),
                                  ),
                                  CupertinoSwitch(
                                    value: snapshot.privateEntriesOnly,
                                    activeColor: styleConfig().private,
                                    onChanged: (_) =>
                                        cubit.togglePrivateEntriesOnly(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  localizations.journalFavoriteTooltip,
                                  style: searchLabelStyle(),
                                ),
                                CupertinoSwitch(
                                  value: snapshot.starredEntriesOnly,
                                  activeColor: styleConfig().starredGold,
                                  onChanged: (_) =>
                                      cubit.toggleStarredEntriesOnly(),
                                ),
                              ],
                            ),
                            const SizedBox(width: 5),
                            FlaggedBadge(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    localizations.journalFlaggedTooltip,
                                    style: searchLabelStyle(),
                                  ),
                                  CupertinoSwitch(
                                    value: snapshot.flaggedEntriesOnly,
                                    activeColor: styleConfig().starredGold,
                                    onChanged: (_) =>
                                        cubit.toggleFlaggedEntriesOnly(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                        ),
                        if (!snapshot.showTasks) const EntryTypeFilter(),
                        if (snapshot.showTasks) const TaskStatusFilter(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

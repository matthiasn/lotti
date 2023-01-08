import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/misc/multi_select.dart';
import 'package:lotti/widgets/misc/search_widget.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class JournalSliverAppBar extends StatelessWidget {
  const JournalSliverAppBar({
    super.key,
    required this.resetQuery,
  });

  final void Function() resetQuery;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    final items = entryTypes
        .map(
          (entryType) => MultiSelectItem<FilterBy?>(entryType, entryType.name),
        )
        .toList();

    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        return SliverAppBar(
          backgroundColor: styleConfig().negspace,
          expandedHeight: isIOS ? 230 : 210,
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
                    hintText: 'Search Journal...',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 321,
                          child: MultiSelect<FilterBy?>(
                            multiSelectItems: items,
                            initialValue: snapshot.selectedEntryTypes,
                            onConfirm: (selected) {
                              cubit.setSelectedTypes(selected);
                              resetQuery();
                              HapticFeedback.heavyImpact();
                            },
                            title: 'Entry types',
                            buttonText: 'Entry types',
                            iconData: MdiIcons.filter,
                          ),
                        ),
                        const SizedBox(width: 10),
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
                                    style: TextStyle(
                                      color: styleConfig().secondaryTextColor,
                                    ),
                                  ),
                                  CupertinoSwitch(
                                    value: snapshot.privateEntriesOnly,
                                    activeColor: styleConfig().private,
                                    onChanged: (bool value) {
                                      cubit.togglePrivateEntriesOnly();
                                      resetQuery();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  localizations.journalFavoriteTooltip,
                                  style: TextStyle(
                                    color: styleConfig().secondaryTextColor,
                                  ),
                                ),
                                CupertinoSwitch(
                                  value: snapshot.starredEntriesOnly,
                                  activeColor: styleConfig().starredGold,
                                  onChanged: (bool value) {
                                    cubit.toggleStarredEntriesOnly();
                                    resetQuery();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  localizations.journalFlaggedTooltip,
                                  style: TextStyle(
                                    color: styleConfig().secondaryTextColor,
                                  ),
                                ),
                                CupertinoSwitch(
                                  value: snapshot.flaggedEntriesOnly,
                                  activeColor: styleConfig().starredGold,
                                  onChanged: (bool value) {
                                    cubit.toggleFlaggedEntriesOnly();
                                    resetQuery();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
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

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/create/add_actions.dart';
import 'package:lotti/widgets/journal/journal_card.dart';
import 'package:lotti/widgets/journal/tags/selected_tags_widget.dart';
import 'package:lotti/widgets/misc/multi_select.dart';
import 'package:lotti/widgets/misc/search_widget.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';

class FilterBy {
  FilterBy({
    required this.typeName,
    required this.name,
  });

  final String typeName;
  final String name;
}

final List<String> defaultTypes = [
  'JournalEntry',
  'JournalAudio',
  'JournalImage',
  // 'SurveyEntry',
  'Task',
  // 'QuantitativeEntry',
  // 'MeasurementEntry',
  // 'WorkoutEntry',
  // 'HabitCompletionEntry',
];

final List<FilterBy> _entryTypes = [
  FilterBy(typeName: 'Task', name: 'Task'),
  FilterBy(typeName: 'JournalEntry', name: 'Text'),
  FilterBy(typeName: 'JournalAudio', name: 'Audio'),
  FilterBy(typeName: 'JournalImage', name: 'Photo'),
  FilterBy(typeName: 'MeasurementEntry', name: 'Measured'),
  FilterBy(typeName: 'SurveyEntry', name: 'Survey'),
  FilterBy(typeName: 'WorkoutEntry', name: 'Workout'),
  FilterBy(typeName: 'HabitCompletionEntry', name: 'Habit'),
  FilterBy(typeName: 'QuantitativeEntry', name: 'Quant'),
];

final List<FilterBy?> _defaultTypes = [
  FilterBy(typeName: 'Task', name: 'Task'),
  FilterBy(typeName: 'JournalEntry', name: 'Text'),
  FilterBy(typeName: 'JournalAudio', name: 'Audio'),
  FilterBy(typeName: 'JournalImage', name: 'Photo'),
];

class InfiniteJournalPage extends StatefulWidget {
  const InfiniteJournalPage({
    super.key,
    this.navigatorKey,
  });

  final GlobalKey? navigatorKey;

  @override
  State<InfiniteJournalPage> createState() => _InfiniteJournalPageState();
}

class _InfiniteJournalPageState extends State<InfiniteJournalPage> {
  final JournalDb _db = getIt<JournalDb>();

  late Set<String> types;
  late List<FilterBy?> types2;

  StreamController<List<TagEntity>> matchingTagsController =
      StreamController<List<TagEntity>>();

  final List<MultiSelectItem<FilterBy?>> _items = _entryTypes
      .map((entryType) => MultiSelectItem<FilterBy?>(entryType, entryType.name))
      .toList();

  Set<String> tagIds = {};
  bool starredEntriesOnly = false;
  bool flaggedEntriesOnly = false;
  bool privateEntriesOnly = false;
  bool showPrivateEntriesSwitch = true;

  static const _pageSize = 50;

  final PagingController<int, JournalEntity> _pagingController =
      PagingController(firstPageKey: 0);

  @override
  void initState() {
    _pagingController.addPageRequestListener(_fetchPage);
    types = defaultTypes.toSet();
    types2 = _defaultTypes;
    super.initState();
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      Set<String>? entryIds;
      for (final tagId in tagIds) {
        final entryIdsForTag = (await _db.entryIdsByTagId(tagId)).toSet();
        if (entryIds == null) {
          entryIds = entryIdsForTag;
        } else {
          entryIds = entryIds.intersection(entryIdsForTag);
        }
      }

      final newItems = await _db
          .watchJournalEntities(
            types: types.toList(),
            ids: entryIds?.toList(),
            starredStatuses: starredEntriesOnly ? [true] : [true, false],
            privateStatuses: privateEntriesOnly ? [true] : [true, false],
            flaggedStatuses: flaggedEntriesOnly ? [1] : [1, 0],
            limit: _pageSize,
            offset: pageKey,
          )
          .first;

      final isLastPage = newItems.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + newItems.length;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  Future<void> resetQuery() async {
    _pagingController.refresh();
  }

  void addTag(String tagId) {
    setState(() {
      tagIds.add(tagId);
      resetQuery();
    });
  }

  void removeTag(String remove) {
    setState(() {
      tagIds.remove(remove);
      resetQuery();
    });
  }

  String match = '';

  Widget searchRow() {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 300,
              child: SearchWidget(
                margin: EdgeInsets.zero,
                text: match,
                onChanged: (text) {},
                hintText: 'Search Journal...',
              ),
            ),
            MultiSelect<FilterBy?>(
              multiSelectItems: _items,
              initialValue: const [],
              onConfirm: (selected) {
                setState(() {
                  types = selected
                      .map((e) => e?.typeName)
                      .whereType<String>()
                      .toSet();

                  types2 = selected;
                  resetQuery();
                });

                HapticFeedback.heavyImpact();
              },
              title: 'Entry types',
              buttonText: 'Entry types',
              iconData: MdiIcons.filter,
            ),
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Visibility(
                  visible: showPrivateEntriesSwitch,
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
                        value: privateEntriesOnly,
                        activeColor: styleConfig().private,
                        onChanged: (bool value) {
                          setState(() {
                            privateEntriesOnly = value;
                            resetQuery();
                          });
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
                      style: TextStyle(color: styleConfig().secondaryTextColor),
                    ),
                    CupertinoSwitch(
                      value: starredEntriesOnly,
                      activeColor: styleConfig().starredGold,
                      onChanged: (bool value) {
                        setState(() {
                          starredEntriesOnly = value;
                          resetQuery();
                        });
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
                      style: TextStyle(color: styleConfig().secondaryTextColor),
                    ),
                    CupertinoSwitch(
                      value: flaggedEntriesOnly,
                      activeColor: styleConfig().starredGold,
                      onChanged: (bool value) {
                        setState(() {
                          flaggedEntriesOnly = value;
                          resetQuery();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        SelectedTagsWidget(
          removeTag: removeTag,
          tagIds: tagIds.toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: widget.navigatorKey,
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (BuildContext context) {
            return Scaffold(
              backgroundColor: styleConfig().negspace,
              floatingActionButton: RadialAddActionButtons(
                radius: isMobile ? 180 : 120,
                isMacOS: isMacOS,
                isIOS: isIOS,
                isAndroid: isAndroid,
              ),
              body: RefreshIndicator(
                onRefresh: () => Future.sync(_pagingController.refresh),
                child: CustomScrollView(
                  slivers: <Widget>[
                    JournalSliverAppBar(
                      match: '',
                      onQueryChanged: (text) {},
                      searchRow: searchRow(),
                    ),
                    PagedSliverList<int, JournalEntity>(
                      pagingController: _pagingController,
                      builderDelegate: PagedChildBuilderDelegate<JournalEntity>(
                        itemBuilder: (context, item, index) {
                          return item.maybeMap(
                            journalImage: (JournalImage image) {
                              return JournalImageCard(
                                item: image,
                                key: ValueKey(item.meta.id),
                              );
                            },
                            orElse: () {
                              return JournalCard(
                                item: item,
                                key: ValueKey(item.meta.id),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }
}

class JournalSliverAppBar extends StatelessWidget {
  const JournalSliverAppBar({
    super.key,
    required this.match,
    required this.onQueryChanged,
    required this.searchRow,
  });

  final String match;
  final void Function(String) onQueryChanged;
  final Widget searchRow;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: styleConfig().negspace,
      expandedHeight: isIOS ? 230 : 210,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: EdgeInsets.only(top: isIOS ? 30 : 0),
          child: searchRow,
        ),
      ),
    );
  }
}

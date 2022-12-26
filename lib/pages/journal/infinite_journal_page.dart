import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:glass/glass.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/journal/journal_card.dart';
import 'package:lotti/widgets/journal/tags/selected_tags_widget.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';
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
  'SurveyEntry',
  'Task',
  // 'QuantitativeEntry',
  'MeasurementEntry',
  'WorkoutEntry',
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

  StreamController<List<TagEntity>> matchingTagsController =
      StreamController<List<TagEntity>>();

  final List<MultiSelectItem<FilterBy?>> _items = _entryTypes
      .map((entryType) => MultiSelectItem<FilterBy?>(entryType, entryType.name))
      .toList();

  Set<String> tagIds = {};
  bool starredEntriesOnly = false;
  bool flaggedEntriesOnly = false;
  bool privateEntriesOnly = false;
  bool showPrivateEntriesSwitch = false;

  static const _pageSize = 50;

  final PagingController<int, JournalEntity> _pagingController =
      PagingController(firstPageKey: 0);

  @override
  void initState() {
    _pagingController.addPageRequestListener(_fetchPage);

    types = defaultTypes.toSet();

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

      //final newItems = await RemoteApi.getCharacterList(pageKey, _pageSize);

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

  Widget buildFloatingSearchBar() {
    final localizations = AppLocalizations.of(context)!;

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final portraitWidth = MediaQuery.of(context).size.width * 0.88;

    return FloatingSearchBar(
      hint: AppLocalizations.of(context)!.journalSearchHint,
      scrollPadding: const EdgeInsets.only(top: 16, bottom: 56),
      transitionDuration: const Duration(milliseconds: 800),
      transitionCurve: Curves.easeInOut,
      backgroundColor: styleConfig().cardColor,
      queryStyle: const TextStyle(
        fontFamily: mainFont,
        fontSize: 24,
      ),
      hintStyle: const TextStyle(
        fontFamily: mainFont,
        fontSize: 24,
      ),
      physics: const BouncingScrollPhysics(),
      borderRadius: BorderRadius.circular(8),
      axisAlignment: isPortrait ? 0 : -1,
      openAxisAlignment: 0,
      margins: EdgeInsets.only(
        top: isIOS ? 48 : 8,
        left: isDesktop ? 12 : 0,
      ),
      width: isPortrait ? portraitWidth : MediaQuery.of(context).size.width,
      onQueryChanged: (query) async {
        final res = await _db.getMatchingTags(
          query.trim(),
          inactive: true,
        );
        matchingTagsController.add(res);
      },
      transition: SlideFadeFloatingSearchBarTransition(),
      actions: [
        FloatingSearchBarAction.searchToClear(
          showIfClosed: false,
        ),
      ],
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            children: [
              SizedBox(
                height: isIOS ? 100 : 60,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ..._items.map(
                      (MultiSelectItem<FilterBy?> item) => GestureDetector(
                        onTap: () {
                          setState(() {
                            final typeName = item.value?.typeName;
                            if (typeName != null) {
                              if (types.contains(typeName)) {
                                types.remove(typeName);
                              } else {
                                types.add(typeName);
                              }
                              resetQuery();
                              HapticFeedback.heavyImpact();
                            }
                          });
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: ColoredBox(
                              color: types.contains(item.value?.typeName)
                                  ? styleConfig().selectedChoiceChipColor
                                  : styleConfig().unselectedChoiceChipColor,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 1,
                                  horizontal: 8,
                                ),
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontFamily: 'Oswald',
                                    fontSize: 14,
                                    color: types.contains(item.value?.typeName)
                                        ? styleConfig()
                                            .selectedChoiceChipTextColor
                                        : styleConfig()
                                            .unselectedChoiceChipTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Visibility(
                      visible: showPrivateEntriesSwitch,
                      child: Row(
                        children: [
                          Text(
                            localizations.journalPrivateTooltip,
                            style: TextStyle(
                              color: styleConfig().primaryTextColor,
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
                    Text(
                      localizations.journalFavoriteTooltip,
                      style: TextStyle(color: styleConfig().primaryTextColor),
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
                    Text(
                      localizations.journalFlaggedTooltip,
                      style: TextStyle(color: styleConfig().primaryTextColor),
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
              ),
              SelectedTagsWidget(
                removeTag: removeTag,
                tagIds: tagIds.toList(),
              ),
            ],
          ).asGlass(tintColor: styleConfig().primaryTextColor),
        ],
      ),
      builder: (context, transition) {
        return Padding(
          padding: const EdgeInsets.only(
            top: 2,
            bottom: 8,
            right: 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<List<TagEntity>>(
                stream: matchingTagsController.stream,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<TagEntity>> snapshot,
                ) {
                  return Column(
                    children: [
                      ...?snapshot.data?.map(
                        (tagEntity) => ListTile(
                          title: Text(
                            tagEntity.tag,
                            style: TextStyle(
                              fontFamily: mainFont,
                              color: getTagColor(tagEntity),
                              fontWeight: FontWeight.normal,
                              fontSize: 20,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              addTag(tagEntity.id);
                            });
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ).asGlass(
          clipBorderRadius: BorderRadius.circular(8),
          tintColor: styleConfig().cardColor,
        );
      },
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
            final screenWidth = MediaQuery.of(context).size.width;

            var searchHeaderHeight = 136.0;

            if (tagIds.toList().isNotEmpty) {
              searchHeaderHeight += 24;
            }

            if (screenWidth < 640) {
              searchHeaderHeight += 32;
            }

            return Stack(
              children: [
                Scaffold(
                  backgroundColor: styleConfig().negspace,
                  body: Padding(
                    padding: EdgeInsets.only(top: searchHeaderHeight),
                    child: RefreshIndicator(
                      onRefresh: () => Future.sync(_pagingController.refresh),
                      child: PagedListView<int, JournalEntity>(
                        pagingController: _pagingController,
                        builderDelegate:
                            PagedChildBuilderDelegate<JournalEntity>(
                          //animateTransitions: true,
                          itemBuilder: (context, item, index) =>
                              JournalCard(item: item),
                        ),
                      ),
                    ),
                  ),
                ),
                buildFloatingSearchBar(),
              ],
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

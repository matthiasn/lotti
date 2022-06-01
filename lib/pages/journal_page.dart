import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:glass/glass.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/create/add_actions.dart';
import 'package:lotti/widgets/journal/journal_card.dart';
import 'package:lotti/widgets/journal/slideshow.dart';
import 'package:lotti/widgets/journal/tags_search_widget.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({
    Key? key,
    this.navigatorKey,
  }) : super(key: key);

  final GlobalKey? navigatorKey;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class FilterBy {
  final String typeName;
  final String name;

  FilterBy({
    required this.typeName,
    required this.name,
  });
}

class _JournalPageState extends State<JournalPage> {
  final JournalDb _db = getIt<JournalDb>();

  static final List<FilterBy> _entryTypes = [
    FilterBy(typeName: 'Task', name: 'Task'),
    FilterBy(typeName: 'JournalEntry', name: 'Text'),
    FilterBy(typeName: 'JournalAudio', name: 'Audio'),
    FilterBy(typeName: 'JournalImage', name: 'Photo'),
    FilterBy(typeName: 'QuantitativeEntry', name: 'Quant'),
    FilterBy(typeName: 'MeasurementEntry', name: 'Measured'),
    FilterBy(typeName: 'SurveyEntry', name: 'Survey'),
    FilterBy(typeName: 'WorkoutEntry', name: 'Workout'),
  ];

  late Stream<List<JournalEntity>> stream;
  late Stream<List<ConfigFlag>> configFlagsStream;

  final List<MultiSelectItem<FilterBy?>> _items = _entryTypes
      .map((entryType) => MultiSelectItem<FilterBy?>(entryType, entryType.name))
      .toList();

  final List<String> defaultTypes = [
    'JournalEntry',
    'JournalAudio',
    'JournalImage',
    'SurveyEntry',
    'Task',
    'QuantitativeEntry',
    'MeasurementEntry',
    'WorkoutEntry',
  ];
  late Set<String> types;
  Set<String> tagIds = {};
  StreamController<List<TagEntity>> matchingTagsController =
      StreamController<List<TagEntity>>();
  bool starredEntriesOnly = false;
  bool flaggedEntriesOnly = false;
  bool privateEntriesOnly = false;
  bool showPrivateEntriesSwitch = false;
  bool showSlideshow = false;

  @override
  void initState() {
    super.initState();
    types = defaultTypes.toSet();
    configFlagsStream = _db.watchConfigFlags();
    configFlagsStream.listen((List<ConfigFlag> configFlags) {
      setState(() {
        for (ConfigFlag flag in configFlags) {
          if (flag.name == 'private') {
            showPrivateEntriesSwitch = flag.status;
          }
        }
        if (showPrivateEntriesSwitch == false) {
          privateEntriesOnly = false;
        }
      });
      resetStream();
    });
    resetStream();
  }

  void resetStream() async {
    Set<String>? entryIds;
    for (String tagId in tagIds) {
      Set<String> entryIdsForTag = (await _db.entryIdsByTagId(tagId)).toSet();
      if (entryIds == null) {
        entryIds = entryIdsForTag;
      } else {
        entryIds = entryIds.intersection(entryIdsForTag);
      }
    }
    setState(() {
      stream = _db.watchJournalEntities(
        types: types.toList(),
        ids: entryIds?.toList(),
        starredStatuses: starredEntriesOnly ? [true] : [true, false],
        privateStatuses: privateEntriesOnly ? [true] : [true, false],
        flaggedStatuses: flaggedEntriesOnly ? [1] : [1, 0],
      );
    });
  }

  void addTag(String tagId) {
    setState(() {
      tagIds.add(tagId);
      resetStream();
    });
  }

  void removeTag(String remove) {
    setState(() {
      tagIds.remove(remove);
      resetStream();
    });
  }

  Widget buildFloatingSearchBar() {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    double portraitWidth = MediaQuery.of(context).size.width * 0.88;

    return FloatingSearchBar(
      hint: AppLocalizations.of(context)!.journalSearchHint,
      scrollPadding: const EdgeInsets.only(top: 16, bottom: 56),
      transitionDuration: const Duration(milliseconds: 800),
      transitionCurve: Curves.easeInOut,
      backgroundColor: AppColors.appBarFgColor,
      queryStyle: const TextStyle(
        fontFamily: 'Lato',
        fontSize: 24,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Lato',
        fontSize: 24,
      ),
      physics: const BouncingScrollPhysics(),
      borderRadius: BorderRadius.circular(8.0),
      axisAlignment: isPortrait ? 0.0 : -1.0,
      openAxisAlignment: 0.0,
      margins: EdgeInsets.only(
        top: Platform.isIOS ? 48 : 8.0,
        left: isDesktop ? 12.0 : 0.0,
      ),
      width: isPortrait ? portraitWidth : 500,
      onQueryChanged: (query) async {
        List<TagEntity> res = await _db.getMatchingTags(
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
                height: Platform.isIOS ? 100 : 60,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ..._items
                        .map(
                          (MultiSelectItem<FilterBy?> item) => GestureDetector(
                            onTap: () {
                              setState(() {
                                String? typeName = item.value?.typeName;
                                if (typeName != null) {
                                  if (types.contains(typeName)) {
                                    types.remove(typeName);
                                  } else {
                                    types.add(typeName);
                                  }
                                  resetStream();
                                  HapticFeedback.heavyImpact();
                                }
                              });
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  color: types.contains(item.value?.typeName)
                                      ? Colors.lightBlue
                                      : Colors.grey[600],
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
                                        color:
                                            types.contains(item.value?.typeName)
                                                ? Colors.grey[900]
                                                : Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Visibility(
                    visible: showPrivateEntriesSwitch,
                    child: Row(
                      children: [
                        Text(
                          localizations.journalPrivateTooltip,
                          style: TextStyle(color: AppColors.entryTextColor),
                        ),
                        CupertinoSwitch(
                          value: privateEntriesOnly,
                          activeColor: AppColors.private,
                          onChanged: (bool value) {
                            setState(() {
                              privateEntriesOnly = value;
                              resetStream();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Text(
                    localizations.journalFavoriteTooltip,
                    style: TextStyle(color: AppColors.entryTextColor),
                  ),
                  CupertinoSwitch(
                    value: starredEntriesOnly,
                    activeColor: AppColors.starredGold,
                    onChanged: (bool value) {
                      setState(() {
                        starredEntriesOnly = value;
                        resetStream();
                      });
                    },
                  ),
                  Text(
                    localizations.journalFlaggedTooltip,
                    style: TextStyle(color: AppColors.entryTextColor),
                  ),
                  CupertinoSwitch(
                    value: flaggedEntriesOnly,
                    activeColor: AppColors.starredGold,
                    onChanged: (bool value) {
                      setState(() {
                        flaggedEntriesOnly = value;
                        resetStream();
                      });
                    },
                  ),
                ],
              ),
              SelectedTagsWidget(
                removeTag: removeTag,
                tagIds: tagIds.toList(),
              ),
            ],
          ).asGlass(
            clipBorderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
        ],
      ),
      builder: (context, transition) {
        return Padding(
          padding: const EdgeInsets.only(
            top: 2.0,
            bottom: 8.0,
            left: 0.0,
            right: 4.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TODO: fix or remove
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.end,
              //   children: [
              //     Text(
              //       '_slideshow',
              //       style: TextStyle(color: AppColors.entryTextColor),
              //     ),
              //     CupertinoSwitch(
              //       value: showSlideshow,
              //       activeColor: AppColors.starredGold,
              //       onChanged: (bool value) {
              //         setState(() {
              //           showSlideshow = value;
              //         });
              //       },
              //     ),
              //   ],
              // ),
              StreamBuilder<List<TagEntity>>(
                stream: matchingTagsController.stream,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<TagEntity>> snapshot,
                ) {
                  return Column(
                    children: [
                      ...?snapshot.data
                          ?.map((tagEntity) => ListTile(
                                title: Text(
                                  tagEntity.tag,
                                  style: TextStyle(
                                    fontFamily: 'Lato',
                                    color: getTagColor(tagEntity),
                                    fontWeight: FontWeight.normal,
                                    fontSize: 20.0,
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    addTag(tagEntity.id);
                                  });
                                },
                              ))
                          .toList(),
                    ],
                  );
                },
              ),
            ],
          ),
        ).asGlass(
          clipBorderRadius: BorderRadius.circular(8),
          tintColor: AppColors.searchBgColor,
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
            return StreamBuilder<List<JournalEntity>>(
              stream: stream,
              builder: (
                BuildContext context,
                AsyncSnapshot<List<JournalEntity>> snapshot,
              ) {
                if (snapshot.data == null) {
                  return Container();
                } else {
                  List<JournalEntity> items = snapshot.data!;

                  double screenWidth = MediaQuery.of(context).size.width;
                  double searchHeaderHeight = 136;

                  if (tagIds.toList().isNotEmpty) {
                    searchHeaderHeight += 24;
                  }

                  if (screenWidth < 640) {
                    searchHeaderHeight += 32;
                  }

                  if (Platform.isIOS) {
                    searchHeaderHeight += 40;
                  }

                  return Stack(
                    children: [
                      Scaffold(
                        backgroundColor: AppColors.bodyBgColor,
                        body: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: ListView(
                            children: [
                              SizedBox(height: searchHeaderHeight),
                              ...List.generate(
                                items.length,
                                (int index) {
                                  JournalEntity item = items.elementAt(index);
                                  return item.maybeMap(
                                      journalImage: (JournalImage image) {
                                    return JournalImageCard(
                                      item: image,
                                      key: ValueKey(item.meta.id),
                                    );
                                  }, orElse: () {
                                    return JournalCard(
                                      item: item,
                                      key: ValueKey(item.meta.id),
                                    );
                                  });
                                },
                                growable: true,
                              ),
                              const SizedBox(height: 64),
                            ],
                          ),
                        ),
                        floatingActionButton: RadialAddActionButtons(
                          radius: isMobile ? 180 : 120,
                        ),
                      ),
                      if (showSlideshow) SlideShowWidget(items),
                      if (!showSlideshow) buildFloatingSearchBar(),
                      if (showSlideshow)
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                showSlideshow = !showSlideshow;
                                resetStream();
                              });
                            },
                            icon: Icon(
                              Icons.close,
                              color: AppColors.bottomNavIconUnselected,
                            ),
                          ),
                        ),
                    ],
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

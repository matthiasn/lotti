import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glass/glass.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/create/add_actions.dart';
import 'package:lotti/widgets/journal/journal_card.dart';
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
  _JournalPageState createState() => _JournalPageState();
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
    FilterBy(typeName: 'JournalEntry', name: 'Text'),
    FilterBy(typeName: 'JournalAudio', name: 'Audio'),
    FilterBy(typeName: 'JournalImage', name: 'Photo'),
    FilterBy(typeName: 'QuantitativeEntry', name: 'Quantitative'),
    FilterBy(typeName: 'MeasurementEntry', name: 'Measurement'),
    FilterBy(typeName: 'SurveyEntry', name: 'Questionnaire'),
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
    'SurveyEntry'
  ];
  late Set<String> types;
  Set<String> tagIds = {};
  StreamController<List<TagEntity>> matchingTagsController =
      StreamController<List<TagEntity>>();
  bool starredEntriesOnly = false;
  bool privateEntriesOnly = false;
  bool showPrivateEntriesSwitch = false;

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
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    double portraitWidth = MediaQuery.of(context).size.width * 0.88;

    return FloatingSearchBar(
      hint: 'Search...',
      scrollPadding: const EdgeInsets.only(top: 16, bottom: 56),
      transitionDuration: const Duration(milliseconds: 800),
      transitionCurve: Curves.easeInOut,
      backgroundColor: AppColors.appBarFgColor,
      queryStyle: const TextStyle(
        fontFamily: 'Lato',
        fontSize: 24,
        fontWeight: FontWeight.w300,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Lato',
        fontSize: 24,
        fontWeight: FontWeight.w300,
      ),
      physics: const BouncingScrollPhysics(),
      borderRadius: BorderRadius.circular(8.0),
      axisAlignment: isPortrait ? 0.0 : -1.0,
      openAxisAlignment: 0.0,
      margins: EdgeInsets.only(top: 8.0, left: isDesktop ? 12.0 : 0.0),
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
      builder: (context, transition) {
        return Padding(
          padding: const EdgeInsets.only(
            top: 2.0,
            bottom: 8.0,
            left: 4.0,
            right: 4.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Visibility(
                    visible: showPrivateEntriesSwitch,
                    child: Row(
                      children: [
                        Text(
                          'Private: ',
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
                  const SizedBox(
                    width: 16,
                  ),
                  Text(
                    'Starred: ',
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
                ],
              ),
              SelectedTagsWidget(
                removeTag: removeTag,
                tagIds: tagIds.toList(),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
                                    : Colors.grey[50],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    item.label,
                                    style: const TextStyle(
                                      fontFamily: 'Oswald',
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
                                    fontSize: 24.0,
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

                  return Stack(
                    children: [
                      Scaffold(
                        backgroundColor: AppColors.bodyBgColor,
                        body: Container(
                          margin: const EdgeInsets.all(8.0),
                          child: ListView(
                            children: [
                              const SizedBox(
                                height: 56,
                              ),
                              ...List.generate(
                                items.length,
                                (int index) {
                                  JournalEntity item = items.elementAt(index);
                                  return item.maybeMap(
                                      journalImage: (JournalImage image) {
                                    return JournalImageCard(
                                      item: image,
                                      index: index,
                                    );
                                  }, orElse: () {
                                    return JournalCard(
                                      item: item,
                                      index: index,
                                    );
                                  });
                                },
                                growable: true,
                              )
                            ],
                          ),
                        ),
                        floatingActionButton: RadialAddActionButtons(
                          radius: isMobile ? 180 : 120,
                        ),
                      ),
                      buildFloatingSearchBar(),
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

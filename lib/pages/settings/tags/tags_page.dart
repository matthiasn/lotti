import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/utils.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/create/add_tag_actions.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';

class TagsPage extends StatefulWidget {
  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  final JournalDb _db = getIt<JournalDb>();
  late final Stream<List<TagEntity>> stream = _db.watchTags();
  String match = '';

  @override
  void initState() {
    super.initState();
  }

  Widget buildFloatingSearchBar() {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    final portraitWidth = MediaQuery.of(context).size.width * 0.5;

    return Theme(
      data: ThemeData(
        brightness: styleConfig().keyboardAppearance,
      ),
      child: FloatingSearchBar(
        clearQueryOnClose: false,
        automaticallyImplyBackButton: false,
        hint: AppLocalizations.of(context)!.settingsTagsSearchHint,
        scrollPadding: const EdgeInsets.only(top: 16, bottom: 56),
        transitionDuration: const Duration(milliseconds: 800),
        transitionCurve: Curves.easeInOut,
        backgroundColor: styleConfig().cardColor,
        margins: const EdgeInsets.only(top: 8),
        queryStyle: const TextStyle(
          fontFamily: mainFont,
          fontSize: 20,
        ),
        hintStyle: TextStyle(
          fontFamily: mainFont,
          fontSize: 20,
          color: styleConfig().secondaryTextColor,
        ),
        physics: const BouncingScrollPhysics(),
        borderRadius: BorderRadius.circular(8),
        axisAlignment: isPortrait ? 0 : -1,
        openAxisAlignment: 0,
        width: isPortrait ? portraitWidth : 400,
        onQueryChanged: (query) async {
          setState(() {
            match = query.toLowerCase();
          });
        },
        actions: [
          FloatingSearchBarAction.searchToClear(
            showIfClosed: false,
          ),
        ],
        builder: (context, transition) {
          return const SizedBox.shrink();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: TitleAppBar(title: localizations.settingsTagsTitle),
      backgroundColor: styleConfig().negspace,
      floatingActionButton: const RadialAddTagButtons(),
      body: StreamBuilder<List<TagEntity>>(
        stream: stream,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<TagEntity>> snapshot,
        ) {
          final items = snapshot.data ?? <TagEntity>[];
          final filtered = items
              .where(
                (TagEntity entity) => entity.tag.toLowerCase().contains(match),
              )
              .toList();

          return Stack(
            children: [
              ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(
                  bottom: 8,
                  top: 64,
                ),
                children: intersperse(
                  const SettingsDivider(),
                  List.generate(
                    filtered.length,
                    (int index) {
                      return TagCard(
                        tagEntity: filtered.elementAt(index),
                        index: index,
                      );
                    },
                  ),
                ).toList(),
              ),
              buildFloatingSearchBar(),
            ],
          );
        },
      ),
    );
  }
}

class TagCard extends StatelessWidget {
  TagCard({
    super.key,
    required this.tagEntity,
    required this.index,
  });

  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final TagEntity tagEntity;
  final int index;

  @override
  Widget build(BuildContext context) {
    return SettingsNavCard(
      path: '/settings/tags/${tagEntity.id}',
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Container(
          color: getTagColor(tagEntity),
          width: 20,
          height: 20,
        ),
      ),
      title: tagEntity.tag,
    );
  }
}

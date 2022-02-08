import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/create/add_tag_actions.dart';
import 'package:lotti/widgets/misc/app_bar_version.dart';
import 'package:lotti/widgets/pages/settings/tags/tag_details.dart';

class TagsPage extends StatefulWidget {
  const TagsPage({Key? key}) : super(key: key);

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  final JournalDb _db = getIt<JournalDb>();

  late final Stream<List<TagEntity>> stream = _db.watchTags();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TagEntity>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<TagEntity>> snapshot,
      ) {
        List<TagEntity> items = snapshot.data ?? [];

        return Scaffold(
          appBar: VersionAppBar(title: 'Tags, n= ${items.length}'),
          backgroundColor: AppColors.bodyBgColor,
          floatingActionButton: const RadialAddTagButtons(),
          body: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8.0),
            children: List.generate(
              items.length,
              (int index) {
                return TagCard(
                  tagEntity: items.elementAt(index),
                  index: index,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class TagCard extends StatelessWidget {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final TagEntity tagEntity;
  final int index;

  TagCard({
    Key? key,
    required this.tagEntity,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.headerBgColor,
      elevation: 8.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: SingleChildScrollView(
        child: ListTile(
          contentPadding:
              const EdgeInsets.only(left: 16, top: 4, bottom: 8, right: 16),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tagEntity.tag,
                style: TextStyle(
                  color: getTagColor(tagEntity),
                  fontFamily: 'Oswald',
                  fontSize: 20.0,
                ),
              ),
              CupertinoSwitch(
                value: tagEntity.private,
                activeColor: AppColors.private,
                onChanged: (bool private) async {
                  await persistenceLogic
                      .upsertTagEntity(tagEntity.copyWith(private: private));
                },
              ),
            ],
          ),
          enabled: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) {
                  return TagDetailRoute(
                    tagEntity: tagEntity,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

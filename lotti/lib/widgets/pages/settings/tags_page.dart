import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/misc/app_bar_version.dart';

class TagsPage extends StatefulWidget {
  const TagsPage({Key? key}) : super(key: key);

  @override
  State<TagsPage> createState() => _FlagsPageState();
}

class _FlagsPageState extends State<TagsPage> {
  final JournalDb _db = getIt<JournalDb>();

  late final Stream<List<TagDefinition>> stream = _db.watchTags();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TagDefinition>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<TagDefinition>> snapshot,
      ) {
        List<TagDefinition> items = snapshot.data ?? [];

        return Scaffold(
          appBar: const VersionAppBar(title: 'Tags'),
          backgroundColor: AppColors.bodyBgColor,
          body: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8.0),
            children: List.generate(
              items.length,
              (int index) {
                return TagCard(
                  tagDefinition: items.elementAt(index),
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
  final JournalDb _db = getIt<JournalDb>();

  final TagDefinition tagDefinition;
  final int index;

  TagCard({
    Key? key,
    required this.tagDefinition,
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
                tagDefinition.tag,
                style: TextStyle(
                  color: AppColors.entryTextColor,
                  fontFamily: 'Oswald',
                  fontSize: 20.0,
                ),
              ),
              CupertinoSwitch(
                value: tagDefinition.private,
                activeColor: AppColors.private,
                onChanged: (bool private) {
                  _db.upsertTagDefinition(
                      tagDefinition.copyWith(private: private));
                },
              ),
            ],
          ),
          enabled: true,
        ),
      ),
    );
  }
}

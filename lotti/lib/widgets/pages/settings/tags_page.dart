import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/misc/app_bar_version.dart';
import 'package:lotti/widgets/pages/settings/form_text_field.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/src/provider.dart';

class TagsPage extends StatefulWidget {
  const TagsPage({Key? key}) : super(key: key);

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
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
          appBar: VersionAppBar(title: 'Tags, n= ${items.length}'),
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
                onChanged: (bool private) async {
                  await context.read<PersistenceCubit>().upsertEntityDefinition(
                      tagDefinition.copyWith(private: private));
                },
              ),
            ],
          ),
          enabled: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) {
                  return DetailRoute(
                    index: index,
                    tagDefinition: tagDefinition,
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

class DetailRoute extends StatefulWidget {
  const DetailRoute({
    Key? key,
    required this.tagDefinition,
    required this.index,
  }) : super(key: key);

  final int index;
  final TagDefinition tagDefinition;

  @override
  _DetailRouteState createState() {
    return _DetailRouteState();
  }
}

class _DetailRouteState extends State<DetailRoute> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PersistenceCubit, PersistenceState>(
        builder: (BuildContext context, PersistenceState state) {
      return Scaffold(
        backgroundColor: AppColors.bodyBgColor,
        appBar: AppBar(
          foregroundColor: AppColors.appBarFgColor,
          title: Text(
            widget.tagDefinition.tag,
            style: TextStyle(
              color: AppColors.entryTextColor,
              fontFamily: 'Oswald',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                _formKey.currentState!.save();
                if (_formKey.currentState!.validate()) {
                  final formData = _formKey.currentState?.value;
                  TagDefinition tagDefinition = widget.tagDefinition.copyWith(
                    tag: '${formData!['tag']}'.trim(),
                    private: formData['private'],
                    updatedAt: DateTime.now(),
                  );

                  context
                      .read<PersistenceCubit>()
                      .upsertEntityDefinition(tagDefinition);

                  Navigator.pop(context);
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'Oswald',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          backgroundColor: AppColors.headerBgColor,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: AppColors.headerBgColor,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      FormBuilder(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          children: <Widget>[
                            FormTextField(
                              initialValue: widget.tagDefinition.tag,
                              labelText: 'Tag',
                              name: 'tag',
                            ),
                            FormBuilderSwitch(
                              name: 'private',
                              initialValue: widget.tagDefinition.private,
                              title: Text(
                                'Private: ',
                                style: formLabelStyle,
                              ),
                              activeColor: AppColors.private,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(MdiIcons.trashCanOutline),
                              iconSize: 24,
                              tooltip: 'Delete',
                              color: AppColors.appBarFgColor,
                              onPressed: () {
                                context
                                    .read<PersistenceCubit>()
                                    .upsertEntityDefinition(
                                      widget.tagDefinition.copyWith(
                                        deletedAt: DateTime.now(),
                                      ),
                                    );
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/create/add_tag_actions.dart';
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
                  color: AppColors.entryTextColor,
                  fontFamily: 'Oswald',
                  fontSize: 20.0,
                ),
              ),
              CupertinoSwitch(
                value: tagEntity.private,
                activeColor: AppColors.private,
                onChanged: (bool private) async {
                  await context
                      .read<PersistenceCubit>()
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

class TagDetailRoute extends StatefulWidget {
  const TagDetailRoute({
    Key? key,
    required this.tagEntity,
  }) : super(key: key);

  final TagEntity tagEntity;

  @override
  _TagDetailRouteState createState() {
    return _TagDetailRouteState();
  }
}

class _TagDetailRouteState extends State<TagDetailRoute> {
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
            widget.tagEntity.tag,
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
                  TagEntity tagEntity = widget.tagEntity.copyWith(
                    tag: '${formData!['tag']}'.trim(),
                    private: formData['private'],
                    inactive: formData['inactive'],
                    updatedAt: DateTime.now(),
                  );

                  context.read<PersistenceCubit>().upsertTagEntity(tagEntity);

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
                              initialValue: widget.tagEntity.tag,
                              labelText: 'Tag',
                              name: 'tag',
                            ),
                            FormBuilderSwitch(
                              name: 'private',
                              initialValue: widget.tagEntity.private,
                              title: Text(
                                'Private: ',
                                style: formLabelStyle,
                              ),
                              activeColor: AppColors.private,
                            ),
                            FormBuilderSwitch(
                              name: 'inactive',
                              initialValue: widget.tagEntity.inactive,
                              title: Text(
                                'Hide from suggestions: ',
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
                                    .upsertTagEntity(
                                      widget.tagEntity.copyWith(
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

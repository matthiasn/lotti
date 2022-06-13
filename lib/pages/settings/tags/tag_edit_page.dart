import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/form_text_field.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TagEditPage extends StatefulWidget {
  const TagEditPage({
    Key? key,
    required this.tagEntity,
  }) : super(key: key);

  final TagEntity tagEntity;

  @override
  State<TagEditPage> createState() {
    return _TagEditPageState();
  }
}

class _TagEditPageState extends State<TagEditPage> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();
  bool dirty = false;

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    onSavePressed() async {
      _formKey.currentState!.save();
      if (_formKey.currentState!.validate()) {
        final formData = _formKey.currentState?.value;
        TagEntity newTagEntity = widget.tagEntity.copyWith(
          tag: '${formData!['tag']}'.trim(),
          private: formData['private'],
          inactive: formData['inactive'],
          updatedAt: DateTime.now(),
        );

        String type = formData['type'];

        if (type == 'PERSON') {
          newTagEntity = TagEntity.personTag(
            tag: newTagEntity.tag,
            vectorClock: newTagEntity.vectorClock,
            updatedAt: newTagEntity.updatedAt,
            createdAt: newTagEntity.createdAt,
            private: newTagEntity.private,
            inactive: newTagEntity.inactive,
            id: newTagEntity.id,
          );
        }

        if (type == 'STORY') {
          newTagEntity = TagEntity.storyTag(
            tag: newTagEntity.tag,
            vectorClock: newTagEntity.vectorClock,
            updatedAt: newTagEntity.updatedAt,
            createdAt: newTagEntity.createdAt,
            private: newTagEntity.private,
            inactive: newTagEntity.inactive,
            id: newTagEntity.id,
          );
        }

        if (type == 'TAG') {
          newTagEntity = TagEntity.genericTag(
            tag: newTagEntity.tag,
            vectorClock: newTagEntity.vectorClock,
            updatedAt: newTagEntity.updatedAt,
            createdAt: newTagEntity.createdAt,
            private: newTagEntity.private,
            inactive: newTagEntity.inactive,
            id: newTagEntity.id,
          );
        }

        persistenceLogic.upsertTagEntity(newTagEntity);
        context.router.pop();

        setState(() {
          dirty = false;
        });
      }
    }

    return Scaffold(
      appBar: TitleAppBar(
        title: localizations.settingsTagsTitle,
        actions: [
          if (dirty)
            TextButton(
              key: const Key('tag_save'),
              onPressed: onSavePressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  localizations.settingsTagsSaveLabel,
                  style: saveButtonStyle,
                ),
              ),
            ),
        ],
      ),
      backgroundColor: AppColors.bodyBgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: AppColors.entryCardColor,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    FormBuilder(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: () {
                        setState(() {
                          dirty = true;
                        });
                      },
                      child: Column(
                        children: <Widget>[
                          FormTextField(
                            initialValue: widget.tagEntity.tag,
                            labelText: localizations.settingsTagsTagName,
                            name: 'tag',
                            key: const Key('tag_name_field'),
                          ),
                          FormBuilderSwitch(
                            name: 'private',
                            initialValue: widget.tagEntity.private,
                            title: Text(
                              localizations.settingsTagsPrivateLabel,
                              style: formLabelStyle,
                            ),
                            activeColor: AppColors.private,
                          ),
                          FormBuilderSwitch(
                            name: 'inactive',
                            initialValue: widget.tagEntity.inactive,
                            title: Text(
                              localizations.settingsTagsHideLabel,
                              style: formLabelStyle,
                            ),
                            activeColor: AppColors.private,
                          ),
                          FormBuilderChoiceChip(
                            name: 'type',
                            initialValue: widget.tagEntity.map(
                              genericTag: (_) =>
                                  localizations.settingsTagsTypeTag,
                              personTag: (_) =>
                                  localizations.settingsTagsTypePerson,
                              storyTag: (_) => localizations
                                  .settingsTagsTypeStory, // 'STORY',
                            ),
                            decoration: InputDecoration(
                              labelText: localizations.settingsTagsTypeLabel,
                              labelStyle: labelStyle.copyWith(
                                height: 0.6,
                                fontFamily: 'Oswald',
                              ),
                            ),
                            selectedColor: widget.tagEntity.map(
                              genericTag: (tag) => getTagColor(tag),
                              personTag: (tag) => getTagColor(tag),
                              storyTag: (tag) => getTagColor(tag),
                            ),
                            runSpacing: 4,
                            spacing: 4,
                            labelStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              fontFamily: 'Oswald',
                            ),
                            options: [
                              FormBuilderChipOption(
                                value: 'TAG',
                                child: Text(
                                  localizations.settingsTagsTypeTag,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                              FormBuilderChipOption(
                                value: 'PERSON',
                                child: Text(
                                  localizations.settingsTagsTypePerson,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                              FormBuilderChipOption(
                                value: 'STORY',
                                child: Text(
                                  localizations.settingsTagsTypeStory,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Spacer(),
                          IconButton(
                            icon: const Icon(MdiIcons.trashCanOutline),
                            iconSize: 24,
                            tooltip: localizations.settingsTagsDeleteTooltip,
                            color: AppColors.appBarFgColor,
                            onPressed: () {
                              persistenceLogic.upsertTagEntity(
                                widget.tagEntity.copyWith(
                                  deletedAt: DateTime.now(),
                                ),
                              );
                              context.router.pop();
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
  }
}

class EditExistingTagPage extends StatelessWidget {
  final TagsService tagsService = getIt<TagsService>();
  final String tagEntityId;

  EditExistingTagPage({
    Key? key,
    @PathParam() required this.tagEntityId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    TagEntity? tagEntity = tagsService.getTagById(tagEntityId);

    if (tagEntity == null) {
      return const EmptyScaffoldWithTitle('');
    }

    return TagEditPage(tagEntity: tagEntity);
  }
}

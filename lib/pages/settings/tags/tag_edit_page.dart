import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/form_text_field.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TagEditPage extends StatefulWidget {
  const TagEditPage({
    Key? key,
    required this.tagEntity,
  }) : super(key: key);

  final TagEntity tagEntity;

  @override
  _TagEditPageState createState() {
    return _TagEditPageState();
  }
}

class _TagEditPageState extends State<TagEditPage> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                    child: Column(
                      children: <Widget>[
                        FormTextField(
                          initialValue: widget.tagEntity.tag,
                          labelText:
                              AppLocalizations.of(context)!.settingsTagsTagName,
                          name: 'tag',
                          key: const Key('tag_name_field'),
                        ),
                        FormBuilderSwitch(
                          name: 'private',
                          initialValue: widget.tagEntity.private,
                          title: Text(
                            AppLocalizations.of(context)!
                                .settingsTagsPrivateLabel,
                            style: formLabelStyle,
                          ),
                          activeColor: AppColors.private,
                        ),
                        FormBuilderSwitch(
                          name: 'inactive',
                          initialValue: widget.tagEntity.inactive,
                          title: Text(
                            AppLocalizations.of(context)!.settingsTagsHideLabel,
                            style: formLabelStyle,
                          ),
                          activeColor: AppColors.private,
                        ),
                        FormBuilderChoiceChip(
                          name: 'type',
                          initialValue: widget.tagEntity.map(
                            genericTag: (_) => AppLocalizations.of(context)!
                                .settingsTagsTypeTag,
                            personTag: (_) => AppLocalizations.of(context)!
                                .settingsTagsTypePerson,
                            storyTag: (_) => AppLocalizations.of(context)!
                                .settingsTagsTypeStory, // 'STORY',
                          ),
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!
                                .settingsTagsTypeLabel,
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
                            FormBuilderFieldOption(
                              value: 'TAG',
                              child: Text(
                                AppLocalizations.of(context)!
                                    .settingsTagsTypeTag,
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                            FormBuilderFieldOption(
                              value: 'PERSON',
                              child: Text(
                                AppLocalizations.of(context)!
                                    .settingsTagsTypePerson,
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                            FormBuilderFieldOption(
                              value: 'STORY',
                              child: Text(
                                AppLocalizations.of(context)!
                                    .settingsTagsTypeStory,
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
                        TextButton(
                          key: const Key('tag_save'),
                          onPressed: () async {
                            _formKey.currentState!.save();
                            if (_formKey.currentState!.validate()) {
                              final formData = _formKey.currentState?.value;
                              TagEntity newTagEntity =
                                  widget.tagEntity.copyWith(
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
                            }
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Text(
                              AppLocalizations.of(context)!
                                  .settingsTagsSaveLabel,
                              style: const TextStyle(
                                fontSize: 20,
                                fontFamily: 'Oswald',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(MdiIcons.trashCanOutline),
                          iconSize: 24,
                          tooltip: AppLocalizations.of(context)!
                              .settingsTagsDeleteTooltip,
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
      return const SizedBox.shrink();
    }

    return TagEditPage(tagEntity: tagEntity);
  }
}

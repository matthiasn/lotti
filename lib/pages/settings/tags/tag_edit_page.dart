import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/form_text_field.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TagEditPage extends StatefulWidget {
  const TagEditPage({
    super.key,
    required this.tagEntity,
  });

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
    final localizations = AppLocalizations.of(context)!;

    Future<void> onSavePressed() async {
      _formKey.currentState!.save();
      if (_formKey.currentState!.validate()) {
        final formData = _formKey.currentState?.value;

        if (formData != null) {
          final private = formData['private'] as bool? ?? false;
          final inactive = formData['inactive'] as bool? ?? false;

          var newTagEntity = widget.tagEntity.copyWith(
            tag: '${formData['tag']}'.trim(),
            private: private,
            inactive: inactive,
            updatedAt: DateTime.now(),
          );

          final type = formData['type'] as String;

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

          await persistenceLogic.upsertTagEntity(newTagEntity);
          await getIt<AppRouter>().pop();

          setState(() {
            dirty = false;
          });
        }
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: AppColors.entryCardColor,
                padding: const EdgeInsets.all(24),
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
                          FormBuilderChoiceChip<String>(
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
                              genericTag: getTagColor,
                              personTag: getTagColor,
                              storyTag: getTagColor,
                            ),
                            runSpacing: 4,
                            spacing: 4,
                            labelStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              fontFamily: 'Oswald',
                            ),
                            options: [
                              FormBuilderChipOption<String>(
                                value: 'TAG',
                                child: Text(
                                  localizations.settingsTagsTypeTag,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                              FormBuilderChipOption<String>(
                                value: 'PERSON',
                                child: Text(
                                  localizations.settingsTagsTypePerson,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                              FormBuilderChipOption<String>(
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
                      padding: const EdgeInsets.only(top: 16),
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
                              getIt<AppRouter>().pop();
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
  EditExistingTagPage({
    super.key,
    @PathParam() required this.tagEntityId,
  });

  final TagsService tagsService = getIt<TagsService>();
  final String tagEntityId;

  @override
  Widget build(BuildContext context) {
    final tagEntity = tagsService.getTagById(tagEntityId);

    if (tagEntity == null) {
      return const EmptyScaffoldWithTitle('');
    }

    return TagEditPage(tagEntity: tagEntity);
  }
}

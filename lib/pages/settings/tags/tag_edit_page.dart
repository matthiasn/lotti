import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/manual/widget/showcase_text_style.dart';
import 'package:lotti/features/manual/widget/showcase_with_widget.dart';
import 'package:lotti/features/tags/repository/tags_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/form_text_field.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/utils.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/settings/entity_detail_card.dart';
import 'package:lotti/widgets/settings/form/form_switch.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:showcaseview/showcaseview.dart';

class TagEditPage extends StatefulWidget {
  const TagEditPage({
    required this.tagEntity,
    this.newTag = false,
    super.key,
  });

  final TagEntity tagEntity;
  final bool newTag;

  @override
  State<TagEditPage> createState() {
    return _TagEditPageState();
  }
}

class _TagEditPageState extends State<TagEditPage> {
  final _tagNameKey = GlobalKey();
  final _tagPrivateKey = GlobalKey();
  final _tagHideKey = GlobalKey();
  final _tagTypeTagKey = GlobalKey();
  final _tagDeleteKey = GlobalKey();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();
  bool dirty = false;

  @override
  void initState() {
    super.initState();
    if (widget.newTag && widget.tagEntity.tag.isNotEmpty) {
      setState(() {
        dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    void maybePop() => Navigator.of(context).maybePop();

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

          await TagsRepository.upsertTagEntity(
            newTagEntity,
          );
          maybePop();

          setState(() {
            dirty = false;
          });
        }
      }
    }

    final errorColor = context.colorScheme.error;

    return Scaffold(
      appBar: TitleWidgetAppBar(
        title: IconButton(
          onPressed: () {
            ShowCaseWidget.of(context).startShowCase([
              _tagNameKey,
              _tagPrivateKey,
              _tagHideKey,
              _tagTypeTagKey,
              _tagDeleteKey,
            ]);
          },
          icon: const Icon(
            Icons.info_outline_rounded,
          ),
        ),
        actions: [
          if (dirty)
            TextButton(
              key: const Key(
                'tag_save',
              ),
              onPressed: onSavePressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                child: Text(
                  context.messages.settingsTagsSaveLabel,
                  style: saveButtonStyle(
                    Theme.of(
                      context,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          ShowcaseTitleText(titleText: context.messages.settingsTagsDefinition),
          EntityDetailCard(
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
                      ShowcaseWithWidget(
                        showcaseKey: _tagNameKey,
                        startNav: true,
                        description: ShowcaseTextStyle(
                          descriptionText:
                              context.messages.settingsTagsShowCaseNameTooltip,
                        ),
                        child: FormTextField(
                          initialValue: widget.tagEntity.tag,
                          labelText: context.messages.settingsTagsTagName,
                          name: 'tag',
                          key: const Key(
                            'tag_name_field',
                          ),
                          large: true,
                        ),
                      ),
                      inputSpacerSmall,
                      ShowcaseWithWidget(
                        showcaseKey: _tagPrivateKey,
                        description: ShowcaseTextStyle(
                          descriptionText: context
                              .messages.settingsTagsShowCasePrivateTooltip,
                        ),
                        child: FormSwitch(
                          name: 'private',
                          initialValue: widget.tagEntity.private,
                          title: context.messages.settingsTagsPrivateLabel,
                          activeColor: errorColor,
                        ),
                      ),
                      ShowcaseWithWidget(
                        showcaseKey: _tagHideKey,
                        description: ShowcaseTextStyle(
                          descriptionText:
                              context.messages.settingsTagsShowCaseHideTooltip,
                        ),
                        child: FormSwitch(
                          name: 'inactive',
                          initialValue: widget.tagEntity.inactive,
                          title: context.messages.settingsTagsHideLabel,
                          activeColor: errorColor,
                        ),
                      ),
                      inputSpacerSmall,
                      ShowcaseWithWidget(
                        showcaseKey: _tagTypeTagKey,
                        description: ShowcaseTextStyle(
                          descriptionText:
                              context.messages.settingsTagsShowCaseTypeTooltip,
                        ),
                        child: FormBuilderChoiceChips<String>(
                          name: 'type',
                          initialValue: widget.tagEntity.map(
                            genericTag: (_) =>
                                context.messages.settingsTagsTypeTag,
                            personTag: (_) =>
                                context.messages.settingsTagsTypePerson,
                            storyTag: (_) => context
                                .messages.settingsTagsTypeStory, // 'STORY',
                          ),
                          decoration: inputDecoration(
                            labelText: context.messages.settingsTagsTypeLabel,
                            themeData: Theme.of(context),
                          ),
                          selectedColor: widget.tagEntity.map(
                            genericTag: getTagColor,
                            personTag: getTagColor,
                            storyTag: getTagColor,
                          ),
                          runSpacing: 4,
                          spacing: 4,
                          options: [
                            FormBuilderChipOption<String>(
                              value: 'TAG',
                              child: Text(
                                context.messages.settingsTagsTypeTag,
                              ),
                            ),
                            FormBuilderChipOption<String>(
                              value: 'PERSON',
                              child: Text(
                                context.messages.settingsTagsTypePerson,
                              ),
                            ),
                            FormBuilderChipOption<String>(
                              value: 'STORY',
                              child: Text(
                                context.messages.settingsTagsTypeStory,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Spacer(),
                      ShowcaseWithWidget(
                        showcaseKey: _tagDeleteKey,
                        endNav: true,
                        description: ShowcaseTextStyle(
                          descriptionText: context
                              .messages.settingsTagsShowCaseDeleteTooltip,
                        ),
                        child: IconButton(
                          icon: Icon(
                            MdiIcons.trashCanOutline,
                          ),
                          iconSize: 24,
                          tooltip: context.messages.settingsTagsDeleteTooltip,
                          color: context.colorScheme.outline,
                          onPressed: () {
                            TagsRepository.upsertTagEntity(
                              widget.tagEntity.copyWith(
                                deletedAt: DateTime.now(),
                              ),
                            );
                            Navigator.of(context).maybePop();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EditExistingTagPage extends StatelessWidget {
  EditExistingTagPage({
    required this.tagEntityId,
    super.key,
  });

  final TagsService tagsService = getIt<TagsService>();
  final String tagEntityId;

  @override
  Widget build(BuildContext context) {
    final tagEntity = tagsService.getTagById(
      tagEntityId,
    );

    if (tagEntity == null) {
      return const EmptyScaffoldWithTitle(
        '',
      );
    }

    return ShowCaseWidget(
      builder: (context) => TagEditPage(
        tagEntity: tagEntity,
      ),
    );
  }
}

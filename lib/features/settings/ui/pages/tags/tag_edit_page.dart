import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/settings/ui/pages/form_text_field.dart';
import 'package:lotti/features/settings/ui/widgets/entity_detail_card.dart';
import 'package:lotti/features/settings/ui/widgets/form/form_switch.dart';
import 'package:lotti/features/tags/repository/tags_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/utils.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            title: Text(
              context.messages.settingsTagsDetailsLabel,
              style: appBarTextStyleNewLarge.copyWith(
                color: Theme.of(context).primaryColor,
              ),
            ),
            pinned: true,
            actions: [
              if (dirty)
                LottiTertiaryButton(
                  key: const Key(
                    'tag_save',
                  ),
                  label: context.messages.settingsTagsSaveLabel,
                  onPressed: onSavePressed,
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: EntityDetailCard(
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
                          labelText: context.messages.settingsTagsTagName,
                          name: 'tag',
                          key: const Key(
                            'tag_name_field',
                          ),
                          large: true,
                        ),
                        inputSpacerSmall,
                        FormSwitch(
                          name: 'private',
                          initialValue: widget.tagEntity.private,
                          title: context.messages.settingsTagsPrivateLabel,
                          activeColor: errorColor,
                        ),
                        FormSwitch(
                          name: 'inactive',
                          initialValue: widget.tagEntity.inactive,
                          title: context.messages.settingsTagsHideLabel,
                          activeColor: errorColor,
                        ),
                        inputSpacerSmall,
                        FormBuilderChoiceChips<String>(
                          name: 'type',
                          initialValue: () {
                            final t = widget.tagEntity;
                            return switch (t) {
                              GenericTag() =>
                                context.messages.settingsTagsTypeTag,
                              PersonTag() =>
                                context.messages.settingsTagsTypePerson,
                              StoryTag() =>
                                context.messages.settingsTagsTypeStory,
                              _ => context.messages.settingsTagsTypeTag,
                            };
                          }(),
                          decoration: inputDecoration(
                            labelText: context.messages.settingsTagsTypeLabel,
                            themeData: Theme.of(context),
                          ),
                          selectedColor: getTagColor(widget.tagEntity),
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
                        IconButton(
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

    return TagEditPage(
      tagEntity: tagEntity,
    );
  }
}

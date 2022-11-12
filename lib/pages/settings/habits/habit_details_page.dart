import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/form_text_field.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/settings/habits/habit_autocomplete_widget.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HabitDetailsPage extends StatefulWidget {
  const HabitDetailsPage({
    super.key,
    required this.habitDefinition,
  });

  final HabitDefinition habitDefinition;

  @override
  State<HabitDetailsPage> createState() {
    return _HabitDetailsPageState();
  }
}

class _HabitDetailsPageState extends State<HabitDetailsPage> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();
  bool dirty = false;

  @override
  Widget build(BuildContext context) {
    void maybePop() => Navigator.of(context).maybePop();
    final localizations = AppLocalizations.of(context)!;
    final item = widget.habitDefinition;

    Future<void> onSavePressed() async {
      _formKey.currentState!.save();
      if (_formKey.currentState!.validate()) {
        final formData = _formKey.currentState?.value;
        final private = formData?['private'] as bool? ?? false;
        final active = formData?['active'] as bool? ?? false;
        final activeFrom = formData?['active_from'] as DateTime?;
        final showFrom = formData?['show_from'] as DateTime?;
        final defaultStory = formData?['default_story_id'] as StoryTag?;

        final dataType = item.copyWith(
          name: '${formData!['name']}'.trim(),
          description: '${formData['description']}'.trim(),
          private: private,
          active: active,
          activeFrom: activeFrom,
          habitSchedule: HabitSchedule.daily(
            requiredCompletions: 1,
            showFrom: showFrom,
          ),
          defaultStoryId: defaultStory?.id,
        );

        await persistenceLogic.upsertEntityDefinition(dataType);
        setState(() {
          dirty = false;
        });

        maybePop();
      }
    }

    final isDaily = item.habitSchedule is DailyHabitSchedule;
    final showFrom = item.habitSchedule.mapOrNull(daily: (d) => d.showFrom);

    return Scaffold(
      backgroundColor: styleConfig().negspace,
      appBar: TitleAppBar(
        title: widget.habitDefinition.name,
        actions: [
          if (dirty)
            TextButton(
              key: const Key('habit_save'),
              onPressed: onSavePressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  AppLocalizations.of(context)!.settingsHabitsSaveLabel,
                  style: saveButtonStyle(),
                ),
              ),
            )
        ],
      ),
      body: SingleChildScrollView(
        child: StreamBuilder<List<TagEntity>>(
          stream: getIt<TagsService>().watchTags(),
          builder: (context, AsyncSnapshot<List<TagEntity>> snapshot) {
            final storyTags = snapshot.data?.whereType<StoryTag>().toList();

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                color: styleConfig().cardColor,
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
                            key: const Key('habit_name_field'),
                            initialValue: item.name,
                            labelText: AppLocalizations.of(context)!
                                .settingsHabitsNameLabel,
                            name: 'name',
                          ),
                          FormTextField(
                            key: const Key('habit_description_field'),
                            initialValue: item.description,
                            labelText: AppLocalizations.of(context)!
                                .settingsHabitsDescriptionLabel,
                            fieldRequired: false,
                            name: 'description',
                          ),
                          FormBuilderSwitch(
                            name: 'private',
                            initialValue: item.private,
                            title: Text(
                              AppLocalizations.of(context)!
                                  .settingsHabitsPrivateLabel,
                              style: formLabelStyle(),
                            ),
                            activeColor: styleConfig().private,
                          ),
                          FormBuilderSwitch(
                            name: 'active',
                            key: const Key('habit_active'),
                            initialValue: widget.habitDefinition.active,
                            title: Text(
                              localizations.dashboardActiveLabel,
                              style: formLabelStyle(),
                            ),
                            activeColor: styleConfig().starredGold,
                          ),
                          FormBuilderCupertinoDateTimePicker(
                            key: const Key('active_from'),
                            name: 'active_from',
                            alwaysUse24HourFormat: true,
                            inputType: CupertinoDateTimePickerInputType.date,
                            style: inputStyle().copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w300,
                            ),
                            decoration: InputDecoration(
                              labelText: localizations.habitActiveFromLabel,
                              labelStyle: labelStyle(),
                            ),
                          ),
                          if (isDaily)
                            FormBuilderCupertinoDateTimePicker(
                              name: 'show_from',
                              alwaysUse24HourFormat: true,
                              format: hhMmFormat,
                              inputType: CupertinoDateTimePickerInputType.time,
                              style: inputStyle().copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w300,
                              ),
                              initialValue: showFrom,
                              decoration: InputDecoration(
                                labelText: localizations.habitShowFromLabel,
                                labelStyle: labelStyle(),
                              ),
                              theme: datePickerTheme(),
                            ),
                          if (storyTags != null)
                            FormBuilderDropdown<StoryTag>(
                              name: 'default_story_id',
                              initialValue: item.defaultStoryId != null
                                  ? storyTags
                                      .where(
                                        (tag) => tag.id == item.defaultStoryId,
                                      )
                                      .first
                                  : null,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!
                                    .settingsHabitsStoryLabel,
                                labelStyle: formLabelStyle(),
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.close,
                                    color: styleConfig().primaryTextColor,
                                  ),
                                ),
                              ),
                              iconEnabledColor: styleConfig().primaryTextColor,
                              style: const TextStyle(fontSize: 40),
                              dropdownColor: styleConfig().cardColor,
                              items: storyTags.map((storyTag) {
                                return DropdownMenuItem(
                                  value: storyTag,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      storyTag.tag,
                                      style: TextStyle(
                                        fontSize: fontSizeMedium,
                                        color: styleConfig().primaryTextColor,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          HabitAutocompleteWidget(testAutoComplete),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(MdiIcons.trashCanOutline),
                            iconSize: settingsIconSize,
                            tooltip: AppLocalizations.of(context)!
                                .settingsHabitsDeleteTooltip,
                            color: styleConfig().secondaryTextColor,
                            onPressed: () async {
                              const deleteKey = 'deleteKey';
                              final result = await showModalActionSheet<String>(
                                context: context,
                                title: localizations.habitDeleteQuestion,
                                actions: [
                                  SheetAction(
                                    icon: Icons.warning,
                                    label: localizations.habitDeleteConfirm,
                                    key: deleteKey,
                                    isDestructiveAction: true,
                                    isDefaultAction: true,
                                  ),
                                ],
                              );

                              if (result == deleteKey) {
                                await persistenceLogic.upsertEntityDefinition(
                                  item.copyWith(deletedAt: DateTime.now()),
                                );

                                maybePop();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class EditHabitPage extends StatelessWidget {
  EditHabitPage({
    super.key,
    required this.habitId,
  });

  final JournalDb _db = getIt<JournalDb>();
  final String habitId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _db.watchHabitById(habitId),
      builder: (
        BuildContext context,
        AsyncSnapshot<HabitDefinition?> snapshot,
      ) {
        final habitDefinition = snapshot.data;

        if (habitDefinition == null) {
          return const EmptyScaffoldWithTitle('');
        }

        return HabitDetailsPage(
          habitDefinition: habitDefinition,
        );
      },
    );
  }
}

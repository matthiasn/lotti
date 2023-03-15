import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_cubit.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/form_text_field.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/settings/form/form_switch.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HabitDetailsPage extends StatelessWidget {
  const HabitDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocBuilder<HabitSettingsCubit, HabitSettingsState>(
      builder: (context, HabitSettingsState state) {
        final item = state.habitDefinition;
        final cubit = context.read<HabitSettingsCubit>();
        final isDaily = item.habitSchedule is DailyHabitSchedule;
        final showFrom = item.habitSchedule.mapOrNull(daily: (d) => d.showFrom);

        return Scaffold(
          backgroundColor: styleConfig().negspace,
          appBar: TitleAppBar(
            title: state.habitDefinition.name,
            actions: [
              if (state.dirty)
                TextButton(
                  key: const Key('habit_save'),
                  onPressed: cubit.onSavePressed,
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      FormBuilder(
                        key: state.formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onChanged: cubit.setDirty,
                        child: Column(
                          children: <Widget>[
                            FormTextField(
                              key: const Key('habit_name_field'),
                              initialValue: item.name,
                              labelText: AppLocalizations.of(context)!
                                  .settingsHabitsNameLabel,
                              name: 'name',
                            ),
                            inputSpacer,
                            FormTextField(
                              key: const Key('habit_description_field'),
                              initialValue: item.description,
                              labelText: AppLocalizations.of(context)!
                                  .settingsHabitsDescriptionLabel,
                              fieldRequired: false,
                              name: 'description',
                            ),
                            inputSpacer,
                            FormSwitch(
                              name: 'private',
                              initialValue: item.private,
                              title: localizations.settingsHabitsPrivateLabel,
                              activeColor: styleConfig().private,
                            ),
                            FormSwitch(
                              name: 'active',
                              key: const Key('habit_active'),
                              initialValue: state.habitDefinition.active,
                              title: localizations.dashboardActiveLabel,
                              activeColor: styleConfig().starredGold,
                            ),
                            inputSpacer,
                            FormBuilderCupertinoDateTimePicker(
                              key: const Key('active_from'),
                              name: 'active_from',
                              alwaysUse24HourFormat: true,
                              inputType: CupertinoDateTimePickerInputType.date,
                              style: inputStyle().copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w300,
                              ),
                              initialValue: item.activeFrom,
                              decoration: inputDecoration(
                                labelText: localizations.habitActiveFromLabel,
                              ),
                            ),
                            inputSpacer,
                            if (isDaily)
                              FormBuilderCupertinoDateTimePicker(
                                name: 'show_from',
                                alwaysUse24HourFormat: true,
                                format: hhMmFormat,
                                inputType:
                                    CupertinoDateTimePickerInputType.time,
                                style: inputStyle().copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w300,
                                ),
                                initialValue: showFrom,
                                decoration: inputDecoration(
                                  labelText: localizations.habitShowFromLabel,
                                ),
                                theme: datePickerTheme(),
                              ),
                            inputSpacer,
                            if (state.storyTags.isNotEmpty)
                              FormBuilderDropdown<StoryTag>(
                                name: 'default_story_id',
                                initialValue: state.defaultStory,
                                decoration: inputDecoration(
                                  labelText:
                                      localizations.settingsHabitsStoryLabel,
                                ),
                                iconEnabledColor:
                                    styleConfig().primaryTextColor,
                                style: const TextStyle(fontSize: 40),
                                dropdownColor: styleConfig().cardColor,
                                items: [
                                  DropdownMenuItem(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        '',
                                        style: TextStyle(
                                          fontSize: fontSizeMedium,
                                          color: styleConfig().primaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  ...state.storyTags.map((storyTag) {
                                    return DropdownMenuItem(
                                      value: storyTag,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          storyTag.tag,
                                          style: TextStyle(
                                            fontSize: fontSizeMedium,
                                            color:
                                                styleConfig().primaryTextColor,
                                          ),
                                        ),
                                      ),
                                    );
                                  })
                                ],
                              ),
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
                                final result =
                                    await showModalActionSheet<String>(
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
                                  await cubit.delete();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      // const HabitAutocompleteWrapper(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class EditHabitPage extends StatelessWidget {
  EditHabitPage({
    required this.habitId,
    super.key,
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

        return BlocProvider<HabitSettingsCubit>(
          create: (_) => HabitSettingsCubit(
            habitDefinition,
            context: context,
          ),
          child: const HabitDetailsPage(),
        );
      },
    );
  }
}

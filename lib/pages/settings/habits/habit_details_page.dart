import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_cubit.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/form_text_field.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:lotti/widgets/habits/habit_category.dart';
import 'package:lotti/widgets/habits/habit_dashboard.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:lotti/widgets/settings/entity_detail_card.dart';
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
          appBar: TitleAppBar(
            title: '',
            actions: [
              if (state.dirty)
                TextButton(
                  key: const Key('habit_save'),
                  onPressed: cubit.onSavePressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      AppLocalizations.of(context)!.settingsHabitsSaveLabel,
                      style: saveButtonStyle(Theme.of(context)),
                      semanticsLabel: 'Save Habit',
                    ),
                  ),
                )
            ],
          ),
          body: EntityDetailCard(
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
                        semanticsLabel: 'Habit name field',
                        large: true,
                      ),
                      inputSpacer,
                      FormTextField(
                        key: const Key('habit_description_field'),
                        initialValue: item.description,
                        labelText: AppLocalizations.of(context)!
                            .settingsHabitsDescriptionLabel,
                        fieldRequired: false,
                        name: 'description',
                        semanticsLabel: 'Habit description field',
                      ),
                      inputSpacer,
                      const SelectCategoryWidget(),
                      inputSpacer,
                      SelectDashboardWidget(),
                      inputSpacer,
                      FormSwitch(
                        name: 'priority',
                        key: const Key('habit_priority'),
                        semanticsLabel: 'Habit priority',
                        initialValue: state.habitDefinition.priority,
                        title: localizations.habitPriorityLabel,
                        activeColor: starredGold,
                      ),
                      FormSwitch(
                        name: 'private',
                        initialValue: item.private,
                        title: localizations.settingsHabitsPrivateLabel,
                        activeColor: Theme.of(context).colorScheme.error,
                      ),
                      FormSwitch(
                        name: 'archived',
                        key: const Key('habit_archived'),
                        initialValue: !state.habitDefinition.active,
                        title: localizations.habitArchivedLabel,
                        activeColor: Theme.of(context).colorScheme.outline,
                      ),
                      inputSpacer,
                      DateTimeField(
                        dateTime: item.activeFrom,
                        labelText: localizations.habitActiveFromLabel,
                        setDateTime: cubit.setActiveFrom,
                        mode: CupertinoDatePickerMode.date,
                      ),
                      inputSpacer,
                      if (isDaily)
                        DateTimeField(
                          dateTime: showFrom,
                          labelText: localizations.habitShowFromLabel,
                          setDateTime: cubit.setShowFrom,
                          mode: CupertinoDatePickerMode.time,
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
                        icon: Icon(MdiIcons.trashCanOutline),
                        iconSize: settingsIconSize,
                        tooltip: AppLocalizations.of(context)!
                            .settingsHabitsDeleteTooltip,
                        color: Theme.of(context).colorScheme.outline,
                        onPressed: () async {
                          const deleteKey = 'deleteKey';
                          final result = await showModalActionSheet<String>(
                            context: context,
                            title: localizations.habitDeleteQuestion,
                            actions: [
                              ModalSheetAction(
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

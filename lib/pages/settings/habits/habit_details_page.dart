import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_cubit.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/ui/widgets/habit_category.dart';
import 'package:lotti/features/habits/ui/widgets/habit_dashboard.dart';
import 'package:lotti/features/manual/widget/showcase_text_style.dart';
import 'package:lotti/features/manual/widget/showcase_with_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/form_text_field.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:lotti/widgets/settings/entity_detail_card.dart';
import 'package:lotti/widgets/settings/form/form_switch.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:showcaseview/showcaseview.dart';

class HabitDetailsPage extends StatefulWidget {
  const HabitDetailsPage({super.key});

  @override
  State<HabitDetailsPage> createState() => _HabitDetailsPageState();
}

class _HabitDetailsPageState extends State<HabitDetailsPage> {
  final _habitNameKey = GlobalKey();
  final _habitDescKey = GlobalKey();
  final _habitCateKey = GlobalKey();
  final _habitDashKey = GlobalKey();
  final _habitPriorKey = GlobalKey();
  final _habitPrivKey = GlobalKey();
  final _habitArchKey = GlobalKey();
  final _habitStartDateKey = GlobalKey();
  final _habitShowFromTimeKey = GlobalKey();
  final _habitAlertAtKey = GlobalKey();
  final _habitDeleKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HabitSettingsCubit, HabitSettingsState>(
      builder: (context, HabitSettingsState state) {
        final item = state.habitDefinition;
        final cubit = context.read<HabitSettingsCubit>();
        final isDaily = item.habitSchedule is DailyHabitSchedule;
        final showFrom = item.habitSchedule.mapOrNull(daily: (d) => d.showFrom);
        final alertAtTime =
            item.habitSchedule.mapOrNull(daily: (d) => d.alertAtTime);

        return Scaffold(
          appBar: TitleAppBar(
            title: '',
            actions: [
              IconButton(
                onPressed: () {
                  ShowCaseWidget.of(context).startShowCase([
                    _habitNameKey,
                    _habitDescKey,
                    _habitCateKey,
                    _habitDashKey,
                    _habitPriorKey,
                    _habitPrivKey,
                    _habitArchKey,
                    _habitStartDateKey,
                    _habitShowFromTimeKey,
                    _habitAlertAtKey,
                    _habitDeleKey,
                  ]);
                },
                icon: const Icon(
                  Icons.info_outline_rounded,
                ),
              ),
              if (state.dirty)
                TextButton(
                  key: const Key('habit_save'),
                  onPressed: cubit.onSavePressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      context.messages.settingsHabitsSaveLabel,
                      style: saveButtonStyle(Theme.of(context)),
                      semanticsLabel: 'Save Habit',
                    ),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            child: EntityDetailCard(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 10,
              ),
              child: Column(
                children: [
                  FormBuilder(
                    key: state.formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: cubit.setDirty,
                    child: Column(
                      children: <Widget>[
                        ShowcaseWithWidget(
                          description: ShowcaseTextStyle(
                            descriptionText: context
                                .messages.settingsHabitsShowCaseNameTooltip,
                          ),
                          startNav: true,
                          showcaseKey: _habitNameKey,
                          child: FormTextField(
                            key: const Key('habit_name_field'),
                            initialValue: item.name,
                            labelText: context.messages.settingsHabitsNameLabel,
                            name: 'name',
                            semanticsLabel: 'Habit name field',
                          ),
                        ),
                        inputSpacerSmall,
                        ShowcaseWithWidget(
                          description: ShowcaseTextStyle(
                            descriptionText: context
                                .messages.settingsHabitsShowCaseDescrTooltip,
                          ),
                          showcaseKey: _habitDescKey,
                          child: FormTextField(
                            key: const Key('habit_description_field'),
                            initialValue: item.description,
                            labelText:
                                context.messages.settingsHabitsDescriptionLabel,
                            fieldRequired: false,
                            name: 'description',
                            semanticsLabel: 'Habit description field',
                          ),
                        ),
                        inputSpacerSmall,
                        ShowcaseWithWidget(
                          description: ShowcaseTextStyle(
                            descriptionText: context
                                .messages.settingsHabitsShowCaseCatTooltip,
                          ),
                          showcaseKey: _habitCateKey,
                          child: const SelectCategoryWidget(),
                        ),
                        inputSpacerSmall,
                        ShowcaseWithWidget(
                          description: ShowcaseTextStyle(
                            descriptionText: context
                                .messages.settingsHabitsShowCaseDashTooltip,
                          ),
                          showcaseKey: _habitDashKey,
                          child: SelectDashboardWidget(),
                        ),
                        inputSpacerSmall,
                        ShowcaseWithWidget(
                          description: const Text('TODO'),
                          showcaseKey: _habitPriorKey,
                          child: FormSwitch(
                            name: 'priority',
                            key: const Key('habit_priority'),
                            semanticsLabel: 'Habit priority',
                            initialValue: state.habitDefinition.priority,
                            title: context.messages.habitPriorityLabel,
                            activeColor: starredGold,
                          ),
                        ),
                        ShowcaseWithWidget(
                          description: const Text('TODO'),
                          showcaseKey: _habitPrivKey,
                          child: FormSwitch(
                            name: 'private',
                            initialValue: item.private,
                            title: context.messages.settingsHabitsPrivateLabel,
                            activeColor: context.colorScheme.error,
                          ),
                        ),
                        ShowcaseWithWidget(
                          description: const Text('TODO'),
                          showcaseKey: _habitArchKey,
                          child: FormSwitch(
                            name: 'archived',
                            key: const Key('habit_archived'),
                            initialValue: !state.habitDefinition.active,
                            title: context.messages.habitArchivedLabel,
                            activeColor: context.colorScheme.outline,
                          ),
                        ),
                        inputSpacerSmall,
                        ShowcaseWithWidget(
                          description: const Text('TODO'),
                          showcaseKey: _habitStartDateKey,
                          child: DateTimeField(
                            dateTime: item.activeFrom,
                            labelText: context.messages.habitActiveFromLabel,
                            setDateTime: cubit.setActiveFrom,
                            mode: CupertinoDatePickerMode.date,
                          ),
                        ),
                        inputSpacerSmall,
                        if (isDaily) ...[
                          ShowcaseWithWidget(
                            description: const Text('TODO'),
                            showcaseKey: _habitShowFromTimeKey,
                            child: DateTimeField(
                              dateTime: showFrom,
                              labelText: context.messages.habitShowFromLabel,
                              setDateTime: cubit.setShowFrom,
                              mode: CupertinoDatePickerMode.time,
                            ),
                          ),
                          inputSpacerSmall,
                          ShowcaseWithWidget(
                            description: const Text('TODO'),
                            showcaseKey: _habitAlertAtKey,
                            child: DateTimeField(
                              dateTime: alertAtTime,
                              labelText: context.messages.habitShowAlertAtLabel,
                              setDateTime: cubit.setAlertAtTime,
                              clear: cubit.clearAlertAtTime,
                              mode: CupertinoDatePickerMode.time,
                            ),
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: IconButton(
                            icon: ShowcaseWithWidget(
                              description: const Text('TODO'),
                              endNav: true,
                              showcaseKey: _habitDeleKey,
                              child: Icon(MdiIcons.trashCanOutline),
                            ),
                            iconSize: settingsIconSize,
                            tooltip:
                                context.messages.settingsHabitsDeleteTooltip,
                            color: context.colorScheme.outline,
                            onPressed: () async {
                              const deleteKey = 'deleteKey';
                              final result = await showModalActionSheet<String>(
                                context: context,
                                title: context.messages.habitDeleteQuestion,
                                actions: [
                                  ModalSheetAction(
                                    icon: Icons.warning,
                                    label: context.messages.habitDeleteConfirm,
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
                        ),
                      ],
                    ),
                  ),
                  // const HabitAutocompleteWrapper(),
                ],
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

        return ShowCaseWidget(
          builder: (context) => BlocProvider<HabitSettingsCubit>(
            create: (_) => HabitSettingsCubit(
              habitDefinition,
              context: context,
            ),
            child: const HabitDetailsPage(),
          ),
        );
      },
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habit_settings_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_category.dart';
import 'package:lotti/features/habits/ui/widgets/habit_dashboard.dart';
import 'package:lotti/features/settings/ui/pages/form_text_field.dart';
import 'package:lotti/features/settings/ui/widgets/entity_detail_card.dart';
import 'package:lotti/features/settings/ui/widgets/form/form_switch.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HabitDetailsPage extends ConsumerWidget {
  const HabitDetailsPage({
    required this.habitId,
    super.key,
  });

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitSettingsControllerProvider(habitId));
    final controller =
        ref.read(habitSettingsControllerProvider(habitId).notifier);

    final item = state.habitDefinition;
    final isDaily = item.habitSchedule is DailyHabitSchedule;
    final showFrom = item.habitSchedule.mapOrNull(daily: (d) => d.showFrom);
    final alertAtTime =
        item.habitSchedule.mapOrNull(daily: (d) => d.alertAtTime);

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            title: Text(
              context.messages.settingsHabitsDetailsLabel,
              style: appBarTextStyleNewLarge.copyWith(
                color: Theme.of(context).primaryColor,
              ),
            ),
            pinned: true,
            actions: [
              if (state.dirty)
                LottiTertiaryButton(
                  key: const Key('habit_save'),
                  label: context.messages.settingsHabitsSaveLabel,
                  onPressed: () async {
                    final success = await controller.onSavePressed();
                    if (success && context.mounted) {
                      await Navigator.of(context).maybePop();
                    }
                  },
                ),
            ],
          ),
          SliverToBoxAdapter(
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
                    onChanged: controller.setDirty,
                    child: Column(
                      children: <Widget>[
                        FormTextField(
                          key: const Key('habit_name_field'),
                          initialValue: item.name,
                          labelText: context.messages.settingsHabitsNameLabel,
                          name: 'name',
                          semanticsLabel: 'Habit name field',
                        ),
                        inputSpacerSmall,
                        FormTextField(
                          key: const Key(
                            'habit_description_field',
                          ),
                          initialValue: item.description,
                          labelText:
                              context.messages.settingsHabitsDescriptionLabel,
                          fieldRequired: false,
                          name: 'description',
                          semanticsLabel: 'Habit description field',
                        ),
                        inputSpacerSmall,
                        SelectCategoryWidget(habitId: habitId),
                        inputSpacerSmall,
                        SelectDashboardWidget(habitId: habitId),
                        inputSpacerSmall,
                        FormSwitch(
                          name: 'priority',
                          key: const Key('habit_priority'),
                          semanticsLabel: 'Habit priority',
                          initialValue: state.habitDefinition.priority,
                          title: context.messages.habitPriorityLabel,
                          activeColor: starredGold,
                        ),
                        FormSwitch(
                          name: 'private',
                          initialValue: item.private,
                          title: context.messages.settingsHabitsPrivateLabel,
                          activeColor: context.colorScheme.error,
                        ),
                        FormSwitch(
                          name: 'archived',
                          key: const Key('habit_archived'),
                          initialValue: !state.habitDefinition.active,
                          title: context.messages.habitArchivedLabel,
                          activeColor: context.colorScheme.outline,
                        ),
                        inputSpacerSmall,
                        DateTimeField(
                          dateTime: item.activeFrom,
                          labelText: context.messages.habitActiveFromLabel,
                          setDateTime: controller.setActiveFrom,
                          mode: CupertinoDatePickerMode.date,
                        ),
                        inputSpacerSmall,
                        if (isDaily) ...[
                          DateTimeField(
                            dateTime: showFrom,
                            labelText: context.messages.habitShowFromLabel,
                            setDateTime: controller.setShowFrom,
                            mode: CupertinoDatePickerMode.time,
                          ),
                          inputSpacerSmall,
                          DateTimeField(
                            dateTime: alertAtTime,
                            labelText: context.messages.habitShowAlertAtLabel,
                            setDateTime: controller.setAlertAtTime,
                            clear: controller.clearAlertAtTime,
                            mode: CupertinoDatePickerMode.time,
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
                            icon: Icon(MdiIcons.trashCanOutline),
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
                                  ),
                                ],
                              );

                              if (result == deleteKey) {
                                await controller.delete();
                                if (context.mounted) {
                                  await Navigator.of(context).maybePop();
                                }
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
        ],
      ),
    );
  }
}

class EditHabitPage extends ConsumerWidget {
  const EditHabitPage({
    required this.habitId,
    super.key,
  });

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitAsync = ref.watch(habitByIdProvider(habitId));

    return habitAsync.when(
      data: (habitDefinition) {
        if (habitDefinition == null) {
          return const EmptyScaffoldWithTitle('');
        }
        return HabitDetailsPage(habitId: habitId);
      },
      loading: () => const EmptyScaffoldWithTitle(''),
      error: (_, __) => const EmptyScaffoldWithTitle(''),
    );
  }
}

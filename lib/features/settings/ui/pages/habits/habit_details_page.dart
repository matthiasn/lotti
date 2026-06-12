import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habit_settings_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_category.dart';
import 'package:lotti/features/habits/ui/widgets/habit_dashboard.dart';
import 'package:lotti/features/settings/ui/widgets/form/form_switch.dart';
import 'package:lotti/features/settings/ui/widgets/form/settings_form_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:lotti/widgets/settings/settings_date_time_field.dart';
import 'package:lotti/widgets/settings/settings_detail_scaffold.dart';
import 'package:lotti/widgets/settings/settings_form_action_bar.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';

/// Habit definition editor on the shared settings-detail kit.
///
/// The form mechanics are unchanged: a `FormBuilder` keyed by the
/// controller's `formKey` tracks dirty state via `onChanged`, and
/// [HabitSettingsController.onSavePressed] reads the form values on save.
/// Navigation (back, cancel, after save/delete) beams to
/// `/settings/habits` rather than popping — V2's desktop detail surface
/// mounts the page inline (no Navigator route to pop); on mobile the URL
/// change still pops the page off the Beamer stack.
class HabitDetailsPage extends ConsumerWidget {
  const HabitDetailsPage({
    required this.habitId,
    this.isCreateMode = false,
    super.key,
  });

  final String habitId;

  /// Create flow (`CreateHabitPage`) hides the destructive delete action
  /// and uses the create title/label.
  final bool isCreateMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final state = ref.watch(habitSettingsControllerProvider(habitId));
    final controller = ref.read(
      habitSettingsControllerProvider(habitId).notifier,
    );

    final item = state.habitDefinition;
    final isDaily = item.habitSchedule is DailyHabitSchedule;
    final showFrom = item.habitSchedule.mapOrNull(daily: (d) => d.showFrom);
    final alertAtTime = item.habitSchedule.mapOrNull(
      daily: (d) => d.alertAtTime,
    );

    Future<void> handleSave() async {
      final success = await controller.onSavePressed();
      if (success) {
        beamToNamed('/settings/habits');
      }
    }

    Future<void> handleDelete() async {
      const deleteKey = 'deleteKey';
      final result = await showModalActionSheet<String>(
        context: context,
        title: messages.habitDeleteQuestion,
        actions: [
          ModalSheetAction(
            icon: Icons.warning,
            label: messages.habitDeleteConfirm,
            key: deleteKey,
            isDestructiveAction: true,
          ),
        ],
      );

      if (result == deleteKey) {
        await controller.delete();
        beamToNamed('/settings/habits');
      }
    }

    final saveEnabled = state.dirty;

    return SettingsDetailScaffold(
      title: isCreateMode
          ? messages.settingsHabitsCreateTitle
          : messages.settingsHabitsDetailsLabel,
      onBack: () => beamToNamed('/settings/habits'),
      onSaveShortcut: () {
        if (saveEnabled) handleSave();
      },
      actionBar: SettingsFormActionBar(
        primaryLabel: isCreateMode
            ? messages.createButton
            : messages.saveButton,
        onPrimary: handleSave,
        primaryEnabled: saveEnabled,
        secondaryLabel: messages.cancelButton,
        onSecondary: () => beamToNamed('/settings/habits'),
        destructiveLabel: isCreateMode ? null : messages.deleteButton,
        onDestructive: isCreateMode ? null : handleDelete,
      ),
      children: [
        FormBuilder(
          key: state.formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: controller.setDirty,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsFormSection(
                title: messages.basicSettings,
                icon: Icons.settings_outlined,
                children: [
                  SettingsFormTextField(
                    key: const Key('habit_name_field'),
                    initialValue: item.name,
                    labelText: messages.settingsHabitsNameLabel,
                    name: 'name',
                    semanticsLabel: 'Habit name field',
                    autofocus: isCreateMode,
                  ),
                  SettingsFormTextField(
                    key: const Key('habit_description_field'),
                    initialValue: item.description,
                    labelText: messages.settingsHabitsDescriptionLabel,
                    fieldRequired: false,
                    multiline: true,
                    name: 'description',
                    semanticsLabel: 'Habit description field',
                  ),
                  SelectCategoryWidget(habitId: habitId),
                  SelectDashboardWidget(habitId: habitId),
                ],
              ),
              SettingsFormSection(
                title: messages.habitSectionOptionsTitle,
                icon: Icons.tune_rounded,
                children: [
                  FormSwitch(
                    name: 'priority',
                    key: const Key('habit_priority'),
                    semanticsLabel: 'Habit priority',
                    initialValue: item.priority,
                    title: messages.favoriteLabel,
                    icon: Icons.star_outline_rounded,
                  ),
                  FormSwitch(
                    name: 'private',
                    initialValue: item.private,
                    title: messages.privateLabel,
                    subtitle: messages.privateSwitchDescription,
                    icon: Icons.lock_outline,
                  ),
                  FormSwitch(
                    name: 'active',
                    key: const Key('habit_active'),
                    initialValue: item.active,
                    title: messages.activeLabel,
                    subtitle: messages.inactiveSwitchDescription,
                    icon: Icons.visibility_outlined,
                  ),
                ],
              ),
              SettingsFormSection(
                title: messages.habitSectionScheduleTitle,
                icon: Icons.schedule_rounded,
                children: [
                  SettingsDateTimeField(
                    dateTime: item.activeFrom,
                    labelText: messages.habitActiveFromLabel,
                    setDateTime: controller.setActiveFrom,
                    mode: CupertinoDatePickerMode.date,
                  ),
                  if (isDaily) ...[
                    SettingsDateTimeField(
                      dateTime: showFrom,
                      labelText: messages.habitShowFromLabel,
                      setDateTime: controller.setShowFrom,
                      mode: CupertinoDatePickerMode.time,
                    ),
                    SettingsDateTimeField(
                      dateTime: alertAtTime,
                      labelText: messages.habitShowAlertAtLabel,
                      setDateTime: controller.setAlertAtTime,
                      clear: controller.clearAlertAtTime,
                      mode: CupertinoDatePickerMode.time,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
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
      error: (_, _) => const EmptyScaffoldWithTitle(''),
    );
  }
}

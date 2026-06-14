import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/label_editor_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/settings/settings_color_picker_field.dart';
import 'package:lotti/widgets/settings/settings_detail_scaffold.dart';
import 'package:lotti/widgets/settings/settings_form_action_bar.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';

class LabelDetailsPage extends ConsumerStatefulWidget {
  const LabelDetailsPage({
    this.labelId,
    this.initialName,
    super.key,
  });

  final String? labelId; // Edit mode when non-null
  final String? initialName; // Create mode prefill when non-null

  bool get isCreateMode => labelId == null;

  @override
  ConsumerState<LabelDetailsPage> createState() => _LabelDetailsPageState();
}

class _LabelDetailsPageState extends ConsumerState<LabelDetailsPage> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  LabelEditorArgs? _args;
  bool _didSeedControllers = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController = TextEditingController();
    if (widget.isCreateMode) {
      _args = LabelEditorArgs(initialName: widget.initialName);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Create mode: no label stream needed
    if (widget.isCreateMode) {
      return _buildScaffold(
        context,
        controllerArgs: _args!,
        existingLabel: null,
      );
    }

    // Edit mode: watch label by id
    final repo = ref.watch(labelsRepositoryProvider);
    return StreamBuilder<LabelDefinition?>(
      stream: repo.watchLabel(widget.labelId!),
      builder: (context, snapshot) {
        final label = snapshot.data;
        // Wait for first label to arrive
        if (label == null) {
          return Scaffold(
            backgroundColor: context.designTokens.colors.background.level01,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        // Initialize args once per label id
        if (_args?.label?.id != label.id) {
          _args = LabelEditorArgs(label: label);
          _didSeedControllers = false; // re-seed when switching labels
        }
        return _buildScaffold(
          context,
          controllerArgs: _args!,
          existingLabel: label,
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    required LabelEditorArgs controllerArgs,
    required LabelDefinition? existingLabel,
  }) {
    final messages = context.messages;
    final title = widget.isCreateMode
        ? messages.settingsLabelsCreateTitle
        : messages.settingsLabelsEditTitle;

    final controllerProvider = labelEditorControllerProvider(controllerArgs);
    final state = ref.watch(controllerProvider);
    // Seed controllers once from state to avoid clobbering user edits on rebuilds.
    if (!_didSeedControllers) {
      _nameController.value = TextEditingValue(
        text: state.name,
        selection: TextSelection.collapsed(offset: state.name.length),
      );
      final descText = state.description ?? '';
      _descriptionController.value = TextEditingValue(
        text: descText,
        selection: TextSelection.collapsed(offset: descText.length),
      );
      _didSeedControllers = true;
    }

    final controller = ref.read(controllerProvider.notifier);

    Future<void> handleSave() async {
      final result = await controller.save();
      if (!context.mounted) return;
      if (result != null) {
        context.showToast(
          tone: DesignSystemToastTone.success,
          title: messages.saveSuccessful,
        );
        // Beam back to the list rather than popping — V2's desktop
        // detail surface is rendered inline (no Navigator route to
        // pop); the URL change still pops the detail page on mobile.
        beamToNamed('/settings/labels');
      }
    }

    void handleDelete() {
      final label = existingLabel;
      if (label == null) return;
      // Capture the page context for navigation/snackbar after dialog closes.
      final pageContext = context;
      showDialog<bool>(
        context: pageContext,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.messages.settingsLabelsDeleteConfirmTitle),
          content: Text(
            dialogContext.messages.settingsLabelsDeleteConfirmMessage(
              label.name,
            ),
          ),
          actions: [
            DesignSystemButton(
              label: dialogContext.messages.cancelButton,
              variant: DesignSystemButtonVariant.secondary,
              onPressed: () => Navigator.pop(dialogContext),
            ),
            DesignSystemButton(
              variant: DesignSystemButtonVariant.danger,
              onPressed: () async {
                // Close the dialog using its own context
                Navigator.pop(dialogContext);
                await ref.read(labelsRepositoryProvider).deleteLabel(label.id);
                if (!mounted || !pageContext.mounted) return;
                // Beam back to the list rather than popping — see
                // [handleSave] above for the V2-vs-mobile rationale.
                beamToNamed('/settings/labels');
                if (!mounted || !pageContext.mounted) return;
                pageContext.showToast(
                  tone: DesignSystemToastTone.success,
                  title: pageContext.messages.settingsLabelsDeleteSuccess(
                    label.name,
                  ),
                );
              },
              label: dialogContext.messages.settingsLabelsDeleteConfirmAction,
            ),
          ],
        ),
      );
    }

    // Gate Save on dirty state like every sibling editor: a pristine
    // editor shows the quiet disabled pill. In create mode a non-empty
    // name already counts as something worth saving.
    final dirty =
        state.hasChanges ||
        (widget.isCreateMode && state.name.trim().isNotEmpty);
    final saveEnabled =
        !state.isSaving && state.name.trim().isNotEmpty && dirty;
    final tokens = context.designTokens;

    return SettingsDetailScaffold(
      title: title,
      onBack: () => beamToNamed('/settings/labels'),
      onSaveShortcut: () {
        if (saveEnabled) handleSave();
      },
      actionBar: SettingsFormActionBar(
        primaryLabel: widget.isCreateMode
            ? messages.createButton
            : messages.saveButton,
        onPrimary: handleSave,
        primaryEnabled: saveEnabled,
        secondaryLabel: messages.cancelButton,
        onSecondary: () => beamToNamed('/settings/labels'),
      ),
      deleteLabel: widget.isCreateMode ? null : messages.deleteButton,
      onDelete: widget.isCreateMode ? null : handleDelete,
      deleteEnabled: !state.isSaving,
      children: [
        SettingsFormSection(
          title: messages.basicSettings,
          children: [
            DesignSystemTextInput(
              controller: _nameController,
              label: messages.settingsLabelsNameLabel,
              hintText: messages.settingsLabelsNameHint,
              autofocus: widget.isCreateMode,
              textCapitalization: TextCapitalization.sentences,
              onChanged: controller.setName,
            ),
            DesignSystemTextarea(
              controller: _descriptionController,
              label: messages.settingsLabelsDescriptionLabel,
              hintText: messages.settingsLabelsDescriptionHint,
              onChanged: controller.setDescription,
              minLines: 2,
              maxLines: 4,
            ),
            // Color is a basic property, not a chapter — the categories
            // editor places it here too.
            _buildColorPicker(context, controller, state),
          ],
        ),
        SettingsFormSection(
          title: messages.habitSectionOptionsTitle,
          children: [
            SettingsSwitchRow(
              title: messages.privateLabel,
              subtitle: messages.privateSwitchDescription,
              icon: Icons.lock_outline,
              value: state.isPrivate,
              onChanged: (value) =>
                  controller.setPrivate(isPrivateValue: value),
            ),
          ],
        ),
        SettingsFormSection(
          title: messages.settingsLabelsCategoriesHeading,
          children: [
            _buildApplicableCategories(context, controller, state),
          ],
        ),
        if (state.errorMessage != null)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.step4),
            child: Text(
              state.errorMessage!,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.alert.error.defaultColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildColorPicker(
    BuildContext context,
    LabelEditorController controller,
    LabelEditorState state,
  ) {
    return SettingsColorPickerField(
      // Inside the multi-field Basic settings card the field needs its
      // own label.
      label: context.messages.colorLabel,
      color: colorFromCssHex(
        state.colorHex,
        substitute: Theme.of(context).colorScheme.primary,
      ),
      onColorChanged: controller.setColor,
    );
  }

  Widget _buildApplicableCategories(
    BuildContext context,
    LabelEditorController controller,
    LabelEditorState state,
  ) {
    final tokens = context.designTokens;
    final cache = getIt<EntitiesCacheService>();
    final chips =
        state.selectedCategoryIds
            .map(cache.getCategoryById)
            .whereType<CategoryDefinition>()
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chips.isEmpty)
          Text(
            context.messages.settingsLabelsCategoriesNone,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          )
        else
          Wrap(
            spacing: tokens.spacing.step2,
            runSpacing: tokens.spacing.step2,
            children: [
              for (final category in chips)
                Builder(
                  builder: (context) {
                    final bg = colorFromCssHex(
                      category.color,
                      substitute: Theme.of(context).colorScheme.primary,
                    );
                    final isDark =
                        ThemeData.estimateBrightnessForColor(bg) ==
                        Brightness.dark;
                    final fg = isDark ? Colors.white : Colors.black;
                    return InputChip(
                      label: Text(category.name),
                      labelStyle: tokens.typography.styles.others.caption
                          .copyWith(color: fg),
                      backgroundColor: bg,
                      onDeleted: () => controller.removeCategoryId(category.id),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      deleteIconColor: fg,
                      deleteButtonTooltipMessage: context
                          .messages
                          .settingsLabelsCategoriesRemoveTooltip,
                    );
                  },
                ),
            ],
          ),
        SizedBox(height: tokens.spacing.step3),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DesignSystemButton(
            label: context.messages.settingsLabelsCategoriesAdd,
            leadingIcon: Icons.add,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: () async {
              final result = await showCategoryMultiPicker(
                context: context,
                title: context.messages.settingsLabelsCategoriesAdd,
                initialSelectedIds: state.selectedCategoryIds,
              );
              if (result == null) return;
              // Add-only: the chips own removal via onDeleted.
              result.ids.forEach(controller.addCategoryId);
            },
          ),
        ),
      ],
    );
  }
}

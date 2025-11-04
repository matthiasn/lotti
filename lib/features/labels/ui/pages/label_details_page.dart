import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/features/labels/constants/label_color_presets.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/label_editor_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:lotti/widgets/form/lotti_text_field.dart';
import 'package:lotti/widgets/ui/form_bottom_bar.dart';

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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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
    final title = widget.isCreateMode
        ? context.messages.settingsLabelsCreateTitle
        : context.messages.settingsLabelsEditTitle;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.messages.saveSuccessful)),
        );
        Navigator.of(context).pop();
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
            dialogContext.messages
                .settingsLabelsDeleteConfirmMessage(label.name),
          ),
          actions: [
            LottiTertiaryButton(
              onPressed: () => Navigator.pop(dialogContext),
              label: dialogContext.messages.cancelButton,
            ),
            LottiTertiaryButton(
              onPressed: () async {
                // Close the dialog using its own context
                Navigator.pop(dialogContext);
                await ref.read(labelsRepositoryProvider).deleteLabel(label.id);
                if (!mounted || !pageContext.mounted) return;
                // Pop the details page and show a snackbar using the page context
                Navigator.of(pageContext).pop();
                if (!mounted || !pageContext.mounted) return;
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      pageContext.messages
                          .settingsLabelsDeleteSuccess(label.name),
                    ),
                  ),
                );
              },
              label: dialogContext.messages.settingsLabelsDeleteConfirmAction,
              isDestructive: true,
            ),
          ],
        ),
      );
    }

    final saveEnabled = !state.isSaving && state.name.trim().isNotEmpty;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
          if (saveEnabled) handleSave();
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (saveEnabled) handleSave();
        },
      },
      child: Scaffold(
        backgroundColor: context.colorScheme.surface,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(
                title,
                style: appBarTextStyleNewLarge.copyWith(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              pinned: true,
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildNameAndDescription(context, controller, state),
                  const SizedBox(height: 24),
                  _buildColorPicker(context, controller, state),
                  const SizedBox(height: 24),
                  _buildApplicableCategories(context, controller, state),
                  const SizedBox(height: 24),
                  _buildPrivacySwitch(context, controller, state),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                  const SizedBox(height: 80), // space for bottom bar
                ]),
              ),
            ),
          ],
        ),
        bottomNavigationBar: FormBottomBar(
          leftButton: widget.isCreateMode
              ? null
              : LottiTertiaryButton(
                  onPressed: state.isSaving ? null : handleDelete,
                  icon: Icons.delete_outline,
                  label: context.messages.deleteButton,
                  isDestructive: true,
                ),
          rightButtons: [
            LottiSecondaryButton(
              onPressed: () => Navigator.of(context).pop(),
              label: context.messages.cancelButton,
            ),
            LottiPrimaryButton(
              onPressed: saveEnabled ? handleSave : null,
              label: widget.isCreateMode
                  ? context.messages.createButton
                  : context.messages.saveButton,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameAndDescription(
    BuildContext context,
    LabelEditorController controller,
    LabelEditorState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LottiTextField(
          controller: _nameController,
          labelText: context.messages.settingsLabelsNameLabel,
          hintText: context.messages.settingsLabelsNameHint,
          autofocus: widget.isCreateMode,
          textCapitalization: TextCapitalization.sentences,
          onChanged: controller.setName,
        ),
        const SizedBox(height: 16),
        LottiTextArea(
          controller: _descriptionController,
          labelText: context.messages.settingsLabelsDescriptionLabel,
          hintText: context.messages.settingsLabelsDescriptionHint,
          onChanged: controller.setDescription,
          minLines: 2,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildColorPicker(
    BuildContext context,
    LabelEditorController controller,
    LabelEditorState state,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.settingsLabelsColorHeading,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          padding: const EdgeInsets.all(12),
          child: ColorPicker(
            color: colorFromCssHex(
              state.colorHex,
              substitute: theme.colorScheme.primary,
            ),
            onColorChanged: controller.setColor,
            selectedPickerTypeColor: context.colorScheme.primary,
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.custom: true,
              ColorPickerType.wheel: true,
              ColorPickerType.accent: false,
              ColorPickerType.primary: true,
              ColorPickerType.bw: false,
              ColorPickerType.both: false,
            },
            customColorSwatchesAndNames: {
              for (final preset in labelColorPresets)
                ColorTools.createPrimarySwatch(
                  colorFromCssHex(
                    preset.hex,
                    substitute: Colors.blue,
                  ),
                ): preset.name,
            },
            pickerTypeLabels: <ColorPickerType, String>{
              ColorPickerType.custom:
                  context.messages.settingsLabelsColorSubheading,
              ColorPickerType.wheel: context.messages.customColor,
            },
            colorNameTextStyle: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildApplicableCategories(
    BuildContext context,
    LabelEditorController controller,
    LabelEditorState state,
  ) {
    final theme = Theme.of(context);
    final cache = getIt<EntitiesCacheService>();
    final chips = state.selectedCategoryIds
        .map(cache.getCategoryById)
        .whereType<CategoryDefinition>()
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.settingsLabelsCategoriesHeading,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (chips.isEmpty)
          Text(
            context.messages.settingsLabelsCategoriesNone,
            style: theme.textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in chips)
                Builder(builder: (context) {
                  final bg = colorFromCssHex(
                    category.color,
                    substitute: Theme.of(context).colorScheme.primary,
                  );
                  final isDark = ThemeData.estimateBrightnessForColor(bg) ==
                      Brightness.dark;
                  final fg = isDark ? Colors.white : Colors.black;
                  return InputChip(
                    label: Text(category.name),
                    labelStyle:
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: fg,
                            ),
                    backgroundColor: bg,
                    onDeleted: () => controller.removeCategoryId(category.id),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    deleteIconColor: fg,
                    deleteButtonTooltipMessage:
                        context.messages.settingsLabelsCategoriesRemoveTooltip,
                  );
                }),
            ],
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: Text(context.messages.settingsLabelsCategoriesAdd),
          onPressed: () async {
            final result = await showModalBottomSheet<List<CategoryDefinition>>(
              context: context,
              isScrollControlled: true,
              useRootNavigator: true,
              builder: (context) => CategorySelectionModalContent(
                onCategorySelected: (_) {},
                multiSelect: true,
                initiallySelectedCategoryIds: state.selectedCategoryIds,
              ),
            );
            if (result != null && result.isNotEmpty) {
              for (final cat in result) {
                controller.addCategoryId(cat.id);
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildPrivacySwitch(
    BuildContext context,
    LabelEditorController controller,
    LabelEditorState state,
  ) {
    return SwitchListTile.adaptive(
      value: state.isPrivate,
      onChanged: (value) => controller.setPrivate(isPrivateValue: value),
      title: Text(context.messages.settingsLabelsPrivateTitle),
      subtitle: Text(
        context.messages.settingsLabelsPrivateDescription,
      ),
    );
  }
}

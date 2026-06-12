import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/ui/profile_selector.dart';
import 'package:lotti/features/agents/ui/template_selector.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/category_details_controller.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_picker.dart';
import 'package:lotti/features/categories/ui/widgets/category_correction_examples.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_display.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_picker.dart';
import 'package:lotti/features/categories/ui/widgets/category_language_dropdown.dart';
import 'package:lotti/features/categories/ui/widgets/category_name_field.dart';
import 'package:lotti/features/categories/ui/widgets/category_speech_dictionary.dart';
import 'package:lotti/features/categories/ui/widgets/category_switch_tiles.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/language_selection_modal_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/settings/settings_detail_scaffold.dart';
import 'package:lotti/widgets/settings/settings_form_action_bar.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';

part 'category_details_form_sections.dart';

/// Category Details Page with AI Settings
///
/// This page allows editing of category details including:
/// - Basic settings (name, color, privacy, active status)
/// - Default language selection
/// - Allowed AI models/prompts
/// - Automatic prompt configuration
///
/// Both create and edit mode render inside the shared
/// [SettingsDetailScaffold] (header with back affordance, Cmd/Ctrl+S,
/// sticky glass [SettingsFormActionBar]).
class CategoryDetailsPage extends ConsumerStatefulWidget {
  const CategoryDetailsPage({
    this.categoryId,
    super.key,
  });

  final String? categoryId;

  bool get isCreateMode => categoryId == null;

  @override
  ConsumerState<CategoryDetailsPage> createState() =>
      _CategoryDetailsPageState();
}

class _CategoryDetailsPageState extends ConsumerState<CategoryDetailsPage> {
  late TextEditingController _nameController;
  // Track input via controller; avoid re-seeding on rebuilds to prevent selection jumps.
  Color? _selectedColor; // Only used in create mode
  CategoryIcon? _selectedIcon; // Only used in create mode

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncFormWithCategory(CategoryDefinition category) {
    // Only update the controller when its current text differs from the model.
    // This avoids clobbering the user's cursor/selection on each rebuild.
    final newText = category.name;
    if (_nameController.text != newText) {
      // Collapse to end to keep UX consistent when external changes arrive.
      _nameController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  Widget _buildCreateMode(BuildContext context) {
    return SettingsDetailScaffold(
      title: context.messages.createCategoryTitle,
      // Beam to the list URL rather than `Navigator.pop`. V2's desktop
      // detail surface mounts the page inline (no Navigator route was
      // pushed), so popping is a no-op there; on mobile the URL change
      // still pops the detail page off the Beamer stack.
      onBack: () => beamToNamed('/settings/categories'),
      onSaveShortcut: _handleCreate,
      actionBar: SettingsFormActionBar(
        primaryLabel: context.messages.createButton,
        onPrimary: _handleCreate,
        secondaryLabel: context.messages.cancelButton,
        onSecondary: () => beamToNamed('/settings/categories'),
      ),
      children: [
        // Creation asks only for what `createCategory` persists: name,
        // color, icon. Privacy/active/AI defaults are configured on the
        // edit page afterwards — no disabled placeholder controls.
        SettingsFormSection(
          title: context.messages.basicSettings,
          icon: Icons.settings_outlined,
          children: [
            _buildNameField(),
            _buildColorPicker(),
            _buildIconPicker(),
          ],
        ),
      ],
    );
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.categoryNameRequired,
      );
      return;
    }

    final repository = ref.read(categoryRepositoryProvider);
    try {
      final created = await repository.createCategory(
        name: name,
        color: _selectedColor != null
            ? colorToCssHex(_selectedColor!)
            : colorToCssHex(Colors.blue),
        icon: _selectedIcon,
      );

      if (mounted) {
        // Land in the new category's editor: creation only captures
        // name/color/icon, everything else (privacy, language, AI
        // defaults) lives on the edit page. Beaming (not pushing) keeps
        // V2's inline desktop pane in sync.
        beamToNamed('/settings/categories/${created.id}');
      }
    } catch (e) {
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.categoryCreationError,
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (widget.isCreateMode) {
      return _handleCreate();
    }

    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    await controller.saveChanges();

    if (!mounted) return;

    // Check if there was an error during save
    final state = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!),
    );
    if (state.errorMessage != null) {
      // Error is already displayed in the UI via ErrorStateWidget
      return;
    }

    // Success — surface a toast and beam to the list. Beaming (rather
    // than popping) keeps V2's desktop inline panel in sync; mobile's
    // Beamer stack reduces to the list page automatically.
    context.showToast(
      tone: DesignSystemToastTone.success,
      title: context.messages.saveSuccessful,
    );
    beamToNamed('/settings/categories');
  }

  @override
  Widget build(BuildContext context) {
    // For create mode, we don't need the controller yet
    if (widget.isCreateMode) {
      return _buildCreateMode(context);
    }

    // For edit mode, watch the category details
    final state = ref.watch(
      categoryDetailsControllerProvider(widget.categoryId!),
    );
    final category = state.category;

    if (category == null && !state.isLoading) {
      return SettingsDetailScaffold(
        title: context.messages.settingsCategoriesDetailsLabel,
        onBack: () => beamToNamed('/settings/categories'),
        children: [
          Center(
            child: Text(context.messages.categoryNotFound),
          ),
        ],
      );
    }

    if (category != null) {
      _syncFormWithCategory(category);
    }

    final saveEnabled = !state.isSaving && state.hasChanges;

    return SettingsDetailScaffold(
      title: context.messages.settingsCategoriesDetailsLabel,
      onBack: () => beamToNamed('/settings/categories'),
      onSaveShortcut: () {
        if (saveEnabled) _handleSave();
      },
      actionBar: SettingsFormActionBar(
        primaryLabel: context.messages.saveButton,
        onPrimary: _handleSave,
        primaryEnabled: saveEnabled,
        secondaryLabel: context.messages.cancelButton,
        onSecondary: () => beamToNamed('/settings/categories'),
        destructiveLabel: context.messages.deleteButton,
        onDestructive: _showDeleteDialog,
        destructiveEnabled: !state.isSaving,
      ),
      children: [
        if (state.errorMessage != null)
          ErrorStateWidget(
            error: state.errorMessage!,
            mode: ErrorDisplayMode.inline,
          ),
        if (state.isLoading && category == null)
          const Center(
            child: CircularProgressIndicator(),
          )
        else if (category != null) ...[
          SettingsFormSection(
            title: context.messages.basicSettings,
            icon: Icons.settings_outlined,
            children: [
              _buildNameField(),
              _buildColorPicker(),
              _buildIconPicker(category: category),
              _buildSwitchTiles(category),
            ],
          ),
          SettingsFormSection(
            title: context.messages.taskLanguageLabel,
            icon: Icons.language_outlined,
            description: context.messages.categoryDefaultLanguageDescription,
            children: [
              _buildLanguageDropdown(category),
            ],
          ),
          SettingsFormSection(
            title: context.messages.categoryAiDefaultsTitle,
            icon: Icons.smart_toy_outlined,
            description: context.messages.categoryAiDefaultsDescription,
            children: [
              _buildDefaultProfilePicker(category),
              _buildDefaultTemplatePicker(category),
            ],
          ),
          SettingsFormSection(
            title: context.messages.speechDictionarySectionTitle,
            icon: Icons.spellcheck_outlined,
            description: context.messages.speechDictionarySectionDescription,
            children: [
              _buildSpeechDictionary(category),
            ],
          ),
          // Correction examples render their own header + list chrome.
          _buildCorrectionExamples(category),
        ],
      ],
    );
  }

  Widget _buildColorPicker() {
    if (widget.isCreateMode) {
      // For create mode, we need local state since there's no category yet
      return CategoryColorPicker(
        selectedColor: _selectedColor,
        onColorChanged: (color) {
          setState(() {
            _selectedColor = color;
          });
        },
      );
    }

    // For edit mode, derive color from category state
    final state = ref.watch(
      categoryDetailsControllerProvider(widget.categoryId!),
    );
    final category = state.category;
    final selectedColor = category != null
        ? colorFromCssHex(category.color)
        : null;

    return CategoryColorPicker(
      selectedColor: selectedColor,
      onColorChanged: (color) {
        ref
            .read(
              categoryDetailsControllerProvider(widget.categoryId!).notifier,
            )
            .updateFormField(color: colorToCssHex(color));
      },
    );
  }

  Widget _buildIconPicker({CategoryDefinition? category}) {
    final tokens = context.designTokens;
    final isCreateMode = category == null;
    final icon = isCreateMode ? _selectedIcon : category.icon;
    final color = isCreateMode
        ? (_selectedColor ?? Colors.blue)
        : colorFromCssHex(category.color, substitute: Colors.blue);
    final iconDisplayName =
        icon?.displayName ?? CategoryIconStrings.chooseIconText;
    final hintText = isCreateMode
        ? CategoryIconStrings.createModeIconHint
        : CategoryIconStrings.iconSelectionHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          CategoryIconStrings.iconLabel,
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        InkWell(
          onTap: () => _showIconPicker(isCreateMode ? null : category.icon),
          borderRadius: BorderRadius.circular(tokens.radii.m),
          child: Container(
            padding: EdgeInsets.all(tokens.spacing.step5),
            decoration: BoxDecoration(
              border: Border.all(color: tokens.colors.decorative.level01),
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
            child: Row(
              children: [
                if (isCreateMode)
                  Container(
                    width: CategoryIconConstants.defaultIconSize,
                    height: CategoryIconConstants.defaultIconSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color,
                        width: CategoryIconConstants.borderWidth,
                      ),
                    ),
                    child: Center(
                      child: icon != null
                          ? Icon(
                              icon.iconData,
                              color: color,
                              size: CategoryIconConstants.standardIconSize,
                            )
                          : Icon(
                              Icons.category,
                              color: tokens.colors.text.mediumEmphasis,
                              size: CategoryIconConstants.standardIconSize,
                            ),
                    ),
                  )
                else
                  CategoryIconDisplay(
                    category: category,
                  ),
                SizedBox(width: tokens.spacing.step5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        iconDisplayName,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                            ),
                      ),
                      SizedBox(height: tokens.spacing.step1),
                      Text(
                        hintText,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: tokens.spacing.step6,
                  color: tokens.colors.text.lowEmphasis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showIconPicker(CategoryIcon? selectedIcon) async {
    final result = await showDialog<CategoryIcon>(
      context: context,
      builder: (context) => CategoryIconPicker(
        selectedIcon: selectedIcon,
      ),
    );

    if (result != null) {
      if (widget.isCreateMode) {
        setState(() {
          _selectedIcon = result;
        });
      } else {
        ref
            .read(
              categoryDetailsControllerProvider(widget.categoryId!).notifier,
            )
            .updateFormField(icon: result);
      }
    }
  }

  void _showDeleteDialog() {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.messages.categoryDeleteTitle),
        content: Text(context.messages.categoryDeleteConfirmation),
        actions: [
          LottiTertiaryButton(
            onPressed: () => Navigator.of(context).pop(),
            label: context.messages.cancelButton,
          ),
          LottiTertiaryButton(
            onPressed: () async {
              // Pop the confirm dialog first, then beam back to the
              // list once the row is gone.
              Navigator.of(context).pop();
              final controller = ref.read(
                categoryDetailsControllerProvider(widget.categoryId!).notifier,
              );
              await controller.deleteCategory();
              if (context.mounted) {
                beamToNamed('/settings/categories');
              }
            },
            label: context.messages.categoryDeleteConfirm,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

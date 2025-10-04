import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/category_details_controller.dart';
import 'package:lotti/features/categories/ui/widgets/category_automatic_prompts.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_picker.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_display.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_picker.dart';
import 'package:lotti/features/categories/ui/widgets/category_language_dropdown.dart';
import 'package:lotti/features/categories/ui/widgets/category_name_field.dart';
import 'package:lotti/features/categories/ui/widgets/category_prompt_selection.dart';
import 'package:lotti/features/categories/ui/widgets/category_switch_tiles.dart';
import 'package:lotti/features/tasks/ui/widgets/language_selection_modal_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';
import 'package:lotti/widgets/ui/form_bottom_bar.dart';

/// Category Details Page with AI Settings
///
/// This page allows editing of category details including:
/// - Basic settings (name, color, privacy, active status)
/// - Default language selection
/// - Allowed AI models/prompts
/// - Automatic prompt configuration
class CategoryDetailsPage extends ConsumerStatefulWidget {
  const CategoryDetailsPage({
    this.categoryId,
    super.key,
  });

  final String? categoryId;

  static const String routeName = '/settings/categories/details';

  bool get isCreateMode => categoryId == null;

  @override
  ConsumerState<CategoryDetailsPage> createState() =>
      _CategoryDetailsPageState();
}

class _CategoryDetailsPageState extends ConsumerState<CategoryDetailsPage> {
  late TextEditingController _nameController;
  String? _lastSyncedName;
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
    // Update name controller only if the name has changed externally
    if (_lastSyncedName != category.name) {
      _lastSyncedName = category.name;
      _nameController.text = category.name;
    }
  }

  Widget _buildCreateMode(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _handleCreate,
      },
      child: Scaffold(
        backgroundColor: context.colorScheme.surface,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 100,
              pinned: true,
              backgroundColor: context.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.all(16),
                title: Text(
                  context.messages.createCategoryTitle,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Basic Settings Section
                  LottiFormSection(
                    title: context.messages.basicSettings,
                    icon: Icons.settings_outlined,
                    children: [
                      _buildNameField(),
                      const SizedBox(height: 16),
                      _buildColorPicker(),
                      const SizedBox(height: 16),
                      _buildIconPicker(),
                      const SizedBox(height: 16),
                      _buildCreateModeSwitchTiles(),
                    ],
                  ),
                  const SizedBox(height: 80), // Space for bottom bar
                ]),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildCreateModeBottomBar(),
      ),
    );
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.messages.categoryNameRequired),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final repository = ref.read(categoryRepositoryProvider);
    try {
      final newCategory = await repository.createCategory(
        name: name,
        color: _selectedColor != null
            ? colorToCssHex(_selectedColor!)
            : colorToCssHex(Colors.blue),
        icon: _selectedIcon,
      );

      if (mounted) {
        // Navigate to the edit page for the newly created category
        beamToNamed('/settings/categories/${newCategory.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error creating category. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildCreateModeSwitchTiles() {
    return Column(
      children: [
        LottiSwitchField(
          title: context.messages.privateLabel,
          subtitle: context.messages.categoryPrivateDescription,
          value: false,
          onChanged: null,
          // Will be set after creation
          icon: Icons.lock_outline,
          enabled: false,
        ),
        const SizedBox(height: 8),
        LottiSwitchField(
          title: context.messages.activeLabel,
          subtitle: context.messages.categoryActiveDescription,
          value: true,
          onChanged: null,
          // Will be set after creation
          icon: Icons.visibility_outlined,
          enabled: false,
        ),
      ],
    );
  }

  Widget _buildCreateModeBottomBar() {
    return FormBottomBar(
      rightButtons: [
        LottiSecondaryButton(
          onPressed: () => Navigator.of(context).pop(),
          label: context.messages.cancelButton,
        ),
        LottiPrimaryButton(
          onPressed: _handleCreate,
          label: context.messages.createButton,
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (widget.isCreateMode) {
      return _handleCreate();
    }

    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    await controller.saveChanges();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.messages.saveSuccessful),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // For create mode, we don't need the controller yet
    if (widget.isCreateMode) {
      return _buildCreateMode(context);
    }

    // For edit mode, watch the category details
    final state =
        ref.watch(categoryDetailsControllerProvider(widget.categoryId!));
    final category = state.category;

    if (category == null && !state.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.messages.settingsCategoriesDetailsLabel),
        ),
        body: Center(
          child: Text(context.messages.categoryNotFound),
        ),
      );
    }

    if (category != null) {
      _syncFormWithCategory(category);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _handleSave,
      },
      child: Scaffold(
        backgroundColor: context.colorScheme.surface,
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 100,
                    pinned: true,
                    backgroundColor: context.colorScheme.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.all(16),
                      title: Text(
                        context.messages.settingsCategoriesDetailsLabel,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  if (state.errorMessage != null)
                    SliverToBoxAdapter(
                      child: ErrorStateWidget(
                        error: state.errorMessage!,
                        mode: ErrorDisplayMode.inline,
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Basic Settings Section
                        LottiFormSection(
                          title: context.messages.basicSettings,
                          icon: Icons.settings_outlined,
                          children: [
                            _buildNameField(),
                            const SizedBox(height: 16),
                            _buildColorPicker(),
                            const SizedBox(height: 16),
                            if (category != null)
                              _buildIconPicker(category: category),
                            const SizedBox(height: 16),
                            _buildSwitchTiles(category!),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Language Settings Section
                        LottiFormSection(
                          title: context.messages.taskLanguageLabel,
                          icon: Icons.language_outlined,
                          description: context
                              .messages.categoryDefaultLanguageDescription,
                          children: [
                            _buildLanguageDropdown(category),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // AI Model Settings Section
                        LottiFormSection(
                          title: context.messages.aiModelSettings,
                          icon: Icons.psychology_outlined,
                          description:
                              context.messages.categoryAiModelDescription,
                          children: [
                            _buildPromptSelection(category),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Automatic Prompts Section
                        LottiFormSection(
                          title: context.messages.automaticPrompts,
                          icon: Icons.auto_awesome_outlined,
                          description: context
                              .messages.categoryAutomaticPromptsDescription,
                          children: [
                            _buildAutomaticPromptSettings(category),
                          ],
                        ),
                        const SizedBox(height: 80), // Space for bottom bar
                      ]),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: _buildBottomBar(state),
      ),
    );
  }

  Widget _buildNameField() {
    final isCreateMode = widget.categoryId == null;

    return CategoryNameField(
      controller: _nameController,
      isCreateMode: isCreateMode,
      onChanged: isCreateMode
          ? null
          : (value) {
              ref
                  .read(
                    categoryDetailsControllerProvider(widget.categoryId!)
                        .notifier,
                  )
                  .updateFormField(name: value);
            },
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
    final state =
        ref.watch(categoryDetailsControllerProvider(widget.categoryId!));
    final category = state.category;
    final selectedColor =
        category != null ? colorFromCssHex(category.color) : null;

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

  Widget _buildSwitchTiles(CategoryDefinition category) {
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    return CategorySwitchTiles(
      settings: CategorySwitchSettings(
        isPrivate: category.private,
        isActive: category.active,
        isFavorite: category.favorite ?? false,
      ),
      onChanged: (field, {required value}) {
        switch (field) {
          case SwitchFieldType.private:
            controller.updateFormField(private: value);
          case SwitchFieldType.active:
            controller.updateFormField(active: value);
          case SwitchFieldType.favorite:
            controller.updateFormField(favorite: value);
        }
      },
    );
  }

  Widget _buildLanguageDropdown(CategoryDefinition category) {
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    return CategoryLanguageDropdown(
      languageCode: category.defaultLanguageCode,
      onTap: () => _showLanguageSelector(
          context, controller, category.defaultLanguageCode),
    );
  }

  Future<void> _showLanguageSelector(
    BuildContext context,
    CategoryDetailsController controller,
    String? currentLanguageCode,
  ) async {
    final searchQuery = ValueNotifier<String>('');
    final searchController = TextEditingController();

    try {
      await ModalUtils.showSinglePageModal<void>(
        context: context,
        titleWidget: Padding(
          padding:
              const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 16),
          child: LanguageSelectionModalContent.buildHeader(
            context: context,
            controller: searchController,
            queryNotifier: searchQuery,
          ),
        ),
        builder: (BuildContext context) {
          return LanguageSelectionModalContent(
            initialLanguageCode: currentLanguageCode,
            searchQuery: searchQuery,
            onLanguageSelected: (language) {
              controller.updateFormField(defaultLanguageCode: language?.code);
              if (!context.mounted) {
                return;
              }
              Navigator.pop(context);
            },
          );
        },
      );
    } finally {
      searchController.dispose();
      searchQuery.dispose();
    }
  }

  Widget _buildPromptSelection(CategoryDefinition category) {
    final promptsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.prompt),
    );
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    return promptsAsync.when(
      data: (prompts) {
        final promptConfigs = prompts
            .whereType<AiConfigPrompt>()
            .where((p) => !p.archived)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        return CategoryPromptSelection(
          prompts: promptConfigs,
          allowedPromptIds: category.allowedPromptIds ?? [],
          onPromptToggled: (promptId, {required isAllowed}) {
            final currentAllowedIds = category.allowedPromptIds ?? [];
            final updatedIds = List<String>.from(currentAllowedIds);
            if (isAllowed && !updatedIds.contains(promptId)) {
              updatedIds.add(promptId);
            } else if (!isAllowed) {
              updatedIds.remove(promptId);
            }
            controller.updateAllowedPromptIds(updatedIds);
          },
          isLoading: false,
        );
      },
      loading: () => const CategoryPromptSelection(
        prompts: [],
        allowedPromptIds: [],
        onPromptToggled: _dummyPromptToggle,
        isLoading: true,
      ),
      error: (error, _) => CategoryPromptSelection(
        prompts: const [],
        allowedPromptIds: const [],
        onPromptToggled: _dummyPromptToggle,
        isLoading: false,
        error: error.toString(),
      ),
    );
  }

  static void _dummyPromptToggle(String promptId, {required bool isAllowed}) {}

  Widget _buildAutomaticPromptSettings(CategoryDefinition category) {
    final promptsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.prompt),
    );
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    return promptsAsync.when(
      data: (prompts) {
        final promptList = prompts.whereType<AiConfigPrompt>().toList();

        // Build configs for each response type
        final configs = [
          _buildAutomaticPromptConfig(
            category,
            promptList,
            AiResponseType.audioTranscription,
            context.messages.audioRecordings,
            Icons.mic_outlined,
          ),
          _buildAutomaticPromptConfig(
            category,
            promptList,
            AiResponseType.checklistUpdates,
            context.messages.checklistUpdates,
            Icons.checklist_rtl_outlined,
          ),
          _buildAutomaticPromptConfig(
            category,
            promptList,
            AiResponseType.imageAnalysis,
            context.messages.images,
            Icons.image_outlined,
          ),
          _buildAutomaticPromptConfig(
            category,
            promptList,
            AiResponseType.taskSummary,
            context.messages.taskSummaries,
            Icons.summarize_outlined,
          ),
        ];

        return CategoryAutomaticPrompts(
          configs: configs,
          onPromptChanged: controller.updateAutomaticPrompts,
          isLoading: false,
        );
      },
      loading: () => const CategoryAutomaticPrompts(
        configs: [],
        onPromptChanged: _dummyAutomaticPromptChanged,
        isLoading: true,
      ),
      error: (error, _) => CategoryAutomaticPrompts(
        configs: const [],
        onPromptChanged: _dummyAutomaticPromptChanged,
        isLoading: false,
        error: error.toString(),
      ),
    );
  }

  static void _dummyAutomaticPromptChanged(
      AiResponseType responseType, List<String> selectedPromptIds) {}

  AutomaticPromptConfig _buildAutomaticPromptConfig(
    CategoryDefinition category,
    List<AiConfigPrompt> allPrompts,
    AiResponseType responseType,
    String title,
    IconData icon,
  ) {
    final validPrompts = allPrompts
        .where((p) =>
            !p.archived &&
            p.aiResponseType == responseType &&
            category.allowedPromptIds != null &&
            category.allowedPromptIds!.contains(p.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final selectedPromptIds = category.automaticPrompts?[responseType] ?? [];

    return AutomaticPromptConfig(
      responseType: responseType,
      title: title,
      icon: icon,
      availablePrompts: validPrompts,
      selectedPromptIds: selectedPromptIds,
    );
  }

  Widget _buildIconPicker({CategoryDefinition? category}) {
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
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showIconPicker(isCreateMode ? null : category.icon),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
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
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: icon != null
                          ? Icon(
                              icon.iconData,
                              color: color,
                              size: 28,
                            )
                          : const Icon(
                              Icons.category,
                              color: Colors.grey,
                              size: 28,
                            ),
                    ),
                  )
                else
                  CategoryIconDisplay(
                    category: category,
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        iconDisplayName,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        hintText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16),
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

  Widget _buildBottomBar(CategoryDetailsState state) {
    return FormBottomBar(
      leftButton: LottiTertiaryButton(
        onPressed: state.isSaving ? null : _showDeleteDialog,
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
          onPressed: state.isSaving || !state.hasChanges ? null : _handleSave,
          label: context.messages.saveButton,
        ),
      ],
    );
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
              Navigator.of(context).pop();
              final controller = ref.read(
                categoryDetailsControllerProvider(widget.categoryId!).notifier,
              );
              await controller.deleteCategory();
              if (context.mounted) {
                Navigator.of(context).pop();
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

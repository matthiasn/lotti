import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/category_details_controller.dart';
import 'package:lotti/features/tasks/ui/widgets/language_selection_modal_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/lotti_primary_button.dart';
import 'package:lotti/widgets/lotti_secondary_button.dart';
import 'package:lotti/widgets/lotti_tertiary_button.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/ui/empty_state_widget.dart';
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
  Color? _selectedColor;
  bool _hasInitialized = false;

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

  void _initializeForm(CategoryDefinition category) {
    if (!_hasInitialized) {
      _nameController.text = category.name;
      _selectedColor = colorFromCssHex(category.color);
      _hasInitialized = true;

      // Initialize the controller with current values after the frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(categoryDetailsControllerProvider(widget.categoryId!)
                  .notifier)
              .updateFormField(
                name: category.name,
                color: category.color,
              );
        }
      });
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
      );

      if (mounted) {
        // Navigate to the edit page for the newly created category
        beamToNamed('/settings/categories2/${newCategory.id}');
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
          onChanged: null, // Will be set after creation
          icon: Icons.lock_outline,
          enabled: false,
        ),
        const SizedBox(height: 8),
        LottiSwitchField(
          title: context.messages.activeLabel,
          subtitle: context.messages.categoryActiveDescription,
          value: true,
          onChanged: null, // Will be set after creation
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
      _initializeForm(category);
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
    // In create mode, we don't have a controller yet
    final isCreateMode = widget.categoryId == null;

    return LottiTextField(
      controller: _nameController,
      labelText: context.messages.settingsCategoriesNameLabel,
      hintText: context.messages.enterCategoryName,
      prefixIcon: Icons.category_outlined,
      onChanged: isCreateMode
          ? null // In create mode, we handle name via TextEditingController
          : (value) {
              ref
                  .read(
                    categoryDetailsControllerProvider(widget.categoryId!)
                        .notifier,
                  )
                  .updateFormField(name: value);
            },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return context.messages.categoryNameRequired;
        }
        return null;
      },
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.colorLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showColorPicker,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        _selectedColor ?? Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _selectedColor != null
                      ? colorToCssHex(_selectedColor!)
                      : context.messages.selectColor,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const Spacer(),
                const Icon(Icons.palette_outlined),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showColorPicker() {
    showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.messages.selectColor),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor ?? Colors.red,
            onColorChanged: (color) {
              setState(() {
                _selectedColor = color;
              });
              // Only update controller in edit mode
              if (!widget.isCreateMode) {
                ref
                    .read(
                      categoryDetailsControllerProvider(widget.categoryId!)
                          .notifier,
                    )
                    .updateFormField(color: colorToCssHex(color));
              }
            },
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaBorderRadius: BorderRadius.circular(10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.messages.cancelButton),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(context.messages.selectButton),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTiles(CategoryDefinition category) {
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    return Column(
      children: [
        LottiSwitchField(
          title: context.messages.privateLabel,
          subtitle: context.messages.categoryPrivateDescription,
          value: category.private,
          onChanged: (value) => controller.updateFormField(private: value),
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: 8),
        LottiSwitchField(
          title: context.messages.activeLabel,
          subtitle: context.messages.categoryActiveDescription,
          value: category.active,
          onChanged: (value) => controller.updateFormField(active: value),
          icon: Icons.visibility_outlined,
        ),
        const SizedBox(height: 8),
        LottiSwitchField(
          title: context.messages.favoriteLabel,
          subtitle: context.messages.categoryFavoriteDescription,
          value: category.favorite ?? false,
          onChanged: (value) => controller.updateFormField(favorite: value),
          icon: Icons.star_outline,
        ),
      ],
    );
  }

  Widget _buildLanguageDropdown(CategoryDefinition category) {
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    final languageCode = category.defaultLanguageCode;
    final language =
        languageCode != null ? SupportedLanguage.fromCode(languageCode) : null;

    return InkWell(
      onTap: () => _showLanguageSelector(context, controller, languageCode),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.messages.defaultLanguage,
          hintText: context.messages.selectLanguage,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          prefixIcon: const Icon(Icons.translate),
        ),
        child: Row(
          children: [
            if (language != null) ...[
              CountryFlag.fromLanguageCode(
                language.code,
                height: 20,
                width: 30,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  language.localizedName(context),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ] else
              Expanded(
                child: Text(
                  context.messages.noDefaultLanguage,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Future<void> _showLanguageSelector(
    BuildContext context,
    CategoryDetailsController controller,
    String? currentLanguageCode,
  ) async {
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.defaultLanguage,
      builder: (BuildContext context) {
        return LanguageSelectionModalContent(
          initialLanguageCode: currentLanguageCode,
          onLanguageSelected: (language) {
            controller.updateFormField(defaultLanguageCode: language?.code);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildPromptSelection(CategoryDefinition category) {
    final promptsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.prompt),
    );

    return promptsAsync.when(
      data: (prompts) {
        final promptConfigs = prompts
            .whereType<AiConfigPrompt>()
            .where((p) => !p.archived)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        if (promptConfigs.isEmpty) {
          return _buildEmptyPromptsState();
        }

        return _buildPromptCheckboxList(category, promptConfigs);
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => _buildErrorState(error),
    );
  }

  Widget _buildEmptyPromptsState() {
    return EmptyStateWidget(
      icon: Icons.psychology_outlined,
      title: context.messages.noPromptsAvailable,
      description: context.messages.createPromptsFirst,
    );
  }

  Widget _buildPromptCheckboxList(
    CategoryDefinition category,
    List<AiConfigPrompt> prompts,
  ) {
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );
    // When allowedPromptIds is null or empty, no prompts are allowed
    // When it has values, only those specific prompts are allowed
    final allowedPromptIds = category.allowedPromptIds ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.selectAllowedPrompts,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: prompts.map((prompt) {
              // Check if this prompt is in the allowed list
              final isAllowed = allowedPromptIds.contains(prompt.id);

              return CheckboxListTile(
                title: Text(prompt.name),
                subtitle: prompt.description != null
                    ? Text(
                        prompt.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                value: isAllowed,
                onChanged: (value) {
                  // Get current allowed IDs from the actual category state
                  final currentAllowedIds = category.allowedPromptIds ?? [];
                  final updatedIds = List<String>.from(currentAllowedIds);

                  if ((value ?? false) && !updatedIds.contains(prompt.id)) {
                    updatedIds.add(prompt.id);
                  } else if (value == false) {
                    updatedIds.remove(prompt.id);
                  }
                  controller.updateAllowedPromptIds(updatedIds);
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAutomaticPromptSettings(CategoryDefinition category) {
    return Column(
      children: [
        _buildAutomaticPromptSection(
          category,
          AiResponseType.audioTranscription,
          context.messages.audioRecordings,
          Icons.mic_outlined,
        ),
        const SizedBox(height: 16),
        _buildAutomaticPromptSection(
          category,
          AiResponseType.imageAnalysis,
          context.messages.images,
          Icons.image_outlined,
        ),
        const SizedBox(height: 16),
        _buildAutomaticPromptSection(
          category,
          AiResponseType.taskSummary,
          context.messages.taskSummaries,
          Icons.summarize_outlined,
        ),
      ],
    );
  }

  Widget _buildAutomaticPromptSection(
    CategoryDefinition category,
    AiResponseType responseType,
    String title,
    IconData icon,
  ) {
    final promptsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.prompt),
    );
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          promptsAsync.when(
            data: (prompts) {
              final validPrompts = prompts
                  .whereType<AiConfigPrompt>()
                  .where((p) =>
                      !p.archived &&
                      p.aiResponseType == responseType &&
                      category.allowedPromptIds != null &&
                      category.allowedPromptIds!.contains(p.id))
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));

              if (validPrompts.isEmpty) {
                return Text(
                  context.messages.noPromptsForType,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).disabledColor,
                      ),
                );
              }

              final selectedPromptIds =
                  category.automaticPrompts?[responseType] ?? [];

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: validPrompts.map((prompt) {
                  final isSelected = selectedPromptIds.contains(prompt.id);

                  return FilterChip(
                    label: Text(prompt.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        // Only allow one selection - replace any existing selection
                        controller.updateAutomaticPrompts(
                          responseType,
                          [prompt.id],
                        );
                      } else {
                        // Deselecting - clear the selection
                        controller.updateAutomaticPrompts(
                          responseType,
                          [],
                        );
                      }
                    },
                  );
                }).toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => Text(
              context.messages.errorLoadingPrompts,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return ErrorStateWidget(
      error: error.toString(),
      title: context.messages.errorLoadingPrompts,
    );
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
        title: Text(context.messages.categoryDeleteQuestion),
        content: Text(context.messages.categoryDeleteConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.messages.cancelButton),
          ),
          TextButton(
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
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.messages.categoryDeleteConfirm),
          ),
        ],
      ),
    );
  }
}

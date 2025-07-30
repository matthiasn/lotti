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
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/lotti_primary_button.dart';
import 'package:lotti/widgets/lotti_secondary_button.dart';
import 'package:lotti/widgets/lotti_tertiary_button.dart';

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
            content: Text('Error creating category: $e'),
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
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          LottiSecondaryButton(
            onPressed: () => Navigator.of(context).pop(),
            label: context.messages.cancelButton,
          ),
          const SizedBox(width: 12),
          LottiPrimaryButton(
            onPressed: _handleCreate,
            label: context.messages.createButton,
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    if (widget.isCreateMode) {
      return _handleCreate();
    }

    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    await controller.updateBasicSettings(
      name: _nameController.text.trim(),
      color: _selectedColor != null ? colorToCssHex(_selectedColor!) : null,
    );

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
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(
                            color: context.colorScheme.onErrorContainer,
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
    return LottiTextField(
      controller: _nameController,
      labelText: context.messages.settingsCategoriesNameLabel,
      hintText: context.messages.enterCategoryName,
      prefixIcon: Icons.category_outlined,
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
          onChanged: (value) => controller.updateBasicSettings(private: value),
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: 8),
        LottiSwitchField(
          title: context.messages.activeLabel,
          subtitle: context.messages.categoryActiveDescription,
          value: category.active,
          onChanged: (value) => controller.updateBasicSettings(active: value),
          icon: Icons.visibility_outlined,
        ),
        const SizedBox(height: 8),
        LottiSwitchField(
          title: context.messages.favoriteLabel,
          subtitle: context.messages.categoryFavoriteDescription,
          value: category.favorite ?? false,
          onChanged: (value) => controller.updateBasicSettings(favorite: value),
          icon: Icons.star_outline,
        ),
      ],
    );
  }

  Widget _buildLanguageDropdown(CategoryDefinition category) {
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    return DropdownButtonFormField<String?>(
      value: category.defaultLanguageCode,
      decoration: InputDecoration(
        labelText: context.messages.defaultLanguage,
        hintText: context.messages.selectLanguage,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixIcon: const Icon(Icons.translate),
      ),
      items: [
        DropdownMenuItem<String?>(
          child: Text(context.messages.noDefaultLanguage),
        ),
        ...SupportedLanguage.values.map((lang) {
          return DropdownMenuItem<String?>(
            value: lang.code,
            child: Text(lang.localizedName(context)),
          );
        }),
      ],
      onChanged: controller.updateDefaultLanguage,
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 48,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            context.messages.noPromptsAvailable,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.messages.createPromptsFirst,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCheckboxList(
    CategoryDefinition category,
    List<AiConfigPrompt> prompts,
  ) {
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );
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
              final isAllowed = allowedPromptIds.isEmpty ||
                  allowedPromptIds.contains(prompt.id);

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
                  final updatedIds = List<String>.from(allowedPromptIds);
                  if ((value ?? false) && !updatedIds.contains(prompt.id)) {
                    updatedIds.add(prompt.id);
                  } else if (value == false) {
                    updatedIds.remove(prompt.id);
                  }
                  controller.updateAllowedPromptIds(
                    updatedIds.isEmpty ? [] : updatedIds,
                  );
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
                      ((category.allowedPromptIds?.isEmpty ?? true) ||
                          category.allowedPromptIds!.contains(p.id)))
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
                      final updatedIds = List<String>.from(selectedPromptIds);
                      if (selected) {
                        updatedIds.add(prompt.id);
                      } else {
                        updatedIds.remove(prompt.id);
                      }
                      controller.updateAutomaticPrompts(
                        responseType,
                        updatedIds,
                      );
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            context.messages.errorLoadingPrompts,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(CategoryDetailsState state) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          LottiTertiaryButton(
            onPressed: state.isSaving ? null : _showDeleteDialog,
            icon: Icons.delete_outline,
            label: context.messages.deleteButton,
            isDestructive: true,
          ),
          Row(
            children: [
              LottiSecondaryButton(
                onPressed: () => Navigator.of(context).pop(),
                label: context.messages.cancelButton,
              ),
              const SizedBox(width: 12),
              LottiPrimaryButton(
                onPressed: state.isSaving ? null : _handleSave,
                label: context.messages.saveButton,
              ),
            ],
          ),
        ],
      ),
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

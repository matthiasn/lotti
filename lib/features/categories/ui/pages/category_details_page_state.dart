part of 'category_details_page.dart';

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
              // Always show an explicit back arrow — V2's detail pane
              // mounts the page inline (no Navigator.canPop), so the
              // automatic leading would never appear there.
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => beamToNamed('/settings/categories'),
              ),
              title: Text(
                context.messages.createCategoryTitle,
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
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.categoryNameRequired,
      );
      return;
    }

    final repository = ref.read(categoryRepositoryProvider);
    try {
      await repository.createCategory(
        name: name,
        color: _selectedColor != null
            ? colorToCssHex(_selectedColor!)
            : colorToCssHex(Colors.blue),
        icon: _selectedIcon,
      );

      if (mounted) {
        // Beam back to the categories list — V2's desktop detail
        // surface mounts inline (Navigator.pop would be a no-op);
        // the URL change still pops the page on mobile.
        beamToNamed('/settings/categories');
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
          // Beam to the list URL rather than `Navigator.pop`. V2's desktop
          // detail surface mounts the page inline (no Navigator route was
          // pushed), so popping is a no-op there; on mobile the URL change
          // still pops the detail page off the Beamer stack.
          onPressed: () => beamToNamed('/settings/categories'),
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
    final enableProjects =
        ref.watch(configFlagProvider(enableProjectsFlag)).value ?? false;
    final category = state.category;

    if (category == null && !state.isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => beamToNamed('/settings/categories'),
          ),
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
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => beamToNamed('/settings/categories'),
              ),
              title: Text(
                context.messages.settingsCategoriesDetailsLabel,
                style: appBarTextStyleNewLarge.copyWith(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              pinned: true,
              // Save action intentionally removed; single Save lives in bottom bar.
            ),
            if (state.errorMessage != null)
              SliverToBoxAdapter(
                child: ErrorStateWidget(
                  error: state.errorMessage!,
                  mode: ErrorDisplayMode.inline,
                ),
              ),
            if (state.isLoading && category == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (category != null)
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
                        _buildIconPicker(category: category),
                        const SizedBox(height: 16),
                        _buildSwitchTiles(category),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Language Settings Section
                    LottiFormSection(
                      title: context.messages.taskLanguageLabel,
                      icon: Icons.language_outlined,
                      description:
                          context.messages.categoryDefaultLanguageDescription,
                      children: [
                        _buildLanguageDropdown(category),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // AI Defaults Section
                    LottiFormSection(
                      title: context.messages.categoryAiDefaultsTitle,
                      icon: Icons.smart_toy_outlined,
                      description:
                          context.messages.categoryAiDefaultsDescription,
                      children: [
                        _buildDefaultProfilePicker(category),
                        const SizedBox(height: 16),
                        _buildDefaultTemplatePicker(category),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Projects Section
                    if (enableProjects) ...[
                      CategoryProjectsSection(
                        categoryId: widget.categoryId!,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Speech Dictionary Section
                    LottiFormSection(
                      title: context.messages.speechDictionarySectionTitle,
                      icon: Icons.spellcheck_outlined,
                      description:
                          context.messages.speechDictionarySectionDescription,
                      children: [
                        _buildSpeechDictionary(category),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Correction Examples Section
                    _buildCorrectionExamples(category),
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
          onPressed: () => beamToNamed('/settings/categories'),
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

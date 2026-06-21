// Controller-backed form-section builders for CategoryDetailsPage's edit
// mode. Part of the page library so they keep access to the State's
// private members; only setState-free builders live here (the repo's
// extension-split rule: state-writing members cannot move).
part of 'category_details_page.dart';

extension _CategoryDetailsFormSections on _CategoryDetailsPageState {
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
                    categoryDetailsControllerProvider(
                      widget.categoryId!,
                    ).notifier,
                  )
                  .updateFormField(name: value);
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
        isAvailableForDayPlan: category.isAvailableForDayPlan ?? false,
      ),
      onChanged: (field, {required value}) {
        switch (field) {
          case SwitchFieldType.private:
            controller.updateFormField(private: value);
          case SwitchFieldType.active:
            controller.updateFormField(active: value);
          case SwitchFieldType.favorite:
            controller.updateFormField(favorite: value);
          case SwitchFieldType.availableForDayPlan:
            controller.updateFormField(isAvailableForDayPlan: value);
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
        context,
        controller,
        category.defaultLanguageCode,
      ),
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
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: 16,
          ),
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

  Widget _buildDefaultProfilePicker(CategoryDefinition category) {
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    return SettingsProfilePickerField(
      selectedProfileId: category.defaultProfileId,
      onProfileSelected: controller.setDefaultProfileId,
      hintText: context.messages.categoryDefaultProfileHint,
    );
  }

  Widget _buildDefaultTemplatePicker(CategoryDefinition category) {
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    return TemplateSelector(
      selectedTemplateId: category.defaultTemplateId,
      onTemplateSelected: controller.setDefaultTemplateId,
    );
  }

  Widget _buildDefaultEventTemplatePicker(CategoryDefinition category) {
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    return TemplateSelector(
      selectedTemplateId: category.defaultEventTemplateId,
      onTemplateSelected: controller.setDefaultEventTemplateId,
      kind: AgentTemplateKind.eventAgent,
      labelText: context.messages.categoryDefaultEventTemplateLabel,
      hintText: context.messages.categoryDefaultEventTemplateHint,
    );
  }

  Widget _buildSpeechDictionary(CategoryDefinition category) {
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    return CategorySpeechDictionary(
      dictionary: category.speechDictionary,
      onChanged: controller.updateSpeechDictionary,
    );
  }

  Widget _buildCorrectionExamples(CategoryDefinition category) {
    final controller = ref.read(
      categoryDetailsControllerProvider(widget.categoryId!).notifier,
    );

    return CategoryCorrectionExamples(
      examples: category.correctionExamples,
      onDeleteAt: controller.deleteCorrectionExampleAt,
    );
  }
}

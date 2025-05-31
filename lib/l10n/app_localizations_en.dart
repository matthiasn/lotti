// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get addActionAddAudioRecording => 'Audio Recording';

  @override
  String get addActionAddChecklist => 'Checklist';

  @override
  String get addActionAddEvent => 'Event';

  @override
  String get addActionAddImageFromClipboard => 'Paste Image';

  @override
  String get addActionAddPhotos => 'Photo(s)';

  @override
  String get addActionAddScreenshot => 'Screenshot';

  @override
  String get addActionAddTask => 'Task';

  @override
  String get addActionAddText => 'Text Entry';

  @override
  String get addActionAddTimeRecording => 'Timer Entry';

  @override
  String get addAudioTitle => 'Audio Recording';

  @override
  String get addHabitCommentLabel => 'Comment';

  @override
  String get addHabitDateLabel => 'Completed at';

  @override
  String get addMeasurementCommentLabel => 'Comment';

  @override
  String get addMeasurementDateLabel => 'Observed at';

  @override
  String get addMeasurementSaveButton => 'Save';

  @override
  String get addSurveyTitle => 'Fill Survey';

  @override
  String get aiAssistantActionItemSuggestions => 'Action Item Suggestions';

  @override
  String get aiAssistantAnalyzeImage => 'Analyze image';

  @override
  String get aiAssistantSummarizeTask => 'Summarize task';

  @override
  String get aiAssistantThinking => 'Thinking...';

  @override
  String get aiAssistantTitle => 'AI Assistant';

  @override
  String get aiAssistantTranscribeAudio => 'Transcribe audio';

  @override
  String get aiConfigApiKeyEmptyError => 'API key cannot be empty';

  @override
  String get aiConfigApiKeyFieldLabel => 'API Key';

  @override
  String get aiConfigBaseUrlFieldLabel => 'Base URL';

  @override
  String get aiConfigCommentFieldLabel => 'Comment (Optional)';

  @override
  String get aiConfigCreateButtonLabel => 'Create Prompt';

  @override
  String get aiConfigDescriptionFieldLabel => 'Description (Optional)';

  @override
  String aiConfigFailedToLoadModels(String error) {
    return 'Failed to load models: $error';
  }

  @override
  String get aiConfigFailedToSaveMessage =>
      'Failed to save configuration. Please try again.';

  @override
  String get aiConfigInputDataTypesTitle => 'Required Input Data Types';

  @override
  String get aiConfigInputModalitiesFieldLabel => 'Input Modalities';

  @override
  String get aiConfigInputModalitiesTitle => 'Input Modalities';

  @override
  String get aiConfigInvalidUrlError => 'Please enter a valid URL';

  @override
  String get aiConfigListDeleteConfirmCancel => 'CANCEL';

  @override
  String get aiConfigListDeleteConfirmDelete => 'DELETE';

  @override
  String aiConfigListDeleteConfirmMessage(String configName) {
    return 'Are you sure you want to delete \"$configName\"?';
  }

  @override
  String get aiConfigListDeleteConfirmTitle => 'Confirm Deletion';

  @override
  String get aiConfigListEmptyState =>
      'No configurations found. Add one to get started.';

  @override
  String aiConfigListErrorDeleting(String configName, String error) {
    return 'Error deleting $configName: $error';
  }

  @override
  String get aiConfigListErrorLoading => 'Error loading configurations';

  @override
  String aiConfigListItemDeleted(String configName) {
    return '$configName deleted';
  }

  @override
  String get aiConfigListUndoDelete => 'UNDO';

  @override
  String get aiConfigManageModelsButton => 'Manage Models';

  @override
  String aiConfigModelRemovedMessage(String modelName) {
    return '$modelName removed from prompt';
  }

  @override
  String get aiConfigModelsTitle => 'Available Models';

  @override
  String get aiConfigNameFieldLabel => 'Display Name';

  @override
  String get aiConfigNameTooShortError => 'Name must be at least 3 characters';

  @override
  String get aiConfigNoModelsAvailable =>
      'No AI models are configured yet. Please add one in settings.';

  @override
  String get aiConfigNoModelsSelected =>
      'No models selected. At least one model is required.';

  @override
  String get aiConfigNoProvidersAvailable =>
      'No API providers available. Please add an API provider first.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'No models meet the requirements for this prompt. Please configure models that support the required capabilities.';

  @override
  String get aiConfigOutputModalitiesFieldLabel => 'Output Modalities';

  @override
  String get aiConfigOutputModalitiesTitle => 'Output Modalities';

  @override
  String get aiConfigProviderFieldLabel => 'Inference Provider';

  @override
  String get aiConfigProviderModelIdFieldLabel => 'Provider Model ID';

  @override
  String get aiConfigProviderModelIdTooShortError =>
      'ProviderModelId must be at least 3 characters';

  @override
  String get aiConfigProviderTypeFieldLabel => 'Provider Type';

  @override
  String get aiConfigReasoningCapabilityDescription =>
      'Model can perform step-by-step reasoning';

  @override
  String get aiConfigReasoningCapabilityFieldLabel => 'Reasoning Capability';

  @override
  String get aiConfigRequiredInputDataFieldLabel => 'Required Input Data';

  @override
  String get aiConfigResponseTypeFieldLabel => 'AI Response Type';

  @override
  String get aiConfigResponseTypeNotSelectedError =>
      'Please select a response type';

  @override
  String get aiConfigResponseTypeSelectHint => 'Select response type';

  @override
  String get aiConfigSelectInputDataTypesPrompt =>
      'Select required data types...';

  @override
  String get aiConfigSelectModalitiesPrompt => 'Select modalities';

  @override
  String get aiConfigSelectProviderModalTitle => 'Select Inference Provider';

  @override
  String get aiConfigSelectProviderNotFound => 'Inference Provider not found';

  @override
  String get aiConfigSelectProviderTypeModalTitle => 'Select Provider Type';

  @override
  String get aiConfigSelectResponseTypeTitle => 'Select AI Response Type';

  @override
  String get aiConfigSystemMessageFieldLabel => 'System Message';

  @override
  String get aiConfigUpdateButtonLabel => 'Update Prompt';

  @override
  String get aiConfigUseReasoningDescription =>
      'If enabled, the model will use its reasoning capabilities for this prompt.';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Use Reasoning';

  @override
  String get aiConfigUserMessageEmptyError => 'User message cannot be empty';

  @override
  String get aiConfigUserMessageFieldLabel => 'User Message';

  @override
  String get aiProviderAnthropicDescription =>
      'Anthropic\'s Claude family of AI assistants';

  @override
  String get aiProviderAnthropicName => 'Anthropic Claude';

  @override
  String get aiProviderGeminiDescription => 'Google\'s Gemini AI models';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiDescription =>
      'API compatible with OpenAI format';

  @override
  String get aiProviderGenericOpenAiName => 'OpenAI Compatible';

  @override
  String get aiProviderNebiusAiStudioDescription =>
      'Nebius AI Studio\'s models';

  @override
  String get aiProviderNebiusAiStudioName => 'Nebius AI Studio';

  @override
  String get aiProviderOllamaDescription => 'Run inference locally with Ollama';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOpenAiDescription => 'OpenAI\'s GPT models';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'OpenRouter\'s models';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiResponseTypeActionItemSuggestions => 'Action Item Suggestions';

  @override
  String get aiResponseTypeAudioTranscription => 'Audio Transcription';

  @override
  String get aiResponseTypeImageAnalysis => 'Image Analysis';

  @override
  String get aiResponseTypeTaskSummary => 'Task Summary';

  @override
  String get aiTaskSummaryRunning => 'Thinking about summarizing task...';

  @override
  String get aiTaskSummaryTitle => 'AI Task Summary';

  @override
  String get apiKeyAddPageTitle => 'Add API Key';

  @override
  String get apiKeyEditLoadError => 'Failed to load API key configuration';

  @override
  String get apiKeyEditPageTitle => 'Edit API Key';

  @override
  String get apiKeyFormCreateButton => 'Create';

  @override
  String get apiKeyFormUpdateButton => 'Update';

  @override
  String get apiKeysSettingsPageTitle => 'API Keys';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get categoryDeleteConfirm => 'YES, DELETE THIS CATEGORY';

  @override
  String get categoryDeleteQuestion => 'Do you want to delete this category?';

  @override
  String get categorySearchPlaceholder => 'Search categories...';

  @override
  String get checklistAddItem => 'Add a new item';

  @override
  String get checklistDelete => 'Delete checklist?';

  @override
  String get checklistItemDelete => 'Delete checklist item?';

  @override
  String get checklistItemDeleteCancel => 'Cancel';

  @override
  String get checklistItemDeleteConfirm => 'Confirm';

  @override
  String get checklistItemDeleteWarning => 'This action cannot be undone.';

  @override
  String get checklistItemDrag => 'Drag suggestions into checklist';

  @override
  String get checklistNoSuggestionsTitle => 'No suggested Action Items';

  @override
  String get checklistsTitle => 'Checklists';

  @override
  String get checklistSuggestionsOutdated => 'Outdated';

  @override
  String get checklistSuggestionsRunning =>
      'Thinking about untracked suggestions...';

  @override
  String get checklistSuggestionsTitle => 'Suggested Action Items';

  @override
  String get colorLabel => 'Color:';

  @override
  String get colorPickerError => 'Invalid Hex color';

  @override
  String get colorPickerHint => 'Enter Hex color or pick';

  @override
  String get completeHabitFailButton => 'Fail';

  @override
  String get completeHabitSkipButton => 'Skip';

  @override
  String get completeHabitSuccessButton => 'Success';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'When enabled, the app will attempt to generate embeddings for your entries to improve search and related content suggestions.';

  @override
  String get configFlagAutoTranscribeDescription =>
      'Automatically transcribe audio recordings in your entries. This requires an internet connection.';

  @override
  String get configFlagEnableAutoTaskTldrDescription =>
      'Automatically generate summaries for your tasks to help you quickly understand their status.';

  @override
  String get configFlagEnableCalendarPageDescription =>
      'Show the Calendar page in the main navigation. View and manage your entries in a calendar view.';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Show the Dashboards page in the main navigation. View your data and insights in customizable dashboards.';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Show the Habits page in the main navigation. Track and manage your daily habits here.';

  @override
  String get configFlagEnableLoggingDescription =>
      'Enable detailed logging for debugging purposes. This may impact performance.';

  @override
  String get configFlagEnableMatrixDescription =>
      'Enable the Matrix integration to sync your entries across devices and with other Matrix users.';

  @override
  String get configFlagEnableNotifications => 'Enable notifications?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Receive notifications for reminders, updates, and important events.';

  @override
  String get configFlagEnableTooltipDescription =>
      'Show helpful tooltips throughout the app to guide you through features.';

  @override
  String get configFlagPrivate => 'Show private entries?';

  @override
  String get configFlagPrivateDescription =>
      'Enable this to make your entries private by default. Private entries are only visible to you.';

  @override
  String get configFlagRecordLocationDescription =>
      'Automatically record your location with new entries. This helps with location-based organization and search.';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Enable this to automatically resend failed attachment uploads when the connection is restored.';

  @override
  String get configFlagUseCloudInferenceDescription =>
      'Use cloud-based AI services for enhanced features. This requires an internet connection.';

  @override
  String get conflictsResolved => 'resolved';

  @override
  String get conflictsUnresolved => 'unresolved';

  @override
  String get createCategoryTitle => 'Create Category:';

  @override
  String get createEntryLabel => 'Create new entry';

  @override
  String get createEntryTitle => 'Add';

  @override
  String get dashboardActiveLabel => 'Active:';

  @override
  String get dashboardAddChartsTitle => 'Add Charts:';

  @override
  String get dashboardAddHabitButton => 'Habit Charts';

  @override
  String get dashboardAddHabitTitle => 'Habit Charts';

  @override
  String get dashboardAddHealthButton => 'Health Charts';

  @override
  String get dashboardAddHealthTitle => 'Health Charts';

  @override
  String get dashboardAddMeasurementButton => 'Measurement Charts';

  @override
  String get dashboardAddMeasurementTitle => 'Measurement Charts';

  @override
  String get dashboardAddSurveyButton => 'Survey Charts';

  @override
  String get dashboardAddSurveyTitle => 'Survey Charts';

  @override
  String get dashboardAddWorkoutButton => 'Workout Charts';

  @override
  String get dashboardAddWorkoutTitle => 'Workout Charts';

  @override
  String get dashboardAggregationLabel => 'Aggregation Type:';

  @override
  String get dashboardCategoryLabel => 'Category:';

  @override
  String get dashboardCopyHint => 'Save & Copy dashboard config';

  @override
  String get dashboardDeleteConfirm => 'YES, DELETE THIS DASHBOARD';

  @override
  String get dashboardDeleteHint => 'Delete dashboard';

  @override
  String get dashboardDeleteQuestion => 'Do you want to delete this dashboard?';

  @override
  String get dashboardDescriptionLabel => 'Description (optional):';

  @override
  String get dashboardNameLabel => 'Dashboard name:';

  @override
  String get dashboardNotFound => 'Dashboard not found';

  @override
  String get dashboardPrivateLabel => 'Private:';

  @override
  String get done => 'Done';

  @override
  String get doneButton => 'Done';

  @override
  String get editMenuTitle => 'Edit';

  @override
  String get editorPlaceholder => 'Enter notes...';

  @override
  String get entryActions => 'Actions';

  @override
  String get eventNameLabel => 'Event:';

  @override
  String get fileMenuNewEllipsis => 'New ...';

  @override
  String get fileMenuNewEntry => 'New Entry';

  @override
  String get fileMenuNewScreenshot => 'Screenshot';

  @override
  String get fileMenuNewTask => 'Task';

  @override
  String get fileMenuTitle => 'File';

  @override
  String get habitActiveFromLabel => 'Start Date';

  @override
  String get habitArchivedLabel => 'Archived:';

  @override
  String get habitCategoryHint => 'Select Category...';

  @override
  String get habitCategoryLabel => 'Category:';

  @override
  String get habitDashboardHint => 'Select Dashboard...';

  @override
  String get habitDashboardLabel => 'Dashboard:';

  @override
  String get habitDeleteConfirm => 'YES, DELETE THIS HABIT';

  @override
  String get habitDeleteQuestion => 'Do you want to delete this habit?';

  @override
  String get habitPriorityLabel => 'Priority:';

  @override
  String get habitsCompletedHeader => 'Completed';

  @override
  String get habitsFilterAll => 'all';

  @override
  String get habitsFilterCompleted => 'done';

  @override
  String get habitsFilterOpenNow => 'due';

  @override
  String get habitsFilterPendingLater => 'later';

  @override
  String get habitShowAlertAtLabel => 'Show alert at';

  @override
  String get habitShowFromLabel => 'Show from';

  @override
  String get habitsOpenHeader => 'Due now';

  @override
  String get habitsPendingLaterHeader => 'Later today';

  @override
  String get inputDataTypeAudioFilesDescription => 'Use audio files as input';

  @override
  String get inputDataTypeAudioFilesName => 'Audio Files';

  @override
  String get inputDataTypeImagesDescription => 'Use images as input';

  @override
  String get inputDataTypeImagesName => 'Images';

  @override
  String get inputDataTypeTaskDescription => 'Use the current task as input';

  @override
  String get inputDataTypeTaskName => 'Task';

  @override
  String get inputDataTypeTasksListDescription =>
      'Use a list of tasks as input';

  @override
  String get inputDataTypeTasksListName => 'Tasks List';

  @override
  String get journalCopyImageLabel => 'Copy image';

  @override
  String get journalDateFromLabel => 'Date from:';

  @override
  String get journalDateInvalid => 'Invalid Date Range';

  @override
  String get journalDateNowButton => 'Now';

  @override
  String get journalDateSaveButton => 'SAVE';

  @override
  String get journalDateToLabel => 'Date to:';

  @override
  String get journalDeleteConfirm => 'YES, DELETE THIS ENTRY';

  @override
  String get journalDeleteHint => 'Delete entry';

  @override
  String get journalDeleteQuestion =>
      'Do you want to delete this journal entry?';

  @override
  String get journalDurationLabel => 'Duration:';

  @override
  String get journalFavoriteTooltip => 'starred only';

  @override
  String get journalFlaggedTooltip => 'flagged only';

  @override
  String get journalHideMapHint => 'Hide map';

  @override
  String get journalLinkedEntriesAiLabel => 'Show AI-generated entries:';

  @override
  String get journalLinkedEntriesHiddenLabel => 'Show hidden entries:';

  @override
  String get journalLinkedEntriesLabel => 'Linked Entries';

  @override
  String get journalLinkedFromLabel => 'Linked from:';

  @override
  String get journalLinkFromHint => 'Link from';

  @override
  String get journalLinkToHint => 'Link to';

  @override
  String get journalPrivateTooltip => 'private only';

  @override
  String get journalSearchHint => 'Search journal...';

  @override
  String get journalShareAudioHint => 'Share audio';

  @override
  String get journalSharePhotoHint => 'Share photo';

  @override
  String get journalShowMapHint => 'Show map';

  @override
  String get journalTagPlusHint => 'Manage entry tags';

  @override
  String get journalTagsCopyHint => 'Copy tags';

  @override
  String get journalTagsLabel => 'Tags:';

  @override
  String get journalTagsPasteHint => 'Paste tags';

  @override
  String get journalTagsRemoveHint => 'Remove tag';

  @override
  String get journalToggleFlaggedTitle => 'Flagged';

  @override
  String get journalTogglePrivateTitle => 'Private';

  @override
  String get journalToggleStarredTitle => 'Favorite';

  @override
  String get journalUnlinkConfirm => 'YES, UNLINK ENTRY';

  @override
  String get journalUnlinkHint => 'Unlink';

  @override
  String get journalUnlinkQuestion =>
      'Are you sure you want to unlink this entry?';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'YES, DELETE DATABASE';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Are you sure you want to delete $databaseName Database?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Delete Editor Database';

  @override
  String get maintenanceDeleteLoggingDb => 'Delete Logging Database';

  @override
  String get maintenanceDeleteSyncDb => 'Delete Sync Database';

  @override
  String get maintenancePurgeAudioModels => 'Purge audio models';

  @override
  String get maintenancePurgeAudioModelsMessage =>
      'Are you sure you want to purge all audio models? This action cannot be undone.';

  @override
  String get maintenancePurgeAudioModelsConfirm => 'YES, PURGE MODELS';

  @override
  String get maintenancePurgeDeleted => 'Purge deleted items';

  @override
  String get maintenancePurgeDeletedConfirm => 'Yes, purge all';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Are you sure you want to purge all deleted items? This action cannot be undone.';

  @override
  String get maintenanceRecreateFts5 => 'Recreate full-text index';

  @override
  String get maintenanceRecreateFts5Message =>
      'Are you sure you want to recreate the full-text index? This may take some time.';

  @override
  String get maintenanceRecreateFts5Confirm => 'YES, RECREATE INDEX';

  @override
  String get maintenanceReSync => 'Re-sync messages';

  @override
  String get maintenanceSyncDefinitions =>
      'Sync tags, measurables, dashboards, habits, categories';

  @override
  String get measurableDeleteConfirm => 'YES, DELETE THIS MEASURABLE';

  @override
  String get measurableDeleteQuestion =>
      'Do you want to delete this measurable data type?';

  @override
  String get measurableNotFound => 'Measurable not found';

  @override
  String get modalityAudioDescription => 'Audio processing capabilities';

  @override
  String get modalityAudioName => 'Audio';

  @override
  String get modalityImageDescription => 'Image processing capabilities';

  @override
  String get modalityImageName => 'Image';

  @override
  String get modalityTextDescription => 'Text-based content and processing';

  @override
  String get modalityTextName => 'Text';

  @override
  String get modelAddPageTitle => 'Add Model';

  @override
  String get modelEditLoadError => 'Failed to load model configuration';

  @override
  String get modelEditPageTitle => 'Edit Model';

  @override
  String get modelsSettingsPageTitle => 'AI Models';

  @override
  String get navTabTitleCalendar => 'Calendar';

  @override
  String get navTabTitleHabits => 'Habits';

  @override
  String get navTabTitleInsights => 'Dashboards';

  @override
  String get navTabTitleJournal => 'Logbook';

  @override
  String get navTabTitleSettings => 'Settings';

  @override
  String get navTabTitleTasks => 'Tasks';

  @override
  String get outboxMonitorLabelAll => 'all';

  @override
  String get outboxMonitorLabelError => 'error';

  @override
  String get outboxMonitorLabelPending => 'pending';

  @override
  String get outboxMonitorLabelSent => 'sent';

  @override
  String get outboxMonitorNoAttachment => 'no attachment';

  @override
  String get outboxMonitorRetries => 'retries';

  @override
  String get outboxMonitorRetry => 'retry';

  @override
  String get outboxMonitorSwitchLabel => 'enabled';

  @override
  String get promptAddPageTitle => 'Add Prompt';

  @override
  String get promptEditLoadError => 'Failed to load prompt';

  @override
  String get promptEditPageTitle => 'Edit Prompt';

  @override
  String get promptSettingsPageTitle => 'AI Prompts';

  @override
  String get saveButtonLabel => 'Save';

  @override
  String get saveLabel => 'Save';

  @override
  String get searchHint => 'Search...';

  @override
  String get settingsAboutTitle => 'About Lotti';

  @override
  String get settingsAdvancedShowCaseAboutLottiTooltip =>
      'Learn more about the Lotti application, including version and credits.';

  @override
  String get settingsAdvancedShowCaseApiKeyTooltip =>
      'Manage your API keys for various AI providers. Add, edit, or delete keys to configure integrations with supported services like OpenAI, Gemini, and more. Ensure secure handling of sensitive information.';

  @override
  String get settingsAdvancedShowCaseConflictsTooltip =>
      'Resolve synchronization conflicts to ensure data consistency.';

  @override
  String get settingsAdvancedShowCaseHealthImportTooltip =>
      'Import health-related data from external sources.';

  @override
  String get settingsAdvancedShowCaseLogsTooltip =>
      'Access and review application logs for debugging and monitoring.';

  @override
  String get settingsAdvancedShowCaseMaintenanceTooltip =>
      'Perform maintenance tasks to optimize application performance.';

  @override
  String get settingsAdvancedShowCaseMatrixSyncTooltip =>
      'Configure and manage Matrix synchronization settings for seamless data integration.';

  @override
  String get settingsAdvancedShowCaseModelsTooltip =>
      'Define AI models that use inference providers';

  @override
  String get settingsAdvancedShowCaseSyncOutboxTooltip =>
      'View and manage items waiting to be synchronized in the outbox.';

  @override
  String get settingsAdvancedTitle => 'Advanced Settings';

  @override
  String get settingsAiApiKeys => 'API Keys';

  @override
  String get settingsAiModels => 'AI Models';

  @override
  String get settingsCategoriesDetailsLabel => 'Category Details';

  @override
  String get settingsCategoriesDuplicateError => 'Category exists already';

  @override
  String get settingsCategoriesNameLabel => 'Category name:';

  @override
  String get settingsCategoriesTitle => 'Categories';

  @override
  String get settingsCategoryShowCaseActiveTooltip =>
      'Toggle this option to mark the category as active. Active categories are currently in use and will be prominently displayed for easier accessibility.';

  @override
  String get settingsCategoryShowCaseColorTooltip =>
      'Select a color to represent this category. You can either enter a valid HEX color code (e.g., #FF5733) or use the color picker on the right to choose a color visually.';

  @override
  String get settingsCategoryShowCaseDelTooltip =>
      'Click this button to delete the category. Please note that this action is irreversible, so ensure you want to remove the category before proceeding.';

  @override
  String get settingsCategoryShowCaseFavTooltip =>
      '\'Enable this option to mark the category as a favorite. Favorite categories are easier to access and are highlighted for quick reference.\'';

  @override
  String get settingsCategoryShowCaseNameTooltip =>
      'Enter a clear and relevant name for the category. Keep it short and descriptive so you can easily identify its purpose.';

  @override
  String get settingsCategoryShowCasePrivateTooltip =>
      'Toggle this option to mark the category as private. Private categories are only visible to you and help in organizing sensitive or personal habits and tasks securely.';

  @override
  String get settingsConflictsResolutionTitle => 'Sync Conflict Resolution';

  @override
  String get settingsConflictsTitle => 'Sync Conflicts';

  @override
  String get settingsDashboardDetailsLabel => 'Dashboard Details';

  @override
  String get settingsDashboardSaveLabel => 'Save';

  @override
  String get settingsDashboardsShowCaseActiveTooltip =>
      'Toggle this switch to mark the dashboard as active. Active dashboards are currently in use and will be prominently displayed for easier accessibility.';

  @override
  String get settingsDashboardsShowCaseCatTooltip =>
      'Select a category that best describes the dashboard. This helps in organizing and categorizing your dashboards effectively. Examples: \'Health\', \'Productivity\', \'Work\'.';

  @override
  String get settingsDashboardsShowCaseCopyTooltip =>
      'Tap to copy this dashboard. This will allow you to duplicate the dashboard and use them elsewhere.';

  @override
  String get settingsDashboardsShowCaseDelTooltip =>
      'Tap this button to permanently delete the dashboard. Be cautious, as this action cannot be undone and all related data will be removed.';

  @override
  String get settingsDashboardsShowCaseDescrTooltip =>
      'Provide a detailed description for the dashboard. This helps in understanding the purpose and contents of the dashboard. Examples: \'Tracks daily wellness activities\', \'Monitors work-related tasks and goals\'.';

  @override
  String get settingsDashboardsShowCaseHealthChartsTooltip =>
      'Select the health charts you want to include in your dashboard. Examples: \'Weight\', \'Body Fat Percentage\'.';

  @override
  String get settingsDashboardsShowCaseNameTooltip =>
      'Enter a clear and relevant name for the dashboard. Keep it short and descriptive so you can easily identify its purpose. Examples: \'Wellness Track\', \'Daily Goals\', \'Work Schedule\'.';

  @override
  String get settingsDashboardsShowCasePrivateTooltip =>
      'Toggle this switch to make the dashboard private. Private dashboards are only visible to you and won\'t be shared with others.';

  @override
  String get settingsDashboardsShowCaseSurveyChartsTooltip =>
      'Select the survey charts you want to include in your dashboard. Examples: \'Customer Satisfaction\', \'Employee Feedback\'.';

  @override
  String get settingsDashboardsShowCaseWorkoutChartsTooltip =>
      'Select the workout charts you want to include in your dashboard. Examples: \'Walking\', \'Running\', \'Swimming\'.';

  @override
  String get settingsDashboardsTitle => 'Dashboards';

  @override
  String get settingsFlagsTitle => 'Config Flags';

  @override
  String get settingsHabitsDeleteTooltip => 'Delete Habit';

  @override
  String get settingsHabitsDescriptionLabel => 'Description (optional):';

  @override
  String get settingsHabitsDetailsLabel => 'Habit Details';

  @override
  String get settingsHabitsNameLabel => 'Habit name:';

  @override
  String get settingsHabitsPrivateLabel => 'Private: ';

  @override
  String get settingsHabitsSaveLabel => 'Save';

  @override
  String get settingsHabitsShowCaseAlertTimeTooltip =>
      'Set the specific time you want to receive a reminder or alert for this habit. This ensures you never miss completing it. Example: \'8:00 PM\'.';

  @override
  String get settingsHabitsShowCaseArchivedTooltip =>
      'Toggle this switch to archive the habit. Archived habits are no longer active but remain saved for future reference or review. Examples: \'Learn Guitar\', \'Completed Course\'.';

  @override
  String get settingsHabitsShowCaseCatTooltip =>
      'Choose a category that best describes your habit or create a new one by selecting the [+] button.\nExamples: \'Health\', \'Productivity\', \'Exercise\'.';

  @override
  String get settingsHabitsShowCaseDashTooltip =>
      'Select a dashboard to organize and track your habit, or create a new dashboard using the [+] button.\nExamples: \'Wellness Tracker\', \'Daily Goals\', \'Work Schedule\'.';

  @override
  String get settingsHabitsShowCaseDelHabitTooltip =>
      'Tap this button to permanently delete the habit. Be cautious, as this action cannot be undone and all related data will be removed.';

  @override
  String get settingsHabitsShowCaseDescrTooltip =>
      'Provide a brief and meaningful description of the habit. Include any relevant details or \ncontext to clearly define the habit\'s purpose and importance. \nExamples: \'Jog for 30 minutes every morning to boost fitness\' or \'Read one chapter daily to improve knowledge and focus\'';

  @override
  String get settingsHabitsShowCaseNameTooltip =>
      'Enter a clear and descriptive name for the habit.\nAvoid overly long names, and make it concise enough to identify the habit easily. \nExamples: \'Morning Jogs\', \'Read Daily\'.';

  @override
  String get settingsHabitsShowCasePriorTooltip =>
      'Toggle the switch to assign priority to the habit. High-priority habits often represent essential or urgent tasks you want to focus on. Examples: \'Exercise Daily\', \'Work on Project\'.';

  @override
  String get settingsHabitsShowCasePrivateTooltip =>
      'Use this switch to mark the habit as private. Private habits are only visible to you and will not be shared with others. Examples: \'Personal Journal\', \'Meditation\'.';

  @override
  String get settingsHabitsShowCaseStarDateTooltip =>
      'Select the date you want to start tracking this habit. This helps to define when the habit begins and allows for accurate progress monitoring. Example: \'July 1, 2025\'.';

  @override
  String get settingsHabitsShowCaseStartTimeTooltip =>
      'Set the time from which this habit should be visible or start appearing in your schedule. This helps organize your day effectively. Example: \'7:00 AM\'.';

  @override
  String get settingsHabitsTitle => 'Habits';

  @override
  String get settingsHealthImportFromDate => 'Start';

  @override
  String get settingsHealthImportTitle => 'Health Import';

  @override
  String get settingsHealthImportToDate => 'End';

  @override
  String get settingsLogsTitle => 'Logs';

  @override
  String get settingsMaintenanceTitle => 'Maintenance';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'Other device shows emojis, continue';

  @override
  String get settingsMatrixCancel => 'Cancel';

  @override
  String get settingsMatrixCancelVerificationLabel => 'Cancel Verification';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Accept on other device to continue';

  @override
  String get settingsMatrixDeleteLabel => 'Delete';

  @override
  String get settingsMatrixDone => 'Done';

  @override
  String get settingsMatrixEnterValidUrl => 'Please enter a valid URL';

  @override
  String get settingsMatrixHomeserverConfigTitle => 'Matrix Homeserver Setup';

  @override
  String get settingsMatrixHomeServerLabel => 'Homeserver';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Unverified devices';

  @override
  String get settingsMatrixLoginButtonLabel => 'Login';

  @override
  String get settingsMatrixLoginFailed => 'Login failed';

  @override
  String get settingsMatrixLogoutButtonLabel => 'Logout';

  @override
  String get settingsMatrixNextPage => 'Next Page';

  @override
  String get settingsMatrixNoUnverifiedLabel => 'No unverified devices';

  @override
  String get settingsMatrixPasswordLabel => 'Password';

  @override
  String get settingsMatrixPasswordTooShort => 'Password too short';

  @override
  String get settingsMatrixPreviousPage => 'Previous Page';

  @override
  String get settingsMatrixQrTextPage =>
      'Scan this QR code to invite device to a sync room.';

  @override
  String get settingsMatrixRoomConfigTitle => 'Matrix Sync Room Setup';

  @override
  String get settingsMatrixStartVerificationLabel => 'Start Verification';

  @override
  String get settingsMatrixStatsTitle => 'Matrix Stats';

  @override
  String get settingsMatrixTitle => 'Matrix Sync Settings';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Unverified Devices';

  @override
  String get settingsMatrixUserLabel => 'User';

  @override
  String get settingsMatrixUserNameTooShort => 'User name too short';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Cancelled on other device...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Got it';

  @override
  String settingsMatrixVerificationSuccessLabel(
      String deviceName, String deviceID) {
    return 'You\'ve successfully verified $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Confirm on other device that the emojis below are displayed on both devices, in the same order:';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Confirm that the emojis below are displayed on both devices, in the same order:';

  @override
  String get settingsMatrixVerifyLabel => 'Verify';

  @override
  String get settingsMeasurableAggregationLabel =>
      'Default Aggregation Type (optional):';

  @override
  String get settingsMeasurableDeleteTooltip => 'Delete measurable type';

  @override
  String get settingsMeasurableDescriptionLabel => 'Description (optional):';

  @override
  String get settingsMeasurableDetailsLabel => 'Measurable Details';

  @override
  String get settingsMeasurableFavoriteLabel => 'Favorite: ';

  @override
  String get settingsMeasurableNameLabel => 'Measurable name:';

  @override
  String get settingsMeasurablePrivateLabel => 'Private: ';

  @override
  String get settingsMeasurableSaveLabel => 'Save';

  @override
  String get settingsMeasurableShowCaseAggreTypeTooltip =>
      'Select the default aggregation type for the measurable data. This determines how the data will be summarized over time. \nOptions: \'dailySum\', \'dailyMax\', \'dailyAvg\', \'hourlySum\'.';

  @override
  String get settingsMeasurableShowCaseDelTooltip =>
      'Click this button to delete the measurable type. Please note that this action is irreversible, so ensure you want to remove the measurable type before proceeding.';

  @override
  String get settingsMeasurableShowCaseDescrTooltip =>
      'Provide a brief and meaningful description of the measurable type. Include any relevant details or context to clearly define its purpose and importance. \nExamples: \'Body weight measured in kilograms\'';

  @override
  String get settingsMeasurableShowCaseNameTooltip =>
      'Enter a clear and descriptive name for the measurable type.\nAvoid overly long names, and make it concise enough to identify the measurable type easily. \nExamples: \'Weight\', \'Blood Pressure\'.';

  @override
  String get settingsMeasurableShowCasePrivateTooltip =>
      'Toggle this option to mark the measurable type as private. Private measurable types are only visible to you and help in organizing sensitive or personal data securely.';

  @override
  String get settingsMeasurableShowCaseUnitTooltip =>
      'Enter a clear and concise unit abbreviation for the measurable type. This helps in identifying the unit of measurement easily.';

  @override
  String get settingsMeasurablesTitle => 'Measurable Types';

  @override
  String get settingsMeasurableUnitLabel => 'Unit abbreviation (optional):';

  @override
  String get settingsSpeechAudioWithoutTranscript =>
      'Audio entries without transcript:';

  @override
  String get settingsSpeechAudioWithoutTranscriptButton => 'Find & transcribe';

  @override
  String get settingsSpeechLastActivity => 'Last transcription activity:';

  @override
  String get settingsSpeechModelSelectionTitle =>
      'Whisper speech recognition model:';

  @override
  String get settingsSpeechTitle => 'Speech Settings';

  @override
  String get settingsSyncOutboxTitle => 'Sync Outbox';

  @override
  String get settingsTagsDeleteTooltip => 'Delete tag';

  @override
  String get settingsTagsDetailsLabel => 'Tags Details';

  @override
  String get settingsTagsHideLabel => 'Hide from suggestions:';

  @override
  String get settingsTagsPrivateLabel => 'Private:';

  @override
  String get settingsTagsSaveLabel => 'Save';

  @override
  String get settingsTagsShowCaseDeleteTooltip =>
      'Remove this tag permanently. This action cannot be undone.';

  @override
  String get settingsTagsShowCaseHideTooltip =>
      'Enable this option to hide this tag from suggestions. Use it for tags that are personal or not commonly needed.';

  @override
  String get settingsTagsShowCaseNameTooltip =>
      'Enter a clear and relevant name for the tag. Keep it short and descriptive so you can easily categorize your habits Examples: \"Health\", \"Productivity\", \"Mindfulness\".';

  @override
  String get settingsTagsShowCasePrivateTooltip =>
      'Enable this option to make the tag private. Private tags are only visible to you and won\'t be shared with others.';

  @override
  String get settingsTagsShowCaseTypeTooltip =>
      'Select the type of tag to categorize it properly: \n[Tag]-> General categories like \'Health\' or \'Productivity\'. \n[Person]-> Use for tagging specific individuals. \n[Story]-> Attach tags to stories for better organization.';

  @override
  String get settingsTagsTagName => 'Tag:';

  @override
  String get settingsTagsTitle => 'Tags';

  @override
  String get settingsTagsTypeLabel => 'Tag type:';

  @override
  String get settingsTagsTypePerson => 'PERSON';

  @override
  String get settingsTagsTypeStory => 'STORY';

  @override
  String get settingsTagsTypeTag => 'TAG';

  @override
  String get settingsThemingAutomatic => 'Automatic';

  @override
  String get settingsThemingDark => 'Dark Appearance';

  @override
  String get settingsThemingLight => 'Light Appearance';

  @override
  String get settingsThemingShowCaseDarkTooltip =>
      'Choose the dark theme for a darker appearance.';

  @override
  String get settingsThemingShowCaseLightTooltip =>
      'Choose the light theme for a brighter appearance.';

  @override
  String get settingsThemingShowCaseModeTooltip =>
      'Select your preferred theme mode: Light, Dark, or Automatic.';

  @override
  String get settingsThemingTitle => 'Theming';

  @override
  String get settingThemingDark => 'Dark Theme';

  @override
  String get settingThemingLight => 'Light Theme';

  @override
  String get showcaseCloseButton => 'close';

  @override
  String get showcaseNextButton => 'next';

  @override
  String get showcasePreviousButton => 'previous';

  @override
  String get speechModalAddTranscription => 'Add Transcription';

  @override
  String get speechModalSelectLanguage => 'Select Language';

  @override
  String get speechModalTitle => 'Speech Recognition';

  @override
  String get speechModalTranscriptionProgress => 'Transcription Progress';

  @override
  String get syncDeleteConfigConfirm => 'YES, I\'M SURE';

  @override
  String get syncDeleteConfigQuestion =>
      'Do you want to delete the sync configuration?';

  @override
  String get syncEntitiesConfirm => 'YES, SYNC ALL';

  @override
  String get syncEntitiesMessage =>
      'This will sync all tags, measurables, and categories. Do you want to continue?';

  @override
  String get syncStepCategories => 'Categories';

  @override
  String get syncStepComplete => 'Complete';

  @override
  String get syncStepDashboards => 'Dashboards';

  @override
  String get syncStepHabits => 'Habits';

  @override
  String get syncStepMeasurables => 'Measurables';

  @override
  String get syncStepTags => 'Tags';

  @override
  String get taskCategoryAllLabel => 'all';

  @override
  String get taskCategoryLabel => 'Category:';

  @override
  String get taskCategoryUnassignedLabel => 'unassigned';

  @override
  String get taskEstimateLabel => 'Estimate:';

  @override
  String get taskNameHint => 'Enter a name for the task';

  @override
  String get tasksFilterTitle => 'Tasks Filter';

  @override
  String get taskStatusAll => 'All';

  @override
  String get taskStatusBlocked => 'Blocked';

  @override
  String get taskStatusDone => 'Done';

  @override
  String get taskStatusGroomed => 'Groomed';

  @override
  String get taskStatusInProgress => 'In Progress';

  @override
  String get taskStatusLabel => 'Status:';

  @override
  String get taskStatusOnHold => 'On Hold';

  @override
  String get taskStatusOpen => 'Open';

  @override
  String get taskStatusRejected => 'Rejected';

  @override
  String get timeByCategoryChartTitle => 'Time by Category';

  @override
  String get timeByCategoryChartTotalLabel => 'Total';

  @override
  String get viewMenuTitle => 'View';
}

/// The translations for English, as used in the United Kingdom (`en_GB`).
class AppLocalizationsEnGb extends AppLocalizationsEn {
  AppLocalizationsEnGb() : super('en_GB');

  @override
  String get addActionAddAudioRecording => 'Audio Recording';

  @override
  String get addActionAddChecklist => 'Checklist';

  @override
  String get addActionAddEvent => 'Event';

  @override
  String get addActionAddImageFromClipboard => 'Paste Image';

  @override
  String get addActionAddPhotos => 'Photo(s)';

  @override
  String get addActionAddScreenshot => 'Screenshot';

  @override
  String get addActionAddTask => 'Task';

  @override
  String get addActionAddText => 'Text Entry';

  @override
  String get addActionAddTimeRecording => 'Timer Entry';

  @override
  String get addAudioTitle => 'Audio Recording';

  @override
  String get addHabitCommentLabel => 'Comment';

  @override
  String get addHabitDateLabel => 'Completed at';

  @override
  String get addMeasurementCommentLabel => 'Comment';

  @override
  String get addMeasurementDateLabel => 'Observed at';

  @override
  String get addMeasurementSaveButton => 'Save';

  @override
  String get addSurveyTitle => 'Fill Survey';

  @override
  String get aiAssistantActionItemSuggestions => 'Action Item Suggestions';

  @override
  String get aiAssistantAnalyzeImage => 'Analyse image';

  @override
  String get aiAssistantSummarizeTask => 'Summarise task';

  @override
  String get aiAssistantThinking => 'Thinking...';

  @override
  String get aiAssistantTitle => 'AI Assistant';

  @override
  String get aiAssistantTranscribeAudio => 'Transcribe audio';

  @override
  String get aiTaskSummaryRunning => 'Thinking about summarising task...';

  @override
  String get aiTaskSummaryTitle => 'AI Task Summary';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get categoryDeleteConfirm => 'YES, DELETE THIS CATEGORY';

  @override
  String get categoryDeleteQuestion => 'Do you want to delete this category?';

  @override
  String get categorySearchPlaceholder => 'Search categories...';

  @override
  String get checklistAddItem => 'Add a new item';

  @override
  String get checklistDelete => 'Delete checklist?';

  @override
  String get checklistItemDelete => 'Delete checklist item?';

  @override
  String get checklistItemDeleteCancel => 'Cancel';

  @override
  String get checklistItemDeleteConfirm => 'Confirm';

  @override
  String get checklistItemDeleteWarning => 'This action cannot be undone.';

  @override
  String get checklistItemDrag => 'Drag suggestions into checklist';

  @override
  String get checklistNoSuggestionsTitle => 'No suggested Action Items';

  @override
  String get checklistsTitle => 'Checklists';

  @override
  String get checklistSuggestionsOutdated => 'Outdated';

  @override
  String get checklistSuggestionsRunning =>
      'Thinking about untracked suggestions...';

  @override
  String get checklistSuggestionsTitle => 'Suggested Action Items';

  @override
  String get colorLabel => 'Colour:';

  @override
  String get colorPickerError => 'Invalid Hex colour';

  @override
  String get colorPickerHint => 'Enter Hex colour or pick';

  @override
  String get completeHabitFailButton => 'Fail';

  @override
  String get completeHabitSkipButton => 'Skip';

  @override
  String get completeHabitSuccessButton => 'Success';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'When enabled, the app will attempt to generate embeddings for your entries to improve search and related content suggestions.';

  @override
  String get configFlagAutoTranscribeDescription =>
      'Automatically transcribe audio recordings in your entries. This requires an internet connection.';

  @override
  String get configFlagEnableAutoTaskTldrDescription =>
      'Automatically generate summaries for your tasks to help you quickly understand their status.';

  @override
  String get configFlagEnableCalendarPageDescription =>
      'Show the Calendar page in the main navigation. View and manage your entries in a calendar view.';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Show the Dashboards page in the main navigation. View your data and insights in customisable dashboards.';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Show the Habits page in the main navigation. Track and manage your daily habits here.';

  @override
  String get configFlagEnableLoggingDescription =>
      'Enable detailed logging for debugging purposes. This may impact performance.';

  @override
  String get configFlagEnableMatrixDescription =>
      'Enable the Matrix integration to sync your entries across devices and with other Matrix users.';

  @override
  String get configFlagEnableNotifications => 'Enable notifications?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Receive notifications for reminders, updates, and important events.';

  @override
  String get configFlagEnableTooltipDescription =>
      'Show helpful tooltips throughout the app to guide you through features.';

  @override
  String get configFlagPrivate => 'Show private entries?';

  @override
  String get configFlagPrivateDescription =>
      'Enable this to make your entries private by default. Private entries are only visible to you.';

  @override
  String get configFlagRecordLocationDescription =>
      'Automatically record your location with new entries. This helps with location-based organisation and search.';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Enable this to automatically resend failed attachment uploads when the connection is restored.';

  @override
  String get configFlagUseCloudInferenceDescription =>
      'Use cloud-based AI services for enhanced features. This requires an internet connection.';

  @override
  String get conflictsResolved => 'resolved';

  @override
  String get conflictsUnresolved => 'unresolved';

  @override
  String get createCategoryTitle => 'Create Category:';

  @override
  String get createEntryLabel => 'Create new entry';

  @override
  String get createEntryTitle => 'Add';

  @override
  String get dashboardActiveLabel => 'Active:';

  @override
  String get dashboardAddChartsTitle => 'Add Charts:';

  @override
  String get dashboardAddHabitButton => 'Habit Charts';

  @override
  String get dashboardAddHabitTitle => 'Habit Charts';

  @override
  String get dashboardAddHealthButton => 'Health Charts';

  @override
  String get dashboardAddHealthTitle => 'Health Charts';

  @override
  String get dashboardAddMeasurementButton => 'Measurement Charts';

  @override
  String get dashboardAddMeasurementTitle => 'Measurement Charts';

  @override
  String get dashboardAddSurveyButton => 'Survey Charts';

  @override
  String get dashboardAddSurveyTitle => 'Survey Charts';

  @override
  String get dashboardAddWorkoutButton => 'Workout Charts';

  @override
  String get dashboardAddWorkoutTitle => 'Workout Charts';

  @override
  String get dashboardAggregationLabel => 'Aggregation Type:';

  @override
  String get dashboardCategoryLabel => 'Category:';

  @override
  String get dashboardCopyHint => 'Save & Copy dashboard config';

  @override
  String get dashboardDeleteConfirm => 'YES, DELETE THIS DASHBOARD';

  @override
  String get dashboardDeleteHint => 'Delete dashboard';

  @override
  String get dashboardDeleteQuestion => 'Do you want to delete this dashboard?';

  @override
  String get dashboardDescriptionLabel => 'Description (optional):';

  @override
  String get dashboardNameLabel => 'Dashboard name:';

  @override
  String get dashboardNotFound => 'Dashboard not found';

  @override
  String get dashboardPrivateLabel => 'Private:';

  @override
  String get doneButton => 'Done';

  @override
  String get editMenuTitle => 'Edit';

  @override
  String get editorPlaceholder => 'Enter notes...';

  @override
  String get entryActions => 'Actions';

  @override
  String get eventNameLabel => 'Event:';

  @override
  String get fileMenuNewEllipsis => 'New ...';

  @override
  String get fileMenuNewEntry => 'New Entry';

  @override
  String get fileMenuNewScreenshot => 'Screenshot';

  @override
  String get fileMenuNewTask => 'Task';

  @override
  String get fileMenuTitle => 'File';

  @override
  String get habitActiveFromLabel => 'Start Date';

  @override
  String get habitArchivedLabel => 'Archived:';

  @override
  String get habitCategoryHint => 'Select Category...';

  @override
  String get habitCategoryLabel => 'Category:';

  @override
  String get habitDashboardHint => 'Select Dashboard...';

  @override
  String get habitDashboardLabel => 'Dashboard:';

  @override
  String get habitDeleteConfirm => 'YES, DELETE THIS HABIT';

  @override
  String get habitDeleteQuestion => 'Do you want to delete this habit?';

  @override
  String get habitPriorityLabel => 'Priority:';

  @override
  String get habitsCompletedHeader => 'Completed';

  @override
  String get habitsFilterAll => 'all';

  @override
  String get habitsFilterCompleted => 'done';

  @override
  String get habitsFilterOpenNow => 'due';

  @override
  String get habitsFilterPendingLater => 'later';

  @override
  String get habitShowAlertAtLabel => 'Show alert at';

  @override
  String get habitShowFromLabel => 'Show from';

  @override
  String get habitsOpenHeader => 'Due now';

  @override
  String get habitsPendingLaterHeader => 'Later today';

  @override
  String get journalCopyImageLabel => 'Copy image';

  @override
  String get journalDateFromLabel => 'Date from:';

  @override
  String get journalDateInvalid => 'Invalid Date Range';

  @override
  String get journalDateNowButton => 'Now';

  @override
  String get journalDateSaveButton => 'SAVE';

  @override
  String get journalDateToLabel => 'Date to:';

  @override
  String get journalDeleteConfirm => 'YES, DELETE THIS ENTRY';

  @override
  String get journalDeleteHint => 'Delete entry';

  @override
  String get journalDeleteQuestion =>
      'Do you want to delete this journal entry?';

  @override
  String get journalDurationLabel => 'Duration:';

  @override
  String get journalFavoriteTooltip => 'starred only';

  @override
  String get journalFlaggedTooltip => 'flagged only';

  @override
  String get journalHideMapHint => 'Hide map';

  @override
  String get journalLinkedEntriesAiLabel => 'Show AI-generated entries:';

  @override
  String get journalLinkedEntriesHiddenLabel => 'Show hidden entries:';

  @override
  String get journalLinkedEntriesLabel => 'Linked Entries';

  @override
  String get journalLinkedFromLabel => 'Linked from:';

  @override
  String get journalLinkFromHint => 'Link from';

  @override
  String get journalLinkToHint => 'Link to';

  @override
  String get journalPrivateTooltip => 'private only';

  @override
  String get journalSearchHint => 'Search journal…';

  @override
  String get journalShareAudioHint => 'Share audio';

  @override
  String get journalSharePhotoHint => 'Share photo';

  @override
  String get journalShowMapHint => 'Show map';

  @override
  String get journalTagPlusHint => 'Manage entry tags';

  @override
  String get journalTagsCopyHint => 'Copy tags';

  @override
  String get journalTagsLabel => 'Tags:';

  @override
  String get journalTagsPasteHint => 'Paste tags';

  @override
  String get journalTagsRemoveHint => 'Remove tag';

  @override
  String get journalToggleFlaggedTitle => 'Flagged';

  @override
  String get journalTogglePrivateTitle => 'Private';

  @override
  String get journalToggleStarredTitle => 'Favourite';

  @override
  String get journalUnlinkConfirm => 'YES, UNLINK ENTRY';

  @override
  String get journalUnlinkHint => 'Unlink';

  @override
  String get journalUnlinkQuestion =>
      'Are you sure you want to unlink this entry?';

  @override
  String get maintenanceDeleteEditorDb => 'Delete editor drafts database';

  @override
  String get maintenanceDeleteLoggingDb => 'Delete logging database';

  @override
  String get maintenanceDeleteSyncDb => 'Delete sync database';

  @override
  String get maintenancePurgeAudioModels => 'Purge audio models';

  @override
  String get maintenancePurgeDeleted => 'Purge deleted items';

  @override
  String get maintenanceRecreateFts5 => 'Recreate full-text index';

  @override
  String get maintenanceReSync => 'Re-sync messages';

  @override
  String get maintenanceSyncDefinitions =>
      'Sync tags, measurables, dashboards, habits, categories';

  @override
  String get measurableDeleteConfirm => 'YES, DELETE THIS MEASURABLE';

  @override
  String get measurableDeleteQuestion =>
      'Do you want to delete this measurable data type?';

  @override
  String get measurableNotFound => 'Measurable not found';

  @override
  String get navTabTitleCalendar => 'Calendar';

  @override
  String get navTabTitleHabits => 'Habits';

  @override
  String get navTabTitleInsights => 'Dashboards';

  @override
  String get navTabTitleJournal => 'Logbook';

  @override
  String get navTabTitleSettings => 'Settings';

  @override
  String get navTabTitleTasks => 'Tasks';

  @override
  String get outboxMonitorLabelAll => 'all';

  @override
  String get outboxMonitorLabelError => 'error';

  @override
  String get outboxMonitorLabelPending => 'pending';

  @override
  String get outboxMonitorLabelSent => 'sent';

  @override
  String get outboxMonitorNoAttachment => 'no attachment';

  @override
  String get outboxMonitorRetries => 'retries';

  @override
  String get outboxMonitorRetry => 'retry';

  @override
  String get outboxMonitorSwitchLabel => 'enabled';

  @override
  String get saveLabel => 'Save';

  @override
  String get searchHint => 'Search…';

  @override
  String get settingsAboutTitle => 'About Lotti';

  @override
  String get settingsAdvancedShowCaseAboutLottiTooltip =>
      'Learn more about the Lotti application, including version and credits.';

  @override
  String get settingsAdvancedShowCaseConflictsTooltip =>
      'Resolve synchronisation conflicts to ensure data consistency.';

  @override
  String get settingsAdvancedShowCaseHealthImportTooltip =>
      'Import health-related data from external sources.';

  @override
  String get settingsAdvancedShowCaseLogsTooltip =>
      'Access and review application logs for debugging and monitoring.';

  @override
  String get settingsAdvancedShowCaseMaintenanceTooltip =>
      'Perform maintenance tasks to optimise application performance.';

  @override
  String get settingsAdvancedShowCaseMatrixSyncTooltip =>
      'Configure and manage Matrix synchronisation settings for seamless data integration.';

  @override
  String get settingsAdvancedShowCaseSyncOutboxTooltip =>
      'View and manage items waiting to be synchronised in the outbox.';

  @override
  String get settingsAdvancedTitle => 'Advanced Settings';

  @override
  String get settingsCategoriesDuplicateError => 'Category exists already';

  @override
  String get settingsCategoriesNameLabel => 'Category name:';

  @override
  String get settingsCategoriesTitle => 'Categories';

  @override
  String get settingsCategoryShowCaseActiveTooltip =>
      'Toggle this option to mark the category as active. Active categories are currently in use and will be prominently displayed for easier accessibility.';

  @override
  String get settingsCategoryShowCaseColorTooltip =>
      'Select a colour to represent this category. You can either enter a valid HEX colour code (e.g., #FF5733) or use the colour picker on the right to choose a colour visually.';

  @override
  String get settingsCategoryShowCaseDelTooltip =>
      'Click this button to delete the category. Please note that this action is irreversible, so ensure you want to remove the category before proceeding.';

  @override
  String get settingsCategoryShowCaseFavTooltip =>
      'Enable this option to mark the category as a favourite. Favourite categories are easier to access and are highlighted for quick reference.';

  @override
  String get settingsCategoryShowCaseNameTooltip =>
      'Enter a clear and relevant name for the category. Keep it short and descriptive so you can easily identify its purpose.';

  @override
  String get settingsCategoryShowCasePrivateTooltip =>
      'Toggle this option to mark the category as private. Private categories are only visible to you and help in organising sensitive or personal habits and tasks securely.';

  @override
  String get settingsConflictsResolutionTitle => 'Sync Conflict Resolution';

  @override
  String get settingsConflictsTitle => 'Sync Conflicts';

  @override
  String get settingsDashboardsShowCaseActiveTooltip =>
      'Toggle this switch to mark the dashboard as active. Active dashboards are currently in use and will be prominently displayed for easier accessibility.';

  @override
  String get settingsDashboardsShowCaseCatTooltip =>
      'Select a category that best describes the dashboard. This helps in organising and categorising your dashboards effectively. Examples: \'Health\', \'Productivity\', \'Work\'.';

  @override
  String get settingsDashboardsShowCaseCopyTooltip =>
      'Tap to copy this dashboard. This will allow you to duplicate the dashboard and use them elsewhere.';

  @override
  String get settingsDashboardsShowCaseDelTooltip =>
      'Tap this button to permanently delete the dashboard. Be cautious, as this action cannot be undone and all related data will be removed.';

  @override
  String get settingsDashboardsShowCaseDescrTooltip =>
      'Provide a detailed description for the dashboard. This helps in understanding the purpose and contents of the dashboard. Examples: \'Tracks daily wellness activities\', \'Monitors work-related tasks and goals\'.';

  @override
  String get settingsDashboardsShowCaseHealthChartsTooltip =>
      'Select the health charts you want to include in your dashboard. Examples: \'Weight\', \'Body Fat Percentage\'.';

  @override
  String get settingsDashboardsShowCaseNameTooltip =>
      'Enter a clear and relevant name for the dashboard. Keep it short and descriptive so you can easily identify its purpose. Examples: \'Wellness Track\', \'Daily Goals\', \'Work Schedule\'.';

  @override
  String get settingsDashboardsShowCasePrivateTooltip =>
      'Toggle this switch to make the dashboard private. Private dashboards are only visible to you and won’t be shared with others.';

  @override
  String get settingsDashboardsShowCaseSurveyChartsTooltip =>
      'Select the survey charts you want to include in your dashboard. Examples: \'Customer Satisfaction\', \'Employee Feedback\'.';

  @override
  String get settingsDashboardsShowCaseWorkoutChartsTooltip =>
      'Select the workout charts you want to include in your dashboard. Examples: \'Walking\', \'Running\', \'Swimming\'.';

  @override
  String get settingsDashboardsTitle => 'Dashboards';

  @override
  String get settingsFlagsTitle => 'Config Flags';

  @override
  String get settingsHabitsDeleteTooltip => 'Delete Habit';

  @override
  String get settingsHabitsDescriptionLabel => 'Description (optional):';

  @override
  String get settingsHabitsNameLabel => 'Habit name:';

  @override
  String get settingsHabitsPrivateLabel => 'Private:';

  @override
  String get settingsHabitsSaveLabel => 'Save';

  @override
  String get settingsHabitsShowCaseAlertTimeTooltip =>
      'Set the specific time you want to receive a reminder or alert for this habit. This ensures you never miss completing it. Example: \'8:00 PM\'.';

  @override
  String get settingsHabitsShowCaseArchivedTooltip =>
      'Toggle this switch to archive the habit. Archived habits are no longer active but remain saved for future reference or review. Examples: \'Learn Guitar\', \'Completed Course\'.';

  @override
  String get settingsHabitsShowCaseCatTooltip =>
      'Choose a category that best describes your habit or create a new one by selecting the [+] button.\nExamples: \'Health\', \'Productivity\', \'Exercise\'.';

  @override
  String get settingsHabitsShowCaseDashTooltip =>
      'Select a dashboard to organise and track your habit, or create a new dashboard using the [+] button.\nExamples: \'Wellness Tracker\', \'Daily Goals\', \'Work Schedule\'.';

  @override
  String get settingsHabitsShowCaseDelHabitTooltip =>
      'Tap this button to permanently delete the habit. Be cautious, as this action cannot be undone and all related data will be removed.';

  @override
  String get settingsHabitsShowCaseDescrTooltip =>
      'Provide a brief and meaningful description of the habit. Include any relevant details or \ncontext to clearly define the habit\'s purpose and importance. \nExamples: \'Jog for 30 minutes every morning to boost fitness\' or \'Read one chapter daily to improve knowledge and focus\'';

  @override
  String get settingsHabitsShowCaseNameTooltip =>
      'Enter a clear and descriptive name for the habit.\nAvoid overly long names, and make it concise enough to identify the habit easily. \nExamples: \'Morning Jogs\', \'Read Daily\'.';

  @override
  String get settingsHabitsShowCasePriorTooltip =>
      'Toggle the switch to assign priority to the habit. High-priority habits often represent essential or urgent tasks you want to focus on. Examples: \'Exercise Daily\', \'Work on Project\'.';

  @override
  String get settingsHabitsShowCasePrivateTooltip =>
      'Use this switch to mark the habit as private. Private habits are only visible to you and will not be shared with others. Examples: \'Personal Journal\', \'Meditation\'.';

  @override
  String get settingsHabitsShowCaseStarDateTooltip =>
      'Select the date you want to start tracking this habit. This helps to define when the habit begins and allows for accurate progress monitoring. Example: \'1 July 2025\'.';

  @override
  String get settingsHabitsShowCaseStartTimeTooltip =>
      'Set the time from which this habit should be visible or start appearing in your schedule. This helps organise your day effectively. Example: \'7:00 AM\'.';

  @override
  String get settingsHabitsTitle => 'Habits';

  @override
  String get settingsHealthImportFromDate => 'Start';

  @override
  String get settingsHealthImportTitle => 'Health Import';

  @override
  String get settingsHealthImportToDate => 'End';

  @override
  String get settingsLogsTitle => 'Logs';

  @override
  String get settingsMaintenanceTitle => 'Maintenance';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'Other device shows emojis, continue';

  @override
  String get settingsMatrixCancel => 'Cancel';

  @override
  String get settingsMatrixCancelVerificationLabel => 'Cancel Verification';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Accept on other device to continue';

  @override
  String get settingsMatrixDeleteLabel => 'Delete';

  @override
  String get settingsMatrixDone => 'Done';

  @override
  String get settingsMatrixEnterValidUrl => 'Please enter a valid URL';

  @override
  String get settingsMatrixHomeserverConfigTitle => 'Matrix Homeserver Setup';

  @override
  String get settingsMatrixHomeServerLabel => 'Homeserver';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Unverified devices';

  @override
  String get settingsMatrixLoginButtonLabel => 'Login';

  @override
  String get settingsMatrixLoginFailed => 'Login failed';

  @override
  String get settingsMatrixLogoutButtonLabel => 'Logout';

  @override
  String get settingsMatrixNextPage => 'Next Page';

  @override
  String get settingsMatrixNoUnverifiedLabel => 'No unverified devices';

  @override
  String get settingsMatrixPasswordLabel => 'Password';

  @override
  String get settingsMatrixPasswordTooShort => 'Password too short';

  @override
  String get settingsMatrixPreviousPage => 'Previous Page';

  @override
  String get settingsMatrixQrTextPage =>
      'Scan this QR code to invite device to a sync room.';

  @override
  String get settingsMatrixRoomConfigTitle => 'Matrix Sync Room Setup';

  @override
  String get settingsMatrixStartVerificationLabel => 'Start Verification';

  @override
  String get settingsMatrixStatsTitle => 'Matrix Stats';

  @override
  String get settingsMatrixTitle => 'Matrix Sync Settings';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Unverified Devices';

  @override
  String get settingsMatrixUserLabel => 'User';

  @override
  String get settingsMatrixUserNameTooShort => 'User name too short';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Cancelled on other device…';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Got it';

  @override
  String settingsMatrixVerificationSuccessLabel(
      String deviceName, String deviceID) {
    return 'You’ve successfully verified $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Confirm on other device that the emojis below are displayed on both devices, in the same order:';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Confirm that the emojis below are displayed on both devices, in the same order:';

  @override
  String get settingsMatrixVerifyLabel => 'Verify';

  @override
  String get settingsMeasurableAggregationLabel =>
      'Default Aggregation Type (optional):';

  @override
  String get settingsMeasurableDeleteTooltip => 'Delete measurable type';

  @override
  String get settingsMeasurableDescriptionLabel => 'Description (optional):';

  @override
  String get settingsMeasurableFavoriteLabel => 'Favourite: ';

  @override
  String get settingsMeasurableNameLabel => 'Measurable name:';

  @override
  String get settingsMeasurablePrivateLabel => 'Private:';

  @override
  String get settingsMeasurableSaveLabel => 'Save';

  @override
  String get settingsMeasurableShowCaseAggreTypeTooltip =>
      'Select the default aggregation type for the measurable data. This determines how the data will be summarised over time. \nOptions: \'dailySum\', \'dailyMax\', \'dailyAvg\', \'hourlySum\'.';

  @override
  String get settingsMeasurableShowCaseDelTooltip =>
      'Click this button to delete the measurable type. Please note that this action is irreversible, so ensure you want to remove the measurable type before proceeding.';

  @override
  String get settingsMeasurableShowCaseDescrTooltip =>
      'Provide a brief and meaningful description of the measurable type. Include any relevant details or context to clearly define its purpose and importance. \nExamples: \'Body weight measured in kilograms\'';

  @override
  String get settingsMeasurableShowCaseNameTooltip =>
      'Enter a clear and descriptive name for the measurable type.\nAvoid overly long names, and make it concise enough to identify the measurable type easily. \nExamples: \'Weight\', \'Blood Pressure\'.';

  @override
  String get settingsMeasurableShowCasePrivateTooltip =>
      'Toggle this option to mark the measurable type as private. Private measurable types are only visible to you and help in organising sensitive or personal data securely.';

  @override
  String get settingsMeasurableShowCaseUnitTooltip =>
      'Enter a clear and concise unit abbreviation for the measurable type. This helps in identifying the unit of measurement easily.';

  @override
  String get settingsMeasurablesTitle => 'Measurable Types';

  @override
  String get settingsMeasurableUnitLabel => 'Unit abbreviation (optional):';

  @override
  String get settingsSpeechAudioWithoutTranscript =>
      'Audio entries without transcript:';

  @override
  String get settingsSpeechAudioWithoutTranscriptButton => 'Find & transcribe';

  @override
  String get settingsSpeechLastActivity => 'Last transcription activity:';

  @override
  String get settingsSpeechModelSelectionTitle =>
      'Whisper speech recognition model:';

  @override
  String get settingsSpeechTitle => 'Speech Settings';

  @override
  String get settingsSyncOutboxTitle => 'Sync Outbox';

  @override
  String get settingsTagsDeleteTooltip => 'Delete tag';

  @override
  String get settingsTagsHideLabel => 'Hide from suggestions:';

  @override
  String get settingsTagsPrivateLabel => 'Private:';

  @override
  String get settingsTagsSaveLabel => 'Save';

  @override
  String get settingsTagsShowCaseDeleteTooltip =>
      'Remove this tag permanently. This action cannot be undone.';

  @override
  String get settingsTagsShowCaseHideTooltip =>
      'Enable this option to hide this tag from suggestions. Use it for tags that are personal or not commonly needed.';

  @override
  String get settingsTagsShowCaseNameTooltip =>
      'Enter a clear and relevant name for the tag. Keep it short and descriptive so you can easily categorise your habits. Examples: \"Health\", \"Productivity\", \"Mindfulness\".';

  @override
  String get settingsTagsShowCasePrivateTooltip =>
      'Enable this option to make the tag private. Private tags are only visible to you and won\'t be shared with others.';

  @override
  String get settingsTagsShowCaseTypeTooltip =>
      'Select the type of tag to categorise it properly: \n[Tag]-> General categories like \'Health\' or \'Productivity\'. \n[Person]-> Use for tagging specific individuals. \n[Story]-> Attach tags to stories for better organisation.';

  @override
  String get settingsTagsTagName => 'Tag:';

  @override
  String get settingsTagsTitle => 'Tags';

  @override
  String get settingsTagsTypeLabel => 'Tag type:';

  @override
  String get settingsTagsTypePerson => 'PERSON';

  @override
  String get settingsTagsTypeStory => 'STORY';

  @override
  String get settingsTagsTypeTag => 'TAG';

  @override
  String get settingsThemingAutomatic => 'Automatic';

  @override
  String get settingsThemingDark => 'Dark Appearance';

  @override
  String get settingsThemingLight => 'Light Appearance';

  @override
  String get settingsThemingShowCaseDarkTooltip =>
      'Choose the dark theme for a darker appearance.';

  @override
  String get settingsThemingShowCaseLightTooltip =>
      'Choose the light theme for a brighter appearance.';

  @override
  String get settingsThemingShowCaseModeTooltip =>
      'Select your preferred theme mode: Light, Dark, or Automatic.';

  @override
  String get settingsThemingTitle => 'Theming';

  @override
  String get settingThemingDark => 'Dark Theme';

  @override
  String get settingThemingLight => 'Light Theme';

  @override
  String get showcaseCloseButton => 'Close';

  @override
  String get showcaseNextButton => 'Next';

  @override
  String get showcasePreviousButton => 'Previous';

  @override
  String get speechModalAddTranscription => 'Add Transcription';

  @override
  String get speechModalSelectLanguage => 'Select Language';

  @override
  String get speechModalTitle => 'Speech Recognition';

  @override
  String get speechModalTranscriptionProgress => 'Transcription Progress';

  @override
  String get syncDeleteConfigConfirm => 'YES, I’M SURE';

  @override
  String get syncDeleteConfigQuestion =>
      'Do you want to delete the sync configuration?';

  @override
  String get taskCategoryAllLabel => 'all';

  @override
  String get taskCategoryLabel => 'Category:';

  @override
  String get taskCategoryUnassignedLabel => 'unassigned';

  @override
  String get taskEstimateLabel => 'Estimate:';

  @override
  String get taskNameHint => 'Enter a name for the task';

  @override
  String get tasksFilterTitle => 'Tasks Filter';

  @override
  String get taskStatusAll => 'All';

  @override
  String get taskStatusBlocked => 'Blocked';

  @override
  String get taskStatusDone => 'Done';

  @override
  String get taskStatusGroomed => 'Groomed';

  @override
  String get taskStatusInProgress => 'In Progress';

  @override
  String get taskStatusLabel => 'Status:';

  @override
  String get taskStatusOnHold => 'On Hold';

  @override
  String get taskStatusOpen => 'Open';

  @override
  String get taskStatusRejected => 'Rejected';

  @override
  String get timeByCategoryChartTitle => 'Time by Category';

  @override
  String get timeByCategoryChartTotalLabel => 'Total';

  @override
  String get viewMenuTitle => 'View';
}

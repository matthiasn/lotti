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
  String aiConfigAssociatedModelsRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count associated model$_temp0 removed';
  }

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
  String get aiConfigFailedToLoadModelsGeneric =>
      'Failed to load models. Please try again.';

  @override
  String get loggingFailedToLoad => 'Failed to load logs. Please try again.';

  @override
  String get loggingSearchFailed => 'Search failed. Please try again.';

  @override
  String get loggingFailedToLoadMore =>
      'Failed to load more results. Please try again.';

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
  String get aiConfigListCascadeDeleteWarning =>
      'This will also delete all models associated with this provider.';

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
  String get aiConfigProviderDeletedSuccessfully =>
      'Provider deleted successfully';

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
  String get aiFormCancel => 'Cancel';

  @override
  String get aiFormFixErrors => 'Please fix errors before saving';

  @override
  String get aiFormNoChanges => 'No unsaved changes';

  @override
  String get aiInferenceErrorAuthenticationMessage =>
      'Authentication failed. Please check your API key and ensure it is valid.';

  @override
  String get aiInferenceErrorAuthenticationTitle => 'Authentication Failed';

  @override
  String get aiInferenceErrorConnectionFailedMessage =>
      'Unable to connect to the AI service. Please check your internet connection and ensure the service is accessible.';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Connection Failed';

  @override
  String get aiInferenceErrorInvalidRequestMessage =>
      'The request was invalid. Please check your configuration and try again.';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Invalid Request';

  @override
  String get aiInferenceErrorRateLimitMessage =>
      'You have exceeded the rate limit. Please wait a moment before trying again.';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Rate Limit Exceeded';

  @override
  String get aiInferenceErrorRetryButton => 'Try Again';

  @override
  String get aiInferenceErrorServerMessage =>
      'The AI service encountered an error. Please try again later.';

  @override
  String get aiInferenceErrorServerTitle => 'Server Error';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Suggestions:';

  @override
  String get aiInferenceErrorViewLogButton => 'View Log';

  @override
  String get aiInferenceErrorTimeoutMessage =>
      'The request took too long to complete. Please try again or check if the service is responding.';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Request Timed Out';

  @override
  String get aiInferenceErrorUnknownMessage =>
      'An unexpected error occurred. Please try again.';

  @override
  String get aiInferenceErrorUnknownTitle => 'Error';

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
  String get aiProviderGemma3nDescription =>
      'Local Gemma 3n model with audio transcription capabilities';

  @override
  String get aiProviderGemma3nName => 'Gemma 3n (local)';

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
  String get aiProviderWhisperDescription =>
      'Local Whisper transcription with OpenAI-compatible API';

  @override
  String get aiProviderWhisperName => 'Whisper (local)';

  @override
  String get aiResponseTypeActionItemSuggestions => 'Action Item Suggestions';

  @override
  String get aiResponseTypeAudioTranscription => 'Audio Transcription';

  @override
  String get aiResponseTypeChecklistUpdates => 'Checklist Updates';

  @override
  String get aiResponseTypeImageAnalysis => 'Image Analysis';

  @override
  String get aiResponseTypeTaskSummary => 'Task Summary';

  @override
  String get aiSettingsAddModelButton => 'Add Model';

  @override
  String get aiSettingsAddPromptButton => 'Add Prompt';

  @override
  String get aiSettingsAddProviderButton => 'Add Provider';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Clear all filters';

  @override
  String get aiSettingsClearFiltersButton => 'Clear';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filter by $capability capability';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filter by $provider';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip =>
      'Filter by reasoning capability';

  @override
  String get aiSettingsModalityAudio => 'Audio';

  @override
  String get aiSettingsModalityText => 'Text';

  @override
  String get aiSettingsModalityVision => 'Vision';

  @override
  String get aiSettingsNoModelsConfigured => 'No AI models configured';

  @override
  String get aiSettingsNoPromptsConfigured => 'No AI prompts configured';

  @override
  String get aiSettingsNoProvidersConfigured => 'No AI providers configured';

  @override
  String get aiSettingsPageTitle => 'AI Settings';

  @override
  String get aiSettingsReasoningLabel => 'Reasoning';

  @override
  String get aiSettingsSearchHint => 'Search AI configurations...';

  @override
  String get aiSettingsTabModels => 'Models';

  @override
  String get aiSettingsTabPrompts => 'Prompts';

  @override
  String get aiSettingsTabProviders => 'Providers';

  @override
  String get aiTaskSummaryRunning => 'Thinking about summarizing task...';

  @override
  String get aiTaskSummaryTitle => 'AI Task Summary';

  @override
  String get apiKeyAddPageTitle => 'Add Provider';

  @override
  String get apiKeyEditLoadError => 'Failed to load API key configuration';

  @override
  String get apiKeyEditPageTitle => 'Edit Provider';

  @override
  String get apiKeyFormCreateButton => 'Create';

  @override
  String get apiKeyFormUpdateButton => 'Update';

  @override
  String get apiKeysSettingsPageTitle => 'AI Inference Providers';

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
  String get checklistSuggestionsOutdated => 'Outdated';

  @override
  String get checklistSuggestionsRunning =>
      'Thinking about untracked suggestions...';

  @override
  String get checklistSuggestionsTitle => 'Suggested Action Items';

  @override
  String get checklistExportAsMarkdown => 'Export checklist as Markdown';

  @override
  String get checklistMarkdownCopied => 'Checklist copied as Markdown';

  @override
  String get checklistShareHint => 'Long press to share';

  @override
  String get checklistNothingToExport => 'No items to export';

  @override
  String get checklistExportFailed => 'Export failed';

  @override
  String get checklistsTitle => 'Checklists';

  @override
  String get settingsResetHintsTitle => 'Reset In‑App Hints';

  @override
  String get settingsResetHintsSubtitle =>
      'Clear one‑time tips and onboarding hints';

  @override
  String get settingsResetHintsConfirmQuestion =>
      'Reset in‑app hints shown across the app?';

  @override
  String get settingsResetHintsConfirm => 'Confirm';

  @override
  String settingsResetHintsResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reset $count hints',
      one: 'Reset one hint',
      zero: 'Reset zero hints',
    );
    return '$_temp0';
  }

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
  String get configFlagEnableEventsDescription =>
      'Enable the Events feature to track and manage events in your journal.';

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
  String get configFlagEnableTooltip => 'Enable tooltips';

  @override
  String get configFlagEnableTooltipDescription =>
      'Show helpful tooltips throughout the app to guide you through features.';

  @override
  String get configFlagPrivate => 'Show private entries?';

  @override
  String get configFlagPrivateDescription =>
      'Enable this to make your entries private by default. Private entries are only visible to you.';

  @override
  String get configFlagRecordLocation => 'Record location';

  @override
  String get configFlagRecordLocationDescription =>
      'Automatically record your location with new entries. This helps with location-based organization and search.';

  @override
  String get configFlagResendAttachments => 'Resend attachments';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Enable this to automatically resend failed attachment uploads when the connection is restored.';

  @override
  String get configFlagEnableLogging => 'Enable logging';

  @override
  String get configFlagEnableMatrix => 'Enable Matrix sync';

  @override
  String get configFlagEnableHabitsPage => 'Enable Habits page';

  @override
  String get configFlagEnableDashboardsPage => 'Enable Dashboards page';

  @override
  String get configFlagEnableCalendarPage => 'Enable Calendar page';

  @override
  String get configFlagEnableEvents => 'Enable Events';

  @override
  String get configFlagUseCloudInferenceDescription =>
      'Use cloud-based AI services for enhanced features. This requires an internet connection.';

  @override
  String get conflictsResolved => 'resolved';

  @override
  String get conflictsUnresolved => 'unresolved';

  @override
  String get conflictsResolveLocalVersion => 'Resolve with local version';

  @override
  String get conflictsResolveRemoteVersion => 'Resolve with remote version';

  @override
  String get conflictsCopyTextFromSync => 'Copy Text from Sync';

  @override
  String get createCategoryTitle => 'Create Category:';

  @override
  String get categoryCreationError =>
      'Failed to create category. Please try again.';

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
  String get enhancedPromptFormAdditionalDetailsTitle => 'Additional Details';

  @override
  String get enhancedPromptFormAiResponseTypeSubtitle =>
      'Format of the expected response';

  @override
  String get enhancedPromptFormBasicConfigurationTitle => 'Basic Configuration';

  @override
  String get enhancedPromptFormConfigurationOptionsTitle =>
      'Configuration Options';

  @override
  String get enhancedPromptFormDescription =>
      'Create custom prompts that can be used with your AI models to generate specific types of responses';

  @override
  String get enhancedPromptFormDescriptionHelperText =>
      'Optional notes about this prompt\'s purpose and usage';

  @override
  String get enhancedPromptFormDisplayNameHelperText =>
      'A descriptive name for this prompt template';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Choose from ready-made prompt templates';

  @override
  String get enhancedPromptFormPromptConfigurationTitle =>
      'Prompt Configuration';

  @override
  String get enhancedPromptFormQuickStartDescription =>
      'Start with a pre-built template to save time';

  @override
  String get enhancedPromptFormQuickStartTitle => 'Quick Start';

  @override
  String get enhancedPromptFormRequiredInputDataSubtitle =>
      'Type of data this prompt expects';

  @override
  String get enhancedPromptFormSystemMessageHelperText =>
      'Instructions that define the AI\'s behavior and response style';

  @override
  String get enhancedPromptFormUserMessageHelperText => 'The main prompt text.';

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
  String get habitShowAlertAtLabel => 'Show alert at';

  @override
  String get habitShowFromLabel => 'Show from';

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
  String get journalLinkFromHint => 'Link from';

  @override
  String get journalLinkToHint => 'Link to';

  @override
  String get journalLinkedEntriesAiLabel => 'Show AI-generated entries:';

  @override
  String get journalLinkedEntriesHiddenLabel => 'Show hidden entries:';

  @override
  String get journalLinkedEntriesLabel => 'Linked Entries';

  @override
  String get journalLinkedFromLabel => 'Linked from:';

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
  String get maintenanceDeleteEditorDbDescription =>
      'Delete editor drafts database';

  @override
  String get maintenanceDeleteLoggingDb => 'Delete Logging Database';

  @override
  String get maintenanceDeleteLoggingDbDescription => 'Delete logging database';

  @override
  String get maintenanceDeleteSyncDb => 'Delete Sync Database';

  @override
  String get maintenanceDeleteSyncDbDescription => 'Delete sync database';

  @override
  String get maintenancePurgeDeleted => 'Purge deleted items';

  @override
  String get maintenancePurgeDeletedConfirm => 'Yes, purge all';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Purge all deleted items permanently';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Are you sure you want to purge all deleted items? This action cannot be undone.';

  @override
  String get maintenanceRemoveActionItemSuggestions =>
      'Remove deprecated AI suggestions';

  @override
  String get maintenanceRemoveActionItemSuggestionsDescription =>
      'Remove old action item suggestions';

  @override
  String get maintenanceRemoveActionItemSuggestionsMessage =>
      'Are you sure you want to remove all deprecated action item suggestions? This will permanently delete these entries.';

  @override
  String get maintenanceRemoveActionItemSuggestionsConfirm => 'YES, REMOVE';

  @override
  String get maintenanceReSync => 'Re-sync messages';

  @override
  String get maintenanceReSyncDescription => 'Re-sync messages from server';

  @override
  String get maintenanceRecreateFts5 => 'Recreate full-text index';

  @override
  String get maintenanceRecreateFts5Confirm => 'YES, RECREATE INDEX';

  @override
  String get maintenanceRecreateFts5Description =>
      'Recreate full-text search index';

  @override
  String get maintenanceRecreateFts5Message =>
      'Are you sure you want to recreate the full-text index? This may take some time.';

  @override
  String get maintenanceSyncDefinitions =>
      'Sync tags, measurables, dashboards, habits, categories, AI settings';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sync tags, measurables, dashboards, habits, categories, and AI settings';

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
  String modelManagementSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count model$_temp0 selected';
  }

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
  String get promptAddOrRemoveModelsButton => 'Add or Remove Models';

  @override
  String get promptAddPageTitle => 'Add Prompt';

  @override
  String get promptAiResponseTypeDescription =>
      'Format of the expected response';

  @override
  String get promptAiResponseTypeLabel => 'AI Response Type';

  @override
  String get promptBehaviorDescription =>
      'Configure how the prompt processes and responds';

  @override
  String get promptBehaviorTitle => 'Prompt Behavior';

  @override
  String get promptCancelButton => 'Cancel';

  @override
  String get promptContentDescription => 'Define the system and user prompts';

  @override
  String get promptContentTitle => 'Prompt Content';

  @override
  String get promptDefaultModelBadge => 'Default';

  @override
  String get promptDescriptionHint => 'Describe this prompt';

  @override
  String get promptDescriptionLabel => 'Description';

  @override
  String get promptDetailsDescription => 'Basic information about this prompt';

  @override
  String get promptDetailsTitle => 'Prompt Details';

  @override
  String get promptDisplayNameHint => 'Enter a friendly name';

  @override
  String get promptDisplayNameLabel => 'Display Name';

  @override
  String get promptEditLoadError => 'Failed to load prompt';

  @override
  String get promptEditPageTitle => 'Edit Prompt';

  @override
  String get promptErrorLoadingModel => 'Error loading model';

  @override
  String get promptGoBackButton => 'Go Back';

  @override
  String get promptLoadingModel => 'Loading model...';

  @override
  String get promptModelSelectionDescription =>
      'Choose compatible models for this prompt';

  @override
  String get promptModelSelectionTitle => 'Model Selection';

  @override
  String get promptNoModelsSelectedError =>
      'No models selected. Select at least one model.';

  @override
  String get promptReasoningModeDescription =>
      'Enable for prompts requiring deep thinking';

  @override
  String get promptReasoningModeLabel => 'Reasoning Mode';

  @override
  String get promptRequiredInputDataDescription =>
      'Type of data this prompt expects';

  @override
  String get promptRequiredInputDataLabel => 'Required Input Data';

  @override
  String get promptSaveButton => 'Save Prompt';

  @override
  String get promptSelectInputTypeHint => 'Select input type';

  @override
  String get promptSelectModelsButton => 'Select Models';

  @override
  String get promptSelectResponseTypeHint => 'Select response type';

  @override
  String get promptSelectionModalTitle => 'Select Preconfigured Prompt';

  @override
  String get promptSetDefaultButton => 'Set Default';

  @override
  String get promptSettingsPageTitle => 'AI Prompts';

  @override
  String get promptSystemPromptHint => 'Enter the system prompt...';

  @override
  String get promptSystemPromptLabel => 'System Prompt';

  @override
  String get promptTryAgainMessage => 'Please try again or contact support';

  @override
  String get promptUsePreconfiguredButton => 'Use Preconfigured Prompt';

  @override
  String get promptUserPromptHint => 'Enter the user prompt...';

  @override
  String get promptUserPromptLabel => 'User Prompt';

  @override
  String get saveButtonLabel => 'Save';

  @override
  String get saveLabel => 'Save';

  @override
  String get searchHint => 'Search...';

  @override
  String get settingThemingDark => 'Dark Theme';

  @override
  String get settingThemingLight => 'Light Theme';

  @override
  String get settingsAboutTitle => 'About Lotti';

  @override
  String get settingsAboutAppTagline => 'Your Personal Journal';

  @override
  String get settingsAboutAppInformation => 'App Information';

  @override
  String get settingsAboutYourData => 'Your Data';

  @override
  String get settingsAboutCredits => 'Credits';

  @override
  String get settingsAboutBuiltWithFlutter =>
      'Built with Flutter and love for personal journaling.';

  @override
  String get settingsAboutThankYou => 'Thank you for using Lotti!';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutPlatform => 'Platform';

  @override
  String get settingsAboutBuildType => 'Build Type';

  @override
  String get settingsAboutJournalEntries => 'Journal Entries';

  @override
  String get settingsAdvancedTitle => 'Advanced Settings';

  @override
  String get settingsAdvancedMatrixSyncSubtitle =>
      'Configure and manage Matrix synchronization settings';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'View and manage items waiting to be synchronized';

  @override
  String get settingsAdvancedConflictsSubtitle =>
      'Resolve synchronization conflicts to ensure data consistency';

  @override
  String get settingsAdvancedLogsSubtitle =>
      'Access and review application logs for debugging';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Import health-related data from external sources';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Perform maintenance tasks to optimize application performance';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'Learn more about the Lotti application';

  @override
  String get settingsAiApiKeys => 'AI Inference Providers';

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
  String get settingsCategoriesAddTooltip => 'Add Category';

  @override
  String get settingsCategoriesEmptyState => 'No categories found';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Create a category to organize your entries';

  @override
  String get settingsCategoriesErrorLoading => 'Error loading categories';

  @override
  String get settingsCategoriesHasDefaultLanguage => 'Default language';

  @override
  String get settingsCategoriesHasAiSettings => 'AI settings';

  @override
  String get settingsCategoriesHasAutomaticPrompts => 'Automatic AI';

  @override
  String get categoryNotFound => 'Category not found';

  @override
  String get saveSuccessful => 'Saved successfully';

  @override
  String get basicSettings => 'Basic Settings';

  @override
  String get categoryDefaultLanguageDescription =>
      'Set a default language for tasks in this category';

  @override
  String get aiModelSettings => 'AI Model Settings';

  @override
  String get categoryAiModelDescription =>
      'Control which AI prompts can be used with this category';

  @override
  String get automaticPrompts => 'Automatic Prompts';

  @override
  String get categoryAutomaticPromptsDescription =>
      'Configure prompts that run automatically for different content types';

  @override
  String get enterCategoryName => 'Enter category name';

  @override
  String get categoryNameRequired => 'Category name is required';

  @override
  String get selectColor => 'Select Color';

  @override
  String get selectButton => 'Select';

  @override
  String get privateLabel => 'Private';

  @override
  String get categoryPrivateDescription =>
      'Hide this category when private mode is enabled';

  @override
  String get activeLabel => 'Active';

  @override
  String get categoryActiveDescription =>
      'Inactive categories won\'t appear in selection lists';

  @override
  String get favoriteLabel => 'Favorite';

  @override
  String get categoryFavoriteDescription => 'Mark this category as a favorite';

  @override
  String get defaultLanguage => 'Default Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get noDefaultLanguage => 'No default language';

  @override
  String get noPromptsAvailable => 'No prompts available';

  @override
  String get createPromptsFirst =>
      'Create AI prompts first to configure them here';

  @override
  String get selectAllowedPrompts =>
      'Select which prompts are allowed for this category';

  @override
  String get audioRecordings => 'Audio Recordings';

  @override
  String get checklistUpdates => 'Checklist Updates';

  @override
  String get images => 'Images';

  @override
  String get taskSummaries => 'Task Summaries';

  @override
  String get noPromptsForType => 'No prompts available for this type';

  @override
  String get errorLoadingPrompts => 'Error loading prompts';

  @override
  String get categoryDeleteTitle => 'Delete Category?';

  @override
  String get categoryDeleteConfirmation =>
      'This action cannot be undone. All entries in this category will remain but will no longer be categorized.';

  @override
  String get deleteButton => 'Delete';

  @override
  String get saveButton => 'Save';

  @override
  String get createButton => 'Create';

  @override
  String get settingsConflictsResolutionTitle => 'Sync Conflict Resolution';

  @override
  String get settingsConflictsTitle => 'Sync Conflicts';

  @override
  String get settingsDashboardDetailsLabel => 'Dashboard Details';

  @override
  String get settingsDashboardSaveLabel => 'Save';

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
  String get settingsMatrixHomeServerLabel => 'Homeserver';

  @override
  String get settingsMatrixHomeserverConfigTitle => 'Matrix Homeserver Setup';

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
  String get settingsMatrixRoomInviteTitle => 'Room invite';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Invite to room $roomId from $senderId. Accept?';
  }

  @override
  String get settingsMatrixAccept => 'Accept';

  @override
  String get settingsMatrixRoomConfigTitle => 'Matrix Sync Room Setup';

  @override
  String get settingsMatrixStartVerificationLabel => 'Start Verification';

  @override
  String get settingsMatrixStatsTitle => 'Matrix Stats';

  @override
  String get configFlagEnableSyncV2 => 'Enable Matrix Sync V2';

  @override
  String get configFlagEnableSyncV2Description =>
      'Enable Matrix sync pipeline V2 (requires app restart)';

  @override
  String get settingsMatrixSentMessagesLabel => 'Sent messages:';

  @override
  String get settingsMatrixMessageType => 'Message Type';

  @override
  String get settingsMatrixCount => 'Count';

  @override
  String get settingsMatrixMetric => 'Metric';

  @override
  String get settingsMatrixValue => 'Value';

  @override
  String get settingsMatrixV2Metrics => 'Sync V2 Metrics';

  @override
  String get settingsMatrixV2MetricsNoData => 'Sync V2 Metrics: no data';

  @override
  String get settingsMatrixLastUpdated => 'Last updated:';

  @override
  String get settingsMatrixRefresh => 'Refresh';

  @override
  String get settingsMatrixTitle => 'Matrix Sync Settings';

  @override
  String get settingsMatrixSubtitle => 'Configure end-to-end encrypted sync';

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
  String get settingsMeasurableUnitLabel => 'Unit abbreviation (optional):';

  @override
  String get settingsMeasurablesTitle => 'Measurable Types';

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
  String get settingsThemingTitle => 'Theming';

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
  String get syncEntitiesConfirm => 'START SYNC';

  @override
  String get syncEntitiesMessage => 'Choose the entities you want to sync.';

  @override
  String get syncEntitiesSuccessDescription => 'Everything is up to date.';

  @override
  String get syncEntitiesSuccessTitle => 'Sync complete';

  @override
  String get syncStepAiSettings => 'AI settings';

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
  String get taskLanguageLabel => 'Language:';

  @override
  String get taskLanguageArabic => 'Arabic';

  @override
  String get taskLanguageBengali => 'Bengali';

  @override
  String get taskLanguageBulgarian => 'Bulgarian';

  @override
  String get taskLanguageChinese => 'Chinese';

  @override
  String get taskLanguageCroatian => 'Croatian';

  @override
  String get taskLanguageCzech => 'Czech';

  @override
  String get taskLanguageDanish => 'Danish';

  @override
  String get taskLanguageDutch => 'Dutch';

  @override
  String get taskLanguageEnglish => 'English';

  @override
  String get taskLanguageEstonian => 'Estonian';

  @override
  String get taskLanguageFinnish => 'Finnish';

  @override
  String get taskLanguageFrench => 'French';

  @override
  String get taskLanguageGerman => 'German';

  @override
  String get taskLanguageGreek => 'Greek';

  @override
  String get taskLanguageHebrew => 'Hebrew';

  @override
  String get taskLanguageHindi => 'Hindi';

  @override
  String get taskLanguageHungarian => 'Hungarian';

  @override
  String get taskLanguageIndonesian => 'Indonesian';

  @override
  String get taskLanguageItalian => 'Italian';

  @override
  String get taskLanguageJapanese => 'Japanese';

  @override
  String get taskLanguageKorean => 'Korean';

  @override
  String get taskLanguageLatvian => 'Latvian';

  @override
  String get taskLanguageLithuanian => 'Lithuanian';

  @override
  String get taskLanguageNorwegian => 'Norwegian';

  @override
  String get taskLanguagePolish => 'Polish';

  @override
  String get taskLanguagePortuguese => 'Portuguese';

  @override
  String get taskLanguageRomanian => 'Romanian';

  @override
  String get taskLanguageRussian => 'Russian';

  @override
  String get taskLanguageSerbian => 'Serbian';

  @override
  String get taskLanguageSlovak => 'Slovak';

  @override
  String get taskLanguageSlovenian => 'Slovenian';

  @override
  String get taskLanguageSpanish => 'Spanish';

  @override
  String get taskLanguageSwahili => 'Swahili';

  @override
  String get taskLanguageSwedish => 'Swedish';

  @override
  String get taskLanguageThai => 'Thai';

  @override
  String get taskLanguageTurkish => 'Turkish';

  @override
  String get taskLanguageUkrainian => 'Ukrainian';

  @override
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageNigerianPidgin => 'Nigerian Pidgin';

  @override
  String get taskLanguageYoruba => 'Yoruba';

  @override
  String get taskLanguageSearchPlaceholder => 'Search languages...';

  @override
  String get taskLanguageSelectedLabel => 'Currently selected';

  @override
  String get taskLanguageVietnamese => 'Vietnamese';

  @override
  String get tasksFilterTitle => 'Tasks Filter';

  @override
  String get timeByCategoryChartTitle => 'Time by Category';

  @override
  String get timeByCategoryChartTotalLabel => 'Total';

  @override
  String get viewMenuTitle => 'View';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Error';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get aiTranscribingAudio => 'Transcribing audio...';

  @override
  String get copyAsText => 'Copy as text';

  @override
  String get copyAsMarkdown => 'Copy as Markdown';
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
  String aiConfigAssociatedModelsRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count associated model$_temp0 removed';
  }

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Failed to load models. Please try again.';

  @override
  String get loggingFailedToLoad => 'Failed to load logs. Please try again.';

  @override
  String get loggingSearchFailed => 'Search failed. Please try again.';

  @override
  String get loggingFailedToLoadMore =>
      'Failed to load more results. Please try again.';

  @override
  String get aiConfigListUndoDelete => 'UNDO';

  @override
  String get aiConfigManageModelsButton => 'Manage Models';

  @override
  String get aiConfigProviderDeletedSuccessfully =>
      'Provider deleted successfully';

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
  String get checklistSuggestionsOutdated => 'Outdated';

  @override
  String get checklistSuggestionsRunning =>
      'Thinking about untracked suggestions...';

  @override
  String get checklistSuggestionsTitle => 'Suggested Action Items';

  @override
  String get checklistsTitle => 'Checklists';

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
  String get configFlagEnableTooltip => 'Enable tooltips';

  @override
  String get configFlagEnableTooltipDescription =>
      'Show helpful tooltips throughout the app to guide you through features.';

  @override
  String get configFlagPrivate => 'Show private entries?';

  @override
  String get configFlagPrivateDescription =>
      'Enable this to make your entries private by default. Private entries are only visible to you.';

  @override
  String get configFlagRecordLocation => 'Record location';

  @override
  String get configFlagRecordLocationDescription =>
      'Automatically record your location with new entries. This helps with location-based organisation and search.';

  @override
  String get configFlagResendAttachments => 'Resend attachments';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Enable this to automatically resend failed attachment uploads when the connection is restored.';

  @override
  String get configFlagEnableLogging => 'Enable logging';

  @override
  String get configFlagEnableMatrix => 'Enable Matrix sync';

  @override
  String get configFlagEnableHabitsPage => 'Enable Habits page';

  @override
  String get configFlagEnableDashboardsPage => 'Enable Dashboards page';

  @override
  String get configFlagEnableCalendarPage => 'Enable Calendar page';

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
  String get categoryCreationError =>
      'Failed to create category. Please try again.';

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
  String get habitShowAlertAtLabel => 'Show alert at';

  @override
  String get habitShowFromLabel => 'Show from';

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
  String get journalLinkFromHint => 'Link from';

  @override
  String get journalLinkToHint => 'Link to';

  @override
  String get journalLinkedEntriesAiLabel => 'Show AI-generated entries:';

  @override
  String get journalLinkedEntriesHiddenLabel => 'Show hidden entries:';

  @override
  String get journalLinkedEntriesLabel => 'Linked Entries';

  @override
  String get journalLinkedFromLabel => 'Linked from:';

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
  String get maintenanceDeleteEditorDbDescription =>
      'Delete editor drafts database';

  @override
  String get maintenanceDeleteLoggingDb => 'Delete logging database';

  @override
  String get maintenanceDeleteLoggingDbDescription => 'Delete logging database';

  @override
  String get maintenanceDeleteSyncDb => 'Delete sync database';

  @override
  String get maintenanceDeleteSyncDbDescription => 'Delete sync database';

  @override
  String get maintenancePurgeDeleted => 'Purge deleted items';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Purge all deleted items permanently';

  @override
  String get maintenanceReSync => 'Re-sync messages';

  @override
  String get maintenanceReSyncDescription => 'Re-sync messages from server';

  @override
  String get maintenanceRecreateFts5 => 'Recreate full-text index';

  @override
  String get maintenanceRecreateFts5Description =>
      'Recreate full-text search index';

  @override
  String get maintenanceSyncDefinitions =>
      'Sync tags, measurables, dashboards, habits, categories, AI settings';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sync tags, measurables, dashboards, habits, categories, and AI settings';

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
  String get settingThemingDark => 'Dark Theme';

  @override
  String get settingThemingLight => 'Light Theme';

  @override
  String get settingsAboutTitle => 'About Lotti';

  @override
  String get settingsAboutAppTagline => 'Your Personal Journal';

  @override
  String get settingsAboutAppInformation => 'App Information';

  @override
  String get settingsAboutYourData => 'Your Data';

  @override
  String get settingsAboutCredits => 'Credits';

  @override
  String get settingsAboutBuiltWithFlutter =>
      'Built with Flutter and love for personal journaling.';

  @override
  String get settingsAboutThankYou => 'Thank you for using Lotti!';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutPlatform => 'Platform';

  @override
  String get settingsAboutBuildType => 'Build Type';

  @override
  String get settingsAboutJournalEntries => 'Journal Entries';

  @override
  String get settingsAdvancedTitle => 'Advanced Settings';

  @override
  String get settingsAdvancedMatrixSyncSubtitle =>
      'Configure and manage Matrix synchronisation settings';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'View and manage items waiting to be synchronised';

  @override
  String get settingsAdvancedConflictsSubtitle =>
      'Resolve synchronisation conflicts to ensure data consistency';

  @override
  String get settingsAdvancedLogsSubtitle =>
      'Access and review application logs for debugging';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Import health-related data from external sources';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Perform maintenance tasks to optimise application performance';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'Learn more about the Lotti application';

  @override
  String get settingsCategoriesDuplicateError => 'Category exists already';

  @override
  String get settingsCategoriesNameLabel => 'Category name:';

  @override
  String get settingsCategoriesTitle => 'Categories';

  @override
  String get settingsConflictsResolutionTitle => 'Sync Conflict Resolution';

  @override
  String get settingsConflictsTitle => 'Sync Conflicts';

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
  String get settingsMatrixHomeServerLabel => 'Homeserver';

  @override
  String get settingsMatrixHomeserverConfigTitle => 'Matrix Homeserver Setup';

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
  String get configFlagEnableSyncV2 => 'Enable Matrix Sync V2';

  @override
  String get configFlagEnableSyncV2Description =>
      'Enable Matrix sync pipeline V2 (requires app restart)';

  @override
  String get settingsMatrixSentMessagesLabel => 'Sent messages:';

  @override
  String get settingsMatrixMessageType => 'Message Type';

  @override
  String get settingsMatrixCount => 'Count';

  @override
  String get settingsMatrixMetric => 'Metric';

  @override
  String get settingsMatrixValue => 'Value';

  @override
  String get settingsMatrixV2Metrics => 'Sync V2 Metrics';

  @override
  String get settingsMatrixV2MetricsNoData => 'Sync V2 Metrics: no data';

  @override
  String get settingsMatrixLastUpdated => 'Last updated:';

  @override
  String get settingsMatrixRefresh => 'Refresh';

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
  String get settingsMeasurableFavoriteLabel => 'Favourite: ';

  @override
  String get settingsMeasurableNameLabel => 'Measurable name:';

  @override
  String get settingsMeasurablePrivateLabel => 'Private:';

  @override
  String get settingsMeasurableSaveLabel => 'Save';

  @override
  String get settingsMeasurableUnitLabel => 'Unit abbreviation (optional):';

  @override
  String get settingsMeasurablesTitle => 'Measurable Types';

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
  String get settingsThemingTitle => 'Theming';

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
  String get syncEntitiesMessage => 'Choose the data you want to sync.';

  @override
  String get syncEntitiesSuccessDescription => 'Everything is up to date.';

  @override
  String get syncEntitiesSuccessTitle => 'Sync complete';

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
  String get taskLanguageLabel => 'Language:';

  @override
  String get taskLanguageArabic => 'Arabic';

  @override
  String get taskLanguageBengali => 'Bengali';

  @override
  String get taskLanguageBulgarian => 'Bulgarian';

  @override
  String get taskLanguageChinese => 'Chinese';

  @override
  String get taskLanguageCroatian => 'Croatian';

  @override
  String get taskLanguageCzech => 'Czech';

  @override
  String get taskLanguageDanish => 'Danish';

  @override
  String get taskLanguageDutch => 'Dutch';

  @override
  String get taskLanguageEnglish => 'English';

  @override
  String get taskLanguageEstonian => 'Estonian';

  @override
  String get taskLanguageFinnish => 'Finnish';

  @override
  String get taskLanguageFrench => 'French';

  @override
  String get taskLanguageGerman => 'German';

  @override
  String get taskLanguageGreek => 'Greek';

  @override
  String get taskLanguageHebrew => 'Hebrew';

  @override
  String get taskLanguageHindi => 'Hindi';

  @override
  String get taskLanguageHungarian => 'Hungarian';

  @override
  String get taskLanguageIndonesian => 'Indonesian';

  @override
  String get taskLanguageItalian => 'Italian';

  @override
  String get taskLanguageJapanese => 'Japanese';

  @override
  String get taskLanguageKorean => 'Korean';

  @override
  String get taskLanguageLatvian => 'Latvian';

  @override
  String get taskLanguageLithuanian => 'Lithuanian';

  @override
  String get taskLanguageNorwegian => 'Norwegian';

  @override
  String get taskLanguagePolish => 'Polish';

  @override
  String get taskLanguagePortuguese => 'Portuguese';

  @override
  String get taskLanguageRomanian => 'Romanian';

  @override
  String get taskLanguageRussian => 'Russian';

  @override
  String get taskLanguageSerbian => 'Serbian';

  @override
  String get taskLanguageSlovak => 'Slovak';

  @override
  String get taskLanguageSlovenian => 'Slovenian';

  @override
  String get taskLanguageSpanish => 'Spanish';

  @override
  String get taskLanguageSwahili => 'Swahili';

  @override
  String get taskLanguageSwedish => 'Swedish';

  @override
  String get taskLanguageThai => 'Thai';

  @override
  String get taskLanguageTurkish => 'Turkish';

  @override
  String get taskLanguageUkrainian => 'Ukrainian';

  @override
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageNigerianPidgin => 'Nigerian Pidgin';

  @override
  String get taskLanguageYoruba => 'Yoruba';

  @override
  String get taskLanguageSearchPlaceholder => 'Search languages...';

  @override
  String get taskLanguageSelectedLabel => 'Currently selected';

  @override
  String get taskLanguageVietnamese => 'Vietnamese';

  @override
  String get tasksFilterTitle => 'Tasks Filter';

  @override
  String get timeByCategoryChartTitle => 'Time by Category';

  @override
  String get timeByCategoryChartTotalLabel => 'Total';

  @override
  String get viewMenuTitle => 'View';
}

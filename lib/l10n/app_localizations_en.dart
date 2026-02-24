// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get activeLabel => 'Active';

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
  String get addActionAddTimer => 'Timer';

  @override
  String get addActionAddTimeRecording => 'Timer Entry';

  @override
  String get addActionImportImage => 'Import Image';

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
  String get addToDictionary => 'Add to Dictionary';

  @override
  String get addToDictionaryDuplicate => 'Term already exists in dictionary';

  @override
  String get addToDictionaryNoCategory =>
      'Cannot add to dictionary: task has no category';

  @override
  String get addToDictionarySaveFailed => 'Failed to save dictionary';

  @override
  String get addToDictionarySuccess => 'Term added to dictionary';

  @override
  String get addToDictionaryTooLong => 'Term too long (max 50 characters)';

  @override
  String get agentActivityLogHeading => 'Activity Log';

  @override
  String agentControlsActionError(String error) {
    return 'Action failed: $error';
  }

  @override
  String get agentControlsDeleteButton => 'Delete permanently';

  @override
  String get agentControlsDeleteDialogContent =>
      'This will permanently delete all data for this agent, including its history, reports, and observations. This cannot be undone.';

  @override
  String get agentControlsDeleteDialogTitle => 'Delete Agent?';

  @override
  String get agentControlsDestroyButton => 'Destroy';

  @override
  String get agentControlsDestroyDialogContent =>
      'This will permanently deactivate the agent. Its history will be preserved for audit.';

  @override
  String get agentControlsDestroyDialogTitle => 'Destroy Agent?';

  @override
  String get agentControlsDestroyedMessage => 'This agent has been destroyed.';

  @override
  String get agentControlsPauseButton => 'Pause';

  @override
  String get agentControlsReanalyzeButton => 'Re-analyze';

  @override
  String get agentControlsResumeButton => 'Resume';

  @override
  String get agentConversationEmpty => 'No conversations yet.';

  @override
  String agentConversationThreadHeader(String runKey) {
    return 'Wake $runKey';
  }

  @override
  String agentConversationThreadSummary(
      int messageCount, int toolCallCount, String shortId) {
    return '$messageCount messages, $toolCallCount tool calls · $shortId';
  }

  @override
  String agentDetailErrorLoading(String error) {
    return 'Error loading agent: $error';
  }

  @override
  String get agentDetailNotFound => 'Agent not found.';

  @override
  String get agentDetailUnexpectedType => 'Unexpected entity type.';

  @override
  String get agentLifecycleActive => 'Active';

  @override
  String get agentLifecycleCreated => 'Created';

  @override
  String get agentLifecycleDestroyed => 'Destroyed';

  @override
  String get agentLifecyclePaused => 'Paused';

  @override
  String get agentMessageKindAction => 'Action';

  @override
  String get agentMessageKindObservation => 'Observation';

  @override
  String get agentMessageKindSummary => 'Summary';

  @override
  String get agentMessageKindSystem => 'System';

  @override
  String get agentMessageKindThought => 'Thought';

  @override
  String get agentMessageKindToolResult => 'Tool Result';

  @override
  String get agentMessageKindUser => 'User';

  @override
  String get agentMessagePayloadEmpty => '(no content)';

  @override
  String get agentMessagesEmpty => 'No messages yet.';

  @override
  String agentMessagesErrorLoading(String error) {
    return 'Failed to load messages: $error';
  }

  @override
  String get agentObservationsEmpty => 'No observations recorded yet.';

  @override
  String agentReportErrorLoading(String error) {
    return 'Failed to load report: $error';
  }

  @override
  String get agentReportHistoryBadge => 'Report';

  @override
  String get agentReportHistoryEmpty => 'No report snapshots yet.';

  @override
  String get agentReportHistoryError =>
      'An error occurred while loading the report history.';

  @override
  String get agentReportNone => 'No report available yet.';

  @override
  String get agentRunningIndicator => 'Running';

  @override
  String get agentStateConsecutiveFailures => 'Consecutive failures';

  @override
  String agentStateErrorLoading(String error) {
    return 'Failed to load state: $error';
  }

  @override
  String get agentStateHeading => 'State Info';

  @override
  String get agentStateLastWake => 'Last wake';

  @override
  String get agentStateNextWake => 'Next wake';

  @override
  String get agentStateRevision => 'Revision';

  @override
  String get agentStateSleepingUntil => 'Sleeping until';

  @override
  String get agentStateWakeCount => 'Wake count';

  @override
  String get agentTabActivity => 'Activity';

  @override
  String get agentTabConversations => 'Conversations';

  @override
  String get agentTabObservations => 'Observations';

  @override
  String get agentTabReports => 'Reports';

  @override
  String get agentTemplateActiveInstancesTitle => 'Active Instances';

  @override
  String get agentTemplateAllProviders => 'All Providers';

  @override
  String get agentTemplateAssignedLabel => 'Template';

  @override
  String get agentTemplateCreatedSuccess => 'Template created';

  @override
  String get agentTemplateCreateTitle => 'Create Template';

  @override
  String get agentTemplateDeleteConfirm =>
      'Delete this template? This cannot be undone.';

  @override
  String get agentTemplateDeleteHasInstances =>
      'Cannot delete: active agents are using this template.';

  @override
  String get agentTemplateDirectivesHint =>
      'Define the agent\'s personality, tone, goals, and style...';

  @override
  String get agentTemplateDirectivesLabel => 'Directives';

  @override
  String get agentTemplateDisplayNameLabel => 'Name';

  @override
  String get agentTemplateEditTitle => 'Edit Template';

  @override
  String get agentTemplateEmptyList => 'No templates yet. Tap + to create one.';

  @override
  String get agentTemplateEvolveAction => 'Evolve with AI';

  @override
  String get agentTemplateEvolveApprove => 'Approve & Save';

  @override
  String get agentTemplateEvolveButton => 'Evolve Template';

  @override
  String get agentTemplateEvolveCurrentLabel => 'Current Directives';

  @override
  String get agentTemplateEvolveError =>
      'Failed to generate evolution proposal';

  @override
  String get agentTemplateEvolvePreviewTitle => 'Proposed Changes';

  @override
  String get agentTemplateEvolveProposedLabel => 'Proposed Directives';

  @override
  String get agentTemplateEvolveReject => 'Reject';

  @override
  String get agentTemplateEvolveSuccess => 'Template evolved successfully';

  @override
  String get agentTemplateEvolvingProgress =>
      'Generating improved directives...';

  @override
  String get agentTemplateFeedbackChangesHint =>
      'Describe what you\'d like changed...';

  @override
  String get agentTemplateFeedbackChangesLabel => 'Specific changes';

  @override
  String get agentTemplateFeedbackDidntWorkHint =>
      'Describe issues or shortcomings...';

  @override
  String get agentTemplateFeedbackDidntWorkLabel => 'What didn\'t work';

  @override
  String get agentTemplateFeedbackEnjoyedHint =>
      'Describe what the agent does well...';

  @override
  String get agentTemplateFeedbackEnjoyedLabel => 'What worked well';

  @override
  String get agentTemplateFeedbackTitle => 'Feedback';

  @override
  String agentTemplateInstanceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instances',
      one: '1 instance',
      zero: 'No instances',
    );
    return '$_temp0';
  }

  @override
  String get agentTemplateKindTaskAgent => 'Task Agent';

  @override
  String get agentTemplateMetricsActiveInstances => 'Active Instances';

  @override
  String get agentTemplateMetricsAvgDuration => 'Avg Duration';

  @override
  String agentTemplateMetricsDurationSeconds(int count) {
    return '${count}s';
  }

  @override
  String get agentTemplateMetricsFailureCount => 'Failures';

  @override
  String get agentTemplateMetricsFirstWake => 'First Wake';

  @override
  String get agentTemplateMetricsLastWake => 'Last Wake';

  @override
  String get agentTemplateMetricsSuccessRate => 'Success Rate';

  @override
  String get agentTemplateMetricsTitle => 'Performance Metrics';

  @override
  String get agentTemplateMetricsTotalWakes => 'Total Wakes';

  @override
  String get agentTemplateModelLabel => 'Model ID';

  @override
  String get agentTemplateModelRequirements =>
      'Only reasoning models with function calling are shown';

  @override
  String get agentTemplateNoMetrics => 'No performance data yet';

  @override
  String get agentTemplateNoneAssigned => 'No template assigned';

  @override
  String get agentTemplateNoSuitableModels => 'No suitable models found';

  @override
  String get agentTemplateNoTemplates =>
      'No templates available. Create one in Settings first.';

  @override
  String get agentTemplateNotFound => 'Template not found';

  @override
  String get agentTemplateNoVersions => 'No versions';

  @override
  String agentTemplateOneOnOneTitle(String templateName) {
    return '1-on-1 with $templateName';
  }

  @override
  String get agentTemplateRollbackAction => 'Roll Back to This Version';

  @override
  String agentTemplateRollbackConfirm(int version) {
    return 'Roll back to version $version? The agent will use this version on its next wake.';
  }

  @override
  String get agentTemplateSaveNewVersion => 'Save as New Version';

  @override
  String get agentTemplateSelectTitle => 'Select Template';

  @override
  String get agentTemplateSettingsSubtitle =>
      'Manage agent personalities and directives';

  @override
  String get agentTemplateStatusActive => 'Active';

  @override
  String get agentTemplateStatusArchived => 'Archived';

  @override
  String get agentTemplatesTitle => 'Agent Templates';

  @override
  String get agentTemplateSwitchHint =>
      'To use a different template, destroy this agent and create a new one.';

  @override
  String get agentTemplateVersionHistoryTitle => 'Version History';

  @override
  String agentTemplateVersionLabel(int version) {
    return 'Version $version';
  }

  @override
  String get agentTemplateVersionSaved => 'New version saved';

  @override
  String get agentThreadReportLabel => 'Report produced during this wake';

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
  String get aiBatchToggleTooltip => 'Switch to standard recording';

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
  String get aiInferenceErrorViewLogButton => 'View Log';

  @override
  String get aiModelSettings => 'AI Model Settings';

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
  String get aiProviderMistralDescription =>
      'Mistral AI cloud API with native audio transcription';

  @override
  String get aiProviderMistralName => 'Mistral';

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
  String get aiProviderVoxtralDescription =>
      'Local Voxtral transcription (up to 30 min audio, 13 languages)';

  @override
  String get aiProviderVoxtralName => 'Voxtral (local)';

  @override
  String get aiProviderWhisperDescription =>
      'Local Whisper transcription with OpenAI-compatible API';

  @override
  String get aiProviderWhisperName => 'Whisper (local)';

  @override
  String get aiRealtimeToggleTooltip => 'Switch to live transcription';

  @override
  String get aiRealtimeTranscribing => 'Live transcription...';

  @override
  String get aiRealtimeTranscriptionError =>
      'Live transcription disconnected. Audio saved for batch processing.';

  @override
  String get aiResponseDeleteCancel => 'Cancel';

  @override
  String get aiResponseDeleteConfirm => 'Delete';

  @override
  String get aiResponseDeleteError =>
      'Failed to delete AI response. Please try again.';

  @override
  String get aiResponseDeleteTitle => 'Delete AI Response';

  @override
  String get aiResponseDeleteWarning =>
      'Are you sure you want to delete this AI response? This cannot be undone.';

  @override
  String get aiResponseTypeAudioTranscription => 'Audio Transcription';

  @override
  String get aiResponseTypeChecklistUpdates => 'Checklist Updates';

  @override
  String get aiResponseTypeImageAnalysis => 'Image Analysis';

  @override
  String get aiResponseTypeImagePromptGeneration => 'Image Prompt';

  @override
  String get aiResponseTypePromptGeneration => 'Generated Prompt';

  @override
  String get aiResponseTypeTaskSummary => 'Task Summary';

  @override
  String get aiSettingsAddedLabel => 'Added';

  @override
  String get aiSettingsAddModelButton => 'Add Model';

  @override
  String get aiSettingsAddModelTooltip => 'Add this model to your provider';

  @override
  String get aiSettingsAddPromptButton => 'Add Prompt';

  @override
  String get aiSettingsAddProviderButton => 'Add Provider';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Clear all filters';

  @override
  String get aiSettingsClearFiltersButton => 'Clear';

  @override
  String aiSettingsDeleteSelectedConfirmMessage(int count) {
    return 'Are you sure you want to delete $count selected prompts? This action cannot be undone.';
  }

  @override
  String get aiSettingsDeleteSelectedConfirmTitle => 'Delete Selected Prompts';

  @override
  String aiSettingsDeleteSelectedLabel(int count) {
    return 'Delete ($count)';
  }

  @override
  String get aiSettingsDeleteSelectedTooltip => 'Delete selected prompts';

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
  String aiSettingsFilterByResponseTypeTooltip(String responseType) {
    return 'Filter by $responseType prompts';
  }

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
  String get aiSettingsSelectLabel => 'Select';

  @override
  String get aiSettingsSelectModeTooltip =>
      'Toggle selection mode for bulk operations';

  @override
  String get aiSettingsTabModels => 'Models';

  @override
  String get aiSettingsTabPrompts => 'Prompts';

  @override
  String get aiSettingsTabProviders => 'Providers';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Creates optimized models, prompts, and a test category';

  @override
  String aiSetupWizardDescription(String providerName) {
    return 'Set up or refresh models, prompts, and test category for $providerName';
  }

  @override
  String get aiSetupWizardRunButton => 'Run Setup';

  @override
  String get aiSetupWizardRunLabel => 'Run Setup Wizard';

  @override
  String get aiSetupWizardRunningButton => 'Running...';

  @override
  String get aiSetupWizardSafeToRunMultiple =>
      'Safe to run multiple times - existing items will be kept';

  @override
  String get aiSetupWizardTitle => 'AI Setup Wizard';

  @override
  String get aiTaskSummaryCancelScheduled => 'Cancel scheduled summary';

  @override
  String get aiTaskSummaryRunning => 'Thinking about summarizing task...';

  @override
  String aiTaskSummaryScheduled(String time) {
    return 'Summary in $time';
  }

  @override
  String get aiTaskSummaryTitle => 'AI Task Summary';

  @override
  String get aiTaskSummaryTriggerNow => 'Generate summary now';

  @override
  String get aiTranscribingAudio => 'Transcribing audio...';

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
  String get audioRecordingCancel => 'CANCEL';

  @override
  String get audioRecordingListening => 'Listening...';

  @override
  String get audioRecordingRealtime => 'Live Transcription';

  @override
  String get audioRecordings => 'Audio Recordings';

  @override
  String get audioRecordingStandard => 'Standard';

  @override
  String get audioRecordingStop => 'STOP';

  @override
  String get automaticPrompts => 'Automatic Prompts';

  @override
  String get backfillManualDescription =>
      'Request all missing entries regardless of age. Use this to recover older sync gaps.';

  @override
  String get backfillManualProcessing => 'Processing...';

  @override
  String backfillManualSuccess(int count) {
    return '$count entries requested';
  }

  @override
  String get backfillManualTitle => 'Manual Backfill';

  @override
  String get backfillManualTrigger => 'Request Missing Entries';

  @override
  String get backfillReRequestDescription =>
      'Re-request entries that were requested but never received. Use this when responses are stuck.';

  @override
  String get backfillReRequestProcessing => 'Re-requesting...';

  @override
  String backfillReRequestSuccess(int count) {
    return '$count entries re-requested';
  }

  @override
  String get backfillReRequestTitle => 'Re-Request Pending';

  @override
  String get backfillReRequestTrigger => 'Re-Request Pending Entries';

  @override
  String get backfillSettingsInfo =>
      'Automatic backfill requests missing entries from the last 24 hours. Use manual backfill for older entries.';

  @override
  String get backfillSettingsSubtitle => 'Manage sync gap recovery';

  @override
  String get backfillSettingsTitle => 'Backfill Sync';

  @override
  String get backfillStatsBackfilled => 'Backfilled';

  @override
  String get backfillStatsDeleted => 'Deleted';

  @override
  String backfillStatsHostsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count connected device$_temp0';
  }

  @override
  String get backfillStatsMissing => 'Missing';

  @override
  String get backfillStatsNoData => 'No sync data available';

  @override
  String get backfillStatsReceived => 'Received';

  @override
  String get backfillStatsRefresh => 'Refresh stats';

  @override
  String get backfillStatsRequested => 'Requested';

  @override
  String get backfillStatsTitle => 'Sync Statistics';

  @override
  String get backfillStatsTotalEntries => 'Total entries';

  @override
  String get backfillStatsUnresolvable => 'Unresolvable';

  @override
  String get backfillToggleDisabledDescription =>
      'Backfill disabled - useful on metered networks';

  @override
  String get backfillToggleEnabledDescription =>
      'Automatically request missing sync entries';

  @override
  String get backfillToggleTitle => 'Automatic Backfill';

  @override
  String get basicSettings => 'Basic Settings';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get categoryActiveDescription =>
      'Inactive categories won\'t appear in selection lists';

  @override
  String get categoryAiModelDescription =>
      'Control which AI prompts can be used with this category';

  @override
  String get categoryAutomaticPromptsDescription =>
      'Configure prompts that run automatically for different content types';

  @override
  String get categoryCreationError =>
      'Failed to create category. Please try again.';

  @override
  String get categoryDefaultLanguageDescription =>
      'Set a default language for tasks in this category';

  @override
  String get categoryDeleteConfirm => 'YES, DELETE THIS CATEGORY';

  @override
  String get categoryDeleteConfirmation =>
      'This action cannot be undone. All entries in this category will remain but will no longer be categorized.';

  @override
  String get categoryDeleteQuestion => 'Do you want to delete this category?';

  @override
  String get categoryDeleteTitle => 'Delete Category?';

  @override
  String get categoryFavoriteDescription => 'Mark this category as a favorite';

  @override
  String get categoryNameRequired => 'Category name is required';

  @override
  String get categoryNotFound => 'Category not found';

  @override
  String get categoryPrivateDescription =>
      'Hide this category when private mode is enabled';

  @override
  String get categoryPromptFilterAll => 'All';

  @override
  String get categorySearchPlaceholder => 'Search categories...';

  @override
  String get celebrationTapToContinue => 'Tap to continue';

  @override
  String get chatInputCancelRealtime => 'Cancel (Esc)';

  @override
  String get chatInputCancelRecording => 'Cancel recording (Esc)';

  @override
  String get chatInputConfigureModel => 'Configure model';

  @override
  String get chatInputHintDefault => 'Ask about your tasks and productivity...';

  @override
  String get chatInputHintSelectModel => 'Select a model to start chatting';

  @override
  String get chatInputListening => 'Listening...';

  @override
  String get chatInputPleaseWait => 'Please wait...';

  @override
  String get chatInputProcessing => 'Processing...';

  @override
  String get chatInputRecordVoice => 'Record voice message';

  @override
  String get chatInputSendTooltip => 'Send message';

  @override
  String get chatInputStartRealtime => 'Start live transcription';

  @override
  String get chatInputStopRealtime => 'Stop live transcription';

  @override
  String get chatInputStopTranscribe => 'Stop and transcribe';

  @override
  String get checklistAddItem => 'Add a new item';

  @override
  String get checklistAllDone => 'All items completed!';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total done';
  }

  @override
  String get checklistDelete => 'Delete checklist?';

  @override
  String get checklistExportAsMarkdown => 'Export checklist as Markdown';

  @override
  String get checklistExportFailed => 'Export failed';

  @override
  String get checklistFilterShowAll => 'Show all items';

  @override
  String get checklistFilterShowOpen => 'Show open items';

  @override
  String get checklistFilterStateAll => 'Showing all items';

  @override
  String get checklistFilterStateOpenOnly => 'Showing open items';

  @override
  String checklistFilterToggleSemantics(String state) {
    return 'Toggle checklist filter (current: $state)';
  }

  @override
  String get checklistItemArchived => 'Item archived';

  @override
  String get checklistItemArchiveUndo => 'Undo';

  @override
  String get checklistItemDelete => 'Delete checklist item?';

  @override
  String get checklistItemDeleteCancel => 'Cancel';

  @override
  String get checklistItemDeleteConfirm => 'Confirm';

  @override
  String get checklistItemDeleted => 'Item deleted';

  @override
  String get checklistItemDeleteWarning => 'This action cannot be undone.';

  @override
  String get checklistItemDrag => 'Drag suggestions into checklist';

  @override
  String get checklistItemUnarchived => 'Item unarchived';

  @override
  String get checklistMarkdownCopied => 'Checklist copied as Markdown';

  @override
  String get checklistNoSuggestionsTitle => 'No suggested Action Items';

  @override
  String get checklistNothingToExport => 'No items to export';

  @override
  String get checklistShareHint => 'Long press to share';

  @override
  String get checklistsReorder => 'Reorder';

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
  String get checklistUpdates => 'Checklist Updates';

  @override
  String get clearButton => 'Clear';

  @override
  String get colorLabel => 'Color:';

  @override
  String get colorPickerError => 'Invalid Hex color';

  @override
  String get colorPickerHint => 'Enter Hex color or pick';

  @override
  String get commonError => 'Error';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonUnknown => 'Unknown';

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
  String get configFlagEnableAgents => 'Enable Agents';

  @override
  String get configFlagEnableAgentsDescription =>
      'Allow AI agents to autonomously monitor and analyze your tasks.';

  @override
  String get configFlagEnableAiStreaming =>
      'Enable AI streaming for task actions';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Stream AI responses for task-related actions. Turn off to buffer responses and keep the UI smoother.';

  @override
  String get configFlagEnableAutoTaskTldrDescription =>
      'Automatically generate summaries for your tasks to help you quickly understand their status.';

  @override
  String get configFlagEnableCalendarPage => 'Enable Calendar page';

  @override
  String get configFlagEnableCalendarPageDescription =>
      'Show the Calendar page in the main navigation. View and manage your entries in a calendar view.';

  @override
  String get configFlagEnableDailyOs => 'Enable DailyOS';

  @override
  String get configFlagEnableDailyOsDescription =>
      'Show the DailyOS page in the main navigation.';

  @override
  String get configFlagEnableDashboardsPage => 'Enable Dashboards page';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Show the Dashboards page in the main navigation. View your data and insights in customizable dashboards.';

  @override
  String get configFlagEnableEvents => 'Enable Events';

  @override
  String get configFlagEnableEventsDescription =>
      'Show the Events feature to create, track, and manage events in your journal.';

  @override
  String get configFlagEnableHabitsPage => 'Enable Habits page';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Show the Habits page in the main navigation. Track and manage your daily habits here.';

  @override
  String get configFlagEnableLogging => 'Enable logging';

  @override
  String get configFlagEnableLoggingDescription =>
      'Enable detailed logging for debugging purposes. This may impact performance.';

  @override
  String get configFlagEnableMatrix => 'Enable Matrix sync';

  @override
  String get configFlagEnableMatrixDescription =>
      'Enable the Matrix integration to sync your entries across devices and with other Matrix users.';

  @override
  String get configFlagEnableNotifications => 'Enable notifications?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Receive notifications for reminders, updates, and important events.';

  @override
  String get configFlagEnableSessionRatings => 'Enable Session Ratings';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Prompt for a quick session rating when you stop a timer.';

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
  String get configFlagUseCloudInferenceDescription =>
      'Use cloud-based AI services for enhanced features. This requires an internet connection.';

  @override
  String get conflictEntityLabel => 'Entity';

  @override
  String get conflictIdLabel => 'ID';

  @override
  String get conflictsCopyTextFromSync => 'Copy Text from Sync';

  @override
  String get conflictsEmptyDescription =>
      'Everything is in sync right now. Resolved items stay available in the other filter.';

  @override
  String get conflictsEmptyTitle => 'No conflicts detected';

  @override
  String get conflictsResolved => 'resolved';

  @override
  String get conflictsResolveLocalVersion => 'Resolve with local version';

  @override
  String get conflictsResolveRemoteVersion => 'Resolve with remote version';

  @override
  String get conflictsUnresolved => 'unresolved';

  @override
  String get copyAsMarkdown => 'Copy as Markdown';

  @override
  String get copyAsText => 'Copy as text';

  @override
  String get correctionExampleCancel => 'CANCEL';

  @override
  String get correctionExampleCaptured => 'Correction saved for AI learning';

  @override
  String correctionExamplePending(int seconds) {
    return 'Saving correction in ${seconds}s...';
  }

  @override
  String get correctionExamplesEmpty =>
      'No corrections captured yet. Edit a checklist item to add your first example.';

  @override
  String get correctionExamplesSectionDescription =>
      'When you manually correct checklist items, those corrections are saved here and used to improve AI suggestions.';

  @override
  String get correctionExamplesSectionTitle => 'Checklist Correction Examples';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'You have $count corrections. Only the most recent $max will be used in AI prompts. Consider deleting old or redundant examples.';
  }

  @override
  String get coverArtAssign => 'Set as cover art';

  @override
  String get coverArtChipActive => 'Cover';

  @override
  String get coverArtChipSet => 'Set cover';

  @override
  String get coverArtRemove => 'Remove as cover art';

  @override
  String get createButton => 'Create';

  @override
  String get createCategoryTitle => 'Create Category:';

  @override
  String get createEntryLabel => 'Create new entry';

  @override
  String get createEntryTitle => 'Add';

  @override
  String get createNewLinkedTask => 'Create new linked task...';

  @override
  String get createPromptsFirst =>
      'Create AI prompts first to configure them here';

  @override
  String get customColor => 'Custom Color';

  @override
  String get dailyOsActual => 'Actual';

  @override
  String get dailyOsAddBlock => 'Add Block';

  @override
  String get dailyOsAddBudget => 'Add Budget';

  @override
  String get dailyOsAddNote => 'Add a note...';

  @override
  String get dailyOsAgreeToPlan => 'Agree to Plan';

  @override
  String get dailyOsCancel => 'Cancel';

  @override
  String get dailyOsCategory => 'Category';

  @override
  String get dailyOsChooseCategory => 'Choose a category...';

  @override
  String get dailyOsCompletionMessage => 'Great job! You completed your day.';

  @override
  String get dailyOsCopyToTomorrow => 'Copy to tomorrow';

  @override
  String get dailyOsDayComplete => 'Day Complete';

  @override
  String get dailyOsDayPlan => 'Day Plan';

  @override
  String get dailyOsDaySummary => 'Day Summary';

  @override
  String get dailyOsDelete => 'Delete';

  @override
  String get dailyOsDeleteBudget => 'Delete Budget?';

  @override
  String get dailyOsDeleteBudgetConfirm =>
      'This will remove the time budget from your day plan.';

  @override
  String get dailyOsDeletePlannedBlock => 'Delete Block?';

  @override
  String get dailyOsDeletePlannedBlockConfirm =>
      'This will remove the planned block from your timeline.';

  @override
  String get dailyOsDoneForToday => 'Done for today';

  @override
  String get dailyOsDraftMessage => 'Plan is in draft. Agree to lock it in.';

  @override
  String get dailyOsDueToday => 'Due today';

  @override
  String get dailyOsDueTodayShort => 'Due';

  @override
  String dailyOsDuplicateBudget(String categoryName) {
    return 'A budget for \"$categoryName\" already exists';
  }

  @override
  String get dailyOsDuration1h => '1h';

  @override
  String get dailyOsDuration2h => '2h';

  @override
  String get dailyOsDuration30m => '30m';

  @override
  String get dailyOsDuration3h => '3h';

  @override
  String get dailyOsDuration4h => '4h';

  @override
  String dailyOsDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String dailyOsDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String dailyOsDurationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsEditBudget => 'Edit Budget';

  @override
  String get dailyOsEditPlannedBlock => 'Edit Planned Block';

  @override
  String get dailyOsEndTime => 'End';

  @override
  String get dailyOsEntry => 'Entry';

  @override
  String get dailyOsExpandToMove => 'Expand timeline to drag this block';

  @override
  String get dailyOsExpandToMoveMore => 'Expand timeline to move further';

  @override
  String get dailyOsFailedToLoadBudgets => 'Failed to load budgets';

  @override
  String get dailyOsFailedToLoadTimeline => 'Failed to load timeline';

  @override
  String get dailyOsFold => 'Fold';

  @override
  String dailyOsHoursMinutesPlanned(int hours, int minutes) {
    return '${hours}h ${minutes}m planned';
  }

  @override
  String dailyOsHoursPlanned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours planned',
      one: '1 hour planned',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsInvalidTimeRange => 'Invalid time range';

  @override
  String dailyOsMinutesPlanned(int count) {
    return '$count min planned';
  }

  @override
  String get dailyOsNearLimit => 'Near limit';

  @override
  String get dailyOsNoBudgets => 'No time budgets';

  @override
  String get dailyOsNoBudgetsHint =>
      'Add budgets to track how you spend your time across categories.';

  @override
  String get dailyOsNoBudgetWarning => 'No time budgeted';

  @override
  String get dailyOsNote => 'Note';

  @override
  String get dailyOsNoTimeline => 'No timeline entries';

  @override
  String get dailyOsNoTimelineHint =>
      'Start a timer or add planned blocks to see your day.';

  @override
  String get dailyOsOnTrack => 'On track';

  @override
  String get dailyOsOver => 'Over';

  @override
  String get dailyOsOverallProgress => 'Overall Progress';

  @override
  String get dailyOsOverBudget => 'Over budget';

  @override
  String get dailyOsOverdue => 'Overdue';

  @override
  String get dailyOsOverdueShort => 'Late';

  @override
  String get dailyOsPlan => 'Plan';

  @override
  String get dailyOsPlanned => 'Planned';

  @override
  String get dailyOsPlannedDuration => 'Planned Duration';

  @override
  String get dailyOsQuickCreateTask => 'Create task for this budget';

  @override
  String get dailyOsReAgree => 'Re-agree';

  @override
  String get dailyOsRecorded => 'Recorded';

  @override
  String get dailyOsRemaining => 'Remaining';

  @override
  String get dailyOsReviewMessage => 'Changes detected. Review your plan.';

  @override
  String get dailyOsSave => 'Save';

  @override
  String get dailyOsSelectCategory => 'Select Category';

  @override
  String get dailyOsStartTime => 'Start';

  @override
  String get dailyOsTasks => 'Tasks';

  @override
  String get dailyOsTimeBudgets => 'Time Budgets';

  @override
  String dailyOsTimeLeft(String time) {
    return '$time left';
  }

  @override
  String get dailyOsTimeline => 'Timeline';

  @override
  String dailyOsTimeOver(String time) {
    return '+$time over';
  }

  @override
  String get dailyOsTimeRange => 'Time Range';

  @override
  String get dailyOsTimesUp => 'Time\'s up';

  @override
  String get dailyOsTodayButton => 'Today';

  @override
  String get dailyOsUncategorized => 'Uncategorized';

  @override
  String get dailyOsViewModeClassic => 'Classic';

  @override
  String get dailyOsViewModeDailyOs => 'Daily OS';

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
  String get defaultLanguage => 'Default Language';

  @override
  String get deleteButton => 'Delete';

  @override
  String get deleteDeviceLabel => 'Delete device';

  @override
  String deviceDeletedSuccess(String deviceName) {
    return 'Device $deviceName deleted successfully';
  }

  @override
  String deviceDeleteFailed(String error) {
    return 'Failed to delete device: $error';
  }

  @override
  String get done => 'Done';

  @override
  String get doneButton => 'Done';

  @override
  String get editMenuTitle => 'Edit';

  @override
  String get editorInsertDivider => 'Insert divider';

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
  String get enterCategoryName => 'Enter category name';

  @override
  String get entryActions => 'Actions';

  @override
  String get entryLabelsActionSubtitle =>
      'Assign labels to organize this entry';

  @override
  String get entryLabelsActionTitle => 'Labels';

  @override
  String get entryLabelsEditTooltip => 'Edit labels';

  @override
  String get entryLabelsHeaderTitle => 'Labels';

  @override
  String get entryLabelsNoLabels => 'No labels assigned';

  @override
  String get entryTypeLabelAiResponse => 'AI Response';

  @override
  String get entryTypeLabelChecklist => 'Checklist';

  @override
  String get entryTypeLabelChecklistItem => 'To Do';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Habit';

  @override
  String get entryTypeLabelJournalAudio => 'Audio';

  @override
  String get entryTypeLabelJournalEntry => 'Text';

  @override
  String get entryTypeLabelJournalEvent => 'Event';

  @override
  String get entryTypeLabelJournalImage => 'Photo';

  @override
  String get entryTypeLabelMeasurementEntry => 'Measured';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Health';

  @override
  String get entryTypeLabelSurveyEntry => 'Survey';

  @override
  String get entryTypeLabelTask => 'Task';

  @override
  String get entryTypeLabelWorkoutEntry => 'Workout';

  @override
  String get errorLoadingPrompts => 'Error loading prompts';

  @override
  String get eventNameLabel => 'Event:';

  @override
  String get favoriteLabel => 'Favorite';

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
  String get generateCoverArt => 'Generate Cover Art';

  @override
  String get generateCoverArtSubtitle => 'Create image from voice description';

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
  String get imageGenerationAcceptButton => 'Accept as Cover Art';

  @override
  String get imageGenerationCancelEdit => 'Cancel';

  @override
  String get imageGenerationEditPromptButton => 'Edit Prompt';

  @override
  String get imageGenerationEditPromptLabel => 'Edit prompt';

  @override
  String get imageGenerationError => 'Failed to generate image';

  @override
  String get imageGenerationGenerating => 'Generating image...';

  @override
  String get imageGenerationModalTitle => 'Generated Image';

  @override
  String get imageGenerationRetry => 'Retry';

  @override
  String imageGenerationSaveError(String error) {
    return 'Failed to save image: $error';
  }

  @override
  String imageGenerationWithReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Using $count reference images',
      one: 'Using 1 reference image',
      zero: 'No reference images',
    );
    return '$_temp0';
  }

  @override
  String get imagePromptGenerationCardTitle => 'AI Image Prompt';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Image prompt copied to clipboard';

  @override
  String get imagePromptGenerationCopyButton => 'Copy Prompt';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Copy image prompt to clipboard';

  @override
  String get imagePromptGenerationExpandTooltip => 'Show full prompt';

  @override
  String get imagePromptGenerationFullPromptLabel => 'Full Image Prompt:';

  @override
  String get images => 'Images';

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
  String get journalHideLinkHint => 'Hide link';

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
  String get journalShareHint => 'Share';

  @override
  String get journalSharePhotoHint => 'Share photo';

  @override
  String get journalShowLinkHint => 'Show link';

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
  String get linkedFromLabel => 'LINKED FROM';

  @override
  String get linkedTasksMenuTooltip => 'Linked tasks options';

  @override
  String get linkedTasksTitle => 'Linked Tasks';

  @override
  String get linkedToLabel => 'LINKED TO';

  @override
  String get linkExistingTask => 'Link existing task...';

  @override
  String get loggingFailedToLoad => 'Failed to load logs. Please try again.';

  @override
  String get loggingFailedToLoadMore =>
      'Failed to load more results. Please try again.';

  @override
  String get loggingSearchFailed => 'Search failed. Please try again.';

  @override
  String get logsSearchHint => 'Search all logs...';

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
  String get maintenancePopulateSequenceLog => 'Populate sync sequence log';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count entries indexed';
  }

  @override
  String get maintenancePopulateSequenceLogConfirm => 'YES, POPULATE';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Index existing entries for backfill support';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'This will scan all journal entries and add them to the sync sequence log. This enables backfill responses for entries created before this feature was added.';

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
  String get maintenanceReSync => 'Re-sync messages';

  @override
  String get maintenanceReSyncDescription => 'Re-sync messages from server';

  @override
  String get maintenanceSyncDefinitions =>
      'Sync tags, measurables, dashboards, habits, categories, AI settings';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sync tags, measurables, dashboards, habits, categories, and AI settings';

  @override
  String get manageLinks => 'Manage links...';

  @override
  String get matrixStatsError => 'Error loading Matrix stats';

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
  String get multiSelectAddButton => 'Add';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Add ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'No items found';

  @override
  String get navTabTitleCalendar => 'DailyOS';

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
  String nestedAiResponsesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count AI response$_temp0';
  }

  @override
  String get noDefaultLanguage => 'No default language';

  @override
  String get noPromptsAvailable => 'No prompts available';

  @override
  String get noPromptsForType => 'No prompts available for this type';

  @override
  String get noTasksFound => 'No tasks found';

  @override
  String get noTasksToLink => 'No tasks available to link';

  @override
  String get outboxMonitorAttachmentLabel => 'Attachment';

  @override
  String get outboxMonitorDelete => 'delete';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Delete';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      'Are you sure you want to delete this sync item? This action cannot be undone.';

  @override
  String get outboxMonitorDeleteFailed => 'Delete failed. Please try again.';

  @override
  String get outboxMonitorDeleteSuccess => 'Item deleted';

  @override
  String get outboxMonitorEmptyDescription =>
      'There are no sync items in this view.';

  @override
  String get outboxMonitorEmptyTitle => 'Outbox is clear';

  @override
  String get outboxMonitorLabelAll => 'all';

  @override
  String get outboxMonitorLabelError => 'error';

  @override
  String get outboxMonitorLabelPending => 'pending';

  @override
  String get outboxMonitorLabelSent => 'sent';

  @override
  String get outboxMonitorLabelSuccess => 'success';

  @override
  String get outboxMonitorNoAttachment => 'no attachment';

  @override
  String get outboxMonitorRetries => 'retries';

  @override
  String get outboxMonitorRetriesLabel => 'Retries';

  @override
  String get outboxMonitorRetry => 'retry';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Retry Now';

  @override
  String get outboxMonitorRetryConfirmMessage => 'Retry this sync item now?';

  @override
  String get outboxMonitorRetryFailed => 'Retry failed. Please try again.';

  @override
  String get outboxMonitorRetryQueued => 'Retry scheduled';

  @override
  String get outboxMonitorSubjectLabel => 'Subject';

  @override
  String get outboxMonitorSwitchLabel => 'enabled';

  @override
  String get privateLabel => 'Private';

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
  String get promptGenerationCardTitle => 'AI Coding Prompt';

  @override
  String get promptGenerationCopiedSnackbar => 'Prompt copied to clipboard';

  @override
  String get promptGenerationCopyButton => 'Copy Prompt';

  @override
  String get promptGenerationCopyTooltip => 'Copy prompt to clipboard';

  @override
  String get promptGenerationExpandTooltip => 'Show full prompt';

  @override
  String get promptGenerationFullPromptLabel => 'Full Prompt:';

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
  String get promptSelectionModalTitle => 'Select Preconfigured Prompt';

  @override
  String get promptSelectModelsButton => 'Select Models';

  @override
  String get promptSelectResponseTypeHint => 'Select response type';

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
  String get provisionedSyncBundleImported => 'Provisioning code imported';

  @override
  String get provisionedSyncConfigureButton => 'Configure';

  @override
  String get provisionedSyncCopiedToClipboard => 'Copied to clipboard';

  @override
  String get provisionedSyncDisconnect => 'Disconnect';

  @override
  String get provisionedSyncDone => 'Sync configured successfully';

  @override
  String get provisionedSyncError => 'Configuration failed';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'An error occurred during configuration. Please try again.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'Login failed. Please check your credentials and try again.';

  @override
  String get provisionedSyncImportButton => 'Import';

  @override
  String get provisionedSyncImportHint => 'Paste provisioning code here';

  @override
  String get provisionedSyncImportTitle => 'Sync Setup';

  @override
  String get provisionedSyncInvalidBundle => 'Invalid provisioning code';

  @override
  String get provisionedSyncJoiningRoom => 'Joining sync room...';

  @override
  String get provisionedSyncLoggingIn => 'Logging in...';

  @override
  String get provisionedSyncPasteClipboard => 'Paste from clipboard';

  @override
  String get provisionedSyncReady => 'Scan this QR code on your mobile device';

  @override
  String get provisionedSyncRetry => 'Retry';

  @override
  String get provisionedSyncRotatingPassword => 'Securing account...';

  @override
  String get provisionedSyncScanButton => 'Scan QR Code';

  @override
  String get provisionedSyncShowQr => 'Show provisioning QR';

  @override
  String get provisionedSyncSubtitle =>
      'Set up sync from a provisioning bundle';

  @override
  String get provisionedSyncSummaryHomeserver => 'Homeserver';

  @override
  String get provisionedSyncSummaryRoom => 'Room';

  @override
  String get provisionedSyncSummaryUser => 'User';

  @override
  String get provisionedSyncTitle => 'Provisioned Sync';

  @override
  String get provisionedSyncVerifyDevicesTitle => 'Device Verification';

  @override
  String get referenceImageContinue => 'Continue';

  @override
  String referenceImageContinueWithCount(int count) {
    return 'Continue ($count)';
  }

  @override
  String get referenceImageLoadError =>
      'Failed to load images. Please try again.';

  @override
  String get referenceImageSelectionSubtitle =>
      'Choose up to 3 images to guide the AI\'s visual style';

  @override
  String get referenceImageSelectionTitle => 'Select Reference Images';

  @override
  String get referenceImageSkip => 'Skip';

  @override
  String get saveButton => 'Save';

  @override
  String get saveButtonLabel => 'Save';

  @override
  String get saveLabel => 'Save';

  @override
  String get saveSuccessful => 'Saved successfully';

  @override
  String get searchHint => 'Search...';

  @override
  String get searchTasksHint => 'Search tasks...';

  @override
  String get selectAllowedPrompts =>
      'Select which prompts are allowed for this category';

  @override
  String get selectButton => 'Select';

  @override
  String get selectColor => 'Select Color';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get sessionRatingCardLabel => 'Session Rating';

  @override
  String get sessionRatingChallengeJustRight => 'Just right';

  @override
  String get sessionRatingChallengeTooEasy => 'Too easy';

  @override
  String get sessionRatingChallengeTooHard => 'Too challenging';

  @override
  String get sessionRatingDifficultyLabel => 'This work felt...';

  @override
  String get sessionRatingEditButton => 'Edit Rating';

  @override
  String get sessionRatingEnergyQuestion => 'How energized did you feel?';

  @override
  String get sessionRatingFocusQuestion => 'How focused were you?';

  @override
  String get sessionRatingNoteHint => 'Quick note (optional)';

  @override
  String get sessionRatingProductivityQuestion =>
      'How productive was this session?';

  @override
  String get sessionRatingRateAction => 'Rate Session';

  @override
  String get sessionRatingSaveButton => 'Save';

  @override
  String get sessionRatingSaveError =>
      'Failed to save rating. Please try again.';

  @override
  String get sessionRatingSkipButton => 'Skip';

  @override
  String get sessionRatingTitle => 'Rate this session';

  @override
  String get sessionRatingViewAction => 'View Rating';

  @override
  String get settingsAboutAppInformation => 'App Information';

  @override
  String get settingsAboutAppTagline => 'Your Personal Journal';

  @override
  String get settingsAboutBuildType => 'Build Type';

  @override
  String get settingsAboutBuiltWithFlutter =>
      'Built with Flutter and love for personal journaling.';

  @override
  String get settingsAboutCredits => 'Credits';

  @override
  String get settingsAboutJournalEntries => 'Journal Entries';

  @override
  String get settingsAboutPlatform => 'Platform';

  @override
  String get settingsAboutThankYou => 'Thank you for using Lotti!';

  @override
  String get settingsAboutTitle => 'About Lotti';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutYourData => 'Your Data';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'Learn more about the Lotti application';

  @override
  String get settingsAdvancedConflictsSubtitle =>
      'Resolve synchronization conflicts to ensure data consistency';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Import health-related data from external sources';

  @override
  String get settingsAdvancedLogsSubtitle =>
      'Access and review application logs for debugging';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Perform maintenance tasks to optimize application performance';

  @override
  String get settingsAdvancedMatrixSyncSubtitle =>
      'Configure and manage Matrix synchronization settings';

  @override
  String get settingsAdvancedOutboxSubtitle => 'Manage sync items';

  @override
  String get settingsAdvancedTitle => 'Advanced Settings';

  @override
  String get settingsAiApiKeys => 'AI Inference Providers';

  @override
  String get settingsAiModels => 'AI Models';

  @override
  String get settingsCategoriesAddTooltip => 'Add Category';

  @override
  String get settingsCategoriesDetailsLabel => 'Category Details';

  @override
  String get settingsCategoriesDuplicateError => 'Category exists already';

  @override
  String get settingsCategoriesEmptyState => 'No categories found';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Create a category to organize your entries';

  @override
  String get settingsCategoriesErrorLoading => 'Error loading categories';

  @override
  String get settingsCategoriesHasAiSettings => 'AI settings';

  @override
  String get settingsCategoriesHasAutomaticPrompts => 'Automatic AI';

  @override
  String get settingsCategoriesHasDefaultLanguage => 'Default language';

  @override
  String get settingsCategoriesNameLabel => 'Category name:';

  @override
  String get settingsCategoriesTitle => 'Categories';

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
  String get settingsLabelsActionsTooltip => 'Label actions';

  @override
  String get settingsLabelsCategoriesAdd => 'Add category';

  @override
  String get settingsLabelsCategoriesHeading => 'Applicable categories';

  @override
  String get settingsLabelsCategoriesNone => 'Applies to all categories';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Remove';

  @override
  String get settingsLabelsColorHeading => 'Select a color';

  @override
  String get settingsLabelsColorSubheading => 'Quick presets';

  @override
  String get settingsLabelsCreateSuccess => 'Label created successfully';

  @override
  String get settingsLabelsCreateTitle => 'Create label';

  @override
  String get settingsLabelsDeleteCancel => 'Cancel';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Delete';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return 'Are you sure you want to delete \"$labelName\"? Tasks with this label will lose the assignment.';
  }

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Delete label';

  @override
  String settingsLabelsDeleteSuccess(Object labelName) {
    return 'Label \"$labelName\" deleted';
  }

  @override
  String get settingsLabelsDescriptionHint =>
      'Explain when to apply this label';

  @override
  String get settingsLabelsDescriptionLabel => 'Description (optional)';

  @override
  String get settingsLabelsEditTitle => 'Edit label';

  @override
  String get settingsLabelsEmptyState => 'No labels yet';

  @override
  String get settingsLabelsEmptyStateHint =>
      'Tap the + button to create your first label.';

  @override
  String get settingsLabelsErrorLoading => 'Failed to load labels';

  @override
  String get settingsLabelsNameHint => 'Bug, Release blocker, Sync…';

  @override
  String get settingsLabelsNameLabel => 'Label name';

  @override
  String get settingsLabelsNameRequired => 'Label name must not be empty.';

  @override
  String get settingsLabelsPrivateDescription =>
      'Private labels only appear when “Show private entries” is enabled.';

  @override
  String get settingsLabelsPrivateTitle => 'Private label';

  @override
  String get settingsLabelsSearchHint => 'Search labels…';

  @override
  String get settingsLabelsSubtitle => 'Organize tasks with colored labels';

  @override
  String get settingsLabelsTitle => 'Labels';

  @override
  String get settingsLabelsUpdateSuccess => 'Label updated';

  @override
  String settingsLabelsUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
    );
    return 'Used on $_temp0';
  }

  @override
  String get settingsLogsTitle => 'Logs';

  @override
  String get settingsMaintenanceTitle => 'Maintenance';

  @override
  String get settingsMatrixAccept => 'Accept';

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
  String get settingsMatrixCount => 'Count';

  @override
  String get settingsMatrixDeleteLabel => 'Delete';

  @override
  String get settingsMatrixDiagnosticCopied =>
      'Diagnostic info copied to clipboard';

  @override
  String get settingsMatrixDiagnosticCopyButton => 'Copy to Clipboard';

  @override
  String get settingsMatrixDiagnosticDialogTitle => 'Sync Diagnostic Info';

  @override
  String get settingsMatrixDiagnosticShowButton => 'Show Diagnostic Info';

  @override
  String get settingsMatrixDone => 'Done';

  @override
  String get settingsMatrixEnterValidUrl => 'Please enter a valid URL';

  @override
  String get settingsMatrixHomeserverConfigTitle => 'Matrix Homeserver Setup';

  @override
  String get settingsMatrixHomeServerLabel => 'Homeserver';

  @override
  String get settingsMatrixLastUpdated => 'Last updated:';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Unverified devices';

  @override
  String get settingsMatrixLoginButtonLabel => 'Login';

  @override
  String get settingsMatrixLoginFailed => 'Login failed';

  @override
  String get settingsMatrixLogoutButtonLabel => 'Logout';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Run Matrix maintenance tasks and recovery tools';

  @override
  String get settingsMatrixMaintenanceTitle => 'Maintenance';

  @override
  String get settingsMatrixMessageType => 'Message Type';

  @override
  String get settingsMatrixMetric => 'Metric';

  @override
  String get settingsMatrixMetrics => 'Sync Metrics';

  @override
  String get settingsMatrixMetricsNoData => 'Sync Metrics: no data';

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
  String get settingsMatrixRefresh => 'Refresh';

  @override
  String get settingsMatrixRoomConfigTitle => 'Matrix Sync Room Setup';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Invite to room $roomId from $senderId. Accept?';
  }

  @override
  String get settingsMatrixRoomInviteTitle => 'Room invite';

  @override
  String get settingsMatrixSentMessagesLabel => 'Sent messages:';

  @override
  String get settingsMatrixStartVerificationLabel => 'Start Verification';

  @override
  String get settingsMatrixStatsTitle => 'Matrix Stats';

  @override
  String get settingsMatrixSubtitle => 'Configure end-to-end encrypted sync';

  @override
  String get settingsMatrixTitle => 'Sync Settings';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Unverified Devices';

  @override
  String get settingsMatrixUserLabel => 'User';

  @override
  String get settingsMatrixUserNameTooShort => 'User name too short';

  @override
  String get settingsMatrixValue => 'Value';

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
  String get settingsMeasurablesTitle => 'Measurable Types';

  @override
  String get settingsMeasurableUnitLabel => 'Unit abbreviation (optional):';

  @override
  String get settingsResetGeminiConfirm => 'Reset';

  @override
  String get settingsResetGeminiConfirmQuestion =>
      'This will show the Gemini setup dialog again. Continue?';

  @override
  String get settingsResetGeminiSubtitle =>
      'Show the Gemini AI setup dialog again';

  @override
  String get settingsResetGeminiTitle => 'Reset Gemini Setup Dialog';

  @override
  String get settingsResetHintsConfirm => 'Confirm';

  @override
  String get settingsResetHintsConfirmQuestion =>
      'Reset in‑app hints shown across the app?';

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
  String get settingsResetHintsSubtitle =>
      'Clear one‑time tips and onboarding hints';

  @override
  String get settingsResetHintsTitle => 'Reset In‑App Hints';

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
  String get settingsSyncStatsSubtitle => 'Inspect sync pipeline metrics';

  @override
  String get settingsSyncSubtitle => 'Configure sync and view stats';

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
  String get settingThemingDark => 'Dark Theme';

  @override
  String get settingThemingLight => 'Light Theme';

  @override
  String get showCompleted => 'Show completed';

  @override
  String get speechDictionaryHelper =>
      'Semicolon-separated terms (max 50 chars) for better speech recognition';

  @override
  String get speechDictionaryHint => 'macOS; Kirkjubæjarklaustur; Claude Code';

  @override
  String get speechDictionaryLabel => 'Speech Dictionary';

  @override
  String get speechDictionarySectionDescription =>
      'Add terms that are often misspelled by speech recognition (names, places, technical terms)';

  @override
  String get speechDictionarySectionTitle => 'Speech Recognition';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Large dictionary ($count terms) may increase API costs';
  }

  @override
  String get speechModalAddTranscription => 'Add Transcription';

  @override
  String get speechModalSelectLanguage => 'Select Language';

  @override
  String get speechModalTitle => 'Speech Recognition';

  @override
  String get speechModalTranscriptionProgress => 'Transcription Progress';

  @override
  String get syncCreateNewRoom => 'Create New Room';

  @override
  String get syncCreateNewRoomInstead => 'Create New Room Instead';

  @override
  String get syncDeleteConfigConfirm => 'YES, I\'M SURE';

  @override
  String get syncDeleteConfigQuestion =>
      'Do you want to delete the sync configuration?';

  @override
  String get syncDiscoveringRooms => 'Discovering sync rooms...';

  @override
  String get syncDiscoverRoomsButton => 'Discover Existing Rooms';

  @override
  String get syncDiscoveryError => 'Failed to discover rooms';

  @override
  String get syncEntitiesConfirm => 'START SYNC';

  @override
  String get syncEntitiesMessage => 'Choose the entities you want to sync.';

  @override
  String get syncEntitiesSuccessDescription => 'Everything is up to date.';

  @override
  String get syncEntitiesSuccessTitle => 'Sync complete';

  @override
  String get syncInviteErrorForbidden =>
      'Permission denied. You may not have access to invite this user.';

  @override
  String get syncInviteErrorNetwork =>
      'Network error. Please check your connection and try again.';

  @override
  String get syncInviteErrorRateLimited =>
      'Too many requests. Please wait a moment and try again.';

  @override
  String get syncInviteErrorUnknown =>
      'Failed to send invite. Please try again later.';

  @override
  String get syncInviteErrorUserNotFound =>
      'User not found. Please verify the scanned code is correct.';

  @override
  String syncListCountSummary(String label, int itemCount) {
    String _temp0 = intl.Intl.pluralLogic(
      itemCount,
      locale: localeName,
      other: '$itemCount items',
      one: '1 item',
      zero: '0 items',
    );
    return '$label · $_temp0';
  }

  @override
  String get syncListPayloadKindLabel => 'Payload';

  @override
  String get syncListUnknownPayload => 'Unknown payload';

  @override
  String get syncNoRoomsFound =>
      'No existing sync rooms found.\nYou can create a new room to start syncing.';

  @override
  String get syncNotLoggedInToast => 'Sync is not logged in';

  @override
  String get syncPayloadAgentEntity => 'Agent entity';

  @override
  String get syncPayloadAgentLink => 'Agent link';

  @override
  String get syncPayloadAiConfig => 'AI configuration';

  @override
  String get syncPayloadAiConfigDelete => 'AI configuration delete';

  @override
  String get syncPayloadBackfillRequest => 'Backfill request';

  @override
  String get syncPayloadBackfillResponse => 'Backfill response';

  @override
  String get syncPayloadEntityDefinition => 'Entity definition';

  @override
  String get syncPayloadEntryLink => 'Entry link';

  @override
  String get syncPayloadJournalEntity => 'Journal entry';

  @override
  String get syncPayloadTagEntity => 'Tag entity';

  @override
  String get syncPayloadThemingSelection => 'Theming selection';

  @override
  String get syncRetry => 'Retry';

  @override
  String get syncRoomCreatedUnknown => 'Unknown';

  @override
  String get syncRoomDiscoveryTitle => 'Find Existing Sync Room';

  @override
  String get syncRoomHasContent => 'Has Content';

  @override
  String get syncRoomUnnamed => 'Unnamed Room';

  @override
  String get syncRoomVerified => 'Verified';

  @override
  String get syncSelectRoom => 'Select a Sync Room';

  @override
  String get syncSelectRoomDescription =>
      'We found existing sync rooms. Select one to join, or create a new room.';

  @override
  String get syncSkip => 'Skip';

  @override
  String get syncStepAgentEntities => 'Agent entities';

  @override
  String get syncStepAgentLinks => 'Agent links';

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
  String get syncStepLabels => 'Labels';

  @override
  String get syncStepMeasurables => 'Measurables';

  @override
  String get syncStepTags => 'Tags';

  @override
  String get taskAgentChipLabel => 'Agent';

  @override
  String get taskAgentCreateChipLabel => 'Create Agent';

  @override
  String taskAgentCreateError(String error) {
    return 'Failed to create agent: $error';
  }

  @override
  String get taskCategoryAllLabel => 'all';

  @override
  String get taskCategoryLabel => 'Category:';

  @override
  String get taskCategoryUnassignedLabel => 'unassigned';

  @override
  String get taskDueDateLabel => 'Due Date';

  @override
  String taskDueDateWithDate(String date) {
    return 'Due: $date';
  }

  @override
  String taskDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Due in $_temp0';
  }

  @override
  String get taskDueToday => 'Due Today';

  @override
  String get taskDueTomorrow => 'Due Tomorrow';

  @override
  String get taskDueYesterday => 'Due Yesterday';

  @override
  String get taskEstimateLabel => 'Estimate:';

  @override
  String get taskLabelUnassignedLabel => 'unassigned';

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
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageIndonesian => 'Indonesian';

  @override
  String get taskLanguageItalian => 'Italian';

  @override
  String get taskLanguageJapanese => 'Japanese';

  @override
  String get taskLanguageKorean => 'Korean';

  @override
  String get taskLanguageLabel => 'Language:';

  @override
  String get taskLanguageLatvian => 'Latvian';

  @override
  String get taskLanguageLithuanian => 'Lithuanian';

  @override
  String get taskLanguageNigerianPidgin => 'Nigerian Pidgin';

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
  String get taskLanguageSearchPlaceholder => 'Search languages...';

  @override
  String get taskLanguageSelectedLabel => 'Currently selected';

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
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageUkrainian => 'Ukrainian';

  @override
  String get taskLanguageVietnamese => 'Vietnamese';

  @override
  String get taskLanguageYoruba => 'Yoruba';

  @override
  String get taskNameHint => 'Enter a name for the task';

  @override
  String get taskNoDueDateLabel => 'No due date';

  @override
  String get taskNoEstimateLabel => 'No estimate';

  @override
  String taskOverdueByDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Overdue by $_temp0';
  }

  @override
  String get tasksAddLabelButton => 'Add Label';

  @override
  String get tasksFilterTitle => 'Tasks Filter';

  @override
  String get tasksLabelFilterAll => 'All';

  @override
  String get tasksLabelFilterTitle => 'Labels';

  @override
  String get tasksLabelFilterUnlabeled => 'Unlabeled';

  @override
  String get tasksLabelsDialogClose => 'Close';

  @override
  String get tasksLabelsHeaderEditTooltip => 'Edit labels';

  @override
  String get tasksLabelsHeaderTitle => 'Labels';

  @override
  String get tasksLabelsNoLabels => 'No labels';

  @override
  String get tasksLabelsSheetApply => 'Apply';

  @override
  String get tasksLabelsSheetSearchHint => 'Search labels…';

  @override
  String get tasksLabelsSheetTitle => 'Select labels';

  @override
  String get tasksLabelsUpdateFailed => 'Failed to update labels';

  @override
  String get tasksPriorityFilterAll => 'All';

  @override
  String get tasksPriorityFilterTitle => 'Priority';

  @override
  String get tasksPriorityP0 => 'Urgent';

  @override
  String get tasksPriorityP0Description => 'Urgent (ASAP)';

  @override
  String get tasksPriorityP1 => 'High';

  @override
  String get tasksPriorityP1Description => 'High (Soon)';

  @override
  String get tasksPriorityP2 => 'Medium';

  @override
  String get tasksPriorityP2Description => 'Medium (Default)';

  @override
  String get tasksPriorityP3 => 'Low';

  @override
  String get tasksPriorityP3Description => 'Low (Whenever)';

  @override
  String get tasksPriorityPickerTitle => 'Select priority';

  @override
  String get tasksPriorityTitle => 'Priority:';

  @override
  String get tasksQuickFilterClear => 'Clear';

  @override
  String get tasksQuickFilterLabelsActiveTitle => 'Active label filters';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Unassigned';

  @override
  String get tasksShowCoverArt => 'Show cover art on cards';

  @override
  String get tasksShowCreationDate => 'Show creation date on cards';

  @override
  String get tasksShowDueDate => 'Show due date on cards';

  @override
  String get tasksSortByCreationDate => 'Created';

  @override
  String get tasksSortByDate => 'Date';

  @override
  String get tasksSortByDueDate => 'Due Date';

  @override
  String get tasksSortByLabel => 'Sort by';

  @override
  String get tasksSortByPriority => 'Priority';

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
  String get taskSummaries => 'Task Summaries';

  @override
  String get timeByCategoryChartTitle => 'Time by Category';

  @override
  String get timeByCategoryChartTotalLabel => 'Total';

  @override
  String get unlinkButton => 'Unlink';

  @override
  String get unlinkTaskConfirm => 'Are you sure you want to unlink this task?';

  @override
  String get unlinkTaskTitle => 'Unlink Task';

  @override
  String get viewMenuTitle => 'View';

  @override
  String get whatsNewDoneButton => 'Done';

  @override
  String get whatsNewSkipButton => 'Skip';
}

/// The translations for English, as used in the United Kingdom (`en_GB`).
class AppLocalizationsEnGb extends AppLocalizationsEn {
  AppLocalizationsEnGb() : super('en_GB');

  @override
  String get agentControlsReanalyzeButton => 'Re-analyse';

  @override
  String get aiAssistantAnalyzeImage => 'Analyse image';

  @override
  String get aiAssistantSummarizeTask => 'Summarise task';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Creates optimised models, prompts, and a test category';

  @override
  String get aiTaskSummaryRunning => 'Thinking about summarising task...';

  @override
  String get categoryCreationError =>
      'Failed to create category. Please try again.';

  @override
  String get categoryDeleteConfirmation =>
      'This action cannot be undone. All entries in this category will remain but will no longer be categorised.';

  @override
  String get categoryFavoriteDescription => 'Mark this category as a favourite';

  @override
  String get colorLabel => 'Colour:';

  @override
  String get colorPickerError => 'Invalid Hex colour';

  @override
  String get colorPickerHint => 'Enter Hex colour or pick';

  @override
  String get configFlagEnableAgentsDescription =>
      'Allow AI agents to autonomously monitor and analyse your tasks.';

  @override
  String get configFlagEnableAiStreaming =>
      'Enable AI streaming for task actions';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Stream AI responses for task-related actions. Turn off to buffer responses and keep the UI smoother.';

  @override
  String get configFlagEnableCalendarPage => 'Enable Calendar page';

  @override
  String get configFlagEnableDailyOs => 'Enable DailyOS';

  @override
  String get configFlagEnableDailyOsDescription =>
      'Show the DailyOS page in the main navigation.';

  @override
  String get configFlagEnableDashboardsPage => 'Enable Dashboards page';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Show the Dashboards page in the main navigation. View your data and insights in customisable dashboards.';

  @override
  String get configFlagEnableHabitsPage => 'Enable Habits page';

  @override
  String get configFlagEnableLogging => 'Enable logging';

  @override
  String get configFlagEnableMatrix => 'Enable Matrix sync';

  @override
  String get configFlagRecordLocationDescription =>
      'Automatically record your location with new entries. This helps with location-based organisation and search.';

  @override
  String get configFlagResendAttachments => 'Resend attachments';

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
  String get customColor => 'Custom Colour';

  @override
  String get dailyOsUncategorized => 'Uncategorised';

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
  String get enhancedPromptFormSystemMessageHelperText =>
      'Instructions that define the AI\'s behaviour and response style';

  @override
  String get entryActions => 'Actions';

  @override
  String get entryLabelsActionSubtitle =>
      'Assign labels to organise this entry';

  @override
  String get entryTypeLabelChecklistItem => 'To Do';

  @override
  String get eventNameLabel => 'Event:';

  @override
  String get favoriteLabel => 'Favourite';

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
  String get maintenanceRecreateFts5 => 'Recreate full-text index';

  @override
  String get maintenanceRecreateFts5Description =>
      'Recreate full-text search index';

  @override
  String get maintenanceReSync => 'Re-sync messages';

  @override
  String get maintenanceReSyncDescription => 'Re-sync messages from server';

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
  String get navTabTitleCalendar => 'DailyOS';

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
  String get promptBehaviorTitle => 'Prompt Behaviour';

  @override
  String get saveLabel => 'Save';

  @override
  String get searchHint => 'Search…';

  @override
  String get selectColor => 'Select Colour';

  @override
  String get sessionRatingEnergyQuestion => 'How energised did you feel?';

  @override
  String get settingsAboutAppInformation => 'App Information';

  @override
  String get settingsAboutAppTagline => 'Your Personal Journal';

  @override
  String get settingsAboutBuildType => 'Build Type';

  @override
  String get settingsAboutBuiltWithFlutter =>
      'Built with Flutter and love for personal journaling.';

  @override
  String get settingsAboutCredits => 'Credits';

  @override
  String get settingsAboutJournalEntries => 'Journal Entries';

  @override
  String get settingsAboutPlatform => 'Platform';

  @override
  String get settingsAboutThankYou => 'Thank you for using Lotti!';

  @override
  String get settingsAboutTitle => 'About Lotti';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutYourData => 'Your Data';

  @override
  String get settingsAdvancedConflictsSubtitle =>
      'Resolve synchronisation conflicts to ensure data consistency';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Perform maintenance tasks to optimise application performance';

  @override
  String get settingsAdvancedMatrixSyncSubtitle =>
      'Configure and manage Matrix synchronisation settings';

  @override
  String get settingsAdvancedTitle => 'Advanced Settings';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Create a category to organise your entries';

  @override
  String get settingsLabelsColorHeading => 'Select a colour';

  @override
  String get settingsLabelsSubtitle => 'Organise tasks with coloured labels';

  @override
  String get settingsMeasurableFavoriteLabel => 'Favourite: ';
}

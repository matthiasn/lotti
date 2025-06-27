// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get addActionAddAudioRecording => 'Audioaufnahme';

  @override
  String get addActionAddChecklist => 'Checkliste';

  @override
  String get addActionAddEvent => 'Ereignis';

  @override
  String get addActionAddImageFromClipboard => 'Bild einfügen';

  @override
  String get addActionAddPhotos => 'Foto(s)';

  @override
  String get addActionAddScreenshot => 'Screenshot';

  @override
  String get addActionAddTask => 'Aufgabe';

  @override
  String get addActionAddText => 'Texteingabe';

  @override
  String get addActionAddTimeRecording => 'Zeiteingabe';

  @override
  String get addAudioTitle => 'Audioaufnahme';

  @override
  String get addHabitCommentLabel => 'Kommentar';

  @override
  String get addHabitDateLabel => 'Abgeschlossen um';

  @override
  String get addMeasurementCommentLabel => 'Kommentar';

  @override
  String get addMeasurementDateLabel => 'Erfasst um';

  @override
  String get addMeasurementSaveButton => 'Speichern';

  @override
  String get addSurveyTitle => 'Umfrage ausfüllen';

  @override
  String get aiAssistantActionItemSuggestions => 'Vorschläge für Aktionspunkte';

  @override
  String get aiAssistantAnalyzeImage => 'Bild analysieren';

  @override
  String get aiAssistantSummarizeTask => 'Aufgabe zusammenfassen';

  @override
  String get aiAssistantThinking => 'Denke nach...';

  @override
  String get aiAssistantTitle => 'KI-Assistent';

  @override
  String get aiAssistantTranscribeAudio => 'Audio transkribieren';

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
  String get aiProviderWhisperDescription =>
      'Local Whisper transcription with OpenAI-compatible API';

  @override
  String get aiProviderWhisperName => 'Whisper (local)';

  @override
  String get aiResponseTypeActionItemSuggestions => 'Action Item Suggestions';

  @override
  String get aiResponseTypeAudioTranscription => 'Audio Transcription';

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
  String get aiTaskSummaryRunning =>
      'Denke über die Zusammenfassung der Aufgabe nach...';

  @override
  String get aiTaskSummaryTitle => 'KI-Aufgabenzusammenfassung';

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
  String get cancelButton => 'Abbrechen';

  @override
  String get categoryDeleteConfirm => 'JA, DIESE KATEGORIE LÖSCHEN';

  @override
  String get categoryDeleteQuestion => 'Möchten Sie diese Kategorie löschen?';

  @override
  String get categorySearchPlaceholder => 'Kategorien suchen...';

  @override
  String get checklistAddItem => 'Neues Element hinzufügen';

  @override
  String get checklistDelete => 'Checkliste löschen?';

  @override
  String get checklistItemDelete => 'Checklistenelement löschen?';

  @override
  String get checklistItemDeleteCancel => 'Abbrechen';

  @override
  String get checklistItemDeleteConfirm => 'Bestätigen';

  @override
  String get checklistItemDeleteWarning =>
      'Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get checklistItemDrag => 'Vorschläge in die Checkliste ziehen';

  @override
  String get checklistNoSuggestionsTitle =>
      'Keine vorgeschlagenen Aktionspunkte';

  @override
  String get checklistSuggestionsOutdated => 'Veraltet';

  @override
  String get checklistSuggestionsRunning =>
      'Denke über nicht verfolgte Vorschläge nach...';

  @override
  String get checklistSuggestionsTitle => 'Vorgeschlagene Aktionspunkte';

  @override
  String get checklistsTitle => 'Checklisten';

  @override
  String get colorLabel => 'Farbe:';

  @override
  String get colorPickerError => 'Ungültige Hex-Farbe';

  @override
  String get colorPickerHint => 'Hex-Farbe eingeben oder auswählen';

  @override
  String get completeHabitFailButton => 'Fehlgeschlagen';

  @override
  String get completeHabitSkipButton => 'Überspringen';

  @override
  String get completeHabitSuccessButton => 'Erfolgreich';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Wenn aktiviert, versucht die App, Einbettungen für Ihre Einträge zu generieren, um die Suche und Vorschläge für verwandte Inhalte zu verbessern.';

  @override
  String get configFlagAutoTranscribeDescription =>
      'Transkribiert automatisch Audioaufnahmen in Ihren Einträgen. Dies erfordert eine Internetverbindung.';

  @override
  String get configFlagEnableAutoTaskTldrDescription =>
      'Generiert automatisch Zusammenfassungen für Ihre Aufgaben, damit Sie deren Status schnell erfassen können.';

  @override
  String get configFlagEnableCalendarPageDescription =>
      'Zeigt die Kalenderseite in der Hauptnavigation an. Zeigen und verwalten Sie Ihre Einträge in einer Kalenderansicht.';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Zeigt die Dashboard-Seite in der Hauptnavigation an. Zeigen Sie Ihre Daten und Erkenntnisse in anpassbaren Dashboards an.';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Zeigt die Seite \"Gewohnheiten\" in der Hauptnavigation an. Verfolgen und verwalten Sie hier Ihre täglichen Gewohnheiten.';

  @override
  String get configFlagEnableLoggingDescription =>
      'Aktiviert die detaillierte Protokollierung für Debugging-Zwecke. Dies kann die Leistung beeinträchtigen.';

  @override
  String get configFlagEnableMatrixDescription =>
      'Aktiviert die Matrix-Integration, um Ihre Einträge geräteübergreifend und mit anderen Matrix-Benutzern zu synchronisieren.';

  @override
  String get configFlagEnableNotifications => 'Benachrichtigungen aktivieren?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Erhalten Sie Benachrichtigungen für Erinnerungen, Updates und wichtige Ereignisse.';

  @override
  String get configFlagEnableTooltipDescription =>
      'Zeigt hilfreiche Tooltips in der gesamten App an, um Sie durch die Funktionen zu führen.';

  @override
  String get configFlagPrivate => 'Private Einträge anzeigen?';

  @override
  String get configFlagPrivateDescription =>
      'Aktivieren Sie diese Option, um Ihre Einträge standardmäßig privat zu machen. Private Einträge sind nur für Sie sichtbar.';

  @override
  String get configFlagRecordLocationDescription =>
      'Zeichnet automatisch Ihren Standort mit neuen Einträgen auf. Dies hilft bei der ortsbezogenen Organisation und Suche.';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Aktivieren Sie diese Option, um fehlgeschlagene Anlagen-Uploads automatisch erneut zu senden, wenn die Verbindung wiederhergestellt ist.';

  @override
  String get configFlagUseCloudInferenceDescription =>
      'Cloud-basierte KI-Dienste für erweiterte Funktionen verwenden. Dies erfordert eine Internetverbindung.';

  @override
  String get conflictsResolved => 'gelöst';

  @override
  String get conflictsUnresolved => 'ungelöst';

  @override
  String get createCategoryTitle => 'Kategorie erstellen:';

  @override
  String get createEntryLabel => 'Neuen Eintrag erstellen';

  @override
  String get createEntryTitle => 'Hinzufügen';

  @override
  String get dashboardActiveLabel => 'Aktiv:';

  @override
  String get dashboardAddChartsTitle => 'Diagramme hinzufügen:';

  @override
  String get dashboardAddHabitButton => 'Gewohnheitsdiagramme';

  @override
  String get dashboardAddHabitTitle => 'Gewohnheitsdiagramme';

  @override
  String get dashboardAddHealthButton => 'Gesundheitsdiagramme';

  @override
  String get dashboardAddHealthTitle => 'Gesundheitsdiagramme';

  @override
  String get dashboardAddMeasurementButton => 'Messwertdiagramme';

  @override
  String get dashboardAddMeasurementTitle => 'Messwertdiagramme';

  @override
  String get dashboardAddSurveyButton => 'Umfragediagramme';

  @override
  String get dashboardAddSurveyTitle => 'Umfragediagramme';

  @override
  String get dashboardAddWorkoutButton => 'Trainingsdiagramme';

  @override
  String get dashboardAddWorkoutTitle => 'Trainingsdiagramme';

  @override
  String get dashboardAggregationLabel => 'Aggregationsart:';

  @override
  String get dashboardCategoryLabel => 'Kategorie:';

  @override
  String get dashboardCopyHint =>
      'Dashboard-Konfiguration speichern & kopieren';

  @override
  String get dashboardDeleteConfirm => 'JA, DIESES DASHBOARD LÖSCHEN';

  @override
  String get dashboardDeleteHint => 'Dashboard löschen';

  @override
  String get dashboardDeleteQuestion => 'Möchten Sie dieses Dashboard löschen?';

  @override
  String get dashboardDescriptionLabel => 'Beschreibung (optional):';

  @override
  String get dashboardNameLabel => 'Dashboard-Name:';

  @override
  String get dashboardNotFound => 'Dashboard nicht gefunden';

  @override
  String get dashboardPrivateLabel => 'Privat:';

  @override
  String get done => 'Done';

  @override
  String get doneButton => 'Fertig';

  @override
  String get editMenuTitle => 'Bearbeiten';

  @override
  String get editorPlaceholder => 'Notizen eingeben...';

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
  String get entryActions => 'Aktionen';

  @override
  String get eventNameLabel => 'Ereignis:';

  @override
  String get fileMenuNewEllipsis => 'Neu ...';

  @override
  String get fileMenuNewEntry => 'Neuer Eintrag';

  @override
  String get fileMenuNewScreenshot => 'Screenshot';

  @override
  String get fileMenuNewTask => 'Aufgabe';

  @override
  String get fileMenuTitle => 'Datei';

  @override
  String get habitActiveFromLabel => 'Startdatum';

  @override
  String get habitArchivedLabel => 'Archiviert:';

  @override
  String get habitCategoryHint => 'Kategorie auswählen...';

  @override
  String get habitCategoryLabel => 'Kategorie:';

  @override
  String get habitDashboardHint => 'Dashboard auswählen...';

  @override
  String get habitDashboardLabel => 'Dashboard:';

  @override
  String get habitDeleteConfirm => 'JA, DIESE GEWOHNHEIT LÖSCHEN';

  @override
  String get habitDeleteQuestion => 'Möchten Sie diese Gewohnheit löschen?';

  @override
  String get habitPriorityLabel => 'Priorität:';

  @override
  String get habitShowAlertAtLabel => 'Alarm anzeigen um';

  @override
  String get habitShowFromLabel => 'Anzeigen ab';

  @override
  String get habitsCompletedHeader => 'Abgeschlossen';

  @override
  String get habitsFilterAll => 'alle';

  @override
  String get habitsFilterCompleted => 'erledigt';

  @override
  String get habitsFilterOpenNow => 'fällig';

  @override
  String get habitsFilterPendingLater => 'später';

  @override
  String get habitsOpenHeader => 'Jetzt fällig';

  @override
  String get habitsPendingLaterHeader => 'Später heute';

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
  String get journalCopyImageLabel => 'Bild kopieren';

  @override
  String get journalDateFromLabel => 'Datum von:';

  @override
  String get journalDateInvalid => 'Ungültiger Datumsbereich';

  @override
  String get journalDateNowButton => 'Jetzt';

  @override
  String get journalDateSaveButton => 'SPEICHERN';

  @override
  String get journalDateToLabel => 'Datum bis:';

  @override
  String get journalDeleteConfirm => 'JA, DIESEN EINTRAG LÖSCHEN';

  @override
  String get journalDeleteHint => 'Eintrag löschen';

  @override
  String get journalDeleteQuestion =>
      'Möchten Sie diesen Journaleintrag löschen?';

  @override
  String get journalDurationLabel => 'Dauer:';

  @override
  String get journalFavoriteTooltip => 'nur Favoriten';

  @override
  String get journalFlaggedTooltip => 'nur markiert';

  @override
  String get journalHideMapHint => 'Karte ausblenden';

  @override
  String get journalLinkFromHint => 'Verknüpfen von';

  @override
  String get journalLinkToHint => 'Verknüpfen mit';

  @override
  String get journalLinkedEntriesAiLabel => 'KI-generierte Einträge anzeigen:';

  @override
  String get journalLinkedEntriesHiddenLabel => 'Versteckte Einträge anzeigen:';

  @override
  String get journalLinkedEntriesLabel => 'Verknüpfte Einträge';

  @override
  String get journalLinkedFromLabel => 'Verknüpft von:';

  @override
  String get journalPrivateTooltip => 'nur privat';

  @override
  String get journalSearchHint => 'Tagebuch durchsuchen...';

  @override
  String get journalShareAudioHint => 'Audio teilen';

  @override
  String get journalSharePhotoHint => 'Foto teilen';

  @override
  String get journalShowMapHint => 'Karte anzeigen';

  @override
  String get journalTagPlusHint => 'Eintrag-Tags verwalten';

  @override
  String get journalTagsCopyHint => 'Tags kopieren';

  @override
  String get journalTagsLabel => 'Tags:';

  @override
  String get journalTagsPasteHint => 'Tags einfügen';

  @override
  String get journalTagsRemoveHint => 'Tag entfernen';

  @override
  String get journalToggleFlaggedTitle => 'Markiert';

  @override
  String get journalTogglePrivateTitle => 'Privat';

  @override
  String get journalToggleStarredTitle => 'Favorit';

  @override
  String get journalUnlinkConfirm => 'JA, EINTRAG TRENNEN';

  @override
  String get journalUnlinkHint => 'Trennen';

  @override
  String get journalUnlinkQuestion =>
      'Möchten Sie diesen Eintrag wirklich trennen?';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'YES, DELETE DATABASE';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Are you sure you want to delete $databaseName Database?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Entwürfe-Datenbank löschen';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Delete editor drafts database';

  @override
  String get maintenanceDeleteLoggingDb => 'Logging-Datenbank löschen';

  @override
  String get maintenanceDeleteLoggingDbDescription => 'Delete logging database';

  @override
  String get maintenanceDeleteSyncDb => 'Synchronisierungsdatenbank löschen';

  @override
  String get maintenanceDeleteSyncDbDescription => 'Delete sync database';

  @override
  String get maintenancePurgeAudioModels => 'Audiomodelle löschen';

  @override
  String get maintenancePurgeAudioModelsConfirm => 'YES, PURGE MODELS';

  @override
  String get maintenancePurgeAudioModelsDescription => 'Purge all audio models';

  @override
  String get maintenancePurgeAudioModelsMessage =>
      'Are you sure you want to purge all audio models? This action cannot be undone.';

  @override
  String get maintenancePurgeDeleted => 'Gelöschte Elemente löschen';

  @override
  String get maintenancePurgeDeletedConfirm => 'Yes, purge all';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Purge all deleted items permanently';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Are you sure you want to purge all deleted items? This action cannot be undone.';

  @override
  String get maintenanceReSync => 'Nachrichten erneut synchronisieren';

  @override
  String get maintenanceReSyncDescription => 'Re-sync messages from server';

  @override
  String get maintenanceRecreateFts5 => 'Volltextindex neu erstellen';

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
      'Sync tags, measurables, dashboards, habits, categories';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sync tags, measurables, dashboards, habits, categories';

  @override
  String get measurableDeleteConfirm => 'JA, DIESE MESSGRÖSSE LÖSCHEN';

  @override
  String get measurableDeleteQuestion =>
      'Möchten Sie diesen Messgrößen-Datentyp löschen?';

  @override
  String get measurableNotFound => 'Messgröße nicht gefunden';

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
  String get navTabTitleCalendar => 'Kalender';

  @override
  String get navTabTitleHabits => 'Gewohnheiten';

  @override
  String get navTabTitleInsights => 'Dashboards';

  @override
  String get navTabTitleJournal => 'Logbuch';

  @override
  String get navTabTitleSettings => 'Einstellungen';

  @override
  String get navTabTitleTasks => 'Aufgaben';

  @override
  String get outboxMonitorLabelAll => 'alle';

  @override
  String get outboxMonitorLabelError => 'Fehler';

  @override
  String get outboxMonitorLabelPending => 'ausstehend';

  @override
  String get outboxMonitorLabelSent => 'gesendet';

  @override
  String get outboxMonitorNoAttachment => 'kein Anhang';

  @override
  String get outboxMonitorRetries => 'Wiederholungen';

  @override
  String get outboxMonitorRetry => 'wiederholen';

  @override
  String get outboxMonitorSwitchLabel => 'aktiviert';

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
  String get saveLabel => 'Speichern';

  @override
  String get searchHint => 'Suchen...';

  @override
  String get settingThemingDark => 'Dunkles Design';

  @override
  String get settingThemingLight => 'Helles Design';

  @override
  String get settingsAboutTitle => 'Über Lotti';

  @override
  String get settingsAdvancedShowCaseAboutLottiTooltip =>
      'Erfahren Sie mehr über die Lotti-Anwendung, einschließlich Version und Credits.';

  @override
  String get settingsAdvancedShowCaseApiKeyTooltip =>
      'Verwalten Sie Ihre API-Schlüssel für verschiedene KI-Anbieter. Fügen Sie Schlüssel hinzu, bearbeiten oder löschen Sie sie, um Integrationen mit unterstützten Diensten wie OpenAI, Gemini und mehr zu konfigurieren. Stellen Sie eine sichere Handhabung sensibler Informationen sicher.';

  @override
  String get settingsAdvancedShowCaseConflictsTooltip =>
      'Synchronisierungskonflikte lösen, um Datenkonsistenz zu gewährleisten.';

  @override
  String get settingsAdvancedShowCaseHealthImportTooltip =>
      'Gesundheitsbezogene Daten aus externen Quellen importieren.';

  @override
  String get settingsAdvancedShowCaseLogsTooltip =>
      'Zugriff auf Anwendungsprotokolle für Debugging und Überwachung.';

  @override
  String get settingsAdvancedShowCaseMaintenanceTooltip =>
      'Wartungsaufgaben durchführen, um die Anwendungsleistung zu optimieren.';

  @override
  String get settingsAdvancedShowCaseMatrixSyncTooltip =>
      'Konfigurieren und verwalten Sie die Matrix-Synchronisierungseinstellungen für eine nahtlose Datenintegration.';

  @override
  String get settingsAdvancedShowCaseModelsTooltip =>
      'Define AI models that use inference providers';

  @override
  String get settingsAdvancedShowCaseSyncOutboxTooltip =>
      'Elemente anzeigen und verwalten, die in der Outbox auf die Synchronisierung warten.';

  @override
  String get settingsAdvancedTitle => 'Erweiterte Einstellungen';

  @override
  String get settingsAiApiKeys => 'AI Inference Providers';

  @override
  String get settingsAiModels => 'AI Models';

  @override
  String get settingsCategoriesDetailsLabel => 'Category Details';

  @override
  String get settingsCategoriesDuplicateError => 'Kategorie existiert bereits';

  @override
  String get settingsCategoriesNameLabel => 'Kategoriename:';

  @override
  String get settingsCategoriesTitle => 'Kategorien';

  @override
  String get settingsCategoryShowCaseActiveTooltip =>
      'Aktivieren Sie diese Option, um die Kategorie als aktiv zu markieren. Aktive Kategorien sind derzeit in Verwendung und werden für eine bessere Zugänglichkeit gut sichtbar angezeigt.';

  @override
  String get settingsCategoryShowCaseColorTooltip =>
      'Wählen Sie eine Farbe aus, die diese Kategorie repräsentiert. Sie können entweder einen gültigen HEX-Farbcode eingeben (z. B. #FF5733) oder die Farbauswahl rechts verwenden, um eine Farbe visuell auszuwählen.';

  @override
  String get settingsCategoryShowCaseDelTooltip =>
      'Klicken Sie auf diese Schaltfläche, um die Kategorie zu löschen. Bitte beachten Sie, dass diese Aktion nicht rückgängig gemacht werden kann. Stellen Sie daher sicher, dass Sie die Kategorie entfernen möchten, bevor Sie fortfahren.';

  @override
  String get settingsCategoryShowCaseFavTooltip =>
      'Aktivieren Sie diese Option, um die Kategorie als Favorit zu markieren. Lieblingskategorien sind leichter zugänglich und werden zur schnellen Referenz hervorgehoben.';

  @override
  String get settingsCategoryShowCaseNameTooltip =>
      'Geben Sie einen klaren und relevanten Namen für die Kategorie ein. Halten Sie ihn kurz und beschreibend, damit Sie seinen Zweck leicht erkennen können.';

  @override
  String get settingsCategoryShowCasePrivateTooltip =>
      'Aktivieren Sie diese Option, um die Kategorie als privat zu markieren. Private Kategorien sind nur für Sie sichtbar und helfen Ihnen, sensible oder persönliche Gewohnheiten und Aufgaben sicher zu organisieren.';

  @override
  String get settingsConflictsResolutionTitle =>
      'Lösung von Synchronisierungskonflikten';

  @override
  String get settingsConflictsTitle => 'Synchronisierungskonflikte';

  @override
  String get settingsDashboardDetailsLabel => 'Dashboard Details';

  @override
  String get settingsDashboardSaveLabel => 'Save';

  @override
  String get settingsDashboardsShowCaseActiveTooltip =>
      'Aktivieren Sie diesen Schalter, um das Dashboard als aktiv zu markieren. Aktive Dashboards sind derzeit in Verwendung und werden für eine bessere Zugänglichkeit gut sichtbar angezeigt.';

  @override
  String get settingsDashboardsShowCaseCatTooltip =>
      'Wählen Sie eine Kategorie aus, die das Dashboard am besten beschreibt. Dies hilft Ihnen, Ihre Dashboards effektiv zu organisieren und zu kategorisieren. Beispiele: \'Gesundheit\', \'Produktivität\', \'Arbeit\'.';

  @override
  String get settingsDashboardsShowCaseCopyTooltip =>
      'Tippen Sie hier, um dieses Dashboard zu kopieren. Dadurch können Sie das Dashboard duplizieren und an anderer Stelle verwenden.';

  @override
  String get settingsDashboardsShowCaseDelTooltip =>
      'Tippen Sie auf diese Schaltfläche, um das Dashboard dauerhaft zu löschen. Seien Sie vorsichtig, da diese Aktion nicht rückgängig gemacht werden kann und alle zugehörigen Daten entfernt werden.';

  @override
  String get settingsDashboardsShowCaseDescrTooltip =>
      'Geben Sie eine detaillierte Beschreibung für das Dashboard an. Dies hilft Ihnen, den Zweck und den Inhalt des Dashboards zu verstehen. Beispiele: \'Verfolgt tägliche Wellness-Aktivitäten\', \'Überwacht arbeitsbezogene Aufgaben und Ziele\'.';

  @override
  String get settingsDashboardsShowCaseHealthChartsTooltip =>
      'Wählen Sie die Gesundheitsdiagramme aus, die Sie in Ihr Dashboard aufnehmen möchten. Beispiele: \'Gewicht\', \'Körperfettanteil\'.';

  @override
  String get settingsDashboardsShowCaseNameTooltip =>
      'Geben Sie einen klaren und relevanten Namen für das Dashboard ein. Halten Sie ihn kurz und beschreibend, damit Sie seinen Zweck leicht erkennen können. Beispiele: \'Wellness-Tracker\', \'Tagesziele\', \'Arbeitsplan\'.';

  @override
  String get settingsDashboardsShowCasePrivateTooltip =>
      'Aktivieren Sie diesen Schalter, um das Dashboard privat zu machen. Private Dashboards sind nur für Sie sichtbar und werden nicht mit anderen geteilt.';

  @override
  String get settingsDashboardsShowCaseSurveyChartsTooltip =>
      'Wählen Sie die Umfragediagramme aus, die Sie in Ihr Dashboard aufnehmen möchten. Beispiele: \'Kundenzufriedenheit\', \'Mitarbeiterfeedback\'.';

  @override
  String get settingsDashboardsShowCaseWorkoutChartsTooltip =>
      'Wählen Sie die Trainingsdiagramme aus, die Sie in Ihr Dashboard aufnehmen möchten. Beispiele: \'Gehen\', \'Laufen\', \'Schwimmen\'.';

  @override
  String get settingsDashboardsTitle => 'Dashboards';

  @override
  String get settingsFlagsTitle => 'Konfigurationsflags';

  @override
  String get settingsHabitsDeleteTooltip => 'Gewohnheit löschen';

  @override
  String get settingsHabitsDescriptionLabel => 'Beschreibung (optional):';

  @override
  String get settingsHabitsDetailsLabel => 'Habit Details';

  @override
  String get settingsHabitsNameLabel => 'Name der Gewohnheit:';

  @override
  String get settingsHabitsPrivateLabel => 'Privat: ';

  @override
  String get settingsHabitsSaveLabel => 'Speichern';

  @override
  String get settingsHabitsShowCaseAlertTimeTooltip =>
      'Legen Sie die Uhrzeit fest, zu der Sie eine Erinnerung oder einen Alarm für diese Gewohnheit erhalten möchten. So stellen Sie sicher, dass Sie die Ausführung nie verpassen. Beispiel: \'20:00 Uhr\'.';

  @override
  String get settingsHabitsShowCaseArchivedTooltip =>
      'Diesen Schalter umschalten, um die Gewohnheit zu archivieren. Archivierte Gewohnheiten sind nicht mehr aktiv, bleiben aber für spätere Referenz oder Überprüfung gespeichert. Beispiele: \'Gitarre lernen\', \'Abgeschlossener Kurs\'.';

  @override
  String get settingsHabitsShowCaseCatTooltip =>
      'Wähle eine Kategorie, die deine Gewohnheit am besten beschreibt, oder erstelle eine neue, indem du die Schaltfläche [+] auswählst.\nBeispiele: \'Gesundheit\', \'Produktivität\', \'Sport\'.';

  @override
  String get settingsHabitsShowCaseDashTooltip =>
      'Wähle ein Dashboard aus, um deine Gewohnheit zu organisieren und zu verfolgen, oder erstelle ein neues Dashboard mit der Schaltfläche [+].\nBeispiele: \'Wellness-Tracker\', \'Tägliche Ziele\', \'Arbeitsplan\'.';

  @override
  String get settingsHabitsShowCaseDelHabitTooltip =>
      'Tippe auf diese Schaltfläche, um die Gewohnheit dauerhaft zu löschen. Seien Sie vorsichtig, da diese Aktion nicht rückgängig gemacht werden kann und alle zugehörigen Daten entfernt werden.';

  @override
  String get settingsHabitsShowCaseDescrTooltip =>
      'Gib eine kurze und aussagekräftige Beschreibung der Gewohnheit an. Füge alle relevanten Details oder\nKontext hinzu, um den Zweck und die Bedeutung der Gewohnheit klar zu definieren.\nBeispiele: \'Jeden Morgen 30 Minuten joggen, um die Fitness zu steigern\' oder \'Täglich ein Kapitel lesen, um Wissen und Konzentration zu verbessern\'.';

  @override
  String get settingsHabitsShowCaseNameTooltip =>
      'Gib einen klaren und beschreibenden Namen für die Gewohnheit ein.\nVermeide zu lange Namen und halte ihn kurz genug, um die Gewohnheit leicht zu identifizieren.\nBeispiele: \'Morgenjoggen\', \'Täglich lesen\'.';

  @override
  String get settingsHabitsShowCasePriorTooltip =>
      'Schalte den Schalter um, um der Gewohnheit Priorität zuzuweisen. Gewohnheiten mit hoher Priorität stellen oft wichtige oder dringende Aufgaben dar, auf die du dich konzentrieren möchtest. Beispiele: \'Täglich trainieren\', \'An Projekt arbeiten\'.';

  @override
  String get settingsHabitsShowCasePrivateTooltip =>
      'Verwende diesen Schalter, um die Gewohnheit als privat zu markieren. Private Gewohnheiten sind nur für dich sichtbar und werden nicht mit anderen geteilt. Beispiele: \'Persönliches Tagebuch\', \'Meditation\'.';

  @override
  String get settingsHabitsShowCaseStarDateTooltip =>
      'Wähle das Datum aus, an dem du mit der Verfolgung dieser Gewohnheit beginnen möchtest. Dies hilft, den Beginn der Gewohnheit zu definieren und ermöglicht eine genaue Fortschrittsüberwachung. Beispiel: \'1. Juli 2025\'.';

  @override
  String get settingsHabitsShowCaseStartTimeTooltip =>
      'Stelle die Uhrzeit ein, ab der diese Gewohnheit in deinem Zeitplan sichtbar sein oder erscheinen soll. Dies hilft, deinen Tag effektiv zu organisieren. Beispiel: \'7:00 Uhr\'.';

  @override
  String get settingsHabitsTitle => 'Gewohnheiten';

  @override
  String get settingsHealthImportFromDate => 'Start';

  @override
  String get settingsHealthImportTitle => 'Gesundheitsdatenimport';

  @override
  String get settingsHealthImportToDate => 'Ende';

  @override
  String get settingsLogsTitle => 'Protokolle';

  @override
  String get settingsMaintenanceTitle => 'Wartung';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'Anderes Gerät zeigt Emojis, fortfahren';

  @override
  String get settingsMatrixCancel => 'Abbrechen';

  @override
  String get settingsMatrixCancelVerificationLabel => 'Verifizierung abbrechen';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Auf anderem Gerät akzeptieren, um fortzufahren';

  @override
  String get settingsMatrixDeleteLabel => 'Löschen';

  @override
  String get settingsMatrixDone => 'Fertig';

  @override
  String get settingsMatrixEnterValidUrl => 'Bitte gib eine gültige URL ein';

  @override
  String get settingsMatrixHomeServerLabel => 'Homeserver';

  @override
  String get settingsMatrixHomeserverConfigTitle =>
      'Matrix-Homeserver-Einrichtung';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Nicht verifizierte Geräte';

  @override
  String get settingsMatrixLoginButtonLabel => 'Anmelden';

  @override
  String get settingsMatrixLoginFailed => 'Anmeldung fehlgeschlagen';

  @override
  String get settingsMatrixLogoutButtonLabel => 'Abmelden';

  @override
  String get settingsMatrixNextPage => 'Nächste Seite';

  @override
  String get settingsMatrixNoUnverifiedLabel =>
      'Keine nicht verifizierten Geräte';

  @override
  String get settingsMatrixPasswordLabel => 'Passwort';

  @override
  String get settingsMatrixPasswordTooShort => 'Passwort zu kurz';

  @override
  String get settingsMatrixPreviousPage => 'Vorherige Seite';

  @override
  String get settingsMatrixQrTextPage =>
      'Scanne diesen QR-Code, um das Gerät zu einem Synchronisierungsraum einzuladen.';

  @override
  String get settingsMatrixRoomConfigTitle =>
      'Matrix-Synchronisierungsraum-Einrichtung';

  @override
  String get settingsMatrixStartVerificationLabel => 'Verifizierung starten';

  @override
  String get settingsMatrixStatsTitle => 'Matrix-Statistiken';

  @override
  String get settingsMatrixTitle => 'Matrix-Synchronisierungseinstellungen';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Nicht verifizierte Geräte';

  @override
  String get settingsMatrixUserLabel => 'Benutzer';

  @override
  String get settingsMatrixUserNameTooShort => 'Benutzername zu kurz';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Auf anderem Gerät abgebrochen...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Verstanden';

  @override
  String settingsMatrixVerificationSuccessLabel(
      String deviceName, String deviceID) {
    return 'Sie haben $deviceName ($deviceID) erfolgreich verifiziert';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Bestätigen Sie auf dem anderen Gerät, dass die unten stehenden Emojis auf beiden Geräten in der gleichen Reihenfolge angezeigt werden:';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Bestätigen Sie, dass die unten stehenden Emojis auf beiden Geräten in der gleichen Reihenfolge angezeigt werden:';

  @override
  String get settingsMatrixVerifyLabel => 'Verifizieren';

  @override
  String get settingsMeasurableAggregationLabel =>
      'Standard-Aggregationsart (optional):';

  @override
  String get settingsMeasurableDeleteTooltip => 'Messgröße löschen';

  @override
  String get settingsMeasurableDescriptionLabel => 'Beschreibung (optional):';

  @override
  String get settingsMeasurableDetailsLabel => 'Measurable Details';

  @override
  String get settingsMeasurableFavoriteLabel => 'Favorit: ';

  @override
  String get settingsMeasurableNameLabel => 'Name der Messgröße:';

  @override
  String get settingsMeasurablePrivateLabel => 'Privat: ';

  @override
  String get settingsMeasurableSaveLabel => 'Speichern';

  @override
  String get settingsMeasurableShowCaseAggreTypeTooltip =>
      'Wählen Sie die Standardaggregationsart für die Messdaten. Dies bestimmt, wie die Daten im Zeitverlauf zusammengefasst werden. \nOptionen: \'dailySum\', \'dailyMax\', \'dailyAvg\', \'hourlySum\'.';

  @override
  String get settingsMeasurableShowCaseDelTooltip =>
      'Klicken Sie auf diese Schaltfläche, um die Messgröße zu löschen. Bitte beachten Sie, dass diese Aktion unwiderruflich ist. Stellen Sie daher sicher, dass Sie die Messgröße entfernen möchten, bevor Sie fortfahren.';

  @override
  String get settingsMeasurableShowCaseDescrTooltip =>
      'Geben Sie eine kurze und aussagekräftige Beschreibung der Messgröße an. Fügen Sie alle relevanten Details oder Kontext hinzu, um deren Zweck und Bedeutung klar zu definieren. \nBeispiele: \'Körpergewicht in Kilogramm gemessen\'';

  @override
  String get settingsMeasurableShowCaseNameTooltip =>
      'Geben Sie einen klaren und beschreibenden Namen für die Messgröße ein.\nVermeiden Sie zu lange Namen und machen Sie ihn prägnant genug, um die Messgröße leicht zu identifizieren. \nBeispiele: \'Gewicht\', \'Blutdruck\'.';

  @override
  String get settingsMeasurableShowCasePrivateTooltip =>
      'Aktivieren Sie diese Option, um die Messgröße als privat zu markieren. Private Messgrößen sind nur für Sie sichtbar und helfen Ihnen, sensible oder persönliche Daten sicher zu verwalten.';

  @override
  String get settingsMeasurableShowCaseUnitTooltip =>
      'Geben Sie eine klare und prägnante Einheitenabkürzung für die Messgröße ein. Dies hilft, die Maßeinheit leicht zu identifizieren.';

  @override
  String get settingsMeasurableUnitLabel => 'Einheitenabkürzung (optional):';

  @override
  String get settingsMeasurablesTitle => 'Messgrößen';

  @override
  String get settingsSpeechAudioWithoutTranscript =>
      'Audioeinträge ohne Transkript:';

  @override
  String get settingsSpeechAudioWithoutTranscriptButton =>
      'Suchen & transkribieren';

  @override
  String get settingsSpeechLastActivity => 'Letzte Transkriptionsaktivität:';

  @override
  String get settingsSpeechModelSelectionTitle =>
      'Whisper Spracherkennungsmodell:';

  @override
  String get settingsSyncOutboxTitle => 'Sync-Postausgang';

  @override
  String get settingsTagsDeleteTooltip => 'Tag löschen';

  @override
  String get settingsTagsDetailsLabel => 'Tags Details';

  @override
  String get settingsTagsHideLabel => 'In Vorschlägen ausblenden:';

  @override
  String get settingsTagsPrivateLabel => 'Privat:';

  @override
  String get settingsTagsSaveLabel => 'Speichern';

  @override
  String get settingsTagsShowCaseDeleteTooltip =>
      'Entfernen Sie dieses Tag dauerhaft. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get settingsTagsShowCaseHideTooltip =>
      'Aktivieren Sie diese Option, um dieses Tag in Vorschlägen auszublenden. Verwenden Sie es für Tags, die persönlich sind oder nicht häufig benötigt werden.';

  @override
  String get settingsTagsShowCaseNameTooltip =>
      'Geben Sie einen klaren und relevanten Namen für das Tag ein. Halten Sie es kurz und beschreibend, damit Sie Ihre Gewohnheiten leicht kategorisieren können. Beispiele: \"Gesundheit\", \"Produktivität\", \"Achtsamkeit\".';

  @override
  String get settingsTagsShowCasePrivateTooltip =>
      'Aktivieren Sie diese Option, um das Tag privat zu machen. Private Tags sind nur für Sie sichtbar und werden nicht mit anderen geteilt.';

  @override
  String get settingsTagsShowCaseTypeTooltip =>
      'Wählen Sie den Typ des Tags, um es richtig zu kategorisieren: \n[Tag]-> Allgemeine Kategorien wie \'Gesundheit\' oder \'Produktivität\'. \n[Person]-> Verwendung zum Markieren bestimmter Personen. \n[Story]-> Tags an Storys anhängen, um die Organisation zu verbessern.';

  @override
  String get settingsTagsTagName => 'Tag:';

  @override
  String get settingsTagsTitle => 'Tags';

  @override
  String get settingsTagsTypeLabel => 'Tag-Typ:';

  @override
  String get settingsTagsTypePerson => 'PERSON';

  @override
  String get settingsTagsTypeStory => 'STORY';

  @override
  String get settingsTagsTypeTag => 'TAG';

  @override
  String get settingsThemingAutomatic => 'Automatisch';

  @override
  String get settingsThemingDark => 'Dunkles Erscheinungsbild';

  @override
  String get settingsThemingLight => 'Helles Erscheinungsbild';

  @override
  String get settingsThemingShowCaseDarkTooltip =>
      'Wählen Sie das dunkle Thema für ein dunkleres Erscheinungsbild.';

  @override
  String get settingsThemingShowCaseLightTooltip =>
      'Wählen Sie das helle Thema für ein helleres Erscheinungsbild.';

  @override
  String get settingsThemingShowCaseModeTooltip =>
      'Wählen Sie Ihren bevorzugten Themenmodus: Hell, Dunkel oder Automatisch.';

  @override
  String get settingsThemingTitle => 'Farbschema';

  @override
  String get showcaseCloseButton => 'Schließen';

  @override
  String get showcaseNextButton => 'Weiter';

  @override
  String get showcasePreviousButton => 'Zurück';

  @override
  String get speechModalAddTranscription => 'Transkription hinzufügen';

  @override
  String get speechModalSelectLanguage => 'Sprache auswählen';

  @override
  String get speechModalTitle => 'Spracherkennung';

  @override
  String get speechModalTranscriptionProgress => 'Transkriptionsfortschritt';

  @override
  String get syncDeleteConfigConfirm => 'JA, ICH BIN SICHER';

  @override
  String get syncDeleteConfigQuestion =>
      'Möchten Sie die Synchronisierungskonfiguration löschen?';

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
  String get taskCategoryAllLabel => 'Alle';

  @override
  String get taskCategoryLabel => 'Kategorie:';

  @override
  String get taskCategoryUnassignedLabel => 'Nicht zugewiesen';

  @override
  String get taskEstimateLabel => 'Schätzung:';

  @override
  String get taskNameHint => 'Geben Sie einen Namen für die Aufgabe ein';

  @override
  String get taskStatusAll => 'Alle';

  @override
  String get taskStatusBlocked => 'Blockiert';

  @override
  String get taskStatusDone => 'Erledigt';

  @override
  String get taskStatusGroomed => 'Gepflegt';

  @override
  String get taskStatusInProgress => 'In Bearbeitung';

  @override
  String get taskStatusLabel => 'Status:';

  @override
  String get taskStatusOnHold => 'Zurückgestellt';

  @override
  String get taskStatusOpen => 'Offen';

  @override
  String get taskStatusRejected => 'Abgelehnt';

  @override
  String get tasksFilterTitle => 'Aufgabenfilter';

  @override
  String get timeByCategoryChartTitle => 'Zeit nach Kategorie';

  @override
  String get timeByCategoryChartTotalLabel => 'Gesamt';

  @override
  String get viewMenuTitle => 'Ansicht';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Error';

  @override
  String get commonUnknown => 'Unknown';
}

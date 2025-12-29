// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get addActionAddAudioRecording => 'Commencer l\'enregistrement audio';

  @override
  String get addActionAddChecklist => 'Liste de contrôle';

  @override
  String get addActionAddEvent => 'Événement';

  @override
  String get addActionAddImageFromClipboard => 'Coller l\'image';

  @override
  String get addActionAddPhotos => 'Ajouter des photos';

  @override
  String get addActionAddScreenshot => 'Ajouter une capture d\'écran';

  @override
  String get addActionAddTask => 'Ajouter une tâche';

  @override
  String get addActionAddText => 'Ajouter du texte';

  @override
  String get addActionAddTimer => 'Timer';

  @override
  String get addActionImportImage => 'Import Image';

  @override
  String get addActionAddTimeRecording =>
      'Commencer l\'enregistrement du temps';

  @override
  String get addAudioTitle => 'Enregistrement audio';

  @override
  String get addHabitCommentLabel => 'Commentaire';

  @override
  String get addHabitDateLabel => 'Terminé à';

  @override
  String get addMeasurementCommentLabel => 'Commentaire';

  @override
  String get addMeasurementDateLabel => 'Observé à';

  @override
  String get addMeasurementSaveButton => 'Enregistrer';

  @override
  String get addSurveyTitle => 'Remplir le questionnaire';

  @override
  String get aiAssistantActionItemSuggestions => 'Suggestions d\'actions';

  @override
  String get aiAssistantAnalyzeImage => 'Analyser l\'image';

  @override
  String get aiAssistantSummarizeTask => 'Résumer la tâche';

  @override
  String get aiAssistantThinking => 'Réflexion...';

  @override
  String get aiAssistantTitle => 'Assistant IA';

  @override
  String get aiAssistantTranscribeAudio => 'Transcrire l\'audio';

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
      'Échec du chargement des modèles. Veuillez réessayer.';

  @override
  String get loggingFailedToLoad =>
      'Échec du chargement des journaux. Veuillez réessayer.';

  @override
  String get loggingSearchFailed =>
      'Échec de la recherche. Veuillez réessayer.';

  @override
  String get loggingFailedToLoadMore =>
      'Échec du chargement de résultats supplémentaires. Veuillez réessayer.';

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
  String get aiResponseTypeAudioTranscription => 'Audio Transcription';

  @override
  String get aiResponseTypeChecklistUpdates => 'Checklist Updates';

  @override
  String get aiResponseTypeImageAnalysis => 'Image Analysis';

  @override
  String get aiResponseTypePromptGeneration => 'Generated Prompt';

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
  String get aiSettingsClearFiltersButton => 'Effacer';

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
  String get aiTaskSummaryRunning => 'Réflexion sur le résumé de la tâche...';

  @override
  String get aiTaskSummaryTitle => 'Résumé de la tâche IA';

  @override
  String aiTaskSummaryScheduled(String time) {
    return 'Summary in $time';
  }

  @override
  String get aiTaskSummaryCancelScheduled => 'Cancel scheduled summary';

  @override
  String get aiTaskSummaryTriggerNow => 'Generate summary now';

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
  String get cancelButton => 'Annuler';

  @override
  String get categoryDeleteConfirm => 'OUI, SUPPRIMER CETTE CATÉGORIE';

  @override
  String get categoryDeleteQuestion =>
      'Voulez-vous supprimer cette catégorie ?';

  @override
  String get categorySearchPlaceholder => 'Rechercher des catégories...';

  @override
  String get checklistAddItem => 'Ajouter un nouvel élément';

  @override
  String get checklistDelete => 'Supprimer la liste de contrôle ?';

  @override
  String get checklistItemDelete =>
      'Supprimer l\'élément de la liste de contrôle ?';

  @override
  String get checklistItemDeleteCancel => 'Annuler';

  @override
  String get checklistItemDeleteConfirm => 'Confirmer';

  @override
  String get checklistItemDeleteWarning =>
      'Cette action ne peut pas être annulée.';

  @override
  String get checklistItemDrag =>
      'Faites glisser les suggestions dans la liste de contrôle';

  @override
  String get checklistNoSuggestionsTitle => 'Aucune suggestion d\'action';

  @override
  String get checklistSuggestionsOutdated => 'Obsolète';

  @override
  String get checklistSuggestionsRunning =>
      'Réflexion sur les suggestions non suivies...';

  @override
  String get checklistSuggestionsTitle => 'Suggestions d\'actions';

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
  String get checklistsTitle => 'Listes de contrôle';

  @override
  String get checklistsReorder => 'Reorder';

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
  String get colorLabel => 'Couleur :';

  @override
  String get colorPickerError => 'Couleur hexadécimale invalide';

  @override
  String get colorPickerHint => 'Saisir la couleur hexadécimale ou choisir';

  @override
  String get completeHabitFailButton => 'Échec';

  @override
  String get completeHabitSkipButton => 'Ignorer';

  @override
  String get completeHabitSuccessButton => 'Succès';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Lorsque cette option est activée, l\'application tentera de générer des embeddings pour vos entrées afin d\'améliorer la recherche et les suggestions de contenu associées.';

  @override
  String get configFlagAutoTranscribeDescription =>
      'Transcrire automatiquement les enregistrements audio dans vos entrées. Cela nécessite une connexion Internet.';

  @override
  String get configFlagEnableAutoTaskTldrDescription =>
      'Générer automatiquement des résumés pour vos tâches afin de vous aider à comprendre rapidement leur statut.';

  @override
  String get configFlagEnableCalendarPageDescription =>
      'Afficher la page Calendrier dans la navigation principale. Affichez et gérez vos entrées dans une vue calendrier.';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Afficher la page Tableaux de bord dans la navigation principale. Affichez vos données et vos informations dans des tableaux de bord personnalisables.';

  @override
  String get configFlagEnableEventsDescription =>
      'Show the Events feature to create, track, and manage events in your journal.';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Afficher la page Habitudes dans la navigation principale. Suivez et gérez vos habitudes quotidiennes ici.';

  @override
  String get configFlagEnableLoggingDescription =>
      'Activer la journalisation détaillée à des fins de débogage. Cela peut avoir un impact sur les performances.';

  @override
  String get configFlagEnableMatrixDescription =>
      'Activer l\'intégration Matrix pour synchroniser vos entrées sur plusieurs appareils et avec d\'autres utilisateurs Matrix.';

  @override
  String get configFlagEnableNotifications => 'Activer les notifications ?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Recevoir des notifications pour les rappels, les mises à jour et les événements importants.';

  @override
  String get configFlagEnableTooltip => 'Activer les info-bulles';

  @override
  String get configFlagEnableTooltipDescription =>
      'Afficher des info-bulles utiles dans toute l\'application pour vous guider à travers les fonctionnalités.';

  @override
  String get configFlagPrivate => 'Afficher les entrées privées ?';

  @override
  String get configFlagPrivateDescription =>
      'Activez cette option pour rendre vos entrées privées par défaut. Les entrées privées ne sont visibles que par vous.';

  @override
  String get configFlagRecordLocation => 'Enregistrer la localisation';

  @override
  String get configFlagRecordLocationDescription =>
      'Enregistrer automatiquement votre position avec les nouvelles entrées. Cela facilite l\'organisation et la recherche basées sur la localisation.';

  @override
  String get configFlagResendAttachments => 'Renvoyer les pièces jointes';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Activez cette option pour renvoyer automatiquement les téléchargements de pièces jointes ayant échoué lorsque la connexion est rétablie.';

  @override
  String get configFlagEnableAiStreaming =>
      'Activer le streaming IA pour les actions liées aux tâches';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Diffuser les réponses IA pour les actions liées aux tâches. Désactivez pour mettre les réponses en mémoire tampon et conserver une interface plus fluide.';

  @override
  String get configFlagEnableLogging => 'Activer la journalisation';

  @override
  String get configFlagEnableMatrix => 'Activer la synchronisation Matrix';

  @override
  String get configFlagEnableHabitsPage => 'Activer la page Habitudes';

  @override
  String get configFlagEnableDashboardsPage =>
      'Activer la page Tableaux de bord';

  @override
  String get configFlagEnableCalendarPage => 'Activer la page Calendrier';

  @override
  String get configFlagEnableEvents => 'Enable Events';

  @override
  String get configFlagUseCloudInferenceDescription =>
      'Utiliser les services d\'IA basés sur le cloud pour des fonctionnalités améliorées. Cela nécessite une connexion Internet.';

  @override
  String get conflictsResolved => 'résolu';

  @override
  String get conflictsUnresolved => 'non résolu';

  @override
  String get conflictsResolveLocalVersion => 'Resolve with local version';

  @override
  String get conflictsResolveRemoteVersion => 'Resolve with remote version';

  @override
  String get conflictsCopyTextFromSync => 'Copy Text from Sync';

  @override
  String get createCategoryTitle => 'Créer une catégorie :';

  @override
  String get categoryCreationError =>
      'Impossible de créer la catégorie. Veuillez réessayer.';

  @override
  String get createEntryLabel => 'Créer une nouvelle entrée';

  @override
  String get createEntryTitle => 'Ajouter';

  @override
  String get customColor => 'Custom Color';

  @override
  String get dashboardActiveLabel => 'Actif :';

  @override
  String get dashboardAddChartsTitle => 'Ajouter des graphiques :';

  @override
  String get dashboardAddHabitButton => 'Tableaux des habitudes';

  @override
  String get dashboardAddHabitTitle => 'Tableaux des habitudes';

  @override
  String get dashboardAddHealthButton => 'Graphiques de santé';

  @override
  String get dashboardAddHealthTitle => 'Graphiques de santé';

  @override
  String get dashboardAddMeasurementButton => 'Graphiques de mesures';

  @override
  String get dashboardAddMeasurementTitle => 'Graphiques de mesures';

  @override
  String get dashboardAddSurveyButton => 'Graphiques des questionnaires';

  @override
  String get dashboardAddSurveyTitle => 'Graphiques des questionnaires';

  @override
  String get dashboardAddWorkoutButton => 'Graphiques d\'entraînement';

  @override
  String get dashboardAddWorkoutTitle => 'Graphiques d\'entraînement';

  @override
  String get dashboardAggregationLabel => 'Type d\'agrégation :';

  @override
  String get dashboardCategoryLabel => 'Catégorie :';

  @override
  String get dashboardCopyHint =>
      'Enregistrer et copier la configuration du tableau de bord';

  @override
  String get dashboardDeleteConfirm => 'OUI, SUPPRIMER CE TABLEAU DE BORD';

  @override
  String get dashboardDeleteHint => 'Supprimer tableau de bord';

  @override
  String get dashboardDeleteQuestion =>
      'Voulez-vous vraiment supprimer ce tableau de bord ?';

  @override
  String get dashboardDescriptionLabel => 'Description :';

  @override
  String get dashboardNameLabel => 'Nom du tableau de bord :';

  @override
  String get dashboardNotFound => 'Tableau de bord non trouvé';

  @override
  String get dashboardPrivateLabel => 'Privé :';

  @override
  String get done => 'Done';

  @override
  String get doneButton => 'Terminé';

  @override
  String get editMenuTitle => 'Modifier';

  @override
  String get editorPlaceholder => 'Saisir des notes...';

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
  String get eventNameLabel => 'Événement :';

  @override
  String get fileMenuNewEllipsis => 'Nouveau...';

  @override
  String get fileMenuNewEntry => 'Nouvelle entrée';

  @override
  String get fileMenuNewScreenshot => 'Capture d\'écran';

  @override
  String get fileMenuNewTask => 'Tâche';

  @override
  String get fileMenuTitle => 'Fichier';

  @override
  String get habitActiveFromLabel => 'Date de début';

  @override
  String get habitArchivedLabel => 'Archivé :';

  @override
  String get habitCategoryHint => 'Sélectionner une catégorie...';

  @override
  String get habitCategoryLabel => 'Catégorie :';

  @override
  String get habitDashboardHint => 'Sélectionner un tableau de bord...';

  @override
  String get habitDashboardLabel => 'Tableau de bord :';

  @override
  String get habitDeleteConfirm => 'OUI, SUPPRIMER CETTE HABITUDE';

  @override
  String get habitDeleteQuestion => 'Voulez-vous supprimer cette habitude ?';

  @override
  String get habitPriorityLabel => 'Priorité :';

  @override
  String get habitShowAlertAtLabel => 'Afficher l\'alerte à';

  @override
  String get habitShowFromLabel => 'Afficher de';

  @override
  String get habitsCompletedHeader => 'Terminées';

  @override
  String get habitsFilterAll => 'toutes';

  @override
  String get habitsFilterCompleted => 'terminées';

  @override
  String get habitsFilterOpenNow => 'dues';

  @override
  String get habitsFilterPendingLater => 'plus tard';

  @override
  String get habitsOpenHeader => 'Dues maintenant';

  @override
  String get habitsPendingLaterHeader => 'Plus tard dans la journée';

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
  String get journalCopyImageLabel => 'Copier l\'image';

  @override
  String get journalDateFromLabel => 'Date de début :';

  @override
  String get journalDateInvalid => 'Plage de dates invalide';

  @override
  String get journalDateNowButton => 'maintenant';

  @override
  String get journalDateSaveButton => 'ENREGISTRER';

  @override
  String get journalDateToLabel => 'Date de fin :';

  @override
  String get journalDeleteConfirm => 'OUI, SUPPRIMER CETTE ENTRÉE';

  @override
  String get journalDeleteHint => 'Supprimer l\'entrée';

  @override
  String get journalDeleteQuestion =>
      'Voulez-vous vraiment supprimer cette entrée ?';

  @override
  String get journalDurationLabel => 'Durée :';

  @override
  String get journalFavoriteTooltip => 'Préféré';

  @override
  String get journalFlaggedTooltip => 'Suivi';

  @override
  String get journalHideMapHint => 'Masquer la carte';

  @override
  String get journalLinkFromHint => 'Lié depuis';

  @override
  String get journalLinkToHint => 'Lié à';

  @override
  String get journalLinkedEntriesAiLabel =>
      'Afficher les entrées générées par l\'IA :';

  @override
  String get journalLinkedEntriesHiddenLabel =>
      'Afficher les entrées masquées :';

  @override
  String get journalLinkedEntriesLabel => 'Lié :';

  @override
  String get journalLinkedFromLabel => 'Lié depuis :';

  @override
  String get journalPrivateTooltip => 'Privé';

  @override
  String get journalSearchHint => 'Rechercher journal...';

  @override
  String get journalShareAudioHint => 'Partager audio';

  @override
  String get journalSharePhotoHint => 'Partager photo';

  @override
  String get journalShowMapHint => 'Afficher la carte';

  @override
  String get journalTagPlusHint => 'Gérer les étiquettes des entrées';

  @override
  String get journalTagsCopyHint => 'Copier les étiquettes';

  @override
  String get journalTagsLabel => 'Étiquettes :';

  @override
  String get journalTagsPasteHint => 'Coller les étiquettes';

  @override
  String get journalTagsRemoveHint => 'Supprimer une étiquette';

  @override
  String get journalToggleFlaggedTitle => 'Signalé';

  @override
  String get journalTogglePrivateTitle => 'Privé';

  @override
  String get journalToggleStarredTitle => 'Favori';

  @override
  String get journalUnlinkConfirm => 'OUI, DISSOCIER L\'ENTRÉE';

  @override
  String get journalUnlinkHint => 'Dissocier';

  @override
  String get journalUnlinkQuestion =>
      'Êtes-vous sûr de vouloir dissocier cette entrée ?';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'YES, DELETE DATABASE';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Are you sure you want to delete $databaseName Database?';
  }

  @override
  String get maintenanceDeleteEditorDb =>
      'Supprimer la base de données des brouillons';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Delete editor drafts database';

  @override
  String get maintenanceDeleteLoggingDb =>
      'Supprimer la base de données de journalisation';

  @override
  String get maintenanceDeleteLoggingDbDescription => 'Delete logging database';

  @override
  String get maintenanceDeleteSyncDb =>
      'Supprimer la base de données de synchronisation';

  @override
  String get maintenanceDeleteSyncDbDescription => 'Delete sync database';

  @override
  String get maintenancePurgeDeleted => 'Purger les éléments supprimés';

  @override
  String get maintenancePurgeDeletedConfirm => 'Purger';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Purge all deleted items permanently';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Are you sure you want to purge all deleted items? This action cannot be undone.';

  @override
  String get maintenanceReSync => 'Resynchroniser les messages';

  @override
  String get maintenanceReSyncDescription => 'Re-sync messages from server';

  @override
  String get maintenanceRecreateFts5 => 'Recréer l\'index de texte intégral';

  @override
  String get maintenanceRecreateFts5Confirm => 'YES, RECREATE INDEX';

  @override
  String get maintenanceRecreateFts5Description =>
      'Recreate full-text search index';

  @override
  String get maintenanceRecreateFts5Message =>
      'Are you sure you want to recreate the full-text index? This may take some time.';

  @override
  String get maintenancePopulateSequenceLog => 'Populate sync sequence log';

  @override
  String get maintenancePopulateSequenceLogConfirm => 'YES, POPULATE';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Index existing entries for backfill support';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'This will scan all journal entries and add them to the sync sequence log. This enables backfill responses for entries created before this feature was added.';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count entries indexed';
  }

  @override
  String get maintenanceSyncDefinitions =>
      'Sync tags, measurables, dashboards, habits, categories, AI settings';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sync tags, measurables, dashboards, habits, categories, and AI settings';

  @override
  String get backfillSettingsTitle => 'Backfill Sync';

  @override
  String get backfillSettingsSubtitle => 'Manage sync gap recovery';

  @override
  String get backfillSettingsInfo =>
      'Automatic backfill requests missing entries from the last 24 hours. Use manual backfill for older entries.';

  @override
  String get backfillToggleTitle => 'Automatic Backfill';

  @override
  String get backfillToggleEnabledDescription =>
      'Automatically request missing sync entries';

  @override
  String get backfillToggleDisabledDescription =>
      'Backfill disabled - useful on metered networks';

  @override
  String get backfillStatsTitle => 'Sync Statistics';

  @override
  String get backfillStatsRefresh => 'Refresh stats';

  @override
  String get backfillStatsNoData => 'No sync data available';

  @override
  String get backfillStatsTotalEntries => 'Total entries';

  @override
  String get backfillStatsReceived => 'Received';

  @override
  String get backfillStatsMissing => 'Missing';

  @override
  String get backfillStatsRequested => 'Requested';

  @override
  String get backfillStatsBackfilled => 'Backfilled';

  @override
  String get backfillStatsDeleted => 'Deleted';

  @override
  String get backfillStatsUnresolvable => 'Unresolvable';

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
  String get backfillManualTitle => 'Manual Backfill';

  @override
  String get backfillManualDescription =>
      'Request all missing entries regardless of age. Use this to recover older sync gaps.';

  @override
  String get backfillManualTrigger => 'Request Missing Entries';

  @override
  String get backfillManualProcessing => 'Processing...';

  @override
  String backfillManualSuccess(int count) {
    return '$count entries requested';
  }

  @override
  String get backfillReRequestTitle => 'Re-Request Pending';

  @override
  String get backfillReRequestDescription =>
      'Re-request entries that were requested but never received. Use this when responses are stuck.';

  @override
  String get backfillReRequestTrigger => 'Re-Request Pending Entries';

  @override
  String get backfillReRequestProcessing => 'Re-requesting...';

  @override
  String backfillReRequestSuccess(int count) {
    return '$count entries re-requested';
  }

  @override
  String get measurableDeleteConfirm => 'OUI, SUPPRIMER CET ÉLÉMENT MESURABLE';

  @override
  String get measurableDeleteQuestion =>
      'Voulez-vous supprimer ce type de données mesurables ?';

  @override
  String get measurableNotFound => 'Élément mesurable introuvable';

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
  String get navTabTitleCalendar => 'Calendrier';

  @override
  String get navTabTitleHabits => 'Habitudes';

  @override
  String get navTabTitleInsights => 'Tableaux de bord';

  @override
  String get navTabTitleJournal => 'Journal';

  @override
  String get navTabTitleSettings => 'Paramètres';

  @override
  String get navTabTitleTasks => 'Tâches';

  @override
  String get outboxMonitorLabelAll => 'tout';

  @override
  String get outboxMonitorLabelError => 'erreur';

  @override
  String get outboxMonitorLabelPending => 'en attente';

  @override
  String get outboxMonitorLabelSent => 'envoyé';

  @override
  String get outboxMonitorLabelSuccess => 'success';

  @override
  String get outboxMonitorNoAttachment => 'pas de pièce jointe';

  @override
  String get outboxMonitorRetriesLabel => 'Retries';

  @override
  String get outboxMonitorRetries => 'retries';

  @override
  String get outboxMonitorRetry => 'réessayer';

  @override
  String get outboxMonitorSubjectLabel => 'Subject';

  @override
  String get outboxMonitorAttachmentLabel => 'Attachment';

  @override
  String get outboxMonitorRetryConfirmMessage => 'Retry this sync item now?';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Retry Now';

  @override
  String get outboxMonitorRetryQueued => 'Retry scheduled';

  @override
  String get outboxMonitorRetryFailed => 'Retry failed. Please try again.';

  @override
  String get outboxMonitorDelete => 'delete';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      'Are you sure you want to delete this sync item? This action cannot be undone.';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Delete';

  @override
  String get outboxMonitorDeleteSuccess => 'Item deleted';

  @override
  String get outboxMonitorDeleteFailed => 'Delete failed. Please try again.';

  @override
  String get outboxMonitorEmptyTitle => 'Outbox is clear';

  @override
  String get outboxMonitorEmptyDescription =>
      'There are no sync items in this view.';

  @override
  String get outboxMonitorSwitchLabel => 'activé';

  @override
  String get syncListPayloadKindLabel => 'Payload';

  @override
  String get syncListUnknownPayload => 'Unknown payload';

  @override
  String get syncPayloadJournalEntity => 'Journal entry';

  @override
  String get syncPayloadEntityDefinition => 'Entity definition';

  @override
  String get syncPayloadTagEntity => 'Tag entity';

  @override
  String get syncPayloadEntryLink => 'Entry link';

  @override
  String get syncPayloadAiConfig => 'AI configuration';

  @override
  String get syncPayloadAiConfigDelete => 'AI configuration delete';

  @override
  String get syncPayloadThemingSelection => 'Theming selection';

  @override
  String get syncPayloadBackfillRequest => 'Backfill request';

  @override
  String get syncPayloadBackfillResponse => 'Backfill response';

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
  String get conflictsEmptyTitle => 'No conflicts detected';

  @override
  String get conflictsEmptyDescription =>
      'Everything is in sync right now. Resolved items stay available in the other filter.';

  @override
  String get conflictEntityLabel => 'Entity';

  @override
  String get conflictIdLabel => 'ID';

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
  String get promptGenerationCardTitle => 'AI Coding Prompt';

  @override
  String get promptGenerationCopyTooltip => 'Copy prompt to clipboard';

  @override
  String get promptGenerationCopyButton => 'Copy Prompt';

  @override
  String get promptGenerationCopiedSnackbar => 'Prompt copied to clipboard';

  @override
  String get promptGenerationExpandTooltip => 'Show full prompt';

  @override
  String get promptGenerationFullPromptLabel => 'Full Prompt:';

  @override
  String get aiResponseTypeImagePromptGeneration => 'Prompt Image';

  @override
  String get imagePromptGenerationCardTitle => 'Prompt Image IA';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Copier le prompt d\'image dans le presse-papiers';

  @override
  String get imagePromptGenerationCopyButton => 'Copier Prompt';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Prompt d\'image copié dans le presse-papiers';

  @override
  String get imagePromptGenerationExpandTooltip => 'Afficher le prompt complet';

  @override
  String get imagePromptGenerationFullPromptLabel => 'Prompt Image Complet:';

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
  String get aiResponseDeleteTitle => 'Delete AI Response';

  @override
  String get aiResponseDeleteWarning =>
      'Are you sure you want to delete this AI response? This cannot be undone.';

  @override
  String get aiResponseDeleteCancel => 'Cancel';

  @override
  String get aiResponseDeleteConfirm => 'Delete';

  @override
  String get aiResponseDeleteError =>
      'Failed to delete AI response. Please try again.';

  @override
  String get saveButtonLabel => 'Save';

  @override
  String get saveLabel => 'Enregistrer';

  @override
  String get searchHint => 'Rechercher...';

  @override
  String get settingThemingDark => 'Thème sombre';

  @override
  String get settingThemingLight => 'Thème clair';

  @override
  String get settingsAboutTitle => 'À propos de Lotti';

  @override
  String get settingsAboutAppTagline => 'Votre journal personnel';

  @override
  String get settingsAboutAppInformation => 'Informations sur l\'application';

  @override
  String get settingsAboutYourData => 'Vos données';

  @override
  String get settingsAboutCredits => 'Crédits';

  @override
  String get settingsAboutBuiltWithFlutter =>
      'Développé avec Flutter et amour pour le journaling personnel.';

  @override
  String get settingsAboutThankYou => 'Merci d\'utiliser Lotti !';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutPlatform => 'Plateforme';

  @override
  String get settingsAboutBuildType => 'Type de build';

  @override
  String get settingsAboutJournalEntries => 'Entrées de journal';

  @override
  String get settingsAdvancedTitle => 'Paramètres avancés';

  @override
  String get settingsAdvancedMatrixSyncSubtitle =>
      'Configurer et gérer les paramètres de synchronisation Matrix';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Afficher et gérer les éléments en attente de synchronisation';

  @override
  String get settingsAdvancedConflictsSubtitle =>
      'Résoudre les conflits de synchronisation pour assurer la cohérence des données';

  @override
  String get settingsAdvancedLogsSubtitle =>
      'Accéder et examiner les journaux d\'application pour le débogage';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Importer des données liées à la santé depuis des sources externes';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Effectuer des tâches de maintenance pour optimiser les performances de l\'application';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'En savoir plus sur l\'application Lotti';

  @override
  String get settingsAiApiKeys => 'AI Inference Providers';

  @override
  String get settingsAiModels => 'AI Models';

  @override
  String get settingsCategoriesDetailsLabel => 'Category Details';

  @override
  String get settingsCategoriesDuplicateError => 'La catégorie existe déjà';

  @override
  String get settingsCategoriesNameLabel => 'Nom de la catégorie :';

  @override
  String get settingsCategoriesTitle => 'Catégories';

  @override
  String get settingsLabelsTitle => 'Labels';

  @override
  String get settingsLabelsSubtitle => 'Organize tasks with colored labels';

  @override
  String get settingsCategoriesAddTooltip => 'Add Category';

  @override
  String get settingsLabelsSearchHint => 'Search labels…';

  @override
  String get settingsLabelsEmptyState => 'No labels yet';

  @override
  String get settingsLabelsEmptyStateHint =>
      'Tap the + button to create your first label.';

  @override
  String get settingsLabelsErrorLoading => 'Failed to load labels';

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
  String get settingsLabelsCreateTitle => 'Create label';

  @override
  String get settingsLabelsEditTitle => 'Edit label';

  @override
  String get settingsLabelsNameLabel => 'Label name';

  @override
  String get settingsLabelsNameHint => 'Bug, Release blocker, Sync…';

  @override
  String get settingsLabelsNameRequired => 'Label name must not be empty.';

  @override
  String get settingsLabelsDescriptionLabel => 'Description (optional)';

  @override
  String get settingsLabelsDescriptionHint =>
      'Explain when to apply this label';

  @override
  String get settingsLabelsColorHeading => 'Select a color';

  @override
  String get settingsLabelsColorSubheading => 'Quick presets';

  @override
  String get settingsLabelsCategoriesHeading => 'Applicable categories';

  @override
  String get settingsLabelsCategoriesAdd => 'Add category';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Remove';

  @override
  String get settingsLabelsCategoriesNone => 'Applies to all categories';

  @override
  String get settingsLabelsPrivateTitle => 'Private label';

  @override
  String get settingsLabelsPrivateDescription =>
      'Private labels only appear when “Show private entries” is enabled.';

  @override
  String get settingsLabelsCreateSuccess => 'Label created successfully';

  @override
  String get settingsLabelsUpdateSuccess => 'Label updated';

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Delete label';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return 'Are you sure you want to delete \"$labelName\"? Tasks with this label will lose the assignment.';
  }

  @override
  String settingsLabelsDeleteSuccess(Object labelName) {
    return 'Label \"$labelName\" deleted';
  }

  @override
  String get settingsLabelsDeleteCancel => 'Cancel';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Delete';

  @override
  String get settingsLabelsActionsTooltip => 'Label actions';

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
  String get entryTypeLabelTask => 'Task';

  @override
  String get entryTypeLabelJournalEntry => 'Text';

  @override
  String get entryTypeLabelJournalEvent => 'Event';

  @override
  String get entryTypeLabelJournalAudio => 'Audio';

  @override
  String get entryTypeLabelJournalImage => 'Photo';

  @override
  String get entryTypeLabelMeasurementEntry => 'Measured';

  @override
  String get entryTypeLabelSurveyEntry => 'Survey';

  @override
  String get entryTypeLabelWorkoutEntry => 'Workout';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Habit';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Health';

  @override
  String get entryTypeLabelChecklist => 'Checklist';

  @override
  String get entryTypeLabelChecklistItem => 'To Do';

  @override
  String get entryTypeLabelAiResponse => 'AI Response';

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
  String get speechDictionaryLabel => 'Speech Dictionary';

  @override
  String get speechDictionaryHint => 'macOS; Kirkjubæjarklaustur; Claude Code';

  @override
  String get speechDictionaryHelper =>
      'Semicolon-separated terms (max 50 chars) for better speech recognition';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Large dictionary ($count terms) may increase API costs';
  }

  @override
  String get speechDictionarySectionTitle => 'Speech Recognition';

  @override
  String get speechDictionarySectionDescription =>
      'Add terms that are often misspelled by speech recognition (names, places, technical terms)';

  @override
  String get addToDictionary => 'Add to Dictionary';

  @override
  String get addToDictionarySuccess => 'Term added to dictionary';

  @override
  String get addToDictionaryNoCategory =>
      'Cannot add to dictionary: task has no category';

  @override
  String get addToDictionaryDuplicate => 'Term already exists in dictionary';

  @override
  String get addToDictionaryTooLong => 'Term too long (max 50 characters)';

  @override
  String get addToDictionarySaveFailed => 'Failed to save dictionary';

  @override
  String get deleteButton => 'Delete';

  @override
  String get saveButton => 'Save';

  @override
  String get createButton => 'Create';

  @override
  String get settingsConflictsResolutionTitle =>
      'Résolution des conflits de synchronisation';

  @override
  String get settingsConflictsTitle => 'Conflits de synchronisation';

  @override
  String get settingsDashboardDetailsLabel => 'Dashboard Details';

  @override
  String get settingsDashboardSaveLabel => 'Save';

  @override
  String get settingsDashboardsTitle => 'Gestion du tableau de bord';

  @override
  String get settingsFlagsTitle => 'Flags';

  @override
  String get settingsHabitsDeleteTooltip => 'Supprimer l\'habitude';

  @override
  String get settingsHabitsDescriptionLabel => 'Description (facultatif) :';

  @override
  String get settingsHabitsDetailsLabel => 'Habit Details';

  @override
  String get settingsHabitsNameLabel => 'Nom de l\'habitude :';

  @override
  String get settingsHabitsPrivateLabel => 'Privé : ';

  @override
  String get settingsHabitsSaveLabel => 'Enregistrer';

  @override
  String get settingsHabitsTitle => 'Habitudes';

  @override
  String get settingsHealthImportFromDate => 'Début';

  @override
  String get settingsHealthImportTitle => 'Health Import';

  @override
  String get settingsHealthImportToDate => 'Fin';

  @override
  String get settingsLogsTitle => 'Logs';

  @override
  String get settingsMaintenanceTitle => 'Maintenance';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'L\'autre appareil affiche des emojis, continuer';

  @override
  String get settingsMatrixCancel => 'Annuler';

  @override
  String get settingsMatrixCancelVerificationLabel => 'Annuler la vérification';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Accepter sur l\'autre appareil pour continuer';

  @override
  String get settingsMatrixDeleteLabel => 'Supprimer';

  @override
  String get settingsMatrixDone => 'Terminé';

  @override
  String get settingsMatrixEnterValidUrl => 'Veuillez saisir une URL valide';

  @override
  String get settingsMatrixHomeServerLabel => 'Serveur principal';

  @override
  String get settingsMatrixHomeserverConfigTitle =>
      'Configuration du serveur principal Matrix';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Appareils non vérifiés';

  @override
  String get settingsMatrixLoginButtonLabel => 'Connexion';

  @override
  String get settingsMatrixLoginFailed => 'Échec de la connexion';

  @override
  String get settingsMatrixLogoutButtonLabel => 'Déconnexion';

  @override
  String get settingsMatrixNextPage => 'Page suivante';

  @override
  String get settingsMatrixNoUnverifiedLabel => 'Aucun appareil non vérifié';

  @override
  String get settingsMatrixPasswordLabel => 'Mot de passe';

  @override
  String get settingsMatrixPasswordTooShort => 'Mot de passe trop court';

  @override
  String get settingsMatrixPreviousPage => 'Page précédente';

  @override
  String get settingsMatrixQrTextPage =>
      'Scannez ce code QR pour inviter l\'appareil dans une salle de synchronisation.';

  @override
  String get settingsMatrixRoomInviteTitle => 'Room invite';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Invite to room $roomId from $senderId. Accept?';
  }

  @override
  String get settingsMatrixAccept => 'Accept';

  @override
  String get settingsMatrixRoomConfigTitle =>
      'Configuration de la salle de synchronisation Matrix';

  @override
  String get settingsMatrixStartVerificationLabel => 'Démarrer la vérification';

  @override
  String get settingsMatrixStatsTitle => 'Statistiques Matrix';

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
  String get settingsMatrixMetrics => 'Sync Metrics';

  @override
  String get settingsMatrixMetricsNoData => 'Sync Metrics: no data';

  @override
  String get settingsMatrixLastUpdated => 'Last updated:';

  @override
  String get settingsMatrixRefresh => 'Refresh';

  @override
  String get settingsMatrixTitle => 'Paramètres de synchronisation Matrix';

  @override
  String get settingsMatrixMaintenanceTitle => 'Maintenance';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Run Matrix maintenance tasks and recovery tools';

  @override
  String get settingsMatrixSubtitle => 'Configure end-to-end encrypted sync';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Appareils non vérifiés';

  @override
  String get settingsMatrixUserLabel => 'Utilisateur';

  @override
  String get settingsMatrixUserNameTooShort => 'Nom d\'utilisateur trop court';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Annulé sur un autre appareil…';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'OK';

  @override
  String settingsMatrixVerificationSuccessLabel(
      String deviceName, String deviceID) {
    return 'Vous avez vérifié avec succès $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Confirmez sur l\'autre appareil que les émojis ci-dessous sont affichés sur les deux appareils, dans le même ordre :';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Confirmez que les émojis ci-dessous sont affichés sur les deux appareils, dans le même ordre :';

  @override
  String get settingsMatrixVerifyLabel => 'Vérifier';

  @override
  String get settingsMeasurableAggregationLabel =>
      'Type d\'agrégation par défaut :';

  @override
  String get settingsMeasurableDeleteTooltip => 'Supprimer type mesurable';

  @override
  String get settingsMeasurableDescriptionLabel => 'Description :';

  @override
  String get settingsMeasurableDetailsLabel => 'Measurable Details';

  @override
  String get settingsMeasurableFavoriteLabel => 'Préféré :';

  @override
  String get settingsMeasurableNameLabel => 'Nom de la mesure :';

  @override
  String get settingsMeasurablePrivateLabel => 'Privé :';

  @override
  String get settingsMeasurableSaveLabel => 'Enregistrer';

  @override
  String get settingsMeasurableUnitLabel => 'Abréviation d\'unité :';

  @override
  String get settingsMeasurablesTitle => 'Types de données mesurables';

  @override
  String get settingsSpeechAudioWithoutTranscript =>
      'Entrées audio sans transcription :';

  @override
  String get settingsSpeechAudioWithoutTranscriptButton =>
      'Trouver et transcrire';

  @override
  String get settingsSpeechLastActivity =>
      'Dernière activité de transcription :';

  @override
  String get settingsSpeechModelSelectionTitle =>
      'Modèle de reconnaissance vocale Whisper :';

  @override
  String get settingsSyncOutboxTitle => 'Sync Outbox';

  @override
  String get syncNotLoggedInToast => 'Sync is not logged in';

  @override
  String get settingsSyncSubtitle => 'Configure sync and view stats';

  @override
  String get settingsSyncStatsSubtitle => 'Inspect sync pipeline metrics';

  @override
  String get matrixStatsError => 'Error loading Matrix stats';

  @override
  String get settingsTagsDeleteTooltip => 'Supprimer étiquette';

  @override
  String get settingsTagsDetailsLabel => 'Tags Details';

  @override
  String get settingsTagsHideLabel => 'Masquer des suggestions :';

  @override
  String get settingsTagsPrivateLabel => 'Privé :';

  @override
  String get settingsTagsSaveLabel => 'Enregistrer étiquette';

  @override
  String get settingsTagsTagName => 'Étiquette :';

  @override
  String get settingsTagsTitle => 'Étiquettes';

  @override
  String get settingsTagsTypeLabel => 'Type d\'étiquette :';

  @override
  String get settingsTagsTypePerson => 'PERSONNE';

  @override
  String get settingsTagsTypeStory => 'STORY';

  @override
  String get settingsTagsTypeTag => 'ÉTIQUETTE';

  @override
  String get settingsThemingAutomatic => 'Automatique';

  @override
  String get settingsThemingDark => 'Apparence sombre';

  @override
  String get settingsThemingLight => 'Apparence claire';

  @override
  String get settingsThemingTitle => 'Thème';

  @override
  String get speechModalAddTranscription => 'Ajouter une transcription';

  @override
  String get speechModalSelectLanguage => 'Sélectionner la langue';

  @override
  String get speechModalTitle => 'Reconnaissance vocale';

  @override
  String get speechModalTranscriptionProgress =>
      'Progression de la transcription';

  @override
  String get syncDeleteConfigConfirm => 'OUI, JE SUIS SÛR';

  @override
  String get syncDeleteConfigQuestion =>
      'Voulez-vous supprimer la configuration de synchronisation ?';

  @override
  String get syncEntitiesConfirm => 'START SYNC';

  @override
  String get syncEntitiesMessage => 'Choisissez les données à synchroniser.';

  @override
  String get syncEntitiesSuccessDescription => 'Tout est à jour.';

  @override
  String get syncEntitiesSuccessTitle => 'Synchronisation terminée';

  @override
  String get syncStepAiSettings => 'Paramètres IA';

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
  String get syncStepLabels => 'Labels';

  @override
  String get syncStepTags => 'Tags';

  @override
  String get taskCategoryAllLabel => 'tout';

  @override
  String get taskCategoryLabel => 'Catégorie :';

  @override
  String get taskCategoryUnassignedLabel => 'non attribué';

  @override
  String get taskEstimateLabel => 'Temps estimé :';

  @override
  String get taskNoEstimateLabel => 'Sans estimation';

  @override
  String get taskNameHint => 'Saisissez un nom pour la tâche';

  @override
  String get taskStatusAll => 'Tout';

  @override
  String get taskStatusBlocked => 'BLOQUÉE';

  @override
  String get taskStatusDone => 'TERMINÉE';

  @override
  String get taskStatusGroomed => 'AFFINÉE';

  @override
  String get taskStatusInProgress => 'EN COURS';

  @override
  String get taskStatusLabel => 'État de la tâche :';

  @override
  String get taskStatusOnHold => 'EN ATTENTE';

  @override
  String get taskStatusOpen => 'OUVERTE';

  @override
  String get taskStatusRejected => 'REJETÉE';

  @override
  String get taskLanguageLabel => 'Langue :';

  @override
  String get taskLanguageArabic => 'Arabe';

  @override
  String get taskLanguageBengali => 'Bengali';

  @override
  String get taskLanguageBulgarian => 'Bulgare';

  @override
  String get taskLanguageChinese => 'Chinois';

  @override
  String get taskLanguageCroatian => 'Croate';

  @override
  String get taskLanguageCzech => 'Tchèque';

  @override
  String get taskLanguageDanish => 'Danois';

  @override
  String get taskLanguageDutch => 'Néerlandais';

  @override
  String get taskLanguageEnglish => 'Anglais';

  @override
  String get taskLanguageEstonian => 'Estonien';

  @override
  String get taskLanguageFinnish => 'Finnois';

  @override
  String get taskLanguageFrench => 'Français';

  @override
  String get taskLanguageGerman => 'Allemand';

  @override
  String get taskLanguageGreek => 'Grec';

  @override
  String get taskLanguageHebrew => 'Hébreu';

  @override
  String get taskLanguageHindi => 'Hindi';

  @override
  String get taskLanguageHungarian => 'Hongrois';

  @override
  String get taskLanguageIndonesian => 'Indonésien';

  @override
  String get taskLanguageItalian => 'Italien';

  @override
  String get taskLanguageJapanese => 'Japonais';

  @override
  String get taskLanguageKorean => 'Coréen';

  @override
  String get taskLanguageLatvian => 'Letton';

  @override
  String get taskLanguageLithuanian => 'Lituanien';

  @override
  String get taskLanguageNorwegian => 'Norvégien';

  @override
  String get taskLanguagePolish => 'Polonais';

  @override
  String get taskLanguagePortuguese => 'Portugais';

  @override
  String get taskLanguageRomanian => 'Roumain';

  @override
  String get taskLanguageRussian => 'Russe';

  @override
  String get taskLanguageSerbian => 'Serbe';

  @override
  String get taskLanguageSlovak => 'Slovaque';

  @override
  String get taskLanguageSlovenian => 'Slovène';

  @override
  String get taskLanguageSpanish => 'Espagnol';

  @override
  String get taskLanguageSwahili => 'Swahili';

  @override
  String get taskLanguageSwedish => 'Suédois';

  @override
  String get taskLanguageThai => 'Thaï';

  @override
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageTurkish => 'Turc';

  @override
  String get taskLanguageUkrainian => 'Ukrainien';

  @override
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageNigerianPidgin => 'Pidgin nigérian';

  @override
  String get taskLanguageYoruba => 'Yoruba';

  @override
  String get taskLanguageSearchPlaceholder => 'Rechercher des langues...';

  @override
  String get taskLanguageSelectedLabel => 'Langue actuelle';

  @override
  String get taskLanguageVietnamese => 'Vietnamien';

  @override
  String get tasksFilterTitle => 'Filtre des tâches';

  @override
  String get timeByCategoryChartTitle => 'Temps par catégorie';

  @override
  String get timeByCategoryChartTotalLabel => 'Total';

  @override
  String get viewMenuTitle => 'Affichage';

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

  @override
  String get editorInsertDivider => 'Insert divider';

  @override
  String get tasksLabelsHeaderTitle => 'Labels';

  @override
  String get tasksLabelsHeaderEditTooltip => 'Edit labels';

  @override
  String get tasksLabelsNoLabels => 'No labels';

  @override
  String get tasksLabelsDialogClose => 'Close';

  @override
  String get tasksLabelsSheetTitle => 'Select labels';

  @override
  String get tasksLabelsSheetSearchHint => 'Search labels…';

  @override
  String get tasksLabelsSheetApply => 'Apply';

  @override
  String get tasksLabelsUpdateFailed => 'Failed to update labels';

  @override
  String get tasksLabelFilterTitle => 'Labels';

  @override
  String get tasksLabelFilterUnlabeled => 'Unlabeled';

  @override
  String get tasksLabelFilterAll => 'All';

  @override
  String get tasksQuickFilterLabelsActiveTitle => 'Active label filters';

  @override
  String get tasksQuickFilterClear => 'Clear';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Unassigned';

  @override
  String get taskLabelUnassignedLabel => 'unassigned';

  @override
  String get entryLabelsHeaderTitle => 'Étiquettes';

  @override
  String get entryLabelsEditTooltip => 'Modifier les étiquettes';

  @override
  String get entryLabelsNoLabels => 'Aucune étiquette assignée';

  @override
  String get entryLabelsActionTitle => 'Étiquettes';

  @override
  String get entryLabelsActionSubtitle =>
      'Assigner des étiquettes pour organiser cette entrée';

  @override
  String get tasksPriorityTitle => 'Priority:';

  @override
  String get tasksPriorityP0 => 'Urgent';

  @override
  String get tasksPriorityP1 => 'High';

  @override
  String get tasksPriorityP2 => 'Medium';

  @override
  String get tasksPriorityP3 => 'Low';

  @override
  String get tasksPriorityPickerTitle => 'Select priority';

  @override
  String get tasksPriorityFilterTitle => 'Priority';

  @override
  String get tasksPriorityFilterAll => 'All';

  @override
  String get tasksPriorityP0Description => 'Urgent (ASAP)';

  @override
  String get tasksPriorityP1Description => 'High (Soon)';

  @override
  String get tasksPriorityP2Description => 'Medium (Default)';

  @override
  String get tasksPriorityP3Description => 'Low (Whenever)';

  @override
  String get checklistFilterShowAll => 'Show all items';

  @override
  String get checklistFilterShowOpen => 'Show open items';

  @override
  String get checklistFilterStateOpenOnly => 'Showing open items';

  @override
  String get checklistFilterStateAll => 'Showing all items';

  @override
  String checklistFilterToggleSemantics(String state) {
    return 'Toggle checklist filter (current: $state)';
  }

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total done';
  }

  @override
  String get checklistAllDone => 'All items completed!';

  @override
  String get correctionExamplesSectionTitle =>
      'Exemples de Correction de Liste';

  @override
  String get correctionExamplesSectionDescription =>
      'Lorsque vous corrigez manuellement des éléments de liste, ces corrections sont enregistrées ici et utilisées pour améliorer les suggestions de l\'IA.';

  @override
  String get correctionExamplesEmpty =>
      'Aucune correction capturée pour l\'instant. Modifiez un élément de liste pour ajouter votre premier exemple.';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'Vous avez $count corrections. Seules les $max plus récentes seront utilisées dans les prompts IA. Pensez à supprimer les exemples anciens ou redondants.';
  }

  @override
  String get correctionExampleCaptured =>
      'Correction enregistrée pour l\'apprentissage IA';

  @override
  String correctionExamplePending(int seconds) {
    return 'Enregistrement de la correction dans ${seconds}s...';
  }

  @override
  String get correctionExampleCancel => 'ANNULER';

  @override
  String get syncRoomDiscoveryTitle =>
      'Rechercher une salle de synchronisation existante';

  @override
  String get syncDiscoverRoomsButton => 'Découvrir les salles existantes';

  @override
  String get syncDiscoveringRooms =>
      'Recherche des salles de synchronisation...';

  @override
  String get syncNoRoomsFound =>
      'Aucune salle de synchronisation trouvée.\nVous pouvez créer une nouvelle salle pour commencer la synchronisation.';

  @override
  String get syncCreateNewRoom => 'Créer une nouvelle salle';

  @override
  String get syncSelectRoom => 'Sélectionner une salle de synchronisation';

  @override
  String get syncSelectRoomDescription =>
      'Nous avons trouvé des salles de synchronisation existantes. Sélectionnez-en une pour la rejoindre ou créez une nouvelle salle.';

  @override
  String get syncCreateNewRoomInstead => 'Créer une nouvelle salle à la place';

  @override
  String get syncDiscoveryError => 'Échec de la découverte des salles';

  @override
  String get syncRetry => 'Réessayer';

  @override
  String get syncSkip => 'Ignorer';

  @override
  String get syncRoomUnnamed => 'Salle sans nom';

  @override
  String get syncRoomCreatedUnknown => 'Inconnu';

  @override
  String get syncRoomVerified => 'Vérifié';

  @override
  String get syncRoomHasContent => 'Contient des données';

  @override
  String get syncInviteErrorNetwork =>
      'Erreur réseau. Veuillez vérifier votre connexion et réessayer.';

  @override
  String get syncInviteErrorUserNotFound =>
      'Utilisateur non trouvé. Veuillez vérifier que le code scanné est correct.';

  @override
  String get syncInviteErrorForbidden =>
      'Permission refusée. Vous n\'avez peut-être pas accès pour inviter cet utilisateur.';

  @override
  String get syncInviteErrorRateLimited =>
      'Trop de requêtes. Veuillez patienter un moment et réessayer.';

  @override
  String get syncInviteErrorUnknown =>
      'Échec de l\'envoi de l\'invitation. Veuillez réessayer plus tard.';
}

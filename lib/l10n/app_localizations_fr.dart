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
  String get aiTaskSummaryRunning => 'Réflexion sur le résumé de la tâche...';

  @override
  String get aiTaskSummaryTitle => 'Résumé de la tâche IA';

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
  String get checklistsTitle => 'Listes de contrôle';

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
  String get configFlagUseCloudInferenceDescription =>
      'Utiliser les services d\'IA basés sur le cloud pour des fonctionnalités améliorées. Cela nécessite une connexion Internet.';

  @override
  String get conflictsResolved => 'résolu';

  @override
  String get conflictsUnresolved => 'non résolu';

  @override
  String get createCategoryTitle => 'Créer une catégorie :';

  @override
  String get createEntryLabel => 'Créer une nouvelle entrée';

  @override
  String get createEntryTitle => 'Ajouter';

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
  String get maintenanceSyncDefinitions =>
      'Sync tags, measurables, dashboards, habits, categories';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sync tags, measurables, dashboards, habits, categories';

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
  String get outboxMonitorNoAttachment => 'pas de pièce jointe';

  @override
  String get outboxMonitorRetries => 'retries';

  @override
  String get outboxMonitorRetry => 'réessayer';

  @override
  String get outboxMonitorSwitchLabel => 'activé';

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
  String get settingsMatrixRoomConfigTitle =>
      'Configuration de la salle de synchronisation Matrix';

  @override
  String get settingsMatrixStartVerificationLabel => 'Démarrer la vérification';

  @override
  String get settingsMatrixStatsTitle => 'Statistiques Matrix';

  @override
  String get settingsMatrixTitle => 'Paramètres de synchronisation Matrix';

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
  String get taskCategoryAllLabel => 'tout';

  @override
  String get taskCategoryLabel => 'Catégorie :';

  @override
  String get taskCategoryUnassignedLabel => 'non attribué';

  @override
  String get taskEstimateLabel => 'Temps estimé :';

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
  String get taskLanguageLabel => 'Language';

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
  String get taskLanguageVietnamese => 'Vietnamese';

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
}

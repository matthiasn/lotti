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
  String get addActionAddTimeRecording => 'Commencer l\'enregistrement du temps';

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
  String get aiConfigFailedToSaveMessage => 'Failed to save configuration. Please try again.';

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
  String get aiConfigListEmptyState => 'No configurations found. Add one to get started.';

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
  String get aiConfigNoModelsAvailable => 'No AI models are configured yet. Please add one in settings.';

  @override
  String get aiConfigNoModelsSelected => 'No models selected. At least one model is required.';

  @override
  String get aiConfigNoProvidersAvailable => 'No API providers available. Please add an API provider first.';

  @override
  String get aiConfigNoSuitableModelsAvailable => 'No models meet the requirements for this prompt. Please configure models that support the required capabilities.';

  @override
  String get aiConfigOutputModalitiesFieldLabel => 'Output Modalities';

  @override
  String get aiConfigOutputModalitiesTitle => 'Output Modalities';

  @override
  String get aiConfigProviderFieldLabel => 'Inference Provider';

  @override
  String get aiConfigProviderModelIdFieldLabel => 'Provider Model ID';

  @override
  String get aiConfigProviderModelIdTooShortError => 'ProviderModelId must be at least 3 characters';

  @override
  String get aiConfigProviderTypeFieldLabel => 'Provider Type';

  @override
  String get aiConfigReasoningCapabilityDescription => 'Model can perform step-by-step reasoning';

  @override
  String get aiConfigReasoningCapabilityFieldLabel => 'Reasoning Capability';

  @override
  String get aiConfigRequiredInputDataFieldLabel => 'Required Input Data';

  @override
  String get aiConfigResponseTypeFieldLabel => 'AI Response Type';

  @override
  String get aiConfigResponseTypeNotSelectedError => 'Please select a response type';

  @override
  String get aiConfigResponseTypeSelectHint => 'Select response type';

  @override
  String get aiConfigSelectInputDataTypesPrompt => 'Select required data types...';

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
  String get aiConfigUseReasoningDescription => 'If enabled, the model will use its reasoning capabilities for this prompt.';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Use Reasoning';

  @override
  String get aiConfigUserMessageEmptyError => 'User message cannot be empty';

  @override
  String get aiConfigUserMessageFieldLabel => 'User Message';

  @override
  String get aiProviderAnthropicDescription => 'Anthropic\'s Claude family of AI assistants';

  @override
  String get aiProviderAnthropicName => 'Anthropic Claude';

  @override
  String get aiProviderGeminiDescription => 'Google\'s Gemini AI models';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiDescription => 'API compatible with OpenAI format';

  @override
  String get aiProviderGenericOpenAiName => 'OpenAI Compatible';

  @override
  String get aiProviderNebiusAiStudioDescription => 'Nebius AI Studio\'s models';

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
  String get aiTaskSummaryRunning => 'Réflexion sur le résumé de la tâche...';

  @override
  String get aiTaskSummaryTitle => 'Résumé de la tâche IA';

  @override
  String get apiKeyAddPageTitle => 'Add AI Inference Provider';

  @override
  String get apiKeyEditLoadError => 'Failed to load API key configuration';

  @override
  String get apiKeyEditPageTitle => 'Edit AI Inference Provider';

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
  String get categoryDeleteQuestion => 'Voulez-vous supprimer cette catégorie ?';

  @override
  String get categorySearchPlaceholder => 'Rechercher des catégories...';

  @override
  String get checklistAddItem => 'Ajouter un nouvel élément';

  @override
  String get checklistDelete => 'Supprimer la liste de contrôle ?';

  @override
  String get checklistItemDelete => 'Supprimer l\'élément de la liste de contrôle ?';

  @override
  String get checklistItemDeleteCancel => 'Annuler';

  @override
  String get checklistItemDeleteConfirm => 'Confirmer';

  @override
  String get checklistItemDeleteWarning => 'Cette action ne peut pas être annulée.';

  @override
  String get checklistItemDrag => 'Faites glisser les suggestions dans la liste de contrôle';

  @override
  String get checklistNoSuggestionsTitle => 'Aucune suggestion d\'action';

  @override
  String get checklistsTitle => 'Listes de contrôle';

  @override
  String get checklistSuggestionsOutdated => 'Obsolète';

  @override
  String get checklistSuggestionsRunning => 'Réflexion sur les suggestions non suivies...';

  @override
  String get checklistSuggestionsTitle => 'Suggestions d\'actions';

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
  String get configFlagAttemptEmbeddingDescription => 'Lorsque cette option est activée, l\'application tentera de générer des embeddings pour vos entrées afin d\'améliorer la recherche et les suggestions de contenu associées.';

  @override
  String get configFlagAutoTranscribeDescription => 'Transcrire automatiquement les enregistrements audio dans vos entrées. Cela nécessite une connexion Internet.';

  @override
  String get configFlagEnableAutoTaskTldrDescription => 'Générer automatiquement des résumés pour vos tâches afin de vous aider à comprendre rapidement leur statut.';

  @override
  String get configFlagEnableCalendarPageDescription => 'Afficher la page Calendrier dans la navigation principale. Affichez et gérez vos entrées dans une vue calendrier.';

  @override
  String get configFlagEnableDashboardsPageDescription => 'Afficher la page Tableaux de bord dans la navigation principale. Affichez vos données et vos informations dans des tableaux de bord personnalisables.';

  @override
  String get configFlagEnableHabitsPageDescription => 'Afficher la page Habitudes dans la navigation principale. Suivez et gérez vos habitudes quotidiennes ici.';

  @override
  String get configFlagEnableLoggingDescription => 'Activer la journalisation détaillée à des fins de débogage. Cela peut avoir un impact sur les performances.';

  @override
  String get configFlagEnableMatrixDescription => 'Activer l\'intégration Matrix pour synchroniser vos entrées sur plusieurs appareils et avec d\'autres utilisateurs Matrix.';

  @override
  String get configFlagEnableNotifications => 'Activer les notifications ?';

  @override
  String get configFlagEnableNotificationsDescription => 'Recevoir des notifications pour les rappels, les mises à jour et les événements importants.';

  @override
  String get configFlagEnableTooltipDescription => 'Afficher des info-bulles utiles dans toute l\'application pour vous guider à travers les fonctionnalités.';

  @override
  String get configFlagPrivate => 'Afficher les entrées privées ?';

  @override
  String get configFlagPrivateDescription => 'Activez cette option pour rendre vos entrées privées par défaut. Les entrées privées ne sont visibles que par vous.';

  @override
  String get configFlagRecordLocationDescription => 'Enregistrer automatiquement votre position avec les nouvelles entrées. Cela facilite l\'organisation et la recherche basées sur la localisation.';

  @override
  String get configFlagResendAttachmentsDescription => 'Activez cette option pour renvoyer automatiquement les téléchargements de pièces jointes ayant échoué lorsque la connexion est rétablie.';

  @override
  String get configFlagUseCloudInferenceDescription => 'Utiliser les services d\'IA basés sur le cloud pour des fonctionnalités améliorées. Cela nécessite une connexion Internet.';

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
  String get dashboardCopyHint => 'Enregistrer et copier la configuration du tableau de bord';

  @override
  String get dashboardDeleteConfirm => 'OUI, SUPPRIMER CE TABLEAU DE BORD';

  @override
  String get dashboardDeleteHint => 'Supprimer tableau de bord';

  @override
  String get dashboardDeleteQuestion => 'Voulez-vous vraiment supprimer ce tableau de bord ?';

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
  String get habitShowAlertAtLabel => 'Afficher l\'alerte à';

  @override
  String get habitShowFromLabel => 'Afficher de';

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
  String get inputDataTypeTasksListDescription => 'Use a list of tasks as input';

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
  String get journalDeleteQuestion => 'Voulez-vous vraiment supprimer cette entrée ?';

  @override
  String get journalDurationLabel => 'Durée :';

  @override
  String get journalFavoriteTooltip => 'Préféré';

  @override
  String get journalFlaggedTooltip => 'Suivi';

  @override
  String get journalHideMapHint => 'Masquer la carte';

  @override
  String get journalLinkedEntriesAiLabel => 'Afficher les entrées générées par l\'IA :';

  @override
  String get journalLinkedEntriesHiddenLabel => 'Afficher les entrées masquées :';

  @override
  String get journalLinkedEntriesLabel => 'Lié :';

  @override
  String get journalLinkedFromLabel => 'Lié depuis :';

  @override
  String get journalLinkFromHint => 'Lié depuis';

  @override
  String get journalLinkToHint => 'Lié à';

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
  String get journalUnlinkQuestion => 'Êtes-vous sûr de vouloir dissocier cette entrée ?';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'YES, DELETE DATABASE';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Are you sure you want to delete $databaseName Database?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Supprimer la base de données des brouillons';

  @override
  String get maintenanceDeleteLoggingDb => 'Supprimer la base de données de journalisation';

  @override
  String get maintenanceDeleteSyncDb => 'Supprimer la base de données de synchronisation';

  @override
  String get maintenancePurgeAudioModels => 'Purger les modèles audio';

  @override
  String get maintenancePurgeAudioModelsMessage => 'Are you sure you want to purge all audio models? This action cannot be undone.';

  @override
  String get maintenancePurgeAudioModelsConfirm => 'YES, PURGE MODELS';

  @override
  String get maintenancePurgeDeleted => 'Purger les éléments supprimés';

  @override
  String get maintenancePurgeDeletedConfirm => 'Purger';

  @override
  String get maintenancePurgeDeletedMessage => 'Are you sure you want to purge all deleted items? This action cannot be undone.';

  @override
  String get maintenanceRecreateFts5 => 'Recréer l\'index de texte intégral';

  @override
  String get maintenanceRecreateFts5Message => 'Are you sure you want to recreate the full-text index? This may take some time.';

  @override
  String get maintenanceRecreateFts5Confirm => 'YES, RECREATE INDEX';

  @override
  String get maintenanceReSync => 'Resynchroniser les messages';

  @override
  String get maintenanceSyncDefinitions => 'Sync tags, measurables, dashboards, habits, categories';

  @override
  String get measurableDeleteConfirm => 'OUI, SUPPRIMER CET ÉLÉMENT MESURABLE';

  @override
  String get measurableDeleteQuestion => 'Voulez-vous supprimer ce type de données mesurables ?';

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
  String get saveLabel => 'Enregistrer';

  @override
  String get searchHint => 'Rechercher...';

  @override
  String get settingsAboutTitle => 'À propos de Lotti';

  @override
  String get settingsAdvancedShowCaseAboutLottiTooltip => 'En savoir plus sur l\'application Lotti, y compris la version et les crédits.';

  @override
  String get settingsAdvancedShowCaseApiKeyTooltip => 'Administrați cheile API pentru diverși furnizori de inteligență artificială. Adăugați, editați sau ștergeți chei pentru a configura integrări cu servicii compatibile precum OpenAI, Gemini și altele. Asigurați-vă că informațiile sensibile sunt gestionate în siguranță.';

  @override
  String get settingsAdvancedShowCaseConflictsTooltip => 'Résoudre les conflits de synchronisation pour garantir la cohérence des données.';

  @override
  String get settingsAdvancedShowCaseHealthImportTooltip => 'Importer des données relatives à la santé à partir de sources externes.';

  @override
  String get settingsAdvancedShowCaseLogsTooltip => 'Accéder aux journaux d\'application et les consulter pour le débogage et la surveillance.';

  @override
  String get settingsAdvancedShowCaseMaintenanceTooltip => 'Effectuer des tâches de maintenance pour optimiser les performances de l\'application.';

  @override
  String get settingsAdvancedShowCaseMatrixSyncTooltip => 'Configurer et gérer les paramètres de synchronisation Matrix pour une intégration transparente des données.';

  @override
  String get settingsAdvancedShowCaseModelsTooltip => 'Define AI models that use inference providers';

  @override
  String get settingsAdvancedShowCaseSyncOutboxTooltip => 'Afficher et gérer les éléments en attente de synchronisation dans la boîte d\'envoi.';

  @override
  String get settingsAdvancedTitle => 'Paramètres avancés';

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
  String get settingsCategoryShowCaseActiveTooltip => 'Activez cette option pour marquer la catégorie comme active. Les catégories actives sont actuellement utilisées et seront affichées bien en évidence pour une meilleure accessibilité.';

  @override
  String get settingsCategoryShowCaseColorTooltip => 'Sélectionnez une couleur pour représenter cette catégorie. Vous pouvez soit saisir un code couleur HEX valide (par exemple : #FF5733) ou utiliser le sélecteur de couleurs à droite pour choisir une couleur visuellement.';

  @override
  String get settingsCategoryShowCaseDelTooltip => 'Cliquez sur ce bouton pour supprimer la catégorie. Veuillez noter que cette action est irréversible. Assurez-vous donc que vous souhaitez supprimer la catégorie avant de continuer.';

  @override
  String get settingsCategoryShowCaseFavTooltip => 'Activez cette option pour marquer la catégorie comme favorite. Les catégories favorites sont plus faciles d\'accès et sont mises en évidence pour une consultation rapide.';

  @override
  String get settingsCategoryShowCaseNameTooltip => 'Saisissez un nom clair et pertinent pour la catégorie. Soyez bref et descriptif afin de pouvoir identifier facilement son objectif.';

  @override
  String get settingsCategoryShowCasePrivateTooltip => 'Activez cette option pour marquer la catégorie comme privée. Les catégories privées ne sont visibles que par vous et aident à organiser en toute sécurité les habitudes et les tâches sensibles ou personnelles.';

  @override
  String get settingsConflictsResolutionTitle => 'Résolution des conflits de synchronisation';

  @override
  String get settingsConflictsTitle => 'Conflits de synchronisation';

  @override
  String get settingsDashboardDetailsLabel => 'Dashboard Details';

  @override
  String get settingsDashboardSaveLabel => 'Save';

  @override
  String get settingsDashboardsShowCaseActiveTooltip => 'Activez ce commutateur pour marquer le tableau de bord comme actif. Les tableaux de bord actifs sont actuellement utilisés et seront affichés bien en évidence pour une meilleure accessibilité.';

  @override
  String get settingsDashboardsShowCaseCatTooltip => 'Sélectionnez une catégorie qui décrit le mieux le tableau de bord. Cela permet d\'organiser et de catégoriser efficacement vos tableaux de bord. Exemples : « Santé », « Productivité », « Travail ».';

  @override
  String get settingsDashboardsShowCaseCopyTooltip => 'Appuyez pour copier ce tableau de bord. Cela vous permettra de dupliquer le tableau de bord et de l\'utiliser ailleurs.';

  @override
  String get settingsDashboardsShowCaseDelTooltip => 'Appuyez sur ce bouton pour supprimer définitivement le tableau de bord. Soyez prudent, car cette action ne peut pas être annulée et toutes les données associées seront supprimées.';

  @override
  String get settingsDashboardsShowCaseDescrTooltip => 'Fournissez une description détaillée du tableau de bord. Cela permet de comprendre l\'objectif et le contenu du tableau de bord. Exemples : « Suit les activités de bien-être quotidiennes », « Surveille les tâches et les objectifs liés au travail ».';

  @override
  String get settingsDashboardsShowCaseHealthChartsTooltip => 'Sélectionnez les graphiques de santé que vous souhaitez inclure dans votre tableau de bord. Exemples : « Poids », « Pourcentage de graisse corporelle ».';

  @override
  String get settingsDashboardsShowCaseNameTooltip => 'Saisissez un nom clair et pertinent pour le tableau de bord. Soyez bref et descriptif afin de pouvoir identifier facilement son objectif. Exemples : « Suivi du bien-être », « Objectifs quotidiens », « Horaire de travail ».';

  @override
  String get settingsDashboardsShowCasePrivateTooltip => 'Activez ce commutateur pour rendre le tableau de bord privé. Les tableaux de bord privés ne sont visibles que par vous et ne seront pas partagés avec d\'autres.';

  @override
  String get settingsDashboardsShowCaseSurveyChartsTooltip => 'Sélectionnez les graphiques d\'enquête que vous souhaitez inclure dans votre tableau de bord. Exemples : « Satisfaction client », « Commentaires des employés ».';

  @override
  String get settingsDashboardsShowCaseWorkoutChartsTooltip => 'Sélectionnez les graphiques d\'entraînement que vous souhaitez inclure dans votre tableau de bord. Exemples : « Marche », « Course », « Natation ».';

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
  String get settingsHabitsShowCaseAlertTimeTooltip => 'Définissez l\'heure spécifique à laquelle vous souhaitez recevoir un rappel ou une alerte pour cette habitude. Cela vous assure de ne jamais manquer de la compléter. Exemple : « 20 h 00 ».';

  @override
  String get settingsHabitsShowCaseArchivedTooltip => 'Activez ce commutateur pour archiver l\'habitude. Les habitudes archivées ne sont plus actives, mais restent enregistrées pour référence future ou examen. Exemples : « Apprendre la guitare », « Cours terminé ».';

  @override
  String get settingsHabitsShowCaseCatTooltip => 'Choisissez une catégorie qui décrit le mieux votre habitude ou créez-en une nouvelle en sélectionnant le bouton [+].\nExemples : « Santé », « Productivité », « Exercice ».';

  @override
  String get settingsHabitsShowCaseDashTooltip => 'Sélectionnez un tableau de bord pour organiser et suivre votre habitude ou créez un nouveau tableau de bord à l\'aide du bouton [+].\nExemples : « Suivi du bien-être », « Objectifs quotidiens », « Horaire de travail ».';

  @override
  String get settingsHabitsShowCaseDelHabitTooltip => 'Appuyez sur ce bouton pour supprimer définitivement l\'habitude. Soyez prudent, car cette action est irréversible et toutes les données associées seront supprimées.';

  @override
  String get settingsHabitsShowCaseDescrTooltip => 'Fournissez une description brève et significative de l\'habitude. Incluez tous les détails pertinents ou le contexte pour définir clairement le but et l\'importance de l\'habitude.\nExemples : « Faire du jogging pendant 30 minutes chaque matin pour améliorer sa condition physique » ou « Lire un chapitre par jour pour améliorer ses connaissances et sa concentration »';

  @override
  String get settingsHabitsShowCaseNameTooltip => 'Saisissez un nom clair et descriptif pour l\'habitude.\nÉvitez les noms trop longs et faites en sorte qu\'il soit suffisamment concis pour identifier facilement l\'habitude.\nExemples : « Jogging matinal », « Lire quotidiennement ».';

  @override
  String get settingsHabitsShowCasePriorTooltip => 'Activez le commutateur pour attribuer une priorité à l\'habitude. Les habitudes hautement prioritaires représentent souvent des tâches essentielles ou urgentes sur lesquelles vous souhaitez vous concentrer. Exemples : « Faire de l\'exercice quotidiennement », « Travailler sur le projet ».';

  @override
  String get settingsHabitsShowCasePrivateTooltip => 'Utilisez ce commutateur pour marquer l\'habitude comme privée. Les habitudes privées ne sont visibles que par vous et ne seront pas partagées avec d\'autres. Exemples : « Journal personnel », « Méditation ».';

  @override
  String get settingsHabitsShowCaseStarDateTooltip => 'Sélectionnez la date à laquelle vous souhaitez commencer à suivre cette habitude. Cela permet de définir quand l\'habitude commence et permet un suivi précis des progrès. Exemple : « 1er juillet 2025 ».';

  @override
  String get settingsHabitsShowCaseStartTimeTooltip => 'Définissez l\'heure à partir de laquelle cette habitude doit être visible ou commencer à apparaître dans votre emploi du temps. Cela permet d\'organiser efficacement votre journée. Exemple : « 7 h 00 ».';

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
  String get settingsMatrixAcceptVerificationLabel => 'L\'autre appareil affiche des emojis, continuer';

  @override
  String get settingsMatrixCancel => 'Annuler';

  @override
  String get settingsMatrixCancelVerificationLabel => 'Annuler la vérification';

  @override
  String get settingsMatrixContinueVerificationLabel => 'Accepter sur l\'autre appareil pour continuer';

  @override
  String get settingsMatrixDeleteLabel => 'Supprimer';

  @override
  String get settingsMatrixDone => 'Terminé';

  @override
  String get settingsMatrixEnterValidUrl => 'Veuillez saisir une URL valide';

  @override
  String get settingsMatrixHomeserverConfigTitle => 'Configuration du serveur principal Matrix';

  @override
  String get settingsMatrixHomeServerLabel => 'Serveur principal';

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
  String get settingsMatrixQrTextPage => 'Scannez ce code QR pour inviter l\'appareil dans une salle de synchronisation.';

  @override
  String get settingsMatrixRoomConfigTitle => 'Configuration de la salle de synchronisation Matrix';

  @override
  String get settingsMatrixStartVerificationLabel => 'Démarrer la vérification';

  @override
  String get settingsMatrixStatsTitle => 'Statistiques Matrix';

  @override
  String get settingsMatrixTitle => 'Paramètres de synchronisation Matrix';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Appareils non vérifiés';

  @override
  String get settingsMatrixUserLabel => 'Utilisateur';

  @override
  String get settingsMatrixUserNameTooShort => 'Nom d\'utilisateur trop court';

  @override
  String get settingsMatrixVerificationCancelledLabel => 'Annulé sur un autre appareil…';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'OK';

  @override
  String settingsMatrixVerificationSuccessLabel(String deviceName, String deviceID) {
    return 'Vous avez vérifié avec succès $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm => 'Confirmez sur l\'autre appareil que les émojis ci-dessous sont affichés sur les deux appareils, dans le même ordre :';

  @override
  String get settingsMatrixVerifyIncomingConfirm => 'Confirmez que les émojis ci-dessous sont affichés sur les deux appareils, dans le même ordre :';

  @override
  String get settingsMatrixVerifyLabel => 'Vérifier';

  @override
  String get settingsMeasurableAggregationLabel => 'Type d\'agrégation par défaut :';

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
  String get settingsMeasurableShowCaseAggreTypeTooltip => 'Sélectionnez le type d\'agrégation par défaut pour les données mesurables. Cela détermine la façon dont les données seront résumées au fil du temps. \nOptions : « dailySum », « dailyMax », « dailyAvg », « hourlySum ».';

  @override
  String get settingsMeasurableShowCaseDelTooltip => 'Cliquez sur ce bouton pour supprimer le type mesurable. Veuillez noter que cette action est irréversible. Assurez-vous donc de vouloir supprimer le type mesurable avant de continuer.';

  @override
  String get settingsMeasurableShowCaseDescrTooltip => 'Fournissez une description brève et significative du type mesurable. Incluez tous les détails ou contextes pertinents pour définir clairement son objectif et son importance. \nExemples : « Poids corporel mesuré en kilogrammes »';

  @override
  String get settingsMeasurableShowCaseNameTooltip => 'Saisissez un nom clair et descriptif pour le type mesurable.\nÉvitez les noms trop longs et faites en sorte qu\'il soit suffisamment concis pour identifier facilement le type mesurable. \nExemples : « Poids », « Pression artérielle ».';

  @override
  String get settingsMeasurableShowCasePrivateTooltip => 'Activez cette option pour marquer le type mesurable comme privé. Les types mesurables privés ne sont visibles que par vous et aident à organiser les données sensibles ou personnelles en toute sécurité.';

  @override
  String get settingsMeasurableShowCaseUnitTooltip => 'Saisissez une abréviation d\'unité claire et concise pour le type mesurable. Cela permet d\'identifier facilement l\'unité de mesure.';

  @override
  String get settingsMeasurablesTitle => 'Types de données mesurables';

  @override
  String get settingsMeasurableUnitLabel => 'Abréviation d\'unité :';

  @override
  String get settingsSpeechAudioWithoutTranscript => 'Entrées audio sans transcription :';

  @override
  String get settingsSpeechAudioWithoutTranscriptButton => 'Trouver et transcrire';

  @override
  String get settingsSpeechLastActivity => 'Dernière activité de transcription :';

  @override
  String get settingsSpeechModelSelectionTitle => 'Modèle de reconnaissance vocale Whisper :';

  @override
  String get settingsSpeechTitle => 'Paramètres de la parole';

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
  String get settingsTagsShowCaseDeleteTooltip => 'Supprimer définitivement cette balise. Cette action est irréversible.';

  @override
  String get settingsTagsShowCaseHideTooltip => 'Activez cette option pour masquer cette balise des suggestions. Utilisez-la pour les balises personnelles ou rarement utilisées.';

  @override
  String get settingsTagsShowCaseNameTooltip => 'Saisissez un nom clair et pertinent pour la balise. Faites en sorte qu\'il soit court et descriptif afin de pouvoir catégoriser facilement vos habitudes. Exemples : « Santé », « Productivité », « Pleine conscience ».';

  @override
  String get settingsTagsShowCasePrivateTooltip => 'Activez cette option pour rendre la balise privée. Les balises privées ne sont visibles que par vous et ne seront pas partagées avec d\'autres personnes.';

  @override
  String get settingsTagsShowCaseTypeTooltip => 'Sélectionnez le type de balise pour la classer correctement : \n[Balise] -> Catégories générales comme « Santé » ou « Productivité ». \n[Personne] -> À utiliser pour baliser des personnes spécifiques. \n[Histoire] -> Attachez des balises aux histoires pour une meilleure organisation.';

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
  String get settingsThemingShowCaseDarkTooltip => 'Choisissez le thème sombre pour une apparence plus sombre.';

  @override
  String get settingsThemingShowCaseLightTooltip => 'Choisissez le thème clair pour une apparence plus claire.';

  @override
  String get settingsThemingShowCaseModeTooltip => 'Sélectionnez votre mode de thème préféré : Clair, Sombre ou Automatique.';

  @override
  String get settingsThemingTitle => 'Thème';

  @override
  String get settingThemingDark => 'Thème sombre';

  @override
  String get settingThemingLight => 'Thème clair';

  @override
  String get showcaseCloseButton => 'fermer';

  @override
  String get showcaseNextButton => 'suivant';

  @override
  String get showcasePreviousButton => 'précédent';

  @override
  String get speechModalAddTranscription => 'Ajouter une transcription';

  @override
  String get speechModalSelectLanguage => 'Sélectionner la langue';

  @override
  String get speechModalTitle => 'Reconnaissance vocale';

  @override
  String get speechModalTranscriptionProgress => 'Progression de la transcription';

  @override
  String get syncDeleteConfigConfirm => 'OUI, JE SUIS SÛR';

  @override
  String get syncDeleteConfigQuestion => 'Voulez-vous supprimer la configuration de synchronisation ?';

  @override
  String get syncEntitiesConfirm => 'YES, SYNC ALL';

  @override
  String get syncEntitiesMessage => 'This will sync all tags, measurables, and categories. Do you want to continue?';

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
  String get tasksFilterTitle => 'Filtre des tâches';

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
  String get timeByCategoryChartTitle => 'Temps par catégorie';

  @override
  String get timeByCategoryChartTotalLabel => 'Total';

  @override
  String get viewMenuTitle => 'Affichage';
}

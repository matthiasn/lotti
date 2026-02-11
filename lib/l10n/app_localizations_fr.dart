// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get activeLabel => 'Actif';

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
  String get addActionAddTimer => 'Minuteur';

  @override
  String get addActionAddTimeRecording =>
      'Commencer l\'enregistrement du temps';

  @override
  String get addActionImportImage => 'Importer une image';

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
  String get addToDictionary => 'Ajouter au dictionnaire';

  @override
  String get addToDictionaryDuplicate =>
      'Le terme existe déjà dans le dictionnaire';

  @override
  String get addToDictionaryNoCategory =>
      'Impossible d\'ajouter au dictionnaire : la tâche n\'a pas de catégorie';

  @override
  String get addToDictionarySaveFailed =>
      'Échec de l\'enregistrement du dictionnaire';

  @override
  String get addToDictionarySuccess => 'Terme ajouté au dictionnaire';

  @override
  String get addToDictionaryTooLong => 'Terme trop long (max 50 caractères)';

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
  String get aiConfigApiKeyEmptyError => 'La clé API ne peut pas être vide';

  @override
  String get aiConfigApiKeyFieldLabel => 'Clé API';

  @override
  String aiConfigAssociatedModelsRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count modèle$_temp0 associé$_temp1 supprimé$_temp2';
  }

  @override
  String get aiConfigBaseUrlFieldLabel => 'URL de base';

  @override
  String get aiConfigCommentFieldLabel => 'Commentaire (Optionnel)';

  @override
  String get aiConfigCreateButtonLabel => 'Créer un prompt';

  @override
  String get aiConfigDescriptionFieldLabel => 'Description (Optionnel)';

  @override
  String aiConfigFailedToLoadModels(String error) {
    return 'Échec du chargement des modèles : $error';
  }

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Échec du chargement des modèles. Réessaie s\'il te plaît.';

  @override
  String get aiConfigFailedToSaveMessage =>
      'Échec de l\'enregistrement de la configuration. Réessaie s\'il te plaît.';

  @override
  String get aiConfigInputDataTypesTitle => 'Types de données d\'entrée requis';

  @override
  String get aiConfigInputModalitiesFieldLabel => 'Modalités d\'entrée';

  @override
  String get aiConfigInputModalitiesTitle => 'Modalités d\'entrée';

  @override
  String get aiConfigInvalidUrlError => 'Entre une URL valide';

  @override
  String get aiConfigListCascadeDeleteWarning =>
      'Cela supprimera également tous les modèles associés à ce fournisseur.';

  @override
  String get aiConfigListDeleteConfirmCancel => 'ANNULER';

  @override
  String get aiConfigListDeleteConfirmDelete => 'SUPPRIMER';

  @override
  String aiConfigListDeleteConfirmMessage(String configName) {
    return 'Es-tu sûr de vouloir supprimer « $configName » ?';
  }

  @override
  String get aiConfigListDeleteConfirmTitle => 'Confirmer la suppression';

  @override
  String get aiConfigListEmptyState =>
      'Aucune configuration trouvée. Ajoutes-en une pour commencer.';

  @override
  String aiConfigListErrorDeleting(String configName, String error) {
    return 'Erreur lors de la suppression de $configName : $error';
  }

  @override
  String get aiConfigListErrorLoading =>
      'Erreur lors du chargement des configurations';

  @override
  String aiConfigListItemDeleted(String configName) {
    return '$configName supprimé';
  }

  @override
  String get aiConfigListUndoDelete => 'ANNULER';

  @override
  String get aiConfigManageModelsButton => 'Gérer les modèles';

  @override
  String aiConfigModelRemovedMessage(String modelName) {
    return '$modelName retiré du prompt';
  }

  @override
  String get aiConfigModelsTitle => 'Modèles disponibles';

  @override
  String get aiConfigNameFieldLabel => 'Nom d\'affichage';

  @override
  String get aiConfigNameTooShortError =>
      'Le nom doit comporter au moins 3 caractères';

  @override
  String get aiConfigNoModelsAvailable =>
      'Aucun modèle AI n\'est encore configuré. Ajoutes-en un dans les paramètres.';

  @override
  String get aiConfigNoModelsSelected =>
      'Aucun modèle sélectionné. Au moins un modèle est requis.';

  @override
  String get aiConfigNoProvidersAvailable =>
      'Aucun fournisseur d\'API disponible. Ajoute d\'abord un fournisseur d\'API.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Aucun modèle ne répond aux exigences de ce prompt. Configure des modèles avec les capacités requises.';

  @override
  String get aiConfigOutputModalitiesFieldLabel => 'Modalités de sortie';

  @override
  String get aiConfigOutputModalitiesTitle => 'Modalités de sortie';

  @override
  String get aiConfigProviderDeletedSuccessfully =>
      'Fournisseur supprimé avec succès';

  @override
  String get aiConfigProviderFieldLabel => 'Fournisseur d\'inférence';

  @override
  String get aiConfigProviderModelIdFieldLabel => 'ID du modèle du fournisseur';

  @override
  String get aiConfigProviderModelIdTooShortError =>
      'L\'ID du modèle doit comporter au moins 3 caractères';

  @override
  String get aiConfigProviderTypeFieldLabel => 'Type de fournisseur';

  @override
  String get aiConfigReasoningCapabilityDescription =>
      'Le modèle peut effectuer un raisonnement étape par étape';

  @override
  String get aiConfigReasoningCapabilityFieldLabel =>
      'Capacité de raisonnement';

  @override
  String get aiConfigRequiredInputDataFieldLabel =>
      'Données d\'entrée requises';

  @override
  String get aiConfigResponseTypeFieldLabel => 'Type de réponse AI';

  @override
  String get aiConfigResponseTypeNotSelectedError =>
      'Sélectionne un type de réponse';

  @override
  String get aiConfigResponseTypeSelectHint =>
      'Sélectionner le type de réponse';

  @override
  String get aiConfigSelectInputDataTypesPrompt =>
      'Sélectionner les types de données requis...';

  @override
  String get aiConfigSelectModalitiesPrompt => 'Sélectionner les modalités';

  @override
  String get aiConfigSelectProviderModalTitle =>
      'Sélectionner un fournisseur d\'inférence';

  @override
  String get aiConfigSelectProviderNotFound =>
      'Fournisseur d\'inférence introuvable';

  @override
  String get aiConfigSelectProviderTypeModalTitle =>
      'Sélectionner le type de fournisseur';

  @override
  String get aiConfigSelectResponseTypeTitle =>
      'Sélectionner le type de réponse AI';

  @override
  String get aiConfigSystemMessageFieldLabel => 'Message système';

  @override
  String get aiConfigUpdateButtonLabel => 'Mettre à jour le prompt';

  @override
  String get aiConfigUseReasoningDescription =>
      'Si activé, le modèle utilisera ses capacités de raisonnement pour ce prompt.';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Utiliser le raisonnement';

  @override
  String get aiConfigUserMessageEmptyError =>
      'Le message utilisateur ne peut pas être vide';

  @override
  String get aiConfigUserMessageFieldLabel => 'Message utilisateur';

  @override
  String get aiFormCancel => 'Annuler';

  @override
  String get aiFormFixErrors => 'Corrige les erreurs avant d\'enregistrer';

  @override
  String get aiFormNoChanges => 'Aucune modification non enregistrée';

  @override
  String get aiInferenceErrorAuthenticationMessage =>
      'L\'authentification a échoué. Vérifie ta clé API et assure-toi qu\'elle est valide.';

  @override
  String get aiInferenceErrorAuthenticationTitle =>
      'Échec de l\'authentification';

  @override
  String get aiInferenceErrorConnectionFailedMessage =>
      'Impossible de se connecter au service AI. Vérifie ta connexion Internet et assure-toi que le service est accessible.';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Échec de la connexion';

  @override
  String get aiInferenceErrorInvalidRequestMessage =>
      'La requête était invalide. Vérifie ta configuration et réessaie.';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Requête invalide';

  @override
  String get aiInferenceErrorRateLimitMessage =>
      'Tu as dépassé la limite de requêtes. Patiente un moment avant de réessayer.';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Limite de requêtes dépassée';

  @override
  String get aiInferenceErrorRetryButton => 'Réessayer';

  @override
  String get aiInferenceErrorServerMessage =>
      'Le service AI a rencontré une erreur. Réessaie plus tard.';

  @override
  String get aiInferenceErrorServerTitle => 'Erreur serveur';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Suggestions :';

  @override
  String get aiInferenceErrorTimeoutMessage =>
      'La requête a pris trop de temps. Réessaie ou vérifie si le service répond.';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Délai d\'attente dépassé';

  @override
  String get aiInferenceErrorUnknownMessage =>
      'Une erreur inattendue s\'est produite. Réessaie s\'il te plaît.';

  @override
  String get aiInferenceErrorUnknownTitle => 'Erreur';

  @override
  String get aiInferenceErrorViewLogButton => 'Voir le journal';

  @override
  String get aiModelSettings => 'Paramètres du modèle AI';

  @override
  String get aiProviderAnthropicDescription =>
      'La famille d\'assistants AI Claude d\'Anthropic';

  @override
  String get aiProviderAnthropicName => 'Anthropic Claude';

  @override
  String get aiProviderGeminiDescription => 'Modèles AI Gemini de Google';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiDescription =>
      'API compatible avec le format OpenAI';

  @override
  String get aiProviderGenericOpenAiName => 'Compatible OpenAI';

  @override
  String get aiProviderMistralDescription => 'API cloud de Mistral AI';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderNebiusAiStudioDescription =>
      'Modèles de Nebius AI Studio';

  @override
  String get aiProviderNebiusAiStudioName => 'Nebius AI Studio';

  @override
  String get aiProviderOllamaDescription =>
      'Exécuter l\'inférence localement avec Ollama';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOpenAiDescription => 'Modèles GPT d\'OpenAI';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'Modèles d\'OpenRouter';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderVoxtralDescription =>
      'Transcription Voxtral locale (jusqu\'à 30 min d\'audio, 9 langues)';

  @override
  String get aiProviderVoxtralName => 'Voxtral (local)';

  @override
  String get aiProviderWhisperDescription =>
      'Transcription Whisper locale avec API compatible OpenAI';

  @override
  String get aiProviderWhisperName => 'Whisper (local)';

  @override
  String get aiResponseDeleteCancel => 'Annuler';

  @override
  String get aiResponseDeleteConfirm => 'Supprimer';

  @override
  String get aiResponseDeleteError =>
      'Échec de la suppression de la réponse AI. Réessaie s\'il te plaît.';

  @override
  String get aiResponseDeleteTitle => 'Supprimer la réponse AI';

  @override
  String get aiResponseDeleteWarning =>
      'Es-tu sûr de vouloir supprimer cette réponse AI ? Cette action est irréversible.';

  @override
  String get aiResponseTypeAudioTranscription => 'Transcription audio';

  @override
  String get aiResponseTypeChecklistUpdates =>
      'Mises à jour de la liste de contrôle';

  @override
  String get aiResponseTypeImageAnalysis => 'Analyse d\'image';

  @override
  String get aiResponseTypeImagePromptGeneration => 'Prompt Image';

  @override
  String get aiResponseTypePromptGeneration => 'Prompt généré';

  @override
  String get aiResponseTypeTaskSummary => 'Résumé de tâche';

  @override
  String get aiSettingsAddedLabel => 'Ajouté';

  @override
  String get aiSettingsAddModelButton => 'Ajouter un modèle';

  @override
  String get aiSettingsAddModelTooltip => 'Ajouter ce modèle à ton fournisseur';

  @override
  String get aiSettingsAddPromptButton => 'Ajouter un prompt';

  @override
  String get aiSettingsAddProviderButton => 'Ajouter un fournisseur';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Effacer tous les filtres';

  @override
  String get aiSettingsClearFiltersButton => 'Effacer';

  @override
  String aiSettingsDeleteSelectedConfirmMessage(int count) {
    return 'Es-tu sûr de vouloir supprimer $count prompts sélectionnés ? Cette action est irréversible.';
  }

  @override
  String get aiSettingsDeleteSelectedConfirmTitle =>
      'Supprimer les prompts sélectionnés';

  @override
  String aiSettingsDeleteSelectedLabel(int count) {
    return 'Supprimer ($count)';
  }

  @override
  String get aiSettingsDeleteSelectedTooltip =>
      'Supprimer les prompts sélectionnés';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filtrer par capacité $capability';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filtrer par $provider';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip =>
      'Filtrer par capacité de raisonnement';

  @override
  String aiSettingsFilterByResponseTypeTooltip(String responseType) {
    return 'Filtrer par prompts $responseType';
  }

  @override
  String get aiSettingsModalityAudio => 'Audio';

  @override
  String get aiSettingsModalityText => 'Texte';

  @override
  String get aiSettingsModalityVision => 'Vision';

  @override
  String get aiSettingsNoModelsConfigured => 'Aucun modèle AI configuré';

  @override
  String get aiSettingsNoPromptsConfigured => 'Aucun prompt AI configuré';

  @override
  String get aiSettingsNoProvidersConfigured =>
      'Aucun fournisseur AI configuré';

  @override
  String get aiSettingsPageTitle => 'Paramètres AI';

  @override
  String get aiSettingsReasoningLabel => 'Raisonnement';

  @override
  String get aiSettingsSearchHint => 'Rechercher des configurations AI...';

  @override
  String get aiSettingsSelectLabel => 'Sélectionner';

  @override
  String get aiSettingsSelectModeTooltip =>
      'Basculer le mode de sélection pour les opérations en lot';

  @override
  String get aiSettingsTabModels => 'Modèles';

  @override
  String get aiSettingsTabPrompts => 'Prompts';

  @override
  String get aiSettingsTabProviders => 'Fournisseurs';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Crée des modèles, prompts et une catégorie de test optimisés';

  @override
  String aiSetupWizardDescription(String providerName) {
    return 'Configurer ou mettre à jour les modèles, prompts et la catégorie de test pour $providerName';
  }

  @override
  String get aiSetupWizardRunButton => 'Lancer la configuration';

  @override
  String get aiSetupWizardRunLabel => 'Lancer l\'assistant de configuration';

  @override
  String get aiSetupWizardRunningButton => 'En cours...';

  @override
  String get aiSetupWizardSafeToRunMultiple =>
      'Peut être exécuté plusieurs fois - les éléments existants seront conservés';

  @override
  String get aiSetupWizardTitle => 'Assistant de configuration AI';

  @override
  String get aiTaskSummaryCancelScheduled => 'Annuler le résumé programmé';

  @override
  String get aiTaskSummaryRunning => 'Réflexion sur le résumé de la tâche...';

  @override
  String aiTaskSummaryScheduled(String time) {
    return 'Résumé dans $time';
  }

  @override
  String get aiTaskSummaryTitle => 'Résumé de la tâche IA';

  @override
  String get aiTaskSummaryTriggerNow => 'Générer le résumé maintenant';

  @override
  String get aiTranscribingAudio => 'Transcription de l\'audio...';

  @override
  String get apiKeyAddPageTitle => 'Ajouter un fournisseur';

  @override
  String get apiKeyEditLoadError =>
      'Échec du chargement de la configuration de la clé API';

  @override
  String get apiKeyEditPageTitle => 'Modifier le fournisseur';

  @override
  String get apiKeyFormCreateButton => 'Créer';

  @override
  String get apiKeyFormUpdateButton => 'Mettre à jour';

  @override
  String get apiKeysSettingsPageTitle => 'Fournisseurs d\'inférence AI';

  @override
  String get audioRecordings => 'Enregistrements audio';

  @override
  String get automaticPrompts => 'Prompts automatiques';

  @override
  String get backfillManualDescription =>
      'Demander toutes les entrées manquantes quel que soit leur âge. Utilisez cette option pour récupérer les écarts de synchronisation anciens.';

  @override
  String get backfillManualProcessing => 'Traitement...';

  @override
  String backfillManualSuccess(int count) {
    return '$count entrées demandées';
  }

  @override
  String get backfillManualTitle => 'Rattrapage manuel';

  @override
  String get backfillManualTrigger => 'Demander les entrées manquantes';

  @override
  String get backfillReRequestDescription =>
      'Redemander les entrées qui ont été demandées mais jamais reçues. Utilisez cette option lorsque les réponses sont bloquées.';

  @override
  String get backfillReRequestProcessing => 'Nouvelle demande...';

  @override
  String backfillReRequestSuccess(int count) {
    return '$count entrées redemandées';
  }

  @override
  String get backfillReRequestTitle => 'Redemander les en attente';

  @override
  String get backfillReRequestTrigger => 'Redemander les entrées en attente';

  @override
  String get backfillSettingsInfo =>
      'Le rattrapage automatique demande les entrées manquantes des dernières 24 heures. Utilisez le rattrapage manuel pour les entrées plus anciennes.';

  @override
  String get backfillSettingsSubtitle =>
      'Gérer la récupération des écarts de synchronisation';

  @override
  String get backfillSettingsTitle => 'Rattrapage de synchronisation';

  @override
  String get backfillStatsBackfilled => 'Rattrapé';

  @override
  String get backfillStatsDeleted => 'Supprimé';

  @override
  String backfillStatsHostsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count appareil$_temp0 connecté$_temp1';
  }

  @override
  String get backfillStatsMissing => 'Manquant';

  @override
  String get backfillStatsNoData =>
      'Aucune donnée de synchronisation disponible';

  @override
  String get backfillStatsReceived => 'Reçu';

  @override
  String get backfillStatsRefresh => 'Actualiser les statistiques';

  @override
  String get backfillStatsRequested => 'Demandé';

  @override
  String get backfillStatsTitle => 'Statistiques de synchronisation';

  @override
  String get backfillStatsTotalEntries => 'Total des entrées';

  @override
  String get backfillStatsUnresolvable => 'Non résoluble';

  @override
  String get backfillToggleDisabledDescription =>
      'Rattrapage désactivé - utile sur les réseaux limités';

  @override
  String get backfillToggleEnabledDescription =>
      'Demander automatiquement les entrées de synchronisation manquantes';

  @override
  String get backfillToggleTitle => 'Rattrapage automatique';

  @override
  String get basicSettings => 'Paramètres de base';

  @override
  String get cancelButton => 'Annuler';

  @override
  String get categoryActiveDescription =>
      'Les catégories inactives n\'apparaîtront pas dans les listes de sélection';

  @override
  String get categoryAiModelDescription =>
      'Contrôler quels prompts AI peuvent être utilisés avec cette catégorie';

  @override
  String get categoryAutomaticPromptsDescription =>
      'Configurer les prompts qui s\'exécutent automatiquement pour différents types de contenu';

  @override
  String get categoryCreationError =>
      'Impossible de créer la catégorie. Réessaie s\'il te plaît.';

  @override
  String get categoryDefaultLanguageDescription =>
      'Définir une langue par défaut pour les tâches de cette catégorie';

  @override
  String get categoryDeleteConfirm => 'OUI, SUPPRIMER CETTE CATÉGORIE';

  @override
  String get categoryDeleteConfirmation =>
      'Cette action est irréversible. Toutes les entrées de cette catégorie seront conservées mais ne seront plus catégorisées.';

  @override
  String get categoryDeleteQuestion => 'Veux-tu supprimer cette catégorie ?';

  @override
  String get categoryDeleteTitle => 'Supprimer la catégorie ?';

  @override
  String get categoryFavoriteDescription =>
      'Marquer cette catégorie comme favorite';

  @override
  String get categoryNameRequired => 'Le nom de la catégorie est obligatoire';

  @override
  String get categoryNotFound => 'Catégorie introuvable';

  @override
  String get categoryPrivateDescription =>
      'Masquer cette catégorie lorsque le mode privé est activé';

  @override
  String get categorySearchPlaceholder => 'Rechercher des catégories...';

  @override
  String get celebrationTapToContinue => 'Appuyez pour continuer';

  @override
  String get checklistAddItem => 'Ajouter un nouvel élément';

  @override
  String get checklistAllDone => 'Tous les éléments sont terminés !';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total terminés';
  }

  @override
  String get checklistDelete => 'Supprimer la liste de contrôle ?';

  @override
  String get checklistExportAsMarkdown =>
      'Exporter la liste de contrôle en Markdown';

  @override
  String get checklistExportFailed => 'Échec de l\'exportation';

  @override
  String get checklistFilterShowAll => 'Afficher tous les éléments';

  @override
  String get checklistFilterShowOpen => 'Afficher les éléments en cours';

  @override
  String get checklistFilterStateAll => 'Affichage de tous les éléments';

  @override
  String get checklistFilterStateOpenOnly => 'Affichage des éléments en cours';

  @override
  String checklistFilterToggleSemantics(String state) {
    return 'Basculer le filtre de la liste de contrôle (actuel : $state)';
  }

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
  String get checklistMarkdownCopied => 'Liste de contrôle copiée en Markdown';

  @override
  String get checklistNoSuggestionsTitle => 'Aucune suggestion d\'action';

  @override
  String get checklistNothingToExport => 'Aucun élément à exporter';

  @override
  String get checklistShareHint => 'Appui long pour partager';

  @override
  String get checklistsReorder => 'Réorganiser';

  @override
  String get checklistsTitle => 'Listes de contrôle';

  @override
  String get checklistSuggestionsOutdated => 'Obsolète';

  @override
  String get checklistSuggestionsRunning =>
      'Réflexion sur les suggestions non suivies...';

  @override
  String get checklistSuggestionsTitle => 'Suggestions d\'actions';

  @override
  String get checklistUpdates => 'Mises à jour de la liste de contrôle';

  @override
  String get clearButton => 'Effacer';

  @override
  String get colorLabel => 'Couleur :';

  @override
  String get colorPickerError => 'Couleur hexadécimale invalide';

  @override
  String get colorPickerHint => 'Saisir la couleur hexadécimale ou choisir';

  @override
  String get commonError => 'Erreur';

  @override
  String get commonLoading => 'Chargement...';

  @override
  String get commonUnknown => 'Inconnu';

  @override
  String get completeHabitFailButton => 'Échec';

  @override
  String get completeHabitSkipButton => 'Ignorer';

  @override
  String get completeHabitSuccessButton => 'Succès';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Lorsque cette option est activée, l\'application tentera de générer des embeddings pour tes entrées afin d\'améliorer la recherche et les suggestions de contenu associées.';

  @override
  String get configFlagAutoTranscribeDescription =>
      'Transcrire automatiquement les enregistrements audio dans tes entrées. Cela nécessite une connexion Internet.';

  @override
  String get configFlagEnableAiStreaming =>
      'Activer le streaming IA pour les actions liées aux tâches';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Diffuser les réponses IA pour les actions liées aux tâches. Désactivez pour mettre les réponses en mémoire tampon et conserver une interface plus fluide.';

  @override
  String get configFlagEnableAutoTaskTldrDescription =>
      'Générer automatiquement des résumés pour tes tâches afin de t\'aider à comprendre rapidement leur statut.';

  @override
  String get configFlagEnableCalendarPage => 'Activer la page Calendrier';

  @override
  String get configFlagEnableCalendarPageDescription =>
      'Afficher la page Calendrier dans la navigation principale. Affiche et gère tes entrées dans une vue calendrier.';

  @override
  String get configFlagEnableDailyOs => 'Activer DailyOS';

  @override
  String get configFlagEnableDailyOsDescription =>
      'Afficher DailyOS dans la navigation principale.';

  @override
  String get configFlagEnableDashboardsPage =>
      'Activer la page Tableaux de bord';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Afficher la page Tableaux de bord dans la navigation principale. Affiche tes données et tes informations dans des tableaux de bord personnalisables.';

  @override
  String get configFlagEnableEvents => 'Activer les événements';

  @override
  String get configFlagEnableEventsDescription =>
      'Afficher la fonctionnalité Événements pour créer, suivre et gérer des événements dans ton journal.';

  @override
  String get configFlagEnableHabitsPage => 'Activer la page Habitudes';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Afficher la page Habitudes dans la navigation principale. Suis et gère tes habitudes quotidiennes ici.';

  @override
  String get configFlagEnableLogging => 'Activer la journalisation';

  @override
  String get configFlagEnableLoggingDescription =>
      'Activer la journalisation détaillée à des fins de débogage. Cela peut avoir un impact sur les performances.';

  @override
  String get configFlagEnableMatrix => 'Activer la synchronisation Matrix';

  @override
  String get configFlagEnableMatrixDescription =>
      'Activer l\'intégration Matrix pour synchroniser tes entrées sur plusieurs appareils et avec d\'autres utilisateurs Matrix.';

  @override
  String get configFlagEnableNotifications => 'Activer les notifications ?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Recevoir des notifications pour les rappels, les mises à jour et les événements importants.';

  @override
  String get configFlagEnableSessionRatings =>
      'Activer les évaluations de session';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Proposer une évaluation rapide de session à l\'arrêt d\'un minuteur.';

  @override
  String get configFlagEnableTooltip => 'Activer les info-bulles';

  @override
  String get configFlagEnableTooltipDescription =>
      'Afficher des info-bulles utiles dans toute l\'application pour te guider à travers les fonctionnalités.';

  @override
  String get configFlagPrivate => 'Afficher les entrées privées ?';

  @override
  String get configFlagPrivateDescription =>
      'Active cette option pour rendre tes entrées privées par défaut. Les entrées privées ne sont visibles que par toi.';

  @override
  String get configFlagRecordLocation => 'Enregistrer la localisation';

  @override
  String get configFlagRecordLocationDescription =>
      'Enregistrer automatiquement ta position avec les nouvelles entrées. Cela facilite l\'organisation et la recherche basées sur la localisation.';

  @override
  String get configFlagResendAttachments => 'Renvoyer les pièces jointes';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Active cette option pour renvoyer automatiquement les téléchargements de pièces jointes ayant échoué lorsque la connexion est rétablie.';

  @override
  String get configFlagUseCloudInferenceDescription =>
      'Utiliser les services d\'IA basés sur le cloud pour des fonctionnalités améliorées. Cela nécessite une connexion Internet.';

  @override
  String get conflictEntityLabel => 'Entité';

  @override
  String get conflictIdLabel => 'ID';

  @override
  String get conflictsCopyTextFromSync =>
      'Copier le texte depuis la synchronisation';

  @override
  String get conflictsEmptyDescription =>
      'Tout est synchronisé. Les éléments résolus restent disponibles dans l\'autre filtre.';

  @override
  String get conflictsEmptyTitle => 'Aucun conflit détecté';

  @override
  String get conflictsResolved => 'résolu';

  @override
  String get conflictsResolveLocalVersion => 'Résoudre avec la version locale';

  @override
  String get conflictsResolveRemoteVersion =>
      'Résoudre avec la version distante';

  @override
  String get conflictsUnresolved => 'non résolu';

  @override
  String get copyAsMarkdown => 'Copier en Markdown';

  @override
  String get copyAsText => 'Copier en texte';

  @override
  String get correctionExampleCancel => 'ANNULER';

  @override
  String get correctionExampleCaptured =>
      'Correction enregistrée pour l\'apprentissage IA';

  @override
  String correctionExamplePending(int seconds) {
    return 'Enregistrement de la correction dans ${seconds}s...';
  }

  @override
  String get correctionExamplesEmpty =>
      'Aucune correction capturée pour l\'instant. Modifie un élément de liste pour ajouter ton premier exemple.';

  @override
  String get correctionExamplesSectionDescription =>
      'Lorsque tu corriges manuellement des éléments de liste, ces corrections sont enregistrées ici et utilisées pour améliorer les suggestions de l\'IA.';

  @override
  String get correctionExamplesSectionTitle =>
      'Exemples de Correction de Liste';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'Tu as $count corrections. Seules les $max plus récentes seront utilisées dans les prompts IA. Pense à supprimer les exemples anciens ou redondants.';
  }

  @override
  String get coverArtAssign => 'Définir comme couverture';

  @override
  String get coverArtChipActive => 'Couverture';

  @override
  String get coverArtChipSet => 'Définir couverture';

  @override
  String get coverArtRemove => 'Retirer comme couverture';

  @override
  String get createButton => 'Créer';

  @override
  String get createCategoryTitle => 'Créer une catégorie :';

  @override
  String get createEntryLabel => 'Créer une nouvelle entrée';

  @override
  String get createEntryTitle => 'Ajouter';

  @override
  String get createNewLinkedTask => 'Créer une nouvelle tâche liée...';

  @override
  String get createPromptsFirst =>
      'Crée d\'abord des prompts AI pour les configurer ici';

  @override
  String get customColor => 'Couleur personnalisée';

  @override
  String get dailyOsActual => 'Réel';

  @override
  String get dailyOsAddBlock => 'Ajouter un bloc';

  @override
  String get dailyOsAddBudget => 'Ajouter un budget';

  @override
  String get dailyOsAddNote => 'Ajouter une note...';

  @override
  String get dailyOsAgreeToPlan => 'Accepter le plan';

  @override
  String get dailyOsCancel => 'Annuler';

  @override
  String get dailyOsCategory => 'Catégorie';

  @override
  String get dailyOsChooseCategory => 'Choisir une catégorie...';

  @override
  String get dailyOsCompletionMessage => 'Bravo ! Tu as terminé ta journée.';

  @override
  String get dailyOsCopyToTomorrow => 'Copier pour demain';

  @override
  String get dailyOsDayComplete => 'Journée terminée';

  @override
  String get dailyOsDayPlan => 'Plan du jour';

  @override
  String get dailyOsDaySummary => 'Résumé du jour';

  @override
  String get dailyOsDelete => 'Supprimer';

  @override
  String get dailyOsDeleteBudget => 'Supprimer le budget ?';

  @override
  String get dailyOsDeleteBudgetConfirm =>
      'Cela supprimera le budget de temps de ton plan du jour.';

  @override
  String get dailyOsDeletePlannedBlock => 'Supprimer le bloc ?';

  @override
  String get dailyOsDeletePlannedBlockConfirm =>
      'Cela supprimera le bloc planifié de ta chronologie.';

  @override
  String get dailyOsDoneForToday => 'Terminé pour aujourd\'hui';

  @override
  String get dailyOsDraftMessage =>
      'Le plan est un brouillon. Accepte pour le verrouiller.';

  @override
  String get dailyOsDueToday => 'Dû aujourd\'hui';

  @override
  String get dailyOsDueTodayShort => 'Dû';

  @override
  String dailyOsDuplicateBudget(String categoryName) {
    return 'Un budget pour « $categoryName » existe déjà';
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
      other: '$count heures',
      one: '1 heure',
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
  String get dailyOsEditBudget => 'Modifier le budget';

  @override
  String get dailyOsEditPlannedBlock => 'Modifier le bloc planifié';

  @override
  String get dailyOsEndTime => 'Fin';

  @override
  String get dailyOsEntry => 'Entrée';

  @override
  String get dailyOsExpandToMove =>
      'Développer la chronologie pour déplacer ce bloc';

  @override
  String get dailyOsExpandToMoveMore =>
      'Développer la chronologie pour déplacer plus loin';

  @override
  String get dailyOsFailedToLoadBudgets => 'Échec du chargement des budgets';

  @override
  String get dailyOsFailedToLoadTimeline =>
      'Échec du chargement de la chronologie';

  @override
  String get dailyOsFold => 'Réduire';

  @override
  String dailyOsHoursMinutesPlanned(int hours, int minutes) {
    return '${hours}h ${minutes}m planifiées';
  }

  @override
  String dailyOsHoursPlanned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures planifiées',
      one: '1 heure planifiée',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsInvalidTimeRange => 'Plage horaire invalide';

  @override
  String dailyOsMinutesPlanned(int count) {
    return '$count min planifiées';
  }

  @override
  String get dailyOsNearLimit => 'Proche de la limite';

  @override
  String get dailyOsNoBudgets => 'Aucun budget de temps';

  @override
  String get dailyOsNoBudgetsHint =>
      'Ajoute des budgets pour suivre la répartition de ton temps entre les catégories.';

  @override
  String get dailyOsNoBudgetWarning => 'Pas de temps prévu';

  @override
  String get dailyOsNote => 'Note';

  @override
  String get dailyOsNoTimeline => 'Aucune entrée de chronologie';

  @override
  String get dailyOsNoTimelineHint =>
      'Démarre un minuteur ou ajoute des blocs planifiés pour voir ta journée.';

  @override
  String get dailyOsOnTrack => 'En bonne voie';

  @override
  String get dailyOsOver => 'Dépassé';

  @override
  String get dailyOsOverallProgress => 'Progression globale';

  @override
  String get dailyOsOverBudget => 'Budget dépassé';

  @override
  String get dailyOsOverdue => 'En retard';

  @override
  String get dailyOsOverdueShort => 'Retard';

  @override
  String get dailyOsPlan => 'Plan';

  @override
  String get dailyOsPlanned => 'Planifié';

  @override
  String get dailyOsPlannedDuration => 'Durée planifiée';

  @override
  String get dailyOsQuickCreateTask => 'Créer une tâche pour ce budget';

  @override
  String get dailyOsReAgree => 'Accepter à nouveau';

  @override
  String get dailyOsRecorded => 'Enregistré';

  @override
  String get dailyOsRemaining => 'Restant';

  @override
  String get dailyOsReviewMessage =>
      'Modifications détectées. Révise ton plan.';

  @override
  String get dailyOsSave => 'Enregistrer';

  @override
  String get dailyOsSelectCategory => 'Sélectionner une catégorie';

  @override
  String get dailyOsStartTime => 'Début';

  @override
  String get dailyOsTasks => 'Tâches';

  @override
  String get dailyOsTimeBudgets => 'Budgets de temps';

  @override
  String dailyOsTimeLeft(String time) {
    return '$time restant';
  }

  @override
  String get dailyOsTimeline => 'Chronologie';

  @override
  String dailyOsTimeOver(String time) {
    return '+$time dépassé';
  }

  @override
  String get dailyOsTimeRange => 'Plage horaire';

  @override
  String get dailyOsTimesUp => 'Temps écoulé';

  @override
  String get dailyOsTodayButton => 'Aujourd\'hui';

  @override
  String get dailyOsUncategorized => 'Non catégorisé';

  @override
  String get dailyOsViewModeClassic => 'Classique';

  @override
  String get dailyOsViewModeDailyOs => 'Daily OS';

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
      'Veux-tu vraiment supprimer ce tableau de bord ?';

  @override
  String get dashboardDescriptionLabel => 'Description :';

  @override
  String get dashboardNameLabel => 'Nom du tableau de bord :';

  @override
  String get dashboardNotFound => 'Tableau de bord non trouvé';

  @override
  String get dashboardPrivateLabel => 'Privé :';

  @override
  String get defaultLanguage => 'Langue par défaut';

  @override
  String get deleteButton => 'Supprimer';

  @override
  String get done => 'Terminé';

  @override
  String get doneButton => 'Terminé';

  @override
  String get editMenuTitle => 'Modifier';

  @override
  String get editorInsertDivider => 'Insérer un séparateur';

  @override
  String get editorPlaceholder => 'Saisir des notes...';

  @override
  String get enhancedPromptFormAdditionalDetailsTitle =>
      'Détails supplémentaires';

  @override
  String get enhancedPromptFormAiResponseTypeSubtitle =>
      'Format de la réponse attendue';

  @override
  String get enhancedPromptFormBasicConfigurationTitle =>
      'Configuration de base';

  @override
  String get enhancedPromptFormConfigurationOptionsTitle =>
      'Options de configuration';

  @override
  String get enhancedPromptFormDescription =>
      'Crée des prompts personnalisés qui peuvent être utilisés avec tes modèles AI pour générer des types de réponses spécifiques';

  @override
  String get enhancedPromptFormDescriptionHelperText =>
      'Notes facultatives sur l\'objectif et l\'utilisation de ce prompt';

  @override
  String get enhancedPromptFormDisplayNameHelperText =>
      'Un nom descriptif pour ce modèle de prompt';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Choisir parmi des modèles de prompt prédéfinis';

  @override
  String get enhancedPromptFormPromptConfigurationTitle =>
      'Configuration du prompt';

  @override
  String get enhancedPromptFormQuickStartDescription =>
      'Commence avec un modèle prédéfini pour gagner du temps';

  @override
  String get enhancedPromptFormQuickStartTitle => 'Démarrage rapide';

  @override
  String get enhancedPromptFormRequiredInputDataSubtitle =>
      'Type de données attendu par ce prompt';

  @override
  String get enhancedPromptFormSystemMessageHelperText =>
      'Instructions qui définissent le comportement et le style de réponse de l\'AI';

  @override
  String get enhancedPromptFormUserMessageHelperText =>
      'Le texte principal du prompt.';

  @override
  String get enterCategoryName => 'Saisir le nom de la catégorie';

  @override
  String get entryActions => 'Actions';

  @override
  String get entryLabelsActionSubtitle =>
      'Assigner des étiquettes pour organiser cette entrée';

  @override
  String get entryLabelsActionTitle => 'Étiquettes';

  @override
  String get entryLabelsEditTooltip => 'Modifier les étiquettes';

  @override
  String get entryLabelsHeaderTitle => 'Étiquettes';

  @override
  String get entryLabelsNoLabels => 'Aucune étiquette assignée';

  @override
  String get entryTypeLabelAiResponse => 'Réponse AI';

  @override
  String get entryTypeLabelChecklist => 'Liste de contrôle';

  @override
  String get entryTypeLabelChecklistItem => 'Élément de liste';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Habitude';

  @override
  String get entryTypeLabelJournalAudio => 'Audio';

  @override
  String get entryTypeLabelJournalEntry => 'Texte';

  @override
  String get entryTypeLabelJournalEvent => 'Événement';

  @override
  String get entryTypeLabelJournalImage => 'Photo';

  @override
  String get entryTypeLabelMeasurementEntry => 'Mesure';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Santé';

  @override
  String get entryTypeLabelSurveyEntry => 'Sondage';

  @override
  String get entryTypeLabelTask => 'Tâche';

  @override
  String get entryTypeLabelWorkoutEntry => 'Entraînement';

  @override
  String get errorLoadingPrompts => 'Erreur lors du chargement des prompts';

  @override
  String get eventNameLabel => 'Événement :';

  @override
  String get favoriteLabel => 'Favori';

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
  String get generateCoverArt => 'Générer une couverture';

  @override
  String get generateCoverArtSubtitle =>
      'Créer une image à partir de la description vocale';

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
  String get habitDeleteQuestion => 'Veux-tu supprimer cette habitude ?';

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
  String get imageGenerationAcceptButton => 'Accepter comme couverture';

  @override
  String get imageGenerationCancelEdit => 'Annuler';

  @override
  String get imageGenerationEditPromptButton => 'Modifier le prompt';

  @override
  String get imageGenerationEditPromptLabel => 'Modifier le prompt';

  @override
  String get imageGenerationError => 'Échec de la génération d\'image';

  @override
  String get imageGenerationGenerating => 'Génération de l\'image...';

  @override
  String get imageGenerationModalTitle => 'Image générée';

  @override
  String get imageGenerationRetry => 'Réessayer';

  @override
  String imageGenerationSaveError(String error) {
    return 'Échec de l\'enregistrement de l\'image: $error';
  }

  @override
  String imageGenerationWithReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Avec $count images de référence',
      one: 'Avec 1 image de référence',
      zero: 'Aucune image de référence',
    );
    return '$_temp0';
  }

  @override
  String get imagePromptGenerationCardTitle => 'Prompt Image IA';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Prompt d\'image copié dans le presse-papiers';

  @override
  String get imagePromptGenerationCopyButton => 'Copier Prompt';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Copier le prompt d\'image dans le presse-papiers';

  @override
  String get imagePromptGenerationExpandTooltip => 'Afficher le prompt complet';

  @override
  String get imagePromptGenerationFullPromptLabel => 'Prompt image complet :';

  @override
  String get images => 'Images';

  @override
  String get inputDataTypeAudioFilesDescription =>
      'Utiliser des fichiers audio comme entrée';

  @override
  String get inputDataTypeAudioFilesName => 'Fichiers audio';

  @override
  String get inputDataTypeImagesDescription =>
      'Utiliser des images comme entrée';

  @override
  String get inputDataTypeImagesName => 'Images';

  @override
  String get inputDataTypeTaskDescription =>
      'Utiliser la tâche actuelle comme entrée';

  @override
  String get inputDataTypeTaskName => 'Tâche';

  @override
  String get inputDataTypeTasksListDescription =>
      'Utiliser une liste de tâches comme entrée';

  @override
  String get inputDataTypeTasksListName => 'Liste de tâches';

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
      'Veux-tu vraiment supprimer cette entrée ?';

  @override
  String get journalDurationLabel => 'Durée :';

  @override
  String get journalFavoriteTooltip => 'Préféré';

  @override
  String get journalFlaggedTooltip => 'Suivi';

  @override
  String get journalHideLinkHint => 'Masquer le lien';

  @override
  String get journalHideMapHint => 'Masquer la carte';

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
  String get journalShareHint => 'Partager';

  @override
  String get journalSharePhotoHint => 'Partager photo';

  @override
  String get journalShowLinkHint => 'Afficher le lien';

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
      'Es-tu sûr de vouloir dissocier cette entrée ?';

  @override
  String get linkedFromLabel => 'LIÉ DEPUIS';

  @override
  String get linkedTasksMenuTooltip => 'Options des tâches liées';

  @override
  String get linkedTasksTitle => 'Tâches liées';

  @override
  String get linkedToLabel => 'LIÉ À';

  @override
  String get linkExistingTask => 'Lier une tâche existante...';

  @override
  String get loggingFailedToLoad =>
      'Échec du chargement des journaux. Réessaie s\'il te plaît.';

  @override
  String get loggingFailedToLoadMore =>
      'Échec du chargement de résultats supplémentaires. Réessaie s\'il te plaît.';

  @override
  String get loggingSearchFailed =>
      'Échec de la recherche. Réessaie s\'il te plaît.';

  @override
  String get logsSearchHint => 'Rechercher tous les logs...';

  @override
  String get maintenanceDeleteDatabaseConfirm =>
      'OUI, SUPPRIMER LA BASE DE DONNÉES';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Es-tu sûr de vouloir supprimer la base de données $databaseName ?';
  }

  @override
  String get maintenanceDeleteEditorDb =>
      'Supprimer la base de données des brouillons';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Supprimer la base de données des brouillons de l\'éditeur';

  @override
  String get maintenanceDeleteLoggingDb =>
      'Supprimer la base de données de journalisation';

  @override
  String get maintenanceDeleteLoggingDbDescription =>
      'Supprimer la base de données de journalisation';

  @override
  String get maintenanceDeleteSyncDb =>
      'Supprimer la base de données de synchronisation';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Supprimer la base de données de synchronisation';

  @override
  String get maintenancePopulateSequenceLog =>
      'Remplir le journal de séquence de synchronisation';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count entrées indexées';
  }

  @override
  String get maintenancePopulateSequenceLogConfirm => 'OUI, REMPLIR';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Indexer les entrées existantes pour le support de rattrapage';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'Cela analysera toutes les entrées du journal et les ajoutera au journal de séquence de synchronisation. Cela permet les réponses de rattrapage pour les entrées créées avant l\'ajout de cette fonctionnalité.';

  @override
  String get maintenancePurgeDeleted => 'Purger les éléments supprimés';

  @override
  String get maintenancePurgeDeletedConfirm => 'Purger';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Purger définitivement tous les éléments supprimés';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Es-tu sûr de vouloir purger tous les éléments supprimés ? Cette action est irréversible.';

  @override
  String get maintenanceRecreateFts5 => 'Recréer l\'index de texte intégral';

  @override
  String get maintenanceRecreateFts5Confirm => 'OUI, RECRÉER L\'INDEX';

  @override
  String get maintenanceRecreateFts5Description =>
      'Recréer l\'index de recherche en texte intégral';

  @override
  String get maintenanceRecreateFts5Message =>
      'Es-tu sûr de vouloir recréer l\'index de recherche en texte intégral ? Cela peut prendre un certain temps.';

  @override
  String get maintenanceReSync => 'Resynchroniser les messages';

  @override
  String get maintenanceReSyncDescription =>
      'Resynchroniser les messages depuis le serveur';

  @override
  String get maintenanceSyncDefinitions =>
      'Synchroniser les tags, mesurables, tableaux de bord, habitudes, catégories, paramètres AI';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Synchroniser les tags, mesurables, tableaux de bord, habitudes, catégories et paramètres AI';

  @override
  String get manageLinks => 'Gérer les liens...';

  @override
  String get matrixStatsError =>
      'Erreur lors du chargement des statistiques Matrix';

  @override
  String get measurableDeleteConfirm => 'OUI, SUPPRIMER CET ÉLÉMENT MESURABLE';

  @override
  String get measurableDeleteQuestion =>
      'Veux-tu supprimer ce type de données mesurables ?';

  @override
  String get measurableNotFound => 'Élément mesurable introuvable';

  @override
  String get modalityAudioDescription => 'Capacités de traitement audio';

  @override
  String get modalityAudioName => 'Audio';

  @override
  String get modalityImageDescription => 'Capacités de traitement d\'image';

  @override
  String get modalityImageName => 'Image';

  @override
  String get modalityTextDescription =>
      'Contenu et traitement basés sur le texte';

  @override
  String get modalityTextName => 'Texte';

  @override
  String get modelAddPageTitle => 'Ajouter un modèle';

  @override
  String get modelEditLoadError =>
      'Échec du chargement de la configuration du modèle';

  @override
  String get modelEditPageTitle => 'Modifier le modèle';

  @override
  String modelManagementSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count modèle$_temp0 sélectionné$_temp1';
  }

  @override
  String get modelsSettingsPageTitle => 'Modèles AI';

  @override
  String get multiSelectAddButton => 'Ajouter';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Ajouter ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'Aucun élément trouvé';

  @override
  String get navTabTitleCalendar => 'DailyOS';

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
  String nestedAiResponsesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count réponse$_temp0 AI';
  }

  @override
  String get noDefaultLanguage => 'Aucune langue par défaut';

  @override
  String get noPromptsAvailable => 'Aucun prompt disponible';

  @override
  String get noPromptsForType => 'Aucun prompt disponible pour ce type';

  @override
  String get noTasksFound => 'Aucune tâche trouvée';

  @override
  String get noTasksToLink => 'Aucune tâche disponible à lier';

  @override
  String get outboxMonitorAttachmentLabel => 'Pièce jointe';

  @override
  String get outboxMonitorDelete => 'supprimer';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Supprimer';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      'Es-tu sûr de vouloir supprimer cet élément de synchronisation ? Cette action est irréversible.';

  @override
  String get outboxMonitorDeleteFailed =>
      'Échec de la suppression. Réessaie s\'il te plaît.';

  @override
  String get outboxMonitorDeleteSuccess => 'Élément supprimé';

  @override
  String get outboxMonitorEmptyDescription =>
      'Il n\'y a aucun élément de synchronisation dans cette vue.';

  @override
  String get outboxMonitorEmptyTitle => 'La boîte d\'envoi est vide';

  @override
  String get outboxMonitorLabelAll => 'tout';

  @override
  String get outboxMonitorLabelError => 'erreur';

  @override
  String get outboxMonitorLabelPending => 'en attente';

  @override
  String get outboxMonitorLabelSent => 'envoyé';

  @override
  String get outboxMonitorLabelSuccess => 'succès';

  @override
  String get outboxMonitorNoAttachment => 'pas de pièce jointe';

  @override
  String get outboxMonitorRetries => 'retries';

  @override
  String get outboxMonitorRetriesLabel => 'Tentatives';

  @override
  String get outboxMonitorRetry => 'réessayer';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Réessayer maintenant';

  @override
  String get outboxMonitorRetryConfirmMessage =>
      'Réessayer cet élément de synchronisation maintenant ?';

  @override
  String get outboxMonitorRetryFailed =>
      'Échec de la nouvelle tentative. Réessaie s\'il te plaît.';

  @override
  String get outboxMonitorRetryQueued => 'Nouvelle tentative programmée';

  @override
  String get outboxMonitorSubjectLabel => 'Sujet';

  @override
  String get outboxMonitorSwitchLabel => 'activé';

  @override
  String get privateLabel => 'Privé';

  @override
  String get promptAddOrRemoveModelsButton =>
      'Ajouter ou supprimer des modèles';

  @override
  String get promptAddPageTitle => 'Ajouter un prompt';

  @override
  String get promptAiResponseTypeDescription => 'Format de la réponse attendue';

  @override
  String get promptAiResponseTypeLabel => 'Type de réponse AI';

  @override
  String get promptBehaviorDescription =>
      'Configurer le traitement et les réponses du prompt';

  @override
  String get promptBehaviorTitle => 'Comportement du prompt';

  @override
  String get promptCancelButton => 'Annuler';

  @override
  String get promptContentDescription =>
      'Définir les prompts système et utilisateur';

  @override
  String get promptContentTitle => 'Contenu du prompt';

  @override
  String get promptDefaultModelBadge => 'Par défaut';

  @override
  String get promptDescriptionHint => 'Décrire ce prompt';

  @override
  String get promptDescriptionLabel => 'Description';

  @override
  String get promptDetailsDescription => 'Informations de base sur ce prompt';

  @override
  String get promptDetailsTitle => 'Détails du prompt';

  @override
  String get promptDisplayNameHint => 'Saisir un nom convivial';

  @override
  String get promptDisplayNameLabel => 'Nom d\'affichage';

  @override
  String get promptEditLoadError => 'Échec du chargement du prompt';

  @override
  String get promptEditPageTitle => 'Modifier le prompt';

  @override
  String get promptErrorLoadingModel => 'Erreur lors du chargement du modèle';

  @override
  String get promptGenerationCardTitle => 'Prompt de codage AI';

  @override
  String get promptGenerationCopiedSnackbar =>
      'Prompt copié dans le presse-papiers';

  @override
  String get promptGenerationCopyButton => 'Copier le prompt';

  @override
  String get promptGenerationCopyTooltip =>
      'Copier le prompt dans le presse-papiers';

  @override
  String get promptGenerationExpandTooltip => 'Afficher le prompt complet';

  @override
  String get promptGenerationFullPromptLabel => 'Prompt complet :';

  @override
  String get promptGoBackButton => 'Retour';

  @override
  String get promptLoadingModel => 'Chargement du modèle...';

  @override
  String get promptModelSelectionDescription =>
      'Choisir des modèles compatibles pour ce prompt';

  @override
  String get promptModelSelectionTitle => 'Sélection du modèle';

  @override
  String get promptNoModelsSelectedError =>
      'Aucun modèle sélectionné. Sélectionne au moins un modèle.';

  @override
  String get promptReasoningModeDescription =>
      'Activer pour les prompts nécessitant une réflexion approfondie';

  @override
  String get promptReasoningModeLabel => 'Mode raisonnement';

  @override
  String get promptRequiredInputDataDescription =>
      'Type de données attendu par ce prompt';

  @override
  String get promptRequiredInputDataLabel => 'Données d\'entrée requises';

  @override
  String get promptSaveButton => 'Enregistrer le prompt';

  @override
  String get promptSelectInputTypeHint => 'Sélectionner le type d\'entrée';

  @override
  String get promptSelectionModalTitle => 'Sélectionner un prompt préconfiguré';

  @override
  String get promptSelectModelsButton => 'Sélectionner des modèles';

  @override
  String get promptSelectResponseTypeHint => 'Sélectionner le type de réponse';

  @override
  String get promptSetDefaultButton => 'Définir par défaut';

  @override
  String get promptSettingsPageTitle => 'Prompts AI';

  @override
  String get promptSystemPromptHint => 'Saisir le prompt système...';

  @override
  String get promptSystemPromptLabel => 'Prompt système';

  @override
  String get promptTryAgainMessage => 'Réessaie ou contacte le support';

  @override
  String get promptUsePreconfiguredButton => 'Utiliser un prompt préconfiguré';

  @override
  String get promptUserPromptHint => 'Saisir le prompt utilisateur...';

  @override
  String get promptUserPromptLabel => 'Prompt utilisateur';

  @override
  String get provisionedSyncConfigureButton => 'Configurer';

  @override
  String get provisionedSyncCopiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get provisionedSyncDisconnect => 'Déconnecter';

  @override
  String get provisionedSyncDone => 'Synchronisation configurée avec succès';

  @override
  String get provisionedSyncError => 'Échec de la configuration';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'Une erreur est survenue lors de la configuration. Réessaie.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'Échec de la connexion. Vérifie tes identifiants et réessaie.';

  @override
  String get provisionedSyncImportButton => 'Importer';

  @override
  String get provisionedSyncImportHint =>
      'Colle le code de provisionnement ici';

  @override
  String get provisionedSyncImportTitle =>
      'Importer la configuration de synchronisation';

  @override
  String get provisionedSyncInvalidBundle => 'Code de provisionnement invalide';

  @override
  String get provisionedSyncJoiningRoom =>
      'Rejoindre la salle de synchronisation...';

  @override
  String get provisionedSyncLoggingIn => 'Connexion en cours...';

  @override
  String get provisionedSyncReady =>
      'Scanne ce code QR sur ton appareil mobile';

  @override
  String get provisionedSyncRetry => 'Réessayer';

  @override
  String get provisionedSyncRotatingPassword => 'Sécurisation du compte...';

  @override
  String get provisionedSyncScanButton => 'Scanner le code QR';

  @override
  String get provisionedSyncShowQr => 'Afficher le QR de provisionnement';

  @override
  String get provisionedSyncSubtitle =>
      'Configurer la synchronisation à partir d\'un paquet de provisionnement';

  @override
  String get provisionedSyncSummaryHomeserver => 'Serveur';

  @override
  String get provisionedSyncSummaryRoom => 'Salle';

  @override
  String get provisionedSyncSummaryUser => 'Utilisateur';

  @override
  String get provisionedSyncTitle => 'Synchronisation provisionnée';

  @override
  String get provisionedSyncVerifyDevicesTitle => 'Vérification des appareils';

  @override
  String get referenceImageContinue => 'Continuer';

  @override
  String referenceImageContinueWithCount(int count) {
    return 'Continuer ($count)';
  }

  @override
  String get referenceImageLoadError =>
      'Échec du chargement des images. Réessaie s\'il te plaît.';

  @override
  String get referenceImageSelectionSubtitle =>
      'Choisissez jusqu\'à 3 images pour guider le style visuel de l\'IA';

  @override
  String get referenceImageSelectionTitle =>
      'Sélectionner des images de référence';

  @override
  String get referenceImageSkip => 'Passer';

  @override
  String get saveButton => 'Enregistrer';

  @override
  String get saveButtonLabel => 'Enregistrer';

  @override
  String get saveLabel => 'Enregistrer';

  @override
  String get saveSuccessful => 'Enregistré avec succès';

  @override
  String get searchHint => 'Rechercher...';

  @override
  String get searchTasksHint => 'Rechercher des tâches...';

  @override
  String get selectAllowedPrompts =>
      'Sélectionner les prompts autorisés pour cette catégorie';

  @override
  String get selectButton => 'Sélectionner';

  @override
  String get selectColor => 'Sélectionner une couleur';

  @override
  String get selectLanguage => 'Sélectionner une langue';

  @override
  String get sessionRatingCardLabel => 'Évaluation de session';

  @override
  String get sessionRatingChallengeJustRight => 'Juste bien';

  @override
  String get sessionRatingChallengeTooEasy => 'Trop facile';

  @override
  String get sessionRatingChallengeTooHard => 'Trop difficile';

  @override
  String get sessionRatingDifficultyLabel => 'Ce travail semblait...';

  @override
  String get sessionRatingEditButton => 'Modifier l\'évaluation';

  @override
  String get sessionRatingEnergyQuestion =>
      'Quel était ton niveau d\'énergie ?';

  @override
  String get sessionRatingFocusQuestion =>
      'Quel était ton niveau de concentration ?';

  @override
  String get sessionRatingNoteHint => 'Note rapide (optionnelle)';

  @override
  String get sessionRatingProductivityQuestion =>
      'Quelle a été la productivité de cette session ?';

  @override
  String get sessionRatingRateAction => 'Évaluer la session';

  @override
  String get sessionRatingSaveButton => 'Enregistrer';

  @override
  String get sessionRatingSaveError =>
      'Impossible d\'enregistrer l\'évaluation. Réessaie s\'il te plaît.';

  @override
  String get sessionRatingSkipButton => 'Passer';

  @override
  String get sessionRatingTitle => 'Évaluer cette session';

  @override
  String get sessionRatingViewAction => 'Voir l\'évaluation';

  @override
  String get settingsAboutAppInformation => 'Informations sur l\'application';

  @override
  String get settingsAboutAppTagline => 'Ton journal personnel';

  @override
  String get settingsAboutBuildType => 'Type de build';

  @override
  String get settingsAboutBuiltWithFlutter =>
      'Développé avec Flutter et amour pour le journaling personnel.';

  @override
  String get settingsAboutCredits => 'Crédits';

  @override
  String get settingsAboutJournalEntries => 'Entrées de journal';

  @override
  String get settingsAboutPlatform => 'Plateforme';

  @override
  String get settingsAboutThankYou => 'Merci d\'utiliser Lotti !';

  @override
  String get settingsAboutTitle => 'À propos de Lotti';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutYourData => 'Tes données';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'En savoir plus sur l\'application Lotti';

  @override
  String get settingsAdvancedConflictsSubtitle =>
      'Résoudre les conflits de synchronisation pour assurer la cohérence des données';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Importer des données liées à la santé depuis des sources externes';

  @override
  String get settingsAdvancedLogsSubtitle =>
      'Accéder et examiner les journaux d\'application pour le débogage';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Effectuer des tâches de maintenance pour optimiser les performances de l\'application';

  @override
  String get settingsAdvancedMatrixSyncSubtitle =>
      'Configurer et gérer les paramètres de synchronisation Matrix';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Afficher et gérer les éléments en attente de synchronisation';

  @override
  String get settingsAdvancedTitle => 'Paramètres avancés';

  @override
  String get settingsAiApiKeys => 'Fournisseurs d\'inférence AI';

  @override
  String get settingsAiModels => 'Modèles AI';

  @override
  String get settingsCategoriesAddTooltip => 'Ajouter une catégorie';

  @override
  String get settingsCategoriesDetailsLabel => 'Détails de la catégorie';

  @override
  String get settingsCategoriesDuplicateError => 'La catégorie existe déjà';

  @override
  String get settingsCategoriesEmptyState => 'Aucune catégorie trouvée';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Crée une catégorie pour organiser tes entrées';

  @override
  String get settingsCategoriesErrorLoading =>
      'Erreur lors du chargement des catégories';

  @override
  String get settingsCategoriesHasAiSettings => 'Paramètres AI';

  @override
  String get settingsCategoriesHasAutomaticPrompts => 'AI automatique';

  @override
  String get settingsCategoriesHasDefaultLanguage => 'Langue par défaut';

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
  String get settingsDashboardDetailsLabel => 'Détails du tableau de bord';

  @override
  String get settingsDashboardSaveLabel => 'Enregistrer';

  @override
  String get settingsDashboardsTitle => 'Gestion du tableau de bord';

  @override
  String get settingsFlagsTitle => 'Flags';

  @override
  String get settingsHabitsDeleteTooltip => 'Supprimer l\'habitude';

  @override
  String get settingsHabitsDescriptionLabel => 'Description (facultatif) :';

  @override
  String get settingsHabitsDetailsLabel => 'Détails de l\'habitude';

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
  String get settingsLabelsActionsTooltip => 'Actions sur les étiquettes';

  @override
  String get settingsLabelsCategoriesAdd => 'Ajouter une catégorie';

  @override
  String get settingsLabelsCategoriesHeading => 'Catégories applicables';

  @override
  String get settingsLabelsCategoriesNone =>
      'S\'applique à toutes les catégories';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Supprimer';

  @override
  String get settingsLabelsColorHeading => 'Sélectionner une couleur';

  @override
  String get settingsLabelsColorSubheading => 'Préréglages rapides';

  @override
  String get settingsLabelsCreateSuccess => 'Étiquette créée avec succès';

  @override
  String get settingsLabelsCreateTitle => 'Créer une étiquette';

  @override
  String get settingsLabelsDeleteCancel => 'Annuler';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Supprimer';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return 'Es-tu sûr de vouloir supprimer « $labelName » ? Les tâches portant cette étiquette perdront l\'attribution.';
  }

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Supprimer l\'étiquette';

  @override
  String settingsLabelsDeleteSuccess(Object labelName) {
    return 'Étiquette « $labelName » supprimée';
  }

  @override
  String get settingsLabelsDescriptionHint =>
      'Expliquer quand appliquer cette étiquette';

  @override
  String get settingsLabelsDescriptionLabel => 'Description (optionnel)';

  @override
  String get settingsLabelsEditTitle => 'Modifier l\'étiquette';

  @override
  String get settingsLabelsEmptyState => 'Aucune étiquette pour le moment';

  @override
  String get settingsLabelsEmptyStateHint =>
      'Appuie sur le bouton + pour créer ta première étiquette.';

  @override
  String get settingsLabelsErrorLoading => 'Échec du chargement des étiquettes';

  @override
  String get settingsLabelsNameHint => 'Bug, Bloquant, Synchronisation…';

  @override
  String get settingsLabelsNameLabel => 'Nom de l\'étiquette';

  @override
  String get settingsLabelsNameRequired =>
      'Le nom de l\'étiquette ne peut pas être vide.';

  @override
  String get settingsLabelsPrivateDescription =>
      'Les étiquettes privées n\'apparaissent que lorsque « Afficher les entrées privées » est activé.';

  @override
  String get settingsLabelsPrivateTitle => 'Étiquette privée';

  @override
  String get settingsLabelsSearchHint => 'Rechercher des étiquettes…';

  @override
  String get settingsLabelsSubtitle =>
      'Organiser les tâches avec des étiquettes colorées';

  @override
  String get settingsLabelsTitle => 'Étiquettes';

  @override
  String get settingsLabelsUpdateSuccess => 'Étiquette mise à jour';

  @override
  String settingsLabelsUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches',
      one: '1 tâche',
    );
    return 'Utilisée sur $_temp0';
  }

  @override
  String get settingsLogsTitle => 'Logs';

  @override
  String get settingsMaintenanceTitle => 'Maintenance';

  @override
  String get settingsMatrixAccept => 'Accepter';

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
  String get settingsMatrixCount => 'Nombre';

  @override
  String get settingsMatrixDeleteLabel => 'Supprimer';

  @override
  String get settingsMatrixDiagnosticCopied =>
      'Informations de diagnostic copiées dans le presse-papiers';

  @override
  String get settingsMatrixDiagnosticCopyButton =>
      'Copier dans le presse-papiers';

  @override
  String get settingsMatrixDiagnosticDialogTitle =>
      'Informations de diagnostic de synchronisation';

  @override
  String get settingsMatrixDiagnosticShowButton =>
      'Afficher les informations de diagnostic';

  @override
  String get settingsMatrixDone => 'Terminé';

  @override
  String get settingsMatrixEnterValidUrl => 'Entre une URL valide';

  @override
  String get settingsMatrixHomeserverConfigTitle =>
      'Configuration du serveur principal Matrix';

  @override
  String get settingsMatrixHomeServerLabel => 'Serveur principal';

  @override
  String get settingsMatrixLastUpdated => 'Dernière mise à jour :';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Appareils non vérifiés';

  @override
  String get settingsMatrixLoginButtonLabel => 'Connexion';

  @override
  String get settingsMatrixLoginFailed => 'Échec de la connexion';

  @override
  String get settingsMatrixLogoutButtonLabel => 'Déconnexion';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Exécuter les tâches de maintenance Matrix et les outils de récupération';

  @override
  String get settingsMatrixMaintenanceTitle => 'Maintenance';

  @override
  String get settingsMatrixMessageType => 'Type de message';

  @override
  String get settingsMatrixMetric => 'Métrique';

  @override
  String get settingsMatrixMetrics => 'Métriques de synchronisation';

  @override
  String get settingsMatrixMetricsNoData =>
      'Métriques de synchronisation : aucune donnée';

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
  String get settingsMatrixRefresh => 'Actualiser';

  @override
  String get settingsMatrixRoomConfigTitle =>
      'Configuration de la salle de synchronisation Matrix';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Invitation au salon $roomId de $senderId. Accepter ?';
  }

  @override
  String get settingsMatrixRoomInviteTitle => 'Invitation au salon';

  @override
  String get settingsMatrixSentMessagesLabel => 'Messages envoyés :';

  @override
  String get settingsMatrixStartVerificationLabel => 'Démarrer la vérification';

  @override
  String get settingsMatrixStatsTitle => 'Statistiques Matrix';

  @override
  String get settingsMatrixSubtitle =>
      'Configurer la synchronisation chiffrée de bout en bout';

  @override
  String get settingsMatrixTitle => 'Paramètres de synchronisation Matrix';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Appareils non vérifiés';

  @override
  String get settingsMatrixUserLabel => 'Utilisateur';

  @override
  String get settingsMatrixUserNameTooShort => 'Nom d\'utilisateur trop court';

  @override
  String get settingsMatrixValue => 'Valeur';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Annulé sur un autre appareil…';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'OK';

  @override
  String settingsMatrixVerificationSuccessLabel(
      String deviceName, String deviceID) {
    return 'Tu as vérifié avec succès $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Confirme sur l\'autre appareil que les émojis ci-dessous sont affichés sur les deux appareils, dans le même ordre :';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Confirme que les émojis ci-dessous sont affichés sur les deux appareils, dans le même ordre :';

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
  String get settingsMeasurableDetailsLabel => 'Détails du mesurable';

  @override
  String get settingsMeasurableFavoriteLabel => 'Préféré :';

  @override
  String get settingsMeasurableNameLabel => 'Nom de la mesure :';

  @override
  String get settingsMeasurablePrivateLabel => 'Privé :';

  @override
  String get settingsMeasurableSaveLabel => 'Enregistrer';

  @override
  String get settingsMeasurablesTitle => 'Types de données mesurables';

  @override
  String get settingsMeasurableUnitLabel => 'Abréviation d\'unité :';

  @override
  String get settingsResetGeminiConfirm => 'Réinitialiser';

  @override
  String get settingsResetGeminiConfirmQuestion =>
      'Cela affichera à nouveau le dialogue de configuration Gemini. Continuer?';

  @override
  String get settingsResetGeminiSubtitle =>
      'Afficher à nouveau le dialogue de configuration Gemini AI';

  @override
  String get settingsResetGeminiTitle =>
      'Réinitialiser le dialogue de configuration Gemini';

  @override
  String get settingsResetHintsConfirm => 'Confirmer';

  @override
  String get settingsResetHintsConfirmQuestion =>
      'Réinitialiser les astuces dans l\'application ?';

  @override
  String settingsResetHintsResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count astuces réinitialisées',
      one: 'Une astuce réinitialisée',
      zero: 'Aucune astuce réinitialisée',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetHintsSubtitle =>
      'Effacer les conseils ponctuels et les astuces d\'introduction';

  @override
  String get settingsResetHintsTitle =>
      'Réinitialiser les astuces de l\'application';

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
  String get settingsSyncStatsSubtitle =>
      'Inspecter les métriques du pipeline de synchronisation';

  @override
  String get settingsSyncSubtitle =>
      'Configurer la synchronisation et voir les statistiques';

  @override
  String get settingsTagsDeleteTooltip => 'Supprimer étiquette';

  @override
  String get settingsTagsDetailsLabel => 'Détails des tags';

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
  String get settingThemingDark => 'Thème sombre';

  @override
  String get settingThemingLight => 'Thème clair';

  @override
  String get showCompleted => 'Afficher les terminées';

  @override
  String get speechDictionaryHelper =>
      'Termes séparés par des points-virgules (max 50 caractères) pour une meilleure reconnaissance vocale';

  @override
  String get speechDictionaryHint => 'macOS; Kirkjubæjarklaustur; Claude Code';

  @override
  String get speechDictionaryLabel => 'Dictionnaire vocal';

  @override
  String get speechDictionarySectionDescription =>
      'Ajoute des termes souvent mal transcrits par la reconnaissance vocale (noms, lieux, termes techniques)';

  @override
  String get speechDictionarySectionTitle => 'Reconnaissance vocale';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Un grand dictionnaire ($count termes) peut augmenter les coûts API';
  }

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
  String get syncCreateNewRoom => 'Créer une nouvelle salle';

  @override
  String get syncCreateNewRoomInstead => 'Créer une nouvelle salle à la place';

  @override
  String get syncDeleteConfigConfirm => 'OUI, JE SUIS SÛR';

  @override
  String get syncDeleteConfigQuestion =>
      'Veux-tu supprimer la configuration de synchronisation ?';

  @override
  String get syncDiscoveringRooms =>
      'Recherche des salles de synchronisation...';

  @override
  String get syncDiscoverRoomsButton => 'Découvrir les salles existantes';

  @override
  String get syncDiscoveryError => 'Échec de la découverte des salles';

  @override
  String get syncEntitiesConfirm => 'DÉMARRER LA SYNCHRONISATION';

  @override
  String get syncEntitiesMessage => 'Choisis les données à synchroniser.';

  @override
  String get syncEntitiesSuccessDescription => 'Tout est à jour.';

  @override
  String get syncEntitiesSuccessTitle => 'Synchronisation terminée';

  @override
  String get syncInviteErrorForbidden =>
      'Permission refusée. Tu n\'as peut-être pas accès pour inviter cet utilisateur.';

  @override
  String get syncInviteErrorNetwork =>
      'Erreur réseau. Vérifie ta connexion et réessaie.';

  @override
  String get syncInviteErrorRateLimited =>
      'Trop de requêtes. Patiente un moment et réessaie.';

  @override
  String get syncInviteErrorUnknown =>
      'Échec de l\'envoi de l\'invitation. Réessaie plus tard.';

  @override
  String get syncInviteErrorUserNotFound =>
      'Utilisateur non trouvé. Vérifie que le code scanné est correct.';

  @override
  String syncListCountSummary(String label, int itemCount) {
    String _temp0 = intl.Intl.pluralLogic(
      itemCount,
      locale: localeName,
      other: '$itemCount éléments',
      one: '1 élément',
      zero: '0 éléments',
    );
    return '$label · $_temp0';
  }

  @override
  String get syncListPayloadKindLabel => 'Contenu';

  @override
  String get syncListUnknownPayload => 'Contenu inconnu';

  @override
  String get syncNoRoomsFound =>
      'Aucune salle de synchronisation trouvée.\nTu peux créer une nouvelle salle pour commencer la synchronisation.';

  @override
  String get syncNotLoggedInToast => 'La synchronisation n\'est pas connectée';

  @override
  String get syncPayloadAiConfig => 'Configuration AI';

  @override
  String get syncPayloadAiConfigDelete => 'Suppression de configuration AI';

  @override
  String get syncPayloadBackfillRequest => 'Demande de rattrapage';

  @override
  String get syncPayloadBackfillResponse => 'Réponse de rattrapage';

  @override
  String get syncPayloadEntityDefinition => 'Définition d\'entité';

  @override
  String get syncPayloadEntryLink => 'Lien d\'entrée';

  @override
  String get syncPayloadJournalEntity => 'Entrée de journal';

  @override
  String get syncPayloadTagEntity => 'Entité de tag';

  @override
  String get syncPayloadThemingSelection => 'Sélection de thème';

  @override
  String get syncRetry => 'Réessayer';

  @override
  String get syncRoomCreatedUnknown => 'Inconnu';

  @override
  String get syncRoomDiscoveryTitle =>
      'Rechercher une salle de synchronisation existante';

  @override
  String get syncRoomHasContent => 'Contient des données';

  @override
  String get syncRoomUnnamed => 'Salle sans nom';

  @override
  String get syncRoomVerified => 'Vérifié';

  @override
  String get syncSelectRoom => 'Sélectionner une salle de synchronisation';

  @override
  String get syncSelectRoomDescription =>
      'Nous avons trouvé des salles de synchronisation existantes. Sélectionnes-en une pour la rejoindre ou crée une nouvelle salle.';

  @override
  String get syncSkip => 'Ignorer';

  @override
  String get syncStepAiSettings => 'Paramètres IA';

  @override
  String get syncStepCategories => 'Catégories';

  @override
  String get syncStepComplete => 'Terminé';

  @override
  String get syncStepDashboards => 'Tableaux de bord';

  @override
  String get syncStepHabits => 'Habitudes';

  @override
  String get syncStepLabels => 'Étiquettes';

  @override
  String get syncStepMeasurables => 'Mesurables';

  @override
  String get syncStepTags => 'Tags';

  @override
  String get taskCategoryAllLabel => 'tout';

  @override
  String get taskCategoryLabel => 'Catégorie :';

  @override
  String get taskCategoryUnassignedLabel => 'non attribué';

  @override
  String get taskDueDateLabel => 'Date d\'échéance';

  @override
  String taskDueDateWithDate(String date) {
    return 'Échéance : $date';
  }

  @override
  String taskDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return 'Échéance dans $_temp0';
  }

  @override
  String get taskDueToday => 'Échéance aujourd\'hui';

  @override
  String get taskDueTomorrow => 'Échéance demain';

  @override
  String get taskDueYesterday => 'Échéance hier';

  @override
  String get taskEstimateLabel => 'Temps estimé :';

  @override
  String get taskLabelUnassignedLabel => 'non attribué';

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
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageIndonesian => 'Indonésien';

  @override
  String get taskLanguageItalian => 'Italien';

  @override
  String get taskLanguageJapanese => 'Japonais';

  @override
  String get taskLanguageKorean => 'Coréen';

  @override
  String get taskLanguageLabel => 'Langue :';

  @override
  String get taskLanguageLatvian => 'Letton';

  @override
  String get taskLanguageLithuanian => 'Lituanien';

  @override
  String get taskLanguageNigerianPidgin => 'Pidgin nigérian';

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
  String get taskLanguageSearchPlaceholder => 'Rechercher des langues...';

  @override
  String get taskLanguageSelectedLabel => 'Langue actuelle';

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
  String get taskLanguageTurkish => 'Turc';

  @override
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageUkrainian => 'Ukrainien';

  @override
  String get taskLanguageVietnamese => 'Vietnamien';

  @override
  String get taskLanguageYoruba => 'Yoruba';

  @override
  String get taskNameHint => 'Saisissez un nom pour la tâche';

  @override
  String get taskNoDueDateLabel => 'Pas de date d\'échéance';

  @override
  String get taskNoEstimateLabel => 'Sans estimation';

  @override
  String taskOverdueByDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return 'En retard de $_temp0';
  }

  @override
  String get tasksAddLabelButton => 'Ajouter une étiquette';

  @override
  String get tasksFilterTitle => 'Filtre des tâches';

  @override
  String get tasksLabelFilterAll => 'Toutes';

  @override
  String get tasksLabelFilterTitle => 'Étiquettes';

  @override
  String get tasksLabelFilterUnlabeled => 'Sans étiquette';

  @override
  String get tasksLabelsDialogClose => 'Fermer';

  @override
  String get tasksLabelsHeaderEditTooltip => 'Modifier les étiquettes';

  @override
  String get tasksLabelsHeaderTitle => 'Étiquettes';

  @override
  String get tasksLabelsNoLabels => 'Aucune étiquette';

  @override
  String get tasksLabelsSheetApply => 'Appliquer';

  @override
  String get tasksLabelsSheetSearchHint => 'Rechercher des étiquettes…';

  @override
  String get tasksLabelsSheetTitle => 'Sélectionner des étiquettes';

  @override
  String get tasksLabelsUpdateFailed =>
      'Échec de la mise à jour des étiquettes';

  @override
  String get tasksPriorityFilterAll => 'Toutes';

  @override
  String get tasksPriorityFilterTitle => 'Priorité';

  @override
  String get tasksPriorityP0 => 'Urgente';

  @override
  String get tasksPriorityP0Description => 'Urgente (Dès que possible)';

  @override
  String get tasksPriorityP1 => 'Haute';

  @override
  String get tasksPriorityP1Description => 'Haute (Bientôt)';

  @override
  String get tasksPriorityP2 => 'Moyenne';

  @override
  String get tasksPriorityP2Description => 'Moyenne (Par défaut)';

  @override
  String get tasksPriorityP3 => 'Basse';

  @override
  String get tasksPriorityP3Description => 'Basse (Quand possible)';

  @override
  String get tasksPriorityPickerTitle => 'Sélectionner la priorité';

  @override
  String get tasksPriorityTitle => 'Priorité :';

  @override
  String get tasksQuickFilterClear => 'Effacer';

  @override
  String get tasksQuickFilterLabelsActiveTitle =>
      'Filtres d\'étiquettes actifs';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Non attribué';

  @override
  String get tasksShowCoverArt => 'Afficher la couverture sur les cartes';

  @override
  String get tasksShowCreationDate =>
      'Afficher la date de création sur les cartes';

  @override
  String get tasksShowDueDate => 'Afficher la date d\'échéance sur les cartes';

  @override
  String get tasksSortByCreationDate => 'Création';

  @override
  String get tasksSortByDate => 'Date';

  @override
  String get tasksSortByDueDate => 'Échéance';

  @override
  String get tasksSortByLabel => 'Trier par';

  @override
  String get tasksSortByPriority => 'Priorité';

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
  String get taskSummaries => 'Résumés de tâches';

  @override
  String get timeByCategoryChartTitle => 'Temps par catégorie';

  @override
  String get timeByCategoryChartTotalLabel => 'Total';

  @override
  String get unlinkButton => 'Délier';

  @override
  String get unlinkTaskConfirm => 'Es-tu sûr de vouloir délier cette tâche ?';

  @override
  String get unlinkTaskTitle => 'Délier la tâche';

  @override
  String get viewMenuTitle => 'Affichage';

  @override
  String get whatsNewDoneButton => 'Terminé';

  @override
  String get whatsNewSkipButton => 'Ignorer';
}

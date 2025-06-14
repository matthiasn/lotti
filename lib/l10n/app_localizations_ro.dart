// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get addActionAddAudioRecording => 'Adauga inregistrare audio';

  @override
  String get addActionAddChecklist => 'Listă de verificare';

  @override
  String get addActionAddEvent => 'Eveniment';

  @override
  String get addActionAddImageFromClipboard => 'Lipește imagine';

  @override
  String get addActionAddPhotos => 'Adauga fotografie';

  @override
  String get addActionAddScreenshot => 'Adauga captura de ecran';

  @override
  String get addActionAddTask => 'Adauga sarcina';

  @override
  String get addActionAddText => 'Adauga text';

  @override
  String get addActionAddTimeRecording => 'Adauga timp';

  @override
  String get addAudioTitle => 'Adauga titlu';

  @override
  String get addHabitCommentLabel => 'Comentariu';

  @override
  String get addHabitDateLabel => 'Finalizat la';

  @override
  String get addMeasurementCommentLabel => 'Comentariu';

  @override
  String get addMeasurementDateLabel => 'Observat la';

  @override
  String get addMeasurementSaveButton => 'Salveaza masuratoare';

  @override
  String get addSurveyTitle => 'Titlu sondaj';

  @override
  String get aiAssistantActionItemSuggestions => 'Sugestii de acțiuni';

  @override
  String get aiAssistantAnalyzeImage => 'Analizează imaginea';

  @override
  String get aiAssistantSummarizeTask => 'Rezumă sarcina';

  @override
  String get aiAssistantThinking => 'Se gândește...';

  @override
  String get aiAssistantTitle => 'Asistent AI';

  @override
  String get aiAssistantTranscribeAudio => 'Transcrie audio';

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
  String get aiConfigListCascadeDeleteWarning => 'This will also delete all models associated with this provider.';

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
  String get aiConfigProviderDeletedSuccessfully => 'Provider deleted successfully';

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
  String get aiTaskSummaryRunning => 'Se gândește la rezumarea sarcinii...';

  @override
  String get aiTaskSummaryTitle => 'Rezumatul sarcinii AI';

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
  String get cancelButton => 'Anulează';

  @override
  String get categoryDeleteConfirm => 'DA, ȘTERGE ACEASTĂ CATEGORIE';

  @override
  String get categoryDeleteQuestion => 'Doriți să ștergeți această categorie?';

  @override
  String get categorySearchPlaceholder => 'Caută categorii...';

  @override
  String get checklistAddItem => 'Adaugă un element nou';

  @override
  String get checklistDelete => 'Șterge lista de verificare?';

  @override
  String get checklistItemDelete => 'Șterge elementul din lista de verificare?';

  @override
  String get checklistItemDeleteCancel => 'Anulează';

  @override
  String get checklistItemDeleteConfirm => 'Confirmă';

  @override
  String get checklistItemDeleteWarning => 'Această acțiune nu poate fi anulată.';

  @override
  String get checklistItemDrag => 'Trage sugestiile în lista de verificare';

  @override
  String get checklistNoSuggestionsTitle => 'Nu există sugestii de acțiuni';

  @override
  String get checklistsTitle => 'Liste de verificare';

  @override
  String get checklistSuggestionsOutdated => 'Depășite';

  @override
  String get checklistSuggestionsRunning => 'Se gândește la sugestii netrimise...';

  @override
  String get checklistSuggestionsTitle => 'Sugestii de acțiuni';

  @override
  String get colorLabel => 'Culoare:';

  @override
  String get colorPickerError => 'Culoare Hex invalidă';

  @override
  String get colorPickerHint => 'Introduceți culoarea Hex sau alegeți';

  @override
  String get completeHabitFailButton => 'Eșec';

  @override
  String get completeHabitSkipButton => 'Sari peste';

  @override
  String get completeHabitSuccessButton => 'Succes';

  @override
  String get configFlagAttemptEmbeddingDescription => 'Când este activată, aplicația va încerca să genereze încorporări pentru intrările dvs. pentru a îmbunătăți căutarea și sugestiile de conținut corelat.';

  @override
  String get configFlagAutoTranscribeDescription => 'Transcrie automat înregistrările audio din intrările dvs. Acest lucru necesită o conexiune la internet.';

  @override
  String get configFlagEnableAutoTaskTldrDescription => 'Generează automat rezumate pentru sarcinile dvs. pentru a vă ajuta să înțelegeți rapid starea lor.';

  @override
  String get configFlagEnableCalendarPageDescription => 'Afișează pagina Calendar în navigarea principală. Vizualizați și gestionați-vă intrările într-o vizualizare calendaristică.';

  @override
  String get configFlagEnableDashboardsPageDescription => 'Afișează pagina Tablouri de bord în navigarea principală. Vizualizați datele și informațiile dvs. în tablouri de bord personalizabile.';

  @override
  String get configFlagEnableHabitsPageDescription => 'Afișează pagina Obiceiuri în navigarea principală. Urmăriți și gestionați-vă obiceiurile zilnice aici.';

  @override
  String get configFlagEnableLoggingDescription => 'Activează înregistrarea detaliată pentru depanare. Acest lucru poate afecta performanța.';

  @override
  String get configFlagEnableMatrixDescription => 'Activează integrarea Matrix pentru a sincroniza intrările dvs. pe diferite dispozitive și cu alți utilizatori Matrix.';

  @override
  String get configFlagEnableNotifications => 'Activează notificările pe desktop?';

  @override
  String get configFlagEnableNotificationsDescription => 'Primiți notificări pentru mementouri, actualizări și evenimente importante.';

  @override
  String get configFlagEnableTooltipDescription => 'Afișează sfaturi utile în întreaga aplicație pentru a vă ghida prin funcții.';

  @override
  String get configFlagPrivate => 'Arată articolele private?';

  @override
  String get configFlagPrivateDescription => 'Activați această opțiune pentru a face intrările dvs. private în mod implicit. Intrările private sunt vizibile numai pentru dvs.';

  @override
  String get configFlagRecordLocationDescription => 'Înregistrează automat locația dvs. cu intrări noi. Acest lucru ajută la organizarea și căutarea pe baza locației.';

  @override
  String get configFlagResendAttachmentsDescription => 'Activați această opțiune pentru a retrimite automat încărcările de atașamente eșuate atunci când conexiunea este restabilită.';

  @override
  String get configFlagUseCloudInferenceDescription => 'Utilizați servicii AI bazate pe cloud pentru funcții îmbunătățite. Acest lucru necesită o conexiune la internet.';

  @override
  String get conflictsResolved => 'rezolvat';

  @override
  String get conflictsUnresolved => 'nerezolvat';

  @override
  String get createCategoryTitle => 'Creați categorie:';

  @override
  String get createEntryLabel => 'Creați o intrare nouă';

  @override
  String get createEntryTitle => 'Adaugă';

  @override
  String get dashboardActiveLabel => 'Activ:';

  @override
  String get dashboardAddChartsTitle => 'Adaugă diagramă:';

  @override
  String get dashboardAddHabitButton => 'Diagrame de obiceiuri';

  @override
  String get dashboardAddHabitTitle => 'Diagrame de obiceiuri';

  @override
  String get dashboardAddHealthButton => 'Bord de sănătate';

  @override
  String get dashboardAddHealthTitle => 'Bord de sănătate';

  @override
  String get dashboardAddMeasurementButton => 'Bord de măsurătoari';

  @override
  String get dashboardAddMeasurementTitle => 'Bord de măsurătoari';

  @override
  String get dashboardAddSurveyButton => 'Diagrame de Studiu';

  @override
  String get dashboardAddSurveyTitle => 'Diagrame de Studiu';

  @override
  String get dashboardAddWorkoutButton => 'Bord de Antrenament';

  @override
  String get dashboardAddWorkoutTitle => 'Bord de Antrenament';

  @override
  String get dashboardAggregationLabel => 'Agregare';

  @override
  String get dashboardCategoryLabel => 'Categorie:';

  @override
  String get dashboardCopyHint => 'Salvează și copiază configurația tabloului de bord';

  @override
  String get dashboardDeleteConfirm => 'DA, ȘTERGE ACEST TABLOU DE BORD';

  @override
  String get dashboardDeleteHint => 'Șterge tablou de bord';

  @override
  String get dashboardDeleteQuestion => 'Vrei să ștergi acest tablou de bord?';

  @override
  String get dashboardDescriptionLabel => 'Descriere:';

  @override
  String get dashboardNameLabel => 'Numele tabloului de bord:';

  @override
  String get dashboardNotFound => 'Tablou de bord negasit';

  @override
  String get dashboardPrivateLabel => 'Privat:';

  @override
  String get done => 'Done';

  @override
  String get doneButton => 'Gata';

  @override
  String get editMenuTitle => 'Editează';

  @override
  String get editorPlaceholder => 'Introduceți notițe...';

  @override
  String get entryActions => 'Acțiuni';

  @override
  String get eventNameLabel => 'Eveniment:';

  @override
  String get fileMenuNewEllipsis => 'Nou ...';

  @override
  String get fileMenuNewEntry => 'Intrare nouă';

  @override
  String get fileMenuNewScreenshot => 'Captură de ecran';

  @override
  String get fileMenuNewTask => 'Sarcină';

  @override
  String get fileMenuTitle => 'Fișier';

  @override
  String get habitActiveFromLabel => 'Data de început';

  @override
  String get habitArchivedLabel => 'Arhivat:';

  @override
  String get habitCategoryHint => 'Selectați categoria...';

  @override
  String get habitCategoryLabel => 'Categorie:';

  @override
  String get habitDashboardHint => 'Selectați tabloul de bord...';

  @override
  String get habitDashboardLabel => 'Tablou de bord:';

  @override
  String get habitDeleteConfirm => 'DA, ȘTERGEȚI ACEST OBICEI';

  @override
  String get habitDeleteQuestion => 'Doriți să ștergeți acest obicei?';

  @override
  String get habitPriorityLabel => 'Prioritate:';

  @override
  String get habitsCompletedHeader => 'Finalizate';

  @override
  String get habitsFilterAll => 'toate';

  @override
  String get habitsFilterCompleted => 'finalizate';

  @override
  String get habitsFilterOpenNow => 'scadente';

  @override
  String get habitsFilterPendingLater => 'mai târziu';

  @override
  String get habitShowAlertAtLabel => 'Afișați alerta la';

  @override
  String get habitShowFromLabel => 'Afișați de la';

  @override
  String get habitsOpenHeader => 'Scadente acum';

  @override
  String get habitsPendingLaterHeader => 'Mai târziu astăzi';

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
  String get journalCopyImageLabel => 'Copiați imaginea';

  @override
  String get journalDateFromLabel => 'De la:';

  @override
  String get journalDateInvalid => 'Dată invalidă';

  @override
  String get journalDateNowButton => 'acum';

  @override
  String get journalDateSaveButton => 'SALVEAZĂ';

  @override
  String get journalDateToLabel => 'Până la:';

  @override
  String get journalDeleteConfirm => 'DA, ȘTERGE ACEASTĂ INTRARE';

  @override
  String get journalDeleteHint => 'Șterge intrare';

  @override
  String get journalDeleteQuestion => 'Vrei să ștergi această intrare în jurnal?';

  @override
  String get journalDurationLabel => 'Durată:';

  @override
  String get journalFavoriteTooltip => 'Favorit';

  @override
  String get journalFlaggedTooltip => 'Marcat';

  @override
  String get journalHideMapHint => 'Ascunde harta';

  @override
  String get journalLinkedEntriesAiLabel => 'Afișați intrările generate de AI:';

  @override
  String get journalLinkedEntriesHiddenLabel => 'Afișați intrările ascunse:';

  @override
  String get journalLinkedEntriesLabel => 'Legat:';

  @override
  String get journalLinkedFromLabel => 'Legat de la:';

  @override
  String get journalLinkFromHint => 'Legătură de la';

  @override
  String get journalLinkToHint => 'Legătură la';

  @override
  String get journalPrivateTooltip => 'Privat';

  @override
  String get journalSearchHint => 'Cautare jurnal...';

  @override
  String get journalShareAudioHint => 'Împarte audio';

  @override
  String get journalSharePhotoHint => 'Împarte foto';

  @override
  String get journalShowMapHint => 'Arată harta';

  @override
  String get journalTagPlusHint => 'Gestionează etichetele intrării';

  @override
  String get journalTagsCopyHint => 'Copiază etichete';

  @override
  String get journalTagsLabel => 'Etichete:';

  @override
  String get journalTagsPasteHint => 'Lipește etichete';

  @override
  String get journalTagsRemoveHint => 'Înlătură eticheta';

  @override
  String get journalToggleFlaggedTitle => 'Marcate';

  @override
  String get journalTogglePrivateTitle => 'Private';

  @override
  String get journalToggleStarredTitle => 'Favorite';

  @override
  String get journalUnlinkConfirm => 'DA, DESPĂRȚIȚI INTRAREA';

  @override
  String get journalUnlinkHint => 'Despărțiți';

  @override
  String get journalUnlinkQuestion => 'Sigur doriți să despărțiți această intrare?';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'YES, DELETE DATABASE';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Are you sure you want to delete $databaseName Database?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Șterge ciornele din baza de date';

  @override
  String get maintenanceDeleteLoggingDb => 'Șterge log-urile din baza de date';

  @override
  String get maintenanceDeleteSyncDb => 'Ștergeți baza de date de sincronizare';

  @override
  String get maintenancePurgeAudioModels => 'Eliminați modelele audio';

  @override
  String get maintenancePurgeAudioModelsMessage => 'Are you sure you want to purge all audio models? This action cannot be undone.';

  @override
  String get maintenancePurgeAudioModelsConfirm => 'YES, PURGE MODELS';

  @override
  String get maintenancePurgeDeleted => 'Eliminați elementele șterse';

  @override
  String get maintenancePurgeDeletedConfirm => 'Yes, purge all';

  @override
  String get maintenancePurgeDeletedMessage => 'Are you sure you want to purge all deleted items? This action cannot be undone.';

  @override
  String get maintenanceRecreateFts5 => 'Recreați indexul full-text';

  @override
  String get maintenanceRecreateFts5Message => 'Are you sure you want to recreate the full-text index? This may take some time.';

  @override
  String get maintenanceRecreateFts5Confirm => 'YES, RECREATE INDEX';

  @override
  String get maintenanceReSync => 'Resincronizați mesajele';

  @override
  String get maintenanceSyncDefinitions => 'Sync tags, measurables, dashboards, habits, categories';

  @override
  String get measurableDeleteConfirm => 'DA, CONFIRM STERGEREA';

  @override
  String get measurableDeleteQuestion => 'Vrei sa stergi acest tip de masuratoare?';

  @override
  String get measurableNotFound => 'Masuratoarea nu a fost gasita';

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
  String get navTabTitleHabits => 'Obiceiuri';

  @override
  String get navTabTitleInsights => 'Informaţii';

  @override
  String get navTabTitleJournal => 'Jurnal';

  @override
  String get navTabTitleSettings => 'Setări';

  @override
  String get navTabTitleTasks => 'Sarcini';

  @override
  String get outboxMonitorLabelAll => 'toate';

  @override
  String get outboxMonitorLabelError => 'eroare';

  @override
  String get outboxMonitorLabelPending => 'în așteptare';

  @override
  String get outboxMonitorLabelSent => 'trimis';

  @override
  String get outboxMonitorNoAttachment => 'fără atașament';

  @override
  String get outboxMonitorRetries => 'reîncercare';

  @override
  String get outboxMonitorRetry => 'reincercare';

  @override
  String get outboxMonitorSwitchLabel => 'pornit';

  @override
  String get promptAddPageTitle => 'Add Prompt';

  @override
  String get promptEditLoadError => 'Failed to load prompt';

  @override
  String get promptEditPageTitle => 'Edit Prompt';

  @override
  String get promptSettingsPageTitle => 'AI Prompts';

  @override
  String get promptSelectionModalTitle => 'Select Preconfigured Prompt';

  @override
  String get promptUsePreconfiguredButton => 'Use Preconfigured Prompt';

  @override
  String get promptDetailsTitle => 'Prompt Details';

  @override
  String get promptDetailsDescription => 'Basic information about this prompt';

  @override
  String get promptContentTitle => 'Prompt Content';

  @override
  String get promptContentDescription => 'Define the system and user prompts';

  @override
  String get promptBehaviorTitle => 'Prompt Behavior';

  @override
  String get promptBehaviorDescription => 'Configure how the prompt processes and responds';

  @override
  String get promptModelSelectionTitle => 'Model Selection';

  @override
  String get promptModelSelectionDescription => 'Choose compatible models for this prompt';

  @override
  String get promptDisplayNameLabel => 'Display Name';

  @override
  String get promptDisplayNameHint => 'Enter a friendly name';

  @override
  String get promptDescriptionLabel => 'Description';

  @override
  String get promptDescriptionHint => 'Describe this prompt';

  @override
  String get promptSystemPromptLabel => 'System Prompt';

  @override
  String get promptSystemPromptHint => 'Enter the system prompt...';

  @override
  String get promptUserPromptLabel => 'User Prompt';

  @override
  String get promptUserPromptHint => 'Enter the user prompt...';

  @override
  String get promptRequiredInputDataLabel => 'Required Input Data';

  @override
  String get promptRequiredInputDataDescription => 'Type of data this prompt expects';

  @override
  String get promptSelectInputTypeHint => 'Select input type';

  @override
  String get promptAiResponseTypeLabel => 'AI Response Type';

  @override
  String get promptAiResponseTypeDescription => 'Format of the expected response';

  @override
  String get promptSelectResponseTypeHint => 'Select response type';

  @override
  String get promptReasoningModeLabel => 'Reasoning Mode';

  @override
  String get promptReasoningModeDescription => 'Enable for prompts requiring deep thinking';

  @override
  String get promptCancelButton => 'Cancel';

  @override
  String get promptSaveButton => 'Save Prompt';

  @override
  String get promptNoModelsSelectedError => 'No models selected. Select at least one model.';

  @override
  String get promptAddOrRemoveModelsButton => 'Add or Remove Models';

  @override
  String get promptSelectModelsButton => 'Select Models';

  @override
  String get promptDefaultModelBadge => 'Default';

  @override
  String get promptSetDefaultButton => 'Set Default';

  @override
  String get promptLoadingModel => 'Loading model...';

  @override
  String get promptErrorLoadingModel => 'Error loading model';

  @override
  String get promptGoBackButton => 'Go Back';

  @override
  String get promptTryAgainMessage => 'Please try again or contact support';

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
  String get enhancedPromptFormDescription => 'Create custom prompts that can be used with your AI models to generate specific types of responses';

  @override
  String get enhancedPromptFormQuickStartTitle => 'Quick Start';

  @override
  String get enhancedPromptFormQuickStartDescription => 'Start with a pre-built template to save time';

  @override
  String get enhancedPromptFormBasicConfigurationTitle => 'Basic Configuration';

  @override
  String get enhancedPromptFormPromptConfigurationTitle => 'Prompt Configuration';

  @override
  String get enhancedPromptFormConfigurationOptionsTitle => 'Configuration Options';

  @override
  String get enhancedPromptFormAdditionalDetailsTitle => 'Additional Details';

  @override
  String get enhancedPromptFormDisplayNameHelperText => 'A descriptive name for this prompt template';

  @override
  String get enhancedPromptFormUserMessageHelperText => 'The main prompt text.';

  @override
  String get enhancedPromptFormSystemMessageHelperText => 'Instructions that define the AI\'s behavior and response style';

  @override
  String get enhancedPromptFormDescriptionHelperText => 'Optional notes about this prompt\'s purpose and usage';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription => 'Choose from ready-made prompt templates';

  @override
  String get enhancedPromptFormRequiredInputDataSubtitle => 'Type of data this prompt expects';

  @override
  String get enhancedPromptFormAiResponseTypeSubtitle => 'Format of the expected response';

  @override
  String get aiSettingsPageTitle => 'AI Settings';

  @override
  String get aiSettingsNoProvidersConfigured => 'No AI providers configured';

  @override
  String get aiSettingsNoModelsConfigured => 'No AI models configured';

  @override
  String get aiSettingsNoPromptsConfigured => 'No AI prompts configured';

  @override
  String get aiSettingsTabProviders => 'Providers';

  @override
  String get aiSettingsTabModels => 'Models';

  @override
  String get aiSettingsTabPrompts => 'Prompts';

  @override
  String get aiSettingsSearchHint => 'Search AI configurations...';

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filter by $provider';
  }

  @override
  String get aiSettingsClearFiltersButton => 'Clear';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Clear all filters';

  @override
  String get aiSettingsModalityText => 'Text';

  @override
  String get aiSettingsModalityVision => 'Vision';

  @override
  String get aiSettingsModalityAudio => 'Audio';

  @override
  String get aiSettingsReasoningLabel => 'Reasoning';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filter by $capability capability';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip => 'Filter by reasoning capability';

  @override
  String get aiSettingsAddProviderButton => 'Add Provider';

  @override
  String get aiSettingsAddModelButton => 'Add Model';

  @override
  String get aiSettingsAddPromptButton => 'Add Prompt';

  @override
  String get saveButtonLabel => 'Save';

  @override
  String get saveLabel => 'Salvați';

  @override
  String get searchHint => 'Căutare...';

  @override
  String get settingsAboutTitle => 'Despre Lotti';

  @override
  String get settingsAdvancedShowCaseAboutLottiTooltip => 'Aflați mai multe despre aplicația Lotti, inclusiv versiunea și creditele.';

  @override
  String get settingsAdvancedShowCaseApiKeyTooltip => 'Administrați cheile API pentru diverși furnizori de inteligență artificială. Adăugați, editați sau ștergeți chei pentru a configura integrări cu servicii compatibile precum OpenAI, Gemini și altele. Asigurați-vă că informațiile sensibile sunt gestionate în siguranță.';

  @override
  String get settingsAdvancedShowCaseConflictsTooltip => 'Rezolvați conflictele de sincronizare pentru a asigura consecvența datelor.';

  @override
  String get settingsAdvancedShowCaseHealthImportTooltip => 'Importați date legate de sănătate din surse externe.';

  @override
  String get settingsAdvancedShowCaseLogsTooltip => 'Accesați și revizuiți jurnalele aplicației pentru depanare și monitorizare.';

  @override
  String get settingsAdvancedShowCaseMaintenanceTooltip => 'Efectuați sarcini de întreținere pentru a optimiza performanța aplicației.';

  @override
  String get settingsAdvancedShowCaseMatrixSyncTooltip => 'Configurați și gestionați setările de sincronizare Matrix pentru o integrare perfectă a datelor.';

  @override
  String get settingsAdvancedShowCaseModelsTooltip => 'Define AI models that use inference providers';

  @override
  String get settingsAdvancedShowCaseSyncOutboxTooltip => 'Vizualizați și gestionați elementele care așteaptă să fie sincronizate în căsuța de ieșire.';

  @override
  String get settingsAdvancedTitle => 'Setari Avansate';

  @override
  String get settingsAiApiKeys => 'AI Inference Providers';

  @override
  String get settingsAiModels => 'AI Models';

  @override
  String get settingsCategoriesDetailsLabel => 'Category Details';

  @override
  String get settingsCategoriesDuplicateError => 'Categoria există deja';

  @override
  String get settingsCategoriesNameLabel => 'Numele categoriei:';

  @override
  String get settingsCategoriesTitle => 'Categorii';

  @override
  String get settingsCategoryShowCaseActiveTooltip => 'Comutați această opțiune pentru a marca categoria ca activă. Categoriile active sunt utilizate în prezent și vor fi afișate proeminent pentru o accesibilitate mai ușoară.';

  @override
  String get settingsCategoryShowCaseColorTooltip => 'Selectează o culoare pentru a reprezenta această categorie. Poți introduce un cod de culoare HEX valid (de exemplu, #FF5733) sau poți utiliza selectorul de culori din dreapta pentru a alege o culoare vizual.';

  @override
  String get settingsCategoryShowCaseDelTooltip => 'Apasă acest buton pentru a șterge categoria. Reține că această acțiune este ireversibilă, așa că asigură-te că vrei să elimini categoria înainte de a continua.';

  @override
  String get settingsCategoryShowCaseFavTooltip => 'Activează această opțiune pentru a marca categoria ca favorită. Categoriile favorite sunt mai ușor de accesat și sunt evidențiate pentru o referință rapidă.';

  @override
  String get settingsCategoryShowCaseNameTooltip => 'Introdu un nume clar și relevant pentru categorie. Păstrează-l scurt și descriptiv, astfel încât să poți identifica cu ușurință scopul său.';

  @override
  String get settingsCategoryShowCasePrivateTooltip => 'Activează această opțiune pentru a marca categoria ca privată. Categoriile private sunt vizibile doar pentru tine și te ajută să organizezi în siguranță obiceiuri și sarcini sensibile sau personale.';

  @override
  String get settingsConflictsResolutionTitle => 'Rezolvarea Conflictelor de Sincronizare';

  @override
  String get settingsConflictsTitle => 'Sync cu conflicte';

  @override
  String get settingsDashboardDetailsLabel => 'Dashboard Details';

  @override
  String get settingsDashboardSaveLabel => 'Save';

  @override
  String get settingsDashboardsShowCaseActiveTooltip => 'Comută acest buton pentru a marca tabloul de bord ca activ. Tablourile de bord active sunt utilizate în prezent și vor fi afișate proeminent pentru o accesibilitate mai ușoară.';

  @override
  String get settingsDashboardsShowCaseCatTooltip => 'Selectează o categorie care descrie cel mai bine tabloul de bord. Acest lucru ajută la organizarea și clasificarea eficientă a tablourilor de bord. Exemple: \"Sănătate\", \"Productivitate\", \"Muncă\".';

  @override
  String get settingsDashboardsShowCaseCopyTooltip => 'Atinge pentru a copia acest tablou de bord. Acest lucru îți va permite să duplici tabloul de bord și să îl utilizezi în altă parte.';

  @override
  String get settingsDashboardsShowCaseDelTooltip => 'Atinge acest buton pentru a șterge definitiv tabloul de bord. Fii atent, deoarece această acțiune nu poate fi anulată și toate datele aferente vor fi eliminate.';

  @override
  String get settingsDashboardsShowCaseDescrTooltip => 'Oferă o descriere detaliată pentru tabloul de bord. Acest lucru ajută la înțelegerea scopului și a conținutului tabloului de bord. Exemple: \"Urmărește activitățile zilnice de wellness\", \"Monitorizează sarcinile și obiectivele legate de muncă\".';

  @override
  String get settingsDashboardsShowCaseHealthChartsTooltip => 'Selectează diagramele de sănătate pe care dorești să le incluzi în tabloul de bord. Exemple: \"Greutate\", \"Procentaj de grăsime corporală\".';

  @override
  String get settingsDashboardsShowCaseNameTooltip => 'Introdu un nume clar și relevant pentru tabloul de bord. Păstrează-l scurt și descriptiv, astfel încât să poți identifica cu ușurință scopul său. Exemple: \"Urmărire Wellness\", \"Obiective Zilnice\", \"Program de Lucru\".';

  @override
  String get settingsDashboardsShowCasePrivateTooltip => 'Comută acest buton pentru a face tabloul de bord privat. Tablourile de bord private sunt vizibile doar pentru tine și nu vor fi partajate cu alții.';

  @override
  String get settingsDashboardsShowCaseSurveyChartsTooltip => 'Selectează diagramele de sondaj pe care dorești să le incluzi în tabloul de bord. Exemple: \"Satisfacția clienților\", \"Feedbackul angajaților\".';

  @override
  String get settingsDashboardsShowCaseWorkoutChartsTooltip => 'Selectează diagramele de antrenament pe care dorești să le incluzi în tabloul de bord. Exemple: \"Mers pe jos\", \"Alergare\", \"Înot\".';

  @override
  String get settingsDashboardsTitle => 'Panouri de bord';

  @override
  String get settingsFlagsTitle => 'Marcaje';

  @override
  String get settingsHabitsDeleteTooltip => 'Șterge Obiceiul';

  @override
  String get settingsHabitsDescriptionLabel => 'Descriere (opțional):';

  @override
  String get settingsHabitsDetailsLabel => 'Habit Details';

  @override
  String get settingsHabitsNameLabel => 'Numele obiceiului:';

  @override
  String get settingsHabitsPrivateLabel => 'Privat:';

  @override
  String get settingsHabitsSaveLabel => 'Salvează';

  @override
  String get settingsHabitsShowCaseAlertTimeTooltip => 'Setează ora specifică la care dorești să primești o mementă sau o alertă pentru acest obicei. Acest lucru asigură că nu uiți niciodată să îl finalizezi. Exemplu: \"20:00\".';

  @override
  String get settingsHabitsShowCaseArchivedTooltip => 'Comută acest buton pentru a arhiva obiceiul. Obiceiurile arhivate nu mai sunt active, dar rămân salvate pentru referințe sau revizuiri ulterioare. Exemple: \"Învață chitară\", \"Curs finalizat\".';

  @override
  String get settingsHabitsShowCaseCatTooltip => 'Alege o categorie care descrie cel mai bine obiceiul tău sau creează una nouă selectând butonul [+].\nExemple: \"Sănătate\", \"Productivitate\", \"Exerciții fizice\".';

  @override
  String get settingsHabitsShowCaseDashTooltip => 'Selectați un tablou de bord pentru a vă organiza și urmări obiceiurile sau creați un tablou de bord nou folosind butonul [+].\nExemple: \"Monitorizare bunăstare\", \"Obiective zilnice\", \"Program de lucru\".';

  @override
  String get settingsHabitsShowCaseDelHabitTooltip => 'Atingeți acest buton pentru a șterge definitiv obiceiul. Fiți precaut, deoarece această acțiune nu poate fi anulată și toate datele aferente vor fi eliminate.';

  @override
  String get settingsHabitsShowCaseDescrTooltip => 'Furnizați o descriere scurtă și semnificativă a obiceiului. Includeți orice detalii relevante sau\ncontext pentru a defini clar scopul și importanța obiceiului.\nExemple: \"Alergați 30 de minute în fiecare dimineață pentru a vă îmbunătăți condiția fizică\" sau \"Citiți un capitol pe zi pentru a vă îmbunătăți cunoștințele și concentrarea\".';

  @override
  String get settingsHabitsShowCaseNameTooltip => 'Introduceți un nume clar și descriptiv pentru obicei.\nEvitați numele prea lungi și faceți-l suficient de concis pentru a identifica ușor obiceiul.\nExemple: \"Alergări de dimineață\", \"Citit zilnic\".';

  @override
  String get settingsHabitsShowCasePriorTooltip => 'Comutați pentru a atribui prioritate obiceiului. Obiceiurile cu prioritate ridicată reprezintă adesea sarcini esențiale sau urgente pe care doriți să vă concentrați. Exemple: \"Exerciții zilnice\", \"Lucru la proiect\".';

  @override
  String get settingsHabitsShowCasePrivateTooltip => 'Utilizați acest comutator pentru a marca obiceiul ca privat. Obiceiurile private sunt vizibile numai pentru dvs. și nu vor fi partajate cu alte persoane. Exemple: \"Jurnal personal\", \"Meditație\".';

  @override
  String get settingsHabitsShowCaseStarDateTooltip => 'Selectați data de la care doriți să începeți urmărirea acestui obicei. Acest lucru ajută la definirea momentului în care începe obiceiul și permite monitorizarea exactă a progresului. Exemplu: \"1 iulie 2025\".';

  @override
  String get settingsHabitsShowCaseStartTimeTooltip => 'Setați ora de la care acest obicei ar trebui să fie vizibil sau să înceapă să apară în programul dvs. Acest lucru vă ajută să vă organizați ziua eficient. Exemplu: \"7:00 AM\".';

  @override
  String get settingsHabitsTitle => 'Obiceiuri';

  @override
  String get settingsHealthImportFromDate => 'Început';

  @override
  String get settingsHealthImportTitle => 'Health Import';

  @override
  String get settingsHealthImportToDate => 'Sfârșit';

  @override
  String get settingsLogsTitle => 'Logs';

  @override
  String get settingsMaintenanceTitle => 'Mentenanță';

  @override
  String get settingsMatrixAcceptVerificationLabel => 'Celălalt dispozitiv afișează emoji, continuați';

  @override
  String get settingsMatrixCancel => 'Anulare';

  @override
  String get settingsMatrixCancelVerificationLabel => 'Anulează verificarea';

  @override
  String get settingsMatrixContinueVerificationLabel => 'Acceptați pe celălalt dispozitiv pentru a continua';

  @override
  String get settingsMatrixDeleteLabel => 'Șterge';

  @override
  String get settingsMatrixDone => 'Gata';

  @override
  String get settingsMatrixEnterValidUrl => 'Introduceți o adresă URL validă';

  @override
  String get settingsMatrixHomeserverConfigTitle => 'Configurare Matrix Homeserver';

  @override
  String get settingsMatrixHomeServerLabel => 'Homeserver';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Dispozitive neverificate';

  @override
  String get settingsMatrixLoginButtonLabel => 'Conectare';

  @override
  String get settingsMatrixLoginFailed => 'Conectarea a eșuat';

  @override
  String get settingsMatrixLogoutButtonLabel => 'Deconectare';

  @override
  String get settingsMatrixNextPage => 'Pagina următoare';

  @override
  String get settingsMatrixNoUnverifiedLabel => 'Niciun dispozitiv neverificat';

  @override
  String get settingsMatrixPasswordLabel => 'Parolă';

  @override
  String get settingsMatrixPasswordTooShort => 'Parola este prea scurtă';

  @override
  String get settingsMatrixPreviousPage => 'Pagina anterioară';

  @override
  String get settingsMatrixQrTextPage => 'Scanați acest cod QR pentru a invita dispozitivul într-o cameră de sincronizare.';

  @override
  String get settingsMatrixRoomConfigTitle => 'Configurare cameră de sincronizare Matrix';

  @override
  String get settingsMatrixStartVerificationLabel => 'Începe verificarea';

  @override
  String get settingsMatrixStatsTitle => 'Statistici Matrix';

  @override
  String get settingsMatrixTitle => 'Setări sincronizare Matrix';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Dispozitive neverificate';

  @override
  String get settingsMatrixUserLabel => 'Utilizator';

  @override
  String get settingsMatrixUserNameTooShort => 'Numele de utilizator este prea scurt';

  @override
  String get settingsMatrixVerificationCancelledLabel => 'Anulat pe celălalt dispozitiv...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Am înțeles';

  @override
  String settingsMatrixVerificationSuccessLabel(String deviceName, String deviceID) {
    return 'Ați verificat cu succes $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm => 'Confirmați pe celălalt dispozitiv că emoji-urile de mai jos sunt afișate pe ambele dispozitive, în aceeași ordine:';

  @override
  String get settingsMatrixVerifyIncomingConfirm => 'Confirmați că emoji-urile de mai jos sunt afișate pe ambele dispozitive, în aceeași ordine:';

  @override
  String get settingsMatrixVerifyLabel => 'Verifică';

  @override
  String get settingsMeasurableAggregationLabel => 'Tip Agregări:';

  @override
  String get settingsMeasurableDeleteTooltip => 'Șterge tipul măsurătorii';

  @override
  String get settingsMeasurableDescriptionLabel => 'Descriere:';

  @override
  String get settingsMeasurableDetailsLabel => 'Measurable Details';

  @override
  String get settingsMeasurableFavoriteLabel => 'Favorite: ';

  @override
  String get settingsMeasurableNameLabel => 'Numele măsurătorii:';

  @override
  String get settingsMeasurablePrivateLabel => 'Privat: ';

  @override
  String get settingsMeasurableSaveLabel => 'Salvare';

  @override
  String get settingsMeasurableShowCaseAggreTypeTooltip => 'Selectați tipul implicit de agregare pentru datele măsurabile. Aceasta determină modul în care datele vor fi rezumate în timp. \nOpțiuni: \'dailySum\', \'dailyMax\', \'dailyAvg\', \'hourlySum\'.';

  @override
  String get settingsMeasurableShowCaseDelTooltip => 'Faceți clic pe acest buton pentru a șterge tipul măsurabil. Rețineți că această acțiune este ireversibilă, așa că asigurați-vă că doriți să eliminați tipul măsurabil înainte de a continua.';

  @override
  String get settingsMeasurableShowCaseDescrTooltip => 'Furnizați o descriere scurtă și semnificativă a tipului măsurabil. Includeți orice detalii relevante sau context pentru a defini clar scopul și importanța acestuia. \nExemple: \'Greutatea corporală măsurată în kilograme\'';

  @override
  String get settingsMeasurableShowCaseNameTooltip => 'Introduceți un nume clar și descriptiv pentru tipul măsurabil.\nEvitați numele prea lungi și faceți-l suficient de concis pentru a identifica cu ușurință tipul măsurabil. \nExemple: \'Greutate\', \'Tensiune arterială\'.';

  @override
  String get settingsMeasurableShowCasePrivateTooltip => 'Comutați această opțiune pentru a marca tipul măsurabil ca privat. Tipurile măsurabile private sunt vizibile numai pentru dvs. și vă ajută să organizați în siguranță datele sensibile sau personale.';

  @override
  String get settingsMeasurableShowCaseUnitTooltip => 'Introduceți o abreviere clară și concisă a unității pentru tipul măsurabil. Acest lucru ajută la identificarea cu ușurință a unității de măsură.';

  @override
  String get settingsMeasurablesTitle => 'Măsurători';

  @override
  String get settingsMeasurableUnitLabel => 'Unitatea abrevierii:';

  @override
  String get settingsSpeechAudioWithoutTranscript => 'Intrări audio fără transcriere:';

  @override
  String get settingsSpeechAudioWithoutTranscriptButton => 'Găsește și transcrie';

  @override
  String get settingsSpeechLastActivity => 'Ultima activitate de transcriere:';

  @override
  String get settingsSpeechModelSelectionTitle => 'Model de recunoaștere vocală Whisper:';

  @override
  String get settingsSpeechTitle => 'Setări vorbire';

  @override
  String get settingsSyncOutboxTitle => 'Sync Outbox';

  @override
  String get settingsTagsDeleteTooltip => 'Șterge eticheta';

  @override
  String get settingsTagsDetailsLabel => 'Tags Details';

  @override
  String get settingsTagsHideLabel => 'Ascunde din sugestii:';

  @override
  String get settingsTagsPrivateLabel => 'Privat:';

  @override
  String get settingsTagsSaveLabel => 'Salveaza eticheta';

  @override
  String get settingsTagsShowCaseDeleteTooltip => 'Eliminați această etichetă definitiv. Această acțiune nu poate fi anulată.';

  @override
  String get settingsTagsShowCaseHideTooltip => 'Activați această opțiune pentru a ascunde această etichetă din sugestii. Utilizați-o pentru etichetele personale sau care nu sunt necesare în mod obișnuit.';

  @override
  String get settingsTagsShowCaseNameTooltip => 'Introduceți un nume clar și relevant pentru etichetă. Păstrați-l scurt și descriptiv, astfel încât să puteți clasifica cu ușurință obiceiurile dvs. Exemple: \"Sănătate\", \"Productivitate\", \"Mindfulness\".';

  @override
  String get settingsTagsShowCasePrivateTooltip => 'Activați această opțiune pentru a face eticheta privată. Etichetele private sunt vizibile numai pentru dvs. și nu vor fi partajate cu alții.';

  @override
  String get settingsTagsShowCaseTypeTooltip => 'Selectați tipul de etichetă pentru a o clasifica corect: \n[Etichetă]-> Categorii generale precum \'Sănătate\' sau \'Productivitate\'. \n[Persoană]-> Utilizați pentru etichetarea anumitor persoane. \n[Poveste]-> Atașați etichete la povești pentru o mai bună organizare.';

  @override
  String get settingsTagsTagName => 'Etichete:';

  @override
  String get settingsTagsTitle => 'Etichete';

  @override
  String get settingsTagsTypeLabel => 'Tip Eticheta:';

  @override
  String get settingsTagsTypePerson => 'PERSOANA';

  @override
  String get settingsTagsTypeStory => 'POVESTE';

  @override
  String get settingsTagsTypeTag => 'ETICHETA';

  @override
  String get settingsThemingAutomatic => 'Automat';

  @override
  String get settingsThemingDark => 'Aspect întunecat';

  @override
  String get settingsThemingLight => 'Aspect luminos';

  @override
  String get settingsThemingShowCaseDarkTooltip => 'Alegeți tema întunecată pentru un aspect mai întunecat.';

  @override
  String get settingsThemingShowCaseLightTooltip => 'Alegeți tema luminoasă pentru un aspect mai luminos.';

  @override
  String get settingsThemingShowCaseModeTooltip => 'Selectați modul de temă preferat: Luminos, Întunecat sau Automat.';

  @override
  String get settingsThemingTitle => 'Tematică';

  @override
  String get settingThemingDark => 'Temă întunecată';

  @override
  String get settingThemingLight => 'Temă luminoasă';

  @override
  String get showcaseCloseButton => 'închide';

  @override
  String get showcaseNextButton => 'următorul';

  @override
  String get showcasePreviousButton => 'anterior';

  @override
  String get speechModalAddTranscription => 'Adăugați transcriere';

  @override
  String get speechModalSelectLanguage => 'Selectați limba';

  @override
  String get speechModalTitle => 'Recunoaștere vocală';

  @override
  String get speechModalTranscriptionProgress => 'Progresul transcrierii';

  @override
  String get syncDeleteConfigConfirm => 'DA, SUNT SIGUR';

  @override
  String get syncDeleteConfigQuestion => 'Doriți să ștergeți configurația de sincronizare?';

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
  String get taskCategoryAllLabel => 'toate';

  @override
  String get taskCategoryLabel => 'Categorie:';

  @override
  String get taskCategoryUnassignedLabel => 'neeatribuit';

  @override
  String get taskEstimateLabel => 'Timp Estimat:';

  @override
  String get taskNameHint => 'Introduceți un nume pentru sarcină';

  @override
  String get tasksFilterTitle => 'Filtru sarcini';

  @override
  String get taskStatusAll => 'Toate';

  @override
  String get taskStatusBlocked => 'BLOCAT';

  @override
  String get taskStatusDone => 'TERMINAT';

  @override
  String get taskStatusGroomed => 'PREGĂTIT';

  @override
  String get taskStatusInProgress => 'ÎN PROGRES';

  @override
  String get taskStatusLabel => 'Starea Sarcinii:';

  @override
  String get taskStatusOnHold => 'N AŞTEPTARE';

  @override
  String get taskStatusOpen => 'DESCHIS';

  @override
  String get taskStatusRejected => 'RESPINS';

  @override
  String get timeByCategoryChartTitle => 'Timp pe categorie';

  @override
  String get timeByCategoryChartTotalLabel => 'Total';

  @override
  String get viewMenuTitle => 'Vizualizare';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Connection Failed';

  @override
  String get aiInferenceErrorConnectionFailedMessage => 'Unable to connect to the AI service. Please check your internet connection and ensure the service is accessible.';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Request Timed Out';

  @override
  String get aiInferenceErrorTimeoutMessage => 'The request took too long to complete. Please try again or check if the service is responding.';

  @override
  String get aiInferenceErrorAuthenticationTitle => 'Authentication Failed';

  @override
  String get aiInferenceErrorAuthenticationMessage => 'Authentication failed. Please check your API key and ensure it is valid.';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Rate Limit Exceeded';

  @override
  String get aiInferenceErrorRateLimitMessage => 'You have exceeded the rate limit. Please wait a moment before trying again.';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Invalid Request';

  @override
  String get aiInferenceErrorInvalidRequestMessage => 'The request was invalid. Please check your configuration and try again.';

  @override
  String get aiInferenceErrorServerTitle => 'Server Error';

  @override
  String get aiInferenceErrorServerMessage => 'The AI service encountered an error. Please try again later.';

  @override
  String get aiInferenceErrorUnknownTitle => 'Error';

  @override
  String get aiInferenceErrorUnknownMessage => 'An unexpected error occurred. Please try again.';

  @override
  String get aiInferenceErrorRetryButton => 'Try Again';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Suggestions:';
}

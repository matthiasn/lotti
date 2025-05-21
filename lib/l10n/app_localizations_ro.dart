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
  String get addActionAddMeasurable => 'Adauga masuratoare';

  @override
  String get addActionAddPhotos => 'Adauga fotografie';

  @override
  String get addActionAddScreenshot => 'Adauga captura de ecran';

  @override
  String get addActionAddSurvey => 'Adauga sondaj';

  @override
  String get addActionAddTask => 'Adauga sarcina';

  @override
  String get addActionAddText => 'Adauga text';

  @override
  String get addActionAddTimeRecording => 'Adauga timp';

  @override
  String get addAudioTitle => 'Adauga titlu';

  @override
  String get addEntryTitle => 'Titlu';

  @override
  String get addHabitCommentLabel => 'Comentariu';

  @override
  String get addHabitDateLabel => 'Finalizat la';

  @override
  String get addMeasurementCommentLabel => 'Comentariu';

  @override
  String get addMeasurementDateLabel => 'Observat la';

  @override
  String get addMeasurementNoneDefined => 'Nicio masuratoare definita';

  @override
  String get addMeasurementSaveButton => 'Salveaza masuratoare';

  @override
  String get addMeasurementTitle => 'Titlu masuratoare';

  @override
  String get addSurveyTitle => 'Titlu sondaj';

  @override
  String get addTaskTitle => 'Titlu sarcina';

  @override
  String get aiAssistantActionItemSuggestions => 'Sugestii de acțiuni';

  @override
  String get aiAssistantAnalyzeImage => 'Analizează imaginea';

  @override
  String get aiAssistantCreateChecklist =>
      'Creează elemente de listă de verificare';

  @override
  String get aiAssistantRunPrompt => 'Întreabă Llama3';

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
  String get aiConfigCategoryFieldLabel => 'Category (Optional)';

  @override
  String get aiConfigCommentFieldLabel => 'Comment (Optional)';

  @override
  String get aiConfigCreateButtonLabel => 'Create Prompt';

  @override
  String get aiConfigDefaultVariablesFieldLabel =>
      'Default Variables (JSON, Optional)';

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
  String aiConfigListPromptTemplateSubtitle(String templatePreview) {
    return 'Template: $templatePreview...';
  }

  @override
  String get aiConfigListUndoDelete => 'UNDO';

  @override
  String get aiConfigManageModelsButton => 'Manage Models';

  @override
  String get aiConfigModelFieldLabel => 'Model';

  @override
  String get aiConfigModelLoadError => 'Could not load model details.';

  @override
  String aiConfigModelRemovedMessage(String modelName) {
    return '$modelName removed from prompt';
  }

  @override
  String get aiConfigModelsTitle => 'Available Models';

  @override
  String get aiConfigModelSupportsReasoning => 'Supports reasoning';

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
  String get aiConfigSelectModelModalTitle => 'Select AI Model';

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
  String get aiConfigTemplateEmptyError => 'Template cannot be empty';

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
  String get aiTaskNoSummaryTitle =>
      'Nu a fost creat încă un rezumat al sarcinii AI';

  @override
  String get aiTaskSummaryRunning => 'Se gândește la rezumarea sarcinii...';

  @override
  String get aiTaskSummaryTitle => 'Rezumatul sarcinii AI';

  @override
  String get apiKeyAddPageTitle => 'Add API Key';

  @override
  String get apiKeyEditLoadError => 'Failed to load API key configuration';

  @override
  String get apiKeyEditPageTitle => 'Edit API Key';

  @override
  String get apiKeyFormApiKeyError => 'API key cannot be empty';

  @override
  String get apiKeyFormApiKeyLabel => 'API Key';

  @override
  String get apiKeyFormBaseUrlError => 'Please enter a valid URL';

  @override
  String get apiKeyFormBaseUrlLabel => 'Base URL';

  @override
  String get apiKeyFormCommentLabel => 'Comment (Optional)';

  @override
  String get apiKeyFormCreateButton => 'Create';

  @override
  String get apiKeyFormNameError => 'Name must be at least 3 characters';

  @override
  String get apiKeyFormNameLabel => 'Name';

  @override
  String get apiKeyFormSaveError => 'Failed to save API key configuration';

  @override
  String get apiKeyFormShowApiKey => 'Show API Key';

  @override
  String get apiKeyFormUpdateButton => 'Update';

  @override
  String get apiKeysSettingsPageTitle => 'API Keys';

  @override
  String get appBarBack => 'Înapoi';

  @override
  String get cancelButton => 'Anulează';

  @override
  String get cancelButtonLabel => 'Cancel';

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
  String get checklistItemDeleteWarning =>
      'Această acțiune nu poate fi anulată.';

  @override
  String get checklistItemDrag => 'Trage sugestiile în lista de verificare';

  @override
  String get checklistNoSuggestionsTitle => 'Nu există sugestii de acțiuni';

  @override
  String get checklistsTitle => 'Liste de verificare';

  @override
  String get checklistSuggestionsOutdated => 'Depășite';

  @override
  String get checklistSuggestionsRunning =>
      'Se gândește la sugestii netrimise...';

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
  String get configFlagAttemptEmbeddingDescription =>
      'Când este activată, aplicația va încerca să genereze încorporări pentru intrările dvs. pentru a îmbunătăți căutarea și sugestiile de conținut corelat.';

  @override
  String get configFlagAutoTranscribeDescription =>
      'Transcrie automat înregistrările audio din intrările dvs. Acest lucru necesită o conexiune la internet.';

  @override
  String get configFlagEnableAutoTaskTldrDescription =>
      'Generează automat rezumate pentru sarcinile dvs. pentru a vă ajuta să înțelegeți rapid starea lor.';

  @override
  String get configFlagEnableCalendarPageDescription =>
      'Afișează pagina Calendar în navigarea principală. Vizualizați și gestionați-vă intrările într-o vizualizare calendaristică.';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Afișează pagina Tablouri de bord în navigarea principală. Vizualizați datele și informațiile dvs. în tablouri de bord personalizabile.';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Afișează pagina Obiceiuri în navigarea principală. Urmăriți și gestionați-vă obiceiurile zilnice aici.';

  @override
  String get configFlagEnableLoggingDescription =>
      'Activează înregistrarea detaliată pentru depanare. Acest lucru poate afecta performanța.';

  @override
  String get configFlagEnableMatrixDescription =>
      'Activează integrarea Matrix pentru a sincroniza intrările dvs. pe diferite dispozitive și cu alți utilizatori Matrix.';

  @override
  String get configFlagEnableNotifications =>
      'Activează notificările pe desktop?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Primiți notificări pentru mementouri, actualizări și evenimente importante.';

  @override
  String get configFlagEnableTooltipDescription =>
      'Afișează sfaturi utile în întreaga aplicație pentru a vă ghida prin funcții.';

  @override
  String get configFlagPrivate => 'Arată articolele private?';

  @override
  String get configFlagPrivateDescription =>
      'Activați această opțiune pentru a face intrările dvs. private în mod implicit. Intrările private sunt vizibile numai pentru dvs.';

  @override
  String get configFlagRecordLocationDescription =>
      'Înregistrează automat locația dvs. cu intrări noi. Acest lucru ajută la organizarea și căutarea pe baza locației.';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Activați această opțiune pentru a retrimite automat încărcările de atașamente eșuate atunci când conexiunea este restabilită.';

  @override
  String get configFlagUseCloudInferenceDescription =>
      'Utilizați servicii AI bazate pe cloud pentru funcții îmbunătățite. Acest lucru necesită o conexiune la internet.';

  @override
  String get configInvalidCert => 'Permiteți certificatul SSL invalid?';

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
  String get dashboardAddStoryButton => 'Articol/Timp Grafic';

  @override
  String get dashboardAddStoryTitle => 'Articol/Timp Grafic';

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
  String get dashboardCopyHint =>
      'Salvează și copiază configurația tabloului de bord';

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
  String get dashboardReviewTimeLabel => 'Daily Review Time:';

  @override
  String get dashboardSaveLabel => 'Salvează și închide';

  @override
  String get dashboardsEmptyHint =>
      'Nimic de vazut aici, creaza un nou panou de bord in setari. \n\n Butonul cu roti dintate de mai sus te va duce acolo.';

  @override
  String get dashboardsHowToHint => 'Cum se utilizează Lotti';

  @override
  String get dashboardsLoadingHint => 'Se incarca ..';

  @override
  String get doneButton => 'Gata';

  @override
  String get editMenuTitle => 'Editează';

  @override
  String get editorPlaceholder => 'Introduceți notițe...';

  @override
  String get entryActions => 'Acțiuni';

  @override
  String get entryNotFound => 'Nu am gasit';

  @override
  String get eventNameLabel => 'Eveniment:';

  @override
  String get fileInputTypeAll => 'All files';

  @override
  String get fileInputTypeAudio => 'Audio files';

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
  String get habitActiveUntilLabel => 'Activ până la';

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
  String get habitNotFound => 'Obicei negăsit';

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
  String get habitsLongerStreaksEmptyHeader =>
      'Momentan nu există serii de o săptămână';

  @override
  String get habitsLongerStreaksHeader =>
      'Serii de o săptămână (sau mai lungi)';

  @override
  String get habitsOpenHeader => 'Scadente acum';

  @override
  String get habitsPendingLaterHeader => 'Mai târziu astăzi';

  @override
  String get habitsSearchHint => 'Căutare...';

  @override
  String get habitsShortStreaksEmptyHeader =>
      'Momentan nu există serii de trei zile';

  @override
  String get habitsShortStreaksHeader => 'Serii de trei zile (sau mai lungi)';

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
  String get journalDateSaveHint => 'Salvează intrare';

  @override
  String get journalDateToLabel => 'Până la:';

  @override
  String get journalDeleteConfirm => 'DA, ȘTERGE ACEASTĂ INTRARE';

  @override
  String get journalDeleteHint => 'Șterge intrare';

  @override
  String get journalDeleteQuestion =>
      'Vrei să ștergi această intrare în jurnal?';

  @override
  String get journalDurationLabel => 'Durată:';

  @override
  String get journalFavoriteTooltip => 'Favorit';

  @override
  String get journalFlaggedTooltip => 'Marcat';

  @override
  String get journalHeaderContract => 'Afișați mai puțin';

  @override
  String get journalHeaderExpand => 'Afișați tot';

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
  String get journalToolbarSaveHint => 'Salvează intrarea';

  @override
  String get journalUnlinkConfirm => 'DA, DESPĂRȚIȚI INTRAREA';

  @override
  String get journalUnlinkHint => 'Despărțiți';

  @override
  String get journalUnlinkQuestion =>
      'Sigur doriți să despărțiți această intrare?';

  @override
  String get journalUnlinkText => 'Dezleagă intrarea';

  @override
  String get maintenanceAssignCategoriesToChecklists =>
      'Alocați categorii listelor de verificare';

  @override
  String get maintenanceAssignCategoriesToLinked =>
      'Alocați categorii intrărilor legate de intrări cu categorii';

  @override
  String get maintenanceAssignCategoriesToLinkedFromTasks =>
      'Alocați categorii intrărilor legate de sarcini';

  @override
  String get maintenanceCancelNotifications => 'Anuleaza notificarile';

  @override
  String get maintenanceDeleteEditorDb => 'Șterge ciornele din baza de date';

  @override
  String get maintenanceDeleteLoggingDb => 'Șterge log-urile din baza de date';

  @override
  String get maintenanceDeleteLoggingDbConfirm => 'Yes, delete database';

  @override
  String get maintenanceDeleteLoggingDbQuestion =>
      'Are you sure you want to delete the logging database? This action cannot be undone.';

  @override
  String get maintenanceDeleteSyncDb => 'Ștergeți baza de date de sincronizare';

  @override
  String get maintenanceDeleteSyncDbConfirm => 'Yes, delete database';

  @override
  String get maintenanceDeleteSyncDbQuestion =>
      'Are you sure you want to delete the sync database? This action cannot be undone.';

  @override
  String get maintenanceDeleteTagged => 'Șterge etichetat';

  @override
  String get maintenancePersistTaskCategories =>
      'Păstrați categoriile de sarcini';

  @override
  String get maintenancePurgeAudioModels => 'Eliminați modelele audio';

  @override
  String get maintenancePurgeDeleted => 'Eliminați elementele șterse';

  @override
  String get maintenancePurgeDeletedConfirm => 'Yes, purge all';

  @override
  String get maintenancePurgeDeletedEmpty => 'No deleted items to purge';

  @override
  String get maintenancePurgeDeletedProgress => 'Purging deleted items...';

  @override
  String get maintenancePurgeDeletedQuestion =>
      'Are you sure you want to purge all deleted items?';

  @override
  String get maintenanceRecreateFts5 => 'Recreați indexul full-text';

  @override
  String get maintenanceRecreateTagged => 'Recrează etichetat';

  @override
  String get maintenanceReprocessSync => 'Reproceseaza sincronizare';

  @override
  String get maintenanceResetHostId => 'Resetați ID-ul gazdei';

  @override
  String get maintenanceReSync => 'Resincronizați mesajele';

  @override
  String get maintenanceStories => 'Alocă poveștile din intrările părinte';

  @override
  String get maintenanceSyncCategories => 'Sincronizați categoriile';

  @override
  String get maintenanceSyncDefinitions =>
      'Sincronizați etichetele, valorile măsurabile, tablourile de bord, obiceiurile';

  @override
  String get maintenanceSyncSkip => 'Săriți mesajul de sincronizare';

  @override
  String get manualLinkText =>
      'pentru mai multe informatii, consulta manualul.';

  @override
  String get measurableDeleteConfirm => 'DA, CONFIRM STERGEREA';

  @override
  String get measurableDeleteQuestion =>
      'Vrei sa stergi acest tip de masuratoare?';

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
  String get navTabTitleFlagged => 'Marcat';

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
  String get saveButtonLabel => 'Save';

  @override
  String get saveLabel => 'Salvați';

  @override
  String get searchHint => 'Căutare...';

  @override
  String get settingsAboutTitle => 'Despre Lotti';

  @override
  String get settingsAdvancedShowCaseAboutLottiTooltip =>
      'Aflați mai multe despre aplicația Lotti, inclusiv versiunea și creditele.';

  @override
  String get settingsAdvancedShowCaseApiKeyTooltip =>
      'Administrați cheile API pentru diverși furnizori de inteligență artificială. Adăugați, editați sau ștergeți chei pentru a configura integrări cu servicii compatibile precum OpenAI, Gemini și altele. Asigurați-vă că informațiile sensibile sunt gestionate în siguranță.';

  @override
  String get settingsAdvancedShowCaseConflictsTooltip =>
      'Rezolvați conflictele de sincronizare pentru a asigura consecvența datelor.';

  @override
  String get settingsAdvancedShowCaseHealthImportTooltip =>
      'Importați date legate de sănătate din surse externe.';

  @override
  String get settingsAdvancedShowCaseLogsTooltip =>
      'Accesați și revizuiți jurnalele aplicației pentru depanare și monitorizare.';

  @override
  String get settingsAdvancedShowCaseMaintenanceTooltip =>
      'Efectuați sarcini de întreținere pentru a optimiza performanța aplicației.';

  @override
  String get settingsAdvancedShowCaseMatrixSyncTooltip =>
      'Configurați și gestionați setările de sincronizare Matrix pentru o integrare perfectă a datelor.';

  @override
  String get settingsAdvancedShowCaseModelsTooltip =>
      'Define AI models that use inference providers';

  @override
  String get settingsAdvancedShowCaseSyncOutboxTooltip =>
      'Vizualizați și gestionați elementele care așteaptă să fie sincronizate în căsuța de ieșire.';

  @override
  String get settingsAdvancedTitle => 'Setari Avansate';

  @override
  String get settingsAiApiKeys => 'API Keys';

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
  String get settingsCategoryShowCaseActiveTooltip =>
      'Comutați această opțiune pentru a marca categoria ca activă. Categoriile active sunt utilizate în prezent și vor fi afișate proeminent pentru o accesibilitate mai ușoară.';

  @override
  String get settingsCategoryShowCaseCatTooltip =>
      'Activează această opțiune pentru a marca categoria ca activă. Categoriile active sunt utilizate în prezent și vor fi afișate proeminent pentru o accesibilitate mai ușoară.';

  @override
  String get settingsCategoryShowCaseColorTooltip =>
      'Selectează o culoare pentru a reprezenta această categorie. Poți introduce un cod de culoare HEX valid (de exemplu, #FF5733) sau poți utiliza selectorul de culori din dreapta pentru a alege o culoare vizual.';

  @override
  String get settingsCategoryShowCaseDelTooltip =>
      'Apasă acest buton pentru a șterge categoria. Reține că această acțiune este ireversibilă, așa că asigură-te că vrei să elimini categoria înainte de a continua.';

  @override
  String get settingsCategoryShowCaseFavTooltip =>
      'Activează această opțiune pentru a marca categoria ca favorită. Categoriile favorite sunt mai ușor de accesat și sunt evidențiate pentru o referință rapidă.';

  @override
  String get settingsCategoryShowCaseNameTooltip =>
      'Introdu un nume clar și relevant pentru categorie. Păstrează-l scurt și descriptiv, astfel încât să poți identifica cu ușurință scopul său.';

  @override
  String get settingsCategoryShowCasePrivateTooltip =>
      'Activează această opțiune pentru a marca categoria ca privată. Categoriile private sunt vizibile doar pentru tine și te ajută să organizezi în siguranță obiceiuri și sarcini sensibile sau personale.';

  @override
  String get settingsConflictsResolutionTitle =>
      'Rezolvarea Conflictelor de Sincronizare';

  @override
  String get settingsConflictsTitle => 'Sync cu conflicte';

  @override
  String get settingsDashboardDetailsLabel => 'Dashboard Details';

  @override
  String get settingsDashboardSaveLabel => 'Save';

  @override
  String get settingsDashboardsSearchHint => 'Caută...';

  @override
  String get settingsDashboardsShowCaseActiveTooltip =>
      'Comută acest buton pentru a marca tabloul de bord ca activ. Tablourile de bord active sunt utilizate în prezent și vor fi afișate proeminent pentru o accesibilitate mai ușoară.';

  @override
  String get settingsDashboardsShowCaseCatTooltip =>
      'Selectează o categorie care descrie cel mai bine tabloul de bord. Acest lucru ajută la organizarea și clasificarea eficientă a tablourilor de bord. Exemple: \"Sănătate\", \"Productivitate\", \"Muncă\".';

  @override
  String get settingsDashboardsShowCaseCopyTooltip =>
      'Atinge pentru a copia acest tablou de bord. Acest lucru îți va permite să duplici tabloul de bord și să îl utilizezi în altă parte.';

  @override
  String get settingsDashboardsShowCaseDelTooltip =>
      'Atinge acest buton pentru a șterge definitiv tabloul de bord. Fii atent, deoarece această acțiune nu poate fi anulată și toate datele aferente vor fi eliminate.';

  @override
  String get settingsDashboardsShowCaseDescrTooltip =>
      'Oferă o descriere detaliată pentru tabloul de bord. Acest lucru ajută la înțelegerea scopului și a conținutului tabloului de bord. Exemple: \"Urmărește activitățile zilnice de wellness\", \"Monitorizează sarcinile și obiectivele legate de muncă\".';

  @override
  String get settingsDashboardsShowCaseHealthChartsTooltip =>
      'Selectează diagramele de sănătate pe care dorești să le incluzi în tabloul de bord. Exemple: \"Greutate\", \"Procentaj de grăsime corporală\".';

  @override
  String get settingsDashboardsShowCaseNameTooltip =>
      'Introdu un nume clar și relevant pentru tabloul de bord. Păstrează-l scurt și descriptiv, astfel încât să poți identifica cu ușurință scopul său. Exemple: \"Urmărire Wellness\", \"Obiective Zilnice\", \"Program de Lucru\".';

  @override
  String get settingsDashboardsShowCasePrivateTooltip =>
      'Comută acest buton pentru a face tabloul de bord privat. Tablourile de bord private sunt vizibile doar pentru tine și nu vor fi partajate cu alții.';

  @override
  String get settingsDashboardsShowCaseSurveyChartsTooltip =>
      'Selectează diagramele de sondaj pe care dorești să le incluzi în tabloul de bord. Exemple: \"Satisfacția clienților\", \"Feedbackul angajaților\".';

  @override
  String get settingsDashboardsShowCaseWorkoutChartsTooltip =>
      'Selectează diagramele de antrenament pe care dorești să le incluzi în tabloul de bord. Exemple: \"Mers pe jos\", \"Alergare\", \"Înot\".';

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
  String get settingsHabitsFavoriteLabel => 'Favorit:';

  @override
  String get settingsHabitsNameLabel => 'Numele obiceiului:';

  @override
  String get settingsHabitsPrivateLabel => 'Privat:';

  @override
  String get settingsHabitsSaveLabel => 'Salvează';

  @override
  String get settingsHabitsSearchHint => 'Caută...';

  @override
  String get settingsHabitsShowCaseAlertTimeTooltip =>
      'Setează ora specifică la care dorești să primești o mementă sau o alertă pentru acest obicei. Acest lucru asigură că nu uiți niciodată să îl finalizezi. Exemplu: \"20:00\".';

  @override
  String get settingsHabitsShowCaseArchivedTooltip =>
      'Comută acest buton pentru a arhiva obiceiul. Obiceiurile arhivate nu mai sunt active, dar rămân salvate pentru referințe sau revizuiri ulterioare. Exemple: \"Învață chitară\", \"Curs finalizat\".';

  @override
  String get settingsHabitsShowCaseCatTooltip =>
      'Alege o categorie care descrie cel mai bine obiceiul tău sau creează una nouă selectând butonul [+].\nExemple: \"Sănătate\", \"Productivitate\", \"Exerciții fizice\".';

  @override
  String get settingsHabitsShowCaseDashTooltip =>
      'Selectați un tablou de bord pentru a vă organiza și urmări obiceiurile sau creați un tablou de bord nou folosind butonul [+].\nExemple: \"Monitorizare bunăstare\", \"Obiective zilnice\", \"Program de lucru\".';

  @override
  String get settingsHabitsShowCaseDelHabitTooltip =>
      'Atingeți acest buton pentru a șterge definitiv obiceiul. Fiți precaut, deoarece această acțiune nu poate fi anulată și toate datele aferente vor fi eliminate.';

  @override
  String get settingsHabitsShowCaseDescrTooltip =>
      'Furnizați o descriere scurtă și semnificativă a obiceiului. Includeți orice detalii relevante sau\ncontext pentru a defini clar scopul și importanța obiceiului.\nExemple: \"Alergați 30 de minute în fiecare dimineață pentru a vă îmbunătăți condiția fizică\" sau \"Citiți un capitol pe zi pentru a vă îmbunătăți cunoștințele și concentrarea\".';

  @override
  String get settingsHabitsShowCaseNameTooltip =>
      'Introduceți un nume clar și descriptiv pentru obicei.\nEvitați numele prea lungi și faceți-l suficient de concis pentru a identifica ușor obiceiul.\nExemple: \"Alergări de dimineață\", \"Citit zilnic\".';

  @override
  String get settingsHabitsShowCasePriorTooltip =>
      'Comutați pentru a atribui prioritate obiceiului. Obiceiurile cu prioritate ridicată reprezintă adesea sarcini esențiale sau urgente pe care doriți să vă concentrați. Exemple: \"Exerciții zilnice\", \"Lucru la proiect\".';

  @override
  String get settingsHabitsShowCasePrivateTooltip =>
      'Utilizați acest comutator pentru a marca obiceiul ca privat. Obiceiurile private sunt vizibile numai pentru dvs. și nu vor fi partajate cu alte persoane. Exemple: \"Jurnal personal\", \"Meditație\".';

  @override
  String get settingsHabitsShowCaseStarDateTooltip =>
      'Selectați data de la care doriți să începeți urmărirea acestui obicei. Acest lucru ajută la definirea momentului în care începe obiceiul și permite monitorizarea exactă a progresului. Exemplu: \"1 iulie 2025\".';

  @override
  String get settingsHabitsShowCaseStartTimeTooltip =>
      'Setați ora de la care acest obicei ar trebui să fie vizibil sau să înceapă să apară în programul dvs. Acest lucru vă ajută să vă organizați ziua eficient. Exemplu: \"7:00 AM\".';

  @override
  String get settingsHabitsStoryLabel => 'Istoricul completării obiceiurilor';

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
  String get settingsMatrixAcceptIncomingVerificationLabel =>
      'Acceptă verificarea';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'Celălalt dispozitiv afișează emoji, continuați';

  @override
  String get settingsMatrixCancel => 'Anulare';

  @override
  String get settingsMatrixCancelVerificationLabel => 'Anulează verificarea';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Acceptați pe celălalt dispozitiv pentru a continua';

  @override
  String get settingsMatrixDeleteLabel => 'Șterge';

  @override
  String get settingsMatrixDone => 'Gata';

  @override
  String get settingsMatrixEnterValidUrl => 'Introduceți o adresă URL validă';

  @override
  String get settingsMatrixHomeserverConfigTitle =>
      'Configurare Matrix Homeserver';

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
  String get settingsMatrixQrTextPage =>
      'Scanați acest cod QR pentru a invita dispozitivul într-o cameră de sincronizare.';

  @override
  String get settingsMatrixRoomConfigTitle =>
      'Configurare cameră de sincronizare Matrix';

  @override
  String get settingsMatrixRoomIdLabel => 'ID cameră';

  @override
  String get settingsMatrixSaveLabel => 'Salvează';

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
  String get settingsMatrixUserNameTooShort =>
      'Numele de utilizator este prea scurt';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Anulat pe celălalt dispozitiv...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Am înțeles';

  @override
  String settingsMatrixVerificationSuccessLabel(
      String deviceName, String deviceID) {
    return 'Ați verificat cu succes $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Confirmați pe celălalt dispozitiv că emoji-urile de mai jos sunt afișate pe ambele dispozitive, în aceeași ordine:';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Confirmați că emoji-urile de mai jos sunt afișate pe ambele dispozitive, în aceeași ordine:';

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
  String get settingsMeasurableShowCaseAggreTypeTooltip =>
      'Selectați tipul implicit de agregare pentru datele măsurabile. Aceasta determină modul în care datele vor fi rezumate în timp. \nOpțiuni: \'dailySum\', \'dailyMax\', \'dailyAvg\', \'hourlySum\'.';

  @override
  String get settingsMeasurableShowCaseDelTooltip =>
      'Faceți clic pe acest buton pentru a șterge tipul măsurabil. Rețineți că această acțiune este ireversibilă, așa că asigurați-vă că doriți să eliminați tipul măsurabil înainte de a continua.';

  @override
  String get settingsMeasurableShowCaseDescrTooltip =>
      'Furnizați o descriere scurtă și semnificativă a tipului măsurabil. Includeți orice detalii relevante sau context pentru a defini clar scopul și importanța acestuia. \nExemple: \'Greutatea corporală măsurată în kilograme\'';

  @override
  String get settingsMeasurableShowCaseNameTooltip =>
      'Introduceți un nume clar și descriptiv pentru tipul măsurabil.\nEvitați numele prea lungi și faceți-l suficient de concis pentru a identifica cu ușurință tipul măsurabil. \nExemple: \'Greutate\', \'Tensiune arterială\'.';

  @override
  String get settingsMeasurableShowCasePrivateTooltip =>
      'Comutați această opțiune pentru a marca tipul măsurabil ca privat. Tipurile măsurabile private sunt vizibile numai pentru dvs. și vă ajută să organizați în siguranță datele sensibile sau personale.';

  @override
  String get settingsMeasurableShowCaseUnitTooltip =>
      'Introduceți o abreviere clară și concisă a unității pentru tipul măsurabil. Acest lucru ajută la identificarea cu ușurință a unității de măsură.';

  @override
  String get settingsMeasurablesSearchHint => 'Caută...';

  @override
  String get settingsMeasurablesTitle => 'Măsurători';

  @override
  String get settingsMeasurableUnitLabel => 'Unitatea abrevierii:';

  @override
  String get settingsPlaygroundTitle => 'Developer Playground';

  @override
  String get settingsPlaygroundTutorialTitle => 'Rulează ghidul';

  @override
  String get settingsSpeechAudioWithoutTranscript =>
      'Intrări audio fără transcriere:';

  @override
  String get settingsSpeechAudioWithoutTranscriptButton =>
      'Găsește și transcrie';

  @override
  String get settingsSpeechDownloadButton => 'descarcă';

  @override
  String get settingsSpeechLastActivity => 'Ultima activitate de transcriere:';

  @override
  String get settingsSpeechModelSelectionTitle =>
      'Model de recunoaștere vocală Whisper:';

  @override
  String get settingsSpeechTitle => 'Setări vorbire';

  @override
  String get settingsSyncCancelButton => 'Anuleaă';

  @override
  String get settingsSyncCfgTitle => 'Sincronizare configurare';

  @override
  String get settingsSyncCloseButton => 'Închide';

  @override
  String get settingsSyncCopyButton => 'Copiază';

  @override
  String get settingsSyncCopyCfg => 'Copiază SyncConfig în Clipboard?';

  @override
  String get settingsSyncCopyCfgWarning =>
      'Cu aceste setare, oricine îți poate citi jurnalul. Copiază doar când știi ce faci. SIGUR VREI să continui cu această setare?';

  @override
  String get settingsSyncDeleteConfigButton =>
      'Sterge configurare sincronizare';

  @override
  String get settingsSyncDeleteImapButton => 'Sterge configurarea IMAP';

  @override
  String get settingsSyncDeleteKeyButton => 'Șterge Shared Key';

  @override
  String get settingsSyncFolderLabel => 'IMAP Folder';

  @override
  String get settingsSyncGenKey => 'Generează shared key...';

  @override
  String get settingsSyncGenKeyButton => 'Generează Shared Key';

  @override
  String get settingsSyncHostLabel => 'Host';

  @override
  String get settingsSyncImportButton => 'Import SyncConfig';

  @override
  String get settingsSyncIncompleteConfig => 'Sync config nu e complet';

  @override
  String get settingsSyncLoadingKey => 'Încarcă shared key...';

  @override
  String get settingsSyncNotInitialized => 'Sync nu a fost inițializat...';

  @override
  String get settingsSyncOutboxTitle => 'Sync Outbox';

  @override
  String get settingsSyncPasswordLabel => 'Parolă';

  @override
  String get settingsSyncPasteCfg => 'Import SyncConfig din Clipboard?';

  @override
  String get settingsSyncPasteCfgWarning =>
      'Vrei sa importi SyncConfig din Clipboard? ESTI SIGUR?';

  @override
  String get settingsSyncPortLabel => 'Port';

  @override
  String get settingsSyncReGenKeyButton => 'Sterge cheia secreta';

  @override
  String get settingsSyncSaveButton => 'Salvează IMAP Config';

  @override
  String get settingsSyncScanning => 'Scaneaza Shared Secret...';

  @override
  String get settingsSyncSuccessCloseButton => 'Inchide';

  @override
  String get settingsSyncTestConnectionButton => 'Testeaza configurare IMAP';

  @override
  String get settingsSyncUserLabel => 'Utilizator';

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
  String get settingsTagsSearchHint => 'Caută etichete...';

  @override
  String get settingsTagsShowCaseDeleteTooltip =>
      'Eliminați această etichetă definitiv. Această acțiune nu poate fi anulată.';

  @override
  String get settingsTagsShowCaseHideTooltip =>
      'Activați această opțiune pentru a ascunde această etichetă din sugestii. Utilizați-o pentru etichetele personale sau care nu sunt necesare în mod obișnuit.';

  @override
  String get settingsTagsShowCaseNameTooltip =>
      'Introduceți un nume clar și relevant pentru etichetă. Păstrați-l scurt și descriptiv, astfel încât să puteți clasifica cu ușurință obiceiurile dvs. Exemple: \"Sănătate\", \"Productivitate\", \"Mindfulness\".';

  @override
  String get settingsTagsShowCasePrivateTooltip =>
      'Activați această opțiune pentru a face eticheta privată. Etichetele private sunt vizibile numai pentru dvs. și nu vor fi partajate cu alții.';

  @override
  String get settingsTagsShowCaseTypeTooltip =>
      'Selectați tipul de etichetă pentru a o clasifica corect: \n[Etichetă]-> Categorii generale precum \'Sănătate\' sau \'Productivitate\'. \n[Persoană]-> Utilizați pentru etichetarea anumitor persoane. \n[Poveste]-> Atașați etichete la povești pentru o mai bună organizare.';

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
  String get settingsThemingShowCaseDarkTooltip =>
      'Alegeți tema întunecată pentru un aspect mai întunecat.';

  @override
  String get settingsThemingShowCaseLightTooltip =>
      'Alegeți tema luminoasă pentru un aspect mai luminos.';

  @override
  String get settingsThemingShowCaseModeTooltip =>
      'Selectați modul de temă preferat: Luminos, Întunecat sau Automat.';

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
  String get syncAssistantHeadline => 'Asistent de sincronizare';

  @override
  String get syncAssistantPage1 =>
      'Hai să începem să sincronizăm între Lotti pe Desktop și Lotti de pe telefonul mobil.';

  @override
  String get syncAssistantPage2 =>
      'Comunicația se întâmplă fără că datele tale să circule printr-un serviciu de tip cloud. În loc de asta, îți folosești propriul email pentru a comunica între dispozitive prin mesaje criptate în folderul tău IMAP. Te rog să îți pui setările serverului mai sus.';

  @override
  String get syncAssistantPage2mobile =>
      'Scaneaza te rog codul de bare generat cu setarile tale de pe urmatoarea pagina. Daca nu ai facut deja, te rog porneste configurarea de pe versiune de desktop';

  @override
  String get syncAssistantPage3 =>
      'În plus, pe lângă propriul serviciu de email, este folosită encriptarea cu algoritmul AES-GCM , care folosește o cheie secretă că să comunice între dispozitivele tale. Vom genera această cheie secretă acum și apoi vom genera și un cod QR care conține informația. Te rog să ai grijă cum și cu cine împărți această informație căci conține toate informațiile de access la contul tău de email. Nu arată nimănui acest cod QR!!!';

  @override
  String get syncAssistantStatusEmpty => 'Adauga detaliile de cont valide';

  @override
  String get syncAssistantStatusGenerating => 'Generez un nou secret ..';

  @override
  String get syncAssistantStatusLoading => 'Se incarca ..';

  @override
  String get syncAssistantStatusSaved => 'Configurarea IMAP salvata.';

  @override
  String get syncAssistantStatusSuccess =>
      'Contul a fost configurat cu succes.';

  @override
  String get syncAssistantStatusTesting => 'Testez configurarea IMAP';

  @override
  String get syncAssistantStatusValid => 'Contul este valid.';

  @override
  String get syncDeleteConfigConfirm => 'DA, SUNT SIGUR';

  @override
  String get syncDeleteConfigQuestion =>
      'Doriți să ștergeți configurația de sincronizare?';

  @override
  String get taskCategoryAllLabel => 'toate';

  @override
  String get taskCategoryLabel => 'Categorie:';

  @override
  String get taskCategoryUnassignedLabel => 'neeatribuit';

  @override
  String get taskDueLabel => 'Sarcină de îndeplinit:';

  @override
  String get taskEditHint => 'Editează Sarcina';

  @override
  String get taskEstimateLabel => 'Timp Estimat:';

  @override
  String get taskNameHint => 'Introduceți un nume pentru sarcină';

  @override
  String get taskNameLabel => 'Sarcină:';

  @override
  String get taskNotFound => 'Sarcina nu a fost gasită';

  @override
  String get tasksFilterTitle => 'Filtru sarcini';

  @override
  String get tasksSearchHint => 'Caută sarcini...';

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
  String get viewMenuDisableBrightTheme => 'Dezactivați tema luminoasă';

  @override
  String get viewMenuEnableBrightTheme => 'Activați tema luminoasă';

  @override
  String get viewMenuHideThemeConfig => 'Ascundeți configurația temei';

  @override
  String get viewMenuShowThemeConfig => 'Afișați configurația temei';

  @override
  String get viewMenuTitle => 'Vizualizare';
}

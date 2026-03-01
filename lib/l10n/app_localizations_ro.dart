// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get activeLabel => 'Activ';

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
  String get addActionAddTimer => 'Cronometru';

  @override
  String get addActionAddTimeRecording => 'Adauga timp';

  @override
  String get addActionImportImage => 'Importă imagine';

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
  String get addToDictionary => 'Adaugă la dicționar';

  @override
  String get addToDictionaryDuplicate => 'Termenul există deja în dicționar';

  @override
  String get addToDictionaryNoCategory =>
      'Nu se poate adăuga la dicționar: sarcina nu are categorie';

  @override
  String get addToDictionarySaveFailed => 'Salvarea dicționarului a eșuat';

  @override
  String get addToDictionarySuccess => 'Termen adăugat la dicționar';

  @override
  String get addToDictionaryTooLong => 'Termen prea lung (max 50 caractere)';

  @override
  String get agentActivityLogHeading => 'Jurnal de activitate';

  @override
  String agentControlsActionError(String error) {
    return 'Acțiunea a eșuat: $error';
  }

  @override
  String get agentControlsDeleteButton => 'Șterge definitiv';

  @override
  String get agentControlsDeleteDialogContent =>
      'Toate datele acestui agent vor fi șterse definitiv, inclusiv istoricul, rapoartele și observațiile. Această acțiune nu poate fi anulată.';

  @override
  String get agentControlsDeleteDialogTitle => 'Ștergi agentul?';

  @override
  String get agentControlsDestroyButton => 'Distruge';

  @override
  String get agentControlsDestroyDialogContent =>
      'Agentul va fi dezactivat permanent. Istoricul său va fi păstrat pentru audit.';

  @override
  String get agentControlsDestroyDialogTitle => 'Distrugi agentul?';

  @override
  String get agentControlsDestroyedMessage => 'Acest agent a fost distrus.';

  @override
  String get agentControlsPauseButton => 'Pauză';

  @override
  String get agentControlsReanalyzeButton => 'Reanalizează';

  @override
  String get agentControlsResumeButton => 'Reia';

  @override
  String get agentConversationEmpty => 'Nicio conversație încă.';

  @override
  String agentConversationThreadHeader(String runKey) {
    return 'Trezire $runKey';
  }

  @override
  String agentConversationThreadSummary(
      int messageCount, int toolCallCount, String shortId) {
    return '$messageCount mesaje, $toolCallCount apeluri de instrumente · $shortId';
  }

  @override
  String agentConversationTokenCount(String tokenCount) {
    return '$tokenCount jetoane';
  }

  @override
  String agentDetailErrorLoading(String error) {
    return 'Eroare la încărcarea agentului: $error';
  }

  @override
  String get agentDetailNotFound => 'Agentul nu a fost găsit.';

  @override
  String get agentDetailUnexpectedType => 'Tip de entitate neașteptat.';

  @override
  String get agentEvolutionChartMttrTrend => 'Tendință MTTR';

  @override
  String get agentEvolutionChartSuccessRateTrend => 'Rata de succes';

  @override
  String get agentEvolutionChartVersionPerformance => 'Pe versiune';

  @override
  String get agentEvolutionChartWakeHistory => 'Istoric wake-uri';

  @override
  String get agentEvolutionChatPlaceholder =>
      'Împărtășiți feedback sau întrebați despre performanță...';

  @override
  String get agentEvolutionCurrentDirectives => 'Directive curente';

  @override
  String get agentEvolutionDashboardTitle => 'Performanță';

  @override
  String get agentEvolutionMetricActive => 'Active';

  @override
  String get agentEvolutionMetricAvgDuration => 'Durată medie';

  @override
  String get agentEvolutionMetricFailures => 'Eșecuri';

  @override
  String get agentEvolutionMetricNotAvailable => 'N/D';

  @override
  String get agentEvolutionMetricSuccess => 'Succes';

  @override
  String get agentEvolutionMetricWakes => 'Activări';

  @override
  String get agentEvolutionMttrLabel => 'Timp mediu de rezolvare';

  @override
  String get agentEvolutionNoteRecorded => 'Notă înregistrată';

  @override
  String get agentEvolutionProposalRationale => 'Justificare';

  @override
  String get agentEvolutionProposalRejected =>
      'Propunere respinsă — continuați conversația';

  @override
  String get agentEvolutionProposalTitle => 'Modificări propuse';

  @override
  String get agentEvolutionProposedDirectives => 'Directive propuse';

  @override
  String get agentEvolutionRatingAdequate => 'Adecvat';

  @override
  String get agentEvolutionRatingExcellent => 'Excelent';

  @override
  String get agentEvolutionRatingNeedsWork => 'Necesită îmbunătățiri';

  @override
  String get agentEvolutionRatingPrompt =>
      'Cât de bine funcționează acest șablon?';

  @override
  String get agentEvolutionSessionAbandoned =>
      'Sesiune încheiată fără modificări';

  @override
  String agentEvolutionSessionCompleted(int version) {
    return 'Sesiune finalizată — versiunea $version creată';
  }

  @override
  String get agentEvolutionSessionError =>
      'Sesiunea de evoluție nu a putut fi pornită';

  @override
  String get agentEvolutionSessionStarting =>
      'Se pornește sesiunea de evoluție...';

  @override
  String agentEvolutionSessionTitle(int sessionNumber) {
    return 'Evoluție #$sessionNumber';
  }

  @override
  String get agentEvolutionStatusAbandoned => 'Abandonat';

  @override
  String get agentEvolutionStatusActive => 'Activ';

  @override
  String get agentEvolutionStatusCompleted => 'Finalizat';

  @override
  String get agentInstancesEmptyList => 'Nu s-au găsit instanțe de agent';

  @override
  String get agentInstancesFilterActive => 'Activ';

  @override
  String get agentInstancesFilterAll => 'Toate';

  @override
  String get agentInstancesFilterDestroyed => 'Distrus';

  @override
  String get agentInstancesFilterDormant => 'Inactiv';

  @override
  String get agentInstancesKindAll => 'Toate';

  @override
  String get agentInstancesKindEvolution => 'Evoluție';

  @override
  String get agentInstancesKindTaskAgent => 'Agent de sarcini';

  @override
  String get agentInstancesTitle => 'Instanțe';

  @override
  String get agentLifecycleActive => 'Activ';

  @override
  String get agentLifecycleCreated => 'Creat';

  @override
  String get agentLifecycleDestroyed => 'Distrus';

  @override
  String get agentLifecycleDormant => 'Inactiv';

  @override
  String get agentLifecyclePaused => 'În pauză';

  @override
  String get agentMessageKindAction => 'Acțiune';

  @override
  String get agentMessageKindObservation => 'Observație';

  @override
  String get agentMessageKindSummary => 'Rezumat';

  @override
  String get agentMessageKindSystem => 'Sistem';

  @override
  String get agentMessageKindThought => 'Gând';

  @override
  String get agentMessageKindToolResult => 'Rezultat instrument';

  @override
  String get agentMessageKindUser => 'Utilizator';

  @override
  String get agentMessagePayloadEmpty => '(fără conținut)';

  @override
  String get agentMessagesEmpty => 'Niciun mesaj încă.';

  @override
  String agentMessagesErrorLoading(String error) {
    return 'Eroare la încărcarea mesajelor: $error';
  }

  @override
  String get agentObservationsEmpty =>
      'Nu au fost înregistrate observații încă.';

  @override
  String agentReportErrorLoading(String error) {
    return 'Eroare la încărcarea raportului: $error';
  }

  @override
  String get agentReportHistoryBadge => 'Raport';

  @override
  String get agentReportHistoryEmpty =>
      'Nu există încă instantanee ale raportului.';

  @override
  String get agentReportHistoryError =>
      'A apărut o eroare la încărcarea istoricului rapoartelor.';

  @override
  String get agentReportNone => 'Niciun raport disponibil încă.';

  @override
  String get agentReportSectionTitle => 'Raportul agentului';

  @override
  String get agentRunningIndicator => 'În execuție';

  @override
  String get agentSettingsSubtitle => 'Șabloane, instanțe și monitorizare';

  @override
  String get agentSettingsTitle => 'Agenți';

  @override
  String get agentStateConsecutiveFailures => 'Eșecuri consecutive';

  @override
  String agentStateErrorLoading(String error) {
    return 'Eroare la încărcarea stării: $error';
  }

  @override
  String get agentStateHeading => 'Informații de stare';

  @override
  String get agentStateLastWake => 'Ultima trezire';

  @override
  String get agentStateNextWake => 'Următoarea trezire';

  @override
  String get agentStateRevision => 'Revizie';

  @override
  String get agentStateSleepingUntil => 'Doarme până la';

  @override
  String get agentStateWakeCount => 'Număr de treziri';

  @override
  String get agentTabActivity => 'Activitate';

  @override
  String get agentTabConversations => 'Conversații';

  @override
  String get agentTabObservations => 'Observații';

  @override
  String get agentTabReports => 'Rapoarte';

  @override
  String get agentTabStats => 'Statistici';

  @override
  String get agentTemplateActiveInstancesTitle => 'Instanțe active';

  @override
  String get agentTemplateAggregateTokenUsageHeading =>
      'Utilizare totală de token-uri';

  @override
  String get agentTemplateAllProviders => 'Toți furnizorii';

  @override
  String get agentTemplateAssignedLabel => 'Șablon';

  @override
  String get agentTemplateCreatedSuccess => 'Șablon creat';

  @override
  String get agentTemplateCreateTitle => 'Creează un șablon';

  @override
  String get agentTemplateDeleteConfirm =>
      'Ștergi acest șablon? Această acțiune nu poate fi anulată.';

  @override
  String get agentTemplateDeleteHasInstances =>
      'Nu se poate șterge: agenți activi utilizează acest șablon.';

  @override
  String get agentTemplateDirectivesHint =>
      'Definește personalitatea, tonul, obiectivele și stilul agentului...';

  @override
  String get agentTemplateDirectivesLabel => 'Directive';

  @override
  String get agentTemplateDisplayNameLabel => 'Nume';

  @override
  String get agentTemplateEditTitle => 'Editează șablonul';

  @override
  String get agentTemplateEmptyList =>
      'Niciun șablon încă. Apasă + pentru a crea unul.';

  @override
  String get agentTemplateEvolveAction => 'Evoluează cu IA';

  @override
  String get agentTemplateEvolveApprove => 'Aprobă și salvează';

  @override
  String get agentTemplateEvolveReject => 'Respinge';

  @override
  String get agentTemplateInstanceBreakdownHeading => 'Detaliere pe instanță';

  @override
  String agentTemplateInstanceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de instanțe',
      few: '$count instanțe',
      one: '1 instanță',
      zero: 'Nicio instanță',
    );
    return '$_temp0';
  }

  @override
  String get agentTemplateKindImprover => 'Îmbunătățitor de șablon';

  @override
  String get agentTemplateKindTaskAgent => 'Agent de sarcini';

  @override
  String get agentTemplateMetricsActiveInstances => 'Instanțe active';

  @override
  String get agentTemplateMetricsSuccessRate => 'Rata de succes';

  @override
  String get agentTemplateMetricsTotalWakes => 'Total activări';

  @override
  String get agentTemplateModelLabel => 'ID model';

  @override
  String get agentTemplateModelRequirements =>
      'Sunt afișate doar modelele de raționament cu apeluri de funcții';

  @override
  String get agentTemplateNoMetrics => 'Nu există încă date de performanță';

  @override
  String get agentTemplateNoneAssigned => 'Niciun șablon atribuit';

  @override
  String get agentTemplateNoSuitableModels => 'Nu s-au găsit modele potrivite';

  @override
  String get agentTemplateNoTemplates =>
      'Nu sunt șabloane disponibile. Creează unul în Setări mai întâi.';

  @override
  String get agentTemplateNotFound => 'Șablon negăsit';

  @override
  String get agentTemplateNoVersions => 'Nicio versiune';

  @override
  String get agentTemplateReportsEmpty => 'Niciun raport încă.';

  @override
  String get agentTemplateReportsTab => 'Rapoarte';

  @override
  String get agentTemplateRollbackAction => 'Revino la această versiune';

  @override
  String agentTemplateRollbackConfirm(int version) {
    return 'Revino la versiunea $version? Agentul va folosi această versiune la următoarea trezire.';
  }

  @override
  String get agentTemplateSaveNewVersion => 'Salvează';

  @override
  String get agentTemplateSelectTitle => 'Selectează un șablon';

  @override
  String get agentTemplateSettingsSubtitle =>
      'Gestionează personalitățile și directivele agenților';

  @override
  String get agentTemplateSettingsTab => 'Setări';

  @override
  String get agentTemplateStatsTab => 'Statistici';

  @override
  String get agentTemplateStatusActive => 'Activ';

  @override
  String get agentTemplateStatusArchived => 'Arhivat';

  @override
  String get agentTemplatesTitle => 'Șabloane agent';

  @override
  String get agentTemplateSwitchHint =>
      'Pentru a utiliza un alt șablon, distruge acest agent și creează unul nou.';

  @override
  String get agentTemplateVersionHistoryTitle => 'Istoric versiuni';

  @override
  String agentTemplateVersionLabel(int version) {
    return 'Versiunea $version';
  }

  @override
  String get agentTemplateVersionSaved => 'Versiune nouă salvată';

  @override
  String get agentThreadReportLabel => 'Raport generat în acest ciclu';

  @override
  String get agentTokenUsageCachedTokens => 'Din cache';

  @override
  String get agentTokenUsageEmpty =>
      'Nu s-a înregistrat încă nicio utilizare de tokeni.';

  @override
  String agentTokenUsageErrorLoading(String error) {
    return 'Eroare la încărcarea utilizării tokenilor: $error';
  }

  @override
  String get agentTokenUsageHeading => 'Utilizarea tokenilor';

  @override
  String get agentTokenUsageInputTokens => 'Intrare';

  @override
  String get agentTokenUsageModel => 'Model';

  @override
  String get agentTokenUsageOutputTokens => 'Ieșire';

  @override
  String get agentTokenUsageThoughtsTokens => 'Gânduri';

  @override
  String get agentTokenUsageTotalTokens => 'Total';

  @override
  String get agentTokenUsageWakeCount => 'Treziri';

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
  String get aiBatchToggleTooltip => 'Comutare la înregistrare standard';

  @override
  String get aiConfigApiKeyEmptyError => 'Cheia API nu poate fi goală';

  @override
  String get aiConfigApiKeyFieldLabel => 'Cheie API';

  @override
  String aiConfigAssociatedModelsRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modele asociate eliminate',
      one: '1 model asociat eliminat',
    );
    return '$_temp0';
  }

  @override
  String get aiConfigBaseUrlFieldLabel => 'URL de bază';

  @override
  String get aiConfigCommentFieldLabel => 'Comentariu (Opțional)';

  @override
  String get aiConfigCreateButtonLabel => 'Creează prompt';

  @override
  String get aiConfigDescriptionFieldLabel => 'Descriere (Opțional)';

  @override
  String aiConfigFailedToLoadModels(String error) {
    return 'Eșec la încărcarea modelelor: $error';
  }

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Eșec la încărcarea modelelor. Vă rugăm să încercați din nou.';

  @override
  String get aiConfigFailedToSaveMessage =>
      'Eșec la salvarea configurației. Vă rugăm să încercați din nou.';

  @override
  String get aiConfigInputDataTypesTitle =>
      'Tipuri de date de intrare necesare';

  @override
  String get aiConfigInputModalitiesFieldLabel => 'Modalități de intrare';

  @override
  String get aiConfigInputModalitiesTitle => 'Modalități de intrare';

  @override
  String get aiConfigInvalidUrlError => 'Vă rugăm să introduceți un URL valid';

  @override
  String get aiConfigListCascadeDeleteWarning =>
      'Aceasta va șterge și toate modelele asociate acestui furnizor.';

  @override
  String get aiConfigListDeleteConfirmCancel => 'ANULEAZĂ';

  @override
  String get aiConfigListDeleteConfirmDelete => 'ȘTERGE';

  @override
  String aiConfigListDeleteConfirmMessage(String configName) {
    return 'Sigur doriți să ștergeți „$configName”?';
  }

  @override
  String get aiConfigListDeleteConfirmTitle => 'Confirmați ștergerea';

  @override
  String get aiConfigListEmptyState =>
      'Nu s-au găsit configurații. Adăugați una pentru a începe.';

  @override
  String aiConfigListErrorDeleting(String configName, String error) {
    return 'Eroare la ștergerea $configName: $error';
  }

  @override
  String get aiConfigListErrorLoading => 'Eroare la încărcarea configurațiilor';

  @override
  String aiConfigListItemDeleted(String configName) {
    return '$configName șters';
  }

  @override
  String get aiConfigListUndoDelete => 'ANULEAZĂ';

  @override
  String get aiConfigManageModelsButton => 'Gestionează modele';

  @override
  String aiConfigModelRemovedMessage(String modelName) {
    return '$modelName eliminat din prompt';
  }

  @override
  String get aiConfigModelsTitle => 'Modele disponibile';

  @override
  String get aiConfigNameFieldLabel => 'Nume afișat';

  @override
  String get aiConfigNameTooShortError =>
      'Numele trebuie să aibă cel puțin 3 caractere';

  @override
  String get aiConfigNoModelsAvailable =>
      'Nu sunt configurate modele AI încă. Vă rugăm să adăugați unul în setări.';

  @override
  String get aiConfigNoModelsSelected =>
      'Niciun model selectat. Este necesar cel puțin un model.';

  @override
  String get aiConfigNoProvidersAvailable =>
      'Nu există furnizori de API disponibili. Vă rugăm să adăugați mai întâi un furnizor de API.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Niciun model nu îndeplinește cerințele pentru acest prompt. Vă rugăm să configurați modele cu capabilitățile necesare.';

  @override
  String get aiConfigOutputModalitiesFieldLabel => 'Modalități de ieșire';

  @override
  String get aiConfigOutputModalitiesTitle => 'Modalități de ieșire';

  @override
  String get aiConfigProviderDeletedSuccessfully => 'Furnizor șters cu succes';

  @override
  String get aiConfigProviderFieldLabel => 'Furnizor de inferență';

  @override
  String get aiConfigProviderModelIdFieldLabel => 'ID model furnizor';

  @override
  String get aiConfigProviderModelIdTooShortError =>
      'ID-ul modelului trebuie să aibă cel puțin 3 caractere';

  @override
  String get aiConfigProviderTypeFieldLabel => 'Tip furnizor';

  @override
  String get aiConfigReasoningCapabilityDescription =>
      'Modelul poate efectua raționament pas cu pas';

  @override
  String get aiConfigReasoningCapabilityFieldLabel =>
      'Capacitate de raționament';

  @override
  String get aiConfigRequiredInputDataFieldLabel => 'Date de intrare necesare';

  @override
  String get aiConfigResponseTypeFieldLabel => 'Tip răspuns AI';

  @override
  String get aiConfigResponseTypeNotSelectedError =>
      'Vă rugăm să selectați un tip de răspuns';

  @override
  String get aiConfigResponseTypeSelectHint => 'Selectați tipul de răspuns';

  @override
  String get aiConfigSelectInputDataTypesPrompt =>
      'Selectați tipurile de date necesare...';

  @override
  String get aiConfigSelectModalitiesPrompt => 'Selectați modalitățile';

  @override
  String get aiConfigSelectProviderModalTitle =>
      'Selectați furnizorul de inferență';

  @override
  String get aiConfigSelectProviderNotFound => 'Furnizor de inferență negăsit';

  @override
  String get aiConfigSelectProviderTypeModalTitle =>
      'Selectați tipul de furnizor';

  @override
  String get aiConfigSelectResponseTypeTitle => 'Selectați tipul de răspuns AI';

  @override
  String get aiConfigSystemMessageFieldLabel => 'Mesaj de sistem';

  @override
  String get aiConfigUpdateButtonLabel => 'Actualizează prompt';

  @override
  String get aiConfigUseReasoningDescription =>
      'Dacă este activat, modelul va folosi capacitățile sale de raționament pentru acest prompt.';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Folosește raționamentul';

  @override
  String get aiConfigUserMessageEmptyError =>
      'Mesajul utilizatorului nu poate fi gol';

  @override
  String get aiConfigUserMessageFieldLabel => 'Mesaj utilizator';

  @override
  String get aiFormCancel => 'Anulează';

  @override
  String get aiFormFixErrors =>
      'Vă rugăm să corectați erorile înainte de salvare';

  @override
  String get aiFormNoChanges => 'Nu există modificări nesalvate';

  @override
  String get aiInferenceErrorAuthenticationMessage =>
      'Autentificarea a eșuat. Vă rugăm să verificați cheia API și să vă asigurați că este validă.';

  @override
  String get aiInferenceErrorAuthenticationTitle => 'Autentificare eșuată';

  @override
  String get aiInferenceErrorConnectionFailedMessage =>
      'Nu s-a putut conecta la serviciul AI. Vă rugăm să verificați conexiunea la internet și să vă asigurați că serviciul este accesibil.';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Conexiune eșuată';

  @override
  String get aiInferenceErrorInvalidRequestMessage =>
      'Cererea a fost invalidă. Vă rugăm să verificați configurația și să încercați din nou.';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Cerere invalidă';

  @override
  String get aiInferenceErrorRateLimitMessage =>
      'Ați depășit limita de cereri. Vă rugăm să așteptați un moment înainte de a încerca din nou.';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Limită de cereri depășită';

  @override
  String get aiInferenceErrorRetryButton => 'Încearcă din nou';

  @override
  String get aiInferenceErrorServerMessage =>
      'Serviciul AI a întâmpinat o eroare. Vă rugăm să încercați mai târziu.';

  @override
  String get aiInferenceErrorServerTitle => 'Eroare de server';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Sugestii:';

  @override
  String get aiInferenceErrorTimeoutMessage =>
      'Cererea a durat prea mult. Vă rugăm să încercați din nou sau să verificați dacă serviciul răspunde.';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Timp de așteptare depășit';

  @override
  String get aiInferenceErrorUnknownMessage =>
      'A apărut o eroare neașteptată. Vă rugăm să încercați din nou.';

  @override
  String get aiInferenceErrorUnknownTitle => 'Eroare';

  @override
  String get aiInferenceErrorViewLogButton => 'Vezi jurnalul';

  @override
  String get aiModelSettings => 'Setări model AI';

  @override
  String get aiProviderAlibabaDescription =>
      'Familia de modele Qwen de la Alibaba Cloud prin API-ul DashScope';

  @override
  String get aiProviderAlibabaName => 'Alibaba Cloud (Qwen)';

  @override
  String get aiProviderAnthropicDescription =>
      'Familia de asistenți AI Claude de la Anthropic';

  @override
  String get aiProviderAnthropicName => 'Anthropic Claude';

  @override
  String get aiProviderGeminiDescription => 'Modele AI Gemini de la Google';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiDescription =>
      'API compatibil cu formatul OpenAI';

  @override
  String get aiProviderGenericOpenAiName => 'Compatibil OpenAI';

  @override
  String get aiProviderMistralDescription =>
      'API cloud Mistral AI cu transcriere audio nativă';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderNebiusAiStudioDescription => 'Modele Nebius AI Studio';

  @override
  String get aiProviderNebiusAiStudioName => 'Nebius AI Studio';

  @override
  String get aiProviderOllamaDescription => 'Rulează inferența local cu Ollama';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOpenAiDescription => 'Modele GPT de la OpenAI';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'Modele OpenRouter';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderVoxtralDescription =>
      'Transcriere Voxtral locală (până la 30 min audio, 13 limbi)';

  @override
  String get aiProviderVoxtralName => 'Voxtral (local)';

  @override
  String get aiProviderWhisperDescription =>
      'Transcriere Whisper locală cu API compatibil OpenAI';

  @override
  String get aiProviderWhisperName => 'Whisper (local)';

  @override
  String get aiRealtimeToggleTooltip => 'Comutare la transcriere în direct';

  @override
  String get aiRealtimeTranscribing => 'Transcriere în direct...';

  @override
  String get aiRealtimeTranscriptionError =>
      'Transcriere în direct deconectată. Audio salvat pentru procesare în lot.';

  @override
  String get aiResponseDeleteCancel => 'Anulează';

  @override
  String get aiResponseDeleteConfirm => 'Șterge';

  @override
  String get aiResponseDeleteError =>
      'Eșec la ștergerea răspunsului AI. Vă rugăm să încercați din nou.';

  @override
  String get aiResponseDeleteTitle => 'Șterge răspunsul AI';

  @override
  String get aiResponseDeleteWarning =>
      'Sigur doriți să ștergeți acest răspuns AI? Această acțiune nu poate fi anulată.';

  @override
  String get aiResponseTypeAudioTranscription => 'Transcriere audio';

  @override
  String get aiResponseTypeChecklistUpdates =>
      'Actualizări listă de verificare';

  @override
  String get aiResponseTypeImageAnalysis => 'Analiză de imagine';

  @override
  String get aiResponseTypeImagePromptGeneration => 'Prompt Imagine';

  @override
  String get aiResponseTypePromptGeneration => 'Prompt generat';

  @override
  String get aiResponseTypeTaskSummary => 'Rezumat sarcină';

  @override
  String get aiSettingsAddedLabel => 'Adăugat';

  @override
  String get aiSettingsAddModelButton => 'Adaugă model';

  @override
  String get aiSettingsAddModelTooltip =>
      'Adaugă acest model la furnizorul tău';

  @override
  String get aiSettingsAddProfileButton => 'Adaugă profil';

  @override
  String get aiSettingsAddPromptButton => 'Adaugă prompt';

  @override
  String get aiSettingsAddProviderButton => 'Adaugă furnizor';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Șterge toate filtrele';

  @override
  String get aiSettingsClearFiltersButton => 'Șterge';

  @override
  String aiSettingsDeleteSelectedConfirmMessage(int count) {
    return 'Sigur doriți să ștergeți $count prompturi selectate? Această acțiune nu poate fi anulată.';
  }

  @override
  String get aiSettingsDeleteSelectedConfirmTitle =>
      'Șterge prompturile selectate';

  @override
  String aiSettingsDeleteSelectedLabel(int count) {
    return 'Șterge ($count)';
  }

  @override
  String get aiSettingsDeleteSelectedTooltip => 'Șterge prompturile selectate';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filtrează după capabilitatea $capability';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filtrează după $provider';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip =>
      'Filtrează după capacitatea de raționament';

  @override
  String aiSettingsFilterByResponseTypeTooltip(String responseType) {
    return 'Filtrează după prompturi $responseType';
  }

  @override
  String get aiSettingsModalityAudio => 'Audio';

  @override
  String get aiSettingsModalityText => 'Text';

  @override
  String get aiSettingsModalityVision => 'Viziune';

  @override
  String get aiSettingsNoModelsConfigured => 'Niciun model AI configurat';

  @override
  String get aiSettingsNoPromptsConfigured => 'Niciun prompt AI configurat';

  @override
  String get aiSettingsNoProvidersConfigured => 'Niciun furnizor AI configurat';

  @override
  String get aiSettingsPageTitle => 'Setări AI';

  @override
  String get aiSettingsReasoningLabel => 'Raționament';

  @override
  String get aiSettingsSearchHint => 'Caută configurații AI...';

  @override
  String get aiSettingsSelectLabel => 'Selectează';

  @override
  String get aiSettingsSelectModeTooltip =>
      'Comută modul de selecție pentru operații în lot';

  @override
  String get aiSettingsTabModels => 'Modele';

  @override
  String get aiSettingsTabProfiles => 'Profile';

  @override
  String get aiSettingsTabPrompts => 'Prompturi';

  @override
  String get aiSettingsTabProviders => 'Furnizori';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Creează modele, prompturi și o categorie de test optimizate';

  @override
  String aiSetupWizardDescription(String providerName) {
    return 'Configurează sau actualizează modele, prompturi și categoria de test pentru $providerName';
  }

  @override
  String get aiSetupWizardRunButton => 'Rulează configurarea';

  @override
  String get aiSetupWizardRunLabel => 'Rulează asistentul de configurare';

  @override
  String get aiSetupWizardRunningButton => 'Se rulează...';

  @override
  String get aiSetupWizardSafeToRunMultiple =>
      'Poate fi rulat de mai multe ori - elementele existente vor fi păstrate';

  @override
  String get aiSetupWizardTitle => 'Asistent de configurare AI';

  @override
  String get aiTaskSummaryCancelScheduled => 'Anulează rezumatul programat';

  @override
  String aiTaskSummaryDeleteConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Vrei cu adevărat să ștergi $count rezumate ale sarcinilor? Această acțiune nu poate fi anulată.',
      one:
          'Vrei cu adevărat să ștergi acest rezumat al sarcinii? Această acțiune nu poate fi anulată.',
    );
    return '$_temp0';
  }

  @override
  String get aiTaskSummaryDeleteConfirmTitle => 'Șterge rezumatele sarcinilor';

  @override
  String get aiTaskSummaryDeleteTooltip => 'Șterge toate rezumatele sarcinilor';

  @override
  String get aiTaskSummaryRunning => 'Se gândește la rezumarea sarcinii...';

  @override
  String aiTaskSummaryScheduled(String time) {
    return 'Rezumat în $time';
  }

  @override
  String get aiTaskSummaryTitle => 'Rezumatul sarcinii AI';

  @override
  String get aiTaskSummaryTriggerNow => 'Generează rezumatul acum';

  @override
  String get aiTranscribingAudio => 'Se transcrie audio...';

  @override
  String get apiKeyAddPageTitle => 'Adaugă furnizor';

  @override
  String get apiKeyEditLoadError =>
      'Eșec la încărcarea configurației cheii API';

  @override
  String get apiKeyEditPageTitle => 'Editează furnizor';

  @override
  String get apiKeyFormCreateButton => 'Creează';

  @override
  String get apiKeyFormUpdateButton => 'Actualizează';

  @override
  String get apiKeysSettingsPageTitle => 'Furnizori de inferență AI';

  @override
  String get audioRecordingCancel => 'ANULARE';

  @override
  String get audioRecordingListening => 'Se ascultă...';

  @override
  String get audioRecordingRealtime => 'Transcriere în direct';

  @override
  String get audioRecordings => 'Înregistrări audio';

  @override
  String get audioRecordingStandard => 'Standard';

  @override
  String get audioRecordingStop => 'STOP';

  @override
  String get automaticPrompts => 'Prompturi automate';

  @override
  String get backfillManualDescription =>
      'Solicită toate intrările lipsă indiferent de vechime. Folosiți pentru a recupera lacune de sincronizare mai vechi.';

  @override
  String get backfillManualProcessing => 'Se procesează...';

  @override
  String backfillManualSuccess(int count) {
    return '$count intrări solicitate';
  }

  @override
  String get backfillManualTitle => 'Completare manuală';

  @override
  String get backfillManualTrigger => 'Solicită intrări lipsă';

  @override
  String get backfillReRequestDescription =>
      'Resolicită intrările care au fost solicitate dar niciodată primite. Folosiți când răspunsurile sunt blocate.';

  @override
  String get backfillReRequestProcessing => 'Se resolicită...';

  @override
  String backfillReRequestSuccess(int count) {
    return '$count intrări resolicitate';
  }

  @override
  String get backfillReRequestTitle => 'Resolicită în așteptare';

  @override
  String get backfillReRequestTrigger => 'Resolicită intrări în așteptare';

  @override
  String get backfillSettingsInfo =>
      'Completarea automată solicită intrările lipsă din ultimele 24 de ore. Folosiți completarea manuală pentru intrări mai vechi.';

  @override
  String get backfillSettingsSubtitle =>
      'Gestionează recuperarea lacunelor de sincronizare';

  @override
  String get backfillSettingsTitle => 'Completare sincronizare';

  @override
  String get backfillStatsBackfilled => 'Completat';

  @override
  String get backfillStatsDeleted => 'Șters';

  @override
  String backfillStatsHostsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dispozitive conectate',
      one: '1 dispozitiv conectat',
    );
    return '$_temp0';
  }

  @override
  String get backfillStatsMissing => 'Lipsă';

  @override
  String get backfillStatsNoData =>
      'Nu există date de sincronizare disponibile';

  @override
  String get backfillStatsReceived => 'Primit';

  @override
  String get backfillStatsRefresh => 'Actualizează statisticile';

  @override
  String get backfillStatsRequested => 'Solicitat';

  @override
  String get backfillStatsTitle => 'Statistici de sincronizare';

  @override
  String get backfillStatsTotalEntries => 'Total intrări';

  @override
  String get backfillStatsUnresolvable => 'Nerezolvabil';

  @override
  String get backfillToggleDisabledDescription =>
      'Completare dezactivată - utilă pe rețele cu date limitate';

  @override
  String get backfillToggleEnabledDescription =>
      'Solicită automat intrările de sincronizare lipsă';

  @override
  String get backfillToggleTitle => 'Completare automată';

  @override
  String get basicSettings => 'Setări de bază';

  @override
  String get cancelButton => 'Anulează';

  @override
  String get categoryActiveDescription =>
      'Categoriile inactive nu vor apărea în listele de selecție';

  @override
  String get categoryAiModelDescription =>
      'Controlați ce prompturi AI pot fi folosite cu această categorie';

  @override
  String get categoryAutomaticPromptsDescription =>
      'Configurați prompturi care se execută automat pentru diferite tipuri de conținut';

  @override
  String get categoryCreationError =>
      'Nu s-a putut crea categoria. Vă rugăm să încercați din nou.';

  @override
  String get categoryDefaultLanguageDescription =>
      'Setați o limbă implicită pentru sarcinile din această categorie';

  @override
  String get categoryDeleteConfirm => 'DA, ȘTERGE ACEASTĂ CATEGORIE';

  @override
  String get categoryDeleteConfirmation =>
      'Această acțiune nu poate fi anulată. Toate intrările din această categorie vor fi păstrate, dar nu vor mai fi categorizate.';

  @override
  String get categoryDeleteQuestion => 'Doriți să ștergeți această categorie?';

  @override
  String get categoryDeleteTitle => 'Ștergeți categoria?';

  @override
  String get categoryFavoriteDescription =>
      'Marcați această categorie ca favorită';

  @override
  String get categoryNameRequired => 'Numele categoriei este obligatoriu';

  @override
  String get categoryNotFound => 'Categorie negăsită';

  @override
  String get categoryPrivateDescription =>
      'Ascundeți această categorie când modul privat este activat';

  @override
  String get categoryPromptFilterAll => 'Toate';

  @override
  String get categorySearchPlaceholder => 'Caută categorii...';

  @override
  String get celebrationTapToContinue => 'Atingeți pentru a continua';

  @override
  String get changeSetCardTitle => 'Modificări propuse';

  @override
  String get changeSetConfirmAll => 'Confirmați toate';

  @override
  String get changeSetConfirmError => 'Modificarea nu a putut fi aplicată';

  @override
  String get changeSetItemConfirmed => 'Modificare aplicată';

  @override
  String get changeSetItemRejected => 'Modificare respinsă';

  @override
  String changeSetPendingCount(int count) {
    return '$count în așteptare';
  }

  @override
  String get changeSetSwipeConfirm => 'Confirmați';

  @override
  String get changeSetSwipeReject => 'Respingeți';

  @override
  String get chatInputCancelRealtime => 'Anulează (Esc)';

  @override
  String get chatInputCancelRecording => 'Anulează înregistrarea (Esc)';

  @override
  String get chatInputConfigureModel => 'Configurează modelul';

  @override
  String get chatInputHintDefault =>
      'Întreabă despre sarcinile și productivitatea ta...';

  @override
  String get chatInputHintSelectModel =>
      'Selectează un model pentru a începe conversația';

  @override
  String get chatInputListening => 'Ascultă...';

  @override
  String get chatInputPleaseWait => 'Așteaptă...';

  @override
  String get chatInputProcessing => 'Se procesează...';

  @override
  String get chatInputRecordVoice => 'Înregistrează mesaj vocal';

  @override
  String get chatInputSendTooltip => 'Trimite mesajul';

  @override
  String get chatInputStartRealtime => 'Pornește transcrierea în timp real';

  @override
  String get chatInputStopRealtime => 'Oprește transcrierea în timp real';

  @override
  String get chatInputStopTranscribe => 'Oprește și transcrie';

  @override
  String get checklistAddItem => 'Adaugă un element nou';

  @override
  String get checklistAllDone => 'Toate elementele sunt finalizate!';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total finalizate';
  }

  @override
  String get checklistDelete => 'Șterge lista de verificare?';

  @override
  String get checklistExportAsMarkdown =>
      'Exportă lista de verificare ca Markdown';

  @override
  String get checklistExportFailed => 'Exportul a eșuat';

  @override
  String get checklistFilterShowAll => 'Arată toate elementele';

  @override
  String get checklistFilterShowOpen => 'Arată elementele deschise';

  @override
  String get checklistFilterStateAll => 'Se arată toate elementele';

  @override
  String get checklistFilterStateOpenOnly => 'Se arată elementele deschise';

  @override
  String checklistFilterToggleSemantics(String state) {
    return 'Comută filtrul listei de verificare (curent: $state)';
  }

  @override
  String get checklistItemArchived => 'Element arhivat';

  @override
  String get checklistItemArchiveUndo => 'Anulează';

  @override
  String get checklistItemDelete => 'Șterge elementul din lista de verificare?';

  @override
  String get checklistItemDeleteCancel => 'Anulează';

  @override
  String get checklistItemDeleteConfirm => 'Confirmă';

  @override
  String get checklistItemDeleted => 'Element șters';

  @override
  String get checklistItemDeleteWarning =>
      'Această acțiune nu poate fi anulată.';

  @override
  String get checklistItemDrag => 'Trage sugestiile în lista de verificare';

  @override
  String get checklistItemUnarchived => 'Element restaurat';

  @override
  String get checklistMarkdownCopied =>
      'Lista de verificare copiată ca Markdown';

  @override
  String get checklistNoSuggestionsTitle => 'Nu există sugestii de acțiuni';

  @override
  String get checklistNothingToExport => 'Nu există elemente de exportat';

  @override
  String get checklistShareHint => 'Apăsare lungă pentru partajare';

  @override
  String get checklistsReorder => 'Reordonează';

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
  String get checklistUpdates => 'Actualizări listă de verificare';

  @override
  String get clearButton => 'Șterge';

  @override
  String get colorLabel => 'Culoare:';

  @override
  String get colorPickerError => 'Culoare Hex invalidă';

  @override
  String get colorPickerHint => 'Introduceți culoarea Hex sau alegeți';

  @override
  String get commonError => 'Eroare';

  @override
  String get commonLoading => 'Se încarcă...';

  @override
  String get commonUnknown => 'Necunoscut';

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
  String get configFlagEnableAgents => 'Activează agenții';

  @override
  String get configFlagEnableAgentsDescription =>
      'Permite agenților AI să monitorizeze și să analizeze autonom sarcinile dvs.';

  @override
  String get configFlagEnableAiStreaming =>
      'Activează streamingul AI pentru acțiunile legate de sarcini';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Transmite răspunsurile AI pentru acțiunile legate de sarcini. Dezactivați pentru a stoca răspunsurile în buffer și a menține interfața mai fluidă.';

  @override
  String get configFlagEnableAutoTaskTldrDescription =>
      'Generează automat rezumate pentru sarcinile dvs. pentru a vă ajuta să înțelegeți rapid starea lor.';

  @override
  String get configFlagEnableCalendarPage => 'Activează pagina Calendar';

  @override
  String get configFlagEnableCalendarPageDescription =>
      'Afișează pagina Calendar în navigarea principală. Vizualizați și gestionați-vă intrările într-o vizualizare calendaristică.';

  @override
  String get configFlagEnableDailyOs => 'Activează DailyOS';

  @override
  String get configFlagEnableDailyOsDescription =>
      'Afișează DailyOS în navigarea principală.';

  @override
  String get configFlagEnableDashboardsPage =>
      'Activează pagina Tablouri de bord';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Afișează pagina Tablouri de bord în navigarea principală. Vizualizați datele și informațiile dvs. în tablouri de bord personalizabile.';

  @override
  String get configFlagEnableEvents => 'Activează evenimentele';

  @override
  String get configFlagEnableEventsDescription =>
      'Afișează funcția Evenimente pentru a crea, urmări și gestiona evenimente în jurnalul dvs.';

  @override
  String get configFlagEnableHabitsPage => 'Activează pagina Obiceiuri';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Afișează pagina Obiceiuri în navigarea principală. Urmăriți și gestionați-vă obiceiurile zilnice aici.';

  @override
  String get configFlagEnableLogging => 'Activează înregistrarea';

  @override
  String get configFlagEnableLoggingDescription =>
      'Activează înregistrarea detaliată pentru depanare. Acest lucru poate afecta performanța.';

  @override
  String get configFlagEnableMatrix => 'Activează sincronizarea Matrix';

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
  String get configFlagEnableSessionRatings =>
      'Activează evaluările de sesiune';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Solicită o evaluare rapidă a sesiunii la oprirea unui cronometru.';

  @override
  String get configFlagEnableTooltip => 'Activează sfaturile';

  @override
  String get configFlagEnableTooltipDescription =>
      'Afișează sfaturi utile în întreaga aplicație pentru a vă ghida prin funcții.';

  @override
  String get configFlagPrivate => 'Arată articolele private?';

  @override
  String get configFlagPrivateDescription =>
      'Activați această opțiune pentru a face intrările dvs. private în mod implicit. Intrările private sunt vizibile numai pentru dvs.';

  @override
  String get configFlagRecordLocation => 'Înregistrează locația';

  @override
  String get configFlagRecordLocationDescription =>
      'Înregistrează automat locația dvs. cu intrări noi. Acest lucru ajută la organizarea și căutarea pe baza locației.';

  @override
  String get configFlagResendAttachments => 'Retrimite atașamentele';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Activați această opțiune pentru a retrimite automat încărcările de atașamente eșuate atunci când conexiunea este restabilită.';

  @override
  String get configFlagUseCloudInferenceDescription =>
      'Utilizați servicii AI bazate pe cloud pentru funcții îmbunătățite. Acest lucru necesită o conexiune la internet.';

  @override
  String get conflictEntityLabel => 'Entitate';

  @override
  String get conflictIdLabel => 'ID';

  @override
  String get conflictsCopyTextFromSync => 'Copiază textul din sincronizare';

  @override
  String get conflictsEmptyDescription =>
      'Totul este sincronizat. Elementele rezolvate rămân disponibile în celălalt filtru.';

  @override
  String get conflictsEmptyTitle => 'Nu s-au detectat conflicte';

  @override
  String get conflictsResolved => 'rezolvat';

  @override
  String get conflictsResolveLocalVersion => 'Rezolvă cu versiunea locală';

  @override
  String get conflictsResolveRemoteVersion =>
      'Rezolvă cu versiunea de la distanță';

  @override
  String get conflictsUnresolved => 'nerezolvat';

  @override
  String get copyAsMarkdown => 'Copiază ca Markdown';

  @override
  String get copyAsText => 'Copiază ca text';

  @override
  String get correctionExampleCancel => 'ANULEAZĂ';

  @override
  String get correctionExampleCaptured =>
      'Corecție salvată pentru învățarea AI';

  @override
  String correctionExamplePending(int seconds) {
    return 'Salvare corecție în ${seconds}s...';
  }

  @override
  String get correctionExamplesEmpty =>
      'Nu s-au capturat corecții încă. Editați un element din listă pentru a adăuga primul exemplu.';

  @override
  String get correctionExamplesSectionDescription =>
      'Când corectați manual elementele listei, acele corecții sunt salvate aici și utilizate pentru a îmbunătăți sugestiile AI.';

  @override
  String get correctionExamplesSectionTitle => 'Exemple de Corecție a Listei';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'Aveți $count corecții. Doar cele mai recente $max vor fi folosite în prompturile AI. Luați în considerare ștergerea exemplelor vechi sau redundante.';
  }

  @override
  String get coverArtAssign => 'Setează ca imagine de copertă';

  @override
  String get coverArtChipActive => 'Copertă';

  @override
  String get coverArtChipSet => 'Setează coperta';

  @override
  String get coverArtRemove => 'Elimină ca imagine de copertă';

  @override
  String get createButton => 'Creează';

  @override
  String get createCategoryTitle => 'Creați categorie:';

  @override
  String get createEntryLabel => 'Creați o intrare nouă';

  @override
  String get createEntryTitle => 'Adaugă';

  @override
  String get createNewLinkedTask => 'Creează o nouă sarcină legată...';

  @override
  String get createPromptsFirst =>
      'Creați mai întâi prompturi AI pentru a le configura aici';

  @override
  String get customColor => 'Culoare personalizată';

  @override
  String get dailyOsActual => 'Real';

  @override
  String get dailyOsAddBlock => 'Adaugă bloc';

  @override
  String get dailyOsAddBudget => 'Adaugă buget';

  @override
  String get dailyOsAddNote => 'Adaugă o notă...';

  @override
  String get dailyOsAgreeToPlan => 'Acceptă planul';

  @override
  String get dailyOsCancel => 'Anulează';

  @override
  String get dailyOsCategory => 'Categorie';

  @override
  String get dailyOsChooseCategory => 'Alegeți o categorie...';

  @override
  String get dailyOsCompletionMessage => 'Felicitări! V-ați finalizat ziua.';

  @override
  String get dailyOsCopyToTomorrow => 'Copiază pentru mâine';

  @override
  String get dailyOsDayComplete => 'Zi finalizată';

  @override
  String get dailyOsDayPlan => 'Planul zilei';

  @override
  String get dailyOsDaySummary => 'Rezumatul zilei';

  @override
  String get dailyOsDelete => 'Șterge';

  @override
  String get dailyOsDeleteBudget => 'Ștergeți bugetul?';

  @override
  String get dailyOsDeleteBudgetConfirm =>
      'Aceasta va elimina bugetul de timp din planul zilei.';

  @override
  String get dailyOsDeletePlannedBlock => 'Ștergeți blocul?';

  @override
  String get dailyOsDeletePlannedBlockConfirm =>
      'Aceasta va elimina blocul planificat din cronologie.';

  @override
  String get dailyOsDoneForToday => 'Gata pentru azi';

  @override
  String get dailyOsDraftMessage =>
      'Planul este ciornă. Acceptați pentru a-l confirma.';

  @override
  String get dailyOsDueToday => 'Scadent azi';

  @override
  String get dailyOsDueTodayShort => 'Azi';

  @override
  String dailyOsDuplicateBudget(String categoryName) {
    return 'Un buget pentru „$categoryName” există deja';
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
      other: '$count ore',
      one: '1 oră',
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
      other: '$count minute',
      one: '1 minut',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsEditBudget => 'Editează bugetul';

  @override
  String get dailyOsEditPlannedBlock => 'Editează blocul planificat';

  @override
  String get dailyOsEndTime => 'Sfârșit';

  @override
  String get dailyOsEntry => 'Intrare';

  @override
  String get dailyOsExpandToMove =>
      'Extinde cronologia pentru a trage acest bloc';

  @override
  String get dailyOsExpandToMoveMore =>
      'Extinde cronologia pentru a muta mai departe';

  @override
  String get dailyOsFailedToLoadBudgets => 'Eșec la încărcarea bugetelor';

  @override
  String get dailyOsFailedToLoadTimeline => 'Eșec la încărcarea cronologiei';

  @override
  String get dailyOsFold => 'Restrânge';

  @override
  String dailyOsHoursMinutesPlanned(int hours, int minutes) {
    return '${hours}h ${minutes}m planificate';
  }

  @override
  String dailyOsHoursPlanned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ore planificate',
      one: '1 oră planificată',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsInvalidTimeRange => 'Interval de timp invalid';

  @override
  String dailyOsMinutesPlanned(int count) {
    return '$count min planificate';
  }

  @override
  String get dailyOsNearLimit => 'Aproape de limită';

  @override
  String get dailyOsNoBudgets => 'Fără bugete de timp';

  @override
  String get dailyOsNoBudgetsHint =>
      'Adăugați bugete pentru a urmări cum vă distribuiți timpul pe categorii.';

  @override
  String get dailyOsNoBudgetWarning => 'Niciun timp planificat';

  @override
  String get dailyOsNote => 'Notă';

  @override
  String get dailyOsNoTimeline => 'Fără intrări în cronologie';

  @override
  String get dailyOsNoTimelineHint =>
      'Porniți un cronometru sau adăugați blocuri planificate pentru a vedea ziua dvs.';

  @override
  String get dailyOsOnTrack => 'Pe drumul cel bun';

  @override
  String get dailyOsOver => 'Depășit';

  @override
  String get dailyOsOverallProgress => 'Progres general';

  @override
  String get dailyOsOverBudget => 'Buget depășit';

  @override
  String get dailyOsOverdue => 'Întârziat';

  @override
  String get dailyOsOverdueShort => 'Târziu';

  @override
  String get dailyOsPlan => 'Plan';

  @override
  String get dailyOsPlanned => 'Planificat';

  @override
  String get dailyOsPlannedDuration => 'Durată planificată';

  @override
  String get dailyOsQuickCreateTask => 'Creează sarcină pentru acest buget';

  @override
  String get dailyOsReAgree => 'Acceptă din nou';

  @override
  String get dailyOsRecorded => 'Înregistrat';

  @override
  String get dailyOsRemaining => 'Rămas';

  @override
  String get dailyOsReviewMessage => 'Modificări detectate. Revizuiți planul.';

  @override
  String get dailyOsSave => 'Salvează';

  @override
  String get dailyOsSelectCategory => 'Selectează categoria';

  @override
  String get dailyOsStartTime => 'Început';

  @override
  String get dailyOsTasks => 'Sarcini';

  @override
  String get dailyOsTimeBudgets => 'Bugete de timp';

  @override
  String dailyOsTimeLeft(String time) {
    return '$time rămas';
  }

  @override
  String get dailyOsTimeline => 'Cronologie';

  @override
  String dailyOsTimeOver(String time) {
    return '+$time depășit';
  }

  @override
  String get dailyOsTimeRange => 'Interval de timp';

  @override
  String get dailyOsTimesUp => 'Timpul a expirat';

  @override
  String get dailyOsTodayButton => 'Astăzi';

  @override
  String get dailyOsUncategorized => 'Necategorizat';

  @override
  String get dailyOsViewModeClassic => 'Clasic';

  @override
  String get dailyOsViewModeDailyOs => 'Daily OS';

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
  String get defaultLanguage => 'Limbă implicită';

  @override
  String get deleteButton => 'Șterge';

  @override
  String get deleteDeviceLabel => 'Șterge dispozitivul';

  @override
  String deviceDeletedSuccess(String deviceName) {
    return 'Dispozitivul $deviceName a fost șters cu succes';
  }

  @override
  String deviceDeleteFailed(String error) {
    return 'Ștergerea dispozitivului a eșuat: $error';
  }

  @override
  String get done => 'Gata';

  @override
  String get doneButton => 'Gata';

  @override
  String get editMenuTitle => 'Editează';

  @override
  String get editorInsertDivider => 'Inserează separator';

  @override
  String get editorPlaceholder => 'Introduceți notițe...';

  @override
  String get enhancedPromptFormAdditionalDetailsTitle => 'Detalii suplimentare';

  @override
  String get enhancedPromptFormAiResponseTypeSubtitle =>
      'Formatul răspunsului așteptat';

  @override
  String get enhancedPromptFormBasicConfigurationTitle => 'Configurare de bază';

  @override
  String get enhancedPromptFormConfigurationOptionsTitle =>
      'Opțiuni de configurare';

  @override
  String get enhancedPromptFormDescription =>
      'Creați prompturi personalizate care pot fi folosite cu modelele dvs. AI pentru a genera tipuri specifice de răspunsuri';

  @override
  String get enhancedPromptFormDescriptionHelperText =>
      'Note opționale despre scopul și utilizarea acestui prompt';

  @override
  String get enhancedPromptFormDisplayNameHelperText =>
      'Un nume descriptiv pentru acest șablon de prompt';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Alegeți din șabloane de prompt predefinite';

  @override
  String get enhancedPromptFormPromptConfigurationTitle => 'Configurare prompt';

  @override
  String get enhancedPromptFormQuickStartDescription =>
      'Începeți cu un șablon predefinit pentru a economisi timp';

  @override
  String get enhancedPromptFormQuickStartTitle => 'Pornire rapidă';

  @override
  String get enhancedPromptFormRequiredInputDataSubtitle =>
      'Tipul de date așteptat de acest prompt';

  @override
  String get enhancedPromptFormSystemMessageHelperText =>
      'Instrucțiuni care definesc comportamentul și stilul de răspuns al AI';

  @override
  String get enhancedPromptFormUserMessageHelperText =>
      'Textul principal al promptului.';

  @override
  String get enterCategoryName => 'Introduceți numele categoriei';

  @override
  String get entryActions => 'Acțiuni';

  @override
  String get entryLabelsActionSubtitle =>
      'Atribuie etichete pentru a organiza această intrare';

  @override
  String get entryLabelsActionTitle => 'Etichete';

  @override
  String get entryLabelsEditTooltip => 'Editează etichetele';

  @override
  String get entryLabelsHeaderTitle => 'Etichete';

  @override
  String get entryLabelsNoLabels => 'Nicio etichetă atribuită';

  @override
  String get entryTypeLabelAiResponse => 'Răspuns AI';

  @override
  String get entryTypeLabelChecklist => 'Listă de verificare';

  @override
  String get entryTypeLabelChecklistItem => 'Element de verificare';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Obicei';

  @override
  String get entryTypeLabelJournalAudio => 'Audio';

  @override
  String get entryTypeLabelJournalEntry => 'Text';

  @override
  String get entryTypeLabelJournalEvent => 'Eveniment';

  @override
  String get entryTypeLabelJournalImage => 'Foto';

  @override
  String get entryTypeLabelMeasurementEntry => 'Măsurătoare';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Sănătate';

  @override
  String get entryTypeLabelSurveyEntry => 'Sondaj';

  @override
  String get entryTypeLabelTask => 'Sarcină';

  @override
  String get entryTypeLabelWorkoutEntry => 'Antrenament';

  @override
  String get errorLoadingPrompts => 'Eroare la încărcarea prompturilor';

  @override
  String get eventNameLabel => 'Eveniment:';

  @override
  String get favoriteLabel => 'Favorit';

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
  String get generateCoverArt => 'Generează copertă';

  @override
  String get generateCoverArtSubtitle =>
      'Creează imagine din descrierea vocală';

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
  String get imageGenerationAcceptButton => 'Acceptă ca copertă';

  @override
  String get imageGenerationCancelEdit => 'Anulează';

  @override
  String get imageGenerationEditPromptButton => 'Editează promptul';

  @override
  String get imageGenerationEditPromptLabel => 'Editează promptul';

  @override
  String get imageGenerationError => 'Generarea imaginii a eșuat';

  @override
  String get imageGenerationGenerating => 'Se generează imaginea...';

  @override
  String get imageGenerationModalTitle => 'Imagine generată';

  @override
  String get imageGenerationRetry => 'Reîncearcă';

  @override
  String imageGenerationSaveError(String error) {
    return 'Salvarea imaginii a eșuat: $error';
  }

  @override
  String imageGenerationWithReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cu $count de imagini de referință',
      few: 'Cu $count imagini de referință',
      one: 'Cu 1 imagine de referință',
      zero: 'Fără imagini de referință',
    );
    return '$_temp0';
  }

  @override
  String get imagePromptGenerationCardTitle => 'Prompt Imagine AI';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Promptul de imagine a fost copiat în clipboard';

  @override
  String get imagePromptGenerationCopyButton => 'Copiază Prompt';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Copiază promptul de imagine în clipboard';

  @override
  String get imagePromptGenerationExpandTooltip => 'Afișează promptul complet';

  @override
  String get imagePromptGenerationFullPromptLabel => 'Prompt Imagine Complet:';

  @override
  String get images => 'Imagini';

  @override
  String get inferenceProfileCreateTitle => 'Creați un profil';

  @override
  String get inferenceProfileDeleteInUseMessage =>
      'Acest profil este utilizat de agenți sau șabloane și nu poate fi șters.';

  @override
  String get inferenceProfileDescriptionLabel => 'Descriere';

  @override
  String get inferenceProfileDesktopOnly => 'Doar desktop';

  @override
  String get inferenceProfileDesktopOnlyDescription =>
      'Disponibil doar pe platformele desktop (ex. pentru modele locale)';

  @override
  String get inferenceProfileEditTitle => 'Editați profilul';

  @override
  String get inferenceProfileImageGeneration => 'Generare de imagini';

  @override
  String get inferenceProfileImageRecognition => 'Recunoaștere de imagini';

  @override
  String get inferenceProfileNameLabel => 'Numele profilului';

  @override
  String get inferenceProfileNameRequired => 'Este necesar un nume de profil';

  @override
  String get inferenceProfileSaveButton => 'Salvați';

  @override
  String get inferenceProfileSelectModel => 'Selectați un model…';

  @override
  String get inferenceProfilesEmpty => 'Niciun profil de inferență';

  @override
  String get inferenceProfilesTitle => 'Profile de inferență';

  @override
  String get inferenceProfileThinking => 'Gândire';

  @override
  String get inferenceProfileThinkingRequired =>
      'Este necesar un model de gândire';

  @override
  String get inferenceProfileTranscription => 'Transcriere';

  @override
  String get inputDataTypeAudioFilesDescription =>
      'Folosește fișiere audio ca intrare';

  @override
  String get inputDataTypeAudioFilesName => 'Fișiere audio';

  @override
  String get inputDataTypeImagesDescription => 'Folosește imagini ca intrare';

  @override
  String get inputDataTypeImagesName => 'Imagini';

  @override
  String get inputDataTypeTaskDescription =>
      'Folosește sarcina curentă ca intrare';

  @override
  String get inputDataTypeTaskName => 'Sarcină';

  @override
  String get inputDataTypeTasksListDescription =>
      'Folosește o listă de sarcini ca intrare';

  @override
  String get inputDataTypeTasksListName => 'Listă de sarcini';

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
  String get journalDeleteQuestion =>
      'Vrei să ștergi această intrare în jurnal?';

  @override
  String get journalDurationLabel => 'Durată:';

  @override
  String get journalFavoriteTooltip => 'Favorit';

  @override
  String get journalFlaggedTooltip => 'Marcat';

  @override
  String get journalHideLinkHint => 'Ascunde linkul';

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
  String get journalShareHint => 'Partajează';

  @override
  String get journalSharePhotoHint => 'Împarte foto';

  @override
  String get journalShowLinkHint => 'Arată linkul';

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
  String get journalUnlinkQuestion =>
      'Sigur doriți să despărțiți această intrare?';

  @override
  String get linkedFromLabel => 'LEGAT DE LA';

  @override
  String get linkedTasksMenuTooltip => 'Opțiuni sarcini legate';

  @override
  String get linkedTasksTitle => 'Sarcini legate';

  @override
  String get linkedToLabel => 'LEGAT LA';

  @override
  String get linkExistingTask => 'Leagă o sarcină existentă...';

  @override
  String get loggingFailedToLoad =>
      'Eșec la încărcarea jurnalelor. Vă rugăm să încercați din nou.';

  @override
  String get loggingFailedToLoadMore =>
      'Eșec la încărcarea mai multor rezultate. Vă rugăm să încercați din nou.';

  @override
  String get loggingSearchFailed =>
      'Căutarea a eșuat. Vă rugăm să încercați din nou.';

  @override
  String get logsSearchHint => 'Caută în toate jurnalele...';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'DA, ȘTERGE BAZA DE DATE';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Sigur doriți să ștergeți baza de date $databaseName?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Șterge ciornele din baza de date';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Șterge baza de date a ciornelor editorului';

  @override
  String get maintenanceDeleteLoggingDb => 'Șterge log-urile din baza de date';

  @override
  String get maintenanceDeleteLoggingDbDescription =>
      'Șterge baza de date de jurnalizare';

  @override
  String get maintenanceDeleteSyncDb => 'Ștergeți baza de date de sincronizare';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Șterge baza de date de sincronizare';

  @override
  String get maintenancePopulateSequenceLog =>
      'Completează jurnalul de secvență de sincronizare';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count intrări indexate';
  }

  @override
  String get maintenancePopulateSequenceLogConfirm => 'DA, COMPLETEAZĂ';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Indexează intrările existente pentru suport de completare';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'Aceasta va scana toate intrările din jurnal și le va adăuga la jurnalul de secvență de sincronizare. Aceasta permite răspunsurile de completare pentru intrările create înainte de adăugarea acestei funcții.';

  @override
  String get maintenancePurgeDeleted => 'Eliminați elementele șterse';

  @override
  String get maintenancePurgeDeletedConfirm => 'Da, șterge tot';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Șterge definitiv toate elementele șterse';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Sigur doriți să ștergeți definitiv toate elementele șterse? Această acțiune nu poate fi anulată.';

  @override
  String get maintenanceRecreateFts5 => 'Recreați indexul full-text';

  @override
  String get maintenanceRecreateFts5Confirm => 'DA, RECREEAZĂ INDEXUL';

  @override
  String get maintenanceRecreateFts5Description =>
      'Recreează indexul de căutare text complet';

  @override
  String get maintenanceRecreateFts5Message =>
      'Sigur doriți să recreați indexul de căutare text complet? Acest lucru poate dura ceva timp.';

  @override
  String get maintenanceReSync => 'Resincronizați mesajele';

  @override
  String get maintenanceReSyncDescription =>
      'Resincronizează mesajele de pe server';

  @override
  String get maintenanceSyncDefinitions =>
      'Sincronizează etichete, măsurabile, tablouri de bord, obiceiuri, categorii, setări AI';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sincronizează etichete, măsurabile, tablouri de bord, obiceiuri, categorii și setări AI';

  @override
  String get manageLinks => 'Gestionează legăturile...';

  @override
  String get matrixStatsError => 'Eroare la încărcarea statisticilor Matrix';

  @override
  String get measurableDeleteConfirm => 'DA, CONFIRM STERGEREA';

  @override
  String get measurableDeleteQuestion =>
      'Vrei sa stergi acest tip de masuratoare?';

  @override
  String get measurableNotFound => 'Masuratoarea nu a fost gasita';

  @override
  String get modalityAudioDescription => 'Capacități de procesare audio';

  @override
  String get modalityAudioName => 'Audio';

  @override
  String get modalityImageDescription => 'Capacități de procesare a imaginilor';

  @override
  String get modalityImageName => 'Imagine';

  @override
  String get modalityTextDescription => 'Conținut și procesare bazată pe text';

  @override
  String get modalityTextName => 'Text';

  @override
  String get modelAddPageTitle => 'Adaugă model';

  @override
  String get modelEditLoadError => 'Eșec la încărcarea configurației modelului';

  @override
  String get modelEditPageTitle => 'Editează modelul';

  @override
  String modelManagementSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modele selectate',
      one: '1 model selectat',
    );
    return '$_temp0';
  }

  @override
  String get modelsSettingsPageTitle => 'Modele AI';

  @override
  String get multiSelectAddButton => 'Adaugă';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Adaugă ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'Nu s-au găsit elemente';

  @override
  String get navTabTitleCalendar => 'DailyOS';

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
  String nestedAiResponsesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count răspunsuri AI',
      one: '1 răspuns AI',
    );
    return '$_temp0';
  }

  @override
  String get noDefaultLanguage => 'Fără limbă implicită';

  @override
  String get noPromptsAvailable => 'Nu există prompturi disponibile';

  @override
  String get noPromptsForType =>
      'Nu există prompturi disponibile pentru acest tip';

  @override
  String get noTasksFound => 'Nu s-au găsit sarcini';

  @override
  String get noTasksToLink => 'Nu sunt sarcini disponibile pentru a fi legate';

  @override
  String get outboxMonitorAttachmentLabel => 'Atașament';

  @override
  String get outboxMonitorDelete => 'șterge';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Șterge';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      'Sigur doriți să ștergeți acest element de sincronizare? Această acțiune nu poate fi anulată.';

  @override
  String get outboxMonitorDeleteFailed =>
      'Ștergerea a eșuat. Vă rugăm să încercați din nou.';

  @override
  String get outboxMonitorDeleteSuccess => 'Element șters';

  @override
  String get outboxMonitorEmptyDescription =>
      'Nu există elemente de sincronizare în această vizualizare.';

  @override
  String get outboxMonitorEmptyTitle => 'Căsuța de trimitere este goală';

  @override
  String get outboxMonitorLabelAll => 'toate';

  @override
  String get outboxMonitorLabelError => 'eroare';

  @override
  String get outboxMonitorLabelPending => 'în așteptare';

  @override
  String get outboxMonitorLabelSent => 'trimis';

  @override
  String get outboxMonitorLabelSuccess => 'succes';

  @override
  String get outboxMonitorNoAttachment => 'fără atașament';

  @override
  String get outboxMonitorPayloadSizeLabel => 'Dimensiune';

  @override
  String get outboxMonitorRetries => 'reîncercare';

  @override
  String get outboxMonitorRetriesLabel => 'Reîncercări';

  @override
  String get outboxMonitorRetry => 'reincercare';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Reîncearcă acum';

  @override
  String get outboxMonitorRetryConfirmMessage =>
      'Reîncercați acest element de sincronizare acum?';

  @override
  String get outboxMonitorRetryFailed =>
      'Reîncercarea a eșuat. Vă rugăm să încercați din nou.';

  @override
  String get outboxMonitorRetryQueued => 'Reîncercare programată';

  @override
  String get outboxMonitorSubjectLabel => 'Subiect';

  @override
  String get outboxMonitorSwitchLabel => 'pornit';

  @override
  String get outboxMonitorVolumeChartTitle => 'Volum de sincronizare zilnic';

  @override
  String get privateLabel => 'Privat';

  @override
  String get promptAddOrRemoveModelsButton => 'Adaugă sau elimină modele';

  @override
  String get promptAddPageTitle => 'Adaugă prompt';

  @override
  String get promptAiResponseTypeDescription => 'Formatul răspunsului așteptat';

  @override
  String get promptAiResponseTypeLabel => 'Tip răspuns AI';

  @override
  String get promptBehaviorDescription =>
      'Configurați modul în care promptul procesează și răspunde';

  @override
  String get promptBehaviorTitle => 'Comportament prompt';

  @override
  String get promptCancelButton => 'Anulează';

  @override
  String get promptContentDescription =>
      'Definiți prompturile de sistem și utilizator';

  @override
  String get promptContentTitle => 'Conținut prompt';

  @override
  String get promptDefaultModelBadge => 'Implicit';

  @override
  String get promptDescriptionHint => 'Descrieți acest prompt';

  @override
  String get promptDescriptionLabel => 'Descriere';

  @override
  String get promptDetailsDescription =>
      'Informații de bază despre acest prompt';

  @override
  String get promptDetailsTitle => 'Detalii prompt';

  @override
  String get promptDisplayNameHint => 'Introduceți un nume prietenos';

  @override
  String get promptDisplayNameLabel => 'Nume afișat';

  @override
  String get promptEditLoadError => 'Eșec la încărcarea promptului';

  @override
  String get promptEditPageTitle => 'Editează promptul';

  @override
  String get promptErrorLoadingModel => 'Eroare la încărcarea modelului';

  @override
  String get promptGenerationCardTitle => 'Prompt de codare AI';

  @override
  String get promptGenerationCopiedSnackbar => 'Prompt copiat în clipboard';

  @override
  String get promptGenerationCopyButton => 'Copiază promptul';

  @override
  String get promptGenerationCopyTooltip => 'Copiază promptul în clipboard';

  @override
  String get promptGenerationExpandTooltip => 'Arată promptul complet';

  @override
  String get promptGenerationFullPromptLabel => 'Prompt complet:';

  @override
  String get promptGoBackButton => 'Înapoi';

  @override
  String get promptLoadingModel => 'Se încarcă modelul...';

  @override
  String get promptModelSelectionDescription =>
      'Alegeți modele compatibile pentru acest prompt';

  @override
  String get promptModelSelectionTitle => 'Selecție model';

  @override
  String get promptNoModelsSelectedError =>
      'Niciun model selectat. Selectați cel puțin un model.';

  @override
  String get promptReasoningModeDescription =>
      'Activați pentru prompturi care necesită gândire profundă';

  @override
  String get promptReasoningModeLabel => 'Mod raționament';

  @override
  String get promptRequiredInputDataDescription =>
      'Tipul de date așteptat de acest prompt';

  @override
  String get promptRequiredInputDataLabel => 'Date de intrare necesare';

  @override
  String get promptSaveButton => 'Salvează promptul';

  @override
  String get promptSelectInputTypeHint => 'Selectați tipul de intrare';

  @override
  String get promptSelectionModalTitle => 'Selectează prompt preconfigurat';

  @override
  String get promptSelectModelsButton => 'Selectează modele';

  @override
  String get promptSelectResponseTypeHint => 'Selectați tipul de răspuns';

  @override
  String get promptSetDefaultButton => 'Setează ca implicit';

  @override
  String get promptSettingsPageTitle => 'Prompturi AI';

  @override
  String get promptSystemPromptHint => 'Introduceți promptul de sistem...';

  @override
  String get promptSystemPromptLabel => 'Prompt de sistem';

  @override
  String get promptTryAgainMessage =>
      'Vă rugăm să încercați din nou sau să contactați suportul';

  @override
  String get promptUsePreconfiguredButton => 'Folosește prompt preconfigurat';

  @override
  String get promptUserPromptHint => 'Introduceți promptul utilizatorului...';

  @override
  String get promptUserPromptLabel => 'Prompt utilizator';

  @override
  String get provisionedSyncBundleImported => 'Cod de provizionare importat';

  @override
  String get provisionedSyncConfigureButton => 'Configurează';

  @override
  String get provisionedSyncCopiedToClipboard => 'Copiat în clipboard';

  @override
  String get provisionedSyncDisconnect => 'Deconectează';

  @override
  String get provisionedSyncDone => 'Sincronizare configurată cu succes';

  @override
  String get provisionedSyncError => 'Configurarea a eșuat';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'A apărut o eroare în timpul configurării. Încearcă din nou.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'Autentificarea a eșuat. Verifică datele de acces și încearcă din nou.';

  @override
  String get provisionedSyncImportButton => 'Importă';

  @override
  String get provisionedSyncImportHint => 'Lipește codul de provizionare aici';

  @override
  String get provisionedSyncImportTitle => 'Configurează sincronizarea';

  @override
  String get provisionedSyncInvalidBundle => 'Cod de provizionare invalid';

  @override
  String get provisionedSyncJoiningRoom =>
      'Se alătură camerei de sincronizare...';

  @override
  String get provisionedSyncLoggingIn => 'Conectare în curs...';

  @override
  String get provisionedSyncPasteClipboard => 'Lipește din clipboard';

  @override
  String get provisionedSyncReady =>
      'Scanează acest cod QR pe dispozitivul tău mobil';

  @override
  String get provisionedSyncRetry => 'Reîncearcă';

  @override
  String get provisionedSyncRotatingPassword => 'Securizarea contului...';

  @override
  String get provisionedSyncScanButton => 'Scanează codul QR';

  @override
  String get provisionedSyncShowQr => 'Arată QR de aprovizionare';

  @override
  String get provisionedSyncSubtitle =>
      'Configurarea sincronizării dintr-un pachet de provizionare';

  @override
  String get provisionedSyncSummaryHomeserver => 'Server';

  @override
  String get provisionedSyncSummaryRoom => 'Cameră';

  @override
  String get provisionedSyncSummaryUser => 'Utilizator';

  @override
  String get provisionedSyncTitle => 'Sincronizare provizionată';

  @override
  String get provisionedSyncVerifyDevicesTitle => 'Verificarea dispozitivelor';

  @override
  String get referenceImageContinue => 'Continuă';

  @override
  String referenceImageContinueWithCount(int count) {
    return 'Continuă ($count)';
  }

  @override
  String get referenceImageLoadError =>
      'Încărcarea imaginilor a eșuat. Te rugăm să încerci din nou.';

  @override
  String get referenceImageSelectionSubtitle =>
      'Alege până la 3 imagini pentru a ghida stilul vizual al IA';

  @override
  String get referenceImageSelectionTitle => 'Selectează imagini de referință';

  @override
  String get referenceImageSkip => 'Sari peste';

  @override
  String get saveButton => 'Salvează';

  @override
  String get saveButtonLabel => 'Salvează';

  @override
  String get saveLabel => 'Salvați';

  @override
  String get saveSuccessful => 'Salvat cu succes';

  @override
  String get searchHint => 'Căutare...';

  @override
  String get searchTasksHint => 'Caută sarcini...';

  @override
  String get selectAllowedPrompts =>
      'Selectați ce prompturi sunt permise pentru această categorie';

  @override
  String get selectButton => 'Selectează';

  @override
  String get selectColor => 'Selectează culoarea';

  @override
  String get selectLanguage => 'Selectează limba';

  @override
  String get sessionRatingCardLabel => 'Evaluare sesiune';

  @override
  String get sessionRatingChallengeJustRight => 'Exact potrivit';

  @override
  String get sessionRatingChallengeTooEasy => 'Prea ușor';

  @override
  String get sessionRatingChallengeTooHard => 'Prea provocator';

  @override
  String get sessionRatingDifficultyLabel => 'Această muncă a fost...';

  @override
  String get sessionRatingEditButton => 'Editează evaluarea';

  @override
  String get sessionRatingEnergyQuestion => 'Cât de energizat te-ai simțit?';

  @override
  String get sessionRatingFocusQuestion => 'Cât de concentrat ai fost?';

  @override
  String get sessionRatingNoteHint => 'Notă scurtă (opțional)';

  @override
  String get sessionRatingProductivityQuestion =>
      'Cât de productivă a fost această sesiune?';

  @override
  String get sessionRatingRateAction => 'Evaluează sesiunea';

  @override
  String get sessionRatingSaveButton => 'Salvează';

  @override
  String get sessionRatingSaveError =>
      'Nu s-a putut salva evaluarea. Vă rugăm să încercați din nou.';

  @override
  String get sessionRatingSkipButton => 'Omite';

  @override
  String get sessionRatingTitle => 'Evaluează această sesiune';

  @override
  String get sessionRatingViewAction => 'Vezi evaluarea';

  @override
  String get settingsAboutAppInformation => 'Informații aplicație';

  @override
  String get settingsAboutAppTagline => 'Jurnalul tău personal';

  @override
  String get settingsAboutBuildType => 'Tip build';

  @override
  String get settingsAboutBuiltWithFlutter =>
      'Dezvoltat cu Flutter și dragoste pentru jurnalizarea personală.';

  @override
  String get settingsAboutCredits => 'Credite';

  @override
  String get settingsAboutJournalEntries => 'Intrări jurnal';

  @override
  String get settingsAboutPlatform => 'Platformă';

  @override
  String get settingsAboutThankYou => 'Mulțumim că folosești Lotti!';

  @override
  String get settingsAboutTitle => 'Despre Lotti';

  @override
  String get settingsAboutVersion => 'Versiune';

  @override
  String get settingsAboutYourData => 'Datele tale';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'Aflați mai multe despre aplicația Lotti';

  @override
  String get settingsAdvancedConflictsSubtitle =>
      'Rezolvați conflictele de sincronizare pentru a asigura consistența datelor';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Importați date legate de sănătate din surse externe';

  @override
  String get settingsAdvancedLogsSubtitle =>
      'Accesați și examinați log-urile aplicației pentru depanare';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Efectuați sarcini de întreținere pentru a optimiza performanța aplicației';

  @override
  String get settingsAdvancedMatrixSyncSubtitle =>
      'Configurați și gestionați setările de sincronizare Matrix';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Vizualizați și gestionați elementele care așteaptă sincronizarea';

  @override
  String get settingsAdvancedTitle => 'Setari Avansate';

  @override
  String get settingsAiApiKeys => 'Furnizori de inferență AI';

  @override
  String get settingsAiModels => 'Modele AI';

  @override
  String get settingsCategoriesAddTooltip => 'Adaugă categorie';

  @override
  String get settingsCategoriesDetailsLabel => 'Detalii categorie';

  @override
  String get settingsCategoriesDuplicateError => 'Categoria există deja';

  @override
  String get settingsCategoriesEmptyState => 'Nu s-au găsit categorii';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Creați o categorie pentru a organiza intrările dvs.';

  @override
  String get settingsCategoriesErrorLoading =>
      'Eroare la încărcarea categoriilor';

  @override
  String get settingsCategoriesHasAiSettings => 'Setări AI';

  @override
  String get settingsCategoriesHasAutomaticPrompts => 'AI automat';

  @override
  String get settingsCategoriesHasDefaultLanguage => 'Limbă implicită';

  @override
  String get settingsCategoriesNameLabel => 'Numele categoriei:';

  @override
  String get settingsCategoriesTitle => 'Categorii';

  @override
  String get settingsConflictsResolutionTitle =>
      'Rezolvarea Conflictelor de Sincronizare';

  @override
  String get settingsConflictsTitle => 'Sync cu conflicte';

  @override
  String get settingsDashboardDetailsLabel => 'Detalii tablou de bord';

  @override
  String get settingsDashboardSaveLabel => 'Salvează';

  @override
  String get settingsDashboardsTitle => 'Panouri de bord';

  @override
  String get settingsFlagsTitle => 'Marcaje';

  @override
  String get settingsHabitsDeleteTooltip => 'Șterge Obiceiul';

  @override
  String get settingsHabitsDescriptionLabel => 'Descriere (opțional):';

  @override
  String get settingsHabitsDetailsLabel => 'Detalii obicei';

  @override
  String get settingsHabitsNameLabel => 'Numele obiceiului:';

  @override
  String get settingsHabitsPrivateLabel => 'Privat:';

  @override
  String get settingsHabitsSaveLabel => 'Salvează';

  @override
  String get settingsHabitsTitle => 'Obiceiuri';

  @override
  String get settingsHealthImportFromDate => 'Început';

  @override
  String get settingsHealthImportTitle => 'Health Import';

  @override
  String get settingsHealthImportToDate => 'Sfârșit';

  @override
  String get settingsLabelsActionsTooltip => 'Acțiuni etichetă';

  @override
  String get settingsLabelsCategoriesAdd => 'Adaugă categorie';

  @override
  String get settingsLabelsCategoriesHeading => 'Categorii aplicabile';

  @override
  String get settingsLabelsCategoriesNone => 'Se aplică la toate categoriile';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Elimină';

  @override
  String get settingsLabelsColorHeading => 'Selectează o culoare';

  @override
  String get settingsLabelsColorSubheading => 'Presetări rapide';

  @override
  String get settingsLabelsCreateSuccess => 'Etichetă creată cu succes';

  @override
  String get settingsLabelsCreateTitle => 'Creează etichetă';

  @override
  String get settingsLabelsDeleteCancel => 'Anulează';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Șterge';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return 'Sigur doriți să ștergeți „$labelName”? Sarcinile cu această etichetă vor pierde atribuirea.';
  }

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Șterge eticheta';

  @override
  String settingsLabelsDeleteSuccess(Object labelName) {
    return 'Eticheta „$labelName” ștearsă';
  }

  @override
  String get settingsLabelsDescriptionHint =>
      'Explicați când să aplicați această etichetă';

  @override
  String get settingsLabelsDescriptionLabel => 'Descriere (opțional)';

  @override
  String get settingsLabelsEditTitle => 'Editează eticheta';

  @override
  String get settingsLabelsEmptyState => 'Nicio etichetă încă';

  @override
  String get settingsLabelsEmptyStateHint =>
      'Apăsați butonul + pentru a crea prima etichetă.';

  @override
  String get settingsLabelsErrorLoading => 'Eșec la încărcarea etichetelor';

  @override
  String get settingsLabelsNameHint => 'Bug, Blocant, Sincronizare…';

  @override
  String get settingsLabelsNameLabel => 'Nume etichetă';

  @override
  String get settingsLabelsNameRequired => 'Numele etichetei nu poate fi gol.';

  @override
  String get settingsLabelsPrivateDescription =>
      'Etichetele private apar doar când „Arată intrările private” este activat.';

  @override
  String get settingsLabelsPrivateTitle => 'Etichetă privată';

  @override
  String get settingsLabelsSearchHint => 'Caută etichete…';

  @override
  String get settingsLabelsSubtitle =>
      'Organizați sarcinile cu etichete colorate';

  @override
  String get settingsLabelsTitle => 'Etichete';

  @override
  String get settingsLabelsUpdateSuccess => 'Etichetă actualizată';

  @override
  String settingsLabelsUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sarcini',
      one: '1 sarcină',
    );
    return 'Folosită pe $_temp0';
  }

  @override
  String get settingsLoggingAgentRuntime => 'Execuția agentului';

  @override
  String get settingsLoggingAgentRuntimeSubtitle =>
      'Deciziile și distribuția orchestratorului de activare';

  @override
  String get settingsLoggingAgentWorkflow => 'Fluxul de lucru al agentului';

  @override
  String get settingsLoggingAgentWorkflowSubtitle =>
      'Execuția conversațiilor și apelurile de instrumente';

  @override
  String get settingsLoggingDomainsSubtitle =>
      'Controlați ce domenii scriu în jurnal';

  @override
  String get settingsLoggingDomainsTitle => 'Domenii de jurnalizare';

  @override
  String get settingsLoggingGlobalToggle => 'Activați jurnalizarea';

  @override
  String get settingsLoggingGlobalToggleSubtitle =>
      'Comutatorul principal pentru toată jurnalizarea';

  @override
  String get settingsLoggingSync => 'Sincronizare';

  @override
  String get settingsLoggingSyncSubtitle =>
      'Operațiuni de sincronizare între dispozitive';

  @override
  String get settingsLoggingViewLogsSubtitle =>
      'Răsfoiți și căutați toate înregistrările din jurnal';

  @override
  String get settingsLogsTitle => 'Logs';

  @override
  String get settingsMaintenanceTitle => 'Mentenanță';

  @override
  String get settingsMatrixAccept => 'Acceptă';

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
  String get settingsMatrixCount => 'Număr';

  @override
  String get settingsMatrixDeleteLabel => 'Șterge';

  @override
  String get settingsMatrixDiagnosticCopied =>
      'Informațiile de diagnostic au fost copiate în clipboard';

  @override
  String get settingsMatrixDiagnosticCopyButton => 'Copiază în clipboard';

  @override
  String get settingsMatrixDiagnosticDialogTitle =>
      'Informații de diagnostic pentru sincronizare';

  @override
  String get settingsMatrixDiagnosticShowButton =>
      'Afișează informațiile de diagnostic';

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
  String get settingsMatrixLastUpdated => 'Ultima actualizare:';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Dispozitive neverificate';

  @override
  String get settingsMatrixLoginButtonLabel => 'Conectare';

  @override
  String get settingsMatrixLoginFailed => 'Conectarea a eșuat';

  @override
  String get settingsMatrixLogoutButtonLabel => 'Deconectare';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Rulează sarcini de întreținere Matrix și instrumente de recuperare';

  @override
  String get settingsMatrixMaintenanceTitle => 'Întreținere';

  @override
  String get settingsMatrixMessageType => 'Tip mesaj';

  @override
  String get settingsMatrixMetric => 'Metrică';

  @override
  String get settingsMatrixMetrics => 'Metrici sincronizare';

  @override
  String get settingsMatrixMetricsNoData => 'Metrici sincronizare: fără date';

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
  String get settingsMatrixRefresh => 'Actualizează';

  @override
  String get settingsMatrixRoomConfigTitle =>
      'Configurare cameră de sincronizare Matrix';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Invitație la camera $roomId de la $senderId. Acceptați?';
  }

  @override
  String get settingsMatrixRoomInviteTitle => 'Invitație la cameră';

  @override
  String get settingsMatrixSentMessagesLabel => 'Mesaje trimise:';

  @override
  String get settingsMatrixStartVerificationLabel => 'Începe verificarea';

  @override
  String get settingsMatrixStatsTitle => 'Statistici Matrix';

  @override
  String get settingsMatrixSubtitle =>
      'Configurează sincronizarea criptată de la un capăt la altul';

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
  String get settingsMatrixValue => 'Valoare';

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
  String get settingsMeasurableDetailsLabel => 'Detalii măsurabil';

  @override
  String get settingsMeasurableFavoriteLabel => 'Favorite: ';

  @override
  String get settingsMeasurableNameLabel => 'Numele măsurătorii:';

  @override
  String get settingsMeasurablePrivateLabel => 'Privat: ';

  @override
  String get settingsMeasurableSaveLabel => 'Salvare';

  @override
  String get settingsMeasurablesTitle => 'Măsurători';

  @override
  String get settingsMeasurableUnitLabel => 'Unitatea abrevierii:';

  @override
  String get settingsResetGeminiConfirm => 'Resetează';

  @override
  String get settingsResetGeminiConfirmQuestion =>
      'Aceasta va afișa din nou dialogul de configurare Gemini. Continui?';

  @override
  String get settingsResetGeminiSubtitle =>
      'Afișează din nou dialogul de configurare Gemini AI';

  @override
  String get settingsResetGeminiTitle =>
      'Resetează dialogul de configurare Gemini';

  @override
  String get settingsResetHintsConfirm => 'Confirmă';

  @override
  String get settingsResetHintsConfirmQuestion =>
      'Resetați indiciile din aplicație?';

  @override
  String settingsResetHintsResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count indicii resetate',
      one: 'Un indiciu resetat',
      zero: 'Zero indicii resetate',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetHintsSubtitle =>
      'Șterge sfaturile unice și indiciile de introducere';

  @override
  String get settingsResetHintsTitle => 'Resetează indiciile din aplicație';

  @override
  String get settingsSpeechAudioWithoutTranscript =>
      'Intrări audio fără transcriere:';

  @override
  String get settingsSpeechAudioWithoutTranscriptButton =>
      'Găsește și transcrie';

  @override
  String get settingsSpeechLastActivity => 'Ultima activitate de transcriere:';

  @override
  String get settingsSpeechModelSelectionTitle =>
      'Model de recunoaștere vocală Whisper:';

  @override
  String get settingsSyncOutboxTitle => 'Sync Outbox';

  @override
  String get settingsSyncStatsSubtitle =>
      'Inspectează metricile canalului de sincronizare';

  @override
  String get settingsSyncSubtitle =>
      'Configurează sincronizarea și vizualizează statisticile';

  @override
  String get settingsTagsDeleteTooltip => 'Șterge eticheta';

  @override
  String get settingsTagsDetailsLabel => 'Detalii etichete';

  @override
  String get settingsTagsHideLabel => 'Ascunde din sugestii:';

  @override
  String get settingsTagsPrivateLabel => 'Privat:';

  @override
  String get settingsTagsSaveLabel => 'Salveaza eticheta';

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
  String get settingsThemingTitle => 'Tematică';

  @override
  String get settingThemingDark => 'Temă întunecată';

  @override
  String get settingThemingLight => 'Temă luminoasă';

  @override
  String get showCompleted => 'Afișează finalizate';

  @override
  String get speechDictionaryHelper =>
      'Termeni separați prin punct și virgulă (max 50 caractere) pentru o mai bună recunoaștere vocală';

  @override
  String get speechDictionaryHint => 'macOS; Kirkjubæjarklaustur; Claude Code';

  @override
  String get speechDictionaryLabel => 'Dicționar vocal';

  @override
  String get speechDictionarySectionDescription =>
      'Adăugați termeni care sunt adesea transcrisi greșit de recunoașterea vocală (nume, locuri, termeni tehnici)';

  @override
  String get speechDictionarySectionTitle => 'Recunoaștere vocală';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Un dicționar mare ($count termeni) poate crește costurile API';
  }

  @override
  String get speechModalAddTranscription => 'Adăugați transcriere';

  @override
  String get speechModalSelectLanguage => 'Selectați limba';

  @override
  String get speechModalTitle => 'Recunoaștere vocală';

  @override
  String get speechModalTranscriptionProgress => 'Progresul transcrierii';

  @override
  String get syncCreateNewRoom => 'Creează cameră nouă';

  @override
  String get syncCreateNewRoomInstead => 'Creează cameră nouă în schimb';

  @override
  String get syncDeleteConfigConfirm => 'DA, SUNT SIGUR';

  @override
  String get syncDeleteConfigQuestion =>
      'Doriți să ștergeți configurația de sincronizare?';

  @override
  String get syncDiscoveringRooms => 'Se caută camerele de sincronizare...';

  @override
  String get syncDiscoverRoomsButton => 'Descoperă camerele existente';

  @override
  String get syncDiscoveryError => 'Descoperirea camerelor a eșuat';

  @override
  String get syncEntitiesConfirm => 'ÎNCEPE SINCRONIZAREA';

  @override
  String get syncEntitiesMessage =>
      'Alege datele pe care vrei să le sincronizezi.';

  @override
  String get syncEntitiesSuccessDescription => 'Totul este actualizat.';

  @override
  String get syncEntitiesSuccessTitle => 'Sincronizare finalizată';

  @override
  String get syncInviteErrorForbidden =>
      'Permisiune refuzată. Este posibil să nu aveți acces pentru a invita acest utilizator.';

  @override
  String get syncInviteErrorNetwork =>
      'Eroare de rețea. Verificați conexiunea și încercați din nou.';

  @override
  String get syncInviteErrorRateLimited =>
      'Prea multe cereri. Așteptați un moment și încercați din nou.';

  @override
  String get syncInviteErrorUnknown =>
      'Invitația nu a putut fi trimisă. Încercați din nou mai târziu.';

  @override
  String get syncInviteErrorUserNotFound =>
      'Utilizator negăsit. Verificați că codul scanat este corect.';

  @override
  String syncListCountSummary(String label, int itemCount) {
    String _temp0 = intl.Intl.pluralLogic(
      itemCount,
      locale: localeName,
      other: '$itemCount elemente',
      one: '1 element',
      zero: '0 elemente',
    );
    return '$label · $_temp0';
  }

  @override
  String get syncListPayloadKindLabel => 'Conținut';

  @override
  String get syncListUnknownPayload => 'Conținut necunoscut';

  @override
  String get syncNoRoomsFound =>
      'Nu s-au găsit camere de sincronizare.\nPoți crea o cameră nouă pentru a începe sincronizarea.';

  @override
  String get syncNotLoggedInToast => 'Sincronizarea nu este conectată';

  @override
  String get syncPayloadAgentEntity => 'Entitate agent';

  @override
  String get syncPayloadAgentLink => 'Legătură agent';

  @override
  String get syncPayloadAiConfig => 'Configurare AI';

  @override
  String get syncPayloadAiConfigDelete => 'Ștergere configurare AI';

  @override
  String get syncPayloadBackfillRequest => 'Cerere de completare';

  @override
  String get syncPayloadBackfillResponse => 'Răspuns de completare';

  @override
  String get syncPayloadEntityDefinition => 'Definiție entitate';

  @override
  String get syncPayloadEntryLink => 'Link intrare';

  @override
  String get syncPayloadJournalEntity => 'Intrare jurnal';

  @override
  String get syncPayloadTagEntity => 'Entitate etichetă';

  @override
  String get syncPayloadThemingSelection => 'Selecție temă';

  @override
  String get syncRetry => 'Reîncearcă';

  @override
  String get syncRoomCreatedUnknown => 'Necunoscut';

  @override
  String get syncRoomDiscoveryTitle =>
      'Găsește cameră de sincronizare existentă';

  @override
  String get syncRoomHasContent => 'Are conținut';

  @override
  String get syncRoomUnnamed => 'Cameră fără nume';

  @override
  String get syncRoomVerified => 'Verificat';

  @override
  String get syncSelectRoom => 'Selectează cameră de sincronizare';

  @override
  String get syncSelectRoomDescription =>
      'Am găsit camere de sincronizare existente. Selectează una pentru a te alătura sau creează o cameră nouă.';

  @override
  String get syncSkip => 'Omite';

  @override
  String get syncStepAgentEntities => 'Entități agent';

  @override
  String get syncStepAgentLinks => 'Legături agent';

  @override
  String get syncStepAiSettings => 'Setări AI';

  @override
  String get syncStepCategories => 'Categorii';

  @override
  String get syncStepComplete => 'Finalizat';

  @override
  String get syncStepDashboards => 'Tablouri de bord';

  @override
  String get syncStepHabits => 'Obiceiuri';

  @override
  String get syncStepLabels => 'Etichete';

  @override
  String get syncStepMeasurables => 'Măsurabile';

  @override
  String get syncStepTags => 'Etichete';

  @override
  String get taskAgentCancelTimerTooltip => 'Anulează';

  @override
  String get taskAgentChipLabel => 'Agent';

  @override
  String taskAgentCountdownTooltip(String countdown) {
    return 'Următoarea rulare automată în $countdown';
  }

  @override
  String get taskAgentCreateChipLabel => 'Creează agent';

  @override
  String taskAgentCreateError(String error) {
    return 'Eroare la crearea agentului: $error';
  }

  @override
  String get taskAgentRunNowTooltip => 'Reîmprospătează';

  @override
  String get taskCategoryAllLabel => 'toate';

  @override
  String get taskCategoryLabel => 'Categorie:';

  @override
  String get taskCategoryUnassignedLabel => 'neeatribuit';

  @override
  String get taskDueDateLabel => 'Data scadenței';

  @override
  String taskDueDateWithDate(String date) {
    return 'Scadent: $date';
  }

  @override
  String taskDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Scadent în $days zile',
      one: 'Scadent mâine',
    );
    return '$_temp0';
  }

  @override
  String get taskDueToday => 'Scadent astăzi';

  @override
  String get taskDueTomorrow => 'Scadent mâine';

  @override
  String get taskDueYesterday => 'Scadent ieri';

  @override
  String get taskEstimateLabel => 'Timp Estimat:';

  @override
  String get taskLabelUnassignedLabel => 'neatribuit';

  @override
  String get taskLanguageArabic => 'Arabă';

  @override
  String get taskLanguageBengali => 'Bengaleză';

  @override
  String get taskLanguageBulgarian => 'Bulgară';

  @override
  String get taskLanguageChinese => 'Chineză';

  @override
  String get taskLanguageCroatian => 'Croată';

  @override
  String get taskLanguageCzech => 'Cehă';

  @override
  String get taskLanguageDanish => 'Daneză';

  @override
  String get taskLanguageDutch => 'Olandeză';

  @override
  String get taskLanguageEnglish => 'Engleză';

  @override
  String get taskLanguageEstonian => 'Estonă';

  @override
  String get taskLanguageFinnish => 'Finlandeză';

  @override
  String get taskLanguageFrench => 'Franceză';

  @override
  String get taskLanguageGerman => 'Germană';

  @override
  String get taskLanguageGreek => 'Greacă';

  @override
  String get taskLanguageHebrew => 'Ebraică';

  @override
  String get taskLanguageHindi => 'Hindi';

  @override
  String get taskLanguageHungarian => 'Maghiară';

  @override
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageIndonesian => 'Indoneziană';

  @override
  String get taskLanguageItalian => 'Italiană';

  @override
  String get taskLanguageJapanese => 'Japoneză';

  @override
  String get taskLanguageKorean => 'Coreeană';

  @override
  String get taskLanguageLabel => 'Limbă:';

  @override
  String get taskLanguageLatvian => 'Letonă';

  @override
  String get taskLanguageLithuanian => 'Lituaniană';

  @override
  String get taskLanguageNigerianPidgin => 'Pidgin nigerian';

  @override
  String get taskLanguageNorwegian => 'Norvegiană';

  @override
  String get taskLanguagePolish => 'Poloneză';

  @override
  String get taskLanguagePortuguese => 'Portugheză';

  @override
  String get taskLanguageRomanian => 'Română';

  @override
  String get taskLanguageRussian => 'Rusă';

  @override
  String get taskLanguageSearchPlaceholder => 'Caută limbi...';

  @override
  String get taskLanguageSelectedLabel => 'Limba curentă';

  @override
  String get taskLanguageSerbian => 'Sârbă';

  @override
  String get taskLanguageSlovak => 'Slovacă';

  @override
  String get taskLanguageSlovenian => 'Slovenă';

  @override
  String get taskLanguageSpanish => 'Spaniolă';

  @override
  String get taskLanguageSwahili => 'Swahili';

  @override
  String get taskLanguageSwedish => 'Suedeză';

  @override
  String get taskLanguageThai => 'Thailandeză';

  @override
  String get taskLanguageTurkish => 'Turcă';

  @override
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageUkrainian => 'Ucraineană';

  @override
  String get taskLanguageVietnamese => 'Vietnameză';

  @override
  String get taskLanguageYoruba => 'Yoruba';

  @override
  String get taskNameHint => 'Introduceți un nume pentru sarcină';

  @override
  String get taskNoDueDateLabel => 'Fără dată scadentă';

  @override
  String get taskNoEstimateLabel => 'Fără estimare';

  @override
  String taskOverdueByDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Întârziat cu $days zile',
      one: 'Întârziat cu 1 zi',
    );
    return '$_temp0';
  }

  @override
  String get tasksAddLabelButton => 'Adaugă etichetă';

  @override
  String get tasksFilterTitle => 'Filtru sarcini';

  @override
  String get tasksLabelFilterAll => 'Toate';

  @override
  String get tasksLabelFilterTitle => 'Etichete';

  @override
  String get tasksLabelFilterUnlabeled => 'Fără etichetă';

  @override
  String get tasksLabelsDialogClose => 'Închide';

  @override
  String get tasksLabelsHeaderEditTooltip => 'Editează etichetele';

  @override
  String get tasksLabelsHeaderTitle => 'Etichete';

  @override
  String get tasksLabelsNoLabels => 'Fără etichete';

  @override
  String get tasksLabelsSheetApply => 'Aplică';

  @override
  String get tasksLabelsSheetSearchHint => 'Caută etichete…';

  @override
  String get tasksLabelsSheetTitle => 'Selectează etichete';

  @override
  String get tasksLabelsUpdateFailed => 'Eșec la actualizarea etichetelor';

  @override
  String get tasksPriorityFilterAll => 'Toate';

  @override
  String get tasksPriorityFilterTitle => 'Prioritate';

  @override
  String get tasksPriorityP0 => 'Urgentă';

  @override
  String get tasksPriorityP0Description => 'Urgentă (Cât mai curând)';

  @override
  String get tasksPriorityP1 => 'Ridicată';

  @override
  String get tasksPriorityP1Description => 'Ridicată (Curând)';

  @override
  String get tasksPriorityP2 => 'Medie';

  @override
  String get tasksPriorityP2Description => 'Medie (Implicit)';

  @override
  String get tasksPriorityP3 => 'Scăzută';

  @override
  String get tasksPriorityP3Description => 'Scăzută (Când se poate)';

  @override
  String get tasksPriorityPickerTitle => 'Selectează prioritatea';

  @override
  String get tasksPriorityTitle => 'Prioritate:';

  @override
  String get tasksQuickFilterClear => 'Șterge';

  @override
  String get tasksQuickFilterLabelsActiveTitle => 'Filtre de etichete active';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Neatribuit';

  @override
  String get tasksShowCoverArt => 'Afișează coperta pe carduri';

  @override
  String get tasksShowCreationDate => 'Afișează data creării pe carduri';

  @override
  String get tasksShowDueDate => 'Afișează data scadenței pe carduri';

  @override
  String get tasksSortByCreationDate => 'Creație';

  @override
  String get tasksSortByDate => 'Dată';

  @override
  String get tasksSortByDueDate => 'Scadență';

  @override
  String get tasksSortByLabel => 'Sortare după';

  @override
  String get tasksSortByPriority => 'Prioritate';

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
  String get taskSummaries => 'Rezumate sarcini';

  @override
  String get timeByCategoryChartTitle => 'Timp pe categorie';

  @override
  String get timeByCategoryChartTotalLabel => 'Total';

  @override
  String get unlinkButton => 'Dezleagă';

  @override
  String get unlinkTaskConfirm =>
      'Ești sigur că vrei să dezlegi această sarcină?';

  @override
  String get unlinkTaskTitle => 'Dezleagă sarcina';

  @override
  String get viewMenuTitle => 'Vizualizare';

  @override
  String get whatsNewDoneButton => 'Gata';

  @override
  String get whatsNewSkipButton => 'Omite';
}

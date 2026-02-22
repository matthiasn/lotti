// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get activeLabel => 'Aktivní';

  @override
  String get addActionAddAudioRecording => 'Audiozáznam';

  @override
  String get addActionAddChecklist => 'Kontrolní seznam';

  @override
  String get addActionAddEvent => 'Událost';

  @override
  String get addActionAddImageFromClipboard => 'Vložit obrázek';

  @override
  String get addActionAddPhotos => 'Fotografie';

  @override
  String get addActionAddScreenshot => 'Snímek obrazovky';

  @override
  String get addActionAddTask => 'Úkol';

  @override
  String get addActionAddText => 'Textový záznam';

  @override
  String get addActionAddTimer => 'Časovač';

  @override
  String get addActionAddTimeRecording => 'Záznam času';

  @override
  String get addActionImportImage => 'Importovat obrázek';

  @override
  String get addAudioTitle => 'Audiozáznam';

  @override
  String get addHabitCommentLabel => 'Komentář';

  @override
  String get addHabitDateLabel => 'Dokončeno dne';

  @override
  String get addMeasurementCommentLabel => 'Komentář';

  @override
  String get addMeasurementDateLabel => 'Pozorováno dne';

  @override
  String get addMeasurementSaveButton => 'Uložit';

  @override
  String get addSurveyTitle => 'Vyplnit průzkum';

  @override
  String get addToDictionary => 'Přidat do slovníku';

  @override
  String get addToDictionaryDuplicate => 'Výraz již ve slovníku existuje';

  @override
  String get addToDictionaryNoCategory =>
      'Nelze přidat do slovníku: úkol nemá kategorii';

  @override
  String get addToDictionarySaveFailed => 'Nepodařilo se uložit slovník';

  @override
  String get addToDictionarySuccess => 'Výraz byl přidán do slovníku';

  @override
  String get addToDictionaryTooLong => 'Výraz je příliš dlouhý (max. 50 znaků)';

  @override
  String get agentActivityLogHeading => 'Protokol aktivity';

  @override
  String agentControlsActionError(String error) {
    return 'Akce se nezdařila: $error';
  }

  @override
  String get agentControlsDeleteButton => 'Smazat trvale';

  @override
  String get agentControlsDeleteDialogContent =>
      'Všechna data tohoto agenta budou trvale smazána, včetně historie, reportů a pozorování. Tuto akci nelze vrátit zpět.';

  @override
  String get agentControlsDeleteDialogTitle => 'Smazat agenta?';

  @override
  String get agentControlsDestroyButton => 'Zničit';

  @override
  String get agentControlsDestroyDialogContent =>
      'Agent bude trvale deaktivován. Jeho historie bude zachována pro audit.';

  @override
  String get agentControlsDestroyDialogTitle => 'Zničit agenta?';

  @override
  String get agentControlsDestroyedMessage => 'Tento agent byl zničen.';

  @override
  String get agentControlsPauseButton => 'Pozastavit';

  @override
  String get agentControlsReanalyzeButton => 'Znovu analyzovat';

  @override
  String get agentControlsResumeButton => 'Pokračovat';

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
    return 'Chyba při načítání agenta: $error';
  }

  @override
  String get agentDetailNotFound => 'Agent nebyl nalezen.';

  @override
  String get agentDetailUnexpectedType => 'Neočekávaný typ entity.';

  @override
  String get agentLifecycleActive => 'Aktivní';

  @override
  String get agentLifecycleCreated => 'Vytvořen';

  @override
  String get agentLifecycleDestroyed => 'Zničen';

  @override
  String get agentLifecyclePaused => 'Pozastaven';

  @override
  String get agentMessageKindAction => 'Akce';

  @override
  String get agentMessageKindObservation => 'Pozorování';

  @override
  String get agentMessageKindSummary => 'Shrnutí';

  @override
  String get agentMessageKindSystem => 'Systém';

  @override
  String get agentMessageKindThought => 'Myšlenka';

  @override
  String get agentMessageKindToolResult => 'Výsledek nástroje';

  @override
  String get agentMessageKindUser => 'Uživatel';

  @override
  String get agentMessagePayloadEmpty => '(bez obsahu)';

  @override
  String get agentMessagesEmpty => 'Zatím žádné zprávy.';

  @override
  String agentMessagesErrorLoading(String error) {
    return 'Nepodařilo se načíst zprávy: $error';
  }

  @override
  String get agentObservationsEmpty => 'No observations recorded yet.';

  @override
  String agentReportErrorLoading(String error) {
    return 'Nepodařilo se načíst report: $error';
  }

  @override
  String get agentReportHistoryBadge => 'Report';

  @override
  String get agentReportHistoryEmpty => 'No report snapshots yet.';

  @override
  String get agentReportHistoryError =>
      'An error occurred while loading the report history.';

  @override
  String get agentReportNone => 'Report zatím není k dispozici.';

  @override
  String get agentRunningIndicator => 'Running';

  @override
  String get agentStateConsecutiveFailures => 'Po sobě jdoucí selhání';

  @override
  String agentStateErrorLoading(String error) {
    return 'Nepodařilo se načíst stav: $error';
  }

  @override
  String get agentStateHeading => 'Informace o stavu';

  @override
  String get agentStateLastWake => 'Poslední probuzení';

  @override
  String get agentStateNextWake => 'Příští probuzení';

  @override
  String get agentStateRevision => 'Revize';

  @override
  String get agentStateSleepingUntil => 'Spí do';

  @override
  String get agentStateWakeCount => 'Počet probuzení';

  @override
  String get agentTabActivity => 'Activity';

  @override
  String get agentTabConversations => 'Conversations';

  @override
  String get agentTabObservations => 'Observations';

  @override
  String get agentTabReports => 'Reports';

  @override
  String get agentThreadReportLabel => 'Report produced during this wake';

  @override
  String get aiAssistantActionItemSuggestions => 'Návrhy akčních položek';

  @override
  String get aiAssistantAnalyzeImage => 'Analyzovat obrázek';

  @override
  String get aiAssistantSummarizeTask => 'Shrnout úkol';

  @override
  String get aiAssistantThinking => 'Přemýšlím...';

  @override
  String get aiAssistantTitle => 'AI asistent';

  @override
  String get aiAssistantTranscribeAudio => 'Přepsat zvuk';

  @override
  String get aiBatchToggleTooltip => 'Přepnout na standardní nahrávání';

  @override
  String get aiConfigApiKeyEmptyError => 'API klíč nemůže být prázdný';

  @override
  String get aiConfigApiKeyFieldLabel => 'API klíč';

  @override
  String aiConfigAssociatedModelsRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count přiřazených modelů odebráno',
      one: '1 přiřazený model odebrán',
    );
    return '$_temp0';
  }

  @override
  String get aiConfigBaseUrlFieldLabel => 'Základní URL';

  @override
  String get aiConfigCommentFieldLabel => 'Komentář (volitelné)';

  @override
  String get aiConfigCreateButtonLabel => 'Vytvořit prompt';

  @override
  String get aiConfigDescriptionFieldLabel => 'Popis (volitelné)';

  @override
  String aiConfigFailedToLoadModels(String error) {
    return 'Nepodařilo se načíst modely: $error';
  }

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Nepodařilo se načíst modely. Prosím, zkuste to znovu.';

  @override
  String get aiConfigFailedToSaveMessage =>
      'Nepodařilo se uložit konfiguraci. Prosím, zkuste to znovu.';

  @override
  String get aiConfigInputDataTypesTitle => 'Požadované typy vstupních dat';

  @override
  String get aiConfigInputModalitiesFieldLabel => 'Vstupní modality';

  @override
  String get aiConfigInputModalitiesTitle => 'Vstupní modality';

  @override
  String get aiConfigInvalidUrlError => 'Zadejte prosím platnou URL';

  @override
  String get aiConfigListCascadeDeleteWarning =>
      'Toto také smaže všechny modely spojené s tímto poskytovatelem.';

  @override
  String get aiConfigListDeleteConfirmCancel => 'ZRUŠIT';

  @override
  String get aiConfigListDeleteConfirmDelete => 'SMAZAT';

  @override
  String aiConfigListDeleteConfirmMessage(String configName) {
    return 'Jste si jistý, že chcete smazat \"$configName\"?';
  }

  @override
  String get aiConfigListDeleteConfirmTitle => 'Potvrdit smazání';

  @override
  String get aiConfigListEmptyState =>
      'Žádné konfigurace nalezeny. Přidejte jednu a začněte.';

  @override
  String aiConfigListErrorDeleting(String configName, String error) {
    return 'Chyba při mazání $configName: $error';
  }

  @override
  String get aiConfigListErrorLoading => 'Chyba při načítání konfigurací';

  @override
  String aiConfigListItemDeleted(String configName) {
    return '$configName smazáno';
  }

  @override
  String get aiConfigListUndoDelete => 'ZPĚT';

  @override
  String get aiConfigManageModelsButton => 'Spravovat modely';

  @override
  String aiConfigModelRemovedMessage(String modelName) {
    return '$modelName byl odebrán z promptu';
  }

  @override
  String get aiConfigModelsTitle => 'Dostupné modely';

  @override
  String get aiConfigNameFieldLabel => 'Zobrazovaný název';

  @override
  String get aiConfigNameTooShortError => 'Název musí mít alespoň 3 znaky';

  @override
  String get aiConfigNoModelsAvailable =>
      'Žádné AI modely zatím nejsou konfigurovány. Prosím, přidejte je v nastavení.';

  @override
  String get aiConfigNoModelsSelected =>
      'Nebyly vybrány žádné modely. Je potřeba alespoň jeden model.';

  @override
  String get aiConfigNoProvidersAvailable =>
      'Žádní poskytovatelé API nejsou k dispozici. Prosím, nejprve přidejte poskytovatele API.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Žádný model nesplňuje požadavky pro tento prompt. Prosím, nakonfigurujte modely, které podporují požadované schopnosti.';

  @override
  String get aiConfigOutputModalitiesFieldLabel => 'Výstupní modality';

  @override
  String get aiConfigOutputModalitiesTitle => 'Výstupní modality';

  @override
  String get aiConfigProviderDeletedSuccessfully =>
      'Poskytovatel úspěšně smazán';

  @override
  String get aiConfigProviderFieldLabel => 'Poskytovatel inferencí';

  @override
  String get aiConfigProviderModelIdFieldLabel => 'ID modelu poskytovatele';

  @override
  String get aiConfigProviderModelIdTooShortError =>
      'ID modelu musí mít alespoň 3 znaky';

  @override
  String get aiConfigProviderTypeFieldLabel => 'Typ poskytovatele';

  @override
  String get aiConfigReasoningCapabilityDescription =>
      'Model může provádět krokové uvažování';

  @override
  String get aiConfigReasoningCapabilityFieldLabel => 'Schopnost uvažování';

  @override
  String get aiConfigRequiredInputDataFieldLabel => 'Požadovaná vstupní data';

  @override
  String get aiConfigResponseTypeFieldLabel => 'Typ odpovědi AI';

  @override
  String get aiConfigResponseTypeNotSelectedError =>
      'Prosím, vyberte typ odpovědi';

  @override
  String get aiConfigResponseTypeSelectHint => 'Vyberte typ odpovědi';

  @override
  String get aiConfigSelectInputDataTypesPrompt =>
      'Vyberte požadované typy dat...';

  @override
  String get aiConfigSelectModalitiesPrompt => 'Vyberte modality';

  @override
  String get aiConfigSelectProviderModalTitle =>
      'Vyberte poskytovatele inferencí';

  @override
  String get aiConfigSelectProviderNotFound =>
      'Poskytovatel inferencí nebyl nalezen';

  @override
  String get aiConfigSelectProviderTypeModalTitle =>
      'Vyberte typ poskytovatele';

  @override
  String get aiConfigSelectResponseTypeTitle => 'Vyberte typ AI odpovědi';

  @override
  String get aiConfigSystemMessageFieldLabel => 'Systémová zpráva';

  @override
  String get aiConfigUpdateButtonLabel => 'Aktualizovat prompt';

  @override
  String get aiConfigUseReasoningDescription =>
      'Pokud je povoleno, model použije své schopnosti uvažování pro tento prompt.';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Použít uvažování';

  @override
  String get aiConfigUserMessageEmptyError =>
      'Zpráva uživatele nemůže být prázdná';

  @override
  String get aiConfigUserMessageFieldLabel => 'Zpráva uživatele';

  @override
  String get aiFormCancel => 'Zrušit';

  @override
  String get aiFormFixErrors => 'Prosím, opravte chyby před uložením';

  @override
  String get aiFormNoChanges => 'Žádné neuložené změny';

  @override
  String get aiInferenceErrorAuthenticationMessage =>
      'Autentizace selhala. Prosím, zkontrolujte svůj API klíč a ujistěte se, že je platný.';

  @override
  String get aiInferenceErrorAuthenticationTitle => 'Autentizace selhala';

  @override
  String get aiInferenceErrorConnectionFailedMessage =>
      'Nelze se připojit ke službě AI. Prosím, zkontrolujte své připojení k internetu a ujistěte se, že je služba dostupná.';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Připojení selhalo';

  @override
  String get aiInferenceErrorInvalidRequestMessage =>
      'Žádost byla neplatná. Zkontrolujte prosím svou konfiguraci a zkuste to znovu.';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Neplatný požadavek';

  @override
  String get aiInferenceErrorRateLimitMessage =>
      'Překročili jste limit rychlosti. Prosím, počkejte chvíli, než to zkusíte znovu.';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Limit rychlosti překročen';

  @override
  String get aiInferenceErrorRetryButton => 'Zkusit znovu';

  @override
  String get aiInferenceErrorServerMessage =>
      'AI služba narazila na chybu. Zkuste to prosím později.';

  @override
  String get aiInferenceErrorServerTitle => 'Chyba serveru';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Návrhy:';

  @override
  String get aiInferenceErrorTimeoutMessage =>
      'Žádost trvala příliš dlouho. Zkuste to prosím znovu nebo zkontrolujte, zda služba reaguje.';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Požadavek vypršel';

  @override
  String get aiInferenceErrorUnknownMessage =>
      'Došlo k neočekávané chybě. Prosím, zkuste to znovu.';

  @override
  String get aiInferenceErrorUnknownTitle => 'Chyba';

  @override
  String get aiInferenceErrorViewLogButton => 'Zobrazit log';

  @override
  String get aiModelSettings => 'Nastavení AI modelu';

  @override
  String get aiProviderAnthropicDescription =>
      'Rodina AI asistentů Claude od Anthropic';

  @override
  String get aiProviderAnthropicName => 'Anthropic Claude';

  @override
  String get aiProviderGeminiDescription => 'Google Gemini AI modely';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiDescription =>
      'API kompatibilní s formátem OpenAI';

  @override
  String get aiProviderGenericOpenAiName => 'Kompatibilní s OpenAI';

  @override
  String get aiProviderMistralDescription =>
      'Mistral AI cloudové API s nativním přepisem zvuku';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderNebiusAiStudioDescription => 'Modely Nebius AI Studia';

  @override
  String get aiProviderNebiusAiStudioName => 'Nebius AI Studio';

  @override
  String get aiProviderOllamaDescription =>
      'Spouštějte inferenci lokálně s Ollama';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOpenAiDescription => 'GPT modely od OpenAI';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'Modely OpenRouter';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderVoxtralDescription =>
      'Lokální přepis Voxtral (až 30 min zvuku, 13 jazyků)';

  @override
  String get aiProviderVoxtralName => 'Voxtral (lokální)';

  @override
  String get aiProviderWhisperDescription =>
      'Lokální přepisování s Whisper a kompatibilní API OpenAI';

  @override
  String get aiProviderWhisperName => 'Whisper (lokální)';

  @override
  String get aiRealtimeToggleTooltip => 'Přepnout na živý přepis';

  @override
  String get aiRealtimeTranscribing => 'Živý přepis...';

  @override
  String get aiRealtimeTranscriptionError =>
      'Živý přepis odpojen. Zvuk uložen pro dávkové zpracování.';

  @override
  String get aiResponseDeleteCancel => 'Zrušit';

  @override
  String get aiResponseDeleteConfirm => 'Smazat';

  @override
  String get aiResponseDeleteError =>
      'Nepodařilo se smazat odpověď AI. Prosím, zkuste to znovu.';

  @override
  String get aiResponseDeleteTitle => 'Smazat AI odpověď';

  @override
  String get aiResponseDeleteWarning =>
      'Jste si jistý, že chcete tuto AI odpověď smazat? To nelze vzít zpět.';

  @override
  String get aiResponseTypeAudioTranscription => 'Přepis zvuku';

  @override
  String get aiResponseTypeChecklistUpdates =>
      'Aktualizace kontrolního seznamu';

  @override
  String get aiResponseTypeImageAnalysis => 'Analýza obrázku';

  @override
  String get aiResponseTypeImagePromptGeneration => 'Prompt pro obrázek';

  @override
  String get aiResponseTypePromptGeneration => 'Vygenerovaný prompt';

  @override
  String get aiResponseTypeTaskSummary => 'Shrnutí úkolu';

  @override
  String get aiSettingsAddedLabel => 'Přidáno';

  @override
  String get aiSettingsAddModelButton => 'Přidat model';

  @override
  String get aiSettingsAddModelTooltip =>
      'Přidat tento model ke svému poskytovateli';

  @override
  String get aiSettingsAddPromptButton => 'Přidat prompt';

  @override
  String get aiSettingsAddProviderButton => 'Přidat poskytovatele';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Vymazat všechny filtry';

  @override
  String get aiSettingsClearFiltersButton => 'Vymazat';

  @override
  String aiSettingsDeleteSelectedConfirmMessage(int count) {
    return 'Opravdu chcete smazat $count vybraných výzev? Tuto akci nelze vrátit zpět.';
  }

  @override
  String get aiSettingsDeleteSelectedConfirmTitle => 'Smazat vybrané výzvy';

  @override
  String aiSettingsDeleteSelectedLabel(int count) {
    return 'Smazat ($count)';
  }

  @override
  String get aiSettingsDeleteSelectedTooltip => 'Smazat vybrané výzvy';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filtrovat podle schopnosti $capability';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filtrovat podle $provider';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip =>
      'Filtrovat podle schopnosti uvažování';

  @override
  String aiSettingsFilterByResponseTypeTooltip(String responseType) {
    return 'Filtrovat podle výzev typu $responseType';
  }

  @override
  String get aiSettingsModalityAudio => 'Audio';

  @override
  String get aiSettingsModalityText => 'Text';

  @override
  String get aiSettingsModalityVision => 'Obraz';

  @override
  String get aiSettingsNoModelsConfigured =>
      'Nejsou nakonfigurovány žádné AI modely';

  @override
  String get aiSettingsNoPromptsConfigured =>
      'Nejsou nakonfigurovány žádné AI výzvy';

  @override
  String get aiSettingsNoProvidersConfigured =>
      'Nejsou nakonfigurovány žádní poskytovatelé AI';

  @override
  String get aiSettingsPageTitle => 'Nastavení AI';

  @override
  String get aiSettingsReasoningLabel => 'Uvažování';

  @override
  String get aiSettingsSearchHint => 'Hledat konfigurace AI...';

  @override
  String get aiSettingsSelectLabel => 'Vybrat';

  @override
  String get aiSettingsSelectModeTooltip =>
      'Přepnout režim výběru pro hromadné operace';

  @override
  String get aiSettingsTabModels => 'Modely';

  @override
  String get aiSettingsTabPrompts => 'Výzvy';

  @override
  String get aiSettingsTabProviders => 'Poskytovatelé';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Vytváří optimalizované modely, výzvy a testovací kategorii';

  @override
  String aiSetupWizardDescription(String providerName) {
    return 'Nastavte nebo aktualizujte modely, výzvy a testovací kategorii pro $providerName';
  }

  @override
  String get aiSetupWizardRunButton => 'Spustit nastavení';

  @override
  String get aiSetupWizardRunLabel => 'Spustit průvodce nastavením';

  @override
  String get aiSetupWizardRunningButton => 'Probíhá...';

  @override
  String get aiSetupWizardSafeToRunMultiple =>
      'Bezpečné spustit vícekrát - existující položky budou zachovány';

  @override
  String get aiSetupWizardTitle => 'Průvodce nastavením AI';

  @override
  String get aiTaskSummaryCancelScheduled => 'Zrušit plánovaný souhrn';

  @override
  String get aiTaskSummaryRunning => 'Přemýšlím o shrnutí úkolu...';

  @override
  String aiTaskSummaryScheduled(String time) {
    return 'Shrnutí za $time';
  }

  @override
  String get aiTaskSummaryTitle => 'Shrnutí úkolu AI';

  @override
  String get aiTaskSummaryTriggerNow => 'Vygenerovat shrnutí nyní';

  @override
  String get aiTranscribingAudio => 'Přepisování zvuku...';

  @override
  String get apiKeyAddPageTitle => 'Přidat poskytovatele';

  @override
  String get apiKeyEditLoadError =>
      'Nepodařilo se načíst konfiguraci API klíče';

  @override
  String get apiKeyEditPageTitle => 'Upravit poskytovatele';

  @override
  String get apiKeyFormCreateButton => 'Vytvořit';

  @override
  String get apiKeyFormUpdateButton => 'Aktualizovat';

  @override
  String get apiKeysSettingsPageTitle => 'Poskytovatelé AI inferencí';

  @override
  String get audioRecordingCancel => 'ZRUŠIT';

  @override
  String get audioRecordingListening => 'Naslouchám...';

  @override
  String get audioRecordingRealtime => 'Živý přepis';

  @override
  String get audioRecordings => 'Audiozáznamy';

  @override
  String get audioRecordingStandard => 'Standardní';

  @override
  String get audioRecordingStop => 'STOP';

  @override
  String get automaticPrompts => 'Automatické výzvy';

  @override
  String get backfillManualDescription =>
      'Požádejte o všechny chybějící záznamy bez ohledu na jejich stáří. Použijte toto pro obnovení starších mezer ve synchronizaci.';

  @override
  String get backfillManualProcessing => 'Probíhá zpracování...';

  @override
  String backfillManualSuccess(int count) {
    return 'Požádáno o $count záznamů';
  }

  @override
  String get backfillManualTitle => 'Ruční doplnění';

  @override
  String get backfillManualTrigger => 'Požádat o chybějící záznamy';

  @override
  String get backfillReRequestDescription =>
      'Požádejte znovu o položky, které byly požadovány, ale nikdy nedoručeny. Použijte toto, když jsou odpovědi zaseknuté.';

  @override
  String get backfillReRequestProcessing => 'Znovu se žádá...';

  @override
  String backfillReRequestSuccess(int count) {
    return '$count položek bylo požádáno znovu';
  }

  @override
  String get backfillReRequestTitle => 'Znovu požádat o čekající';

  @override
  String get backfillReRequestTrigger => 'Požádat znovu o čekající položky';

  @override
  String get backfillSettingsInfo =>
      'Automatické žádosti o doplnění chybějících položek za posledních 24 hodin. Použijte ruční záplň pro starší zápisy.';

  @override
  String get backfillSettingsSubtitle => 'Správa obnovy mezer v synchronizaci';

  @override
  String get backfillSettingsTitle => 'Synchronizace doplnění';

  @override
  String get backfillStatsBackfilled => 'Doplněno';

  @override
  String get backfillStatsDeleted => 'Smazáno';

  @override
  String backfillStatsHostsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count připojených zařízení',
      one: '1 připojené zařízení',
    );
    return '$_temp0';
  }

  @override
  String get backfillStatsMissing => 'Chybí';

  @override
  String get backfillStatsNoData => 'Žádná dostupná data synchronizace';

  @override
  String get backfillStatsReceived => 'Přijato';

  @override
  String get backfillStatsRefresh => 'Aktualizovat statistiky';

  @override
  String get backfillStatsRequested => 'Požadováno';

  @override
  String get backfillStatsTitle => 'Statistiky synchronizace';

  @override
  String get backfillStatsTotalEntries => 'Celkem položek';

  @override
  String get backfillStatsUnresolvable => 'Nevyřešitelné';

  @override
  String get backfillToggleDisabledDescription =>
      'Doplnění zakázáno - užitečné při omezených sítích';

  @override
  String get backfillToggleEnabledDescription =>
      'Automaticky požadovat chybějící položky synchronizace';

  @override
  String get backfillToggleTitle => 'Automatické zpětné doplňování';

  @override
  String get basicSettings => 'Základní nastavení';

  @override
  String get cancelButton => 'Zrušit';

  @override
  String get categoryActiveDescription =>
      'Neaktivní kategorie se nebudou zobrazovat ve výběrových seznamech';

  @override
  String get categoryAiModelDescription =>
      'Určete, které AI výzvy lze použít s touto kategorií';

  @override
  String get categoryAutomaticPromptsDescription =>
      'Nastavte výzvy, které se automaticky spouštějí pro různé typy obsahu';

  @override
  String get categoryCreationError => 'Nepodařilo se vytvořit kategorii.';

  @override
  String get categoryDefaultLanguageDescription =>
      'Nastavte výchozí jazyk pro úkoly v této kategorii';

  @override
  String get categoryDeleteConfirm => 'ANO, SMAŽ TUTO KATEGORII';

  @override
  String get categoryDeleteConfirmation =>
      'Tuto akci nelze vrátit zpět. Všechny položky v této kategorii zůstanou, ale již nebudou přiřazeny k žádné kategorii.';

  @override
  String get categoryDeleteQuestion => 'Chcete tuto kategorii smazat?';

  @override
  String get categoryDeleteTitle => 'Smazat kategorii?';

  @override
  String get categoryFavoriteDescription =>
      'Označit tuto kategorii jako oblíbenou';

  @override
  String get categoryNameRequired => 'Název kategorie je povinný';

  @override
  String get categoryNotFound => 'Kategorie nenalezena';

  @override
  String get categoryPrivateDescription =>
      'Skrýt tuto kategorii, když je zapnutý soukromý režim';

  @override
  String get categorySearchPlaceholder => 'Vyhledávat kategorie...';

  @override
  String get celebrationTapToContinue => 'Klepněte pro pokračování';

  @override
  String get chatInputCancelRealtime => 'Zrušit (Esc)';

  @override
  String get chatInputCancelRecording => 'Zrušit nahrávání (Esc)';

  @override
  String get chatInputConfigureModel => 'Konfigurovat model';

  @override
  String get chatInputHintDefault => 'Ptejte se na své úkoly a produktivitu...';

  @override
  String get chatInputHintSelectModel => 'Vyberte model pro zahájení chatu';

  @override
  String get chatInputListening => 'Naslouchám...';

  @override
  String get chatInputPleaseWait => 'Čekejte prosím...';

  @override
  String get chatInputProcessing => 'Zpracování...';

  @override
  String get chatInputRecordVoice => 'Nahrát hlasovou zprávu';

  @override
  String get chatInputSendTooltip => 'Odeslat zprávu';

  @override
  String get chatInputStartRealtime => 'Spustit živý přepis';

  @override
  String get chatInputStopRealtime => 'Zastavit živý přepis';

  @override
  String get chatInputStopTranscribe => 'Zastavit a přepsat';

  @override
  String get checklistAddItem => 'Přidat novou položku';

  @override
  String get checklistAllDone => 'Všechny položky splněny!';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total hotovo';
  }

  @override
  String get checklistDelete => 'Smazat kontrolní seznam?';

  @override
  String get checklistExportAsMarkdown =>
      'Exportovat kontrolní seznam jako Markdown';

  @override
  String get checklistExportFailed => 'Export selhal';

  @override
  String get checklistFilterShowAll => 'Zobrazit všechny položky';

  @override
  String get checklistFilterShowOpen => 'Zobrazit otevřené položky';

  @override
  String get checklistFilterStateAll => 'Zobrazují se všechny položky';

  @override
  String get checklistFilterStateOpenOnly => 'Zobrazují se otevřené položky';

  @override
  String checklistFilterToggleSemantics(String state) {
    return 'Přepnout filtr kontrolního seznamu (aktuální: $state)';
  }

  @override
  String get checklistItemArchived => 'Položka archivována';

  @override
  String get checklistItemArchiveUndo => 'Zpět';

  @override
  String get checklistItemDelete => 'Smazat položku kontrolního seznamu?';

  @override
  String get checklistItemDeleteCancel => 'Zrušit';

  @override
  String get checklistItemDeleteConfirm => 'Potvrdit';

  @override
  String get checklistItemDeleted => 'Položka smazána';

  @override
  String get checklistItemDeleteWarning => 'Tuto akci nelze vrátit zpět.';

  @override
  String get checklistItemDrag => 'Přetáhněte návrhy do kontrolního seznamu';

  @override
  String get checklistItemUnarchived => 'Položka obnovena z archivu';

  @override
  String get checklistMarkdownCopied =>
      'Kontrolní seznam zkopírován jako Markdown';

  @override
  String get checklistNoSuggestionsTitle => 'Žádné navrhované akční položky';

  @override
  String get checklistNothingToExport => 'Žádné položky k exportu';

  @override
  String get checklistShareHint => 'Dlouhé stisknutí pro sdílení';

  @override
  String get checklistsReorder => 'Přeuspořádat';

  @override
  String get checklistsTitle => 'Kontrolní seznamy';

  @override
  String get checklistSuggestionsOutdated => 'Zastaralé';

  @override
  String get checklistSuggestionsRunning =>
      'Přemýšlím o nesledovaných návrzích...';

  @override
  String get checklistSuggestionsTitle => 'Navrhované akční položky';

  @override
  String get checklistUpdates => 'Aktualizace kontrolního seznamu';

  @override
  String get clearButton => 'Vymazat';

  @override
  String get colorLabel => 'Barva:';

  @override
  String get colorPickerError => 'Neplatná hexadecimální barva';

  @override
  String get colorPickerHint => 'Zadejte hexadecimální barvu nebo vyberte';

  @override
  String get commonError => 'Chyba';

  @override
  String get commonLoading => 'Načítání...';

  @override
  String get commonUnknown => 'Neznámé';

  @override
  String get completeHabitFailButton => 'Neúspěch';

  @override
  String get completeHabitSkipButton => 'Přeskočit';

  @override
  String get completeHabitSuccessButton => 'Úspěch';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Pokud je povoleno, aplikace se pokusí generovat vektory pro vaše položky, aby zlepšila vyhledávání a návrhy souvisejícího obsahu.';

  @override
  String get configFlagAutoTranscribeDescription =>
      'Automaticky přepisujte zvukové nahrávky ve vašich položkách. To vyžaduje připojení k internetu.';

  @override
  String get configFlagEnableAgents => 'Povolit agenty';

  @override
  String get configFlagEnableAgentsDescription =>
      'Umožni AI agentům autonomně sledovat a analyzovat tvé úkoly.';

  @override
  String get configFlagEnableAiStreaming =>
      'Povolit AI streamování pro akce úkolů';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Streamujte AI odpovědi pro akce související s úkoly. Vypněte, pokud chcete odpovědi bufferovat a udržet plynulejší rozhraní.';

  @override
  String get configFlagEnableAutoTaskTldrDescription =>
      'Automaticky generujte shrnutí svých úkolů, abyste rychle pochopili jejich stav.';

  @override
  String get configFlagEnableCalendarPage => 'Povolit stránku Kalendáře';

  @override
  String get configFlagEnableCalendarPageDescription =>
      'Zobrazit stránku Kalendář v hlavní navigaci. Prohlížejte a spravujte své položky ve formátu kalendáře.';

  @override
  String get configFlagEnableDailyOs => 'Povolit DailyOS';

  @override
  String get configFlagEnableDailyOsDescription =>
      'Zobrazit DailyOS v hlavní navigaci.';

  @override
  String get configFlagEnableDashboardsPage => 'Povolit stránku Dashboardů';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Zobrazit stránku Přehledy v hlavní navigaci. Prohlížejte svá data a poznatky na přizpůsobitelných přehledech.';

  @override
  String get configFlagEnableEvents => 'Povolit události';

  @override
  String get configFlagEnableEventsDescription =>
      'Zobrazit funkci Události pro vytváření, sledování a správu událostí ve vašem deníku.';

  @override
  String get configFlagEnableHabitsPage => 'Povolit stránku Návyků';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Zobrazit stránku Návyky v hlavní navigaci. Zde sledujte a spravujte své denní návyky.';

  @override
  String get configFlagEnableLogging => 'Povolit protokolování';

  @override
  String get configFlagEnableLoggingDescription =>
      'Povolit podrobné protokolování pro účely ladění. To může ovlivnit výkon.';

  @override
  String get configFlagEnableMatrix => 'Povolit synchronizaci s Matrixem';

  @override
  String get configFlagEnableMatrixDescription =>
      'Povolit integraci s Matrix pro synchronizaci vašich záznamů mezi zařízeními a s ostatními uživateli Matrix.';

  @override
  String get configFlagEnableNotifications => 'Povolit oznámení?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Přijímejte upozornění na připomínky, aktualizace a důležité události.';

  @override
  String get configFlagEnableSessionRatings => 'Povolit hodnocení relací';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Po zastavení časovače zobrazit rychlé hodnocení relace.';

  @override
  String get configFlagEnableTooltip => 'Povolit nápovědy';

  @override
  String get configFlagEnableTooltipDescription =>
      'Zobrazit užitečné nápovědy v celé aplikaci, které vás provedou funkcemi.';

  @override
  String get configFlagPrivate => 'Zobrazit soukromé záznamy?';

  @override
  String get configFlagPrivateDescription =>
      'Povolte to, aby vaše záznamy byly ve výchozím nastavení soukromé. Soukromé záznamy jsou viditelné jen pro vás.';

  @override
  String get configFlagRecordLocation => 'Zaznamenat polohu';

  @override
  String get configFlagRecordLocationDescription =>
      'Automaticky zaznamenejte vaši polohu s novými záznamy. To pomáhá s organizací a vyhledáváním podle polohy.';

  @override
  String get configFlagResendAttachments => 'Odeslat přílohy znovu';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Povolte toto nastavení pro automatické opětovné odeslání neúspěšného nahrávání příloh po obnovení připojení.';

  @override
  String get configFlagUseCloudInferenceDescription =>
      'Používat AI služby v cloudu pro vylepšené funkce. Vyžaduje připojení k internetu.';

  @override
  String get conflictEntityLabel => 'Entita';

  @override
  String get conflictIdLabel => 'ID';

  @override
  String get conflictsCopyTextFromSync => 'Kopírovat text ze synchronizace';

  @override
  String get conflictsEmptyDescription =>
      'Všechno je teď synchronizované. Vyřešené položky zůstávají dostupné v druhém filtru.';

  @override
  String get conflictsEmptyTitle => 'Nebyly zjištěny žádné konflikty';

  @override
  String get conflictsResolved => 'vyřešeno';

  @override
  String get conflictsResolveLocalVersion => 'Vyřešit s místní verzí';

  @override
  String get conflictsResolveRemoteVersion => 'Vyřešit se vzdálenou verzí';

  @override
  String get conflictsUnresolved => 'nevyřešeno';

  @override
  String get copyAsMarkdown => 'Kopírovat jako Markdown';

  @override
  String get copyAsText => 'Kopírovat jako text';

  @override
  String get correctionExampleCancel => 'ZRUŠIT';

  @override
  String get correctionExampleCaptured => 'Oprava uložena pro učení AI';

  @override
  String correctionExamplePending(int seconds) {
    return 'Ukládání opravy za $seconds s...';
  }

  @override
  String get correctionExamplesEmpty =>
      'Zatím žádné opravy. Upravte položku kontrolního seznamu a přidejte svůj první příklad.';

  @override
  String get correctionExamplesSectionDescription =>
      'Když ručně opravujete položky kontrolního seznamu, tyto opravy se uloží zde a použijí ke zlepšení AI návrhů.';

  @override
  String get correctionExamplesSectionTitle =>
      'Příklady opravy kontrolního seznamu';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'Máte $count oprav. V AI promptech se použije pouze nejnovějších $max. Zvažte smazání starých nebo nadbytečných příkladů.';
  }

  @override
  String get coverArtAssign => 'Nastavit jako obal';

  @override
  String get coverArtChipActive => 'Obal';

  @override
  String get coverArtChipSet => 'Nastavit obal';

  @override
  String get coverArtRemove => 'Odebrat jako obal';

  @override
  String get createButton => 'Vytvořit';

  @override
  String get createCategoryTitle => 'Vytvořit kategorii:';

  @override
  String get createEntryLabel => 'Vytvořit novou položku';

  @override
  String get createEntryTitle => 'Přidat';

  @override
  String get createNewLinkedTask => 'Vytvořit nový propojený úkol...';

  @override
  String get createPromptsFirst =>
      'Nejprve vytvořte AI prompty, abyste je zde nakonfigurovali';

  @override
  String get customColor => 'Vlastní barva';

  @override
  String get dailyOsActual => 'Skutečný';

  @override
  String get dailyOsAddBlock => 'Přidat blok';

  @override
  String get dailyOsAddBudget => 'Přidat rozpočet';

  @override
  String get dailyOsAddNote => 'Přidat poznámku...';

  @override
  String get dailyOsAgreeToPlan => 'Souhlasím s plánem';

  @override
  String get dailyOsCancel => 'Zrušit';

  @override
  String get dailyOsCategory => 'Kategorie';

  @override
  String get dailyOsChooseCategory => 'Vyberte kategorii...';

  @override
  String get dailyOsCompletionMessage =>
      'Skvělá práce! Dokončili jste svůj den.';

  @override
  String get dailyOsCopyToTomorrow => 'Kopírovat na zítřek';

  @override
  String get dailyOsDayComplete => 'Den dokončen';

  @override
  String get dailyOsDayPlan => 'Plán dne';

  @override
  String get dailyOsDaySummary => 'Souhrn dne';

  @override
  String get dailyOsDelete => 'Smazat';

  @override
  String get dailyOsDeleteBudget => 'Smazat rozpočet?';

  @override
  String get dailyOsDeleteBudgetConfirm =>
      'Tímto se časový rozpočet odstraní z vašeho denního plánu.';

  @override
  String get dailyOsDeletePlannedBlock => 'Smazat blok?';

  @override
  String get dailyOsDeletePlannedBlockConfirm =>
      'Tímto se odebere plánovaný blok z vaší časové osy.';

  @override
  String get dailyOsDoneForToday => 'Hotovo na dnes';

  @override
  String get dailyOsDraftMessage =>
      'Plán je ve stavu konceptu. Souhlasíte s jeho uzamčením.';

  @override
  String get dailyOsDueToday => 'Termín dnes';

  @override
  String get dailyOsDueTodayShort => 'Dnes';

  @override
  String dailyOsDuplicateBudget(String categoryName) {
    return 'Rozpočet pro \"$categoryName\" již existuje';
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
      other: '$count hodin',
      one: '1 hodina',
    );
    return '$_temp0';
  }

  @override
  String dailyOsDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String dailyOsDurationMinutes(int count) {
    return '$count minut';
  }

  @override
  String get dailyOsEditBudget => 'Upravit rozpočet';

  @override
  String get dailyOsEditPlannedBlock => 'Upravit plánovaný blok';

  @override
  String get dailyOsEndTime => 'Konec';

  @override
  String get dailyOsEntry => 'Záznam';

  @override
  String get dailyOsExpandToMove =>
      'Rozbalte časovou osu pro přetažení tohoto bloku';

  @override
  String get dailyOsExpandToMoveMore => 'Rozbalte časovou osu pro další přesun';

  @override
  String get dailyOsFailedToLoadBudgets => 'Nepodařilo se načíst rozpočty';

  @override
  String get dailyOsFailedToLoadTimeline => 'Nepodařilo se načíst časovou osu';

  @override
  String get dailyOsFold => 'Složit';

  @override
  String dailyOsHoursMinutesPlanned(int hours, int minutes) {
    return '${hours}h ${minutes}m naplánováno';
  }

  @override
  String dailyOsHoursPlanned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hodin naplánováno',
      one: '1 hodina naplánována',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsInvalidTimeRange => 'Neplatný časový rozsah';

  @override
  String dailyOsMinutesPlanned(int count) {
    return '$count min naplánováno';
  }

  @override
  String get dailyOsNearLimit => 'Blízko limitu';

  @override
  String get dailyOsNoBudgets => 'Žádné časové rozpočty';

  @override
  String get dailyOsNoBudgetsHint =>
      'Přidejte rozpočty pro sledování, jak trávíte čas napříč kategoriemi.';

  @override
  String get dailyOsNoBudgetWarning => 'Žádný časový rozpočet';

  @override
  String get dailyOsNote => 'Poznámka';

  @override
  String get dailyOsNoTimeline => 'Žádné záznamy v časové ose';

  @override
  String get dailyOsNoTimelineHint =>
      'Spustit časovač nebo přidat plánované bloky, abyste viděli svůj den.';

  @override
  String get dailyOsOnTrack => 'Na správné cestě';

  @override
  String get dailyOsOver => 'Překročeno';

  @override
  String get dailyOsOverallProgress => 'Celkový pokrok';

  @override
  String get dailyOsOverBudget => 'Překročení rozpočtu';

  @override
  String get dailyOsOverdue => 'Zpožděné';

  @override
  String get dailyOsOverdueShort => 'Pozdě';

  @override
  String get dailyOsPlan => 'Plán';

  @override
  String get dailyOsPlanned => 'Naplánováno';

  @override
  String get dailyOsPlannedDuration => 'Plánovaná doba trvání';

  @override
  String get dailyOsQuickCreateTask => 'Vytvořit úkol pro tento rozpočet';

  @override
  String get dailyOsReAgree => 'Znovu souhlasit';

  @override
  String get dailyOsRecorded => 'Zaznamenáno';

  @override
  String get dailyOsRemaining => 'Zbývá';

  @override
  String get dailyOsReviewMessage => 'Zjištěny změny. Zkontrolujte svůj plán.';

  @override
  String get dailyOsSave => 'Uložit';

  @override
  String get dailyOsSelectCategory => 'Vyberte kategorii';

  @override
  String get dailyOsStartTime => 'Začátek';

  @override
  String get dailyOsTasks => 'Úkoly';

  @override
  String get dailyOsTimeBudgets => 'Časové rozpočty';

  @override
  String dailyOsTimeLeft(String time) {
    return 'Zbývá $time';
  }

  @override
  String get dailyOsTimeline => 'Časová osa';

  @override
  String dailyOsTimeOver(String time) {
    return '+$time navíc';
  }

  @override
  String get dailyOsTimeRange => 'Časový rozsah';

  @override
  String get dailyOsTimesUp => 'Čas vypršel';

  @override
  String get dailyOsTodayButton => 'Dnes';

  @override
  String get dailyOsUncategorized => 'Nezařazeno';

  @override
  String get dailyOsViewModeClassic => 'Klasický';

  @override
  String get dailyOsViewModeDailyOs => 'Denní OS';

  @override
  String get dashboardActiveLabel => 'Aktivní:';

  @override
  String get dashboardAddChartsTitle => 'Přidat grafy:';

  @override
  String get dashboardAddHabitButton => 'Návykové grafy';

  @override
  String get dashboardAddHabitTitle => 'Návykové grafy';

  @override
  String get dashboardAddHealthButton => 'Zdravotní grafy';

  @override
  String get dashboardAddHealthTitle => 'Zdravotní grafy';

  @override
  String get dashboardAddMeasurementButton => 'Měřicí grafy';

  @override
  String get dashboardAddMeasurementTitle => 'Měřicí grafy';

  @override
  String get dashboardAddSurveyButton => 'Grafy průzkumů';

  @override
  String get dashboardAddSurveyTitle => 'Grafy průzkumů';

  @override
  String get dashboardAddWorkoutButton => 'Grafy cvičení';

  @override
  String get dashboardAddWorkoutTitle => 'Grafy cvičení';

  @override
  String get dashboardAggregationLabel => 'Typ agregace:';

  @override
  String get dashboardCategoryLabel => 'Kategorie:';

  @override
  String get dashboardCopyHint => 'Uložit a zkopírovat konfiguraci panelu';

  @override
  String get dashboardDeleteConfirm => 'ANO, SMAZAT TENTO PANEL';

  @override
  String get dashboardDeleteHint => 'Smazat dashboard';

  @override
  String get dashboardDeleteQuestion =>
      'Opravdu chcete smazat tento dashboard?';

  @override
  String get dashboardDescriptionLabel => 'Popis (volitelné):';

  @override
  String get dashboardNameLabel => 'Název dashboardu:';

  @override
  String get dashboardNotFound => 'Dashboard nenalezen';

  @override
  String get dashboardPrivateLabel => 'Soukromý:';

  @override
  String get defaultLanguage => 'Výchozí jazyk';

  @override
  String get deleteButton => 'Smazat';

  @override
  String get deleteDeviceLabel => 'Odstranit zařízení';

  @override
  String deviceDeletedSuccess(String deviceName) {
    return 'Zařízení $deviceName bylo úspěšně odstraněno';
  }

  @override
  String deviceDeleteFailed(String error) {
    return 'Zařízení se nepodařilo odstranit: $error';
  }

  @override
  String get done => 'Hotovo';

  @override
  String get doneButton => 'Hotovo';

  @override
  String get editMenuTitle => 'Upravit';

  @override
  String get editorInsertDivider => 'Vložit oddělovač';

  @override
  String get editorPlaceholder => 'Zadejte poznámky...';

  @override
  String get enhancedPromptFormAdditionalDetailsTitle => 'Další podrobnosti';

  @override
  String get enhancedPromptFormAiResponseTypeSubtitle =>
      'Formát očekávané odpovědi';

  @override
  String get enhancedPromptFormBasicConfigurationTitle =>
      'Základní konfigurace';

  @override
  String get enhancedPromptFormConfigurationOptionsTitle =>
      'Možnosti konfigurace';

  @override
  String get enhancedPromptFormDescription =>
      'Vytvářejte vlastní výzvy, které lze použít s vašimi AI modely k generování specifických typů odpovědí';

  @override
  String get enhancedPromptFormDescriptionHelperText =>
      'Volitelné poznámky o účelu a použití této výzvy';

  @override
  String get enhancedPromptFormDisplayNameHelperText =>
      'Popisný název pro tuto šablonu výzvy';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Vyberte z připravených šablon výzev';

  @override
  String get enhancedPromptFormPromptConfigurationTitle => 'Konfigurace výzvy';

  @override
  String get enhancedPromptFormQuickStartDescription =>
      'Začněte s předpřipravenou šablonou a ušetřete čas';

  @override
  String get enhancedPromptFormQuickStartTitle => 'Rychlý start';

  @override
  String get enhancedPromptFormRequiredInputDataSubtitle =>
      'Typ dat, která tento prompt očekává';

  @override
  String get enhancedPromptFormSystemMessageHelperText =>
      'Instrukce, které určují chování AI a styl odpovědi';

  @override
  String get enhancedPromptFormUserMessageHelperText => 'Hlavní text promptu.';

  @override
  String get enterCategoryName => 'Zadejte název kategorie';

  @override
  String get entryActions => 'Akce';

  @override
  String get entryLabelsActionSubtitle =>
      'Přiřadit štítky pro organizaci tohoto záznamu';

  @override
  String get entryLabelsActionTitle => 'Štítky';

  @override
  String get entryLabelsEditTooltip => 'Upravit štítky';

  @override
  String get entryLabelsHeaderTitle => 'Štítky';

  @override
  String get entryLabelsNoLabels => 'Žádné přiřazené štítky';

  @override
  String get entryTypeLabelAiResponse => 'Odpověď AI';

  @override
  String get entryTypeLabelChecklist => 'Kontrolní seznam';

  @override
  String get entryTypeLabelChecklistItem => 'Úkol';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Návyk';

  @override
  String get entryTypeLabelJournalAudio => 'Audio';

  @override
  String get entryTypeLabelJournalEntry => 'Text';

  @override
  String get entryTypeLabelJournalEvent => 'Událost';

  @override
  String get entryTypeLabelJournalImage => 'Fotografie';

  @override
  String get entryTypeLabelMeasurementEntry => 'Naměřeno';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Zdraví';

  @override
  String get entryTypeLabelSurveyEntry => 'Průzkum';

  @override
  String get entryTypeLabelTask => 'Úkol';

  @override
  String get entryTypeLabelWorkoutEntry => 'Cvičení';

  @override
  String get errorLoadingPrompts => 'Chyba při načítání výzev';

  @override
  String get eventNameLabel => 'Událost:';

  @override
  String get favoriteLabel => 'Oblíbené';

  @override
  String get fileMenuNewEllipsis => 'Nový ...';

  @override
  String get fileMenuNewEntry => 'Nový záznam';

  @override
  String get fileMenuNewScreenshot => 'Snímek obrazovky';

  @override
  String get fileMenuNewTask => 'Úkol';

  @override
  String get fileMenuTitle => 'Soubor';

  @override
  String get generateCoverArt => 'Vytvořit obálku';

  @override
  String get generateCoverArtSubtitle => 'Vytvořit obrázek z hlasového popisu';

  @override
  String get habitActiveFromLabel => 'Datum začátku';

  @override
  String get habitArchivedLabel => 'Archivováno:';

  @override
  String get habitCategoryHint => 'Vyberte kategorii...';

  @override
  String get habitCategoryLabel => 'Kategorie:';

  @override
  String get habitDashboardHint => 'Vyberte panel...';

  @override
  String get habitDashboardLabel => 'Dashboard:';

  @override
  String get habitDeleteConfirm => 'ANO, SMAŽ TENTO ZVYK';

  @override
  String get habitDeleteQuestion => 'Chcete tento zvyk smazat?';

  @override
  String get habitPriorityLabel => 'Priorita:';

  @override
  String get habitsCompletedHeader => 'Dokončeno';

  @override
  String get habitsFilterAll => 'všechny';

  @override
  String get habitsFilterCompleted => 'hotovo';

  @override
  String get habitsFilterOpenNow => 'nyní';

  @override
  String get habitsFilterPendingLater => 'později';

  @override
  String get habitShowAlertAtLabel => 'Zobrazit upozornění v';

  @override
  String get habitShowFromLabel => 'Zobrazit od';

  @override
  String get habitsOpenHeader => 'K splnění';

  @override
  String get habitsPendingLaterHeader => 'Později dnes';

  @override
  String get imageGenerationAcceptButton => 'Přijmout jako obal';

  @override
  String get imageGenerationCancelEdit => 'Zrušit';

  @override
  String get imageGenerationEditPromptButton => 'Upravit výzvu';

  @override
  String get imageGenerationEditPromptLabel => 'Upravit výzvu';

  @override
  String get imageGenerationError => 'Nepodařilo se vygenerovat obrázek';

  @override
  String get imageGenerationGenerating => 'Generování obrázku...';

  @override
  String get imageGenerationModalTitle => 'Generovaný obrázek';

  @override
  String get imageGenerationRetry => 'Opakovat pokus';

  @override
  String imageGenerationSaveError(String error) {
    return 'Nepodařilo se uložit obrázek: $error';
  }

  @override
  String imageGenerationWithReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Používá se $count referenčních obrázků',
      one: 'Používá se 1 referenční obrázek',
      zero: 'Žádné referenční obrázky',
    );
    return '$_temp0';
  }

  @override
  String get imagePromptGenerationCardTitle => 'AI prompt pro obrázek';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Prompt obrázku byl zkopírován do schránky';

  @override
  String get imagePromptGenerationCopyButton => 'Kopírovat prompt';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Kopírovat prompt obrázku do schránky';

  @override
  String get imagePromptGenerationExpandTooltip => 'Zobrazit celý prompt';

  @override
  String get imagePromptGenerationFullPromptLabel => 'Celý prompt obrázku:';

  @override
  String get images => 'Obrázky';

  @override
  String get inputDataTypeAudioFilesDescription =>
      'Použijte audio soubory jako vstup';

  @override
  String get inputDataTypeAudioFilesName => 'Audio soubory';

  @override
  String get inputDataTypeImagesDescription => 'Použijte obrázky jako vstup';

  @override
  String get inputDataTypeImagesName => 'Obrázky';

  @override
  String get inputDataTypeTaskDescription =>
      'Použijte aktuální úkol jako vstup';

  @override
  String get inputDataTypeTaskName => 'Úkol';

  @override
  String get inputDataTypeTasksListDescription =>
      'Použijte seznam úkolů jako vstup';

  @override
  String get inputDataTypeTasksListName => 'Seznam úkolů';

  @override
  String get journalCopyImageLabel => 'Kopírovat obrázek';

  @override
  String get journalDateFromLabel => 'Datum od:';

  @override
  String get journalDateInvalid => 'Neplatné časové rozmezí';

  @override
  String get journalDateNowButton => 'Nyní';

  @override
  String get journalDateSaveButton => 'ULOŽIT';

  @override
  String get journalDateToLabel => 'Datum do:';

  @override
  String get journalDeleteConfirm => 'ANO, SMAZAT TENTO ZÁZNAM';

  @override
  String get journalDeleteHint => 'Smazat záznam';

  @override
  String get journalDeleteQuestion =>
      'Opravdu chcete smazat tento deníkový záznam?';

  @override
  String get journalDurationLabel => 'Doba trvání:';

  @override
  String get journalFavoriteTooltip => 'pouze oblíbené';

  @override
  String get journalFlaggedTooltip => 'pouze označené';

  @override
  String get journalHideLinkHint => 'Skrýt odkaz';

  @override
  String get journalHideMapHint => 'Skrýt mapu';

  @override
  String get journalLinkedEntriesAiLabel => 'Zobrazit záznamy generované AI:';

  @override
  String get journalLinkedEntriesHiddenLabel => 'Zobrazit skryté záznamy:';

  @override
  String get journalLinkedEntriesLabel => 'Propojené záznamy';

  @override
  String get journalLinkedFromLabel => 'Odkaz z:';

  @override
  String get journalLinkFromHint => 'Odkaz z';

  @override
  String get journalLinkToHint => 'Odkaz na';

  @override
  String get journalPrivateTooltip => 'pouze soukromé';

  @override
  String get journalSearchHint => 'Hledat deník...';

  @override
  String get journalShareAudioHint => 'Sdílet audio';

  @override
  String get journalShareHint => 'Sdílet';

  @override
  String get journalSharePhotoHint => 'Sdílet foto';

  @override
  String get journalShowLinkHint => 'Zobrazit odkaz';

  @override
  String get journalShowMapHint => 'Zobrazit mapu';

  @override
  String get journalTagPlusHint => 'Spravovat tagy záznamů';

  @override
  String get journalTagsCopyHint => 'Kopírovat štítky';

  @override
  String get journalTagsLabel => 'Štítky:';

  @override
  String get journalTagsPasteHint => 'Vložit štítky';

  @override
  String get journalTagsRemoveHint => 'Odstranit tag';

  @override
  String get journalToggleFlaggedTitle => 'Označené';

  @override
  String get journalTogglePrivateTitle => 'Soukromé';

  @override
  String get journalToggleStarredTitle => 'Oblíbené';

  @override
  String get journalUnlinkConfirm => 'ANO, ODEPNOUT ZÁZNAM';

  @override
  String get journalUnlinkHint => 'Odepnout';

  @override
  String get journalUnlinkQuestion => 'Opravdu chcete tento záznam odepnout?';

  @override
  String get linkedFromLabel => 'PROPOJENO Z';

  @override
  String get linkedTasksMenuTooltip => 'Možnosti propojených úkolů';

  @override
  String get linkedTasksTitle => 'Propojené úkoly';

  @override
  String get linkedToLabel => 'PROPOJENO NA';

  @override
  String get linkExistingTask => 'Propojit existující úkol...';

  @override
  String get loggingFailedToLoad =>
      'Nepodařilo se načíst logy. Prosím, zkuste to znovu.';

  @override
  String get loggingFailedToLoadMore =>
      'Nepodařilo se načíst další výsledky. Prosím, zkuste to znovu.';

  @override
  String get loggingSearchFailed =>
      'Vyhledávání neúspěšné. Prosím, zkuste to znovu.';

  @override
  String get logsSearchHint => 'Prohledat všechny logy...';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'ANO, SMAZAT DATABÁZI';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Opravdu chcete smazat databázi $databaseName?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Smazat databázi editoru';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Smazat databázi konceptů editoru';

  @override
  String get maintenanceDeleteLoggingDb => 'Smazat databázi logování';

  @override
  String get maintenanceDeleteLoggingDbDescription =>
      'Smazat logovací databázi';

  @override
  String get maintenanceDeleteSyncDb => 'Smazat synchronizační databázi';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Smazat synchronizační databázi';

  @override
  String get maintenancePopulateSequenceLog =>
      'Naplnit protokol synchronizační sekvence';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count záznamů indexováno';
  }

  @override
  String get maintenancePopulateSequenceLogConfirm => 'ANO, NAPLNIT';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Indexovat existující položky pro podporu doplňování';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'Toto prohledá všechny záznamy deníku a přidá je do protokolu synchronizační sekvence. To umožní zpětné zpracování odpovědí pro záznamy vytvořené před přidáním této funkce.';

  @override
  String get maintenancePurgeDeleted => 'Vyčistit smazané položky';

  @override
  String get maintenancePurgeDeletedConfirm => 'Ano, vyčistit všechny';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Vymazat všechny smazané položky trvale';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Jste si jistý, že chcete vymazat všechny smazané položky? Tuto akci nelze vzít zpět.';

  @override
  String get maintenanceRecreateFts5 => 'Znovu vytvořit index plného textu';

  @override
  String get maintenanceRecreateFts5Confirm => 'ANO, ZNOVU VYTVOŘIT INDEX';

  @override
  String get maintenanceRecreateFts5Description =>
      'Znovu vytvořit index fulltextového vyhledávání';

  @override
  String get maintenanceRecreateFts5Message =>
      'Opravdu chcete znovu vytvořit index fulltextového vyhledávání? Toto může chvíli trvat.';

  @override
  String get maintenanceReSync => 'Znovu synchronizovat zprávy';

  @override
  String get maintenanceReSyncDescription =>
      'Znovu synchronizovat zprávy ze serveru';

  @override
  String get maintenanceSyncDefinitions =>
      'Synchronizovat tagy, měřitelné údaje, dashboardy, návyky, kategorie, AI nastavení';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Synchronizovat tagy, měřitelné údaje, dashboardy, návyky, kategorie a AI nastavení';

  @override
  String get manageLinks => 'Spravovat propojení...';

  @override
  String get matrixStatsError => 'Chyba při načítání statistik Matrixu';

  @override
  String get measurableDeleteConfirm => 'ANO, SMAŽ TUTO MĚŘITELNOU';

  @override
  String get measurableDeleteQuestion =>
      'Chcete tento měřitelný datový typ smazat?';

  @override
  String get measurableNotFound => 'Měřitelný typ nenalezen';

  @override
  String get modalityAudioDescription => 'Schopnosti zpracování zvuku';

  @override
  String get modalityAudioName => 'Audio';

  @override
  String get modalityImageDescription => 'Schopnosti zpracování obrazu';

  @override
  String get modalityImageName => 'Obraz';

  @override
  String get modalityTextDescription => 'Textový obsah a zpracování';

  @override
  String get modalityTextName => 'Text';

  @override
  String get modelAddPageTitle => 'Přidat model';

  @override
  String get modelEditLoadError => 'Nepodařilo se načíst konfiguraci modelu';

  @override
  String get modelEditPageTitle => 'Upravit model';

  @override
  String modelManagementSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelů vybráno',
      one: '1 model vybrán',
    );
    return '$_temp0';
  }

  @override
  String get modelsSettingsPageTitle => 'AI modely';

  @override
  String get multiSelectAddButton => 'Přidat';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Přidat ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'Žádné položky nenalezeny';

  @override
  String get navTabTitleCalendar => 'DailyOS';

  @override
  String get navTabTitleHabits => 'Zvyky';

  @override
  String get navTabTitleInsights => 'Přehledy';

  @override
  String get navTabTitleJournal => 'Zápisník';

  @override
  String get navTabTitleSettings => 'Nastavení';

  @override
  String get navTabTitleTasks => 'Úkoly';

  @override
  String nestedAiResponsesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count AI odpovědí',
      one: '1 AI odpověď',
    );
    return '$_temp0';
  }

  @override
  String get noDefaultLanguage => 'Žádný výchozí jazyk';

  @override
  String get noPromptsAvailable => 'Žádné dostupné výzvy';

  @override
  String get noPromptsForType => 'Pro tento typ nejsou k dispozici žádné výzvy';

  @override
  String get noTasksFound => 'Nebyly nalezeny žádné úkoly';

  @override
  String get noTasksToLink => 'Žádné dostupné úkoly k propojení';

  @override
  String get outboxMonitorAttachmentLabel => 'Příloha';

  @override
  String get outboxMonitorDelete => 'smazat';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Smazat';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      'Opravdu chcete tuto synchronizační položku smazat? Tuto akci nelze vrátit zpět.';

  @override
  String get outboxMonitorDeleteFailed =>
      'Smazání selhalo. Zkuste to prosím znovu.';

  @override
  String get outboxMonitorDeleteSuccess => 'Položka smazána';

  @override
  String get outboxMonitorEmptyDescription =>
      'V tomto zobrazení nejsou žádné synchronizační položky.';

  @override
  String get outboxMonitorEmptyTitle => 'Odchozí pošta je prázdná';

  @override
  String get outboxMonitorLabelAll => 'vše';

  @override
  String get outboxMonitorLabelError => 'chyba';

  @override
  String get outboxMonitorLabelPending => 'čeká';

  @override
  String get outboxMonitorLabelSent => 'odesláno';

  @override
  String get outboxMonitorLabelSuccess => 'úspěch';

  @override
  String get outboxMonitorNoAttachment => 'žádná příloha';

  @override
  String get outboxMonitorRetries => 'pokusy';

  @override
  String get outboxMonitorRetriesLabel => 'Počet pokusů';

  @override
  String get outboxMonitorRetry => 'zkusit znovu';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Zkusit nyní';

  @override
  String get outboxMonitorRetryConfirmMessage =>
      'Chcete tuto synchronizaci zkusit znovu nyní?';

  @override
  String get outboxMonitorRetryFailed =>
      'Opakování selhalo. Zkuste to prosím znovu.';

  @override
  String get outboxMonitorRetryQueued => 'Opakování naplánováno';

  @override
  String get outboxMonitorSubjectLabel => 'Předmět';

  @override
  String get outboxMonitorSwitchLabel => 'povoleno';

  @override
  String get privateLabel => 'Soukromé';

  @override
  String get promptAddOrRemoveModelsButton => 'Přidat nebo odstranit modely';

  @override
  String get promptAddPageTitle => 'Přidat prompt';

  @override
  String get promptAiResponseTypeDescription => 'Formát očekávané odpovědi';

  @override
  String get promptAiResponseTypeLabel => 'AI typ odpovědi';

  @override
  String get promptBehaviorDescription =>
      'Konfigurovat, jak prompt zpracovává a reaguje';

  @override
  String get promptBehaviorTitle => 'Chování promptu';

  @override
  String get promptCancelButton => 'Zrušit';

  @override
  String get promptContentDescription =>
      'Definujte systémové a uživatelské prompty';

  @override
  String get promptContentTitle => 'Obsah promptu';

  @override
  String get promptDefaultModelBadge => 'Výchozí';

  @override
  String get promptDescriptionHint => 'Popište tento prompt';

  @override
  String get promptDescriptionLabel => 'Popis';

  @override
  String get promptDetailsDescription => 'Základní informace o tomto promptu';

  @override
  String get promptDetailsTitle => 'Detaily promptu';

  @override
  String get promptDisplayNameHint => 'Zadejte přátelský název';

  @override
  String get promptDisplayNameLabel => 'Zobrazovaný název';

  @override
  String get promptEditLoadError => 'Nepodařilo se načíst prompt';

  @override
  String get promptEditPageTitle => 'Upravit prompt';

  @override
  String get promptErrorLoadingModel => 'Chyba při načítání modelu';

  @override
  String get promptGenerationCardTitle => 'AI kódovací prompt';

  @override
  String get promptGenerationCopiedSnackbar => 'Prompt zkopírován do schránky';

  @override
  String get promptGenerationCopyButton => 'Zkopírovat prompt';

  @override
  String get promptGenerationCopyTooltip => 'Zkopírovat prompt do schránky';

  @override
  String get promptGenerationExpandTooltip => 'Zobrazit celý prompt';

  @override
  String get promptGenerationFullPromptLabel => 'Celý prompt:';

  @override
  String get promptGoBackButton => 'Zpět';

  @override
  String get promptLoadingModel => 'Načítání modelu...';

  @override
  String get promptModelSelectionDescription =>
      'Vyberte kompatibilní modely pro tento prompt';

  @override
  String get promptModelSelectionTitle => 'Výběr modelu';

  @override
  String get promptNoModelsSelectedError =>
      'Nebyl vybrán žádný model. Vyberte alespoň jeden model.';

  @override
  String get promptReasoningModeDescription =>
      'Povolit pro výzvy vyžadující hluboké přemýšlení';

  @override
  String get promptReasoningModeLabel => 'Režim uvažování';

  @override
  String get promptRequiredInputDataDescription =>
      'Typ dat, která tato výzva očekává';

  @override
  String get promptRequiredInputDataLabel => 'Požadovaná vstupní data';

  @override
  String get promptSaveButton => 'Uložit výzvu';

  @override
  String get promptSelectInputTypeHint => 'Vyberte typ vstupu';

  @override
  String get promptSelectionModalTitle => 'Vyberte přednastavenou výzvu';

  @override
  String get promptSelectModelsButton => 'Vybrat modely';

  @override
  String get promptSelectResponseTypeHint => 'Vyberte typ odpovědi';

  @override
  String get promptSetDefaultButton => 'Nastavit jako výchozí';

  @override
  String get promptSettingsPageTitle => 'AI výzvy';

  @override
  String get promptSystemPromptHint => 'Zadejte systémovou výzvu...';

  @override
  String get promptSystemPromptLabel => 'Systémový prompt';

  @override
  String get promptTryAgainMessage =>
      'Zkuste to znovu nebo kontaktujte podporu';

  @override
  String get promptUsePreconfiguredButton => 'Použít přednastavený prompt';

  @override
  String get promptUserPromptHint => 'Zadejte uživatelský prompt...';

  @override
  String get promptUserPromptLabel => 'Uživatelský prompt';

  @override
  String get provisionedSyncBundleImported => 'Provizní kód importován';

  @override
  String get provisionedSyncConfigureButton => 'Konfigurovat';

  @override
  String get provisionedSyncCopiedToClipboard => 'Zkopírováno do schránky';

  @override
  String get provisionedSyncDisconnect => 'Odpojit';

  @override
  String get provisionedSyncDone => 'Synchronizace úspěšně nakonfigurována';

  @override
  String get provisionedSyncError => 'Konfigurace selhala';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'Při konfiguraci došlo k chybě. Zkuste to znovu.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'Přihlášení selhalo. Zkontrolujte své přihlašovací údaje a zkuste to znovu.';

  @override
  String get provisionedSyncImportButton => 'Importovat';

  @override
  String get provisionedSyncImportHint => 'Vložte provizní kód sem';

  @override
  String get provisionedSyncImportTitle => 'Nastavit synchronizaci';

  @override
  String get provisionedSyncInvalidBundle => 'Neplatný provizní kód';

  @override
  String get provisionedSyncJoiningRoom =>
      'Připojování k synchronizační místnosti...';

  @override
  String get provisionedSyncLoggingIn => 'Přihlašování...';

  @override
  String get provisionedSyncPasteClipboard => 'Vložit ze schránky';

  @override
  String get provisionedSyncReady =>
      'Naskenujte tento QR kód na svém mobilním zařízení';

  @override
  String get provisionedSyncRetry => 'Zkusit znovu';

  @override
  String get provisionedSyncRotatingPassword => 'Zabezpečování účtu...';

  @override
  String get provisionedSyncScanButton => 'Naskenovat QR kód';

  @override
  String get provisionedSyncShowQr => 'Zobrazit QR kód pro spárování';

  @override
  String get provisionedSyncSubtitle =>
      'Nastavit synchronizaci z provizního balíčku';

  @override
  String get provisionedSyncSummaryHomeserver => 'Server';

  @override
  String get provisionedSyncSummaryRoom => 'Místnost';

  @override
  String get provisionedSyncSummaryUser => 'Uživatel';

  @override
  String get provisionedSyncTitle => 'Provizní synchronizace';

  @override
  String get provisionedSyncVerifyDevicesTitle => 'Ověření zařízení';

  @override
  String get referenceImageContinue => 'Pokračovat';

  @override
  String referenceImageContinueWithCount(int count) {
    return 'Pokračovat ($count)';
  }

  @override
  String get referenceImageLoadError =>
      'Nepodařilo se načíst obrázky. Zkuste to prosím znovu.';

  @override
  String get referenceImageSelectionSubtitle =>
      'Vyberte až 3 obrázky pro vedení vizuálního stylu AI';

  @override
  String get referenceImageSelectionTitle => 'Vyberte referenční obrázky';

  @override
  String get referenceImageSkip => 'Přeskočit';

  @override
  String get saveButton => 'Uložit';

  @override
  String get saveButtonLabel => 'Uložit';

  @override
  String get saveLabel => 'Uložit';

  @override
  String get saveSuccessful => 'Úspěšně uloženo';

  @override
  String get searchHint => 'Hledat...';

  @override
  String get searchTasksHint => 'Hledat úkoly...';

  @override
  String get selectAllowedPrompts =>
      'Vyberte, které výzvy jsou povoleny pro tuto kategorii';

  @override
  String get selectButton => 'Vybrat';

  @override
  String get selectColor => 'Vybrat barvu';

  @override
  String get selectLanguage => 'Vybrat jazyk';

  @override
  String get sessionRatingCardLabel => 'Hodnocení relace';

  @override
  String get sessionRatingChallengeJustRight => 'Tak akorát';

  @override
  String get sessionRatingChallengeTooEasy => 'Příliš snadné';

  @override
  String get sessionRatingChallengeTooHard => 'Příliš náročné';

  @override
  String get sessionRatingDifficultyLabel => 'Tato práce byla...';

  @override
  String get sessionRatingEditButton => 'Upravit hodnocení';

  @override
  String get sessionRatingEnergyQuestion => 'Jak energický/á jste se cítil/a?';

  @override
  String get sessionRatingFocusQuestion => 'Jak soustředění jste byli?';

  @override
  String get sessionRatingNoteHint => 'Krátká poznámka (volitelné)';

  @override
  String get sessionRatingProductivityQuestion =>
      'Jak produktivní byla tato relace?';

  @override
  String get sessionRatingRateAction => 'Ohodnotit relaci';

  @override
  String get sessionRatingSaveButton => 'Uložit';

  @override
  String get sessionRatingSaveError =>
      'Nepodařilo se uložit hodnocení. Zkuste to prosím znovu.';

  @override
  String get sessionRatingSkipButton => 'Přeskočit';

  @override
  String get sessionRatingTitle => 'Ohodnoťte tuto relaci';

  @override
  String get sessionRatingViewAction => 'Zobrazit hodnocení';

  @override
  String get settingsAboutAppInformation => 'Informace o aplikaci';

  @override
  String get settingsAboutAppTagline => 'Váš osobní deník';

  @override
  String get settingsAboutBuildType => 'Typ sestavení';

  @override
  String get settingsAboutBuiltWithFlutter =>
      'Vytvořeno pomocí Flutteru s láskou k osobnímu deníkování.';

  @override
  String get settingsAboutCredits => 'Poděkování';

  @override
  String get settingsAboutJournalEntries => 'Záznamy v deníku';

  @override
  String get settingsAboutPlatform => 'Platforma';

  @override
  String get settingsAboutThankYou => 'Děkujeme, že používáte Lotti!';

  @override
  String get settingsAboutTitle => 'O Lotti';

  @override
  String get settingsAboutVersion => 'Verze';

  @override
  String get settingsAboutYourData => 'Vaše data';

  @override
  String get settingsAdvancedAboutSubtitle => 'Zjistěte více o aplikaci Lotti';

  @override
  String get settingsAdvancedConflictsSubtitle =>
      'Řešte konflikty synchronizace pro zajištění konzistence dat';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Importujte zdravotní údaje z externích zdrojů';

  @override
  String get settingsAdvancedLogsSubtitle =>
      'Přistupujte k logům aplikace a kontrolujte je pro ladění';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Provádějte údržbové úkoly pro optimalizaci výkonu aplikace';

  @override
  String get settingsAdvancedMatrixSyncSubtitle =>
      'Konfigurujte a spravujte nastavení synchronizace Matrix';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Spravujte položky synchronizace';

  @override
  String get settingsAdvancedTitle => 'Pokročilá nastavení';

  @override
  String get settingsAiApiKeys => 'Poskytovatelé AI inferencí';

  @override
  String get settingsAiModels => 'AI modely';

  @override
  String get settingsCategoriesAddTooltip => 'Přidat kategorii';

  @override
  String get settingsCategoriesDetailsLabel => 'Detaily kategorie';

  @override
  String get settingsCategoriesDuplicateError => 'Kategorie již existuje';

  @override
  String get settingsCategoriesEmptyState => 'Žádné kategorie nalezeny';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Vytvořte kategorii pro organizaci vašich záznamů';

  @override
  String get settingsCategoriesErrorLoading => 'Chyba při načítání kategorií';

  @override
  String get settingsCategoriesHasAiSettings => 'Nastavení AI';

  @override
  String get settingsCategoriesHasAutomaticPrompts => 'Automatická AI';

  @override
  String get settingsCategoriesHasDefaultLanguage => 'Výchozí jazyk';

  @override
  String get settingsCategoriesNameLabel => 'Název kategorie:';

  @override
  String get settingsCategoriesTitle => 'Kategorie';

  @override
  String get settingsConflictsResolutionTitle =>
      'Řešení konfliktů synchronizace';

  @override
  String get settingsConflictsTitle => 'Konflikty synchronizace';

  @override
  String get settingsDashboardDetailsLabel => 'Detaily panelu';

  @override
  String get settingsDashboardSaveLabel => 'Uložit';

  @override
  String get settingsDashboardsTitle => 'Panely';

  @override
  String get settingsFlagsTitle => 'Konfigurační příznaky';

  @override
  String get settingsHabitsDeleteTooltip => 'Smazat návyk';

  @override
  String get settingsHabitsDescriptionLabel => 'Popis (volitelné):';

  @override
  String get settingsHabitsDetailsLabel => 'Detaily návyku';

  @override
  String get settingsHabitsNameLabel => 'Název návyku:';

  @override
  String get settingsHabitsPrivateLabel => 'Soukromé: ';

  @override
  String get settingsHabitsSaveLabel => 'Uložit';

  @override
  String get settingsHabitsTitle => 'Návyky';

  @override
  String get settingsHealthImportFromDate => 'Začátek';

  @override
  String get settingsHealthImportTitle => 'Import zdraví';

  @override
  String get settingsHealthImportToDate => 'Konec';

  @override
  String get settingsLabelsActionsTooltip => 'Akce se štítkem';

  @override
  String get settingsLabelsCategoriesAdd => 'Přidat kategorii';

  @override
  String get settingsLabelsCategoriesHeading => 'Použitelné kategorie';

  @override
  String get settingsLabelsCategoriesNone => 'Platí pro všechny kategorie';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Odstranit';

  @override
  String get settingsLabelsColorHeading => 'Vyberte barvu';

  @override
  String get settingsLabelsColorSubheading => 'Rychlé přednastavení';

  @override
  String get settingsLabelsCreateSuccess => 'Štítek úspěšně vytvořen';

  @override
  String get settingsLabelsCreateTitle => 'Vytvořit štítek';

  @override
  String get settingsLabelsDeleteCancel => 'Zrušit';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Smazat';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return 'Opravdu chcete smazat štítek \"$labelName\"? Úkoly s tímto štítkem ztratí přiřazení.';
  }

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Smazat štítek';

  @override
  String settingsLabelsDeleteSuccess(Object labelName) {
    return 'Štítek \"$labelName\" smazán';
  }

  @override
  String get settingsLabelsDescriptionHint =>
      'Vysvětlete, kdy použít tento štítek';

  @override
  String get settingsLabelsDescriptionLabel => 'Popis (volitelné)';

  @override
  String get settingsLabelsEditTitle => 'Upravit štítek';

  @override
  String get settingsLabelsEmptyState => 'Zatím žádné štítky';

  @override
  String get settingsLabelsEmptyStateHint =>
      'Klepněte na tlačítko + pro vytvoření prvního štítku.';

  @override
  String get settingsLabelsErrorLoading => 'Nepodařilo se načíst štítky';

  @override
  String get settingsLabelsNameHint =>
      'Chyba, Zabránění vydání, Synchronizace…';

  @override
  String get settingsLabelsNameLabel => 'Název štítku';

  @override
  String get settingsLabelsNameRequired => 'Název štítku nesmí být prázdný.';

  @override
  String get settingsLabelsPrivateDescription =>
      'Soukromé štítky se zobrazují pouze tehdy, když je povoleno Zobrazit soukromé záznamy.';

  @override
  String get settingsLabelsPrivateTitle => 'Soukromý štítek';

  @override
  String get settingsLabelsSearchHint => 'Hledat štítky...';

  @override
  String get settingsLabelsSubtitle => 'Organizujte úkoly barevnými štítky';

  @override
  String get settingsLabelsTitle => 'Štítky';

  @override
  String get settingsLabelsUpdateSuccess => 'Štítek aktualizován';

  @override
  String settingsLabelsUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count úkolech',
      one: '1 úkolu',
    );
    return 'Použito na $_temp0';
  }

  @override
  String get settingsLogsTitle => 'Záznamy';

  @override
  String get settingsMaintenanceTitle => 'Údržba';

  @override
  String get settingsMatrixAccept => 'Přijmout';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'Jiné zařízení zobrazuje emoji, pokračovat';

  @override
  String get settingsMatrixCancel => 'Zrušit';

  @override
  String get settingsMatrixCancelVerificationLabel => 'Zrušit ověření';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Přijměte na jiném zařízení pro pokračování';

  @override
  String get settingsMatrixCount => 'Počet';

  @override
  String get settingsMatrixDeleteLabel => 'Odstranit';

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
  String get settingsMatrixDone => 'Hotovo';

  @override
  String get settingsMatrixEnterValidUrl => 'Zadejte platnou URL';

  @override
  String get settingsMatrixHomeserverConfigTitle =>
      'Nastavení Matrix domácího serveru';

  @override
  String get settingsMatrixHomeServerLabel => 'Domácí server';

  @override
  String get settingsMatrixLastUpdated => 'Naposledy aktualizováno:';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Neověřená zařízení';

  @override
  String get settingsMatrixLoginButtonLabel => 'Přihlásit se';

  @override
  String get settingsMatrixLoginFailed => 'Přihlášení se nezdařilo';

  @override
  String get settingsMatrixLogoutButtonLabel => 'Odhlásit se';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Spustit úlohy údržby Matrix a nástroje pro obnovení';

  @override
  String get settingsMatrixMaintenanceTitle => 'Údržba';

  @override
  String get settingsMatrixMessageType => 'Typ zprávy';

  @override
  String get settingsMatrixMetric => 'Metrika';

  @override
  String get settingsMatrixMetrics => 'Metriky synchronizace';

  @override
  String get settingsMatrixMetricsNoData => 'Metriky synchronizace: žádná data';

  @override
  String get settingsMatrixNextPage => 'Další stránka';

  @override
  String get settingsMatrixNoUnverifiedLabel => 'Žádná neověřená zařízení';

  @override
  String get settingsMatrixPasswordLabel => 'Heslo';

  @override
  String get settingsMatrixPasswordTooShort => 'Heslo je příliš krátké';

  @override
  String get settingsMatrixPreviousPage => 'Předchozí stránka';

  @override
  String get settingsMatrixQrTextPage =>
      'Naskenujte tento QR kód a pozvěte zařízení do synchronizační místnosti.';

  @override
  String get settingsMatrixRefresh => 'Obnovit';

  @override
  String get settingsMatrixRoomConfigTitle =>
      'Nastavení místnosti pro synchronizaci Matrix';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Pozvánka do místnosti $roomId od $senderId. Přijmout?';
  }

  @override
  String get settingsMatrixRoomInviteTitle => 'Pozvánka do místnosti';

  @override
  String get settingsMatrixSentMessagesLabel => 'Odeslané zprávy:';

  @override
  String get settingsMatrixStartVerificationLabel => 'Spustit ověření';

  @override
  String get settingsMatrixStatsTitle => 'Statistiky Matrix';

  @override
  String get settingsMatrixSubtitle =>
      'Konfigurovat šifrovanou synchronizaci end-to-end';

  @override
  String get settingsMatrixTitle => 'Nastavení synchronizace';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Neověřená zařízení';

  @override
  String get settingsMatrixUserLabel => 'Uživatel';

  @override
  String get settingsMatrixUserNameTooShort =>
      'Uživatelské jméno je příliš krátké';

  @override
  String get settingsMatrixValue => 'Hodnota';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Zrušeno na jiném zařízení...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Rozumím';

  @override
  String settingsMatrixVerificationSuccessLabel(
      String deviceName, String deviceID) {
    return 'Úspěšně jste ověřili zařízení $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Potvrďte na jiném zařízení, že níže uvedené emotikony se zobrazují na obou zařízeních, ve stejném pořadí:';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Potvrďte, že níže uvedené emotikony se zobrazují na obou zařízeních ve stejném pořadí:';

  @override
  String get settingsMatrixVerifyLabel => 'Ověřit';

  @override
  String get settingsMeasurableAggregationLabel =>
      'Výchozí typ agregace (volitelné):';

  @override
  String get settingsMeasurableDeleteTooltip => 'Smazat měřitelný typ';

  @override
  String get settingsMeasurableDescriptionLabel => 'Popis (volitelné):';

  @override
  String get settingsMeasurableDetailsLabel => 'Podrobnosti měřitelného';

  @override
  String get settingsMeasurableFavoriteLabel => 'Oblíbené: ';

  @override
  String get settingsMeasurableNameLabel => 'Název měřitelného:';

  @override
  String get settingsMeasurablePrivateLabel => 'Soukromé: ';

  @override
  String get settingsMeasurableSaveLabel => 'Uložit';

  @override
  String get settingsMeasurablesTitle => 'Typy měřitelných veličin';

  @override
  String get settingsMeasurableUnitLabel => 'Zkratka jednotky (volitelné):';

  @override
  String get settingsResetGeminiConfirm => 'Obnovit';

  @override
  String get settingsResetGeminiConfirmQuestion =>
      'Tímto se znovu zobrazí dialog nastavení Gemini. Pokračovat?';

  @override
  String get settingsResetGeminiSubtitle =>
      'Zobrazit znovu dialog pro nastavení Gemini AI';

  @override
  String get settingsResetGeminiTitle => 'Dialog pro obnovení nastavení Gemini';

  @override
  String get settingsResetHintsConfirm => 'Potvrdit';

  @override
  String get settingsResetHintsConfirmQuestion =>
      'Resetovat nápovědy v aplikaci zobrazené v celé aplikaci?';

  @override
  String settingsResetHintsResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Resetováno $count nápověd',
      one: 'Resetována jedna nápověda',
      zero: 'Resetováno nula nápověd',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetHintsSubtitle =>
      'Vymazat jednorázové tipy a tipy pro onboarding';

  @override
  String get settingsResetHintsTitle => 'Resetovat nápovědy v aplikaci';

  @override
  String get settingsSpeechAudioWithoutTranscript =>
      'Audiozáznamy bez přepisu:';

  @override
  String get settingsSpeechAudioWithoutTranscriptButton => 'Najít a přepsat';

  @override
  String get settingsSpeechLastActivity => 'Poslední aktivita přepisu:';

  @override
  String get settingsSpeechModelSelectionTitle =>
      'Model rozpoznávání řeči Whisper:';

  @override
  String get settingsSyncOutboxTitle => 'Synchronizace odeslané pošty';

  @override
  String get settingsSyncStatsSubtitle =>
      'Prohlédněte si metriky synchronizačního procesu';

  @override
  String get settingsSyncSubtitle =>
      'Nastavte synchronizaci a zobrazte statistiky';

  @override
  String get settingsTagsDeleteTooltip => 'Odstranit štítek';

  @override
  String get settingsTagsDetailsLabel => 'Podrobnosti o štítcích';

  @override
  String get settingsTagsHideLabel => 'Skrýt z návrhů:';

  @override
  String get settingsTagsPrivateLabel => 'Soukromé:';

  @override
  String get settingsTagsSaveLabel => 'Uložit';

  @override
  String get settingsTagsTagName => 'Štítek:';

  @override
  String get settingsTagsTitle => 'Štítky';

  @override
  String get settingsTagsTypeLabel => 'Typ štítku:';

  @override
  String get settingsTagsTypePerson => 'OSOBA';

  @override
  String get settingsTagsTypeStory => 'PŘÍBĚH';

  @override
  String get settingsTagsTypeTag => 'ŠTÍTEK';

  @override
  String get settingsThemingAutomatic => 'Automaticky';

  @override
  String get settingsThemingDark => 'Tmavé prostředí';

  @override
  String get settingsThemingLight => 'Světlé prostředí';

  @override
  String get settingsThemingTitle => 'Vzhled';

  @override
  String get settingThemingDark => 'Tmavé téma';

  @override
  String get settingThemingLight => 'Světlé téma';

  @override
  String get showCompleted => 'Zobrazit dokončené';

  @override
  String get speechDictionaryHelper =>
      'Výrazy oddělené středníkem (max. 50 znaků) pro lepší rozpoznávání řeči';

  @override
  String get speechDictionaryHint => 'macOS; Kirkjubæjarklaustur; Claude Code';

  @override
  String get speechDictionaryLabel => 'Slovník řeči';

  @override
  String get speechDictionarySectionDescription =>
      'Přidejte výrazy, které jsou často chybně rozpoznávány hlasovým vstupem (jména, místa, technické termíny)';

  @override
  String get speechDictionarySectionTitle => 'Rozpoznávání řeči';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Velký slovník ($count výrazů) může zvýšit náklady na API';
  }

  @override
  String get speechModalAddTranscription => 'Přidat přepis';

  @override
  String get speechModalSelectLanguage => 'Vyberte jazyk';

  @override
  String get speechModalTitle => 'Rozpoznávání řeči';

  @override
  String get speechModalTranscriptionProgress => 'Pokrok přepisu';

  @override
  String get syncCreateNewRoom => 'Vytvořit novou místnost';

  @override
  String get syncCreateNewRoomInstead => 'Místo toho vytvořit novou místnost';

  @override
  String get syncDeleteConfigConfirm => 'ANO, JSEM SI JISTÝ';

  @override
  String get syncDeleteConfigQuestion =>
      'Chcete smazat konfiguraci synchronizace?';

  @override
  String get syncDiscoveringRooms => 'Objevování synchronizačních místností...';

  @override
  String get syncDiscoverRoomsButton => 'Objevit existující místnosti';

  @override
  String get syncDiscoveryError => 'Nepodařilo se objevit místnosti';

  @override
  String get syncEntitiesConfirm => 'SPUSTIT SYNCHRONIZACI';

  @override
  String get syncEntitiesMessage =>
      'Vyberte entity, které chcete synchronizovat.';

  @override
  String get syncEntitiesSuccessDescription => 'Vše je aktuální.';

  @override
  String get syncEntitiesSuccessTitle => 'Synchronizace dokončena';

  @override
  String get syncInviteErrorForbidden =>
      'Povolení zamítnuto. Možná nemáte přístup k pozvání tohoto uživatele.';

  @override
  String get syncInviteErrorNetwork =>
      'Chyba sítě. Prosím, zkontrolujte spojení a zkuste to znovu.';

  @override
  String get syncInviteErrorRateLimited =>
      'Příliš mnoho požadavků. Prosím, počkejte chvíli a zkuste to znovu.';

  @override
  String get syncInviteErrorUnknown =>
      'Nepodařilo se odeslat pozvánku. Zkuste to prosím později.';

  @override
  String get syncInviteErrorUserNotFound =>
      'Uživatel nenalezen. Prosím, ověřte, že naskenovaný kód je správný.';

  @override
  String syncListCountSummary(String label, int itemCount) {
    String _temp0 = intl.Intl.pluralLogic(
      itemCount,
      locale: localeName,
      other: '$itemCount položek',
      one: '1 položka',
      zero: '0 položek',
    );
    return '$label · $_temp0';
  }

  @override
  String get syncListPayloadKindLabel => 'Obsah';

  @override
  String get syncListUnknownPayload => 'Neznámý obsah';

  @override
  String get syncNoRoomsFound =>
      'Žádné existující synchronizační místnosti nalezeny.\nMůžete vytvořit novou místnost pro zahájení synchronizace.';

  @override
  String get syncNotLoggedInToast => 'Synchronizace není přihlášena';

  @override
  String get syncPayloadAgentEntity => 'Entita agenta';

  @override
  String get syncPayloadAgentLink => 'Propojení agenta';

  @override
  String get syncPayloadAiConfig => 'Nastavení AI';

  @override
  String get syncPayloadAiConfigDelete => 'Smazání nastavení AI';

  @override
  String get syncPayloadBackfillRequest => 'Žádost o doplnění';

  @override
  String get syncPayloadBackfillResponse => 'Odpověď na doplnění';

  @override
  String get syncPayloadEntityDefinition => 'Definice entity';

  @override
  String get syncPayloadEntryLink => 'Odkaz na položku';

  @override
  String get syncPayloadJournalEntity => 'Položka deníku';

  @override
  String get syncPayloadTagEntity => 'Entita štítku';

  @override
  String get syncPayloadThemingSelection => 'Výběr tématu';

  @override
  String get syncRetry => 'Zkusit znovu';

  @override
  String get syncRoomCreatedUnknown => 'Neznámé';

  @override
  String get syncRoomDiscoveryTitle =>
      'Najít existující synchronizační místnost';

  @override
  String get syncRoomHasContent => 'Má obsah';

  @override
  String get syncRoomUnnamed => 'Nepojmenovaná místnost';

  @override
  String get syncRoomVerified => 'Ověřená';

  @override
  String get syncSelectRoom => 'Vyberte synchronizační místnost';

  @override
  String get syncSelectRoomDescription =>
      'Našli jsme existující synchronizační místnosti. Vyberte si jednu, ke které se připojíte, nebo vytvořte novou místnost.';

  @override
  String get syncSkip => 'Přeskočit';

  @override
  String get syncStepAgentEntities => 'Entity agentů';

  @override
  String get syncStepAgentLinks => 'Propojení agentů';

  @override
  String get syncStepAiSettings => 'AI nastavení';

  @override
  String get syncStepCategories => 'Kategorie';

  @override
  String get syncStepComplete => 'Dokončeno';

  @override
  String get syncStepDashboards => 'Dashboardy';

  @override
  String get syncStepHabits => 'Zvyky';

  @override
  String get syncStepLabels => 'Štítky';

  @override
  String get syncStepMeasurables => 'Měřitelné hodnoty';

  @override
  String get syncStepTags => 'Tagy';

  @override
  String get taskAgentChipLabel => 'Agent';

  @override
  String get taskAgentCreateChipLabel => 'Vytvořit agenta';

  @override
  String taskAgentCreateError(String error) {
    return 'Nepodařilo se vytvořit agenta: $error';
  }

  @override
  String get taskCategoryAllLabel => 'vše';

  @override
  String get taskCategoryLabel => 'Kategorie:';

  @override
  String get taskCategoryUnassignedLabel => 'nepřiřazeno';

  @override
  String get taskDueDateLabel => 'Datum splnění';

  @override
  String taskDueDateWithDate(String date) {
    return 'Splnit do: $date';
  }

  @override
  String taskDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dní',
      one: '1 den',
    );
    return 'Splatné za $_temp0';
  }

  @override
  String get taskDueToday => 'Dnes splatné';

  @override
  String get taskDueTomorrow => 'Zítra splatné';

  @override
  String get taskDueYesterday => 'Včera splatné';

  @override
  String get taskEstimateLabel => 'Odhad:';

  @override
  String get taskLabelUnassignedLabel => 'nepřiřazeno';

  @override
  String get taskLanguageArabic => 'Arabština';

  @override
  String get taskLanguageBengali => 'Bengálština';

  @override
  String get taskLanguageBulgarian => 'Bulharština';

  @override
  String get taskLanguageChinese => 'Čínština';

  @override
  String get taskLanguageCroatian => 'Chorvatština';

  @override
  String get taskLanguageCzech => 'Čeština';

  @override
  String get taskLanguageDanish => 'Dánština';

  @override
  String get taskLanguageDutch => 'Nizozemština';

  @override
  String get taskLanguageEnglish => 'Angličtina';

  @override
  String get taskLanguageEstonian => 'Estonština';

  @override
  String get taskLanguageFinnish => 'Finština';

  @override
  String get taskLanguageFrench => 'Francouzština';

  @override
  String get taskLanguageGerman => 'Němčina';

  @override
  String get taskLanguageGreek => 'Řečtina';

  @override
  String get taskLanguageHebrew => 'Hebrejština';

  @override
  String get taskLanguageHindi => 'Hindština';

  @override
  String get taskLanguageHungarian => 'Maďarština';

  @override
  String get taskLanguageIgbo => 'Igboština';

  @override
  String get taskLanguageIndonesian => 'Indonéština';

  @override
  String get taskLanguageItalian => 'Italština';

  @override
  String get taskLanguageJapanese => 'Japonština';

  @override
  String get taskLanguageKorean => 'Korejština';

  @override
  String get taskLanguageLabel => 'Jazyk:';

  @override
  String get taskLanguageLatvian => 'Lotyština';

  @override
  String get taskLanguageLithuanian => 'Litevština';

  @override
  String get taskLanguageNigerianPidgin => 'Nigerijský pidžin';

  @override
  String get taskLanguageNorwegian => 'Norština';

  @override
  String get taskLanguagePolish => 'Polština';

  @override
  String get taskLanguagePortuguese => 'Portugalština';

  @override
  String get taskLanguageRomanian => 'Rumunština';

  @override
  String get taskLanguageRussian => 'Ruština';

  @override
  String get taskLanguageSearchPlaceholder => 'Hledat jazyky...';

  @override
  String get taskLanguageSelectedLabel => 'Aktuálně vybráno';

  @override
  String get taskLanguageSerbian => 'Srbština';

  @override
  String get taskLanguageSlovak => 'Slovenština';

  @override
  String get taskLanguageSlovenian => 'Slovinština';

  @override
  String get taskLanguageSpanish => 'Španělština';

  @override
  String get taskLanguageSwahili => 'Svahilština';

  @override
  String get taskLanguageSwedish => 'Švédština';

  @override
  String get taskLanguageThai => 'Thajština';

  @override
  String get taskLanguageTurkish => 'Turečtina';

  @override
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageUkrainian => 'Ukrajinština';

  @override
  String get taskLanguageVietnamese => 'Vietnamština';

  @override
  String get taskLanguageYoruba => 'Jorubština';

  @override
  String get taskNameHint => 'Zadejte název úkolu';

  @override
  String get taskNoDueDateLabel => 'Bez data splnění';

  @override
  String get taskNoEstimateLabel => 'Bez odhadu';

  @override
  String taskOverdueByDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dní',
      one: '1 den',
    );
    return 'Po splatnosti o $_temp0';
  }

  @override
  String get tasksAddLabelButton => 'Přidat štítek';

  @override
  String get tasksFilterTitle => 'Filtr úkolů';

  @override
  String get tasksLabelFilterAll => 'Vše';

  @override
  String get tasksLabelFilterTitle => 'Štítky';

  @override
  String get tasksLabelFilterUnlabeled => 'Bez štítku';

  @override
  String get tasksLabelsDialogClose => 'Zavřít';

  @override
  String get tasksLabelsHeaderEditTooltip => 'Upravit štítky';

  @override
  String get tasksLabelsHeaderTitle => 'Štítky';

  @override
  String get tasksLabelsNoLabels => 'Žádné štítky';

  @override
  String get tasksLabelsSheetApply => 'Použít';

  @override
  String get tasksLabelsSheetSearchHint => 'Hledat štítky…';

  @override
  String get tasksLabelsSheetTitle => 'Vybrat štítky';

  @override
  String get tasksLabelsUpdateFailed => 'Nepodařilo se aktualizovat štítky';

  @override
  String get tasksPriorityFilterAll => 'Vše';

  @override
  String get tasksPriorityFilterTitle => 'Priorita';

  @override
  String get tasksPriorityP0 => 'Naléhavé';

  @override
  String get tasksPriorityP0Description => 'Naléhavé (co nejdříve)';

  @override
  String get tasksPriorityP1 => 'Vysoká';

  @override
  String get tasksPriorityP1Description => 'Vysoká (brzy)';

  @override
  String get tasksPriorityP2 => 'Střední';

  @override
  String get tasksPriorityP2Description => 'Střední (výchozí)';

  @override
  String get tasksPriorityP3 => 'Nízká';

  @override
  String get tasksPriorityP3Description => 'Nízká (kdykoliv)';

  @override
  String get tasksPriorityPickerTitle => 'Vyberte prioritu';

  @override
  String get tasksPriorityTitle => 'Priorita:';

  @override
  String get tasksQuickFilterClear => 'Vymazat';

  @override
  String get tasksQuickFilterLabelsActiveTitle => 'Aktivní filtry štítků';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Nepřiřazeno';

  @override
  String get tasksShowCoverArt => 'Zobrazit obal na kartách';

  @override
  String get tasksShowCreationDate => 'Zobrazit datum vytvoření na kartách';

  @override
  String get tasksShowDueDate => 'Zobrazit datum splnění na kartách';

  @override
  String get tasksSortByCreationDate => 'Vytvořeno';

  @override
  String get tasksSortByDate => 'Datum';

  @override
  String get tasksSortByDueDate => 'Termín dokončení';

  @override
  String get tasksSortByLabel => 'Seřadit podle';

  @override
  String get tasksSortByPriority => 'Priorita';

  @override
  String get taskStatusAll => 'Vše';

  @override
  String get taskStatusBlocked => 'Blokováno';

  @override
  String get taskStatusDone => 'Hotovo';

  @override
  String get taskStatusGroomed => 'Připraveno';

  @override
  String get taskStatusInProgress => 'Probíhá';

  @override
  String get taskStatusLabel => 'Stav:';

  @override
  String get taskStatusOnHold => 'Pozastaveno';

  @override
  String get taskStatusOpen => 'Otevřeno';

  @override
  String get taskStatusRejected => 'Odmítnuto';

  @override
  String get taskSummaries => 'Souhrny úkolů';

  @override
  String get timeByCategoryChartTitle => 'Čas podle kategorie';

  @override
  String get timeByCategoryChartTotalLabel => 'Celkem';

  @override
  String get unlinkButton => 'Zrušit propojení';

  @override
  String get unlinkTaskConfirm =>
      'Opravdu chcete zrušit propojení tohoto úkolu?';

  @override
  String get unlinkTaskTitle => 'Zrušit propojení úkolu';

  @override
  String get viewMenuTitle => 'Zobrazit';

  @override
  String get whatsNewDoneButton => 'Hotovo';

  @override
  String get whatsNewSkipButton => 'Přeskočit';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get activeLabel => 'Aktiv';

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
  String get addActionAddTimer => 'Timer';

  @override
  String get addActionAddTimeRecording => 'Zeiteingabe';

  @override
  String get addActionImportImage => 'Bild importieren';

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
  String get addToDictionary => 'Zum Wörterbuch hinzufügen';

  @override
  String get addToDictionaryDuplicate =>
      'Begriff bereits im Wörterbuch vorhanden';

  @override
  String get addToDictionaryNoCategory =>
      'Kann nicht zum Wörterbuch hinzufügen: Aufgabe hat keine Kategorie';

  @override
  String get addToDictionarySaveFailed =>
      'Wörterbuch konnte nicht gespeichert werden';

  @override
  String get addToDictionarySuccess => 'Begriff zum Wörterbuch hinzugefügt';

  @override
  String get addToDictionaryTooLong => 'Begriff zu lang (max. 50 Zeichen)';

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
  String get aiConfigApiKeyEmptyError => 'API-Schlüssel darf nicht leer sein';

  @override
  String get aiConfigApiKeyFieldLabel => 'API-Schlüssel';

  @override
  String aiConfigAssociatedModelsRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' Modelle',
      one: 's Modell',
    );
    return '$count zugehörige$_temp0 entfernt';
  }

  @override
  String get aiConfigBaseUrlFieldLabel => 'Basis-URL';

  @override
  String get aiConfigCommentFieldLabel => 'Kommentar (Optional)';

  @override
  String get aiConfigCreateButtonLabel => 'Prompt erstellen';

  @override
  String get aiConfigDescriptionFieldLabel => 'Beschreibung (Optional)';

  @override
  String aiConfigFailedToLoadModels(String error) {
    return 'Modelle konnten nicht geladen werden: $error';
  }

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Fehler beim Laden der Modelle. Bitte versuche es erneut.';

  @override
  String get aiConfigFailedToSaveMessage =>
      'Konfiguration konnte nicht gespeichert werden. Bitte versuche es erneut.';

  @override
  String get aiConfigInputDataTypesTitle => 'Erforderliche Eingabedatentypen';

  @override
  String get aiConfigInputModalitiesFieldLabel => 'Eingabemodalitäten';

  @override
  String get aiConfigInputModalitiesTitle => 'Eingabemodalitäten';

  @override
  String get aiConfigInvalidUrlError => 'Bitte gib eine gültige URL ein';

  @override
  String get aiConfigListCascadeDeleteWarning =>
      'Dies löscht auch alle mit diesem Anbieter verknüpften Modelle.';

  @override
  String get aiConfigListDeleteConfirmCancel => 'ABBRECHEN';

  @override
  String get aiConfigListDeleteConfirmDelete => 'LÖSCHEN';

  @override
  String aiConfigListDeleteConfirmMessage(String configName) {
    return 'Möchtest du \"$configName\" wirklich löschen?';
  }

  @override
  String get aiConfigListDeleteConfirmTitle => 'Löschen bestätigen';

  @override
  String get aiConfigListEmptyState =>
      'Keine Konfigurationen gefunden. Füge eine hinzu, um zu beginnen.';

  @override
  String aiConfigListErrorDeleting(String configName, String error) {
    return 'Fehler beim Löschen von $configName: $error';
  }

  @override
  String get aiConfigListErrorLoading =>
      'Fehler beim Laden der Konfigurationen';

  @override
  String aiConfigListItemDeleted(String configName) {
    return '$configName gelöscht';
  }

  @override
  String get aiConfigListUndoDelete => 'RÜCKGÄNGIG';

  @override
  String get aiConfigManageModelsButton => 'Modelle verwalten';

  @override
  String aiConfigModelRemovedMessage(String modelName) {
    return '$modelName vom Prompt entfernt';
  }

  @override
  String get aiConfigModelsTitle => 'Verfügbare Modelle';

  @override
  String get aiConfigNameFieldLabel => 'Anzeigename';

  @override
  String get aiConfigNameTooShortError =>
      'Name muss mindestens 3 Zeichen haben';

  @override
  String get aiConfigNoModelsAvailable =>
      'Noch keine AI-Modelle konfiguriert. Bitte füge eines in den Einstellungen hinzu.';

  @override
  String get aiConfigNoModelsSelected =>
      'Keine Modelle ausgewählt. Mindestens ein Modell ist erforderlich.';

  @override
  String get aiConfigNoProvidersAvailable =>
      'Keine API-Anbieter verfügbar. Bitte füge zuerst einen API-Anbieter hinzu.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Keine Modelle erfüllen die Anforderungen für diesen Prompt. Bitte konfiguriere Modelle mit den erforderlichen Fähigkeiten.';

  @override
  String get aiConfigOutputModalitiesFieldLabel => 'Ausgabemodalitäten';

  @override
  String get aiConfigOutputModalitiesTitle => 'Ausgabemodalitäten';

  @override
  String get aiConfigProviderDeletedSuccessfully =>
      'Anbieter erfolgreich gelöscht';

  @override
  String get aiConfigProviderFieldLabel => 'Inferenz-Anbieter';

  @override
  String get aiConfigProviderModelIdFieldLabel => 'Modell-ID des Anbieters';

  @override
  String get aiConfigProviderModelIdTooShortError =>
      'Modell-ID muss mindestens 3 Zeichen haben';

  @override
  String get aiConfigProviderTypeFieldLabel => 'Anbietertyp';

  @override
  String get aiConfigReasoningCapabilityDescription =>
      'Modell kann schrittweises Schlussfolgern durchführen';

  @override
  String get aiConfigReasoningCapabilityFieldLabel =>
      'Schlussfolgerungsfähigkeit';

  @override
  String get aiConfigRequiredInputDataFieldLabel =>
      'Erforderliche Eingabedaten';

  @override
  String get aiConfigResponseTypeFieldLabel => 'AI-Antworttyp';

  @override
  String get aiConfigResponseTypeNotSelectedError =>
      'Bitte wähle einen Antworttyp';

  @override
  String get aiConfigResponseTypeSelectHint => 'Antworttyp auswählen';

  @override
  String get aiConfigSelectInputDataTypesPrompt =>
      'Erforderliche Datentypen auswählen...';

  @override
  String get aiConfigSelectModalitiesPrompt => 'Modalitäten auswählen';

  @override
  String get aiConfigSelectProviderModalTitle => 'Inferenz-Anbieter auswählen';

  @override
  String get aiConfigSelectProviderNotFound =>
      'Inferenz-Anbieter nicht gefunden';

  @override
  String get aiConfigSelectProviderTypeModalTitle => 'Anbietertyp auswählen';

  @override
  String get aiConfigSelectResponseTypeTitle => 'AI-Antworttyp auswählen';

  @override
  String get aiConfigSystemMessageFieldLabel => 'Systemnachricht';

  @override
  String get aiConfigUpdateButtonLabel => 'Prompt aktualisieren';

  @override
  String get aiConfigUseReasoningDescription =>
      'Wenn aktiviert, nutzt das Modell seine Schlussfolgerungsfähigkeiten für diesen Prompt.';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Schlussfolgerung verwenden';

  @override
  String get aiConfigUserMessageEmptyError =>
      'Benutzernachricht darf nicht leer sein';

  @override
  String get aiConfigUserMessageFieldLabel => 'Benutzernachricht';

  @override
  String get aiFormCancel => 'Abbrechen';

  @override
  String get aiFormFixErrors => 'Bitte behebe die Fehler vor dem Speichern';

  @override
  String get aiFormNoChanges => 'Keine ungespeicherten Änderungen';

  @override
  String get aiInferenceErrorAuthenticationMessage =>
      'Authentifizierung fehlgeschlagen. Bitte überprüfe deinen API-Schlüssel.';

  @override
  String get aiInferenceErrorAuthenticationTitle =>
      'Authentifizierung fehlgeschlagen';

  @override
  String get aiInferenceErrorConnectionFailedMessage =>
      'Verbindung zum AI-Dienst nicht möglich. Bitte überprüfe deine Internetverbindung.';

  @override
  String get aiInferenceErrorConnectionFailedTitle =>
      'Verbindung fehlgeschlagen';

  @override
  String get aiInferenceErrorInvalidRequestMessage =>
      'Die Anfrage war ungültig. Bitte überprüfe deine Konfiguration und versuche es erneut.';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Ungültige Anfrage';

  @override
  String get aiInferenceErrorRateLimitMessage =>
      'Ratenlimit überschritten. Bitte warte einen Moment.';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Ratenlimit überschritten';

  @override
  String get aiInferenceErrorRetryButton => 'Erneut versuchen';

  @override
  String get aiInferenceErrorServerMessage =>
      'Der AI-Dienst hat einen Fehler festgestellt. Bitte versuche es später erneut.';

  @override
  String get aiInferenceErrorServerTitle => 'Serverfehler';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Vorschläge:';

  @override
  String get aiInferenceErrorTimeoutMessage =>
      'Die Anfrage hat zu lange gedauert. Bitte versuche es erneut.';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Zeitüberschreitung';

  @override
  String get aiInferenceErrorUnknownMessage =>
      'Ein unerwarteter Fehler ist aufgetreten. Bitte versuche es erneut.';

  @override
  String get aiInferenceErrorUnknownTitle => 'Fehler';

  @override
  String get aiInferenceErrorViewLogButton => 'Protokoll anzeigen';

  @override
  String get aiModelSettings => 'AI-Modell-Einstellungen';

  @override
  String get aiProviderAnthropicDescription =>
      'Anthropics Claude-Familie von AI-Assistenten';

  @override
  String get aiProviderAnthropicName => 'Anthropic Claude';

  @override
  String get aiProviderGeminiDescription => 'Googles Gemini AI-Modelle';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiDescription =>
      'API kompatibel mit OpenAI-Format';

  @override
  String get aiProviderGenericOpenAiName => 'OpenAI-kompatibel';

  @override
  String get aiProviderMistralDescription => 'Mistral AI Cloud-API';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderNebiusAiStudioDescription =>
      'Modelle von Nebius AI Studio';

  @override
  String get aiProviderNebiusAiStudioName => 'Nebius AI Studio';

  @override
  String get aiProviderOllamaDescription => 'Lokale Inferenz mit Ollama';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOpenAiDescription => 'OpenAIs GPT-Modelle';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'Modelle von OpenRouter';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderVoxtralDescription =>
      'Lokale Voxtral-Transkription (bis zu 30 Min. Audio, 9 Sprachen)';

  @override
  String get aiProviderVoxtralName => 'Voxtral (lokal)';

  @override
  String get aiProviderWhisperDescription =>
      'Lokale Whisper-Transkription mit OpenAI-kompatibler API';

  @override
  String get aiProviderWhisperName => 'Whisper (lokal)';

  @override
  String get aiResponseDeleteCancel => 'Abbrechen';

  @override
  String get aiResponseDeleteConfirm => 'Löschen';

  @override
  String get aiResponseDeleteError =>
      'KI-Antwort konnte nicht gelöscht werden. Bitte versuche es erneut.';

  @override
  String get aiResponseDeleteTitle => 'KI-Antwort löschen';

  @override
  String get aiResponseDeleteWarning =>
      'Möchtest du diese KI-Antwort wirklich löschen? Dies kann nicht rückgängig gemacht werden.';

  @override
  String get aiResponseTypeAudioTranscription => 'Audio-Transkription';

  @override
  String get aiResponseTypeChecklistUpdates => 'Checklisten-Updates';

  @override
  String get aiResponseTypeImageAnalysis => 'Bildanalyse';

  @override
  String get aiResponseTypeImagePromptGeneration => 'Bild-Prompt';

  @override
  String get aiResponseTypePromptGeneration => 'Generierter Prompt';

  @override
  String get aiResponseTypeTaskSummary => 'Aufgabenzusammenfassung';

  @override
  String get aiSettingsAddedLabel => 'Hinzugefügt';

  @override
  String get aiSettingsAddModelButton => 'Modell hinzufügen';

  @override
  String get aiSettingsAddModelTooltip =>
      'Dieses Modell zu deinem Anbieter hinzufügen';

  @override
  String get aiSettingsAddPromptButton => 'Prompt hinzufügen';

  @override
  String get aiSettingsAddProviderButton => 'Anbieter hinzufügen';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Alle Filter zurücksetzen';

  @override
  String get aiSettingsClearFiltersButton => 'Löschen';

  @override
  String aiSettingsDeleteSelectedConfirmMessage(int count) {
    return 'Möchtest du wirklich $count ausgewählte Prompts löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get aiSettingsDeleteSelectedConfirmTitle =>
      'Ausgewählte Prompts löschen';

  @override
  String aiSettingsDeleteSelectedLabel(int count) {
    return 'Löschen ($count)';
  }

  @override
  String get aiSettingsDeleteSelectedTooltip => 'Ausgewählte Prompts löschen';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Nach Fähigkeit $capability filtern';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Nach $provider filtern';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip =>
      'Nach Schlussfolgerungsfähigkeit filtern';

  @override
  String aiSettingsFilterByResponseTypeTooltip(String responseType) {
    return 'Nach $responseType-Prompts filtern';
  }

  @override
  String get aiSettingsModalityAudio => 'Audio';

  @override
  String get aiSettingsModalityText => 'Text';

  @override
  String get aiSettingsModalityVision => 'Bild';

  @override
  String get aiSettingsNoModelsConfigured => 'Keine AI-Modelle konfiguriert';

  @override
  String get aiSettingsNoPromptsConfigured => 'Keine AI-Prompts konfiguriert';

  @override
  String get aiSettingsNoProvidersConfigured =>
      'Keine AI-Anbieter konfiguriert';

  @override
  String get aiSettingsPageTitle => 'AI-Einstellungen';

  @override
  String get aiSettingsReasoningLabel => 'Schlussfolgerung';

  @override
  String get aiSettingsSearchHint => 'AI-Konfigurationen suchen...';

  @override
  String get aiSettingsSelectLabel => 'Auswählen';

  @override
  String get aiSettingsSelectModeTooltip =>
      'Auswahlmodus für Massenoperationen umschalten';

  @override
  String get aiSettingsTabModels => 'Modelle';

  @override
  String get aiSettingsTabPrompts => 'Prompts';

  @override
  String get aiSettingsTabProviders => 'Anbieter';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Erstellt optimierte Modelle, Prompts und eine Testkategorie';

  @override
  String aiSetupWizardDescription(String providerName) {
    return 'Modelle, Prompts und Testkategorie für $providerName einrichten oder aktualisieren';
  }

  @override
  String get aiSetupWizardRunButton => 'Einrichtung starten';

  @override
  String get aiSetupWizardRunLabel => 'Einrichtungsassistent ausführen';

  @override
  String get aiSetupWizardRunningButton => 'Wird ausgeführt...';

  @override
  String get aiSetupWizardSafeToRunMultiple =>
      'Kann mehrfach ausgeführt werden - vorhandene Elemente werden beibehalten';

  @override
  String get aiSetupWizardTitle => 'KI-Einrichtungsassistent';

  @override
  String get aiTaskSummaryCancelScheduled =>
      'Geplante Zusammenfassung abbrechen';

  @override
  String get aiTaskSummaryRunning =>
      'Denke über die Zusammenfassung der Aufgabe nach...';

  @override
  String aiTaskSummaryScheduled(String time) {
    return 'Zusammenfassung in $time';
  }

  @override
  String get aiTaskSummaryTitle => 'KI-Aufgabenzusammenfassung';

  @override
  String get aiTaskSummaryTriggerNow => 'Zusammenfassung jetzt erstellen';

  @override
  String get aiTranscribingAudio => 'Audio wird transkribiert...';

  @override
  String get apiKeyAddPageTitle => 'Anbieter hinzufügen';

  @override
  String get apiKeyEditLoadError =>
      'API-Schlüssel-Konfiguration konnte nicht geladen werden';

  @override
  String get apiKeyEditPageTitle => 'Anbieter bearbeiten';

  @override
  String get apiKeyFormCreateButton => 'Erstellen';

  @override
  String get apiKeyFormUpdateButton => 'Aktualisieren';

  @override
  String get apiKeysSettingsPageTitle => 'AI-Inferenz-Anbieter';

  @override
  String get audioRecordings => 'Audioaufnahmen';

  @override
  String get automaticPrompts => 'Automatische Prompts';

  @override
  String get backfillManualDescription =>
      'Alle fehlenden Einträge unabhängig vom Alter anfordern. Nutze dies zur Wiederherstellung älterer Synchronisierungslücken.';

  @override
  String get backfillManualProcessing => 'Verarbeitung...';

  @override
  String backfillManualSuccess(int count) {
    return '$count Einträge angefordert';
  }

  @override
  String get backfillManualTitle => 'Manuelle Nachfüllung';

  @override
  String get backfillManualTrigger => 'Fehlende Einträge anfordern';

  @override
  String get backfillReRequestDescription =>
      'Einträge erneut anfordern, die angefordert aber nie empfangen wurden. Nutze dies bei hängenden Antworten.';

  @override
  String get backfillReRequestProcessing => 'Erneut anfordern...';

  @override
  String backfillReRequestSuccess(int count) {
    return '$count Einträge erneut angefordert';
  }

  @override
  String get backfillReRequestTitle => 'Ausstehende erneut anfordern';

  @override
  String get backfillReRequestTrigger =>
      'Ausstehende Einträge erneut anfordern';

  @override
  String get backfillSettingsInfo =>
      'Automatische Nachfüllung fordert fehlende Einträge der letzten 24 Stunden an. Nutze manuelle Nachfüllung für ältere Einträge.';

  @override
  String get backfillSettingsSubtitle => 'Synchronisierungslücken verwalten';

  @override
  String get backfillSettingsTitle => 'Sync-Nachfüllung';

  @override
  String get backfillStatsBackfilled => 'Nachgefüllt';

  @override
  String get backfillStatsDeleted => 'Gelöscht';

  @override
  String backfillStatsHostsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' Geräte',
      one: 's Gerät',
    );
    return '$count verbundene$_temp0';
  }

  @override
  String get backfillStatsMissing => 'Fehlend';

  @override
  String get backfillStatsNoData => 'Keine Synchronisierungsdaten verfügbar';

  @override
  String get backfillStatsReceived => 'Empfangen';

  @override
  String get backfillStatsRefresh => 'Statistiken aktualisieren';

  @override
  String get backfillStatsRequested => 'Angefordert';

  @override
  String get backfillStatsTitle => 'Synchronisierungsstatistiken';

  @override
  String get backfillStatsTotalEntries => 'Einträge gesamt';

  @override
  String get backfillStatsUnresolvable => 'Nicht auflösbar';

  @override
  String get backfillToggleDisabledDescription =>
      'Nachfüllung deaktiviert – nützlich bei Mobilfunknetzen';

  @override
  String get backfillToggleEnabledDescription =>
      'Fehlende Sync-Einträge automatisch anfordern';

  @override
  String get backfillToggleTitle => 'Automatische Nachfüllung';

  @override
  String get basicSettings => 'Grundeinstellungen';

  @override
  String get cancelButton => 'Abbrechen';

  @override
  String get categoryActiveDescription =>
      'Inaktive Kategorien erscheinen nicht in Auswahllisten';

  @override
  String get categoryAiModelDescription =>
      'Steuere, welche AI-Prompts mit dieser Kategorie verwendet werden können';

  @override
  String get categoryAutomaticPromptsDescription =>
      'Prompts konfigurieren, die automatisch für verschiedene Inhaltstypen ausgeführt werden';

  @override
  String get categoryCreationError =>
      'Kategorie konnte nicht erstellt werden. Bitte versuche es erneut.';

  @override
  String get categoryDefaultLanguageDescription =>
      'Standardsprache für Aufgaben in dieser Kategorie festlegen';

  @override
  String get categoryDeleteConfirm => 'JA, DIESE KATEGORIE LÖSCHEN';

  @override
  String get categoryDeleteConfirmation =>
      'Diese Aktion kann nicht rückgängig gemacht werden. Alle Einträge in dieser Kategorie bleiben erhalten, werden aber nicht mehr kategorisiert.';

  @override
  String get categoryDeleteQuestion => 'Möchtest du diese Kategorie löschen?';

  @override
  String get categoryDeleteTitle => 'Kategorie löschen?';

  @override
  String get categoryFavoriteDescription =>
      'Diese Kategorie als Favorit markieren';

  @override
  String get categoryNameRequired => 'Kategoriename ist erforderlich';

  @override
  String get categoryNotFound => 'Kategorie nicht gefunden';

  @override
  String get categoryPrivateDescription =>
      'Diese Kategorie ausblenden, wenn der private Modus aktiviert ist';

  @override
  String get categorySearchPlaceholder => 'Kategorien suchen...';

  @override
  String get celebrationTapToContinue => 'Tippen zum Fortfahren';

  @override
  String get checklistAddItem => 'Neues Element hinzufügen';

  @override
  String get checklistAllDone => 'Alle Punkte erledigt!';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total erledigt';
  }

  @override
  String get checklistDelete => 'Checkliste löschen?';

  @override
  String get checklistExportAsMarkdown => 'Checkliste als Markdown exportieren';

  @override
  String get checklistExportFailed => 'Export fehlgeschlagen';

  @override
  String get checklistFilterShowAll => 'Alle Einträge anzeigen';

  @override
  String get checklistFilterShowOpen => 'Offene Einträge anzeigen';

  @override
  String get checklistFilterStateAll => 'Alle Einträge werden angezeigt';

  @override
  String get checklistFilterStateOpenOnly => 'Offene Einträge werden angezeigt';

  @override
  String checklistFilterToggleSemantics(String state) {
    return 'Checklisten-Filter umschalten (aktuell: $state)';
  }

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
  String get checklistMarkdownCopied => 'Checkliste als Markdown kopiert';

  @override
  String get checklistNoSuggestionsTitle =>
      'Keine vorgeschlagenen Aktionspunkte';

  @override
  String get checklistNothingToExport => 'Keine Einträge zum Exportieren';

  @override
  String get checklistShareHint => 'Lange drücken zum Teilen';

  @override
  String get checklistsReorder => 'Neu anordnen';

  @override
  String get checklistsTitle => 'Checklisten';

  @override
  String get checklistSuggestionsOutdated => 'Veraltet';

  @override
  String get checklistSuggestionsRunning =>
      'Denke über nicht verfolgte Vorschläge nach...';

  @override
  String get checklistSuggestionsTitle => 'Vorgeschlagene Aktionspunkte';

  @override
  String get checklistUpdates => 'Checklisten-Updates';

  @override
  String get clearButton => 'Löschen';

  @override
  String get colorLabel => 'Farbe:';

  @override
  String get colorPickerError => 'Ungültige Hex-Farbe';

  @override
  String get colorPickerHint => 'Hex-Farbe eingeben oder auswählen';

  @override
  String get commonError => 'Fehler';

  @override
  String get commonLoading => 'Laden...';

  @override
  String get commonUnknown => 'Unbekannt';

  @override
  String get completeHabitFailButton => 'Fehlgeschlagen';

  @override
  String get completeHabitSkipButton => 'Überspringen';

  @override
  String get completeHabitSuccessButton => 'Erfolgreich';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Wenn aktiviert, versucht die App, Einbettungen für deine Einträge zu generieren, um die Suche und Vorschläge für verwandte Inhalte zu verbessern.';

  @override
  String get configFlagAutoTranscribeDescription =>
      'Transkribiert automatisch Audioaufnahmen in deinen Einträgen. Dies erfordert eine Internetverbindung.';

  @override
  String get configFlagEnableAiStreaming =>
      'AI-Streaming für Aufgabenaktionen aktivieren';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Streame AI-Antworten für aufgabenbezogene Aktionen. Deaktivieren, um Antworten zu puffern und die UI flüssiger zu halten.';

  @override
  String get configFlagEnableAutoTaskTldrDescription =>
      'Generiert automatisch Zusammenfassungen für deine Aufgaben, damit du deren Status schnell erfassen kannst.';

  @override
  String get configFlagEnableCalendarPage => 'Seite Kalender aktivieren';

  @override
  String get configFlagEnableCalendarPageDescription =>
      'Zeigt die Kalenderseite in der Hauptnavigation an. Zeige und verwalte deine Einträge in einer Kalenderansicht.';

  @override
  String get configFlagEnableDailyOs => 'DailyOS aktivieren';

  @override
  String get configFlagEnableDailyOsDescription =>
      'DailyOS in der Hauptnavigation anzeigen.';

  @override
  String get configFlagEnableDashboardsPage => 'Seite Dashboards aktivieren';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Zeigt die Dashboard-Seite in der Hauptnavigation an. Zeige deine Daten und Erkenntnisse in anpassbaren Dashboards an.';

  @override
  String get configFlagEnableEvents => 'Ereignisse aktivieren';

  @override
  String get configFlagEnableEventsDescription =>
      'Ereignisfunktion anzeigen, um Ereignisse in deinem Journal zu erstellen, zu verfolgen und zu verwalten.';

  @override
  String get configFlagEnableHabitsPage => 'Seite Gewohnheiten aktivieren';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Zeigt die Seite \"Gewohnheiten\" in der Hauptnavigation an. Verfolge und verwalte hier deine täglichen Gewohnheiten.';

  @override
  String get configFlagEnableLogging => 'Protokollierung aktivieren';

  @override
  String get configFlagEnableLoggingDescription =>
      'Aktiviert die detaillierte Protokollierung für Debugging-Zwecke. Dies kann die Leistung beeinträchtigen.';

  @override
  String get configFlagEnableMatrix => 'Matrix-Synchronisation aktivieren';

  @override
  String get configFlagEnableMatrixDescription =>
      'Aktiviert die Matrix-Integration, um deine Einträge geräteübergreifend und mit anderen Matrix-Benutzern zu synchronisieren.';

  @override
  String get configFlagEnableNotifications => 'Benachrichtigungen aktivieren?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Erhalte Benachrichtigungen für Erinnerungen, Updates und wichtige Ereignisse.';

  @override
  String get configFlagEnableSessionRatings => 'Sitzungsbewertungen aktivieren';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Nach dem Stoppen eines Timers eine schnelle Sitzungsbewertung anzeigen.';

  @override
  String get configFlagEnableTooltip => 'Tooltips aktivieren';

  @override
  String get configFlagEnableTooltipDescription =>
      'Zeigt hilfreiche Tooltips in der gesamten App an, um dich durch die Funktionen zu führen.';

  @override
  String get configFlagPrivate => 'Private Einträge anzeigen?';

  @override
  String get configFlagPrivateDescription =>
      'Aktiviere diese Option, um deine Einträge standardmäßig privat zu machen. Private Einträge sind nur für dich sichtbar.';

  @override
  String get configFlagRecordLocation => 'Standort aufzeichnen';

  @override
  String get configFlagRecordLocationDescription =>
      'Zeichnet automatisch deinen Standort mit neuen Einträgen auf. Dies hilft bei der ortsbezogenen Organisation und Suche.';

  @override
  String get configFlagResendAttachments => 'Anhänge erneut senden';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Aktiviere diese Option, um fehlgeschlagene Anlagen-Uploads automatisch erneut zu senden, wenn die Verbindung wiederhergestellt ist.';

  @override
  String get configFlagUseCloudInferenceDescription =>
      'Cloud-basierte KI-Dienste für erweiterte Funktionen verwenden. Dies erfordert eine Internetverbindung.';

  @override
  String get conflictEntityLabel => 'Entität';

  @override
  String get conflictIdLabel => 'ID';

  @override
  String get conflictsCopyTextFromSync => 'Text aus Synchronisierung kopieren';

  @override
  String get conflictsEmptyDescription =>
      'Alles ist synchronisiert. Gelöste Einträge bleiben im anderen Filter verfügbar.';

  @override
  String get conflictsEmptyTitle => 'Keine Konflikte erkannt';

  @override
  String get conflictsResolved => 'gelöst';

  @override
  String get conflictsResolveLocalVersion => 'Mit lokaler Version auflösen';

  @override
  String get conflictsResolveRemoteVersion => 'Mit entfernter Version auflösen';

  @override
  String get conflictsUnresolved => 'ungelöst';

  @override
  String get copyAsMarkdown => 'Als Markdown kopieren';

  @override
  String get copyAsText => 'Als Text kopieren';

  @override
  String get correctionExampleCancel => 'ABBRECHEN';

  @override
  String get correctionExampleCaptured => 'Korrektur für KI-Lernen gespeichert';

  @override
  String correctionExamplePending(int seconds) {
    return 'Korrektur wird in ${seconds}s gespeichert...';
  }

  @override
  String get correctionExamplesEmpty =>
      'Noch keine Korrekturen erfasst. Bearbeite ein Checklistenelement, um dein erstes Beispiel hinzuzufügen.';

  @override
  String get correctionExamplesSectionDescription =>
      'Wenn du Checklistenelemente manuell korrigierst, werden diese Korrekturen hier gespeichert und zur Verbesserung der KI-Vorschläge verwendet.';

  @override
  String get correctionExamplesSectionTitle => 'Checklisten-Korrekturbeispiele';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'Du hast $count Korrekturen. Nur die neuesten $max werden in KI-Prompts verwendet. Erwäge, alte oder redundante Beispiele zu löschen.';
  }

  @override
  String get coverArtAssign => 'Als Titelbild setzen';

  @override
  String get coverArtChipActive => 'Titelbild';

  @override
  String get coverArtChipSet => 'Titelbild setzen';

  @override
  String get coverArtRemove => 'Titelbild entfernen';

  @override
  String get createButton => 'Erstellen';

  @override
  String get createCategoryTitle => 'Kategorie erstellen:';

  @override
  String get createEntryLabel => 'Neuen Eintrag erstellen';

  @override
  String get createEntryTitle => 'Hinzufügen';

  @override
  String get createNewLinkedTask => 'Neue verknüpfte Aufgabe erstellen...';

  @override
  String get createPromptsFirst =>
      'Erstelle zuerst AI-Prompts, um sie hier zu konfigurieren';

  @override
  String get customColor => 'Benutzerdefinierte Farbe';

  @override
  String get dailyOsActual => 'Tatsächlich';

  @override
  String get dailyOsAddBlock => 'Block hinzufügen';

  @override
  String get dailyOsAddBudget => 'Budget hinzufügen';

  @override
  String get dailyOsAddNote => 'Notiz hinzufügen...';

  @override
  String get dailyOsAgreeToPlan => 'Plan bestätigen';

  @override
  String get dailyOsCancel => 'Abbrechen';

  @override
  String get dailyOsCategory => 'Kategorie';

  @override
  String get dailyOsChooseCategory => 'Kategorie auswählen...';

  @override
  String get dailyOsCompletionMessage =>
      'Gut gemacht! Du hast deinen Tag abgeschlossen.';

  @override
  String get dailyOsCopyToTomorrow => 'Auf morgen kopieren';

  @override
  String get dailyOsDayComplete => 'Tag abgeschlossen';

  @override
  String get dailyOsDayPlan => 'Tagesplan';

  @override
  String get dailyOsDaySummary => 'Tageszusammenfassung';

  @override
  String get dailyOsDelete => 'Löschen';

  @override
  String get dailyOsDeleteBudget => 'Budget löschen?';

  @override
  String get dailyOsDeleteBudgetConfirm =>
      'Dies entfernt das Zeitbudget aus deinem Tagesplan.';

  @override
  String get dailyOsDeletePlannedBlock => 'Block löschen?';

  @override
  String get dailyOsDeletePlannedBlockConfirm =>
      'Dies entfernt den geplanten Block aus deiner Zeitleiste.';

  @override
  String get dailyOsDoneForToday => 'Fertig für heute';

  @override
  String get dailyOsDraftMessage =>
      'Plan ist ein Entwurf. Bestätige, um ihn festzulegen.';

  @override
  String get dailyOsDueToday => 'Heute fällig';

  @override
  String get dailyOsDueTodayShort => 'Fällig';

  @override
  String dailyOsDuplicateBudget(String categoryName) {
    return 'Ein Budget für \"$categoryName\" existiert bereits';
  }

  @override
  String get dailyOsDuration1h => '1 Std.';

  @override
  String get dailyOsDuration2h => '2 Std.';

  @override
  String get dailyOsDuration30m => '30 Min.';

  @override
  String get dailyOsDuration3h => '3 Std.';

  @override
  String get dailyOsDuration4h => '4 Std.';

  @override
  String dailyOsDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden',
      one: '1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String dailyOsDurationHoursMinutes(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String dailyOsDurationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minuten',
      one: '1 Minute',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsEditBudget => 'Budget bearbeiten';

  @override
  String get dailyOsEditPlannedBlock => 'Geplanten Block bearbeiten';

  @override
  String get dailyOsEndTime => 'Ende';

  @override
  String get dailyOsEntry => 'Eintrag';

  @override
  String get dailyOsExpandToMove =>
      'Zeitleiste erweitern, um diesen Block zu verschieben';

  @override
  String get dailyOsExpandToMoveMore =>
      'Zeitleiste erweitern, um weiter zu verschieben';

  @override
  String get dailyOsFailedToLoadBudgets =>
      'Budgets konnten nicht geladen werden';

  @override
  String get dailyOsFailedToLoadTimeline =>
      'Zeitleiste konnte nicht geladen werden';

  @override
  String get dailyOsFold => 'Einklappen';

  @override
  String dailyOsHoursMinutesPlanned(int hours, int minutes) {
    return '$hours Std. $minutes Min. geplant';
  }

  @override
  String dailyOsHoursPlanned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden geplant',
      one: '1 Stunde geplant',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsInvalidTimeRange => 'Ungültiger Zeitbereich';

  @override
  String dailyOsMinutesPlanned(int count) {
    return '$count Min. geplant';
  }

  @override
  String get dailyOsNearLimit => 'Fast am Limit';

  @override
  String get dailyOsNoBudgets => 'Keine Zeitbudgets';

  @override
  String get dailyOsNoBudgetsHint =>
      'Füge Budgets hinzu, um zu verfolgen, wie du deine Zeit auf Kategorien verteilst.';

  @override
  String get dailyOsNoBudgetWarning => 'Keine Zeit eingeplant';

  @override
  String get dailyOsNote => 'Notiz';

  @override
  String get dailyOsNoTimeline => 'Keine Zeitleisteneinträge';

  @override
  String get dailyOsNoTimelineHint =>
      'Starte einen Timer oder füge geplante Blöcke hinzu, um deinen Tag zu sehen.';

  @override
  String get dailyOsOnTrack => 'Im Plan';

  @override
  String get dailyOsOver => 'Über';

  @override
  String get dailyOsOverallProgress => 'Gesamtfortschritt';

  @override
  String get dailyOsOverBudget => 'Über Budget';

  @override
  String get dailyOsOverdue => 'Überfällig';

  @override
  String get dailyOsOverdueShort => 'Spät';

  @override
  String get dailyOsPlan => 'Plan';

  @override
  String get dailyOsPlanned => 'Geplant';

  @override
  String get dailyOsPlannedDuration => 'Geplante Dauer';

  @override
  String get dailyOsQuickCreateTask => 'Aufgabe für dieses Budget erstellen';

  @override
  String get dailyOsReAgree => 'Erneut bestätigen';

  @override
  String get dailyOsRecorded => 'Erfasst';

  @override
  String get dailyOsRemaining => 'Verbleibend';

  @override
  String get dailyOsReviewMessage =>
      'Änderungen erkannt. Überprüfe deinen Plan.';

  @override
  String get dailyOsSave => 'Speichern';

  @override
  String get dailyOsSelectCategory => 'Kategorie auswählen';

  @override
  String get dailyOsStartTime => 'Start';

  @override
  String get dailyOsTasks => 'Aufgaben';

  @override
  String get dailyOsTimeBudgets => 'Zeitbudgets';

  @override
  String dailyOsTimeLeft(String time) {
    return '$time verbleibend';
  }

  @override
  String get dailyOsTimeline => 'Zeitleiste';

  @override
  String dailyOsTimeOver(String time) {
    return '+$time darüber';
  }

  @override
  String get dailyOsTimeRange => 'Zeitbereich';

  @override
  String get dailyOsTimesUp => 'Zeit abgelaufen';

  @override
  String get dailyOsTodayButton => 'Heute';

  @override
  String get dailyOsUncategorized => 'Unkategorisiert';

  @override
  String get dailyOsViewModeClassic => 'Klassisch';

  @override
  String get dailyOsViewModeDailyOs => 'Daily OS';

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
  String get dashboardDeleteQuestion => 'Möchtest du dieses Dashboard löschen?';

  @override
  String get dashboardDescriptionLabel => 'Beschreibung (optional):';

  @override
  String get dashboardNameLabel => 'Dashboard-Name:';

  @override
  String get dashboardNotFound => 'Dashboard nicht gefunden';

  @override
  String get dashboardPrivateLabel => 'Privat:';

  @override
  String get defaultLanguage => 'Standardsprache';

  @override
  String get deleteButton => 'Löschen';

  @override
  String get done => 'Fertig';

  @override
  String get doneButton => 'Fertig';

  @override
  String get editMenuTitle => 'Bearbeiten';

  @override
  String get editorInsertDivider => 'Trennlinie einfügen';

  @override
  String get editorPlaceholder => 'Notizen eingeben...';

  @override
  String get enhancedPromptFormAdditionalDetailsTitle => 'Zusätzliche Details';

  @override
  String get enhancedPromptFormAiResponseTypeSubtitle =>
      'Format der erwarteten Antwort';

  @override
  String get enhancedPromptFormBasicConfigurationTitle => 'Grundkonfiguration';

  @override
  String get enhancedPromptFormConfigurationOptionsTitle =>
      'Konfigurationsoptionen';

  @override
  String get enhancedPromptFormDescription =>
      'Erstelle benutzerdefinierte Prompts für deine AI-Modelle';

  @override
  String get enhancedPromptFormDescriptionHelperText =>
      'Optionale Notizen zu Zweck und Verwendung dieses Prompts';

  @override
  String get enhancedPromptFormDisplayNameHelperText =>
      'Ein beschreibender Name für diese Prompt-Vorlage';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Aus vorgefertigten Prompt-Vorlagen wählen';

  @override
  String get enhancedPromptFormPromptConfigurationTitle =>
      'Prompt-Konfiguration';

  @override
  String get enhancedPromptFormQuickStartDescription =>
      'Mit einer vorgefertigten Vorlage Zeit sparen';

  @override
  String get enhancedPromptFormQuickStartTitle => 'Schnellstart';

  @override
  String get enhancedPromptFormRequiredInputDataSubtitle =>
      'Art der Daten, die dieser Prompt erwartet';

  @override
  String get enhancedPromptFormSystemMessageHelperText =>
      'Anweisungen, die das Verhalten und den Antwortstil der AI definieren';

  @override
  String get enhancedPromptFormUserMessageHelperText =>
      'Der Haupttext des Prompts.';

  @override
  String get enterCategoryName => 'Kategorienamen eingeben';

  @override
  String get entryActions => 'Aktionen';

  @override
  String get entryLabelsActionSubtitle =>
      'Labels zuweisen, um diesen Eintrag zu organisieren';

  @override
  String get entryLabelsActionTitle => 'Labels';

  @override
  String get entryLabelsEditTooltip => 'Labels bearbeiten';

  @override
  String get entryLabelsHeaderTitle => 'Labels';

  @override
  String get entryLabelsNoLabels => 'Keine Labels zugewiesen';

  @override
  String get entryTypeLabelAiResponse => 'AI-Antwort';

  @override
  String get entryTypeLabelChecklist => 'Checkliste';

  @override
  String get entryTypeLabelChecklistItem => 'Aufgabe';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Gewohnheit';

  @override
  String get entryTypeLabelJournalAudio => 'Audio';

  @override
  String get entryTypeLabelJournalEntry => 'Text';

  @override
  String get entryTypeLabelJournalEvent => 'Ereignis';

  @override
  String get entryTypeLabelJournalImage => 'Foto';

  @override
  String get entryTypeLabelMeasurementEntry => 'Messung';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Gesundheit';

  @override
  String get entryTypeLabelSurveyEntry => 'Umfrage';

  @override
  String get entryTypeLabelTask => 'Aufgabe';

  @override
  String get entryTypeLabelWorkoutEntry => 'Training';

  @override
  String get errorLoadingPrompts => 'Fehler beim Laden der Prompts';

  @override
  String get eventNameLabel => 'Ereignis:';

  @override
  String get favoriteLabel => 'Favorit';

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
  String get generateCoverArt => 'Cover generieren';

  @override
  String get generateCoverArtSubtitle =>
      'Bild aus Sprachbeschreibung erstellen';

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
  String get habitDeleteQuestion => 'Möchtest du diese Gewohnheit löschen?';

  @override
  String get habitPriorityLabel => 'Priorität:';

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
  String get habitShowAlertAtLabel => 'Alarm anzeigen um';

  @override
  String get habitShowFromLabel => 'Anzeigen ab';

  @override
  String get habitsOpenHeader => 'Jetzt fällig';

  @override
  String get habitsPendingLaterHeader => 'Später heute';

  @override
  String get imageGenerationAcceptButton => 'Als Cover übernehmen';

  @override
  String get imageGenerationCancelEdit => 'Abbrechen';

  @override
  String get imageGenerationEditPromptButton => 'Prompt bearbeiten';

  @override
  String get imageGenerationEditPromptLabel => 'Prompt bearbeiten';

  @override
  String get imageGenerationError => 'Bildgenerierung fehlgeschlagen';

  @override
  String get imageGenerationGenerating => 'Bild wird generiert...';

  @override
  String get imageGenerationModalTitle => 'Generiertes Bild';

  @override
  String get imageGenerationRetry => 'Wiederholen';

  @override
  String imageGenerationSaveError(String error) {
    return 'Bild konnte nicht gespeichert werden: $error';
  }

  @override
  String imageGenerationWithReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mit $count Referenzbildern',
      one: 'Mit 1 Referenzbild',
      zero: 'Keine Referenzbilder',
    );
    return '$_temp0';
  }

  @override
  String get imagePromptGenerationCardTitle => 'KI-Bild-Prompt';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Bild-Prompt in Zwischenablage kopiert';

  @override
  String get imagePromptGenerationCopyButton => 'Prompt kopieren';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Bild-Prompt in Zwischenablage kopieren';

  @override
  String get imagePromptGenerationExpandTooltip =>
      'Vollständigen Prompt anzeigen';

  @override
  String get imagePromptGenerationFullPromptLabel =>
      'Vollständiger Bild-Prompt:';

  @override
  String get images => 'Bilder';

  @override
  String get inputDataTypeAudioFilesDescription =>
      'Audiodateien als Eingabe verwenden';

  @override
  String get inputDataTypeAudioFilesName => 'Audiodateien';

  @override
  String get inputDataTypeImagesDescription => 'Bilder als Eingabe verwenden';

  @override
  String get inputDataTypeImagesName => 'Bilder';

  @override
  String get inputDataTypeTaskDescription =>
      'Aktuelle Aufgabe als Eingabe verwenden';

  @override
  String get inputDataTypeTaskName => 'Aufgabe';

  @override
  String get inputDataTypeTasksListDescription =>
      'Aufgabenliste als Eingabe verwenden';

  @override
  String get inputDataTypeTasksListName => 'Aufgabenliste';

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
      'Möchtest du diesen Journaleintrag löschen?';

  @override
  String get journalDurationLabel => 'Dauer:';

  @override
  String get journalFavoriteTooltip => 'nur Favoriten';

  @override
  String get journalFlaggedTooltip => 'nur markiert';

  @override
  String get journalHideLinkHint => 'Link ausblenden';

  @override
  String get journalHideMapHint => 'Karte ausblenden';

  @override
  String get journalLinkedEntriesAiLabel => 'KI-generierte Einträge anzeigen:';

  @override
  String get journalLinkedEntriesHiddenLabel => 'Versteckte Einträge anzeigen:';

  @override
  String get journalLinkedEntriesLabel => 'Verknüpfte Einträge';

  @override
  String get journalLinkedFromLabel => 'Verknüpft von:';

  @override
  String get journalLinkFromHint => 'Verknüpfen von';

  @override
  String get journalLinkToHint => 'Verknüpfen mit';

  @override
  String get journalPrivateTooltip => 'nur privat';

  @override
  String get journalSearchHint => 'Tagebuch durchsuchen...';

  @override
  String get journalShareAudioHint => 'Audio teilen';

  @override
  String get journalShareHint => 'Teilen';

  @override
  String get journalSharePhotoHint => 'Foto teilen';

  @override
  String get journalShowLinkHint => 'Link anzeigen';

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
      'Möchtest du diesen Eintrag wirklich trennen?';

  @override
  String get linkedFromLabel => 'VERKNÜPFT VON';

  @override
  String get linkedTasksMenuTooltip => 'Optionen für verknüpfte Aufgaben';

  @override
  String get linkedTasksTitle => 'Verknüpfte Aufgaben';

  @override
  String get linkedToLabel => 'VERKNÜPFT MIT';

  @override
  String get linkExistingTask => 'Vorhandene Aufgabe verknüpfen...';

  @override
  String get loggingFailedToLoad =>
      'Fehler beim Laden der Protokolle. Bitte versuche es erneut.';

  @override
  String get loggingFailedToLoadMore =>
      'Fehler beim Laden weiterer Ergebnisse. Bitte versuche es erneut.';

  @override
  String get loggingSearchFailed =>
      'Suche fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get logsSearchHint => 'Alle Logs durchsuchen...';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'JA, DATENBANK LÖSCHEN';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Bist du sicher, dass du die $databaseName-Datenbank löschen möchtest?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Entwürfe-Datenbank löschen';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Editor-Entwürfe-Datenbank löschen';

  @override
  String get maintenanceDeleteLoggingDb => 'Logging-Datenbank löschen';

  @override
  String get maintenanceDeleteLoggingDbDescription =>
      'Logging-Datenbank löschen';

  @override
  String get maintenanceDeleteSyncDb => 'Synchronisierungsdatenbank löschen';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Synchronisierungsdatenbank löschen';

  @override
  String get maintenancePopulateSequenceLog => 'Sync-Sequenzprotokoll befüllen';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count Einträge indexiert';
  }

  @override
  String get maintenancePopulateSequenceLogConfirm => 'JA, BEFÜLLEN';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Bestehende Einträge für Nachfüllunterstützung indexieren';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'Dies scannt alle Journaleinträge und fügt sie dem Sync-Sequenzprotokoll hinzu. Dies ermöglicht Nachfüllantworten für Einträge, die vor dieser Funktion erstellt wurden.';

  @override
  String get maintenancePurgeDeleted => 'Gelöschte Elemente löschen';

  @override
  String get maintenancePurgeDeletedConfirm => 'Ja, alle löschen';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Alle gelöschten Einträge endgültig entfernen';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Möchtest du wirklich alle gelöschten Einträge endgültig entfernen? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get maintenanceRecreateFts5 => 'Volltextindex neu erstellen';

  @override
  String get maintenanceRecreateFts5Confirm => 'JA, INDEX NEU ERSTELLEN';

  @override
  String get maintenanceRecreateFts5Description =>
      'Volltextsuchindex neu erstellen';

  @override
  String get maintenanceRecreateFts5Message =>
      'Möchtest du den Volltextindex wirklich neu erstellen? Dies kann einige Zeit dauern.';

  @override
  String get maintenanceReSync => 'Nachrichten erneut synchronisieren';

  @override
  String get maintenanceReSyncDescription =>
      'Nachrichten vom Server erneut synchronisieren';

  @override
  String get maintenanceSyncDefinitions =>
      'Tags, Messgrößen, Dashboards, Gewohnheiten, Kategorien, AI-Einstellungen synchronisieren';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Tags, Messgrößen, Dashboards, Gewohnheiten, Kategorien und AI-Einstellungen synchronisieren';

  @override
  String get manageLinks => 'Verknüpfungen verwalten...';

  @override
  String get matrixStatsError => 'Fehler beim Laden der Matrix-Statistiken';

  @override
  String get measurableDeleteConfirm => 'JA, DIESE MESSGRÖSSE LÖSCHEN';

  @override
  String get measurableDeleteQuestion =>
      'Möchtest du diesen Messgrößen-Datentyp löschen?';

  @override
  String get measurableNotFound => 'Messgröße nicht gefunden';

  @override
  String get modalityAudioDescription => 'Audio-Verarbeitungsfähigkeiten';

  @override
  String get modalityAudioName => 'Audio';

  @override
  String get modalityImageDescription => 'Bild-Verarbeitungsfähigkeiten';

  @override
  String get modalityImageName => 'Bild';

  @override
  String get modalityTextDescription => 'Textbasierte Inhalte und Verarbeitung';

  @override
  String get modalityTextName => 'Text';

  @override
  String get modelAddPageTitle => 'Modell hinzufügen';

  @override
  String get modelEditLoadError =>
      'Modellkonfiguration konnte nicht geladen werden';

  @override
  String get modelEditPageTitle => 'Modell bearbeiten';

  @override
  String modelManagementSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'e',
      one: '',
    );
    return '$count Modell$_temp0 ausgewählt';
  }

  @override
  String get modelsSettingsPageTitle => 'AI-Modelle';

  @override
  String get multiSelectAddButton => 'Hinzufügen';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Hinzufügen ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'Keine Einträge gefunden';

  @override
  String get navTabTitleCalendar => 'DailyOS';

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
  String nestedAiResponsesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'en',
      one: '',
    );
    return '$count KI-Antwort$_temp0';
  }

  @override
  String get noDefaultLanguage => 'Keine Standardsprache';

  @override
  String get noPromptsAvailable => 'Keine Prompts verfügbar';

  @override
  String get noPromptsForType => 'Keine Prompts für diesen Typ verfügbar';

  @override
  String get noTasksFound => 'Keine Aufgaben gefunden';

  @override
  String get noTasksToLink => 'Keine Aufgaben zum Verknüpfen verfügbar';

  @override
  String get outboxMonitorAttachmentLabel => 'Anhang';

  @override
  String get outboxMonitorDelete => 'Löschen';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Löschen';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      'Möchtest du dieses Sync-Element wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get outboxMonitorDeleteFailed =>
      'Löschen fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get outboxMonitorDeleteSuccess => 'Element gelöscht';

  @override
  String get outboxMonitorEmptyDescription =>
      'In dieser Ansicht befinden sich keine Sync-Elemente.';

  @override
  String get outboxMonitorEmptyTitle => 'Postausgang ist leer';

  @override
  String get outboxMonitorLabelAll => 'alle';

  @override
  String get outboxMonitorLabelError => 'Fehler';

  @override
  String get outboxMonitorLabelPending => 'ausstehend';

  @override
  String get outboxMonitorLabelSent => 'gesendet';

  @override
  String get outboxMonitorLabelSuccess => 'Erfolgreich';

  @override
  String get outboxMonitorNoAttachment => 'kein Anhang';

  @override
  String get outboxMonitorRetries => 'Wiederholungen';

  @override
  String get outboxMonitorRetriesLabel => 'Wiederholungen';

  @override
  String get outboxMonitorRetry => 'wiederholen';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Jetzt wiederholen';

  @override
  String get outboxMonitorRetryConfirmMessage =>
      'Dieses Sync-Element jetzt erneut versuchen?';

  @override
  String get outboxMonitorRetryFailed =>
      'Wiederholung fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get outboxMonitorRetryQueued => 'Wiederholung geplant';

  @override
  String get outboxMonitorSubjectLabel => 'Betreff';

  @override
  String get outboxMonitorSwitchLabel => 'aktiviert';

  @override
  String get privateLabel => 'Privat';

  @override
  String get promptAddOrRemoveModelsButton =>
      'Modelle hinzufügen oder entfernen';

  @override
  String get promptAddPageTitle => 'Prompt hinzufügen';

  @override
  String get promptAiResponseTypeDescription => 'Format der erwarteten Antwort';

  @override
  String get promptAiResponseTypeLabel => 'AI-Antworttyp';

  @override
  String get promptBehaviorDescription =>
      'Konfiguriere, wie der Prompt verarbeitet und antwortet';

  @override
  String get promptBehaviorTitle => 'Prompt-Verhalten';

  @override
  String get promptCancelButton => 'Abbrechen';

  @override
  String get promptContentDescription =>
      'System- und Benutzer-Prompts definieren';

  @override
  String get promptContentTitle => 'Prompt-Inhalt';

  @override
  String get promptDefaultModelBadge => 'Standard';

  @override
  String get promptDescriptionHint => 'Diesen Prompt beschreiben';

  @override
  String get promptDescriptionLabel => 'Beschreibung';

  @override
  String get promptDetailsDescription => 'Grundinformationen zu diesem Prompt';

  @override
  String get promptDetailsTitle => 'Prompt-Details';

  @override
  String get promptDisplayNameHint => 'Einen Anzeigenamen eingeben';

  @override
  String get promptDisplayNameLabel => 'Anzeigename';

  @override
  String get promptEditLoadError => 'Prompt konnte nicht geladen werden';

  @override
  String get promptEditPageTitle => 'Prompt bearbeiten';

  @override
  String get promptErrorLoadingModel => 'Fehler beim Laden des Modells';

  @override
  String get promptGenerationCardTitle => 'KI-Coding-Prompt';

  @override
  String get promptGenerationCopiedSnackbar =>
      'Prompt in Zwischenablage kopiert';

  @override
  String get promptGenerationCopyButton => 'Prompt kopieren';

  @override
  String get promptGenerationCopyTooltip => 'Prompt in Zwischenablage kopieren';

  @override
  String get promptGenerationExpandTooltip => 'Vollständigen Prompt anzeigen';

  @override
  String get promptGenerationFullPromptLabel => 'Vollständiger Prompt:';

  @override
  String get promptGoBackButton => 'Zurück';

  @override
  String get promptLoadingModel => 'Modell wird geladen...';

  @override
  String get promptModelSelectionDescription =>
      'Kompatible Modelle für diesen Prompt auswählen';

  @override
  String get promptModelSelectionTitle => 'Modellauswahl';

  @override
  String get promptNoModelsSelectedError =>
      'Keine Modelle ausgewählt. Wähle mindestens ein Modell aus.';

  @override
  String get promptReasoningModeDescription =>
      'Für Prompts aktivieren, die tiefes Nachdenken erfordern';

  @override
  String get promptReasoningModeLabel => 'Schlussfolgerungsmodus';

  @override
  String get promptRequiredInputDataDescription =>
      'Art der Daten, die dieser Prompt erwartet';

  @override
  String get promptRequiredInputDataLabel => 'Erforderliche Eingabedaten';

  @override
  String get promptSaveButton => 'Prompt speichern';

  @override
  String get promptSelectInputTypeHint => 'Eingabetyp auswählen';

  @override
  String get promptSelectionModalTitle => 'Vorkonfigurierten Prompt auswählen';

  @override
  String get promptSelectModelsButton => 'Modelle auswählen';

  @override
  String get promptSelectResponseTypeHint => 'Antworttyp auswählen';

  @override
  String get promptSetDefaultButton => 'Als Standard festlegen';

  @override
  String get promptSettingsPageTitle => 'AI-Prompts';

  @override
  String get promptSystemPromptHint => 'System-Prompt eingeben...';

  @override
  String get promptSystemPromptLabel => 'System-Prompt';

  @override
  String get promptTryAgainMessage =>
      'Bitte versuche es erneut oder kontaktiere den Support';

  @override
  String get promptUsePreconfiguredButton =>
      'Vorkonfigurierten Prompt verwenden';

  @override
  String get promptUserPromptHint => 'Benutzer-Prompt eingeben...';

  @override
  String get promptUserPromptLabel => 'Benutzer-Prompt';

  @override
  String get provisionedSyncConfigureButton => 'Konfigurieren';

  @override
  String get provisionedSyncCopiedToClipboard =>
      'In die Zwischenablage kopiert';

  @override
  String get provisionedSyncDisconnect => 'Trennen';

  @override
  String get provisionedSyncDone => 'Synchronisierung erfolgreich konfiguriert';

  @override
  String get provisionedSyncError => 'Konfiguration fehlgeschlagen';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'Bei der Konfiguration ist ein Fehler aufgetreten. Bitte versuche es erneut.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'Anmeldung fehlgeschlagen. Bitte überprüfe deine Zugangsdaten und versuche es erneut.';

  @override
  String get provisionedSyncImportButton => 'Importieren';

  @override
  String get provisionedSyncImportHint => 'Bereitstellungscode hier einfügen';

  @override
  String get provisionedSyncImportTitle => 'Sync-Konfiguration importieren';

  @override
  String get provisionedSyncInvalidBundle => 'Ungültiger Bereitstellungscode';

  @override
  String get provisionedSyncJoiningRoom => 'Sync-Raum beitreten...';

  @override
  String get provisionedSyncLoggingIn => 'Anmeldung läuft...';

  @override
  String get provisionedSyncReady =>
      'Scanne diesen QR-Code auf deinem Mobilgerät';

  @override
  String get provisionedSyncRetry => 'Erneut versuchen';

  @override
  String get provisionedSyncRotatingPassword => 'Konto wird gesichert...';

  @override
  String get provisionedSyncScanButton => 'QR-Code scannen';

  @override
  String get provisionedSyncShowQr => 'QR-Code anzeigen';

  @override
  String get provisionedSyncSubtitle =>
      'Synchronisierung aus einem Bereitstellungspaket einrichten';

  @override
  String get provisionedSyncSummaryHomeserver => 'Homeserver';

  @override
  String get provisionedSyncSummaryRoom => 'Raum';

  @override
  String get provisionedSyncSummaryUser => 'Benutzer';

  @override
  String get provisionedSyncTitle => 'Provisionierte Synchronisierung';

  @override
  String get provisionedSyncVerifyDevicesTitle => 'Geräteverifizierung';

  @override
  String get referenceImageContinue => 'Weiter';

  @override
  String referenceImageContinueWithCount(int count) {
    return 'Weiter ($count)';
  }

  @override
  String get referenceImageLoadError =>
      'Bilder konnten nicht geladen werden. Bitte versuche es erneut.';

  @override
  String get referenceImageSelectionSubtitle =>
      'Wähle bis zu 3 Bilder, um den visuellen Stil der KI zu leiten';

  @override
  String get referenceImageSelectionTitle => 'Referenzbilder auswählen';

  @override
  String get referenceImageSkip => 'Überspringen';

  @override
  String get saveButton => 'Speichern';

  @override
  String get saveButtonLabel => 'Speichern';

  @override
  String get saveLabel => 'Speichern';

  @override
  String get saveSuccessful => 'Erfolgreich gespeichert';

  @override
  String get searchHint => 'Suchen...';

  @override
  String get searchTasksHint => 'Aufgaben suchen...';

  @override
  String get selectAllowedPrompts =>
      'Auswählen, welche Prompts für diese Kategorie erlaubt sind';

  @override
  String get selectButton => 'Auswählen';

  @override
  String get selectColor => 'Farbe auswählen';

  @override
  String get selectLanguage => 'Sprache auswählen';

  @override
  String get sessionRatingCardLabel => 'Sitzungsbewertung';

  @override
  String get sessionRatingChallengeJustRight => 'Genau richtig';

  @override
  String get sessionRatingChallengeTooEasy => 'Zu einfach';

  @override
  String get sessionRatingChallengeTooHard => 'Zu herausfordernd';

  @override
  String get sessionRatingDifficultyLabel => 'Diese Arbeit fühlte sich an...';

  @override
  String get sessionRatingEditButton => 'Bewertung bearbeiten';

  @override
  String get sessionRatingEnergyQuestion =>
      'Wie energiegeladen hast du dich gefühlt?';

  @override
  String get sessionRatingFocusQuestion => 'Wie fokussiert warst du?';

  @override
  String get sessionRatingNoteHint => 'Kurze Notiz (optional)';

  @override
  String get sessionRatingProductivityQuestion =>
      'Wie produktiv war diese Sitzung?';

  @override
  String get sessionRatingRateAction => 'Sitzung bewerten';

  @override
  String get sessionRatingSaveButton => 'Speichern';

  @override
  String get sessionRatingSaveError =>
      'Bewertung konnte nicht gespeichert werden. Bitte versuche es erneut.';

  @override
  String get sessionRatingSkipButton => 'Überspringen';

  @override
  String get sessionRatingTitle => 'Sitzung bewerten';

  @override
  String get sessionRatingViewAction => 'Bewertung anzeigen';

  @override
  String get settingsAboutAppInformation => 'App-Informationen';

  @override
  String get settingsAboutAppTagline => 'Dein persönliches Tagebuch';

  @override
  String get settingsAboutBuildType => 'Build-Typ';

  @override
  String get settingsAboutBuiltWithFlutter =>
      'Entwickelt mit Flutter und Liebe für persönliches Journaling.';

  @override
  String get settingsAboutCredits => 'Credits';

  @override
  String get settingsAboutJournalEntries => 'Tagebucheinträge';

  @override
  String get settingsAboutPlatform => 'Plattform';

  @override
  String get settingsAboutThankYou => 'Vielen Dank, dass du Lotti nutzt!';

  @override
  String get settingsAboutTitle => 'Über Lotti';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutYourData => 'Deine Daten';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'Erfahre mehr über die Lotti-Anwendung';

  @override
  String get settingsAdvancedConflictsSubtitle =>
      'Synchronisierungskonflikte lösen, um Datenkonsistenz zu gewährleisten';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Gesundheitsbezogene Daten aus externen Quellen importieren';

  @override
  String get settingsAdvancedLogsSubtitle =>
      'Auf Anwendungsprotokolle zugreifen und überprüfen für Debugging';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Wartungsaufgaben durchführen, um die Anwendungsleistung zu optimieren';

  @override
  String get settingsAdvancedMatrixSyncSubtitle =>
      'Matrix-Synchronisierungseinstellungen konfigurieren und verwalten';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Elemente anzeigen und verwalten, die auf Synchronisierung warten';

  @override
  String get settingsAdvancedTitle => 'Erweiterte Einstellungen';

  @override
  String get settingsAiApiKeys => 'AI-Inferenz-Anbieter';

  @override
  String get settingsAiModels => 'AI-Modelle';

  @override
  String get settingsCategoriesAddTooltip => 'Kategorie hinzufügen';

  @override
  String get settingsCategoriesDetailsLabel => 'Kategoriedetails';

  @override
  String get settingsCategoriesDuplicateError => 'Kategorie existiert bereits';

  @override
  String get settingsCategoriesEmptyState => 'Keine Kategorien gefunden';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Erstelle eine Kategorie, um deine Einträge zu organisieren';

  @override
  String get settingsCategoriesErrorLoading =>
      'Fehler beim Laden der Kategorien';

  @override
  String get settingsCategoriesHasAiSettings => 'AI-Einstellungen';

  @override
  String get settingsCategoriesHasAutomaticPrompts => 'Automatische AI';

  @override
  String get settingsCategoriesHasDefaultLanguage => 'Standardsprache';

  @override
  String get settingsCategoriesNameLabel => 'Kategoriename:';

  @override
  String get settingsCategoriesTitle => 'Kategorien';

  @override
  String get settingsConflictsResolutionTitle =>
      'Lösung von Synchronisierungskonflikten';

  @override
  String get settingsConflictsTitle => 'Synchronisierungskonflikte';

  @override
  String get settingsDashboardDetailsLabel => 'Dashboard-Details';

  @override
  String get settingsDashboardSaveLabel => 'Speichern';

  @override
  String get settingsDashboardsTitle => 'Dashboards';

  @override
  String get settingsFlagsTitle => 'Konfigurationsflags';

  @override
  String get settingsHabitsDeleteTooltip => 'Gewohnheit löschen';

  @override
  String get settingsHabitsDescriptionLabel => 'Beschreibung (optional):';

  @override
  String get settingsHabitsDetailsLabel => 'Gewohnheitsdetails';

  @override
  String get settingsHabitsNameLabel => 'Name der Gewohnheit:';

  @override
  String get settingsHabitsPrivateLabel => 'Privat: ';

  @override
  String get settingsHabitsSaveLabel => 'Speichern';

  @override
  String get settingsHabitsTitle => 'Gewohnheiten';

  @override
  String get settingsHealthImportFromDate => 'Start';

  @override
  String get settingsHealthImportTitle => 'Gesundheitsdatenimport';

  @override
  String get settingsHealthImportToDate => 'Ende';

  @override
  String get settingsLabelsActionsTooltip => 'Label-Aktionen';

  @override
  String get settingsLabelsCategoriesAdd => 'Kategorie hinzufügen';

  @override
  String get settingsLabelsCategoriesHeading => 'Anwendbare Kategorien';

  @override
  String get settingsLabelsCategoriesNone => 'Gilt für alle Kategorien';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Entfernen';

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
      'Private Labels erscheinen nur, wenn \"Private Einträge anzeigen\" aktiviert ist.';

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
      other: '$count Aufgaben',
      one: '1 Aufgabe',
    );
    return 'Bei $_temp0 verwendet';
  }

  @override
  String get settingsLogsTitle => 'Protokolle';

  @override
  String get settingsMaintenanceTitle => 'Wartung';

  @override
  String get settingsMatrixAccept => 'Akzeptieren';

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
  String get settingsMatrixCount => 'Anzahl';

  @override
  String get settingsMatrixDeleteLabel => 'Löschen';

  @override
  String get settingsMatrixDiagnosticCopied =>
      'Diagnoseinfos in die Zwischenablage kopiert';

  @override
  String get settingsMatrixDiagnosticCopyButton => 'In Zwischenablage kopieren';

  @override
  String get settingsMatrixDiagnosticDialogTitle => 'Sync-Diagnoseinfos';

  @override
  String get settingsMatrixDiagnosticShowButton => 'Diagnoseinfos anzeigen';

  @override
  String get settingsMatrixDone => 'Fertig';

  @override
  String get settingsMatrixEnterValidUrl => 'Bitte gib eine gültige URL ein';

  @override
  String get settingsMatrixHomeserverConfigTitle =>
      'Matrix-Homeserver-Einrichtung';

  @override
  String get settingsMatrixHomeServerLabel => 'Homeserver';

  @override
  String get settingsMatrixLastUpdated => 'Zuletzt aktualisiert:';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Nicht verifizierte Geräte';

  @override
  String get settingsMatrixLoginButtonLabel => 'Anmelden';

  @override
  String get settingsMatrixLoginFailed => 'Anmeldung fehlgeschlagen';

  @override
  String get settingsMatrixLogoutButtonLabel => 'Abmelden';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Matrix-Wartungsaufgaben und Wiederherstellungstools ausführen';

  @override
  String get settingsMatrixMaintenanceTitle => 'Wartung';

  @override
  String get settingsMatrixMessageType => 'Nachrichtentyp';

  @override
  String get settingsMatrixMetric => 'Metrik';

  @override
  String get settingsMatrixMetrics => 'Sync-Metriken';

  @override
  String get settingsMatrixMetricsNoData => 'Sync-Metriken: keine Daten';

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
  String get settingsMatrixRefresh => 'Aktualisieren';

  @override
  String get settingsMatrixRoomConfigTitle =>
      'Matrix-Synchronisierungsraum-Einrichtung';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Einladung zu Raum $roomId von $senderId. Akzeptieren?';
  }

  @override
  String get settingsMatrixRoomInviteTitle => 'Raumeinladung';

  @override
  String get settingsMatrixSentMessagesLabel => 'Gesendete Nachrichten:';

  @override
  String get settingsMatrixStartVerificationLabel => 'Verifizierung starten';

  @override
  String get settingsMatrixStatsTitle => 'Matrix-Statistiken';

  @override
  String get settingsMatrixSubtitle =>
      'Ende-zu-Ende verschlüsselte Synchronisation konfigurieren';

  @override
  String get settingsMatrixTitle => 'Matrix-Synchronisierungseinstellungen';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Nicht verifizierte Geräte';

  @override
  String get settingsMatrixUserLabel => 'Benutzer';

  @override
  String get settingsMatrixUserNameTooShort => 'Benutzername zu kurz';

  @override
  String get settingsMatrixValue => 'Wert';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Auf anderem Gerät abgebrochen...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Verstanden';

  @override
  String settingsMatrixVerificationSuccessLabel(
      String deviceName, String deviceID) {
    return 'Du hast $deviceName ($deviceID) erfolgreich verifiziert';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Bestätige auf dem anderen Gerät, dass die unten stehenden Emojis auf beiden Geräten in der gleichen Reihenfolge angezeigt werden:';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Bestätige, dass die unten stehenden Emojis auf beiden Geräten in der gleichen Reihenfolge angezeigt werden:';

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
  String get settingsMeasurableDetailsLabel => 'Details zur Messgröße';

  @override
  String get settingsMeasurableFavoriteLabel => 'Favorit: ';

  @override
  String get settingsMeasurableNameLabel => 'Name der Messgröße:';

  @override
  String get settingsMeasurablePrivateLabel => 'Privat: ';

  @override
  String get settingsMeasurableSaveLabel => 'Speichern';

  @override
  String get settingsMeasurablesTitle => 'Messgrößen';

  @override
  String get settingsMeasurableUnitLabel => 'Einheitenabkürzung (optional):';

  @override
  String get settingsResetGeminiConfirm => 'Zurücksetzen';

  @override
  String get settingsResetGeminiConfirmQuestion =>
      'Der Gemini-Einrichtungsdialog wird erneut angezeigt. Fortfahren?';

  @override
  String get settingsResetGeminiSubtitle =>
      'Den Gemini AI-Einrichtungsdialog erneut anzeigen';

  @override
  String get settingsResetGeminiTitle =>
      'Gemini-Einrichtungsdialog zurücksetzen';

  @override
  String get settingsResetHintsConfirm => 'Bestätigen';

  @override
  String get settingsResetHintsConfirmQuestion =>
      'In-App-Hinweise in der gesamten App zurücksetzen?';

  @override
  String settingsResetHintsResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Hinweise zurückgesetzt',
      one: 'Einen Hinweis zurückgesetzt',
      zero: 'Keine Hinweise zurückgesetzt',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetHintsSubtitle =>
      'Einmalige Tipps und Einführungshinweise löschen';

  @override
  String get settingsResetHintsTitle => 'In-App-Hinweise zurücksetzen';

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
  String get settingsSyncStatsSubtitle => 'Sync-Pipeline-Metriken überprüfen';

  @override
  String get settingsSyncSubtitle =>
      'Synchronisierung konfigurieren und Statistiken anzeigen';

  @override
  String get settingsTagsDeleteTooltip => 'Tag löschen';

  @override
  String get settingsTagsDetailsLabel => 'Tag-Details';

  @override
  String get settingsTagsHideLabel => 'In Vorschlägen ausblenden:';

  @override
  String get settingsTagsPrivateLabel => 'Privat:';

  @override
  String get settingsTagsSaveLabel => 'Speichern';

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
  String get settingsThemingTitle => 'Farbschema';

  @override
  String get settingThemingDark => 'Dunkles Design';

  @override
  String get settingThemingLight => 'Helles Design';

  @override
  String get showCompleted => 'Abgeschlossene anzeigen';

  @override
  String get speechDictionaryHelper =>
      'Durch Semikolon getrennte Begriffe (max. 50 Zeichen) für bessere Spracherkennung';

  @override
  String get speechDictionaryHint => 'macOS; Kirkjubæjarklaustur; Claude Code';

  @override
  String get speechDictionaryLabel => 'Sprachwörterbuch';

  @override
  String get speechDictionarySectionDescription =>
      'Begriffe hinzufügen, die von der Spracherkennung oft falsch geschrieben werden (Namen, Orte, Fachbegriffe)';

  @override
  String get speechDictionarySectionTitle => 'Spracherkennung';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Großes Wörterbuch ($count Begriffe) kann API-Kosten erhöhen';
  }

  @override
  String get speechModalAddTranscription => 'Transkription hinzufügen';

  @override
  String get speechModalSelectLanguage => 'Sprache auswählen';

  @override
  String get speechModalTitle => 'Spracherkennung';

  @override
  String get speechModalTranscriptionProgress => 'Transkriptionsfortschritt';

  @override
  String get syncCreateNewRoom => 'Neuen Raum erstellen';

  @override
  String get syncCreateNewRoomInstead => 'Stattdessen neuen Raum erstellen';

  @override
  String get syncDeleteConfigConfirm => 'JA, ICH BIN SICHER';

  @override
  String get syncDeleteConfigQuestion =>
      'Möchtest du die Synchronisierungskonfiguration löschen?';

  @override
  String get syncDiscoveringRooms => 'Sync-Räume werden gesucht...';

  @override
  String get syncDiscoverRoomsButton => 'Bestehende Räume entdecken';

  @override
  String get syncDiscoveryError => 'Räume konnten nicht gefunden werden';

  @override
  String get syncEntitiesConfirm => 'SYNC STARTEN';

  @override
  String get syncEntitiesMessage =>
      'Wähle die Daten, die du synchronisieren möchtest.';

  @override
  String get syncEntitiesSuccessDescription =>
      'Alles ist auf dem neuesten Stand.';

  @override
  String get syncEntitiesSuccessTitle => 'Synchronisierung abgeschlossen';

  @override
  String get syncInviteErrorForbidden =>
      'Zugriff verweigert. Du hast möglicherweise keine Berechtigung, diesen Benutzer einzuladen.';

  @override
  String get syncInviteErrorNetwork =>
      'Netzwerkfehler. Bitte überprüfe deine Verbindung und versuche es erneut.';

  @override
  String get syncInviteErrorRateLimited =>
      'Zu viele Anfragen. Bitte warte einen Moment und versuche es erneut.';

  @override
  String get syncInviteErrorUnknown =>
      'Einladung konnte nicht gesendet werden. Bitte versuche es später erneut.';

  @override
  String get syncInviteErrorUserNotFound =>
      'Benutzer nicht gefunden. Bitte überprüfe den gescannten Code.';

  @override
  String syncListCountSummary(String label, int itemCount) {
    String _temp0 = intl.Intl.pluralLogic(
      itemCount,
      locale: localeName,
      other: '$itemCount Elemente',
      one: '1 Element',
      zero: '0 Elemente',
    );
    return '$label · $_temp0';
  }

  @override
  String get syncListPayloadKindLabel => 'Payload';

  @override
  String get syncListUnknownPayload => 'Unbekannter Payload';

  @override
  String get syncNoRoomsFound =>
      'Keine bestehenden Sync-Räume gefunden.\nDu kannst einen neuen Raum erstellen, um mit der Synchronisierung zu beginnen.';

  @override
  String get syncNotLoggedInToast => 'Sync ist nicht angemeldet';

  @override
  String get syncPayloadAiConfig => 'AI-Konfiguration';

  @override
  String get syncPayloadAiConfigDelete => 'AI-Konfiguration löschen';

  @override
  String get syncPayloadBackfillRequest => 'Nachfüllanfrage';

  @override
  String get syncPayloadBackfillResponse => 'Nachfüllantwort';

  @override
  String get syncPayloadEntityDefinition => 'Entitätsdefinition';

  @override
  String get syncPayloadEntryLink => 'Eintragsverknüpfung';

  @override
  String get syncPayloadJournalEntity => 'Journaleintrag';

  @override
  String get syncPayloadTagEntity => 'Tag-Entität';

  @override
  String get syncPayloadThemingSelection => 'Designauswahl';

  @override
  String get syncRetry => 'Erneut versuchen';

  @override
  String get syncRoomCreatedUnknown => 'Unbekannt';

  @override
  String get syncRoomDiscoveryTitle => 'Bestehenden Sync-Raum finden';

  @override
  String get syncRoomHasContent => 'Hat Inhalt';

  @override
  String get syncRoomUnnamed => 'Unbenannter Raum';

  @override
  String get syncRoomVerified => 'Verifiziert';

  @override
  String get syncSelectRoom => 'Sync-Raum auswählen';

  @override
  String get syncSelectRoomDescription =>
      'Wir haben bestehende Sync-Räume gefunden. Wähle einen zum Beitreten oder erstelle einen neuen Raum.';

  @override
  String get syncSkip => 'Überspringen';

  @override
  String get syncStepAiSettings => 'KI-Einstellungen';

  @override
  String get syncStepCategories => 'Kategorien';

  @override
  String get syncStepComplete => 'Abgeschlossen';

  @override
  String get syncStepDashboards => 'Dashboards';

  @override
  String get syncStepHabits => 'Gewohnheiten';

  @override
  String get syncStepLabels => 'Labels';

  @override
  String get syncStepMeasurables => 'Messgrößen';

  @override
  String get syncStepTags => 'Tags';

  @override
  String get taskCategoryAllLabel => 'Alle';

  @override
  String get taskCategoryLabel => 'Kategorie:';

  @override
  String get taskCategoryUnassignedLabel => 'Nicht zugewiesen';

  @override
  String get taskDueDateLabel => 'Fälligkeitsdatum';

  @override
  String taskDueDateWithDate(String date) {
    return 'Fällig: $date';
  }

  @override
  String taskDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tagen',
      one: 'einem Tag',
    );
    return 'Fällig in $_temp0';
  }

  @override
  String get taskDueToday => 'Heute fällig';

  @override
  String get taskDueTomorrow => 'Morgen fällig';

  @override
  String get taskDueYesterday => 'Gestern fällig';

  @override
  String get taskEstimateLabel => 'Schätzung:';

  @override
  String get taskLabelUnassignedLabel => 'nicht zugewiesen';

  @override
  String get taskLanguageArabic => 'Arabisch';

  @override
  String get taskLanguageBengali => 'Bengalisch';

  @override
  String get taskLanguageBulgarian => 'Bulgarisch';

  @override
  String get taskLanguageChinese => 'Chinesisch';

  @override
  String get taskLanguageCroatian => 'Kroatisch';

  @override
  String get taskLanguageCzech => 'Tschechisch';

  @override
  String get taskLanguageDanish => 'Dänisch';

  @override
  String get taskLanguageDutch => 'Niederländisch';

  @override
  String get taskLanguageEnglish => 'Englisch';

  @override
  String get taskLanguageEstonian => 'Estnisch';

  @override
  String get taskLanguageFinnish => 'Finnisch';

  @override
  String get taskLanguageFrench => 'Französisch';

  @override
  String get taskLanguageGerman => 'Deutsch';

  @override
  String get taskLanguageGreek => 'Griechisch';

  @override
  String get taskLanguageHebrew => 'Hebräisch';

  @override
  String get taskLanguageHindi => 'Hindi';

  @override
  String get taskLanguageHungarian => 'Ungarisch';

  @override
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageIndonesian => 'Indonesisch';

  @override
  String get taskLanguageItalian => 'Italienisch';

  @override
  String get taskLanguageJapanese => 'Japanisch';

  @override
  String get taskLanguageKorean => 'Koreanisch';

  @override
  String get taskLanguageLabel => 'Sprache:';

  @override
  String get taskLanguageLatvian => 'Lettisch';

  @override
  String get taskLanguageLithuanian => 'Litauisch';

  @override
  String get taskLanguageNigerianPidgin => 'Nigerianisches Pidgin';

  @override
  String get taskLanguageNorwegian => 'Norwegisch';

  @override
  String get taskLanguagePolish => 'Polnisch';

  @override
  String get taskLanguagePortuguese => 'Portugiesisch';

  @override
  String get taskLanguageRomanian => 'Rumänisch';

  @override
  String get taskLanguageRussian => 'Russisch';

  @override
  String get taskLanguageSearchPlaceholder => 'Sprachen durchsuchen...';

  @override
  String get taskLanguageSelectedLabel => 'Aktuell ausgewählt';

  @override
  String get taskLanguageSerbian => 'Serbisch';

  @override
  String get taskLanguageSlovak => 'Slowakisch';

  @override
  String get taskLanguageSlovenian => 'Slowenisch';

  @override
  String get taskLanguageSpanish => 'Spanisch';

  @override
  String get taskLanguageSwahili => 'Swahili';

  @override
  String get taskLanguageSwedish => 'Schwedisch';

  @override
  String get taskLanguageThai => 'Thailändisch';

  @override
  String get taskLanguageTurkish => 'Türkisch';

  @override
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageUkrainian => 'Ukrainisch';

  @override
  String get taskLanguageVietnamese => 'Vietnamesisch';

  @override
  String get taskLanguageYoruba => 'Yoruba';

  @override
  String get taskNameHint => 'Gib einen Namen für die Aufgabe ein';

  @override
  String get taskNoDueDateLabel => 'Kein Fälligkeitsdatum';

  @override
  String get taskNoEstimateLabel => 'Keine Schätzung';

  @override
  String taskOverdueByDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage',
      one: '1 Tag',
    );
    return '$_temp0 überfällig';
  }

  @override
  String get tasksAddLabelButton => 'Label hinzufügen';

  @override
  String get tasksFilterTitle => 'Aufgabenfilter';

  @override
  String get tasksLabelFilterAll => 'Alle';

  @override
  String get tasksLabelFilterTitle => 'Labels';

  @override
  String get tasksLabelFilterUnlabeled => 'Ohne Label';

  @override
  String get tasksLabelsDialogClose => 'Schließen';

  @override
  String get tasksLabelsHeaderEditTooltip => 'Labels bearbeiten';

  @override
  String get tasksLabelsHeaderTitle => 'Labels';

  @override
  String get tasksLabelsNoLabels => 'Keine Labels';

  @override
  String get tasksLabelsSheetApply => 'Anwenden';

  @override
  String get tasksLabelsSheetSearchHint => 'Labels suchen…';

  @override
  String get tasksLabelsSheetTitle => 'Labels auswählen';

  @override
  String get tasksLabelsUpdateFailed =>
      'Labels konnten nicht aktualisiert werden';

  @override
  String get tasksPriorityFilterAll => 'Alle';

  @override
  String get tasksPriorityFilterTitle => 'Priorität';

  @override
  String get tasksPriorityP0 => 'Dringend';

  @override
  String get tasksPriorityP0Description => 'Dringend (ASAP)';

  @override
  String get tasksPriorityP1 => 'Hoch';

  @override
  String get tasksPriorityP1Description => 'Hoch (Bald)';

  @override
  String get tasksPriorityP2 => 'Mittel';

  @override
  String get tasksPriorityP2Description => 'Mittel (Standard)';

  @override
  String get tasksPriorityP3 => 'Niedrig';

  @override
  String get tasksPriorityP3Description => 'Niedrig (Irgendwann)';

  @override
  String get tasksPriorityPickerTitle => 'Priorität auswählen';

  @override
  String get tasksPriorityTitle => 'Priorität:';

  @override
  String get tasksQuickFilterClear => 'Zurücksetzen';

  @override
  String get tasksQuickFilterLabelsActiveTitle => 'Aktive Label-Filter';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Nicht zugewiesen';

  @override
  String get tasksShowCoverArt => 'Titelbild auf Karten anzeigen';

  @override
  String get tasksShowCreationDate => 'Erstellungsdatum auf Karten anzeigen';

  @override
  String get tasksShowDueDate => 'Fälligkeitsdatum auf Karten anzeigen';

  @override
  String get tasksSortByCreationDate => 'Erstellt';

  @override
  String get tasksSortByDate => 'Datum';

  @override
  String get tasksSortByDueDate => 'Fälligkeit';

  @override
  String get tasksSortByLabel => 'Sortieren nach';

  @override
  String get tasksSortByPriority => 'Priorität';

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
  String get taskSummaries => 'Aufgabenzusammenfassungen';

  @override
  String get timeByCategoryChartTitle => 'Zeit nach Kategorie';

  @override
  String get timeByCategoryChartTotalLabel => 'Gesamt';

  @override
  String get unlinkButton => 'Verknüpfung aufheben';

  @override
  String get unlinkTaskConfirm =>
      'Bist du sicher, dass du die Verknüpfung zu dieser Aufgabe aufheben möchtest?';

  @override
  String get unlinkTaskTitle => 'Verknüpfung aufheben';

  @override
  String get viewMenuTitle => 'Ansicht';

  @override
  String get whatsNewDoneButton => 'Fertig';

  @override
  String get whatsNewSkipButton => 'Überspringen';
}

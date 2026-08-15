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
  String get addActionAddEvent => 'Termin hinzufügen';

  @override
  String get addActionAddEventHint => 'Erstellt einen Termin und öffnet ihn.';

  @override
  String get addActionAddImageFromClipboard => 'Bild einfügen';

  @override
  String get addActionAddImageFromClipboardHint =>
      'Hängt das Bild aus deiner Zwischenablage an.';

  @override
  String get addActionAddScreenshot => 'Bildschirmfoto aufnehmen';

  @override
  String get addActionAddScreenshotHint =>
      'Schließt dieses Menü und nimmt dann den Bildschirm auf.';

  @override
  String get addActionAddTask => 'Aufgabe';

  @override
  String get addActionAddTimer => 'Timer';

  @override
  String get addActionAddTimeRecording => 'Zeiteingabe';

  @override
  String get addActionCreateLinkedTask => 'Neue Aufgabe verknüpfen';

  @override
  String get addActionCreateLinkedTaskHint =>
      'Erstellt eine neue, mit dieser verknüpfte Aufgabe und öffnet sie.';

  @override
  String get addActionCreateTask => 'Aufgabe hinzufügen';

  @override
  String get addActionCreateTaskHint =>
      'Erstellt eine neue Aufgabe und öffnet sie.';

  @override
  String get addActionImportImage => 'Bild importieren';

  @override
  String get addActionImportImageHint =>
      'Öffnet deine Galerie oder Dateiauswahl.';

  @override
  String get addActionStartTimer => 'Timer starten';

  @override
  String get addActionStartTimerHint => 'Beginnt sofort mit der Zeiterfassung.';

  @override
  String get addHabitCommentLabel => 'Kommentar';

  @override
  String get addHabitDateLabel => 'Abgeschlossen um';

  @override
  String get addLinkedEntryLabel => 'Verknüpften Eintrag hinzufügen';

  @override
  String get addMeasurementCommentLabel => 'Kommentar';

  @override
  String get addMeasurementDateLabel => 'Erfasst um';

  @override
  String get addMeasurementSaveButton => 'Speichern';

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
  String agentABComparisonChoose(String option) {
    return 'Wähle $option';
  }

  @override
  String agentABComparisonOption(String option) {
    return 'Option $option';
  }

  @override
  String agentABComparisonPrefer(String option) {
    return 'Ich bevorzuge Option $option';
  }

  @override
  String get agentBinaryChoiceNo => 'Nein';

  @override
  String get agentBinaryChoiceYes => 'Ja';

  @override
  String get agentCategoryRatingsScaleMax => 'Zuerst beheben';

  @override
  String get agentCategoryRatingsScaleMin => 'So lassen';

  @override
  String agentCategoryRatingsStarLabel(int starIndex, int totalStars) {
    return '$starIndex von $totalStars Sternen';
  }

  @override
  String get agentCategoryRatingsSubmit => 'Diese Prioritäten nutzen';

  @override
  String get agentCategoryRatingsSubtitle =>
      'Wie wichtig ist es, dass ich das jeweils behebe? 1 heißt: so lassen. 5 heißt: als Erstes beheben.';

  @override
  String get agentCategoryRatingsTitle => 'Hilf mir beim Priorisieren';

  @override
  String agentControlsActionError(String error) {
    return 'Aktion fehlgeschlagen: $error';
  }

  @override
  String get agentControlsDeleteButton => 'Endgültig löschen';

  @override
  String get agentControlsDeleteDialogContent =>
      'Alle Daten dieses Agenten werden dauerhaft gelöscht, einschließlich Verlauf, Berichte und Beobachtungen. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get agentControlsDeleteDialogTitle => 'Agent löschen?';

  @override
  String get agentControlsDestroyButton => 'Zerstören';

  @override
  String get agentControlsDestroyDialogContent =>
      'Der Agent wird dauerhaft deaktiviert. Sein Verlauf wird zur Nachverfolgung aufbewahrt.';

  @override
  String get agentControlsDestroyDialogTitle => 'Agent zerstören?';

  @override
  String get agentControlsDestroyedMessage => 'Dieser Agent wurde zerstört.';

  @override
  String get agentControlsPauseButton => 'Pausieren';

  @override
  String get agentControlsReanalyzeButton => 'Erneut analysieren';

  @override
  String get agentControlsResumeButton => 'Fortsetzen';

  @override
  String get agentConversationEmpty => 'Noch keine Konversationen.';

  @override
  String agentConversationThreadSummary(
    int messageCount,
    int toolCallCount,
    String shortId,
  ) {
    return '$messageCount Nachrichten, $toolCallCount Tool-Aufrufe · $shortId';
  }

  @override
  String agentConversationTokenCount(String tokenCount) {
    return '$tokenCount Tokens';
  }

  @override
  String get agentDefaultProfileLabel => 'Standard-Inferenzprofil';

  @override
  String agentDetailErrorLoading(String error) {
    return 'Fehler beim Laden des Agenten: $error';
  }

  @override
  String get agentDetailNotFound => 'Agent nicht gefunden.';

  @override
  String get agentDetailUnexpectedType => 'Unerwarteter Entitätstyp.';

  @override
  String get agentEvolutionApprovalRate => 'Genehmigungsrate';

  @override
  String get agentEvolutionChartMttrTrend => 'MTTR-Trend';

  @override
  String get agentEvolutionChartSuccessRateTrend => 'Erfolgstrend';

  @override
  String get agentEvolutionChartVersionPerformance => 'Nach Version';

  @override
  String get agentEvolutionChartWakeHistory => 'Aufwachverlauf';

  @override
  String get agentEvolutionChatPlaceholder =>
      'Feedback teilen oder nach Leistung fragen...';

  @override
  String get agentEvolutionCurrentDirectives => 'Aktuelle Anweisungen';

  @override
  String get agentEvolutionHistoryTitle => 'Evolutionsverlauf';

  @override
  String get agentEvolutionMetricActive => 'Aktiv';

  @override
  String get agentEvolutionMetricAvgDuration => 'Durchschn. Dauer';

  @override
  String get agentEvolutionMetricFailures => 'Fehler';

  @override
  String get agentEvolutionMetricSuccess => 'Erfolg';

  @override
  String get agentEvolutionMetricWakes => 'Aufrufe';

  @override
  String get agentEvolutionNoSessions => 'Noch keine Evolutionssitzungen';

  @override
  String get agentEvolutionNoteRecorded => 'Notiz aufgezeichnet';

  @override
  String get agentEvolutionProposalApprovalFailed =>
      'Genehmigung fehlgeschlagen — bitte versuche es erneut';

  @override
  String get agentEvolutionProposalRationale => 'Begründung';

  @override
  String get agentEvolutionProposalRejected =>
      'Vorschlag abgelehnt — Gespräch fortsetzen';

  @override
  String get agentEvolutionProposalTitle => 'Vorgeschlagene Änderungen';

  @override
  String get agentEvolutionProposedDirectives => 'Vorgeschlagene Anweisungen';

  @override
  String get agentEvolutionSessionAbandoned =>
      'Sitzung ohne Änderungen beendet';

  @override
  String agentEvolutionSessionCompleted(int version) {
    return 'Sitzung abgeschlossen — Version $version erstellt';
  }

  @override
  String get agentEvolutionSessionCount => 'Sitzungen';

  @override
  String get agentEvolutionSessionError =>
      'Evolution-Sitzung konnte nicht gestartet werden';

  @override
  String agentEvolutionSessionProgress(int sessionNumber, int totalSessions) {
    return 'Sitzung $sessionNumber von $totalSessions';
  }

  @override
  String get agentEvolutionSessionStarting =>
      'Evolution-Sitzung wird gestartet...';

  @override
  String agentEvolutionSessionTitle(int sessionNumber) {
    return 'Entwicklung #$sessionNumber';
  }

  @override
  String agentEvolutionSoulCurrentField(String field) {
    return 'Aktuell — $field';
  }

  @override
  String agentEvolutionSoulProposedField(String field) {
    return 'Vorgeschlagen — $field';
  }

  @override
  String get agentEvolutionStatusAbandoned => 'Abgebrochen';

  @override
  String get agentEvolutionStatusActive => 'Aktiv';

  @override
  String get agentEvolutionStatusCompleted => 'Abgeschlossen';

  @override
  String get agentEvolutionTimelineFeedbackLabel => 'Feedback';

  @override
  String get agentEvolutionVersionProposed => 'Version vorgeschlagen';

  @override
  String get agentFeedbackCategoryAccuracy => 'Genauigkeit';

  @override
  String get agentFeedbackCategoryBreakdownTitle => 'Kategorieaufschlüsselung';

  @override
  String get agentFeedbackCategoryCommunication => 'Kommunikation';

  @override
  String get agentFeedbackCategoryGeneral => 'Allgemein';

  @override
  String get agentFeedbackCategoryPrioritization => 'Priorisierung';

  @override
  String get agentFeedbackCategoryTimeliness => 'Zeitnähe';

  @override
  String get agentFeedbackCategoryTooling => 'Werkzeuge';

  @override
  String get agentFeedbackClassificationTitle => 'Feedback-Klassifizierung';

  @override
  String get agentFeedbackExcellenceTitle => 'Herausragendes';

  @override
  String get agentFeedbackGrievancesTitle => 'Beschwerden';

  @override
  String get agentFeedbackHighPriorityTitle => 'Hochprioritäres Feedback';

  @override
  String agentFeedbackItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0';
  }

  @override
  String get agentFeedbackSourceDecision => 'Entscheidung';

  @override
  String get agentFeedbackSourceMetric => 'Metrik';

  @override
  String get agentFeedbackSourceObservation => 'Beobachtung';

  @override
  String get agentFeedbackSourceRating => 'Bewertung';

  @override
  String get agentInstancesEmptyFiltered =>
      'Keine Instanzen passen zu deinen Filtern.';

  @override
  String get agentInstancesFilterClearAll => 'Alles löschen';

  @override
  String get agentInstancesFilterClearSection => 'Löschen';

  @override
  String get agentInstancesFilterSectionSoul => 'Seele';

  @override
  String get agentInstancesFilterSectionStatus => 'Status';

  @override
  String get agentInstancesFilterSectionType => 'Typ';

  @override
  String agentInstancesGroupActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktiv',
      one: '1 aktiv',
    );
    return '$_temp0';
  }

  @override
  String get agentInstancesGroupBySoul => 'Seele';

  @override
  String get agentInstancesGroupByStatus => 'Status';

  @override
  String get agentInstancesGroupByType => 'Typ';

  @override
  String get agentInstancesKindEvolution => 'Entwicklung';

  @override
  String get agentInstancesKindTaskAgent => 'Aufgaben-Agent';

  @override
  String get agentInstancesPageTitle => 'Agenten-Instanzen';

  @override
  String agentInstancesResultCountAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Instanzen',
      one: '1 Instanz',
    );
    return '$_temp0';
  }

  @override
  String agentInstancesResultCountFiltered(int filtered, int total) {
    return '$filtered von $total';
  }

  @override
  String get agentInstancesSearchClear => 'Suche löschen';

  @override
  String get agentInstancesSearchPlaceholder => 'Instanzen suchen…';

  @override
  String get agentInstancesSortName => 'Name';

  @override
  String get agentInstancesSortOldest => 'Älteste';

  @override
  String get agentInstancesSortRecent => 'Neueste';

  @override
  String get agentInstancesTitle => 'Instanzen';

  @override
  String get agentInstancesToolbarFilters => 'Filter';

  @override
  String get agentInstancesToolbarGroupBy => 'Gruppieren nach';

  @override
  String get agentInstancesUnassignedSoul => 'Nicht zugewiesen';

  @override
  String get agentLifecycleActive => 'Aktiv';

  @override
  String get agentLifecycleCreated => 'Erstellt';

  @override
  String get agentLifecycleDestroyed => 'Zerstört';

  @override
  String get agentLifecycleDormant => 'Ruhend';

  @override
  String get agentMessageKindAction => 'Aktion';

  @override
  String get agentMessageKindMilestone => 'Meilenstein';

  @override
  String get agentMessageKindObservation => 'Beobachtung';

  @override
  String get agentMessageKindRetraction => 'Zurücknahme';

  @override
  String get agentMessageKindSummary => 'Zusammenfassung';

  @override
  String get agentMessageKindSystem => 'System';

  @override
  String get agentMessageKindSystemPrompt => 'System-Prompt';

  @override
  String get agentMessageKindThought => 'Gedanke';

  @override
  String get agentMessageKindToolResult => 'Werkzeugergebnis';

  @override
  String get agentMessageKindUser => 'Benutzer';

  @override
  String get agentMessagePayloadEmpty => '(kein Inhalt)';

  @override
  String get agentMessagesEmpty => 'Noch keine Nachrichten.';

  @override
  String agentMessagesErrorLoading(String error) {
    return 'Nachrichten konnten nicht geladen werden: $error';
  }

  @override
  String get agentObservationsEmpty =>
      'Noch keine Beobachtungen aufgezeichnet.';

  @override
  String get agentPendingWakesDeleteTooltip => 'Weckvorgang entfernen';

  @override
  String get agentPendingWakesEmptyFiltered =>
      'Keine Weckvorgänge passen zu deinen Filtern.';

  @override
  String get agentPendingWakesFilterSectionType => 'Typ';

  @override
  String get agentPendingWakesGroupByType => 'Typ';

  @override
  String get agentPendingWakesPendingLabel => 'Ausstehend';

  @override
  String agentPendingWakesRunningHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Läuft jetzt ($count)',
      one: 'Läuft jetzt',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesScheduledLabel => 'Geplant';

  @override
  String get agentPendingWakesSearchPlaceholder => 'Weckvorgänge suchen…';

  @override
  String get agentPendingWakesSortDueLatest => 'Fällig zuletzt';

  @override
  String get agentPendingWakesSortDueSoonest => 'Fällig zuerst';

  @override
  String get agentPendingWakesTitle => 'Weckzyklen';

  @override
  String get agentReportHistoryBadge => 'Bericht';

  @override
  String get agentReportHistoryEmpty => 'Noch keine Berichts-Snapshots.';

  @override
  String get agentReportHistoryError =>
      'Fehler beim Laden der Berichtshistorie.';

  @override
  String get agentReportNone => 'Noch kein Bericht verfügbar.';

  @override
  String get agentRitualContinueAction => 'Einzelgespräch fortsetzen';

  @override
  String get agentRitualOpeningHint =>
      'Liest, was seit eurem letzten Gespräch passiert ist …';

  @override
  String get agentRitualReviewAction => 'Einzelgespräch starten';

  @override
  String get agentRitualReviewNegativeSignals => 'Negativ';

  @override
  String get agentRitualReviewNeutralSignals => 'Neutral';

  @override
  String get agentRitualReviewNoFeedback =>
      'Keine Feedback-Signale in diesem Zeitfenster';

  @override
  String get agentRitualReviewNoNegativeSignals =>
      'Keine negativen Feedback-Signale in diesem Tab';

  @override
  String get agentRitualReviewNoNeutralSignals =>
      'Keine neutralen Feedback-Signale in diesem Tab';

  @override
  String get agentRitualReviewNoPositiveSignals =>
      'Keine positiven Feedback-Signale in diesem Tab';

  @override
  String get agentRitualReviewPositiveSignals => 'Positiv';

  @override
  String get agentRitualReviewProposalSection => 'Aktueller Vorschlag';

  @override
  String get agentRitualReviewSessionHistory => 'Frühere Einzelgespräche';

  @override
  String get agentRitualReviewTitle => 'Einzelgespräch';

  @override
  String get agentRitualSinceLastHeading => 'Seit unserem letzten Gespräch';

  @override
  String get agentRitualStartHeading => 'Einzelgespräch starten';

  @override
  String get agentRitualSummaryApprovedChangesHeading =>
      'Bestätigte Änderungen';

  @override
  String get agentRitualSummaryConversationHeading => 'Gespräch';

  @override
  String get agentRitualSummaryRecapHeading => 'Sitzungszusammenfassung';

  @override
  String get agentRitualSummaryRoleAssistant => 'Agent';

  @override
  String get agentRitualSummaryRoleUser => 'Du';

  @override
  String get agentRitualSummaryStartHint =>
      'Geh durch, was dich gestört hat, was gut lief und was sich als Nächstes ändern sollte.';

  @override
  String get agentRitualSummaryTokensSinceLast =>
      'Token seit dem letzten Einzelgespräch';

  @override
  String get agentRitualSummaryWakeHistory30Days =>
      'Aufwachaktivität (letzte 30 Tage)';

  @override
  String get agentRitualSummaryWakesSinceLast =>
      'Aufwachvorgänge seit dem letzten Einzelgespräch';

  @override
  String get agentRitualTypingSemantics => 'Der Agent formuliert eine Antwort';

  @override
  String agentRitualWakesSinceLastCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufwachvorgänge seit eurem letzten Einzelgespräch',
      one: '1 Aufwachvorgang seit eurem letzten Einzelgespräch',
    );
    return '$_temp0';
  }

  @override
  String get agentRunningIndicator => 'Läuft';

  @override
  String get agentsCreateGoal => 'Neuer Ziel-Agent';

  @override
  String get agentSessionProgressTitle => 'Sitzungsfortschritt';

  @override
  String get agentSettingsSubtitle => 'Vorlagen, Instanzen und Überwachung';

  @override
  String get agentSettingsTitle => 'Agenten';

  @override
  String get agentSoulAntiSycophancyLabel => 'Anti-Speichelleckerei-Richtlinie';

  @override
  String get agentSoulAssignedTemplatesTitle => 'Zugewiesene Vorlagen';

  @override
  String get agentSoulAssignmentLabel => 'Seele';

  @override
  String get agentSoulCoachingStyleLabel => 'Coaching-Stil';

  @override
  String get agentSoulCreatedSuccess => 'Seele erstellt';

  @override
  String get agentSoulCreateTitle => 'Seele erstellen';

  @override
  String get agentSoulDeleteConfirmBody =>
      'Das entfernt die Seele und alle ihre Versionen.';

  @override
  String get agentSoulDeleteConfirmTitle => 'Seele löschen';

  @override
  String get agentSoulDetailTitle => 'Seelen-Details';

  @override
  String get agentSoulDisplayNameLabel => 'Name';

  @override
  String get agentSoulEvolutionHistoryTitle => 'Seelen-Evolutionsverlauf';

  @override
  String get agentSoulEvolutionNoSessions =>
      'Noch keine Seelen-Evolutionssitzungen';

  @override
  String get agentSoulFieldAntiSycophancy => 'Anti-Schmeichelei';

  @override
  String get agentSoulFieldCoachingStyle => 'Coaching-Stil';

  @override
  String get agentSoulFieldToneBounds => 'Tonale Grenzen';

  @override
  String get agentSoulFieldVoice => 'Stimme';

  @override
  String get agentSoulInfoTab => 'Info';

  @override
  String get agentSoulNoneAssigned => 'Keine Seele zugewiesen';

  @override
  String get agentSoulNotFound => 'Seele nicht gefunden';

  @override
  String get agentSoulProposalSubtitle =>
      'Vorgeschlagene Persönlichkeitsänderungen';

  @override
  String get agentSoulProposalTitle => 'Seelen-Persönlichkeitsvorschlag';

  @override
  String get agentSoulReviewStartAction => 'Persönlichkeitsüberprüfung starten';

  @override
  String get agentSoulReviewStartHint =>
      'Starte eine persönlichkeitsfokussierte Sitzung, um Feedback durchzugehen und Stimme, Ton, Coaching-Stil und Direktheit weiterzuentwickeln.';

  @override
  String agentSoulReviewTemplateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Vorlagen teilen diese Seele',
      one: '1 Vorlage teilt diese Seele',
    );
    return '$_temp0';
  }

  @override
  String get agentSoulReviewTitle => 'Seelen-Einzelgespräch';

  @override
  String get agentSoulRollbackAction => 'Auf diese Version zurücksetzen';

  @override
  String agentSoulRollbackConfirm(int version) {
    return 'Auf Version $version zurücksetzen? Alle Vorlagen, die diese Seele verwenden, werden die Änderung übernehmen.';
  }

  @override
  String get agentSoulSelectTitle => 'Seele auswählen';

  @override
  String get agentSoulsEmptyFiltered =>
      'Keine Seelen passen zu deinen Filtern.';

  @override
  String get agentSoulSettingsTab => 'Einstellungen';

  @override
  String get agentSoulsSearchPlaceholder => 'Seelen suchen…';

  @override
  String get agentSoulsTitle => 'Seelen';

  @override
  String get agentSoulToneBoundsLabel => 'Tonfall-Grenzen';

  @override
  String get agentSoulVersionHistoryTitle => 'Versionsverlauf';

  @override
  String agentSoulVersionLabel(int version) {
    return 'Version $version';
  }

  @override
  String get agentSoulVersionSaved => 'Neue Seelenversion gespeichert';

  @override
  String get agentSoulVoiceDirectiveLabel => 'Stimm-Direktive';

  @override
  String get agentsPageEmpty =>
      'Noch keine Ziel-Agenten. Erstelle einen und er behält deinen Fortschritt im Blick.';

  @override
  String get agentsPageLoadFailed =>
      'Deine Agenten konnten gerade nicht geladen werden.';

  @override
  String get agentsPageTitle => 'Ziel-Agenten';

  @override
  String get agentStateConsecutiveFailures => 'Aufeinanderfolgende Fehler';

  @override
  String agentStateErrorLoading(String error) {
    return 'Status konnte nicht geladen werden: $error';
  }

  @override
  String get agentStateHeading => 'Statusinformationen';

  @override
  String get agentStateLastWake => 'Letztes Aufwachen';

  @override
  String get agentStateNextWake => 'Nächstes Aufwachen';

  @override
  String get agentStateRevision => 'Überarbeitung';

  @override
  String get agentStateSleepingUntil => 'Schlafend bis';

  @override
  String get agentStateWakeCount => 'Aufwachzähler';

  @override
  String get agentSuggestionTimeEntryUpdateCurrent => 'Aktuell';

  @override
  String get agentSuggestionTimeEntryUpdateNoChange => '(unverändert)';

  @override
  String get agentSuggestionTimeEntryUpdateProposed => 'Vorgeschlagen';

  @override
  String get agentSuggestionTimeEntryUpdateUnavailable =>
      'Ursprünglicher Eintrag nicht verfügbar';

  @override
  String agentSummaryAddItem(Object title) {
    return 'Hinzufügen: „$title“';
  }

  @override
  String agentSummaryArchiveItem(Object title) {
    return 'Archivieren: „$title“';
  }

  @override
  String agentSummaryCheckItem(Object title) {
    return 'Abhaken: „$title“';
  }

  @override
  String agentSummaryCreateFollowUp(Object title) {
    return 'Folgeaufgabe erstellen: „$title“';
  }

  @override
  String agentSummaryCreateFollowUpRelated(Object title, Object relation) {
    return 'Folgeaufgabe erstellen: „$title“ — $relation';
  }

  @override
  String agentSummaryCreateTask(Object title) {
    return 'Aufgabe erstellen: $title';
  }

  @override
  String agentSummaryFollowUpTask(Object title) {
    return 'Folgeaufgabe: $title';
  }

  @override
  String agentSummaryGoalRevisionCadence(String value) {
    return 'Häufigkeit auf $value ändern';
  }

  @override
  String agentSummaryGoalRevisionPeriod(String value) {
    return 'Zeitraum auf $value ändern';
  }

  @override
  String agentSummaryGoalRevisionScope(String value) {
    return 'gilt für $value';
  }

  @override
  String agentSummaryGoalRevisionTarget(String value) {
    return 'Zielwert auf $value ändern';
  }

  @override
  String agentSummaryMigrateItem(Object title) {
    return 'In die Folgeaufgabe verschieben: „$title“';
  }

  @override
  String get agentSummaryRecommendNextSteps => 'Nächste Schritte vorschlagen';

  @override
  String agentSummaryRecommendNextStepsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nächste Schritte vorschlagen',
      one: '1 nächsten Schritt vorschlagen',
    );
    return '$_temp0';
  }

  @override
  String agentSummaryRestoreItem(Object title) {
    return 'Wiederherstellen: „$title“';
  }

  @override
  String agentSummaryReviseTimeEntryText(Object summary) {
    return 'Text des Zeiteintrags überarbeiten: „$summary“';
  }

  @override
  String agentSummarySetDueDate(Object date) {
    return 'Fälligkeitsdatum auf $date setzen';
  }

  @override
  String agentSummarySetEstimate(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Schätzung auf $minutes Minuten setzen',
      one: 'Schätzung auf 1 Minute setzen',
    );
    return '$_temp0';
  }

  @override
  String agentSummarySetLanguage(Object language) {
    return 'Sprache auf „$language“ setzen';
  }

  @override
  String agentSummarySetPriority(Object priority) {
    return 'Priorität auf $priority setzen';
  }

  @override
  String agentSummarySetStatus(Object status) {
    return 'Status auf $status setzen';
  }

  @override
  String agentSummarySetTitle(Object title) {
    return 'Titel auf „$title“ setzen';
  }

  @override
  String get agentSummarySuggestFollowUpTask => 'Eine Folgeaufgabe vorschlagen';

  @override
  String agentSummaryTimeEntry(Object range, Object summary) {
    return 'Zeiteintrag $range: „$summary“';
  }

  @override
  String agentSummaryTimeRangeBetween(Object start, Object end) {
    return '$start–$end';
  }

  @override
  String agentSummaryTimeRangeFrom(Object start) {
    return 'ab $start';
  }

  @override
  String agentSummaryTimeRangeUntil(Object end) {
    return 'bis $end';
  }

  @override
  String agentSummaryUncheckItem(Object title) {
    return 'Häkchen entfernen: „$title“';
  }

  @override
  String agentSummaryUpdateItem(Object title) {
    return 'Ändern: „$title“';
  }

  @override
  String agentSummaryUpdateProjectStatus(Object status) {
    return 'Projektstatus auf $status setzen';
  }

  @override
  String agentSummaryUpdateRunningTimer(Object summary) {
    return 'Text der laufenden Zeitmessung ändern: „$summary“';
  }

  @override
  String get agentSummaryUpdateTimeEntry => 'Zeiteintrag aktualisieren';

  @override
  String agentSummaryUpdateTimeEntryRange(Object range) {
    return 'Zeiteintrag $range aktualisieren';
  }

  @override
  String agentSummaryUpdateTimeEntryRangeText(Object range, Object summary) {
    return 'Zeiteintrag $range aktualisieren: „$summary“';
  }

  @override
  String get agentTabActivity => 'Aktivität';

  @override
  String get agentTabConversations => 'Konversationen';

  @override
  String get agentTabObservations => 'Beobachtungen';

  @override
  String get agentTabReports => 'Berichte';

  @override
  String get agentTabStats => 'Statistik';

  @override
  String get agentTemplateAggregateTokenUsageHeading =>
      'Token-Verbrauch (gesamt)';

  @override
  String get agentTemplateAssignedLabel => 'Vorlage';

  @override
  String get agentTemplateCreatedSuccess => 'Vorlage erstellt';

  @override
  String get agentTemplateCreateTitle => 'Vorlage erstellen';

  @override
  String get agentTemplateDeleteConfirm =>
      'Diese Vorlage löschen? Das kann nicht rückgängig gemacht werden.';

  @override
  String get agentTemplateDeleteHasInstances =>
      'Kann nicht gelöscht werden: Aktive Agenten verwenden diese Vorlage.';

  @override
  String get agentTemplateDisplayNameLabel => 'Name';

  @override
  String get agentTemplateEditTitle => 'Vorlage bearbeiten';

  @override
  String get agentTemplateEvolutionTab => 'Evolution';

  @override
  String get agentTemplateEvolveApprove => 'Genehmigen & Speichern';

  @override
  String get agentTemplateEvolveReject => 'Ablehnen';

  @override
  String get agentTemplateGeneralDirectiveHint =>
      'Definiere die Persönlichkeit, Tools, Ziele und den Interaktionsstil des Agenten...';

  @override
  String get agentTemplateGeneralDirectiveLabel => 'Allgemeine Anweisung';

  @override
  String get agentTemplateInstanceBreakdownHeading =>
      'Aufschlüsselung nach Instanz';

  @override
  String agentTemplateInstanceLastActive(String date) {
    return 'Zuletzt aufgewacht: $date';
  }

  @override
  String get agentTemplateInstanceNeverActive => 'Nie aufgewacht';

  @override
  String get agentTemplateInstanceOpenTask => 'Aufgabe öffnen';

  @override
  String get agentTemplateInstancesEmpty => 'Noch keine Instanzen.';

  @override
  String get agentTemplateInstancesHeading => 'Instanzen';

  @override
  String agentTemplateInstanceStarted(String date) {
    return 'Gestartet am $date';
  }

  @override
  String get agentTemplateKindDayAgent => 'Tages-Agent';

  @override
  String get agentTemplateKindEventAgent => 'Ereignis-Agent';

  @override
  String get agentTemplateKindImprover => 'Vorlagen-Verbesserer';

  @override
  String get agentTemplateKindProjectAgent => 'Projekt-Agent';

  @override
  String get agentTemplateKindTaskAgent => 'Aufgaben-Agent';

  @override
  String get agentTemplateMetricsTotalWakes => 'Aktivierungen gesamt';

  @override
  String get agentTemplateNoneAssigned => 'Keine Vorlage zugewiesen';

  @override
  String get agentTemplateNoTemplates =>
      'Keine Vorlagen verfügbar. Erstelle zuerst eine in den Einstellungen.';

  @override
  String get agentTemplateNotFound => 'Vorlage nicht gefunden';

  @override
  String get agentTemplateNoVersions => 'Keine Versionen';

  @override
  String get agentTemplateReportDirectiveHint =>
      'Definiere die Berichtsstruktur, erforderliche Abschnitte und Formatierungsregeln...';

  @override
  String get agentTemplateReportDirectiveLabel => 'Berichtsanweisung';

  @override
  String get agentTemplateReportsEmpty => 'Noch keine Berichte.';

  @override
  String get agentTemplateReportsTab => 'Berichte';

  @override
  String get agentTemplateRollbackAction => 'Auf diese Version zurücksetzen';

  @override
  String agentTemplateRollbackConfirm(int version) {
    return 'Auf Version $version zurücksetzen? Der Agent wird diese Version beim nächsten Aufwachen verwenden.';
  }

  @override
  String get agentTemplateSaveNewVersion => 'Speichern';

  @override
  String get agentTemplateSelectTitle => 'Vorlage auswählen';

  @override
  String get agentTemplatesEmptyFiltered =>
      'Keine Vorlagen passen zu deinen Filtern.';

  @override
  String get agentTemplateSettingsTab => 'Einstellungen';

  @override
  String get agentTemplatesFilterSectionKind => 'Art';

  @override
  String get agentTemplatesGroupByKind => 'Art';

  @override
  String get agentTemplatesGroupNone => 'Alle';

  @override
  String get agentTemplatesSearchPlaceholder => 'Vorlagen suchen…';

  @override
  String get agentTemplateStatsTab => 'Statistiken';

  @override
  String get agentTemplateStatusActive => 'Aktiv';

  @override
  String get agentTemplateStatusArchived => 'Archiviert';

  @override
  String get agentTemplatesTitle => 'Agenten-Vorlagen';

  @override
  String get agentTemplateSwitchHint =>
      'Um eine andere Vorlage zu verwenden, lösche diesen Agenten und erstelle einen neuen.';

  @override
  String get agentTemplateVersionHistoryTitle => 'Versionshistorie';

  @override
  String agentTemplateVersionLabel(int version) {
    return 'Version $version';
  }

  @override
  String get agentTemplateVersionSaved => 'Neue Version gespeichert';

  @override
  String get agentThreadReportLabel => 'Bericht aus diesem Aufwachzyklus';

  @override
  String get agentTokenUsageCachedTokens => 'Gecacht';

  @override
  String get agentTokenUsageEmpty => 'Noch kein Token-Verbrauch aufgezeichnet.';

  @override
  String agentTokenUsageErrorLoading(String error) {
    return 'Fehler beim Laden des Token-Verbrauchs: $error';
  }

  @override
  String get agentTokenUsageHeading => 'Token-Verbrauch';

  @override
  String get agentTokenUsageInputTokens => 'Eingabe';

  @override
  String get agentTokenUsageModel => 'Modell';

  @override
  String get agentTokenUsageOutputTokens => 'Ausgabe';

  @override
  String get agentTokenUsageThoughtsTokens => 'Denken';

  @override
  String get agentTokenUsageTotalTokens => 'Gesamt';

  @override
  String get agentTokenUsageWakeCount => 'Aufwachvorgänge';

  @override
  String get agentToolGoalRevisionLabel => 'Vorschlag zur Zielanpassung';

  @override
  String get aggregationDailyAvg => 'Tagesdurchschnitt';

  @override
  String get aggregationDailyMax => 'Tagesmaximum';

  @override
  String get aggregationDailySum => 'Tagessumme';

  @override
  String get aggregationHourlySum => 'Stundensumme';

  @override
  String get aggregationNone => 'Rohwerte';

  @override
  String get aiAssistantTitle => 'Generieren…';

  @override
  String get aiAttributionArtifactOutput => 'Ausgabe';

  @override
  String get aiAttributionCompletedAt => 'Abgeschlossen am';

  @override
  String get aiAttributionCost => 'Kosten';

  @override
  String get aiAttributionCostUnknown => 'Kosten unbekannt';

  @override
  String get aiAttributionCreator => 'Erstellt von';

  @override
  String get aiAttributionDiagnostics => 'Diagnose';

  @override
  String get aiAttributionDuration => 'Dauer';

  @override
  String get aiAttributionInteractions => 'Interaktionen';

  @override
  String get aiAttributionLoading => 'KI-Zuordnung wird geladen…';

  @override
  String get aiAttributionNoInteractionDetails =>
      'Keine Interaktionsdetails verfügbar.';

  @override
  String get aiAttributionRequestEvidence => 'Anfrage-Nachweis';

  @override
  String get aiAttributionResponseEvidence => 'Antwort-Nachweis';

  @override
  String aiAttributionSecondary(String model, String time, int callCount) {
    String _temp0 = intl.Intl.pluralLogic(
      callCount,
      locale: localeName,
      other: '$callCount Aufrufe',
      one: '1 Aufruf',
      zero: 'keine Aufrufe',
    );
    return '$model · $time · $_temp0';
  }

  @override
  String get aiAttributionStartedAt => 'Gestartet am';

  @override
  String get aiAttributionStatus => 'Status';

  @override
  String get aiAttributionStatusCancelled => 'Abgebrochen';

  @override
  String get aiAttributionStatusFailed => 'Fehlgeschlagen';

  @override
  String get aiAttributionStatusPartial => 'Teilweise';

  @override
  String get aiAttributionStatusSucceeded => 'Abgeschlossen';

  @override
  String aiAttributionSummary(String actor, String trigger, String status) {
    return '$actor · $trigger · $status';
  }

  @override
  String get aiAttributionTitle => 'KI-Zuordnung';

  @override
  String aiAttributionTokenBreakdown(
    String input,
    String output,
    String cached,
    String reasoning,
  ) {
    return 'Eingabe: $input · Ausgabe: $output · Zwischengespeichert: $cached · Denken: $reasoning';
  }

  @override
  String get aiAttributionTokens => 'Tokens';

  @override
  String get aiAttributionTokenUsageUnknown => 'Token-Nutzung unbekannt';

  @override
  String get aiAttributionTrigger => 'Auslöser';

  @override
  String get aiAttributionTriggerAgent => 'Agent';

  @override
  String get aiAttributionTriggerAutomatic => 'Automatisch';

  @override
  String get aiAttributionTriggerImported => 'Importiert';

  @override
  String get aiAttributionTriggerManual => 'Manuell';

  @override
  String get aiAttributionTriggerScheduled => 'Geplant';

  @override
  String get aiAttributionTriggerSynced => 'Aus Sync';

  @override
  String get aiAttributionUnavailable => 'KI-Zuordnung ist nicht verfügbar.';

  @override
  String get aiAttributionUnknownCreator => 'Unbekannte Person';

  @override
  String get aiAttributionUnknownModel => 'Unbekanntes Modell';

  @override
  String get aiAttributionYou => 'Du';

  @override
  String get aiCapabilityChipImageGeneration => 'Bildgenerierung';

  @override
  String get aiCapabilityChipImageRecognition => 'Bilderkennung';

  @override
  String get aiCapabilityChipThinking => 'Denken';

  @override
  String get aiCapabilityChipTranscription => 'Transkription';

  @override
  String aiCardHistoryToggle(int count) {
    return 'Verlauf · $count';
  }

  @override
  String get aiCardMenuActionDelete => 'Löschen';

  @override
  String get aiCardMenuActionEdit => 'Bearbeiten';

  @override
  String get aiCardMenuTooltip => 'Weitere Aktionen';

  @override
  String get aiCardOpenAgentInternals => 'Agent-Internes öffnen';

  @override
  String get aiCardProposalConfirmed => 'Bestätigt';

  @override
  String get aiCardProposalDismissed => 'Abgelehnt';

  @override
  String get aiCardProposalKindAdd => 'Hinzufügen';

  @override
  String get aiCardProposalKindDue => 'Fällig';

  @override
  String get aiCardProposalKindEstimate => 'Schätzung';

  @override
  String get aiCardProposalKindLabel => 'Label';

  @override
  String get aiCardProposalKindPriority => 'Priorität';

  @override
  String get aiCardProposalKindRemove => 'Entfernen';

  @override
  String get aiCardProposalKindStatus => 'Status';

  @override
  String get aiCardProposalKindUpdate => 'Aktualisieren';

  @override
  String get aiCardReadMore => 'Mehr lesen';

  @override
  String get aiCardShowLess => 'Weniger anzeigen';

  @override
  String get aiCardTitle => 'KI-Zusammenfassung';

  @override
  String get aiChatAssistantResponding => 'Der Assistent antwortet';

  @override
  String get aiChatMessageCopied => 'In die Zwischenablage kopiert';

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Fehler beim Laden der Modelle. Bitte versuche es erneut.';

  @override
  String get aiConfigNoModelsAvailable =>
      'Noch keine AI-Modelle konfiguriert. Bitte füge eines in den Einstellungen hinzu.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Keine Modelle erfüllen die Anforderungen für diesen Prompt. Bitte konfiguriere Modelle mit den erforderlichen Fähigkeiten.';

  @override
  String get aiConfigSelectProviderModalTitle => 'Inferenz-Anbieter auswählen';

  @override
  String get aiConfigSelectProviderTypeModalTitle => 'Anbietertyp auswählen';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Schlussfolgerung verwenden';

  @override
  String aiConsumptionAttributionReference(String id) {
    return 'Zuordnung $id';
  }

  @override
  String aiConsumptionCallsLine(int count, int measured) {
    return 'KI-Aufrufe: $count · Impact gemessen bei $measured';
  }

  @override
  String aiConsumptionCostLine(String cost) {
    return 'Kosten: $cost';
  }

  @override
  String get aiConsumptionDurationLessThanMinute => 'Unter 1 Min.';

  @override
  String aiConsumptionDurationLine(String duration) {
    return 'Rechenzeit: $duration';
  }

  @override
  String aiConsumptionImpactLine(String energy, String carbon, String water) {
    return 'Impact: $energy · $carbon CO₂e · $water Wasser';
  }

  @override
  String aiConsumptionLedgerCap(int limit) {
    return 'Zeigt die neuesten $limit Aufrufe in diesem Zeitraum';
  }

  @override
  String get aiConsumptionLedgerTitle => 'Letzte Aufrufe';

  @override
  String get aiConsumptionMetricsNotReported => 'Nicht gemeldet';

  @override
  String aiConsumptionTokensLabel(String tokens) {
    return '$tokens Tokens';
  }

  @override
  String aiConsumptionTokensLine(String input, String output) {
    return 'Tokens: $input rein · $output raus';
  }

  @override
  String get aiConsumptionTypeAgentTurn => 'Agentendurchlauf';

  @override
  String get aiConsumptionTypeAudioTranscription => 'Transkription';

  @override
  String get aiConsumptionTypeEmbeddingIndexing => 'Embedding-Indexierung';

  @override
  String get aiConsumptionTypeImageAnalysis => 'Bildanalyse';

  @override
  String get aiConsumptionTypeImageGeneration => 'Bildgenerierung';

  @override
  String get aiConsumptionTypePromptGeneration => 'Prompt-Generierung';

  @override
  String get aiConsumptionTypeTextGeneration => 'Textgenerierung';

  @override
  String aiConsumptionWorkGroup(int callCount) {
    String _temp0 = intl.Intl.pluralLogic(
      callCount,
      locale: localeName,
      other: '$callCount Aufrufe',
      one: '1 Aufruf',
    );
    return 'KI-Arbeit · $_temp0';
  }

  @override
  String aiDeleteToastCascadeDescription(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Außerdem entfernt: $count Modelle ($names)',
      one: 'Außerdem entfernt: 1 Modell ($names)',
    );
    return '$_temp0';
  }

  @override
  String aiDeleteToastErrorTitle(String name) {
    return 'Löschen von $name fehlgeschlagen';
  }

  @override
  String get aiDeleteToastModelTitle => 'Modell gelöscht';

  @override
  String get aiDeleteToastProfileTitle => 'Profil gelöscht';

  @override
  String get aiDeleteToastPromptTitle => 'Prompt gelöscht';

  @override
  String get aiDeleteToastProviderTitle => 'Anbieter gelöscht';

  @override
  String get aiDeleteToastSkillTitle => 'Fähigkeit gelöscht';

  @override
  String get aiDeleteToastUndoAction => 'Rückgängig';

  @override
  String get aiFormCancel => 'Abbrechen';

  @override
  String get aiFormFixErrors => 'Bitte behebe die Fehler vor dem Speichern';

  @override
  String get aiFormNoChanges => 'Keine ungespeicherten Änderungen';

  @override
  String get aiImageAnalysisPickerDefaultBadge => 'Standard';

  @override
  String get aiImageAnalysisPickerTitle => 'Wähle ein Bildanalysemodell';

  @override
  String get aiImageGenerationPickerTitle => 'Wähle ein Bildgenerierungsmodell';

  @override
  String get aiImpactBreakdownBoth => 'Beide';

  @override
  String get aiImpactBreakdownCategory => 'Nach Kategorie';

  @override
  String get aiImpactBreakdownModel => 'Nach Modell';

  @override
  String get aiImpactCategoryTitle => 'Aufschlüsselung nach Kategorie';

  @override
  String get aiImpactChartHint =>
      'Tippe auf einen Balken für Aufrufe · auf eine Serie zum Isolieren';

  @override
  String get aiImpactChartShareCaption => 'Zusammensetzung über die Zeit';

  @override
  String get aiImpactChartShareSegment => 'Anteil';

  @override
  String aiImpactChartTitle(String metric) {
    return '$metric nach Kategorie';
  }

  @override
  String aiImpactChartTitleModel(String metric) {
    return '$metric nach Modell';
  }

  @override
  String get aiImpactCoverageNote =>
      'Energie, CO₂e und Kosten werden nur für Cloud-Modelle gemessen.';

  @override
  String get aiImpactEmptyBody =>
      'KI-Aufrufe aus deinen Aufgaben und Agenten erscheinen hier.';

  @override
  String get aiImpactEmptyTitle => 'Keine KI-Nutzung in diesem Zeitraum';

  @override
  String get aiImpactKpiCarbon => 'CO₂E';

  @override
  String get aiImpactKpiCost => 'KOSTEN';

  @override
  String aiImpactKpiDeltaBaseline(String period) {
    return 'ggü. $period';
  }

  @override
  String get aiImpactKpiEnergy => 'ENERGIE';

  @override
  String get aiImpactKpiRequests => 'ANFRAGEN';

  @override
  String get aiImpactKpiTokens => 'TOKENS';

  @override
  String get aiImpactLedgerClearFilter => 'Alle anzeigen';

  @override
  String get aiImpactLoadError =>
      'KI-Impact-Daten konnten nicht geladen werden';

  @override
  String get aiImpactLocationColumn => 'STANDORT';

  @override
  String get aiImpactLocationTitle => 'Impact nach Standort';

  @override
  String get aiImpactLocationUnknown => 'Unbekannt';

  @override
  String get aiImpactMetricCarbon => 'CO₂e';

  @override
  String get aiImpactMetricCost => 'Kosten';

  @override
  String get aiImpactMetricEnergy => 'Energie';

  @override
  String get aiImpactMetricRequests => 'Anfragen';

  @override
  String get aiImpactMetricTokens => 'Tokens';

  @override
  String aiImpactModelCallsLabel(String count) {
    return '$count Aufrufe';
  }

  @override
  String get aiImpactModelColumn => 'MODELL';

  @override
  String get aiImpactModelCostHeavy => 'kostenintensiv';

  @override
  String get aiImpactModelCoverageNote =>
      'Lokale Modelle sind in diesem Diagramm nicht enthalten.';

  @override
  String get aiImpactModelOther => 'Andere Modelle';

  @override
  String aiImpactModelRatePerMillion(String cost) {
    return '$cost/1 Mio. Tok.';
  }

  @override
  String get aiImpactModelTitle => 'Modellaufschlüsselung';

  @override
  String get aiImpactModelUnknown => 'Unbekanntes Modell';

  @override
  String get aiImpactRenewableColumn => 'ERNEUERBAR';

  @override
  String get aiImpactTitle => 'KI-Impact';

  @override
  String get aiInferenceErrorAuthenticationTitle =>
      'Authentifizierung fehlgeschlagen';

  @override
  String get aiInferenceErrorConnectionFailedTitle =>
      'Verbindung fehlgeschlagen';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Ungültige Anfrage';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Ratenlimit überschritten';

  @override
  String get aiInferenceErrorRetryButton => 'Erneut versuchen';

  @override
  String get aiInferenceErrorServerTitle => 'Serverfehler';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Vorschläge:';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Zeitüberschreitung';

  @override
  String get aiInferenceErrorUnknownTitle => 'Fehler';

  @override
  String get aiInternalsTitle => 'Agent-Internes';

  @override
  String get aiModelCardDeleteTooltip => 'Modell löschen';

  @override
  String get aiModelDownloadCloseButton => 'Schließen';

  @override
  String aiModelDownloadDialogDescription(String modelName) {
    return 'Lotti lädt $modelName in den MLX-Audio-Cache und nutzt es für lokale Sprachverarbeitung.';
  }

  @override
  String aiModelDownloadDialogTitle(String modelName) {
    return '$modelName installieren';
  }

  @override
  String get aiModelDownloadInstallTooltip => 'Modell installieren';

  @override
  String get aiModelDownloadOpenProgressTooltip =>
      'Download-Fortschritt anzeigen';

  @override
  String get aiModelDownloadStatusChecking => 'Modellstatus wird geprüft';

  @override
  String aiModelDownloadStatusDownloading(int percent) {
    return 'Download läuft $percent %';
  }

  @override
  String get aiModelDownloadStatusDownloadingIndeterminate => 'Download läuft';

  @override
  String get aiModelDownloadStatusFailed => 'Download fehlgeschlagen';

  @override
  String get aiModelDownloadStatusInstalled => 'Installiert';

  @override
  String get aiModelDownloadStatusNotInstalled => 'Nicht installiert';

  @override
  String get aiModelDownloadStatusUnsupported => 'Apple Silicon erforderlich';

  @override
  String get aiModelInstallChoiceCancelButton => 'Abbrechen';

  @override
  String get aiModelInstallChoiceDescription =>
      'Wähle zuerst das lokale Speech-to-Text-Modell aus, das heruntergeladen werden soll. Die anderen kannst du später über die Modellliste installieren.';

  @override
  String get aiModelInstallChoiceInstallButton => 'Modell installieren';

  @override
  String get aiModelInstallChoiceRecommended => 'Empfohlen';

  @override
  String get aiModelInstallChoiceTitle => 'MLX-Audio-Modell wählen';

  @override
  String get aiModelPickerByProviderLabel => 'Anbieter wählen';

  @override
  String get aiModelPickerCurrentDefaultLabel => 'Aktueller Standard';

  @override
  String aiModelPickerProviderModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Modelle',
      one: '1 Modell',
    );
    return '$_temp0';
  }

  @override
  String aiOllamaModelInstalledSuccessfully(String modelName) {
    return 'Modell \"$modelName\" erfolgreich installiert!';
  }

  @override
  String get aiPickProviderBadgeDesktopOnly => 'NUR DESKTOP';

  @override
  String get aiPickProviderBadgeNew => 'NEU';

  @override
  String get aiPickProviderBadgeRecommended => 'EMPFOHLEN';

  @override
  String get aiPickProviderContinueButton => 'Weiter';

  @override
  String get aiPickProviderDontShowAgainButton => 'Nicht mehr anzeigen';

  @override
  String get aiPickProviderFooterHint =>
      'Du kannst später in Einstellungen → KI weitere Anbieter hinzufügen. Dein API-Schlüssel wird lokal gespeichert.';

  @override
  String get aiPickProviderModalTitle => 'KI-Funktionen einrichten';

  @override
  String get aiPickProviderSubtitle =>
      'Wähl einen Anbieter zum Loslegen. Wir richten Modelle und ein Startprofil automatisch für dich ein.';

  @override
  String get aiProfileCardInUseBadge => 'In Benutzung';

  @override
  String get aiProfileModelPickerSearchHint => 'Modelle suchen…';

  @override
  String get aiProfileSlotModelMissing => 'fehlt';

  @override
  String get aiPromptGenerationPickerTitle =>
      'Wähle ein Modell für die Prompt-Generierung';

  @override
  String get aiProviderAlibabaName => 'Alibaba Cloud (Qwen)';

  @override
  String get aiProviderAnthropicName => 'Anthropic Claude';

  @override
  String get aiProviderCardDraftBadge => 'ENTWURF';

  @override
  String get aiProviderCardFixButton => 'Beheben';

  @override
  String aiProviderCardModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Modelle',
      one: '1 Modell',
    );
    return '$_temp0';
  }

  @override
  String aiProviderCardModelCountWithLastUsed(int count, String lastUsed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Modelle · zuletzt verwendet $lastUsed',
      one: '1 Modell · zuletzt verwendet $lastUsed',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardOllamaHint => 'Stelle sicher, dass Ollama läuft';

  @override
  String aiProviderCardStatusConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Verbunden · $count Modelle',
      one: 'Verbunden · 1 Modell',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardStatusConnectedShort => 'Verbunden';

  @override
  String get aiProviderCardStatusInvalidKey => 'Ungültiger Schlüssel';

  @override
  String get aiProviderCardStatusOffline =>
      'Offline · Stelle sicher, dass Ollama läuft';

  @override
  String get aiProviderCardStatusOfflineShort => 'Offline';

  @override
  String get aiProviderConnectBackToProviders => 'Zurück zu den Anbietern';

  @override
  String get aiProviderConnectBreadcrumbAdd => 'Anbieter hinzufügen';

  @override
  String get aiProviderConnectFieldBaseUrlHint =>
      'Leer lassen, um den offiziellen Endpunkt zu verwenden';

  @override
  String get aiProviderConnectFieldBaseUrlLabelOptional =>
      'Basis-URL (optional)';

  @override
  String get aiProviderConnectFieldBaseUrlPlaceholder =>
      'https://api.example.com';

  @override
  String get aiProviderConnectFieldDisplayNameHint =>
      'Wird in deiner Anbieterliste angezeigt';

  @override
  String get aiProviderConnectionCheckingLabel =>
      'Schlüssel wird geprüft, verfügbare Modelle werden geladen…';

  @override
  String aiProviderConnectionFailedBadResponseDetail(String type) {
    return 'Unerwartete Antwortform: $type';
  }

  @override
  String aiProviderConnectionFailedHttpDetail(int status, String message) {
    return 'HTTP $status · $message';
  }

  @override
  String get aiProviderConnectionFailedInvalidBaseUrlDetail =>
      'Die Basis-URL muss ein http(s)-Schema und einen Host enthalten (z. B. https://api.example.com)';

  @override
  String aiProviderConnectionFailedNetworkDetail(String message) {
    return '$message';
  }

  @override
  String get aiProviderConnectionFailedTimeoutDetail =>
      'Zeitüberschreitung bei der Anfrage';

  @override
  String aiProviderConnectionFailedTitle(String providerName) {
    return '$providerName ist nicht erreichbar. Prüfe den Schlüssel oder dein Netzwerk.';
  }

  @override
  String get aiProviderConnectionRetestButton => 'Erneut testen';

  @override
  String get aiProviderConnectionRetryButton => 'Erneut versuchen';

  @override
  String aiProviderConnectionVerifiedSubtitle(int count, int ms) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Modelle für dein Konto verfügbar · Antwort in $ms ms',
      one: '1 Modell für dein Konto verfügbar · Antwort in $ms ms',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderConnectionVerifiedTitle => 'Verbindung bestätigt';

  @override
  String aiProviderConnectKeyHelperLink(String url) {
    return 'Schlüssel holen auf $url';
  }

  @override
  String get aiProviderConnectKeyHiddenLabel => 'Verborgen';

  @override
  String get aiProviderConnectKeyPrivacyHint =>
      'Dein API-Schlüssel verlässt nie dein Gerät.';

  @override
  String aiProviderConnectPageTitle(String providerName) {
    return '$providerName verbinden';
  }

  @override
  String get aiProviderConnectSaveAndContinue => 'Speichern und fortfahren';

  @override
  String get aiProviderConnectSaveAsDraft => 'Als Entwurf speichern';

  @override
  String get aiProviderConnectSavedAsDraftToast => 'Als Entwurf gespeichert';

  @override
  String get aiProviderConnectStepChoose => 'Anbieter wählen';

  @override
  String get aiProviderConnectStepConnect => 'Verbinden';

  @override
  String get aiProviderConnectStepReview => 'Überprüfen';

  @override
  String get aiProviderDetailAddModelButton => 'Modell hinzufügen';

  @override
  String get aiProviderDetailApiKeyLabel => 'API-Schlüssel';

  @override
  String get aiProviderDetailBackTooltip => 'Zurück';

  @override
  String get aiProviderDetailBaseUrlLabel => 'Basis-URL';

  @override
  String get aiProviderDetailConnectionTitle => 'Verbindung';

  @override
  String get aiProviderDetailDangerZoneTitle => 'Gefahrenzone';

  @override
  String get aiProviderDetailDisplayNameLabel => 'Anzeigename';

  @override
  String get aiProviderDetailEditButton => 'Bearbeiten';

  @override
  String get aiProviderDetailEditTooltip => 'Anbieter bearbeiten';

  @override
  String get aiProviderDetailLoadError =>
      'Anbieter konnte nicht geladen werden. Versuche es erneut über die KI-Einstellungen.';

  @override
  String get aiProviderDetailMissingMessage =>
      'Dieser Anbieter ist nicht mehr verfügbar.';

  @override
  String aiProviderDetailModelsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Modelle · $count',
      one: 'Modelle · 1',
      zero: 'Modelle',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderDetailNoModelsMessage =>
      'Noch keine Modelle. Füge eines hinzu, um diesen Anbieter zu nutzen.';

  @override
  String get aiProviderDetailPageTitle => 'Anbieter-Details';

  @override
  String get aiProviderDetailProfilesUsingTitle =>
      'Profile, die diesen Anbieter nutzen';

  @override
  String get aiProviderDetailRemoveButton => 'Anbieter entfernen';

  @override
  String get aiProviderDetailRemoveDescription =>
      'Löscht den Anbieter und alle Modelle, die ihn nutzen. Das lässt sich nicht rückgängig machen.';

  @override
  String get aiProviderDetailRemoveTitle => 'Diesen Anbieter entfernen';

  @override
  String get aiProviderDetailValueUnset => 'Nicht gesetzt';

  @override
  String get aiProviderEmbeddedRuntimeHint =>
      'Läuft eingebettet im Apple-App-Prozess. Kein lokaler Server und keine Basis-URL nötig.';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiName => 'OpenAI-kompatibel';

  @override
  String get aiProviderMeliousName => 'Melious.ai';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderMlxAudioName => 'MLX Audio (lokal)';

  @override
  String get aiProviderNebiusAiStudioName => 'Nebius AI Studio';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOmlxName => 'oMLX (lokal)';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderTaglineAlibaba =>
      'Qwen-Modelle · multimodal · langer Kontext';

  @override
  String get aiProviderTaglineAnthropic => 'Claude-Familie · langer Kontext';

  @override
  String get aiProviderTaglineGemini => 'Multimodal · Audiotranskription';

  @override
  String get aiProviderTaglineMelious =>
      'EU-gehostet · dynamischer Katalog · Eco-Routing';

  @override
  String get aiProviderTaglineMlxAudio =>
      'Eingebettet · Apple Silicon · lokales Audio';

  @override
  String get aiProviderTaglineOllama => 'Läuft lokal · keine Cloud-Aufrufe';

  @override
  String get aiProviderTaglineOmlx => 'Lokale MLX-Inferenz · OpenAI-kompatibel';

  @override
  String get aiProviderTaglineOpenAi => 'GPT-Familie · Vision + Reasoning';

  @override
  String get aiProviderUnknownName => 'KI-Anbieter';

  @override
  String get aiProviderVoxtralName => 'Voxtral (lokal)';

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
  String get aiResponseShowLess => 'Weniger anzeigen';

  @override
  String get aiResponseShowMore => 'Mehr anzeigen';

  @override
  String get aiRunningActivityOpenProgress => 'KI-Fortschritt anzeigen';

  @override
  String get aiSettingsAddedLabel => 'Hinzugefügt';

  @override
  String get aiSettingsAddModelButton => 'Modell hinzufügen';

  @override
  String get aiSettingsAddModelErrorDescription =>
      'Beim Hinzufügen des Modells ist etwas schiefgelaufen. Bitte versuche es erneut.';

  @override
  String get aiSettingsAddModelErrorTitle =>
      'Modell konnte nicht hinzugefügt werden';

  @override
  String get aiSettingsAddModelTooltip =>
      'Dieses Modell zu deinem Anbieter hinzufügen';

  @override
  String get aiSettingsAddProfileButton => 'Profil hinzufügen';

  @override
  String get aiSettingsAddProviderButton => 'Anbieter hinzufügen';

  @override
  String get aiSettingsAgentWakeConcurrencyDescription =>
      'Wähle, wie viele verschiedene Agenten gleichzeitig Inferenz ausführen dürfen. Höhere Werte liefern schnellere Antworten, beanspruchen aber mehr Kapazität beim Anbieter und auf deinem Gerät.';

  @override
  String get aiSettingsAgentWakeConcurrencyLabel =>
      'Parallele Agenten-Aktivierungen';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Alle Filter zurücksetzen';

  @override
  String get aiSettingsClearFiltersButton => 'Löschen';

  @override
  String get aiSettingsCounterModels => 'Modelle';

  @override
  String get aiSettingsCounterProfiles => 'Profile';

  @override
  String get aiSettingsCounterProviders => 'Anbieter';

  @override
  String get aiSettingsEmptyDescription =>
      'Füge einen hinzu, um Transkription, Bilderkennung, Bildgenerierung und semantische Suche freizuschalten.';

  @override
  String get aiSettingsEmptyTitle => 'Noch keine Anbieter';

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
  String get aiSettingsFtueBannerDescription =>
      'Dauert etwa eine Minute. Lotti richtet Modelle und ein Startprofil für dich ein.';

  @override
  String get aiSettingsFtueBannerStartButton => 'Einrichtung starten';

  @override
  String get aiSettingsFtueBannerTitle =>
      'Füge deinen ersten KI-Anbieter hinzu';

  @override
  String get aiSettingsModalityAudio => 'Audio';

  @override
  String get aiSettingsModalityText => 'Text';

  @override
  String get aiSettingsModalityVision => 'Bild';

  @override
  String get aiSettingsNoModelsConfigured => 'Keine AI-Modelle konfiguriert';

  @override
  String get aiSettingsNoProvidersConfigured =>
      'Keine AI-Anbieter konfiguriert';

  @override
  String get aiSettingsPageLead =>
      'Richte KI-Anbieter ein, die Modelle, die Lotti nutzen kann, und die Inferenzprofile, die entscheiden, welches Modell welche Aufgabe übernimmt.';

  @override
  String get aiSettingsPageTitle => 'AI-Einstellungen';

  @override
  String get aiSettingsReasoningLabel => 'Schlussfolgerung';

  @override
  String get aiSettingsRemoveModelTooltip =>
      'Dieses Modell von deinem Anbieter entfernen';

  @override
  String get aiSettingsSearchHint =>
      'Anbieter, Modelle, Profile durchsuchen...';

  @override
  String get aiSettingsSearchHintShort => 'Suchen';

  @override
  String get aiSettingsTabModels => 'Modelle';

  @override
  String get aiSettingsTabProfiles => 'Profile';

  @override
  String get aiSettingsTabProviders => 'Anbieter';

  @override
  String get aiSetupPreviewAcceptButton => 'Übernehmen & abschließen';

  @override
  String get aiSetupPreviewAlreadyAddedSectionLabel => 'Bereits hinzugefügt';

  @override
  String aiSetupPreviewCategoryFooter(String categoryName) {
    return 'Richte Testkategorie $categoryName ein, um es auszuprobieren.';
  }

  @override
  String aiSetupPreviewConnectedHeader(String providerName) {
    return '$providerName verbunden';
  }

  @override
  String get aiSetupPreviewCustomizeButton => 'Anpassen';

  @override
  String get aiSetupPreviewLead =>
      'Sieh dir an, was Lotti hinzufügen wird. Hake ab, was du nicht möchtest — du kannst es später jederzeit manuell einrichten.';

  @override
  String get aiSetupPreviewLiveBadge => 'Live';

  @override
  String aiSetupPreviewModalTitle(String providerName) {
    return 'Einrichtung $providerName';
  }

  @override
  String get aiSetupPreviewModelsSectionLabel => 'Modelle';

  @override
  String get aiSetupPreviewProfileSectionLabel => 'Inferenzprofil';

  @override
  String get aiSetupPreviewProfileSetActiveBadge => 'Aktiv setzen';

  @override
  String aiSetupResultBulletCategoryCreated(String categoryName) {
    return 'Testkategorie $categoryName eingerichtet';
  }

  @override
  String aiSetupResultBulletCategoryReused(String categoryName) {
    return 'Vorhandene Testkategorie $categoryName wird wiederverwendet';
  }

  @override
  String aiSetupResultBulletModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Modelle eingerichtet',
      one: '1 Modell eingerichtet',
    );
    return '$_temp0';
  }

  @override
  String aiSetupResultBulletProfile(String profileName) {
    return 'Inferenzprofil $profileName erstellt';
  }

  @override
  String aiSetupResultErrorsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Probleme',
      one: '1 Problem',
    );
    return '$_temp0 bei der Einrichtung';
  }

  @override
  String aiSetupResultHeader(String providerName) {
    return '$providerName ist verbunden';
  }

  @override
  String aiSetupResultKnownModelsMissing(String providerName) {
    return 'Erforderliche Modellkonfigurationen für $providerName konnten nicht gefunden werden';
  }

  @override
  String get aiSetupResultLead =>
      'Wir haben alles für dich eingerichtet. Die KI-Funktionen stehen in deinem Journal bereit.';

  @override
  String aiSetupResultModalTitle(String providerName) {
    return '$providerName bereit';
  }

  @override
  String get aiSetupResultStartUsingButton => 'KI verwenden';

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
  String get aiSummaryPlayTooltip => 'Zusammenfassung vorlesen';

  @override
  String get aiSummaryPreparingTooltip => 'Audio wird vorbereitet';

  @override
  String get aiSummarySpeakTooltip => 'Zusammenfassung lokal vorlesen';

  @override
  String get aiSummaryStopTooltip => 'Stopp';

  @override
  String get aiSummaryThinkingLabel => 'Denkt nach …';

  @override
  String get aiSummaryTtsUnavailable => 'Sprachausgabe ist nicht verfügbar';

  @override
  String get aiTaskSummaryTitle => 'KI-Aufgabenzusammenfassung';

  @override
  String get aiTranscriptionPickerDefaultBadge => 'Standard';

  @override
  String get aiTranscriptionPickerTitle => 'Wähle ein Transkriptionsmodell';

  @override
  String get apiKeyAddPageTitle => 'Anbieter hinzufügen';

  @override
  String get apiKeyAuthenticationDescription => 'Sichere deine API-Verbindung';

  @override
  String get apiKeyAuthenticationTitle => 'Authentifizierung';

  @override
  String get apiKeyAvailableModelsDescription =>
      'Vorkonfigurierte Modelle für diesen Anbieter schnell hinzufügen';

  @override
  String get apiKeyAvailableModelsTitle => 'Verfügbare Modelle';

  @override
  String get apiKeyBaseUrlLabel => 'Basis-URL';

  @override
  String get apiKeyDisplayNameHint => 'Gib einen Anzeigenamen ein';

  @override
  String get apiKeyDisplayNameLabel => 'Anzeigename';

  @override
  String get apiKeyDynamicModelsDescription =>
      'Durchsuche den Live-Modellkatalog dieses Anbieters und füge jedes Modell hinzu';

  @override
  String get apiKeyEditGoBackButton => 'Zurück';

  @override
  String get apiKeyEditLoadError =>
      'API-Schlüssel-Konfiguration konnte nicht geladen werden';

  @override
  String get apiKeyEditLoadErrorRetry =>
      'Bitte versuche es erneut oder kontaktiere den Support';

  @override
  String get apiKeyEditPageTitle => 'Anbieter bearbeiten';

  @override
  String get apiKeyHideTooltip => 'API-Schlüssel ausblenden';

  @override
  String get apiKeyInputHint => 'Gib deinen API-Schlüssel ein';

  @override
  String get apiKeyInputLabel => 'API-Schlüssel';

  @override
  String apiKeyKnownModelInputLabel(String modalities) {
    return 'Eingabe: $modalities';
  }

  @override
  String apiKeyKnownModelOutputLabel(String modalities) {
    return 'Ausgabe: $modalities';
  }

  @override
  String get apiKeyProviderConfigDescription =>
      'Konfiguriere die Einstellungen deines KI-Inferenzanbieters';

  @override
  String get apiKeyProviderConfigTitle => 'Anbieterkonfiguration';

  @override
  String get apiKeyProviderTypeHint => 'Anbietertyp auswählen';

  @override
  String get apiKeyProviderTypeLabel => 'Anbietertyp';

  @override
  String get apiKeyShowTooltip => 'API-Schlüssel anzeigen';

  @override
  String get audioRecordingCancel => 'Abbrechen';

  @override
  String get audioRecordingDiscardDialogBody =>
      'Diese Aufnahme wird gelöscht. Es wird kein Audioeintrag, Transkript oder Aufgaben-Zusammenfassung erstellt.';

  @override
  String get audioRecordingDiscardDialogCancel => 'Weiter aufnehmen';

  @override
  String get audioRecordingDiscardDialogConfirm => 'Verwerfen';

  @override
  String get audioRecordingDiscardDialogTitle => 'Aufnahme verwerfen?';

  @override
  String get audioRecordingPause => 'Pause';

  @override
  String get audioRecordingResume => 'Fortsetzen';

  @override
  String get audioRecordings => 'Audioaufnahmen';

  @override
  String get audioRecordingStop => 'Stopp';

  @override
  String backfillAdvancedRecoveryActions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aktionen',
      one: '1 Aktion',
    );
    return '$_temp0';
  }

  @override
  String get backfillAdvancedRecoveryTitle => 'Erweiterte Wiederherstellung';

  @override
  String get backfillAgentClocksDescription =>
      'Versieh Agenten-Entitäten und Agenten-Verknüpfungen, die ohne Vektoruhr gespeichert wurden, nachträglich mit einer, damit deine anderen Geräte sie einordnen und empfangen können.';

  @override
  String get backfillAgentClocksFailed =>
      'Agenten-Vektoruhren konnten nicht repariert werden';

  @override
  String get backfillAgentClocksTitle => 'Agenten-Vektoruhren';

  @override
  String get backfillAgentClocksTrigger => 'Vektoruhren reparieren';

  @override
  String get backfillAskPeersConfirmAccept => 'Peers fragen';

  @override
  String backfillAskPeersConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Setzt alle $count unlösbaren Sequenzlog-Einträge zurück auf fehlend, damit der reguläre Backfill-Sweep Peers erneut fragt. Peers, die die Daten noch haben, antworten; wirklich nicht wiederherstellbare Einträge werden nach dem 7-Tage-Schonfenster erneut zurückgezogen.',
      one:
          'Setzt 1 unlösbaren Sequenzlog-Eintrag zurück auf fehlend, damit der reguläre Backfill-Sweep Peers erneut fragt. Peers, die die Daten noch haben, antworten; wirklich nicht wiederherstellbare Einträge werden nach dem 7-Tage-Schonfenster erneut zurückgezogen.',
    );
    return '$_temp0';
  }

  @override
  String get backfillAskPeersConfirmTitle =>
      'Peers erneut nach unlösbaren Einträgen fragen?';

  @override
  String get backfillAskPeersDescription =>
      'Setzt jeden unlösbaren Sequenzlog-Eintrag zurück auf fehlend und lässt den regulären Backfill-Sweep Peers erneut fragen.';

  @override
  String get backfillAskPeersProcessing => 'Wird wiedereröffnet…';

  @override
  String get backfillAskPeersTitle => 'Peers nach unlösbaren Einträgen fragen';

  @override
  String backfillAskPeersTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Peers nach $count Einträgen fragen',
      one: 'Peers nach 1 Eintrag fragen',
    );
    return '$_temp0';
  }

  @override
  String get backfillCatchUpDescription =>
      'Fordere fehlende Einträge der letzten Zeit jetzt von Peers an.';

  @override
  String backfillDevicesMeta(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Geräte-IDs',
      one: '1 Geräte-ID',
    );
    return '$_temp0';
  }

  @override
  String get backfillManualDescription =>
      'Alle fehlenden Einträge unabhängig vom Alter anfordern. Nutze dies zur Wiederherstellung älterer Synchronisierungslücken.';

  @override
  String get backfillManualProcessing => 'Verarbeitung...';

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
  String get backfillReRequestTitle => 'Ausstehende erneut anfordern';

  @override
  String get backfillReRequestTrigger =>
      'Ausstehende Einträge erneut anfordern';

  @override
  String get backfillResetUnresolvableDescription =>
      'Setze als unlösbar markierte Einträge auf fehlend zurück, damit sie erneut angefordert werden können. Verwende dies nach der Sequenzlog-Neubefüllung.';

  @override
  String get backfillResetUnresolvableProcessing => 'Wird zurückgesetzt...';

  @override
  String get backfillResetUnresolvableTitle => 'Unlösbare zurücksetzen';

  @override
  String get backfillResetUnresolvableTrigger =>
      'Unlösbare Einträge zurücksetzen';

  @override
  String get backfillRetireStuckConfirmAccept => 'Jetzt zurückziehen';

  @override
  String backfillRetireStuckConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Markiert $count aktuell offene (fehlende oder angeforderte) Sequenzlog-Einträge als unlösbar. Nutze dies, um den Watermark zu entsperren, wenn Einträge bereits eine Weile feststecken, ohne dass das 7-Tage-Schonfenster abgelaufen ist. Einträge können später wiederhergestellt werden, wenn ihre Nutzdaten mit gültiger Vector Clock auf der Festplatte ankommen.',
      one:
          'Markiert 1 aktuell offenen (fehlenden oder angeforderten) Sequenzlog-Eintrag als unlösbar. Nutze dies, um den Watermark zu entsperren, wenn Einträge bereits eine Weile feststecken, ohne dass das 7-Tage-Schonfenster abgelaufen ist. Einträge können später wiederhergestellt werden, wenn ihre Nutzdaten mit gültiger Vector Clock auf der Festplatte ankommen.',
    );
    return '$_temp0';
  }

  @override
  String get backfillRetireStuckConfirmTitle =>
      'Festsitzende Einträge jetzt zurückziehen?';

  @override
  String get backfillRetireStuckDescription =>
      'Setzt jeden aktuell offenen fehlenden oder angeforderten Sequenzlog-Eintrag auf unlösbar. Überspringt das 7-Tage-Schonfenster — verwende dies nur für festsitzende Einträge, die den Watermark blockieren.';

  @override
  String get backfillRetireStuckProcessing => 'Wird zurückgezogen…';

  @override
  String get backfillRetireStuckTitle => 'Festsitzende Einträge zurückziehen';

  @override
  String backfillRetireStuckTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count festsitzende Einträge zurückziehen',
      one: '1 festsitzenden Eintrag zurückziehen',
    );
    return '$_temp0';
  }

  @override
  String get backfillSettingsSubtitle => 'Synchronisierungslücken verwalten';

  @override
  String get backfillSettingsTitle => 'Sync-Nachfüllung';

  @override
  String get backfillStatsBackfilled => 'Nachgefüllt';

  @override
  String get backfillStatsBurned => 'Entwertet';

  @override
  String get backfillStatsDeleted => 'Gelöscht';

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
  String get backfillStatusInboundQueue => 'Eingangswarteschlange';

  @override
  String get backfillStatusMissing => 'Fehlend';

  @override
  String get backfillStatusSkipped => 'Übersprungen';

  @override
  String get backfillToggleDescription =>
      'Fordert fehlende Einträge der letzten 24 Stunden an.';

  @override
  String get backfillToggleTitle => 'Automatische Nachfüllung';

  @override
  String get basicSettings => 'Grundeinstellungen';

  @override
  String get calendarHasPlanLabel => 'Hat einen Plan';

  @override
  String get calendarTodayLabel => 'Heute';

  @override
  String get cancelButton => 'Abbrechen';

  @override
  String get categoryActiveDescription =>
      'Inaktive Kategorien erscheinen nicht in Auswahllisten';

  @override
  String get categoryActiveSwitchDescription => 'Für neue Einträge wählbar';

  @override
  String get categoryAiDefaultsDescription =>
      'Standard-KI-Profil und Agenten-Vorlage für neue Aufgaben in dieser Kategorie festlegen';

  @override
  String get categoryAiDefaultsTitle => 'KI-Standardwerte';

  @override
  String get categoryAutomaticAgentWakesDescription =>
      'Lass den Assistenten in dieser Kategorie sich selbst aktualisieren, wenn sich eine Aufgabe ändert. Gilt für neue Aufgaben; bestehende behalten ihre eigene Einstellung.';

  @override
  String get categoryAutomaticAgentWakesLabel =>
      'Assistent automatisch aktualisieren';

  @override
  String get categoryAutomaticInferenceDescription =>
      'Neue Audioaufnahmen und Bilder in dieser Kategorie automatisch auswerten';

  @override
  String get categoryAutomaticInferenceLabel => 'Automatische Inferenz';

  @override
  String get categoryCreationError =>
      'Kategorie konnte nicht erstellt werden. Bitte versuche es erneut.';

  @override
  String get categoryDayPlanDescription =>
      'Diese Kategorie für die Auswahl im Tagesplan verfügbar machen';

  @override
  String get categoryDayPlanLabel => 'Tagesplanung';

  @override
  String get categoryDefaultEventTemplateHint => 'Vorlage auswählen…';

  @override
  String get categoryDefaultEventTemplateLabel =>
      'Standard-Ereignis-Agenten-Vorlage';

  @override
  String get categoryDefaultLanguageDescription =>
      'Standardsprache für Aufgaben in dieser Kategorie festlegen';

  @override
  String get categoryDefaultProfileHint => 'Profil auswählen…';

  @override
  String get categoryDefaultTemplateHint => 'Vorlage auswählen…';

  @override
  String get categoryDefaultTemplateLabel => 'Standard-Agenten-Vorlage';

  @override
  String get categoryDeleteConfirm => 'Ja, diese Kategorie löschen';

  @override
  String get categoryDeleteConfirmation =>
      'Diese Aktion kann nicht rückgängig gemacht werden. Alle Einträge in dieser Kategorie bleiben erhalten, werden aber nicht mehr kategorisiert.';

  @override
  String get categoryDeleteTitle => 'Kategorie löschen?';

  @override
  String get categoryFavoriteBadgeLabel => 'Favorit';

  @override
  String get categoryFavoriteDescription =>
      'Diese Kategorie als Favorit markieren';

  @override
  String get categoryIconChooseHint => 'Symbol auswählen';

  @override
  String get categoryIconCreateHint => 'Symbol auswählen';

  @override
  String get categoryIconEditHint => 'Anderes Symbol auswählen';

  @override
  String get categoryIconLabel => 'Symbol';

  @override
  String get categoryIconPickerTitle => 'Symbol auswählen';

  @override
  String get categoryNameRequired => 'Kategoriename ist erforderlich';

  @override
  String get categoryNotFound => 'Kategorie nicht gefunden';

  @override
  String get categoryPrivateBadgeLabel => 'Privat';

  @override
  String get categoryPrivateDescription =>
      'Nur sichtbar, wenn private Einträge angezeigt werden';

  @override
  String get categorySearchPlaceholder => 'Kategorien suchen...';

  @override
  String get changeSetCardTitle => 'Vorgeschlagene Änderungen';

  @override
  String get changeSetConfirmAll => 'Alle bestätigen';

  @override
  String changeSetConfirmAllPartialIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente hatten Teilprobleme',
      one: '1 Element hatte Teilprobleme',
    );
    return '$_temp0';
  }

  @override
  String get changeSetConfirmError => 'Änderung konnte nicht angewendet werden';

  @override
  String get changeSetItemConfirmed => 'Änderung angewendet';

  @override
  String changeSetItemConfirmedWithWarning(String warning) {
    return 'Angewendet mit Warnung: $warning';
  }

  @override
  String get changeSetItemRejected => 'Änderung abgelehnt';

  @override
  String changeSetPendingCount(int count) {
    return '$count ausstehend';
  }

  @override
  String get changeSetSwipeConfirm => 'Bestätigen';

  @override
  String get changeSetSwipeReject => 'Ablehnen';

  @override
  String get chatInputCancelRealtime => 'Abbrechen (Esc)';

  @override
  String get chatInputCancelRecording => 'Aufnahme abbrechen (Esc)';

  @override
  String get chatInputConfigureModel => 'Modell konfigurieren';

  @override
  String get chatInputHintDefault =>
      'Fragen zu deinen Aufgaben und Produktivität...';

  @override
  String get chatInputHintSelectModel => 'Wähle ein Modell zum Chatten';

  @override
  String get chatInputListening => 'Hört zu...';

  @override
  String get chatInputNoAudioRecorded =>
      'Es wurde kein Audio aufgenommen. Versuch es noch einmal.';

  @override
  String get chatInputPleaseWait => 'Bitte warten...';

  @override
  String get chatInputProcessing => 'Verarbeitung...';

  @override
  String get chatInputRecordingFailed =>
      'Aufnahme fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get chatInputRecordingNoAudioModel =>
      'Es ist noch kein Transkriptionsmodell eingerichtet. Füge in den KI-Einstellungen ein Modell mit Audio-Unterstützung hinzu.';

  @override
  String get chatInputRecordingNoMicPermission =>
      'Lotti kann das Mikrofon nicht nutzen. Erlaube Lotti den Mikrofonzugriff in deinen Systemeinstellungen.';

  @override
  String get chatInputRecordVoice => 'Sprachnachricht aufnehmen';

  @override
  String get chatInputSendTooltip => 'Nachricht senden';

  @override
  String get chatInputStopRealtime => 'Live-Transkription beenden';

  @override
  String get chatInputStopTranscribe => 'Stoppen und transkribieren';

  @override
  String get chatInputTranscriptionFailed =>
      'Die Aufnahme wurde gespeichert, aber die Transkription ist fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get checkInAvoidLabel => 'Besser vermeiden';

  @override
  String get checkInDateLabel => 'Wann?';

  @override
  String get checkInDeleteConfirmMessage =>
      'Diesen Check-in löschen? Das lässt sich nicht rückgängig machen.';

  @override
  String get checkInEditTitle => 'Check-in bearbeiten';

  @override
  String get checkInErrorCreateFailed =>
      'Check-in konnte nicht gespeichert werden. Bitte versuch es erneut.';

  @override
  String get checkInErrorDeleteFailed =>
      'Check-in konnte nicht gelöscht werden. Bitte versuch es erneut.';

  @override
  String get checkInInteractionCall => 'Anruf';

  @override
  String get checkInInteractionInPerson => 'Persönlich';

  @override
  String get checkInInteractionLabel => 'Wie hattet ihr Kontakt?';

  @override
  String get checkInInteractionMessage => 'Nachricht';

  @override
  String get checkInInteractionOther => 'Anderes';

  @override
  String get checkInInteractionVideoCall => 'Videoanruf';

  @override
  String get checkInNarrativeLabel => 'Worüber habt ihr gesprochen?';

  @override
  String get checkInPayAttentionLabel => 'Nächstes Mal darauf achten';

  @override
  String get checkInSentimentDelightful => 'Wunderbar';

  @override
  String get checkInSentimentDifficult => 'Schwierig';

  @override
  String get checkInSentimentGood => 'Gut';

  @override
  String get checkInSentimentLabel => 'Wie hat es sich angefühlt?';

  @override
  String get checkInSentimentNeutral => 'Neutral';

  @override
  String get checkInSentimentStrained => 'Angespannt';

  @override
  String get checkInTopicsHint => 'Kommagetrennt, z. B. Arbeit, Reisen';

  @override
  String get checkInTopicsLabel => 'Themen';

  @override
  String get checklistAddItem => 'Neues Element hinzufügen';

  @override
  String checklistAiConfidenceLabel(String level) {
    return 'Konfidenz: $level';
  }

  @override
  String get checklistAiMarkComplete => 'Als erledigt markieren';

  @override
  String get checklistAiSuggestionBody =>
      'Diese Aufgabe scheint erledigt zu sein:';

  @override
  String get checklistAiSuggestionTitle => 'KI-Vorschlag';

  @override
  String get checklistAllDone => 'Alle Punkte erledigt!';

  @override
  String get checklistCollapseTooltip => 'Einklappen';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total erledigt';
  }

  @override
  String get checklistDelete => 'Checkliste löschen?';

  @override
  String get checklistExpandTooltip => 'Ausklappen';

  @override
  String get checklistExportAsMarkdown => 'Checkliste als Markdown exportieren';

  @override
  String get checklistExportFailed => 'Export fehlgeschlagen';

  @override
  String get checklistItemArchived => 'Element archiviert';

  @override
  String get checklistItemArchiveUndo => 'Rückgängig';

  @override
  String get checklistItemDeleteCancel => 'Abbrechen';

  @override
  String get checklistItemDeleteConfirm => 'Bestätigen';

  @override
  String get checklistItemDeleted => 'Element gelöscht';

  @override
  String get checklistItemDeleteWarning =>
      'Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get checklistMarkdownCopied => 'Checkliste als Markdown kopiert';

  @override
  String get checklistMoreTooltip => 'Mehr';

  @override
  String get checklistNoneDone => 'Noch keine erledigten Punkte.';

  @override
  String get checklistNothingToExport => 'Keine Einträge zum Exportieren';

  @override
  String get checklistProgressSemantics => 'Checklisten-Fortschritt';

  @override
  String get checklistShare => 'Teilen';

  @override
  String get checklistShareHint => 'Lange drücken zum Teilen';

  @override
  String get checklistsReorder => 'Neu anordnen';

  @override
  String get clearButton => 'Löschen';

  @override
  String get colorCustomLabel => 'Benutzerdefiniert';

  @override
  String get colorLabel => 'Farbe';

  @override
  String get commandPaletteNoResults =>
      'Keine verfügbaren Befehle passen zu deiner Suche';

  @override
  String get commandPaletteSearchHint => 'Befehle suchen…';

  @override
  String get commandPaletteTitle => 'Befehlspalette';

  @override
  String get commonError => 'Fehler';

  @override
  String get commonLoading => 'Laden...';

  @override
  String get commonUnknown => 'Unbekannt';

  @override
  String get completeHabitFailButton => 'Verpasst';

  @override
  String get completeHabitSkipButton => 'Überspringen';

  @override
  String get completeHabitSuccessButton => 'Erfolgreich';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Wenn aktiviert, versucht die App, Einbettungen für deine Einträge zu generieren, um die Suche und Vorschläge für verwandte Inhalte zu verbessern.';

  @override
  String get configFlagDailyOsOnboardingEnabled => 'Daily-OS-Einführung';

  @override
  String get configFlagDailyOsOnboardingEnabledDescription =>
      'Führe neue Daily-OS-Nutzer durch ein echtes Check-in, das Sprache in eine Aufgabe und einen Tagesplan verwandelt.';

  @override
  String get configFlagEnableAiStreaming =>
      'AI-Streaming für Aufgabenaktionen aktivieren';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Streame AI-Antworten für aufgabenbezogene Aktionen. Deaktivieren, um Antworten zu puffern und die UI flüssiger zu halten.';

  @override
  String get configFlagEnableAiSummaryTts => 'AI-Zusammenfassung vorlesen';

  @override
  String get configFlagEnableAiSummaryTtsDescription =>
      'Zeigt die lokale Text-to-Speech-Schaltfläche in AI-Zusammenfassungen von Aufgaben. Erfordert ein installiertes MLX-Audio-TTS-Modell.';

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
  String get configFlagEnableEmbeddings => 'Einbettungen generieren';

  @override
  String get configFlagEnableEvents => 'Ereignisse aktivieren';

  @override
  String get configFlagEnableEventsDescription =>
      'Ereignisfunktion anzeigen, um Ereignisse in deinem Journal zu erstellen, zu verfolgen und zu verwalten.';

  @override
  String get configFlagEnableForkHealing => 'Agenten-Fork-Heilung';

  @override
  String get configFlagEnableForkHealingDescription =>
      'Auseinandergelaufene Agenten-Verläufe aus der Nutzung mehrerer Geräte beim nächsten Aufwachen zusammenführen.';

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
      'Erhalte Benachrichtigungen für Erinnerungen, Aktualisierungen und wichtige Ereignisse.';

  @override
  String get configFlagEnableProjects => 'Projekte aktivieren';

  @override
  String get configFlagEnableProjectsDescription =>
      'Projektverwaltung zum Organisieren von Aufgaben in Projekten anzeigen.';

  @override
  String get configFlagEnableRelationships => 'Menschen-Seite aktivieren';

  @override
  String get configFlagEnableRelationshipsDescription =>
      'Zeigt den Menschen-Tab zur Pflege deiner persönlichen Beziehungen.';

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
  String get configFlagEnableUnifiedGoals =>
      'Einheitliche Zielseite aktivieren';

  @override
  String get configFlagEnableUnifiedGoalsDescription =>
      'Zeigt die einheitliche Zielseite in der Hauptnavigation. Ziele und ihre Gewohnheiten erscheinen dort gemeinsam auf einer Seite.';

  @override
  String get configFlagEnableVectorSearch => 'Vektorsuche';

  @override
  String get configFlagEnableVectorSearchDescription =>
      'Aktiviert Vektorsuche in den Aufgabenfiltern. Erfordert aktivierte Embeddings und ein laufendes Ollama.';

  @override
  String get configFlagEnableWhatsNew => '„Neu\"-Hinweise anzeigen';

  @override
  String get configFlagEnableWhatsNewDescription =>
      'Hebt neue Funktionen und Änderungen im Einstellungsbaum hervor.';

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
  String get conflictApplyButton => 'Übernehmen';

  @override
  String get conflictApplyFailedTitle =>
      'Konflikt konnte nicht angewendet werden';

  @override
  String conflictBannerAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Tagen',
      one: 'vor 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Std.',
      one: 'vor 1 Std.',
    );
    return '$_temp0';
  }

  @override
  String get conflictBannerAgoJustNow => 'gerade eben';

  @override
  String conflictBannerAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Min.',
      one: 'vor 1 Min.',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerDivergedAgo(String entity, String ago) {
    return '$entity · auseinandergegangen $ago';
  }

  @override
  String conflictBannerFieldsDifferList(String fields) {
    return 'Unterschiede: $fields';
  }

  @override
  String get conflictCombineApply => 'Kombiniert übernehmen';

  @override
  String get conflictCombineStartFrom => 'Ausgehen von';

  @override
  String get conflictConfirmDeletion => 'Löschen bestätigen';

  @override
  String get conflictDeleteVsEditDescription =>
      'Dieser Eintrag wurde auf einem Gerät bearbeitet und auf einem anderen gelöscht. Es wird nichts entfernt, bis du dich entscheidest.';

  @override
  String get conflictDeleteVsEditTitle => 'Auf einem Gerät gelöscht';

  @override
  String get conflictDetailEntryNotFoundTitle => 'Eintrag nicht gefunden';

  @override
  String get conflictDetailLoadErrorTitle =>
      'Konflikt konnte nicht geladen werden';

  @override
  String get conflictDetailNotFoundTitle => 'Konflikt nicht gefunden';

  @override
  String get conflictDiffRecommended => 'Empfohlen';

  @override
  String conflictDiffUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Felder unverändert',
      one: '1 Feld unverändert',
    );
    return '$_temp0';
  }

  @override
  String get conflictFieldBody => 'Text';

  @override
  String get conflictFieldCategory => 'Kategorie';

  @override
  String get conflictFieldDuration => 'Dauer';

  @override
  String get conflictFieldEnd => 'Ende';

  @override
  String get conflictFieldFlag => 'Markierung';

  @override
  String get conflictFieldOther => 'Weitere Details';

  @override
  String get conflictFieldOtherDescription =>
      'Diese Versionen unterscheiden sich in Details, die hier nicht einzeln angezeigt werden.';

  @override
  String get conflictFieldPrivate => 'Privat';

  @override
  String get conflictFieldStarred => 'Favorit';

  @override
  String get conflictFieldStart => 'Beginn';

  @override
  String get conflictFieldTitle => 'Titel';

  @override
  String get conflictFieldWordCount => 'Wortanzahl';

  @override
  String get conflictFlagFollowUp => 'Nachverfolgung nötig';

  @override
  String get conflictFlagImport => 'Importiert';

  @override
  String get conflictFlagNone => 'Keine';

  @override
  String get conflictFooterHelperLocalSelected =>
      'Behält deine lokale Bearbeitung und verwirft die synchronisierte Version.';

  @override
  String get conflictFooterHelperPickASide =>
      'Wähle eine Seite zum Übernehmen.';

  @override
  String get conflictFooterHelperRemoteSelected =>
      'Übernimmt die synchronisierte Version und verwirft deine lokale Bearbeitung.';

  @override
  String conflictHeaderPillEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0';
  }

  @override
  String conflictHeaderPillFieldsDiffer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Felder unterscheiden sich',
      one: '1 Feld unterscheidet sich',
    );
    return '$_temp0';
  }

  @override
  String get conflictKeepEdited => 'Bearbeitete Version behalten';

  @override
  String conflictListItemSemanticsLabel(
    String status,
    String timestamp,
    String entityType,
    String id,
  ) {
    return '$status, $timestamp, $entityType, Konflikt $id';
  }

  @override
  String conflictListItemTooltipFullId(String id) {
    return 'Konflikt-ID: $id';
  }

  @override
  String get conflictMetaLocalEdit => 'lokale Bearbeitung';

  @override
  String get conflictMetaVecPrefix => 'vec';

  @override
  String get conflictMetaViaSync => 'via Sync';

  @override
  String conflictNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge wurden auf zwei Geräten bearbeitet',
      one: '1 Eintrag wurde auf zwei Geräten bearbeitet',
    );
    return '$_temp0';
  }

  @override
  String get conflictNotificationTitle => 'Sync braucht deine Aufmerksamkeit';

  @override
  String get conflictPageLeadDesktop =>
      'Unterschiede sind inline hervorgehoben. Klick auf eine Seite, um diese Version zu verwenden, oder öffne Bearbeiten & zusammenführen, um sie zu kombinieren.';

  @override
  String get conflictPageLeadMobile =>
      'Unterschiede sind inline hervorgehoben. Tippe auf eine Seite, um diese Version zu verwenden.';

  @override
  String get conflictPageTitle => 'Sync-Konflikt';

  @override
  String get conflictPickerCombine => 'Kombinieren…';

  @override
  String get conflictPickerEditMerge => 'Bearbeiten & zusammenführen…';

  @override
  String get conflictPickerUseFromSync => 'Aus Sync verwenden';

  @override
  String get conflictPickerUseThisDevice => 'Dieses Gerät verwenden';

  @override
  String get conflictResolvedToast => 'Konflikt gelöst';

  @override
  String get conflictsEmptyDescription =>
      'Alles ist synchronisiert. Gelöste Einträge bleiben im anderen Filter verfügbar.';

  @override
  String get conflictsEmptyTitle => 'Keine Konflikte erkannt';

  @override
  String get conflictSideFromSync => 'AUS SYNC';

  @override
  String get conflictSideThisDevice => 'DIESES GERÄT';

  @override
  String get conflictsResolved => 'gelöst';

  @override
  String get conflictsUnresolved => 'ungelöst';

  @override
  String get conflictValueAbsent => 'Nicht gesetzt';

  @override
  String get conflictValueNo => 'Nein';

  @override
  String get conflictValueYes => 'Ja';

  @override
  String conflictWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wörter',
      one: '$count Wort',
    );
    return '$_temp0';
  }

  @override
  String get contactUsDiscordLabel => 'Discord';

  @override
  String get contactUsEmailSubject => 'Lotti-Feedback';

  @override
  String get contactUsGithubLabel => 'GitHub';

  @override
  String get contactUsLabel => 'Kontaktiere uns';

  @override
  String get copyAsMarkdown => 'Als Markdown kopieren';

  @override
  String get copyAsText => 'Als Text kopieren';

  @override
  String get correctionExampleCancel => 'Abbrechen';

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
  String get coverArtChipActive => 'Titelbild';

  @override
  String get coverArtChipSet => 'Titelbild setzen';

  @override
  String get coverArtGenerationComplete => 'Titelbild fertig!';

  @override
  String get coverArtGenerationDismissHint =>
      'Du kannst dies schließen — die Generierung läuft im Hintergrund weiter';

  @override
  String get createButton => 'Erstellen';

  @override
  String get createCategoryTitle => 'Kategorie erstellen';

  @override
  String get createEntryLabel => 'Neuen Eintrag erstellen';

  @override
  String get createEntryTitle => 'Hinzufügen';

  @override
  String get createEntryTriggerHintFull =>
      'Notiz, Checkliste, Sprachnotiz, Bild und mehr hinzufügen';

  @override
  String get createNewLinkedTask => 'Neue verknüpfte Aufgabe erstellen…';

  @override
  String get createNewLinkedTaskTitle => 'Neue Aufgabe';

  @override
  String get customColor => 'Benutzerdefinierte Farbe';

  @override
  String get dailyOsDayPlan => 'Tagesplan';

  @override
  String get dailyOsNextActivityActionFailed =>
      'Die Aktion wurde nicht abgeschlossen. Deine Aufnahme ist weiterhin sicher — versuch es erneut.';

  @override
  String get dailyOsNextActivityAgentActionFailed =>
      'Die Aktion wurde nicht abgeschlossen. Es ist nichts verloren gegangen – versuch es erneut.';

  @override
  String get dailyOsNextActivityAgentJobDraft =>
      'Der Entwurf deines Tagesplans wurde nicht fertig.';

  @override
  String get dailyOsNextActivityAgentJobModelFailed =>
      'Das KI-Modell konnte das nicht abschließen.';

  @override
  String get dailyOsNextActivityAgentJobNoPlan =>
      'Es gibt noch keinen Tagesplan zum Aktualisieren.';

  @override
  String get dailyOsNextActivityAgentJobParse =>
      'Das Auswerten deines Check-ins wurde nicht fertig.';

  @override
  String get dailyOsNextActivityAgentJobRefine =>
      'Die Aktualisierung deines Tagesplans wurde nicht fertig.';

  @override
  String get dailyOsNextActivityAgentJobRetryHint =>
      'Es ist nichts verloren gegangen. Versuch es erneut, wenn du so weit bist.';

  @override
  String get dailyOsNextActivityAgentJobSetupRequired =>
      'Für die Planung ist noch kein KI-Modell eingerichtet.';

  @override
  String get dailyOsNextActivityAgentJobTemporary =>
      'Der KI-Dienst war ausgelastet oder nicht erreichbar.';

  @override
  String get dailyOsNextActivityDaySummary => 'Tageszusammenfassung';

  @override
  String get dailyOsNextActivityDeleteDialogBody =>
      'Die Aufnahme und ihre ausstehende Transkription werden aus diesem Tag entfernt.';

  @override
  String get dailyOsNextActivityDeleteDialogTitle => 'Diese Aufnahme löschen?';

  @override
  String get dailyOsNextActivityDeleteRecording => 'Löschen';

  @override
  String get dailyOsNextActivityEmpty => 'Noch keine Aufnahmen oder Check-ins.';

  @override
  String get dailyOsNextActivityLoadFailed =>
      'Deine gespeicherte Aktivität ist weiterhin auf diesem Gerät, konnte aber gerade nicht geladen werden.';

  @override
  String get dailyOsNextActivityMissingAudio =>
      'Dieser Eintrag bleibt erhalten, aber die Audiodatei ist auf diesem Gerät nicht verfügbar. Stell die Datei wieder her und versuch es dann erneut.';

  @override
  String get dailyOsNextActivityNeedsAttention => 'Prüfung nötig';

  @override
  String get dailyOsNextActivityOpenAiSetup => 'Daily-OS-Einrichtung öffnen';

  @override
  String get dailyOsNextActivityOpenSetup => 'Transkription einrichten';

  @override
  String get dailyOsNextActivityPlanAvailable =>
      'Dein Tagesplan ist verfügbar.';

  @override
  String get dailyOsNextActivityPlanCreated => 'Plan erstellt';

  @override
  String get dailyOsNextActivityReady => 'Bereit';

  @override
  String get dailyOsNextActivityRetry => 'Transkription erneut versuchen';

  @override
  String get dailyOsNextActivityRetryLoad => 'Erneut laden';

  @override
  String get dailyOsNextActivityRetryStep => 'Erneut versuchen';

  @override
  String get dailyOsNextActivitySaved => 'Lokal gespeichert';

  @override
  String get dailyOsNextActivitySetupRequired =>
      'Deine Aufnahme ist sicher. Richte ein Modell für Audiotranskription ein und versuch es dann erneut.';

  @override
  String get dailyOsNextActivitySubmitted => 'Zum Tag hinzugefügt';

  @override
  String get dailyOsNextActivityTranscribing => 'Wird transkribiert';

  @override
  String get dailyOsNextActivityTranscriptPending =>
      'Deine Aufnahme ist gespeichert. Das Transkript steht noch aus.';

  @override
  String get dailyOsNextActivityUseToPlan => 'Für den Tagesplan verwenden';

  @override
  String get dailyOsNextActivityUseToRefine => 'Zum Anpassen verwenden';

  @override
  String get dailyOsNextActivityWaitingForNetwork => 'Warte auf Verbindung';

  @override
  String get dailyOsNextAgendaCapacityComfortable => 'Entspannt';

  @override
  String get dailyOsNextAgendaCapacityNearFull => 'Fast voll';

  @override
  String get dailyOsNextAgendaCapacityNoPlan => 'Noch kein Plan';

  @override
  String dailyOsNextAgendaCapacityOf(String capacity) {
    return 'von $capacity';
  }

  @override
  String get dailyOsNextAgendaCapacityOver => 'Überlastet';

  @override
  String get dailyOsNextAgendaDonutLeft => 'frei';

  @override
  String get dailyOsNextAgendaDonutOver => 'drüber';

  @override
  String dailyOsNextAgendaHeadlineLeft(String duration) {
    return '$duration übrig';
  }

  @override
  String dailyOsNextAgendaHeadlineOver(String duration) {
    return '$duration drüber';
  }

  @override
  String get dailyOsNextAgendaNoPlanBody =>
      'Deine erfasste Zeit ist trotzdem hier — sprich ein Check-in ein und ich entwerfe einen Tag darum.';

  @override
  String dailyOsNextAgendaNoPlanSummary(String duration) {
    return 'Bisher $duration erfasst. Sprich ein Check-in ein und ich entwerfe einen Tag darum.';
  }

  @override
  String get dailyOsNextAgendaNoPlanTitle => 'Noch kein Plan für heute.';

  @override
  String get dailyOsNextAgendaStateDone => 'Erledigt';

  @override
  String get dailyOsNextAgendaStateInProgress => 'In Arbeit';

  @override
  String get dailyOsNextAgendaStateOpen => 'Offen';

  @override
  String get dailyOsNextAgendaStateOverdue => 'Überfällig';

  @override
  String dailyOsNextAgendaSummary(String scheduled, String capacity) {
    return '$scheduled von $capacity verplant';
  }

  @override
  String dailyOsNextAgendaTrackedLegend(String duration, int completedCount) {
    return 'Erfasst · $duration · $completedCount erledigt';
  }

  @override
  String get dailyOsNextBlockEditCategoryLabel => 'Kategorie';

  @override
  String get dailyOsNextBlockEditFailed =>
      'Der Block konnte nicht aktualisiert werden — versuch es nochmal.';

  @override
  String get dailyOsNextBlockEditNameLabel => 'Titel';

  @override
  String get dailyOsNextBlockEditOpenTask => 'Aufgabe öffnen';

  @override
  String get dailyOsNextBlockEditSave => 'Änderungen speichern';

  @override
  String get dailyOsNextBlockEditSaved => 'Zeitplan aktualisiert.';

  @override
  String get dailyOsNextBlockEditTimeLabel => 'Start und Ende';

  @override
  String get dailyOsNextBlockEditTitle => 'Block bearbeiten';

  @override
  String get dailyOsNextBlockEditTooltip => 'Block bearbeiten';

  @override
  String get dailyOsNextBlockEditWhyLabel => 'Warum zu dieser Zeit';

  @override
  String get dailyOsNextBlockMoveTooltip => 'Block verschieben';

  @override
  String get dailyOsNextBlockResizeEndTooltip => 'Ende anpassen';

  @override
  String get dailyOsNextBlockResizeStartTooltip => 'Start anpassen';

  @override
  String get dailyOsNextCaptureCaptured => 'Hab\'s.';

  @override
  String get dailyOsNextCaptureDoneCta => 'Fertig';

  @override
  String get dailyOsNextCaptureErrorAudioPersistFailed =>
      'Deine Aufnahme konnte nicht gespeichert werden.';

  @override
  String get dailyOsNextCaptureErrorMicrophonePermissionDenied =>
      'Der Zugriff auf das Mikrofon wurde verweigert.';

  @override
  String get dailyOsNextCaptureErrorNoAudioRecorded =>
      'Es wurde kein Audio aufgenommen.';

  @override
  String get dailyOsNextCaptureErrorRecordingSavedPendingTranscription =>
      'Deine Aufnahme ist gespeichert. Die Transkription konnte nicht abgeschlossen werden.';

  @override
  String get dailyOsNextCaptureErrorRecordingStartFailed =>
      'Die Aufnahme konnte nicht starten.';

  @override
  String get dailyOsNextCaptureHeadlineCaptured => 'Passt das so?';

  @override
  String get dailyOsNextCaptureHeadlineLead => 'Was beschäftigt dich';

  @override
  String get dailyOsNextCaptureHeadlineListening => 'Ich höre zu.';

  @override
  String get dailyOsNextCaptureHeadlineTail => 'heute?';

  @override
  String dailyOsNextCaptureHeadlineTailForDate(String date) {
    return 'für $date?';
  }

  @override
  String get dailyOsNextCaptureHeadlineTailTomorrow => 'für morgen?';

  @override
  String get dailyOsNextCaptureHeadlineTailYesterday => 'für gestern?';

  @override
  String get dailyOsNextCaptureHeadlineTranscribing => 'Ich schreibe mit…';

  @override
  String get dailyOsNextCaptureIdleClick => 'Zum Sprechen klicken';

  @override
  String get dailyOsNextCaptureIdleExample =>
      '„Vormittags Deep Work, nach dem Mittag ein Spaziergang, E-Mails bis fünf.“';

  @override
  String get dailyOsNextCaptureIdleHint =>
      'Tippen zum Sprechen · stattdessen tippen';

  @override
  String get dailyOsNextCaptureIdleTalk => 'Tippen zum Sprechen';

  @override
  String get dailyOsNextCaptureListeningStatus => 'Höre zu…';

  @override
  String dailyOsNextCapturePastPrompt(String date) {
    return 'Möchtest du für $date noch etwas erfassen?';
  }

  @override
  String get dailyOsNextCaptureReconcileCta => 'Prüfen';

  @override
  String get dailyOsNextCaptureRecordingSavedStatus => 'Aufnahme gespeichert';

  @override
  String get dailyOsNextCapturesPanelTitle => 'Aufnahmen';

  @override
  String get dailyOsNextCaptureTranscribing => 'Wird transkribiert…';

  @override
  String get dailyOsNextCaptureTranscriptHint =>
      'Korrigiere alles, was der Text falsch erkannt hat, bevor du planst.';

  @override
  String get dailyOsNextCaptureTranscriptLabel => 'Transkript prüfen';

  @override
  String get dailyOsNextCaptureTypeInstead => 'Stattdessen tippen';

  @override
  String get dailyOsNextCaptureVoiceButtonReset => 'Von vorne beginnen';

  @override
  String get dailyOsNextCaptureVoiceButtonStart => 'Aufnahme starten';

  @override
  String get dailyOsNextCaptureVoiceButtonStop => 'Aufnahme stoppen';

  @override
  String get dailyOsNextCategoryFilterAll => 'Alle Kategorien';

  @override
  String get dailyOsNextCategoryFilterDescription =>
      'Nur für die Tagesplanung aktivierte Kategorien werden für die automatische Daily-OS-Verarbeitung berücksichtigt.';

  @override
  String get dailyOsNextCategoryFilterEmpty =>
      'Noch keine Kategorien für die Tagesplanung aktiviert.';

  @override
  String get dailyOsNextCategoryFilterIncludeAll => 'Alle einbeziehen';

  @override
  String get dailyOsNextCategoryFilterTitle => 'Verarbeitungskategorien';

  @override
  String get dailyOsNextCategoryFilterTooltip =>
      'Daily-OS-Verarbeitungskategorien auswählen';

  @override
  String dailyOsNextCommitCapacityNote(String scheduled, String capacity) {
    return '$scheduled von $capacity eingeplant. Komfortable Reserve — eine Überraschung verträgt der Tag.';
  }

  @override
  String get dailyOsNextCommitDraftOverline => 'DEIN TAG, ENTWORFEN';

  @override
  String get dailyOsNextCommitExplainer =>
      'Bestätige, um den Tag vom Entwurf in fest umzuwandeln.';

  @override
  String get dailyOsNextCommitFinalStepEyebrow => 'LETZTER SCHRITT';

  @override
  String get dailyOsNextCommitHeadline => 'Mach ihn zu deinem.';

  @override
  String get dailyOsNextCommitHoldHelper =>
      'Eine Sekunde halten zum Bestätigen';

  @override
  String get dailyOsNextCommitHoldWordDone => 'Festgelegt';

  @override
  String get dailyOsNextCommitHoldWordHolding => 'Weiter halten';

  @override
  String get dailyOsNextCommitHoldWordIdle => 'Halten';

  @override
  String get dailyOsNextCommitLockingIn => 'Wird festgemacht…';

  @override
  String get dailyOsNextCommitShepherdSubline =>
      'Ich begleite ihn — du machst die Arbeit.';

  @override
  String get dailyOsNextCommitSubCaption =>
      'Du kannst danach weiter mit mir sprechen — aber das Gerüst bleibt stehen.';

  @override
  String get dailyOsNextCommitTitle => 'Festmachen';

  @override
  String get dailyOsNextCommitTodayIsYours => 'Der Tag gehört dir.';

  @override
  String get dailyOsNextDayAgentStatusAttention => 'Braucht Aufmerksamkeit';

  @override
  String get dailyOsNextDayAgentStatusDayClosed => 'Tag abgeschlossen';

  @override
  String get dailyOsNextDayAgentStatusWorking => 'Plant…';

  @override
  String dailyOsNextDayAgentTokensToday(int tokens) {
    return '$tokens Tokens für die Planung dieses Tages';
  }

  @override
  String get dailyOsNextDayBack => 'Zurück';

  @override
  String get dailyOsNextDayCheckInCta => 'Check-in einsprechen';

  @override
  String get dailyOsNextDayDeleteDialogBody =>
      'Die geplanten Blöcke für diesen Tag werden entfernt. Deine Aufnahmen und ihre Audio-Dateien bleiben in deinem Journal.';

  @override
  String get dailyOsNextDayDeleteDialogCancel => 'Abbrechen';

  @override
  String get dailyOsNextDayDeleteDialogConfirm => 'Löschen';

  @override
  String get dailyOsNextDayDeleteDialogTitle => 'Diesen Plan löschen?';

  @override
  String get dailyOsNextDayLockInCta => 'Festmachen';

  @override
  String get dailyOsNextDayMenuDeletePlan => 'Plan löschen';

  @override
  String get dailyOsNextDayMenuInspectAgent => 'Agent prüfen';

  @override
  String get dailyOsNextDayMenuSettings => 'Daily-OS-Einstellungen';

  @override
  String get dailyOsNextDayMoreTooltip => 'Mehr';

  @override
  String get dailyOsNextDayRefineCta => 'Anpassen';

  @override
  String get dailyOsNextDayRefineFooterHint =>
      'Sprich, um den Plan umzubauen — du siehst jede Änderung, bevor etwas gespeichert wird.';

  @override
  String get dailyOsNextDayTitle => 'Dein Tag';

  @override
  String get dailyOsNextDayWhyChipLabel => 'WARUM';

  @override
  String get dailyOsNextDayWrapUpCta => 'Abschließen';

  @override
  String get dailyOsNextDraftingBackToDecisions =>
      'Zurück zu den Entscheidungen';

  @override
  String get dailyOsNextDraftingHeader => 'Plane deinen Tag…';

  @override
  String get dailyOsNextDraftingNudgeAccept => 'Ja, Morgen schützen';

  @override
  String get dailyOsNextDraftingNudgeDecline => 'Heute nicht';

  @override
  String get dailyOsNextDraftingProgressBlocks => 'Baue Blöcke';

  @override
  String get dailyOsNextDraftingProgressMatching => 'Ordne Aufgaben zu';

  @override
  String get dailyOsNextDraftingProgressQueued => 'In der Warteschlange';

  @override
  String get dailyOsNextDraftingProgressReading => 'Lese Check-in';

  @override
  String get dailyOsNextDraftingProgressSaving => 'Speichere Plan';

  @override
  String get dailyOsNextDraftingProgressValidating => 'Prüfe';

  @override
  String get dailyOsNextDraftingReasoningOverline => '✦ ÜBERLEGUNG';

  @override
  String get dailyOsNextDraftingRecoveryBody =>
      'Der Aufwachvorgang hat keinen Plan erzeugt. Versuch es erneut oder geh zurück und passe die Entscheidungen vor dem Planen an.';

  @override
  String get dailyOsNextDraftingRecoveryTitle => 'Planung hängt';

  @override
  String get dailyOsNextDraftingRetry => 'Erneut versuchen';

  @override
  String get dailyOsNextDraftingStatusAfternoon => 'Sortiere den Nachmittag…';

  @override
  String get dailyOsNextDraftingStatusAlmost => 'Fast fertig…';

  @override
  String get dailyOsNextDraftingStatusBreathing => 'Lasse Raum zum Durchatmen…';

  @override
  String get dailyOsNextDraftingStatusDeepWork => 'Plane Deep Work zuerst ein…';

  @override
  String get dailyOsNextDraftingStatusMatching =>
      'Ordne Aufgaben deinem Tag zu…';

  @override
  String get dailyOsNextDraftingStatusReading => 'Lese deinen Check-in…';

  @override
  String get dailyOsNextDraftingStatusTimings =>
      'Prüfe die Zeiten noch einmal…';

  @override
  String get dailyOsNextDraftingStatusYesterday =>
      'Schaue auf den gestrigen Rhythmus…';

  @override
  String get dailyOsNextEditTitleHint => 'Titel bearbeiten';

  @override
  String get dailyOsNextGenericError =>
      'Etwas ist schiefgelaufen. Versuch es gleich noch mal.';

  @override
  String get dailyOsNextGreetingAfternoon => 'Guten Tag.';

  @override
  String get dailyOsNextGreetingEvening => 'Guten Abend.';

  @override
  String dailyOsNextGreetingHiName(String name) {
    return 'Hallo $name 👋';
  }

  @override
  String get dailyOsNextGreetingMorning => 'Guten Morgen.';

  @override
  String get dailyOsNextKnowledgeConfirm => 'Bestätigen';

  @override
  String get dailyOsNextKnowledgeConfirmedHeader => 'Bestätigt';

  @override
  String get dailyOsNextKnowledgeEdit => 'Bearbeiten';

  @override
  String get dailyOsNextKnowledgeEditCancel => 'Abbrechen';

  @override
  String get dailyOsNextKnowledgeEditHookHint => 'Einzeilige Zusammenfassung';

  @override
  String get dailyOsNextKnowledgeEditSave => 'Speichern';

  @override
  String get dailyOsNextKnowledgeEditStatementHint =>
      'Woran soll ich mich erinnern?';

  @override
  String get dailyOsNextKnowledgeEmpty =>
      'Noch nichts — ich merke mir, was du mir sagst.';

  @override
  String dailyOsNextKnowledgeNudge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Beobachtungen — prüfen',
      one: '1 Beobachtung — prüfen',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextKnowledgeProposedHeader =>
      'Wartet auf deine Bestätigung';

  @override
  String get dailyOsNextKnowledgeRetract => 'Vergessen';

  @override
  String get dailyOsNextKnowledgeStale => 'Stimmt das noch?';

  @override
  String get dailyOsNextKnowledgeTitle => 'Was ich gelernt habe';

  @override
  String get dailyOsNextParsedCardBreakLinkTooltip => 'Verknüpfung lösen';

  @override
  String get dailyOsNextPlanChangesFailedNotificationBody =>
      'Öffne Lotti, um zu sehen, was passiert ist, und versuche es erneut.';

  @override
  String get dailyOsNextPlanChangesFailedNotificationTitle =>
      'Deine Planänderungen wurden nicht fertig';

  @override
  String get dailyOsNextPlanChangesReadyNotificationBody =>
      'Die vorgeschlagenen Änderungen warten auf deine Durchsicht.';

  @override
  String get dailyOsNextPlanChangesReadyNotificationTitle =>
      'Deine Planänderungen sind fertig';

  @override
  String get dailyOsNextPlanFailedNotificationBody =>
      'Öffne Lotti, um zu sehen, was passiert ist, und versuche es erneut.';

  @override
  String get dailyOsNextPlanFailedNotificationTitle =>
      'Dein Tagesplan wurde nicht fertig';

  @override
  String get dailyOsNextPlanReadyNotificationBody =>
      'Der Entwurf wartet auf deine Durchsicht.';

  @override
  String get dailyOsNextPlanReadyNotificationTitle =>
      'Dein Tagesplan ist fertig';

  @override
  String get dailyOsNextPlanViewActivity => 'Aktivität';

  @override
  String get dailyOsNextPlanViewAgenda => 'Agenda';

  @override
  String get dailyOsNextPlanViewDay => 'Tag';

  @override
  String get dailyOsNextReconcileBadgeMatched => 'VERKNÜPFT';

  @override
  String get dailyOsNextReconcileBadgeNew => 'NEU';

  @override
  String get dailyOsNextReconcileBadgeUpdate => 'AKTUALISIEREN';

  @override
  String get dailyOsNextReconcileBuildDayCta => 'Tag bauen';

  @override
  String get dailyOsNextReconcileDecideOverline => 'WERT ZU ENTSCHEIDEN';

  @override
  String dailyOsNextReconcileDecisionProgress(int decided, int total) {
    return '$decided von $total geprüft';
  }

  @override
  String get dailyOsNextReconcileDefaultBehaviorHint =>
      'Prüf die Karten, bevor du deinen Tag baust. Gewählte Aktionen fließen in den Plan ein; Karten ohne Aktion bleiben, wie sie sind.';

  @override
  String dailyOsNextReconcileError(String detail) {
    return 'Etwas ist schiefgelaufen: $detail';
  }

  @override
  String get dailyOsNextReconcileHeadline => 'Das habe ich gehört.';

  @override
  String get dailyOsNextReconcileHeardEmpty =>
      'Erfasste Karten erscheinen hier, sobald das Parsen fertig ist.';

  @override
  String get dailyOsNextReconcileHeardOverline => 'GEHÖRT';

  @override
  String get dailyOsNextReconcileLowConfidence => 'geringe Sicherheit';

  @override
  String get dailyOsNextReconcileProcessing =>
      'Ich höre noch einmal zu und gleiche deinen Tag ab …';

  @override
  String get dailyOsNextReconcileReRecord => 'Neu aufnehmen';

  @override
  String get dailyOsNextReconcileVoiceHint =>
      'Prüf die Entscheidungen, bevor du deinen Tag planst';

  @override
  String get dailyOsNextRefineAccept => 'Übernehmen';

  @override
  String get dailyOsNextRefineCurrentPlan => 'AKTUELLER PLAN';

  @override
  String get dailyOsNextRefineDiffAdded => 'HINZUGEFÜGT';

  @override
  String get dailyOsNextRefineDiffDropped => 'VERWORFEN';

  @override
  String get dailyOsNextRefineDiffMoved => 'VERSCHOBEN';

  @override
  String get dailyOsNextRefineHeadlineDiffReady => 'Das würde ich ändern.';

  @override
  String get dailyOsNextRefineHeadlineIdle => 'Was soll sich ändern?';

  @override
  String get dailyOsNextRefineHeadlineThinking => 'Überarbeite deinen Plan…';

  @override
  String get dailyOsNextRefineKeepTalking => 'Weitersprechen';

  @override
  String get dailyOsNextRefineLooksGood => 'Passt so';

  @override
  String get dailyOsNextRefineNoChanges =>
      'Es kamen keine Planänderungen zurück. Formuliere es anders und versuch es nochmal.';

  @override
  String get dailyOsNextRefineOverline => '🎤 ANPASSUNG';

  @override
  String get dailyOsNextRefineRevert => 'Zurück';

  @override
  String get dailyOsNextRefineStatusAccepted => 'Festgemacht.';

  @override
  String get dailyOsNextRefineStatusDiffReady => 'Das hat sich geändert.';

  @override
  String get dailyOsNextRefineStatusIdle => 'Tippen zum Sprechen.';

  @override
  String get dailyOsNextRefineStatusListening => 'Höre zu…';

  @override
  String get dailyOsNextRefineStatusThinking => '✦ Plan wird überarbeitet…';

  @override
  String get dailyOsNextRefineTitle => 'Plan anpassen';

  @override
  String get dailyOsNextRenameFailed =>
      'Umbenennen fehlgeschlagen — versuch es nochmal.';

  @override
  String get dailyOsNextReviewAddBuffer => 'Puffer hinzufügen';

  @override
  String get dailyOsNextReviewAddBufferPrompt =>
      'Füge realistischen Puffer zwischen den geplanten Blöcken hinzu, besonders bei Übergängen und nach anspruchsvoller Arbeit.';

  @override
  String get dailyOsNextReviewAdjust => 'Anpassen';

  @override
  String get dailyOsNextReviewLooksGood => 'Sieht gut aus';

  @override
  String get dailyOsNextReviewMoveLighter => 'Leichter verschieben';

  @override
  String get dailyOsNextReviewMoveLighterPrompt =>
      'Verschiebe leichtere oder energieärmere Arbeit nach hinten und halte das stärkste Fokusfenster für die anspruchsvollste Aufgabe frei.';

  @override
  String get dailyOsNextReviewTooMuch => 'Zu viel';

  @override
  String get dailyOsNextReviewTooMuchPrompt =>
      'Dieser Plan ist für heute zu viel. Reduziere die Last, schütze Atemraum und behalte nur die wichtigsten Blöcke.';

  @override
  String get dailyOsNextReviewWhyTitle => 'Warum das im Plan ist';

  @override
  String get dailyOsNextShutdownCarryoverDrop => 'Verwerfen';

  @override
  String get dailyOsNextShutdownCarryoverDropped => 'Verworfen';

  @override
  String get dailyOsNextShutdownCarryoverOverline => 'BLEIBT OFFEN';

  @override
  String get dailyOsNextShutdownCarryoverPickDate => 'Datum wählen';

  @override
  String get dailyOsNextShutdownCarryoverScheduled => 'Eingeplant';

  @override
  String get dailyOsNextShutdownCloseDay => 'Tag abschließen';

  @override
  String get dailyOsNextShutdownCompletedOverline => 'WAS DU GESCHAFFT HAST';

  @override
  String get dailyOsNextShutdownMetricEnergy => 'ENERGIE';

  @override
  String dailyOsNextShutdownMetricEnergyDelta(String delta) {
    return '$delta vs. Woche';
  }

  @override
  String get dailyOsNextShutdownMetricFlow => 'FLOW-SITZUNGEN';

  @override
  String get dailyOsNextShutdownMetricFocus => 'FOKUSZEIT';

  @override
  String get dailyOsNextShutdownMetricSwitches => 'KONTEXTWECHSEL';

  @override
  String dailyOsNextShutdownMetricSwitchesAvg(String avg) {
    return '⌀ $avg diese Woche';
  }

  @override
  String get dailyOsNextShutdownReflectionOverline => '💬 EIN-ZEILEN-REFLEXION';

  @override
  String get dailyOsNextShutdownReflectionPlaceholder =>
      'z. B. Morgen war scharf, Nachmittag schleppend nach dem langen Kaffee mit Sarah.';

  @override
  String get dailyOsNextShutdownReflectionPrompt =>
      'Wie war heute? (Das fließt in den Entwurf von morgen.)';

  @override
  String get dailyOsNextShutdownReflectionSpeak => 'Sprechen';

  @override
  String get dailyOsNextShutdownReflectionSubmit => 'Überspringen';

  @override
  String get dailyOsNextShutdownReflectionThanks =>
      'Notiert — fließt in morgen ein.';

  @override
  String get dailyOsNextShutdownSaveAndClose => 'Speichern & schließen';

  @override
  String get dailyOsNextShutdownTitle => 'Tag abschließen';

  @override
  String get dailyOsNextShutdownTomorrowOverline => '✦ FÜR MORGEN';

  @override
  String dailyOsNextStateDueOnDate(String date) {
    return 'Fällig am $date';
  }

  @override
  String get dailyOsNextStateDueToday => 'Heute fällig';

  @override
  String dailyOsNextStateInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In Arbeit · $count Sitzungen',
      one: 'In Arbeit · 1 Sitzung',
      zero: 'In Arbeit',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Überfällig · $days Tage',
      one: 'Überfällig · 1 Tag',
      zero: 'Überfällig',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdueOnDate(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Am $date seit $days Tagen überfällig',
      one: 'Am $date seit 1 Tag überfällig',
      zero: 'Am $date überfällig',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextStateRecurringMissed => 'Wiederkehrend · verpasst';

  @override
  String get dailyOsNextTimelineActual => 'Ist';

  @override
  String get dailyOsNextTimelineArrange => 'Blöcke anordnen';

  @override
  String get dailyOsNextTimelineBoth => 'Plan und Ist';

  @override
  String get dailyOsNextTimelinePlanned => 'Plan';

  @override
  String dailyOsNextTimelineSessionOf(int index, int total) {
    return 'Sitzung $index von $total';
  }

  @override
  String get dailyOsNextTimelineShowBoth => 'Plan und Ist gemeinsam anzeigen';

  @override
  String get dailyOsNextTimelineShowPaged =>
      'Plan und Ist zum Wischen anzeigen';

  @override
  String get dailyOsNextTimelineSwipeHint =>
      'Wische zu Ist · vertikal kneifen zum Zoomen';

  @override
  String get dailyOsNextTimelineTracked => 'erfasst';

  @override
  String dailyOsNextTimeSpentEarlierSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frühere Sitzungen',
      one: '1 frühere Sitzung',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextTimeSpentShowLess => 'Weniger anzeigen';

  @override
  String dailyOsNextTimeSpentSummary(String duration, int completedCount) {
    return '$duration · $completedCount erledigt';
  }

  @override
  String get dailyOsNextTimeSpentTitle => 'HEUTE BISHER';

  @override
  String get dailyOsNextTimeSpentTitlePast => 'ERFASSTE ZEIT';

  @override
  String get dailyOsNextTriageConfirmDefer => 'Verschoben';

  @override
  String get dailyOsNextTriageConfirmDone => 'Erledigt markiert';

  @override
  String get dailyOsNextTriageConfirmDoNow => 'Sofort erledigt';

  @override
  String get dailyOsNextTriageConfirmDrop => 'Verworfen';

  @override
  String get dailyOsNextTriageConfirmToday => 'Heute hinzugefügt';

  @override
  String get dailyOsNextTriageDefer => 'Verschieben';

  @override
  String get dailyOsNextTriageDone => 'Erledigt';

  @override
  String get dailyOsNextTriageDoNow => 'Jetzt machen';

  @override
  String get dailyOsNextTriageDrop => 'Verwerfen';

  @override
  String get dailyOsNextTriageToday => 'Heute';

  @override
  String get dailyOsOnboardingCoachCapture => 'Sag, was dir im Kopf herumgeht.';

  @override
  String get dailyOsOnboardingCoachDrafting =>
      'Der Planer erstellt neue Aufgaben und fügt die Arbeit in deinen Tag ein.';

  @override
  String get dailyOsOnboardingCoachReconcile =>
      'Wähle, was in den heutigen Tag gehört. Neue Einträge werden zu Aufgaben, wenn du den Tag aufbaust.';

  @override
  String get dailyOsOnboardingSpotlightAction => 'Ausprobieren';

  @override
  String get dailyOsOnboardingSpotlightDismiss => 'Nicht jetzt';

  @override
  String get dailyOsOnboardingSpotlightMessage =>
      'Tippe hier und sag, was dir im Kopf herumgeht – ich mache eine Aufgabe daraus und baue deinen Tag darum herum.';

  @override
  String get dailyOsOnboardingSpotlightTitle => 'Mach aus Worten einen Plan';

  @override
  String get dailyOsSettingsChooseModelDescription =>
      'Überschreibe nur das Denkmodell des Planers.';

  @override
  String get dailyOsSettingsChooseModelTitle =>
      'Modellüberschreibung auswählen';

  @override
  String get dailyOsSettingsChooseProfileDescription =>
      'Überschreibe das gesamte Inferenzprofil für diesen Planer.';

  @override
  String get dailyOsSettingsChooseProfileTitle => 'Daily-OS-Profil auswählen';

  @override
  String get dailyOsSettingsDataDisclosure =>
      'Daily OS sendet relevante Aufgaben, Erfassungen, Pläne, gelernte Präferenzen und weiteren zusammengestellten Planungskontext zur Verarbeitung an den ausgewählten Anbieter.';

  @override
  String get dailyOsSettingsDefaultProfileDescription =>
      'Wird von Daily OS verwendet, sofern die Planer-Instanz keine Überschreibung hat.';

  @override
  String get dailyOsSettingsDefaultProfileMissing => 'Profil auswählen';

  @override
  String get dailyOsSettingsDefaultRestored =>
      'Daily-OS-Standard wiederhergestellt';

  @override
  String get dailyOsSettingsDirectOverrideActive =>
      'Direkte Modellüberschreibung ist aktiv.';

  @override
  String get dailyOsSettingsInferenceTitle => 'Standard-Inferenzprofil';

  @override
  String get dailyOsSettingsInstanceCurrentSetup =>
      'Aktuelle Planer-Konfiguration';

  @override
  String get dailyOsSettingsInstanceOverrideDescription =>
      'Verwende das Daily-OS-Standardprofil, wähle eine Profilüberschreibung oder überschreibe nur das Denkmodell dieses Planers.';

  @override
  String get dailyOsSettingsInstanceOverrideTitle => 'Daily-OS-Inferenz';

  @override
  String get dailyOsSettingsLocalDisclosure =>
      'Der ausgewählte Endpunkt befindet sich auf diesem Gerät.';

  @override
  String dailyOsSettingsModelChanged(String model) {
    return 'Daily OS verwendet jetzt $model';
  }

  @override
  String get dailyOsSettingsNameNudgeAction => 'Namen hinzufügen';

  @override
  String get dailyOsSettingsNameNudgeBody =>
      'Mit einem bevorzugten Namen werden Check-ins persönlicher. Du kannst auch ohne ihn weiterplanen.';

  @override
  String get dailyOsSettingsNameNudgeTitle =>
      'Wie soll Daily OS dich ansprechen?';

  @override
  String dailyOsSettingsProfileChanged(String profile) {
    return 'Daily OS verwendet jetzt $profile';
  }

  @override
  String get dailyOsSettingsProfileOverrideActive =>
      'Profilüberschreibung aktiv';

  @override
  String dailyOsSettingsRemoteDisclosure(String provider, String host) {
    return 'Daily OS sendet den zusammengestellten Planungskontext zur entfernten Verarbeitung an $provider unter $host.';
  }

  @override
  String get dailyOsSettingsSetupAction => 'Daily OS einrichten';

  @override
  String get dailyOsSettingsSetupRequiredBody =>
      'Daily OS braucht deine Anbieterwahl, bevor dein Planungskontext verarbeitet werden kann.';

  @override
  String get dailyOsSettingsSetupRequiredTitle => 'Inferenzprofil auswählen';

  @override
  String get dailyOsSettingsSubtitle =>
      'Lege fest, wie Daily OS dich anspricht und welches Inferenzprofil deine Tage plant.';

  @override
  String get dailyOsSettingsTitle => 'Daily OS';

  @override
  String get dailyOsSettingsTreeSubtitle =>
      'Planung, Personalisierung und KI-Anbieter';

  @override
  String get dailyOsSettingsUseDefault => 'Daily-OS-Standard verwenden';

  @override
  String get dailyOsSettingsUseDefaultDescription =>
      'Folge dem in den Daily-OS-Einstellungen ausgewählten Profil.';

  @override
  String get dailyOsTodayButton => 'Heute';

  @override
  String get dashboardActiveLabel => 'Aktiv';

  @override
  String get dashboardActiveSwitchDescription =>
      'Wird in der Dashboard-Liste angezeigt';

  @override
  String get dashboardAddChartsTitle => 'Diagramme';

  @override
  String get dashboardAddHabitButton => 'Gewohnheiten';

  @override
  String get dashboardAddHabitTitle => 'Gewohnheitsdiagramme';

  @override
  String get dashboardAddHealthButton => 'Gesundheit';

  @override
  String get dashboardAddHealthTitle => 'Gesundheitsdiagramme';

  @override
  String get dashboardAddMeasurementButton => 'Messungen';

  @override
  String get dashboardAddMeasurementTitle => 'Messdiagramme hinzufügen';

  @override
  String get dashboardAddMeasurementTooltip => 'Messung hinzufügen';

  @override
  String get dashboardAddSurveyButton => 'Umfragen';

  @override
  String get dashboardAddSurveyTitle => 'Umfragediagramme';

  @override
  String get dashboardAddWorkoutButton => 'Trainings';

  @override
  String get dashboardAddWorkoutTitle => 'Trainingsdiagramme';

  @override
  String get dashboardAggregationApplyImmediately =>
      'Wähle eine Zusammenfassung. Änderungen gelten sofort.';

  @override
  String get dashboardAggregationDailyAverage => 'Tagesdurchschnitt';

  @override
  String get dashboardAggregationDailyMax => 'Tägliches Maximum';

  @override
  String get dashboardAggregationDailyTotal => 'Tägliche Summe';

  @override
  String get dashboardAggregationHourlyTotal => 'Stündliche Summe';

  @override
  String get dashboardAggregationLabel => 'Aggregationsart:';

  @override
  String get dashboardAggregationTitle => 'Aggregationsart';

  @override
  String get dashboardAvailableChartsDescription =>
      'Wähle einen Typ, markiere ein oder mehrere Diagramme und füge sie hinzu.';

  @override
  String get dashboardAvailableChartsTitle => 'Diagramme nach Typ hinzufügen';

  @override
  String get dashboardCategoryLabel => 'Kategorie';

  @override
  String get dashboardChartNoData => 'Keine Daten in diesem Zeitraum';

  @override
  String get dashboardConfigurationDescription =>
      'Speichere das Dashboard und kopiere dann seine JSON-Konfiguration.';

  @override
  String get dashboardConfigurationTitle => 'Konfiguration exportieren';

  @override
  String get dashboardCopyHint =>
      'Dashboard-Konfiguration speichern & kopieren';

  @override
  String get dashboardCopyLabel => 'Speichern und JSON kopieren';

  @override
  String get dashboardCurrentChartsDescription =>
      'Ziehe zum Sortieren. Bei Messdiagrammen kannst du die Aggregation ändern.';

  @override
  String get dashboardCurrentChartsTitle => 'Diagramme auf diesem Dashboard';

  @override
  String get dashboardDeleteConfirm => 'Ja, dieses Dashboard löschen';

  @override
  String get dashboardDeleteHint => 'Dashboard löschen';

  @override
  String get dashboardDeleteQuestion => 'Möchtest du dieses Dashboard löschen?';

  @override
  String get dashboardDescriptionLabel => 'Beschreibung (optional)';

  @override
  String get dashboardEditAggregationLabel => 'Aggregation bearbeiten';

  @override
  String get dashboardHealthBloodPressure => 'Blutdruck';

  @override
  String get dashboardHealthDiastolic => 'Diastolisch';

  @override
  String get dashboardHealthSystolic => 'Systolisch';

  @override
  String dashboardMeasurementAddButtonWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Diagramme hinzufügen',
      one: '1 Diagramm hinzufügen',
    );
    return '$_temp0';
  }

  @override
  String dashboardMeasurementAggregationFor(String name) {
    return 'Diagrammmodus für $name';
  }

  @override
  String get dashboardMeasurementAggregationHelp =>
      'Wähle Messdiagramme aus. Passe den Diagrammmodus in ausgewählten Zeilen vor dem Hinzufügen an.';

  @override
  String get dashboardNameLabel => 'Dashboard-Name';

  @override
  String get dashboardNoChartsAdded =>
      'Noch keine Diagramme. Füge unten eins hinzu.';

  @override
  String get dashboardNoHabitsForCharts =>
      'Erstelle zuerst eine Gewohnheit, um Gewohnheitsdiagramme hinzuzufügen.';

  @override
  String get dashboardNoMeasurablesForCharts =>
      'Erstelle zuerst einen messbaren Wert, um Messdiagramme hinzuzufügen.';

  @override
  String get dashboardNotFound => 'Dashboard nicht gefunden';

  @override
  String get dashboardPrivateLabel => 'Privat';

  @override
  String get dashboardRemoveChartLabel => 'Diagramm entfernen';

  @override
  String get dashboardReorderChartLabel => 'Diagramm neu anordnen';

  @override
  String get dashboardTakeSurveyTooltip => 'Umfrage ausfüllen';

  @override
  String get defaultLanguage => 'Standardsprache';

  @override
  String get deleteButton => 'Löschen';

  @override
  String get deleteDeviceLabel => 'Aus Sync entfernen';

  @override
  String get demoAiNudgeBody =>
      'Die Demo-Welt enthält fiktive KI-Anbieter, daher können KI-Aktionen hier nicht wirklich laufen. Verbinde dein eigenes KI-Konto, um echte KI in der Demo zu nutzen. Dein Schlüssel bleibt in dieser Demo-Welt, außer du kopierst ihn beim Verlassen mit.';

  @override
  String get demoAiNudgeCancel => 'Jetzt nicht';

  @override
  String get demoAiNudgeConfirm => 'Echte KI einrichten';

  @override
  String get demoAiNudgeTitle => 'Die KI in der Demo ist nur gespielt';

  @override
  String get demoAiSetupSuccessBody =>
      'Diese Demo-Welt nutzt jetzt dein echtes KI-Konto. Dein Schlüssel bleibt hier, außer du kopierst ihn beim Verlassen mit.';

  @override
  String get demoAiSetupSuccessTitle => 'Echte KI ist aktiv';

  @override
  String get demoBannerExit => 'Beenden';

  @override
  String get demoBannerLabel => 'Demo-Welt';

  @override
  String get demoBannerSubtitle => 'Dein Journal bleibt unberührt';

  @override
  String get demoCopyBody =>
      'Wähle aus, welche Aufgaben und Einträge in dein Journal kopiert werden sollen.';

  @override
  String get demoCopyConfirm => 'Kopieren und beenden';

  @override
  String get demoCopyFailedToast =>
      'Das Kopieren deiner Demo-Daten hat nicht geklappt — in der Demo-Welt ist noch alles da, versuch es noch mal.';

  @override
  String get demoCopyProgress => 'Deine Arbeit wird kopiert…';

  @override
  String get demoCopySectionAiSetup => 'KI-Einrichtung';

  @override
  String get demoCopySectionEntries => 'Journaleinträge';

  @override
  String get demoCopySectionTasks => 'Aufgaben';

  @override
  String get demoCopySelectAll => 'Alle auswählen';

  @override
  String get demoCopyTitle => 'Meine Arbeit mitnehmen';

  @override
  String demoCopyToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge in dein Journal kopiert',
      one: '1 Eintrag in dein Journal kopiert',
    );
    return '$_temp0';
  }

  @override
  String get demoDeleteFailedToast =>
      'Die Demo-Daten konnten nicht gelöscht werden — versuch es noch mal.';

  @override
  String get demoEnterFailedToast =>
      'Die Demo-Welt konnte nicht geöffnet werden — versuch es noch mal.';

  @override
  String get demoEnteringProgress => 'Demo-Welt wird eingerichtet…';

  @override
  String get demoExitCandidatesError =>
      'Deine Arbeit zum Kopieren konnte nicht geprüft werden. Du kannst die Demo trotzdem verlassen.';

  @override
  String get demoExitConfirm => 'Demo beenden';

  @override
  String get demoExitFailedToast =>
      'Das Verlassen der Demo hat nicht geklappt — versuch es noch mal.';

  @override
  String get demoExitSheetBody =>
      'Deine Demo-Welt bleibt gespeichert — du kannst jederzeit zurückkommen.';

  @override
  String get demoExitSheetTitle => 'Demo verlassen?';

  @override
  String get demoExitTakeWork => 'Meine Arbeit mitnehmen…';

  @override
  String demoMediaDownloadCount(int completed, int total) {
    return '$completed von $total';
  }

  @override
  String get demoMediaDownloadProgress => 'Demo-Bilder werden heruntergeladen';

  @override
  String get demoMediaDownloadRetry =>
      'Einige Demo-Bilder konnten nicht heruntergeladen werden. Beim nächsten Start wird es erneut versucht.';

  @override
  String get demoOnboardingExplore => 'Mit Beispieldaten erkunden';

  @override
  String get demoSettingsDeleteConfirm =>
      'Demo-Welt und alle zugehörigen Daten löschen?';

  @override
  String get demoSettingsDeleteTitle => 'Demo-Daten löschen';

  @override
  String get demoSettingsDeleteToast => 'Demo-Daten gelöscht';

  @override
  String get demoSettingsExitTitle => 'Demo beenden';

  @override
  String get demoSettingsHealthImportUnavailable =>
      'Der Import von Gesundheitsdaten ist in der Demo-Welt nicht verfügbar';

  @override
  String get demoSettingsRealAiActiveSubtitle =>
      'Echte KI ist in dieser Demo-Welt eingerichtet';

  @override
  String get demoSettingsRealAiSubtitle =>
      'Nutze dein eigenes KI-Konto in der Demo-Welt';

  @override
  String get demoSettingsRealAiTitle => 'Echte KI in der Demo aktivieren';

  @override
  String get demoSettingsResetConfirm =>
      'Demo-Welt zurücksetzen? Alle deine Änderungen dort gehen verloren.';

  @override
  String get demoSettingsResetTitle => 'Demo-Daten zurücksetzen';

  @override
  String get demoSettingsResumeTitle => 'Zurück zur Demo-Welt';

  @override
  String get demoSettingsSyncUnavailable =>
      'Sync ist in der Demo-Welt nicht verfügbar';

  @override
  String get demoSettingsTrySubtitle =>
      'Erkunde Lotti mit Beispieldaten — dein Journal bleibt unberührt';

  @override
  String get demoSettingsTryTitle => 'Demo-Welt ausprobieren';

  @override
  String get demoTryButton => 'Demo ausprobieren';

  @override
  String get designSystemActionVariantTitle => 'Mit Aktion';

  @override
  String get designSystemActivatedLabel => 'Aktiv';

  @override
  String get designSystemAvatarAwayLabel => 'Abwesend';

  @override
  String get designSystemAvatarBusyLabel => 'Beschäftigt';

  @override
  String get designSystemAvatarConnectedLabel => 'Verbunden';

  @override
  String get designSystemAvatarEnabledLabel => 'Aktiviert';

  @override
  String get designSystemAvatarSizeMatrixTitle => 'Größenmatrix';

  @override
  String get designSystemAvatarStatusMatrixTitle => 'Statusmatrix';

  @override
  String get designSystemBackLabel => 'Zurück';

  @override
  String get designSystemBreadcrumbCurrentLabel => 'Breadcrumbs';

  @override
  String get designSystemBreadcrumbDesignSystemLabel => 'Design System';

  @override
  String get designSystemBreadcrumbHomeLabel => 'Start';

  @override
  String get designSystemBreadcrumbMobileLabel => 'Mobil';

  @override
  String get designSystemBreadcrumbProjectsLabel => 'Projekte';

  @override
  String get designSystemBreadcrumbSampleLabel => 'Breadcrumb';

  @override
  String get designSystemBreadcrumbTrailTitle => 'Breadcrumb-Pfad';

  @override
  String get designSystemCalendarPickerLabel => 'Kalenderauswahl';

  @override
  String get designSystemCalendarViewsTitle => 'Kalenderansichten';

  @override
  String get designSystemCalloutInfoSample =>
      'Ein informativer Ton: Rahmen und Symbol tragen die Farbe, die Nachricht bleibt kontrastreich.';

  @override
  String get designSystemCaptionDescriptionSample =>
      'Das Entfernen aller Benutzer hat dieses Projekt zurückgezogen. Füge Benutzer hinzu, um es erneut zu veröffentlichen.';

  @override
  String get designSystemCaptionIconLeftLabel => 'Symbol links';

  @override
  String get designSystemCaptionIconTopLabel => 'Symbol oben';

  @override
  String get designSystemCaptionNoIconLabel => 'Ohne Symbol';

  @override
  String get designSystemCaptionTitleSample => 'Überschrift';

  @override
  String get designSystemCaptionVariantsTitle => 'Caption-Varianten';

  @override
  String get designSystemCaptionWithActionsLabel => 'Mit Aktionen';

  @override
  String get designSystemCaptionWithoutActionsLabel => 'Ohne Aktionen';

  @override
  String get designSystemCheckboxLabel => 'Checkbox';

  @override
  String get designSystemContextMenuDeleteLabel => 'Löschen';

  @override
  String get designSystemContextMenuVariantsTitle => 'Kontextmenü-Varianten';

  @override
  String get designSystemCountdownVariantTitle => 'Mit Countdown';

  @override
  String get designSystemDateCardsTitle => 'Datumskarten';

  @override
  String get designSystemDefaultLabel => 'Standard';

  @override
  String get designSystemDisabledLabel => 'Deaktiviert';

  @override
  String get designSystemDividerLabelText => 'Trennlinienlabel';

  @override
  String get designSystemDropdownComboboxTitle => 'Kombinationsfeld';

  @override
  String get designSystemDropdownFieldLabel => 'Label';

  @override
  String get designSystemDropdownInputLabel => 'Eingabe';

  @override
  String get designSystemDropdownListTitle => 'Dropdown-Liste';

  @override
  String get designSystemDropdownMultiselectInputLabel => 'Teams auswählen';

  @override
  String get designSystemDropdownMultiselectTitle => 'Mehrfachauswahl';

  @override
  String get designSystemDropdownOptionAnalytics => 'Analytics';

  @override
  String get designSystemDropdownOptionBackend => 'Backend';

  @override
  String get designSystemDropdownOptionDesign => 'Design';

  @override
  String get designSystemDropdownOptionFrontend => 'Frontend';

  @override
  String get designSystemDropdownOptionGrowth => 'Growth';

  @override
  String get designSystemDropdownOptionMobile => 'Mobile';

  @override
  String get designSystemDropdownOptionQa => 'QA';

  @override
  String get designSystemErrorLabel => 'Fehler';

  @override
  String get designSystemFileUploadClickLabel => 'Zum Hochladen klicken';

  @override
  String get designSystemFileUploadCompleteLabel => 'Fertig';

  @override
  String get designSystemFileUploadDefaultLabel => 'Standard';

  @override
  String get designSystemFileUploadDragLabel => 'oder per Drag & Drop';

  @override
  String get designSystemFileUploadDropZoneSectionTitle => 'Ablagezone';

  @override
  String get designSystemFileUploadErrorLabel => 'Fehler';

  @override
  String get designSystemFileUploadFailedText => 'Upload fehlgeschlagen';

  @override
  String get designSystemFileUploadHintText =>
      'SVG, PNG, JPG oder GIF (max. 800×400px)';

  @override
  String get designSystemFileUploadHoverLabel => 'Hover';

  @override
  String get designSystemFileUploadItemSectionTitle => 'Datei-Elemente';

  @override
  String get designSystemFileUploadRetryLabel => 'Erneut versuchen';

  @override
  String get designSystemFileUploadUploadingLabel => 'Wird hochgeladen';

  @override
  String get designSystemFilledLabel => 'Gefüllt';

  @override
  String get designSystemHeaderApiDocumentationLabel => 'API-Dokumentation';

  @override
  String get designSystemHeaderBackActionLabel => 'Zurück';

  @override
  String get designSystemHeaderDesktopSectionTitle => 'Desktop';

  @override
  String get designSystemHeaderHelpActionLabel => 'Hilfe';

  @override
  String get designSystemHeaderMobileSectionTitle => 'Mobil';

  @override
  String get designSystemHeaderNotificationsActionLabel => 'Benachrichtigungen';

  @override
  String get designSystemHeaderSearchActionLabel => 'Suchen';

  @override
  String get designSystemHorizontalLabel => 'Horizontal';

  @override
  String get designSystemHoverLabel => 'Hover';

  @override
  String get designSystemInfoLabel => 'Info';

  @override
  String get designSystemInputErrorSample => 'Dieses Feld ist erforderlich';

  @override
  String get designSystemInputHelperSample => 'Gib deinen Namen ein';

  @override
  String get designSystemInputHintSample => 'Platzhalter...';

  @override
  String get designSystemInputLabelSample => 'Label';

  @override
  String get designSystemInputVariantsTitle => 'Eingabefeld-Varianten';

  @override
  String get designSystemInputWithErrorLabel => 'Mit Fehler';

  @override
  String get designSystemInputWithHelperLabel => 'Mit Hilfstext';

  @override
  String get designSystemInputWithIconsLabel => 'Mit Symbolen';

  @override
  String get designSystemListItemActivatedLabel => 'Aktiviert';

  @override
  String get designSystemListItemOneLineLabel => 'Einzeilig';

  @override
  String get designSystemListItemSubtitleSample => 'Untertitel';

  @override
  String get designSystemListItemTitleSample => 'Titel';

  @override
  String get designSystemListItemTwoLinesLabel => 'Zweizeilig';

  @override
  String get designSystemListItemVariantsTitle => 'Listenelement-Varianten';

  @override
  String get designSystemListItemWithDividerLabel => 'Mit Trennlinie';

  @override
  String get designSystemMediumLabel => 'Mittel';

  @override
  String designSystemMyDailyDurationHoursMinutesCompact(
    int hours,
    int minutes,
  ) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get designSystemNavigationCollapsedLabel => 'Eingeklappt';

  @override
  String get designSystemNavigationDailyFilterSectionTitle => 'Tagesfilter';

  @override
  String get designSystemNavigationExpandedLabel => 'Ausgeklappt';

  @override
  String get designSystemNavigationFilterByBlockLabel => 'Nach Block filtern';

  @override
  String get designSystemNavigationHikingLabel => 'Wandern';

  @override
  String get designSystemNavigationHolidayLabel => 'Urlaub';

  @override
  String get designSystemNavigationInsightsLabel => 'Einblicke';

  @override
  String get designSystemNavigationLottiTasksLabel => 'Lotti-Aufgaben';

  @override
  String get designSystemNavigationMyDailyLabel => 'Mein Tag';

  @override
  String get designSystemNavigationNewLabel => 'Neu';

  @override
  String get designSystemNavigationPlaceholderLabel => 'Platzhalter';

  @override
  String get designSystemNavigationSidebarSectionTitle => 'Sidebar-Varianten';

  @override
  String get designSystemNavigationSubComponentsSectionTitle =>
      'Unterkomponenten';

  @override
  String get designSystemNavigationTabBarSectionTitle => 'Tableisten-Varianten';

  @override
  String get designSystemPressedLabel => 'Gedrückt';

  @override
  String get designSystemProgressBarChunkyLabel => 'Chunky';

  @override
  String get designSystemProgressBarLabelAndPercentageLabel =>
      'Label + Prozent';

  @override
  String get designSystemProgressBarLabelOnlyLabel => 'Nur Label';

  @override
  String get designSystemProgressBarOffLabel => 'Aus';

  @override
  String get designSystemProgressBarPercentageOnlyLabel => 'Prozent';

  @override
  String get designSystemProgressBarQuestBarLabel => 'Quest-Leiste';

  @override
  String get designSystemProgressBarQuestLabel => 'Mega-Preis-Label';

  @override
  String get designSystemProgressBarSampleLabel => 'Progress-Bar-Label';

  @override
  String get designSystemRadioButtonLabel => 'Radio-Button';

  @override
  String get designSystemScrollbarSizesTitle => 'Scrollbar-Größen';

  @override
  String get designSystemSearchClearLabel => 'Suche löschen';

  @override
  String get designSystemSearchFilledText => 'Lotti-Suche';

  @override
  String get designSystemSearchHintLabel => 'Benutzer eingeben';

  @override
  String get designSystemSelectedLabel => 'Ausgewählt';

  @override
  String get designSystemSizeScaleTitle => 'Größenskala';

  @override
  String get designSystemSmallLabel => 'Klein';

  @override
  String get designSystemSpinnerPlainLabel => 'Ohne Spur';

  @override
  String get designSystemSpinnerSkeletonPulseLabel => 'Puls';

  @override
  String get designSystemSpinnerSkeletonsTitle => 'Skelette';

  @override
  String get designSystemSpinnerSkeletonWaveLabel => 'Welle';

  @override
  String get designSystemSpinnerSpinnersTitle => 'Spinner';

  @override
  String get designSystemSpinnerTrackLabel => 'Mit Spur';

  @override
  String designSystemSplitButtonDropdownSemantics(String label) {
    return 'Optionen für $label öffnen';
  }

  @override
  String get designSystemStateMatrixTitle => 'Statusmatrix';

  @override
  String get designSystemSuccessLabel => 'Erfolg';

  @override
  String get designSystemTabBarTitle => 'Tab-Leiste';

  @override
  String get designSystemTabPendingLabel => 'Ausstehend';

  @override
  String get designSystemTaskListBlockedLabel => 'Blockiert';

  @override
  String get designSystemTaskListDefaultLabel => 'Standard';

  @override
  String get designSystemTaskListHoverLabel => 'Hover';

  @override
  String get designSystemTaskListItemSectionTitle => 'Aufgabenlisten-Varianten';

  @override
  String get designSystemTaskListOnHoldLabel => 'Pausiert';

  @override
  String get designSystemTaskListOpenLabel => 'Offen';

  @override
  String get designSystemTaskListPressedLabel => 'Gedrückt';

  @override
  String get designSystemTaskListSampleTime => '8:00-9:30';

  @override
  String get designSystemTaskListSampleTitle => 'Benutzertest';

  @override
  String get designSystemTaskListWithDividerLabel => 'Mit Trennlinie';

  @override
  String get designSystemTextareaErrorSample => 'Dieses Feld ist erforderlich';

  @override
  String get designSystemTextareaHelperSample => 'Gib deine Nachricht hier ein';

  @override
  String get designSystemTextareaHintSample => 'Etwas eingeben...';

  @override
  String get designSystemTextareaLabelSample => 'Label';

  @override
  String get designSystemTextareaVariantsTitle => 'Textarea-Varianten';

  @override
  String get designSystemTextareaWithCounterLabel => 'Mit Zähler';

  @override
  String get designSystemTextareaWithErrorLabel => 'Mit Fehler';

  @override
  String get designSystemTextareaWithHelperLabel => 'Mit Hilfstext';

  @override
  String get designSystemTimePickerFormatsTitle => 'Zeitformate';

  @override
  String get designSystemTimePickerTwelveHourLabel => '12-Stunden';

  @override
  String get designSystemTimePickerTwentyFourHourLabel => '24-Stunden';

  @override
  String get designSystemTitleOnlyVariantTitle => 'Nur-Titel-Variante';

  @override
  String get designSystemToastDetailsLabel => 'Benachrichtigungsdetails';

  @override
  String get designSystemToggleLabel => 'Toggle-Label';

  @override
  String get designSystemTooltipIconMessageSample =>
      'Hilfreiche Informationen zu diesem Feld';

  @override
  String get designSystemTooltipIconVariantsTitle => 'Tooltip-Symbol';

  @override
  String get designSystemUndoLabel => 'Rückgängig';

  @override
  String get designSystemVariantMatrixTitle => 'Variantenmatrix';

  @override
  String get designSystemVerticalLabel => 'Vertikal';

  @override
  String get designSystemWarningLabel => 'Warnung';

  @override
  String get designSystemWeeklyCalendarLabel => 'Wochenkalender';

  @override
  String get designSystemWithLabelLabel => 'Mit Label';

  @override
  String get desktopEmptyStateSelectDashboard =>
      'Wähle ein Dashboard aus, um Details anzuzeigen';

  @override
  String get desktopEmptyStateSelectProject =>
      'Wähle ein Projekt aus, um Details anzuzeigen';

  @override
  String get desktopEmptyStateSelectTask =>
      'Wähle eine Aufgabe aus, um Details anzuzeigen';

  @override
  String deviceDeletedSuccess(String deviceName) {
    return '$deviceName aus Sync entfernt';
  }

  @override
  String get deviceDeleteFailedGeneric =>
      'Das Gerät konnte nicht entfernt werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String deviceDeleteQuestion(String deviceName) {
    return '$deviceName aus deinem Sync-Konto entfernen? Das Gerät wird abgemeldet und muss neu gekoppelt werden, bevor es wieder synchronisieren kann.';
  }

  @override
  String get doneButton => 'Fertig';

  @override
  String get editLinkTypeCounterpartLabel => 'Verknüpfte Aufgabe';

  @override
  String get editLinkTypeFailedMessage =>
      'Die Beziehung konnte nicht aktualisiert werden. Bitte versuch es erneut.';

  @override
  String get editLinkTypeTitle => 'Beziehung bearbeiten';

  @override
  String get editLinkTypeTooltip => 'Beziehung bearbeiten';

  @override
  String get editMenuTitle => 'Bearbeiten';

  @override
  String get editorDiscardChanges => 'Änderungen verwerfen';

  @override
  String get editorInsertDivider => 'Trennlinie einfügen';

  @override
  String get editorMoreFormatting => 'Mehr Formatierung';

  @override
  String get editorPlaceholder => 'Notizen eingeben...';

  @override
  String get embeddingSelectAll => 'Alle auswählen';

  @override
  String get embeddingUnselectAll => 'Alle abwählen';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Aus vorgefertigten Prompt-Vorlagen wählen';

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
  String get entryTypeLabelCheckIn => 'Check-in';

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
  String get eventNameLabel => 'Ereignis:';

  @override
  String get eventsAddCoverPhoto => 'Titelbild hinzufügen';

  @override
  String get eventsAddLabel => 'Hinzufügen';

  @override
  String get eventsChangeCover => 'Titelbild ändern';

  @override
  String get eventsDeleteEvent => 'Ereignis löschen';

  @override
  String get eventsFilterAll => 'Alle';

  @override
  String eventsMetricPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos',
      one: '1 Foto',
    );
    return '$_temp0';
  }

  @override
  String eventsMetricTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben',
      one: '1 Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String get eventsNewEvent => 'Neues Ereignis';

  @override
  String get eventsPageTitle => 'Ereignisse';

  @override
  String get eventsPhotosSection => 'Fotos';

  @override
  String get eventsRecapAwaitingContent =>
      'Füge ein Foto oder eine Notiz hinzu, dann erscheint hier die Zusammenfassung.';

  @override
  String get eventsRecapUnavailable =>
      'Die Zusammenfassung konnte nicht geladen werden.';

  @override
  String get eventsRegenerateSummary => 'Zusammenfassung neu erstellen';

  @override
  String get eventsSearchHint => 'Ereignisse suchen';

  @override
  String get eventsSectionUpcoming => 'Bevorstehend';

  @override
  String get eventsStatusCancelled => 'Abgesagt';

  @override
  String get eventsStatusCompleted => 'Abgeschlossen';

  @override
  String get eventsStatusMissed => 'Verpasst';

  @override
  String get eventsStatusOngoing => 'Läuft';

  @override
  String get eventsStatusPlanned => 'Geplant';

  @override
  String get eventsStatusPostponed => 'Verschoben';

  @override
  String get eventsStatusRescheduled => 'Neu geplant';

  @override
  String get eventsStatusTentative => 'Vorläufig';

  @override
  String get eventsSummaryTitle => 'Zusammenfassung';

  @override
  String get eventsTasksEmpty =>
      'Verknüpfe eine Vorbereitungs- oder Folgeaufgabe';

  @override
  String get eventsTasksSection => 'Aufgaben';

  @override
  String get eventsTimelineEmpty =>
      'Füge Fotos, Notizen oder eine Sprachnotiz hinzu';

  @override
  String get eventsTimelineSection => 'Zeitleiste';

  @override
  String get eventsTitleHint => 'Ereignistitel';

  @override
  String get eventsVoiceNote => 'Sprachnotiz';

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
  String get filterSelectionNoMatches => 'Keine Treffer';

  @override
  String get geminiThinkingModeHighDescription =>
      'Tiefstes Reasoning; kann Latenz und Kosten erhöhen.';

  @override
  String get geminiThinkingModeHighLabel => 'Hoch';

  @override
  String get geminiThinkingModeLowDescription =>
      'Wenig Reasoning für schnelle Alltagsprompts.';

  @override
  String get geminiThinkingModeLowLabel => 'Niedrig';

  @override
  String get geminiThinkingModeMediumDescription =>
      'Ausgewogenes Reasoning für sorgfältigere Antworten.';

  @override
  String get geminiThinkingModeMediumLabel => 'Mittel';

  @override
  String get geminiThinkingModeMinimalDescription =>
      'Schnellste Einstellung; Gemini kann bei komplexen Prompts trotzdem kurz denken.';

  @override
  String get geminiThinkingModeMinimalLabel => 'Minimal';

  @override
  String get generateCoverArt => 'Titelbild generieren';

  @override
  String get generateCoverArtSubtitle =>
      'Bild aus einer Beschreibung erstellen';

  @override
  String goalAgentLifetimeTimePill(String duration) {
    return '$duration Denkzeit';
  }

  @override
  String goalAgentLifetimeTimeTooltip(String calls) {
    return 'Gesamtzeit, die das Modell dieses Agenten gearbeitet hat, über $calls Aufrufe.';
  }

  @override
  String get goalAssessmentHistoryTitle => 'Tägliche Reflexionen';

  @override
  String get goalAssessmentImproving => 'Verbessert sich';

  @override
  String get goalAssessmentMeasuredReadOnly =>
      'Gemessen von Lotti – dieser Teil kann nicht bearbeitet werden.';

  @override
  String get goalAssessmentMeasuredTitle => 'Was Lotti gemessen hat';

  @override
  String get goalAssessmentMet => 'Erreicht';

  @override
  String get goalAssessmentMissed => 'Verpasst';

  @override
  String get goalAssessmentMixed => 'Gemischt';

  @override
  String get goalAssessmentNote => 'Hinweis (optional)';

  @override
  String get goalAssessmentPerDimension =>
      'Einzelne Dimensionen bewerten (optional)';

  @override
  String get goalAssessmentRecorded => 'Aufgezeichnet';

  @override
  String goalAssessmentRecordFor(String dayName) {
    return 'Eintrag für $dayName';
  }

  @override
  String get goalAssessmentReflectToday => 'Über den heutigen Tag nachdenken';

  @override
  String goalAssessmentSpecVersion(int version) {
    return 'Ziel v$version angewendet';
  }

  @override
  String goalAssessmentSuggestedProvenance(String agentName) {
    return 'Von $agentName vorgeschlagen, von dir angenommen';
  }

  @override
  String get goalAssessmentSuggestedProvenanceGeneric =>
      'Von deinem Ziel-Agenten vorgeschlagen, von dir angenommen';

  @override
  String get goalAssessmentSuggestionHint =>
      'Vorschlag aus den gemessenen Daten — ändere ihn, wenn du anderer Meinung bist.';

  @override
  String get goalAssessmentUserProvenance => 'Von dir bewertet';

  @override
  String get goalAssessmentVerdictTitle => 'Wie lief der Tag?';

  @override
  String goalAttainmentLabel(int percent) {
    return '$percent % des Ziels';
  }

  @override
  String get goalBannerActionFailed =>
      'Das wurde nicht gespeichert — bitte versuch es noch einmal.';

  @override
  String get goalBannerDismissForDay => 'Für heute ausblenden';

  @override
  String goalBannerHiddenFromBar(String countdown) {
    return 'Aus der Bannerleiste ausgeblendet · wieder in $countdown';
  }

  @override
  String get goalBannerRateTooltip => 'Dieses Banner bewerten';

  @override
  String get goalBannerRatingSkip => 'Überspringen';

  @override
  String get goalBannerRatingTitle => 'Wie fandest du dieses Banner?';

  @override
  String goalBannerSemanticLabel(String goalTitle) {
    return 'Ziel-Banner für $goalTitle';
  }

  @override
  String get goalBannerSnoozeEightHours => '8 Stunden';

  @override
  String get goalBannerSnoozeLabel => 'Pausieren';

  @override
  String get goalBannerSnoozeOneHour => '1 Stunde';

  @override
  String get goalBannerSnoozePrompt => 'Wann soll es wieder erscheinen?';

  @override
  String get goalBannerSnoozeSixHours => '6 Stunden';

  @override
  String get goalBannerSnoozeThreeHours => '3 Stunden';

  @override
  String get goalBannerSnoozeTitle => 'Banner pausieren';

  @override
  String goalChatEmpty(String agentName) {
    return 'Beginne ein Gespräch mit $agentName.';
  }

  @override
  String get goalChatFailed => 'Das wurde nicht gesendet.';

  @override
  String get goalChatHistoryError =>
      'Dieses Gespräch konnte gerade nicht geladen werden.';

  @override
  String goalChatMessageFooter(Object author, Object time) {
    return '$author · $time';
  }

  @override
  String goalChatMessageSemantics(String author, String time, String message) {
    return '$author, $time: $message';
  }

  @override
  String get goalChatPageTitle => 'Gespräch';

  @override
  String goalChatPlaceholder(String agentName) {
    return 'Sprich mit $agentName…';
  }

  @override
  String goalChatResponding(String agentName) {
    return '$agentName antwortet…';
  }

  @override
  String get goalChatTalkToAgent => 'Mit dem Agenten sprechen';

  @override
  String goalChatWhyPrefill(String status) {
    return 'Warum ist dieses Ziel gerade $status?';
  }

  @override
  String get goalChatYou => 'Du';

  @override
  String get goalCoarseHealthBehind => 'Im Rückstand';

  @override
  String get goalCoarseHealthHealthy => 'Gesund';

  @override
  String get goalCoarseHealthNotEnoughData => 'Zu wenig Daten';

  @override
  String get goalCoarseHealthRestarting => 'Startet neu';

  @override
  String get goalCompositeLastSevenDays => 'Letzte 7 Tage';

  @override
  String goalCompositeProgressSummary(
    int metCount,
    int dimensionCount,
    int requiredCount,
  ) {
    return 'Gestern: $metCount von $dimensionCount Dimensionen · $requiredCount nötig.';
  }

  @override
  String get goalCreateFailed =>
      'Das Ziel konnte nicht gespeichert werden — versuch es noch einmal.';

  @override
  String get goalCreateHabitCountLabel => 'Mal pro 7 Tage (je Gewohnheit)';

  @override
  String get goalCreateHabitCountRange =>
      'Die Anzahl muss zwischen 1 und 7 liegen.';

  @override
  String get goalCreateHabitsLabel => 'Zu beobachtende Gewohnheiten';

  @override
  String get goalCreateHabitsLoadFailed =>
      'Deine Gewohnheiten konnten gerade nicht geladen werden — versuch es gleich noch einmal.';

  @override
  String get goalCreateNameLabel => 'Name';

  @override
  String get goalCreateSaveButton => 'Agent erstellen';

  @override
  String get goalCreateStatementLabel => 'Zielbeschreibung';

  @override
  String get goalCreateStepsTargetLabel => 'Durchschnittliche Schritte pro Tag';

  @override
  String get goalCreateTypeHabits => 'Gewohnheits-Routine';

  @override
  String get goalCreateTypeSteps => 'Tägliche Schritte (rollierende Woche)';

  @override
  String get goalCreateValidationMissing =>
      'Gib dem Ziel einen Namen und mindestens ein Kriterium.';

  @override
  String goalDaysToRecover(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage bis zur Erholung',
      one: '1 Tag bis zur Erholung',
    );
    return '$_temp0';
  }

  @override
  String get goalDeleteConfirmButton => 'Ziel löschen';

  @override
  String get goalDeleteDialogContent =>
      'Damit wird der Ziel-Agent stillgelegt und auf allen Geräten aus deiner Liste entfernt. Das lässt sich nicht rückgängig machen.';

  @override
  String get goalDeleteDialogTitle => 'Dieses Ziel löschen?';

  @override
  String get goalDeleteMenuItem => 'Ziel löschen';

  @override
  String goalDetailAlsoInGoal(String goals) {
    return 'Auch in $goals';
  }

  @override
  String get goalDetailAskWhy => 'Warum?';

  @override
  String get goalDetailCompletionRateTitle => 'Erfolgsquote · dieses Ziel';

  @override
  String get goalDetailGoalDaysTitle => 'Zieltage';

  @override
  String get goalDetailHealthUnavailable =>
      'Der Zustand dieses Ziels konnte gerade nicht geladen werden.';

  @override
  String get goalDetailNoReport =>
      'Noch kein Bericht — der Agent meldet sich nach der ersten relevanten Änderung.';

  @override
  String get goalDetailNotFound => 'Diesen Ziel-Agenten gibt es nicht mehr.';

  @override
  String goalDetailReadAsOf(String ago) {
    return 'Stand: $ago';
  }

  @override
  String get goalDetailSignalsTitle => 'Signale';

  @override
  String get goalDetailThisWeekTitle => 'Diese Woche';

  @override
  String get goalDetailTimelineTitle => 'Interaktionen';

  @override
  String get goalDetailUpdateFailed => 'Letzte Aktualisierung fehlgeschlagen';

  @override
  String goalDetailUpdateFailedWithReason(String reason) {
    return 'Letzte Aktualisierung fehlgeschlagen — $reason';
  }

  @override
  String get goalDetailWatchingSignals =>
      'Die oben aufgeführten Signale werden innerhalb von Sekunden aktualisiert. Dein Agent sieht nur die hier aufgeführten Signale.';

  @override
  String get goalDimensionCategoryTimeSource => 'Verfolgte Kategoriezeit';

  @override
  String goalDimensionHabitReading(int currentCount, int targetCount) {
    return '$currentCount von $targetCount in diesem Zeitraum';
  }

  @override
  String get goalDimensionHabitSource => 'Gewohnheitsvervollständigungen';

  @override
  String get goalDimensionHealthSource => 'Gesundheitsdaten';

  @override
  String get goalDimensionImprovingNote =>
      'Noch nicht am Ziel, aber der letzte Wert ging in die richtige Richtung.';

  @override
  String get goalDimensionLabelTimeSource => 'Nach Label erfasste Zeit';

  @override
  String get goalDimensionMeasurableSource => 'Deine Messgröße';

  @override
  String goalDimensionMetricReading(String currentValue, String targetValue) {
    return '$currentValue von $targetValue';
  }

  @override
  String goalDimensionMetricReadingWithUnit(
    String currentValue,
    String targetValue,
    String unitName,
  ) {
    return '$currentValue von $targetValue $unitName';
  }

  @override
  String get goalDimensionNeedsAttentionNote =>
      'In diesem Zeitraum hinter dem Ziel.';

  @override
  String get goalDimensionNeedsAttentionStatus => 'Braucht Aufmerksamkeit';

  @override
  String get goalDimensionNoDataNote =>
      'Es liegen noch nicht genügend Daten vor, um diese Dimension beurteilen zu können.';

  @override
  String get goalDimensionOnTargetTodayNote =>
      'Der neueste Messwert von heute liegt im Zielbereich; mach so weiter.';

  @override
  String get goalDimensionOnTargetTodayStatus => 'Heute im Zielbereich';

  @override
  String get goalDimensionOnTrackNote =>
      'Diese Dimension ist derzeit auf Kurs.';

  @override
  String get goalDimensionOnTrackStatus => 'Auf dem richtigen Weg';

  @override
  String get goalDimensionRecordedByAgent =>
      'Von dir gesagt und nach deiner Zustimmung aufgezeichnet.';

  @override
  String goalDimensionRecordedByAgentDetails(
    String agentName,
    String recordedAt,
  ) {
    return 'Von dir gesagt, von $agentName aufgezeichnet, $recordedAt';
  }

  @override
  String get goalFormAddDimension => 'Dimension hinzufügen';

  @override
  String get goalFormAddSignal => 'Signal hinzufügen';

  @override
  String get goalFormBloodPressureSource =>
      'Systolisch und diastolisch · mmHg · 7-Tage-Durchschnitt';

  @override
  String goalFormCategoryTimeCadence(
    String categoryName,
    String direction,
    String target,
  ) {
    String _temp0 = intl.Intl.selectLogic(
      target,
      {
        '1': 'Stunde',
        'other': 'Stunden',
      },
    );
    return '$categoryName: $direction $target $_temp0 pro rollierende 7 Tage';
  }

  @override
  String get goalFormCategoryTimeSource =>
      'Erfasste Zeit · Stunden pro rollierende 7 Tage';

  @override
  String get goalFormCategoryTimeTarget => 'Stunden pro rollierende 7 Tage';

  @override
  String get goalFormChooseHabit => 'Vorhandene Gewohnheit wählen';

  @override
  String get goalFormCompositeAll => 'Alle Maße';

  @override
  String get goalFormCompositeAllHint =>
      'Am strengsten – jede Dimension muss erfüllt sein.';

  @override
  String get goalFormCompositeAny => 'Eine beliebige Dimension';

  @override
  String get goalFormCompositeAnyHint =>
      'Am lockersten – eine erfüllte Dimension genügt.';

  @override
  String goalFormCompositeAtLeast(int requiredCount, int dimensionCount) {
    return 'Zumindest $requiredCount von $dimensionCount';
  }

  @override
  String get goalFormCompositeAtLeastHint =>
      'Wähle, wie viele Dimensionen erfüllt sein müssen.';

  @override
  String get goalFormCompositeRule => 'Wie dieses Ziel zusammenkommt';

  @override
  String get goalFormConfirmTitle => 'Lern deinen Agenten kennen';

  @override
  String get goalFormContinue => 'Weiter';

  @override
  String get goalFormCostHonesty =>
      'Verwendet deinen konfigurierten KI-Anbieter. Was es gekostet hat, siehst du jederzeit auf der Seite dieses Ziels.';

  @override
  String get goalFormDecreaseTarget => 'Wochenziel verringern';

  @override
  String get goalFormDefaultPersonaName => 'Juno';

  @override
  String get goalFormDiastolicTarget => 'Diastolisch (mmHg)';

  @override
  String get goalFormDirectionAtLeast => 'Mindestens';

  @override
  String get goalFormDirectionAtMost => 'Höchstens';

  @override
  String get goalFormEditTitle => 'Ziel bearbeiten';

  @override
  String goalFormEditVersion(int version) {
    return 'Damit beginnt Version $version. Dein Verlauf bleibt erhalten.';
  }

  @override
  String get goalFormExampleGym => 'zweimal pro Woche ins Fitnessstudio';

  @override
  String get goalFormExampleHealth => 'meinen Blutdruck im Griff behalten';

  @override
  String get goalFormExampleRead => 'vor dem Schlafengehen lesen';

  @override
  String get goalFormExampleWalk => 'mehr spazieren gehen';

  @override
  String get goalFormFooter =>
      'Du kannst diesen Agenten jederzeit umbenennen, neu ausrichten, pausieren oder löschen.';

  @override
  String get goalFormGenericIntentionWords =>
      'und,konsequent,konstant,täglich,tag,tage,tagen,jeder,jede,jeden,ziel,gewohnheit,monat,monatlich,monate,pro,regelmäßig,routine,zeit,mal,woche,wöchentlich,wochen,jahr,jährlich,jahre,jedes';

  @override
  String get goalFormGoalNameLabel => 'Name des Ziels';

  @override
  String goalFormHabitCadence(String habit, int count) {
    return '$habit ($count×/Woche)';
  }

  @override
  String get goalFormHabitSignal => 'zählt, wenn du die Gewohnheit abhakst';

  @override
  String get goalFormHealthBloodPressureDiastolic => 'Diastolischer Blutdruck';

  @override
  String get goalFormHealthBloodPressureSystolic => 'Systolischer Blutdruck';

  @override
  String goalFormHealthCadence(
    String healthName,
    String direction,
    String target,
    String unitName,
  ) {
    return '$healthName: 7-Tage-Durchschnitt $direction $target $unitName';
  }

  @override
  String get goalFormHealthData => 'Gesundheitsdaten';

  @override
  String get goalFormHealthReadingsSignal => 'nutzt deine gemessenen Werte';

  @override
  String goalFormHealthSource(String unitName) {
    return 'Gesundheitsdaten · $unitName · 7-Tage-Durchschnitt';
  }

  @override
  String goalFormHealthTarget(String unitName) {
    return 'Ziel ($unitName)';
  }

  @override
  String get goalFormHealthWeight => 'Gewicht';

  @override
  String get goalFormIncreaseTarget => 'Wochenziel erhöhen';

  @override
  String get goalFormIntentionHelper =>
      'Sag es auf deine Art — so wird dein Agent darüber sprechen.';

  @override
  String get goalFormIntentionHint =>
      'Zweimal pro Woche ins Fitnessstudio gehen und meine Morgenübungen beibehalten.';

  @override
  String get goalFormIntentionPrompt => 'Worauf möchtest du hinarbeiten?';

  @override
  String goalFormLabelTimeCadence(
    String labelName,
    String direction,
    String target,
  ) {
    String _temp0 = intl.Intl.selectLogic(
      target,
      {
        '1': 'Stunde',
        'other': 'Stunden',
      },
    );
    return '$labelName: $direction $target $_temp0 pro Tag';
  }

  @override
  String get goalFormLabelTimeSource =>
      'Erfasste Zeit mit diesem Label · Stunden pro Tag';

  @override
  String get goalFormLabelTimeTarget => 'Stunden pro Tag';

  @override
  String get goalFormMappingIntro =>
      'Ich kann nur coachen, was ich sehe. Diese Signale sind meine Augen.';

  @override
  String get goalFormMappingTitle => 'Das kann ich beobachten';

  @override
  String goalFormMeasurableCadence(String measurableName, String target) {
    return '$measurableName: $target pro rollierende Woche';
  }

  @override
  String goalFormMeasurableSource(String unitName) {
    return 'Deine Messgröße · $unitName';
  }

  @override
  String get goalFormMeasurementVerbs =>
      'messen,misst,gemessen,messung,tracken,trackt,getrackt,tracking,notieren,notiert,notiz,protokollieren,protokolliert,protokoll,prüfen,prüft,geprüft,kontrollieren,kontrolliert,kontrolle,erfassen,erfasst,überwachen,überwacht,aufzeichnen,aufgezeichnet,dokumentieren,dokumentiert,eintragen,eingetragen';

  @override
  String get goalFormNoHabits => 'Es gibt noch keine aktiven Gewohnheiten.';

  @override
  String get goalFormOpenHabits => 'Erst eine Gewohnheit erstellen';

  @override
  String get goalFormPersonaLabel => 'Name des Agenten';

  @override
  String get goalFormPreservedCriteriaSummary =>
      'Die vorhandenen Signale und der Zeitplan bleiben unverändert erhalten.';

  @override
  String goalFormProgress(int step, int total) {
    return 'Schritt $step von $total';
  }

  @override
  String get goalFormRefusalBody =>
      'Ich müsste raten, und ich coache nicht auf Vermutungen. Wähl ein beobachtbares Ersatzsignal oder formuliere dein Vorhaben neu.';

  @override
  String get goalFormRefusalFooter =>
      'Ein Agent, der dein Ziel nicht sehen kann, sagt das — er tut nie so als ob.';

  @override
  String get goalFormRefusalTitle =>
      'Ich kann dieses Vorhaben nicht sehen — nichts Beobachtbares zeigt mir, dass es passiert ist.';

  @override
  String goalFormRestatement(String signals) {
    return 'Ich beobachte $signals über eine rollierende Woche — und melde mich nur, wenn es hilft.';
  }

  @override
  String get goalFormRollingNote =>
      'Rollierende Woche — immer die letzten 7 Tage. Die Häufigkeit gilt je Signal; keine toten Wochenenden, keine verlorenen Wochen.';

  @override
  String get goalFormSaveChanges => 'Neue Version speichern';

  @override
  String get goalFormStatementLabel => 'Dein Ziel, in deinen Worten';

  @override
  String goalFormStepsCadence(String target) {
    return '$target Schritte pro Tag';
  }

  @override
  String get goalFormStepsDailyTarget => 'Tagesziel';

  @override
  String get goalFormStepsSignal => 'automatische Schrittzählung';

  @override
  String get goalFormSuggestedSignals => 'Vorgeschlagen';

  @override
  String get goalFormSystolicTarget => 'Systolisch (mmHg)';

  @override
  String get goalFormUnsupportedCriteria =>
      'Dieses Ziel verwendet eine Zuordnung, die dieser Editor nicht sicher ändern kann. Namen, Vorhaben und Agent kannst du trotzdem umbenennen.';

  @override
  String get goalFormValidationIdentity =>
      'Gib dem Ziel und seinem Agenten einen Namen.';

  @override
  String get goalFormValidationIntention =>
      'Beschreib zuerst, worauf du hinarbeiten möchtest.';

  @override
  String get goalFormValidationMapping =>
      'Wähl mindestens ein Signal, das der Agent wirklich beobachten kann.';

  @override
  String get goalFormValidationPersona => 'Gib deinem Agenten einen Namen.';

  @override
  String get goalFormValidationTarget => 'Leg ein Ziel fest, um fortzufahren.';

  @override
  String get goalFormValidationTitle => 'Gib deinem Ziel einen Namen.';

  @override
  String goalFormWeeklyTarget(int count) {
    return '$count×/Woche';
  }

  @override
  String get goalFormYourMeasurables => 'Deine Messgrößen';

  @override
  String get goalHabitCheckOffAction => 'Erledigt';

  @override
  String goalHabitCheckOffSuggestion(String dimension) {
    return '$dimension heute erfasst — Gewohnheit abhaken?';
  }

  @override
  String get goalHealthTrendDown => 'Fällt ab';

  @override
  String get goalHealthTrendFlat => 'Bleibt stabil';

  @override
  String get goalHealthTrendUp => 'Steigt';

  @override
  String get goalLogTodayLinkedHint =>
      'Aktualisiert sich aus der verknüpften Quelle';

  @override
  String get goalLogTodayTitle => 'Heute erfassen';

  @override
  String goalMetricBarSemantics(
    String status,
    Object date,
    Object value,
    Object target,
  ) {
    String _temp0 = intl.Intl.selectLogic(
      status,
      {
        'missing': '$date: kein Wert; Ziel $target',
        'met': '$date: $value; Ziel $target; erreicht',
        'other': '$date: $value; Ziel $target; nicht erreicht',
      },
    );
    return '$_temp0';
  }

  @override
  String get goalNudgeStatusDismissed => 'Verworfen';

  @override
  String get goalNudgeStatusExpired => 'Abgelaufen';

  @override
  String get goalNudgeStatusRetired => 'Zurückgezogen';

  @override
  String get goalNudgeStatusSuperseded => 'Überholt';

  @override
  String goalPatternBusiestHour(String hour) {
    return 'Die meisten Sitzungen beginnen gegen $hour:00. Öffne Insights für eine genauere Analyse.';
  }

  @override
  String get goalPatternTitle => 'Zeitmuster';

  @override
  String get goalPendingProposalBadge => 'Vorschlag wartet auf Prüfung';

  @override
  String get goalProgressAgesOut => 'fällt heute Abend raus';

  @override
  String get goalProgressAtRate => 'im Soll';

  @override
  String get goalProgressCaption =>
      'letzte 7 Tage · verschiebt sich um Mitternacht';

  @override
  String get goalProgressCompactCaption => 'verschiebt sich um Mitternacht';

  @override
  String goalProgressCompactSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erfolgreiche Tage im Sieben-Tage-Fenster',
      one: '1 erfolgreicher Tag im Sieben-Tage-Fenster',
      zero: 'Keine erfolgreichen Tage im Sieben-Tage-Fenster',
    );
    return '$_temp0';
  }

  @override
  String goalProgressDaysToHealthy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage bis gesund',
      one: '1 Tag bis gesund',
    );
    return '$_temp0';
  }

  @override
  String get goalProgressDone => 'erledigt · Ziel erreicht';

  @override
  String get goalProgressHabitDayNoEntry => 'Kein Eintrag';

  @override
  String goalProgressHabitDaySemantics(String date, String outcome) {
    return '$date: $outcome';
  }

  @override
  String goalProgressHabitTarget(int count) {
    return '$count× pro 7 Tage';
  }

  @override
  String goalProgressHabitTargetWindow(int count, String window) {
    return '$count× · $window';
  }

  @override
  String get goalProgressPartial => 'erledigt · Ziel noch offen';

  @override
  String get goalProgressStripLoading => 'Tagesübersicht wird noch geladen';

  @override
  String get goalProgressTitle => 'Diese rollierende Woche';

  @override
  String get goalProgressToday => 'heute';

  @override
  String get goalRecordOfferConflict =>
      'Du hast diese Messgröße an einem dieser Tage bereits protokolliert. Kläre vor dem Aufzeichnen, welcher Eintrag erhalten bleiben soll.';

  @override
  String get goalRecordOfferDeselectRow => 'Zeilenauswahl aufheben';

  @override
  String get goalRecordOfferDismiss => 'Verwerfen';

  @override
  String get goalRecordOfferEstimatedSplit =>
      'Geschätzte Aufteilung – bei Bedarf bearbeiten';

  @override
  String get goalRecordOfferIntro =>
      'Ich habe in deiner Aussage eine Menge gefunden. Prüfe die Werte, bevor etwas aufgezeichnet wird.';

  @override
  String get goalRecordOfferInvalidValue =>
      'Gib einen Wert größer als null ein.';

  @override
  String get goalRecordOfferNothingSelected =>
      'Wähle mindestens eine Zeile zum Aufzeichnen aus.';

  @override
  String goalRecordOfferOverline(String agentName, String measurableName) {
    return '$agentName BIETET AN · IN $measurableName EINTRAGEN';
  }

  @override
  String goalRecordOfferProvenance(String agentName) {
    return 'Von dir gesagt, von $agentName aufgezeichnet';
  }

  @override
  String goalRecordOfferReceipt(int entryCount, String agentName) {
    String _temp0 = intl.Intl.pluralLogic(
      entryCount,
      locale: localeName,
      other: '$entryCount Einträge',
      one: '1 Eintrag',
    );
    return 'Aufgezeichnet · $_temp0 · von dir gesagt, von $agentName aufgezeichnet';
  }

  @override
  String goalRecordOfferRecordMany(int entryCount) {
    String _temp0 = intl.Intl.pluralLogic(
      entryCount,
      locale: localeName,
      other: '$entryCount Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0 aufzeichnen';
  }

  @override
  String get goalRecordOfferRecordOne => 'Eintrag aufzeichnen';

  @override
  String get goalRecordOfferSelectRow => 'Zeile auswählen';

  @override
  String goalReliabilityWeeks(int achieved) {
    return '$achieved / 6 Wochen';
  }

  @override
  String get goalReportSectionChange => 'Letzte Änderung';

  @override
  String get goalReportSectionCoverage => 'Datenabdeckung';

  @override
  String get goalReportSectionStanding => 'Wie es steht';

  @override
  String get goalReportSectionWindow => 'Das größere Fenster';

  @override
  String get goalStatusAchieved => 'Erreicht';

  @override
  String get goalStatusAtRisk => 'Gefährdet';

  @override
  String get goalStatusInsufficientData => 'Keine Daten';

  @override
  String get goalStatusOffTrack => 'Vom Kurs ab';

  @override
  String get goalStatusOnTrack => 'Auf Kurs';

  @override
  String get goalStatusRecovering => 'Auf dem Weg zurück';

  @override
  String get goalWindowCalendarMonth => 'Kalendermonat';

  @override
  String get goalWindowCalendarWeek => 'Kalenderwoche';

  @override
  String goalWindowRollingDays(int count) {
    return 'rollierende $count Tage';
  }

  @override
  String get goalWindowSingleDay => 'ein einzelner Tag';

  @override
  String get goMenuTitle => 'Gehe zu';

  @override
  String get habitActiveFromLabel => 'Startdatum';

  @override
  String get habitActiveSwitchDescription =>
      'Wird auf der Gewohnheiten-Seite angezeigt';

  @override
  String get habitArchivedLabel => 'Archiviert';

  @override
  String get habitCategoryHint => 'Kategorie auswählen';

  @override
  String get habitCategoryLabel => 'Kategorie';

  @override
  String get habitCloseCompletionLabel => 'Gewohnheitserfassung schließen';

  @override
  String habitCompleteSemanticLabel(String habit) {
    return '$habit eintragen';
  }

  @override
  String get habitCompletionStatusCompleted => 'Erledigt';

  @override
  String get habitCompletionStatusFailed => 'Fehlgeschlagen';

  @override
  String get habitCompletionStatusOpen => 'Offen';

  @override
  String get habitCompletionStatusSkipped => 'Übersprungen';

  @override
  String get habitDashboardHint => 'Dashboard auswählen';

  @override
  String get habitDashboardLabel => 'Dashboard (optional)';

  @override
  String habitDayStatusSemantic(String habit, String status) {
    return '$habit, $status';
  }

  @override
  String get habitDeleteConfirm => 'Ja, diese Gewohnheit löschen';

  @override
  String get habitDeleteQuestion => 'Möchtest du diese Gewohnheit löschen?';

  @override
  String habitHeatmapDaySemantic(String date, int done, int total) {
    return '$date, $done von $total erledigt';
  }

  @override
  String get habitLogOtherDayHint => 'Halten, um einen anderen Tag einzutragen';

  @override
  String get habitNotRecordedLabel => 'Nicht erfasst';

  @override
  String get habitPriorityLabel => 'Priorität';

  @override
  String get habitsAboveGoal => 'Im Plan';

  @override
  String habitsActiveHabitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktive Gewohnheiten',
      one: '1 aktive Gewohnheit',
    );
    return '$_temp0';
  }

  @override
  String get habitsAllDoneToday => 'Heute alles erledigt';

  @override
  String get habitsChartUseDynamicBaseline => 'Dynamische Basislinie verwenden';

  @override
  String get habitsChartUseZeroBaseline => 'Null-Basislinie verwenden';

  @override
  String get habitsCompletedHeader => 'Abgeschlossen';

  @override
  String get habitsCompletionRateTitle => 'Erfolgsquote';

  @override
  String get habitsConsistencyTitle => 'Beständigkeit';

  @override
  String habitsDayFailedPercent(int percent) {
    return '$percent% als verpasst erfasst';
  }

  @override
  String habitsDaySkippedPercent(int percent) {
    return '$percent% übersprungen';
  }

  @override
  String habitsDaySuccessfulPercent(int percent) {
    return '$percent% erfolgreich';
  }

  @override
  String get habitsDoneTodayLabel => 'Heute erledigt';

  @override
  String get habitSectionOptionsTitle => 'Optionen';

  @override
  String get habitSectionScheduleTitle => 'Zeitplan';

  @override
  String get habitsFilterAll => 'alle';

  @override
  String get habitsFilterCompleted => 'erledigt';

  @override
  String get habitsFilterOpenNow => 'fällig';

  @override
  String get habitsFilterPendingLater => 'später';

  @override
  String get habitsGoalLineLabel => 'Zielwert';

  @override
  String get habitsHeatmapEmpty =>
      'Füge eine Gewohnheit hinzu, um deine Beständigkeit aufzubauen';

  @override
  String get habitsHeatmapLess => 'Weniger';

  @override
  String get habitsHeatmapMore => 'Mehr';

  @override
  String get habitShowAlertAtLabel => 'Alarm anzeigen um';

  @override
  String get habitShowFromLabel => 'Anzeigen ab';

  @override
  String habitsLaggardHint(String habit, int kept, int active) {
    return '$habit — $kept von $active geschafft';
  }

  @override
  String get habitsOpenHeader => 'Jetzt fällig';

  @override
  String get habitsPendingLaterHeader => 'Später heute';

  @override
  String habitsPointsToGoal(int points) {
    return '$points Pkt. bis zum Zielwert';
  }

  @override
  String get habitsRecordButton => 'Eintragen';

  @override
  String get habitsRollingAverageLabel => '7-Tage-Schnitt';

  @override
  String get habitsStartStreakToday => 'Starte heute eine Serie';

  @override
  String habitsStreakLongCount(int count) {
    return '$count mit 7-Tage-Serie';
  }

  @override
  String habitsStreakShortCount(int count) {
    return '$count mit 3-Tage-Serie';
  }

  @override
  String get habitsTapForBreakdown =>
      'Tippe auf einen Tag für die Aufschlüsselung';

  @override
  String habitsToGoCount(int count) {
    return 'noch $count';
  }

  @override
  String habitStreakDaysSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage in Folge',
      one: '1 Tag in Folge',
    );
    return '$_temp0';
  }

  @override
  String get habitsVsPreviousWeek => 'ggü. Vorwoche';

  @override
  String get helpMenuCommandPalette => 'Befehlspalette…';

  @override
  String get helpMenuKeyboardShortcuts => 'Tastaturkurzbefehle…';

  @override
  String get helpMenuTitle => 'Hilfe';

  @override
  String get imageGenerationError => 'Bildgenerierung fehlgeschlagen';

  @override
  String get imageGenerationGenerating => 'Bild wird generiert...';

  @override
  String get imageGenerationProviderRejectedTitle =>
      'Der Bildanbieter hat diese Anfrage abgelehnt';

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
  String get imageViewerDownloadFailed =>
      'Bild konnte nicht gespeichert werden';

  @override
  String get imageViewerDownloadingTooltip => 'Bild wird gespeichert';

  @override
  String get imageViewerDownloadPermissionDenied =>
      'Fotozugriff verweigert – aktiviere ihn in den Einstellungen';

  @override
  String imageViewerDownloadSaved(String fileName) {
    return '$fileName gespeichert';
  }

  @override
  String get imageViewerDownloadSavedToGallery => 'In Fotos gespeichert';

  @override
  String get imageViewerDownloadTooltip => 'Bild herunterladen';

  @override
  String get imageViewerNextTooltip => 'Nächstes Bild';

  @override
  String get imageViewerPreviousTooltip => 'Vorheriges Bild';

  @override
  String get inactiveLabel => 'Inaktiv';

  @override
  String get inactiveSwitchDescription =>
      'Kann für neue Einträge gewählt werden, wenn aktiv';

  @override
  String get inferenceProfileChooseModelTitle => 'Modell auswählen';

  @override
  String get inferenceProfileChooseTitle => 'Inferenzprofil auswählen';

  @override
  String get inferenceProfileCreateTitle => 'Profil erstellen';

  @override
  String get inferenceProfileDescriptionLabel => 'Beschreibung';

  @override
  String get inferenceProfileDesktopOnly => 'Nur Desktop';

  @override
  String get inferenceProfileDesktopOnlyDescription =>
      'Nur auf Desktop-Plattformen verfügbar (z.B. für lokale Modelle)';

  @override
  String inferenceProfileDetailLoadError(String error) {
    return 'Profil konnte nicht geladen werden: $error';
  }

  @override
  String get inferenceProfileDetailNotFound => 'Profil nicht gefunden';

  @override
  String get inferenceProfileEditTitle => 'Profil bearbeiten';

  @override
  String get inferenceProfileImageGeneration => 'Bilderzeugung';

  @override
  String get inferenceProfileImageRecognition => 'Bilderkennung';

  @override
  String get inferenceProfileModelUnavailable =>
      'Modell nicht verfügbar – sein Anbieter wurde möglicherweise entfernt';

  @override
  String get inferenceProfileNameLabel => 'Profilname';

  @override
  String get inferenceProfileNameRequired => 'Ein Profilname ist erforderlich';

  @override
  String get inferenceProfilePinnedHostHelper =>
      'Wenn gesetzt, führt nur dieses Gerät die Inferenz für synchronisierte Audio-Einträge automatisch aus, die dieses Profil verwenden.';

  @override
  String get inferenceProfilePinnedHostLabel => 'Verknüpftes Gerät';

  @override
  String get inferenceProfilePinnedHostNoEligibleNodes =>
      'Keine bekannten Geräte bieten die Anbieter, die dieses Profil verwendet. Öffne die Sync-Knoten-Einstellungen auf dem Zielgerät.';

  @override
  String get inferenceProfilePinnedHostNoneHelper =>
      'Synchronisierte Audio-Einträge werden nicht automatisch transkribiert, wenn kein Gerät verknüpft ist.';

  @override
  String get inferenceProfilePinnedHostNoneLabel =>
      'Nicht verknüpft (kein Auto-Trigger)';

  @override
  String get inferenceProfilePinnedHostThisDeviceSuffix => ' (dieses Gerät)';

  @override
  String get inferenceProfileSaveButton => 'Speichern';

  @override
  String get inferenceProfileSelectModel => 'Modell auswählen…';

  @override
  String get inferenceProfileSelectProfile => 'Profil auswählen…';

  @override
  String get inferenceProfilesEmpty => 'Noch keine Inferenz-Profile';

  @override
  String inferenceProfileSkillModelRequired(String slotName) {
    return '$slotName-Modell muss gesetzt sein';
  }

  @override
  String get inferenceProfileSkillsSection => 'Automatisierte Fähigkeiten';

  @override
  String inferenceProfileSkillUsesModel(String slotName) {
    return 'Verwendet $slotName-Modell';
  }

  @override
  String get inferenceProfilesTitle => 'Inferenz-Profile';

  @override
  String get inferenceProfileThinking => 'Denken';

  @override
  String get inferenceProfileThinkingHighEnd => 'Denken (High-End)';

  @override
  String get inferenceProfileThinkingRequired =>
      'Ein Denk-Modell ist erforderlich';

  @override
  String get inferenceProfileTranscription => 'Transkription';

  @override
  String get inferenceProfileUnavailable => 'Inferenzprofil nicht verfügbar';

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
  String get insightsChartCompareCaption => 'Dieser Zeitraum vs. der vorige';

  @override
  String get insightsChartCompareCaptionPartial =>
      'Dieser Zeitraum bisher vs. der vorige';

  @override
  String get insightsChartCompareHint => 'Vergleich in der Tabelle unten';

  @override
  String get insightsChartCumulativeCaption => 'Laufende Summe im Zeitraum';

  @override
  String get insightsChartCumulativeShort =>
      'Noch zu wenige Tage für eine laufende Summe';

  @override
  String get insightsChartDailyCaption => 'Zeit pro Tag';

  @override
  String get insightsChartHourlyCaption => 'Zeit pro Stunde';

  @override
  String get insightsChartPerDay => 'Pro Tag';

  @override
  String get insightsChartPerHour => 'Pro Stunde';

  @override
  String get insightsChartPerWeek => 'Pro Woche';

  @override
  String get insightsChartRunningTotal => 'Laufende Summe';

  @override
  String get insightsChartTitle => 'Zeit nach Kategorie';

  @override
  String get insightsChartWeeklyCaption => 'Zeit pro Woche';

  @override
  String get insightsChooseFocusCategories => 'Fokus-Kategorien wählen';

  @override
  String get insightsCompare => 'Vergleichen';

  @override
  String get insightsCompareFullPeriod => 'ganzer Zeitraum';

  @override
  String get insightsComparePrevious => 'Vorher';

  @override
  String get insightsCompareSameDays => 'gleiche Tage';

  @override
  String get insightsCompareTooltip => 'Mit dem vorigen Zeitraum vergleichen';

  @override
  String get insightsCompareVs => 'vs';

  @override
  String get insightsDeletedCategory => 'Gelöschte Kategorie';

  @override
  String get insightsDeltaNew => 'neu';

  @override
  String get insightsEmptyBody =>
      'Zeit, die du auf Einträgen und Aufgaben erfasst, erscheint hier.';

  @override
  String get insightsEmptyChart => 'Keine Daten in diesem Zeitraum';

  @override
  String get insightsEmptyPreviousPeriod => 'Vorigen Zeitraum anzeigen';

  @override
  String get insightsEmptyShowYear => 'Dieses Jahr anzeigen';

  @override
  String get insightsEmptyTitle => 'Keine erfasste Zeit in diesem Zeitraum';

  @override
  String get insightsFocusCategoriesEmpty => 'Noch keine aktiven Kategorien.';

  @override
  String get insightsFocusCategoriesTitle => 'Fokus-Kategorien';

  @override
  String get insightsKpiFocus => 'FOKUS';

  @override
  String get insightsKpiFocusHelp => 'Kategorien, die du beobachtest';

  @override
  String get insightsKpiOther => 'SONSTIGES';

  @override
  String get insightsKpiOtherHelp => 'Alles andere';

  @override
  String insightsKpiTopCategory(String category, String share) {
    return 'Meiste Zeit für $category · $share';
  }

  @override
  String get insightsKpiTotal => 'GESAMT';

  @override
  String get insightsLoadError => 'Zeitdaten konnten nicht geladen werden';

  @override
  String get insightsOtherCategories => 'Sonstiges';

  @override
  String get insightsPartialWeek => 'Teilwoche';

  @override
  String get insightsPeriodDay => 'Tag';

  @override
  String get insightsPeriodJump => 'Zu einem Datum springen';

  @override
  String get insightsPeriodMonth => 'Monat';

  @override
  String get insightsPeriodNext => 'Nächster Zeitraum';

  @override
  String get insightsPeriodPrevious => 'Vorheriger Zeitraum';

  @override
  String get insightsPeriodQuarter => 'Quartal';

  @override
  String get insightsPeriodToDateSuffix => 'bisher';

  @override
  String get insightsPeriodWeek => 'Woche';

  @override
  String get insightsPeriodYear => 'Jahr';

  @override
  String get insightsRangeMonthToDate => 'Dieser Monat bisher';

  @override
  String get insightsRangeMtd => 'Dieser Monat';

  @override
  String get insightsRangeYearToDate => 'Dieses Jahr bisher';

  @override
  String get insightsRangeYtd => 'Dieses Jahr';

  @override
  String get insightsRefreshError =>
      'Aktualisierung fehlgeschlagen — zuletzt geladene Daten werden angezeigt';

  @override
  String get insightsTableAvgPerDay => 'Ø/TAG';

  @override
  String get insightsTableCategory => 'KATEGORIE';

  @override
  String get insightsTableCompareNote => 'Änderung ggü. dem vorigen Zeitraum';

  @override
  String get insightsTableCurrent => 'AKTUELL';

  @override
  String get insightsTableDelta => 'Änderung';

  @override
  String get insightsTablePrevious => 'VORHER';

  @override
  String get insightsTableShare => 'ANTEIL';

  @override
  String get insightsTableTotal => 'GESAMT';

  @override
  String get insightsTimeAnalysisTitle => 'Zeitanalyse';

  @override
  String get insightsUncategorized => 'Ohne Kategorie';

  @override
  String get journalCopyImageLabel => 'Bild kopieren';

  @override
  String get journalDateFromLabel => 'Datum von:';

  @override
  String get journalDateInvalid => 'Ungültiger Datumsbereich';

  @override
  String get journalDateLabel => 'Datum';

  @override
  String get journalDateNowButton => 'Jetzt';

  @override
  String get journalDateSaveButton => 'Speichern';

  @override
  String get journalDateTimeRangeTitle => 'Datum & Uhrzeit';

  @override
  String get journalDateToLabel => 'Datum bis:';

  @override
  String get journalDeleteConfirm => 'Ja, diesen Eintrag löschen';

  @override
  String get journalDeleteHint => 'Eintrag löschen';

  @override
  String get journalDeleteQuestion =>
      'Möchtest du diesen Journaleintrag löschen?';

  @override
  String get journalDurationLabel => 'Dauer';

  @override
  String get journalEndDateLabel => 'Enddatum';

  @override
  String get journalEndsAnotherDayHint => 'Eigenes Enddatum wählen';

  @override
  String get journalEndsAnotherDayLabel => 'Endet an einem anderen Tag';

  @override
  String get journalEndTimeLabel => 'Endzeit';

  @override
  String get journalEntryExpandLabel => 'Eintrag erweitern';

  @override
  String get journalFilterEntryTypesTitle => 'Eintragstypen';

  @override
  String get journalFilterFlagged => 'Markiert';

  @override
  String get journalFilterPrivate => 'Privat';

  @override
  String get journalFilterShowTitle => 'Anzeigen';

  @override
  String get journalFilterStarred => 'Favoriten';

  @override
  String get journalFilterTitle => 'Tagebuch filtern';

  @override
  String get journalHideLinkHint => 'Link ausblenden';

  @override
  String get journalHideMapHint => 'Karte ausblenden';

  @override
  String get journalLinkedEntriesActivityFilterAudio => 'Audio';

  @override
  String get journalLinkedEntriesActivityFilterCode => 'Code';

  @override
  String get journalLinkedEntriesActivityFilterImages => 'Bilder';

  @override
  String get journalLinkedEntriesActivityFilterTimer => 'Timer';

  @override
  String get journalLinkedEntriesFilterModalTitle => 'Filtern & Sortieren';

  @override
  String get journalLinkedEntriesShowFlaggedOnly =>
      'Nur markierte Einträge anzeigen';

  @override
  String get journalLinkedEntriesShowHidden => 'Versteckte Einträge anzeigen';

  @override
  String get journalLinkedEntriesSortLabel => 'Sortieren nach';

  @override
  String get journalLinkedEntriesSortNewestFirst => 'Neueste zuerst';

  @override
  String get journalLinkedEntriesSortOldestFirst => 'Älteste zuerst';

  @override
  String get journalLinkedFromLabel => 'Verknüpft von:';

  @override
  String get journalLinkFromHint => 'Verknüpfen von';

  @override
  String get journalLinkToHint => 'Verknüpfen mit';

  @override
  String journalOvernightNextDay(String date) {
    return 'Endet $date (nächster Tag)';
  }

  @override
  String get journalPrivateTooltip => 'nur privat';

  @override
  String get journalSearchHint => 'Tagebuch durchsuchen...';

  @override
  String get journalSetEndDateTimeNowSemantic =>
      'Enddatum und -zeit auf jetzt setzen';

  @override
  String get journalSetStartDateTimeNowSemantic =>
      'Startdatum und -zeit auf jetzt setzen';

  @override
  String get journalShareHint => 'Teilen';

  @override
  String get journalShowLinkHint => 'Link anzeigen';

  @override
  String get journalShowMapHint => 'Karte anzeigen';

  @override
  String get journalStartDateLabel => 'Startdatum';

  @override
  String get journalStartTimeLabel => 'Startzeit';

  @override
  String get journalTodayButton => 'Heute';

  @override
  String get journalToggleFlaggedTitle => 'Markiert';

  @override
  String get journalTogglePrivateTitle => 'Privat';

  @override
  String get journalToggleStarredTitle => 'Favorit';

  @override
  String get journalUnlinkConfirm => 'Ja, Eintrag trennen';

  @override
  String get journalUnlinkHint => 'Trennen';

  @override
  String get journalUnlinkQuestion =>
      'Möchtest du diesen Eintrag wirklich trennen?';

  @override
  String get keyboardCommandActivate => 'Fokussiertes Element aktivieren';

  @override
  String get keyboardCommandCategoryCreation => 'Erstellen';

  @override
  String get keyboardCommandCategoryEditing => 'Bearbeiten';

  @override
  String get keyboardCommandCategoryGeneral => 'Allgemein';

  @override
  String get keyboardCommandCategoryListsAndControls =>
      'Listen und Bedienelemente';

  @override
  String get keyboardCommandCategoryNavigation => 'Navigation';

  @override
  String get keyboardCommandCategoryView => 'Ansicht';

  @override
  String get keyboardCommandCreateInContext =>
      'In der aktuellen Ansicht erstellen';

  @override
  String get keyboardCommandFocusSearch => 'Suche fokussieren';

  @override
  String get keyboardCommandMoveDown =>
      'Fokussiertes Element nach unten verschieben';

  @override
  String get keyboardCommandMoveUp =>
      'Fokussiertes Element nach oben verschieben';

  @override
  String keyboardCommandNavigate(String destination) {
    return 'Zu $destination wechseln';
  }

  @override
  String get keyboardCommandNextRegion => 'Nächsten Bereich fokussieren';

  @override
  String get keyboardCommandOpenPalette => 'Befehlspalette öffnen';

  @override
  String get keyboardCommandPageDown => 'Eine Seite nach unten';

  @override
  String get keyboardCommandPageUp => 'Eine Seite nach oben';

  @override
  String get keyboardCommandPreviousRegion => 'Vorherigen Bereich fokussieren';

  @override
  String get keyboardCommandRefresh => 'Aktuelle Ansicht aktualisieren';

  @override
  String get keyboardCommandRename => 'Fokussiertes Element umbenennen';

  @override
  String get keyboardCommandSelectFirst => 'Erstes Element auswählen';

  @override
  String get keyboardCommandSelectLast => 'Letztes Element auswählen';

  @override
  String get keyboardCommandSelectNext => 'Nächstes Element auswählen';

  @override
  String get keyboardCommandSelectPrevious => 'Vorheriges Element auswählen';

  @override
  String get keyboardCommandToggle => 'Fokussiertes Element umschalten';

  @override
  String get keyboardKeyAlt => 'Alt';

  @override
  String get keyboardKeyArrowDown => 'Pfeil nach unten';

  @override
  String get keyboardKeyArrowLeft => 'Pfeil nach links';

  @override
  String get keyboardKeyArrowRight => 'Pfeil nach rechts';

  @override
  String get keyboardKeyArrowUp => 'Pfeil nach oben';

  @override
  String get keyboardKeyControl => 'Strg';

  @override
  String get keyboardKeyDelete => 'Entf';

  @override
  String get keyboardKeyEnd => 'Ende';

  @override
  String get keyboardKeyEnter => 'Eingabe';

  @override
  String get keyboardKeyEscape => 'Esc';

  @override
  String get keyboardKeyHome => 'Pos 1';

  @override
  String get keyboardKeyMinus => 'Minus';

  @override
  String get keyboardKeyOr => 'oder';

  @override
  String get keyboardKeyPageDown => 'Bild ab';

  @override
  String get keyboardKeyPageUp => 'Bild auf';

  @override
  String get keyboardKeyPlus => 'Plus';

  @override
  String get keyboardKeyShift => 'Umschalt';

  @override
  String get keyboardKeySpace => 'Leertaste';

  @override
  String get keyboardResizeDividerLabel => 'Bereiche anpassen';

  @override
  String keyboardResizeDividerValue(int value, int min, int max) {
    return 'Bereiche anpassen, $value Pixel. Bereich $min bis $max Pixel.';
  }

  @override
  String get keyboardShortcutsNoResults =>
      'Keine Kurzbefehle passen zu deiner Suche';

  @override
  String get keyboardShortcutsSearchHint => 'Kurzbefehle suchen…';

  @override
  String get keyboardShortcutsSubtitle =>
      'Alle Desktop-Befehle und ihre aktuellen Tastenkombinationen.';

  @override
  String get keyboardShortcutsTitle => 'Tastaturkurzbefehle';

  @override
  String knowledgeGraphAgeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Tagen',
      one: 'vor 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String knowledgeGraphAgeMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Monaten',
      one: 'vor 1 Monat',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeToday => 'Heute';

  @override
  String knowledgeGraphAgeWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Wochen',
      one: 'vor 1 Woche',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeYesterday => 'Gestern';

  @override
  String get knowledgeGraphBack => 'Zurück';

  @override
  String get knowledgeGraphCloseDetails => 'Details schließen';

  @override
  String get knowledgeGraphDensity => 'Dichte';

  @override
  String get knowledgeGraphDensityBalanced => 'Ausgewogen';

  @override
  String get knowledgeGraphDensityCalm => 'Ruhig';

  @override
  String get knowledgeGraphDensityExplore => 'Erkunden';

  @override
  String get knowledgeGraphEmpty => 'Noch keine Verknüpfungen zum Erkunden';

  @override
  String get knowledgeGraphEntryLoadError =>
      'Dieser Eintrag konnte nicht geladen werden';

  @override
  String get knowledgeGraphEntryNotFound => 'Eintrag nicht gefunden';

  @override
  String get knowledgeGraphError => 'Wissensgraph konnte nicht geladen werden';

  @override
  String get knowledgeGraphFilterCategories => 'Kategorien';

  @override
  String get knowledgeGraphFilterRecency => 'Aktualität';

  @override
  String get knowledgeGraphFilterRelations => 'Beziehungen';

  @override
  String get knowledgeGraphFilters => 'Filter';

  @override
  String get knowledgeGraphFilterTaskStatus => 'Aufgabenstatus';

  @override
  String get knowledgeGraphFilterTypes => 'Typen';

  @override
  String get knowledgeGraphForward => 'Vorwärts';

  @override
  String get knowledgeGraphLast30Days => 'Letzte 30 Tage';

  @override
  String get knowledgeGraphLast7Days => 'Letzte 7 Tage';

  @override
  String get knowledgeGraphLast90Days => 'Letzte 90 Tage';

  @override
  String knowledgeGraphLinkedSection(int count) {
    return 'VERKNÜPFT · $count';
  }

  @override
  String get knowledgeGraphMoreBelow => 'Weiter unten';

  @override
  String get knowledgeGraphMoreLinks => 'Weitere Verknüpfungen';

  @override
  String knowledgeGraphNodeCount(int count) {
    return 'Knoten: $count';
  }

  @override
  String get knowledgeGraphNodeTypeAiSummary => 'KI-Zusammenfassung';

  @override
  String get knowledgeGraphNodeTypeAudioNote => 'Audionotiz';

  @override
  String get knowledgeGraphNodeTypeChecklist => 'Checkliste';

  @override
  String get knowledgeGraphNodeTypeChecklistItem => 'Checklisteneintrag';

  @override
  String get knowledgeGraphNodeTypeNote => 'Notiz';

  @override
  String get knowledgeGraphNodeTypePhoto => 'Foto';

  @override
  String get knowledgeGraphNodeTypeProject => 'Projekt';

  @override
  String get knowledgeGraphNodeTypeRating => 'Bewertung';

  @override
  String get knowledgeGraphNodeTypeTask => 'Aufgabe';

  @override
  String get knowledgeGraphOneHop => '1 Schritt';

  @override
  String get knowledgeGraphOpenDetails => 'Details öffnen';

  @override
  String get knowledgeGraphOpenPhoto => 'Foto im Vollbild ansehen';

  @override
  String knowledgeGraphPhotosSection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'FOTOS · $count',
      one: 'FOTO · 1',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphRecenter => 'Neu zentrieren';

  @override
  String get knowledgeGraphRecentToOlder => 'Neu → älter';

  @override
  String get knowledgeGraphRelationAiSource => 'KI-Quelle';

  @override
  String get knowledgeGraphRelationAssociation => 'Verknüpfter Eintrag';

  @override
  String get knowledgeGraphRelationChecklist => 'Checkliste';

  @override
  String get knowledgeGraphRelationInProject => 'Im Projekt';

  @override
  String get knowledgeGraphRelationLinkedTask => 'Verknüpfte Aufgabe';

  @override
  String get knowledgeGraphRelationNoteLog => 'Notiz / Protokoll';

  @override
  String get knowledgeGraphRelationRating => 'Bewertung';

  @override
  String get knowledgeGraphSummarySection => 'ZUSAMMENFASSUNG';

  @override
  String get knowledgeGraphTitle => 'Wissensgraph';

  @override
  String get knowledgeGraphTooltip => 'Verknüpfungen erkunden';

  @override
  String get knowledgeGraphTopologyOverview => 'Topologieübersicht';

  @override
  String get knowledgeGraphTwoHops => '2 Schritte';

  @override
  String get knowledgeGraphViewConnections => 'Verbindungen';

  @override
  String get knowledgeGraphViewGraph => 'Graph';

  @override
  String knowledgeGraphWalkHint(int count) {
    return 'Tippe auf einen Knoten · Knoten: $count';
  }

  @override
  String get linkBlocksCycleErrorMessage =>
      'Das würde einen blockierenden Kreislauf erzeugen — wähle eine andere Aufgabe.';

  @override
  String linkCreatedMessage(String relation, String title) {
    return '$relation: $title';
  }

  @override
  String get linkCreatedUndo => 'Rückgängig';

  @override
  String get linkCreateFailedMessage =>
      'Die Verknüpfung konnte nicht erstellt werden. Bitte versuche es erneut.';

  @override
  String get linkDirectionLabel => 'Diese Aufgabe…';

  @override
  String get linkedTaskImageBadge => 'Von verknüpfter Aufgabe';

  @override
  String get linkedTasksBlockedBySectionTitle => 'Blockiert von';

  @override
  String get linkedTasksEmptyAction => 'Aufgabe verknüpfen…';

  @override
  String get linkedTasksEmptyHint =>
      'Verknüpfe diese Aufgabe mit einer anderen Aufgabe.';

  @override
  String get linkedTasksMenuTooltip => 'Optionen für verknüpfte Aufgaben';

  @override
  String get linkedTasksTitle => 'Verknüpfte Aufgaben';

  @override
  String get linkExistingTask => 'Vorhandene Aufgabe verknüpfen…';

  @override
  String get linkExistingTaskTitle => 'Verknüpfen';

  @override
  String get linkPhraseBasic => 'Bezieht sich auf';

  @override
  String get linkPhraseBlocksInverse => 'Wird blockiert von';

  @override
  String get linkPhraseBlocksPrimary => 'Blockiert';

  @override
  String get linkPhraseDuplicatesInverse => 'Wird dupliziert von';

  @override
  String get linkPhraseDuplicatesPrimary => 'Dupliziert';

  @override
  String get linkPhraseFixesInverse => 'Wird behoben durch';

  @override
  String get linkPhraseFixesPrimary => 'Behebt';

  @override
  String get linkPhraseFollowsUpInverse => 'Hat Folgeaufgabe';

  @override
  String get linkPhraseFollowsUpPrimary => 'Folgt auf';

  @override
  String get linkPhraseSupersedesInverse => 'Wird ersetzt durch';

  @override
  String get linkPhraseSupersedesPrimary => 'Ersetzt';

  @override
  String linkPickerCreateTaskSemanticLabel(String title) {
    return 'Aufgabe erstellen: $title';
  }

  @override
  String linkSummaryBasic(Object target) {
    return 'Diese Aufgabe bezieht sich auf $target';
  }

  @override
  String linkSummaryBlocksInverse(Object target) {
    return 'Diese Aufgabe wird blockiert von $target';
  }

  @override
  String linkSummaryBlocksPrimary(Object target) {
    return 'Diese Aufgabe blockiert $target';
  }

  @override
  String linkSummaryDuplicatesInverse(Object target) {
    return 'Diese Aufgabe wird dupliziert von $target';
  }

  @override
  String linkSummaryDuplicatesPrimary(Object target) {
    return 'Diese Aufgabe dupliziert $target';
  }

  @override
  String linkSummaryFixesInverse(Object target) {
    return 'Diese Aufgabe wird durch $target behoben';
  }

  @override
  String linkSummaryFixesPrimary(Object target) {
    return 'Diese Aufgabe behebt $target';
  }

  @override
  String linkSummaryFollowsUpInverse(Object target) {
    return 'Diese Aufgabe hat die Folgeaufgabe $target';
  }

  @override
  String linkSummaryFollowsUpPrimary(Object target) {
    return 'Diese Aufgabe knüpft an $target an';
  }

  @override
  String get linkSummaryNewTaskBasic =>
      'Diese Aufgabe bezieht sich auf die neue Aufgabe';

  @override
  String get linkSummaryNewTaskBlocksInverse =>
      'Die neue Aufgabe blockiert diese Aufgabe';

  @override
  String get linkSummaryNewTaskBlocksPrimary =>
      'Diese Aufgabe blockiert die neue Aufgabe';

  @override
  String get linkSummaryNewTaskDuplicatesInverse =>
      'Die neue Aufgabe dupliziert diese Aufgabe';

  @override
  String get linkSummaryNewTaskDuplicatesPrimary =>
      'Diese Aufgabe dupliziert die neue Aufgabe';

  @override
  String get linkSummaryNewTaskFixesInverse =>
      'Die neue Aufgabe behebt diese Aufgabe';

  @override
  String get linkSummaryNewTaskFixesPrimary =>
      'Diese Aufgabe behebt die neue Aufgabe';

  @override
  String get linkSummaryNewTaskFollowsUpInverse =>
      'Die neue Aufgabe knüpft an diese Aufgabe an';

  @override
  String get linkSummaryNewTaskFollowsUpPrimary =>
      'Diese Aufgabe knüpft an die neue Aufgabe an';

  @override
  String get linkSummaryNewTaskSupersedesInverse =>
      'Die neue Aufgabe ersetzt diese Aufgabe';

  @override
  String get linkSummaryNewTaskSupersedesPrimary =>
      'Diese Aufgabe ersetzt die neue Aufgabe';

  @override
  String linkSummarySupersedesInverse(Object target) {
    return 'Diese Aufgabe wird durch $target ersetzt';
  }

  @override
  String linkSummarySupersedesPrimary(Object target) {
    return 'Diese Aufgabe ersetzt $target';
  }

  @override
  String get linkTaskButton => 'Verknüpfen';

  @override
  String get listPaneHideTooltip => 'Liste ausblenden';

  @override
  String get listPaneShowTooltip => 'Liste anzeigen';

  @override
  String get logbookEmptyHint =>
      'Erstelle deinen ersten Eintrag, um mit dem Logbuch zu starten.';

  @override
  String get logbookEmptyTitle => 'Dein Logbuch ist leer';

  @override
  String get logbookNewEntriesHint => 'Neue Einträge erscheinen hier.';

  @override
  String get logbookNoMatchesHint =>
      'Passe deine Suche oder Filter an, um mehr zu sehen.';

  @override
  String get logbookNoMatchesTitle => 'Keine passenden Einträge';

  @override
  String get loggingDomainAgentRuntime => 'Agent-Runtime';

  @override
  String get loggingDomainAgentWorkflow => 'Agent-Workflow';

  @override
  String get loggingDomainAi => 'KI';

  @override
  String get loggingDomainCalendar => 'Kalender & Zeit';

  @override
  String get loggingDomainChat => 'Chat';

  @override
  String get loggingDomainDailyOs => 'Daily OS';

  @override
  String get loggingDomainDatabase => 'Datenbank';

  @override
  String get loggingDomainGeneral => 'Allgemein';

  @override
  String get loggingDomainHabits => 'Gewohnheiten';

  @override
  String get loggingDomainHealth => 'Gesundheit';

  @override
  String get loggingDomainLabels => 'Labels';

  @override
  String get loggingDomainLocation => 'Standort';

  @override
  String get loggingDomainNavigation => 'Navigation';

  @override
  String get loggingDomainNotifications => 'Benachrichtigungen';

  @override
  String get loggingDomainOnboarding => 'Onboarding & FTUE';

  @override
  String get loggingDomainPersistence => 'Persistenz';

  @override
  String get loggingDomainRatings => 'Bewertungen';

  @override
  String get loggingDomainScreenshots => 'Screenshots';

  @override
  String get loggingDomainSettings => 'Einstellungen';

  @override
  String get loggingDomainSpeech => 'Sprache & Audio';

  @override
  String get loggingDomainSync => 'Sync';

  @override
  String get loggingDomainTasks => 'Aufgaben & Checklisten';

  @override
  String get loggingDomainTheming => 'Themes';

  @override
  String get loggingDomainWhatsNew => 'Neuigkeiten';

  @override
  String get maintenanceDeleteAgentDb => 'Agenten-Datenbank löschen';

  @override
  String get maintenanceDeleteAgentDbDescription =>
      'Agenten-Datenbank löschen und App neu starten';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'Ja, Datenbank löschen';

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
  String get maintenanceDeleteSyncDb => 'Synchronisierungsdatenbank löschen';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Synchronisierungsdatenbank löschen';

  @override
  String get maintenanceGenerateEmbeddings => 'Embeddings generieren';

  @override
  String get maintenanceGenerateEmbeddingsConfirm => 'Ja, generieren';

  @override
  String get maintenanceGenerateEmbeddingsDescription =>
      'Embeddings für Einträge ausgewählter Kategorien generieren';

  @override
  String get maintenanceGenerateEmbeddingsMessage =>
      'Wähle Kategorien, um Embeddings zu generieren.';

  @override
  String maintenanceGenerateEmbeddingsProgress(
    int processed,
    int total,
    int embedded,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$processed / $total Einträge ($embedded eingebettet)',
      one: '$processed / $total Eintrag ($embedded eingebettet)',
    );
    return '$_temp0';
  }

  @override
  String get maintenancePopulatePhaseAgentEntities =>
      'Agenten-Entitäten werden verarbeitet...';

  @override
  String get maintenancePopulatePhaseAgentLinks =>
      'Agenten-Verknüpfungen werden verarbeitet...';

  @override
  String get maintenancePopulatePhaseJournal =>
      'Journaleinträge werden verarbeitet...';

  @override
  String get maintenancePopulatePhaseLinks =>
      'Eintragsverknüpfungen werden verarbeitet...';

  @override
  String get maintenancePopulateSequenceLog => 'Sync-Sequenzprotokoll befüllen';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count Einträge indexiert';
  }

  @override
  String get maintenancePopulateSequenceLogConfirm => 'Ja, befüllen';

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
  String get maintenancePurgeSentOutbox =>
      'Alte gesendete Outbox-Einträge löschen';

  @override
  String get maintenancePurgeSentOutboxConfirm => 'Ja, löschen';

  @override
  String get maintenancePurgeSentOutboxDescription =>
      'Gesendete Outbox-Zeilen, die älter als 7 Tage sind, löschen und Speicherplatz freigeben';

  @override
  String get maintenancePurgeSentOutboxQuestion =>
      'Gesendete Outbox-Einträge löschen, die älter als 7 Tage sind? Bereits gesendete Zeilen werden in Blöcken gelöscht und VACUUM gibt Speicherplatz frei. Ausstehende und fehlerhafte Einträge bleiben erhalten.';

  @override
  String get maintenanceRecreateFts5 => 'Volltextindex neu erstellen';

  @override
  String get maintenanceRecreateFts5Confirm => 'Ja, Index neu erstellen';

  @override
  String get maintenanceRecreateFts5Description =>
      'Volltextsuchindex neu erstellen';

  @override
  String get maintenanceRecreateFts5Message =>
      'Möchtest du den Volltextindex wirklich neu erstellen? Dies kann einige Zeit dauern.';

  @override
  String get maintenanceRepairScreenshotPaths =>
      'Screenshot-Speicher reparieren';

  @override
  String get maintenanceRepairScreenshotPathsDescription =>
      'Verschiebe Screenshots aus älteren Versionen in den richtigen Ordner, damit die KI-Bildanalyse sie lesen kann.';

  @override
  String maintenanceRepairScreenshotPathsResult(
    int repaired,
    int missing,
    int conflicts,
    int failed,
  ) {
    return 'Screenshot-Reparatur abgeschlossen: $repaired repariert, $missing fehlen, $conflicts Konflikte, $failed fehlgeschlagen.';
  }

  @override
  String get maintenanceReSync => 'Nachrichtenverlauf';

  @override
  String get maintenanceReSyncAgentEntities => 'Agenten-Entitäten';

  @override
  String get maintenanceReSyncAgentLinks => 'Agenten-Verknüpfungen';

  @override
  String get maintenanceReSyncCompleteDescription =>
      'Deine anderen Geräte erhalten sie, sobald die Synchronisierung aufgeholt hat.';

  @override
  String get maintenanceReSyncCompleteTitle => 'Nachrichten eingereiht';

  @override
  String get maintenanceReSyncCustom => 'Benutzerdefiniert';

  @override
  String get maintenanceReSyncDescription =>
      'Nachrichten für deine anderen Geräte einreihen';

  @override
  String get maintenanceReSyncEntityTypes => 'Entitätstypen';

  @override
  String get maintenanceReSyncEverything => 'Alles';

  @override
  String get maintenanceReSyncFailed =>
      'Nachrichten konnten nicht eingereiht werden. Versuch es erneut.';

  @override
  String get maintenanceReSyncInvalidRange =>
      'Der Start muss vor dem Ende liegen';

  @override
  String get maintenanceReSyncJournalEntities => 'Journal-Einträge';

  @override
  String get maintenanceReSyncLast30Days => 'Letzte 30 Tage';

  @override
  String maintenanceReSyncPartialDescription(int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other:
          '$failed Einträge sind fehlgeschlagen. Versuche nur diese Einträge erneut.',
      one: '1 Eintrag ist fehlgeschlagen. Versuche nur diesen Eintrag erneut.',
    );
    return '$_temp0';
  }

  @override
  String maintenanceReSyncPartialTitle(int succeeded, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Einträge',
      one: 'Eintrag',
    );
    return '$succeeded von $total $_temp0 eingereiht';
  }

  @override
  String get maintenanceReSyncRetryFailed =>
      'Fehlgeschlagene Einträge erneut versuchen';

  @override
  String get maintenanceReSyncSelectAtLeastOne =>
      'Wähle mindestens einen Entitätstyp aus';

  @override
  String get maintenanceReSyncSending => 'Nachrichten werden vorbereitet';

  @override
  String get maintenanceReSyncStart => 'Starten';

  @override
  String get maintenanceSyncDefinitions =>
      'Messgrößen, Dashboards, Gewohnheiten, Kategorien, AI-Einstellungen synchronisieren';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Messgrößen, Dashboards, Gewohnheiten, Kategorien und AI-Einstellungen synchronisieren';

  @override
  String get manageLinks => 'Verknüpfungen verwalten…';

  @override
  String get matrixStatsConflicts => 'Konflikte';

  @override
  String get matrixStatsCopyDiagnostics => 'Diagnosen kopieren';

  @override
  String get matrixStatsCopyDiagnosticsTooltip =>
      'Synchronisierungsdiagnosen in die Zwischenablage kopieren';

  @override
  String get matrixStatsDbApplied => 'Datenbank angewendet';

  @override
  String get matrixStatsDbApply => 'Datenbankanwendung';

  @override
  String get matrixStatsDbIgnoredVectorClock =>
      'Von Datenbank ignoriert (VectorClock)';

  @override
  String get matrixStatsDbMissingBase => 'Fehlende Datenbankbasis';

  @override
  String matrixStatsDbMissingBaseValue(Object count) {
    return 'Fehlende Datenbankbasis: $count';
  }

  @override
  String get matrixStatsDiagnostics => 'Diagnose';

  @override
  String matrixStatsDroppedByType(Object type) {
    return 'Verworfen ($type)';
  }

  @override
  String get matrixStatsEntryLinkNoops => 'EntryLink-Nulloperationen';

  @override
  String get matrixStatsForceRescan => 'Erneut scannen erzwingen';

  @override
  String get matrixStatsForceRescanTooltip =>
      'Jetzt erneut scannen und nachholen';

  @override
  String get matrixStatsLastIgnored => 'Zuletzt ignoriert:';

  @override
  String get matrixStatsLegendTooltip =>
      'Legende:\n• dbApplied = geschriebene Datenbankzeilen\n• dbIgnoredByVectorClock = von der Datenbank ignorierte ältere oder identische eingehende Daten\n• conflictsCreated = protokollierte gleichzeitige Vector Clocks\n• dbMissingBase = übersprungen, während eine fehlende Abhängigkeit erwartet wird\n• dbEntryLinkNoop = Verknüpfung bereits vorhanden, nichts geschrieben\n• droppedByType.<type> = verworfene Nachrichten pro Typ nach Wiederholungen oder Ignorieren älterer Nachrichten\n• queueActive = eingehende Ereignisse, die noch angewendet werden müssen\n• signalConnectivity = Sync-Anstöße nach Wiederkehr der Verbindung';

  @override
  String get matrixStatsQueueActive => 'Warteschlange (aktiv)';

  @override
  String get matrixStatsRefresh => 'Aktualisieren';

  @override
  String get matrixStatsRefreshDiagnosticsTooltip => 'Diagnose aktualisieren';

  @override
  String get matrixStatsRetryNow => 'Jetzt wiederholen';

  @override
  String get matrixStatsRetryNowTooltip =>
      'Ausstehende Fehler jetzt erneut versuchen';

  @override
  String get matrixStatsSignals => 'Signale';

  @override
  String get matrixStatsSignalsConnectivity => 'Signale (Verbindung)';

  @override
  String get matrixStatsTopKpis => 'Wichtigste KPIs';

  @override
  String get measurableDeleteConfirm => 'Ja, diese Messgröße löschen';

  @override
  String get measurableDeleteQuestion =>
      'Möchtest du diesen Messgrößen-Datentyp löschen?';

  @override
  String get measurableNotFound => 'Messgröße nicht gefunden';

  @override
  String get measurementCommentHint => 'Notiz hinzufügen (optional)';

  @override
  String get measurementCommentSemantic => 'Kommentar, optional';

  @override
  String measurementObservedAtChangeSemantic(String dateTime) {
    return 'Erfasst am $dateTime. Datum und Uhrzeit ändern.';
  }

  @override
  String get measurementQuickAddLabel => 'Schnell erfassen';

  @override
  String measurementQuickLogSemantic(String value) {
    return '$value sofort erfassen';
  }

  @override
  String get measurementSaveError =>
      'Die Messung konnte nicht gespeichert werden. Versuch es noch einmal.';

  @override
  String get measurementSetObservedAtNowSemantic =>
      'Erfassungsdatum und -uhrzeit auf jetzt setzen';

  @override
  String get measurementTimeLabel => 'Uhrzeit';

  @override
  String measurementValueSemantic(String measurable) {
    return 'Wert für $measurable';
  }

  @override
  String get mediaShowInFileExplorerAction => 'Im Datei-Explorer anzeigen';

  @override
  String get mediaShowInFilesAction => 'In Dateien anzeigen';

  @override
  String get mediaShowInFinderAction => 'Im Finder anzeigen';

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
  String get modelEditBackTooltip => 'Zurück';

  @override
  String get modelEditDescriptionHint => 'Beschreibe dieses Modell';

  @override
  String get modelEditDescriptionLabel => 'Beschreibung';

  @override
  String get modelEditDisplayNameHint =>
      'Ein einprägsamer Name für dieses Modell';

  @override
  String get modelEditDisplayNameLabel => 'Anzeigename';

  @override
  String get modelEditFunctionCallingDescription =>
      'Dieses Modell unterstützt Function- und Tool-Calling.';

  @override
  String get modelEditFunctionCallingLabel => 'Function Calling';

  @override
  String get modelEditGeminiThinkingModeLabel => 'Gemini-Denkmodus';

  @override
  String get modelEditInputModalitiesHint => 'Eingabetypen auswählen';

  @override
  String get modelEditInputModalitiesLabel => 'Eingabemodalitäten';

  @override
  String get modelEditLoadError =>
      'Modellkonfiguration konnte nicht geladen werden';

  @override
  String get modelEditMaxTokensHint => 'Optional — leer lassen für unbegrenzt';

  @override
  String get modelEditMaxTokensLabel => 'Maximale Completion-Tokens';

  @override
  String get modelEditModalityNoneSelected => 'Nichts ausgewählt';

  @override
  String get modelEditOutputModalitiesHint => 'Ausgabetypen auswählen';

  @override
  String get modelEditOutputModalitiesLabel => 'Ausgabemodalitäten';

  @override
  String get modelEditPageTitle => 'Modell bearbeiten';

  @override
  String get modelEditProviderHint => 'Anbieter auswählen';

  @override
  String get modelEditProviderLabel => 'Anbieter';

  @override
  String get modelEditProviderModelIdHint => 'z. B. gpt-4-turbo';

  @override
  String get modelEditProviderModelIdLabel => 'Anbieter-Modell-ID';

  @override
  String get modelEditReasoningDescription =>
      'Dieses Modell nutzt erweitertes Denken / Chain-of-Thought.';

  @override
  String get modelEditReasoningLabel => 'Reasoning-Modell';

  @override
  String get modelEditSaveButton => 'Speichern';

  @override
  String get modelEditSectionCapabilities => 'Fähigkeiten';

  @override
  String get modelEditSectionIdentity => 'Identität';

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
  String get multiSelectAddButton => 'Hinzufügen';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Hinzufügen ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'Keine Einträge gefunden';

  @override
  String get navSidebarManualBrowserHint => 'Wird in deinem Browser geöffnet';

  @override
  String get navSidebarManualLabel => 'Handbuch';

  @override
  String navTabMoreSemanticsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mehr, $count weitere Bereiche',
      one: 'Mehr, 1 weiterer Bereich',
    );
    return '$_temp0';
  }

  @override
  String get navTabTitleCalendar => 'DailyOS';

  @override
  String get navTabTitleEvents => 'Ereignisse';

  @override
  String get navTabTitleGoals => 'Ziele';

  @override
  String get navTabTitleHabits => 'Gewohnheiten';

  @override
  String get navTabTitleInsights => 'Einblicke';

  @override
  String get navTabTitleJournal => 'Logbuch';

  @override
  String get navTabTitleMore => 'Mehr';

  @override
  String get navTabTitlePeople => 'Menschen';

  @override
  String get navTabTitleProjects => 'Projekte';

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
  String get noTasksFound => 'Keine Aufgaben gefunden';

  @override
  String get noTasksToLink => 'Keine Aufgaben zum Verknüpfen verfügbar';

  @override
  String get notificationBellEmptySemantics =>
      'Mitteilungen, keine ungelesenen Mitteilungen';

  @override
  String get notificationBellTooltip => 'Mitteilungen';

  @override
  String notificationBellUnseenSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mitteilungen',
      one: 'Mitteilung',
    );
    return 'Mitteilungen, $count ungelesene $_temp0';
  }

  @override
  String get notificationInboxDismiss => 'Mitteilung verwerfen';

  @override
  String get notificationInboxEmpty => 'Du bist auf dem neuesten Stand.';

  @override
  String get notificationInboxError =>
      'Mitteilungen konnten nicht geladen werden.';

  @override
  String get notificationInboxTitle => 'Mitteilungen';

  @override
  String get notificationSuggestionAttentionBodyFallback =>
      'Öffne die Aufgabe zur Prüfung.';

  @override
  String notificationSuggestionAttentionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Vorschläge brauchen deine Aufmerksamkeit',
      one: '1 Vorschlag braucht deine Aufmerksamkeit',
    );
    return '$_temp0';
  }

  @override
  String get onboardingApiKeyConnect => 'Verbinden';

  @override
  String get onboardingApiKeyConnecting => 'Verbinde…';

  @override
  String get onboardingApiKeyEnterKeyHint =>
      'Gib einen gültigen Schlüssel ein, um fortzufahren.';

  @override
  String get onboardingApiKeyError =>
      'Verbindung fehlgeschlagen. Prüfe deinen Schlüssel und versuch es erneut.';

  @override
  String get onboardingApiKeyField => 'API-Schlüssel';

  @override
  String get onboardingApiKeyGetKeyAt => 'Schlüssel erhältst du bei';

  @override
  String get onboardingApiKeyHide => 'Schlüssel verbergen';

  @override
  String get onboardingApiKeyInvalid =>
      'Dieser Schlüssel wurde abgelehnt. Prüf ihn und füg ihn noch mal ein.';

  @override
  String get onboardingApiKeyLocalNote =>
      'Läuft auf deinem Gerät – kein Schlüssel nötig.';

  @override
  String get onboardingApiKeyNoKeyHelp =>
      'Neu hier? Anmelden, API-Schlüssel erstellen, einfügen – kostenlos zum Starten.';

  @override
  String get onboardingApiKeyReveal => 'Schlüssel anzeigen';

  @override
  String get onboardingApiKeyTitle => 'Füge deinen API-Schlüssel ein';

  @override
  String onboardingApiKeyUnreachable(String providerName) {
    return '$providerName ist nicht erreichbar. Prüf den Schlüssel oder deine Verbindung und versuch es noch mal.';
  }

  @override
  String get onboardingApiKeyVerifying => 'Wird geprüft…';

  @override
  String get onboardingCaptureCategoryPrompt => 'Wo soll das landen?';

  @override
  String get onboardingCaptureListening =>
      'Ich höre zu … tippe, wenn du fertig bist';

  @override
  String get onboardingCaptureOrbLabel => 'Deinen Gedanken aufnehmen';

  @override
  String get onboardingCaptureRatherType => 'Lieber tippen?';

  @override
  String get onboardingCaptureReassurance =>
      'Du kannst danach noch alles bearbeiten.';

  @override
  String get onboardingCaptureThinking =>
      'Ich verwandle deine Worte in eine Aufgabe…';

  @override
  String get onboardingCaptureTypePrompt => 'Tippe deinen Gedanken';

  @override
  String get onboardingCategoryAddOwn => 'Eigene hinzufügen';

  @override
  String get onboardingCategoryContinue => 'Weiter';

  @override
  String get onboardingCategoryExplanation =>
      'Jeder Lebensbereich bekommt seinen eigenen Raum. Wähle, was passt — oder füge eigene hinzu.';

  @override
  String get onboardingCategoryFamily => 'Familie';

  @override
  String get onboardingCategoryFitness => 'Fitness';

  @override
  String get onboardingCategoryFriends => 'Freunde';

  @override
  String get onboardingCategoryTitle => 'Wo soll deine KI arbeiten?';

  @override
  String get onboardingCategoryWhy => 'Warum Bereiche?';

  @override
  String onboardingCategoryWhyDetail(String provider) {
    return 'Jeder Bereich kann seine eigene KI nutzen. $provider betreibt die hier gewählten Bereiche — später kannst du verschiedenen Bereichen verschiedene KIs geben.';
  }

  @override
  String get onboardingCategoryWork => 'Arbeit';

  @override
  String get onboardingConnectGeminiName => 'Gemini';

  @override
  String get onboardingConnectGeminiTagline => 'USA';

  @override
  String get onboardingConnectLessOptions => 'Weniger Optionen';

  @override
  String get onboardingConnectMistralName => 'Mistral';

  @override
  String get onboardingConnectMistralTagline => 'Europäische Union';

  @override
  String get onboardingConnectMoreOptions => 'Mehr Optionen';

  @override
  String get onboardingConnectNotSure =>
      'Melious.ai ist die empfohlene Voreinstellung.';

  @override
  String get onboardingConnectOllamaName => 'Ollama';

  @override
  String get onboardingConnectOpenAiName => 'OpenAI';

  @override
  String get onboardingConnectQwenName => 'Qwen';

  @override
  String get onboardingConnectQwenTagline => 'China';

  @override
  String get onboardingConnectTitle => 'Wähle das KI-Gehirn für deine Aufgaben';

  @override
  String get onboardingFirstTaskCreatedHint =>
      'Tippe auf deine Aufgabe, um sie zu öffnen';

  @override
  String get onboardingFirstTaskCreatedTitle =>
      'Deine erste Aufgabe ist fertig';

  @override
  String get onboardingFirstTaskGuidance =>
      'Tippe zum Sprechen und sag, was zu tun ist — Lotti macht daraus eine echte Aufgabe.';

  @override
  String get onboardingFirstTaskSuggestionDentist =>
      'Einen Zahnarzttermin vereinbaren';

  @override
  String get onboardingFirstTaskSuggestionMeeting =>
      'Das Meeting am Montag vorbereiten';

  @override
  String get onboardingFirstTaskSuggestionPlanWeek => 'Meine Woche planen';

  @override
  String get onboardingFirstTaskSuggestionsLabel =>
      'Noch nicht bereit zu sprechen? Starte mit einem Vorschlag:';

  @override
  String get onboardingFirstTaskTitle => 'Erstelle deine erste Aufgabe';

  @override
  String get onboardingMetricsActiveDays => 'Aktive Tage';

  @override
  String get onboardingMetricsActiveDaysInFirstSeven =>
      'Aktive Tage in den ersten 7 Tagen';

  @override
  String get onboardingMetricsBaselineCohort => 'Baseline-Kohorte (vor FTUE)';

  @override
  String get onboardingMetricsInstallFirstSeenUtc =>
      'Installation erstmals erfasst (UTC)';

  @override
  String get onboardingMetricsNo => 'nein';

  @override
  String get onboardingMetricsReachedRealAha =>
      'Den echten Aha-Moment erreicht';

  @override
  String get onboardingMetricsYes => 'ja';

  @override
  String get onboardingRecordingStyleAnalogue => 'Analog — VU-Meter';

  @override
  String get onboardingRecordingStyleContinue => 'Weiter';

  @override
  String get onboardingRecordingStyleExplanation =>
      'Wähl einen Look fürs Mikro. Du kannst ihn jederzeit in den Einstellungen ändern.';

  @override
  String get onboardingRecordingStyleModern => 'Modern — Energie-Orb';

  @override
  String get onboardingRecordingStyleTitle => 'Wie soll die Aufnahme wirken?';

  @override
  String get onboardingRecordingStyleTryVoice => 'Mit deiner Stimme testen';

  @override
  String get onboardingSuccessContinue => 'Los geht\'s';

  @override
  String get onboardingSuccessSubtitle =>
      'Dein KI-Gehirn ist verbunden und verwandelt deine Worte in Aufgaben.';

  @override
  String get onboardingSuccessTitle => 'Alles bereit';

  @override
  String get onboardingWelcomeConnectButton => 'KI-Gehirn wählen';

  @override
  String get onboardingWelcomeMessage =>
      'Verbinde dein KI-Gehirn, sprich einen Gedanken aus und sieh zu, wie er zur strukturierten Aufgabe wird.';

  @override
  String get onboardingWelcomeSkipButton => 'Erst umsehen';

  @override
  String get onboardingWelcomeTitle => 'Sprich. Lotti macht einen Plan daraus.';

  @override
  String get optionalCategoryLabel => 'Kategorie (optional)';

  @override
  String get outboxActionRemove => 'Entfernen';

  @override
  String get outboxActionRetry => 'Erneut versuchen';

  @override
  String get outboxFailedReassurance =>
      'Weiterhin auf diesem Gerät gespeichert – wird synchronisiert, sobald das Problem behoben ist.';

  @override
  String get outboxFilterFailed => 'Fehlgeschlagen';

  @override
  String get outboxFilterWaiting => 'Wartet';

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
  String get outboxMonitorFetchFailed =>
      'Der Postausgang konnte nicht geladen werden. Zieh zum Aktualisieren und versuch es erneut.';

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
  String get outboxMonitorPayloadSizeLabel => 'Größe';

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
  String get outboxMonitorVolumeChartTitle => 'Tägliches Sync-Volumen';

  @override
  String get outboxRemoveConfirmMessage =>
      'Diese Änderung wurde noch nicht synchronisiert. Wenn du sie hier entfernst, erreicht sie deine anderen Geräte nicht. Auf diesem Gerät bleibt sie erhalten.';

  @override
  String get outboxRemoveConfirmTitle => 'Aus der Warteschlange entfernen?';

  @override
  String get outboxRetryAll => 'Alle erneut senden';

  @override
  String get outboxShowDetails => 'Technische Details anzeigen';

  @override
  String get outboxStatusFailed => 'Senden fehlgeschlagen';

  @override
  String get outboxStatusSending => 'Wird gesendet';

  @override
  String get outboxStatusSent => 'Gesendet';

  @override
  String get outboxStatusWaiting => 'Wartet auf Senden';

  @override
  String outboxSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente konnten nicht gesendet werden',
      one: '1 Element konnte nicht gesendet werden',
    );
    return '$_temp0';
  }

  @override
  String outboxSummaryOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente werden gesendet, sobald du wieder verbunden bist',
      one: '1 Element wird gesendet, sobald du wieder verbunden bist',
    );
    return '$_temp0';
  }

  @override
  String outboxSummarySending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente werden gesendet…',
      one: '1 Element wird gesendet…',
    );
    return '$_temp0';
  }

  @override
  String get outboxSummarySynced => 'Alles synchronisiert';

  @override
  String outboxSummaryWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente warten auf Senden',
      one: '1 Element wartet auf Senden',
    );
    return '$_temp0';
  }

  @override
  String outboxTriedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-mal versucht',
      one: '1-mal versucht',
    );
    return '$_temp0';
  }

  @override
  String get panasCompletionText => 'Danke, dass du PANAS ausgefüllt hast!';

  @override
  String get panasCompletionTitle => 'Fertig';

  @override
  String get panasEmotionActive => 'Aktiv';

  @override
  String get panasEmotionAfraid => 'Verängstigt';

  @override
  String get panasEmotionAlert => 'Wachsam';

  @override
  String get panasEmotionAshamed => 'Beschämt';

  @override
  String get panasEmotionAttentive => 'Aufmerksam';

  @override
  String get panasEmotionDetermined => 'Entschlossen';

  @override
  String get panasEmotionDistressed => 'Bedrückt';

  @override
  String get panasEmotionEnthusiastic => 'Enthusiastisch';

  @override
  String get panasEmotionExcited => 'Aufgeregt';

  @override
  String get panasEmotionGuilty => 'Schuldig';

  @override
  String get panasEmotionHostile => 'Feindselig';

  @override
  String get panasEmotionInspired => 'Inspiriert';

  @override
  String get panasEmotionInterested => 'Interessiert';

  @override
  String get panasEmotionIrritable => 'Reizbar';

  @override
  String get panasEmotionJittery => 'Zittrig';

  @override
  String get panasEmotionNervous => 'Nervös';

  @override
  String get panasEmotionProud => 'Stolz';

  @override
  String get panasEmotionScared => 'Ängstlich';

  @override
  String get panasEmotionStrong => 'Stark';

  @override
  String get panasEmotionUpset => 'Verärgert';

  @override
  String get panasInstructionFootnote =>
      'Watson, D., Clark, L. A., & Tellegen, A. (1988). Development and validation of brief measures of positive and negative affect: The PANAS scales. Journal of Personality and Social Psychology, 54(6), 1063–1070.';

  @override
  String get panasInstructionText =>
      'Gib an, wie stark du dich genau jetzt, in diesem Moment, so fühlst.\n\n1—Gar nicht oder nur sehr wenig,\n2—Ein wenig,\n3—Mäßig,\n4—Ziemlich,\n5—Extrem';

  @override
  String get panasInstructionTitle =>
      'Skala für positive und negative Affekte (PANAS; Watson et al., 1988)';

  @override
  String get panasScaleALittle => 'Ein wenig';

  @override
  String get panasScaleExtremely => 'Extrem';

  @override
  String get panasScaleModerately => 'Mäßig';

  @override
  String get panasScaleQuiteABit => 'Ziemlich';

  @override
  String get panasScaleVerySlightlyOrNotAtAll =>
      'Gar nicht oder nur sehr wenig';

  @override
  String get privateLabel => 'Privat';

  @override
  String get privateSwitchDescription =>
      'Nur sichtbar, wenn private Einträge angezeigt werden';

  @override
  String get projectActionAddTask => 'Aufgabe hinzufügen';

  @override
  String get projectActionArchive => 'Archivieren';

  @override
  String get projectActionDelete => 'Löschen';

  @override
  String get projectActionEdit => 'Projekt bearbeiten';

  @override
  String get projectAgentNotProvisioned =>
      'Für dieses Projekt wurde noch kein Projekt-Agent eingerichtet.';

  @override
  String get projectAgentSectionTitle => 'Agent';

  @override
  String get projectArchiveSuccess => 'Projekt archiviert';

  @override
  String projectCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Projekte',
      one: '$count Projekt',
    );
    return '$_temp0';
  }

  @override
  String get projectCreateButton => 'Neues Projekt';

  @override
  String get projectCreateTitle => 'Projekt erstellen';

  @override
  String get projectDeleteConfirmBody =>
      'Das Projekt wird entfernt. Seine Aufgaben bleiben in deinem Journal.';

  @override
  String get projectDeleteConfirmTitle => 'Dieses Projekt löschen?';

  @override
  String get projectDeleteFailed =>
      'Das Projekt konnte nicht gelöscht werden. Versuch es erneut.';

  @override
  String get projectDeleteSuccess => 'Projekt gelöscht';

  @override
  String get projectDetailTitle => 'Projektdetails';

  @override
  String get projectErrorCreateFailed => 'Fehler beim Erstellen des Projekts.';

  @override
  String get projectErrorLoadFailed =>
      'Projektdaten konnten nicht geladen werden.';

  @override
  String get projectErrorLoadProjects => 'Fehler beim Laden der Projekte';

  @override
  String get projectErrorUpdateFailed =>
      'Projekt konnte nicht aktualisiert werden. Bitte versuche es erneut.';

  @override
  String get projectFilterLabel => 'Projekt';

  @override
  String get projectHealthBandAtRisk => 'Riskant';

  @override
  String get projectHealthBandBlocked => 'Blockiert';

  @override
  String get projectHealthBandOnTrack => 'Im Plan';

  @override
  String get projectHealthBandSurviving => 'Über Wasser';

  @override
  String get projectHealthBandWatch => 'Beobachten';

  @override
  String projectHealthConfidence(int confidence) {
    return '$confidence % Sicherheit';
  }

  @override
  String get projectHealthEmptyBody =>
      'Starte den Projektagenten, um aus den neuesten Projekt- und Aufgabenaktivitäten eine Einschätzung zu erstellen.';

  @override
  String get projectHealthEmptyTitle => 'Noch kein Statusbericht';

  @override
  String get projectHealthRunNow => 'Bericht erstellen';

  @override
  String get projectHealthSectionTitle => 'Projektgesundheit';

  @override
  String projectHealthSummary(int projectCount, int taskCount) {
    String _temp0 = intl.Intl.pluralLogic(
      projectCount,
      locale: localeName,
      other: '$projectCount Projekte',
      one: '$projectCount Projekt',
    );
    String _temp1 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: '$taskCount Aufgaben',
      one: '$taskCount Aufgabe',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get projectHealthTitle => 'Projekte';

  @override
  String projectLinkedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verknüpfte Aufgaben',
      one: '$count verknüpfte Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String get projectLinkedTasks => 'Verknüpfte Aufgaben';

  @override
  String get projectManageTooltip => 'Projekte verwalten';

  @override
  String get projectNoLinkedTasks => 'Noch keine Aufgaben verknüpft';

  @override
  String get projectNoProjects => 'Noch keine Projekte';

  @override
  String get projectNotFound => 'Projekt nicht gefunden';

  @override
  String get projectPickerLabel => 'Projekt';

  @override
  String get projectPickerUnassigned => 'Kein Projekt';

  @override
  String get projectRecommendationDismissTooltip => 'Ausblenden';

  @override
  String get projectRecommendationResolveTooltip => 'Als erledigt markieren';

  @override
  String get projectRecommendationsTitle => 'Empfohlene nächste Schritte';

  @override
  String get projectRecommendationUpdateError =>
      'Die Empfehlung konnte nicht aktualisiert werden. Bitte versuche es erneut.';

  @override
  String get projectsClearFilters => 'Filter löschen';

  @override
  String get projectsEmptyBody =>
      'Erstelle ein Projekt, um zusammengehörige Aufgaben, Fortschritt und Agenten-Einblicke zu bündeln.';

  @override
  String get projectsEmptyCurrentBody =>
      'Abgeschlossene und archivierte Projekte sind ausgeblendet. Wechsle zu Alle, um sie wiederzusehen.';

  @override
  String get projectsEmptyCurrentTitle => 'Keine aktuellen Projekte';

  @override
  String get projectsEmptyFilteredBody =>
      'Passe Suche oder Filter an, um passende Projekte wieder anzuzeigen.';

  @override
  String get projectsEmptyFilteredTitle =>
      'Keine Projekte passen zu dieser Ansicht';

  @override
  String get projectsEmptyTitle => 'Starte dein erstes Projekt';

  @override
  String get projectsFilterStatusLabel => 'Status:';

  @override
  String get projectsFilterTooltip => 'Projekte filtern';

  @override
  String get projectShowcaseAiReportTitle => 'AI-Bericht';

  @override
  String projectShowcaseBlockedLegend(int count) {
    return '$count Blockiert';
  }

  @override
  String projectShowcaseBlockedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blockierte Aufgaben',
      one: '$count blockierte Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseCompletedLegend(int count) {
    return '$count Abgeschlossen';
  }

  @override
  String get projectShowcaseDescriptionTitle => 'Beschreibung';

  @override
  String projectShowcaseDueDate(String date) {
    return 'Fällig $date';
  }

  @override
  String get projectShowcaseHealthScoreDescription =>
      'Dieser Wert basiert auf Aufgabentempo, Blockern und der verbleibenden Zeit bis zur Deadline.';

  @override
  String get projectShowcaseHealthScoreTitle => 'Gesundheitswert';

  @override
  String get projectShowcaseNoResults =>
      'Keine Projekte passen zu deiner Suche.';

  @override
  String get projectShowcaseOneOnOneReviewsTab => '1:1-Reviews';

  @override
  String get projectShowcaseOngoing => 'Laufend';

  @override
  String get projectShowcaseProjectTasksTab => 'Projektaufgaben';

  @override
  String get projectShowcaseSearchHint => 'Projekte suchen';

  @override
  String projectShowcaseSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sitzungen',
      one: '$count Sitzung',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseTasksCompleted(int completed, int total) {
    return '$completed/$total Aufgaben abgeschlossen';
  }

  @override
  String projectShowcaseUpdatedHoursAgo(int hours) {
    return 'Aktualisiert vor $hours Std. ↻';
  }

  @override
  String projectShowcaseUpdatedMinutesAgo(int minutes) {
    return 'Aktualisiert vor $minutes Min. ↻';
  }

  @override
  String get projectShowcaseUsefulness => 'Nützlichkeit';

  @override
  String get projectShowcaseViewBlocker => 'Blocker ansehen';

  @override
  String get projectsScopeAll => 'Alle';

  @override
  String get projectsScopeCurrent => 'Aktuell';

  @override
  String get projectsSortActionable => 'Aufmerksamkeit nötig';

  @override
  String get projectsSortName => 'Name';

  @override
  String get projectsSortRecent => 'Kürzlich aktualisiert';

  @override
  String get projectsSortTargetDate => 'Zieldatum';

  @override
  String get projectsSortTooltip => 'Projekte sortieren';

  @override
  String get projectStatusActive => 'Aktiv';

  @override
  String get projectStatusArchived => 'Archiviert';

  @override
  String get projectStatusChangeTitle => 'Status ändern';

  @override
  String get projectStatusCompleted => 'Abgeschlossen';

  @override
  String get projectStatusMonitoring => 'Beobachtung';

  @override
  String get projectStatusOnHold => 'Pausiert';

  @override
  String get projectStatusOpen => 'Offen';

  @override
  String get projectSummaryOutdated => 'Zusammenfassung ist veraltet.';

  @override
  String projectSummaryOutdatedScheduled(String date, String time) {
    return 'Zusammenfassung ist veraltet. Nächste Aktualisierung am $date um $time.';
  }

  @override
  String get projectsUnavailableCategory => 'Nicht verfügbare Kategorie';

  @override
  String get projectTargetDateLabel => 'Zieldatum';

  @override
  String get projectTaskProgressNone => 'Keine Aufgaben';

  @override
  String get projectTitleLabel => 'Projekttitel';

  @override
  String get projectTitleRequired => 'Der Projekttitel darf nicht leer sein';

  @override
  String get promptDefaultModelBadge => 'Standard';

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
  String get promptSelectionModalTitle => 'Vorkonfigurierten Prompt auswählen';

  @override
  String get provisionedSyncCopiedToClipboard =>
      'In die Zwischenablage kopiert';

  @override
  String get provisionedSyncDisconnect => 'Sync auf diesem Gerät beenden';

  @override
  String get provisionedSyncDone => 'Verbunden';

  @override
  String get provisionedSyncError => 'Dieser Code hat nicht funktioniert';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'Beim Verbinden ist etwas schiefgegangen. Versuche es erneut; wenn es weiter fehlschlägt, prüfe, ob das andere Gerät noch synchronisiert.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'Der Server hat die Zugangsdaten aus dem Code nicht akzeptiert. Ein Code funktioniert nicht mehr, sobald sich das Passwort des Kontos ändert — hol dir einen frischen Code von deinem anderen Gerät, oder versuch es einfach nochmal, falls nur die Verbindung abgebrochen ist.';

  @override
  String get provisionedSyncImportButton => 'Weiter';

  @override
  String get provisionedSyncImportHint => 'Kopplungscode hier einfügen';

  @override
  String get provisionedSyncImportTitle => 'Sync einrichten';

  @override
  String get provisionedSyncJoiningRoom =>
      'Gemeinsamer Speicher wird eingerichtet…';

  @override
  String get provisionedSyncLoggingIn => 'Verbindung zu deinem Sync-Konto…';

  @override
  String get provisionedSyncPasteClipboard => 'Aus Zwischenablage einfügen';

  @override
  String get provisionedSyncRetry => 'Erneut versuchen';

  @override
  String get provisionedSyncRotatingPassword =>
      'Dieses Gerät wird abgesichert…';

  @override
  String get provisionedSyncSubtitle => 'Geräte koppeln und verwalten';

  @override
  String get provisionedSyncSummaryHomeserver => 'Sync-Server';

  @override
  String get provisionedSyncSummaryUser => 'Sync-Konto';

  @override
  String get provisionedSyncTitle => 'Geräte';

  @override
  String get queueCatchUpNowButton => 'Jetzt aufholen';

  @override
  String get queueCatchUpNowDone =>
      'Aufholen gestartet — die Warteschlange wird abgearbeitet.';

  @override
  String queueCatchUpNowError(String reason) {
    return 'Aufholen fehlgeschlagen: $reason';
  }

  @override
  String get queueDepthCardEmpty => 'Warteschlange leer — Worker ist aktuell.';

  @override
  String get queueDepthCardLoading => 'Warteschlangenfüllung wird gelesen…';

  @override
  String get queueDepthCardTitle => 'Eingangs-Warteschlange';

  @override
  String get queueFetchAllHistoryCancel => 'Abbrechen';

  @override
  String queueFetchAllHistoryCancelled(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events Ereignisse',
      one: '1 Ereignis',
      zero: 'keine Ereignisse',
    );
    return 'Abgebrochen — bisher $_temp0 abgerufen.';
  }

  @override
  String get queueFetchAllHistoryClose => 'Schließen';

  @override
  String get queueFetchAllHistoryDescription =>
      'Lädt den gesamten sichtbaren Verlauf des Raums in die Warteschlange. Jederzeit abbrechbar; ein späterer Durchlauf setzt dort an, wo die Paginierung gestoppt hat.';

  @override
  String queueFetchAllHistoryDone(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages Seiten',
      one: '1 Seite',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages Seiten',
      one: '1 Seite',
    );
    String _temp2 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events Ereignisse über $_temp0 abgerufen.',
      one: '1 Ereignis über $_temp1 abgerufen.',
      zero: 'Keine Ereignisse abgerufen.',
    );
    return '$_temp2';
  }

  @override
  String queueFetchAllHistoryError(String reason) {
    return 'Abruf gestoppt: $reason';
  }

  @override
  String get queueFetchAllHistoryErrorUnknown => 'Abruf unerwartet gestoppt.';

  @override
  String queueFetchAllHistoryProgress(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: 'Seite $pages  ·  $events Ereignisse abgerufen',
      one: 'Seite $pages  ·  1 Ereignis abgerufen',
    );
    return '$_temp0';
  }

  @override
  String get queueFetchAllHistoryTitle => 'Verlauf wird geholt';

  @override
  String queueSkippedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count übersprungen',
      one: '1 übersprungen',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedCardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Sync-Ereignisse, die die Warteschlange aufgegeben hat. Tippe auf Wiederholen, um sie erneut zu versuchen.',
      one:
          '1 Sync-Ereignis, das die Warteschlange aufgegeben hat. Tippe auf Wiederholen, um es erneut zu versuchen.',
    );
    return '$_temp0';
  }

  @override
  String get queueSkippedCardTitle => 'Übersprungene Ereignisse';

  @override
  String get queueSkippedRetryAll => 'Übersprungene Ereignisse wiederholen';

  @override
  String queueSkippedRetryAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ereignisse zur Wiederholung eingereiht.',
      one: '1 Ereignis zur Wiederholung eingereiht.',
      zero: 'Keine übersprungenen Ereignisse.',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedRetryAllError(String reason) {
    return 'Wiederholung fehlgeschlagen: $reason';
  }

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
  String referenceImageSelectionSubtitle(int maxImages) {
    return 'Wähle bis zu $maxImages Bilder, um den visuellen Stil der KI zu leiten';
  }

  @override
  String get referenceImageSelectionTitle => 'Referenzbilder auswählen';

  @override
  String get referenceImageSkip => 'Überspringen';

  @override
  String relationshipCadenceEveryNDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Alle $days Tage',
      one: 'Jeden Tag',
    );
    return '$_temp0';
  }

  @override
  String get relationshipCadenceFortnightly => 'Alle zwei Wochen';

  @override
  String get relationshipCadenceLabel => 'Check-in-Rhythmus';

  @override
  String get relationshipCadenceMonthly => 'Monatlich';

  @override
  String get relationshipCadenceNone => 'Kein Rhythmus';

  @override
  String get relationshipCadenceQuarterly => 'Vierteljährlich';

  @override
  String get relationshipCadenceWeekly => 'Wöchentlich';

  @override
  String get relationshipCreateTitle => 'Person hinzufügen';

  @override
  String get relationshipDeleteConfirmMessage =>
      'Auch alle Check-ins werden gelöscht. Das lässt sich nicht rückgängig machen.';

  @override
  String relationshipDeleteConfirmTitle(String name) {
    return '$name löschen?';
  }

  @override
  String get relationshipEditTitle => 'Person bearbeiten';

  @override
  String get relationshipErrorCreateFailed =>
      'Person konnte nicht gespeichert werden. Bitte versuch es erneut.';

  @override
  String get relationshipErrorDeleteFailed =>
      'Person konnte nicht gelöscht werden. Bitte versuch es erneut.';

  @override
  String get relationshipErrorUpdateFailed =>
      'Änderungen konnten nicht gespeichert werden. Bitte versuch es erneut.';

  @override
  String get relationshipImportantDescription =>
      'Erinnere mich, in Kontakt zu bleiben';

  @override
  String get relationshipImportantLabel => 'Wichtig';

  @override
  String get relationshipLogCheckIn => 'Check-in erfassen';

  @override
  String get relationshipNameLabel => 'Name';

  @override
  String get relationshipNameRequired => 'Ein Name ist erforderlich';

  @override
  String get relationshipNicknameLabel => 'Spitzname';

  @override
  String get relationshipNoCheckIns =>
      'Noch keine Check-ins — erfasse einen nach eurem nächsten Gespräch.';

  @override
  String get relationshipNotFound =>
      'Diese Person ist nicht mehr in deiner Liste.';

  @override
  String get relationshipsEmptyState =>
      'Füge die Menschen hinzu, denen du nah bleiben willst.';

  @override
  String get relationshipsPageTitle => 'Menschen';

  @override
  String get relationshipStatusActive => 'Aktiv';

  @override
  String get relationshipStatusArchived => 'Archiviert';

  @override
  String get relationshipStatusDormant => 'Ruhend';

  @override
  String get relationshipStatusFieldLabel => 'Status';

  @override
  String get saveButton => 'Speichern';

  @override
  String get saveButtonLabel => 'Speichern';

  @override
  String get saveLabel => 'Speichern';

  @override
  String get saveShortcutTooltip => 'Speichern — Strg+S (⌘S auf dem Mac)';

  @override
  String get saveSuccessful => 'Erfolgreich gespeichert';

  @override
  String get searchHint => 'Suchen...';

  @override
  String get searchModeFullText => 'Volltext';

  @override
  String get searchModeVector => 'Vektor';

  @override
  String get searchTasksHint => 'Aufgaben suchen…';

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
  String get settingsAboutDailyOsPersonalizationTitle =>
      'Daily-OS-Personalisierung';

  @override
  String get settingsAboutDailyOsUserNameHelper =>
      'Wird für die Daily-OS-Begrüßung verwendet und mit deinen Geräten synchronisiert.';

  @override
  String get settingsAboutDailyOsUserNameLabel => 'Dein Name';

  @override
  String get settingsAboutJournalEntries => 'Tagebucheinträge';

  @override
  String get settingsAboutPlatform => 'Plattform';

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
  String get settingsAdvancedHealthImportSubtitle =>
      'Gesundheitsbezogene Daten aus externen Quellen importieren';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Wartungsaufgaben durchführen, um die Anwendungsleistung zu optimieren';

  @override
  String get settingsAdvancedManualLanguageSubtitle =>
      'Wähle die Sprache, in der das Lotti-Handbuch geöffnet wird';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Elemente anzeigen und verwalten, die auf Synchronisierung warten';

  @override
  String get settingsAdvancedSubtitle => 'Erweiterte Einstellungen und Wartung';

  @override
  String get settingsAdvancedTitle => 'Erweiterte Einstellungen';

  @override
  String get settingsAgentsInstancesSubtitle => 'Laufende Agenten';

  @override
  String get settingsAgentsPendingWakesSubtitle => 'Geplante Aufwachzyklen';

  @override
  String get settingsAgentsSoulsSubtitle =>
      'Langlebige Agenten-Persönlichkeiten';

  @override
  String get settingsAgentsTemplatesSubtitle => 'Geteilte Agenten-Vorlagen';

  @override
  String get settingsAiModelsSubtitle =>
      'Modellzeilen und Fähigkeiten je Anbieter';

  @override
  String get settingsAiModelsTitle => 'Modelle';

  @override
  String get settingsAiProfilesSubtitle => 'Anbieter und Modelle';

  @override
  String get settingsAiProfilesTitle => 'Inferenzprofile';

  @override
  String get settingsAiProvidersSubtitle =>
      'Verbundene KI-Anbieter und Schlüssel';

  @override
  String get settingsAiProvidersTitle => 'Anbieter';

  @override
  String get settingsAiSubtitle =>
      'AI-Anbieter, Modelle und Prompts konfigurieren';

  @override
  String get settingsAiTitle => 'AI-Einstellungen';

  @override
  String get settingsAiUsageSubtitle =>
      'Kosten, Energie und CO₂e deiner KI-Aufrufe';

  @override
  String get settingsAiUsageTitle => 'Verbrauch & Impact';

  @override
  String get settingsBeamPageEditModelTitle => 'Modell bearbeiten';

  @override
  String get settingsBeamPageEditProfileTitle => 'Profil bearbeiten';

  @override
  String get settingsCategoriesCreateTitle => 'Kategorie erstellen';

  @override
  String get settingsCategoriesDetailsLabel => 'Kategorie bearbeiten';

  @override
  String get settingsCategoriesEmptyState => 'Noch keine Kategorien';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Erstelle eine Kategorie, um deine Einträge zu organisieren';

  @override
  String get settingsCategoriesErrorLoading =>
      'Fehler beim Laden der Kategorien';

  @override
  String get settingsCategoriesNameLabel => 'Kategoriename';

  @override
  String settingsCategoriesNoMatchQuery(String query) {
    return 'Keine Kategorien stimmen mit \"$query\" überein';
  }

  @override
  String get settingsCategoriesSearchHint => 'Kategorien suchen…';

  @override
  String get settingsCategoriesSubtitle => 'Kategorien mit AI-Einstellungen';

  @override
  String settingsCategoriesTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben',
      one: '$count Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String get settingsCategoriesTitle => 'Kategorien';

  @override
  String get settingsCelebrationsChecklistDescription =>
      'Ein Pop und Funken, wenn du einen Eintrag abhakst';

  @override
  String get settingsCelebrationsChecklistTitle => 'Checklisten-Einträge';

  @override
  String get settingsCelebrationsCustomizeTitle => 'Anpassen';

  @override
  String get settingsCelebrationsCustomizeTooltip => 'Diesen Stil anpassen';

  @override
  String get settingsCelebrationsEnabledDescription =>
      'Hauptschalter für alle Abschluss-Effekte. Aus blendet jede Animation aus; Haptik hat ihren eigenen Schalter.';

  @override
  String get settingsCelebrationsEnabledTitle => 'Abschluss-Animationen';

  @override
  String get settingsCelebrationsGroupLook => 'Aussehen';

  @override
  String get settingsCelebrationsGroupMotion => 'Bewegung';

  @override
  String get settingsCelebrationsGroupShape => 'Form';

  @override
  String get settingsCelebrationsHabitsDescription =>
      'Leuchten und Funken, wenn du eine Gewohnheit abschließt';

  @override
  String get settingsCelebrationsHabitsTitle => 'Gewohnheiten';

  @override
  String get settingsCelebrationsHapticsDescription =>
      'Ein kurzes Vibrieren, wenn du etwas abschließt – unabhängig von der Animation.';

  @override
  String get settingsCelebrationsHapticsTitle => 'Abschluss-Haptik';

  @override
  String get settingsCelebrationsKnobClearCenter => 'Mittelabstand';

  @override
  String get settingsCelebrationsKnobCount => 'Partikel';

  @override
  String get settingsCelebrationsKnobDescClearCenter =>
      'Freier Raum in der Mitte';

  @override
  String get settingsCelebrationsKnobDescCount =>
      'Wie viele Partikel herausfliegen';

  @override
  String get settingsCelebrationsKnobDescFallout =>
      'Wie weit Funken herabrieseln';

  @override
  String get settingsCelebrationsKnobDescFanSpread => 'Breite des Fächers';

  @override
  String get settingsCelebrationsKnobDescGlow => 'Stärke des Leuchtens';

  @override
  String get settingsCelebrationsKnobDescGravity =>
      'Wie schnell Partikel fallen';

  @override
  String get settingsCelebrationsKnobDescHalo => 'Stärke des Halos';

  @override
  String get settingsCelebrationsKnobDescInnerRing => 'Größe des inneren Rings';

  @override
  String get settingsCelebrationsKnobDescLaunch =>
      'Verzögerung vor dem Ausbruch';

  @override
  String get settingsCelebrationsKnobDescPop => 'Wann sie platzen';

  @override
  String get settingsCelebrationsKnobDescReach => 'Wie weit Partikel fliegen';

  @override
  String get settingsCelebrationsKnobDescRise => 'Wie hoch Partikel aufsteigen';

  @override
  String get settingsCelebrationsKnobDescSize => 'Wie groß jedes Partikel ist';

  @override
  String get settingsCelebrationsKnobDescSpeedSpread =>
      'Unterschied in der Geschwindigkeit';

  @override
  String get settingsCelebrationsKnobDescSpin =>
      'Wie schnell Teile sich drehen';

  @override
  String get settingsCelebrationsKnobDescSpread => 'Breite des Sprühens';

  @override
  String get settingsCelebrationsKnobDescSway => 'Wie stark Teile schwanken';

  @override
  String get settingsCelebrationsKnobDescSwell => 'Wie stark sie wachsen';

  @override
  String get settingsCelebrationsKnobDescTrail => 'Länge der Spur';

  @override
  String get settingsCelebrationsKnobDescTwinkle =>
      'Wie stark Partikel funkeln';

  @override
  String get settingsCelebrationsKnobDescUpward => 'Wie stark sie aufsteigen';

  @override
  String get settingsCelebrationsKnobDescWobble => 'Wie stark Teile wackeln';

  @override
  String get settingsCelebrationsKnobFallout => 'Niederfall';

  @override
  String get settingsCelebrationsKnobFanSpread => 'Fächerbreite';

  @override
  String get settingsCelebrationsKnobGlow => 'Leuchten';

  @override
  String get settingsCelebrationsKnobGravity => 'Schwerkraft';

  @override
  String get settingsCelebrationsKnobHalo => 'Halo';

  @override
  String get settingsCelebrationsKnobInnerRing => 'Innerer Ring';

  @override
  String get settingsCelebrationsKnobLaunch => 'Startzeit';

  @override
  String get settingsCelebrationsKnobPop => 'Platzpunkt';

  @override
  String get settingsCelebrationsKnobReach => 'Reichweite';

  @override
  String get settingsCelebrationsKnobRise => 'Steighöhe';

  @override
  String get settingsCelebrationsKnobSize => 'Größe';

  @override
  String get settingsCelebrationsKnobSpeedSpread => 'Geschwindigkeitsvariation';

  @override
  String get settingsCelebrationsKnobSpin => 'Drehung';

  @override
  String get settingsCelebrationsKnobSpread => 'Streuwinkel';

  @override
  String get settingsCelebrationsKnobSway => 'Schwanken';

  @override
  String get settingsCelebrationsKnobSwell => 'Anschwellen';

  @override
  String get settingsCelebrationsKnobTrail => 'Schweiflänge';

  @override
  String get settingsCelebrationsKnobTwinkle => 'Funkeln';

  @override
  String get settingsCelebrationsKnobUpward => 'Aufstieg';

  @override
  String get settingsCelebrationsKnobWobble => 'Wackeln';

  @override
  String get settingsCelebrationsPlaygroundHint =>
      'Tippe die markierte Zeile an für eine Vorschau';

  @override
  String get settingsCelebrationsPlaygroundLiveNote =>
      'Änderungen werden sofort überall gespeichert und angewendet';

  @override
  String get settingsCelebrationsPreviewChecklistItem => 'Hak mich ab';

  @override
  String get settingsCelebrationsPreviewDescription =>
      'Tippe ein Element an, um deinen Stil abzuspielen.';

  @override
  String get settingsCelebrationsPreviewDone => 'Erledigt';

  @override
  String get settingsCelebrationsPreviewHabit => 'Gewohnheit';

  @override
  String get settingsCelebrationsPreviewSample1 => 'Morgenspaziergang';

  @override
  String get settingsCelebrationsPreviewSample2 => 'Bericht fertigstellen';

  @override
  String get settingsCelebrationsPreviewSample3 => 'Pflanzen gießen';

  @override
  String get settingsCelebrationsPreviewTitle => 'Ausprobieren';

  @override
  String get settingsCelebrationsReplay => 'Erneut abspielen';

  @override
  String get settingsCelebrationsResetToast =>
      'Stil auf Standard zurückgesetzt';

  @override
  String get settingsCelebrationsResetToDefault => 'Auf Standard zurücksetzen';

  @override
  String get settingsCelebrationsResetUndo => 'Rückgängig';

  @override
  String get settingsCelebrationsSectionDescription =>
      'Eine kleine Feier, wenn du etwas abschließt. Schaltest du eine aus, bleibt der Abschluss samt Haptik erhalten – nur die Animation entfällt.';

  @override
  String get settingsCelebrationsSectionTitle => 'Feiern beim Abschließen';

  @override
  String get settingsCelebrationsStyleDescription =>
      'Tippe eine Karte an, um einen Stil vorzuschauen und auszuwählen.';

  @override
  String get settingsCelebrationsStyleTitle => 'Stil';

  @override
  String get settingsCelebrationsSubtitle => 'Feiern beim Abschließen';

  @override
  String get settingsCelebrationsTasksDescription =>
      'Leuchten und Funken, wenn du eine Aufgabe auf Erledigt setzt';

  @override
  String get settingsCelebrationsTasksTitle => 'Aufgaben';

  @override
  String get settingsCelebrationsTitle => 'Animationen';

  @override
  String get settingsCelebrationsVariantBubbles => 'Blasen';

  @override
  String get settingsCelebrationsVariantCombine => 'Zwei kombinieren';

  @override
  String get settingsCelebrationsVariantCombineDescription =>
      'Jedes Mal zwei zufällige Stile, überlagert';

  @override
  String get settingsCelebrationsVariantConfetti => 'Konfetti';

  @override
  String get settingsCelebrationsVariantEmbers => 'Glut';

  @override
  String get settingsCelebrationsVariantFireworks => 'Feuerwerk';

  @override
  String get settingsCelebrationsVariantRandom => 'Zufällig';

  @override
  String get settingsCelebrationsVariantRandomDescription =>
      'Jedes Mal ein neuer Stil';

  @override
  String get settingsCelebrationsVariantSparks => 'Funken';

  @override
  String get settingsConflictsTitle => 'Synchronisierungskonflikte';

  @override
  String get settingsDashboardDetailsLabel => 'Dashboard bearbeiten';

  @override
  String get settingsDashboardSaveLabel => 'Speichern';

  @override
  String get settingsDashboardsCreateTitle => 'Dashboard erstellen';

  @override
  String get settingsDashboardsEmptyState => 'Noch keine Dashboards';

  @override
  String get settingsDashboardsEmptyStateHint =>
      'Tippe auf +, um dein erstes Dashboard zu erstellen.';

  @override
  String get settingsDashboardsErrorLoading =>
      'Fehler beim Laden der Dashboards';

  @override
  String settingsDashboardsNoMatchQuery(String query) {
    return 'Keine Dashboards passend zu \"$query\"';
  }

  @override
  String get settingsDashboardsSearchHint => 'Dashboards durchsuchen…';

  @override
  String get settingsDashboardsSubtitle => 'Deine Dashboard-Ansichten anpassen';

  @override
  String get settingsDashboardsTitle => 'Dashboards';

  @override
  String get settingsDefinitionsSubtitle =>
      'Gewohnheiten, Kategorien, Labels, Dashboards und Messgrößen';

  @override
  String get settingsDefinitionsTitle => 'Definitionen';

  @override
  String get settingsFlagsEmptySearch => 'Keine Flags entsprechen deiner Suche';

  @override
  String get settingsFlagsSearchHint => 'Flags durchsuchen';

  @override
  String get settingsFlagsSubtitle =>
      'Feature-Flags und Optionen konfigurieren';

  @override
  String get settingsFlagsTitle => 'Konfigurationsflags';

  @override
  String get settingsHabitsCreateTitle => 'Gewohnheit erstellen';

  @override
  String get settingsHabitsDeleteTooltip => 'Gewohnheit löschen';

  @override
  String get settingsHabitsDescriptionLabel => 'Beschreibung (optional)';

  @override
  String get settingsHabitsDetailsLabel => 'Gewohnheit bearbeiten';

  @override
  String get settingsHabitsEmptyState => 'Noch keine Gewohnheiten';

  @override
  String get settingsHabitsEmptyStateHint =>
      'Tippe auf +, um deine erste Gewohnheit zu erstellen.';

  @override
  String get settingsHabitsErrorLoading => 'Fehler beim Laden der Gewohnheiten';

  @override
  String get settingsHabitsNameLabel => 'Name der Gewohnheit';

  @override
  String settingsHabitsNoMatchQuery(String query) {
    return 'Keine Gewohnheiten passend zu \"$query\"';
  }

  @override
  String get settingsHabitsPrivateLabel => 'Privat: ';

  @override
  String get settingsHabitsSaveLabel => 'Speichern';

  @override
  String get settingsHabitsSearchHint => 'Gewohnheiten durchsuchen…';

  @override
  String get settingsHabitsSubtitle =>
      'Deine Gewohnheiten und Routinen verwalten';

  @override
  String get settingsHabitsTitle => 'Gewohnheiten';

  @override
  String get settingsHealthImportAccessHint =>
      'Einige Daten konnten nicht gelesen werden. Wenn du Lottis Zugriff in den Health-Datenschutzeinstellungen deines Geräts deaktiviert hast, kann Lotti ihn nicht erneut anfordern – schalte ihn dort wieder ein.';

  @override
  String get settingsHealthImportActivity => 'Aktivität';

  @override
  String get settingsHealthImportActivityDescription =>
      'Schritte, Stockwerke und Gehstrecke';

  @override
  String get settingsHealthImportAll => 'Alles importieren';

  @override
  String get settingsHealthImportBloodPressure => 'Blutdruck';

  @override
  String get settingsHealthImportBloodPressureDescription =>
      'Systolische und diastolische Werte';

  @override
  String get settingsHealthImportBodyMeasurement => 'Körpermaße';

  @override
  String get settingsHealthImportBodyMeasurementDescription =>
      'Gewicht, Körperfett, BMI und Größe';

  @override
  String get settingsHealthImportDataSectionTitle => 'Zu importierende Daten';

  @override
  String get settingsHealthImportFromDate => 'Start';

  @override
  String get settingsHealthImportHeartRate => 'Herzfrequenz';

  @override
  String get settingsHealthImportHeartRateDescription =>
      'Ruhepuls, Gehpuls und Variabilität';

  @override
  String get settingsHealthImportOpenSettings => 'Einstellungen öffnen';

  @override
  String settingsHealthImportQuickRange(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Letzte $days Tage',
      one: 'Letzter Tag',
    );
    return '$_temp0';
  }

  @override
  String get settingsHealthImportRangeSectionTitle => 'Zeitraum';

  @override
  String get settingsHealthImportSleep => 'Schlaf';

  @override
  String get settingsHealthImportSleepDescription =>
      'Bettzeit und Schlafphasen';

  @override
  String get settingsHealthImportStatusFailed =>
      'Import fehlgeschlagen – sieh in die Logs';

  @override
  String settingsHealthImportStatusImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Werte importiert',
      one: '1 Wert importiert',
      zero: 'Keine neuen Werte',
    );
    return '$_temp0';
  }

  @override
  String get settingsHealthImportStatusNoDataOrAccess =>
      'Keine Daten – prüfe Lottis Zugriff in deiner Health-App';

  @override
  String get settingsHealthImportStatusPermissionDenied =>
      'Zugriff verweigert – erlaube Lotti den Zugriff in deiner Health-App';

  @override
  String get settingsHealthImportStatusRunning => 'Wird importiert …';

  @override
  String get settingsHealthImportStatusUnsupportedType =>
      'Dieser Datentyp wird nicht mehr unterstützt';

  @override
  String get settingsHealthImportSubtitle =>
      'Aus Apple Health oder Health Connect importieren';

  @override
  String get settingsHealthImportTitle => 'Gesundheitsdatenimport';

  @override
  String get settingsHealthImportToDate => 'Ende';

  @override
  String get settingsHealthImportUnavailable =>
      'Gesundheitsdaten gibt es nur unter iOS und Android';

  @override
  String get settingsHealthImportWorkout => 'Trainings';

  @override
  String get settingsHealthImportWorkoutDescription =>
      'Trainings mit Strecke und verbrauchter Energie';

  @override
  String get settingsKeyboardShortcutsSubtitle =>
      'Lerne die Tastenkombinationen für schnellere Navigation und Bearbeitung am Desktop kennen';

  @override
  String get settingsKeyboardShortcutsTitle => 'Tastaturkurzbefehle';

  @override
  String get settingsLabelsCategoriesAdd => 'Kategorie hinzufügen';

  @override
  String get settingsLabelsCategoriesHeading => 'Anwendbare Kategorien';

  @override
  String get settingsLabelsCategoriesNone => 'Gilt für alle Kategorien';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Entfernen';

  @override
  String get settingsLabelsColorHeading => 'Farbe';

  @override
  String get settingsLabelsColorSubheading => 'Schnellauswahl';

  @override
  String get settingsLabelsCreateTitle => 'Label erstellen';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Löschen';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return 'Möchtest du das Label \"$labelName\" wirklich löschen? Aufgaben mit diesem Label verlieren die Zuordnung.';
  }

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Label löschen';

  @override
  String settingsLabelsDeleteSuccess(Object labelName) {
    return 'Label \"$labelName\" wurde gelöscht';
  }

  @override
  String get settingsLabelsDescriptionHint =>
      'Erkläre, wann dieses Label verwendet werden soll';

  @override
  String get settingsLabelsDescriptionLabel => 'Beschreibung (optional)';

  @override
  String get settingsLabelsEditTitle => 'Label bearbeiten';

  @override
  String get settingsLabelsEmptyState => 'Noch keine Labels';

  @override
  String get settingsLabelsEmptyStateHint =>
      'Tippe auf +, um dein erstes Label zu erstellen.';

  @override
  String get settingsLabelsErrorLoading =>
      'Labels konnten nicht geladen werden';

  @override
  String get settingsLabelsNameHint => 'Fehler, Release-Blocker, Sync…';

  @override
  String get settingsLabelsNameLabel => 'Labelname';

  @override
  String settingsLabelsNoMatchCreate(String query) {
    return 'Label \"$query\" erstellen';
  }

  @override
  String settingsLabelsNoMatchQuery(String query) {
    return 'Keine Labels passend zu \"$query\"';
  }

  @override
  String get settingsLabelsPrivateDescription =>
      'Nur sichtbar, wenn private Einträge angezeigt werden';

  @override
  String get settingsLabelsPrivateTitle => 'Privat';

  @override
  String get settingsLabelsSearchHint => 'Labels durchsuchen…';

  @override
  String get settingsLabelsSubtitle =>
      'Aufgaben mit farbigen Labels organisieren';

  @override
  String get settingsLabelsTitle => 'Labels';

  @override
  String settingsLabelsUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben',
      one: '1 Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String get settingsLoggingDomainsSubtitle =>
      'Steuere, welche Bereiche ins Protokoll schreiben';

  @override
  String get settingsLoggingDomainsTitle => 'Protokoll-Bereiche';

  @override
  String get settingsLoggingGlobalToggle => 'Protokollierung aktivieren';

  @override
  String get settingsLoggingGlobalToggleSubtitle =>
      'Hauptschalter für die gesamte Protokollierung';

  @override
  String get settingsLoggingSlowQueries => 'Langsame Datenbankabfragen';

  @override
  String get settingsLoggingSlowQueriesSubtitle =>
      'Langsame Abfragen werden in slow_queries-YYYY-MM-DD.log geschrieben';

  @override
  String get settingsMaintenanceOnboardingAnimationGallerySubtitle =>
      'Vergleiche Begrüßungsanimationen und die Verbindungsseite live (Debug)';

  @override
  String get settingsMaintenanceOnboardingAnimationGalleryTitle =>
      'Onboarding-Animationsgalerie';

  @override
  String get settingsMaintenanceOnboardingWelcomeSubtitle =>
      'Vorschau der FTUE-Begrüßung und Anbieter-Kacheln (Debug)';

  @override
  String get settingsMaintenanceOnboardingWelcomeTitle =>
      'Onboarding-Begrüßung anzeigen';

  @override
  String get settingsMaintenanceTitle => 'Wartung';

  @override
  String get settingsManualLanguageCzechTitle => 'Tschechisch';

  @override
  String get settingsManualLanguageDanishTitle => 'Dänisch';

  @override
  String get settingsManualLanguageDutchTitle => 'Niederländisch';

  @override
  String get settingsManualLanguageEnglishTitle => 'Englisch';

  @override
  String get settingsManualLanguageFollowSystemSubtitle =>
      'Verwende die Sprache deines Geräts in Lotti und im Handbuch, wenn sie unterstützt wird; andernfalls Englisch.';

  @override
  String get settingsManualLanguageFollowSystemTitle =>
      'Systemsprache verwenden';

  @override
  String get settingsManualLanguageFrenchTitle => 'Französisch';

  @override
  String get settingsManualLanguageGermanTitle => 'Deutsch';

  @override
  String get settingsManualLanguageItalianTitle => 'Italienisch';

  @override
  String get settingsManualLanguagePortugueseTitle => 'Portugiesisch';

  @override
  String get settingsManualLanguageRomanianTitle => 'Rumänisch';

  @override
  String get settingsManualLanguageSpanishTitle => 'Spanisch';

  @override
  String get settingsManualLanguageSwedishTitle => 'Schwedisch';

  @override
  String get settingsManualLanguageTitle => 'Sprache';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'Anderes Gerät zeigt Emojis, fortfahren';

  @override
  String get settingsMatrixCancel => 'Abbrechen';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Auf anderem Gerät akzeptieren, um fortzufahren';

  @override
  String get settingsMatrixDiagnosticCopied =>
      'Diagnoseinfos in die Zwischenablage kopiert';

  @override
  String get settingsMatrixDiagnosticCopyButton => 'In Zwischenablage kopieren';

  @override
  String get settingsMatrixDiagnosticDialogTitle => 'Sync-Diagnoseinfos';

  @override
  String get settingsMatrixDiagnosticShowButton => 'Technische Details';

  @override
  String get settingsMatrixLastUpdated => 'Zuletzt aktualisiert:';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Matrix-Wartung und Wiederherstellung';

  @override
  String get settingsMatrixMaintenanceTitle => 'Wartung';

  @override
  String get settingsMatrixMetrics => 'Sync-Metriken';

  @override
  String get settingsMatrixNextPage => 'Nächste Seite';

  @override
  String get settingsMatrixPreviousPage => 'Vorherige Seite';

  @override
  String get settingsMatrixSentMessagesLabel => 'Gesendete Nachrichten:';

  @override
  String settingsMatrixSentMessageType(String eventType) {
    return 'Gesendet ($eventType)';
  }

  @override
  String get settingsMatrixStartVerificationLabel => 'Verifizierung starten';

  @override
  String get settingsMatrixStatsTitle => 'Matrix-Statistiken';

  @override
  String get settingsMatrixTitle => 'Synchronisierungseinstellungen';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Auf anderem Gerät abgebrochen...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Verstanden';

  @override
  String get settingsMatrixVerifyLabel => 'Verifizieren';

  @override
  String get settingsMeasurableAggregationHelper =>
      'Wie die Einträge eines Tages in Diagrammen zusammengefasst werden';

  @override
  String get settingsMeasurableAggregationLabel => 'Standard-Aggregation';

  @override
  String get settingsMeasurableDeleteTooltip => 'Messgröße löschen';

  @override
  String get settingsMeasurableDescriptionLabel => 'Beschreibung (optional)';

  @override
  String get settingsMeasurableDetailsLabel => 'Messgröße bearbeiten';

  @override
  String get settingsMeasurableNameLabel => 'Name der Messgröße';

  @override
  String get settingsMeasurablePrivateLabel => 'Privat: ';

  @override
  String get settingsMeasurableSaveLabel => 'Speichern';

  @override
  String get settingsMeasurablesCreateTitle => 'Messgröße erstellen';

  @override
  String get settingsMeasurablesEmptyState => 'Noch keine Messgrößen';

  @override
  String get settingsMeasurablesEmptyStateHint =>
      'Messgrößen sind Zahlen, die du über die Zeit verfolgst — Gewicht, Wasser, Schritte.';

  @override
  String get settingsMeasurablesErrorLoading =>
      'Fehler beim Laden der Messgrößen';

  @override
  String settingsMeasurablesNoMatchQuery(String query) {
    return 'Keine Messgrößen passend zu \"$query\"';
  }

  @override
  String get settingsMeasurablesSearchHint => 'Messgrößen durchsuchen…';

  @override
  String get settingsMeasurablesSubtitle => 'Messbare Datentypen konfigurieren';

  @override
  String get settingsMeasurablesTitle => 'Messgrößen';

  @override
  String get settingsMeasurableUnitLabel => 'Einheitenabkürzung (optional)';

  @override
  String get settingsOnboardingActionSubtitle =>
      'Öffne den Willkommens-Ablauf erneut – verbinde dein KI-Gehirn und erstelle eine Aufgabe';

  @override
  String get settingsOnboardingMetricsSubtitle =>
      'FTUE-Funnel – Installation, Aktivierung, Bindung (Debug)';

  @override
  String get settingsOnboardingMetricsTitle => 'Onboarding-Metriken';

  @override
  String get settingsOnboardingReplayTitle => 'Onboarding wiederholen';

  @override
  String get settingsOnboardingStartTitle => 'Onboarding starten';

  @override
  String get settingsOnboardingStatusActivated =>
      'Du hast deine erste KI-Aufgabe erstellt';

  @override
  String get settingsOnboardingStatusLoading => 'Wird geladen…';

  @override
  String get settingsOnboardingStatusNotActivated => 'Noch nicht gestartet';

  @override
  String get settingsOnboardingStatusTitle => 'Status';

  @override
  String get settingsOnboardingSubtitle =>
      'Den Willkommens-Ablauf jederzeit erneut anzeigen';

  @override
  String get settingsOnboardingTestResetConfirm => 'Zurücksetzen';

  @override
  String get settingsOnboardingTestResetConfirmQuestion =>
      'Onboarding-Hinweisverlauf und Metriken löschen? Bestehende Daily-OS-Pläne bleiben erhalten. Nutze daher ein neues Profil, um den vollständigen ersten Daily-OS-Durchlauf zu testen.';

  @override
  String get settingsOnboardingTestResetSubtitle =>
      'Löscht Hinweisverlauf und Metriken; bestehende Daily-OS-Pläne bleiben erhalten (Debug)';

  @override
  String get settingsOnboardingTestResetTitle =>
      'Onboarding-Teststatus zurücksetzen';

  @override
  String get settingsOnboardingTitle => 'Onboarding';

  @override
  String get settingsOptionsTitle => 'Optionen';

  @override
  String get settingsRecordingStyleExplanation =>
      'Wähle, wie das Mikro beim Aufnehmen aussehen soll.';

  @override
  String get settingsRecordingStyleSubtitle =>
      'VU-Meter oder Energie-Orb bei der Aufnahme';

  @override
  String get settingsRecordingStyleTitle => 'Aufnahmestil';

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
  String get settingsSpeechSubtitle => 'Stimme und Vorlesen';

  @override
  String get settingsSpeechTitle => 'Sprache';

  @override
  String get settingsSyncConflictsSubtitle => 'Sync-Konflikte auflösen';

  @override
  String get settingsSyncNodeProfileCapabilitiesEmpty =>
      'Keine erkannt — der Auto-Trigger für synchronisierte Audio-Inferenz zielt nicht auf dieses Gerät.';

  @override
  String get settingsSyncNodeProfileCapabilitiesLabel =>
      'Erkannte KI-Fähigkeiten';

  @override
  String get settingsSyncNodeProfileCapabilityMlxAudio => 'MLX Audio (lokal)';

  @override
  String get settingsSyncNodeProfileCapabilityOllamaLlm => 'Ollama LLM';

  @override
  String get settingsSyncNodeProfileCapabilityOmlxLlm => 'oMLX LLM';

  @override
  String get settingsSyncNodeProfileCapabilityVoxtral => 'Voxtral (lokal)';

  @override
  String get settingsSyncNodeProfileCapabilityWhisper => 'Whisper (lokal)';

  @override
  String get settingsSyncNodeProfileDisplayNameHelper =>
      'Wird auf deinen anderen Geräten angezeigt, wenn du auswählst, an welches du ein Profil verknüpfst.';

  @override
  String get settingsSyncNodeProfileDisplayNameLabel =>
      'Anzeigename des Geräts';

  @override
  String get settingsSyncNodeProfileKnownNodesEmpty =>
      'Noch keine anderen Geräte haben ein Profil veröffentlicht.';

  @override
  String get settingsSyncNodeProfileKnownNodesTitle => 'Bekannte Sync-Geräte';

  @override
  String get settingsSyncNodeProfileSaveButton => 'Speichern';

  @override
  String get settingsSyncNodeProfileSubtitle => 'Gerätename und Fähigkeiten';

  @override
  String get settingsSyncNodeProfileTitle => 'Dieses Gerät';

  @override
  String get settingsSyncOutboxTitle => 'Sync-Postausgang';

  @override
  String get settingsSyncStatsSubtitle => 'Sync-Pipeline-Metriken überprüfen';

  @override
  String get settingsSyncSubtitle =>
      'Synchronisierung konfigurieren und Statistiken anzeigen';

  @override
  String get settingsThemingAutomatic => 'Automatisch';

  @override
  String get settingsThemingDark => 'Dunkles Erscheinungsbild';

  @override
  String get settingsThemingLight => 'Helles Erscheinungsbild';

  @override
  String get settingsThemingSubtitle =>
      'App-Erscheinungsbild und Themes anpassen';

  @override
  String get settingsThemingTitle => 'Farbschema';

  @override
  String get settingsV2CategoryEmptyBody =>
      'Wähle links eine Unter-Einstellung aus.';

  @override
  String get settingsV2DetailRootCrumb => 'Einstellungen';

  @override
  String get settingsV2EmptyStateBody =>
      'Wähle links einen Bereich aus, um zu beginnen.';

  @override
  String get settingsV2ResizeHandleLabel => 'Einstellungsbaum anpassen';

  @override
  String get settingsV2UnimplementedTitle => 'Bereich noch nicht verfügbar';

  @override
  String get settingsWhatsNewSubtitle =>
      'Sieh dir die neuesten Neuigkeiten und Funktionen an';

  @override
  String get settingsWhatsNewTitle => 'Was gibt\'s Neues';

  @override
  String get sidebarActiveSectionTitle => 'Aktivität';

  @override
  String get sidebarActivityCollapseTooltip => 'Aktivität einklappen';

  @override
  String get sidebarActivityExpandTooltip => 'Aktivität ausklappen';

  @override
  String get sidebarAudioRecordingStatusLabel => 'Aufnahme';

  @override
  String get sidebarRunningTimerLabel => 'Laufender Timer';

  @override
  String get sidebarRunningTimerStopTooltip => 'Timer stoppen';

  @override
  String get sidebarTimerStatusLabel => 'Timer';

  @override
  String get sidebarToggleCollapseLabel => 'Seitenleiste einklappen';

  @override
  String get sidebarToggleExpandLabel => 'Seitenleiste ausklappen';

  @override
  String sidebarWakesActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktiv',
      one: '1 aktiv',
    );
    return '$_temp0';
  }

  @override
  String get sidebarWakesCancelTooltip => 'Agent abbrechen';

  @override
  String get sidebarWakesHeader => 'Agenten';

  @override
  String get sidebarWakesNow => 'jetzt';

  @override
  String get sidebarWakesOpenList => 'Liste öffnen';

  @override
  String get sidebarWakesOpenTask => 'Aufgabe öffnen';

  @override
  String sidebarWakesQueuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count geplant',
      one: '1 geplant',
    );
    return '$_temp0';
  }

  @override
  String get sidebarWakesQueuedLabel => 'Geplant';

  @override
  String get sidebarWakesWorkingLabel => 'Arbeitet';

  @override
  String get skillsSectionTitle => 'Skills';

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
  String get speechModalSelectLanguage => 'Sprache auswählen';

  @override
  String get speechModalTitle => 'Spracherkennung';

  @override
  String get speechNoAudioRecorded =>
      'Es wurde kein Audio aufgenommen. Versuch es noch einmal.';

  @override
  String get speechSettingsModelDescription => 'Lokales Sprachmodell';

  @override
  String get speechSettingsModelDownloadsOnce => 'Wird einmal geladen';

  @override
  String get speechSettingsModelLabel => 'Modell';

  @override
  String get speechSettingsRecommendedBadge => 'Empfohlen';

  @override
  String get speechSettingsSpeedDescription =>
      'Wie schnell Zusammenfassungen vorgelesen werden';

  @override
  String get speechSettingsSpeedLabel => 'Lesegeschwindigkeit';

  @override
  String get speechSettingsVoiceDescription =>
      'Wähle die Stimme, die Zusammenfassungen vorliest';

  @override
  String get speechSettingsVoiceLabel => 'Stimme';

  @override
  String get speechVoiceGenderFemale => 'Weiblich';

  @override
  String get speechVoiceGenderMale => 'Männlich';

  @override
  String get speechVoicePreviewTooltip => 'Stimme anhören';

  @override
  String get surveyBackButton => 'Zurück';

  @override
  String get surveyCancelConfirmation => 'Umfrage abbrechen?';

  @override
  String get surveyChooseOneOption => 'Wähle eine Option';

  @override
  String get surveyChooseOneOrMoreOptions => 'Wähle eine oder mehrere Optionen';

  @override
  String get surveyDiscardConfirmation => 'Ergebnisse verwerfen und beenden?';

  @override
  String get surveyInputNumberValidation => 'Gib eine Zahl ein';

  @override
  String get surveyNextButton => 'Weiter';

  @override
  String get surveyNoButton => 'Nein';

  @override
  String get surveyProgressOf => 'von';

  @override
  String get surveyTapToAnswer => 'Zum Antworten tippen';

  @override
  String get surveyValueAnd => 'und';

  @override
  String get surveyValueBetween => 'Muss zwischen liegen';

  @override
  String get surveyYesButton => 'Ja';

  @override
  String get syncAddDeviceAction => 'Gerät hinzufügen';

  @override
  String get syncAddDeviceConnected =>
      'Das neue Gerät ist beigetreten – schließe vor dem Senden die Emoji-Verifizierung ab.';

  @override
  String get syncAddDeviceCopyCode => 'Kopplungscode kopieren';

  @override
  String get syncAddDeviceGenerateFailed =>
      'Der Kopplungscode konnte nicht erstellt werden. Versuche es erneut.';

  @override
  String get syncAddDeviceHideCode => 'Kopplungscode ausblenden';

  @override
  String get syncAddDeviceIntro =>
      'Installiere Lotti dort, öffne Einstellungen → Sync-Einstellungen → Geräte und wähle „Sync einrichten“.';

  @override
  String get syncAddDeviceRevealCode => 'Kopplungscode als Text anzeigen';

  @override
  String get syncAddDeviceRosterError =>
      'Es konnte nicht geprüft werden, ob das neue Gerät beigetreten ist.';

  @override
  String get syncAddDeviceSecurityNote =>
      'Dieser Code ist ein Schlüssel zu deinem Konto — zeig ihn nur deinem eigenen neuen Gerät.';

  @override
  String get syncAddDeviceSendMessages => 'Nachrichtenverlauf senden';

  @override
  String get syncAddDeviceSendSettings => 'Einstellungen senden';

  @override
  String get syncAddDeviceSendSettingsReady =>
      'Neues Gerät verifiziert – bereit zum Senden.';

  @override
  String get syncAddDeviceStepScanTitle => 'Auf dem neuen Gerät scannen';

  @override
  String get syncAddDeviceTimelineJoined =>
      'Beigetreten — bestätige die Emoji auf beiden Bildschirmen';

  @override
  String get syncAddDeviceTimelineVerified =>
      'Verifiziert — bereit zur Übergabe';

  @override
  String get syncAddDeviceTimelineWaiting => 'Warten auf das neue Gerät …';

  @override
  String get syncAddDeviceUnavailable =>
      'Richte Sync auf diesem Gerät ein, bevor du ein weiteres hinzufügst.';

  @override
  String get syncAddDeviceUnlockHint =>
      'Wird nach dem Emoji-Abgleich freigeschaltet — vorher könnte das neue Gerät sie ohnehin nicht entschlüsseln.';

  @override
  String get syncDeleteConfigConfirm => 'Sync beenden';

  @override
  String get syncDeleteConfigQuestion => 'Sync auf diesem Gerät beenden?';

  @override
  String get syncDeviceRemovalInProgress => 'Gerät wird entfernt …';

  @override
  String syncDevicesCount(num count, String server) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Geräte auf $server',
      one: '1 Gerät auf $server',
    );
    return '$_temp0';
  }

  @override
  String syncDevicesJustJoined(String deviceName) {
    return '$deviceName ist gerade beigetreten und verifiziert';
  }

  @override
  String get syncDevicesJustJoinedHint =>
      'Übergib ihm jetzt deine Einstellungen und deinen Nachrichtenverlauf.';

  @override
  String get syncDevicesKeylessHint =>
      'Die Kopplung wurde nie abgeschlossen — das Gerät kann nur entfernt werden.';

  @override
  String syncDevicesLastSeen(String date) {
    return 'Zuletzt gesehen $date';
  }

  @override
  String get syncDevicesLoadFailed =>
      'Die Geräteliste konnte nicht geladen werden.';

  @override
  String get syncDevicesOnlyThisDevice =>
      'Keine anderen Geräte sind angemeldet.';

  @override
  String syncDevicesPaired(String date) {
    return 'Gekoppelt am $date';
  }

  @override
  String syncDevicesPausedBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count nicht verifizierte Geräte können neue Einträge nicht lesen — lösche oder verifiziere sie unten.',
      one:
          '1 nicht verifiziertes Gerät kann neue Einträge nicht lesen — lösche oder verifiziere es unten.',
    );
    return '$_temp0';
  }

  @override
  String syncDevicesPausedBannerDeleteOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count nicht verifizierte Geräte können neue Einträge nicht lesen — lösche sie unten.',
      one:
          '1 nicht verifiziertes Gerät kann neue Einträge nicht lesen — lösche es unten.',
    );
    return '$_temp0';
  }

  @override
  String syncDevicesPausedBannerVerifyOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count nicht verifizierte Geräte können neue Einträge nicht lesen — verifiziere sie unten.',
      one:
          '1 nicht verifiziertes Gerät kann neue Einträge nicht lesen — verifiziere es unten.',
    );
    return '$_temp0';
  }

  @override
  String get syncDevicesStaleHint => 'Wahrscheinlich nicht mehr in Gebrauch';

  @override
  String get syncDevicesSyncResumed =>
      'Jedes gekoppelte Gerät kann deine Einträge wieder lesen.';

  @override
  String get syncDevicesThisDeviceChip => 'Dieses Gerät';

  @override
  String get syncDevicesUnverifiedChip => 'Nicht verifiziert';

  @override
  String get syncDevicesVerifiedChip => 'Verifiziert';

  @override
  String get syncDisconnectExplanation =>
      'Deine Einträge bleiben auf diesem Gerät. Es wird vom Sync-Konto abgemeldet und braucht einen neuen Kopplungscode, um wieder zu synchronisieren. Deine anderen Geräte sind nicht betroffen.';

  @override
  String get syncDisconnectFailed =>
      'Die Synchronisierung dieses Geräts konnte nicht beendet werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get syncEntitiesConfirm => 'Sync starten';

  @override
  String get syncEntitiesMessage =>
      'Wähle die Daten, die du synchronisieren möchtest.';

  @override
  String get syncEntitiesSuccessDescription =>
      'Alles ist auf dem neuesten Stand.';

  @override
  String get syncEntitiesSuccessTitle => 'Synchronisierung abgeschlossen';

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
  String get syncListPayloadKindLabel => 'Nutzlast';

  @override
  String get syncListUnknownPayload => 'Unbekannte Nutzlast';

  @override
  String get syncNotLoggedInToast => 'Sync ist nicht angemeldet';

  @override
  String get syncPairBack => 'Zurück';

  @override
  String get syncPairCameraDenied =>
      'Lotti braucht Kamerazugriff zum Scannen. Erlaube ihn in den Systemeinstellungen oder gib den Code manuell ein.';

  @override
  String get syncPairCameraRetry => 'Kamera erneut versuchen';

  @override
  String get syncPairCheckAgain => 'Erneut prüfen';

  @override
  String get syncPairCheckCode =>
      'Das neue Gerät zeigt denselben Code, bevor es sich verbindet — vergleiche beide.';

  @override
  String get syncPairCheckCodeLabel => 'Prüfcode';

  @override
  String get syncPairClipboardEmpty =>
      'Nichts zum Einfügen. Kopiere zuerst den Kopplungscode auf deinem anderen Gerät.';

  @override
  String get syncPairClipboardUnavailable =>
      'Die Zwischenablage konnte nicht gelesen werden. Füge den Code direkt in das Feld ein.';

  @override
  String get syncPairConnectButton => 'Die Codes stimmen überein — verbinden';

  @override
  String get syncPairDiscardCode => 'Sie stimmen nicht überein';

  @override
  String get syncPairedFirstDeviceBody =>
      'Es ist das erste Gerät auf deinem Konto. Füge jederzeit ein weiteres hinzu — alles, was du hier schreibst, wartet dann darauf.';

  @override
  String get syncPairedFirstDeviceTitle =>
      'Die Synchronisierung ist auf diesem Gerät eingerichtet';

  @override
  String get syncPairedSettingsStep =>
      'Kategorien, Gewohnheiten, Dashboards und KI-Einrichtung — kommen nach dem Emoji-Abgleich von deinem anderen Gerät.';

  @override
  String get syncPairedSettingsStepFallback =>
      'Falls du ihn geschlossen hast, öffne auf dem anderen Gerät Einstellungen → Synchronisierungseinstellungen → Wartung, führe die Einstellungssynchronisierung aus und wähle danach Nachrichtenverlauf.';

  @override
  String get syncPairedSettingsStepTitle => 'Deine Einstellungen empfangen';

  @override
  String get syncPairedStepsLeft =>
      'Noch zwei Schritte, bis dieses Gerät dein Tagebuch lesen kann.';

  @override
  String get syncPairedVerifyFallback =>
      'Noch keine Emojis? Prüfe erneut – oder öffne Geräte und starte die Prüfung dort.';

  @override
  String get syncPairedVerifyStep =>
      'Beide Geräte zeigen gleich sieben Emoji. Bis sie übereinstimmen, sieht dieses Gerät nur verschlüsselte Daten.';

  @override
  String get syncPairedVerifyStepDone =>
      'Emojis stimmen überein – dieses Gerät kann deine Einträge lesen';

  @override
  String get syncPairedVerifyStepTitle => 'Emoji bestätigen';

  @override
  String get syncPairedVerifyWaiting =>
      'Warte darauf, dass die Emojis erscheinen…';

  @override
  String get syncPairEnterManually => 'Code stattdessen einfügen';

  @override
  String get syncPairEnterNewCode => 'Neuen Code eingeben';

  @override
  String get syncPairErrorMalformed =>
      'Das sieht nicht nach einem Kopplungscode aus. Prüfe, ob du ihn vollständig kopiert hast – drücke auf dem anderen Gerät erneut Kopplungscode kopieren.';

  @override
  String get syncPairErrorVersion =>
      'Dieser Code stammt aus einer anderen Lotti-Version. Aktualisiere beide Geräte und versuche es erneut.';

  @override
  String get syncPairFirstDeviceHint =>
      'Es gibt noch kein anderes Gerät zum Kopieren — dein erster Code kommt aus dem Provisionierungs-Werkzeug deines Sync-Servers.';

  @override
  String get syncPairFirstDeviceTitle => 'Richtest du dein erstes Gerät ein?';

  @override
  String get syncPairGoToDevices => 'Zu Geräte';

  @override
  String get syncPairMismatchWarning =>
      'Unterschiedliche Codes bedeuten: Dieser stammt nicht von deinem Gerät. Verbinde dich nicht — hol dir einen frischen Code von deinem eigenen Gerät.';

  @override
  String get syncPairOnlyOwnCode =>
      'Der Code ist ein Schlüssel zu deinem Konto. Verwende nur einen von deinem eigenen Gerät — mit dem Code einer anderen Person geht alles, was du schreibst, an sie.';

  @override
  String get syncPairOpenManual => 'Anleitung für das erste Gerät öffnen';

  @override
  String get syncPairPasteTitle => 'Kopplungscode einfügen';

  @override
  String get syncPairRetryThisCode => 'Diesen Code erneut versuchen';

  @override
  String get syncPairReviewIntro =>
      'Dein anderes Gerät zeigt unter seinem QR-Code einen Prüfcode. Er muss genau so lauten:';

  @override
  String get syncPairReviewTitle => 'Vergleiche, bevor du dich verbindest';

  @override
  String get syncPairSameCodeQuestion =>
      'Derselbe Code auf beiden Bildschirmen?';

  @override
  String get syncPairScanHint =>
      'Richte die Kamera auf den QR-Code unter „Gerät hinzufügen“ auf deinem anderen Gerät.';

  @override
  String get syncPairScanLink =>
      'Kamera zur Hand? Scanne stattdessen den QR-Code';

  @override
  String get syncPairScannerRejected =>
      'Das ist der Code, den du abgelehnt hast. Scanne den Code, den dein eigenes Gerät anzeigt, oder füge ihn unten ein.';

  @override
  String get syncPairScanTitle => 'Pairing-Code scannen';

  @override
  String get syncPairShowEmoji => 'Emoji anzeigen';

  @override
  String get syncPairWhereToFind =>
      'Er ist auf deinem anderen Gerät unter „Gerät hinzufügen“ — dort kopieren, hier einfügen.';

  @override
  String get syncPayloadAgentBundle => 'Agent-Bündel';

  @override
  String get syncPayloadAgentEntity => 'Agent-Entität';

  @override
  String get syncPayloadAgentLink => 'Agent-Link';

  @override
  String get syncPayloadAiConfig => 'AI-Konfiguration';

  @override
  String get syncPayloadAiConfigDelete => 'AI-Konfiguration löschen';

  @override
  String get syncPayloadBackfillRequest => 'Nachfüllanfrage';

  @override
  String get syncPayloadBackfillResponse => 'Nachfüllantwort';

  @override
  String get syncPayloadConfigFlag => 'Konfigurationsflag';

  @override
  String get syncPayloadConsumptionEvent => 'KI-Verbrauch';

  @override
  String get syncPayloadDailyOsUserName => 'Daily-OS-Name';

  @override
  String get syncPayloadEntityDefinition => 'Entitätsdefinition';

  @override
  String get syncPayloadEntryLink => 'Eintragsverknüpfung';

  @override
  String get syncPayloadJournalEntity => 'Journaleintrag';

  @override
  String get syncPayloadMediaRequest => 'Medienanfrage';

  @override
  String get syncPayloadNotification => 'Hinweis';

  @override
  String get syncPayloadNotificationStateUpdate =>
      'Hinweisstatus-Aktualisierung';

  @override
  String get syncPayloadOutboxBundle => 'Outbox-Bündel';

  @override
  String get syncPayloadSavedTaskFilter => 'Gespeicherter Aufgabenfilter';

  @override
  String get syncPayloadSavedTaskFilterDelete =>
      'Gespeicherter Aufgabenfilter gelöscht';

  @override
  String get syncPayloadSyncNodeProfile => 'Sync-Knoten-Profil';

  @override
  String get syncPayloadThemingSelection => 'Designauswahl';

  @override
  String syncQueueCountMillions(String value) {
    return '${value}M';
  }

  @override
  String syncQueueCountThousands(String value) {
    return '${value}K';
  }

  @override
  String syncQueueIncomingSemanticLabel(int count) {
    return 'Posteingang: $count';
  }

  @override
  String syncQueueOutgoingSemanticLabel(int count) {
    return 'Postausgang: $count';
  }

  @override
  String syncReauthExplanation(String deviceName) {
    return 'Der Sync-Server hat das gespeicherte Passwort nicht akzeptiert. Gib das aktuelle Passwort deines Sync-Kontos ein, um $deviceName zu entfernen.';
  }

  @override
  String get syncReauthInvalidPassword =>
      'Dieses Passwort hat nicht funktioniert. Prüf es und versuch es noch einmal.';

  @override
  String get syncReauthPasswordLabel => 'Passwort des Sync-Kontos';

  @override
  String get syncReauthTitle => 'Bist du das?';

  @override
  String get syncSetupCta => 'Sync einrichten';

  @override
  String get syncSetupEmptyFootnote =>
      'Läuft auf deinem eigenen Sync-Server · nichts verlässt deine Geräte unverschlüsselt';

  @override
  String get syncSetupEmptyHint =>
      'Dein Tagebuch auf jedem deiner Geräte. Ende-zu-Ende-verschlüsselt, nur zwischen deinen Geräten — ohne Cloud-Konto.';

  @override
  String get syncSetupEmptyTitle => 'Geräte synchronisieren';

  @override
  String get syncStepAiSettings => 'KI-Einstellungen';

  @override
  String get syncStepBackfillAgentEntityClocks =>
      'Vektoruhren für Agent-Entitäten nachtragen';

  @override
  String get syncStepBackfillAgentLinkClocks =>
      'Vektoruhren für Agent-Links nachtragen';

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
  String get syncStepSavedTaskFilters => 'Gespeicherte Aufgabenfilter';

  @override
  String get syncVerifiedCelebrationBody =>
      'Ab jetzt synchronisiert sich alles, was du schreibst — Ende-zu-Ende-verschlüsselt, von Gerät zu Gerät.';

  @override
  String get syncVerifiedCelebrationTitle => 'Deine Geräte vertrauen einander';

  @override
  String get syncVerifyModalTitle => 'Bestätige dein Gerät';

  @override
  String get syncVerifyPromptLine1 => 'Beide Bildschirme zeigen sieben Emoji.';

  @override
  String get syncVerifyPromptQuestion => 'Gleiche Emoji, gleiche Reihenfolge?';

  @override
  String get syncVerifyStaleConfirm => 'Trotzdem bestätigen';

  @override
  String syncVerifyStaleMessage(String deviceName) {
    return '$deviceName hat sich eine Weile nicht gemeldet. Das Bestätigen klappt nur, solange es wach und online ist und Lotti zeigt — sonst wartet der Emoji-Abgleich auf eine Antwort, die nie kommt.';
  }

  @override
  String get syncVerifyStaleTitle => 'Dieses Gerät ist vielleicht offline';

  @override
  String get syncVerifyTheyDiffer => 'Sie unterscheiden sich — abbrechen';

  @override
  String get syncVerifyTheyMatch => 'Sie stimmen überein';

  @override
  String get syncWizardStepCheck => 'Prüfen';

  @override
  String get syncWizardStepConnect => 'Verbinden';

  @override
  String get syncWizardStepGetCode => 'Code holen';

  @override
  String syncWizardStepStatus(int step, String label) {
    return 'Schritt $step von 3: $label';
  }

  @override
  String get taskActionBarAudioRecordingActive => 'Audioaufnahme läuft';

  @override
  String get taskActionBarMoreActions => 'Weitere Aktionen';

  @override
  String get taskActionBarOpenRunningTimer => 'Laufenden Timer öffnen';

  @override
  String get taskActionBarStopTracking => 'Zeiterfassung beenden';

  @override
  String get taskActionBarTrackTime => 'Zeit erfassen';

  @override
  String get taskAgentAssignHint =>
      'Entwirft Schritte und Zusammenfassungen mit eingebauter KI.';

  @override
  String get taskAgentAttributionUnavailable => 'Zuordnung nicht verfügbar';

  @override
  String get taskAgentAutomaticUpdatesLabel => 'Automatische Aktualisierungen';

  @override
  String get taskAgentAutomaticUpdatesNeedsSetup =>
      'Wähle eine KI-Einrichtung, bevor du automatische Aktualisierungen einschaltest.';

  @override
  String get taskAgentCancelTimerTooltip =>
      'Ausstehende automatische Aktualisierung abbrechen';

  @override
  String get taskAgentChangeSetupTooltip => 'KI-Setup ändern';

  @override
  String get taskAgentChooseModel => 'Denkmodell wählen';

  @override
  String get taskAgentChooseProfile => 'Inferenzprofil auswählen';

  @override
  String taskAgentCountdownTooltip(String countdown) {
    return 'Nächster automatischer Lauf in $countdown';
  }

  @override
  String get taskAgentCreateChipLabel => 'Agent zuweisen';

  @override
  String taskAgentCreateError(String error) {
    return 'Agent konnte nicht erstellt werden: $error';
  }

  @override
  String get taskAgentCurrentSetupHeader => 'Aktuelle Einrichtung';

  @override
  String get taskAgentCurrentSetupLabel => 'Aktuelle Einrichtung';

  @override
  String get taskAgentDirectModelOverride => 'Direkte Modellüberschreibung';

  @override
  String get taskAgentDisableConfirmAction => 'Ausschalten';

  @override
  String get taskAgentDisableConfirmBody =>
      'Der aktuelle Bericht bleibt sichtbar, aber der Agent kann erst wieder laufen, wenn du eine Einrichtung auswählst.';

  @override
  String get taskAgentDisableConfirmTitle =>
      'KI für diesen Agenten ausschalten?';

  @override
  String get taskAgentInferenceProfileLabel => 'Inferenzprofil';

  @override
  String get taskAgentModelPickerTitle => 'Denkmodell wählen';

  @override
  String taskAgentNextUpdateIn(String countdown) {
    return 'Nächste Aktualisierung in $countdown';
  }

  @override
  String taskAgentNextUpdateInShort(String countdown) {
    return 'in $countdown';
  }

  @override
  String get taskAgentNoAiSetup => 'Keine KI-Einrichtung';

  @override
  String get taskAgentNoAiSetupDescription =>
      'Pausiert die Inferenz, bis du ein Profil oder Modell auswählst.';

  @override
  String get taskAgentNoModelsAvailable =>
      'Keine kompatiblen Denkmodelle verfügbar';

  @override
  String get taskAgentNoProfilesAvailable =>
      'Auf diesem Gerät sind keine Profile verfügbar';

  @override
  String get taskAgentNoProfileSelected => 'Kein KI-Setup';

  @override
  String get taskAgentNoProfileSelectedDescription =>
      'Wähle eine gespeicherte Einrichtung oder ein Denkmodell, bevor der Agent laufen kann.';

  @override
  String taskAgentProfileChangedToast(String profile) {
    return '$profile wird für jede künftige Aktualisierung des Agenten verwendet, bis du es änderst.';
  }

  @override
  String get taskAgentProfileDefaultBadge => 'Profilstandard';

  @override
  String get taskAgentReportOutdatedTitle =>
      'Diese Zusammenfassung ist veraltet';

  @override
  String get taskAgentReportUpToDate => 'Zusammenfassung ist aktuell';

  @override
  String get taskAgentRouteVia => 'über';

  @override
  String get taskAgentRunNowTooltip => 'Jetzt ausführen';

  @override
  String get taskAgentSavingSetup => 'Agent-Einrichtung wird gespeichert';

  @override
  String taskAgentSetupAndReportSemantics(String identity) {
    return 'Dieser Bericht und die aktuelle Einrichtung verwenden $identity. Aktivieren, um die Einrichtung zu ändern.';
  }

  @override
  String get taskAgentSetupBroken =>
      'Die ausgewählte KI-Einrichtung ist nicht verfügbar';

  @override
  String taskAgentSetupChangedToast(String model) {
    return '$model wird für jede künftige Aktualisierung des Agenten verwendet, bis du es änderst.';
  }

  @override
  String get taskAgentSetupChoiceHelp =>
      'Wähle ein Profil für die Standardwerte oder überschreibe nur das Denkmodell.';

  @override
  String get taskAgentSetupOriginCategory =>
      'Beim Erstellen dieses Agenten aus dem Kategorie-Standard kopiert';

  @override
  String get taskAgentSetupOriginDisabled => 'Deaktiviert';

  @override
  String get taskAgentSetupOriginLegacy => 'Alte Einrichtung';

  @override
  String get taskAgentSetupOriginTemplate => 'Aus der Vorlage kopiert';

  @override
  String get taskAgentSetupOriginUser =>
      'Du hast dies für diesen Agenten ausgewählt';

  @override
  String get taskAgentSetupPersistenceDescription =>
      'Änderungen gelten für alle künftigen Aktualisierungen, bis du sie wieder änderst.';

  @override
  String taskAgentSetupSemantics(String identity) {
    return 'Aktuelle Einrichtung: $identity. Aktivieren, um die Einrichtung zu ändern.';
  }

  @override
  String get taskAgentSetupTitle => 'Agent-Einrichtung';

  @override
  String get taskAgentSkipScheduledUpdate => 'Einmal überspringen';

  @override
  String get taskAgentStatusOutOfDate => 'Veraltet';

  @override
  String get taskAgentStatusUpToDate => 'Aktuell';

  @override
  String get taskAgentThinkingModelLabel => 'Denkmodell';

  @override
  String get taskAgentThisReportHeader => 'Dieser Bericht';

  @override
  String get taskAgentTurnOffSetup => 'KI für diesen Agenten ausschalten';

  @override
  String get taskAgentUpdateNow => 'Jetzt aktualisieren';

  @override
  String get taskAgentUpdatesOnChange => 'Aktualisiert bei Änderungen';

  @override
  String get taskAgentUseCategoryDefault => 'Kategorie-Standard kopieren';

  @override
  String get taskAgentUseCategoryDefaultDescription =>
      'Kopiert das aktuelle Setup der Kategorie. Spätere Kategorieänderungen wirken sich nicht auf diesen Agenten aus.';

  @override
  String get taskAgentUseProfileDefault => 'Profilstandard verwenden';

  @override
  String taskBlockedByChipLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Blockiert von $count Aufgaben',
      one: 'Blockiert von 1 Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String taskBlockedByChipTooltip(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tippe für $count Blocker',
      one: 'Blockiert von $title',
    );
    return '$_temp0';
  }

  @override
  String get taskBlockedByUnresolvedLabel =>
      'Blockierende Aufgabe noch nicht synchronisiert';

  @override
  String taskBlockedReason(String title) {
    return 'Blockiert von: $title';
  }

  @override
  String get taskBlockerPickerTitle => 'Was blockiert sie?';

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
  String get taskEditTitleLabel => 'Aufgabentitel bearbeiten';

  @override
  String get taskEstimateLabel => 'Schätzung:';

  @override
  String get taskEstimateModalTitle => 'Schätzung';

  @override
  String taskEstimateProgressLabel(String tracked, String estimate) {
    return '$tracked von $estimate';
  }

  @override
  String taskEstimateTooltip(String tracked, String estimate) {
    return 'Erfasste Zeit: $tracked von $estimate geschätzt';
  }

  @override
  String get taskFirstRunAddChecklist => 'Checkliste hinzufügen';

  @override
  String get taskFirstRunAddChecklistHint =>
      'Fügt eine Liste abhakbarer Schritte hinzu.';

  @override
  String get taskFirstRunAssignAgent => 'Agent zuweisen';

  @override
  String get taskFirstRunRecordAudio => 'Sprachnotiz aufnehmen';

  @override
  String get taskFirstRunRecordAudioHint =>
      'Öffnet die Aufnahme, ohne sie zu starten.';

  @override
  String get taskFirstRunWriteNote => 'Notiz schreiben';

  @override
  String get taskFirstRunWriteNoteHint =>
      'Fügt eine verknüpfte Notiz für Details und Gedanken hinzu.';

  @override
  String taskLabelsMoreCount(int count) {
    return '+$count';
  }

  @override
  String get taskLabelsShowFewer => 'Weniger anzeigen';

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
  String get taskLanguageLabel => 'Sprache';

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
  String get taskLanguageSelectedLabel => 'Aktuell ausgewählt';

  @override
  String get taskLanguageSerbian => 'Serbisch';

  @override
  String get taskLanguageSetAction => 'Sprache festlegen';

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
  String get taskPriorityHigh => 'Hoch';

  @override
  String get taskPriorityLow => 'Niedrig';

  @override
  String get taskPriorityMedium => 'Mittel';

  @override
  String taskPriorityTooltip(String priority) {
    return 'Priorität: $priority';
  }

  @override
  String get taskPriorityUrgent => 'Dringend';

  @override
  String get tasksAddLabelButton => 'Label hinzufügen';

  @override
  String get tasksAgentFilterAll => 'Alle';

  @override
  String get tasksAgentFilterHasAgent => 'Hat Agent';

  @override
  String get tasksAgentFilterNoAgent => 'Kein Agent';

  @override
  String get tasksAgentFilterTitle => 'Agent';

  @override
  String tasksCompactFilterCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Filter',
      one: '$count Filter',
    );
    return '$_temp0';
  }

  @override
  String get tasksCompactHeaderExpandHint => 'Suche und Filter anzeigen';

  @override
  String tasksCompactSearchContext(String query) {
    return '„$query“';
  }

  @override
  String get taskSetCategoryLabel => 'Kategorie festlegen';

  @override
  String get taskSetDueDateLabel => 'Fälligkeit setzen';

  @override
  String get taskSetEstimateLabel => 'Aufwand schätzen';

  @override
  String get tasksFilterApplyTitle => 'Filter anwenden';

  @override
  String get tasksFilterClearAll => 'Alles löschen';

  @override
  String get tasksFilterTitle => 'Aufgaben filtern';

  @override
  String get taskShowcaseAudio => 'Audio';

  @override
  String taskShowcaseCompletedCount(int completed, int total) {
    return '$completed / $total erledigt';
  }

  @override
  String taskShowcaseDueDate(String date) {
    return 'Fällig: $date';
  }

  @override
  String get taskShowcaseJumpToSection => 'Zum Abschnitt springen';

  @override
  String get taskShowcaseLinked => 'Verknüpft';

  @override
  String get taskShowcaseNoResults =>
      'Keine Aufgaben stimmen mit deiner Suche überein.';

  @override
  String get taskShowcaseReadMore => 'Mehr lesen';

  @override
  String taskShowcaseRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen',
      one: '1 Aufnahme',
    );
    return '$_temp0';
  }

  @override
  String taskShowcaseTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben',
      one: '1 Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String get taskShowcaseTaskDescription => 'Aufgabenbeschreibung';

  @override
  String get taskShowcaseTimeTracker => 'Zeiterfassung';

  @override
  String get taskShowcaseTodo => 'Todo';

  @override
  String get taskShowcaseTodos => 'Todos';

  @override
  String get tasksLabelFilterAll => 'Alle';

  @override
  String get tasksLabelFilterTitle => 'Label';

  @override
  String get tasksLabelFilterUnlabeled => 'Ohne Label';

  @override
  String get tasksLabelsDialogClose => 'Schließen';

  @override
  String get tasksLabelsSheetApply => 'Anwenden';

  @override
  String get tasksLabelsSheetSearchHint => 'Labels suchen…';

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
  String get tasksQuickFilterUnassignedLabel => 'Nicht zugewiesen';

  @override
  String get tasksSavedFilterDeleteConfirmTooltip =>
      'Zum Löschen erneut tippen';

  @override
  String get tasksSavedFilterDeleteTooltip => 'Gespeicherten Filter löschen';

  @override
  String get tasksSavedFilterDragHandleSemantics =>
      'Ziehen, um die Reihenfolge zu ändern';

  @override
  String get tasksSavedFilterRenameSemantics =>
      'Gespeicherten Filter umbenennen';

  @override
  String get tasksSavedFiltersAllShort => 'Alle';

  @override
  String get tasksSavedFiltersAllTasks => 'Alle Aufgaben';

  @override
  String get tasksSavedFiltersCustom => 'Eigene';

  @override
  String get tasksSavedFiltersDeleteConfirmAction => 'Löschen';

  @override
  String tasksSavedFiltersDeleteConfirmMessage(String name) {
    return 'Den gespeicherten Filter „$name“ löschen? Das lässt sich nicht rückgängig machen.';
  }

  @override
  String tasksSavedFiltersDeleteConfirmNamed(String name) {
    return 'Löschen von $name bestätigen';
  }

  @override
  String tasksSavedFiltersDeleteNamed(String name) {
    return '$name löschen';
  }

  @override
  String get tasksSavedFiltersDone => 'Fertig';

  @override
  String get tasksSavedFiltersEdit => 'Bearbeiten';

  @override
  String get tasksSavedFiltersFilterNameLabel => 'Filtername';

  @override
  String get tasksSavedFiltersGroupSemantics => 'Aufgabenfilter';

  @override
  String get tasksSavedFiltersManageTooltip => 'Aufgabenfilter verwalten';

  @override
  String get tasksSavedFiltersRailButton => 'Ansichten';

  @override
  String tasksSavedFiltersRenameNamed(String name) {
    return '$name umbenennen';
  }

  @override
  String get tasksSavedFiltersReorderHelper =>
      'Zieh die Filter in die gewünschte Reihenfolge. Die ersten fünf erscheinen in der Seitenleiste.';

  @override
  String get tasksSavedFiltersSaveAsNewButtonLabel =>
      'Als neuen Filter speichern…';

  @override
  String get tasksSavedFiltersSaveAsNewDescription =>
      'Der bestehende Filter bleibt unverändert und ein separater wird erstellt.';

  @override
  String get tasksSavedFiltersSaveAsNewTitle => 'Als neuen Filter speichern';

  @override
  String get tasksSavedFiltersSaveButtonLabel => 'Filter speichern…';

  @override
  String get tasksSavedFiltersSaveChoiceIntro =>
      'Wähle, ob du den gespeicherten Filter aktualisieren oder einen separaten erstellen möchtest.';

  @override
  String get tasksSavedFiltersSaveChoiceTitle => 'Filter speichern';

  @override
  String get tasksSavedFiltersSaveCurrentAs =>
      'Aktuellen Filter speichern als…';

  @override
  String get tasksSavedFiltersSaveError =>
      'Der Filter konnte nicht gespeichert werden. Versuch es noch einmal.';

  @override
  String get tasksSavedFiltersSavePageHelper =>
      'Gib diesem Filter einen kurzen Namen. Du kannst ihn später in den Aufgabenfiltern neu anordnen.';

  @override
  String get tasksSavedFiltersSavePopupCancel => 'Abbrechen';

  @override
  String get tasksSavedFiltersSavePopupHint => 'z. B. Blockiert oder pausiert';

  @override
  String get tasksSavedFiltersSavePopupSave => 'Speichern';

  @override
  String get tasksSavedFiltersSavePopupTitle => 'Diesen Filter benennen';

  @override
  String get tasksSavedFiltersSheetTitle => 'Aufgabenfilter';

  @override
  String get tasksSavedFiltersShowLess => 'Weniger anzeigen';

  @override
  String tasksSavedFiltersShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weitere gespeicherte Filter',
      one: '1 weiterer gespeicherter Filter',
    );
    return '$_temp0';
  }

  @override
  String tasksSavedFiltersTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben',
      one: '1 Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String get tasksSavedFiltersUpdateButtonLabel => 'Filter aktualisieren';

  @override
  String get tasksSavedFiltersUpdateExistingDescription =>
      'Ersetze seine gespeicherten Kriterien durch die aktuelle Filterkonfiguration.';

  @override
  String get tasksSavedFiltersUpdateExistingTitle =>
      'Bestehenden Filter aktualisieren';

  @override
  String get tasksSavedFilterToastDeleted => 'Filter gelöscht';

  @override
  String tasksSavedFilterToastSaved(String name) {
    return '„$name“ gespeichert';
  }

  @override
  String tasksSavedFilterToastUpdated(String name) {
    return '„$name“ aktualisiert';
  }

  @override
  String get tasksSearchModeLabel => 'Suchmodus';

  @override
  String get tasksShowCreationDate => 'Erstellungsdatum auf Karten anzeigen';

  @override
  String get tasksShowDueDate => 'Fälligkeitsdatum auf Karten anzeigen';

  @override
  String get tasksSortByCreationDate => 'Erstellt';

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
  String get taskTitleEmpty => 'Kein Titel';

  @override
  String get taskTitlePrompt => 'Aufgabe benennen';

  @override
  String get taskUntitled => '(ohne Titel)';

  @override
  String get thinkingDisclosureCopied => 'Begründung kopiert';

  @override
  String get thinkingDisclosureCopy => 'Begründung kopieren';

  @override
  String get thinkingDisclosureHide => 'Begründung ausblenden';

  @override
  String get thinkingDisclosureShow => 'Begründung anzeigen';

  @override
  String get thinkingDisclosureStateCollapsed => 'eingeklappt';

  @override
  String get thinkingDisclosureStateExpanded => 'ausgeklappt';

  @override
  String get timeEntryItemEnd => 'Ende';

  @override
  String get timeEntryItemRunning => 'Läuft';

  @override
  String get timeEntryItemStart => 'Start';

  @override
  String transcriptLanguageLabel(String language) {
    return 'Sprache: $language';
  }

  @override
  String transcriptModelLabel(String provider, String model) {
    return 'Modell: $provider, $model';
  }

  @override
  String get unifiedGoalStatusAtRisk => 'Gefährdet';

  @override
  String get unifiedGoalStatusNoData => 'Keine Daten';

  @override
  String unifiedGoalSummaryAllOnTrack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Gewohnheiten auf Kurs – heute ist nichts nötig.',
      one: 'Deine Gewohnheit ist auf Kurs – heute ist nichts nötig.',
    );
    return '$_temp0';
  }

  @override
  String get unifiedGoalSummaryNoData =>
      'Noch keine Daten – erfasse eine Gewohnheit oder verbinde ein Signal, um zu starten.';

  @override
  String unifiedGoalSummaryPartial(int onTrack, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$onTrack von $total Gewohnheiten auf Kurs',
      one: '$onTrack von 1 Gewohnheit auf Kurs',
    );
    return '$_temp0';
  }

  @override
  String get unifiedGoalsUngroupedHabitsHeader => 'Keinem Ziel zugeordnet';

  @override
  String get unlinkButton => 'Verknüpfung aufheben';

  @override
  String get unlinkTaskConfirm =>
      'Bist du sicher, dass du die Verknüpfung zu dieser Aufgabe aufheben möchtest?';

  @override
  String unlinkTaskConfirmNamed(String title) {
    return '„$title“ trennen? Die Aufgabe selbst wird nicht gelöscht.';
  }

  @override
  String get unlinkTaskFailedMessage =>
      'Die Verknüpfung konnte nicht aufgehoben werden. Bitte versuch es erneut.';

  @override
  String get unlinkTaskTitle => 'Verknüpfung aufheben';

  @override
  String vectorSearchTiming(int elapsed, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${elapsed}ms, $count Ergebnisse',
      one: '${elapsed}ms, $count Ergebnis',
    );
    return '$_temp0';
  }

  @override
  String get viewMenuTitle => 'Ansicht';

  @override
  String get viewMenuZoomIn => 'Vergrößern';

  @override
  String get viewMenuZoomOut => 'Verkleinern';

  @override
  String get viewMenuZoomReset => 'Originalgröße';

  @override
  String get whatsNewBadgeNew => 'NEU';

  @override
  String get whatsNewDoneButton => 'Fertig';

  @override
  String get whatsNewSkipButton => 'Überspringen';
}

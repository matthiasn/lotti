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
  String get agentEvolutionChartWakeHistory => 'Wake-Verlauf';

  @override
  String get agentEvolutionChatPlaceholder =>
      'Feedback teilen oder nach Leistung fragen...';

  @override
  String get agentEvolutionCurrentDirectives => 'Aktuelle Anweisungen';

  @override
  String get agentEvolutionDashboardTitle => 'Leistung';

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
    return 'Evolution #$sessionNumber';
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
  String get agentInstancesKindEvolution => 'Evolution';

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
  String agentPendingWakesActivityHourDetail(
    String hour,
    int count,
    String reasons,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Weckvorgänge',
      one: '1 Weckvorgang',
    );
    return '$hour: $_temp0 ($reasons)';
  }

  @override
  String get agentPendingWakesActivityTitle => 'Weckaktivität (24h)';

  @override
  String agentPendingWakesActivityTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Weckvorgänge insgesamt',
      one: '1 Weckvorgang insgesamt',
    );
    return '$_temp0';
  }

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
  String get agentRitualReviewAction => 'Gespräch starten';

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
  String get agentRitualReviewSessionHistory => 'Sitzungsverlauf';

  @override
  String get agentRitualReviewTitle => '1-on-1';

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
      'Starte ein 1-on-1, um zu prüfen, was den Nutzer gestört hat, was gut funktioniert hat und was sich als Nächstes ändern sollte.';

  @override
  String get agentRitualSummarySubtitle =>
      'Frühere 1-on-1s, echte Wake-Aktivität und die Änderungen, auf die du dich mit dem Agenten geeinigt hast.';

  @override
  String get agentRitualSummaryTokensSinceLast =>
      'Tokens seit dem letzten 1-on-1';

  @override
  String get agentRitualSummaryWakeHistory30Days =>
      'Wake-Aktivität (letzte 30 Tage)';

  @override
  String get agentRitualSummaryWakesSinceLast =>
      'Wakes seit dem letzten 1-on-1';

  @override
  String get agentRunningIndicator => 'Läuft';

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
  String get agentSoulReviewHeroSubtitle =>
      'Verfeinere die Persönlichkeit über alle Vorlagen hinweg, die diese Seele teilen. Der Evolutionsagent sieht Feedback von jeder Vorlage, die diese Persönlichkeit verwendet.';

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
  String get agentSoulReviewTitle => 'Seelen-1-on-1';

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
  String get agentStateRevision => 'Revision';

  @override
  String get agentStateSleepingUntil => 'Schlafend bis';

  @override
  String get agentStateWakeCount => 'Aufwachzähler';

  @override
  String get agentStatsAllDayLegend => 'Ganzer Tag';

  @override
  String get agentStatsAverageLabel => 'Durchschnitt';

  @override
  String agentStatsByTimeLegend(String time) {
    return 'Täglich bis $time';
  }

  @override
  String get agentStatsCacheRateLabel => 'Cache-Rate';

  @override
  String get agentStatsDailyUsageHeading => 'Tägliche Nutzung';

  @override
  String get agentStatsInputLabel => 'Eingabe';

  @override
  String get agentStatsNoUsage =>
      'Keine Token-Nutzung in den letzten 7 Tagen erfasst.';

  @override
  String get agentStatsOutputLabel => 'Ausgabe';

  @override
  String agentStatsSourceActiveFor(String duration) {
    return 'Aktiv seit $duration';
  }

  @override
  String get agentStatsSourceActivityHeading => 'Agentenaktivität';

  @override
  String agentStatsSourceWakes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufwachvorgänge',
      one: '1 Aufwachvorgang',
    );
    return '$_temp0';
  }

  @override
  String get agentStatsTabTitle => 'Statistiken';

  @override
  String get agentStatsThoughtsLabel => 'Gedanken';

  @override
  String get agentStatsTodayLabel => 'Heute';

  @override
  String get agentStatsTokensPerWakeLabel => 'Tokens / Aufwachen';

  @override
  String get agentStatsTokensUnit => 'Tokens';

  @override
  String agentStatsUsageAboveAverage(String time) {
    return 'Du verwendest heute mehr Tokens als gewöhnlich um $time.';
  }

  @override
  String agentStatsUsageBelowAverage(String time) {
    return 'Du verwendest heute weniger Tokens als gewöhnlich um $time.';
  }

  @override
  String get agentStatsWakesLabel => 'Aufwachvorgänge';

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
    return 'Auf Version $version zurücksetzen? Der Agent wird diese Version beim nächsten Wake verwenden.';
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
  String get agentThreadReportLabel => 'Bericht aus diesem Wake-Zyklus';

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
  String get aggregationDailyAvg => 'Tagesdurchschnitt';

  @override
  String get aggregationDailyMax => 'Tagesmaximum';

  @override
  String get aggregationDailySum => 'Tagessumme';

  @override
  String get aggregationHourlySum => 'Stundensumme';

  @override
  String get aggregationNone => 'Keine';

  @override
  String get aiAssistantTitle => 'Generieren…';

  @override
  String get aiBatchToggleTooltip => 'Zur Standardaufnahme wechseln';

  @override
  String get aiCapabilityChipImageGeneration => 'Bildgenerierung';

  @override
  String get aiCapabilityChipImageRecognition => 'Bilderkennung';

  @override
  String get aiCapabilityChipThinking => 'Denken';

  @override
  String get aiCapabilityChipTranscription => 'Transkription';

  @override
  String get aiCardEmptyProposals =>
      'Keine offenen Vorschläge · der Agent zeigt neue Änderungen hier an';

  @override
  String aiCardHistoryToggle(int count) {
    return 'Verlauf · $count';
  }

  @override
  String get aiCardMenuActionDelete => 'Löschen';

  @override
  String get aiCardMenuActionEdit => 'Bearbeiten';

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
  String get aiProfileCardActiveBadge => 'Aktiv';

  @override
  String get aiProfileModelPickerSearchHint => 'Modelle suchen…';

  @override
  String get aiProfileSlotModelMissing => 'fehlt';

  @override
  String get aiPromptGenerationPickerTitle =>
      'Wähle ein Modell für die Prompt-Generierung';

  @override
  String get aiProviderAlibabaDescription =>
      'Alibaba Clouds Qwen-Modellfamilie über die DashScope-API';

  @override
  String get aiProviderAlibabaName => 'Alibaba Cloud (Qwen)';

  @override
  String get aiProviderAnthropicDescription =>
      'Anthropics Claude-Familie von AI-Assistenten';

  @override
  String get aiProviderAnthropicName => 'Anthropic Claude';

  @override
  String get aiProviderCardDraftBadge => 'ENTWURF';

  @override
  String get aiProviderCardFixButton => 'Beheben';

  @override
  String get aiProviderCardMenuTooltip => 'Weitere Aktionen';

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
  String get aiProviderDetailActiveProfileTitle => 'Aktives Profil';

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
  String get aiProviderGeminiDescription => 'Googles Gemini AI-Modelle';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiDescription =>
      'API kompatibel mit OpenAI-Format';

  @override
  String get aiProviderGenericOpenAiName => 'OpenAI-kompatibel';

  @override
  String get aiProviderMistralDescription =>
      'Mistral AI Cloud-API mit nativer Audio-Transkription';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderMlxAudioDescription =>
      'Eingebettete MLX-Audio-Modelle für lokale STT und TTS auf Apple Silicon';

  @override
  String get aiProviderMlxAudioName => 'MLX Audio (lokal)';

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
  String get aiProviderOmlxDescription =>
      'Lokale OpenAI-kompatible oMLX-Inferenz für MLX-Modelle';

  @override
  String get aiProviderOmlxName => 'oMLX (lokal)';

  @override
  String get aiProviderOpenAiDescription => 'OpenAIs GPT-Modelle';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'Modelle von OpenRouter';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderSelectContinue => 'Weiter';

  @override
  String get aiProviderSelectDontShowAgain => 'Nicht mehr anzeigen';

  @override
  String get aiProviderSetupOptionGeminiDescription =>
      'Multimodale Modelle mit Audiotranskription. Erfordert API-Schlüssel.';

  @override
  String get aiProviderSetupOptionMistralDescription =>
      'Europäische KI mit Reasoning- (Magistral) und Audio-Modellen (Voxtral).';

  @override
  String get aiProviderSetupOptionOpenAiDescription =>
      'GPT-Modelle für Chat und Reasoning. Erfordert API-Schlüssel mit Guthaben.';

  @override
  String get aiProviderTaglineAlibaba =>
      'Qwen-Modelle · multimodal · langer Kontext';

  @override
  String get aiProviderTaglineAnthropic => 'Claude-Familie · langer Kontext';

  @override
  String get aiProviderTaglineGemini => 'Multimodal · Audiotranskription';

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
  String get aiProviderVoxtralDescription =>
      'Lokale Voxtral-Transkription (bis zu 30 Min. Audio, 13 Sprachen)';

  @override
  String get aiProviderVoxtralName => 'Voxtral (lokal)';

  @override
  String get aiProviderWhisperDescription =>
      'Lokale Whisper-Transkription mit OpenAI-kompatibler API';

  @override
  String get aiProviderWhisperName => 'Whisper (lokal)';

  @override
  String get aiRealtimeToggleTooltip => 'Zur Live-Transkription wechseln';

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
  String get aiRunningActivityOpenProgress => 'KI-Fortschritt anzeigen';

  @override
  String get aiSettingsAddedLabel => 'Hinzugefügt';

  @override
  String get aiSettingsAddModelButton => 'Modell hinzufügen';

  @override
  String get aiSettingsAddModelTooltip =>
      'Dieses Modell zu deinem Anbieter hinzufügen';

  @override
  String get aiSettingsAddProfileButton => 'Profil hinzufügen';

  @override
  String get aiSettingsAddProviderButton => 'Anbieter hinzufügen';

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
  String get aiSettingsSearchHint => 'AI-Konfigurationen suchen...';

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
  String get audioRecordingCancel => 'ABBRECHEN';

  @override
  String get audioRecordingListening => 'Hört zu...';

  @override
  String get audioRecordingRealtime => 'Live-Transkription';

  @override
  String get audioRecordings => 'Audioaufnahmen';

  @override
  String get audioRecordingStandard => 'Standard';

  @override
  String get audioRecordingStop => 'STOPP';

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
  String get categoryDeleteConfirm => 'JA, DIESE KATEGORIE LÖSCHEN';

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
  String get chatInputPleaseWait => 'Bitte warten...';

  @override
  String get chatInputProcessing => 'Verarbeitung...';

  @override
  String get chatInputRecordVoice => 'Sprachnachricht aufnehmen';

  @override
  String get chatInputSendTooltip => 'Nachricht senden';

  @override
  String get chatInputStartRealtime => 'Live-Transkription starten';

  @override
  String get chatInputStopRealtime => 'Live-Transkription beenden';

  @override
  String get chatInputStopTranscribe => 'Stoppen und transkribieren';

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
  String get configFlagDailyOsNextEnabled =>
      'Neue agentische DailyOS-Oberfläche';

  @override
  String get configFlagDailyOsNextEnabledDescription =>
      'Ersetzt die bisherige DailyOS-Oberfläche durch den neuen sprachgeführten, agentischen Capture- und Reconcile-Ablauf. Frühe Vorschau — die Backend-Logik ist noch gemockt.';

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
  String get configFlagEnableKnowledgeGraph => 'Wissensgraph';

  @override
  String get configFlagEnableKnowledgeGraphDescription =>
      'Zeige den experimentellen Wissensgraph-Explorer bei Aufgaben — eine visuelle Karte der Verknüpfungen zwischen Aufgaben, Einträgen und Projekten.';

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
  String get configFlagEnableProjects => 'Projekte aktivieren';

  @override
  String get configFlagEnableProjectsDescription =>
      'Projektverwaltung zum Organisieren von Aufgaben in Projekten anzeigen.';

  @override
  String get configFlagEnableSessionRatings => 'Sitzungsbewertungen aktivieren';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Nach dem Stoppen eines Timers eine schnelle Sitzungsbewertung anzeigen.';

  @override
  String get configFlagEnableSyncedAlerts => 'Synchronisierte Hinweise';

  @override
  String get configFlagEnableSyncedAlertsDescription =>
      'Synchronisiere KI- und Aufgabenhinweise zwischen deinen Geräten und erlaube ihnen, lokale Systemmitteilungen zu planen.';

  @override
  String get configFlagEnableTooltip => 'Tooltips aktivieren';

  @override
  String get configFlagEnableTooltipDescription =>
      'Zeigt hilfreiche Tooltips in der gesamten App an, um dich durch die Funktionen zu führen.';

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
  String get configFlagShowSidebarWakeQueue =>
      'Weckvorgang-Warteschlange in der Seitenleiste anzeigen';

  @override
  String get configFlagShowSidebarWakeQueueDescription =>
      'Zeige die Weckvorgang-Warteschlange über den Einstellungen — Header, die nächsten zwei anstehenden Weckvorgänge mit Countdown und ein Link zur vollständigen Liste.';

  @override
  String get configFlagShowSyncActivityIndicator =>
      'Sync-Aktivitätsanzeige einblenden';

  @override
  String get configFlagShowSyncActivityIndicatorDescription =>
      'Live-Sync-Aktivität in der Seitenleiste anzeigen — eine tx/rx-LED-Leiste mit Outbox- und Inbox-Tiefe.';

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
  String get copyAsMarkdown => 'Als Markdown kopieren';

  @override
  String get copyAsText => 'Als Text kopieren';

  @override
  String get correctionExampleCancel => 'ABBRECHEN';

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
  String get coverArtGenerationComplete => 'Cover-Art fertig!';

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
  String get createNewLinkedTask => 'Neue verknüpfte Aufgabe erstellen...';

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
  String get dailyOsDayPlan => 'Tagesplan';

  @override
  String get dailyOsDaySummary => 'Tageszusammenfassung';

  @override
  String get dailyOsDelete => 'Löschen';

  @override
  String get dailyOsDeletePlannedBlock => 'Block löschen?';

  @override
  String get dailyOsDeletePlannedBlockConfirm =>
      'Dies entfernt den geplanten Block aus deiner Zeitleiste.';

  @override
  String get dailyOsDraftMessage =>
      'Plan ist ein Entwurf. Bestätige, um ihn festzulegen.';

  @override
  String get dailyOsDueToday => 'Heute fällig';

  @override
  String get dailyOsDueTodayShort => 'Fällig';

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
  String get dailyOsEditPlannedBlock => 'Geplanten Block bearbeiten';

  @override
  String get dailyOsEndTime => 'Ende';

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
  String get dailyOsInvalidTimeRange => 'Ungültiger Zeitbereich';

  @override
  String get dailyOsNearLimit => 'Fast am Limit';

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
  String get dailyOsNextCaptureCaptured => 'Hab\'s.';

  @override
  String get dailyOsNextCaptureDoneCta => 'Fertig';

  @override
  String get dailyOsNextCaptureErrorMicrophonePermissionDenied =>
      'Der Zugriff auf das Mikrofon wurde verweigert.';

  @override
  String get dailyOsNextCaptureErrorNoActiveRealtimeSession =>
      'Keine aktive Echtzeit-Sitzung.';

  @override
  String get dailyOsNextCaptureErrorNoAudioRecorded =>
      'Es wurde kein Audio aufgenommen.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionFailed =>
      'Die Echtzeit-Transkription ist fehlgeschlagen.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionStartFailed =>
      'Die Echtzeit-Transkription konnte nicht starten.';

  @override
  String get dailyOsNextCaptureErrorRecordingStartFailed =>
      'Die Aufnahme konnte nicht starten.';

  @override
  String get dailyOsNextCaptureErrorTranscriptionFailed =>
      'Die Transkription ist fehlgeschlagen.';

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
  String get dailyOsNextDraftingHeader => 'Plane deinen Tag…';

  @override
  String get dailyOsNextDraftingNudgeAccept => 'Ja, Morgen schützen';

  @override
  String get dailyOsNextDraftingNudgeDecline => 'Heute nicht';

  @override
  String get dailyOsNextDraftingReasoningOverline => '✦ ÜBERLEGUNG';

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
    return 'Hi $name 👋';
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
  String get dailyOsNextPlanViewAgenda => 'Agenda';

  @override
  String get dailyOsNextPlanViewDay => 'Tag';

  @override
  String get dailyOsNextReconcileBadgeMatched => 'VERKNÜPFT';

  @override
  String get dailyOsNextReconcileBadgeNew => 'NEU';

  @override
  String get dailyOsNextReconcileBadgeUpdate => 'UPDATE';

  @override
  String get dailyOsNextReconcileBuildDayCta => 'Tag bauen';

  @override
  String get dailyOsNextReconcileDecideOverline => 'WERT ZU ENTSCHEIDEN';

  @override
  String get dailyOsNextReconcileDefaultBehaviorHint =>
      'Deine Entscheidungen hier fließen in den Plan ein — keine Entscheidung heißt „lass es, wie es ist“.';

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
  String get dailyOsNextTimelineBoth => 'Plan und Ist';

  @override
  String get dailyOsNextTimelineMeridiemAm => 'AM';

  @override
  String get dailyOsNextTimelineMeridiemAmShort => 'am';

  @override
  String get dailyOsNextTimelineMeridiemPm => 'PM';

  @override
  String get dailyOsNextTimelineMeridiemPmShort => 'pm';

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
  String get dailyOsPlanCreated => 'Plan erfolgreich erstellt';

  @override
  String get dailyOsPlanCreatedDescription =>
      'Deine Zeitblöcke wurden gespeichert. Du kannst jetzt deine Aufgaben verfolgen.';

  @override
  String get dailyOsPlanned => 'Geplant';

  @override
  String get dailyOsPlanWithoutVoice => 'Ohne Sprache planen';

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
  String get dailyOsSaveError => 'Plan konnte nicht gespeichert werden';

  @override
  String get dailyOsSaveErrorDescription =>
      'Etwas ist schiefgelaufen. Bitte versuche es erneut.';

  @override
  String get dailyOsSavePlan => 'Plan speichern';

  @override
  String get dailyOsSelectCategory => 'Kategorie auswählen';

  @override
  String get dailyOsSetTimeBlocks => 'Zeitblöcke festlegen';

  @override
  String get dailyOsSetTimeBlocksAddNew => 'Neuen Zeitblock hinzufügen';

  @override
  String get dailyOsSetTimeBlocksFavourites => 'Favoriten';

  @override
  String get dailyOsSetTimeBlocksOther => 'Andere Kategorien';

  @override
  String get dailyOsSetTimeBlocksTapHint =>
      'Tippe, um einen Zeitblock hinzuzufügen';

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
  String get dashboardActiveLabel => 'Aktiv';

  @override
  String get dashboardActiveSwitchDescription =>
      'Wird in der Dashboard-Liste angezeigt';

  @override
  String get dashboardAddChartsTitle => 'Diagramme';

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
  String get dashboardAddMeasurementTooltip => 'Messung hinzufügen';

  @override
  String get dashboardAddSurveyButton => 'Umfragediagramme';

  @override
  String get dashboardAddSurveyTitle => 'Umfragediagramme';

  @override
  String get dashboardAddWorkoutButton => 'Trainingsdiagramme';

  @override
  String get dashboardAddWorkoutTitle => 'Trainingsdiagramme';

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
  String get dashboardCategoryLabel => 'Kategorie';

  @override
  String get dashboardChartNoData => 'Keine Daten in diesem Zeitraum';

  @override
  String get dashboardCopyHint =>
      'Dashboard-Konfiguration speichern & kopieren';

  @override
  String get dashboardCopyLabel => 'Speichern und Konfiguration kopieren';

  @override
  String get dashboardDeleteConfirm => 'JA, DIESES DASHBOARD LÖSCHEN';

  @override
  String get dashboardDeleteHint => 'Dashboard löschen';

  @override
  String get dashboardDeleteQuestion => 'Möchtest du dieses Dashboard löschen?';

  @override
  String get dashboardDescriptionLabel => 'Beschreibung (optional)';

  @override
  String get dashboardHealthBloodPressure => 'Blutdruck';

  @override
  String get dashboardHealthDiastolic => 'Diastolisch';

  @override
  String get dashboardHealthSystolic => 'Systolisch';

  @override
  String get dashboardNameLabel => 'Dashboard-Name';

  @override
  String get dashboardNotFound => 'Dashboard nicht gefunden';

  @override
  String get dashboardPrivateLabel => 'Privat';

  @override
  String get dashboardTakeSurveyTooltip => 'Umfrage ausfüllen';

  @override
  String get defaultLanguage => 'Standardsprache';

  @override
  String get deleteButton => 'Löschen';

  @override
  String get deleteDeviceLabel => 'Gerät löschen';

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
  String get designSystemMyDailyEditPlanLabel => 'Plan bearbeiten';

  @override
  String get designSystemMyDailyGreetingMorning => 'Guten Morgen.';

  @override
  String designSystemMyDailyGreetingWithName(String name) {
    return 'Hi, $name';
  }

  @override
  String get designSystemMyDailyHikeWithDanielaTitle => 'Wandern mit Daniela';

  @override
  String get designSystemMyDailyLunchBreakTitle => 'Mittagspause';

  @override
  String get designSystemMyDailyMeetingsLabel => 'Meetings';

  @override
  String get designSystemMyDailyMeetingWithDannyTitle => 'Meeting mit Danny';

  @override
  String get designSystemMyDailyProfileActionLabel => 'Profil';

  @override
  String get designSystemMyDailySkiWithMattTitle => 'Mit Matt Ski fahren';

  @override
  String get designSystemMyDailyTapToExpandLabel => 'Zum Aufklappen tippen';

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
    return 'Gerät $deviceName erfolgreich gelöscht';
  }

  @override
  String deviceDeleteFailed(String error) {
    return 'Gerät konnte nicht gelöscht werden: $error';
  }

  @override
  String get doneButton => 'Fertig';

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
  String get eventsDeleteEvent => 'Event löschen';

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
  String get eventsTitleHint => 'Event-Titel';

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
  String get generateCoverArt => 'Cover generieren';

  @override
  String get generateCoverArtSubtitle =>
      'Bild aus Sprachbeschreibung erstellen';

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
  String get habitDeleteConfirm => 'JA, DIESE GEWOHNHEIT LÖSCHEN';

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
  String get habitsGoalLineLabel => 'Ziel';

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
    return '$points Pkt. bis zum Ziel';
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
  String get inactiveLabel => 'Inaktiv';

  @override
  String get inactiveSwitchDescription =>
      'Kann für neue Einträge gewählt werden, wenn aktiv';

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
  String get journalDateSaveButton => 'SPEICHERN';

  @override
  String get journalDateTimeRangeTitle => 'Datum & Uhrzeit';

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
  String get journalUnlinkConfirm => 'JA, EINTRAG TRENNEN';

  @override
  String get journalUnlinkHint => 'Trennen';

  @override
  String get journalUnlinkQuestion =>
      'Möchtest du diesen Eintrag wirklich trennen?';

  @override
  String get knowledgeGraphEmpty => 'Noch keine Verknüpfungen zum Erkunden';

  @override
  String get knowledgeGraphError => 'Wissensgraph konnte nicht geladen werden';

  @override
  String get knowledgeGraphTitle => 'Wissensgraph';

  @override
  String get knowledgeGraphTooltip => 'Verknüpfungen erkunden';

  @override
  String get linkedFromCaption => 'von';

  @override
  String get linkedTaskImageBadge => 'Von verknüpfter Aufgabe';

  @override
  String get linkedTasksMenuTooltip => 'Optionen für verknüpfte Aufgaben';

  @override
  String get linkedTasksTitle => 'Verknüpfte Aufgaben';

  @override
  String get linkedToCaption => 'zu';

  @override
  String get linkExistingTask => 'Vorhandene Aufgabe verknüpfen...';

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
  String get maintenanceDeleteSyncDb => 'Synchronisierungsdatenbank löschen';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Synchronisierungsdatenbank löschen';

  @override
  String get maintenanceGenerateEmbeddings => 'Embeddings generieren';

  @override
  String get maintenanceGenerateEmbeddingsConfirm => 'JA, GENERIEREN';

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
  String get maintenancePurgeSentOutbox =>
      'Alte gesendete Outbox-Einträge löschen';

  @override
  String get maintenancePurgeSentOutboxConfirm => 'JA, LÖSCHEN';

  @override
  String get maintenancePurgeSentOutboxDescription =>
      'Gesendete Outbox-Zeilen, die älter als 7 Tage sind, löschen und Speicherplatz freigeben';

  @override
  String get maintenancePurgeSentOutboxQuestion =>
      'Gesendete Outbox-Einträge löschen, die älter als 7 Tage sind? Bereits gesendete Zeilen werden in Blöcken gelöscht und VACUUM gibt Speicherplatz frei. Ausstehende und fehlerhafte Einträge bleiben erhalten.';

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
  String get maintenanceReSyncAgentEntities => 'Agenten-Entitäten';

  @override
  String get maintenanceReSyncDescription =>
      'Nachrichten vom Server erneut synchronisieren';

  @override
  String get maintenanceReSyncEntityTypes => 'Entitätstypen';

  @override
  String get maintenanceReSyncJournalEntities => 'Journal-Einträge';

  @override
  String get maintenanceReSyncSelectAtLeastOne =>
      'Wähle mindestens einen Entitätstyp aus';

  @override
  String get maintenanceReSyncStart => 'Starten';

  @override
  String get maintenanceSyncDefinitions =>
      'Messgrößen, Dashboards, Gewohnheiten, Kategorien, AI-Einstellungen synchronisieren';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Messgrößen, Dashboards, Gewohnheiten, Kategorien und AI-Einstellungen synchronisieren';

  @override
  String get manageLinks => 'Verknüpfungen verwalten...';

  @override
  String get measurableDeleteConfirm => 'JA, DIESE MESSGRÖSSE LÖSCHEN';

  @override
  String get measurableDeleteQuestion =>
      'Möchtest du diesen Messgrößen-Datentyp löschen?';

  @override
  String get measurableNotFound => 'Messgröße nicht gefunden';

  @override
  String get measurementCommentHint => 'Notiz hinzufügen (optional)';

  @override
  String get measurementQuickAddLabel => 'Schnell hinzufügen';

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
  String get navTabTitleHabits => 'Gewohnheiten';

  @override
  String get navTabTitleInsights => 'Einblicke';

  @override
  String get navTabTitleJournal => 'Logbuch';

  @override
  String get navTabTitleMore => 'Mehr';

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
  String get privateLabel => 'Privat';

  @override
  String get privateSwitchDescription =>
      'Nur sichtbar, wenn private Einträge angezeigt werden';

  @override
  String get projectAgentNotProvisioned =>
      'Für dieses Projekt wurde noch kein Projekt-Agent eingerichtet.';

  @override
  String get projectAgentSectionTitle => 'Agent';

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
    return 'Zusammenfassung ist veraltet. Nächstes Update am $date um $time.';
  }

  @override
  String get projectTargetDateLabel => 'Zieldatum';

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
  String get provisionedSyncBundleImported => 'Bereitstellungscode importiert';

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
  String get provisionedSyncImportTitle => 'Sync einrichten';

  @override
  String get provisionedSyncInvalidBundle => 'Ungültiger Bereitstellungscode';

  @override
  String get provisionedSyncJoiningRoom => 'Sync-Raum beitreten...';

  @override
  String get provisionedSyncLoggingIn => 'Anmeldung läuft...';

  @override
  String get provisionedSyncPasteClipboard => 'Aus Zwischenablage einfügen';

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
  String get referenceImageSelectionSubtitle =>
      'Wähle bis zu 5 Bilder, um den visuellen Stil der KI zu leiten';

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
  String get searchTasksHint => 'Aufgaben suchen...';

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
      'Wird nur für die Daily-OS-Begrüßung auf diesem Gerät verwendet.';

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
  String get settingsAdvancedOutboxSubtitle =>
      'Elemente anzeigen und verwalten, die auf Synchronisierung warten';

  @override
  String get settingsAdvancedSubtitle => 'Erweiterte Einstellungen und Wartung';

  @override
  String get settingsAdvancedTitle => 'Erweiterte Einstellungen';

  @override
  String get settingsAgentsInstancesSubtitle => 'Laufende Agenten';

  @override
  String get settingsAgentsPendingWakesSubtitle => 'Geplante Wake-Timer';

  @override
  String get settingsAgentsSoulsSubtitle =>
      'Langlebige Agenten-Persönlichkeiten';

  @override
  String get settingsAgentsStatsSubtitle => 'Token-Nutzung und Aktivität';

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
  String get settingsCelebrationsEnabledDescription =>
      'Hauptschalter für alle Abschluss-Effekte. Aus blendet jede Animation aus; Haptik hat ihren eigenen Schalter.';

  @override
  String get settingsCelebrationsEnabledTitle => 'Abschluss-Animationen';

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
  String get settingsCelebrationsPreviewChecklistItem => 'Hak mich ab';

  @override
  String get settingsCelebrationsPreviewDescription =>
      'Tippe ein Element an, um deinen Stil abzuspielen.';

  @override
  String get settingsCelebrationsPreviewDone => 'Erledigt';

  @override
  String get settingsCelebrationsPreviewHabit => 'Gewohnheit';

  @override
  String get settingsCelebrationsPreviewTitle => 'Ausprobieren';

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
  String get settingsCelebrationsVariantConfetti => 'Konfetti';

  @override
  String get settingsCelebrationsVariantEmbers => 'Glut';

  @override
  String get settingsCelebrationsVariantFireworks => 'Feuerwerk';

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
  String get settingsHealthImportActivity => 'Aktivitätsdaten importieren';

  @override
  String get settingsHealthImportBloodPressure => 'Blutdruckdaten importieren';

  @override
  String get settingsHealthImportBodyMeasurement => 'Körpermaße importieren';

  @override
  String get settingsHealthImportFromDate => 'Start';

  @override
  String get settingsHealthImportHeartRate => 'Herzfrequenzdaten importieren';

  @override
  String get settingsHealthImportSleep => 'Schlafdaten importieren';

  @override
  String get settingsHealthImportTitle => 'Gesundheitsdatenimport';

  @override
  String get settingsHealthImportToDate => 'Ende';

  @override
  String get settingsHealthImportWorkout => 'Trainingsdaten importieren';

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
  String get settingsLabelsColorSubheading => 'Quick presets';

  @override
  String get settingsLabelsCreateTitle => 'Create label';

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
  String get settingsLabelsSearchHint => 'Search labels…';

  @override
  String get settingsLabelsSubtitle => 'Organize tasks with colored labels';

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
  String get settingsMaintenanceTitle => 'Wartung';

  @override
  String get settingsMatrixAccept => 'Akzeptieren';

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
  String get settingsMatrixDiagnosticShowButton => 'Diagnoseinfos anzeigen';

  @override
  String get settingsMatrixDone => 'Fertig';

  @override
  String get settingsMatrixLastUpdated => 'Zuletzt aktualisiert:';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Nicht verifizierte Geräte';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Matrix-Wartungsaufgaben und Wiederherstellungstools ausführen';

  @override
  String get settingsMatrixMaintenanceTitle => 'Wartung';

  @override
  String get settingsMatrixMetrics => 'Sync-Metriken';

  @override
  String get settingsMatrixNextPage => 'Nächste Seite';

  @override
  String get settingsMatrixNoUnverifiedLabel =>
      'Keine nicht verifizierten Geräte';

  @override
  String get settingsMatrixPreviousPage => 'Vorherige Seite';

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
  String get settingsMatrixTitle => 'Matrix-Synchronisierungseinstellungen';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Nicht verifizierte Geräte';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Auf anderem Gerät abgebrochen...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Verstanden';

  @override
  String settingsMatrixVerificationSuccessLabel(
    String deviceName,
    String deviceID,
  ) {
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
  String get settingsSyncConflictsSubtitle =>
      'Synchronisierungskonflikte lösen, um Datenkonsistenz zu gewährleisten';

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
  String get settingsSyncNodeProfileSubtitle =>
      'Benenne dieses Gerät und überprüfe die Fähigkeiten, die deine anderen Geräte sehen können.';

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
      'Sieh dir die neuesten Updates und Funktionen an';

  @override
  String get settingsWhatsNewTitle => 'Was gibt\'s Neues';

  @override
  String get settingThemingDark => 'Dunkles Design';

  @override
  String get settingThemingLight => 'Helles Design';

  @override
  String get sidebarRunningTimerLabel => 'Laufender Timer';

  @override
  String get sidebarRunningTimerStopTooltip => 'Timer stoppen';

  @override
  String get sidebarToggleCollapseLabel => 'Seitenleiste einklappen';

  @override
  String get sidebarToggleExpandLabel => 'Seitenleiste ausklappen';

  @override
  String get sidebarWakesCancelTooltip => 'Agent abbrechen';

  @override
  String get sidebarWakesHeader => 'Agenten';

  @override
  String get sidebarWakesNow => 'jetzt';

  @override
  String get sidebarWakesOpenList => 'Liste öffnen';

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
  String get syncActivityInboxLabel => 'Inbox';

  @override
  String syncActivityIndicatorSemantics(int outbox, int inbox) {
    return 'Sync-Aktivität. Outbox: $outbox. Inbox: $inbox. Sync-Outbox öffnen.';
  }

  @override
  String get syncActivityOutboxLabel => 'Outbox';

  @override
  String get syncDeleteConfigConfirm => 'JA, ICH BIN SICHER';

  @override
  String get syncDeleteConfigQuestion =>
      'Möchtest du die Synchronisierungskonfiguration löschen?';

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
  String get syncNotLoggedInToast => 'Sync ist nicht angemeldet';

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
  String get syncPayloadEntityDefinition => 'Entitätsdefinition';

  @override
  String get syncPayloadEntryLink => 'Eintragsverknüpfung';

  @override
  String get syncPayloadJournalEntity => 'Journaleintrag';

  @override
  String get syncPayloadNotification => 'Hinweis';

  @override
  String get syncPayloadNotificationStateUpdate =>
      'Hinweisstatus-Aktualisierung';

  @override
  String get syncPayloadOutboxBundle => 'Outbox-Bündel';

  @override
  String get syncPayloadSyncNodeProfile => 'Sync-Knoten-Profil';

  @override
  String get syncPayloadThemingSelection => 'Designauswahl';

  @override
  String get syncStepAgentEntities => 'Agent-Entitäten';

  @override
  String get syncStepAgentLinks => 'Agent-Links';

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
  String get taskAgentCancelTimerTooltip => 'Abbrechen';

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
  String get taskAgentRunNowTooltip => 'Aktualisieren';

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
  String taskEstimateProgressLabel(String tracked, String estimate) {
    return '$tracked von $estimate';
  }

  @override
  String taskEstimateTooltip(String tracked, String estimate) {
    return 'Erfasste Zeit: $tracked von $estimate geschätzt';
  }

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
  String get tasksFilterApplyTitle => 'Filter anwenden';

  @override
  String get tasksFilterClearAll => 'Alles löschen';

  @override
  String get tasksFilterTitle => 'Aufgabenfilter';

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
  String get tasksQuickFilterClear => 'Zurücksetzen';

  @override
  String get tasksQuickFilterLabelsActiveTitle => 'Aktive Label-Filter';

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
  String get tasksSavedFiltersSaveButtonLabel => 'Speichern';

  @override
  String get tasksSavedFiltersSavePopupCancel => 'Abbrechen';

  @override
  String tasksSavedFiltersSavePopupHelper(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Filter aktiv. In der Seitenleiste unter „Aufgaben“ gespeichert.',
      one: '1 Filter aktiv. In der Seitenleiste unter „Aufgaben“ gespeichert.',
    );
    return '$_temp0';
  }

  @override
  String get tasksSavedFiltersSavePopupHint => 'z. B. Blockiert oder pausiert';

  @override
  String get tasksSavedFiltersSavePopupSave => 'Speichern';

  @override
  String get tasksSavedFiltersSavePopupTitle => 'Diesen Filter benennen';

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
  String get unlinkButton => 'Verknüpfung aufheben';

  @override
  String get unlinkTaskConfirm =>
      'Bist du sicher, dass du die Verknüpfung zu dieser Aufgabe aufheben möchtest?';

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
  String get whatsNewDoneButton => 'Fertig';

  @override
  String get whatsNewSkipButton => 'Überspringen';
}

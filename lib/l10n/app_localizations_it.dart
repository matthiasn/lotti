// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get activeLabel => 'Attivo';

  @override
  String get addActionAddAudioRecording => 'Registrazione audio';

  @override
  String get addActionAddChecklist => 'Lista di controllo';

  @override
  String get addActionAddEvent => 'Evento';

  @override
  String get addActionAddImageFromClipboard => 'Incolla immagine';

  @override
  String get addActionAddScreenshot => 'Sceneggiatura';

  @override
  String get addActionAddTask => 'Compiti';

  @override
  String get addActionAddText => 'Inserimento del testo';

  @override
  String get addActionAddTimer => 'Cronometro';

  @override
  String get addActionAddTimeRecording => 'Registrazione del tempo';

  @override
  String get addActionImportImage => 'Immagine di importazione';

  @override
  String get addHabitCommentLabel => 'Commento';

  @override
  String get addHabitDateLabel => 'Completo a';

  @override
  String get addMeasurementCommentLabel => 'Commento';

  @override
  String get addMeasurementDateLabel => 'Osservato a';

  @override
  String get addMeasurementSaveButton => 'Salva';

  @override
  String get addToDictionary => 'Aggiungi al dizionario';

  @override
  String get addToDictionaryDuplicate => 'Il termine esiste già nel dizionario';

  @override
  String get addToDictionaryNoCategory =>
      'Non può aggiungere al dizionario: l\'attività non ha categoria';

  @override
  String get addToDictionarySaveFailed =>
      'Non riuscito a salvare il dizionario';

  @override
  String get addToDictionarySuccess => 'Termine aggiunto al dizionario';

  @override
  String get addToDictionaryTooLong =>
      'Termine troppo lungo (max 50 caratteri)';

  @override
  String agentABComparisonChoose(String option) {
    return 'Scegli $option';
  }

  @override
  String agentABComparisonOption(String option) {
    return 'Opzione $option';
  }

  @override
  String agentABComparisonPrefer(String option) {
    return 'Preferisco Opzione $option';
  }

  @override
  String get agentBinaryChoiceNo => 'No.';

  @override
  String get agentBinaryChoiceYes => 'Sì.';

  @override
  String get agentCategoryRatingsScaleMax => 'Fissare prima';

  @override
  String get agentCategoryRatingsScaleMin => 'Lascialo.';

  @override
  String agentCategoryRatingsStarLabel(int starIndex, int totalStars) {
    return '$starIndex delle stelle $totalStars';
  }

  @override
  String get agentCategoryRatingsSubmit => 'Utilizzare queste priorità';

  @override
  String get agentCategoryRatingsSubtitle =>
      'Quanto è importante che fissi ciascuno di questi? 1 significa lasciarlo da solo, 5 significa risolverlo prima.';

  @override
  String get agentCategoryRatingsTitle => 'Aiutami a Prioritize';

  @override
  String agentControlsActionError(String error) {
    return 'Azione fallita: $error';
  }

  @override
  String get agentControlsDeleteButton => 'Eliminare permanentemente';

  @override
  String get agentControlsDeleteDialogContent =>
      'Questo cancellerà definitivamente tutti i dati per questo agente, tra cui la sua storia, i suoi rapporti e le sue osservazioni.';

  @override
  String get agentControlsDeleteDialogTitle => 'Eliminare l\'agente?';

  @override
  String get agentControlsDestroyButton => 'Distruggere';

  @override
  String get agentControlsDestroyDialogContent =>
      'Questo disattiva definitivamente l\'agente, la sua storia sarà preservata per l\'audit.';

  @override
  String get agentControlsDestroyDialogTitle => 'Agente di distruzione?';

  @override
  String get agentControlsDestroyedMessage =>
      'Questo agente e\' stato distrutto.';

  @override
  String get agentControlsPauseButton => 'Pausa.';

  @override
  String get agentControlsReanalyzeButton => 'Rianalizzare';

  @override
  String get agentControlsResumeButton => 'Ripresa';

  @override
  String get agentConversationEmpty => 'Ancora nessuna conversazione.';

  @override
  String agentConversationThreadSummary(
    int messageCount,
    int toolCallCount,
    String shortId,
  ) {
    return '$messageCount messaggi, $toolCallCount chiamate strumento · $shortId';
  }

  @override
  String agentConversationTokenCount(String tokenCount) {
    return 'Token $tokenCount';
  }

  @override
  String get agentDefaultProfileLabel => 'Profilo di inferenza predefinito';

  @override
  String agentDetailErrorLoading(String error) {
    return 'Agente di caricamento di errore: $error';
  }

  @override
  String get agentDetailNotFound => 'Agente non trovato.';

  @override
  String get agentDetailUnexpectedType => 'Tipo di entità inaspettata.';

  @override
  String get agentEvolutionApprovalRate => 'Tasso di approssimazione';

  @override
  String get agentEvolutionChartMttrTrend => 'Andamento MTTR';

  @override
  String get agentEvolutionChartSuccessRateTrend => 'Tendenza di successo';

  @override
  String get agentEvolutionChartVersionPerformance => 'Per la versione';

  @override
  String get agentEvolutionChartWakeHistory => 'Storia del risveglio';

  @override
  String get agentEvolutionChatPlaceholder =>
      'Condividi feedback o chiedi informazioni sulle prestazioni...';

  @override
  String get agentEvolutionCurrentDirectives => 'Direttive attuali';

  @override
  String get agentEvolutionDashboardTitle => 'Prestazioni';

  @override
  String get agentEvolutionHistoryTitle => 'Storia dell\'evoluzione';

  @override
  String get agentEvolutionMetricActive => 'Attivo';

  @override
  String get agentEvolutionMetricAvgDuration => 'Durata Avg';

  @override
  String get agentEvolutionMetricFailures => 'Fallimenti';

  @override
  String get agentEvolutionMetricSuccess => 'Successo';

  @override
  String get agentEvolutionMetricWakes => 'Sveglia';

  @override
  String get agentEvolutionNoSessions => 'Nessuna sessione di evoluzione';

  @override
  String get agentEvolutionNoteRecorded => 'Nota Registrata';

  @override
  String get agentEvolutionProposalApprovalFailed =>
      'Approvazione fallito — si prega di riprovare';

  @override
  String get agentEvolutionProposalRationale => 'Motivazione';

  @override
  String get agentEvolutionProposalRejected =>
      'Proposta respinta — continua la conversazione';

  @override
  String get agentEvolutionProposalTitle => 'Variazioni proposte';

  @override
  String get agentEvolutionProposedDirectives => 'Direttive proposte';

  @override
  String get agentEvolutionSessionAbandoned =>
      'Sessione terminata senza modifiche';

  @override
  String agentEvolutionSessionCompleted(int version) {
    return 'Sessione completata — versione $version creata';
  }

  @override
  String get agentEvolutionSessionCount => 'Sessioni';

  @override
  String get agentEvolutionSessionError =>
      'Non è riuscito a iniziare la sessione di evoluzione';

  @override
  String agentEvolutionSessionProgress(int sessionNumber, int totalSessions) {
    return 'Sessione $sessionNumber di $totalSessions';
  }

  @override
  String get agentEvolutionSessionStarting =>
      'Avvio della sessione di evoluzione...';

  @override
  String agentEvolutionSessionTitle(int sessionNumber) {
    return 'Evoluzione #$sessionNumber';
  }

  @override
  String agentEvolutionSoulCurrentField(String field) {
    return 'Corrente — $field';
  }

  @override
  String agentEvolutionSoulProposedField(String field) {
    return 'Proposta — $field';
  }

  @override
  String get agentEvolutionStatusAbandoned => 'Abbandonati';

  @override
  String get agentEvolutionStatusActive => 'Attivo';

  @override
  String get agentEvolutionStatusCompleted => 'Completo';

  @override
  String get agentEvolutionTimelineFeedbackLabel => 'Riscontro';

  @override
  String get agentEvolutionVersionProposed => 'Proposta della Commissione';

  @override
  String get agentFeedbackCategoryAccuracy => 'Accuratezza';

  @override
  String get agentFeedbackCategoryBreakdownTitle =>
      'Ripartizione della categoria';

  @override
  String get agentFeedbackCategoryCommunication => 'Comunicazione';

  @override
  String get agentFeedbackCategoryGeneral => 'Generale';

  @override
  String get agentFeedbackCategoryPrioritization => 'Priorizzazione';

  @override
  String get agentFeedbackCategoryTimeliness => 'Temporaneità';

  @override
  String get agentFeedbackCategoryTooling => 'Attrezzi';

  @override
  String get agentFeedbackClassificationTitle => 'Classificazione Feedback';

  @override
  String get agentFeedbackExcellenceTitle => 'Note di eccellenza';

  @override
  String get agentFeedbackGrievancesTitle => 'Grievanze';

  @override
  String get agentFeedbackHighPriorityTitle => 'Feedback ad alta qualità';

  @override
  String agentFeedbackItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articoli',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String get agentFeedbackSourceDecision => 'Decisione della Commissione';

  @override
  String get agentFeedbackSourceMetric => 'Metrico';

  @override
  String get agentFeedbackSourceObservation => 'Osservazione';

  @override
  String get agentFeedbackSourceRating => 'Valutazione';

  @override
  String get agentInstancesEmptyFiltered =>
      'Nessuna istanza corrisponde ai tuoi filtri.';

  @override
  String get agentInstancesFilterClearAll => 'Cancella tutto';

  @override
  String get agentInstancesFilterClearSection => 'Cancellazione';

  @override
  String get agentInstancesFilterSectionSoul => 'Animazione';

  @override
  String get agentInstancesFilterSectionStatus => 'Stato';

  @override
  String get agentInstancesFilterSectionType => 'Tipologia';

  @override
  String agentInstancesGroupActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attivi',
      one: '1 attivo',
    );
    return '$_temp0';
  }

  @override
  String get agentInstancesGroupBySoul => 'Animazione';

  @override
  String get agentInstancesGroupByStatus => 'Stato';

  @override
  String get agentInstancesGroupByType => 'Tipologia';

  @override
  String get agentInstancesKindEvolution => 'Evoluzione';

  @override
  String get agentInstancesKindTaskAgent => 'Agente di servizio';

  @override
  String get agentInstancesPageTitle => 'Casi dell\'agente';

  @override
  String agentInstancesResultCountAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count istanze',
      one: '1 istanza',
    );
    return '$_temp0';
  }

  @override
  String agentInstancesResultCountFiltered(int filtered, int total) {
    return '$filtered di $total';
  }

  @override
  String get agentInstancesSearchClear => 'Cancella la ricerca';

  @override
  String get agentInstancesSearchPlaceholder => 'Le istanze di ricerca...';

  @override
  String get agentInstancesSortName => 'Nome';

  @override
  String get agentInstancesSortOldest => 'Il più vecchio';

  @override
  String get agentInstancesSortRecent => 'Recenti';

  @override
  String get agentInstancesTitle => 'Casi';

  @override
  String get agentInstancesToolbarFilters => 'Filtri';

  @override
  String get agentInstancesToolbarGroupBy => 'Gruppo';

  @override
  String get agentInstancesUnassignedSoul => 'Non firmata';

  @override
  String get agentLifecycleActive => 'Attivo';

  @override
  String get agentLifecycleCreated => 'Creato';

  @override
  String get agentLifecycleDestroyed => 'Distrutto';

  @override
  String get agentLifecycleDormant => 'Inattivo';

  @override
  String get agentMessageKindAction => 'Azione';

  @override
  String get agentMessageKindMilestone => 'Traguardo';

  @override
  String get agentMessageKindObservation => 'Osservazione';

  @override
  String get agentMessageKindRetraction => 'Retrazione';

  @override
  String get agentMessageKindSummary => 'Sintesi';

  @override
  String get agentMessageKindSystem => 'Sistema';

  @override
  String get agentMessageKindSystemPrompt => 'Prompt di sistema';

  @override
  String get agentMessageKindThought => 'Pensiero';

  @override
  String get agentMessageKindToolResult => 'Risultato dello strumento';

  @override
  String get agentMessageKindUser => 'Utente';

  @override
  String get agentMessagePayloadEmpty => '(senza contenuto)';

  @override
  String get agentMessagesEmpty => 'Nessun messaggio.';

  @override
  String agentMessagesErrorLoading(String error) {
    return 'Non caricare messaggi: $error';
  }

  @override
  String get agentObservationsEmpty =>
      'Non sono ancora state osservate osservazioni.';

  @override
  String agentPendingWakesActivityHourDetail(
    String hour,
    int count,
    String reasons,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risvegli',
      one: '1 risveglio',
    );
    return '$hour: $_temp0 ($reasons)';
  }

  @override
  String get agentPendingWakesActivityTitle => 'Attività di sveglia (24h)';

  @override
  String agentPendingWakesActivityTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risvegli totali',
      one: '1 risveglio totale',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesDeleteTooltip => 'Rimuovere la sveglia';

  @override
  String get agentPendingWakesEmptyFiltered =>
      'Nessuna scia corrisponde ai tuoi filtri.';

  @override
  String get agentPendingWakesFilterSectionType => 'Tipologia';

  @override
  String get agentPendingWakesGroupByType => 'Tipologia';

  @override
  String get agentPendingWakesPendingLabel => 'Finanziamenti';

  @override
  String agentPendingWakesRunningHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In esecuzione ora ($count)',
      one: 'In esecuzione ora',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesScheduledLabel => 'Programmato';

  @override
  String get agentPendingWakesSearchPlaceholder => 'Cerca sveglia...';

  @override
  String get agentPendingWakesSortDueLatest => 'Più recenti';

  @override
  String get agentPendingWakesSortDueSoonest => 'Più presto.';

  @override
  String get agentPendingWakesTitle => 'Cicli di sveglia';

  @override
  String get agentReportHistoryBadge => 'Relazione';

  @override
  String get agentReportHistoryEmpty => 'Non ci sono ancora istantanee.';

  @override
  String get agentReportHistoryError =>
      'Si è verificato un errore durante il caricamento della cronologia del rapporto.';

  @override
  String get agentReportNone => 'Nessun rapporto disponibile ancora.';

  @override
  String get agentRitualReviewAction => 'Iniziare la conversazione';

  @override
  String get agentRitualReviewNegativeSignals => 'Negativo';

  @override
  String get agentRitualReviewNeutralSignals => 'Neutrale';

  @override
  String get agentRitualReviewNoFeedback =>
      'Nessun segnale di feedback in questa finestra';

  @override
  String get agentRitualReviewNoNegativeSignals =>
      'Nessun segnale di feedback negativo in questa scheda';

  @override
  String get agentRitualReviewNoNeutralSignals =>
      'Nessun segnale di feedback neutro in questa scheda';

  @override
  String get agentRitualReviewNoPositiveSignals =>
      'Nessun segnale di feedback positivo in questa scheda';

  @override
  String get agentRitualReviewPositiveSignals => 'Positivo';

  @override
  String get agentRitualReviewProposalSection => 'Proposta attuale';

  @override
  String get agentRitualReviewSessionHistory => 'Storia della sessione';

  @override
  String get agentRitualReviewTitle => '1 su 1';

  @override
  String get agentRitualSummaryApprovedChangesHeading => 'Modifiche approvate';

  @override
  String get agentRitualSummaryConversationHeading => 'Conversazione';

  @override
  String get agentRitualSummaryRecapHeading => 'Riepilogo sessione';

  @override
  String get agentRitualSummaryRoleAssistant => 'Agente';

  @override
  String get agentRitualSummaryRoleUser => 'Tu sei';

  @override
  String get agentRitualSummaryStartHint =>
      'Inizia un 1-on-1 per rivedere quello che ti ha disturbato, cosa ha funzionato, e cosa dovrebbe cambiare dopo.';

  @override
  String get agentRitualSummarySubtitle =>
      'Recenti 1-on-1, attività di sveglia reale, e i cambiamenti che hai accettato.';

  @override
  String get agentRitualSummaryTokensSinceLast => 'Tokens dall\'ultimo 1-on-1';

  @override
  String get agentRitualSummaryWakeHistory30Days =>
      'Sveglia attività (ultimi 30 giorni)';

  @override
  String get agentRitualSummaryWakesSinceLast => 'Sveglia dall\'ultimo 1-on-1';

  @override
  String get agentRunningIndicator => 'Esecuzione';

  @override
  String get agentSessionProgressTitle => 'Progressi di sessione';

  @override
  String get agentSettingsSubtitle => 'Modelli, istanze e monitoraggio';

  @override
  String get agentSettingsTitle => 'Agenti';

  @override
  String get agentSoulAntiSycophancyLabel => 'Politica anti-sicofanzia';

  @override
  String get agentSoulAssignedTemplatesTitle => 'Modelli assegnati';

  @override
  String get agentSoulAssignmentLabel => 'Animazione';

  @override
  String get agentSoulCoachingStyleLabel => 'Stile di coaching';

  @override
  String get agentSoulCreatedSuccess => 'L\'anima creata';

  @override
  String get agentSoulCreateTitle => 'Creare l\'anima';

  @override
  String get agentSoulDeleteConfirmBody =>
      'Questo rimuoverà l\'anima e tutte le sue versioni.';

  @override
  String get agentSoulDeleteConfirmTitle => 'Eliminare l\'anima';

  @override
  String get agentSoulDetailTitle => 'Dettaglio dell\'anima';

  @override
  String get agentSoulDisplayNameLabel => 'Nome';

  @override
  String get agentSoulEvolutionHistoryTitle =>
      'Storia dell\'evoluzione dell\'anima';

  @override
  String get agentSoulEvolutionNoSessions =>
      'Nessuna sessione di evoluzione dell\'anima';

  @override
  String get agentSoulFieldAntiSycophancy => 'Anti-sicofanzia';

  @override
  String get agentSoulFieldCoachingStyle => 'Stile di coaching';

  @override
  String get agentSoulFieldToneBounds => 'Bordi di tono';

  @override
  String get agentSoulFieldVoice => 'Voce';

  @override
  String get agentSoulInfoTab => 'Informazioni';

  @override
  String get agentSoulNoneAssigned => 'Nessuna anima assegnata';

  @override
  String get agentSoulNotFound => 'L\'anima non trovata';

  @override
  String get agentSoulProposalSubtitle => 'Cambiamenti di personalità proposti';

  @override
  String get agentSoulProposalTitle => 'Proposta di personalità dell\'anima';

  @override
  String get agentSoulReviewHeroSubtitle =>
      'Definire la personalità in tutti i modelli che condividono questa anima. L\'agente di evoluzione vede feedback da ogni modello che utilizza questa personalità.';

  @override
  String get agentSoulReviewStartAction =>
      'Iniziare la recensione della personalità';

  @override
  String get agentSoulReviewStartHint =>
      'Inizia una sessione focalizzata sulla personalità per rivedere il feedback e evolvere la voce, il tono, lo stile di coaching e la direttività.';

  @override
  String agentSoulReviewTemplateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelli che condividono questa anima',
      one: '1 modello che condivide l\'anima',
    );
    return '$_temp0';
  }

  @override
  String get agentSoulReviewTitle => 'Anima 1-on-1';

  @override
  String get agentSoulRollbackAction => 'Torna indietro a questa versione';

  @override
  String agentSoulRollbackConfirm(int version) {
    return 'Ripiegare alla versione $version? Tutti i modelli che utilizzano questa anima raccoglieranno il cambiamento.';
  }

  @override
  String get agentSoulSelectTitle => 'Selezionare l\'anima';

  @override
  String get agentSoulsEmptyFiltered =>
      'Nessuna anima corrisponde ai tuoi filtri.';

  @override
  String get agentSoulSettingsTab => 'Impostazioni delle impostazioni';

  @override
  String get agentSoulsSearchPlaceholder => 'Cerca anime...';

  @override
  String get agentSoulsTitle => 'Le anime';

  @override
  String get agentSoulToneBoundsLabel => 'Bordi di tono';

  @override
  String get agentSoulVersionHistoryTitle => 'Storia della versione';

  @override
  String agentSoulVersionLabel(int version) {
    return 'Versione $version';
  }

  @override
  String get agentSoulVersionSaved => 'Nuova versione anima salvata';

  @override
  String get agentSoulVoiceDirectiveLabel => 'Direttiva della voce';

  @override
  String get agentStateConsecutiveFailures => 'Fallimenti consecutivi';

  @override
  String agentStateErrorLoading(String error) {
    return 'Non caricato stato: $error';
  }

  @override
  String get agentStateHeading => 'Informazioni sullo stato';

  @override
  String get agentStateLastWake => 'Ultimo risveglio';

  @override
  String get agentStateNextWake => 'La prossima sveglia';

  @override
  String get agentStateRevision => 'Revisione';

  @override
  String get agentStateSleepingUntil => 'Dormire fino a quando';

  @override
  String get agentStateWakeCount => 'Contesto di sveglia';

  @override
  String get agentStatsAllDayLegend => 'Tutto il giorno';

  @override
  String get agentStatsAverageLabel => 'Media';

  @override
  String agentStatsByTimeLegend(String time) {
    return 'Quotidiano di $time';
  }

  @override
  String get agentStatsCacheRateLabel => 'Tasso di Cache';

  @override
  String get agentStatsDailyUsageHeading => 'Uso quotidiano';

  @override
  String get agentStatsInputLabel => 'Dati in ingresso';

  @override
  String get agentStatsNoUsage =>
      'Nessun utilizzo di token registrato negli ultimi 7 giorni.';

  @override
  String get agentStatsOutputLabel => 'Produzione';

  @override
  String agentStatsSourceActiveFor(String duration) {
    return 'Attivo per $duration';
  }

  @override
  String get agentStatsSourceActivityHeading => 'Attività agente';

  @override
  String agentStatsSourceWakes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risvegli',
      one: '1 risveglio',
    );
    return '$_temp0';
  }

  @override
  String get agentStatsTabTitle => 'Statistiche';

  @override
  String get agentStatsThoughtsLabel => 'Pensieri';

  @override
  String get agentStatsTodayLabel => 'Oggi';

  @override
  String get agentStatsTokensPerWakeLabel => 'Tokens / Sveglia';

  @override
  String get agentStatsTokensUnit => 'Tokens';

  @override
  String agentStatsUsageAboveAverage(String time) {
    return 'Stai usando più gettoni oggi che di solito fai da $time.';
  }

  @override
  String agentStatsUsageBelowAverage(String time) {
    return 'Stai usando meno gettoni oggi che di solito fai da $time.';
  }

  @override
  String get agentStatsWakesLabel => 'Sveglia';

  @override
  String get agentSuggestionTimeEntryUpdateCurrent => 'Corrente';

  @override
  String get agentSuggestionTimeEntryUpdateNoChange => '(invariato)';

  @override
  String get agentSuggestionTimeEntryUpdateProposed => 'Proposta';

  @override
  String get agentSuggestionTimeEntryUpdateUnavailable =>
      'Articolo originale non disponibile';

  @override
  String get agentTabActivity => 'Attività';

  @override
  String get agentTabConversations => 'Conversazioni';

  @override
  String get agentTabObservations => 'Osservazioni';

  @override
  String get agentTabReports => 'Rapporti';

  @override
  String get agentTabStats => 'Statistiche';

  @override
  String get agentTemplateAggregateTokenUsageHeading =>
      'Uso del token aggregato';

  @override
  String get agentTemplateAssignedLabel => 'Modello';

  @override
  String get agentTemplateCreatedSuccess => 'Template creato';

  @override
  String get agentTemplateCreateTitle => 'Crea un modello';

  @override
  String get agentTemplateDeleteConfirm =>
      'Eliminare questo modello? Questo non può essere annullato.';

  @override
  String get agentTemplateDeleteHasInstances =>
      'Non è possibile eliminare: gli agenti attivi utilizzano questo modello.';

  @override
  String get agentTemplateDisplayNameLabel => 'Nome';

  @override
  String get agentTemplateEditTitle => 'Modifica modello';

  @override
  String get agentTemplateEvolveApprove => 'Approva e salva';

  @override
  String get agentTemplateEvolveReject => 'Rifiuti';

  @override
  String get agentTemplateGeneralDirectiveHint =>
      'Definire la personalità, gli strumenti, gli obiettivi e lo stile di interazione dell\'agente...';

  @override
  String get agentTemplateGeneralDirectiveLabel => 'Direttiva del Consiglio';

  @override
  String get agentTemplateInstanceBreakdownHeading =>
      'Ripartizione per instance';

  @override
  String get agentTemplateKindDayAgent => 'Agente del giorno';

  @override
  String get agentTemplateKindEventAgent => 'Agente eventi';

  @override
  String get agentTemplateKindImprover => 'Miglioramento dei modelli';

  @override
  String get agentTemplateKindProjectAgent => 'Agente di progetto';

  @override
  String get agentTemplateKindTaskAgent => 'Agente di servizio';

  @override
  String get agentTemplateMetricsTotalWakes => 'Totale sveglia';

  @override
  String get agentTemplateNoneAssigned => 'Nessun modello assegnato';

  @override
  String get agentTemplateNoTemplates =>
      'Non sono disponibili modelli. Crea uno in Impostazioni prima.';

  @override
  String get agentTemplateNotFound => 'Template non trovato';

  @override
  String get agentTemplateNoVersions => 'Nessuna versione';

  @override
  String get agentTemplateReportDirectiveHint =>
      'Definire la struttura del rapporto, le sezioni richieste e le regole di formattazione...';

  @override
  String get agentTemplateReportDirectiveLabel => 'Direttiva della Commissione';

  @override
  String get agentTemplateReportsEmpty => 'Non ci sono ancora rapporti.';

  @override
  String get agentTemplateReportsTab => 'Rapporti';

  @override
  String get agentTemplateRollbackAction => 'Torna indietro a questa versione';

  @override
  String agentTemplateRollbackConfirm(int version) {
    return 'Torna alla versione $version? L\'agente userà questa versione sulla sua prossima sveglia.';
  }

  @override
  String get agentTemplateSaveNewVersion => 'Salva';

  @override
  String get agentTemplateSelectTitle => 'Seleziona il modello';

  @override
  String get agentTemplatesEmptyFiltered =>
      'Nessun modello corrisponde ai tuoi filtri.';

  @override
  String get agentTemplateSettingsTab => 'Impostazioni delle impostazioni';

  @override
  String get agentTemplatesFilterSectionKind => 'Tipo...';

  @override
  String get agentTemplatesGroupByKind => 'Tipo...';

  @override
  String get agentTemplatesGroupNone => 'Tutti';

  @override
  String get agentTemplatesSearchPlaceholder => 'Modelli di ricerca...';

  @override
  String get agentTemplateStatsTab => 'Statistiche';

  @override
  String get agentTemplateStatusActive => 'Attivo';

  @override
  String get agentTemplateStatusArchived => 'Archivio';

  @override
  String get agentTemplatesTitle => 'Modelli dell\'agente';

  @override
  String get agentTemplateSwitchHint =>
      'Per usare un modello diverso, distruggere questo agente e crearne uno nuovo.';

  @override
  String get agentTemplateVersionHistoryTitle => 'Storia della versione';

  @override
  String agentTemplateVersionLabel(int version) {
    return 'Versione $version';
  }

  @override
  String get agentTemplateVersionSaved => 'Nuova versione salvata';

  @override
  String get agentThreadReportLabel => 'Rapporto prodotto durante la veglia';

  @override
  String get agentTokenUsageCachedTokens => 'In cache';

  @override
  String get agentTokenUsageEmpty =>
      'Nessun utilizzo di token registrato ancora.';

  @override
  String agentTokenUsageErrorLoading(String error) {
    return 'Non caricare l\'utilizzo di token: $error';
  }

  @override
  String get agentTokenUsageHeading => 'Uso token';

  @override
  String get agentTokenUsageInputTokens => 'Dati in ingresso';

  @override
  String get agentTokenUsageModel => 'Modello';

  @override
  String get agentTokenUsageOutputTokens => 'Produzione';

  @override
  String get agentTokenUsageThoughtsTokens => 'Pensieri';

  @override
  String get agentTokenUsageTotalTokens => 'Totale';

  @override
  String get agentTokenUsageWakeCount => 'Sveglia';

  @override
  String get aggregationDailyAvg => 'Media giornaliera';

  @override
  String get aggregationDailyMax => 'Massimo giornaliero';

  @override
  String get aggregationDailySum => 'Sommario giornaliero';

  @override
  String get aggregationHourlySum => 'Somma oraria';

  @override
  String get aggregationNone => 'Valori correnti';

  @override
  String get aiAssistantTitle => 'Genera...';

  @override
  String get aiBatchToggleTooltip => 'Passare alla registrazione standard';

  @override
  String get aiCapabilityChipImageGeneration => 'Generazione di immagini';

  @override
  String get aiCapabilityChipImageRecognition =>
      'Riconoscimento dell\'immagine';

  @override
  String get aiCapabilityChipThinking => 'Pensare';

  @override
  String get aiCapabilityChipTranscription => 'Trascrizione';

  @override
  String aiCardHistoryToggle(int count) {
    return 'Storia · $count';
  }

  @override
  String get aiCardMenuActionDelete => 'Cancella';

  @override
  String get aiCardMenuActionEdit => 'Modifica';

  @override
  String get aiCardMenuTooltip => 'Altre azioni';

  @override
  String get aiCardOpenAgentInternals => 'Interni di agente aperto';

  @override
  String get aiCardProposalConfirmed => 'Confermato';

  @override
  String get aiCardProposalDismissed => 'Annullamento della decisione n.';

  @override
  String get aiCardProposalKindAdd => 'Aggiungi';

  @override
  String get aiCardProposalKindDue => 'Scadenza';

  @override
  String get aiCardProposalKindEstimate => 'Stima';

  @override
  String get aiCardProposalKindLabel => 'Etichetta';

  @override
  String get aiCardProposalKindPriority => 'Priorità';

  @override
  String get aiCardProposalKindRemove => 'Rimuovi';

  @override
  String get aiCardProposalKindStatus => 'Stato';

  @override
  String get aiCardProposalKindUpdate => 'Aggiornamento';

  @override
  String get aiCardReadMore => 'Leggi tutto';

  @override
  String get aiCardShowLess => 'Mostra di meno';

  @override
  String get aiCardTitle => 'Riepilogo dell\'AI';

  @override
  String get aiChatAssistantResponding => 'L’assistente sta rispondendo';

  @override
  String get aiChatMessageCopied => 'Copiato negli appunti';

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Non caricare modelli. Si prega di riprovare.';

  @override
  String get aiConfigNoModelsAvailable =>
      'Non sono ancora configurati modelli AI. Si prega di aggiungere uno nelle impostazioni.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Nessun modello soddisfa i requisiti per questo prompt. Si prega di configurare i modelli che supportano le funzionalità richieste.';

  @override
  String get aiConfigSelectProviderModalTitle =>
      'Seleziona il provider di inferenza';

  @override
  String get aiConfigSelectProviderTypeModalTitle =>
      'Selezionare il tipo di fornitore';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Utilizzare ragionamento';

  @override
  String aiConsumptionCallsLine(int count, int measured) {
    return 'AI chiama: $count · impatto misurato per $measured';
  }

  @override
  String aiConsumptionCostLine(String cost) {
    return 'Costo: $cost';
  }

  @override
  String aiConsumptionImpactLine(String energy, String carbon, String water) {
    return 'Impatto: $energy · $carbon CO2e · $water acqua';
  }

  @override
  String aiConsumptionLedgerCap(int limit) {
    return 'Mostrare le ultime chiamate $limit in questo periodo';
  }

  @override
  String get aiConsumptionLedgerTitle => 'Chiamate recenti';

  @override
  String get aiConsumptionMetricsNotReported => 'Non riportato';

  @override
  String aiConsumptionTokensLabel(String tokens) {
    return 'Token $tokens';
  }

  @override
  String aiConsumptionTokensLine(String input, String output) {
    return 'Token: $input in ingresso · $output in uscita';
  }

  @override
  String get aiConsumptionTypeAgentTurn => 'Agente turno';

  @override
  String get aiConsumptionTypeAudioTranscription => 'Trascrizione';

  @override
  String get aiConsumptionTypeImageAnalysis => 'Analisi immagine';

  @override
  String get aiConsumptionTypeImageGeneration => 'Generazione di immagini';

  @override
  String get aiConsumptionTypePromptGeneration => 'Generazione di Prompt';

  @override
  String get aiConsumptionTypeTextGeneration => 'Generazione di testi';

  @override
  String aiDeleteToastCascadeDescription(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rimossa anche modelli $count: $names',
      one: 'Rimossa anche 1 modello: $names',
    );
    return '$_temp0';
  }

  @override
  String aiDeleteToastErrorTitle(String name) {
    return 'Non è stato possibile eliminare $name';
  }

  @override
  String get aiDeleteToastModelTitle => 'Modello cancellato';

  @override
  String get aiDeleteToastProfileTitle => 'Profilo cancellato';

  @override
  String get aiDeleteToastPromptTitle => 'Prompt cancellato';

  @override
  String get aiDeleteToastProviderTitle => 'Fornitore cancellato';

  @override
  String get aiDeleteToastSkillTitle => 'Competenze cancellate';

  @override
  String get aiDeleteToastUndoAction => 'Annulla';

  @override
  String get aiFormCancel => 'Annullamento';

  @override
  String get aiFormFixErrors =>
      'Si prega di correggere gli errori prima di salvare';

  @override
  String get aiFormNoChanges => 'Nessuna modifica non rilevata';

  @override
  String get aiImageAnalysisPickerDefaultBadge => 'Predefinito';

  @override
  String get aiImageAnalysisPickerTitle =>
      'Scegli un modello di analisi dell\'immagine';

  @override
  String get aiImageGenerationPickerTitle =>
      'Scegli un modello di generazione di immagini';

  @override
  String get aiImpactBreakdownBoth => 'Entrambi.';

  @override
  String get aiImpactBreakdownCategory => 'Per categoria';

  @override
  String get aiImpactBreakdownModel => 'Per modello';

  @override
  String get aiImpactCategoryTitle => 'Ripartizione della categoria';

  @override
  String get aiImpactChartHint =>
      'Toccare una barra alle chiamate di portata · toccare una serie per isolare';

  @override
  String get aiImpactChartShareCaption => 'Composizione nel tempo';

  @override
  String get aiImpactChartShareSegment => 'Condividi';

  @override
  String aiImpactChartTitle(String metric) {
    return '$metric per categoria';
  }

  @override
  String aiImpactChartTitleModel(String metric) {
    return '$metric per modello';
  }

  @override
  String get aiImpactCoverageNote =>
      'Energia, CO2e e costi sono misurati solo per i modelli cloud.';

  @override
  String get aiImpactEmptyBody =>
      'Le chiamate dell\'IA dai vostri compiti e gli agenti si presenteranno qui.';

  @override
  String get aiImpactEmptyTitle => 'Nessun utilizzo di AI in questa gamma';

  @override
  String get aiImpactKpiCarbon => 'CO2E';

  @override
  String get aiImpactKpiCost => 'COSTO';

  @override
  String aiImpactKpiDeltaBaseline(String period) {
    return 'rispetto a $period';
  }

  @override
  String get aiImpactKpiEnergy => 'ENERGIA';

  @override
  String get aiImpactKpiRequests => 'RICHIESTA';

  @override
  String get aiImpactKpiTokens => 'TOKENSO';

  @override
  String get aiImpactLedgerClearFilter => 'Mostra tutto';

  @override
  String get aiImpactLoadError =>
      'Non è possibile caricare i dati di impatto dell\'AI';

  @override
  String get aiImpactLocationColumn => 'LOCAZIONE';

  @override
  String get aiImpactLocationTitle => 'Impatto per posizione';

  @override
  String get aiImpactLocationUnknown => 'Sconosciuto';

  @override
  String get aiImpactMetricCarbon => 'CO2e';

  @override
  String get aiImpactMetricCost => 'Costo';

  @override
  String get aiImpactMetricEnergy => 'Energia';

  @override
  String get aiImpactMetricRequests => 'Richieste';

  @override
  String get aiImpactMetricTokens => 'Token';

  @override
  String aiImpactModelCallsLabel(String count) {
    return 'Chiamate $count';
  }

  @override
  String get aiImpactModelColumn => 'MODELLO';

  @override
  String get aiImpactModelCostHeavy => 'costo-pesante';

  @override
  String get aiImpactModelCoverageNote =>
      'I modelli locali sono esclusi da questo grafico.';

  @override
  String get aiImpactModelOther => 'Altri modelli';

  @override
  String aiImpactModelRatePerMillion(String cost) {
    return '$cost/1M token';
  }

  @override
  String get aiImpactModelTitle => 'Ripartizione del modello';

  @override
  String get aiImpactModelUnknown => 'Modello sconosciuto';

  @override
  String get aiImpactRenewableColumn => 'RENEZIA';

  @override
  String get aiImpactTitle => 'Impatto dell\'AI';

  @override
  String get aiInferenceErrorAuthenticationTitle =>
      'Autenticazione non riuscita';

  @override
  String get aiInferenceErrorConnectionFailedTitle =>
      'Connessione non riuscita';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Richiesta non valida';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Limite di Tasso Escluso';

  @override
  String get aiInferenceErrorRetryButton => 'Prova di nuovo';

  @override
  String get aiInferenceErrorServerTitle => 'Errore del server';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Suggerimenti:';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Richiesta tempo libero';

  @override
  String get aiInferenceErrorUnknownTitle => 'Errore';

  @override
  String get aiInternalsTitle => 'Agenti interni';

  @override
  String get aiModelDownloadCloseButton => 'Chiudere';

  @override
  String aiModelDownloadDialogDescription(String modelName) {
    return 'Lotti scaricherà $modelName nella cache MLX Audio e la userà per l\'elaborazione del discorso locale.';
  }

  @override
  String aiModelDownloadDialogTitle(String modelName) {
    return 'Installare $modelName';
  }

  @override
  String get aiModelDownloadInstallTooltip => 'Modello di installazione';

  @override
  String get aiModelDownloadOpenProgressTooltip =>
      'Mostra i progressi del download';

  @override
  String get aiModelDownloadStatusChecking =>
      'Controllare lo stato del modello';

  @override
  String aiModelDownloadStatusDownloading(int percent) {
    return 'Scarica $percent%';
  }

  @override
  String get aiModelDownloadStatusDownloadingIndeterminate =>
      'Download in corso';

  @override
  String get aiModelDownloadStatusFailed => 'Download non riuscito';

  @override
  String get aiModelDownloadStatusInstalled => 'Installato';

  @override
  String get aiModelDownloadStatusNotInstalled => 'Non installato';

  @override
  String get aiModelDownloadStatusUnsupported => 'Apple Silicon richiesto';

  @override
  String get aiModelInstallChoiceCancelButton => 'Annullamento';

  @override
  String get aiModelInstallChoiceDescription =>
      'Scegli il modello vocale-to-text locale per scaricare prima. Puoi installare gli altri più tardi dalla lista dei modelli.';

  @override
  String get aiModelInstallChoiceInstallButton => 'Modello di installazione';

  @override
  String get aiModelInstallChoiceRecommended => 'Consigliato';

  @override
  String get aiModelInstallChoiceTitle => 'Scegli il modello MLX Audio';

  @override
  String get aiModelPickerByProviderLabel => 'Scegli un fornitore';

  @override
  String get aiModelPickerCurrentDefaultLabel => 'Corrente di default';

  @override
  String aiModelPickerProviderModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelli',
      one: '1 modello',
    );
    return '$_temp0';
  }

  @override
  String aiOllamaModelInstalledSuccessfully(String modelName) {
    return 'Modello \"$modelName\" installato con successo!';
  }

  @override
  String get aiPickProviderBadgeDesktopOnly => 'DESKTOP SOLO';

  @override
  String get aiPickProviderBadgeNew => 'NUOVO';

  @override
  String get aiPickProviderBadgeRecommended => 'RACCOMANDATO';

  @override
  String get aiPickProviderContinueButton => 'Continua';

  @override
  String get aiPickProviderDontShowAgainButton => 'Non mostrare di nuovo';

  @override
  String get aiPickProviderFooterHint =>
      'È possibile aggiungere più fornitori in seguito in Impostazioni → AI. La chiave API viene memorizzata localmente.';

  @override
  String get aiPickProviderModalTitle => 'Impostare le funzionalità AI';

  @override
  String get aiPickProviderSubtitle =>
      'Scegli un fornitore per iniziare. Organizzeremo i modelli e un profilo di partenza automaticamente.';

  @override
  String get aiProfileCardActiveBadge => 'Attivo';

  @override
  String get aiProfileModelPickerSearchHint => 'Modelli di ricerca...';

  @override
  String get aiProfileSlotModelMissing => 'mancante';

  @override
  String get aiPromptGenerationPickerTitle =>
      'Scegli un modello di generazione rapida';

  @override
  String get aiProviderAlibabaDescription =>
      'La famiglia di modelli Qwen di Alibaba Cloud tramite DashScope API';

  @override
  String get aiProviderAlibabaName => 'Alibaba Cloud (Qwen)';

  @override
  String get aiProviderAnthropicDescription =>
      'La famiglia Claude di assistenti dell\'AI di Antropic';

  @override
  String get aiProviderAnthropicName => 'Antropico Claude';

  @override
  String get aiProviderCardDraftBadge => 'BOZZA';

  @override
  String get aiProviderCardFixButton => 'Fissazione';

  @override
  String aiProviderCardModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelli',
      one: '1 modello',
    );
    return '$_temp0';
  }

  @override
  String aiProviderCardModelCountWithLastUsed(int count, String lastUsed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelli · ultima $lastUsed usata',
      one: '1 modello · ultimo $lastUsed',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardOllamaHint => 'Assicurarsi che Ollama stia correndo';

  @override
  String aiProviderCardStatusConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Connesso · $count modelli',
      one: 'Connesso · 1 modello',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardStatusConnectedShort => 'Collegato';

  @override
  String get aiProviderCardStatusInvalidKey => 'Chiave non valida';

  @override
  String get aiProviderCardStatusOffline =>
      'Offline · Assicurarsi che Ollama stia correndo';

  @override
  String get aiProviderCardStatusOfflineShort => 'Non in linea';

  @override
  String get aiProviderConnectBackToProviders => 'Torna ai provider';

  @override
  String get aiProviderConnectBreadcrumbAdd => 'Aggiungi il provider';

  @override
  String get aiProviderConnectFieldBaseUrlHint =>
      'Lasciare vuoto per usare l\'endpoint ufficiale';

  @override
  String get aiProviderConnectFieldBaseUrlLabelOptional =>
      'URL di base (opzionale)';

  @override
  String get aiProviderConnectFieldBaseUrlPlaceholder =>
      'https://api.example.com';

  @override
  String get aiProviderConnectFieldDisplayNameHint =>
      'Mostrato nella tua lista dei fornitori';

  @override
  String get aiProviderConnectionCheckingLabel =>
      'Tasto di controllo, elenco modelli disponibili...';

  @override
  String aiProviderConnectionFailedBadResponseDetail(String type) {
    return 'Forma di risposta inaspettata: $type';
  }

  @override
  String aiProviderConnectionFailedHttpDetail(int status, String message) {
    return 'HTTP $status · $message';
  }

  @override
  String get aiProviderConnectionFailedInvalidBaseUrlDetail =>
      'L\'URL di base deve includere lo schema http(s) e l\'host (ad esempio https://api.example.com)';

  @override
  String aiProviderConnectionFailedNetworkDetail(String message) {
    return '$message';
  }

  @override
  String get aiProviderConnectionFailedTimeoutDetail =>
      'Richiesta tempo libero';

  @override
  String aiProviderConnectionFailedTitle(String providerName) {
    return 'Non è possibile raggiungere $providerName. Controllare la chiave o la rete.';
  }

  @override
  String get aiProviderConnectionRetestButton => 'Ripeti il test';

  @override
  String get aiProviderConnectionRetryButton => 'Recuperare';

  @override
  String aiProviderConnectionVerifiedSubtitle(int count, int ms) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelli disponibili sul tuo conto · risposto in ${ms}ms',
      one: '1 modello disponibile sul tuo conto · risposto in ${ms}ms',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderConnectionVerifiedTitle => 'Connessione verificata';

  @override
  String aiProviderConnectKeyHelperLink(String url) {
    return 'Ottieni una chiave su $url';
  }

  @override
  String get aiProviderConnectKeyHiddenLabel => 'Nascosto';

  @override
  String get aiProviderConnectKeyPrivacyHint =>
      'La chiave API non lascia mai il tuo dispositivo.';

  @override
  String aiProviderConnectPageTitle(String providerName) {
    return 'Collegare $providerName';
  }

  @override
  String get aiProviderConnectSaveAndContinue => 'Salvare e continuare';

  @override
  String get aiProviderConnectSaveAsDraft => 'Salvare come bozza';

  @override
  String get aiProviderConnectSavedAsDraftToast => 'Salvataggio come bozza';

  @override
  String get aiProviderConnectStepChoose => 'Scegli il fornitore';

  @override
  String get aiProviderConnectStepConnect => 'Collegamento';

  @override
  String get aiProviderConnectStepReview => 'Recensione';

  @override
  String get aiProviderDetailActiveProfileTitle => 'Profilo attivo';

  @override
  String get aiProviderDetailAddModelButton => 'Aggiungi il modello';

  @override
  String get aiProviderDetailApiKeyLabel => 'Chiave API';

  @override
  String get aiProviderDetailBackTooltip => 'Indietro';

  @override
  String get aiProviderDetailBaseUrlLabel => 'URL della base';

  @override
  String get aiProviderDetailConnectionTitle => 'Connessione';

  @override
  String get aiProviderDetailDangerZoneTitle => 'Zona di pericolo';

  @override
  String get aiProviderDetailDisplayNameLabel => 'Nome dell\'esposizione';

  @override
  String get aiProviderDetailEditButton => 'Modifica';

  @override
  String get aiProviderDetailEditTooltip => 'Modifica del fornitore';

  @override
  String get aiProviderDetailLoadError =>
      'Non è possibile caricare questo provider. Riprova dall\'elenco Impostazioni AI.';

  @override
  String get aiProviderDetailMissingMessage =>
      'Questo fornitore non è più disponibile.';

  @override
  String aiProviderDetailModelsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Modelli · $count',
      one: 'Modelli · 1',
      zero: 'Modelli',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderDetailNoModelsMessage =>
      'Ancora nessun modello. Aggiungine uno per iniziare a usare questo fornitore.';

  @override
  String get aiProviderDetailPageTitle => 'Dettagli del fornitore';

  @override
  String get aiProviderDetailRemoveButton => 'Rimuovere il fornitore';

  @override
  String get aiProviderDetailRemoveDescription =>
      'Elimina il fornitore e ogni modello che dipende da esso. Questo non può essere annullato.';

  @override
  String get aiProviderDetailRemoveTitle => 'Rimuovi questo fornitore';

  @override
  String get aiProviderDetailValueUnset => 'Non impostato';

  @override
  String get aiProviderEmbeddedRuntimeHint =>
      'Esegue incorporato nel processo dell\'app Apple. Non è richiesto alcun server locale o URL di base.';

  @override
  String get aiProviderGeminiDescription => 'Modelli Gemini AI di Google';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiDescription =>
      'API compatibile con il formato OpenAI';

  @override
  String get aiProviderGenericOpenAiName => 'Compatibile con OpenAI';

  @override
  String get aiProviderMeliousDescription =>
      'Inferenza ospitata in Europa con un catalogo dinamico di modelli, routing, audio e immagini';

  @override
  String get aiProviderMeliousName => 'Melious.ai';

  @override
  String get aiProviderMistralDescription =>
      'Mistral AI cloud API con trascrizione audio nativo';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderMlxAudioDescription =>
      'Modelli MLX Audio integrati per STT e TTS locali su Apple Silicon';

  @override
  String get aiProviderMlxAudioName => 'MLX Audio (locale)';

  @override
  String get aiProviderNebiusAiStudioDescription =>
      'Modelli di Nebius AI Studio';

  @override
  String get aiProviderNebiusAiStudioName => 'Nebius AI Studio';

  @override
  String get aiProviderOllamaDescription =>
      'Eseguire l\'inferenza localmente con Ollama';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOmlxDescription =>
      'Inferenza oMLX compatibile con OpenAI locale per modelli ML';

  @override
  String get aiProviderOmlxName => 'oMLX (locale)';

  @override
  String get aiProviderOpenAiDescription => 'Modelli GPT di OpenAI';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'Modelli di OpenRouter';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderTaglineAlibaba =>
      'Modelli Qwen · multimodale · contesto lungo';

  @override
  String get aiProviderTaglineAnthropic => 'Claude famiglia · contesto lungo';

  @override
  String get aiProviderTaglineGemini => 'Multimodal · trascrizione audio';

  @override
  String get aiProviderTaglineMelious =>
      'EU-hosted · catalogo dinamico · eco routing';

  @override
  String get aiProviderTaglineMlxAudio =>
      'Embedded · Apple Silicon · audio locale';

  @override
  String get aiProviderTaglineOllama =>
      'Corre localmente · nessuna chiamata cloud';

  @override
  String get aiProviderTaglineOmlx =>
      'Inferenza locale MLX · compatibile con OpenAI';

  @override
  String get aiProviderTaglineOpenAi => 'Famiglia GPT · visione + ragionamento';

  @override
  String get aiProviderUnknownName => 'Fornitore di AI';

  @override
  String get aiProviderVoxtralDescription =>
      'Trascrizione Voxtral locale (fino a 30 min audio, 13 lingue)';

  @override
  String get aiProviderVoxtralName => 'Voxtral (locale)';

  @override
  String get aiProviderWhisperDescription =>
      'Trascrizione locale Whisper con API compatibile con OpenAI';

  @override
  String get aiProviderWhisperName => 'Whisper (locale)';

  @override
  String get aiRealtimeToggleTooltip => 'Passare alla trascrizione live';

  @override
  String get aiResponseDeleteCancel => 'Annullamento';

  @override
  String get aiResponseDeleteConfirm => 'Cancella';

  @override
  String get aiResponseDeleteError =>
      'Non è riuscito a eliminare la risposta AI. Si prega di riprovare.';

  @override
  String get aiResponseDeleteTitle => 'Eliminare la risposta AI';

  @override
  String get aiResponseDeleteWarning =>
      'Sei sicuro di voler eliminare questa risposta AI? Questo non può essere annullato.';

  @override
  String get aiResponseTypeAudioTranscription => 'Trascrizione audio';

  @override
  String get aiResponseTypeChecklistUpdates =>
      'Aggiornamenti della lista di controllo';

  @override
  String get aiResponseTypeImageAnalysis => 'Analisi immagine';

  @override
  String get aiResponseTypeImagePromptGeneration => 'Prompt immagine';

  @override
  String get aiResponseTypePromptGeneration => 'Prompt generata';

  @override
  String get aiResponseTypeTaskSummary => 'Riepilogo delle attività';

  @override
  String get aiRunningActivityOpenProgress => 'Mostra i progressi dell\'IA';

  @override
  String get aiSettingsAddedLabel => 'Aggiunto';

  @override
  String get aiSettingsAddModelButton => 'Aggiungi il modello';

  @override
  String get aiSettingsAddModelErrorDescription =>
      'Qualcosa è andato storto durante l\'aggiunta del modello.';

  @override
  String get aiSettingsAddModelErrorTitle =>
      'Non è possibile aggiungere il modello';

  @override
  String get aiSettingsAddModelTooltip =>
      'Aggiungi questo modello al tuo fornitore';

  @override
  String get aiSettingsAddProfileButton => 'Aggiungi il profilo';

  @override
  String get aiSettingsAddProviderButton => 'Aggiungi il provider';

  @override
  String get aiSettingsAgentWakeConcurrencyDescription =>
      'Scelga quanti agenti diversi possono eseguire l\'inferenza contemporaneamente. I valori più elevati rispondono più velocemente ma usano più provider e capacità del dispositivo.';

  @override
  String get aiSettingsAgentWakeConcurrencyLabel =>
      'L\'agente corrente si sveglia';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Cancella tutti i filtri';

  @override
  String get aiSettingsClearFiltersButton => 'Cancellazione';

  @override
  String get aiSettingsCounterModels => 'Modelli';

  @override
  String get aiSettingsCounterProfiles => 'Profili';

  @override
  String get aiSettingsCounterProviders => 'Fornitori';

  @override
  String get aiSettingsEmptyDescription =>
      'Aggiungere uno per sbloccare la trascrizione, il riconoscimento delle immagini, la generazione di immagini e la ricerca semantica.';

  @override
  String get aiSettingsEmptyTitle => 'Nessun provider ancora';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filtra per capacità $capability';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filtra per $provider';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip =>
      'Filtra con capacità di ragionamento';

  @override
  String get aiSettingsFtueBannerDescription =>
      'Ci vuole circa un minuto. Lotti istituirà modelli e un profilo iniziale per voi.';

  @override
  String get aiSettingsFtueBannerStartButton => 'Avviare la configurazione';

  @override
  String get aiSettingsFtueBannerTitle => 'Aggiungi il tuo primo fornitore AI';

  @override
  String get aiSettingsModalityAudio => 'Audio audio';

  @override
  String get aiSettingsModalityText => 'Testo';

  @override
  String get aiSettingsModalityVision => 'Visione';

  @override
  String get aiSettingsNoModelsConfigured => 'Nessun modello AI configurato';

  @override
  String get aiSettingsNoProvidersConfigured =>
      'Nessun provider AI configurato';

  @override
  String get aiSettingsPageLead =>
      'Configurare i provider AI, i modelli Lotti possono chiamare, e i profili di inferenza che decidono quale modello gestisce quale compito.';

  @override
  String get aiSettingsPageTitle => 'Impostazioni dell\'intelligenza';

  @override
  String get aiSettingsReasoningLabel => 'Ragione';

  @override
  String get aiSettingsRemoveModelTooltip =>
      'Rimuovi questo modello dal tuo fornitore';

  @override
  String get aiSettingsSearchHint =>
      'Fornitori di ricerca, modelli, profili...';

  @override
  String get aiSettingsSearchHintShort => 'Ricerca';

  @override
  String get aiSettingsTabModels => 'Modelli';

  @override
  String get aiSettingsTabProfiles => 'Profili';

  @override
  String get aiSettingsTabProviders => 'Fornitori';

  @override
  String get aiSetupPreviewAcceptButton => 'Accettare e finire';

  @override
  String get aiSetupPreviewAlreadyAddedSectionLabel => 'Già aggiunto';

  @override
  String aiSetupPreviewCategoryFooter(String categoryName) {
    return 'Impostare una categoria di test $categoryName per provarlo.';
  }

  @override
  String aiSetupPreviewConnectedHeader(String providerName) {
    return '$providerName collegato';
  }

  @override
  String get aiSetupPreviewCustomizeButton => 'Personalizzarsi';

  @override
  String get aiSetupPreviewLead =>
      'Scopri cosa aggiunge Lotti. Deseleziona tutto quello che non vuoi; puoi sempre impostarlo a mano.';

  @override
  String get aiSetupPreviewLiveBadge => 'Vivo';

  @override
  String aiSetupPreviewModalTitle(String providerName) {
    return 'Configurazione $providerName';
  }

  @override
  String get aiSetupPreviewModelsSectionLabel => 'Modelli';

  @override
  String get aiSetupPreviewProfileSectionLabel => 'Profilo di inferenza';

  @override
  String get aiSetupPreviewProfileSetActiveBadge => 'Impostazione attiva';

  @override
  String aiSetupResultBulletCategoryCreated(String categoryName) {
    return 'Impostare una categoria di test $categoryName per provarlo';
  }

  @override
  String aiSetupResultBulletCategoryReused(String categoryName) {
    return 'Riutilizzare la categoria di test esistente $categoryName';
  }

  @override
  String aiSetupResultBulletModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Configurati $count modelli',
      one: 'Configurato 1 modello',
    );
    return '$_temp0';
  }

  @override
  String aiSetupResultBulletProfile(String profileName) {
    return 'Profilo di inferenza creato $profileName';
  }

  @override
  String aiSetupResultErrorsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemi',
      one: '1 problema',
    );
    return '$_temp0 durante la configurazione';
  }

  @override
  String aiSetupResultHeader(String providerName) {
    return '$providerName è collegato';
  }

  @override
  String aiSetupResultKnownModelsMissing(String providerName) {
    return 'Non riuscito a trovare le configurazioni del modello $providerName richieste';
  }

  @override
  String get aiSetupResultLead =>
      'Abbiamo impostato le cose per voi. Le funzioni dell\'IA sono pronte per l\'uso nel vostro diario.';

  @override
  String aiSetupResultModalTitle(String providerName) {
    return '$providerName pronto';
  }

  @override
  String get aiSetupResultStartUsingButton => 'Iniziare a usare AI';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Crea modelli ottimizzati, richieste e una categoria di test';

  @override
  String aiSetupWizardDescription(String providerName) {
    return 'Impostare o aggiornare i modelli, i suggerimenti e la categoria di test per $providerName';
  }

  @override
  String get aiSetupWizardRunButton => 'Impostazione di corsa';

  @override
  String get aiSetupWizardRunLabel =>
      'Eseguire la procedura guidata configurazione';

  @override
  String get aiSetupWizardRunningButton => 'Correre...';

  @override
  String get aiSetupWizardSafeToRunMultiple =>
      'Sicuro per eseguire più volte - gli elementi esistenti saranno mantenuti';

  @override
  String get aiSetupWizardTitle =>
      'Mago di configurazione dell\'intelligenza artificiale';

  @override
  String get aiSummaryPlayTooltip => 'Riepilogo del gioco';

  @override
  String get aiSummaryPreparingTooltip => 'Preparazione audio';

  @override
  String get aiSummarySpeakTooltip => 'Leggi sommario aloud localmente';

  @override
  String get aiSummaryStopTooltip => 'Fermati.';

  @override
  String get aiSummaryThinkingLabel => 'Pensando...';

  @override
  String get aiSummaryTtsUnavailable => 'Text-to-speech non è disponibile';

  @override
  String get aiTaskSummaryTitle => 'Riassunto delle attività AI';

  @override
  String get aiTranscriptionPickerDefaultBadge => 'Predefinito';

  @override
  String get aiTranscriptionPickerTitle => 'Scegli un modello di trascrizione';

  @override
  String get apiKeyAddPageTitle => 'Aggiungi Provider';

  @override
  String get apiKeyAuthenticationDescription => 'Proteggi la connessione API';

  @override
  String get apiKeyAuthenticationTitle => 'Autenticazione';

  @override
  String get apiKeyAvailableModelsDescription =>
      'Modelli preconfigurati rapidi per questo provider';

  @override
  String get apiKeyAvailableModelsTitle => 'Modelli disponibili';

  @override
  String get apiKeyBaseUrlLabel => 'URL della base';

  @override
  String get apiKeyDisplayNameHint => 'Inserisci un nome amichevole';

  @override
  String get apiKeyDisplayNameLabel => 'Nome dell\'esposizione';

  @override
  String get apiKeyDynamicModelsDescription =>
      'Cerca nel catalogo modelli dal vivo di questo fornitore e aggiungi qualsiasi modello';

  @override
  String get apiKeyEditGoBackButton => 'Torna indietro';

  @override
  String get apiKeyEditLoadError =>
      'Non è possibile caricare la configurazione delle chiavi API';

  @override
  String get apiKeyEditLoadErrorRetry =>
      'Si prega di provare di nuovo o contattare il supporto';

  @override
  String get apiKeyEditPageTitle => 'Modifica Provider';

  @override
  String get apiKeyHideTooltip => 'Nascondi la chiave API';

  @override
  String get apiKeyInputHint => 'Inserisci la chiave API';

  @override
  String get apiKeyInputLabel => 'Chiave API';

  @override
  String apiKeyKnownModelInputLabel(String modalities) {
    return 'In ingresso: $modalities';
  }

  @override
  String apiKeyKnownModelOutputLabel(String modalities) {
    return 'In uscita: $modalities';
  }

  @override
  String get apiKeyProviderConfigDescription =>
      'Configura le impostazioni del provider di inferenza AI';

  @override
  String get apiKeyProviderConfigTitle => 'Configurazione del fornitore';

  @override
  String get apiKeyProviderTypeHint => 'Selezionare un tipo di fornitore';

  @override
  String get apiKeyProviderTypeLabel => 'Tipo di fornitore';

  @override
  String get apiKeyShowTooltip => 'Mostra la chiave API';

  @override
  String get audioRecordingCancel => 'CANCELLAZIONE';

  @override
  String get audioRecordingDiscardDialogBody =>
      'Questa registrazione verrà cancellata. Non verrà creata alcuna voce audio, trascrizione o sommaria delle attività.';

  @override
  String get audioRecordingDiscardDialogCancel => 'Continua a registrare';

  @override
  String get audioRecordingDiscardDialogConfirm => 'Cartolina';

  @override
  String get audioRecordingDiscardDialogTitle =>
      'Disattivare la registrazione?';

  @override
  String get audioRecordingListening => 'Ascoltare...';

  @override
  String get audioRecordingPause => 'PAESI';

  @override
  String get audioRecordingRealtime => 'Trascrizione live';

  @override
  String get audioRecordingResume => 'RISORSE';

  @override
  String get audioRecordings => 'Registrazioni audio';

  @override
  String get audioRecordingStandard => 'Modalità standard';

  @override
  String get audioRecordingStop => 'ARRESTA';

  @override
  String backfillAdvancedRecoveryActions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count azioni',
      one: '1 azione',
    );
    return '$_temp0';
  }

  @override
  String get backfillAdvancedRecoveryTitle => 'Recupero avanzato';

  @override
  String get backfillAskPeersConfirmAccept => 'Chiedi ai colleghi';

  @override
  String backfillAskPeersConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Questa operazione riporta $count voci irrisolvibili del log di sequenza allo stato mancante, in modo che il normale ciclo di recupero richieda di nuovo i peer. I peer che hanno ancora il contenuto risponderanno; le voci realmente irrecuperabili saranno nuovamente ritirate dopo i 7 giorni di tolleranza.',
      one:
          'Questa operazione riporta 1 voce irrisolvibile del log di sequenza allo stato mancante, in modo che il normale ciclo di recupero richieda di nuovo i peer. I peer che hanno ancora il contenuto risponderanno; le voci realmente irrecuperabili saranno nuovamente ritirate dopo i 7 giorni di tolleranza.',
    );
    return '$_temp0';
  }

  @override
  String get backfillAskPeersConfirmTitle =>
      'Chiedi ai pari di nuovo per le voci irrisolvibili?';

  @override
  String get backfillAskPeersDescription =>
      'Flip ogni entrata in sequenza-log irrisolvibile indietro per mancare e lasciare che il normale backfill spazzare peers re-ask.';

  @override
  String get backfillAskPeersProcessing => 'Riaprire...';

  @override
  String get backfillAskPeersTitle => 'Chiedi ai coetanei per irrisolvibili';

  @override
  String backfillAskPeersTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Chiedi ai peer $count voci',
      one: 'Chiedi ai peer 1 voce',
    );
    return '$_temp0';
  }

  @override
  String get backfillCatchUpDescription =>
      'Tirare le ultime voci scomparse dai colleghi in questo momento.';

  @override
  String backfillDevicesMeta(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ID dispositivo',
      one: '1 ID dispositivo',
    );
    return '$_temp0';
  }

  @override
  String get backfillManualDescription =>
      'Richiedere tutte le voci mancanti indipendentemente dall\'età. Utilizzare questo per recuperare le lacune di sincronizzazione più vecchie.';

  @override
  String get backfillManualProcessing => 'Elaborazione...';

  @override
  String get backfillManualTitle => 'Ricambio manuale';

  @override
  String get backfillManualTrigger => 'Richiesta Voci mancanti';

  @override
  String get backfillReRequestDescription =>
      'Ri-richiesta che sono state richieste ma mai ricevute. Utilizzare questo quando le risposte sono bloccate.';

  @override
  String get backfillReRequestProcessing => 'Ri-richiesta...';

  @override
  String get backfillReRequestTitle => 'Ri-Richiesta Pending';

  @override
  String get backfillReRequestTrigger => 'Recuperare i Pending';

  @override
  String get backfillResetUnresolvableDescription =>
      'Reimpostare le voci contrassegnate come unresolvable indietro a mancare in modo che possano essere ri-richiesta.';

  @override
  String get backfillResetUnresolvableProcessing => 'Rimontare...';

  @override
  String get backfillResetUnresolvableTitle => 'Resettare irrisolvibile';

  @override
  String get backfillResetUnresolvableTrigger =>
      'Reimpostare le voci irrisolvibili';

  @override
  String get backfillRetireStuckConfirmAccept => 'Retire ora';

  @override
  String backfillRetireStuckConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Questa operazione contrassegna $count voci attualmente aperte del log di sequenza (mancanti o richieste) come irrisolvibili. Usala per sbloccare il watermark quando delle voci sono bloccate da tempo ma non sono ancora trascorsi i 7 giorni di tolleranza. Le voci potranno comunque essere ripristinate se i loro contenuti arriveranno in seguito sul disco con un vettore di versione valido.',
      one:
          'Questa operazione contrassegna 1 voce attualmente aperta del log di sequenza (mancante o richiesta) come irrisolvibile. Usala per sbloccare il watermark quando una voce è bloccata da tempo ma non sono ancora trascorsi i 7 giorni di tolleranza. La voce potrà comunque essere ripristinata se il suo contenuto arriverà in seguito sul disco con un vettore di versione valido.',
    );
    return '$_temp0';
  }

  @override
  String get backfillRetireStuckConfirmTitle =>
      'Ritirare le entrate bloccate ora?';

  @override
  String get backfillRetireStuckDescription =>
      'Forzare ogni ingresso di sequenza-log mancante o richiesto attualmente in irrisolvibile. Salta l\'amnistia di 7 giorni — utilizzare solo per file bloccate bloccando la filigrana.';

  @override
  String get backfillRetireStuckProcessing => 'Retiring...';

  @override
  String get backfillRetireStuckTitle => 'Retire le voci bloccate';

  @override
  String backfillRetireStuckTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ritira $count voci bloccate',
      one: 'Ritira 1 voce bloccata',
    );
    return '$_temp0';
  }

  @override
  String get backfillSettingsSubtitle =>
      'Gestire il recupero del gap di sincronizzazione';

  @override
  String get backfillSettingsTitle => 'Sincronizzazione di backup';

  @override
  String get backfillStatsBackfilled => 'Ricambio';

  @override
  String get backfillStatsBurned => 'Bruciata';

  @override
  String get backfillStatsDeleted => 'Cancellato';

  @override
  String get backfillStatsMissing => 'Mancato';

  @override
  String get backfillStatsNoData =>
      'Nessun dato di sincronizzazione disponibile';

  @override
  String get backfillStatsReceived => 'Ricevuto.';

  @override
  String get backfillStatsRefresh => 'Rifiuti stat';

  @override
  String get backfillStatsRequested => 'Richiesta';

  @override
  String get backfillStatsTitle => 'Statistiche di Sync';

  @override
  String get backfillStatsTotalEntries => 'Totale delle entrate';

  @override
  String get backfillStatsUnresolvable => 'Irrisolvibile';

  @override
  String get backfillStatusInboundQueue => 'La coda in entrata';

  @override
  String get backfillStatusMissing => 'Mancato';

  @override
  String get backfillStatusSkipped => 'Abilitato';

  @override
  String get backfillToggleDescription =>
      'Richieste di informazioni mancanti dalle ultime 24 ore.';

  @override
  String get backfillToggleTitle => 'Ricarica automatica';

  @override
  String get basicSettings => 'Impostazioni di base';

  @override
  String get calendarHasPlanLabel => 'Ha un piano';

  @override
  String get calendarTodayLabel => 'Oggi';

  @override
  String get cancelButton => 'Annullamento';

  @override
  String get categoryActiveDescription =>
      'Le categorie inattive non appaiono nelle liste di selezione';

  @override
  String get categoryActiveSwitchDescription => 'Selezionabile per nuove voci';

  @override
  String get categoryAiDefaultsDescription =>
      'Impostare il profilo AI predefinito e il modello di agente per le nuove attività in questa categoria';

  @override
  String get categoryAiDefaultsTitle => 'Predefinizioni dell\'IA';

  @override
  String get categoryCreationError =>
      'Non è riuscito a creare la categoria. Si prega di riprovare.';

  @override
  String get categoryDayPlanDescription =>
      'Rendere questa categoria disponibile per la selezione nel piano diurno';

  @override
  String get categoryDayPlanLabel => 'Pianificazione del giorno';

  @override
  String get categoryDefaultEventTemplateHint => 'Seleziona un modello';

  @override
  String get categoryDefaultEventTemplateLabel =>
      'Modello dell\'agente di eventi predefinito';

  @override
  String get categoryDefaultLanguageDescription =>
      'Impostare una lingua predefinita per le attività in questa categoria';

  @override
  String get categoryDefaultProfileHint => 'Seleziona un profilo';

  @override
  String get categoryDefaultTemplateHint => 'Seleziona un modello';

  @override
  String get categoryDefaultTemplateLabel => 'Modello di agente predefinito';

  @override
  String get categoryDeleteConfirm => 'SÌ, DELETE QUESTA CATEGORIA';

  @override
  String get categoryDeleteConfirmation =>
      'Questa azione non può essere annullata. Tutte le voci in questa categoria rimarranno ma non saranno più classificate.';

  @override
  String get categoryDeleteTitle => 'Elimina categoria?';

  @override
  String get categoryFavoriteBadgeLabel => 'Preferito';

  @override
  String get categoryFavoriteDescription =>
      'Segna questa categoria come preferito';

  @override
  String get categoryIconChooseHint => 'Seleziona un\'icona';

  @override
  String get categoryIconCreateHint => 'Seleziona un\'icona';

  @override
  String get categoryIconEditHint => 'Seleziona un\'icona diversa';

  @override
  String get categoryIconLabel => 'Icona';

  @override
  String get categoryIconPickerTitle => 'Scegli l\'icona';

  @override
  String get categoryNameRequired => 'Il nome della categoria è richiesto';

  @override
  String get categoryNotFound => 'Categoria non trovata';

  @override
  String get categoryPrivateBadgeLabel => 'Privato';

  @override
  String get categoryPrivateDescription =>
      'Solo visibile quando vengono mostrate le voci private';

  @override
  String get categorySearchPlaceholder => 'Cerca le categorie...';

  @override
  String get changeSetCardTitle => 'Modifiche proposte';

  @override
  String get changeSetConfirmAll => 'Confermare tutto';

  @override
  String changeSetConfirmAllPartialIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gli articoli di $count hanno problemi parziali',
      one: '1 elemento aveva problemi parziali',
    );
    return '$_temp0';
  }

  @override
  String get changeSetConfirmError => 'Non si applica il cambiamento';

  @override
  String get changeSetItemConfirmed => 'Variazione';

  @override
  String changeSetItemConfirmedWithWarning(String warning) {
    return 'Applicato con avviso: $warning';
  }

  @override
  String get changeSetItemRejected => 'Variazione';

  @override
  String changeSetPendingCount(int count) {
    return '$count in attesa';
  }

  @override
  String get changeSetSwipeConfirm => 'Conferma';

  @override
  String get changeSetSwipeReject => 'Rifiuti';

  @override
  String get chatInputCancelRealtime => 'Annullare (Esc)';

  @override
  String get chatInputCancelRecording => 'Annulla registrazione (Esc)';

  @override
  String get chatInputConfigureModel => 'Configurare il modello';

  @override
  String get chatInputHintDefault =>
      'Chiedete i vostri compiti e la vostra produttività...';

  @override
  String get chatInputHintSelectModel =>
      'Selezionare un modello per iniziare a chattare';

  @override
  String get chatInputListening => 'Ascoltare...';

  @override
  String get chatInputPleaseWait => 'Ti prego, aspetta...';

  @override
  String get chatInputProcessing => 'Elaborazione...';

  @override
  String get chatInputRecordVoice => 'Messaggio vocale registrato';

  @override
  String get chatInputSendTooltip => 'Invia messaggio';

  @override
  String get chatInputStartRealtime => 'Iniziare trascrizione live';

  @override
  String get chatInputStopRealtime => 'Stop trascrizione live';

  @override
  String get chatInputStopTranscribe => 'Fermati e trascrivi';

  @override
  String get checklistAddItem => 'Aggiungi un nuovo articolo';

  @override
  String checklistAiConfidenceLabel(String level) {
    return 'Confidenza: $level';
  }

  @override
  String get checklistAiMarkComplete => 'Segna come completato';

  @override
  String get checklistAiSuggestionBody =>
      'Questo articolo sembra essere completato:';

  @override
  String get checklistAiSuggestionTitle => 'AI Suggerimento';

  @override
  String get checklistAllDone => 'Tutti gli articoli completati!';

  @override
  String get checklistCollapseTooltip => 'Colpisco';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total fatto';
  }

  @override
  String get checklistDelete => 'Eliminare la lista di controllo?';

  @override
  String get checklistExpandTooltip => 'Espulsione';

  @override
  String get checklistExportAsMarkdown =>
      'Elenco di controllo dell\'esportazione come Markdown';

  @override
  String get checklistExportFailed => 'Esportazione fallita';

  @override
  String get checklistItemArchived => 'Articolo archiviato';

  @override
  String get checklistItemArchiveUndo => 'Annulla';

  @override
  String get checklistItemDeleteCancel => 'Annullamento';

  @override
  String get checklistItemDeleteConfirm => 'Conferma';

  @override
  String get checklistItemDeleted => 'Articolo cancellato';

  @override
  String get checklistItemDeleteWarning =>
      'Questa azione non può essere annullata.';

  @override
  String get checklistMarkdownCopied =>
      'Elenco di controllo copiato come Markdown';

  @override
  String get checklistMoreTooltip => 'Altro';

  @override
  String get checklistNoneDone => 'Non ho ancora completato gli articoli.';

  @override
  String get checklistNothingToExport => 'Nessun articolo da esportare';

  @override
  String get checklistProgressSemantics => 'Progressi della lista di controllo';

  @override
  String get checklistShare => 'Condividi';

  @override
  String get checklistShareHint => 'Stampa lunga da condividere';

  @override
  String get checklistsReorder => 'Riordina';

  @override
  String get clearButton => 'Cancellazione';

  @override
  String get colorCustomLabel => 'Personale';

  @override
  String get colorLabel => 'Colore';

  @override
  String get commandPaletteNoResults =>
      'Nessun comando disponibile corrisponde alla tua ricerca';

  @override
  String get commandPaletteSearchHint => 'Comandi di ricerca...';

  @override
  String get commandPaletteTitle => 'tavolozza dei comandi';

  @override
  String get commonError => 'Errore';

  @override
  String get commonLoading => 'Caricamento...';

  @override
  String get commonUnknown => 'Sconosciuto';

  @override
  String get completeHabitFailButton => 'Mancato';

  @override
  String get completeHabitSkipButton => 'Salta!';

  @override
  String get completeHabitSuccessButton => 'Successo';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Quando abilitata, l\'applicazione cercherà di generare embeddings per le vostre voci per migliorare la ricerca e i relativi suggerimenti di contenuti.';

  @override
  String get configFlagDailyOsOnboardingEnabled =>
      'Passaggio giornaliero del sistema operativo';

  @override
  String get configFlagDailyOsOnboardingEnabledDescription =>
      'Guidare gli utenti del sistema operativo giornaliero di prima volta attraverso un check-in reale che trasforma il discorso in un compito e un piano di giorno.';

  @override
  String get configFlagEnableAiStreaming =>
      'Attiva lo streaming AI per le azioni di attività';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Risposte dell\'intelligenza artificiale per le azioni correlate al compito. Spegnere le risposte del buffer e mantenere l\'interfaccia utente più fluida.';

  @override
  String get configFlagEnableAiSummaryTts => 'Riproduzione di sintesi AI';

  @override
  String get configFlagEnableAiSummaryTtsDescription =>
      'Mostra il pulsante di testo-to-speech locale sui riassunti dell\'intelligenza artificiale del compito. Richiede un modello MLX Audio TTS installato.';

  @override
  String get configFlagEnableDashboardsPage => 'Attivare la pagina Dashboards';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Mostra la pagina Dashboards nella navigazione principale. Visualizza i tuoi dati e approfondimenti in dashboard personalizzabili.';

  @override
  String get configFlagEnableEmbeddings => 'Generare Embeddings';

  @override
  String get configFlagEnableEvents => 'Abilita eventi';

  @override
  String get configFlagEnableEventsDescription =>
      'Mostra la funzione Eventi per creare, tracciare e gestire eventi nel tuo diario.';

  @override
  String get configFlagEnableForkHealing => 'Guarigione dell\'agente Fork';

  @override
  String get configFlagEnableForkHealingDescription =>
      'Storie di agenti divergenti Heal da uso multi-dispositivo fondendoli alla prossima veglia.';

  @override
  String get configFlagEnableHabitsPage => 'Attivare la pagina Habits';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Mostra la pagina Habits nella navigazione principale. Traccia e gestisci le tue abitudini quotidiane qui.';

  @override
  String get configFlagEnableLogging => 'Abilita la registrazione';

  @override
  String get configFlagEnableLoggingDescription =>
      'Abilitare logging dettagliato per scopi di debug. Questo può avere un impatto sulle prestazioni.';

  @override
  String get configFlagEnableMatrix => 'Attiva la sincronizzazione Matrix';

  @override
  String get configFlagEnableMatrixDescription =>
      'Abilitare l\'integrazione Matrix per sincronizzare le voci tra i dispositivi e con altri utenti Matrix.';

  @override
  String get configFlagEnableNotifications => 'Attivare le notifiche?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Ricevi notifiche per promemoria, aggiornamenti e eventi importanti.';

  @override
  String get configFlagEnableProjects => 'Attivare i progetti';

  @override
  String get configFlagEnableProjectsDescription =>
      'Mostra le caratteristiche di gestione del progetto per l\'organizzazione dei compiti in progetti.';

  @override
  String get configFlagEnableSessionRatings =>
      'Attiva le valutazioni delle sessioni';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Prompt per una rapida valutazione di sessione quando si ferma un timer.';

  @override
  String get configFlagEnableTooltip => 'Abilitare i tooltip';

  @override
  String get configFlagEnableTooltipDescription =>
      'Mostra utili tooltips in tutta l\'app per guidarti attraverso le funzionalità.';

  @override
  String get configFlagEnableVectorSearch => 'Ricerca vettoriale';

  @override
  String get configFlagEnableVectorSearchDescription =>
      'Abilitare la ricerca vettoriale nei filtri di attività. Richiede embeddings da abilitare e Ollama in esecuzione.';

  @override
  String get configFlagEnableWhatsNew => 'Mostra cosa è nuovo';

  @override
  String get configFlagEnableWhatsNewDescription =>
      'Evidenzia nuove funzionalità e modifiche all\'interno dell\'albero Impostazioni.';

  @override
  String get configFlagPrivate => 'Mostrare voci private?';

  @override
  String get configFlagPrivateDescription =>
      'Abilitare questo per rendere le vostre voci private per impostazione predefinita. Le voci private sono visibili solo a voi.';

  @override
  String get configFlagRecordLocation => 'Luogo di registrazione';

  @override
  String get configFlagRecordLocationDescription =>
      'Registra automaticamente la tua posizione con nuove voci. Questo aiuta con l\'organizzazione basata sulla posizione e la ricerca.';

  @override
  String get configFlagResendAttachments => 'Rispondere agli allegati';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Abilita questo per rivendere automaticamente gli upload di allegati falliti quando la connessione viene ripristinata.';

  @override
  String get configFlagShowSyncActivityIndicator =>
      'Mostra l\'indicatore di attività di sincronizzazione';

  @override
  String get configFlagShowSyncActivityIndicatorDescription =>
      'Mostra uno stato di sincronizzazione tranquillo nella barra laterale; i conti della coda appaiono solo mentre il lavoro è in attesa.';

  @override
  String get conflictApplyButton => 'Applicare';

  @override
  String get conflictApplyFailedTitle =>
      'Non è possibile applicare la risoluzione';

  @override
  String conflictBannerAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni fa',
      one: '1 giorno fa',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h fa',
      one: '1 h fa',
    );
    return '$_temp0';
  }

  @override
  String get conflictBannerAgoJustNow => 'solo ora';

  @override
  String conflictBannerAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min fa',
      one: '1 minuto fa',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerDivergedAgo(String entity, String ago) {
    return '$entity · divergente $ago';
  }

  @override
  String conflictBannerFieldsDifferList(String fields) {
    return 'Differenza in: $fields';
  }

  @override
  String get conflictCombineApply => 'Applicare combinato';

  @override
  String get conflictCombineStartFrom => 'Iniziare da';

  @override
  String get conflictConfirmDeletion => 'Confermare la cancellazione';

  @override
  String get conflictDeleteVsEditDescription =>
      'Questa voce è stata modificata su un dispositivo e cancellato su un altro. Nulla viene rimosso fino a quando non si sceglie.';

  @override
  String get conflictDeleteVsEditTitle => 'Eliminato su un dispositivo';

  @override
  String get conflictDetailEntryNotFoundTitle => 'Entrata non trovata';

  @override
  String get conflictDetailLoadErrorTitle => 'Non poteva caricare i conflitti';

  @override
  String get conflictDetailNotFoundTitle => 'Conflitto non trovato';

  @override
  String get conflictDiffRecommended => 'Consigliato';

  @override
  String conflictDiffUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count campi invariati',
      one: '1 campo invariato',
    );
    return '$_temp0';
  }

  @override
  String get conflictFieldBody => 'Corpo';

  @override
  String get conflictFieldCategory => 'Categoria';

  @override
  String get conflictFieldDuration => 'Durata';

  @override
  String get conflictFieldEnd => 'Fine';

  @override
  String get conflictFieldFlag => 'Bandiera';

  @override
  String get conflictFieldOther => 'Altri dettagli';

  @override
  String get conflictFieldOtherDescription =>
      'Queste versioni differiscono nei dettagli non mostrati singolarmente qui.';

  @override
  String get conflictFieldPrivate => 'Privato';

  @override
  String get conflictFieldStarred => 'Stellato';

  @override
  String get conflictFieldStart => 'Iniziare';

  @override
  String get conflictFieldTitle => 'Titolo';

  @override
  String get conflictFieldWordCount => 'parola conteggio';

  @override
  String get conflictFlagFollowUp => 'Seguire necessario';

  @override
  String get conflictFlagImport => 'Importato';

  @override
  String get conflictFlagNone => 'Nessuno';

  @override
  String get conflictFooterHelperLocalSelected =>
      'Manterrà la modifica locale e scarterà la versione sincronizzata.';

  @override
  String get conflictFooterHelperPickASide => 'Scegli un lato da applicare.';

  @override
  String get conflictFooterHelperRemoteSelected =>
      'Accetterà la versione sincronizzata e scarterà la tua modifica locale.';

  @override
  String conflictHeaderPillEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voci',
      one: '1 ingresso',
    );
    return '$_temp0';
  }

  @override
  String conflictHeaderPillFieldsDiffer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'I campi di $count differiscono',
      one: '1 campo differisce',
    );
    return '$_temp0';
  }

  @override
  String get conflictKeepEdited => 'Mantenere la versione modificata';

  @override
  String conflictListItemSemanticsLabel(
    String status,
    String timestamp,
    String entityType,
    String id,
  ) {
    return '$status, $timestamp, $entityType, conflitto $id';
  }

  @override
  String conflictListItemTooltipFullId(String id) {
    return 'ID conflitto: $id';
  }

  @override
  String get conflictMetaLocalEdit => 'modifiche locali';

  @override
  String get conflictMetaVecPrefix => 'Vec.';

  @override
  String get conflictMetaViaSync => 'via sincronizzazione';

  @override
  String conflictNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Le voci $count sono state modificate su due dispositivi',
      one: '1 voce è stata modificata su due dispositivi',
    );
    return '$_temp0';
  }

  @override
  String get conflictNotificationTitle =>
      'Sync ha bisogno della tua recensione';

  @override
  String get conflictPageLeadDesktop =>
      'Fare clic su un lato per utilizzare quella versione, o aprire Modifica & unisciti per combinarli.';

  @override
  String get conflictPageLeadMobile =>
      'Differenze evidenziate in linea. Toccare un lato per utilizzare quella versione.';

  @override
  String get conflictPageTitle => 'Sincronizzazione del conflitto';

  @override
  String get conflictPickerCombine => 'Combina...';

  @override
  String get conflictPickerEditMerge => 'Edit & merge...';

  @override
  String get conflictPickerUseFromSync => 'Utilizzare dalla sincronizzazione';

  @override
  String get conflictPickerUseThisDevice => 'Utilizzare questo dispositivo';

  @override
  String get conflictResolvedToast => 'Conflitto risolto';

  @override
  String get conflictsEmptyDescription =>
      'Tutto è in sincronia in questo momento. Gli elementi recuperati rimangono disponibili nell\'altro filtro.';

  @override
  String get conflictsEmptyTitle => 'Nessun conflitto rilevato';

  @override
  String get conflictSideFromSync => 'DA SYNC';

  @override
  String get conflictSideThisDevice => 'PRESIDENZA DEL VICESSO';

  @override
  String get conflictsResolved => 'risolto';

  @override
  String get conflictsUnresolved => 'irrisolto';

  @override
  String get conflictValueAbsent => 'Non impostato';

  @override
  String get conflictValueNo => 'No.';

  @override
  String get conflictValueYes => 'Sì.';

  @override
  String conflictWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parole',
      one: '$count parola',
    );
    return '$_temp0';
  }

  @override
  String get copyAsMarkdown => 'Copia come Markdown';

  @override
  String get copyAsText => 'Copia come testo';

  @override
  String get correctionExampleCancel => 'CANCELLAZIONE';

  @override
  String correctionExamplePending(int seconds) {
    return 'Risparmio di correzione in ${seconds}s...';
  }

  @override
  String get correctionExamplesEmpty =>
      'Ancora nessuna correzione. Modificare un elemento della lista di controllo per aggiungere il tuo primo esempio.';

  @override
  String get correctionExamplesSectionDescription =>
      'Quando si corregge manualmente gli elementi della lista di controllo, queste correzioni vengono salvate qui e utilizzate per migliorare i suggerimenti AI.';

  @override
  String get correctionExamplesSectionTitle =>
      'Esempi di correzione della lista di controllo';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'Avete correzioni $count. Solo il più recente $max sarà utilizzato nei prompt AI. Considerate l\'eliminazione di esempi vecchi o ridondanti.';
  }

  @override
  String get coverArtChipActive => 'Copertura';

  @override
  String get coverArtChipSet => 'Copripiumini';

  @override
  String get coverArtGenerationComplete => 'Coprire l\'arte pronta!';

  @override
  String get coverArtGenerationDismissHint =>
      'È possibile chiudere questo — la generazione continua in background';

  @override
  String get createButton => 'Creare';

  @override
  String get createCategoryTitle => 'Creare una categoria';

  @override
  String get createEntryLabel => 'Creare una nuova voce';

  @override
  String get createEntryTitle => 'Aggiungi';

  @override
  String get createNewLinkedTask => 'Creare un nuovo compito collegato...';

  @override
  String get customColor => 'Colore personalizzato';

  @override
  String get dailyOsDayPlan => 'Piano giornaliero';

  @override
  String get dailyOsNextAgendaCapacityComfortable => 'Confortevole';

  @override
  String get dailyOsNextAgendaCapacityNearFull => 'Vicino a tutto';

  @override
  String get dailyOsNextAgendaCapacityNoPlan => 'Nessun piano ancora';

  @override
  String dailyOsNextAgendaCapacityOf(String capacity) {
    return 'di $capacity';
  }

  @override
  String get dailyOsNextAgendaCapacityOver => 'Capacità superiore';

  @override
  String get dailyOsNextAgendaDonutLeft => 'sinistra';

  @override
  String get dailyOsNextAgendaDonutOver => 'sopra.';

  @override
  String dailyOsNextAgendaHeadlineLeft(String duration) {
    return '$duration sinistra';
  }

  @override
  String dailyOsNextAgendaHeadlineOver(String duration) {
    return '$duration sopra';
  }

  @override
  String get dailyOsNextAgendaNoPlanBody =>
      'Il vostro tempo tracciato è qui in entrambi i casi — parlare un check-in e io abbozzerò un giorno intorno a esso.';

  @override
  String dailyOsNextAgendaNoPlanSummary(String duration) {
    return 'Ho rintracciato $duration, ho detto un check-in e ho preparato un giorno.';
  }

  @override
  String get dailyOsNextAgendaNoPlanTitle =>
      'Non c\'e\' ancora un piano per oggi.';

  @override
  String get dailyOsNextAgendaStateDone => 'Fatto';

  @override
  String get dailyOsNextAgendaStateInProgress => 'In corso';

  @override
  String get dailyOsNextAgendaStateOpen => 'Aprire';

  @override
  String get dailyOsNextAgendaStateOverdue => 'Suggerimento';

  @override
  String dailyOsNextAgendaSummary(String scheduled, String capacity) {
    return '$scheduled di $capacity impegnata';
  }

  @override
  String dailyOsNextAgendaTrackedLegend(String duration, int completedCount) {
    return 'Tracciato · $duration · $completedCount fatto';
  }

  @override
  String get dailyOsNextBlockEditCategoryLabel => 'Categoria';

  @override
  String get dailyOsNextBlockEditFailed =>
      'Non è stato possibile aggiornare il blocco — riprovare.';

  @override
  String get dailyOsNextBlockEditNameLabel => 'Titolo';

  @override
  String get dailyOsNextBlockEditOpenTask => 'Attività aperte';

  @override
  String get dailyOsNextBlockEditSave => 'Salvare le modifiche';

  @override
  String get dailyOsNextBlockEditSaved => 'Orari aggiornato.';

  @override
  String get dailyOsNextBlockEditTimeLabel => 'Inizio e fine';

  @override
  String get dailyOsNextBlockEditTitle => 'Modifica blocco';

  @override
  String get dailyOsNextBlockEditTooltip => 'Modifica blocco';

  @override
  String get dailyOsNextBlockEditWhyLabel => 'Perché questa volta';

  @override
  String get dailyOsNextBlockMoveTooltip => 'Blocco di spostamento';

  @override
  String get dailyOsNextBlockResizeEndTooltip => 'Regolare la fine';

  @override
  String get dailyOsNextBlockResizeStartTooltip => 'Regolare l\'inizio';

  @override
  String get dailyOsNextCaptureCaptured => 'Ricevuto.';

  @override
  String get dailyOsNextCaptureDoneCta => 'Fatto';

  @override
  String get dailyOsNextCaptureErrorMicrophonePermissionDenied =>
      'Il permesso del microfono è stato negato.';

  @override
  String get dailyOsNextCaptureErrorNoActiveRealtimeSession =>
      'Nessuna sessione in tempo reale attiva.';

  @override
  String get dailyOsNextCaptureErrorNoAudioRecorded =>
      'Nessun audio è stato registrato.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionFailed =>
      'La trascrizione in tempo reale è fallita.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionStartFailed =>
      'La trascrizione in tempo reale non può iniziare.';

  @override
  String get dailyOsNextCaptureErrorRecordingStartFailed =>
      'La registrazione non poteva iniziare.';

  @override
  String get dailyOsNextCaptureErrorTranscriptionFailed =>
      'La trascrizione e\' fallita.';

  @override
  String get dailyOsNextCaptureHeadlineCaptured => 'Ti sembra giusto?';

  @override
  String get dailyOsNextCaptureHeadlineLead => 'Cosa c’è nella tua mente';

  @override
  String get dailyOsNextCaptureHeadlineListening => 'Sto ascoltando.';

  @override
  String get dailyOsNextCaptureHeadlineTail => 'per oggi?';

  @override
  String dailyOsNextCaptureHeadlineTailForDate(String date) {
    return 'per $date?';
  }

  @override
  String get dailyOsNextCaptureHeadlineTailTomorrow => 'per domani?';

  @override
  String get dailyOsNextCaptureHeadlineTailYesterday => 'per ieri?';

  @override
  String get dailyOsNextCaptureHeadlineTranscribing => 'L\'ho scritto...';

  @override
  String get dailyOsNextCaptureIdleClick => 'Clicca per parlare';

  @override
  String get dailyOsNextCaptureIdleExample =>
      '“Deep work questa mattina, una passeggiata dopo pranzo, e-mail prima di cinque.”';

  @override
  String get dailyOsNextCaptureIdleHint =>
      'Toccare per parlare · digitare invece';

  @override
  String get dailyOsNextCaptureIdleTalk => 'Toccare per parlare';

  @override
  String get dailyOsNextCaptureListeningStatus => 'Ascoltare...';

  @override
  String dailyOsNextCapturePastPrompt(String date) {
    return 'C\'e\' qualcosa che vuoi ancora rintracciare da $date?';
  }

  @override
  String get dailyOsNextCaptureReconcileCta => 'Recensione';

  @override
  String get dailyOsNextCapturesPanelTitle => 'Catture';

  @override
  String get dailyOsNextCaptureTranscribing => 'Transcribing...';

  @override
  String get dailyOsNextCaptureTranscriptHint =>
      'Fissare qualsiasi cosa la trascrizione si sia sbagliata prima di pianificare.';

  @override
  String get dailyOsNextCaptureTranscriptLabel => 'Revisione trascrizione';

  @override
  String get dailyOsNextCaptureTypeInstead => 'Digitare invece';

  @override
  String get dailyOsNextCaptureVoiceButtonReset => 'Avvicinati';

  @override
  String get dailyOsNextCaptureVoiceButtonStart => 'Iniziare ad ascoltare';

  @override
  String get dailyOsNextCaptureVoiceButtonStop => 'Smettila di ascoltare.';

  @override
  String get dailyOsNextCategoryFilterAll => 'Tutte le categorie';

  @override
  String get dailyOsNextCategoryFilterDescription =>
      'Solo le categorie abilitate per la pianificazione del giorno sono in superficie per l\'elaborazione automatizzata del sistema operativo giornaliero.';

  @override
  String get dailyOsNextCategoryFilterEmpty =>
      'Nessuna categoria abilitata per la pianificazione del giorno ancora.';

  @override
  String get dailyOsNextCategoryFilterIncludeAll => 'Includi tutto';

  @override
  String get dailyOsNextCategoryFilterTitle => 'Categorie di lavorazione';

  @override
  String get dailyOsNextCategoryFilterTooltip =>
      'Scegliere le categorie di elaborazione del sistema operativo giornaliero';

  @override
  String dailyOsNextCommitCapacityNote(String scheduled, String capacity) {
    return '$scheduled di $capacity impegnato. Confortevole margine — è possibile assorbire una sorpresa.';
  }

  @override
  String get dailyOsNextCommitDraftOverline => 'Il tuo giorno, rovinato.';

  @override
  String get dailyOsNextCommitExplainer =>
      'Firma per muoversi oggi da bozza a commesso.';

  @override
  String get dailyOsNextCommitFinalStepEyebrow => 'SETTORE FINALE';

  @override
  String get dailyOsNextCommitHeadline => 'Fallo tuo.';

  @override
  String get dailyOsNextCommitHoldHelper =>
      'Tenere un secondo per firmare fuori';

  @override
  String get dailyOsNextCommitHoldWordDone => 'Impegno';

  @override
  String get dailyOsNextCommitHoldWordHolding => 'Continua a tenere premuto';

  @override
  String get dailyOsNextCommitHoldWordIdle => 'Aspetta.';

  @override
  String get dailyOsNextCommitLockingIn => 'Chiudere in...';

  @override
  String get dailyOsNextCommitShepherdSubline =>
      'Io lo pastorerò — tu fai il lavoro.';

  @override
  String get dailyOsNextCommitSubCaption =>
      'Si può ancora parlare con me in seguito — ma le ossa rimangono messe.';

  @override
  String get dailyOsNextCommitTitle => 'Bloccatelo dentro.';

  @override
  String get dailyOsNextCommitTodayIsYours => 'Oggi è tuo.';

  @override
  String get dailyOsNextDayBack => 'Indietro';

  @override
  String get dailyOsNextDayCheckInCta => 'Parlare un check-in';

  @override
  String get dailyOsNextDayDeleteDialogBody =>
      'I blocchi elaborati per questo giorno saranno rimossi. Capture e le loro registrazioni audio rimangono nel tuo diario.';

  @override
  String get dailyOsNextDayDeleteDialogCancel => 'Annullamento';

  @override
  String get dailyOsNextDayDeleteDialogConfirm => 'Cancella';

  @override
  String get dailyOsNextDayDeleteDialogTitle => 'Eliminare questo piano?';

  @override
  String get dailyOsNextDayLockInCta => 'Bloccare';

  @override
  String get dailyOsNextDayMenuDeletePlan => 'Eliminare il piano';

  @override
  String get dailyOsNextDayMenuInspectAgent => 'Agente di ispezione';

  @override
  String get dailyOsNextDayMenuSettings =>
      'Impostazioni del sistema operativo quotidiane';

  @override
  String get dailyOsNextDayMoreTooltip => 'Altro';

  @override
  String get dailyOsNextDayRefineCta => 'Raffinare';

  @override
  String get dailyOsNextDayRefineFooterHint =>
      'Parlare per rimodellare il piano - vedrete ogni cambiamento prima che tutto venga salvato.';

  @override
  String get dailyOsNextDayTitle => 'La tua giornata';

  @override
  String get dailyOsNextDayWhyChipLabel => 'Perche\'?';

  @override
  String get dailyOsNextDayWrapUpCta => '# Wrap up #';

  @override
  String get dailyOsNextDraftingBackToDecisions => 'Ritorno alle decisioni';

  @override
  String get dailyOsNextDraftingHeader => 'Ti stai preparando la giornata...';

  @override
  String get dailyOsNextDraftingNudgeAccept => 'Sì, proteggi le mattine';

  @override
  String get dailyOsNextDraftingNudgeDecline => 'Non oggi.';

  @override
  String get dailyOsNextDraftingProgressBlocks => 'Blocchi di bozza';

  @override
  String get dailyOsNextDraftingProgressMatching =>
      'Competenze di corrispondenza';

  @override
  String get dailyOsNextDraftingProgressQueued => 'In coda';

  @override
  String get dailyOsNextDraftingProgressReading => 'Check-in lettura';

  @override
  String get dailyOsNextDraftingProgressSaving => 'Piano di risparmio';

  @override
  String get dailyOsNextDraftingProgressValidating => 'Validazione';

  @override
  String get dailyOsNextDraftingReasoningOverline => 'MOTIVAZIONE';

  @override
  String get dailyOsNextDraftingRecoveryBody =>
      'La scia non ha prodotto un piano, riprovare, o tornare indietro e regolare le decisioni prima di redigere.';

  @override
  String get dailyOsNextDraftingRecoveryTitle => 'La bozza è bloccata';

  @override
  String get dailyOsNextDraftingRetry => 'Prova di nuovo';

  @override
  String get dailyOsNextDraftingStatusAfternoon =>
      'Sequenziamento del pomeriggio...';

  @override
  String get dailyOsNextDraftingStatusAlmost => 'Ci siamo quasi...';

  @override
  String get dailyOsNextDraftingStatusBreathing =>
      'Lasciare spazio per respirare...';

  @override
  String get dailyOsNextDraftingStatusDeepWork =>
      'Prima di tutto, il lavoro profondo...';

  @override
  String get dailyOsNextDraftingStatusMatching =>
      'Compagni per la tua giornata...';

  @override
  String get dailyOsNextDraftingStatusReading => 'Leggendo il tuo check-in...';

  @override
  String get dailyOsNextDraftingStatusTimings => 'Tempi di ricontrollamento...';

  @override
  String get dailyOsNextDraftingStatusYesterday =>
      'Guardando il ritmo di ieri...';

  @override
  String get dailyOsNextEditTitleHint => 'Modifica del titolo';

  @override
  String get dailyOsNextGenericError =>
      'C\'e\' qualcosa che non va, riprova tra un attimo.';

  @override
  String get dailyOsNextGreetingAfternoon => 'Buon pomeriggio.';

  @override
  String get dailyOsNextGreetingEvening => 'Buonasera.';

  @override
  String dailyOsNextGreetingHiName(String name) {
    return 'Ciao $name';
  }

  @override
  String get dailyOsNextGreetingMorning => 'Buongiorno.';

  @override
  String get dailyOsNextKnowledgeConfirm => 'Conferma';

  @override
  String get dailyOsNextKnowledgeConfirmedHeader => 'Confermato';

  @override
  String get dailyOsNextKnowledgeEdit => 'Modifica';

  @override
  String get dailyOsNextKnowledgeEditCancel => 'Annullamento';

  @override
  String get dailyOsNextKnowledgeEditHookHint => 'Riepilogo di una linea';

  @override
  String get dailyOsNextKnowledgeEditSave => 'Salva';

  @override
  String get dailyOsNextKnowledgeEditStatementHint => 'Cosa dovrei ricordare?';

  @override
  String get dailyOsNextKnowledgeEmpty =>
      'Ancora niente. Mi ricordero\' cosa mi dirai.';

  @override
  String dailyOsNextKnowledgeNudge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cose che ho notato — recensione',
      one: '1 cosa ho notato — recensione',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextKnowledgeProposedHeader => 'Risvegliare la conferma';

  @override
  String get dailyOsNextKnowledgeRetract => 'Dimenticati.';

  @override
  String get dailyOsNextKnowledgeStale => 'E\' ancora vero?';

  @override
  String get dailyOsNextKnowledgeTitle => 'Quello che ho imparato';

  @override
  String get dailyOsNextParsedCardBreakLinkTooltip => 'Collegamento di rottura';

  @override
  String get dailyOsNextPlanViewAgenda => 'Ordine del giorno';

  @override
  String get dailyOsNextPlanViewDay => 'Giorno';

  @override
  String get dailyOsNextReconcileBadgeMatched => 'MATCHED:';

  @override
  String get dailyOsNextReconcileBadgeNew => 'NUOVO';

  @override
  String get dailyOsNextReconcileBadgeUpdate => 'AGGIORNAMENTO';

  @override
  String get dailyOsNextReconcileBuildDayCta => 'Costruisci la mia giornata';

  @override
  String get dailyOsNextReconcileDecideOverline => 'DORTH DECIDING ON';

  @override
  String dailyOsNextReconcileDecisionProgress(int decided, int total) {
    return '$decided di $total recensito';
  }

  @override
  String get dailyOsNextReconcileDefaultBehaviorHint =>
      'Rivedere le carte prima di costruire il vostro giorno. Le azioni scelte si nutrono del piano; le carte lasciate da sole rimangono come sono.';

  @override
  String dailyOsNextReconcileError(String detail) {
    return 'Qualcosa è andato storto: $detail';
  }

  @override
  String get dailyOsNextReconcileHeadline => 'Ecco quello che ho sentito.';

  @override
  String get dailyOsNextReconcileHeardEmpty =>
      'Carte di cattura apparirà qui una volta che la parsing finisce.';

  @override
  String get dailyOsNextReconcileHeardOverline => 'CAPITOLO';

  @override
  String get dailyOsNextReconcileLowConfidence => 'bassa fiducia';

  @override
  String get dailyOsNextReconcileProcessing =>
      'Ascoltare e abbinare la tua giornata...';

  @override
  String get dailyOsNextReconcileReRecord => 'Registri';

  @override
  String get dailyOsNextReconcileVoiceHint =>
      'Decisioni di revisione prima di costruire il vostro giorno';

  @override
  String get dailyOsNextRefineAccept => 'Accettare';

  @override
  String get dailyOsNextRefineCurrentPlan => 'PIANO DI CURRE';

  @override
  String get dailyOsNextRefineDiffAdded => 'ADDETTI';

  @override
  String get dailyOsNextRefineDiffDropped => 'RIMOSSO';

  @override
  String get dailyOsNextRefineDiffMoved => 'MOVIMENTO';

  @override
  String get dailyOsNextRefineHeadlineDiffReady => 'Ecco cosa cambierei.';

  @override
  String get dailyOsNextRefineHeadlineIdle => 'Cosa dovrebbe cambiare?';

  @override
  String get dailyOsNextRefineHeadlineThinking =>
      'Rielaborazione del tuo piano...';

  @override
  String get dailyOsNextRefineKeepTalking => 'Continua a parlare';

  @override
  String get dailyOsNextRefineLooksGood => 'Sembra buono.';

  @override
  String get dailyOsNextRefineNoChanges =>
      'Nessun cambiamento di piano è tornato. Riparli e riprova.';

  @override
  String get dailyOsNextRefineOverline => ' ⁇  RIFERIMENTO';

  @override
  String get dailyOsNextRefineRevert => 'Torna indietro';

  @override
  String get dailyOsNextRefineStatusAccepted => 'Chiuso.';

  @override
  String get dailyOsNextRefineStatusDiffReady => 'Ecco cosa è cambiato.';

  @override
  String get dailyOsNextRefineStatusIdle => 'Toccare per parlare.';

  @override
  String get dailyOsNextRefineStatusListening => 'Ascoltare...';

  @override
  String get dailyOsNextRefineStatusThinking => 'Rielaborazione del piano...';

  @override
  String get dailyOsNextRefineTitle => 'Definire il piano';

  @override
  String get dailyOsNextRenameFailed => 'Non poteva rinominare — riprovare.';

  @override
  String get dailyOsNextReviewAddBuffer => 'Aggiungere buffer';

  @override
  String get dailyOsNextReviewAddBufferPrompt =>
      'Aggiungere un buffer realistico tra i blocchi previsti, soprattutto intorno alle transizioni e dopo il lavoro impegnativo.';

  @override
  String get dailyOsNextReviewAdjust => 'Regolare';

  @override
  String get dailyOsNextReviewLooksGood => 'Sembra buono.';

  @override
  String get dailyOsNextReviewMoveLighter => 'Spostare l\'accendino';

  @override
  String get dailyOsNextReviewMoveLighterPrompt =>
      'Spostare il lavoro più leggero o più basso-energia in seguito, e mantenere la finestra di messa a fuoco più forte per il compito più esigente.';

  @override
  String get dailyOsNextReviewTooMuch => 'Troppo spesso.';

  @override
  String get dailyOsNextReviewTooMuchPrompt =>
      'Questo piano è troppo per oggi. Ridurre il carico, proteggere la sala respirazione, e mantenere solo i blocchi più importanti.';

  @override
  String get dailyOsNextReviewWhyTitle => 'Perché questi hanno fatto in modo';

  @override
  String get dailyOsNextShutdownCarryoverDrop => 'Goccia';

  @override
  String get dailyOsNextShutdownCarryoverDropped => 'Gocciato';

  @override
  String get dailyOsNextShutdownCarryoverOverline => 'CARRIE FORWARD';

  @override
  String get dailyOsNextShutdownCarryoverPickDate => 'Scegli un appuntamento';

  @override
  String get dailyOsNextShutdownCarryoverScheduled => 'Programmato';

  @override
  String get dailyOsNextShutdownCloseDay => 'Chiudere il giorno';

  @override
  String get dailyOsNextShutdownCompletedOverline => 'Quello che hai fatto';

  @override
  String get dailyOsNextShutdownMetricEnergy => 'ENERGIA';

  @override
  String dailyOsNextShutdownMetricEnergyDelta(String delta) {
    return '$delta vs. settimana';
  }

  @override
  String get dailyOsNextShutdownMetricFlow => 'SESSIONI FLOW';

  @override
  String get dailyOsNextShutdownMetricFocus => 'TEMPO DEL FOCUS';

  @override
  String get dailyOsNextShutdownMetricSwitches => 'SVILUPPO CONTESTO';

  @override
  String dailyOsNextShutdownMetricSwitchesAvg(String avg) {
    return 'avg $avg questa settimana';
  }

  @override
  String get dailyOsNextShutdownReflectionOverline =>
      ' ⁇  RISFLETTO DI UNA LINEA';

  @override
  String get dailyOsNextShutdownReflectionPlaceholder =>
      'ad esempio, la mattina era affilata, il pomeriggio trascinato dopo il caffè con Sarah ha corso a lungo.';

  @override
  String get dailyOsNextShutdownReflectionPrompt =>
      'Come è atterrato oggi? (Questo nutre il progetto di domani.)';

  @override
  String get dailyOsNextShutdownReflectionSpeak => 'Parla.';

  @override
  String get dailyOsNextShutdownReflectionSubmit => 'Salta!';

  @override
  String get dailyOsNextShutdownReflectionThanks =>
      'Ce l\'ho, domani ci si nutre.';

  @override
  String get dailyOsNextShutdownSaveAndClose => 'Salva e chiudi';

  @override
  String get dailyOsNextShutdownTitle => 'Chiudere il giorno';

  @override
  String get dailyOsNextShutdownTomorrowOverline =>
      'allevamento per il TOMORROW';

  @override
  String dailyOsNextStateDueOnDate(String date) {
    return 'Scadenza: $date';
  }

  @override
  String get dailyOsNextStateDueToday => 'Scadenza oggi';

  @override
  String dailyOsNextStateInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In corso · $count sessioni',
      one: 'In corso · 1 sessione',
      zero: 'In corso',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Scaduto · $days giorni',
      one: 'Scaduto · 1 giorno',
      zero: 'Scaduto',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdueOnDate(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Scaduto da $days giorni il $date',
      one: 'Scaduto da 1 giorno il $date',
      zero: 'Scaduto il $date',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextStateRecurringMissed => 'Ripresa · mancato';

  @override
  String get dailyOsNextTimelineActual => 'Attualità';

  @override
  String get dailyOsNextTimelineArrange => 'Blocchi d\'arrangiamento';

  @override
  String get dailyOsNextTimelineBoth => 'Piano e reale';

  @override
  String get dailyOsNextTimelineMeridiemAm => 'AMORE';

  @override
  String get dailyOsNextTimelineMeridiemAmShort => 'Sono io.';

  @override
  String get dailyOsNextTimelineMeridiemPm => 'Pomeriggio';

  @override
  String get dailyOsNextTimelineMeridiemPmShort => '14:00';

  @override
  String get dailyOsNextTimelinePlanned => 'Piano';

  @override
  String dailyOsNextTimelineSessionOf(int index, int total) {
    return 'Sessione $index di $total';
  }

  @override
  String get dailyOsNextTimelineShowBoth => 'Mostra piano e reale insieme';

  @override
  String get dailyOsNextTimelineShowPaged => 'Mostra piano e vero e proprio';

  @override
  String get dailyOsNextTimelineSwipeHint =>
      'Swipe per reale · pizzicare verticalmente per ingrandire';

  @override
  String get dailyOsNextTimelineTracked => 'tracciato';

  @override
  String dailyOsNextTimeSpentEarlierSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessioni precedenti',
      one: '1 sessione precedente',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextTimeSpentShowLess => 'Mostra di meno';

  @override
  String dailyOsNextTimeSpentSummary(String duration, int completedCount) {
    return '$duration · $completedCount fatto';
  }

  @override
  String get dailyOsNextTimeSpentTitle => 'Oggi è così triste';

  @override
  String get dailyOsNextTimeSpentTitlePast => 'TIME SPENTO';

  @override
  String get dailyOsNextTriageConfirmDefer => 'Deferito';

  @override
  String get dailyOsNextTriageConfirmDone => 'Marcato fatto';

  @override
  String get dailyOsNextTriageConfirmDoNow => 'Fatto ora';

  @override
  String get dailyOsNextTriageConfirmDrop => 'Gocciato';

  @override
  String get dailyOsNextTriageConfirmToday => 'Aggiunto a oggi';

  @override
  String get dailyOsNextTriageDefer => 'Denominazione';

  @override
  String get dailyOsNextTriageDone => 'Fatto';

  @override
  String get dailyOsNextTriageDoNow => 'Adesso.';

  @override
  String get dailyOsNextTriageDrop => 'Goccia';

  @override
  String get dailyOsNextTriageToday => 'Oggi';

  @override
  String get dailyOsOnboardingCoachCapture =>
      'Di\' cosa sta attirando la tua attenzione.';

  @override
  String get dailyOsOnboardingCoachDrafting =>
      'Il pianificatore sta creando nuovi compiti e adattando il lavoro alla tua giornata.';

  @override
  String get dailyOsOnboardingCoachReconcile =>
      'Scegli ciò che appartiene a oggi. Nuovi oggetti diventano compiti quando si costruisce il giorno.';

  @override
  String get dailyOsOnboardingSpotlightAction => 'Provalo.';

  @override
  String get dailyOsOnboardingSpotlightDismiss => 'Non ora.';

  @override
  String get dailyOsOnboardingSpotlightMessage =>
      'Toccate qui e dite che cosa c\'è nella vostra mente — lo trasformerò in un compito e costruirò il vostro giorno intorno a esso.';

  @override
  String get dailyOsOnboardingSpotlightTitle =>
      'Trasformare la conversazione in un piano';

  @override
  String get dailyOsSettingsChooseModelDescription =>
      'Override solo il modello di pensiero del pianificatore.';

  @override
  String get dailyOsSettingsChooseModelTitle => 'Scegli il modello override';

  @override
  String get dailyOsSettingsChooseProfileDescription =>
      'Override il profilo di inferenza completo per questo pianificatore.';

  @override
  String get dailyOsSettingsChooseProfileTitle =>
      'Scegli il profilo del sistema operativo giornaliero';

  @override
  String get dailyOsSettingsDataDisclosure =>
      'Daily OS invia compiti rilevanti, cattura, piani, preferenze apprese e altri contesti di pianificazione assemblati al fornitore selezionato per l\'elaborazione.';

  @override
  String get dailyOsSettingsDefaultProfileDescription =>
      'Usato da Daily OS a meno che l\'istanza planner non abbia un override.';

  @override
  String get dailyOsSettingsDefaultProfileMissing => 'Scegli un profilo';

  @override
  String get dailyOsSettingsDefaultRestored =>
      'Predefinizione giornaliera del sistema operativo ripristinata';

  @override
  String get dailyOsSettingsDirectOverrideActive =>
      'Il override del modello diretto è attivo.';

  @override
  String get dailyOsSettingsInferenceTitle =>
      'Profilo di inferenza predefinito';

  @override
  String get dailyOsSettingsInstanceCurrentSetup =>
      'Configurazione attuale del planner';

  @override
  String get dailyOsSettingsInstanceOverrideDescription =>
      'Utilizzare il profilo predefinito Daily OS, scegliere un override del profilo, o ignorare solo il modello di pensiero di questo pianificatore.';

  @override
  String get dailyOsSettingsInstanceOverrideTitle =>
      'Inferenza giornaliera del sistema operativo';

  @override
  String get dailyOsSettingsLocalDisclosure =>
      'Il punto finale selezionato è su questo dispositivo.';

  @override
  String dailyOsSettingsModelChanged(String model) {
    return 'Daily OS ora utilizza $model';
  }

  @override
  String get dailyOsSettingsNameNudgeAction => 'Aggiungi il nome';

  @override
  String get dailyOsSettingsNameNudgeBody =>
      'L\'aggiunta di un nome preferito rende i check-in più personali. È possibile continuare a pianificare senza di esso.';

  @override
  String get dailyOsSettingsNameNudgeTitle =>
      'Come dovrebbe il sistema operativo giornaliero indirizzarti?';

  @override
  String dailyOsSettingsProfileChanged(String profile) {
    return 'Daily OS ora utilizza $profile';
  }

  @override
  String get dailyOsSettingsProfileOverrideActive => 'Profilo override attivo';

  @override
  String dailyOsSettingsRemoteDisclosure(String provider, String host) {
    return 'Daily OS invia il contesto di pianificazione assemblato a $provider a $host per l\'elaborazione remota.';
  }

  @override
  String get dailyOsSettingsSetupAction =>
      'Impostare il sistema operativo giornaliero';

  @override
  String get dailyOsSettingsSetupRequiredBody =>
      'Il sistema operativo giornaliero ha bisogno della vostra scelta del fornitore prima che possa elaborare il vostro contesto di pianificazione.';

  @override
  String get dailyOsSettingsSetupRequiredTitle =>
      'Scegli un profilo di inferenza';

  @override
  String get dailyOsSettingsSubtitle =>
      'Scegli come il sistema operativo giornaliero ti indirizza e quale profilo di inferenza pianifica i tuoi giorni.';

  @override
  String get dailyOsSettingsTitle => 'Sistema operativo giornaliero';

  @override
  String get dailyOsSettingsTreeSubtitle =>
      'Progettazione, personalizzazione e fornitore di AI';

  @override
  String get dailyOsSettingsUseDefault =>
      'Utilizzare l\'impostazione giornaliera del sistema operativo';

  @override
  String get dailyOsSettingsUseDefaultDescription =>
      'Segui il profilo selezionato nelle impostazioni del sistema operativo giornaliero.';

  @override
  String get dailyOsTodayButton => 'Oggi';

  @override
  String get dashboardActiveLabel => 'Attivo';

  @override
  String get dashboardActiveSwitchDescription =>
      'Visualizzato nella lista dei cruscotti';

  @override
  String get dashboardAddChartsTitle => 'Carte';

  @override
  String get dashboardAddHabitButton => 'Abitazioni';

  @override
  String get dashboardAddHabitTitle => 'Grafico dell\'abitudine';

  @override
  String get dashboardAddHealthButton => 'Salute';

  @override
  String get dashboardAddHealthTitle => 'Carte di salute';

  @override
  String get dashboardAddMeasurementButton => 'Misure';

  @override
  String get dashboardAddMeasurementTitle => 'Aggiungere grafici di misura';

  @override
  String get dashboardAddMeasurementTooltip => 'Aggiungere la misura';

  @override
  String get dashboardAddSurveyButton => 'Indagini';

  @override
  String get dashboardAddSurveyTitle => 'Grafico dell\'indagine';

  @override
  String get dashboardAddWorkoutButton => 'Esercizi';

  @override
  String get dashboardAddWorkoutTitle => 'Carte di allenamento';

  @override
  String get dashboardAggregationApplyImmediately =>
      'Scegli un riassunto. Le modifiche si applicano immediatamente.';

  @override
  String get dashboardAggregationDailyAverage => 'Media giornaliera';

  @override
  String get dashboardAggregationDailyMax => 'Quotidiano max';

  @override
  String get dashboardAggregationDailyTotal => 'Totale giornaliero';

  @override
  String get dashboardAggregationHourlyTotal => 'Totale orario';

  @override
  String get dashboardAggregationLabel => 'Tipo di aggregazione:';

  @override
  String get dashboardAggregationTitle => 'Tipo di aggregazione';

  @override
  String get dashboardAvailableChartsDescription =>
      'Scegliere un tipo, selezionare uno o più grafici, quindi aggiungerli.';

  @override
  String get dashboardAvailableChartsTitle => 'Aggiungi grafici per tipo';

  @override
  String get dashboardCategoryLabel => 'Categoria';

  @override
  String get dashboardChartNoData => 'Nessun dato in questo intervallo';

  @override
  String get dashboardConfigurationDescription =>
      'Salvare il cruscotto, quindi copiare la configurazione JSON.';

  @override
  String get dashboardConfigurationTitle => 'Configurazione dell\'esportazione';

  @override
  String get dashboardCopyHint => 'Salva e copia configurazione del cruscotto';

  @override
  String get dashboardCopyLabel => 'Salvare e copiare JSON';

  @override
  String get dashboardCurrentChartsDescription =>
      'I grafici di misura possono essere selezionati per modificare la loro aggregazione.';

  @override
  String get dashboardCurrentChartsTitle => 'Carte su questo cruscotto';

  @override
  String get dashboardDeleteConfirm => 'SÌ, DELETE QUESTO DASHBOARD';

  @override
  String get dashboardDeleteHint => 'Cancella cruscotto';

  @override
  String get dashboardDeleteQuestion => 'Vuoi eliminare questo cruscotto?';

  @override
  String get dashboardDescriptionLabel => 'Descrizione (opzionale)';

  @override
  String get dashboardEditAggregationLabel => 'Modifica aggregazione';

  @override
  String get dashboardHealthBloodPressure => 'Pressione sanguigna';

  @override
  String get dashboardHealthDiastolic => 'Diastosi';

  @override
  String get dashboardHealthSystolic => 'Sistolica';

  @override
  String dashboardMeasurementAddButtonWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aggiungi $count grafici',
      one: 'Aggiungi 1 grafico',
    );
    return '$_temp0';
  }

  @override
  String dashboardMeasurementAggregationFor(String name) {
    return 'Modalità grafico per $name';
  }

  @override
  String get dashboardMeasurementAggregationHelp =>
      'Selezionare i grafici di misura. Regolare la modalità grafico sulle righe selezionate prima di aggiungere.';

  @override
  String get dashboardNameLabel => 'Nome di Dashboard';

  @override
  String get dashboardNoChartsAdded =>
      'Non sono ancora stati aggiunti grafici. Aggiungere uno qui sotto.';

  @override
  String get dashboardNoHabitsForCharts =>
      'Creare un\'abitudine prima di aggiungere grafici di abitudine.';

  @override
  String get dashboardNoMeasurablesForCharts =>
      'Creare un primo misurabile per aggiungere grafici di misura.';

  @override
  String get dashboardNotFound => 'Dashboard non trovato';

  @override
  String get dashboardPrivateLabel => 'Privato';

  @override
  String get dashboardRemoveChartLabel => 'Rimuovi il grafico';

  @override
  String get dashboardReorderChartLabel => 'Grafico di riordino';

  @override
  String get dashboardTakeSurveyTooltip => 'Assumere l\'indagine';

  @override
  String get defaultLanguage => 'Lingua di default';

  @override
  String get deleteButton => 'Cancella';

  @override
  String get deleteDeviceLabel => 'Eliminare il dispositivo';

  @override
  String get designSystemActionVariantTitle => 'Con l\'azione';

  @override
  String get designSystemActivatedLabel => 'Attivato';

  @override
  String get designSystemAvatarAwayLabel => 'Via';

  @override
  String get designSystemAvatarBusyLabel => 'Occupato';

  @override
  String get designSystemAvatarConnectedLabel => 'Collegato';

  @override
  String get designSystemAvatarEnabledLabel => 'Abilitato';

  @override
  String get designSystemAvatarSizeMatrixTitle => 'Dimensioni Matrix';

  @override
  String get designSystemAvatarStatusMatrixTitle => 'Matrice di stato';

  @override
  String get designSystemBackLabel => 'Indietro';

  @override
  String get designSystemBreadcrumbCurrentLabel => 'Braccioli';

  @override
  String get designSystemBreadcrumbDesignSystemLabel =>
      'Sistema di progettazione';

  @override
  String get designSystemBreadcrumbHomeLabel => 'Inizio';

  @override
  String get designSystemBreadcrumbMobileLabel => 'Dispositivo mobile';

  @override
  String get designSystemBreadcrumbProjectsLabel => 'Progetti';

  @override
  String get designSystemBreadcrumbSampleLabel => 'Pancromo';

  @override
  String get designSystemBreadcrumbTrailTitle => 'Sentiero del pane';

  @override
  String get designSystemCalendarPickerLabel => 'Picker Calendario';

  @override
  String get designSystemCalendarViewsTitle => 'Vista del calendario';

  @override
  String get designSystemCaptionDescriptionSample =>
      'Rimuovere tutti gli utenti inediti di questo progetto. Aggiungete agli utenti di pubblicarlo di nuovo.';

  @override
  String get designSystemCaptionIconLeftLabel => 'icona sinistra';

  @override
  String get designSystemCaptionIconTopLabel => 'icona superiore';

  @override
  String get designSystemCaptionNoIconLabel => 'Nessuna icona';

  @override
  String get designSystemCaptionTitleSample => 'Titolo di acquisizione';

  @override
  String get designSystemCaptionVariantsTitle => 'Varianti di captazione';

  @override
  String get designSystemCaptionWithActionsLabel => 'Con le azioni';

  @override
  String get designSystemCaptionWithoutActionsLabel => 'Senza azioni';

  @override
  String get designSystemCheckboxLabel => 'Check-in';

  @override
  String get designSystemContextMenuDeleteLabel => 'Cancella';

  @override
  String get designSystemContextMenuVariantsTitle =>
      'Varianti di menu contestuale';

  @override
  String get designSystemCountdownVariantTitle => 'Con il conto alla rovescia';

  @override
  String get designSystemDateCardsTitle => 'Schede di data';

  @override
  String get designSystemDefaultLabel => 'Predefinito';

  @override
  String get designSystemDisabledLabel => 'Disabili';

  @override
  String get designSystemDividerLabelText => 'Etichetta di Divider';

  @override
  String get designSystemDropdownComboboxTitle => 'Casella combinata';

  @override
  String get designSystemDropdownFieldLabel => 'Etichetta';

  @override
  String get designSystemDropdownInputLabel => 'Dati in ingresso';

  @override
  String get designSystemDropdownListTitle => 'Elenco a discesa';

  @override
  String get designSystemDropdownMultiselectInputLabel => 'Seleziona i team';

  @override
  String get designSystemDropdownMultiselectTitle => 'Multiselezione';

  @override
  String get designSystemDropdownOptionAnalytics => 'Analisi';

  @override
  String get designSystemDropdownOptionBackend => 'Indietro';

  @override
  String get designSystemDropdownOptionDesign => 'Progettazione';

  @override
  String get designSystemDropdownOptionFrontend => 'Fronte';

  @override
  String get designSystemDropdownOptionGrowth => 'Crescita';

  @override
  String get designSystemDropdownOptionMobile => 'Dispositivo mobile';

  @override
  String get designSystemDropdownOptionQa => 'QA';

  @override
  String get designSystemErrorLabel => 'Errore';

  @override
  String get designSystemFileUploadClickLabel => 'Clicca per caricare';

  @override
  String get designSystemFileUploadCompleteLabel => 'Completo';

  @override
  String get designSystemFileUploadDefaultLabel => 'Predefinito';

  @override
  String get designSystemFileUploadDragLabel => 'o trascina e goccia';

  @override
  String get designSystemFileUploadDropZoneSectionTitle => 'Zona di goccia';

  @override
  String get designSystemFileUploadErrorLabel => 'Errore';

  @override
  String get designSystemFileUploadFailedText => 'Caricamento in corso';

  @override
  String get designSystemFileUploadHintText =>
      'SVG, PNG, JPG o GIF (max. 800×400px)';

  @override
  String get designSystemFileUploadHoverLabel => 'Passaggio del mouse';

  @override
  String get designSystemFileUploadItemSectionTitle => 'Articoli di file';

  @override
  String get designSystemFileUploadRetryLabel => 'Recuperare';

  @override
  String get designSystemFileUploadUploadingLabel => 'Caricamento';

  @override
  String get designSystemFilledLabel => 'Riempito';

  @override
  String get designSystemHeaderApiDocumentationLabel => 'Documentazione API';

  @override
  String get designSystemHeaderBackActionLabel => 'Indietro';

  @override
  String get designSystemHeaderDesktopSectionTitle => 'Sezione desktop';

  @override
  String get designSystemHeaderHelpActionLabel => 'Aiuto';

  @override
  String get designSystemHeaderMobileSectionTitle => 'Sezione mobile';

  @override
  String get designSystemHeaderNotificationsActionLabel => 'Notifica';

  @override
  String get designSystemHeaderSearchActionLabel => 'Ricerca';

  @override
  String get designSystemHorizontalLabel => 'Orizzonte';

  @override
  String get designSystemHoverLabel => 'Passaggio del mouse';

  @override
  String get designSystemInfoLabel => 'Informazioni';

  @override
  String get designSystemInputErrorSample => 'Questo campo è richiesto';

  @override
  String get designSystemInputHelperSample => 'Inserisci il tuo nome';

  @override
  String get designSystemInputHintSample => 'Detentore...';

  @override
  String get designSystemInputLabelSample => 'Etichetta';

  @override
  String get designSystemInputVariantsTitle => 'Varianti di ingresso';

  @override
  String get designSystemInputWithErrorLabel => 'Con l\'errore';

  @override
  String get designSystemInputWithHelperLabel => 'Con testo helper';

  @override
  String get designSystemInputWithIconsLabel => 'Con le icone';

  @override
  String get designSystemListItemActivatedLabel => 'Attivato';

  @override
  String get designSystemListItemOneLineLabel => 'Una linea';

  @override
  String get designSystemListItemSubtitleSample => 'Sottotitoli';

  @override
  String get designSystemListItemTitleSample => 'Titolo';

  @override
  String get designSystemListItemTwoLinesLabel => 'Due linee';

  @override
  String get designSystemListItemVariantsTitle => 'Elenco prodotti Varianti';

  @override
  String get designSystemListItemWithDividerLabel => 'Con divisore';

  @override
  String get designSystemMediumLabel => 'Mezzo';

  @override
  String designSystemMyDailyDurationHoursMinutesCompact(
    int hours,
    int minutes,
  ) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get designSystemNavigationCollapsedLabel => 'Collasso';

  @override
  String get designSystemNavigationDailyFilterSectionTitle =>
      'Filtro giornaliero';

  @override
  String get designSystemNavigationExpandedLabel => 'Espansione';

  @override
  String get designSystemNavigationFilterByBlockLabel => 'Filtra per blocco';

  @override
  String get designSystemNavigationHikingLabel => 'Escursioni a piedi';

  @override
  String get designSystemNavigationHolidayLabel => 'Vacanza';

  @override
  String get designSystemNavigationInsightsLabel => 'Analisi';

  @override
  String get designSystemNavigationLottiTasksLabel => 'Compiti Lotti';

  @override
  String get designSystemNavigationMyDailyLabel => 'Il mio quotidiano';

  @override
  String get designSystemNavigationNewLabel => 'Nuovo';

  @override
  String get designSystemNavigationPlaceholderLabel => 'Destinatario';

  @override
  String get designSystemNavigationSidebarSectionTitle => 'Varianti laterali';

  @override
  String get designSystemNavigationSubComponentsSectionTitle =>
      'Sottocomponenti';

  @override
  String get designSystemNavigationTabBarSectionTitle =>
      'Varianti della barra delle schede';

  @override
  String get designSystemPressedLabel => 'Pressato';

  @override
  String get designSystemProgressBarChunkyLabel => 'Coccinella';

  @override
  String get designSystemProgressBarLabelAndPercentageLabel =>
      'Etichetta + Percentuale';

  @override
  String get designSystemProgressBarLabelOnlyLabel => 'Etichetta solo';

  @override
  String get designSystemProgressBarOffLabel => 'Fuori!';

  @override
  String get designSystemProgressBarPercentageOnlyLabel => 'Percentuale';

  @override
  String get designSystemProgressBarQuestBarLabel => 'Barra della missione';

  @override
  String get designSystemProgressBarQuestLabel => 'Etichetta del premio Mega';

  @override
  String get designSystemProgressBarSampleLabel =>
      'Etichetta di barre di progresso';

  @override
  String get designSystemRadioButtonLabel => 'Pulsante radio';

  @override
  String get designSystemScrollbarSizesTitle =>
      'Dimensioni della barra di scorrimento';

  @override
  String get designSystemSearchClearLabel => 'Cancella ricerca';

  @override
  String get designSystemSearchFilledText => 'Ricerca Lotti';

  @override
  String get designSystemSearchHintLabel => 'Tipo utente';

  @override
  String get designSystemSelectedLabel => 'Selezionato';

  @override
  String get designSystemSizeScaleTitle => 'Scala di dimensione';

  @override
  String get designSystemSmallLabel => 'Piccolo';

  @override
  String get designSystemSpinnerPlainLabel => 'Pianura';

  @override
  String get designSystemSpinnerSkeletonPulseLabel => 'Pulsante';

  @override
  String get designSystemSpinnerSkeletonsTitle => 'Scheletri';

  @override
  String get designSystemSpinnerSkeletonWaveLabel => 'Onda';

  @override
  String get designSystemSpinnerSpinnersTitle => 'Indicatori di caricamento';

  @override
  String get designSystemSpinnerTrackLabel => 'Con la pista';

  @override
  String designSystemSplitButtonDropdownSemantics(String label) {
    return 'Opzioni aperte $label';
  }

  @override
  String get designSystemStateMatrixTitle => 'Matrice di Stato';

  @override
  String get designSystemSuccessLabel => 'Successo';

  @override
  String get designSystemTabBarTitle => 'Bar della scheda';

  @override
  String get designSystemTabPendingLabel => 'Finanziamenti';

  @override
  String get designSystemTaskListBlockedLabel => 'Bloccato';

  @override
  String get designSystemTaskListDefaultLabel => 'Predefinito';

  @override
  String get designSystemTaskListHoverLabel => 'Passaggio del mouse';

  @override
  String get designSystemTaskListItemSectionTitle =>
      'Elenco delle attività Varianti dell\'oggetto';

  @override
  String get designSystemTaskListOnHoldLabel => 'Aspetta.';

  @override
  String get designSystemTaskListOpenLabel => 'Aprire';

  @override
  String get designSystemTaskListPressedLabel => 'Pressato';

  @override
  String get designSystemTaskListSampleTime => '8:00-9:30';

  @override
  String get designSystemTaskListSampleTitle => 'Test dell\'utente';

  @override
  String get designSystemTaskListWithDividerLabel => 'Con divisore';

  @override
  String get designSystemTextareaErrorSample => 'Questo campo è richiesto';

  @override
  String get designSystemTextareaHelperSample =>
      'Inserisci il tuo messaggio qui';

  @override
  String get designSystemTextareaHintSample => 'Tipo qualcosa...';

  @override
  String get designSystemTextareaLabelSample => 'Etichetta';

  @override
  String get designSystemTextareaVariantsTitle =>
      'Varianti della superficie del testo';

  @override
  String get designSystemTextareaWithCounterLabel => 'Con contatore';

  @override
  String get designSystemTextareaWithErrorLabel => 'Con l\'errore';

  @override
  String get designSystemTextareaWithHelperLabel => 'Con testo helper';

  @override
  String get designSystemTimePickerFormatsTitle => 'Formati del tempo';

  @override
  String get designSystemTimePickerTwelveHourLabel => '12 ore';

  @override
  String get designSystemTimePickerTwentyFourHourLabel => '24 ore su 24';

  @override
  String get designSystemTitleOnlyVariantTitle => 'Titolo Solo Variante';

  @override
  String get designSystemToastDetailsLabel => 'Dettagli di notifica';

  @override
  String get designSystemToggleLabel => 'Etichetta Toggle';

  @override
  String get designSystemTooltipIconMessageSample =>
      'Informazioni utili su questo campo';

  @override
  String get designSystemTooltipIconVariantsTitle => 'Icona del tooltip';

  @override
  String get designSystemUndoLabel => 'Annulla';

  @override
  String get designSystemVariantMatrixTitle => 'Matrice Variante';

  @override
  String get designSystemVerticalLabel => 'Verticale';

  @override
  String get designSystemWarningLabel => 'Avvertenza';

  @override
  String get designSystemWeeklyCalendarLabel => 'Calendario settimanale';

  @override
  String get designSystemWithLabelLabel => 'Con etichetta';

  @override
  String get desktopEmptyStateSelectDashboard =>
      'Selezionare una dashboard per visualizzare i dettagli';

  @override
  String get desktopEmptyStateSelectProject =>
      'Selezionare un progetto per visualizzare i dettagli';

  @override
  String get desktopEmptyStateSelectTask =>
      'Selezionare un\'attività per visualizzare i dettagli';

  @override
  String deviceDeletedSuccess(String deviceName) {
    return 'Dispositivo $deviceName cancellato con successo';
  }

  @override
  String deviceDeleteFailed(String error) {
    return 'Non riuscito a eliminare il dispositivo: $error';
  }

  @override
  String get doneButton => 'Fatto';

  @override
  String get editMenuTitle => 'Modifica';

  @override
  String get editorDiscardChanges => 'Disattivare le modifiche';

  @override
  String get editorInsertDivider => 'Inserto divisore';

  @override
  String get editorMoreFormatting => 'Più formattazione';

  @override
  String get editorPlaceholder => 'Inserisci note...';

  @override
  String get embeddingSelectAll => 'Seleziona tutto';

  @override
  String get embeddingUnselectAll => 'Deselect Tutti';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Scegli tra i modelli di prompt ready-made';

  @override
  String get enterCategoryName => 'Inserisci il nome della categoria';

  @override
  String get entryActions => 'Azioni';

  @override
  String get entryLabelsActionSubtitle =>
      'Assegnare etichette per organizzare questa voce';

  @override
  String get entryLabelsActionTitle => 'Etichette';

  @override
  String get entryLabelsEditTooltip => 'Modifica delle etichette';

  @override
  String get entryLabelsHeaderTitle => 'Etichette';

  @override
  String get entryLabelsNoLabels => 'Nessuna etichetta assegnata';

  @override
  String get entryTypeLabelAiResponse => 'Risposta dell\'IA';

  @override
  String get entryTypeLabelChecklist => 'Lista di controllo';

  @override
  String get entryTypeLabelChecklistItem => 'Da fare';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Abitazioni';

  @override
  String get entryTypeLabelJournalAudio => 'Audio audio';

  @override
  String get entryTypeLabelJournalEntry => 'Testo';

  @override
  String get entryTypeLabelJournalEvent => 'Evento';

  @override
  String get entryTypeLabelJournalImage => 'Fotografie';

  @override
  String get entryTypeLabelMeasurementEntry => 'Misura';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Salute';

  @override
  String get entryTypeLabelSurveyEntry => 'Indagine';

  @override
  String get entryTypeLabelTask => 'Compiti';

  @override
  String get entryTypeLabelWorkoutEntry => 'Lavorazione';

  @override
  String get eventNameLabel => 'Evento:';

  @override
  String get eventsAddCoverPhoto => 'Aggiungi foto di copertina';

  @override
  String get eventsAddLabel => 'Aggiungi';

  @override
  String get eventsChangeCover => 'Cambia la copertura';

  @override
  String get eventsDeleteEvent => 'Elimina evento';

  @override
  String get eventsFilterAll => 'Tutti';

  @override
  String eventsMetricPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foto',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String eventsMetricTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attività',
      one: '1 attività',
    );
    return '$_temp0';
  }

  @override
  String get eventsNewEvent => 'Nuovo evento';

  @override
  String get eventsPageTitle => 'Eventi';

  @override
  String get eventsPhotosSection => 'Fotografie';

  @override
  String get eventsRecapAwaitingContent =>
      'Aggiungi una foto o una nota e il recap apparirà qui.';

  @override
  String get eventsRecapUnavailable => 'Non ho potuto caricare il recap.';

  @override
  String get eventsRegenerateSummary => 'Riepilogo rigenerante';

  @override
  String get eventsSearchHint => 'Eventi di ricerca';

  @override
  String get eventsSectionUpcoming => 'Prossimo';

  @override
  String get eventsStatusCancelled => 'Annullamento';

  @override
  String get eventsStatusCompleted => 'Completo';

  @override
  String get eventsStatusMissed => 'Mancato';

  @override
  String get eventsStatusOngoing => 'In corso';

  @override
  String get eventsStatusPlanned => 'Pianificato';

  @override
  String get eventsStatusPostponed => 'Postponi';

  @override
  String get eventsStatusRescheduled => 'Riprogrammazione';

  @override
  String get eventsStatusTentative => 'Tentativo';

  @override
  String get eventsSummaryTitle => 'Sintesi';

  @override
  String get eventsTasksEmpty =>
      'Collegare un\'attività di preparazione o follow-up';

  @override
  String get eventsTasksSection => 'Compiti';

  @override
  String get eventsTimelineEmpty => 'Aggiungi foto, note o un memo vocale';

  @override
  String get eventsTimelineSection => 'Tempo';

  @override
  String get eventsTitleHint => 'Titolo dell\'evento';

  @override
  String get eventsVoiceNote => 'Nota vocale';

  @override
  String get favoriteLabel => 'Preferito';

  @override
  String get fileMenuNewEllipsis => 'Nuovo...';

  @override
  String get fileMenuNewEntry => 'Nuova ammissione';

  @override
  String get fileMenuNewScreenshot => 'Sceneggiatura';

  @override
  String get fileMenuNewTask => 'Compiti';

  @override
  String get fileMenuTitle => 'Menu File';

  @override
  String get filterSelectionNoMatches => 'Nessuna corrispondenza';

  @override
  String get geminiThinkingModeHighDescription =>
      'Il ragionamento più profondo; può aumentare la latenza e il costo.';

  @override
  String get geminiThinkingModeHighLabel => 'Alto.';

  @override
  String get geminiThinkingModeLowDescription =>
      'Basso ragionamento per veloci richieste di tutti i giorni.';

  @override
  String get geminiThinkingModeLowLabel => 'Basso';

  @override
  String get geminiThinkingModeMediumDescription =>
      'ragionamento bilanciato per risposte più accurate.';

  @override
  String get geminiThinkingModeMediumLabel => 'Mezzo';

  @override
  String get geminiThinkingModeMinimalDescription =>
      'Impostazione più veloce; Gemini può ancora pensare brevemente su suggerimenti complessi.';

  @override
  String get geminiThinkingModeMinimalLabel => 'Minimo';

  @override
  String get generateCoverArt => 'Generare l\'arte della copertura';

  @override
  String get generateCoverArtSubtitle =>
      'Crea immagine dalla descrizione vocale';

  @override
  String get goMenuTitle => 'Vai.';

  @override
  String get habitActiveFromLabel => 'Data di inizio';

  @override
  String get habitActiveSwitchDescription => 'Mostrato sulla pagina Habits';

  @override
  String get habitArchivedLabel => 'Archivio';

  @override
  String get habitCategoryHint => 'Seleziona una categoria';

  @override
  String get habitCategoryLabel => 'Categoria';

  @override
  String get habitCloseCompletionLabel => 'Completamento dell\'abitudine';

  @override
  String habitCompleteSemanticLabel(String habit) {
    return 'Registrazione $habit';
  }

  @override
  String get habitCompletionStatusCompleted => 'Completo';

  @override
  String get habitCompletionStatusFailed => 'Fatta.';

  @override
  String get habitCompletionStatusOpen => 'Aprire';

  @override
  String get habitCompletionStatusSkipped => 'Abilitato';

  @override
  String get habitDashboardHint => 'Seleziona una dashboard';

  @override
  String get habitDashboardLabel => 'Dashboard (opzionale)';

  @override
  String habitDayStatusSemantic(String habit, String status) {
    return '$habit, $status';
  }

  @override
  String get habitDeleteConfirm => 'SÌ, DELETE QUESTO HABIT';

  @override
  String get habitDeleteQuestion => 'Vuoi eliminare questa abitudine?';

  @override
  String habitHeatmapDaySemantic(String date, int done, int total) {
    return '$date, $done di $total fatto';
  }

  @override
  String get habitLogOtherDayHint => 'Tenere per registrare un altro giorno';

  @override
  String get habitNotRecordedLabel => 'Non registrato';

  @override
  String get habitPriorityLabel => 'Priorità';

  @override
  String get habitsAboveGoal => 'Sulla pista';

  @override
  String habitsActiveHabitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count abitudini attive',
      one: '1 abitudine attiva',
    );
    return '$_temp0';
  }

  @override
  String get habitsAllDoneToday => 'Tutto fatto oggi';

  @override
  String get habitsChartUseDynamicBaseline => 'Usa la linea di base dinamica';

  @override
  String get habitsChartUseZeroBaseline => 'Usa la linea di base zero';

  @override
  String get habitsCompletedHeader => 'Completo';

  @override
  String get habitsCompletionRateTitle => 'Tasso di compensazione';

  @override
  String get habitsConsistencyTitle => 'Consistenza';

  @override
  String habitsDayFailedPercent(int percent) {
    return '$percent% registrato fallisce';
  }

  @override
  String habitsDaySkippedPercent(int percent) {
    return '$percent% saltato';
  }

  @override
  String habitsDaySuccessfulPercent(int percent) {
    return '$percent% di successo';
  }

  @override
  String get habitsDoneTodayLabel => 'Fatto oggi';

  @override
  String get habitSectionOptionsTitle => 'Opzioni';

  @override
  String get habitSectionScheduleTitle => 'Orari';

  @override
  String get habitsFilterAll => 'tutti quanti';

  @override
  String get habitsFilterCompleted => 'Fatto';

  @override
  String get habitsFilterOpenNow => 'dovuto';

  @override
  String get habitsFilterPendingLater => 'più tardi';

  @override
  String get habitsGoalLineLabel => 'Gol';

  @override
  String get habitsHeatmapEmpty =>
      'Aggiungi un\'abitudine per iniziare a costruire la tua consistenza';

  @override
  String get habitsHeatmapLess => 'Meno';

  @override
  String get habitsHeatmapMore => 'Altro';

  @override
  String get habitShowAlertAtLabel => 'Mostra all\'allerta';

  @override
  String get habitShowFromLabel => 'Mostra da';

  @override
  String habitsLaggardHint(String habit, int kept, int active) {
    return '$habit — tenuto $kept di $active';
  }

  @override
  String get habitsOpenHeader => 'Due ora';

  @override
  String get habitsPendingLaterHeader => 'Più tardi oggi';

  @override
  String habitsPointsToGoal(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points pts a gol',
      one: '1 pt a gol',
    );
    return '$_temp0';
  }

  @override
  String get habitsRecordButton => 'Registrazione';

  @override
  String get habitsRollingAverageLabel => '7 giorni avg';

  @override
  String get habitsStartStreakToday => 'Inizia una striscia oggi';

  @override
  String habitsStreakLongCount(int count) {
    return '$count su una striscia di 7 giorni';
  }

  @override
  String habitsStreakShortCount(int count) {
    return '$count su una striscia di 3 giorni';
  }

  @override
  String get habitsTapForBreakdown => 'Toccare un giorno per il guasto';

  @override
  String habitsToGoCount(int count) {
    return '$count per andare';
  }

  @override
  String habitStreakDaysSemantic(int count) {
    return '$count-day striscia';
  }

  @override
  String get habitsVsPreviousWeek => 'vs settimana precedente';

  @override
  String get helpMenuCommandPalette => 'Comando Palette...';

  @override
  String get helpMenuKeyboardShortcuts => 'Tastiera Scorciatoie...';

  @override
  String get helpMenuTitle => 'Aiuto';

  @override
  String get imageGenerationError => 'Non è riuscito a generare immagine';

  @override
  String get imageGenerationGenerating => 'Generando l\'immagine...';

  @override
  String get imageGenerationProviderRejectedTitle =>
      'Il fornitore di immagini ha respinto questa richiesta';

  @override
  String imageGenerationWithReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Utilizzo di $count immagini di riferimento',
      one: 'Utilizzo di 1 immagine di riferimento',
      zero: 'Nessuna immagine di riferimento',
    );
    return '$_temp0';
  }

  @override
  String get imagePromptGenerationCardTitle => 'Prompt di immagine di AI';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Prompt dell\'immagine copiato negli appunti';

  @override
  String get imagePromptGenerationCopyButton => 'Copia Prompt';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Copia il prompt dell\'immagine negli appunti';

  @override
  String get imagePromptGenerationExpandTooltip => 'Mostra il prompt completo';

  @override
  String get imagePromptGenerationFullPromptLabel =>
      'Prompt immagine completa:';

  @override
  String get images => 'Immagini';

  @override
  String get imageViewerDownloadFailed => 'Non poteva salvare l\'immagine';

  @override
  String get imageViewerDownloadingTooltip => 'Salvataggio dell\'immagine';

  @override
  String get imageViewerDownloadPermissionDenied =>
      'Accesso foto negato — abilitarlo in Impostazioni';

  @override
  String imageViewerDownloadSaved(String fileName) {
    return 'Salvataggio $fileName';
  }

  @override
  String get imageViewerDownloadSavedToGallery => 'Salvataggio a foto';

  @override
  String get imageViewerDownloadTooltip => 'Scarica l\'immagine';

  @override
  String get inactiveLabel => 'Inattivo';

  @override
  String get inactiveSwitchDescription =>
      'Può essere scelto per le nuove voci quando in su';

  @override
  String get inferenceProfileChooseModelTitle => 'Scegli un modello';

  @override
  String get inferenceProfileChooseTitle => 'Scegli un profilo di inferenza';

  @override
  String get inferenceProfileCreateTitle => 'Crea il profilo';

  @override
  String get inferenceProfileDescriptionLabel => 'Designazione';

  @override
  String get inferenceProfileDesktopOnly => 'Solo Desktop';

  @override
  String get inferenceProfileDesktopOnlyDescription =>
      'Disponibile solo su piattaforme desktop (ad esempio per modelli locali)';

  @override
  String inferenceProfileDetailLoadError(String error) {
    return 'Non poteva caricare il profilo: $error';
  }

  @override
  String get inferenceProfileDetailNotFound => 'Profilo non trovato';

  @override
  String get inferenceProfileEditTitle => 'Modifica profilo';

  @override
  String get inferenceProfileImageGeneration => 'Generazione di immagini';

  @override
  String get inferenceProfileImageRecognition =>
      'Riconoscimento delle immagini';

  @override
  String get inferenceProfileModelUnavailable =>
      'Modello non disponibile — il suo fornitore può essere stato rimosso';

  @override
  String get inferenceProfileNameLabel => 'Nome del profilo';

  @override
  String get inferenceProfileNameRequired => 'È richiesto un nome del profilo';

  @override
  String get inferenceProfilePinnedHostHelper =>
      'Quando impostato, solo questo dispositivo esegue automaticamente l\'inferenza per le voci audio sincronizzate che utilizzano questo profilo.';

  @override
  String get inferenceProfilePinnedHostLabel => 'Dispositivi perni';

  @override
  String get inferenceProfilePinnedHostNoEligibleNodes =>
      'Nessun dispositivo conosciuto pubblicizza i fornitori che questo profilo utilizza. Aprire le impostazioni del nodo Sync sul dispositivo di destinazione.';

  @override
  String get inferenceProfilePinnedHostNoneHelper =>
      'Le voci audio sincronizzate non sono auto-trascritte quando nessun dispositivo è pinned.';

  @override
  String get inferenceProfilePinnedHostNoneLabel =>
      'Non spillato (non auto-trigger)';

  @override
  String get inferenceProfilePinnedHostThisDeviceSuffix =>
      '(questo dispositivo)';

  @override
  String get inferenceProfileSaveButton => 'Salva';

  @override
  String get inferenceProfileSelectModel => 'Scegli un modello...';

  @override
  String get inferenceProfileSelectProfile => 'Scegli un profilo...';

  @override
  String get inferenceProfilesEmpty => 'Nessun profilo di inferenza ancora';

  @override
  String inferenceProfileSkillModelRequired(String slotName) {
    return 'Richiede modello $slotName da impostare';
  }

  @override
  String get inferenceProfileSkillsSection => 'Abilità automatizzate';

  @override
  String inferenceProfileSkillUsesModel(String slotName) {
    return 'Utilizza il modello $slotName';
  }

  @override
  String get inferenceProfilesTitle => 'Profili di inferenza';

  @override
  String get inferenceProfileThinking => 'Pensare';

  @override
  String get inferenceProfileThinkingHighEnd => 'Pensare (High-End)';

  @override
  String get inferenceProfileThinkingRequired =>
      'Un modello di pensiero è richiesto';

  @override
  String get inferenceProfileTranscription => 'Trascrizione';

  @override
  String get inferenceProfileUnavailable =>
      'Profilo di inferenza non disponibile';

  @override
  String get inputDataTypeAudioFilesDescription =>
      'Utilizzare i file audio come input';

  @override
  String get inputDataTypeAudioFilesName => 'File audio';

  @override
  String get inputDataTypeImagesDescription =>
      'Utilizzare le immagini come input';

  @override
  String get inputDataTypeImagesName => 'Immagini';

  @override
  String get inputDataTypeTaskDescription =>
      'Utilizzare l\'attività corrente come input';

  @override
  String get inputDataTypeTaskName => 'Compiti';

  @override
  String get inputDataTypeTasksListDescription =>
      'Utilizzare un elenco di attività come input';

  @override
  String get inputDataTypeTasksListName => 'Elenco delle attività';

  @override
  String get insightsChartCompareCaption =>
      'Questo periodo rispetto al precedente';

  @override
  String get insightsChartCompareCaptionPartial =>
      'Questo periodo finora vs il precedente';

  @override
  String get insightsChartCompareHint =>
      'Confronto mostrato nella tabella sottostante';

  @override
  String get insightsChartCumulativeCaption => 'Esecuzione totale sulla gamma';

  @override
  String get insightsChartCumulativeShort =>
      'Non abbastanza giorni ancora per un totale in esecuzione';

  @override
  String get insightsChartDailyCaption => 'Tempo al giorno';

  @override
  String get insightsChartHourlyCaption => 'Tempo all\'ora';

  @override
  String get insightsChartPerDay => 'Per giorno';

  @override
  String get insightsChartPerHour => 'Per ora';

  @override
  String get insightsChartPerWeek => 'Per settimana';

  @override
  String get insightsChartRunningTotal => 'Totale in esecuzione';

  @override
  String get insightsChartTitle => 'Tempo per categoria';

  @override
  String get insightsChartWeeklyCaption => 'Tempo a settimana';

  @override
  String get insightsChooseFocusCategories =>
      'Scegli le categorie di messa a fuoco';

  @override
  String get insightsCompare => 'Confronta';

  @override
  String get insightsCompareFullPeriod => 'periodo completo';

  @override
  String get insightsComparePrevious => 'Precedente';

  @override
  String get insightsCompareSameDays => 'stessi giorni';

  @override
  String get insightsCompareTooltip => 'Confronta con il periodo precedente';

  @override
  String get insightsCompareVs => 'vs.';

  @override
  String get insightsDeletedCategory => 'Categoria cancellata';

  @override
  String get insightsDeltaNew => 'nuovo nuovo';

  @override
  String get insightsEmptyBody =>
      'Il tempo che si tiene traccia di voci e compiti si presenterà qui.';

  @override
  String get insightsEmptyChart => 'Nessun dato in questo intervallo';

  @override
  String get insightsEmptyPreviousPeriod => 'Mostra il periodo precedente';

  @override
  String get insightsEmptyShowYear => 'Vedi quest\'anno';

  @override
  String get insightsEmptyTitle => 'Nessun tempo tracciato in questa gamma';

  @override
  String get insightsFocusCategoriesEmpty => 'Ancora nessuna categoria attiva.';

  @override
  String get insightsFocusCategoriesTitle => 'Categorie di messa a fuoco';

  @override
  String get insightsKpiFocus => 'CONCENTRAZIONE';

  @override
  String get insightsKpiFocusHelp => 'Categorie che stai guardando';

  @override
  String get insightsKpiOther => 'ALTRE';

  @override
  String get insightsKpiOtherHelp => 'Tutto il resto';

  @override
  String insightsKpiTopCategory(String category, String share) {
    return 'La maggior parte su $category · $share';
  }

  @override
  String get insightsKpiTotal => 'TOTALE';

  @override
  String get insightsLoadError => 'Non è possibile caricare i dati del tempo';

  @override
  String get insightsOtherCategories => 'Altri';

  @override
  String get insightsPartialWeek => 'settimana parziale';

  @override
  String get insightsPeriodDay => 'Giorno';

  @override
  String get insightsPeriodJump => 'Vai a una data';

  @override
  String get insightsPeriodMonth => 'Mese';

  @override
  String get insightsPeriodNext => 'Periodo successivo';

  @override
  String get insightsPeriodPrevious => 'Periodo precedente';

  @override
  String get insightsPeriodQuarter => 'Quarto trimestre';

  @override
  String get insightsPeriodToDateSuffix => 'fino ad ora';

  @override
  String get insightsPeriodWeek => 'Rassegna';

  @override
  String get insightsPeriodYear => 'Anno';

  @override
  String get insightsRangeMonthToDate => 'Questo mese finora';

  @override
  String get insightsRangeMtd => 'Questo mese';

  @override
  String get insightsRangeYearToDate => 'Quest\'anno finora';

  @override
  String get insightsRangeYtd => 'Quest\'anno';

  @override
  String get insightsRefreshError =>
      'Non è stato possibile aggiornare — mostrando gli ultimi dati caricati';

  @override
  String get insightsTableAvgPerDay => 'MEDIA/GIORNO';

  @override
  String get insightsTableCategory => 'CATEGORIA';

  @override
  String get insightsTableCompareNote =>
      'Il cambiamento è contro il periodo precedente';

  @override
  String get insightsTableCurrent => 'CURRE';

  @override
  String get insightsTableDelta => 'Cambiamento';

  @override
  String get insightsTablePrevious => 'PREVIO';

  @override
  String get insightsTableShare => 'CONDIVIDI';

  @override
  String get insightsTableTotal => 'TOTALE';

  @override
  String get insightsTimeAnalysisTitle => 'Analisi del tempo';

  @override
  String get insightsUncategorized => 'Non categorizzato';

  @override
  String get journalCopyImageLabel => 'Copia immagine';

  @override
  String get journalDateFromLabel => 'Data da:';

  @override
  String get journalDateInvalid => 'Gamma di data non valida';

  @override
  String get journalDateLabel => 'Data';

  @override
  String get journalDateNowButton => 'Ora.';

  @override
  String get journalDateSaveButton => 'Salva';

  @override
  String get journalDateTimeRangeTitle => 'Data e ora';

  @override
  String get journalDateToLabel => 'Data di:';

  @override
  String get journalDeleteConfirm => 'SÌ, ELIMINA QUESTA VOCE';

  @override
  String get journalDeleteHint => 'Eliminare la voce';

  @override
  String get journalDeleteQuestion => 'Vuoi eliminare questa voce del diario?';

  @override
  String get journalDurationLabel => 'Durata';

  @override
  String get journalEndDateLabel => 'Data di fine';

  @override
  String get journalEndsAnotherDayHint => 'Scegli una data di fine separata';

  @override
  String get journalEndsAnotherDayLabel => 'Finisce in un altro giorno';

  @override
  String get journalEndTimeLabel => 'Tempo di chiusura';

  @override
  String get journalFilterEntryTypesTitle => 'Tipologie di ammissione';

  @override
  String get journalFilterFlagged => 'Bandiera';

  @override
  String get journalFilterPrivate => 'Privato';

  @override
  String get journalFilterShowTitle => 'Mostra';

  @override
  String get journalFilterStarred => 'Stellato';

  @override
  String get journalFilterTitle => 'Diario di filtro';

  @override
  String get journalHideLinkHint => 'Nascondi il link';

  @override
  String get journalHideMapHint => 'Nascondi la mappa';

  @override
  String get journalLinkedEntriesActivityFilterAudio => 'Audio audio';

  @override
  String get journalLinkedEntriesActivityFilterCode => 'Codice';

  @override
  String get journalLinkedEntriesActivityFilterImages => 'Immagini';

  @override
  String get journalLinkedEntriesActivityFilterTimer => 'Cronometro';

  @override
  String get journalLinkedEntriesFilterModalTitle => 'Filtro e Ordinazione';

  @override
  String get journalLinkedEntriesShowFlaggedOnly =>
      'Mostra solo le voci contrassegnate';

  @override
  String get journalLinkedEntriesShowHidden => 'Mostra le voci nascoste';

  @override
  String get journalLinkedEntriesSortLabel => 'Ordina per';

  @override
  String get journalLinkedEntriesSortNewestFirst => 'Il primo nuovo';

  @override
  String get journalLinkedEntriesSortOldestFirst => 'Il primo vecchio';

  @override
  String get journalLinkedFromLabel => 'Linked da:';

  @override
  String get journalLinkFromHint => 'Link da';

  @override
  String get journalLinkToHint => 'Link a';

  @override
  String journalOvernightNextDay(String date) {
    return 'Fine $date (giorno successivo)';
  }

  @override
  String get journalPrivateTooltip => 'privato solo';

  @override
  String get journalSearchHint => 'Diario di ricerca...';

  @override
  String get journalSetEndDateTimeNowSemantic =>
      'Impostare la data e l\'ora di fine';

  @override
  String get journalSetStartDateTimeNowSemantic =>
      'Impostare la data di inizio e l\'ora per ora';

  @override
  String get journalShareHint => 'Condividi';

  @override
  String get journalShowLinkHint => 'Mostra il link';

  @override
  String get journalShowMapHint => 'Visualizza mappa';

  @override
  String get journalStartDateLabel => 'Data di inizio';

  @override
  String get journalStartTimeLabel => 'Tempo di inizio';

  @override
  String get journalTodayButton => 'Oggi';

  @override
  String get journalToggleFlaggedTitle => 'Bandiera';

  @override
  String get journalTogglePrivateTitle => 'Privato';

  @override
  String get journalToggleStarredTitle => 'Preferito';

  @override
  String get journalUnlinkConfirm => 'SÌ, SCOLLEGA LA VOCE';

  @override
  String get journalUnlinkHint => 'Un link';

  @override
  String get journalUnlinkQuestion =>
      'Sei sicuro di voler sbloccare questa voce?';

  @override
  String get keyboardCommandActivate => 'Attivare l\'elemento concentrato';

  @override
  String get keyboardCommandCategoryCreation => 'Creazione';

  @override
  String get keyboardCommandCategoryEditing => 'Modifica';

  @override
  String get keyboardCommandCategoryGeneral => 'Generale';

  @override
  String get keyboardCommandCategoryListsAndControls => 'Liste e controlli';

  @override
  String get keyboardCommandCategoryNavigation => 'Navigazione';

  @override
  String get keyboardCommandCategoryView => 'Vista';

  @override
  String get keyboardCommandCreateInContext => 'Creare in vista corrente';

  @override
  String get keyboardCommandFocusSearch => 'Ricerca focalizzata';

  @override
  String get keyboardCommandMoveDown =>
      'Spostare l\'oggetto focalizzato verso il basso';

  @override
  String get keyboardCommandMoveUp => 'Spostare l\'oggetto concentrato';

  @override
  String keyboardCommandNavigate(String destination) {
    return 'Vai a $destination';
  }

  @override
  String get keyboardCommandNextRegion => 'Concentra il riquadro successivo';

  @override
  String get keyboardCommandOpenPalette => 'Aprire la tavolozza dei comandi';

  @override
  String get keyboardCommandPageDown => 'Spostare una pagina';

  @override
  String get keyboardCommandPageUp => 'Spostare una pagina';

  @override
  String get keyboardCommandPreviousRegion =>
      'Concentra il pannello precedente';

  @override
  String get keyboardCommandRefresh => 'Refresh vista corrente';

  @override
  String get keyboardCommandRename => 'Rinominare l\'oggetto concentrato';

  @override
  String get keyboardCommandSelectFirst => 'Selezionare il primo elemento';

  @override
  String get keyboardCommandSelectLast => 'Seleziona l\'ultima voce';

  @override
  String get keyboardCommandSelectNext => 'Selezionare l\'elemento successivo';

  @override
  String get keyboardCommandSelectPrevious =>
      'Seleziona l\'elemento precedente';

  @override
  String get keyboardCommandToggle => 'Toggle oggetto focalizzato';

  @override
  String get keyboardKeyAlt => 'Alt.';

  @override
  String get keyboardKeyArrowDown => 'Condividi su Facebook';

  @override
  String get keyboardKeyArrowLeft => 'Arrow sinistro';

  @override
  String get keyboardKeyArrowRight => 'Freccia destra';

  @override
  String get keyboardKeyArrowUp => 'Arrow!';

  @override
  String get keyboardKeyControl => 'Ctrl';

  @override
  String get keyboardKeyDelete => 'Cancella';

  @override
  String get keyboardKeyEnd => 'Fine';

  @override
  String get keyboardKeyEnter => 'Inserisci';

  @override
  String get keyboardKeyEscape => 'Fuga';

  @override
  String get keyboardKeyHome => 'Inizio';

  @override
  String get keyboardKeyMinus => 'Minuscolo';

  @override
  String get keyboardKeyOr => 'o';

  @override
  String get keyboardKeyPageDown => 'Pagina iniziale';

  @override
  String get keyboardKeyPageUp => 'Pagina in corso';

  @override
  String get keyboardKeyPlus => 'Più';

  @override
  String get keyboardKeyShift => 'Spostamento';

  @override
  String get keyboardKeySpace => 'Spazio';

  @override
  String get keyboardResizeDividerLabel => 'Ridimensionare i pannelli';

  @override
  String keyboardResizeDividerValue(int value, int min, int max) {
    return 'Ridimensionare i pannelli, $value pixel. Intervallo da $min a $max pixel.';
  }

  @override
  String get keyboardShortcutsNoResults =>
      'Nessuna scorciatoia corrisponde alla tua ricerca';

  @override
  String get keyboardShortcutsSearchHint => 'Cerca scorciatoie...';

  @override
  String get keyboardShortcutsSubtitle =>
      'Ogni comando desktop e la sua combinazione di tastiera corrente.';

  @override
  String get keyboardShortcutsTitle => 'Tasti di scelta rapida';

  @override
  String knowledgeGraphAgeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni fa',
      one: '1 giorno fa',
    );
    return '$_temp0';
  }

  @override
  String knowledgeGraphAgeMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesi fa',
      one: '1 mese fa',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeToday => 'oggi';

  @override
  String knowledgeGraphAgeWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count settimane fa',
      one: '1 settimana fa',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeYesterday => 'ieri';

  @override
  String get knowledgeGraphBack => 'Indietro';

  @override
  String get knowledgeGraphCloseDetails => 'Chiudi i dettagli';

  @override
  String get knowledgeGraphEmpty => 'Nessun link per esplorare ancora';

  @override
  String get knowledgeGraphEntryLoadError => 'Non poteva caricare questa voce';

  @override
  String get knowledgeGraphEntryNotFound => 'Entrata non trovata';

  @override
  String get knowledgeGraphError =>
      'Non è stato possibile caricare il grafico della conoscenza';

  @override
  String knowledgeGraphLinkedSection(int count) {
    return 'LINEE · $count';
  }

  @override
  String get knowledgeGraphMoreLinks => 'più collegamenti';

  @override
  String knowledgeGraphNodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodi',
      one: '1 nodo',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphNodeTypeAiSummary => 'Riepilogo dell\'AI';

  @override
  String get knowledgeGraphNodeTypeAudioNote => 'Nota audio';

  @override
  String get knowledgeGraphNodeTypeChecklist => 'Lista di controllo';

  @override
  String get knowledgeGraphNodeTypeChecklistItem =>
      'Articolo della lista di controllo';

  @override
  String get knowledgeGraphNodeTypeNote => 'Nota';

  @override
  String get knowledgeGraphNodeTypePhoto => 'Fotografie';

  @override
  String get knowledgeGraphNodeTypeProject => 'Progetto';

  @override
  String get knowledgeGraphNodeTypeRating => 'Valutazione';

  @override
  String get knowledgeGraphNodeTypeTask => 'Compiti';

  @override
  String get knowledgeGraphOpenDetails => 'Apri i dettagli';

  @override
  String get knowledgeGraphRecenter => 'Recenti';

  @override
  String get knowledgeGraphRecentToOlder => 'recenti → vecchi';

  @override
  String get knowledgeGraphRelationAiSource => 'Fonte dell\'IA';

  @override
  String get knowledgeGraphRelationChecklist => 'lista di controllo';

  @override
  String get knowledgeGraphRelationInProject => 'in progetto';

  @override
  String get knowledgeGraphRelationLinkedTask => 'attività collegata';

  @override
  String get knowledgeGraphRelationNoteLog => 'nota / log';

  @override
  String get knowledgeGraphRelationRating => 'rating Valutazione';

  @override
  String get knowledgeGraphSummarySection => 'SUMMARIO';

  @override
  String get knowledgeGraphTitle => 'Grafico della conoscenza';

  @override
  String get knowledgeGraphTooltip => 'Esplora i link';

  @override
  String knowledgeGraphWalkHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodi',
      one: '1 nodo',
    );
    return 'Toccare un nodo per camminare · $_temp0';
  }

  @override
  String get linkedFromCaption => 'da';

  @override
  String get linkedTaskImageBadge => 'Da un\'attività collegata';

  @override
  String get linkedTasksMenuTooltip => 'Opzioni di attività collegate';

  @override
  String get linkedTasksTitle => 'Compiti collegati';

  @override
  String get linkedToCaption => 'a';

  @override
  String get linkExistingTask => 'Collegare il compito esistente...';

  @override
  String get loggingDomainAgentRuntime => 'Tempo libero dell\'agente';

  @override
  String get loggingDomainAgentWorkflow => 'Flusso di lavoro agente';

  @override
  String get loggingDomainAi => 'IA';

  @override
  String get loggingDomainCalendar => 'Calendario e ora';

  @override
  String get loggingDomainChat => 'Conversazione';

  @override
  String get loggingDomainDailyOs => 'Sistema operativo giornaliero';

  @override
  String get loggingDomainDatabase => 'Database';

  @override
  String get loggingDomainGeneral => 'Generale';

  @override
  String get loggingDomainHabits => 'Abitazioni';

  @override
  String get loggingDomainHealth => 'Salute';

  @override
  String get loggingDomainLabels => 'Etichette';

  @override
  String get loggingDomainLocation => 'Posizione';

  @override
  String get loggingDomainNavigation => 'Navigazione';

  @override
  String get loggingDomainNotifications => 'Notifica';

  @override
  String get loggingDomainOnboarding => 'A bordo & FTUE';

  @override
  String get loggingDomainPersistence => 'Persistenza';

  @override
  String get loggingDomainRatings => 'Valutazioni';

  @override
  String get loggingDomainScreenshots => 'Proiezioni';

  @override
  String get loggingDomainSettings => 'Impostazioni delle impostazioni';

  @override
  String get loggingDomainSpeech => 'Discorso e audio';

  @override
  String get loggingDomainSync => 'Traduzione:';

  @override
  String get loggingDomainTasks => 'Compiti e liste di controllo';

  @override
  String get loggingDomainTheming => 'Il nome';

  @override
  String get loggingDomainWhatsNew => 'Cosa c\'è di nuovo';

  @override
  String get maintenanceDeleteAgentDb => 'Eliminare il database degli agenti';

  @override
  String get maintenanceDeleteAgentDbDescription =>
      'Elimina il database degli agenti e riavvia l\'app';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'SÌ, DELETE DATABASE';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Sei sicuro di voler eliminare $databaseName Database?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Eliminare il database degli editor';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Eliminare il database delle bozze dell\'editor';

  @override
  String get maintenanceDeleteSyncDb => 'Eliminare il database Sync';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Elimina il database di sincronizzazione';

  @override
  String get maintenanceGenerateEmbeddings => 'Generare Embeddings';

  @override
  String get maintenanceGenerateEmbeddingsConfirm => 'Sì, GENERATO';

  @override
  String get maintenanceGenerateEmbeddingsDescription =>
      'Generare embeddings per le voci in categorie selezionate';

  @override
  String get maintenanceGenerateEmbeddingsMessage =>
      'Selezionare le categorie per generare embeddings per.';

  @override
  String maintenanceGenerateEmbeddingsProgress(
    int processed,
    int total,
    int embedded,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$processed / $total voci ($embedded embedded)',
      one: '$processed / $total entrata ($embedded embedded)',
    );
    return '$_temp0';
  }

  @override
  String get maintenancePopulatePhaseAgentEntities =>
      'Elaborazione delle entità dell\'agente...';

  @override
  String get maintenancePopulatePhaseAgentLinks =>
      'L\'agente di elaborazione collega...';

  @override
  String get maintenancePopulatePhaseJournal =>
      'Elaborazione di voci di giornale...';

  @override
  String get maintenancePopulatePhaseLinks => 'Elaborazione dei link...';

  @override
  String get maintenancePopulateSequenceLog =>
      'Sequenza di sincronizzazione populare log';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return 'Indicizzate le voci $count';
  }

  @override
  String get maintenancePopulateSequenceLogConfirm => 'Sì, POPOLATO';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Indice delle entrate esistenti per il supporto di backfill';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'Questo consente di eseguire la scansione di tutte le voci della rivista e aggiungerle al registro delle sequenze di sincronizzazione.';

  @override
  String get maintenancePurgeDeleted => 'Purezza oggetti cancellati';

  @override
  String get maintenancePurgeDeletedConfirm => 'Si\', purificare tutto.';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Purezza tutti gli elementi eliminati in modo permanente';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Sei sicuro di voler eliminare tutti gli elementi eliminati? Questa azione non può essere annullata.';

  @override
  String get maintenancePurgeSentOutbox =>
      'Purge vecchio inviato outbox articoli';

  @override
  String get maintenancePurgeSentOutboxConfirm => 'Sì, PURGE';

  @override
  String get maintenancePurgeSentOutboxDescription =>
      'Eliminare le righe di uscita inviate più di 7 giorni e recuperare il disco';

  @override
  String get maintenancePurgeSentOutboxQuestion =>
      'Questo elimina le righe già inviate in blocchi ed esegue VACUUM per recuperare il disco. In attesa e gli elementi di errore sono tenuti.';

  @override
  String get maintenanceRecreateFts5 => 'Ricreare l\'indice di testo completo';

  @override
  String get maintenanceRecreateFts5Confirm => 'YES, INDICE CRONOLOGICO';

  @override
  String get maintenanceRecreateFts5Description =>
      'Ricreare l\'indice di ricerca full-text';

  @override
  String get maintenanceRecreateFts5Message =>
      'Sei sicuro di voler ricreare l\'indice full-text? Potrebbe volerci un po\' di tempo.';

  @override
  String get maintenanceReSync => 'Resync messaggi';

  @override
  String get maintenanceReSyncAgentEntities => 'entità dell\'agente';

  @override
  String get maintenanceReSyncDescription => 'Resync messaggi dal server';

  @override
  String get maintenanceReSyncEntityTypes => 'Tipi di ammissione';

  @override
  String get maintenanceReSyncJournalEntities => 'Enti di pubblicazione';

  @override
  String get maintenanceReSyncSelectAtLeastOne =>
      'Selezionare almeno un tipo di entità';

  @override
  String get maintenanceReSyncStart => 'Iniziare';

  @override
  String get maintenanceSyncDefinitions =>
      'Sincronizzabili, cruscotti, abitudini, categorie, Impostazioni AI';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sincronizzabili, cruscotti, abitudini, categorie e impostazioni AI';

  @override
  String get manageLinks => 'Gestire i collegamenti...';

  @override
  String get matrixStatsCatchupBatches => 'Batches di catch-up';

  @override
  String get matrixStatsCircuitOpens => 'Circuito si apre';

  @override
  String get matrixStatsConflicts => 'Conflitti';

  @override
  String get matrixStatsCopyDiagnostics => 'Diagnostica di copia';

  @override
  String get matrixStatsCopyDiagnosticsTooltip =>
      'Copia la diagnostica di sincronizzazione negli appunti';

  @override
  String get matrixStatsDbApplied => 'DB applicata';

  @override
  String get matrixStatsDbApply => 'DB Applicare';

  @override
  String get matrixStatsDbIgnoredVectorClock => 'DB Ignorato (VectorClock)';

  @override
  String get matrixStatsDbMissingBase => 'Base mancante DB';

  @override
  String matrixStatsDroppedByType(Object type) {
    return 'Gocciato ($type)';
  }

  @override
  String get matrixStatsEntryLinkNoops => 'Operazioni EntryLink senza effetto';

  @override
  String get matrixStatsFailures => 'Fallimenti';

  @override
  String get matrixStatsFlushes => 'Flussi';

  @override
  String get matrixStatsForceRescan => 'Forza Rescan';

  @override
  String get matrixStatsForceRescanTooltip => 'Forza rescan e cattura ora';

  @override
  String get matrixStatsLegend => 'La leggenda';

  @override
  String get matrixStatsLegendTooltip =>
      'Legenda: • elaborata. <type> = messaggi di sincronizzazione elaborati per tipo di payload • dropByType. <type> = per-type drops after retries or old-message ignora • dbApplied = righe di database scritte • dbIgnoredByVectorClock = dati in entrata vecchi o identici ignorati dal database • conflittiCreated = orologi corrente registrati • dbMissing';

  @override
  String get matrixStatsProcessed => 'Processo';

  @override
  String matrixStatsProcessedByType(Object type) {
    return 'Processato ($type)';
  }

  @override
  String get matrixStatsRefresh => 'Rifiuti';

  @override
  String get matrixStatsReliability => 'Affidabilità';

  @override
  String get matrixStatsRetriesScheduled => 'Riprese programmate';

  @override
  String get matrixStatsRetryNow => 'Recuperare ora';

  @override
  String get matrixStatsRetryNowTooltip =>
      'Recuperare fallimenti in sospeso ora';

  @override
  String get matrixStatsSignalLatencyLast => 'Latency del segnale (ultimo ms)';

  @override
  String get matrixStatsSignalLatencyMax => 'Latenza segnaletica (max ms)';

  @override
  String get matrixStatsSignalLatencyMin => 'Latenza di segnale (min ms)';

  @override
  String get matrixStatsSignals => 'Segnali';

  @override
  String get matrixStatsSignalsClientStream => 'Segnali (flusso corrente)';

  @override
  String get matrixStatsSignalsConnectivity => 'Segnali (connettività)';

  @override
  String get matrixStatsSignalsTimelineCallbacks =>
      'Segnali (chiamate di linea temporale)';

  @override
  String get matrixStatsSkipped => 'Abilitato';

  @override
  String get matrixStatsSkippedRetryCap => 'Saltato (limite tentativi)';

  @override
  String get matrixStatsStaleAttachmentPurges => 'Punteggio di aggancio';

  @override
  String get matrixStatsThroughput => 'Portata';

  @override
  String get matrixStatsTopKpis => 'I migliori KPI';

  @override
  String get measurableDeleteConfirm => 'SÌ, DELETE QUESTO MEASURABILE';

  @override
  String get measurableDeleteQuestion =>
      'Vuoi eliminare questo tipo di dati misurabile?';

  @override
  String get measurableNotFound => 'Misurazione non trovata';

  @override
  String get measurementCommentHint => 'Aggiungi una nota (opzionale)';

  @override
  String get measurementCommentSemantic => 'Commento, opzionale';

  @override
  String measurementObservedAtChangeSemantic(String dateTime) {
    return 'Osservato a $dateTime. Cambia la data e l\'ora.';
  }

  @override
  String get measurementQuickAddLabel => 'Diario rapido';

  @override
  String measurementQuickLogSemantic(String value) {
    return 'Log $value immediatamente';
  }

  @override
  String get measurementSaveError =>
      'Non ho potuto salvare questa misura. Prova di nuovo.';

  @override
  String get measurementSetObservedAtNowSemantic =>
      'Impostare la data e l\'ora osservati per ora';

  @override
  String get measurementTimeLabel => 'Tempo';

  @override
  String measurementValueSemantic(String measurable) {
    return 'Valore per $measurable';
  }

  @override
  String get mediaShowInFileExplorerAction => 'Mostra in File Explorer';

  @override
  String get mediaShowInFilesAction => 'Mostra in file';

  @override
  String get mediaShowInFinderAction => 'Mostra in Finder';

  @override
  String get modalityAudioDescription => 'Capacità di elaborazione audio';

  @override
  String get modalityAudioName => 'Audio audio';

  @override
  String get modalityImageDescription =>
      'Capacità di elaborazione delle immagini';

  @override
  String get modalityImageName => 'Immagine';

  @override
  String get modalityTextDescription =>
      'Contenuto e elaborazione basati sul testo';

  @override
  String get modalityTextName => 'Testo';

  @override
  String get modelAddPageTitle => 'Aggiungi il modello';

  @override
  String get modelEditBackTooltip => 'Indietro';

  @override
  String get modelEditDescriptionHint => 'Descrivi questo modello';

  @override
  String get modelEditDescriptionLabel => 'Designazione';

  @override
  String get modelEditDisplayNameHint =>
      'Un nome amichevole per questo modello';

  @override
  String get modelEditDisplayNameLabel => 'Nome dell\'esposizione';

  @override
  String get modelEditFunctionCallingDescription =>
      'Questo modello supporta la funzione e la chiamata degli strumenti.';

  @override
  String get modelEditFunctionCallingLabel => 'Funzione chiamata';

  @override
  String get modelEditGeminiThinkingModeLabel => 'Modalità di pensiero Gemini';

  @override
  String get modelEditInputModalitiesHint => 'Seleziona i tipi di input';

  @override
  String get modelEditInputModalitiesLabel => 'Modalità di ingresso';

  @override
  String get modelEditLoadError =>
      'Non è possibile caricare la configurazione del modello';

  @override
  String get modelEditMaxTokensHint =>
      'Facoltativo — lasciare vuoto per illimitato';

  @override
  String get modelEditMaxTokensLabel => 'Token di completamento massimo';

  @override
  String get modelEditModalityNoneSelected => 'Nessuno selezionato';

  @override
  String get modelEditOutputModalitiesHint => 'Seleziona i tipi di output';

  @override
  String get modelEditOutputModalitiesLabel => 'Modalità di produzione';

  @override
  String get modelEditPageTitle => 'Modifica del modello';

  @override
  String get modelEditProviderHint => 'Seleziona un fornitore';

  @override
  String get modelEditProviderLabel => 'Fornitore';

  @override
  String get modelEditProviderModelIdHint => 'ad esempio gpt-4-turbo';

  @override
  String get modelEditProviderModelIdLabel => 'Fornitore modello ID';

  @override
  String get modelEditReasoningDescription =>
      'Questo modello utilizza il pensiero esteso / catena di pensiero.';

  @override
  String get modelEditReasoningLabel => 'Modello motivante';

  @override
  String get modelEditSaveButton => 'Salva';

  @override
  String get modelEditSectionCapabilities => 'Capacità';

  @override
  String get modelEditSectionIdentity => 'Identità';

  @override
  String modelManagementSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'i',
      one: 'o',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'i',
      one: 'o',
    );
    return '$count modell$_temp0 selezionat$_temp1';
  }

  @override
  String get multiSelectAddButton => 'Aggiungi';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Aggiungi ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'Nessun articolo trovato';

  @override
  String get navSidebarManualBrowserHint => 'Si apre nel tuo browser';

  @override
  String get navSidebarManualLabel => 'Manuale';

  @override
  String navTabMoreSemanticsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Altro, $count destinazioni aggiuntive',
      one: 'Altro, 1 destinazione aggiuntiva',
    );
    return '$_temp0';
  }

  @override
  String get navTabTitleCalendar => 'Quotidiano';

  @override
  String get navTabTitleEvents => 'Eventi';

  @override
  String get navTabTitleHabits => 'Abitazioni';

  @override
  String get navTabTitleInsights => 'Analisi';

  @override
  String get navTabTitleJournal => 'Regime di registro';

  @override
  String get navTabTitleMore => 'Altro';

  @override
  String get navTabTitleProjects => 'Progetti';

  @override
  String get navTabTitleSettings => 'Impostazioni delle impostazioni';

  @override
  String get navTabTitleTasks => 'Compiti';

  @override
  String nestedAiResponsesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'e',
      one: 'a',
    );
    return '$count rispost$_temp0 IA';
  }

  @override
  String get noDefaultLanguage => 'Nessuna lingua predefinita';

  @override
  String get noTasksFound => 'Nessun compito trovato';

  @override
  String get noTasksToLink => 'Nessun compito disponibile per il collegamento';

  @override
  String get notificationBellEmptySemantics =>
      'Notifiche, non avvisi illeggibili';

  @override
  String get notificationBellTooltip => 'Notifica';

  @override
  String notificationBellUnseenSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'avvisi non letti',
      one: 'avviso non letto',
    );
    return 'Notifiche, $count $_temp0';
  }

  @override
  String get notificationInboxDismiss => 'Discorso della notifica';

  @override
  String get notificationInboxEmpty => 'Siete tutti coinvolti.';

  @override
  String get notificationInboxError => 'Non ho potuto caricare le notifiche.';

  @override
  String get notificationInboxTitle => 'Notifica';

  @override
  String get notificationSuggestionAttentionBodyFallback =>
      'Aprire il compito di rivedere.';

  @override
  String notificationSuggestionAttentionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suggerimenti bisogno della vostra attenzione',
      one: '1 suggerimento ha bisogno della vostra attenzione',
    );
    return '$_temp0';
  }

  @override
  String get onboardingApiKeyConnect => 'Collegamento';

  @override
  String get onboardingApiKeyConnecting => 'Collegamento...';

  @override
  String get onboardingApiKeyEnterKeyHint =>
      'Inserisci una chiave valida per continuare.';

  @override
  String get onboardingApiKeyError => 'Controlla la chiave e riprova.';

  @override
  String get onboardingApiKeyField => 'Chiave API';

  @override
  String get onboardingApiKeyGetKeyAt => 'Ottieni una chiave';

  @override
  String get onboardingApiKeyHide => 'Nascondi la chiave';

  @override
  String get onboardingApiKeyInvalid =>
      'Quella chiave è stata respinta, controllala e incollala di nuovo.';

  @override
  String get onboardingApiKeyLocalNote =>
      'Funziona sul tuo dispositivo — nessuna chiave necessaria.';

  @override
  String get onboardingApiKeyNoKeyHelp =>
      'Novità qui? Accedi, crea una chiave API, quindi incollalo — gratuito per iniziare.';

  @override
  String get onboardingApiKeyReveal => 'Mostra la chiave';

  @override
  String get onboardingApiKeyTitle => 'Incolla la chiave API';

  @override
  String onboardingApiKeyUnreachable(String providerName) {
    return 'Non è possibile raggiungere $providerName. Controllare la chiave o la connessione e riprovare.';
  }

  @override
  String get onboardingApiKeyVerifying => 'Verificare...';

  @override
  String get onboardingCaptureCategoryPrompt =>
      'Dove dovrebbe essere questa terra?';

  @override
  String get onboardingCaptureListening => 'Ascolta... tocca quando hai finito';

  @override
  String get onboardingCaptureOrbLabel => 'Registra il tuo pensiero';

  @override
  String get onboardingCaptureRatherType => 'Piuttosto tipo?';

  @override
  String get onboardingCaptureReassurance =>
      'Sarai in grado di modificare tutto dopo.';

  @override
  String get onboardingCaptureThinking =>
      'Trasformare le tue parole in un compito...';

  @override
  String get onboardingCaptureTypePrompt => 'Scrivi il tuo pensiero';

  @override
  String get onboardingCategoryAddOwn => 'Aggiungi il tuo';

  @override
  String get onboardingCategoryContinue => 'Continua';

  @override
  String get onboardingCategoryExplanation =>
      'Ogni area della vostra vita ottiene il proprio spazio. Scegli qualsiasi che si adatta — o aggiungere il proprio.';

  @override
  String get onboardingCategoryFamily => 'Famiglia';

  @override
  String get onboardingCategoryFitness => 'Forma fisica';

  @override
  String get onboardingCategoryFriends => 'Amici';

  @override
  String get onboardingCategoryTitle =>
      'Dove dovrebbe funzionare l\'intelligenza artificiale?';

  @override
  String get onboardingCategoryWhy => 'Perché le aree?';

  @override
  String onboardingCategoryWhyDetail(String provider) {
    return 'Ogni area può utilizzare la propria AI. $provider alimenterà le aree che si sceglie qui - in seguito è possibile dare diverse aree AI differenti.';
  }

  @override
  String get onboardingCategoryWork => 'Lavoro';

  @override
  String get onboardingConnectGeminiName => 'Gemini';

  @override
  String get onboardingConnectGeminiTagline => 'Stati Uniti';

  @override
  String get onboardingConnectLessOptions => 'Opzioni minori';

  @override
  String get onboardingConnectMistralName => 'Mistral';

  @override
  String get onboardingConnectMistralTagline => 'Unione europea';

  @override
  String get onboardingConnectMoreOptions => 'Altre opzioni';

  @override
  String get onboardingConnectNotSure =>
      'Melious.ai è il default raccomandato.';

  @override
  String get onboardingConnectOllamaName => 'Ollama';

  @override
  String get onboardingConnectOpenAiName => 'OpenAI';

  @override
  String get onboardingConnectQwenName => 'Qwen';

  @override
  String get onboardingConnectQwenTagline => 'Cina';

  @override
  String get onboardingConnectTitle =>
      'Scegli il cervello AI per i tuoi compiti';

  @override
  String get onboardingFirstTaskCreatedHint =>
      'Tocca il tuo compito per aprirlo';

  @override
  String get onboardingFirstTaskCreatedTitle => 'Il tuo primo compito è pronto';

  @override
  String get onboardingFirstTaskGuidance =>
      'Toccare per parlare e dire ciò che ha bisogno di fare — Lotti lo trasforma in un vero compito.';

  @override
  String get onboardingFirstTaskSuggestionDentist =>
      'Prenota un appuntamento con il dentista';

  @override
  String get onboardingFirstTaskSuggestionMeeting =>
      'Preparatevi per l\'incontro di lunedì';

  @override
  String get onboardingFirstTaskSuggestionPlanWeek =>
      'Organizza la mia settimana';

  @override
  String get onboardingFirstTaskSuggestionsLabel =>
      'Non sei pronto a parlare? Inizia con uno di questi:';

  @override
  String get onboardingFirstTaskTitle => 'Crea il tuo primo compito';

  @override
  String get onboardingMetricsActiveDays => 'Giorni attivi';

  @override
  String get onboardingMetricsActiveDaysInFirstSeven =>
      'Giorni attivi nei primi 7';

  @override
  String get onboardingMetricsBaselineCohort => 'Coorte base (pre-FTUE)';

  @override
  String get onboardingMetricsInstallFirstSeenUtc =>
      'Installare prima vista (UTC)';

  @override
  String get onboardingMetricsNo => 'No.';

  @override
  String get onboardingMetricsReachedRealAha => 'Raggiungere l\'aha reale';

  @override
  String get onboardingMetricsYes => 'Sì.';

  @override
  String get onboardingRecordingStyleAnalogue => 'Analoga — Misuratore di VU';

  @override
  String get onboardingRecordingStyleContinue => 'Continua';

  @override
  String get onboardingRecordingStyleExplanation =>
      'Scegli un\'occhiata al microfono, puoi cambiarlo in qualsiasi momento in Impostazioni.';

  @override
  String get onboardingRecordingStyleModern => 'Moderno — energia orb';

  @override
  String get onboardingRecordingStyleTitle =>
      'Come dovrebbe la registrazione sentire?';

  @override
  String get onboardingRecordingStyleTryVoice => 'Prova con la tua voce';

  @override
  String get onboardingSuccessContinue => 'Iniziare';

  @override
  String get onboardingSuccessSubtitle =>
      'Il vostro cervello AI è collegato e pronto a trasformare le vostre parole in compiti.';

  @override
  String get onboardingSuccessTitle => 'Sei tutto pronto.';

  @override
  String get onboardingWelcomeConnectButton => 'Scegli il tuo cervello AI';

  @override
  String get onboardingWelcomeMessage =>
      'Collegare il vostro cervello AI, poi parlare un pensiero e guardarlo diventare un compito strutturato.';

  @override
  String get onboardingWelcomeSkipButton => 'Guarda prima.';

  @override
  String get onboardingWelcomeTitle => 'Lotti lo trasforma in un piano.';

  @override
  String get optionalCategoryLabel => 'Categoria (opzionale)';

  @override
  String get outboxActionRemove => 'Rimuovi';

  @override
  String get outboxActionRetry => 'Recuperare';

  @override
  String get outboxFailedReassurance =>
      'Ancora salvato su questo dispositivo — si sincronizzerà una volta che il problema si schiarisce.';

  @override
  String get outboxFilterFailed => 'Fatta.';

  @override
  String get outboxFilterWaiting => 'Aspettare';

  @override
  String get outboxMonitorAttachmentLabel => 'Allegati';

  @override
  String get outboxMonitorDelete => 'Cancella';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Cancella';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      'Sei sicuro di voler eliminare questa voce di sincronizzazione? Questa azione non può essere annullata.';

  @override
  String get outboxMonitorDeleteFailed =>
      'Elimina fallita, per favore riprova.';

  @override
  String get outboxMonitorDeleteSuccess => 'Articolo cancellato';

  @override
  String get outboxMonitorEmptyDescription =>
      'Non ci sono elementi di sincronizzazione in questa vista.';

  @override
  String get outboxMonitorEmptyTitle => 'La casella di posta è chiara';

  @override
  String get outboxMonitorFetchFailed =>
      'Non ho potuto caricare la casella di posta, tira per rinfrescare e riprovare.';

  @override
  String get outboxMonitorLabelError => 'errore';

  @override
  String get outboxMonitorLabelPending => 'in sospeso';

  @override
  String get outboxMonitorLabelSent => 'inviato';

  @override
  String get outboxMonitorLabelSuccess => 'successo';

  @override
  String get outboxMonitorNoAttachment => 'nessun allegato';

  @override
  String get outboxMonitorPayloadSizeLabel => 'Dimensione';

  @override
  String get outboxMonitorRetries => 'Restrizioni';

  @override
  String get outboxMonitorRetriesLabel => 'Restrizioni';

  @override
  String get outboxMonitorRetry => 'Retribuzioni';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Recuperare ora';

  @override
  String get outboxMonitorRetryConfirmMessage =>
      'Recuperare questo articolo di sincronizzazione ora?';

  @override
  String get outboxMonitorRetryFailed =>
      'Il nuovo tentativo non è riuscito. Riprova.';

  @override
  String get outboxMonitorRetryQueued => 'Recuperare programmato';

  @override
  String get outboxMonitorSubjectLabel => 'Oggetto';

  @override
  String get outboxMonitorVolumeChartTitle =>
      'Volume di sincronizzazione giornaliero';

  @override
  String get outboxRemoveConfirmMessage =>
      'Questo cambiamento non è ancora sincronizzato. Rimuoverlo qui significa che non raggiungerà gli altri dispositivi.';

  @override
  String get outboxRemoveConfirmTitle => 'Rimuovere dalla coda?';

  @override
  String get outboxRetryAll => 'Recuperare tutti';

  @override
  String get outboxShowDetails => 'Mostra dettagli tecnici';

  @override
  String get outboxStatusFailed => 'Non potevo mandare';

  @override
  String get outboxStatusSending => 'Inviare';

  @override
  String get outboxStatusSent => 'Inviato';

  @override
  String get outboxStatusWaiting => 'In attesa di inviare';

  @override
  String outboxSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articoli non potevano inviare',
      one: '1 elemento non poteva inviare',
    );
    return '$_temp0';
  }

  @override
  String outboxSummaryOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi verranno inviati quando ti riconnetterai',
      one: '1 elemento verrà inviato quando ti riconnetterai',
    );
    return '$_temp0';
  }

  @override
  String outboxSummarySending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Invio di $count elementi…',
      one: 'Invio di 1 elemento…',
    );
    return '$_temp0';
  }

  @override
  String get outboxSummarySynced => 'Tutto è sincronizzato';

  @override
  String outboxSummaryWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articoli in attesa di inviare',
      one: '1 elemento in attesa di inviare',
    );
    return '$_temp0';
  }

  @override
  String outboxTriedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tentato $count volte',
      one: 'Tentato una volta',
    );
    return '$_temp0';
  }

  @override
  String get panasCompletionText => 'Grazie per aver riempito i PANAS!';

  @override
  String get panasCompletionTitle => 'Finito';

  @override
  String get panasEmotionActive => 'Attivo';

  @override
  String get panasEmotionAfraid => 'Paura';

  @override
  String get panasEmotionAlert => 'Avviso';

  @override
  String get panasEmotionAshamed => 'Vergognoso';

  @override
  String get panasEmotionAttentive => 'Attentivo';

  @override
  String get panasEmotionDetermined => 'Determinazione';

  @override
  String get panasEmotionDistressed => 'In difficoltà';

  @override
  String get panasEmotionEnthusiastic => 'Enthusiasta';

  @override
  String get panasEmotionExcited => 'Eccitato';

  @override
  String get panasEmotionGuilty => 'Colpevole';

  @override
  String get panasEmotionHostile => 'Ostacolo';

  @override
  String get panasEmotionInspired => 'Ispirato';

  @override
  String get panasEmotionInterested => 'Interessi';

  @override
  String get panasEmotionIrritable => 'Irritabile';

  @override
  String get panasEmotionJittery => 'Agitato';

  @override
  String get panasEmotionNervous => 'Nervosa';

  @override
  String get panasEmotionProud => 'Proudo';

  @override
  String get panasEmotionScared => 'Spaventato';

  @override
  String get panasEmotionStrong => 'Forte';

  @override
  String get panasEmotionUpset => 'Impostazione';

  @override
  String get panasInstructionFootnote =>
      'Watson, D., Clark, L. A., & Tellegen, A. (1988). Sviluppo e convalida di brevi misure di impatto positivo e negativo: Le scale PANAS. Journal of Personality and Social Psychology, 54(6), 1063-1070.';

  @override
  String get panasInstructionText =>
      '1—Molto leggermente o non affatto, 2—Un po\', 3—Moderatamente, 4—Quite un po\', 5—Extremely';

  @override
  String get panasInstructionTitle =>
      'Il programma Positivo e Negativo Affect (PANAS; Watson et al., 1988)';

  @override
  String get panasScaleALittle => 'Un po\'.';

  @override
  String get panasScaleExtremely => 'Estrema';

  @override
  String get panasScaleModerately => 'Moderatamente';

  @override
  String get panasScaleQuiteABit => 'Un po\' troppo.';

  @override
  String get panasScaleVerySlightlyOrNotAtAll =>
      'Molto leggermente o non affatto';

  @override
  String get privateLabel => 'Privato';

  @override
  String get privateSwitchDescription =>
      'Solo visibile quando vengono mostrate le voci private';

  @override
  String get projectAgentNotProvisioned =>
      'Nessun agente di progetto è stato fornito per questo progetto ancora.';

  @override
  String get projectAgentSectionTitle => 'Agente';

  @override
  String projectCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count progetti',
      one: '$count progetto',
    );
    return '$_temp0';
  }

  @override
  String get projectCreateButton => 'Nuovo progetto';

  @override
  String get projectCreateTitle => 'Creare un progetto';

  @override
  String get projectDetailTitle => 'Dettagli del progetto';

  @override
  String get projectErrorCreateFailed => 'Progetto di creazione di errori.';

  @override
  String get projectErrorLoadFailed => 'Non ha caricato i dati del progetto.';

  @override
  String get projectErrorLoadProjects => 'Progetti di caricamento di errori';

  @override
  String get projectErrorUpdateFailed =>
      'Non è riuscito ad aggiornare il progetto. Si prega di riprovare.';

  @override
  String get projectFilterLabel => 'Progetto';

  @override
  String get projectHealthBandAtRisk => 'A Risk';

  @override
  String get projectHealthBandBlocked => 'Bloccato';

  @override
  String get projectHealthBandOnTrack => 'Sulla pista';

  @override
  String get projectHealthBandSurviving => 'Sopravvivere';

  @override
  String get projectHealthBandWatch => 'Guarda qui';

  @override
  String get projectHealthSectionTitle => 'Salute del progetto';

  @override
  String projectHealthSummary(int projectCount, int taskCount) {
    String _temp0 = intl.Intl.pluralLogic(
      projectCount,
      locale: localeName,
      other: '$projectCount progetti',
      one: '$projectCount progetto',
    );
    String _temp1 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: '$taskCount attività',
      one: '$taskCount attività',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get projectHealthTitle => 'Progetti';

  @override
  String projectLinkedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count compiti collegati',
      one: '$count attività collegata',
    );
    return '$_temp0';
  }

  @override
  String get projectLinkedTasks => 'Compiti collegati';

  @override
  String get projectManageTooltip => 'Gestione dei progetti';

  @override
  String get projectNoLinkedTasks => 'Nessun compito ancora collegato';

  @override
  String get projectNoProjects => 'Nessun progetto ancora';

  @override
  String get projectNotFound => 'Progetto non trovato';

  @override
  String get projectPickerLabel => 'Progetto';

  @override
  String get projectPickerUnassigned => 'Nessun progetto';

  @override
  String get projectRecommendationDismissTooltip => 'Discorso';

  @override
  String get projectRecommendationResolveTooltip => 'Mark risolto';

  @override
  String get projectRecommendationsTitle => 'Prossimi passi consigliati';

  @override
  String get projectRecommendationUpdateError =>
      'Non ho potuto aggiornare la raccomandazione, si prega di riprovare.';

  @override
  String get projectsFilterStatusLabel => 'Stato:';

  @override
  String get projectsFilterTooltip => 'Progetti di filtrazione';

  @override
  String get projectShowcaseAiReportTitle => 'Rapporto AI';

  @override
  String projectShowcaseBlockedLegend(int count) {
    return '$count bloccata';
  }

  @override
  String projectShowcaseBlockedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count: attività bloccate',
      one: '$count task bloccato',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseCompletedLegend(int count) {
    return '$count completato';
  }

  @override
  String get projectShowcaseDescriptionTitle => 'Designazione';

  @override
  String projectShowcaseDueDate(String date) {
    return 'Scadenza: $date';
  }

  @override
  String get projectShowcaseHealthScoreDescription =>
      'Questo punteggio si basa sulla velocità delle attività, i bloccanti e il tempo lasciato alla scadenza.';

  @override
  String get projectShowcaseHealthScoreTitle => 'Punteggio della salute';

  @override
  String get projectShowcaseNoResults =>
      'Nessun progetto corrisponde alla tua ricerca.';

  @override
  String get projectShowcaseOneOnOneReviewsTab => 'One-on-one Recensioni';

  @override
  String get projectShowcaseOngoing => 'In corso';

  @override
  String get projectShowcaseProjectTasksTab => 'Compiti del progetto';

  @override
  String get projectShowcaseSearchHint => 'Progetti di ricerca';

  @override
  String projectShowcaseSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessioni',
      one: '$count sessione',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseTasksCompleted(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$completed/$total attività completate',
      one: '$completed/$total attività completata',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseUpdatedHoursAgo(int hours) {
    return 'Aggiornato ${hours}h fa  ⁇ ';
  }

  @override
  String projectShowcaseUpdatedMinutesAgo(int minutes) {
    return 'Aggiornato ${minutes}m fa  ⁇ ';
  }

  @override
  String get projectShowcaseUsefulness => 'Utilenza';

  @override
  String get projectShowcaseViewBlocker => 'Visualizza blocco';

  @override
  String get projectStatusActive => 'Attivo';

  @override
  String get projectStatusArchived => 'Archivio';

  @override
  String get projectStatusChangeTitle => 'Cambia lo stato';

  @override
  String get projectStatusCompleted => 'Completo';

  @override
  String get projectStatusMonitoring => 'Monitoraggio';

  @override
  String get projectStatusOnHold => 'Aspetta.';

  @override
  String get projectStatusOpen => 'Aprire';

  @override
  String get projectSummaryOutdated => 'Sommario obsoleto.';

  @override
  String projectSummaryOutdatedScheduled(String date, String time) {
    return 'Riepilogo aggiornato. Prossimo aggiornamento $date a $time.';
  }

  @override
  String get projectTargetDateLabel => 'Data di destinazione';

  @override
  String get projectTitleLabel => 'Titolo del progetto';

  @override
  String get projectTitleRequired =>
      'Il titolo del progetto non può essere vuoto';

  @override
  String get promptDefaultModelBadge => 'Predefinito';

  @override
  String get promptGenerationCardTitle => 'Prompettore di codifica AI';

  @override
  String get promptGenerationCopiedSnackbar => 'Prompt copiato a clipboard';

  @override
  String get promptGenerationCopyButton => 'Copia Prompt';

  @override
  String get promptGenerationCopyTooltip => 'Copia il prompt per il clipboard';

  @override
  String get promptGenerationExpandTooltip => 'Mostra il prompt completo';

  @override
  String get promptGenerationFullPromptLabel => 'Prompt completo:';

  @override
  String get promptSelectionModalTitle => 'Selezionare Prompt preconfigurato';

  @override
  String get provisionedSyncBundleImported => 'Codice di previsione importato';

  @override
  String get provisionedSyncConfigureButton => 'Configurazione';

  @override
  String get provisionedSyncCopiedToClipboard => 'Copiato negli appunti';

  @override
  String get provisionedSyncDisconnect => 'Scollegamento';

  @override
  String get provisionedSyncDone => 'Sincronizzazione configurata con successo';

  @override
  String get provisionedSyncError => 'Configurazione fallita';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'Si è verificato un errore durante la configurazione. Si prega di riprovare.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'Login fallito. Controllare le credenziali e riprovare.';

  @override
  String get provisionedSyncImportButton => 'Importazioni';

  @override
  String get provisionedSyncImportHint => 'Incolla codice di provisioning qui';

  @override
  String get provisionedSyncImportTitle => 'Configurazione di sincronizzazione';

  @override
  String get provisionedSyncInvalidBundle => 'Codice di fornitura non valido';

  @override
  String get provisionedSyncJoiningRoom => 'Unisciti alla sincronia...';

  @override
  String get provisionedSyncLoggingIn => 'Accesso in corso...';

  @override
  String get provisionedSyncPasteClipboard => 'Incolla da appunti';

  @override
  String get provisionedSyncReady =>
      'Scansiona questo codice QR sul tuo dispositivo mobile';

  @override
  String get provisionedSyncRetry => 'Recuperare';

  @override
  String get provisionedSyncRotatingPassword => 'Impostazione del conto...';

  @override
  String get provisionedSyncScanButton => 'Scansione del codice QR';

  @override
  String get provisionedSyncShowQr => 'Mostrare il QR provisioning';

  @override
  String get provisionedSyncSubtitle =>
      'Impostare la sincronizzazione da un bundle di provisioning';

  @override
  String get provisionedSyncSummaryHomeserver => 'Server domestico';

  @override
  String get provisionedSyncSummaryRoom => 'Camera';

  @override
  String get provisionedSyncSummaryUser => 'Utente';

  @override
  String get provisionedSyncTitle => 'Sincronizzazione prevista';

  @override
  String get provisionedSyncVerifyDevicesTitle => 'Verifica del dispositivo';

  @override
  String get queueCatchUpNowButton => 'Prenditi ora';

  @override
  String get queueCatchUpNowDone => 'Prendere a calci — la coda sta drenando.';

  @override
  String queueCatchUpNowError(String reason) {
    return 'Il catch-up non è riuscito: $reason';
  }

  @override
  String get queueDepthCardEmpty =>
      'Queue vuoto — il lavoratore è preso in su.';

  @override
  String get queueDepthCardLoading => 'Leggere la profondità della coda...';

  @override
  String get queueDepthCardTitle => 'La coda in entrata';

  @override
  String get queueFetchAllHistoryCancel => 'Annullamento';

  @override
  String queueFetchAllHistoryCancelled(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events eventi',
      one: '1 evento',
      zero: 'nessun evento',
    );
    return 'Annullato — $_temp0 recuperati finora.';
  }

  @override
  String get queueFetchAllHistoryClose => 'Chiudere';

  @override
  String get queueFetchAllHistoryDescription =>
      'Cammina tutta la storia visibile della stanza nella coda. Sicuro per annullare; un secondo run riprende da dove l\'impaginazione si è fermata.';

  @override
  String queueFetchAllHistoryDone(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages pagine',
      one: '1 pagina',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages pagine',
      one: '1 pagina',
    );
    String _temp2 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events eventi recuperati in $_temp0.',
      one: '1 evento recuperato in $_temp1.',
      zero: 'Nessun evento recuperato.',
    );
    return '$_temp2';
  }

  @override
  String queueFetchAllHistoryError(String reason) {
    return 'Fermata: $reason';
  }

  @override
  String get queueFetchAllHistoryErrorUnknown =>
      'Fetch si e\' fermato inaspettatamente.';

  @override
  String queueFetchAllHistoryProgress(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: 'Pagina $pages · $events eventi recuperati',
      one: 'Pagina $pages · 1 evento recuperato',
    );
    return '$_temp0';
  }

  @override
  String get queueFetchAllHistoryTitle => 'Storie di cattura';

  @override
  String queueSkippedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saltato',
      one: '1 saltato',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedCardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count sincronizza gli eventi che la coda ha rinunciato. Toccare la re-attempt.',
      one:
          '1 sincronizzazione della coda ha rinunciato. Toccare la rettiva per re-attempt.',
    );
    return '$_temp0';
  }

  @override
  String get queueSkippedCardTitle => 'Eventi sportivi';

  @override
  String get queueSkippedRetryAll => 'Riprovare gli eventi saltati';

  @override
  String queueSkippedRetryAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventi in coda per un nuovo tentativo.',
      one: '1 evento in coda per un nuovo tentativo.',
      zero: 'Nessun evento ignorato da ritentare.',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedRetryAllError(String reason) {
    return 'Nuovo tentativo non riuscito: $reason';
  }

  @override
  String get referenceImageContinue => 'Continua';

  @override
  String referenceImageContinueWithCount(int count) {
    return 'Continua ($count)';
  }

  @override
  String get referenceImageLoadError =>
      'Non ha caricato le immagini. Si prega di riprovare.';

  @override
  String get referenceImageSelectionSubtitle =>
      'Scegli fino a 5 immagini per guidare lo stile visivo dell\'AI';

  @override
  String get referenceImageSelectionTitle =>
      'Seleziona le immagini di riferimento';

  @override
  String get referenceImageSkip => 'Salta!';

  @override
  String get saveButton => 'Salva';

  @override
  String get saveButtonLabel => 'Salva';

  @override
  String get saveLabel => 'Salva';

  @override
  String get saveShortcutTooltip => 'Salva — Ctrl+S (⌘S su Mac)';

  @override
  String get saveSuccessful => 'Salvataggio con successo';

  @override
  String get searchHint => 'Cerca...';

  @override
  String get searchModeFullText => 'Testo completo';

  @override
  String get searchModeVector => 'Vettore';

  @override
  String get searchTasksHint => 'Compiti di ricerca...';

  @override
  String get selectButton => 'Seleziona';

  @override
  String get selectColor => 'Seleziona un colore';

  @override
  String get selectLanguage => 'Seleziona la lingua';

  @override
  String get sessionRatingCardLabel => 'Valutazione della sessione';

  @override
  String get sessionRatingChallengeJustRight => 'Giusto.';

  @override
  String get sessionRatingChallengeTooEasy => 'Troppo facile.';

  @override
  String get sessionRatingChallengeTooHard => 'Troppo impegnativo';

  @override
  String get sessionRatingDifficultyLabel => 'Questo lavoro si sentiva...';

  @override
  String get sessionRatingEditButton => 'Modifica della valutazione';

  @override
  String get sessionRatingEnergyQuestion => 'Quanto ti sei sentita eccitata?';

  @override
  String get sessionRatingFocusQuestion => 'Quanto eri concentrato?';

  @override
  String get sessionRatingNoteHint => 'Nota rapida (opzionale)';

  @override
  String get sessionRatingProductivityQuestion =>
      'Quanto è stato produttivo questa sessione?';

  @override
  String get sessionRatingRateAction => 'Sessione di tasso';

  @override
  String get sessionRatingSaveButton => 'Salva';

  @override
  String get sessionRatingSaveError =>
      'Non è riuscito a salvare la valutazione. Si prega di riprovare.';

  @override
  String get sessionRatingSkipButton => 'Salta!';

  @override
  String get sessionRatingTitle => 'Valutare questa sessione';

  @override
  String get sessionRatingViewAction => 'Visualizza la valutazione';

  @override
  String get settingsAboutAppInformation => 'Informazioni sull\'app';

  @override
  String get settingsAboutAppTagline => 'Il tuo giornale personale';

  @override
  String get settingsAboutBuildType => 'Tipo di costruzione';

  @override
  String get settingsAboutDailyOsPersonalizationTitle =>
      'Personalizzazione del sistema operativo giornaliero';

  @override
  String get settingsAboutDailyOsUserNameHelper =>
      'Usato per il saluto del Daily OS e sincronizzato attraverso i dispositivi.';

  @override
  String get settingsAboutDailyOsUserNameLabel => 'Il tuo nome';

  @override
  String get settingsAboutJournalEntries => 'Pubblicazioni';

  @override
  String get settingsAboutPlatform => 'Piattaforma';

  @override
  String get settingsAboutTitle => 'A proposito di Lotti';

  @override
  String get settingsAboutVersion => 'Versione';

  @override
  String get settingsAboutYourData => 'I tuoi dati';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'Scopri di più sull\'applicazione Lotti';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Importare dati relativi alla salute da fonti esterne';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Eseguire le attività di manutenzione per ottimizzare le prestazioni delle applicazioni';

  @override
  String get settingsAdvancedManualLanguageSubtitle =>
      'Scegli in quale lingua aprire il Manuale Lotti';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Gestisci gli elementi di sincronizzazione';

  @override
  String get settingsAdvancedSubtitle => 'Impostazioni e manutenzione avanzate';

  @override
  String get settingsAdvancedTitle => 'Impostazioni avanzate';

  @override
  String get settingsAgentsInstancesSubtitle => 'Agenti in esecuzione';

  @override
  String get settingsAgentsPendingWakesSubtitle =>
      'Temporizzatori di veglia programmati';

  @override
  String get settingsAgentsSoulsSubtitle =>
      'Personaggi di agente di lunga durata';

  @override
  String get settingsAgentsStatsSubtitle => 'Utilizzo e attività di Token';

  @override
  String get settingsAgentsTemplatesSubtitle =>
      'Analizzazioni di agente condiviso';

  @override
  String get settingsAiModelsSubtitle =>
      'Per-provider righe e funzionalità del modello';

  @override
  String get settingsAiModelsTitle => 'Modelli';

  @override
  String get settingsAiProfilesSubtitle => 'Fornitori e modelli';

  @override
  String get settingsAiProfilesTitle => 'Profili di inferenza';

  @override
  String get settingsAiProvidersSubtitle =>
      'Fornitori e chiavi di AI collegati';

  @override
  String get settingsAiProvidersTitle => 'Fornitori';

  @override
  String get settingsAiSubtitle =>
      'Configurare i fornitori di AI, i modelli e le richieste';

  @override
  String get settingsAiTitle => 'Impostazioni dell\'intelligenza';

  @override
  String get settingsAiUsageSubtitle =>
      'Costo, energia e CO2e delle chiamate AI';

  @override
  String get settingsAiUsageTitle => 'Utilizzo e impatto';

  @override
  String get settingsBeamPageEditModelTitle => 'Modifica modello';

  @override
  String get settingsBeamPageEditProfileTitle => 'Modifica profilo';

  @override
  String get settingsCategoriesCreateTitle => 'Creare una categoria';

  @override
  String get settingsCategoriesDetailsLabel => 'Modifica della categoria';

  @override
  String get settingsCategoriesEmptyState => 'Nessuna categoria ancora';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Crea una categoria per organizzare le tue voci';

  @override
  String get settingsCategoriesErrorLoading =>
      'Categorie di caricamento degli errori';

  @override
  String get settingsCategoriesNameLabel => 'Nome della categoria';

  @override
  String settingsCategoriesNoMatchQuery(String query) {
    return 'Nessuna categoria corrisponde \"$query\"';
  }

  @override
  String get settingsCategoriesSearchHint => 'Cerca le categorie...';

  @override
  String get settingsCategoriesSubtitle => 'Categorie con impostazioni AI';

  @override
  String settingsCategoriesTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attività',
      one: '$count attività',
    );
    return '$_temp0';
  }

  @override
  String get settingsCategoriesTitle => 'Categorie';

  @override
  String get settingsCelebrationsChecklistDescription =>
      'Un pop e scintille quando si controlla un prodotto spento';

  @override
  String get settingsCelebrationsChecklistTitle => 'Elenco dei prodotti';

  @override
  String get settingsCelebrationsCustomizeTitle => 'Personalizzarsi';

  @override
  String get settingsCelebrationsCustomizeTooltip =>
      'Personalizza questo stile';

  @override
  String get settingsCelebrationsEnabledDescription =>
      'L\'interruttore principale per il completamento fiorisce. Off nasconde ogni animazione; l\'ottica mantiene il proprio interruttore.';

  @override
  String get settingsCelebrationsEnabledTitle => 'Animazioni di celebrazione';

  @override
  String get settingsCelebrationsGroupLook => 'Guarda.';

  @override
  String get settingsCelebrationsGroupMotion => 'Motivazione';

  @override
  String get settingsCelebrationsGroupShape => 'Forma';

  @override
  String get settingsCelebrationsHabitsDescription =>
      'Glow e scintille quando si completa un\'abitudine';

  @override
  String get settingsCelebrationsHabitsTitle => 'Abitazioni';

  @override
  String get settingsCelebrationsHapticsDescription =>
      'Un breve ronzio quando si finisce qualcosa — indipendente dall\'animazione.';

  @override
  String get settingsCelebrationsHapticsTitle => 'Setttica di completamento';

  @override
  String get settingsCelebrationsKnobClearCenter => 'Lacuna centrale';

  @override
  String get settingsCelebrationsKnobCount => 'Particelle';

  @override
  String get settingsCelebrationsKnobDescClearCenter =>
      'Spazio vuoto al centro';

  @override
  String get settingsCelebrationsKnobDescCount =>
      'Quante particelle volano fuori';

  @override
  String get settingsCelebrationsKnobDescFallout =>
      'Fino a che punto le scintille si allontanano';

  @override
  String get settingsCelebrationsKnobDescFanSpread =>
      'Larghezza del ventilatore';

  @override
  String get settingsCelebrationsKnobDescGlow => 'Forza del bagliore';

  @override
  String get settingsCelebrationsKnobDescGravity =>
      'Come cadere rapidamente le particelle';

  @override
  String get settingsCelebrationsKnobDescHalo => 'La forza dell\'alo';

  @override
  String get settingsCelebrationsKnobDescInnerRing =>
      'Dimensione dell\'anello interno';

  @override
  String get settingsCelebrationsKnobDescLaunch =>
      'Ritardo prima dell\'esplosione';

  @override
  String get settingsCelebrationsKnobDescPop => '# When they pop #';

  @override
  String get settingsCelebrationsKnobDescReach =>
      'Quanto lontano viaggiano le particelle';

  @override
  String get settingsCelebrationsKnobDescRise =>
      'Come aumentano le particelle elevate';

  @override
  String get settingsCelebrationsKnobDescSize =>
      'Quanto grande ogni particella è';

  @override
  String get settingsCelebrationsKnobDescSpeedSpread =>
      'Variazione della velocità delle particelle';

  @override
  String get settingsCelebrationsKnobDescSpin =>
      'Come si girano i pezzi veloci';

  @override
  String get settingsCelebrationsKnobDescSpread => 'Larghezza dello spray';

  @override
  String get settingsCelebrationsKnobDescSway => 'Quanti pezzi scorrono';

  @override
  String get settingsCelebrationsKnobDescSwell => 'Quanto crescono';

  @override
  String get settingsCelebrationsKnobDescTrail => 'Lunghezza di ogni sentiero';

  @override
  String get settingsCelebrationsKnobDescTwinkle =>
      'Quante particelle sfarfallio';

  @override
  String get settingsCelebrationsKnobDescUpward => 'Come si alzano forte';

  @override
  String get settingsCelebrationsKnobDescWobble => 'Quanti pezzi wobble';

  @override
  String get settingsCelebrationsKnobFallout => 'Fallimento';

  @override
  String get settingsCelebrationsKnobFanSpread => 'Diffusore del ventilatore';

  @override
  String get settingsCelebrationsKnobGlow => 'Glow.';

  @override
  String get settingsCelebrationsKnobGravity => 'Gravità';

  @override
  String get settingsCelebrationsKnobHalo => 'Halo.';

  @override
  String get settingsCelebrationsKnobInnerRing => 'Anello interno';

  @override
  String get settingsCelebrationsKnobLaunch => 'Tempo di lancio';

  @override
  String get settingsCelebrationsKnobPop => 'Punto di partenza';

  @override
  String get settingsCelebrationsKnobReach => 'Raggiungere';

  @override
  String get settingsCelebrationsKnobRise => 'Altezza del rialzo';

  @override
  String get settingsCelebrationsKnobSize => 'Dimensione';

  @override
  String get settingsCelebrationsKnobSpeedSpread => 'Variazione della velocità';

  @override
  String get settingsCelebrationsKnobSpin => 'Spingi';

  @override
  String get settingsCelebrationsKnobSpread => 'Arco di dispersione';

  @override
  String get settingsCelebrationsKnobSway => 'Oscillazione';

  @override
  String get settingsCelebrationsKnobSwell => 'Bene.';

  @override
  String get settingsCelebrationsKnobTrail => 'Lunghezza del sentiero';

  @override
  String get settingsCelebrationsKnobTwinkle => 'Doppia';

  @override
  String get settingsCelebrationsKnobUpward => 'Risalire';

  @override
  String get settingsCelebrationsKnobWobble => 'Dondolio';

  @override
  String get settingsCelebrationsPlaygroundHint =>
      'Toccare la riga evidenziata per l\'anteprima';

  @override
  String get settingsCelebrationsPlaygroundLiveNote =>
      'Cambiamenti salvare e applicare ovunque istantaneamente';

  @override
  String get settingsCelebrationsPreviewChecklistItem => 'Controllami.';

  @override
  String get settingsCelebrationsPreviewDescription =>
      'Toccare un controllo per giocare il tuo stile selezionato.';

  @override
  String get settingsCelebrationsPreviewDone => 'Fatto';

  @override
  String get settingsCelebrationsPreviewHabit => 'Abitazioni';

  @override
  String get settingsCelebrationsPreviewSample1 => 'Mattina a piedi';

  @override
  String get settingsCelebrationsPreviewSample2 => 'Termina il rapporto';

  @override
  String get settingsCelebrationsPreviewSample3 => 'Acquare le piante';

  @override
  String get settingsCelebrationsPreviewTitle => 'Provalo.';

  @override
  String get settingsCelebrationsReplay => 'Riproduci';

  @override
  String get settingsCelebrationsResetToast =>
      'Ripristino stile per impostazione predefinita';

  @override
  String get settingsCelebrationsResetToDefault => 'Ripristino di default';

  @override
  String get settingsCelebrationsResetUndo => 'Annulla';

  @override
  String get settingsCelebrationsSectionDescription =>
      'Suona un fiore quando finisci qualcosa. Interruttore uno spegnimento mantiene il completamento e il suo haptico — basta saltare l\'animazione.';

  @override
  String get settingsCelebrationsSectionTitle =>
      'Celebrazioni di completamento';

  @override
  String get settingsCelebrationsStyleDescription =>
      'Toccare una carta per visualizzare in anteprima uno stile di celebrazione e renderlo tuo.';

  @override
  String get settingsCelebrationsStyleTitle => 'Stile';

  @override
  String get settingsCelebrationsSubtitle => 'Celebrazioni di completamento';

  @override
  String get settingsCelebrationsTasksDescription =>
      'Bagliori e scintille quando un\'attività viene completata';

  @override
  String get settingsCelebrationsTasksTitle => 'Compiti';

  @override
  String get settingsCelebrationsTitle => 'Animazione';

  @override
  String get settingsCelebrationsVariantBubbles => 'Bolle';

  @override
  String get settingsCelebrationsVariantCombine => 'Combina due';

  @override
  String get settingsCelebrationsVariantCombineDescription =>
      'Due stili casuali, stratificato, ogni volta';

  @override
  String get settingsCelebrationsVariantConfetti => 'Coriandoli';

  @override
  String get settingsCelebrationsVariantEmbers => 'Legname';

  @override
  String get settingsCelebrationsVariantFireworks => 'Fuochi d\'artificio';

  @override
  String get settingsCelebrationsVariantRandom => 'Casuale';

  @override
  String get settingsCelebrationsVariantRandomDescription =>
      'Uno stile fresco ad ogni completamento';

  @override
  String get settingsCelebrationsVariantSparks => 'Scintille';

  @override
  String get settingsConflictsTitle => 'Conflitti di sincronizzazione';

  @override
  String get settingsDashboardDetailsLabel => 'Modifica cruscotto';

  @override
  String get settingsDashboardSaveLabel => 'Salva';

  @override
  String get settingsDashboardsCreateTitle => 'Crea cruscotto';

  @override
  String get settingsDashboardsEmptyState => 'Nessuna dashboard ancora';

  @override
  String get settingsDashboardsEmptyStateHint =>
      'Tocca il tasto + per creare il tuo primo cruscotto.';

  @override
  String get settingsDashboardsErrorLoading =>
      'Cruscotti di caricamento degli errori';

  @override
  String settingsDashboardsNoMatchQuery(String query) {
    return 'Nessun cruscotto corrisponde a \"$query\"';
  }

  @override
  String get settingsDashboardsSearchHint => 'Cerca cruscotti...';

  @override
  String get settingsDashboardsSubtitle =>
      'Personalizza le tue viste sul cruscotto';

  @override
  String get settingsDashboardsTitle => 'Pannelli';

  @override
  String get settingsDefinitionsSubtitle =>
      'Abitudini, categorie, etichette, cruscotti e misurabili';

  @override
  String get settingsDefinitionsTitle => 'Definizioni';

  @override
  String get settingsFlagsEmptySearch =>
      'Nessuna bandiera corrisponde alla tua ricerca';

  @override
  String get settingsFlagsSearchHint => 'Bandiere di ricerca';

  @override
  String get settingsFlagsSubtitle =>
      'Configurare bandiere e opzioni di funzionalità';

  @override
  String get settingsFlagsTitle => 'Bandiere di conflitto';

  @override
  String get settingsHabitsCreateTitle => 'Creare l\'abitudine';

  @override
  String get settingsHabitsDeleteTooltip => 'Eliminare l\'abitudine';

  @override
  String get settingsHabitsDescriptionLabel => 'Descrizione (opzionale)';

  @override
  String get settingsHabitsDetailsLabel => 'Modificare l\'abitudine';

  @override
  String get settingsHabitsEmptyState => 'Non ci sono ancora abitudini';

  @override
  String get settingsHabitsEmptyStateHint =>
      'Tocca il tasto + per creare la tua prima abitudine.';

  @override
  String get settingsHabitsErrorLoading =>
      'Le abitudini di caricamento degli errori';

  @override
  String get settingsHabitsNameLabel => 'Nome dell\'abitudine';

  @override
  String settingsHabitsNoMatchQuery(String query) {
    return 'Nessuna abitudine corrisponde a \"$query\"';
  }

  @override
  String get settingsHabitsPrivateLabel => 'Privato:';

  @override
  String get settingsHabitsSaveLabel => 'Salva';

  @override
  String get settingsHabitsSearchHint => 'Le abitudini di ricerca...';

  @override
  String get settingsHabitsSubtitle => 'Gestisci le tue abitudini e routine';

  @override
  String get settingsHabitsTitle => 'Abitazioni';

  @override
  String get settingsHealthImportActivity =>
      'Importazione dei dati di attività';

  @override
  String get settingsHealthImportBloodPressure =>
      'Importa i dati della pressione sanguigna';

  @override
  String get settingsHealthImportBodyMeasurement =>
      'Importazione dei dati di misurazione del corpo';

  @override
  String get settingsHealthImportFromDate => 'Iniziare';

  @override
  String get settingsHealthImportHeartRate =>
      'Importa i dati della frequenza cardiaca';

  @override
  String get settingsHealthImportSleep => 'Importa i dati del sonno';

  @override
  String get settingsHealthImportTitle => 'Importo della salute';

  @override
  String get settingsHealthImportToDate => 'Fine';

  @override
  String get settingsHealthImportWorkout => 'Importazione dei dati di lavoro';

  @override
  String get settingsKeyboardShortcutsSubtitle =>
      'Imparare le combinazioni di tastiera per la navigazione desktop più veloce e la modifica';

  @override
  String get settingsKeyboardShortcutsTitle => 'Tasti di scelta rapida';

  @override
  String get settingsLabelsCategoriesAdd => 'Aggiungi la categoria';

  @override
  String get settingsLabelsCategoriesHeading => 'Categorie applicabili';

  @override
  String get settingsLabelsCategoriesNone => 'Riguarda tutte le categorie';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Rimuovi';

  @override
  String get settingsLabelsColorHeading => 'Colore';

  @override
  String get settingsLabelsColorSubheading => 'Preimpostazioni rapide';

  @override
  String get settingsLabelsCreateTitle => 'Crea etichetta';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Cancella';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return 'Sei sicuro di voler eliminare \"$labelName\"? Compiti con questa etichetta perderanno l\'assegnazione.';
  }

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Elimina l\'etichetta';

  @override
  String settingsLabelsDeleteSuccess(Object labelName) {
    return 'Etichetta \"$labelName\" cancellato';
  }

  @override
  String get settingsLabelsDescriptionHint =>
      'Spiegare quando applicare questa etichetta';

  @override
  String get settingsLabelsDescriptionLabel => 'Descrizione (opzionale)';

  @override
  String get settingsLabelsEditTitle => 'Modifica dell\'etichetta';

  @override
  String get settingsLabelsEmptyState => 'Ancora nessuna etichetta';

  @override
  String get settingsLabelsEmptyStateHint =>
      'Tocca il tasto + per creare la tua prima etichetta.';

  @override
  String get settingsLabelsErrorLoading => 'Etichette non caricate';

  @override
  String get settingsLabelsNameHint => 'Bug, Blocco di rilascio, Sync...';

  @override
  String get settingsLabelsNameLabel => 'Nome e cognome';

  @override
  String settingsLabelsNoMatchCreate(String query) {
    return 'Crea l\'etichetta \"$query\"';
  }

  @override
  String settingsLabelsNoMatchQuery(String query) {
    return 'Nessuna etichetta corrisponde a \"$query\"';
  }

  @override
  String get settingsLabelsPrivateDescription =>
      'Solo visibile quando vengono mostrate le voci private';

  @override
  String get settingsLabelsPrivateTitle => 'Privato';

  @override
  String get settingsLabelsSearchHint => 'Etichette di ricerca...';

  @override
  String get settingsLabelsSubtitle =>
      'Organizzare le attività con le etichette colorate';

  @override
  String get settingsLabelsTitle => 'Etichette';

  @override
  String settingsLabelsUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attività',
      one: '1 attività',
    );
    return '$_temp0';
  }

  @override
  String get settingsLoggingDomainsSubtitle =>
      'Controllo che i domini scrivono al log';

  @override
  String get settingsLoggingDomainsTitle => 'Registrazione di domini';

  @override
  String get settingsLoggingGlobalToggle => 'Abilita la registrazione';

  @override
  String get settingsLoggingGlobalToggleSubtitle =>
      'Interruttore master per tutti i log';

  @override
  String get settingsLoggingSlowQueries => 'Lenti quesiti del database';

  @override
  String get settingsLoggingSlowQueriesSubtitle =>
      'Scrive domande lente a slow_queries-YYYY-MM-DD.log';

  @override
  String get settingsMaintenanceOnboardingAnimationGallerySubtitle =>
      'Confronta le animazioni di benvenuto + collega la pagina dal vivo (debug)';

  @override
  String get settingsMaintenanceOnboardingAnimationGalleryTitle =>
      'Galleria di animazione onboarding';

  @override
  String get settingsMaintenanceOnboardingWelcomeSubtitle =>
      'Anteprima il benvenuto FTUE + le piastrelle del fornitore (debug)';

  @override
  String get settingsMaintenanceOnboardingWelcomeTitle =>
      'Mostra il benvenuto a bordo';

  @override
  String get settingsMaintenanceTitle => 'Manutenzione';

  @override
  String get settingsManualLanguageCzechTitle => 'Ceco';

  @override
  String get settingsManualLanguageDutchTitle => 'Olandese';

  @override
  String get settingsManualLanguageDanishTitle => 'Danese';

  @override
  String get settingsManualLanguageEnglishTitle => 'Inglese';

  @override
  String get settingsManualLanguageFollowSystemSubtitle =>
      'Usa la lingua del dispositivo in Lotti e nel Manuale quando è supportata; altrimenti usa l’inglese.';

  @override
  String get settingsManualLanguageFollowSystemTitle => 'Segui il sistema';

  @override
  String get settingsManualLanguageFrenchTitle => 'Francese';

  @override
  String get settingsManualLanguageGermanTitle => 'Tedesco';

  @override
  String get settingsManualLanguageItalianTitle => 'Italiano';

  @override
  String get settingsManualLanguagePortugueseTitle => 'Portoghese';

  @override
  String get settingsManualLanguageRomanianTitle => 'Rumeno';

  @override
  String get settingsManualLanguageSpanishTitle => 'Spagnolo';

  @override
  String get settingsManualLanguageSwedishTitle => 'Svedese';

  @override
  String get settingsManualLanguageTitle => 'Lingua';

  @override
  String get settingsMatrixAccept => 'Accettare';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'Altro dispositivo mostra emoji, continuare';

  @override
  String get settingsMatrixCancel => 'Annullamento';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Accetti su altri dispositivi per continuare';

  @override
  String get settingsMatrixDiagnosticCopied =>
      'Informazioni diagnostiche copiate a clipboard';

  @override
  String get settingsMatrixDiagnosticCopyButton => 'Copia a Appunti';

  @override
  String get settingsMatrixDiagnosticDialogTitle =>
      'Informazioni diagnostiche di Sync';

  @override
  String get settingsMatrixDiagnosticShowButton =>
      'Mostra informazioni diagnostiche';

  @override
  String get settingsMatrixDone => 'Fatto';

  @override
  String get settingsMatrixLastUpdated => 'Ultimo aggiornamento:';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Dispositivi non verificati';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Eseguire Matrix compiti di manutenzione e strumenti di recupero';

  @override
  String get settingsMatrixMaintenanceTitle => 'Manutenzione';

  @override
  String get settingsMatrixMetrics => 'Sincronizzazioni';

  @override
  String get settingsMatrixNextPage => 'Pagina successiva';

  @override
  String get settingsMatrixNoUnverifiedLabel =>
      'Nessun dispositivo non verificato';

  @override
  String get settingsMatrixPreviousPage => 'Pagina precedente';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Invita la stanza $roomId da $senderId. Accettare?';
  }

  @override
  String get settingsMatrixRoomInviteTitle => 'Invita la camera';

  @override
  String get settingsMatrixSentMessagesLabel => 'Messaggi inviati:';

  @override
  String settingsMatrixSentMessageType(String eventType) {
    return 'Inviato ($eventType)';
  }

  @override
  String get settingsMatrixStartVerificationLabel => 'Avviare la verifica';

  @override
  String get settingsMatrixStatsTitle => 'Statistiche Matrix';

  @override
  String get settingsMatrixTitle => 'Impostazioni di sincronizzazione';

  @override
  String get settingsMatrixUnverifiedDevicesPage =>
      'Dispositivi non verificati';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Cancellato su altro dispositivo...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Capito.';

  @override
  String settingsMatrixVerificationSuccessLabel(
    String deviceName,
    String deviceID,
  ) {
    return 'Hai verificato con successo $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Confermare su altro dispositivo che le emoji qui sotto vengono visualizzate su entrambi i dispositivi, nello stesso ordine:';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Confermare che le emoji qui sotto sono visualizzate su entrambi i dispositivi, nello stesso ordine:';

  @override
  String get settingsMatrixVerifyLabel => 'Verifica';

  @override
  String get settingsMeasurableAggregationHelper =>
      'Come le voci di un giorno si combinano sui grafici';

  @override
  String get settingsMeasurableAggregationLabel =>
      'Tipo di aggregazione predefinito';

  @override
  String get settingsMeasurableDeleteTooltip => 'Eliminare il tipo misurabile';

  @override
  String get settingsMeasurableDescriptionLabel => 'Descrizione (opzionale)';

  @override
  String get settingsMeasurableDetailsLabel => 'Modificare misurabile';

  @override
  String get settingsMeasurableNameLabel => 'Nome misurabile';

  @override
  String get settingsMeasurablePrivateLabel => 'Privato:';

  @override
  String get settingsMeasurableSaveLabel => 'Salva';

  @override
  String get settingsMeasurablesCreateTitle => 'Creare misurabili';

  @override
  String get settingsMeasurablesEmptyState => 'Non ancora misurabili';

  @override
  String get settingsMeasurablesEmptyStateHint =>
      'Misurabili sono numeri che si traccia nel tempo — peso, acqua, passi.';

  @override
  String get settingsMeasurablesErrorLoading => 'Caricamento errori misurabili';

  @override
  String settingsMeasurablesNoMatchQuery(String query) {
    return 'Nessuna corrispondenza misurabile \"$query\"';
  }

  @override
  String get settingsMeasurablesSearchHint => 'Cerca i misurabili...';

  @override
  String get settingsMeasurablesSubtitle =>
      'Configurare tipi di dati misurabili';

  @override
  String get settingsMeasurablesTitle => 'Misurabili';

  @override
  String get settingsMeasurableUnitLabel => 'Abbreviazione unità (opzionale)';

  @override
  String get settingsOnboardingActionSubtitle =>
      'Riaprire il flusso di benvenuto — collegare il cervello AI e creare un compito';

  @override
  String get settingsOnboardingMetricsSubtitle =>
      'Imbuto FTUE — installazione, attivazione, ritenzione (debug)';

  @override
  String get settingsOnboardingMetricsTitle => 'Metriche di bordo';

  @override
  String get settingsOnboardingReplayTitle => 'Riproduci a bordo';

  @override
  String get settingsOnboardingStartTitle => 'Iniziare a bordo';

  @override
  String get settingsOnboardingStatusActivated =>
      'Hai creato il tuo primo compito AI';

  @override
  String get settingsOnboardingStatusLoading => 'Caricamento...';

  @override
  String get settingsOnboardingStatusNotActivated => 'Non ancora iniziato';

  @override
  String get settingsOnboardingStatusTitle => 'Stato';

  @override
  String get settingsOnboardingSubtitle =>
      'Riproduci il flusso di benvenuto in qualsiasi momento';

  @override
  String get settingsOnboardingTestResetConfirm => 'Ripristino';

  @override
  String get settingsOnboardingTestResetConfirmQuestion =>
      'Cancellare la cronologia dei suggerimenti e le metriche? I piani operativi giornalieri esistenti rimangono, quindi utilizzare un profilo pulito per testare il passaggio completo del sistema operativo giornaliero di prima corsa.';

  @override
  String get settingsOnboardingTestResetSubtitle =>
      'Cancella cronologia e metriche del prompt; i piani operativi giornalieri esistenti rimangono (debug)';

  @override
  String get settingsOnboardingTestResetTitle =>
      'Ripristino dello stato del test di bordo';

  @override
  String get settingsOnboardingTitle => 'A bordo';

  @override
  String get settingsOptionsTitle => 'Opzioni';

  @override
  String get settingsRecordingStyleExplanation =>
      'Scegli come appare il microfono mentre stai registrando.';

  @override
  String get settingsRecordingStyleSubtitle =>
      'Misuratore VU o orb di energia durante la registrazione';

  @override
  String get settingsRecordingStyleTitle => 'Stile di registrazione';

  @override
  String get settingsResetGeminiConfirm => 'Ripristino';

  @override
  String get settingsResetGeminiConfirmQuestion =>
      'Questo mostrerà la finestra di dialogo di configurazione Gemini.';

  @override
  String get settingsResetGeminiSubtitle =>
      'Mostra di nuovo la finestra di dialogo di configurazione Gemini AI';

  @override
  String get settingsResetGeminiTitle =>
      'Reimposta finestra di configurazione Gemini';

  @override
  String get settingsResetHintsConfirm => 'Conferma';

  @override
  String get settingsResetHintsConfirmQuestion =>
      'Ripristinare i suggerimenti in-app visualizzati attraverso l\'app?';

  @override
  String settingsResetHintsResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reimpostati $count suggerimenti',
      one: 'Reimpostato un suggerimento',
      zero: 'Reimpostati zero suggerimenti',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetHintsSubtitle =>
      'Punte chiare una tantum e suggerimenti di bordo';

  @override
  String get settingsResetHintsTitle => 'Reimposta suggerimenti nell\'app';

  @override
  String get settingsSpeechSubtitle => 'Voce e lettura aloud';

  @override
  String get settingsSpeechTitle => 'Discorso';

  @override
  String get settingsSyncConflictsSubtitle =>
      'Risolvere i conflitti di sincronizzazione per garantire la coerenza dei dati';

  @override
  String get settingsSyncNodeProfileCapabilitiesEmpty =>
      'Nessuno rilevato — auto-trigger dell\'inferenza audio sincronizzata non si rivolgerà a questo dispositivo.';

  @override
  String get settingsSyncNodeProfileCapabilitiesLabel => 'Capacità AI rilevate';

  @override
  String get settingsSyncNodeProfileCapabilityMlxAudio => 'MLX Audio (locale)';

  @override
  String get settingsSyncNodeProfileCapabilityOllamaLlm => 'Ollama LLM';

  @override
  String get settingsSyncNodeProfileCapabilityOmlxLlm => 'oMLX LLM';

  @override
  String get settingsSyncNodeProfileCapabilityVoxtral => 'Voxtral (locale)';

  @override
  String get settingsSyncNodeProfileCapabilityWhisper => 'Whisper (locale)';

  @override
  String get settingsSyncNodeProfileDisplayNameHelper =>
      'Visibile agli altri dispositivi quando si sceglie quale per spillare un profilo a.';

  @override
  String get settingsSyncNodeProfileDisplayNameLabel =>
      'Nome del display del dispositivo';

  @override
  String get settingsSyncNodeProfileKnownNodesEmpty =>
      'Nessun altro dispositivo ha ancora pubblicato un profilo.';

  @override
  String get settingsSyncNodeProfileKnownNodesTitle =>
      'Dispositivi di sincronizzazione noti';

  @override
  String get settingsSyncNodeProfileSaveButton => 'Salva';

  @override
  String get settingsSyncNodeProfileSubtitle =>
      'Nominare questo dispositivo e rivedere le funzionalità visibili agli altri dispositivi.';

  @override
  String get settingsSyncNodeProfileTitle => 'Questo dispositivo';

  @override
  String get settingsSyncOutboxTitle => 'Posta in uscita';

  @override
  String get settingsSyncStatsSubtitle =>
      'Ispezione delle metriche di sincronizzazione';

  @override
  String get settingsSyncSubtitle =>
      'Configurare le statistiche di sincronizzazione e visualizzazione';

  @override
  String get settingsThemingAutomatic => 'Automatico';

  @override
  String get settingsThemingDark => 'Aspetto oscuro';

  @override
  String get settingsThemingLight => 'Aspetto leggero';

  @override
  String get settingsThemingSubtitle =>
      'Personalizza l\'aspetto dell\'app e i temi';

  @override
  String get settingsThemingTitle => 'Il nome';

  @override
  String get settingsV2CategoryEmptyBody => 'Scegli un sub-setting a sinistra.';

  @override
  String get settingsV2DetailRootCrumb => 'Impostazioni delle impostazioni';

  @override
  String get settingsV2EmptyStateBody =>
      'Scegli una sezione a sinistra per iniziare.';

  @override
  String get settingsV2ResizeHandleLabel =>
      'Ridimensionare l\'albero impostazioni';

  @override
  String get settingsV2UnimplementedTitle => 'Pannello non ancora implementato';

  @override
  String get settingsWhatsNewSubtitle =>
      'Visualizza gli ultimi aggiornamenti e le funzionalità';

  @override
  String get settingsWhatsNewTitle => 'Che cosa è nuovo';

  @override
  String get settingThemingDark => 'Temi scuri';

  @override
  String get settingThemingLight => 'Tema della luce';

  @override
  String get sidebarActiveSectionTitle => 'Attività';

  @override
  String get sidebarActivityCollapseTooltip => 'L\'attività di colata';

  @override
  String get sidebarActivityExpandTooltip => 'Attività all\'estero';

  @override
  String get sidebarAudioRecordingStatusLabel => 'Registrazione';

  @override
  String get sidebarRunningTimerLabel => 'Tempo di esecuzione';

  @override
  String get sidebarRunningTimerStopTooltip => 'Ferma il timer.';

  @override
  String get sidebarTimerStatusLabel => 'Cronometro';

  @override
  String get sidebarToggleCollapseLabel => 'Barra laterale di ricaduta';

  @override
  String get sidebarToggleExpandLabel => 'Barra laterale espandibile';

  @override
  String sidebarWakesActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attivi',
      one: '1 attivo',
    );
    return '$_temp0';
  }

  @override
  String get sidebarWakesCancelTooltip => 'Annulla l\'agente';

  @override
  String get sidebarWakesHeader => 'Agenti';

  @override
  String get sidebarWakesNow => 'ora';

  @override
  String get sidebarWakesOpenList => 'Elenco aperto';

  @override
  String get sidebarWakesOpenTask => 'Attività aperte';

  @override
  String sidebarWakesQueuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in coda',
      one: '1 coda',
    );
    return '$_temp0';
  }

  @override
  String get sidebarWakesQueuedLabel => 'In coda';

  @override
  String get sidebarWakesWorkingLabel => 'Lavorazione';

  @override
  String get skillsSectionTitle => 'Competenze';

  @override
  String get speechDictionaryHelper =>
      'Termini semicolon-separati (max 50 chars) per un migliore riconoscimento vocale';

  @override
  String get speechDictionaryHint => 'macOS; Kirkjubæjarklaustur; Claude Code';

  @override
  String get speechDictionaryLabel => 'Dizionario di discorso';

  @override
  String get speechDictionarySectionDescription =>
      'Aggiungi i termini che sono spesso trascurati dal riconoscimento vocale (nomi, luoghi, termini tecnici)';

  @override
  String get speechDictionarySectionTitle => 'Riconoscimento vocale';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Grande dizionario ( termini $count) può aumentare i costi API';
  }

  @override
  String get speechModalSelectLanguage => 'Seleziona la lingua';

  @override
  String get speechModalTitle => 'Riconoscimento vocale';

  @override
  String get speechSettingsModelDescription => 'Modello vocale on-device';

  @override
  String get speechSettingsModelDownloadsOnce => 'Downloads una volta';

  @override
  String get speechSettingsModelLabel => 'Modello';

  @override
  String get speechSettingsRecommendedBadge => 'Consigliato';

  @override
  String get speechSettingsSpeedDescription =>
      'Quanto velocemente si leggono i riassunti';

  @override
  String get speechSettingsSpeedLabel => 'Velocità di lettura';

  @override
  String get speechSettingsVoiceDescription =>
      'Scegli la voce che legge i riassunti aloud';

  @override
  String get speechSettingsVoiceLabel => 'Voce';

  @override
  String get speechVoiceGenderFemale => 'Femmina';

  @override
  String get speechVoiceGenderMale => 'Maschio';

  @override
  String get speechVoicePreviewTooltip => 'Anteprima voce';

  @override
  String get surveyBackButton => 'Indietro';

  @override
  String get surveyCancelConfirmation => 'Annullare l\'indagine?';

  @override
  String get surveyChooseOneOption => 'Scegli una opzione';

  @override
  String get surveyChooseOneOrMoreOptions => 'Scegli una o più opzioni';

  @override
  String get surveyDiscardConfirmation => 'Eliminare i risultati e smettere?';

  @override
  String get surveyInputNumberValidation => 'Inserisci un numero';

  @override
  String get surveyNextButton => 'Il prossimo';

  @override
  String get surveyNoButton => 'No.';

  @override
  String get surveyProgressOf => 'di';

  @override
  String get surveyTapToAnswer => 'Toccare per rispondere';

  @override
  String get surveyValueAnd => 'e';

  @override
  String get surveyValueBetween => 'Dev\'essere tra';

  @override
  String get surveyYesButton => 'Sì.';

  @override
  String get syncActivityIdle => 'Idle';

  @override
  String get syncActivityInboxLabel => 'Posta in arrivo';

  @override
  String syncActivityIndicatorSemantics(int outbox, int inbox) {
    return 'Posta in arrivo: $outbox. Posta in arrivo: $inbox.';
  }

  @override
  String get syncActivityOutboxLabel => 'Posta in uscita';

  @override
  String get syncActivitySyncingTitle => 'Synch';

  @override
  String get syncActivityTitle => 'Traduzione:';

  @override
  String get syncDeleteConfigConfirm => 'Si\', sono sicuro.';

  @override
  String get syncDeleteConfigQuestion =>
      'Vuoi eliminare la configurazione di sincronizzazione?';

  @override
  String get syncEntitiesConfirm => 'AVVIA SINCRONIZZAZIONE';

  @override
  String get syncEntitiesMessage => 'Scegli le entità che vuoi sincronizzare.';

  @override
  String get syncEntitiesSuccessDescription => 'Tutto e\' aggiornato.';

  @override
  String get syncEntitiesSuccessTitle => 'Sincronizzazione completa';

  @override
  String syncListCountSummary(String label, int itemCount) {
    String _temp0 = intl.Intl.pluralLogic(
      itemCount,
      locale: localeName,
      other: '$itemCount articoli',
      one: '1 elemento',
      zero: '0',
    );
    return '$label · $_temp0';
  }

  @override
  String get syncListPayloadKindLabel => 'Carico di pagamento';

  @override
  String get syncListUnknownPayload => 'Sconosciuto carico utile';

  @override
  String get syncNotLoggedInToast => 'Sync non è collegato';

  @override
  String get syncPayloadAgentBundle => 'Pacchetto dell\'agente';

  @override
  String get syncPayloadAgentEntity => 'Ente agente';

  @override
  String get syncPayloadAgentLink => 'Collegamento dell\'agente';

  @override
  String get syncPayloadAiConfig => 'Configurazione AI';

  @override
  String get syncPayloadAiConfigDelete => 'Configurazione AI eliminare';

  @override
  String get syncPayloadBackfillRequest => 'Richiesta di rimborso';

  @override
  String get syncPayloadBackfillResponse => 'Risposta di backup';

  @override
  String get syncPayloadConfigFlag => 'Bandiera di conflitto';

  @override
  String get syncPayloadConsumptionEvent => 'Consumo di AI';

  @override
  String get syncPayloadDailyOsUserName =>
      'Nome del sistema operativo giornaliero';

  @override
  String get syncPayloadEntityDefinition => 'Definizione di ingresso';

  @override
  String get syncPayloadEntryLink => 'Collegamento di ingresso';

  @override
  String get syncPayloadJournalEntity => 'Entrata del giornale';

  @override
  String get syncPayloadNotification => 'Notifica';

  @override
  String get syncPayloadNotificationStateUpdate =>
      'Aggiornamento dello stato di notifica';

  @override
  String get syncPayloadOutboxBundle => 'Fascetta di uscita';

  @override
  String get syncPayloadSavedTaskFilter => 'Filtro di attività salvato';

  @override
  String get syncPayloadSavedTaskFilterDelete =>
      'Cancellare il filtro attività salvato';

  @override
  String get syncPayloadSyncNodeProfile => 'Profilo di Sync node';

  @override
  String get syncPayloadThemingSelection => 'La selezione dei nomi';

  @override
  String get syncStepAgentEntities => 'entità dell\'agente';

  @override
  String get syncStepAgentLinks => 'Link dell\'agente';

  @override
  String get syncStepAiSettings => 'Impostazioni dell\'intelligenza';

  @override
  String get syncStepBackfillAgentEntityClocks =>
      'Backfill agente entità orologi';

  @override
  String get syncStepBackfillAgentLinkClocks =>
      'Orologi di collegamento agente di riempimento';

  @override
  String get syncStepCategories => 'Categorie';

  @override
  String get syncStepComplete => 'Completo';

  @override
  String get syncStepDashboards => 'Pannelli';

  @override
  String get syncStepHabits => 'Abitazioni';

  @override
  String get syncStepLabels => 'Etichette';

  @override
  String get syncStepMeasurables => 'Misurabili';

  @override
  String get syncStepSavedTaskFilters => 'Filtri di attività salvate';

  @override
  String get taskActionBarAudioRecordingActive =>
      'Registrazione audio in corso';

  @override
  String get taskActionBarMoreActions => 'Altre azioni';

  @override
  String get taskActionBarOpenRunningTimer => 'Apri il timer in esecuzione';

  @override
  String get taskActionBarStopTracking => 'Smettere di rintracciare il tempo';

  @override
  String get taskActionBarTrackTime => 'Tempo di tracciamento';

  @override
  String get taskAgentAttributionUnavailable => 'Attribuzione non disponibile';

  @override
  String get taskAgentAutomaticUpdatesLabel => 'Aggiornamenti automatici';

  @override
  String get taskAgentAutomaticUpdatesNeedsSetup =>
      'Scegli una configurazione AI prima di attivare aggiornamenti automatici.';

  @override
  String get taskAgentCancelTimerTooltip =>
      'Annulla aggiornamento automatico in attesa';

  @override
  String get taskAgentChooseModel => 'Scegli un modello di pensiero';

  @override
  String get taskAgentChooseProfile => 'Scegli un profilo di inferenza';

  @override
  String taskAgentCountdownTooltip(String countdown) {
    return 'Il prossimo auto-run in $countdown';
  }

  @override
  String get taskAgentCreateChipLabel => 'Agente di assegnazione';

  @override
  String taskAgentCreateError(String error) {
    return 'Non è riuscito a creare agente: $error';
  }

  @override
  String get taskAgentCurrentSetupHeader => 'Configurazione attuale';

  @override
  String get taskAgentCurrentSetupLabel => 'Configurazione attuale';

  @override
  String get taskAgentDirectModelOverride => 'Modello diretto override';

  @override
  String get taskAgentDisableConfirmAction => 'Spegnilo.';

  @override
  String get taskAgentDisableConfirmBody =>
      'L\'attuale relazione rimane visibile, ma questo agente non può funzionare fino a quando non si sceglie una configurazione.';

  @override
  String get taskAgentDisableConfirmTitle => 'Spegni l\'IA per questo agente?';

  @override
  String get taskAgentInferenceProfileLabel => 'Profilo di inferenza';

  @override
  String get taskAgentModelPickerTitle => 'Scegli il modello di pensiero';

  @override
  String taskAgentNextUpdateIn(String countdown) {
    return 'Prossimo aggiornamento in $countdown';
  }

  @override
  String get taskAgentNoAiSetup => 'Nessun setup dell\'AI';

  @override
  String get taskAgentNoAiSetupDescription =>
      'Pauses agente inferenza fino a quando si sceglie un profilo o un modello.';

  @override
  String get taskAgentNoModelsAvailable =>
      'Nessun modello di pensiero compatibile disponibile';

  @override
  String get taskAgentNoProfilesAvailable =>
      'Nessun profilo disponibile su questo dispositivo';

  @override
  String get taskAgentNoProfileSelected => 'Nessun setup dell\'AI';

  @override
  String get taskAgentNoProfileSelectedDescription =>
      'Scegliere un setup salvato o un modello di pensiero prima che questo agente possa eseguire.';

  @override
  String taskAgentProfileChangedToast(String profile) {
    return 'Usando $profile per ogni aggiornamento dell\'agente futuro fino a quando non lo cambi.';
  }

  @override
  String get taskAgentProfileDefaultBadge => 'Profilo predefinito';

  @override
  String get taskAgentReportOutdatedTitle => 'Questo riassunto è fuori data';

  @override
  String get taskAgentReportUpToDate => 'Il riassunto è aggiornato';

  @override
  String get taskAgentRouteVia => 'via via';

  @override
  String get taskAgentRunNowTooltip => 'Correte ora';

  @override
  String get taskAgentSavingSetup => 'Impostazione agente di risparmio';

  @override
  String taskAgentSetupAndReportSemantics(String identity) {
    return 'Questo report e la configurazione corrente utilizzano $identity. Attivare per modificare la configurazione.';
  }

  @override
  String get taskAgentSetupBroken =>
      'La configurazione AI selezionata non è disponibile';

  @override
  String taskAgentSetupChangedToast(String model) {
    return 'Usando $model per ogni aggiornamento dell\'agente futuro fino a quando non lo cambi.';
  }

  @override
  String get taskAgentSetupChoiceHelp =>
      'Scegli un profilo per i suoi valori predefiniti, o sovrascrivi solo il modello di pensiero.';

  @override
  String get taskAgentSetupOriginCategory =>
      'Copiato dalle impostazioni predefinite della categoria quando è stato creato questo agente';

  @override
  String get taskAgentSetupOriginDisabled => 'Disabili';

  @override
  String get taskAgentSetupOriginLegacy => 'Configurazione legacy';

  @override
  String get taskAgentSetupOriginTemplate => 'Copiato dal modello';

  @override
  String get taskAgentSetupOriginUser => 'Hai scelto questo per questo agente.';

  @override
  String get taskAgentSetupPersistenceDescription =>
      'Le modifiche si applicano ad ogni aggiornamento futuro fino a modificarle.';

  @override
  String taskAgentSetupSemantics(String identity) {
    return 'Configurazione corrente: $identity. Attivare per modificare la configurazione.';
  }

  @override
  String get taskAgentSetupTitle => 'Impostazione dell\'agente';

  @override
  String get taskAgentThinkingModelLabel => 'Modella di pensiero';

  @override
  String get taskAgentThisReportHeader => 'Questa relazione';

  @override
  String get taskAgentTurnOffSetup => 'Spegnere l\'IA per questo agente';

  @override
  String get taskAgentUseCategoryDefault => 'Copiare la categoria predefinita';

  @override
  String get taskAgentUseCategoryDefaultDescription =>
      'Copre la configurazione attuale della categoria. Le modifiche successive della categoria non influenzeranno questo agente.';

  @override
  String get taskAgentUseProfileDefault => 'Utilizzare il profilo predefinito';

  @override
  String get taskAgentWakeAgent => 'Agente sveglia';

  @override
  String get taskCategoryAllLabel => 'tutti quanti';

  @override
  String get taskCategoryLabel => 'Categoria:';

  @override
  String get taskCategoryUnassignedLabel => 'non firmata';

  @override
  String get taskDueDateLabel => 'Data di scadenza';

  @override
  String taskDueDateWithDate(String date) {
    return 'Scadenza: $date';
  }

  @override
  String taskDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days giorni',
      one: '1 giorno',
    );
    return 'Due in $_temp0';
  }

  @override
  String get taskDueToday => 'Scade oggi';

  @override
  String get taskDueTomorrow => 'Scade domani';

  @override
  String get taskDueYesterday => 'Scadeva ieri';

  @override
  String get taskEditTitleLabel => 'Modifica titolo dell\'attività';

  @override
  String get taskEstimateLabel => 'Stima:';

  @override
  String get taskEstimateModalTitle => 'Stima';

  @override
  String taskEstimateProgressLabel(String tracked, String estimate) {
    return '$tracked di $estimate';
  }

  @override
  String taskEstimateTooltip(String tracked, String estimate) {
    return 'Tempo tracciato: $tracked di $estimate stimato';
  }

  @override
  String taskLabelsMoreCount(int count) {
    return '+$count';
  }

  @override
  String get taskLabelsShowFewer => 'Mostra meno';

  @override
  String get taskLanguageArabic => 'Arabo';

  @override
  String get taskLanguageBengali => 'Bengali';

  @override
  String get taskLanguageBulgarian => 'Bulgaro';

  @override
  String get taskLanguageChinese => 'Cinese';

  @override
  String get taskLanguageCroatian => 'Croazia';

  @override
  String get taskLanguageCzech => 'Repubblica ceca';

  @override
  String get taskLanguageDanish => 'Danese';

  @override
  String get taskLanguageDutch => 'Paesi Bassi';

  @override
  String get taskLanguageEnglish => 'Inglese';

  @override
  String get taskLanguageEstonian => 'Estone';

  @override
  String get taskLanguageFinnish => 'Finlandia';

  @override
  String get taskLanguageFrench => 'Francese';

  @override
  String get taskLanguageGerman => 'Germania';

  @override
  String get taskLanguageGreek => 'Grecia';

  @override
  String get taskLanguageHebrew => 'Ebraico';

  @override
  String get taskLanguageHindi => 'Hindi';

  @override
  String get taskLanguageHungarian => 'Ungheria';

  @override
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageIndonesian => 'Indonesiano';

  @override
  String get taskLanguageItalian => 'Italiano';

  @override
  String get taskLanguageJapanese => 'Giapponese';

  @override
  String get taskLanguageKorean => 'Coreano';

  @override
  String get taskLanguageLabel => 'Lingua';

  @override
  String get taskLanguageLatvian => 'Lettonia';

  @override
  String get taskLanguageLithuanian => 'Lituano';

  @override
  String get taskLanguageNigerianPidgin => 'Pidgin nigeriano';

  @override
  String get taskLanguageNorwegian => 'Norvegese';

  @override
  String get taskLanguagePolish => 'Polacco';

  @override
  String get taskLanguagePortuguese => 'Portoghese';

  @override
  String get taskLanguageRomanian => 'Rumeno';

  @override
  String get taskLanguageRussian => 'Russo';

  @override
  String get taskLanguageSelectedLabel => 'Attualmente selezionato';

  @override
  String get taskLanguageSerbian => 'Serbia';

  @override
  String get taskLanguageSetAction => 'Impostare la lingua';

  @override
  String get taskLanguageSlovak => 'Slovacco Slovacco';

  @override
  String get taskLanguageSlovenian => 'Sloveno';

  @override
  String get taskLanguageSpanish => 'Spagnolo';

  @override
  String get taskLanguageSwahili => 'SERVIZIO';

  @override
  String get taskLanguageSwedish => 'Svezia';

  @override
  String get taskLanguageThai => 'Tailandese';

  @override
  String get taskLanguageTurkish => 'Turco';

  @override
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageUkrainian => 'Ucraino';

  @override
  String get taskLanguageVietnamese => 'Vietnamita';

  @override
  String get taskLanguageYoruba => 'Yoruba';

  @override
  String get taskNoDueDateLabel => 'Nessuna data';

  @override
  String get taskNoEstimateLabel => 'Nessuna stima';

  @override
  String taskOverdueByDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days giorni',
      one: '1 giorno',
    );
    return 'In ritardo di $_temp0';
  }

  @override
  String get taskPriorityHigh => 'Alto.';

  @override
  String get taskPriorityLow => 'Basso';

  @override
  String get taskPriorityMedium => 'Mezzo';

  @override
  String get taskPriorityUrgent => 'Urgente';

  @override
  String get tasksAddLabelButton => 'Aggiungi l\'etichetta';

  @override
  String get tasksAgentFilterAll => 'Tutti';

  @override
  String get tasksAgentFilterHasAgent => 'Ha l\'agente.';

  @override
  String get tasksAgentFilterNoAgent => 'Nessun agente';

  @override
  String get tasksAgentFilterTitle => 'Agente';

  @override
  String get tasksFilterApplyTitle => 'Applica il filtro';

  @override
  String get tasksFilterClearAll => 'Cancella tutto';

  @override
  String get tasksFilterTitle => 'Filtra le attività';

  @override
  String get taskShowcaseAudio => 'Audio audio';

  @override
  String taskShowcaseCompletedCount(int completed, int total) {
    return '$completed / $total fatto';
  }

  @override
  String taskShowcaseDueDate(String date) {
    return 'Scadenza: $date';
  }

  @override
  String get taskShowcaseJumpToSection => 'Vai alla sezione';

  @override
  String get taskShowcaseLinked => 'Collegamento';

  @override
  String get taskShowcaseNoResults =>
      'Nessun compito corrisponde alla tua ricerca.';

  @override
  String get taskShowcaseReadMore => 'Leggi tutto';

  @override
  String taskShowcaseRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count registrazioni',
      one: '1 registrazione',
    );
    return '$_temp0';
  }

  @override
  String taskShowcaseTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attività',
      one: '1 attività',
    );
    return '$_temp0';
  }

  @override
  String get taskShowcaseTaskDescription => 'Descrizione dell\'attività';

  @override
  String get taskShowcaseTimeTracker => 'Tracciatore di tempo';

  @override
  String get taskShowcaseTodo => 'Da fare';

  @override
  String get taskShowcaseTodos => 'Da fare';

  @override
  String get tasksLabelFilterAll => 'Tutti';

  @override
  String get tasksLabelFilterTitle => 'Etichetta';

  @override
  String get tasksLabelFilterUnlabeled => 'Non etichettato';

  @override
  String get tasksLabelsDialogClose => 'Chiudere';

  @override
  String get tasksLabelsSheetApply => 'Applicare';

  @override
  String get tasksLabelsSheetSearchHint => 'Etichette di ricerca...';

  @override
  String get tasksLabelsUpdateFailed =>
      'Non è riuscito ad aggiornare le etichette';

  @override
  String get tasksPriorityFilterAll => 'Tutti';

  @override
  String get tasksPriorityFilterTitle => 'Priorità';

  @override
  String get tasksPriorityP0 => 'Urgente';

  @override
  String get tasksPriorityP0Description => 'Urgente (ASAP)';

  @override
  String get tasksPriorityP1 => 'Alto.';

  @override
  String get tasksPriorityP1Description => 'Alto (Soon)';

  @override
  String get tasksPriorityP2 => 'Mezzo';

  @override
  String get tasksPriorityP2Description => 'Medio (Default)';

  @override
  String get tasksPriorityP3 => 'Basso';

  @override
  String get tasksPriorityP3Description => 'basso (sempre)';

  @override
  String get tasksPriorityPickerTitle => 'Selezionare la priorità';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Non firmata';

  @override
  String get tasksSavedFilterDeleteConfirmTooltip =>
      'Toccare di nuovo per eliminare';

  @override
  String get tasksSavedFilterDeleteTooltip => 'Eliminare il filtro salvato';

  @override
  String get tasksSavedFilterDragHandleSemantics => 'Trascinare per riordinare';

  @override
  String get tasksSavedFilterRenameSemantics => 'Rinominare il filtro salvato';

  @override
  String get tasksSavedFiltersAllShort => 'Tutti';

  @override
  String get tasksSavedFiltersAllTasks => 'Tutte le attività';

  @override
  String get tasksSavedFiltersCustom => 'Personale';

  @override
  String get tasksSavedFiltersDeleteConfirmAction => 'Cancella';

  @override
  String tasksSavedFiltersDeleteConfirmMessage(String name) {
    return 'Eliminare il filtro salvato \'$name\'? Questo non può essere annullato.';
  }

  @override
  String tasksSavedFiltersDeleteConfirmNamed(String name) {
    return 'Conferma di eliminare $name';
  }

  @override
  String tasksSavedFiltersDeleteNamed(String name) {
    return 'Eliminare $name';
  }

  @override
  String get tasksSavedFiltersDone => 'Fatto';

  @override
  String get tasksSavedFiltersEdit => 'Modifica';

  @override
  String get tasksSavedFiltersFilterNameLabel => 'Nome del filtro';

  @override
  String get tasksSavedFiltersGroupSemantics => 'Filtri di attività';

  @override
  String get tasksSavedFiltersManageTooltip =>
      'Gestire i filtri delle attività';

  @override
  String get tasksSavedFiltersRailButton => 'Filtri';

  @override
  String tasksSavedFiltersRenameNamed(String name) {
    return 'Rinomina $name';
  }

  @override
  String get tasksSavedFiltersReorderHelper =>
      'Trascina per impostare l\'ordine. I primi cinque filtri appaiono nella barra laterale.';

  @override
  String get tasksSavedFiltersSaveAsNewButtonLabel => 'Salva come nuovo...';

  @override
  String get tasksSavedFiltersSaveAsNewDescription =>
      'Mantenere il filtro esistente invariato e creare uno separato.';

  @override
  String get tasksSavedFiltersSaveAsNewTitle => 'Salvare come nuovo filtro';

  @override
  String get tasksSavedFiltersSaveButtonLabel => 'Salvare il filtro...';

  @override
  String get tasksSavedFiltersSaveChoiceIntro =>
      'Scegliere se aggiornare il filtro salvato o creare uno separato.';

  @override
  String get tasksSavedFiltersSaveChoiceTitle => 'Salvare il filtro';

  @override
  String get tasksSavedFiltersSaveCurrentAs => 'Salvare il filtro corrente...';

  @override
  String get tasksSavedFiltersSaveError =>
      'Non ho potuto salvare questo filtro.';

  @override
  String get tasksSavedFiltersSavePageHelper =>
      'Dare a questo filtro un nome breve. È possibile riordinarlo in seguito nei filtri Task.';

  @override
  String get tasksSavedFiltersSavePopupCancel => 'Annullamento';

  @override
  String get tasksSavedFiltersSavePopupHint => 'ad es. bloccati o in attesa';

  @override
  String get tasksSavedFiltersSavePopupSave => 'Salva';

  @override
  String get tasksSavedFiltersSavePopupTitle => 'Nome questo filtro';

  @override
  String get tasksSavedFiltersSheetTitle => 'Filtri di attività';

  @override
  String get tasksSavedFiltersShowLess => 'Mostra meno';

  @override
  String tasksSavedFiltersShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count più salvati filtri',
      one: '1 filtro più salvato',
    );
    return '$_temp0';
  }

  @override
  String tasksSavedFiltersTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attività',
      one: '1 attività',
    );
    return '$_temp0';
  }

  @override
  String get tasksSavedFiltersUpdateButtonLabel => 'Filtro aggiornamento';

  @override
  String get tasksSavedFiltersUpdateExistingDescription =>
      'Sostituire i criteri salvati con la configurazione del filtro corrente.';

  @override
  String get tasksSavedFiltersUpdateExistingTitle =>
      'Aggiornare il filtro esistente';

  @override
  String get tasksSavedFilterToastDeleted => 'Filtro cancellato';

  @override
  String tasksSavedFilterToastSaved(String name) {
    return 'Salvataggio \'$name\'';
  }

  @override
  String tasksSavedFilterToastUpdated(String name) {
    return 'Aggiornato \'$name\'';
  }

  @override
  String get tasksSearchModeLabel => 'Modalità di ricerca';

  @override
  String get tasksShowCreationDate => 'Mostra la data di creazione su carte';

  @override
  String get tasksShowDueDate => 'Mostrare la data di scadenza sulle carte';

  @override
  String get tasksSortByCreationDate => 'Creato';

  @override
  String get tasksSortByDueDate => 'Data di scadenza';

  @override
  String get tasksSortByLabel => 'Ordina per';

  @override
  String get tasksSortByPriority => 'Priorità';

  @override
  String get taskStatusAll => 'Tutti';

  @override
  String get taskStatusBlocked => 'Bloccato';

  @override
  String get taskStatusDone => 'Fatto';

  @override
  String get taskStatusGroomed => 'Rifinito';

  @override
  String get taskStatusInProgress => 'In corso';

  @override
  String get taskStatusLabel => 'Stato:';

  @override
  String get taskStatusOnHold => 'Aspetta.';

  @override
  String get taskStatusOpen => 'Aprire';

  @override
  String get taskStatusRejected => 'Rifiuti';

  @override
  String get taskTitleEmpty => 'Nessun titolo';

  @override
  String get taskUntitled => '(non legato)';

  @override
  String get thinkingDisclosureCopied => 'Ragione copiata';

  @override
  String get thinkingDisclosureCopy => 'Copia ragionamento';

  @override
  String get thinkingDisclosureHide => 'Nascondere il ragionamento';

  @override
  String get thinkingDisclosureShow => 'Mostra il ragionamento';

  @override
  String get thinkingDisclosureStateCollapsed => 'collassato';

  @override
  String get thinkingDisclosureStateExpanded => 'ampliato';

  @override
  String get timeEntryItemEnd => 'Fine';

  @override
  String get timeEntryItemRunning => 'Esecuzione';

  @override
  String get timeEntryItemStart => 'Iniziare';

  @override
  String get unlinkButton => 'Un link';

  @override
  String get unlinkTaskConfirm =>
      'Sei sicuro di voler sbloccare questo compito?';

  @override
  String get unlinkTaskTitle => 'Scollega attività';

  @override
  String vectorSearchTiming(int elapsed, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$elapsed ms, $count risultati',
      one: '$elapsed ms, $count risultato',
    );
    return '$_temp0';
  }

  @override
  String get viewMenuTitle => 'Vista';

  @override
  String get viewMenuZoomIn => 'Zoom in su';

  @override
  String get viewMenuZoomOut => 'Zoom fuori';

  @override
  String get viewMenuZoomReset => 'Dimensioni effettive';

  @override
  String get whatsNewBadgeNew => 'NUOVO';

  @override
  String get whatsNewDoneButton => 'Fatto';

  @override
  String get whatsNewSkipButton => 'Salta!';
}

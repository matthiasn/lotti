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
  String agentABComparisonChoose(String option) {
    return 'Alege $option';
  }

  @override
  String agentABComparisonOption(String option) {
    return 'Opțiunea $option';
  }

  @override
  String agentABComparisonPrefer(String option) {
    return 'Prefer Opțiunea $option';
  }

  @override
  String get agentBinaryChoiceNo => 'Nu';

  @override
  String get agentBinaryChoiceYes => 'Da';

  @override
  String get agentCategoryRatingsScaleMax => 'Corectează mai întâi';

  @override
  String get agentCategoryRatingsScaleMin => 'Lasă așa';

  @override
  String agentCategoryRatingsStarLabel(int starIndex, int totalStars) {
    return '$starIndex din $totalStars stele';
  }

  @override
  String get agentCategoryRatingsSubmit => 'Folosește aceste priorități';

  @override
  String get agentCategoryRatingsSubtitle =>
      'Cât de important este să corectez fiecare dintre aceste puncte? 1 înseamnă lasă așa, 5 înseamnă corectează mai întâi.';

  @override
  String get agentCategoryRatingsTitle => 'Ajută-mă să prioritizez';

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
  String agentConversationThreadSummary(
    int messageCount,
    int toolCallCount,
    String shortId,
  ) {
    return '$messageCount mesaje, $toolCallCount apeluri de instrumente · $shortId';
  }

  @override
  String agentConversationTokenCount(String tokenCount) {
    return '$tokenCount jetoane';
  }

  @override
  String get agentDefaultProfileLabel => 'Profil de inferență implicit';

  @override
  String agentDetailErrorLoading(String error) {
    return 'Eroare la încărcarea agentului: $error';
  }

  @override
  String get agentDetailNotFound => 'Agentul nu a fost găsit.';

  @override
  String get agentDetailUnexpectedType => 'Tip de entitate neașteptat.';

  @override
  String get agentEvolutionApprovalRate => 'Rata de aprobare';

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
  String get agentEvolutionHistoryTitle => 'Istoricul evoluției';

  @override
  String get agentEvolutionMetricActive => 'Active';

  @override
  String get agentEvolutionMetricAvgDuration => 'Durată medie';

  @override
  String get agentEvolutionMetricFailures => 'Eșecuri';

  @override
  String get agentEvolutionMetricSuccess => 'Succes';

  @override
  String get agentEvolutionMetricWakes => 'Activări';

  @override
  String get agentEvolutionNoSessions => 'Nu există sesiuni de evoluție încă';

  @override
  String get agentEvolutionNoteRecorded => 'Notă înregistrată';

  @override
  String get agentEvolutionProposalApprovalFailed =>
      'Aprobarea a eșuat — te rog încearcă din nou';

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
  String get agentEvolutionSessionAbandoned =>
      'Sesiune încheiată fără modificări';

  @override
  String agentEvolutionSessionCompleted(int version) {
    return 'Sesiune finalizată — versiunea $version creată';
  }

  @override
  String get agentEvolutionSessionCount => 'Sesiuni';

  @override
  String get agentEvolutionSessionError =>
      'Sesiunea de evoluție nu a putut fi pornită';

  @override
  String agentEvolutionSessionProgress(int sessionNumber, int totalSessions) {
    return 'Sesiunea $sessionNumber din $totalSessions';
  }

  @override
  String get agentEvolutionSessionStarting =>
      'Se pornește sesiunea de evoluție...';

  @override
  String agentEvolutionSessionTitle(int sessionNumber) {
    return 'Evoluție #$sessionNumber';
  }

  @override
  String agentEvolutionSoulCurrentField(String field) {
    return 'Curent — $field';
  }

  @override
  String agentEvolutionSoulProposedField(String field) {
    return 'Propus — $field';
  }

  @override
  String get agentEvolutionStatusAbandoned => 'Abandonat';

  @override
  String get agentEvolutionStatusActive => 'Activ';

  @override
  String get agentEvolutionStatusCompleted => 'Finalizat';

  @override
  String get agentEvolutionTimelineFeedbackLabel => 'Feedback';

  @override
  String get agentEvolutionVersionProposed => 'Versiune propusă';

  @override
  String get agentFeedbackCategoryAccuracy => 'Acuratețe';

  @override
  String get agentFeedbackCategoryBreakdownTitle => 'Defalcare pe categorii';

  @override
  String get agentFeedbackCategoryCommunication => 'Comunicare';

  @override
  String get agentFeedbackCategoryGeneral => 'General';

  @override
  String get agentFeedbackCategoryPrioritization => 'Prioritizare';

  @override
  String get agentFeedbackCategoryTimeliness => 'Promptitudine';

  @override
  String get agentFeedbackCategoryTooling => 'Instrumente';

  @override
  String get agentFeedbackClassificationTitle => 'Clasificare feedback';

  @override
  String get agentFeedbackExcellenceTitle => 'Note de excelență';

  @override
  String get agentFeedbackGrievancesTitle => 'Nemulțumiri';

  @override
  String get agentFeedbackHighPriorityTitle =>
      'Feedback de prioritate ridicată';

  @override
  String agentFeedbackItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de elemente',
      few: '$count elemente',
      one: '1 element',
    );
    return '$_temp0';
  }

  @override
  String get agentFeedbackSourceDecision => 'Decizie';

  @override
  String get agentFeedbackSourceMetric => 'Metrică';

  @override
  String get agentFeedbackSourceObservation => 'Observație';

  @override
  String get agentFeedbackSourceRating => 'Evaluare';

  @override
  String get agentInstancesEmptyFiltered =>
      'Nicio instanță nu corespunde filtrelor dvs.';

  @override
  String get agentInstancesFilterClearAll => 'Șterge tot';

  @override
  String get agentInstancesFilterClearSection => 'Șterge';

  @override
  String get agentInstancesFilterSectionSoul => 'Suflet';

  @override
  String get agentInstancesFilterSectionStatus => 'Stare';

  @override
  String get agentInstancesFilterSectionType => 'Tip';

  @override
  String agentInstancesGroupActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de active',
      few: '$count active',
      one: '1 activă',
    );
    return '$_temp0';
  }

  @override
  String get agentInstancesGroupBySoul => 'Suflet';

  @override
  String get agentInstancesGroupByStatus => 'Stare';

  @override
  String get agentInstancesGroupByType => 'Tip';

  @override
  String get agentInstancesKindEvolution => 'Evoluție';

  @override
  String get agentInstancesKindTaskAgent => 'Agent de sarcini';

  @override
  String get agentInstancesPageTitle => 'Instanțe agenți';

  @override
  String agentInstancesResultCountAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de instanțe',
      few: '$count instanțe',
      one: '1 instanță',
    );
    return '$_temp0';
  }

  @override
  String agentInstancesResultCountFiltered(int filtered, int total) {
    return '$filtered din $total';
  }

  @override
  String get agentInstancesSearchClear => 'Șterge căutarea';

  @override
  String get agentInstancesSearchPlaceholder => 'Caută instanțe…';

  @override
  String get agentInstancesSortName => 'Nume';

  @override
  String get agentInstancesSortOldest => 'Cele mai vechi';

  @override
  String get agentInstancesSortRecent => 'Recente';

  @override
  String get agentInstancesTitle => 'Instanțe';

  @override
  String get agentInstancesToolbarFilters => 'Filtre';

  @override
  String get agentInstancesToolbarGroupBy => 'Grupează după';

  @override
  String get agentInstancesUnassignedSoul => 'Neatribuit';

  @override
  String get agentLifecycleActive => 'Activ';

  @override
  String get agentLifecycleCreated => 'Creat';

  @override
  String get agentLifecycleDestroyed => 'Distrus';

  @override
  String get agentLifecycleDormant => 'Inactiv';

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
  String agentPendingWakesActivityHourDetail(
    String hour,
    int count,
    String reasons,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count treziri',
      one: '1 trezire',
    );
    return '$hour: $_temp0 ($reasons)';
  }

  @override
  String get agentPendingWakesActivityTitle => 'Activitate treziri (24h)';

  @override
  String agentPendingWakesActivityTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count treziri în total',
      one: '1 trezire în total',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesDeleteTooltip => 'Elimină trezirea';

  @override
  String get agentPendingWakesEmptyFiltered =>
      'Nicio trezire nu se potrivește cu filtrele dvs.';

  @override
  String get agentPendingWakesFilterSectionType => 'Tip';

  @override
  String get agentPendingWakesGroupByType => 'Tip';

  @override
  String get agentPendingWakesPendingLabel => 'În așteptare';

  @override
  String agentPendingWakesRunningHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'În execuție ($count)',
      one: 'În execuție',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesScheduledLabel => 'Programată';

  @override
  String get agentPendingWakesSearchPlaceholder => 'Caută treziri…';

  @override
  String get agentPendingWakesSortDueLatest => 'Programate ultimele';

  @override
  String get agentPendingWakesSortDueSoonest => 'Programate primele';

  @override
  String get agentPendingWakesTitle => 'Cicluri de trezire';

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
  String get agentRitualReviewAction => 'Începe conversația';

  @override
  String get agentRitualReviewNegativeSignals => 'Negativ';

  @override
  String get agentRitualReviewNeutralSignals => 'Neutru';

  @override
  String get agentRitualReviewNoFeedback =>
      'Niciun semnal de feedback în această fereastră';

  @override
  String get agentRitualReviewNoNegativeSignals =>
      'Niciun semnal de feedback negativ în această filă';

  @override
  String get agentRitualReviewNoNeutralSignals =>
      'Niciun semnal de feedback neutru în această filă';

  @override
  String get agentRitualReviewNoPositiveSignals =>
      'Niciun semnal de feedback pozitiv în această filă';

  @override
  String get agentRitualReviewPositiveSignals => 'Pozitiv';

  @override
  String get agentRitualReviewProposalSection => 'Propunerea curentă';

  @override
  String get agentRitualReviewSessionHistory => 'Istoricul sesiunilor';

  @override
  String get agentRitualReviewTitle => '1-on-1';

  @override
  String get agentRitualSummaryApprovedChangesHeading => 'Modificări aprobate';

  @override
  String get agentRitualSummaryConversationHeading => 'Conversație';

  @override
  String get agentRitualSummaryRecapHeading => 'Rezumatul sesiunii';

  @override
  String get agentRitualSummaryRoleAssistant => 'Agent';

  @override
  String get agentRitualSummaryRoleUser => 'Tu';

  @override
  String get agentRitualSummaryStartHint =>
      'Începe un 1-on-1 pentru a revizui ce te-a deranjat, ce a funcționat și ce ar trebui schimbat.';

  @override
  String get agentRitualSummarySubtitle =>
      'Sesiunile 1-on-1 anterioare, activitatea reală de activări și modificările convenite.';

  @override
  String get agentRitualSummaryTokensSinceLast => 'Tokeni de la ultimul 1-on-1';

  @override
  String get agentRitualSummaryWakeHistory30Days =>
      'Activitate activări (ultimele 30 de zile)';

  @override
  String get agentRitualSummaryWakesSinceLast =>
      'Activări de la ultimul 1-on-1';

  @override
  String get agentRunningIndicator => 'În execuție';

  @override
  String get agentSessionProgressTitle => 'Progresul sesiunii';

  @override
  String get agentSettingsSubtitle => 'Șabloane, instanțe și monitorizare';

  @override
  String get agentSettingsTitle => 'Agenți';

  @override
  String get agentSoulAntiSycophancyLabel => 'Politica anti-lingușire';

  @override
  String get agentSoulAssignedTemplatesTitle => 'Șabloane atribuite';

  @override
  String get agentSoulAssignmentLabel => 'Suflet';

  @override
  String get agentSoulCoachingStyleLabel => 'Stil de coaching';

  @override
  String get agentSoulCreatedSuccess => 'Suflet creat';

  @override
  String get agentSoulCreateTitle => 'Creează un suflet';

  @override
  String get agentSoulDeleteConfirmBody =>
      'Aceasta va elimina sufletul și toate versiunile sale.';

  @override
  String get agentSoulDeleteConfirmTitle => 'Șterge sufletul';

  @override
  String get agentSoulDetailTitle => 'Detalii suflet';

  @override
  String get agentSoulDisplayNameLabel => 'Nume';

  @override
  String get agentSoulEvolutionHistoryTitle => 'Istoricul evoluției sufletului';

  @override
  String get agentSoulEvolutionNoSessions =>
      'Nu există încă sesiuni de evoluție a sufletului';

  @override
  String get agentSoulFieldAntiSycophancy => 'Anti-lingușire';

  @override
  String get agentSoulFieldCoachingStyle => 'Stil de coaching';

  @override
  String get agentSoulFieldToneBounds => 'Limite de ton';

  @override
  String get agentSoulFieldVoice => 'Voce';

  @override
  String get agentSoulInfoTab => 'Info';

  @override
  String get agentSoulNoneAssigned => 'Niciun suflet atribuit';

  @override
  String get agentSoulNotFound => 'Suflet negăsit';

  @override
  String get agentSoulProposalSubtitle => 'Modificări de personalitate propuse';

  @override
  String get agentSoulProposalTitle =>
      'Propunere de personalitate a sufletului';

  @override
  String get agentSoulReviewHeroSubtitle =>
      'Rafinează personalitatea în toate șabloanele care partajează acest suflet. Agentul de evoluție vede feedback-ul de la fiecare șablon care folosește această personalitate.';

  @override
  String get agentSoulReviewStartAction => 'Începe revizuirea personalității';

  @override
  String get agentSoulReviewStartHint =>
      'Începe o sesiune axată pe personalitate pentru a examina feedback-ul și a evolua vocea, tonul, stilul de coaching și sinceritatea.';

  @override
  String agentSoulReviewTemplateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count șabloane partajează acest suflet',
      one: '1 șablon partajează acest suflet',
    );
    return '$_temp0';
  }

  @override
  String get agentSoulReviewTitle => 'Suflet 1-on-1';

  @override
  String get agentSoulRollbackAction => 'Revino la această versiune';

  @override
  String agentSoulRollbackConfirm(int version) {
    return 'Revino la versiunea $version? Toate șabloanele care folosesc acest suflet vor prelua modificarea.';
  }

  @override
  String get agentSoulSelectTitle => 'Selectează un suflet';

  @override
  String get agentSoulsEmptyFiltered =>
      'Niciun suflet nu se potrivește cu filtrele dvs.';

  @override
  String get agentSoulSettingsTab => 'Setări';

  @override
  String get agentSoulsSearchPlaceholder => 'Caută suflete…';

  @override
  String get agentSoulsTitle => 'Suflete';

  @override
  String get agentSoulToneBoundsLabel => 'Limite de ton';

  @override
  String get agentSoulVersionHistoryTitle => 'Istoric versiuni';

  @override
  String agentSoulVersionLabel(int version) {
    return 'Versiunea $version';
  }

  @override
  String get agentSoulVersionSaved => 'Versiune nouă de suflet salvată';

  @override
  String get agentSoulVoiceDirectiveLabel => 'Directivă vocală';

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
  String get agentStatsAllDayLegend => 'Toată ziua';

  @override
  String get agentStatsAverageLabel => 'Medie';

  @override
  String agentStatsByTimeLegend(String time) {
    return 'Zilnic până la $time';
  }

  @override
  String get agentStatsCacheRateLabel => 'Rată cache';

  @override
  String get agentStatsDailyUsageHeading => 'Utilizare zilnică';

  @override
  String get agentStatsInputLabel => 'Intrare';

  @override
  String get agentStatsNoUsage =>
      'Nu s-a înregistrat nicio utilizare de tokenuri în ultimele 7 zile.';

  @override
  String get agentStatsOutputLabel => 'Ieșire';

  @override
  String agentStatsSourceActiveFor(String duration) {
    return 'Activ de $duration';
  }

  @override
  String get agentStatsSourceActivityHeading => 'Activitatea agenților';

  @override
  String agentStatsSourceWakes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de treziri',
      few: '$count treziri',
      one: '1 trezire',
    );
    return '$_temp0';
  }

  @override
  String get agentStatsTabTitle => 'Statistici';

  @override
  String get agentStatsThoughtsLabel => 'Gânduri';

  @override
  String get agentStatsTodayLabel => 'Astăzi';

  @override
  String get agentStatsTokensPerWakeLabel => 'Tokenuri / trezire';

  @override
  String get agentStatsTokensUnit => 'tokenuri';

  @override
  String agentStatsUsageAboveAverage(String time) {
    return 'Utilizați mai multe tokenuri astăzi decât de obicei la $time.';
  }

  @override
  String agentStatsUsageBelowAverage(String time) {
    return 'Utilizați mai puține tokenuri astăzi decât de obicei la $time.';
  }

  @override
  String get agentStatsWakesLabel => 'Treziri';

  @override
  String get agentSuggestionTimeEntryUpdateCurrent => 'Curent';

  @override
  String get agentSuggestionTimeEntryUpdateNoChange => '(neschimbat)';

  @override
  String get agentSuggestionTimeEntryUpdateProposed => 'Propus';

  @override
  String get agentSuggestionTimeEntryUpdateUnavailable =>
      'Înregistrarea originală nu este disponibilă';

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
  String get agentTemplateAggregateTokenUsageHeading =>
      'Utilizare totală de token-uri';

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
  String get agentTemplateDisplayNameLabel => 'Nume';

  @override
  String get agentTemplateEditTitle => 'Editează șablonul';

  @override
  String get agentTemplateEvolveApprove => 'Aprobă și salvează';

  @override
  String get agentTemplateEvolveReject => 'Respinge';

  @override
  String get agentTemplateGeneralDirectiveHint =>
      'Definiți personalitatea, instrumentele, obiectivele și stilul de interacțiune al agentului...';

  @override
  String get agentTemplateGeneralDirectiveLabel => 'Directivă generală';

  @override
  String get agentTemplateInstanceBreakdownHeading => 'Detaliere pe instanță';

  @override
  String get agentTemplateKindImprover => 'Îmbunătățitor de șablon';

  @override
  String get agentTemplateKindProjectAgent => 'Agent de proiect';

  @override
  String get agentTemplateKindTaskAgent => 'Agent de sarcini';

  @override
  String get agentTemplateMetricsTotalWakes => 'Total activări';

  @override
  String get agentTemplateNoneAssigned => 'Niciun șablon atribuit';

  @override
  String get agentTemplateNoTemplates =>
      'Nu sunt șabloane disponibile. Creează unul în Setări mai întâi.';

  @override
  String get agentTemplateNotFound => 'Șablon negăsit';

  @override
  String get agentTemplateNoVersions => 'Nicio versiune';

  @override
  String get agentTemplateReportDirectiveHint =>
      'Definiți structura raportului, secțiunile necesare și regulile de formatare...';

  @override
  String get agentTemplateReportDirectiveLabel => 'Directivă de raport';

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
  String get agentTemplatesEmptyFiltered =>
      'Niciun șablon nu corespunde filtrelor dvs.';

  @override
  String get agentTemplateSettingsTab => 'Setări';

  @override
  String get agentTemplatesFilterSectionKind => 'Tip';

  @override
  String get agentTemplatesGroupByKind => 'Tip';

  @override
  String get agentTemplatesGroupNone => 'Toate';

  @override
  String get agentTemplatesSearchPlaceholder => 'Caută șabloane…';

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
  String get aiAssistantTitle => 'Generează…';

  @override
  String get aiBatchToggleTooltip => 'Comutare la înregistrare standard';

  @override
  String get aiCapabilityChipImageGeneration => 'Generare de imagini';

  @override
  String get aiCapabilityChipImageRecognition => 'Recunoaștere de imagini';

  @override
  String get aiCapabilityChipThinking => 'Gândire';

  @override
  String get aiCapabilityChipTranscription => 'Transcriere';

  @override
  String get aiCardEmptyProposals =>
      'Nicio propunere deschisă · agentul va afișa aici noile modificări';

  @override
  String aiCardHistoryToggle(int count) {
    return 'Istoric · $count';
  }

  @override
  String get aiCardOpenAgentInternals =>
      'Deschideți componentele interne ale agentului';

  @override
  String get aiCardProposalConfirmed => 'Confirmată';

  @override
  String get aiCardProposalDismissed => 'Respinsă';

  @override
  String get aiCardProposalKindAdd => 'Adăugați';

  @override
  String get aiCardProposalKindDue => 'Scadență';

  @override
  String get aiCardProposalKindEstimate => 'Estimare';

  @override
  String get aiCardProposalKindLabel => 'Etichetă';

  @override
  String get aiCardProposalKindPriority => 'Prioritate';

  @override
  String get aiCardProposalKindRemove => 'Eliminați';

  @override
  String get aiCardProposalKindStatus => 'Stare';

  @override
  String get aiCardProposalKindUpdate => 'Actualizați';

  @override
  String get aiCardReadMore => 'Citiți mai mult';

  @override
  String get aiCardShowLess => 'Afișați mai puțin';

  @override
  String get aiCardTitle => 'Rezumat AI';

  @override
  String get aiChatMessageCopied => 'Copiat în clipboard';

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Eșec la încărcarea modelelor. Vă rugăm să încercați din nou.';

  @override
  String get aiConfigNoModelsAvailable =>
      'Nu sunt configurate modele AI încă. Vă rugăm să adăugați unul în setări.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Niciun model nu îndeplinește cerințele pentru acest prompt. Vă rugăm să configurați modele cu capabilitățile necesare.';

  @override
  String get aiConfigSelectProviderModalTitle =>
      'Selectați furnizorul de inferență';

  @override
  String get aiConfigSelectProviderTypeModalTitle =>
      'Selectați tipul de furnizor';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Folosește raționamentul';

  @override
  String get aiFormCancel => 'Anulează';

  @override
  String get aiFormFixErrors =>
      'Vă rugăm să corectați erorile înainte de salvare';

  @override
  String get aiFormNoChanges => 'Nu există modificări nesalvate';

  @override
  String get aiInferenceErrorAuthenticationTitle => 'Autentificare eșuată';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Conexiune eșuată';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Cerere invalidă';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Limită de cereri depășită';

  @override
  String get aiInferenceErrorRetryButton => 'Încearcă din nou';

  @override
  String get aiInferenceErrorServerTitle => 'Eroare de server';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Sugestii:';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Timp de așteptare depășit';

  @override
  String get aiInferenceErrorUnknownTitle => 'Eroare';

  @override
  String get aiInternalsTitle => 'Componente interne ale agentului';

  @override
  String aiOllamaModelInstalledSuccessfully(String modelName) {
    return 'Modelul „$modelName” a fost instalat cu succes!';
  }

  @override
  String get aiProfileCardActiveBadge => 'Activ';

  @override
  String get aiProfileSlotModelMissing => 'lipsește';

  @override
  String get aiProviderAlibabaDescription =>
      'Familia de modele Qwen de la Alibaba Cloud prin API-ul DashScope';

  @override
  String get aiProviderCardFixButton => 'Remediați';

  @override
  String aiProviderCardStatusConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Conectat · $count de modele',
      few: 'Conectat · $count modele',
      one: 'Conectat · 1 model',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardMenuTooltip => 'Mai multe acțiuni';

  @override
  String aiProviderCardModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de modele',
      few: '$count modele',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String aiProviderCardModelCountWithLastUsed(int count, String lastUsed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de modele · folosite ultima dată $lastUsed',
      few: '$count modele · folosite ultima dată $lastUsed',
      one: '1 model · folosit ultima dată $lastUsed',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardOllamaHint => 'Asigurați-vă că Ollama rulează';

  @override
  String get aiProviderCardStatusConnectedShort => 'Conectat';

  @override
  String get aiProviderCardStatusInvalidKey => 'Cheie nevalidă';

  @override
  String get aiProviderCardStatusOfflineShort => 'Deconectat';

  @override
  String get aiProviderCardStatusOffline =>
      'Deconectat · Asigurați-vă că Ollama rulează';

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
  String get aiProviderUnknownName => 'Furnizor AI';

  @override
  String get aiProviderTaglineAnthropic =>
      'Claude Sonnet · raționament cu context lung';

  @override
  String get aiProviderTaglineGemini =>
      'Nivel gratuit · multimodal · transcriere audio';

  @override
  String get aiProviderTaglineOllama =>
      'Rulează pe Mac-ul dvs. · zero apeluri în cloud';

  @override
  String get aiProviderTaglineOpenAi => 'Raționament de top · familia GPT-5.2';

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
  String get aiSettingsAddProviderButton => 'Adaugă furnizor';

  @override
  String get aiSettingsPageLead =>
      'Configurați furnizorii AI, modelele pe care Lotti le poate apela și profilurile de inferență care decid ce model gestionează fiecare sarcină.';

  @override
  String get aiSettingsSearchHintShort => 'Căutați';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Șterge toate filtrele';

  @override
  String get aiSettingsClearFiltersButton => 'Șterge';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filtrează după capabilitatea $capability';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filtrează după $provider';
  }

  @override
  String get aiSettingsCounterModels => 'Modele';

  @override
  String get aiSettingsCounterProfiles => 'Profile';

  @override
  String get aiSettingsCounterProviders => 'Furnizori';

  @override
  String get aiSettingsEmptyDescription =>
      'Adăugați unul pentru a debloca transcrierea, recunoașterea de imagini, generarea de imagini și căutarea semantică.';

  @override
  String get aiSettingsEmptyTitle => 'Încă niciun furnizor';

  @override
  String get aiSettingsFilterByReasoningTooltip =>
      'Filtrează după capacitatea de raționament';

  @override
  String get aiSettingsFtueBannerDescription =>
      'Durează aproximativ un minut. Lotti va configura modelele și un profil inițial pentru dvs.';

  @override
  String get aiSettingsFtueBannerStartButton => 'Începeți configurarea';

  @override
  String get aiSettingsFtueBannerTitle => 'Adăugați primul dvs. furnizor AI';

  @override
  String get aiSettingsModalityAudio => 'Audio';

  @override
  String get aiSettingsModalityText => 'Text';

  @override
  String get aiSettingsModalityVision => 'Viziune';

  @override
  String get aiSettingsNoModelsConfigured => 'Niciun model AI configurat';

  @override
  String get aiSettingsNoProvidersConfigured => 'Niciun furnizor AI configurat';

  @override
  String get aiSettingsPageTitle => 'Setări AI';

  @override
  String get aiSettingsReasoningLabel => 'Raționament';

  @override
  String get aiSettingsSearchHint => 'Caută configurații AI...';

  @override
  String get aiSettingsTabModels => 'Modele';

  @override
  String get aiSettingsTabProfiles => 'Profile';

  @override
  String get aiSettingsTabProviders => 'Furnizori';

  @override
  String get aiSetupPreviewAcceptButton => 'Acceptați și finalizați';

  @override
  String get aiSetupPreviewAlreadyAddedSectionLabel => 'Deja adăugate';

  @override
  String aiSetupPreviewCategoryFooter(String categoryName) {
    return 'Configurați categoria de test $categoryName pentru a o încerca.';
  }

  @override
  String aiSetupPreviewConnectedHeader(String providerName) {
    return '$providerName conectat';
  }

  @override
  String get aiSetupPreviewCustomizeButton => 'Personalizați';

  @override
  String get aiSetupPreviewLead =>
      'Verificați ce va adăuga Lotti. Debifați ce nu doriți — puteți configura manual mai târziu oricând.';

  @override
  String get aiSetupPreviewLiveBadge => 'Live';

  @override
  String aiSetupPreviewModalTitle(String providerName) {
    return 'Configurare $providerName';
  }

  @override
  String get aiSetupPreviewModelsSectionLabel => 'Modele';

  @override
  String get aiSetupPreviewProfileSectionLabel => 'Profil de inferență';

  @override
  String get aiSetupPreviewProfileSetActiveBadge => 'Activați';

  @override
  String aiSetupResultBulletCategoryCreated(String categoryName) {
    return 'Categoria de test $categoryName a fost configurată';
  }

  @override
  String aiSetupResultBulletCategoryReused(String categoryName) {
    return 'Se reutilizează categoria de test existentă $categoryName';
  }

  @override
  String aiSetupResultBulletModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de modele configurate',
      few: '$count modele configurate',
      one: '1 model configurat',
    );
    return '$_temp0';
  }

  @override
  String aiSetupResultBulletProfile(String profileName) {
    return 'Profil de inferență $profileName creat';
  }

  @override
  String aiSetupResultErrorsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de probleme',
      few: '$count probleme',
      one: '1 problemă',
    );
    return '$_temp0 la configurare';
  }

  @override
  String aiSetupResultHeader(String providerName) {
    return '$providerName este conectat';
  }

  @override
  String get aiSetupResultLead =>
      'Am configurat totul pentru dvs. Funcțiile AI sunt gata de utilizat în jurnalul dvs.';

  @override
  String aiSetupResultModalTitle(String providerName) {
    return '$providerName gata';
  }

  @override
  String get aiSetupResultReviewSetupButton => 'Verificați configurarea';

  @override
  String get aiSetupResultStartUsingButton => 'Începeți să utilizați AI';

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
  String get aiTaskSummaryTitle => 'Rezumatul sarcinii AI';

  @override
  String get apiKeyAddPageTitle => 'Adaugă furnizor';

  @override
  String get apiKeyEditLoadError =>
      'Eșec la încărcarea configurației cheii API';

  @override
  String get apiKeyEditPageTitle => 'Editează furnizor';

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
  String backfillAdvancedRecoveryActions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count acțiuni',
      one: '1 acțiune',
    );
    return '$_temp0';
  }

  @override
  String get backfillAdvancedRecoveryTitle => 'Recuperare avansată';

  @override
  String get backfillAskPeersConfirmAccept => 'Întreabă colegii';

  @override
  String backfillAskPeersConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Aceasta resetează cele $count de intrări nerezolvabile din jurnalul de secvență înapoi la lipsă, astfel încât parcurgerea normală de completare să întrebe din nou colegii. Colegii care încă au datele vor răspunde; intrările cu adevărat irecuperabile vor fi retrase din nou după fereastra de amnistie de 7 zile.',
      few:
          'Aceasta resetează cele $count intrări nerezolvabile din jurnalul de secvență înapoi la lipsă, astfel încât parcurgerea normală de completare să întrebe din nou colegii. Colegii care încă au datele vor răspunde; intrările cu adevărat irecuperabile vor fi retrase din nou după fereastra de amnistie de 7 zile.',
      one:
          'Aceasta resetează 1 intrare nerezolvabilă din jurnalul de secvență înapoi la lipsă, astfel încât parcurgerea normală de completare să întrebe din nou colegii. Colegii care încă au datele vor răspunde; intrările cu adevărat irecuperabile vor fi retrase din nou după fereastra de amnistie de 7 zile.',
    );
    return '$_temp0';
  }

  @override
  String get backfillAskPeersConfirmTitle =>
      'Întrebați din nou colegii pentru intrări nerezolvabile?';

  @override
  String get backfillAskPeersDescription =>
      'Resetează fiecare intrare nerezolvabilă din jurnalul de secvență înapoi la lipsă și lasă parcurgerea normală de completare să întrebe din nou colegii.';

  @override
  String get backfillAskPeersProcessing => 'Se redeschide…';

  @override
  String get backfillAskPeersTitle => 'Întreabă colegii pentru nerezolvabile';

  @override
  String backfillAskPeersTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Întreabă colegii pentru $count de intrări',
      few: 'Întreabă colegii pentru $count intrări',
      one: 'Întreabă colegii pentru 1 intrare',
    );
    return '$_temp0';
  }

  @override
  String get backfillCatchUpDescription =>
      'Solicitați acum colegilor intrările lipsă recente.';

  @override
  String backfillDevicesMeta(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ID-uri dispozitive',
      one: '1 ID dispozitiv',
    );
    return '$_temp0';
  }

  @override
  String get backfillManualDescription =>
      'Solicită toate intrările lipsă indiferent de vechime. Folosiți pentru a recupera lacune de sincronizare mai vechi.';

  @override
  String get backfillManualProcessing => 'Se procesează...';

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
  String get backfillReRequestTitle => 'Resolicită în așteptare';

  @override
  String get backfillReRequestTrigger => 'Resolicită intrări în așteptare';

  @override
  String get backfillResetUnresolvableDescription =>
      'Resetează intrările marcate ca nerezolvabile înapoi la lipsă, pentru a putea fi solicitate din nou. Utilizați după repopularea jurnalului de secvență.';

  @override
  String get backfillResetUnresolvableProcessing => 'Se resetează...';

  @override
  String get backfillResetUnresolvableTitle => 'Resetare nerezolvabile';

  @override
  String get backfillResetUnresolvableTrigger =>
      'Resetați intrările nerezolvabile';

  @override
  String get backfillRetireStuckConfirmAccept => 'Retrage acum';

  @override
  String backfillRetireStuckConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Marchează cele $count de intrări curent deschise (lipsă sau solicitate) din jurnalul de secvență ca nerezolvabile. Folosiți aceasta pentru a debloca marcajul când intrările au fost blocate o vreme fără ca fereastra de amnistie de 7 zile să fi expirat. Intrările pot fi resuscitate dacă datele lor ajung ulterior pe disc cu un ceas vectorial valid.',
      few:
          'Marchează cele $count intrări curent deschise (lipsă sau solicitate) din jurnalul de secvență ca nerezolvabile. Folosiți aceasta pentru a debloca marcajul când intrările au fost blocate o vreme fără ca fereastra de amnistie de 7 zile să fi expirat. Intrările pot fi resuscitate dacă datele lor ajung ulterior pe disc cu un ceas vectorial valid.',
      one:
          'Marchează 1 intrare curent deschisă (lipsă sau solicitată) din jurnalul de secvență ca nerezolvabilă. Folosiți aceasta pentru a debloca marcajul când intrările au fost blocate o vreme fără ca fereastra de amnistie de 7 zile să fi expirat. Intrările pot fi resuscitate dacă datele lor ajung ulterior pe disc cu un ceas vectorial valid.',
    );
    return '$_temp0';
  }

  @override
  String get backfillRetireStuckConfirmTitle =>
      'Retrageți acum intrările blocate?';

  @override
  String get backfillRetireStuckDescription =>
      'Forțează fiecare intrare lipsă sau solicitată curent deschisă din jurnalul de secvență la nerezolvabilă. Sare peste amnistia de 7 zile — folosiți doar pentru rândurile blocate care blochează marcajul.';

  @override
  String get backfillRetireStuckProcessing => 'Se retrage…';

  @override
  String get backfillRetireStuckTitle => 'Retrage intrări blocate';

  @override
  String backfillRetireStuckTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retrage $count de intrări blocate',
      few: 'Retrage $count intrări blocate',
      one: 'Retrage 1 intrare blocată',
    );
    return '$_temp0';
  }

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
  String get backfillStatusInboundQueue => 'Coadă de intrare';

  @override
  String get backfillStatusMissing => 'Lipsă';

  @override
  String get backfillStatusSkipped => 'Omis';

  @override
  String get backfillToggleDescription =>
      'Solicită intrările lipsă din ultimele 24 de ore.';

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
  String get categoryAiDefaultsDescription =>
      'Setați profilul AI și șablonul de agent implicit pentru sarcinile noi din această categorie';

  @override
  String get categoryAiDefaultsTitle => 'Setări implicite AI';

  @override
  String get categoryCreationError =>
      'Nu s-a putut crea categoria. Vă rugăm să încercați din nou.';

  @override
  String get categoryDefaultLanguageDescription =>
      'Setați o limbă implicită pentru sarcinile din această categorie';

  @override
  String get categoryDefaultProfileHint => 'Selectați un profil…';

  @override
  String get categoryDefaultTemplateHint => 'Selectați un șablon…';

  @override
  String get categoryDefaultTemplateLabel => 'Șablon de agent implicit';

  @override
  String get categoryDeleteConfirm => 'DA, ȘTERGE ACEASTĂ CATEGORIE';

  @override
  String get categoryDeleteConfirmation =>
      'Această acțiune nu poate fi anulată. Toate intrările din această categorie vor fi păstrate, dar nu vor mai fi categorizate.';

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
  String get categorySearchPlaceholder => 'Caută categorii...';

  @override
  String get changeSetCardTitle => 'Modificări propuse';

  @override
  String get changeSetConfirmAll => 'Confirmați toate';

  @override
  String changeSetConfirmAllPartialIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elemente au avut probleme parțiale',
      one: '1 element a avut probleme parțiale',
    );
    return '$_temp0';
  }

  @override
  String get changeSetConfirmError => 'Modificarea nu a putut fi aplicată';

  @override
  String get changeSetItemConfirmed => 'Modificare aplicată';

  @override
  String changeSetItemConfirmedWithWarning(String warning) {
    return 'Aplicată cu avertisment: $warning';
  }

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
  String checklistAiConfidenceLabel(String level) {
    return 'Încredere: $level';
  }

  @override
  String get checklistAiMarkComplete => 'Marchează ca finalizat';

  @override
  String get checklistAiSuggestionBody =>
      'Acest element pare să fie finalizat:';

  @override
  String get checklistAiSuggestionTitle => 'Sugestie AI';

  @override
  String get checklistAllDone => 'Toate elementele sunt finalizate!';

  @override
  String get checklistCollapseTooltip => 'Restrângeți';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total finalizate';
  }

  @override
  String get checklistDelete => 'Șterge lista de verificare?';

  @override
  String get checklistExpandTooltip => 'Extindeți';

  @override
  String get checklistExportAsMarkdown =>
      'Exportă lista de verificare ca Markdown';

  @override
  String get checklistExportFailed => 'Exportul a eșuat';

  @override
  String get checklistItemArchived => 'Element arhivat';

  @override
  String get checklistItemArchiveUndo => 'Anulează';

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
  String get checklistMarkdownCopied =>
      'Lista de verificare copiată ca Markdown';

  @override
  String get checklistMoreTooltip => 'Mai mult';

  @override
  String get checklistNoneDone => 'Niciun element finalizat încă.';

  @override
  String get checklistNothingToExport => 'Nu există elemente de exportat';

  @override
  String get checklistProgressSemantics => 'Progresul listei de verificare';

  @override
  String get checklistShare => 'Partajează';

  @override
  String get checklistShareHint => 'Apăsare lungă pentru partajare';

  @override
  String get checklistsReorder => 'Reordonează';

  @override
  String get clearButton => 'Șterge';

  @override
  String get colorLabel => 'Culoare:';

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
  String get configFlagEnableAiStreaming =>
      'Activează streamingul AI pentru acțiunile legate de sarcini';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Transmite răspunsurile AI pentru acțiunile legate de sarcini. Dezactivați pentru a stoca răspunsurile în buffer și a menține interfața mai fluidă.';

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
  String get configFlagEnableEmbeddings => 'Generare încorporări';

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
  String get configFlagEnableProjects => 'Activează proiectele';

  @override
  String get configFlagEnableProjectsDescription =>
      'Afișează funcțiile de gestionare a proiectelor pentru organizarea sarcinilor în proiecte.';

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
  String get configFlagEnableVectorSearch => 'Căutare vectorială';

  @override
  String get configFlagEnableVectorSearchDescription =>
      'Activează căutarea vectorială în filtrele de sarcini. Necesită embedding-uri activate și Ollama în execuție.';

  @override
  String get configFlagEnableWhatsNew => 'Afișează „Noutăți\"';

  @override
  String get configFlagEnableWhatsNewDescription =>
      'Evidențiază funcțiile și modificările noi în arborele Setărilor.';

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
  String get configFlagShowSidebarWakeQueue =>
      'Afișează coada de treziri în bara laterală';

  @override
  String get configFlagShowSidebarWakeQueueDescription =>
      'Afișează coada de treziri deasupra Setărilor — anteturile, următoarele două treziri cu numărătoare inversă și un link către lista completă.';

  @override
  String get configFlagShowSyncActivityIndicator =>
      'Afișează indicatorul de activitate de sincronizare';

  @override
  String get configFlagShowSyncActivityIndicatorDescription =>
      'Afișează activitatea de sincronizare live în bara laterală — o bandă LED tx/rx cu adâncimea cozilor de ieșire și intrare.';

  @override
  String get conflictApplyButton => 'Aplică';

  @override
  String get conflictApplyFailedTitle => 'Rezoluția nu a putut fi aplicată';

  @override
  String conflictBannerAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'acum $count zile',
      one: 'acum 1 zi',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'acum $count h',
      one: 'acum 1 h',
    );
    return '$_temp0';
  }

  @override
  String get conflictBannerAgoJustNow => 'chiar acum';

  @override
  String conflictBannerAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'acum $count min',
      one: 'acum 1 min',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerDivergedAgo(String entity, String ago) {
    return '$entity · a divergat $ago';
  }

  @override
  String conflictBannerFieldsDifferList(String fields) {
    return 'Diferențe: $fields';
  }

  @override
  String get conflictDetailEntryNotFoundTitle => 'Intrare negăsită';

  @override
  String get conflictDetailLoadErrorTitle =>
      'Conflictul nu a putut fi încărcat';

  @override
  String get conflictDetailNotFoundTitle => 'Conflict negăsit';

  @override
  String get conflictFieldCategory => 'categorie';

  @override
  String get conflictFieldDuration => 'durată';

  @override
  String get conflictFieldTitle => 'Titlu';

  @override
  String get conflictFieldWordCount => 'număr de cuvinte';

  @override
  String get conflictFooterHelperLocalSelected =>
      'Va păstra modificarea locală și va renunța la versiunea sincronizată.';

  @override
  String get conflictFooterHelperPickASide =>
      'Alegeți o parte pentru a aplica.';

  @override
  String get conflictFooterHelperRemoteSelected =>
      'Va accepta versiunea sincronizată și va renunța la modificarea locală.';

  @override
  String conflictHeaderPillEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count intrări',
      one: '1 intrare',
    );
    return '$_temp0';
  }

  @override
  String conflictHeaderPillFieldsDiffer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count câmpuri diferă',
      one: '1 câmp diferă',
    );
    return '$_temp0';
  }

  @override
  String conflictListItemSemanticsLabel(
    String status,
    String timestamp,
    String entityType,
    String id,
  ) {
    return '$status, $timestamp, $entityType, conflict $id';
  }

  @override
  String conflictListItemTooltipFullId(String id) {
    return 'ID conflict: $id';
  }

  @override
  String get conflictMetaLocalEdit => 'modificare locală';

  @override
  String get conflictMetaVecPrefix => 'vec';

  @override
  String get conflictMetaViaSync => 'prin sincronizare';

  @override
  String get conflictPageLeadDesktop =>
      'Diferențele sunt evidențiate inline. Faceți clic pe o parte pentru a folosi versiunea respectivă sau deschideți Editare și îmbinare pentru a le combina.';

  @override
  String get conflictPageLeadMobile =>
      'Diferențele sunt evidențiate inline. Atingeți o parte pentru a folosi versiunea respectivă.';

  @override
  String get conflictPageTitle => 'Conflict de sincronizare';

  @override
  String get conflictPickerEditMerge => 'Editare și îmbinare…';

  @override
  String get conflictPickerUseFromSync => 'Folosiți din sincronizare';

  @override
  String get conflictPickerUseThisDevice => 'Folosiți acest dispozitiv';

  @override
  String get conflictsEmptyDescription =>
      'Totul este sincronizat. Elementele rezolvate rămân disponibile în celălalt filtru.';

  @override
  String get conflictsEmptyTitle => 'Nu s-au detectat conflicte';

  @override
  String get conflictSideFromSync => 'DIN SINCRONIZARE';

  @override
  String get conflictSideThisDevice => 'ACEST DISPOZITIV';

  @override
  String get conflictsResolved => 'rezolvat';

  @override
  String get conflictsUnresolved => 'nerezolvat';

  @override
  String conflictWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de cuvinte',
      few: '$count cuvinte',
      one: '$count cuvânt',
    );
    return '$_temp0';
  }

  @override
  String get copyAsMarkdown => 'Copiază ca Markdown';

  @override
  String get copyAsText => 'Copiază ca text';

  @override
  String get correctionExampleCancel => 'ANULEAZĂ';

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
  String get coverArtChipActive => 'Copertă';

  @override
  String get coverArtChipSet => 'Setează coperta';

  @override
  String get coverArtGenerationComplete => 'Coperta este gata!';

  @override
  String get coverArtGenerationDismissHint =>
      'Poți închide acest dialog — generarea continuă în fundal';

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
  String get dailyOsDayPlan => 'Planul zilei';

  @override
  String get dailyOsDaySummary => 'Rezumatul zilei';

  @override
  String get dailyOsDelete => 'Șterge';

  @override
  String get dailyOsDeletePlannedBlock => 'Ștergeți blocul?';

  @override
  String get dailyOsDeletePlannedBlockConfirm =>
      'Aceasta va elimina blocul planificat din cronologie.';

  @override
  String get dailyOsDraftMessage =>
      'Planul este ciornă. Acceptați pentru a-l confirma.';

  @override
  String get dailyOsDueToday => 'Scadent azi';

  @override
  String get dailyOsDueTodayShort => 'Azi';

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
  String get dailyOsEditPlannedBlock => 'Editează blocul planificat';

  @override
  String get dailyOsEndTime => 'Sfârșit';

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
  String get dailyOsInvalidTimeRange => 'Interval de timp invalid';

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
  String get dailyOsPlanCreated => 'Plan creat cu succes';

  @override
  String get dailyOsPlanCreatedDescription =>
      'Blocurile dvs. de timp au fost salvate. Puteți începe să vă urmăriți sarcinile.';

  @override
  String get dailyOsPlanned => 'Planificat';

  @override
  String get dailyOsPlanWithoutVoice => 'Planificați fără voce';

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
  String get dailyOsSaveError => 'Planul nu a putut fi salvat';

  @override
  String get dailyOsSaveErrorDescription =>
      'Ceva nu a funcționat corect. Vă rugăm să încercați din nou.';

  @override
  String get dailyOsSavePlan => 'Salvați planul';

  @override
  String get dailyOsSelectCategory => 'Selectează categoria';

  @override
  String get dailyOsSetTimeBlocks => 'Setați blocuri de timp';

  @override
  String get dailyOsSetTimeBlocksAddNew => 'Adăugați un bloc de timp nou';

  @override
  String get dailyOsSetTimeBlocksFavourites => 'Favorite';

  @override
  String get dailyOsSetTimeBlocksOther => 'Alte categorii';

  @override
  String get dailyOsSetTimeBlocksTapHint =>
      'Atingeți pentru a adăuga un bloc de timp';

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
  String get designSystemActionVariantTitle => 'Cu acțiune';

  @override
  String get designSystemActivatedLabel => 'Activ';

  @override
  String get designSystemAvatarAwayLabel => 'Absent';

  @override
  String get designSystemAvatarBusyLabel => 'Ocupat';

  @override
  String get designSystemAvatarConnectedLabel => 'Conectat';

  @override
  String get designSystemAvatarEnabledLabel => 'Activat';

  @override
  String get designSystemAvatarSizeMatrixTitle => 'Matricea dimensiunilor';

  @override
  String get designSystemAvatarStatusMatrixTitle => 'Matricea stărilor';

  @override
  String get designSystemBackLabel => 'Înapoi';

  @override
  String get designSystemBreadcrumbCurrentLabel => 'Breadcrumbs';

  @override
  String get designSystemBreadcrumbDesignSystemLabel => 'Design System';

  @override
  String get designSystemBreadcrumbHomeLabel => 'Acasă';

  @override
  String get designSystemBreadcrumbMobileLabel => 'Mobil';

  @override
  String get designSystemBreadcrumbProjectsLabel => 'Proiecte';

  @override
  String get designSystemBreadcrumbSampleLabel => 'Breadcrumb';

  @override
  String get designSystemBreadcrumbTrailTitle => 'Traseu breadcrumb';

  @override
  String get designSystemCalendarPickerLabel => 'Selector calendar';

  @override
  String get designSystemCalendarViewsTitle => 'Vizualizări calendar';

  @override
  String get designSystemCaptionDescriptionSample =>
      'Eliminarea tuturor utilizatorilor a retras publicarea acestui proiect. Adăugați utilizatori pentru a republica.';

  @override
  String get designSystemCaptionIconLeftLabel => 'Pictogramă stânga';

  @override
  String get designSystemCaptionIconTopLabel => 'Pictogramă sus';

  @override
  String get designSystemCaptionNoIconLabel => 'Fără pictogramă';

  @override
  String get designSystemCaptionTitleSample => 'Titlu';

  @override
  String get designSystemCaptionVariantsTitle => 'Variante de caption';

  @override
  String get designSystemCaptionWithActionsLabel => 'Cu acțiuni';

  @override
  String get designSystemCaptionWithoutActionsLabel => 'Fără acțiuni';

  @override
  String get designSystemCheckboxLabel => 'Casetă de selectare';

  @override
  String get designSystemContextMenuDeleteLabel => 'Șterge';

  @override
  String get designSystemContextMenuVariantsTitle =>
      'Variante meniu contextual';

  @override
  String get designSystemCountdownVariantTitle => 'Cu numărătoare inversă';

  @override
  String get designSystemDateCardsTitle => 'Carduri de dată';

  @override
  String get designSystemDefaultLabel => 'Implicit';

  @override
  String get designSystemDisabledLabel => 'Dezactivat';

  @override
  String get designSystemDividerLabelText => 'Etichetă separator';

  @override
  String get designSystemDropdownComboboxTitle => 'Combobox';

  @override
  String get designSystemDropdownFieldLabel => 'Etichetă';

  @override
  String get designSystemDropdownInputLabel => 'Intrare';

  @override
  String get designSystemDropdownListTitle => 'Listă derulantă';

  @override
  String get designSystemDropdownMultiselectInputLabel => 'Selectați echipe';

  @override
  String get designSystemDropdownMultiselectTitle => 'Selecție multiplă';

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
  String get designSystemErrorLabel => 'Eroare';

  @override
  String get designSystemFileUploadClickLabel => 'Faceți clic pentru a încărca';

  @override
  String get designSystemFileUploadCompleteLabel => 'Finalizat';

  @override
  String get designSystemFileUploadDefaultLabel => 'Implicit';

  @override
  String get designSystemFileUploadDragLabel => 'sau trageți și plasați';

  @override
  String get designSystemFileUploadDropZoneSectionTitle => 'Zona de depunere';

  @override
  String get designSystemFileUploadErrorLabel => 'Eroare';

  @override
  String get designSystemFileUploadFailedText => 'Încărcarea a eșuat';

  @override
  String get designSystemFileUploadHintText =>
      'SVG, PNG, JPG sau GIF (max. 800×400px)';

  @override
  String get designSystemFileUploadHoverLabel => 'La survolare';

  @override
  String get designSystemFileUploadItemSectionTitle => 'Elemente fișier';

  @override
  String get designSystemFileUploadRetryLabel => 'Reîncercați';

  @override
  String get designSystemFileUploadUploadingLabel => 'Se încarcă';

  @override
  String get designSystemFilledLabel => 'Completat';

  @override
  String get designSystemHeaderApiDocumentationLabel => 'Documentație API';

  @override
  String get designSystemHeaderBackActionLabel => 'Înapoi';

  @override
  String get designSystemHeaderDesktopSectionTitle => 'Desktop';

  @override
  String get designSystemHeaderHelpActionLabel => 'Ajutor';

  @override
  String get designSystemHeaderMobileSectionTitle => 'Mobil';

  @override
  String get designSystemHeaderNotificationsActionLabel => 'Notificări';

  @override
  String get designSystemHeaderSearchActionLabel => 'Caută';

  @override
  String get designSystemHorizontalLabel => 'Orizontal';

  @override
  String get designSystemHoverLabel => 'La survolare';

  @override
  String get designSystemInfoLabel => 'Info';

  @override
  String get designSystemInputErrorSample => 'Acest câmp este obligatoriu';

  @override
  String get designSystemInputHelperSample => 'Introduceți numele dvs.';

  @override
  String get designSystemInputHintSample => 'Substituent...';

  @override
  String get designSystemInputLabelSample => 'Etichetă';

  @override
  String get designSystemInputVariantsTitle => 'Variante câmp de introducere';

  @override
  String get designSystemInputWithErrorLabel => 'Cu eroare';

  @override
  String get designSystemInputWithHelperLabel => 'Cu text ajutător';

  @override
  String get designSystemInputWithIconsLabel => 'Cu pictograme';

  @override
  String get designSystemListItemActivatedLabel => 'Activat';

  @override
  String get designSystemListItemOneLineLabel => 'O linie';

  @override
  String get designSystemListItemSubtitleSample => 'Subtitlu';

  @override
  String get designSystemListItemTitleSample => 'Titlu';

  @override
  String get designSystemListItemTwoLinesLabel => 'Două linii';

  @override
  String get designSystemListItemVariantsTitle => 'Variante element de listă';

  @override
  String get designSystemListItemWithDividerLabel => 'Cu separator';

  @override
  String get designSystemMediumLabel => 'Mediu';

  @override
  String designSystemMyDailyDurationHoursMinutesCompact(
    int hours,
    int minutes,
  ) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get designSystemMyDailyEditPlanLabel => 'Editează planul';

  @override
  String get designSystemMyDailyGreetingMorning => 'Bună dimineața.';

  @override
  String designSystemMyDailyGreetingWithName(String name) {
    return 'Bună, $name';
  }

  @override
  String get designSystemMyDailyHikeWithDanielaTitle => 'Drumeție cu Daniela';

  @override
  String get designSystemMyDailyLunchBreakTitle => 'Pauză de prânz';

  @override
  String get designSystemMyDailyMeetingsLabel => 'Întâlniri';

  @override
  String get designSystemMyDailyMeetingWithDannyTitle => 'Întâlnire cu Danny';

  @override
  String get designSystemMyDailyProfileActionLabel => 'Profil';

  @override
  String get designSystemMyDailySkiWithMattTitle => 'Mergi la schi cu Matt';

  @override
  String get designSystemMyDailyTapToExpandLabel => 'Apasă pentru extindere';

  @override
  String get designSystemNavigationCollapsedLabel => 'Restrâns';

  @override
  String get designSystemNavigationDailyFilterSectionTitle => 'Filtru zilnic';

  @override
  String get designSystemNavigationExpandedLabel => 'Extins';

  @override
  String get designSystemNavigationFilterByBlockLabel => 'Filtrează după bloc';

  @override
  String get designSystemNavigationHikingLabel => 'Drumeție';

  @override
  String get designSystemNavigationHolidayLabel => 'Concediu';

  @override
  String get designSystemNavigationInsightsLabel => 'Perspective';

  @override
  String get designSystemNavigationLottiTasksLabel => 'Sarcini Lotti';

  @override
  String get designSystemNavigationMyDailyLabel => 'Ziua mea';

  @override
  String get designSystemNavigationNewLabel => 'Nou';

  @override
  String get designSystemNavigationPlaceholderLabel => 'Substituent';

  @override
  String get designSystemNavigationSidebarSectionTitle =>
      'Variante pentru bara laterală';

  @override
  String get designSystemNavigationSubComponentsSectionTitle => 'Subcomponente';

  @override
  String get designSystemNavigationTabBarSectionTitle =>
      'Variante pentru bara de file';

  @override
  String get designSystemPressedLabel => 'Apăsat';

  @override
  String get designSystemProgressBarChunkyLabel => 'Segmentat';

  @override
  String get designSystemProgressBarLabelAndPercentageLabel =>
      'Etichetă + procent';

  @override
  String get designSystemProgressBarLabelOnlyLabel => 'Doar etichetă';

  @override
  String get designSystemProgressBarOffLabel => 'Oprit';

  @override
  String get designSystemProgressBarPercentageOnlyLabel => 'Procent';

  @override
  String get designSystemProgressBarQuestBarLabel => 'Bară de quest';

  @override
  String get designSystemProgressBarQuestLabel => 'Etichetă mega premiu';

  @override
  String get designSystemProgressBarSampleLabel => 'Etichetă bară de progres';

  @override
  String get designSystemRadioButtonLabel => 'Buton radio';

  @override
  String get designSystemScrollbarSizesTitle => 'Dimensiuni bară de derulare';

  @override
  String get designSystemSearchFilledText => 'Căutare Lotti';

  @override
  String get designSystemSearchHintLabel => 'Introdu utilizatorul';

  @override
  String get designSystemSelectedLabel => 'Selectat';

  @override
  String get designSystemSizeScaleTitle => 'Scală de dimensiuni';

  @override
  String get designSystemSmallLabel => 'Mic';

  @override
  String get designSystemSpinnerPlainLabel => 'Simplu';

  @override
  String get designSystemSpinnerSkeletonPulseLabel => 'Puls';

  @override
  String get designSystemSpinnerSkeletonsTitle => 'Schelete';

  @override
  String get designSystemSpinnerSkeletonWaveLabel => 'Val';

  @override
  String get designSystemSpinnerSpinnersTitle => 'Spinnere';

  @override
  String get designSystemSpinnerTrackLabel => 'Cu pistă';

  @override
  String designSystemSplitButtonDropdownSemantics(String label) {
    return 'Deschide opțiunile pentru $label';
  }

  @override
  String get designSystemStateMatrixTitle => 'Matrice de stări';

  @override
  String get designSystemSuccessLabel => 'Succes';

  @override
  String get designSystemTabBarTitle => 'Bara de file';

  @override
  String get designSystemTabPendingLabel => 'În așteptare';

  @override
  String get designSystemTaskListBlockedLabel => 'Blocat';

  @override
  String get designSystemTaskListDefaultLabel => 'Implicit';

  @override
  String get designSystemTaskListHoverLabel => 'La survolare';

  @override
  String get designSystemTaskListItemSectionTitle =>
      'Variante element listă de sarcini';

  @override
  String get designSystemTaskListOnHoldLabel => 'În așteptare';

  @override
  String get designSystemTaskListOpenLabel => 'Deschis';

  @override
  String get designSystemTaskListPressedLabel => 'Apăsat';

  @override
  String get designSystemTaskListSampleTime => '8:00-9:30';

  @override
  String get designSystemTaskListSampleTitle => 'Testare utilizatori';

  @override
  String get designSystemTaskListWithDividerLabel => 'Cu separator';

  @override
  String get designSystemTextareaErrorSample => 'Acest câmp este obligatoriu';

  @override
  String get designSystemTextareaHelperSample => 'Introdu mesajul tău aici';

  @override
  String get designSystemTextareaHintSample => 'Scrie ceva...';

  @override
  String get designSystemTextareaLabelSample => 'Etichetă';

  @override
  String get designSystemTextareaVariantsTitle => 'Variante textarea';

  @override
  String get designSystemTextareaWithCounterLabel => 'Cu contor';

  @override
  String get designSystemTextareaWithErrorLabel => 'Cu eroare';

  @override
  String get designSystemTextareaWithHelperLabel => 'Cu text ajutător';

  @override
  String get designSystemTimePickerFormatsTitle => 'Formate de oră';

  @override
  String get designSystemTimePickerTwelveHourLabel => '12 ore';

  @override
  String get designSystemTimePickerTwentyFourHourLabel => '24 de ore';

  @override
  String get designSystemTitleOnlyVariantTitle => 'Variantă doar titlu';

  @override
  String get designSystemToastDetailsLabel => 'Detalii notificare';

  @override
  String get designSystemToggleLabel => 'Etichetă pentru toggle';

  @override
  String get designSystemTooltipIconMessageSample =>
      'Informații utile despre acest câmp';

  @override
  String get designSystemTooltipIconVariantsTitle => 'Pictogramă tooltip';

  @override
  String get designSystemUndoLabel => 'Anulează';

  @override
  String get designSystemVariantMatrixTitle => 'Matrice de variante';

  @override
  String get designSystemVerticalLabel => 'Vertical';

  @override
  String get designSystemWarningLabel => 'Avertisment';

  @override
  String get designSystemWeeklyCalendarLabel => 'Calendar săptămânal';

  @override
  String get designSystemWithLabelLabel => 'Cu etichetă';

  @override
  String get desktopEmptyStateSelectDashboard =>
      'Selectați un tablou de bord pentru a vedea detaliile';

  @override
  String get desktopEmptyStateSelectProject =>
      'Selectați un proiect pentru a vedea detaliile';

  @override
  String get desktopEmptyStateSelectTask =>
      'Selectați o sarcină pentru a vedea detaliile';

  @override
  String deviceDeletedSuccess(String deviceName) {
    return 'Dispozitivul $deviceName a fost șters cu succes';
  }

  @override
  String deviceDeleteFailed(String error) {
    return 'Ștergerea dispozitivului a eșuat: $error';
  }

  @override
  String get doneButton => 'Gata';

  @override
  String get editMenuTitle => 'Editează';

  @override
  String get editorInsertDivider => 'Inserează separator';

  @override
  String get editorPlaceholder => 'Introduceți notițe...';

  @override
  String get embeddingSelectAll => 'Selectează tot';

  @override
  String get embeddingUnselectAll => 'Deselectează tot';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Alegeți din șabloane de prompt predefinite';

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
  String get imageGenerationError => 'Generarea imaginii a eșuat';

  @override
  String get imageGenerationGenerating => 'Se generează imaginea...';

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
  String get inactiveLabel => 'Inactiv';

  @override
  String get inferenceProfileCreateTitle => 'Creați un profil';

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
  String get inferenceProfileSelectProfile => 'Selectați un profil…';

  @override
  String get inferenceProfilesEmpty => 'Niciun profil de inferență';

  @override
  String inferenceProfileSkillModelRequired(String slotName) {
    return 'Necesită modelul $slotName';
  }

  @override
  String get inferenceProfileSkillsSection => 'Competențe automatizate';

  @override
  String inferenceProfileSkillUsesModel(String slotName) {
    return 'Utilizează modelul $slotName';
  }

  @override
  String get inferenceProfilesTitle => 'Profile de inferență';

  @override
  String get inferenceProfileThinking => 'Gândire';

  @override
  String get inferenceProfileThinkingHighEnd => 'Gândire (nivel înalt)';

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
  String get journalLinkedEntriesActivityFilterAudio => 'Audio';

  @override
  String get journalLinkedEntriesActivityFilterImages => 'Imagini';

  @override
  String get journalLinkedEntriesActivityFilterTimer => 'Cronometru';

  @override
  String get journalLinkedEntriesFilterModalTitle => 'Filtrare și sortare';

  @override
  String get journalLinkedEntriesShowHidden => 'Afișați intrările ascunse';

  @override
  String get journalLinkedEntriesSortLabel => 'Sortați după';

  @override
  String get journalLinkedEntriesSortNewestFirst => 'Cele mai noi mai întâi';

  @override
  String get journalLinkedEntriesSortOldestFirst => 'Cele mai vechi mai întâi';

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
  String get journalShareHint => 'Partajează';

  @override
  String get journalShowLinkHint => 'Arată linkul';

  @override
  String get journalShowMapHint => 'Arată harta';

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
  String get linkedFromCaption => 'de la';

  @override
  String get linkedTaskImageBadge => 'Din sarcina legată';

  @override
  String get linkedTasksMenuTooltip => 'Opțiuni sarcini legate';

  @override
  String get linkedTasksTitle => 'Sarcini legate';

  @override
  String get linkedToCaption => 'la';

  @override
  String get linkExistingTask => 'Leagă o sarcină existentă...';

  @override
  String get maintenanceDeleteAgentDb => 'Șterge baza de date a agenților';

  @override
  String get maintenanceDeleteAgentDbDescription =>
      'Șterge baza de date a agenților și repornește aplicația';

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
  String get maintenanceDeleteSyncDb => 'Ștergeți baza de date de sincronizare';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Șterge baza de date de sincronizare';

  @override
  String get maintenanceGenerateEmbeddings => 'Generare încorporări';

  @override
  String get maintenanceGenerateEmbeddingsConfirm => 'DA, GENEREAZĂ';

  @override
  String get maintenanceGenerateEmbeddingsDescription =>
      'Generează încorporări pentru intrările din categoriile selectate';

  @override
  String get maintenanceGenerateEmbeddingsMessage =>
      'Selectează categoriile pentru a genera încorporări.';

  @override
  String maintenanceGenerateEmbeddingsProgress(
    int processed,
    int total,
    int embedded,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      embedded,
      locale: localeName,
      other: '$embedded încorporate',
      one: '1 încorporată',
    );
    String _temp1 = intl.Intl.pluralLogic(
      embedded,
      locale: localeName,
      other: '$embedded încorporate',
      one: '1 încorporată',
    );
    String _temp2 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$processed / $total intrări ($_temp0)',
      one: '$processed / $total intrare ($_temp1)',
    );
    return '$_temp2';
  }

  @override
  String get maintenancePopulatePhaseAgentEntities =>
      'Se procesează entitățile agenților...';

  @override
  String get maintenancePopulatePhaseAgentLinks =>
      'Se procesează legăturile agenților...';

  @override
  String get maintenancePopulatePhaseJournal =>
      'Se procesează intrările din jurnal...';

  @override
  String get maintenancePopulatePhaseLinks =>
      'Se procesează legăturile intrărilor...';

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
  String get maintenancePurgeSentOutbox =>
      'Eliminați elementele vechi trimise din outbox';

  @override
  String get maintenancePurgeSentOutboxConfirm => 'DA, ELIMINAȚI';

  @override
  String get maintenancePurgeSentOutboxDescription =>
      'Ștergeți rândurile din outbox trimise cu mai mult de 7 zile în urmă și recuperați spațiul pe disc';

  @override
  String get maintenancePurgeSentOutboxQuestion =>
      'Ștergeți elementele din outbox trimise cu mai mult de 7 zile în urmă? Această operațiune șterge rândurile deja trimise în blocuri și rulează VACUUM pentru a recupera spațiul pe disc. Elementele în așteptare și cu erori sunt păstrate.';

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
  String get maintenanceReSyncAgentEntities => 'Entități agent';

  @override
  String get maintenanceReSyncDescription =>
      'Resincronizează mesajele de pe server';

  @override
  String get maintenanceReSyncEntityTypes => 'Tipuri de entități';

  @override
  String get maintenanceReSyncJournalEntities => 'Intrări jurnal';

  @override
  String get maintenanceReSyncSelectAtLeastOne =>
      'Selectați cel puțin un tip de entitate';

  @override
  String get maintenanceSyncDefinitions =>
      'Sincronizează măsurabile, tablouri de bord, obiceiuri, categorii, setări AI';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sincronizează măsurabile, tablouri de bord, obiceiuri, categorii și setări AI';

  @override
  String get manageLinks => 'Gestionează legăturile...';

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
  String get navTabTitleProjects => 'Proiecte';

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
  String get outboxMonitorFetchFailed =>
      'Căsuța de trimitere nu a putut fi încărcată. Trageți în jos pentru reîmprospătare și încercați din nou.';

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
  String get outboxMonitorVolumeChartTitle => 'Volum de sincronizare zilnic';

  @override
  String get privateLabel => 'Privat';

  @override
  String get projectAgentNotProvisioned =>
      'Încă nu a fost configurat niciun agent de proiect pentru acest proiect.';

  @override
  String get projectAgentSectionTitle => 'Agent';

  @override
  String projectCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de proiecte',
      few: '$count proiecte',
      one: '$count proiect',
    );
    return '$_temp0';
  }

  @override
  String get projectCreateButton => 'Proiect nou';

  @override
  String get projectCreateTitle => 'Creare proiect';

  @override
  String get projectDetailTitle => 'Detalii proiect';

  @override
  String get projectErrorCreateFailed => 'Eroare la crearea proiectului.';

  @override
  String get projectErrorLoadFailed =>
      'Datele proiectului nu au putut fi încărcate.';

  @override
  String get projectErrorLoadProjects => 'Eroare la încărcarea proiectelor';

  @override
  String get projectErrorUpdateFailed =>
      'Proiectul nu a putut fi actualizat. Încercați din nou.';

  @override
  String get projectFilterLabel => 'Proiect';

  @override
  String get projectHealthBandAtRisk => 'Cu risc';

  @override
  String get projectHealthBandBlocked => 'Blocat';

  @override
  String get projectHealthBandOnTrack => 'Pe drumul bun';

  @override
  String get projectHealthBandSurviving => 'Se menține';

  @override
  String get projectHealthBandWatch => 'De urmărit';

  @override
  String get projectHealthSectionTitle => 'Starea proiectului';

  @override
  String projectHealthSummary(int projectCount, int taskCount) {
    String _temp0 = intl.Intl.pluralLogic(
      projectCount,
      locale: localeName,
      other: '$projectCount de proiecte',
      few: '$projectCount proiecte',
      one: '$projectCount proiect',
    );
    String _temp1 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: '$taskCount de sarcini',
      few: '$taskCount sarcini',
      one: '$taskCount sarcină',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get projectHealthTitle => 'Proiecte';

  @override
  String projectLinkedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de sarcini asociate',
      few: '$count sarcini asociate',
      one: '$count sarcină asociată',
    );
    return '$_temp0';
  }

  @override
  String get projectLinkedTasks => 'Sarcini asociate';

  @override
  String get projectManageTooltip => 'Gestionați proiectele';

  @override
  String get projectNoLinkedTasks => 'Nicio sarcină asociată încă';

  @override
  String get projectNoProjects => 'Niciun proiect încă';

  @override
  String get projectNotFound => 'Proiectul nu a fost găsit';

  @override
  String get projectPickerLabel => 'Proiect';

  @override
  String get projectPickerUnassigned => 'Fără proiect';

  @override
  String get projectRecommendationDismissTooltip => 'Respinge';

  @override
  String get projectRecommendationResolveTooltip => 'Marchează ca rezolvat';

  @override
  String get projectRecommendationsTitle => 'Pași următori recomandați';

  @override
  String get projectRecommendationUpdateError =>
      'Recomandarea nu a putut fi actualizată. Vă rugăm să încercați din nou.';

  @override
  String get projectsFilterStatusLabel => 'Stare:';

  @override
  String get projectsFilterTooltip => 'Filtrați proiectele';

  @override
  String get projectShowcaseAiReportTitle => 'Raport AI';

  @override
  String projectShowcaseBlockedLegend(int count) {
    return '$count blocate';
  }

  @override
  String projectShowcaseBlockedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de sarcini blocate',
      few: '$count sarcini blocate',
      one: '$count sarcină blocată',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseCompletedLegend(int count) {
    return '$count finalizate';
  }

  @override
  String get projectShowcaseDescriptionTitle => 'Descriere';

  @override
  String projectShowcaseDueDate(String date) {
    return 'Termen $date';
  }

  @override
  String get projectShowcaseHealthScoreDescription =>
      'Acest scor se bazează pe viteza sarcinilor, blocaje și timpul rămas până la termen.';

  @override
  String get projectShowcaseHealthScoreTitle => 'Scor de sănătate';

  @override
  String get projectShowcaseNoResults =>
      'Niciun proiect nu corespunde căutării tale.';

  @override
  String get projectShowcaseOneOnOneReviewsTab => 'Revizuiri 1:1';

  @override
  String get projectShowcaseOngoing => 'În curs';

  @override
  String get projectShowcaseProjectTasksTab => 'Sarcinile proiectului';

  @override
  String get projectShowcaseSearchHint => 'Caută proiecte';

  @override
  String projectShowcaseSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de sesiuni',
      few: '$count sesiuni',
      one: '$count sesiune',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseTasksCompleted(int completed, int total) {
    return '$completed/$total sarcini finalizate';
  }

  @override
  String projectShowcaseUpdatedHoursAgo(int hours) {
    return 'Actualizat acum $hours ore ↻';
  }

  @override
  String projectShowcaseUpdatedMinutesAgo(int minutes) {
    return 'Actualizat acum $minutes min ↻';
  }

  @override
  String get projectShowcaseUsefulness => 'Utilitate';

  @override
  String get projectShowcaseViewBlocker => 'Vezi blocajul';

  @override
  String get projectStatusActive => 'Activ';

  @override
  String get projectStatusArchived => 'Arhivat';

  @override
  String get projectStatusChangeTitle => 'Schimbă starea';

  @override
  String get projectStatusCompleted => 'Finalizat';

  @override
  String get projectStatusOnHold => 'În așteptare';

  @override
  String get projectStatusOpen => 'Deschis';

  @override
  String get projectSummaryOutdated => 'Rezumatul este învechit.';

  @override
  String projectSummaryOutdatedScheduled(String date, String time) {
    return 'Rezumatul este învechit. Următoarea actualizare va fi pe $date la $time.';
  }

  @override
  String get projectTargetDateLabel => 'Data țintă';

  @override
  String get projectTitleLabel => 'Titlu proiect';

  @override
  String get projectTitleRequired => 'Titlul proiectului nu poate fi gol';

  @override
  String get promptDefaultModelBadge => 'Implicit';

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
  String get promptSelectionModalTitle => 'Selectează prompt preconfigurat';

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
  String get queueCatchUpNowButton => 'Recuperați acum';

  @override
  String get queueCatchUpNowDone => 'Recuperare inițiată — coada se golește.';

  @override
  String queueCatchUpNowError(String reason) {
    return 'Recuperare eșuată: $reason';
  }

  @override
  String get queueDepthCardEmpty => 'Coadă goală — worker-ul este actualizat.';

  @override
  String get queueDepthCardLoading => 'Se citește adâncimea cozii…';

  @override
  String get queueDepthCardTitle => 'Coadă de intrare';

  @override
  String get queueFetchAllHistoryCancel => 'Anulați';

  @override
  String queueFetchAllHistoryCancelled(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events de evenimente obținute',
      few: '$events evenimente obținute',
      one: '1 eveniment obținut',
      zero: 'niciun eveniment obținut',
    );
    return 'Anulat — $_temp0 până acum.';
  }

  @override
  String get queueFetchAllHistoryClose => 'Închideți';

  @override
  String get queueFetchAllHistoryDescription =>
      'Parcurge întregul istoric vizibil al camerei în coadă. Poate fi anulat oricând; o execuție ulterioară reia de unde s-a oprit paginarea.';

  @override
  String queueFetchAllHistoryDone(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages de pagini',
      few: '$pages pagini',
      one: '1 pagină',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages de pagini',
      few: '$pages pagini',
      one: '1 pagină',
    );
    String _temp2 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages de pagini',
      few: '$pages pagini',
      one: '1 pagină',
    );
    String _temp3 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events de evenimente obținute pe $_temp0.',
      few: '$events evenimente obținute pe $_temp1.',
      one: '1 eveniment obținut pe $_temp2.',
      zero: 'Niciun eveniment obținut.',
    );
    return '$_temp3';
  }

  @override
  String queueFetchAllHistoryError(String reason) {
    return 'Obținere oprită: $reason';
  }

  @override
  String get queueFetchAllHistoryErrorUnknown =>
      'Obținerea s-a oprit neașteptat.';

  @override
  String queueFetchAllHistoryProgress(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: 'Pagina $pages  ·  $events de evenimente obținute',
      few: 'Pagina $pages  ·  $events evenimente obținute',
      one: 'Pagina $pages  ·  1 eveniment obținut',
    );
    return '$_temp0';
  }

  @override
  String get queueFetchAllHistoryTitle => 'Se obține istoricul';

  @override
  String queueSkippedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de evenimente omise',
      few: '$count omise',
      one: '1 omis',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedCardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count de evenimente de sincronizare pe care coada le-a abandonat. Apasă pe reîncearcă pentru o nouă încercare.',
      few:
          '$count evenimente de sincronizare pe care coada le-a abandonat. Apasă pe reîncearcă pentru o nouă încercare.',
      one:
          '1 eveniment de sincronizare pe care coada l-a abandonat. Apasă pe reîncearcă pentru o nouă încercare.',
    );
    return '$_temp0';
  }

  @override
  String get queueSkippedCardTitle => 'Evenimente omise';

  @override
  String get queueSkippedRetryAll => 'Reîncearcă evenimentele omise';

  @override
  String queueSkippedRetryAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de evenimente adăugate pentru reîncercare.',
      few: '$count evenimente adăugate pentru reîncercare.',
      one: '1 eveniment adăugat pentru reîncercare.',
      zero: 'Nu există evenimente omise.',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedRetryAllError(String reason) {
    return 'Reîncercarea a eșuat: $reason';
  }

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
      'Alege până la 5 imagini pentru a ghida stilul vizual al IA';

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
  String get searchModeFullText => 'Text integral';

  @override
  String get searchModeVector => 'Vector';

  @override
  String get searchTasksHint => 'Caută sarcini...';

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
  String get settingsAboutJournalEntries => 'Intrări jurnal';

  @override
  String get settingsAboutPlatform => 'Platformă';

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
  String get settingsAdvancedHealthImportSubtitle =>
      'Importați date legate de sănătate din surse externe';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Efectuați sarcini de întreținere pentru a optimiza performanța aplicației';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Vizualizați și gestionați elementele care așteaptă sincronizarea';

  @override
  String get settingsAdvancedSubtitle => 'Setări avansate și întreținere';

  @override
  String get settingsAdvancedTitle => 'Setari Avansate';

  @override
  String get settingsAgentsInstancesSubtitle => 'Agenți în execuție';

  @override
  String get settingsAgentsPendingWakesSubtitle =>
      'Cronometre de trezire programate';

  @override
  String get settingsAgentsSoulsSubtitle =>
      'Personalități durabile ale agenților';

  @override
  String get settingsAgentsStatsSubtitle =>
      'Utilizarea tokenilor și activitate';

  @override
  String get settingsAgentsTemplatesSubtitle => 'Șabloane de agenți partajate';

  @override
  String get settingsAiProfilesSubtitle => 'Furnizori și modele';

  @override
  String get settingsAiProfilesTitle => 'Profiluri de inferență';

  @override
  String get settingsAiSubtitle =>
      'Configurați furnizorii AI, modelele și prompturile';

  @override
  String get settingsAiTitle => 'Setări AI';

  @override
  String get settingsCategoriesCreateTitle => 'Creare categorie';

  @override
  String get settingsCategoriesDetailsLabel => 'Detalii categorie';

  @override
  String get settingsCategoriesEmptyState => 'Nu s-au găsit categorii';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Creați o categorie pentru a organiza intrările dvs.';

  @override
  String get settingsCategoriesErrorLoading =>
      'Eroare la încărcarea categoriilor';

  @override
  String get settingsCategoriesNameLabel => 'Numele categoriei:';

  @override
  String settingsCategoriesNoMatchQuery(String query) {
    return 'Nicio categorie nu corespunde cu \"$query\"';
  }

  @override
  String get settingsCategoriesSearchHint => 'Caută categorii…';

  @override
  String get settingsCategoriesSubtitle => 'Categorii cu setări AI';

  @override
  String settingsCategoriesTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de sarcini',
      few: '$count sarcini',
      one: '$count sarcină',
    );
    return '$_temp0';
  }

  @override
  String get settingsCategoriesTitle => 'Categorii';

  @override
  String get settingsConflictsTitle => 'Sync cu conflicte';

  @override
  String get settingsDashboardDetailsLabel => 'Detalii tablou de bord';

  @override
  String get settingsDashboardSaveLabel => 'Salvează';

  @override
  String get settingsDashboardsSubtitle =>
      'Personalizați vizualizările tabloului de bord';

  @override
  String get settingsDashboardsTitle => 'Panouri de bord';

  @override
  String get settingsDefinitionsSubtitle =>
      'Obiceiuri, categorii, etichete, panouri și unități măsurabile';

  @override
  String get settingsDefinitionsTitle => 'Definiții';

  @override
  String get settingsFlagsEmptySearch =>
      'Niciun marcaj nu corespunde căutării dvs.';

  @override
  String get settingsFlagsSearchHint => 'Căutați marcaje';

  @override
  String get settingsFlagsSubtitle => 'Configurați indicatoarele și opțiunile';

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
  String get settingsHabitsSubtitle =>
      'Gestionați obiceiurile și rutinele dvs.';

  @override
  String get settingsHabitsTitle => 'Obiceiuri';

  @override
  String get settingsHealthImportFromDate => 'Început';

  @override
  String get settingsHealthImportTitle => 'Health Import';

  @override
  String get settingsHealthImportToDate => 'Sfârșit';

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
  String get settingsLabelsCreateTitle => 'Creează etichetă';

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
  String settingsLabelsNoMatchCreate(String query) {
    return 'Creați eticheta \"$query\"';
  }

  @override
  String settingsLabelsNoMatchQuery(String query) {
    return 'Nicio etichetă nu corespunde cu \"$query\"';
  }

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
  String get settingsLoggingSlowQueries => 'Interogări lente ale bazei de date';

  @override
  String get settingsLoggingSlowQueriesSubtitle =>
      'Interogările lente sunt scrise în slow_queries-YYYY-MM-DD.log';

  @override
  String get settingsLoggingSync => 'Sincronizare';

  @override
  String get settingsLoggingSyncSubtitle =>
      'Operațiuni de sincronizare între dispozitive';

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
  String get settingsMatrixContinueVerificationLabel =>
      'Acceptați pe celălalt dispozitiv pentru a continua';

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
  String get settingsMatrixLastUpdated => 'Ultima actualizare:';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Dispozitive neverificate';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Rulează sarcini de întreținere Matrix și instrumente de recuperare';

  @override
  String get settingsMatrixMaintenanceTitle => 'Întreținere';

  @override
  String get settingsMatrixMetrics => 'Metrici sincronizare';

  @override
  String get settingsMatrixNextPage => 'Pagina următoare';

  @override
  String get settingsMatrixNoUnverifiedLabel => 'Niciun dispozitiv neverificat';

  @override
  String get settingsMatrixPreviousPage => 'Pagina anterioară';

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
  String get settingsMatrixTitle => 'Setări sincronizare Matrix';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Dispozitive neverificate';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Anulat pe celălalt dispozitiv...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Am înțeles';

  @override
  String settingsMatrixVerificationSuccessLabel(
    String deviceName,
    String deviceID,
  ) {
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
  String get settingsMeasurableNameLabel => 'Numele măsurătorii:';

  @override
  String get settingsMeasurablePrivateLabel => 'Privat: ';

  @override
  String get settingsMeasurableSaveLabel => 'Salvare';

  @override
  String get settingsMeasurablesSubtitle =>
      'Configurați tipurile de date măsurabile';

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
  String get settingsSyncConflictsSubtitle =>
      'Rezolvați conflictele de sincronizare pentru a asigura consistența datelor';

  @override
  String get settingsSyncOutboxTitle => 'Sync Outbox';

  @override
  String get settingsSyncStatsSubtitle =>
      'Inspectează metricile canalului de sincronizare';

  @override
  String get settingsSyncSubtitle =>
      'Configurează sincronizarea și vizualizează statisticile';

  @override
  String get settingsThemingAutomatic => 'Automat';

  @override
  String get settingsThemingDark => 'Aspect întunecat';

  @override
  String get settingsThemingLight => 'Aspect luminos';

  @override
  String get settingsThemingSubtitle =>
      'Personalizați aspectul și temele aplicației';

  @override
  String get settingsThemingTitle => 'Tematică';

  @override
  String get settingsV2CategoryEmptyBody =>
      'Selectați o sub-setare din stânga.';

  @override
  String get settingsV2DetailRootCrumb => 'Setări';

  @override
  String get settingsV2EmptyStateBody =>
      'Alegeți o secțiune din stânga pentru a începe.';

  @override
  String get settingsV2ResizeHandleLabel => 'Redimensionați arborele de setări';

  @override
  String get settingsV2UnimplementedTitle => 'Panoul nu este încă implementat';

  @override
  String get settingsWhatsNewSubtitle =>
      'Vezi cele mai recente actualizări și funcționalități';

  @override
  String get settingsWhatsNewTitle => 'Ce este nou';

  @override
  String get settingThemingDark => 'Temă întunecată';

  @override
  String get settingThemingLight => 'Temă luminoasă';

  @override
  String get sidebarRunningTimerLabel => 'Cronometru în execuție';

  @override
  String get sidebarRunningTimerStopTooltip => 'Oprește cronometrul';

  @override
  String get sidebarToggleCollapseLabel => 'Restrânge bara laterală';

  @override
  String get sidebarToggleExpandLabel => 'Extinde bara laterală';

  @override
  String get sidebarWakesCancelTooltip => 'Anulează trezirea';

  @override
  String get sidebarWakesHeader => 'Treziri';

  @override
  String get sidebarWakesNow => 'acum';

  @override
  String get sidebarWakesOpenList => 'Deschide lista';

  @override
  String get skillsSectionTitle => 'Competențe';

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
  String get speechModalSelectLanguage => 'Selectați limba';

  @override
  String get speechModalTitle => 'Recunoaștere vocală';

  @override
  String syncActivityIndicatorSemantics(int outbox, int inbox) {
    return 'Activitate sincronizare. Coadă de ieșire: $outbox. Coadă de intrare: $inbox. Deschide coada de ieșire pentru sincronizare.';
  }

  @override
  String get syncDeleteConfigConfirm => 'DA, SUNT SIGUR';

  @override
  String get syncDeleteConfigQuestion =>
      'Doriți să ștergeți configurația de sincronizare?';

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
  String get syncNotLoggedInToast => 'Sincronizarea nu este conectată';

  @override
  String get syncPayloadAgentBundle => 'Pachet agent';

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
  String get syncPayloadOutboxBundle => 'Pachet din căsuța de trimitere';

  @override
  String get syncPayloadThemingSelection => 'Selecție temă';

  @override
  String get syncStepAgentEntities => 'Entități agent';

  @override
  String get syncStepAgentLinks => 'Legături agent';

  @override
  String get syncStepAiSettings => 'Setări AI';

  @override
  String get syncStepBackfillAgentEntityClocks =>
      'Completare ceasuri entități agent';

  @override
  String get syncStepBackfillAgentLinkClocks =>
      'Completare ceasuri legături agent';

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
  String get taskActionBarAudioRecordingActive =>
      'Înregistrare audio în desfășurare';

  @override
  String get taskActionBarMoreActions => 'Mai multe acțiuni';

  @override
  String get taskActionBarOpenRunningTimer => 'Deschide cronometrul activ';

  @override
  String get taskActionBarStopTracking => 'Oprește cronometrul';

  @override
  String get taskActionBarTrackTime => 'Înregistrează timpul';

  @override
  String get taskAgentCancelTimerTooltip => 'Anulează';

  @override
  String taskAgentCountdownTooltip(String countdown) {
    return 'Următoarea rulare automată în $countdown';
  }

  @override
  String get taskAgentCreateChipLabel => 'Atribuiți agent';

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
  String get taskEditTitleLabel => 'Editați titlul sarcinii';

  @override
  String get taskEstimateLabel => 'Timp Estimat:';

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
  String get taskLanguageSelectedLabel => 'Limba curentă';

  @override
  String get taskLanguageSerbian => 'Sârbă';

  @override
  String get taskLanguageSetAction => 'Setați limba';

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
  String get tasksAgentFilterAll => 'Toate';

  @override
  String get tasksAgentFilterHasAgent => 'Cu agent';

  @override
  String get tasksAgentFilterNoAgent => 'Fără agent';

  @override
  String get tasksAgentFilterTitle => 'Agent';

  @override
  String get tasksFilterApplyTitle => 'Aplică filtrul';

  @override
  String get tasksFilterClearAll => 'Șterge tot';

  @override
  String get tasksFilterTitle => 'Filtru sarcini';

  @override
  String get taskShowcaseAudio => 'Audio';

  @override
  String taskShowcaseCompletedCount(int completed, int total) {
    return '$completed / $total finalizate';
  }

  @override
  String taskShowcaseDueDate(String date) {
    return 'Termen: $date';
  }

  @override
  String get taskShowcaseJumpToSection => 'Salt la secțiune';

  @override
  String get taskShowcaseLinked => 'Legat';

  @override
  String get taskShowcaseNoResults =>
      'Nicio sarcină nu corespunde căutării dvs.';

  @override
  String get taskShowcaseReadMore => 'Citiți mai mult';

  @override
  String taskShowcaseRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de înregistrări',
      few: '$count înregistrări',
      one: '1 înregistrare',
    );
    return '$_temp0';
  }

  @override
  String taskShowcaseTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sarcini',
      few: '$count sarcini',
      one: '1 sarcină',
    );
    return '$_temp0';
  }

  @override
  String get taskShowcaseTaskDescription => 'Descrierea sarcinii';

  @override
  String get taskShowcaseTimeTracker => 'Urmărire timp';

  @override
  String get taskShowcaseTodo => 'De făcut';

  @override
  String get taskShowcaseTodos => 'De făcut';

  @override
  String get tasksLabelFilterAll => 'Toate';

  @override
  String get tasksLabelFilterTitle => 'Etichetă';

  @override
  String get tasksLabelFilterUnlabeled => 'Fără etichetă';

  @override
  String get tasksLabelsDialogClose => 'Închide';

  @override
  String get tasksLabelsSheetApply => 'Aplică';

  @override
  String get tasksLabelsSheetSearchHint => 'Caută etichete…';

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
  String get tasksQuickFilterClear => 'Șterge';

  @override
  String get tasksQuickFilterLabelsActiveTitle => 'Filtre de etichete active';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Neatribuit';

  @override
  String get tasksSavedFilterDeleteConfirmTooltip =>
      'Apăsați din nou pentru a șterge';

  @override
  String get tasksSavedFilterDeleteTooltip => 'Ștergeți filtrul salvat';

  @override
  String get tasksSavedFilterDragHandleSemantics => 'Trageți pentru a reordona';

  @override
  String get tasksSavedFilterRenameSemantics => 'Redenumiți filtrul salvat';

  @override
  String get tasksSavedFiltersSaveButtonLabel => 'Salvați';

  @override
  String get tasksSavedFiltersSavePopupCancel => 'Anulați';

  @override
  String tasksSavedFiltersSavePopupHelper(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de filtre active. Salvate în bara laterală, sub Sarcini.',
      few: '$count filtre active. Salvate în bara laterală, sub Sarcini.',
      one: '1 filtru activ. Salvat în bara laterală, sub Sarcini.',
    );
    return '$_temp0';
  }

  @override
  String get tasksSavedFiltersSavePopupHint => 'ex.: Blocate sau în așteptare';

  @override
  String get tasksSavedFiltersSavePopupSave => 'Salvați';

  @override
  String get tasksSavedFiltersSavePopupTitle => 'Denumiți acest filtru';

  @override
  String get tasksSavedFilterToastDeleted => 'Filtru șters';

  @override
  String tasksSavedFilterToastSaved(String name) {
    return 'Salvat „$name”';
  }

  @override
  String tasksSavedFilterToastUpdated(String name) {
    return 'Actualizat „$name”';
  }

  @override
  String get tasksSearchModeLabel => 'Mod de căutare';

  @override
  String get tasksShowCreationDate => 'Afișează data creării pe carduri';

  @override
  String get tasksShowDueDate => 'Afișează data scadenței pe carduri';

  @override
  String get tasksSortByCreationDate => 'Creație';

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
  String get taskStatusOnHold => 'ÎN AȘTEPTARE';

  @override
  String get taskStatusOpen => 'DESCHIS';

  @override
  String get taskStatusRejected => 'RESPINS';

  @override
  String get taskTitleEmpty => 'Fără titlu';

  @override
  String get taskUntitled => '(fără titlu)';

  @override
  String get thinkingDisclosureCopied => 'Raționament copiat';

  @override
  String get thinkingDisclosureCopy => 'Copiază raționamentul';

  @override
  String get thinkingDisclosureHide => 'Ascunde raționamentul';

  @override
  String get thinkingDisclosureShow => 'Afișează raționamentul';

  @override
  String get thinkingDisclosureStateCollapsed => 'restrâns';

  @override
  String get thinkingDisclosureStateExpanded => 'extins';

  @override
  String get timeEntryItemEnd => 'Sfârșit';

  @override
  String get timeEntryItemRunning => 'În desfășurare';

  @override
  String get timeEntryItemStart => 'Început';

  @override
  String get unlinkButton => 'Dezleagă';

  @override
  String get unlinkTaskConfirm =>
      'Ești sigur că vrei să dezlegi această sarcină?';

  @override
  String get unlinkTaskTitle => 'Dezleagă sarcina';

  @override
  String vectorSearchTiming(int elapsed, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${elapsed}ms, $count rezultate',
      one: '${elapsed}ms, $count rezultat',
    );
    return '$_temp0';
  }

  @override
  String get viewMenuTitle => 'Vizualizare';

  @override
  String get viewMenuZoomIn => 'Mărire';

  @override
  String get viewMenuZoomOut => 'Micșorare';

  @override
  String get viewMenuZoomReset => 'Dimensiune reală';

  @override
  String get whatsNewDoneButton => 'Gata';

  @override
  String get whatsNewSkipButton => 'Omite';
}

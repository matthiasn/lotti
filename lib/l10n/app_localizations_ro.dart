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
  String get addActionAddAudioRecording => 'Adăugați o înregistrare audio';

  @override
  String get addActionAddChecklist => 'Listă de verificare';

  @override
  String get addActionAddEvent => 'Eveniment';

  @override
  String get addActionAddImageFromClipboard => 'Lipiți imaginea';

  @override
  String get addActionAddScreenshot => 'Adăugați o captură de ecran';

  @override
  String get addActionAddTask => 'Adăugați o sarcină';

  @override
  String get addActionAddText => 'Adăugați text';

  @override
  String get addActionAddTimer => 'Cronometru';

  @override
  String get addActionAddTimeRecording => 'Adăugați timp';

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
  String get addMeasurementSaveButton => 'Salvați măsurătoarea';

  @override
  String get addToDictionary => 'Adăugați la dicționar';

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
    return 'Alegeți $option';
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
  String get agentCategoryRatingsScaleMax => 'Corectați mai întâi';

  @override
  String get agentCategoryRatingsScaleMin => 'Lasă așa';

  @override
  String agentCategoryRatingsStarLabel(int starIndex, int totalStars) {
    return '$starIndex din $totalStars stele';
  }

  @override
  String get agentCategoryRatingsSubmit => 'Folosiți aceste priorități';

  @override
  String get agentCategoryRatingsSubtitle =>
      'Cât de important este să corectați fiecare dintre aceste puncte? 1 înseamnă «lăsați așa», iar 5 «corectați mai întâi».';

  @override
  String get agentCategoryRatingsTitle => 'Ajută-mă să prioritizez';

  @override
  String agentControlsActionError(String error) {
    return 'Acțiunea a eșuat: $error';
  }

  @override
  String get agentControlsDeleteButton => 'Ștergeți definitiv';

  @override
  String get agentControlsDeleteDialogContent =>
      'Toate datele acestui agent vor fi șterse definitiv, inclusiv istoricul, rapoartele și observațiile. Această acțiune nu poate fi anulată.';

  @override
  String get agentControlsDeleteDialogTitle => 'Ștergeți agentul?';

  @override
  String get agentControlsDestroyButton => 'Distrugeți';

  @override
  String get agentControlsDestroyDialogContent =>
      'Agentul va fi dezactivat permanent. Istoricul său va fi păstrat pentru audit.';

  @override
  String get agentControlsDestroyDialogTitle => 'Distrugeți agentul?';

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
      'Aprobarea a eșuat — vă rugăm să încercați din nou';

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
  String get agentInstancesFilterClearAll => 'Ștergeți tot';

  @override
  String get agentInstancesFilterClearSection => 'Ștergeți';

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
  String get agentInstancesSearchClear => 'Ștergeți căutarea';

  @override
  String get agentInstancesSearchPlaceholder => 'Căutați instanțe…';

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
  String get agentMessageKindMilestone => 'Reper';

  @override
  String get agentMessageKindObservation => 'Observație';

  @override
  String get agentMessageKindRetraction => 'Retractare';

  @override
  String get agentMessageKindSummary => 'Rezumat';

  @override
  String get agentMessageKindSystem => 'Sistem';

  @override
  String get agentMessageKindSystemPrompt => 'Prompt de sistem';

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
  String get agentPendingWakesDeleteTooltip => 'Eliminați trezirea';

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
  String get agentPendingWakesSearchPlaceholder => 'Căutați treziri…';

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
  String get agentRitualReviewAction => 'Începeți conversația';

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
  String get agentRitualSummaryRoleUser => 'Dvs.';

  @override
  String get agentRitualSummaryStartHint =>
      'Începeți un 1-la-1 pentru a revizui ce v-a deranjat, ce a funcționat și ce ar trebui schimbat.';

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
  String get agentSoulCreateTitle => 'Creați un suflet';

  @override
  String get agentSoulDeleteConfirmBody =>
      'Aceasta va elimina sufletul și toate versiunile sale.';

  @override
  String get agentSoulDeleteConfirmTitle => 'Ștergeți sufletul';

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
      'Rafinați personalitatea în toate șabloanele care partajează acest suflet. Agentul de evoluție vede feedbackul de la fiecare șablon care folosește această personalitate.';

  @override
  String get agentSoulReviewStartAction => 'Începeți revizuirea personalității';

  @override
  String get agentSoulReviewStartHint =>
      'Începeți o sesiune axată pe personalitate pentru a examina feedbackul și a evolua vocea, tonul, stilul de coaching și sinceritatea.';

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
  String get agentSoulRollbackAction => 'Reveniți la această versiune';

  @override
  String agentSoulRollbackConfirm(int version) {
    return 'Reveniți la versiunea $version? Toate șabloanele care folosesc acest suflet vor prelua modificarea.';
  }

  @override
  String get agentSoulSelectTitle => 'Selectați un suflet';

  @override
  String get agentSoulsEmptyFiltered =>
      'Niciun suflet nu se potrivește cu filtrele dvs.';

  @override
  String get agentSoulSettingsTab => 'Setări';

  @override
  String get agentSoulsSearchPlaceholder => 'Căutați suflete…';

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
  String get agentTemplateCreateTitle => 'Creați un șablon';

  @override
  String get agentTemplateDeleteConfirm =>
      'Ștergeți acest șablon? Această acțiune nu poate fi anulată.';

  @override
  String get agentTemplateDeleteHasInstances =>
      'Nu se poate șterge: agenți activi utilizează acest șablon.';

  @override
  String get agentTemplateDisplayNameLabel => 'Nume';

  @override
  String get agentTemplateEditTitle => 'Editați șablonul';

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
  String get agentTemplateKindDayAgent => 'Agent de zi';

  @override
  String get agentTemplateKindEventAgent => 'Agent de eveniment';

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
      'Nu sunt șabloane disponibile. Creați mai întâi unul în Setări.';

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
  String get agentTemplateRollbackAction => 'Reveniți la această versiune';

  @override
  String agentTemplateRollbackConfirm(int version) {
    return 'Reveniți la versiunea $version? Agentul va folosi această versiune la următoarea trezire.';
  }

  @override
  String get agentTemplateSaveNewVersion => 'Salvați';

  @override
  String get agentTemplateSelectTitle => 'Selectați un șablon';

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
  String get agentTemplatesSearchPlaceholder => 'Căutați șabloane…';

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
  String get aggregationDailyAvg => 'Medie zilnică';

  @override
  String get aggregationDailyMax => 'Maxim zilnic';

  @override
  String get aggregationDailySum => 'Sumă zilnică';

  @override
  String get aggregationHourlySum => 'Sumă orară';

  @override
  String get aggregationNone => 'Valori brute';

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
  String aiCardHistoryToggle(int count) {
    return 'Istoric · $count';
  }

  @override
  String get aiCardMenuActionDelete => 'Ștergere';

  @override
  String get aiCardMenuActionEdit => 'Editare';

  @override
  String get aiCardMenuTooltip => 'Mai multe acțiuni';

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
  String get aiChatAssistantResponding => 'Asistentul răspunde';

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
  String get aiConfigUseReasoningFieldLabel => 'Folosiți raționamentul';

  @override
  String aiConsumptionCallsLine(int count, int measured) {
    return 'Apeluri AI: $count · impact măsurat pentru $measured';
  }

  @override
  String aiConsumptionCostLine(String cost) {
    return 'Cost: $cost';
  }

  @override
  String aiConsumptionImpactLine(String energy, String carbon, String water) {
    return 'Impact: $energy · $carbon CO₂e · $water apă';
  }

  @override
  String aiConsumptionLedgerCap(int limit) {
    return 'Se afișează cele mai noi $limit apeluri din această perioadă';
  }

  @override
  String get aiConsumptionLedgerTitle => 'Apeluri recente';

  @override
  String get aiConsumptionMetricsNotReported => 'Neraportat';

  @override
  String aiConsumptionTokensLabel(String tokens) {
    return '$tokens tokenuri';
  }

  @override
  String aiConsumptionTokensLine(String input, String output) {
    return 'Tokenuri: $input intrare · $output ieșire';
  }

  @override
  String get aiConsumptionTypeAgentTurn => 'Tur de agent';

  @override
  String get aiConsumptionTypeAudioTranscription => 'Transcriere';

  @override
  String get aiConsumptionTypeImageAnalysis => 'Analiză de imagine';

  @override
  String get aiConsumptionTypeImageGeneration => 'Generare de imagine';

  @override
  String get aiConsumptionTypePromptGeneration => 'Generare de prompt';

  @override
  String get aiConsumptionTypeTextGeneration => 'Generare de text';

  @override
  String aiDeleteToastCascadeDescription(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Am eliminat și $count de modele: $names',
      few: 'Am eliminat și $count modele: $names',
      one: 'Am eliminat și 1 model: $names',
    );
    return '$_temp0';
  }

  @override
  String aiDeleteToastErrorTitle(String name) {
    return 'Nu am putut șterge $name';
  }

  @override
  String get aiDeleteToastModelTitle => 'Model șters';

  @override
  String get aiDeleteToastProfileTitle => 'Profil șters';

  @override
  String get aiDeleteToastPromptTitle => 'Prompt șters';

  @override
  String get aiDeleteToastProviderTitle => 'Furnizor șters';

  @override
  String get aiDeleteToastSkillTitle => 'Abilitate ștearsă';

  @override
  String get aiDeleteToastUndoAction => 'Anulați';

  @override
  String get aiFormCancel => 'Anulați';

  @override
  String get aiFormFixErrors =>
      'Vă rugăm să corectați erorile înainte de salvare';

  @override
  String get aiFormNoChanges => 'Nu există modificări nesalvate';

  @override
  String get aiImageAnalysisPickerDefaultBadge => 'Implicit';

  @override
  String get aiImageAnalysisPickerTitle =>
      'Alegeți un model pentru analiza imaginilor';

  @override
  String get aiImageGenerationPickerTitle =>
      'Alegeți un model pentru generarea imaginilor';

  @override
  String get aiImpactBreakdownBoth => 'Ambele';

  @override
  String get aiImpactBreakdownCategory => 'După categorie';

  @override
  String get aiImpactBreakdownModel => 'După model';

  @override
  String get aiImpactCategoryTitle => 'Defalcare pe categorii';

  @override
  String get aiImpactChartHint =>
      'Atingeți o bară pentru apeluri · o serie pentru a o izola';

  @override
  String get aiImpactChartShareCaption => 'Compoziția în timp';

  @override
  String get aiImpactChartShareSegment => 'Pondere';

  @override
  String aiImpactChartTitle(String metric) {
    return '$metric pe categorii';
  }

  @override
  String aiImpactChartTitleModel(String metric) {
    return '$metric după model';
  }

  @override
  String get aiImpactCoverageNote =>
      'Energia, CO₂e și costul sunt măsurate doar pentru modelele din cloud.';

  @override
  String get aiImpactEmptyBody =>
      'Apelurile AI din sarcinile și agenții dvs. vor apărea aici.';

  @override
  String get aiImpactEmptyTitle => 'Nicio utilizare AI în această perioadă';

  @override
  String get aiImpactKpiCarbon => 'CO₂E';

  @override
  String get aiImpactKpiCost => 'COST';

  @override
  String aiImpactKpiDeltaBaseline(String period) {
    return 'față de $period';
  }

  @override
  String get aiImpactKpiEnergy => 'ENERGIE';

  @override
  String get aiImpactKpiRequests => 'CERERI';

  @override
  String get aiImpactKpiTokens => 'TOKENURI';

  @override
  String get aiImpactLedgerClearFilter => 'Afișați tot';

  @override
  String get aiImpactLoadError =>
      'Datele despre impactul AI nu au putut fi încărcate';

  @override
  String get aiImpactLocationColumn => 'LOCAȚIE';

  @override
  String get aiImpactLocationTitle => 'Impact pe locație';

  @override
  String get aiImpactLocationUnknown => 'Necunoscut';

  @override
  String get aiImpactMetricCarbon => 'CO₂e';

  @override
  String get aiImpactMetricCost => 'Cost';

  @override
  String get aiImpactMetricEnergy => 'Energie';

  @override
  String get aiImpactMetricRequests => 'Cereri';

  @override
  String get aiImpactMetricTokens => 'Tokenuri';

  @override
  String aiImpactModelCallsLabel(String count) {
    return '$count apeluri';
  }

  @override
  String get aiImpactModelColumn => 'MODEL';

  @override
  String get aiImpactModelCostHeavy => 'cost ridicat';

  @override
  String get aiImpactModelCoverageNote =>
      'Modelele locale sunt excluse din acest grafic.';

  @override
  String get aiImpactModelOther => 'Alte modele';

  @override
  String aiImpactModelRatePerMillion(String cost) {
    return '$cost/1M tokeni';
  }

  @override
  String get aiImpactModelTitle => 'Defalcare pe model';

  @override
  String get aiImpactModelUnknown => 'Model necunoscut';

  @override
  String get aiImpactRenewableColumn => 'REGENERABIL';

  @override
  String get aiImpactTitle => 'Impact AI';

  @override
  String get aiInferenceErrorAuthenticationTitle => 'Autentificare eșuată';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Conexiune eșuată';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Cerere invalidă';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Limită de cereri depășită';

  @override
  String get aiInferenceErrorRetryButton => 'Încercați din nou';

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
  String get aiModelDownloadCloseButton => 'Închideți';

  @override
  String aiModelDownloadDialogDescription(String modelName) {
    return 'Lotti va descărca $modelName în cache-ul MLX Audio și îl va utiliza pentru procesarea vocală locală.';
  }

  @override
  String aiModelDownloadDialogTitle(String modelName) {
    return 'Instalați $modelName';
  }

  @override
  String get aiModelDownloadInstallTooltip => 'Instalați modelul';

  @override
  String get aiModelDownloadOpenProgressTooltip =>
      'Afișați progresul descărcării';

  @override
  String get aiModelDownloadStatusChecking => 'Se verifică starea modelului';

  @override
  String aiModelDownloadStatusDownloading(int percent) {
    return 'Se descarcă $percent %';
  }

  @override
  String get aiModelDownloadStatusDownloadingIndeterminate => 'Se descarcă';

  @override
  String get aiModelDownloadStatusFailed => 'Descărcarea a eșuat';

  @override
  String get aiModelDownloadStatusInstalled => 'Instalat';

  @override
  String get aiModelDownloadStatusNotInstalled => 'Neinstalat';

  @override
  String get aiModelDownloadStatusUnsupported => 'Apple Silicon necesar';

  @override
  String get aiModelInstallChoiceCancelButton => 'Anulați';

  @override
  String get aiModelInstallChoiceDescription =>
      'Alegeți mai întâi modelul local de recunoaștere vocală pe care doriți să-l descărcați. Puteți instala celelalte modele mai târziu din lista de modele.';

  @override
  String get aiModelInstallChoiceInstallButton => 'Instalați modelul';

  @override
  String get aiModelInstallChoiceRecommended => 'Recomandat';

  @override
  String get aiModelInstallChoiceTitle => 'Alegeți modelul MLX Audio';

  @override
  String get aiModelPickerByProviderLabel => 'Alegeți un furnizor';

  @override
  String get aiModelPickerCurrentDefaultLabel => 'Modelul implicit actual';

  @override
  String aiModelPickerProviderModelCount(int count) {
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
  String aiOllamaModelInstalledSuccessfully(String modelName) {
    return 'Modelul „$modelName” a fost instalat cu succes!';
  }

  @override
  String get aiPickProviderBadgeDesktopOnly => 'DOAR DESKTOP';

  @override
  String get aiPickProviderBadgeNew => 'NOU';

  @override
  String get aiPickProviderBadgeRecommended => 'RECOMANDAT';

  @override
  String get aiPickProviderContinueButton => 'Continuați';

  @override
  String get aiPickProviderDontShowAgainButton => 'Nu mai afișați';

  @override
  String get aiPickProviderFooterHint =>
      'Puteți adăuga mai mulți furnizori mai târziu în Setări → AI. Cheia dvs. API este stocată local.';

  @override
  String get aiPickProviderModalTitle => 'Configurați funcțiile AI';

  @override
  String get aiPickProviderSubtitle =>
      'Alegeți un furnizor pentru a începe. Vom configura modelele și un profil de pornire automat.';

  @override
  String get aiProfileCardActiveBadge => 'Activ';

  @override
  String get aiProfileModelPickerSearchHint => 'Căutați modele…';

  @override
  String get aiProfileSlotModelMissing => 'lipsește';

  @override
  String get aiPromptGenerationPickerTitle =>
      'Alegeți un model pentru generarea prompturilor';

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
  String get aiProviderCardDraftBadge => 'SCHIȚĂ';

  @override
  String get aiProviderCardFixButton => 'Remediați';

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
  String get aiProviderCardStatusConnectedShort => 'Conectat';

  @override
  String get aiProviderCardStatusInvalidKey => 'Cheie nevalidă';

  @override
  String get aiProviderCardStatusOffline =>
      'Deconectat · Asigurați-vă că Ollama rulează';

  @override
  String get aiProviderCardStatusOfflineShort => 'Deconectat';

  @override
  String get aiProviderConnectBackToProviders => 'Înapoi la furnizori';

  @override
  String get aiProviderConnectBreadcrumbAdd => 'Adăugați furnizor';

  @override
  String get aiProviderConnectFieldBaseUrlHint =>
      'Lăsați necompletat pentru a folosi punctul final implicit';

  @override
  String get aiProviderConnectFieldBaseUrlLabelOptional =>
      'URL de bază (opțional)';

  @override
  String get aiProviderConnectFieldBaseUrlPlaceholder =>
      'https://api.example.com';

  @override
  String get aiProviderConnectFieldDisplayNameHint =>
      'Apare în lista dvs. de furnizori';

  @override
  String get aiProviderConnectionCheckingLabel =>
      'Se verifică cheia, se listează modelele disponibile…';

  @override
  String aiProviderConnectionFailedBadResponseDetail(String type) {
    return 'Formă de răspuns neașteptată: $type';
  }

  @override
  String aiProviderConnectionFailedHttpDetail(int status, String message) {
    return 'HTTP $status · $message';
  }

  @override
  String get aiProviderConnectionFailedInvalidBaseUrlDetail =>
      'URL-ul de bază trebuie să includă schema http(s) și gazda (de ex. https://api.example.com)';

  @override
  String aiProviderConnectionFailedNetworkDetail(String message) {
    return '$message';
  }

  @override
  String get aiProviderConnectionFailedTimeoutDetail => 'Cererea a expirat';

  @override
  String aiProviderConnectionFailedTitle(String providerName) {
    return 'Nu s-a putut accesa $providerName. Verificați cheia sau rețeaua dvs.';
  }

  @override
  String get aiProviderConnectionRetestButton => 'Retestați';

  @override
  String get aiProviderConnectionRetryButton => 'Reîncercați';

  @override
  String aiProviderConnectionVerifiedSubtitle(int count, int ms) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de modele disponibile în contul dvs. · răspuns în $ms ms',
      few: '$count modele disponibile în contul dvs. · răspuns în $ms ms',
      one: '1 model disponibil în contul dvs. · răspuns în $ms ms',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderConnectionVerifiedTitle => 'Conexiune verificată';

  @override
  String aiProviderConnectKeyHelperLink(String url) {
    return 'Obțineți o cheie la $url';
  }

  @override
  String get aiProviderConnectKeyHiddenLabel => 'Ascunsă';

  @override
  String get aiProviderConnectKeyPrivacyHint =>
      'Cheia dvs. API nu părăsește niciodată dispozitivul.';

  @override
  String aiProviderConnectPageTitle(String providerName) {
    return 'Conectați $providerName';
  }

  @override
  String get aiProviderConnectSaveAndContinue => 'Salvați și continuați';

  @override
  String get aiProviderConnectSaveAsDraft => 'Salvați ca schiță';

  @override
  String get aiProviderConnectSavedAsDraftToast => 'Salvată ca schiță';

  @override
  String get aiProviderConnectStepChoose => 'Alegeți furnizorul';

  @override
  String get aiProviderConnectStepConnect => 'Conectați';

  @override
  String get aiProviderConnectStepReview => 'Verificați';

  @override
  String get aiProviderDetailActiveProfileTitle => 'Profil activ';

  @override
  String get aiProviderDetailAddModelButton => 'Adăugați un model';

  @override
  String get aiProviderDetailApiKeyLabel => 'Cheie API';

  @override
  String get aiProviderDetailBackTooltip => 'Înapoi';

  @override
  String get aiProviderDetailBaseUrlLabel => 'URL de bază';

  @override
  String get aiProviderDetailConnectionTitle => 'Conexiune';

  @override
  String get aiProviderDetailDangerZoneTitle => 'Zonă periculoasă';

  @override
  String get aiProviderDetailDisplayNameLabel => 'Nume afișat';

  @override
  String get aiProviderDetailEditButton => 'Editare';

  @override
  String get aiProviderDetailEditTooltip => 'Editare furnizor';

  @override
  String get aiProviderDetailLoadError =>
      'Acest furnizor nu a putut fi încărcat. Încercați din nou din setările AI.';

  @override
  String get aiProviderDetailMissingMessage =>
      'Acest furnizor nu mai este disponibil.';

  @override
  String aiProviderDetailModelsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Modele · $count',
      few: 'Modele · $count',
      one: 'Modele · 1',
      zero: 'Modele',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderDetailNoModelsMessage =>
      'Niciun model încă. Adăugați unul pentru a utiliza acest furnizor.';

  @override
  String get aiProviderDetailPageTitle => 'Detalii furnizor';

  @override
  String get aiProviderDetailRemoveButton => 'Eliminați furnizorul';

  @override
  String get aiProviderDetailRemoveDescription =>
      'Ștergeți furnizorul și toate modelele care depind de el. Această acțiune este ireversibilă.';

  @override
  String get aiProviderDetailRemoveTitle => 'Eliminați acest furnizor';

  @override
  String get aiProviderDetailValueUnset => 'Nesetat';

  @override
  String get aiProviderEmbeddedRuntimeHint =>
      'Rulează integrat în procesul aplicației Apple. Nu este necesar un server local sau un URL de bază.';

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
  String get aiProviderMeliousDescription =>
      'Inferență găzduită în Europa cu catalog dinamic de modele, rutare, audio și imagini';

  @override
  String get aiProviderMeliousName => 'Melious.ai';

  @override
  String get aiProviderMistralDescription =>
      'API cloud Mistral AI cu transcriere audio nativă';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderMlxAudioDescription =>
      'Modele MLX Audio integrate pentru STT și TTS locale pe Apple Silicon';

  @override
  String get aiProviderMlxAudioName => 'MLX Audio (local)';

  @override
  String get aiProviderNebiusAiStudioDescription => 'Modele Nebius AI Studio';

  @override
  String get aiProviderNebiusAiStudioName => 'Nebius AI Studio';

  @override
  String get aiProviderOllamaDescription => 'Rulează inferența local cu Ollama';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOmlxDescription =>
      'Inferență locală oMLX compatibilă OpenAI pentru modele MLX';

  @override
  String get aiProviderOmlxName => 'oMLX (local)';

  @override
  String get aiProviderOpenAiDescription => 'Modele GPT de la OpenAI';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'Modele OpenRouter';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderTaglineAlibaba =>
      'Modele Qwen · multimodal · context lung';

  @override
  String get aiProviderTaglineAnthropic => 'Familia Claude · context lung';

  @override
  String get aiProviderTaglineGemini => 'Multimodal · transcriere audio';

  @override
  String get aiProviderTaglineMelious =>
      'Găzduit în UE · catalog dinamic · rutare eco';

  @override
  String get aiProviderTaglineMlxAudio =>
      'Integrat · Apple Silicon · audio local';

  @override
  String get aiProviderTaglineOllama => 'Rulează local · fără apeluri în cloud';

  @override
  String get aiProviderTaglineOmlx =>
      'Inferență MLX locală · compatibilă OpenAI';

  @override
  String get aiProviderTaglineOpenAi => 'Familia GPT · vision + raționament';

  @override
  String get aiProviderUnknownName => 'Furnizor AI';

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
  String get aiResponseDeleteCancel => 'Anulați';

  @override
  String get aiResponseDeleteConfirm => 'Ștergeți';

  @override
  String get aiResponseDeleteError =>
      'Eșec la ștergerea răspunsului AI. Vă rugăm să încercați din nou.';

  @override
  String get aiResponseDeleteTitle => 'Ștergeți răspunsul AI';

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
  String get aiRunningActivityOpenProgress => 'Afișați progresul AI';

  @override
  String get aiSettingsAddedLabel => 'Adăugat';

  @override
  String get aiSettingsAddModelButton => 'Adăugați un model';

  @override
  String get aiSettingsAddModelErrorDescription =>
      'A apărut o eroare la adăugarea modelului. Încercați din nou.';

  @override
  String get aiSettingsAddModelErrorTitle => 'Modelul nu a putut fi adăugat';

  @override
  String get aiSettingsAddModelTooltip =>
      'Adăugați acest model la furnizorul dvs.';

  @override
  String get aiSettingsAddProfileButton => 'Adăugați un profil';

  @override
  String get aiSettingsAddProviderButton => 'Adăugați un furnizor';

  @override
  String get aiSettingsAgentWakeConcurrencyDescription =>
      'Alegeți câți agenți diferiți pot rula inferențe simultan. Valorile mai mari oferă răspunsuri mai rapide, dar folosesc mai multă capacitate a furnizorului și a dispozitivului dvs.';

  @override
  String get aiSettingsAgentWakeConcurrencyLabel =>
      'Activări simultane ale agenților';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Ștergeți toate filtrele';

  @override
  String get aiSettingsClearFiltersButton => 'Ștergeți';

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
  String get aiSettingsPageLead =>
      'Configurați furnizorii AI, modelele pe care Lotti le poate apela și profilurile de inferență care decid ce model gestionează fiecare sarcină.';

  @override
  String get aiSettingsPageTitle => 'Setări AI';

  @override
  String get aiSettingsReasoningLabel => 'Raționament';

  @override
  String get aiSettingsRemoveModelTooltip =>
      'Eliminați acest model de la furnizorul dvs.';

  @override
  String get aiSettingsSearchHint => 'Căutați furnizori, modele, profiluri...';

  @override
  String get aiSettingsSearchHintShort => 'Căutați';

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
  String get aiSetupPreviewLiveBadge => 'În direct';

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
  String aiSetupResultKnownModelsMissing(String providerName) {
    return 'Nu s-au putut găsi configurațiile de model necesare pentru $providerName';
  }

  @override
  String get aiSetupResultLead =>
      'Am configurat totul pentru dvs. Funcțiile AI sunt gata de utilizat în jurnalul dvs.';

  @override
  String aiSetupResultModalTitle(String providerName) {
    return '$providerName gata';
  }

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
  String get aiSummaryPlayTooltip => 'Citiți rezumatul';

  @override
  String get aiSummaryPreparingTooltip => 'Se pregătește audio';

  @override
  String get aiSummarySpeakTooltip => 'Citiți rezumatul local cu voce tare';

  @override
  String get aiSummaryStopTooltip => 'Opriți';

  @override
  String get aiSummaryThinkingLabel => 'Se gândește…';

  @override
  String get aiSummaryTtsUnavailable => 'Sinteza vocală nu este disponibilă';

  @override
  String get aiTaskSummaryTitle => 'Rezumatul sarcinii AI';

  @override
  String get aiTranscriptionPickerDefaultBadge => 'Implicit';

  @override
  String get aiTranscriptionPickerTitle =>
      'Alegeți un model pentru transcriere';

  @override
  String get apiKeyAddPageTitle => 'Adăugați un furnizor';

  @override
  String get apiKeyAuthenticationDescription => 'Securizați conexiunea API';

  @override
  String get apiKeyAuthenticationTitle => 'Autentificare';

  @override
  String get apiKeyAvailableModelsDescription =>
      'Adăugați rapid modele preconfigurate pentru acest furnizor';

  @override
  String get apiKeyAvailableModelsTitle => 'Modele disponibile';

  @override
  String get apiKeyBaseUrlLabel => 'URL de bază';

  @override
  String get apiKeyDisplayNameHint => 'Introduceți un nume prietenos';

  @override
  String get apiKeyDisplayNameLabel => 'Nume afișat';

  @override
  String get apiKeyDynamicModelsDescription =>
      'Căutați în catalogul live de modele al acestui furnizor și adăugați orice model';

  @override
  String get apiKeyEditGoBackButton => 'Înapoi';

  @override
  String get apiKeyEditLoadError =>
      'Eșec la încărcarea configurației cheii API';

  @override
  String get apiKeyEditLoadErrorRetry =>
      'Vă rugăm să încercați din nou sau să contactați asistența';

  @override
  String get apiKeyEditPageTitle => 'Editați furnizorul';

  @override
  String get apiKeyHideTooltip => 'Ascunde cheia API';

  @override
  String get apiKeyInputHint => 'Introduceți cheia API';

  @override
  String get apiKeyInputLabel => 'Cheie API';

  @override
  String apiKeyKnownModelInputLabel(String modalities) {
    return 'Intrare: $modalities';
  }

  @override
  String apiKeyKnownModelOutputLabel(String modalities) {
    return 'Ieșire: $modalities';
  }

  @override
  String get apiKeyProviderConfigDescription =>
      'Configurați setările furnizorului dvs. de inferență AI';

  @override
  String get apiKeyProviderConfigTitle => 'Configurare furnizor';

  @override
  String get apiKeyProviderTypeHint => 'Selectați un tip de furnizor';

  @override
  String get apiKeyProviderTypeLabel => 'Tip furnizor';

  @override
  String get apiKeyShowTooltip => 'Afișați cheia API';

  @override
  String get audioRecordingCancel => 'ANULARE';

  @override
  String get audioRecordingDiscardDialogBody =>
      'Această înregistrare va fi ștearsă. Nu se va crea nicio intrare audio, transcriere sau rezumat al sarcinii.';

  @override
  String get audioRecordingDiscardDialogCancel => 'Continuați înregistrarea';

  @override
  String get audioRecordingDiscardDialogConfirm => 'Renunțați';

  @override
  String get audioRecordingDiscardDialogTitle => 'Renunțați la înregistrare?';

  @override
  String get audioRecordingListening => 'Se ascultă...';

  @override
  String get audioRecordingPause => 'PAUZĂ';

  @override
  String get audioRecordingRealtime => 'Transcriere în direct';

  @override
  String get audioRecordingResume => 'RELUARE';

  @override
  String get audioRecordings => 'Înregistrări audio';

  @override
  String get audioRecordingStandard => 'Standard';

  @override
  String get audioRecordingStop => 'OPRIȚI';

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
      'Solicitați toate intrările lipsă indiferent de vechime. Folosiți această opțiune pentru a recupera lacune de sincronizare mai vechi.';

  @override
  String get backfillManualProcessing => 'Se procesează...';

  @override
  String get backfillManualTitle => 'Completare manuală';

  @override
  String get backfillManualTrigger => 'Solicitați intrările lipsă';

  @override
  String get backfillReRequestDescription =>
      'Solicitați din nou intrările cerute, dar care nu au fost primite niciodată. Folosiți această opțiune când răspunsurile sunt blocate.';

  @override
  String get backfillReRequestProcessing => 'Se resolicită...';

  @override
  String get backfillReRequestTitle =>
      'Solicitați din nou elementele în așteptare';

  @override
  String get backfillReRequestTrigger =>
      'Solicitați din nou intrările în așteptare';

  @override
  String get backfillResetUnresolvableDescription =>
      'Resetați intrările marcate ca nerezolvabile la starea lipsă, pentru a putea fi solicitate din nou. Utilizați această opțiune după repopularea jurnalului de secvență.';

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
          'Marcați cele $count de intrări deschise în prezent (lipsă sau solicitate) din jurnalul de secvență ca nerezolvabile. Folosiți această opțiune pentru a debloca marcajul când intrările sunt blocate de ceva vreme, fără ca fereastra de amnistie de 7 zile să fi expirat. Intrările pot fi recuperate dacă datele lor ajung ulterior pe disc cu un ceas vectorial valid.',
      few:
          'Marcați cele $count intrări deschise în prezent (lipsă sau solicitate) din jurnalul de secvență ca nerezolvabile. Folosiți această opțiune pentru a debloca marcajul când intrările sunt blocate de ceva vreme, fără ca fereastra de amnistie de 7 zile să fi expirat. Intrările pot fi recuperate dacă datele lor ajung ulterior pe disc cu un ceas vectorial valid.',
      one:
          'Marcați 1 intrare deschisă în prezent (lipsă sau solicitată) din jurnalul de secvență ca nerezolvabilă. Folosiți această opțiune pentru a debloca marcajul când intrările sunt blocate de ceva vreme, fără ca fereastra de amnistie de 7 zile să fi expirat. Intrările pot fi recuperate dacă datele lor ajung ulterior pe disc cu un ceas vectorial valid.',
    );
    return '$_temp0';
  }

  @override
  String get backfillRetireStuckConfirmTitle =>
      'Retrageți acum intrările blocate?';

  @override
  String get backfillRetireStuckDescription =>
      'Forțați fiecare intrare deschisă în prezent, lipsă sau solicitată, din jurnalul de secvență să devină nerezolvabilă. Această acțiune sare peste amnistia de 7 zile; folosiți-o numai pentru rândurile blocate care împiedică avansarea marcajului.';

  @override
  String get backfillRetireStuckProcessing => 'Se retrage…';

  @override
  String get backfillRetireStuckTitle => 'Retrageți intrările blocate';

  @override
  String backfillRetireStuckTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retrageți $count de intrări blocate',
      few: 'Retrageți $count intrări blocate',
      one: 'Retrageți 1 intrare blocată',
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
  String get backfillStatsBurned => 'Anulat';

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
  String get calendarHasPlanLabel => 'Are un plan';

  @override
  String get calendarTodayLabel => 'Astăzi';

  @override
  String get cancelButton => 'Anulați';

  @override
  String get categoryActiveDescription =>
      'Categoriile inactive nu vor apărea în listele de selecție';

  @override
  String get categoryActiveSwitchDescription => 'Selectabil pentru intrări noi';

  @override
  String get categoryAiDefaultsDescription =>
      'Setați profilul AI și șablonul de agent implicit pentru sarcinile noi din această categorie';

  @override
  String get categoryAiDefaultsTitle => 'Setări implicite AI';

  @override
  String get categoryCreationError =>
      'Nu s-a putut crea categoria. Vă rugăm să încercați din nou.';

  @override
  String get categoryDayPlanDescription =>
      'Faceți această categorie disponibilă pentru selecție în planul zilei';

  @override
  String get categoryDayPlanLabel => 'Planificarea zilei';

  @override
  String get categoryDefaultEventTemplateHint => 'Selectați un șablon…';

  @override
  String get categoryDefaultEventTemplateLabel =>
      'Șablon implicit de agent de eveniment';

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
  String get categoryFavoriteBadgeLabel => 'Favorită';

  @override
  String get categoryFavoriteDescription =>
      'Marcați această categorie ca favorită';

  @override
  String get categoryIconChooseHint => 'Alegeți o pictogramă';

  @override
  String get categoryIconCreateHint => 'Alegeți o pictogramă';

  @override
  String get categoryIconEditHint => 'Alegeți altă pictogramă';

  @override
  String get categoryIconLabel => 'Pictogramă';

  @override
  String get categoryIconPickerTitle => 'Alegere pictogramă';

  @override
  String get categoryNameRequired => 'Numele categoriei este obligatoriu';

  @override
  String get categoryNotFound => 'Categorie negăsită';

  @override
  String get categoryPrivateBadgeLabel => 'Privată';

  @override
  String get categoryPrivateDescription =>
      'Vizibil doar când intrările private sunt afișate';

  @override
  String get categorySearchPlaceholder => 'Căutați categorii...';

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
  String get chatInputCancelRealtime => 'Anulați (Esc)';

  @override
  String get chatInputCancelRecording => 'Anulați înregistrarea (Esc)';

  @override
  String get chatInputConfigureModel => 'Configurați modelul';

  @override
  String get chatInputHintDefault =>
      'Întreabă despre sarcinile și productivitatea ta...';

  @override
  String get chatInputHintSelectModel =>
      'Selectați un model pentru a începe conversația';

  @override
  String get chatInputListening => 'Ascultă...';

  @override
  String get chatInputPleaseWait => 'Așteaptă...';

  @override
  String get chatInputProcessing => 'Se procesează...';

  @override
  String get chatInputRecordVoice => 'Înregistrați un mesaj vocal';

  @override
  String get chatInputSendTooltip => 'Trimiteți mesajul';

  @override
  String get chatInputStartRealtime => 'Porniți transcrierea în timp real';

  @override
  String get chatInputStopRealtime => 'Opriți transcrierea în timp real';

  @override
  String get chatInputStopTranscribe => 'Opriți și transcrieți';

  @override
  String get checklistAddItem => 'Adăugați un element nou';

  @override
  String checklistAiConfidenceLabel(String level) {
    return 'Încredere: $level';
  }

  @override
  String get checklistAiMarkComplete => 'Marcați ca finalizat';

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
  String get checklistDelete => 'Ștergeți lista de verificare?';

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
  String get checklistItemArchiveUndo => 'Anulați';

  @override
  String get checklistItemDeleteCancel => 'Anulați';

  @override
  String get checklistItemDeleteConfirm => 'Confirmați';

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
  String get clearButton => 'Ștergeți';

  @override
  String get colorCustomLabel => 'Personalizat';

  @override
  String get colorLabel => 'Culoare';

  @override
  String get commandPaletteNoResults =>
      'Nicio comandă disponibilă nu corespunde căutării dvs.';

  @override
  String get commandPaletteSearchHint => 'Căutați comenzi…';

  @override
  String get commandPaletteTitle => 'Paletă de comenzi';

  @override
  String get commonError => 'Eroare';

  @override
  String get commonLoading => 'Se încarcă...';

  @override
  String get commonUnknown => 'Necunoscut';

  @override
  String get completeHabitFailButton => 'Ratat';

  @override
  String get completeHabitSkipButton => 'Săriți peste';

  @override
  String get completeHabitSuccessButton => 'Succes';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Când este activată, aplicația va încerca să genereze încorporări pentru intrările dvs. pentru a îmbunătăți căutarea și sugestiile de conținut corelat.';

  @override
  String get configFlagDailyOsOnboardingEnabled => 'Ghid Daily OS';

  @override
  String get configFlagDailyOsOnboardingEnabledDescription =>
      'Ghidați utilizatorii noi Daily OS printr-un check-in real care transformă vocea într-o sarcină și un plan de zi.';

  @override
  String get configFlagEnableAiStreaming =>
      'Activați transmiterea în flux AI pentru acțiunile legate de sarcini';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Transmiteți răspunsurile AI în flux pentru acțiunile legate de sarcini. Dezactivați opțiunea pentru a păstra răspunsurile în memoria tampon și a menține interfața mai fluidă.';

  @override
  String get configFlagEnableAiSummaryTts => 'Redare rezumate AI';

  @override
  String get configFlagEnableAiSummaryTtsDescription =>
      'Afișează butonul local text-to-speech pentru rezumatele AI ale sarcinilor. Necesită un model TTS MLX Audio instalat.';

  @override
  String get configFlagEnableDashboardsPage =>
      'Activați pagina Tablouri de bord';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Afișează pagina Tablouri de bord în navigarea principală. Vizualizați datele și informațiile dvs. în tablouri de bord personalizabile.';

  @override
  String get configFlagEnableEmbeddings => 'Generare încorporări';

  @override
  String get configFlagEnableEvents => 'Activați evenimentele';

  @override
  String get configFlagEnableEventsDescription =>
      'Afișează funcția Evenimente pentru a crea, urmări și gestiona evenimente în jurnalul dvs.';

  @override
  String get configFlagEnableForkHealing => 'Repararea bifurcațiilor agentului';

  @override
  String get configFlagEnableForkHealingDescription =>
      'Îmbină istoricurile divergente ale agentului rezultate din utilizarea pe mai multe dispozitive la următoarea activare.';

  @override
  String get configFlagEnableHabitsPage => 'Activați pagina Obiceiuri';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Afișează pagina Obiceiuri în navigarea principală. Urmăriți și gestionați-vă obiceiurile zilnice aici.';

  @override
  String get configFlagEnableLogging => 'Activați jurnalizarea';

  @override
  String get configFlagEnableLoggingDescription =>
      'Activați jurnalizarea detaliată pentru depanare. Această opțiune poate afecta performanța.';

  @override
  String get configFlagEnableMatrix => 'Activați sincronizarea Matrix';

  @override
  String get configFlagEnableMatrixDescription =>
      'Activați integrarea Matrix pentru a sincroniza intrările dvs. între dispozitive și cu alți utilizatori Matrix.';

  @override
  String get configFlagEnableNotifications =>
      'Activați notificările pe desktop?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Primiți notificări pentru mementouri, actualizări și evenimente importante.';

  @override
  String get configFlagEnableProjects => 'Activați proiectele';

  @override
  String get configFlagEnableProjectsDescription =>
      'Afișează funcțiile de gestionare a proiectelor pentru organizarea sarcinilor în proiecte.';

  @override
  String get configFlagEnableSessionRatings => 'Activați evaluările de sesiune';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Solicită o evaluare rapidă a sesiunii la oprirea unui cronometru.';

  @override
  String get configFlagEnableTooltip => 'Activați sfaturile';

  @override
  String get configFlagEnableTooltipDescription =>
      'Afișează sfaturi utile în întreaga aplicație pentru a vă ghida prin funcții.';

  @override
  String get configFlagEnableVectorSearch => 'Căutare vectorială';

  @override
  String get configFlagEnableVectorSearchDescription =>
      'Activați căutarea vectorială în filtrele de sarcini. Necesită reprezentări vectoriale active și Ollama în execuție.';

  @override
  String get configFlagEnableWhatsNew => 'Afișează „Noutăți\"';

  @override
  String get configFlagEnableWhatsNewDescription =>
      'Evidențiază funcțiile și modificările noi în arborele Setărilor.';

  @override
  String get configFlagPrivate => 'Afișați intrările private?';

  @override
  String get configFlagPrivateDescription =>
      'Activați această opțiune pentru a face intrările dvs. private în mod implicit. Intrările private sunt vizibile numai pentru dvs.';

  @override
  String get configFlagRecordLocation => 'Înregistrează locația';

  @override
  String get configFlagRecordLocationDescription =>
      'Înregistrează automat locația dvs. cu intrări noi. Acest lucru ajută la organizarea și căutarea pe baza locației.';

  @override
  String get configFlagResendAttachments => 'Retrimiteți atașamentele';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Activați această opțiune pentru a retrimite automat încărcările de atașamente eșuate atunci când conexiunea este restabilită.';

  @override
  String get configFlagShowSyncActivityIndicator =>
      'Afișează indicatorul de activitate de sincronizare';

  @override
  String get configFlagShowSyncActivityIndicatorDescription =>
      'Afișează discret starea sincronizării în bara laterală; numerele din coadă apar doar când există operații în așteptare.';

  @override
  String get conflictApplyButton => 'Aplicați';

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
  String get conflictCombineApply => 'Aplicați combinația';

  @override
  String get conflictCombineStartFrom => 'Pornire de la';

  @override
  String get conflictConfirmDeletion => 'Confirmați ștergerea';

  @override
  String get conflictDeleteVsEditDescription =>
      'Această intrare a fost editată pe un dispozitiv și ștearsă pe altul. Nimic nu este eliminat până când nu alegeți.';

  @override
  String get conflictDeleteVsEditTitle => 'Șters pe un dispozitiv';

  @override
  String get conflictDetailEntryNotFoundTitle => 'Intrare negăsită';

  @override
  String get conflictDetailLoadErrorTitle =>
      'Conflictul nu a putut fi încărcat';

  @override
  String get conflictDetailNotFoundTitle => 'Conflict negăsit';

  @override
  String get conflictDiffRecommended => 'Recomandat';

  @override
  String conflictDiffUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count câmpuri neschimbate',
      one: '1 câmp neschimbat',
    );
    return '$_temp0';
  }

  @override
  String get conflictFieldBody => 'Conținut';

  @override
  String get conflictFieldCategory => 'categorie';

  @override
  String get conflictFieldDuration => 'durată';

  @override
  String get conflictFieldEnd => 'Sfârșit';

  @override
  String get conflictFieldFlag => 'Marcaj';

  @override
  String get conflictFieldOther => 'Alte detalii';

  @override
  String get conflictFieldOtherDescription =>
      'Aceste versiuni diferă prin detalii care nu sunt afișate individual aici.';

  @override
  String get conflictFieldPrivate => 'Privat';

  @override
  String get conflictFieldStarred => 'Favorit';

  @override
  String get conflictFieldStart => 'Început';

  @override
  String get conflictFieldTitle => 'Titlu';

  @override
  String get conflictFieldWordCount => 'număr de cuvinte';

  @override
  String get conflictFlagFollowUp => 'Necesită urmărire';

  @override
  String get conflictFlagImport => 'Importat';

  @override
  String get conflictFlagNone => 'Niciunul';

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
  String get conflictKeepEdited => 'Păstrați versiunea editată';

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
  String conflictNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count intrări au fost editate pe două dispozitive',
      one: '1 intrare a fost editată pe două dispozitive',
    );
    return '$_temp0';
  }

  @override
  String get conflictNotificationTitle => 'Sincronizarea necesită atenția dvs.';

  @override
  String get conflictPageLeadDesktop =>
      'Diferențele sunt evidențiate inline. Faceți clic pe o parte pentru a folosi versiunea respectivă sau deschideți Editare și îmbinare pentru a le combina.';

  @override
  String get conflictPageLeadMobile =>
      'Diferențele sunt evidențiate inline. Atingeți o parte pentru a folosi versiunea respectivă.';

  @override
  String get conflictPageTitle => 'Conflict de sincronizare';

  @override
  String get conflictPickerCombine => 'Combinați…';

  @override
  String get conflictPickerEditMerge => 'Editare și îmbinare…';

  @override
  String get conflictPickerUseFromSync => 'Folosiți din sincronizare';

  @override
  String get conflictPickerUseThisDevice => 'Folosiți acest dispozitiv';

  @override
  String get conflictResolvedToast => 'Conflict rezolvat';

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
  String get conflictValueAbsent => 'Nedefinit';

  @override
  String get conflictValueNo => 'Nu';

  @override
  String get conflictValueYes => 'Da';

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
  String get copyAsMarkdown => 'Copiați ca Markdown';

  @override
  String get copyAsText => 'Copiați ca text';

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
  String get coverArtChipSet => 'Setați coperta';

  @override
  String get coverArtGenerationComplete => 'Coperta este gata!';

  @override
  String get coverArtGenerationDismissHint =>
      'Puteți închide acest dialog — generarea continuă în fundal';

  @override
  String get createButton => 'Creați';

  @override
  String get createCategoryTitle => 'Creare categorie';

  @override
  String get createEntryLabel => 'Creați o intrare nouă';

  @override
  String get createEntryTitle => 'Adăugați';

  @override
  String get createNewLinkedTask => 'Creați o sarcină nouă asociată...';

  @override
  String get customColor => 'Culoare personalizată';

  @override
  String get dailyOsDayPlan => 'Planul zilei';

  @override
  String get dailyOsNextAgendaCapacityComfortable => 'Confortabil';

  @override
  String get dailyOsNextAgendaCapacityNearFull => 'Aproape plin';

  @override
  String get dailyOsNextAgendaCapacityNoPlan => 'Încă fără plan';

  @override
  String dailyOsNextAgendaCapacityOf(String capacity) {
    return 'din $capacity';
  }

  @override
  String get dailyOsNextAgendaCapacityOver => 'Peste capacitate';

  @override
  String get dailyOsNextAgendaDonutLeft => 'liber';

  @override
  String get dailyOsNextAgendaDonutOver => 'în plus';

  @override
  String dailyOsNextAgendaHeadlineLeft(String duration) {
    return '$duration rămase';
  }

  @override
  String dailyOsNextAgendaHeadlineOver(String duration) {
    return '$duration peste';
  }

  @override
  String get dailyOsNextAgendaNoPlanBody =>
      'Timpul dvs. înregistrat este oricum aici — rostiți un check-in și voi schița o zi în jurul lui.';

  @override
  String dailyOsNextAgendaNoPlanSummary(String duration) {
    return '$duration înregistrat până acum. Rostiți un check-in și voi schița o zi în jurul lui.';
  }

  @override
  String get dailyOsNextAgendaNoPlanTitle =>
      'Încă nu există un plan pentru azi.';

  @override
  String get dailyOsNextAgendaStateDone => 'Finalizat';

  @override
  String get dailyOsNextAgendaStateInProgress => 'În progres';

  @override
  String get dailyOsNextAgendaStateOpen => 'Deschis';

  @override
  String get dailyOsNextAgendaStateOverdue => 'Întârziat';

  @override
  String dailyOsNextAgendaSummary(String scheduled, String capacity) {
    return '$scheduled din $capacity angajate';
  }

  @override
  String dailyOsNextAgendaTrackedLegend(String duration, int completedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      completedCount,
      locale: localeName,
      other: '$completedCount de finalizate',
      few: '$completedCount finalizate',
      one: '1 finalizată',
    );
    return 'Înregistrat · $duration · $_temp0';
  }

  @override
  String get dailyOsNextBlockEditCategoryLabel => 'Categorie';

  @override
  String get dailyOsNextBlockEditFailed =>
      'Blocul nu a putut fi actualizat — încercați din nou.';

  @override
  String get dailyOsNextBlockEditNameLabel => 'Titlu';

  @override
  String get dailyOsNextBlockEditOpenTask => 'Deschideți sarcina';

  @override
  String get dailyOsNextBlockEditSave => 'Salvați modificările';

  @override
  String get dailyOsNextBlockEditSaved => 'Programul a fost actualizat.';

  @override
  String get dailyOsNextBlockEditTimeLabel => 'Început și sfârșit';

  @override
  String get dailyOsNextBlockEditTitle => 'Editați blocul';

  @override
  String get dailyOsNextBlockEditTooltip => 'Editați blocul';

  @override
  String get dailyOsNextBlockEditWhyLabel => 'De ce la această oră';

  @override
  String get dailyOsNextBlockMoveTooltip => 'Mutați blocul';

  @override
  String get dailyOsNextBlockResizeEndTooltip => 'Ajustați sfârșitul';

  @override
  String get dailyOsNextBlockResizeStartTooltip => 'Ajustați începutul';

  @override
  String get dailyOsNextCaptureCaptured => 'Am înțeles.';

  @override
  String get dailyOsNextCaptureDoneCta => 'Gata';

  @override
  String get dailyOsNextCaptureErrorMicrophonePermissionDenied =>
      'Permisiunea pentru microfon a fost refuzată.';

  @override
  String get dailyOsNextCaptureErrorNoActiveRealtimeSession =>
      'Nu există nicio sesiune în timp real activă.';

  @override
  String get dailyOsNextCaptureErrorNoAudioRecorded =>
      'Nu s-a înregistrat niciun audio.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionFailed =>
      'Transcrierea în timp real a eșuat.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionStartFailed =>
      'Transcrierea în timp real nu a putut porni.';

  @override
  String get dailyOsNextCaptureErrorRecordingStartFailed =>
      'Înregistrarea nu a putut porni.';

  @override
  String get dailyOsNextCaptureErrorTranscriptionFailed =>
      'Transcrierea a eșuat.';

  @override
  String get dailyOsNextCaptureHeadlineCaptured => 'Arată corect?';

  @override
  String get dailyOsNextCaptureHeadlineLead => 'La ce vă gândiți';

  @override
  String get dailyOsNextCaptureHeadlineListening => 'Vă ascult.';

  @override
  String get dailyOsNextCaptureHeadlineTail => 'pentru astăzi?';

  @override
  String dailyOsNextCaptureHeadlineTailForDate(String date) {
    return 'pentru $date?';
  }

  @override
  String get dailyOsNextCaptureHeadlineTailTomorrow => 'pentru mâine?';

  @override
  String get dailyOsNextCaptureHeadlineTailYesterday => 'pentru ieri?';

  @override
  String get dailyOsNextCaptureHeadlineTranscribing => 'Se notează…';

  @override
  String get dailyOsNextCaptureIdleClick => 'Faceți clic pentru a vorbi';

  @override
  String get dailyOsNextCaptureIdleExample =>
      '„Dimineață muncă concentrată, o plimbare după prânz, e-mailuri până la cinci.”';

  @override
  String get dailyOsNextCaptureIdleHint =>
      'Apăsați pentru a vorbi · tastați în schimb';

  @override
  String get dailyOsNextCaptureIdleTalk => 'Apăsați pentru a vorbi';

  @override
  String get dailyOsNextCaptureListeningStatus => 'Se ascultă…';

  @override
  String dailyOsNextCapturePastPrompt(String date) {
    return 'Mai doriți să înregistrați ceva din $date?';
  }

  @override
  String get dailyOsNextCaptureReconcileCta => 'Verificați';

  @override
  String get dailyOsNextCapturesPanelTitle => 'Capturi';

  @override
  String get dailyOsNextCaptureTranscribing => 'Se transcrie…';

  @override
  String get dailyOsNextCaptureTranscriptHint =>
      'Corectați orice a înțeles greșit transcrierea înainte de planificare.';

  @override
  String get dailyOsNextCaptureTranscriptLabel => 'Verificați transcrierea';

  @override
  String get dailyOsNextCaptureTypeInstead => 'Tastați în schimb';

  @override
  String get dailyOsNextCaptureVoiceButtonReset => 'Reîncepeți';

  @override
  String get dailyOsNextCaptureVoiceButtonStart => 'Începeți ascultarea';

  @override
  String get dailyOsNextCaptureVoiceButtonStop => 'Opriți ascultarea';

  @override
  String get dailyOsNextCategoryFilterAll => 'Toate categoriile';

  @override
  String get dailyOsNextCategoryFilterDescription =>
      'Doar categoriile activate pentru planificarea zilei sunt folosite pentru procesarea automată Daily OS.';

  @override
  String get dailyOsNextCategoryFilterEmpty =>
      'Nu există încă categorii activate pentru planificarea zilei.';

  @override
  String get dailyOsNextCategoryFilterIncludeAll => 'Include toate';

  @override
  String get dailyOsNextCategoryFilterTitle => 'Categorii de procesare';

  @override
  String get dailyOsNextCategoryFilterTooltip =>
      'Alegeți categoriile de procesare Daily OS';

  @override
  String dailyOsNextCommitCapacityNote(String scheduled, String capacity) {
    return '$scheduled din $capacity angajate. Marjă confortabilă — puteți absorbi o surpriză.';
  }

  @override
  String get dailyOsNextCommitDraftOverline => 'ZIUA DVS., SCHIȚATĂ';

  @override
  String get dailyOsNextCommitExplainer =>
      'Confirmați pentru a trece ziua din schiță în angajament.';

  @override
  String get dailyOsNextCommitFinalStepEyebrow => 'ULTIMUL PAS';

  @override
  String get dailyOsNextCommitHeadline => 'Faceți-o a dvs.';

  @override
  String get dailyOsNextCommitHoldHelper =>
      'Țineți apăsat o secundă pentru a confirma';

  @override
  String get dailyOsNextCommitHoldWordDone => 'Angajat';

  @override
  String get dailyOsNextCommitHoldWordHolding => 'Mențineți';

  @override
  String get dailyOsNextCommitHoldWordIdle => 'Țineți';

  @override
  String get dailyOsNextCommitLockingIn => 'Se fixează…';

  @override
  String get dailyOsNextCommitShepherdSubline =>
      'Vă însoțesc — munca o faceți dvs.';

  @override
  String get dailyOsNextCommitSubCaption =>
      'Puteți vorbi cu mine și după aceea — dar structura rămâne.';

  @override
  String get dailyOsNextCommitTitle => 'Fixați-o';

  @override
  String get dailyOsNextCommitTodayIsYours => 'Ziua este a dvs.';

  @override
  String get dailyOsNextDayBack => 'Înapoi';

  @override
  String get dailyOsNextDayCheckInCta => 'Rostiți un check-in';

  @override
  String get dailyOsNextDayDeleteDialogBody =>
      'Blocurile schițate pentru această zi vor fi eliminate. Capturile dvs. și înregistrările audio rămân în jurnal.';

  @override
  String get dailyOsNextDayDeleteDialogCancel => 'Anulați';

  @override
  String get dailyOsNextDayDeleteDialogConfirm => 'Ștergeți';

  @override
  String get dailyOsNextDayDeleteDialogTitle => 'Ștergeți acest plan?';

  @override
  String get dailyOsNextDayLockInCta => 'Fixează';

  @override
  String get dailyOsNextDayMenuDeletePlan => 'Ștergere plan';

  @override
  String get dailyOsNextDayMenuInspectAgent => 'Inspectare agent';

  @override
  String get dailyOsNextDayMenuSettings => 'Setări Daily OS';

  @override
  String get dailyOsNextDayMoreTooltip => 'Mai mult';

  @override
  String get dailyOsNextDayRefineCta => 'Ajustați';

  @override
  String get dailyOsNextDayRefineFooterHint =>
      'Vorbiți pentru a reorganiza planul — vedeți fiecare schimbare înainte ca ceva să fie salvat.';

  @override
  String get dailyOsNextDayTitle => 'Ziua dvs.';

  @override
  String get dailyOsNextDayWhyChipLabel => 'DE CE';

  @override
  String get dailyOsNextDayWrapUpCta => 'Încheie';

  @override
  String get dailyOsNextDraftingBackToDecisions => 'Înapoi la decizii';

  @override
  String get dailyOsNextDraftingHeader => 'Schițez ziua dvs.…';

  @override
  String get dailyOsNextDraftingNudgeAccept => 'Da, protejează dimineața';

  @override
  String get dailyOsNextDraftingNudgeDecline => 'Nu astăzi';

  @override
  String get dailyOsNextDraftingProgressBlocks => 'Se schițează blocurile';

  @override
  String get dailyOsNextDraftingProgressMatching => 'Se potrivesc sarcinile';

  @override
  String get dailyOsNextDraftingProgressQueued => 'În coadă';

  @override
  String get dailyOsNextDraftingProgressReading => 'Se citește check-in-ul';

  @override
  String get dailyOsNextDraftingProgressSaving => 'Se salvează planul';

  @override
  String get dailyOsNextDraftingProgressValidating => 'Se validează';

  @override
  String get dailyOsNextDraftingReasoningOverline => '✦ RAȚIONAMENT';

  @override
  String get dailyOsNextDraftingRecoveryBody =>
      'Wake-ul nu a produs un plan. Încercați din nou sau reveniți și ajustați deciziile înainte de planificare.';

  @override
  String get dailyOsNextDraftingRecoveryTitle => 'Planificarea s-a blocat';

  @override
  String get dailyOsNextDraftingRetry => 'Încercați din nou';

  @override
  String get dailyOsNextDraftingStatusAfternoon => 'Se ordonează după-amiaza…';

  @override
  String get dailyOsNextDraftingStatusAlmost => 'Aproape gata…';

  @override
  String get dailyOsNextDraftingStatusBreathing => 'Se lasă loc de respiro…';

  @override
  String get dailyOsNextDraftingStatusDeepWork =>
      'Munca concentrată este plasată prima…';

  @override
  String get dailyOsNextDraftingStatusMatching =>
      'Se potrivesc sarcinile cu ziua dvs.…';

  @override
  String get dailyOsNextDraftingStatusReading => 'Se citește check-in-ul dvs.…';

  @override
  String get dailyOsNextDraftingStatusTimings => 'Se verifică orarele…';

  @override
  String get dailyOsNextDraftingStatusYesterday =>
      'Se analizează ritmul de ieri…';

  @override
  String get dailyOsNextEditTitleHint => 'Editați titlul';

  @override
  String get dailyOsNextGenericError =>
      'Ceva nu a mers bine. Încercați din nou în câteva momente.';

  @override
  String get dailyOsNextGreetingAfternoon => 'Bună după-amiaza.';

  @override
  String get dailyOsNextGreetingEvening => 'Bună seara.';

  @override
  String dailyOsNextGreetingHiName(String name) {
    return 'Bună, $name 👋';
  }

  @override
  String get dailyOsNextGreetingMorning => 'Bună dimineața.';

  @override
  String get dailyOsNextKnowledgeConfirm => 'Confirmați';

  @override
  String get dailyOsNextKnowledgeConfirmedHeader => 'Confirmat';

  @override
  String get dailyOsNextKnowledgeEdit => 'Editați';

  @override
  String get dailyOsNextKnowledgeEditCancel => 'Anulați';

  @override
  String get dailyOsNextKnowledgeEditHookHint => 'Rezumat pe un rând';

  @override
  String get dailyOsNextKnowledgeEditSave => 'Salvați';

  @override
  String get dailyOsNextKnowledgeEditStatementHint => 'Ce ar trebui să rețin?';

  @override
  String get dailyOsNextKnowledgeEmpty =>
      'Încă nimic — voi reține ce îmi spuneți.';

  @override
  String dailyOsNextKnowledgeNudge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de observații — de verificat',
      few: '$count observații — de verificat',
      one: '1 observație — de verificat',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextKnowledgeProposedHeader => 'Așteaptă confirmarea dvs.';

  @override
  String get dailyOsNextKnowledgeRetract => 'Uită';

  @override
  String get dailyOsNextKnowledgeStale => 'Mai este valabil?';

  @override
  String get dailyOsNextKnowledgeTitle => 'Ce am învățat';

  @override
  String get dailyOsNextParsedCardBreakLinkTooltip => 'Desface legătura';

  @override
  String get dailyOsNextPlanViewAgenda => 'Agenda';

  @override
  String get dailyOsNextPlanViewDay => 'Ziua';

  @override
  String get dailyOsNextReconcileBadgeMatched => 'LEGAT';

  @override
  String get dailyOsNextReconcileBadgeNew => 'NOU';

  @override
  String get dailyOsNextReconcileBadgeUpdate => 'ACTUALIZARE';

  @override
  String get dailyOsNextReconcileBuildDayCta => 'Construiți ziua mea';

  @override
  String get dailyOsNextReconcileDecideOverline => 'MERITĂ DECIS';

  @override
  String dailyOsNextReconcileDecisionProgress(int decided, int total) {
    return '$decided din $total revizuite';
  }

  @override
  String get dailyOsNextReconcileDefaultBehaviorHint =>
      'Revizuiți cardurile înainte de a construi ziua. Acțiunile alese intră în plan; cardurile lăsate neatinse rămân așa cum sunt.';

  @override
  String dailyOsNextReconcileError(String detail) {
    return 'Ceva nu a mers bine: $detail';
  }

  @override
  String get dailyOsNextReconcileHeadline => 'Iată ce am auzit.';

  @override
  String get dailyOsNextReconcileHeardEmpty =>
      'Cardurile capturii vor apărea aici după finalizarea parsării.';

  @override
  String get dailyOsNextReconcileHeardOverline => 'AUZIT';

  @override
  String get dailyOsNextReconcileLowConfidence => 'încredere scăzută';

  @override
  String get dailyOsNextReconcileProcessing =>
      'Reascult și potrivesc totul cu ziua dvs.…';

  @override
  String get dailyOsNextReconcileReRecord => 'Reînregistrare';

  @override
  String get dailyOsNextReconcileVoiceHint =>
      'Revizuiți deciziile înainte de a vă construi ziua';

  @override
  String get dailyOsNextRefineAccept => 'Acceptă';

  @override
  String get dailyOsNextRefineCurrentPlan => 'PLANUL CURENT';

  @override
  String get dailyOsNextRefineDiffAdded => 'ADĂUGAT';

  @override
  String get dailyOsNextRefineDiffDropped => 'RENUNȚAT';

  @override
  String get dailyOsNextRefineDiffMoved => 'MUTAT';

  @override
  String get dailyOsNextRefineHeadlineDiffReady => 'Iată ce aș schimba.';

  @override
  String get dailyOsNextRefineHeadlineIdle => 'Ce ar trebui schimbat?';

  @override
  String get dailyOsNextRefineHeadlineThinking => 'Se reface planul dvs.…';

  @override
  String get dailyOsNextRefineKeepTalking => 'Continuați să vorbiți';

  @override
  String get dailyOsNextRefineLooksGood => 'Arată bine';

  @override
  String get dailyOsNextRefineNoChanges =>
      'Nu au venit modificări ale planului. Reformulați și încercați din nou.';

  @override
  String get dailyOsNextRefineOverline => '🎤 REGLARE';

  @override
  String get dailyOsNextRefineRevert => 'Anulați';

  @override
  String get dailyOsNextRefineStatusAccepted => 'Fixat.';

  @override
  String get dailyOsNextRefineStatusDiffReady => 'Iată ce s-a schimbat.';

  @override
  String get dailyOsNextRefineStatusIdle => 'Apăsați pentru a vorbi.';

  @override
  String get dailyOsNextRefineStatusListening => 'Ascult…';

  @override
  String get dailyOsNextRefineStatusThinking => '✦ Reorganizez planul…';

  @override
  String get dailyOsNextRefineTitle => 'Reglează planul';

  @override
  String get dailyOsNextRenameFailed =>
      'Redenumirea nu a reușit — încercați din nou.';

  @override
  String get dailyOsNextReviewAddBuffer => 'Adăugați rezervă';

  @override
  String get dailyOsNextReviewAddBufferPrompt =>
      'Adăugați o rezervă realistă între blocurile planificate, mai ales la tranziții și după munca solicitantă.';

  @override
  String get dailyOsNextReviewAdjust => 'Ajustați';

  @override
  String get dailyOsNextReviewLooksGood => 'Arată bine';

  @override
  String get dailyOsNextReviewMoveLighter => 'Mutați ce e mai ușor';

  @override
  String get dailyOsNextReviewMoveLighterPrompt =>
      'Mutați munca mai ușoară sau cu energie mai redusă mai târziu și păstrați cea mai bună fereastră de concentrare pentru sarcina cea mai solicitantă.';

  @override
  String get dailyOsNextReviewTooMuch => 'Prea mult';

  @override
  String get dailyOsNextReviewTooMuchPrompt =>
      'Acest plan este prea mult pentru astăzi. Reduceți încărcarea, protejați spațiul de respiro și păstrați doar cele mai importante blocuri.';

  @override
  String get dailyOsNextReviewWhyTitle => 'De ce au intrat în plan';

  @override
  String get dailyOsNextShutdownCarryoverDrop => 'Renunță';

  @override
  String get dailyOsNextShutdownCarryoverDropped => 'Renunțat';

  @override
  String get dailyOsNextShutdownCarryoverOverline => 'SE REPORTEAZĂ';

  @override
  String get dailyOsNextShutdownCarryoverPickDate => 'Alegeți data';

  @override
  String get dailyOsNextShutdownCarryoverScheduled => 'Programat';

  @override
  String get dailyOsNextShutdownCloseDay => 'Închideți ziua';

  @override
  String get dailyOsNextShutdownCompletedOverline => 'CE AȚI FĂCUT';

  @override
  String get dailyOsNextShutdownMetricEnergy => 'ENERGIE';

  @override
  String dailyOsNextShutdownMetricEnergyDelta(String delta) {
    return '$delta vs. săptămână';
  }

  @override
  String get dailyOsNextShutdownMetricFlow => 'SESIUNI DE FLOW';

  @override
  String get dailyOsNextShutdownMetricFocus => 'TIMP DE FOCUS';

  @override
  String get dailyOsNextShutdownMetricSwitches => 'SCHIMBĂRI DE CONTEXT';

  @override
  String dailyOsNextShutdownMetricSwitchesAvg(String avg) {
    return 'media $avg săptămâna aceasta';
  }

  @override
  String get dailyOsNextShutdownReflectionOverline => '💬 REFLECȚIE DE O LINIE';

  @override
  String get dailyOsNextShutdownReflectionPlaceholder =>
      'ex.: dimineață ascuțită, după-amiază trenantă după o cafea lungă cu Sarah.';

  @override
  String get dailyOsNextShutdownReflectionPrompt =>
      'Cum a fost ziua? (Asta alimentează schița de mâine.)';

  @override
  String get dailyOsNextShutdownReflectionSpeak => 'Spuneți';

  @override
  String get dailyOsNextShutdownReflectionSubmit => 'Săriți peste';

  @override
  String get dailyOsNextShutdownReflectionThanks =>
      'Notat — alimentează ziua de mâine.';

  @override
  String get dailyOsNextShutdownSaveAndClose => 'Salvați și închideți';

  @override
  String get dailyOsNextShutdownTitle => 'Închideți ziua';

  @override
  String get dailyOsNextShutdownTomorrowOverline => '✦ PENTRU MÂINE';

  @override
  String dailyOsNextStateDueOnDate(String date) {
    return 'Scadent pe $date';
  }

  @override
  String get dailyOsNextStateDueToday => 'Scadent astăzi';

  @override
  String dailyOsNextStateInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'În progres · $count sesiuni',
      one: 'În progres · 1 sesiune',
      zero: 'În progres',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Întârziat · $days zile',
      one: 'Întârziat · 1 zi',
      zero: 'Întârziat',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdueOnDate(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Întârziat cu $days zile pe $date',
      one: 'Întârziat cu 1 zi pe $date',
      zero: 'Întârziat pe $date',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextStateRecurringMissed => 'Recurent · ratat';

  @override
  String get dailyOsNextTimelineActual => 'Real';

  @override
  String get dailyOsNextTimelineArrange => 'Aranjați blocurile';

  @override
  String get dailyOsNextTimelineBoth => 'Plan și real';

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
    return 'Sesiunea $index din $total';
  }

  @override
  String get dailyOsNextTimelineShowBoth => 'Afișați planul și realul împreună';

  @override
  String get dailyOsNextTimelineShowPaged =>
      'Afișați planul și realul prin glisare';

  @override
  String get dailyOsNextTimelineSwipeHint =>
      'Glisați spre real · ciupiți vertical pentru zoom';

  @override
  String get dailyOsNextTimelineTracked => 'înregistrat';

  @override
  String dailyOsNextTimeSpentEarlierSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de sesiuni anterioare',
      few: '$count sesiuni anterioare',
      one: '1 sesiune anterioară',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextTimeSpentShowLess => 'Afișați mai puțin';

  @override
  String dailyOsNextTimeSpentSummary(String duration, int completedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      completedCount,
      locale: localeName,
      other: '$completedCount de finalizate',
      few: '$completedCount finalizate',
      one: '1 finalizată',
    );
    return '$duration · $_temp0';
  }

  @override
  String get dailyOsNextTimeSpentTitle => 'AZI PÂNĂ ACUM';

  @override
  String get dailyOsNextTimeSpentTitlePast => 'TIMP ÎNREGISTRAT';

  @override
  String get dailyOsNextTriageConfirmDefer => 'Amânat';

  @override
  String get dailyOsNextTriageConfirmDone => 'Marcat ca finalizat';

  @override
  String get dailyOsNextTriageConfirmDoNow => 'Făcut imediat';

  @override
  String get dailyOsNextTriageConfirmDrop => 'Renunțat';

  @override
  String get dailyOsNextTriageConfirmToday => 'Adăugat la astăzi';

  @override
  String get dailyOsNextTriageDefer => 'Amână';

  @override
  String get dailyOsNextTriageDone => 'Finalizat';

  @override
  String get dailyOsNextTriageDoNow => 'Fă acum';

  @override
  String get dailyOsNextTriageDrop => 'Renunță';

  @override
  String get dailyOsNextTriageToday => 'Astăzi';

  @override
  String get dailyOsOnboardingCoachCapture => 'Spuneți ce vă preocupă.';

  @override
  String get dailyOsOnboardingCoachDrafting =>
      'Planificatorul creează sarcinile noi și așază munca în ziua dvs.';

  @override
  String get dailyOsOnboardingCoachReconcile =>
      'Alegeți ce se potrivește pentru azi. Elementele noi devin sarcini când construiți ziua.';

  @override
  String get dailyOsOnboardingSpotlightAction => 'Încercați';

  @override
  String get dailyOsOnboardingSpotlightDismiss => 'Nu acum';

  @override
  String get dailyOsOnboardingSpotlightMessage =>
      'Atingeți aici și spuneți ce vă preocupă – transform totul într-o sarcină și vă construiesc ziua în jurul ei.';

  @override
  String get dailyOsOnboardingSpotlightTitle => 'Transformați vorbele în plan';

  @override
  String get dailyOsSettingsChooseModelDescription =>
      'Suprascrieți doar modelul de raționament al planificatorului.';

  @override
  String get dailyOsSettingsChooseModelTitle =>
      'Alegeți suprascrierea modelului';

  @override
  String get dailyOsSettingsChooseProfileDescription =>
      'Suprascrieți întregul profil de inferență pentru acest planificator.';

  @override
  String get dailyOsSettingsChooseProfileTitle => 'Alegeți profilul Daily OS';

  @override
  String get dailyOsSettingsDataDisclosure =>
      'Daily OS trimite sarcinile, capturile, planurile, preferințele învățate și restul contextului de planificare asamblat către furnizorul selectat pentru procesare.';

  @override
  String get dailyOsSettingsDefaultProfileDescription =>
      'Este folosit de Daily OS dacă instanța planificatorului nu are o suprascriere.';

  @override
  String get dailyOsSettingsDefaultProfileMissing => 'Alegeți un profil';

  @override
  String get dailyOsSettingsDefaultRestored =>
      'Setarea implicită Daily OS a fost restaurată';

  @override
  String get dailyOsSettingsDirectOverrideActive =>
      'Suprascrierea directă a modelului este activă.';

  @override
  String get dailyOsSettingsInferenceTitle => 'Profil de inferență implicit';

  @override
  String get dailyOsSettingsInstanceCurrentSetup =>
      'Configurația actuală a planificatorului';

  @override
  String get dailyOsSettingsInstanceOverrideDescription =>
      'Folosiți profilul Daily OS implicit, alegeți o suprascriere de profil sau suprascrieți doar modelul de raționament al acestui planificator.';

  @override
  String get dailyOsSettingsInstanceOverrideTitle => 'Inferență Daily OS';

  @override
  String get dailyOsSettingsLocalDisclosure =>
      'Punctul final selectat se află pe acest dispozitiv.';

  @override
  String dailyOsSettingsModelChanged(String model) {
    return 'Daily OS folosește acum $model';
  }

  @override
  String get dailyOsSettingsNameNudgeAction => 'Adăugați numele';

  @override
  String get dailyOsSettingsNameNudgeBody =>
      'Un nume preferat face check-in-urile mai personale. Puteți continua planificarea și fără el.';

  @override
  String get dailyOsSettingsNameNudgeTitle =>
      'Cum doriți să vi se adreseze Daily OS?';

  @override
  String dailyOsSettingsProfileChanged(String profile) {
    return 'Daily OS folosește acum $profile';
  }

  @override
  String get dailyOsSettingsProfileOverrideActive =>
      'Suprascrierea profilului este activă';

  @override
  String dailyOsSettingsRemoteDisclosure(String provider, String host) {
    return 'Daily OS trimite contextul de planificare asamblat către $provider, la $host, pentru procesare la distanță.';
  }

  @override
  String get dailyOsSettingsSetupAction => 'Configurați Daily OS';

  @override
  String get dailyOsSettingsSetupRequiredBody =>
      'Daily OS are nevoie de alegerea dvs. privind furnizorul înainte de a vă procesa contextul de planificare.';

  @override
  String get dailyOsSettingsSetupRequiredTitle =>
      'Alegeți un profil de inferență';

  @override
  String get dailyOsSettingsSubtitle =>
      'Alegeți cum să vi se adreseze Daily OS și ce profil de inferență să vă planifice zilele.';

  @override
  String get dailyOsSettingsTitle => 'Daily OS';

  @override
  String get dailyOsSettingsTreeSubtitle =>
      'Planificare, personalizare și furnizor AI';

  @override
  String get dailyOsSettingsUseDefault => 'Folosiți setarea implicită Daily OS';

  @override
  String get dailyOsSettingsUseDefaultDescription =>
      'Urmează profilul selectat în setările Daily OS.';

  @override
  String get dailyOsTodayButton => 'Astăzi';

  @override
  String get dashboardActiveLabel => 'Activ';

  @override
  String get dashboardActiveSwitchDescription =>
      'Afișat în lista panourilor de bord';

  @override
  String get dashboardAddChartsTitle => 'Grafice';

  @override
  String get dashboardAddHabitButton => 'Obiceiuri';

  @override
  String get dashboardAddHabitTitle => 'Diagrame de obiceiuri';

  @override
  String get dashboardAddHealthButton => 'Sănătate';

  @override
  String get dashboardAddHealthTitle => 'Bord de sănătate';

  @override
  String get dashboardAddMeasurementButton => 'Măsurători';

  @override
  String get dashboardAddMeasurementTitle => 'Adăugați diagrame de măsurători';

  @override
  String get dashboardAddMeasurementTooltip => 'Adăugați o măsurătoare';

  @override
  String get dashboardAddSurveyButton => 'Studii';

  @override
  String get dashboardAddSurveyTitle => 'Sondaje';

  @override
  String get dashboardAddWorkoutButton => 'Antrenamente';

  @override
  String get dashboardAddWorkoutTitle => 'Bord de Antrenament';

  @override
  String get dashboardAggregationApplyImmediately =>
      'Alegeți un rezumat. Modificările se aplică imediat.';

  @override
  String get dashboardAggregationDailyAverage => 'Medie zilnică';

  @override
  String get dashboardAggregationDailyMax => 'Maxim zilnic';

  @override
  String get dashboardAggregationDailyTotal => 'Total zilnic';

  @override
  String get dashboardAggregationHourlyTotal => 'Total orar';

  @override
  String get dashboardAggregationLabel => 'Agregare';

  @override
  String get dashboardAggregationTitle => 'Tip de agregare';

  @override
  String get dashboardAvailableChartsDescription =>
      'Alegeți un tip, selectați unul sau mai multe grafice, apoi adăugați-le.';

  @override
  String get dashboardAvailableChartsTitle => 'Adăugați grafice după tip';

  @override
  String get dashboardCategoryLabel => 'Categorie';

  @override
  String get dashboardChartNoData => 'Nu există date în acest interval';

  @override
  String get dashboardConfigurationDescription =>
      'Salvați tabloul de bord, apoi copiați configurația JSON.';

  @override
  String get dashboardConfigurationTitle => 'Export configurație';

  @override
  String get dashboardCopyHint =>
      'Salvați și copiați configurația tabloului de bord';

  @override
  String get dashboardCopyLabel => 'Salvare și copiere JSON';

  @override
  String get dashboardCurrentChartsDescription =>
      'Trageți pentru reordonare. Pentru graficele de măsurare puteți schimba agregarea.';

  @override
  String get dashboardCurrentChartsTitle => 'Grafice pe acest tablou de bord';

  @override
  String get dashboardDeleteConfirm => 'DA, ȘTERGE ACEST TABLOU DE BORD';

  @override
  String get dashboardDeleteHint => 'Ștergeți tabloul de bord';

  @override
  String get dashboardDeleteQuestion => 'Vrei să ștergi acest tablou de bord?';

  @override
  String get dashboardDescriptionLabel => 'Descriere';

  @override
  String get dashboardEditAggregationLabel => 'Editați agregarea';

  @override
  String get dashboardHealthBloodPressure => 'Tensiune arterială';

  @override
  String get dashboardHealthDiastolic => 'Diastolică';

  @override
  String get dashboardHealthSystolic => 'Sistolică';

  @override
  String dashboardMeasurementAddButtonWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Adăugați $count de diagrame',
      few: 'Adăugați $count diagrame',
      one: 'Adăugați 1 diagramă',
    );
    return '$_temp0';
  }

  @override
  String dashboardMeasurementAggregationFor(String name) {
    return 'Mod diagramă pentru $name';
  }

  @override
  String get dashboardMeasurementAggregationHelp =>
      'Selectați diagrame de măsurare. Ajustați modul diagramei pe rândurile selectate înainte de adăugare.';

  @override
  String get dashboardNameLabel => 'Numele tabloului de bord';

  @override
  String get dashboardNoChartsAdded =>
      'Niciun grafic deocamdată. Adăugați unul mai jos.';

  @override
  String get dashboardNoHabitsForCharts =>
      'Creați mai întâi un obicei pentru a adăuga grafice de obiceiuri.';

  @override
  String get dashboardNoMeasurablesForCharts =>
      'Creați mai întâi o valoare măsurabilă pentru a adăuga grafice de măsurare.';

  @override
  String get dashboardNotFound => 'Tablou de bord negasit';

  @override
  String get dashboardPrivateLabel => 'Privat';

  @override
  String get dashboardRemoveChartLabel => 'Eliminați graficul';

  @override
  String get dashboardReorderChartLabel => 'Reordonați graficul';

  @override
  String get dashboardTakeSurveyTooltip => 'Completați chestionarul';

  @override
  String get defaultLanguage => 'Limbă implicită';

  @override
  String get deleteButton => 'Ștergeți';

  @override
  String get deleteDeviceLabel => 'Ștergeți dispozitivul';

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
  String get designSystemBreadcrumbCurrentLabel => 'Fir de navigare';

  @override
  String get designSystemBreadcrumbDesignSystemLabel => 'Sistem de design';

  @override
  String get designSystemBreadcrumbHomeLabel => 'Acasă';

  @override
  String get designSystemBreadcrumbMobileLabel => 'Mobil';

  @override
  String get designSystemBreadcrumbProjectsLabel => 'Proiecte';

  @override
  String get designSystemBreadcrumbSampleLabel => 'Exemplu';

  @override
  String get designSystemBreadcrumbTrailTitle => 'Traseu de navigare';

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
  String get designSystemContextMenuDeleteLabel => 'Ștergeți';

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
  String get designSystemDropdownComboboxTitle => 'Casetă combinată';

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
  String get designSystemDropdownOptionAnalytics => 'Analiză';

  @override
  String get designSystemDropdownOptionBackend => 'Backend';

  @override
  String get designSystemDropdownOptionDesign => 'Design';

  @override
  String get designSystemDropdownOptionFrontend => 'Frontend';

  @override
  String get designSystemDropdownOptionGrowth => 'Creștere';

  @override
  String get designSystemDropdownOptionMobile => 'Mobil';

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
  String get designSystemHeaderSearchActionLabel => 'Căutați';

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
  String get designSystemSearchClearLabel => 'Șterge căutarea';

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
    return 'Deschideți opțiunile pentru $label';
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
  String get designSystemTextareaHelperSample =>
      'Introduceți mesajul dvs. aici';

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
  String get designSystemUndoLabel => 'Anulați';

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
  String get editMenuTitle => 'Editați';

  @override
  String get editorDiscardChanges => 'Renunțați la modificări';

  @override
  String get editorInsertDivider => 'Inserează separator';

  @override
  String get editorMoreFormatting => 'Mai multă formatare';

  @override
  String get editorPlaceholder => 'Introduceți notițe...';

  @override
  String get embeddingSelectAll => 'Selectați tot';

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
  String get entryLabelsEditTooltip => 'Editați etichetele';

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
  String get eventsAddCoverPhoto => 'Adăugați o fotografie de copertă';

  @override
  String get eventsAddLabel => 'Adăugați';

  @override
  String get eventsChangeCover => 'Schimbați coperta';

  @override
  String get eventsDeleteEvent => 'Ștergeți evenimentul';

  @override
  String get eventsFilterAll => 'Toate';

  @override
  String eventsMetricPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de fotografii',
      few: '$count fotografii',
      one: '1 fotografie',
    );
    return '$_temp0';
  }

  @override
  String eventsMetricTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de sarcini',
      few: '$count sarcini',
      one: '1 sarcină',
    );
    return '$_temp0';
  }

  @override
  String get eventsNewEvent => 'Eveniment nou';

  @override
  String get eventsPageTitle => 'Evenimente';

  @override
  String get eventsPhotosSection => 'Fotografii';

  @override
  String get eventsRecapAwaitingContent =>
      'Adăugați o fotografie sau o notă, iar rezumatul va apărea aici.';

  @override
  String get eventsRecapUnavailable => 'Rezumatul nu a putut fi încărcat.';

  @override
  String get eventsRegenerateSummary => 'Regenerează rezumatul';

  @override
  String get eventsSearchHint => 'Căutați evenimente';

  @override
  String get eventsSectionUpcoming => 'Viitoare';

  @override
  String get eventsStatusCancelled => 'Anulat';

  @override
  String get eventsStatusCompleted => 'Finalizat';

  @override
  String get eventsStatusMissed => 'Ratat';

  @override
  String get eventsStatusOngoing => 'În desfășurare';

  @override
  String get eventsStatusPlanned => 'Planificat';

  @override
  String get eventsStatusPostponed => 'Amânat';

  @override
  String get eventsStatusRescheduled => 'Reprogramat';

  @override
  String get eventsStatusTentative => 'Provizoriu';

  @override
  String get eventsSummaryTitle => 'Rezumat';

  @override
  String get eventsTasksEmpty =>
      'Asociați o sarcină de pregătire sau de urmărire';

  @override
  String get eventsTasksSection => 'Sarcini';

  @override
  String get eventsTimelineEmpty =>
      'Adăugați fotografii, notițe sau o notă vocală';

  @override
  String get eventsTimelineSection => 'Cronologie';

  @override
  String get eventsTitleHint => 'Titlul evenimentului';

  @override
  String get eventsVoiceNote => 'Notă vocală';

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
  String get filterSelectionNoMatches => 'Fără rezultate';

  @override
  String get geminiThinkingModeHighDescription =>
      'Raționament cel mai profund; poate crește latența și costul.';

  @override
  String get geminiThinkingModeHighLabel => 'Ridicat';

  @override
  String get geminiThinkingModeLowDescription =>
      'Raționament redus pentru prompturi zilnice rapide.';

  @override
  String get geminiThinkingModeLowLabel => 'Redus';

  @override
  String get geminiThinkingModeMediumDescription =>
      'Raționament echilibrat pentru răspunsuri mai atente.';

  @override
  String get geminiThinkingModeMediumLabel => 'Mediu';

  @override
  String get geminiThinkingModeMinimalDescription =>
      'Cea mai rapidă setare; Gemini poate gândi totuși scurt la prompturi complexe.';

  @override
  String get geminiThinkingModeMinimalLabel => 'Minim';

  @override
  String get generateCoverArt => 'Generează copertă';

  @override
  String get generateCoverArtSubtitle =>
      'Creează imagine din descrierea vocală';

  @override
  String get goMenuTitle => 'Navigare';

  @override
  String get habitActiveFromLabel => 'Data de început';

  @override
  String get habitActiveSwitchDescription => 'Afișat pe pagina Obiceiuri';

  @override
  String get habitArchivedLabel => 'Arhivat';

  @override
  String get habitCategoryHint => 'Selectați o categorie';

  @override
  String get habitCategoryLabel => 'Categorie';

  @override
  String get habitCloseCompletionLabel => 'Închideți înregistrarea obiceiului';

  @override
  String habitCompleteSemanticLabel(String habit) {
    return 'Înregistrați $habit';
  }

  @override
  String get habitCompletionStatusCompleted => 'Finalizat';

  @override
  String get habitCompletionStatusFailed => 'Eșuat';

  @override
  String get habitCompletionStatusOpen => 'Deschis';

  @override
  String get habitCompletionStatusSkipped => 'Omis';

  @override
  String get habitDashboardHint => 'Selectați un panou de bord';

  @override
  String get habitDashboardLabel => 'Panou de bord (opțional)';

  @override
  String habitDayStatusSemantic(String habit, String status) {
    return '$habit, $status';
  }

  @override
  String get habitDeleteConfirm => 'DA, ȘTERGEȚI ACEST OBICEI';

  @override
  String get habitDeleteQuestion => 'Doriți să ștergeți acest obicei?';

  @override
  String habitHeatmapDaySemantic(String date, int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total realizate',
      few: '$total realizate',
      one: '1 realizat',
    );
    return '$date, $done din $_temp0';
  }

  @override
  String get habitLogOtherDayHint =>
      'Țineți apăsat pentru a înregistra altă zi';

  @override
  String get habitNotRecordedLabel => 'Neînregistrat';

  @override
  String get habitPriorityLabel => 'Prioritate';

  @override
  String get habitsAboveGoal => 'Conform planului';

  @override
  String habitsActiveHabitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de obiceiuri active',
      few: '$count obiceiuri active',
      one: '1 obicei activ',
    );
    return '$_temp0';
  }

  @override
  String get habitsAllDoneToday => 'Tot finalizat azi';

  @override
  String get habitsChartUseDynamicBaseline =>
      'Folosește linia de bază dinamică';

  @override
  String get habitsChartUseZeroBaseline => 'Folosește linia de bază zero';

  @override
  String get habitsCompletedHeader => 'Finalizate';

  @override
  String get habitsCompletionRateTitle => 'Rata de finalizare';

  @override
  String get habitsConsistencyTitle => 'Consecvență';

  @override
  String habitsDayFailedPercent(int percent) {
    return '$percent% înregistrate ca ratate';
  }

  @override
  String habitsDaySkippedPercent(int percent) {
    return '$percent% omise';
  }

  @override
  String habitsDaySuccessfulPercent(int percent) {
    return '$percent% reușite';
  }

  @override
  String get habitsDoneTodayLabel => 'Finalizate azi';

  @override
  String get habitSectionOptionsTitle => 'Opțiuni';

  @override
  String get habitSectionScheduleTitle => 'Programare';

  @override
  String get habitsFilterAll => 'toate';

  @override
  String get habitsFilterCompleted => 'finalizate';

  @override
  String get habitsFilterOpenNow => 'scadente';

  @override
  String get habitsFilterPendingLater => 'mai târziu';

  @override
  String get habitsGoalLineLabel => 'Obiectiv';

  @override
  String get habitsHeatmapEmpty =>
      'Adăugați un obicei pentru a începe să vă urmăriți consecvența';

  @override
  String get habitsHeatmapLess => 'Mai puțin';

  @override
  String get habitsHeatmapMore => 'Mai mult';

  @override
  String get habitShowAlertAtLabel => 'Afișați alerta la';

  @override
  String get habitShowFromLabel => 'Afișați de la';

  @override
  String habitsLaggardHint(String habit, int kept, int active) {
    return '$habit — $kept din $active realizate';
  }

  @override
  String get habitsOpenHeader => 'Scadente acum';

  @override
  String get habitsPendingLaterHeader => 'Mai târziu astăzi';

  @override
  String habitsPointsToGoal(int points) {
    return '$points pct. până la obiectiv';
  }

  @override
  String get habitsRecordButton => 'Înregistrați';

  @override
  String get habitsRollingAverageLabel => 'media pe 7 zile';

  @override
  String get habitsStartStreakToday => 'Începeți o serie astăzi';

  @override
  String habitsStreakLongCount(int count) {
    return '$count cu serie de 7 zile';
  }

  @override
  String habitsStreakShortCount(int count) {
    return '$count cu serie de 3 zile';
  }

  @override
  String get habitsTapForBreakdown => 'Atingeți o zi pentru detalii';

  @override
  String habitsToGoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rămase',
      few: '$count rămase',
      one: '1 rămasă',
    );
    return '$_temp0';
  }

  @override
  String habitStreakDaysSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de zile la rând',
      few: '$count zile la rând',
      one: '1 zi la rând',
    );
    return '$_temp0';
  }

  @override
  String get habitsVsPreviousWeek => 'față de săptămâna trecută';

  @override
  String get helpMenuCommandPalette => 'Paletă de comenzi…';

  @override
  String get helpMenuKeyboardShortcuts => 'Comenzi rapide de la tastatură…';

  @override
  String get helpMenuTitle => 'Ajutor';

  @override
  String get imageGenerationError => 'Generarea imaginii a eșuat';

  @override
  String get imageGenerationGenerating => 'Se generează imaginea...';

  @override
  String get imageGenerationProviderRejectedTitle =>
      'Furnizorul de imagini a respins această solicitare';

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
  String get imagePromptGenerationCopyButton => 'Copiați promptul';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Copiați promptul de imagine în clipboard';

  @override
  String get imagePromptGenerationExpandTooltip => 'Afișați promptul complet';

  @override
  String get imagePromptGenerationFullPromptLabel => 'Prompt Imagine Complet:';

  @override
  String get images => 'Imagini';

  @override
  String get imageViewerDownloadFailed => 'Nu s-a putut salva imaginea';

  @override
  String get imageViewerDownloadingTooltip => 'Se salvează imaginea';

  @override
  String get imageViewerDownloadPermissionDenied =>
      'Acces la fotografii refuzat — activați-l în Setări';

  @override
  String imageViewerDownloadSaved(String fileName) {
    return '$fileName a fost salvat';
  }

  @override
  String get imageViewerDownloadSavedToGallery => 'Salvat în Fotografii';

  @override
  String get imageViewerDownloadTooltip => 'Descărcați imaginea';

  @override
  String get inactiveLabel => 'Inactiv';

  @override
  String get inactiveSwitchDescription =>
      'Poate fi ales pentru intrări noi când este activ';

  @override
  String get inferenceProfileChooseModelTitle => 'Alegeți un model';

  @override
  String get inferenceProfileChooseTitle => 'Alegeți un profil de inferență';

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
  String inferenceProfileDetailLoadError(String error) {
    return 'Profilul nu a putut fi încărcat: $error';
  }

  @override
  String get inferenceProfileDetailNotFound => 'Profil negăsit';

  @override
  String get inferenceProfileEditTitle => 'Editați profilul';

  @override
  String get inferenceProfileImageGeneration => 'Generare de imagini';

  @override
  String get inferenceProfileImageRecognition => 'Recunoaștere de imagini';

  @override
  String get inferenceProfileModelUnavailable =>
      'Model indisponibil — furnizorul său a fost posibil eliminat';

  @override
  String get inferenceProfileNameLabel => 'Numele profilului';

  @override
  String get inferenceProfileNameRequired => 'Este necesar un nume de profil';

  @override
  String get inferenceProfilePinnedHostHelper =>
      'Când este setat, doar acest dispozitiv rulează automat inferența pentru intrările audio sincronizate care folosesc acest profil.';

  @override
  String get inferenceProfilePinnedHostLabel => 'Dispozitiv fixat';

  @override
  String get inferenceProfilePinnedHostNoEligibleNodes =>
      'Niciun dispozitiv cunoscut nu anunță furnizorii pe care îi folosește acest profil. Deschideți setările nodurilor de sincronizare pe dispozitivul țintă.';

  @override
  String get inferenceProfilePinnedHostNoneHelper =>
      'Intrările audio sincronizate nu sunt transcrise automat când niciun dispozitiv nu este fixat.';

  @override
  String get inferenceProfilePinnedHostNoneLabel =>
      'Nefixat (fără declanșare automată)';

  @override
  String get inferenceProfilePinnedHostThisDeviceSuffix =>
      ' (acest dispozitiv)';

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
  String get inferenceProfileUnavailable => 'Profil de inferență indisponibil';

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
  String get insightsChartCompareCaption =>
      'Această perioadă vs. cea anterioară';

  @override
  String get insightsChartCompareCaptionPartial =>
      'Această perioadă până acum vs. cea anterioară';

  @override
  String get insightsChartCompareHint =>
      'Comparația este afișată în tabelul de mai jos';

  @override
  String get insightsChartCumulativeCaption => 'Total cumulat pe interval';

  @override
  String get insightsChartCumulativeShort =>
      'Încă nu sunt destule zile pentru un total cumulat';

  @override
  String get insightsChartDailyCaption => 'Timp pe zi';

  @override
  String get insightsChartHourlyCaption => 'Timp pe oră';

  @override
  String get insightsChartPerDay => 'Pe zi';

  @override
  String get insightsChartPerHour => 'Pe oră';

  @override
  String get insightsChartPerWeek => 'Pe săptămână';

  @override
  String get insightsChartRunningTotal => 'Total cumulat';

  @override
  String get insightsChartTitle => 'Timp pe categorie';

  @override
  String get insightsChartWeeklyCaption => 'Timp pe săptămână';

  @override
  String get insightsChooseFocusCategories =>
      'Alegeți categoriile de focalizare';

  @override
  String get insightsCompare => 'Compară';

  @override
  String get insightsCompareFullPeriod => 'perioadă întreagă';

  @override
  String get insightsComparePrevious => 'Anterior';

  @override
  String get insightsCompareSameDays => 'aceleași zile';

  @override
  String get insightsCompareTooltip => 'Compară cu perioada anterioară';

  @override
  String get insightsCompareVs => 'față de';

  @override
  String get insightsDeletedCategory => 'Categorie ștearsă';

  @override
  String get insightsDeltaNew => 'nou';

  @override
  String get insightsEmptyBody =>
      'Timpul pe care îl înregistrați în notițe și sarcini va apărea aici.';

  @override
  String get insightsEmptyChart => 'Nu există date în acest interval';

  @override
  String get insightsEmptyPreviousPeriod => 'Afișați perioada anterioară';

  @override
  String get insightsEmptyShowYear => 'Afișați anul acesta';

  @override
  String get insightsEmptyTitle =>
      'Nu există timp înregistrat în acest interval';

  @override
  String get insightsFocusCategoriesEmpty => 'Nu există încă categorii active.';

  @override
  String get insightsFocusCategoriesTitle => 'Categorii de focalizare';

  @override
  String get insightsKpiFocus => 'FOCALIZARE';

  @override
  String get insightsKpiFocusHelp => 'Categoriile pe care le urmăriți';

  @override
  String get insightsKpiOther => 'ALTELE';

  @override
  String get insightsKpiOtherHelp => 'Tot restul';

  @override
  String insightsKpiTopCategory(String category, String share) {
    return 'Cel mai mult pe $category · $share';
  }

  @override
  String get insightsKpiTotal => 'TOTAL';

  @override
  String get insightsLoadError => 'Datele despre timp nu au putut fi încărcate';

  @override
  String get insightsOtherCategories => 'Altele';

  @override
  String get insightsPartialWeek => 'săptămână parțială';

  @override
  String get insightsPeriodDay => 'Zi';

  @override
  String get insightsPeriodJump => 'Salt la o dată';

  @override
  String get insightsPeriodMonth => 'Lună';

  @override
  String get insightsPeriodNext => 'Perioada următoare';

  @override
  String get insightsPeriodPrevious => 'Perioada anterioară';

  @override
  String get insightsPeriodQuarter => 'Trimestru';

  @override
  String get insightsPeriodToDateSuffix => 'până acum';

  @override
  String get insightsPeriodWeek => 'Săptămână';

  @override
  String get insightsPeriodYear => 'An';

  @override
  String get insightsRangeMonthToDate => 'Luna aceasta până acum';

  @override
  String get insightsRangeMtd => 'Luna aceasta';

  @override
  String get insightsRangeYearToDate => 'Anul acesta până acum';

  @override
  String get insightsRangeYtd => 'Anul acesta';

  @override
  String get insightsRefreshError =>
      'Reîmprospătarea a eșuat — se afișează ultimele date încărcate';

  @override
  String get insightsTableAvgPerDay => 'MEDIE/ZI';

  @override
  String get insightsTableCategory => 'CATEGORIE';

  @override
  String get insightsTableCompareNote =>
      'Modificare față de perioada anterioară';

  @override
  String get insightsTableCurrent => 'CURENT';

  @override
  String get insightsTableDelta => 'Modificare';

  @override
  String get insightsTablePrevious => 'ANTERIOR';

  @override
  String get insightsTableShare => 'PONDERE';

  @override
  String get insightsTableTotal => 'TOTAL';

  @override
  String get insightsTimeAnalysisTitle => 'Analiza timpului';

  @override
  String get insightsUncategorized => 'Fără categorie';

  @override
  String get journalCopyImageLabel => 'Copiați imaginea';

  @override
  String get journalDateFromLabel => 'De la:';

  @override
  String get journalDateInvalid => 'Dată invalidă';

  @override
  String get journalDateLabel => 'Dată';

  @override
  String get journalDateNowButton => 'acum';

  @override
  String get journalDateSaveButton => 'Salvați';

  @override
  String get journalDateTimeRangeTitle => 'Dată și oră';

  @override
  String get journalDateToLabel => 'Până la:';

  @override
  String get journalDeleteConfirm => 'DA, ȘTERGE ACEASTĂ INTRARE';

  @override
  String get journalDeleteHint => 'Ștergeți intrarea';

  @override
  String get journalDeleteQuestion =>
      'Vrei să ștergi această intrare în jurnal?';

  @override
  String get journalDurationLabel => 'Durată';

  @override
  String get journalEndDateLabel => 'Dată de sfârșit';

  @override
  String get journalEndsAnotherDayHint => 'Alegeți o dată de sfârșit separată';

  @override
  String get journalEndsAnotherDayLabel => 'Se termină în altă zi';

  @override
  String get journalEndTimeLabel => 'Oră de sfârșit';

  @override
  String get journalFilterEntryTypesTitle => 'Tipuri de intrare';

  @override
  String get journalFilterFlagged => 'Marcate';

  @override
  String get journalFilterPrivate => 'Private';

  @override
  String get journalFilterShowTitle => 'Afișați';

  @override
  String get journalFilterStarred => 'Favorite';

  @override
  String get journalFilterTitle => 'Filtrați jurnalul';

  @override
  String get journalHideLinkHint => 'Ascunde linkul';

  @override
  String get journalHideMapHint => 'Ascunde harta';

  @override
  String get journalLinkedEntriesActivityFilterAudio => 'Audio';

  @override
  String get journalLinkedEntriesActivityFilterCode => 'Cod';

  @override
  String get journalLinkedEntriesActivityFilterImages => 'Imagini';

  @override
  String get journalLinkedEntriesActivityFilterTimer => 'Cronometru';

  @override
  String get journalLinkedEntriesFilterModalTitle => 'Filtrare și sortare';

  @override
  String get journalLinkedEntriesShowFlaggedOnly =>
      'Afișați doar intrările marcate';

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
  String journalOvernightNextDay(String date) {
    return 'Se termină $date (ziua următoare)';
  }

  @override
  String get journalPrivateTooltip => 'Privat';

  @override
  String get journalSearchHint => 'Cautare jurnal...';

  @override
  String get journalSetEndDateTimeNowSemantic =>
      'Setați data și ora de final la momentul actual';

  @override
  String get journalSetStartDateTimeNowSemantic =>
      'Setați data și ora de început la momentul actual';

  @override
  String get journalShareHint => 'Partajează';

  @override
  String get journalShowLinkHint => 'Afișați linkul';

  @override
  String get journalShowMapHint => 'Afișați harta';

  @override
  String get journalStartDateLabel => 'Dată de început';

  @override
  String get journalStartTimeLabel => 'Oră de început';

  @override
  String get journalTodayButton => 'Azi';

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
  String get keyboardCommandActivate => 'Activați elementul focalizat';

  @override
  String get keyboardCommandCategoryCreation => 'Creare';

  @override
  String get keyboardCommandCategoryEditing => 'Editare';

  @override
  String get keyboardCommandCategoryGeneral => 'General';

  @override
  String get keyboardCommandCategoryListsAndControls => 'Liste și controale';

  @override
  String get keyboardCommandCategoryNavigation => 'Navigare';

  @override
  String get keyboardCommandCategoryView => 'Vizualizare';

  @override
  String get keyboardCommandCreateInContext => 'Creați în vizualizarea curentă';

  @override
  String get keyboardCommandFocusSearch => 'Focalizați căutarea';

  @override
  String get keyboardCommandMoveDown => 'Mutați în jos elementul focalizat';

  @override
  String get keyboardCommandMoveUp => 'Mutați în sus elementul focalizat';

  @override
  String keyboardCommandNavigate(String destination) {
    return 'Navigați la $destination';
  }

  @override
  String get keyboardCommandNextRegion => 'Focalizați panoul următor';

  @override
  String get keyboardCommandOpenPalette => 'Deschideți paleta de comenzi';

  @override
  String get keyboardCommandPageDown => 'Deplasați cu o pagină în jos';

  @override
  String get keyboardCommandPageUp => 'Deplasați cu o pagină în sus';

  @override
  String get keyboardCommandPreviousRegion => 'Focalizați panoul anterior';

  @override
  String get keyboardCommandRefresh => 'Reîmprospătați vizualizarea curentă';

  @override
  String get keyboardCommandRename => 'Redenumiți elementul focalizat';

  @override
  String get keyboardCommandSelectFirst => 'Selectați primul element';

  @override
  String get keyboardCommandSelectLast => 'Selectați ultimul element';

  @override
  String get keyboardCommandSelectNext => 'Selectați elementul următor';

  @override
  String get keyboardCommandSelectPrevious => 'Selectați elementul anterior';

  @override
  String get keyboardCommandToggle => 'Comutați elementul focalizat';

  @override
  String get keyboardKeyAlt => 'Alt';

  @override
  String get keyboardKeyArrowDown => 'Săgeată în jos';

  @override
  String get keyboardKeyArrowLeft => 'Săgeată la stânga';

  @override
  String get keyboardKeyArrowRight => 'Săgeată la dreapta';

  @override
  String get keyboardKeyArrowUp => 'Săgeată în sus';

  @override
  String get keyboardKeyControl => 'Ctrl';

  @override
  String get keyboardKeyDelete => 'Ștergere';

  @override
  String get keyboardKeyEnd => 'Sfârșit';

  @override
  String get keyboardKeyEnter => 'Enter';

  @override
  String get keyboardKeyEscape => 'Esc';

  @override
  String get keyboardKeyHome => 'Început';

  @override
  String get keyboardKeyMinus => 'Minus';

  @override
  String get keyboardKeyOr => 'sau';

  @override
  String get keyboardKeyPageDown => 'Pagina următoare';

  @override
  String get keyboardKeyPageUp => 'Pagina anterioară';

  @override
  String get keyboardKeyPlus => 'Plus';

  @override
  String get keyboardKeyShift => 'Shift';

  @override
  String get keyboardKeySpace => 'Spațiu';

  @override
  String get keyboardResizeDividerLabel => 'Redimensionați panourile';

  @override
  String keyboardResizeDividerValue(int value, int min, int max) {
    return 'Redimensionați panourile, $value pixeli. Interval $min-$max pixeli.';
  }

  @override
  String get keyboardShortcutsNoResults =>
      'Nicio comandă rapidă nu corespunde căutării dvs.';

  @override
  String get keyboardShortcutsSearchHint => 'Căutați comenzi rapide…';

  @override
  String get keyboardShortcutsSubtitle =>
      'Toate comenzile pentru desktop și combinațiile lor actuale de taste.';

  @override
  String get keyboardShortcutsTitle => 'Comenzi rapide de la tastatură';

  @override
  String knowledgeGraphAgeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'acum $count de zile',
      few: 'acum $count zile',
      one: 'acum 1 zi',
    );
    return '$_temp0';
  }

  @override
  String knowledgeGraphAgeMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'acum $count de luni',
      few: 'acum $count luni',
      one: 'acum 1 lună',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeToday => 'Astăzi';

  @override
  String knowledgeGraphAgeWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'acum $count de săptămâni',
      few: 'acum $count săptămâni',
      one: 'acum 1 săptămână',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeYesterday => 'Ieri';

  @override
  String get knowledgeGraphBack => 'Înapoi';

  @override
  String get knowledgeGraphCloseDetails => 'Închideți detaliile';

  @override
  String get knowledgeGraphEmpty => 'Încă nu există legături de explorat';

  @override
  String get knowledgeGraphEntryLoadError =>
      'Această intrare nu a putut fi încărcată';

  @override
  String get knowledgeGraphEntryNotFound => 'Intrarea nu a fost găsită';

  @override
  String get knowledgeGraphError =>
      'Graful de cunoștințe nu a putut fi încărcat';

  @override
  String knowledgeGraphLinkedSection(int count) {
    return 'LEGATE · $count';
  }

  @override
  String get knowledgeGraphMoreLinks => 'Mai multe legături';

  @override
  String knowledgeGraphNodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de noduri',
      few: '$count noduri',
      one: '1 nod',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphNodeTypeAiSummary => 'Rezumat AI';

  @override
  String get knowledgeGraphNodeTypeAudioNote => 'Notă audio';

  @override
  String get knowledgeGraphNodeTypeChecklist => 'Listă de verificare';

  @override
  String get knowledgeGraphNodeTypeChecklistItem => 'Element din listă';

  @override
  String get knowledgeGraphNodeTypeNote => 'Notă';

  @override
  String get knowledgeGraphNodeTypePhoto => 'Fotografie';

  @override
  String get knowledgeGraphNodeTypeProject => 'Proiect';

  @override
  String get knowledgeGraphNodeTypeRating => 'Evaluare';

  @override
  String get knowledgeGraphNodeTypeTask => 'Sarcină';

  @override
  String get knowledgeGraphOpenDetails => 'Deschideți detaliile';

  @override
  String get knowledgeGraphRecenter => 'Recentrați';

  @override
  String get knowledgeGraphRecentToOlder => 'Recent → mai vechi';

  @override
  String get knowledgeGraphRelationAiSource => 'Sursă AI';

  @override
  String get knowledgeGraphRelationChecklist => 'Listă de verificare';

  @override
  String get knowledgeGraphRelationInProject => 'În proiect';

  @override
  String get knowledgeGraphRelationLinkedTask => 'Sarcină legată';

  @override
  String get knowledgeGraphRelationNoteLog => 'Notă / jurnal';

  @override
  String get knowledgeGraphRelationRating => 'Evaluare';

  @override
  String get knowledgeGraphSummarySection => 'REZUMAT';

  @override
  String get knowledgeGraphTitle => 'Graf de cunoștințe';

  @override
  String get knowledgeGraphTooltip => 'Explorați legăturile';

  @override
  String knowledgeGraphWalkHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de noduri',
      few: '$count noduri',
      one: '1 nod',
    );
    return 'Atingeți un nod pentru a continua · $_temp0';
  }

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
  String get loggingDomainAgentRuntime => 'Rulare agenți';

  @override
  String get loggingDomainAgentWorkflow => 'Flux de lucru agenți';

  @override
  String get loggingDomainAi => 'IA';

  @override
  String get loggingDomainCalendar => 'Calendar și timp';

  @override
  String get loggingDomainChat => 'Chat';

  @override
  String get loggingDomainDailyOs => 'Daily OS';

  @override
  String get loggingDomainDatabase => 'Bază de date';

  @override
  String get loggingDomainGeneral => 'General';

  @override
  String get loggingDomainHabits => 'Obiceiuri';

  @override
  String get loggingDomainHealth => 'Sănătate';

  @override
  String get loggingDomainLabels => 'Etichete';

  @override
  String get loggingDomainLocation => 'Locație';

  @override
  String get loggingDomainNavigation => 'Navigare';

  @override
  String get loggingDomainNotifications => 'Notificări';

  @override
  String get loggingDomainOnboarding => 'Onboarding și FTUE';

  @override
  String get loggingDomainPersistence => 'Persistență';

  @override
  String get loggingDomainRatings => 'Evaluări';

  @override
  String get loggingDomainScreenshots => 'Capturi de ecran';

  @override
  String get loggingDomainSettings => 'Setări';

  @override
  String get loggingDomainSpeech => 'Voce și audio';

  @override
  String get loggingDomainSync => 'Sincronizare';

  @override
  String get loggingDomainTasks => 'Sarcini și liste';

  @override
  String get loggingDomainTheming => 'Teme';

  @override
  String get loggingDomainWhatsNew => 'Noutăți';

  @override
  String get maintenanceDeleteAgentDb => 'Ștergeți baza de date a agenților';

  @override
  String get maintenanceDeleteAgentDbDescription =>
      'Ștergeți baza de date a agenților și reporniți aplicația';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'DA, ȘTERGE BAZA DE DATE';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Sigur doriți să ștergeți baza de date $databaseName?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Ștergeți ciornele din baza de date';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Ștergeți baza de date a ciornelor editorului';

  @override
  String get maintenanceDeleteSyncDb => 'Ștergeți baza de date de sincronizare';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Ștergeți baza de date de sincronizare';

  @override
  String get maintenanceGenerateEmbeddings => 'Generare încorporări';

  @override
  String get maintenanceGenerateEmbeddingsConfirm => 'DA, GENEREAZĂ';

  @override
  String get maintenanceGenerateEmbeddingsDescription =>
      'Generează încorporări pentru intrările din categoriile selectate';

  @override
  String get maintenanceGenerateEmbeddingsMessage =>
      'Selectați categoriile pentru a genera reprezentări vectoriale.';

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
      'Ștergeți definitiv toate elementele șterse';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Sigur doriți să ștergeți definitiv toate elementele șterse? Această acțiune nu poate fi anulată.';

  @override
  String get maintenancePurgeSentOutbox =>
      'Eliminați elementele vechi trimise din coada de ieșire';

  @override
  String get maintenancePurgeSentOutboxConfirm => 'DA, ELIMINAȚI';

  @override
  String get maintenancePurgeSentOutboxDescription =>
      'Ștergeți rândurile din coada de ieșire trimise cu mai mult de 7 zile în urmă și recuperați spațiul pe disc';

  @override
  String get maintenancePurgeSentOutboxQuestion =>
      'Ștergeți elementele trimise din coada de ieșire cu mai mult de 7 zile în urmă? Această operațiune șterge în loturi rândurile deja trimise și rulează VACUUM pentru a recupera spațiul pe disc. Elementele în așteptare și cu erori sunt păstrate.';

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
  String get maintenanceReSyncStart => 'Porniți';

  @override
  String get maintenanceSyncDefinitions =>
      'Sincronizați măsurabilele, tablourile de bord, obiceiurile, categoriile și setările AI';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sincronizați din nou măsurabilele, tablourile de bord, obiceiurile, categoriile și setările AI';

  @override
  String get manageLinks => 'Gestionează legăturile...';

  @override
  String get matrixStatsCatchupBatches => 'Loturi de recuperare';

  @override
  String get matrixStatsCircuitOpens => 'Deschideri ale întrerupătorului';

  @override
  String get matrixStatsConflicts => 'Conflicte';

  @override
  String get matrixStatsCopyDiagnostics => 'Copiază diagnosticarea';

  @override
  String get matrixStatsCopyDiagnosticsTooltip =>
      'Copiază diagnosticarea sincronizării în clipboard';

  @override
  String get matrixStatsDbApplied => 'Aplicat în baza de date';

  @override
  String get matrixStatsDbApply => 'Aplicare în baza de date';

  @override
  String get matrixStatsDbIgnoredVectorClock =>
      'Ignorat de baza de date (VectorClock)';

  @override
  String get matrixStatsDbMissingBase => 'Lipsește baza de date';

  @override
  String matrixStatsDroppedByType(Object type) {
    return 'Eliminat ($type)';
  }

  @override
  String get matrixStatsEntryLinkNoops => 'Operațiuni fără efect EntryLink';

  @override
  String get matrixStatsFailures => 'Erori';

  @override
  String get matrixStatsFlushes => 'Goliri';

  @override
  String get matrixStatsForceRescan => 'Forțează rescanarea';

  @override
  String get matrixStatsForceRescanTooltip =>
      'Forțează acum rescanarea și recuperarea';

  @override
  String get matrixStatsLegend => 'Legendă';

  @override
  String get matrixStatsLegendTooltip =>
      'Legendă:\n• processed.<type> = mesaje de sincronizare procesate după tipul încărcăturii\n• droppedByType.<type> = elemente eliminate pe tip după reîncercări sau ignorarea mesajelor vechi\n• dbApplied = rânduri scrise în baza de date\n• dbIgnoredByVectorClock = date de intrare vechi sau identice ignorate de baza de date\n• conflictsCreated = ceasuri vectoriale concurente înregistrate\n• dbMissingBase = omis în așteptarea unei dependențe sau a unui rând de bază lipsă\n• staleAttachmentPurges = descriptori vechi din cache eliminați înainte de reîmprospătare';

  @override
  String get matrixStatsProcessed => 'Procesat';

  @override
  String matrixStatsProcessedByType(Object type) {
    return 'Procesat ($type)';
  }

  @override
  String get matrixStatsRefresh => 'Reîmprospătează';

  @override
  String get matrixStatsReliability => 'Fiabilitate';

  @override
  String get matrixStatsRetriesScheduled => 'Reîncercări programate';

  @override
  String get matrixStatsRetryNow => 'Reîncearcă acum';

  @override
  String get matrixStatsRetryNowTooltip =>
      'Reîncearcă acum erorile în așteptare';

  @override
  String get matrixStatsSignalLatencyLast => 'Latența semnalului (ultimii ms)';

  @override
  String get matrixStatsSignalLatencyMax => 'Latența semnalului (max. ms)';

  @override
  String get matrixStatsSignalLatencyMin => 'Latența semnalului (min. ms)';

  @override
  String get matrixStatsSignals => 'Semnale';

  @override
  String get matrixStatsSignalsClientStream => 'Semnale (flux client)';

  @override
  String get matrixStatsSignalsConnectivity => 'Semnale (conectivitate)';

  @override
  String get matrixStatsSignalsTimelineCallbacks =>
      'Semnale (apeluri inverse din cronologie)';

  @override
  String get matrixStatsSkipped => 'Omis';

  @override
  String get matrixStatsSkippedRetryCap => 'Omis (limită de reîncercări)';

  @override
  String get matrixStatsStaleAttachmentPurges => 'Atașamente vechi eliminate';

  @override
  String get matrixStatsThroughput => 'Debit';

  @override
  String get matrixStatsTopKpis => 'Indicatori principali';

  @override
  String get measurableDeleteConfirm => 'DA, CONFIRM STERGEREA';

  @override
  String get measurableDeleteQuestion =>
      'Sigur doriți să ștergeți acest tip de măsurătoare?';

  @override
  String get measurableNotFound => 'Masuratoarea nu a fost gasita';

  @override
  String get measurementCommentHint => 'Adăugați o notă (opțional)';

  @override
  String get measurementCommentSemantic => 'Comentariu, opțional';

  @override
  String measurementObservedAtChangeSemantic(String dateTime) {
    return 'Înregistrat la $dateTime. Modificați data și ora.';
  }

  @override
  String get measurementQuickAddLabel => 'Înregistrare rapidă';

  @override
  String measurementQuickLogSemantic(String value) {
    return 'Înregistrați imediat $value';
  }

  @override
  String get measurementSaveError =>
      'Măsurătoarea nu a putut fi salvată. Încercați din nou.';

  @override
  String get measurementSetObservedAtNowSemantic =>
      'Setați data și ora observate la momentul actual';

  @override
  String get measurementTimeLabel => 'Ora';

  @override
  String measurementValueSemantic(String measurable) {
    return 'Valoare pentru $measurable';
  }

  @override
  String get mediaShowInFileExplorerAction => 'Afișați în Explorer';

  @override
  String get mediaShowInFilesAction => 'Afișați în Fișiere';

  @override
  String get mediaShowInFinderAction => 'Afișați în Finder';

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
  String get modelAddPageTitle => 'Adăugați un model';

  @override
  String get modelEditBackTooltip => 'Înapoi';

  @override
  String get modelEditDescriptionHint => 'Descrieți acest model';

  @override
  String get modelEditDescriptionLabel => 'Descriere';

  @override
  String get modelEditDisplayNameHint => 'Un nume prietenos pentru acest model';

  @override
  String get modelEditDisplayNameLabel => 'Nume afișat';

  @override
  String get modelEditFunctionCallingDescription =>
      'Acest model acceptă apeluri de funcții și instrumente.';

  @override
  String get modelEditFunctionCallingLabel => 'Apeluri de funcții';

  @override
  String get modelEditGeminiThinkingModeLabel => 'Mod de gândire Gemini';

  @override
  String get modelEditInputModalitiesHint => 'Selectați tipurile de intrare';

  @override
  String get modelEditInputModalitiesLabel => 'Modalități de intrare';

  @override
  String get modelEditLoadError => 'Eșec la încărcarea configurației modelului';

  @override
  String get modelEditMaxTokensHint => 'Opțional — lăsați gol pentru nelimitat';

  @override
  String get modelEditMaxTokensLabel => 'Tokenuri maxime de completare';

  @override
  String get modelEditModalityNoneSelected => 'Niciunul selectat';

  @override
  String get modelEditOutputModalitiesHint => 'Selectați tipurile de ieșire';

  @override
  String get modelEditOutputModalitiesLabel => 'Modalități de ieșire';

  @override
  String get modelEditPageTitle => 'Editați modelul';

  @override
  String get modelEditProviderHint => 'Selectați un furnizor';

  @override
  String get modelEditProviderLabel => 'Furnizor';

  @override
  String get modelEditProviderModelIdHint => 'ex. gpt-4-turbo';

  @override
  String get modelEditProviderModelIdLabel => 'ID model furnizor';

  @override
  String get modelEditReasoningDescription =>
      'Acest model folosește gândire extinsă / lanț de raționament.';

  @override
  String get modelEditReasoningLabel => 'Model cu raționament';

  @override
  String get modelEditSaveButton => 'Salvare';

  @override
  String get modelEditSectionCapabilities => 'Capabilități';

  @override
  String get modelEditSectionIdentity => 'Identitate';

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
  String get multiSelectAddButton => 'Adăugați';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Adăugați ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'Nu s-au găsit elemente';

  @override
  String get navSidebarManualBrowserHint => 'Se deschide în browserul dvs.';

  @override
  String get navSidebarManualLabel => 'Ghid';

  @override
  String navTabMoreSemanticsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mai multe, $count de secțiuni suplimentare',
      few: 'Mai multe, $count secțiuni suplimentare',
      one: 'Mai multe, 1 secțiune suplimentară',
    );
    return '$_temp0';
  }

  @override
  String get navTabTitleCalendar => 'DailyOS';

  @override
  String get navTabTitleEvents => 'Evenimente';

  @override
  String get navTabTitleHabits => 'Obiceiuri';

  @override
  String get navTabTitleInsights => 'Informaţii';

  @override
  String get navTabTitleJournal => 'Jurnal';

  @override
  String get navTabTitleMore => 'Mai multe';

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
  String get notificationBellEmptySemantics =>
      'Notificări, nicio alertă necitită';

  @override
  String get notificationBellTooltip => 'Notificări';

  @override
  String notificationBellUnseenSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de alerte necitite',
      few: '$count alerte necitite',
      one: '1 alertă necitită',
    );
    return 'Notificări, $_temp0';
  }

  @override
  String get notificationInboxDismiss => 'Închideți notificarea';

  @override
  String get notificationInboxEmpty => 'Sunteți la zi.';

  @override
  String get notificationInboxError => 'Nu s-au putut încărca notificările.';

  @override
  String get notificationInboxTitle => 'Notificări';

  @override
  String get notificationSuggestionAttentionBodyFallback =>
      'Deschideți sarcina pentru a o revizui.';

  @override
  String notificationSuggestionAttentionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de sugestii necesită atenția dvs.',
      few: '$count sugestii necesită atenția dvs.',
      one: '1 sugestie necesită atenția dvs.',
    );
    return '$_temp0';
  }

  @override
  String get onboardingApiKeyConnect => 'Conectați';

  @override
  String get onboardingApiKeyConnecting => 'Se conectează…';

  @override
  String get onboardingApiKeyEnterKeyHint =>
      'Introduceți o cheie validă pentru a continua.';

  @override
  String get onboardingApiKeyError =>
      'Conectarea a eșuat. Verificați cheia și încercați din nou.';

  @override
  String get onboardingApiKeyField => 'Cheie API';

  @override
  String get onboardingApiKeyGetKeyAt => 'Obțineți o cheie la';

  @override
  String get onboardingApiKeyHide => 'Ascundeți cheia';

  @override
  String get onboardingApiKeyInvalid =>
      'Cheia a fost respinsă. Verificați-o și lipiți-o din nou.';

  @override
  String get onboardingApiKeyLocalNote =>
      'Rulează pe dispozitiv – nu e nevoie de cheie.';

  @override
  String get onboardingApiKeyNoKeyHelp =>
      'Prima dată? Conectați-vă, creați o cheie API și lipiți-o — gratuit la început.';

  @override
  String get onboardingApiKeyReveal => 'Afișați cheia';

  @override
  String get onboardingApiKeyTitle => 'Introduceți cheia API';

  @override
  String onboardingApiKeyUnreachable(String providerName) {
    return 'Nu s-a putut contacta $providerName. Verificați cheia sau conexiunea și încercați din nou.';
  }

  @override
  String get onboardingApiKeyVerifying => 'Se verifică…';

  @override
  String get onboardingCaptureCategoryPrompt => 'Unde doriți să ajungă?';

  @override
  String get onboardingCaptureListening => 'Ascult… atingeți când ați terminat';

  @override
  String get onboardingCaptureOrbLabel => 'Înregistrați-vă gândul';

  @override
  String get onboardingCaptureRatherType => 'Preferați să scrieți?';

  @override
  String get onboardingCaptureReassurance =>
      'Veți putea edita totul în continuare.';

  @override
  String get onboardingCaptureThinking =>
      'Vă transform cuvintele într-o sarcină…';

  @override
  String get onboardingCaptureTypePrompt => 'Scrieți-vă gândul';

  @override
  String get onboardingCategoryAddOwn => 'Adăugați propria';

  @override
  String get onboardingCategoryContinue => 'Continuați';

  @override
  String get onboardingCategoryExplanation =>
      'Fiecare zonă a vieții are spațiul ei. Alegeți ce se potrivește sau adăugați-vă propriile.';

  @override
  String get onboardingCategoryFamily => 'Familie';

  @override
  String get onboardingCategoryFitness => 'Fitness';

  @override
  String get onboardingCategoryFriends => 'Prieteni';

  @override
  String get onboardingCategoryTitle => 'Unde să lucreze AI-ul dvs.?';

  @override
  String get onboardingCategoryWhy => 'De ce zone?';

  @override
  String onboardingCategoryWhyDetail(String provider) {
    return 'Fiecare zonă poate folosi propria AI. $provider va alimenta zonele alese aici — mai târziu puteți atribui AI diferite pentru zone diferite.';
  }

  @override
  String get onboardingCategoryWork => 'Muncă';

  @override
  String get onboardingConnectGeminiName => 'Gemini';

  @override
  String get onboardingConnectGeminiTagline => 'Statele Unite';

  @override
  String get onboardingConnectLessOptions => 'Mai puține opțiuni';

  @override
  String get onboardingConnectMistralName => 'Mistral';

  @override
  String get onboardingConnectMistralTagline => 'Uniunea Europeană';

  @override
  String get onboardingConnectMoreOptions => 'Mai multe opțiuni';

  @override
  String get onboardingConnectNotSure =>
      'Melious.ai este opțiunea implicită recomandată.';

  @override
  String get onboardingConnectOllamaName => 'Ollama';

  @override
  String get onboardingConnectOpenAiName => 'OpenAI';

  @override
  String get onboardingConnectQwenName => 'Qwen';

  @override
  String get onboardingConnectQwenTagline => 'China';

  @override
  String get onboardingConnectTitle =>
      'Alegeți creierul AI pentru sarcinile dvs.';

  @override
  String get onboardingFirstTaskCreatedHint =>
      'Atingeți sarcina pentru a o deschide';

  @override
  String get onboardingFirstTaskCreatedTitle => 'Prima dvs. sarcină este gata';

  @override
  String get onboardingFirstTaskGuidance =>
      'Atingeți pentru a vorbi și spuneți ce aveți de făcut — Lotti o transformă într-o sarcină reală.';

  @override
  String get onboardingFirstTaskSuggestionDentist =>
      'Să fac o programare la dentist';

  @override
  String get onboardingFirstTaskSuggestionMeeting =>
      'Să pregătesc ședința de luni';

  @override
  String get onboardingFirstTaskSuggestionPlanWeek =>
      'Să îmi planific săptămâna';

  @override
  String get onboardingFirstTaskSuggestionsLabel =>
      'Nu sunteți încă pregătit să vorbiți? Începeți cu una dintre acestea:';

  @override
  String get onboardingFirstTaskTitle => 'Creați-vă prima sarcină';

  @override
  String get onboardingMetricsActiveDays => 'Zile active';

  @override
  String get onboardingMetricsActiveDaysInFirstSeven =>
      'Zile active în primele 7 zile';

  @override
  String get onboardingMetricsBaselineCohort =>
      'Cohorta de referință (înainte de FTUE)';

  @override
  String get onboardingMetricsInstallFirstSeenUtc =>
      'Prima instalare detectată (UTC)';

  @override
  String get onboardingMetricsNo => 'nu';

  @override
  String get onboardingMetricsReachedRealAha =>
      'Momentul «aha» real a fost atins';

  @override
  String get onboardingMetricsYes => 'da';

  @override
  String get onboardingRecordingStyleAnalogue => 'Analogic — VU-metru';

  @override
  String get onboardingRecordingStyleContinue => 'Continuați';

  @override
  String get onboardingRecordingStyleExplanation =>
      'Alegeți un aspect pentru microfon. Îl puteți schimba oricând în Setări.';

  @override
  String get onboardingRecordingStyleModern => 'Modern — orb de energie';

  @override
  String get onboardingRecordingStyleTitle =>
      'Cum doriți să arate înregistrarea?';

  @override
  String get onboardingRecordingStyleTryVoice => 'Încercați cu vocea';

  @override
  String get onboardingSuccessContinue => 'Începeți';

  @override
  String get onboardingSuccessSubtitle =>
      'Creierul AI este conectat și pregătit să vă transforme cuvintele în sarcini.';

  @override
  String get onboardingSuccessTitle => 'Gata de start';

  @override
  String get onboardingWelcomeConnectButton => 'Alegeți creierul AI';

  @override
  String get onboardingWelcomeMessage =>
      'Conectați-vă creierul AI, rostiți un gând și urmăriți-l devenind o sarcină structurată.';

  @override
  String get onboardingWelcomeSkipButton => 'Explorați mai întâi';

  @override
  String get onboardingWelcomeTitle =>
      'Vorbiți. Lotti transformă totul într-un plan.';

  @override
  String get optionalCategoryLabel => 'Categorie (opțional)';

  @override
  String get outboxActionRemove => 'Eliminați';

  @override
  String get outboxActionRetry => 'Reîncercați';

  @override
  String get outboxFailedReassurance =>
      'Rămâne salvat pe acest dispozitiv – se va sincroniza după ce problema se rezolvă.';

  @override
  String get outboxFilterFailed => 'Eșuat';

  @override
  String get outboxFilterWaiting => 'În așteptare';

  @override
  String get outboxMonitorAttachmentLabel => 'Atașament';

  @override
  String get outboxMonitorDelete => 'șterge';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Ștergeți';

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
      'Coada de ieșire nu a putut fi încărcată. Trageți în jos pentru reîmprospătare și încercați din nou.';

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
  String get outboxMonitorRetryConfirmLabel => 'Reîncercați acum';

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
  String get outboxRemoveConfirmMessage =>
      'Această modificare nu a fost încă sincronizată. Dacă o eliminați aici, nu va ajunge pe celelalte dispozitive. Rămâne pe acest dispozitiv.';

  @override
  String get outboxRemoveConfirmTitle => 'Eliminați din coadă?';

  @override
  String get outboxRetryAll => 'Reîncercați tot';

  @override
  String get outboxShowDetails => 'Afișați detaliile tehnice';

  @override
  String get outboxStatusFailed => 'Nu s-a putut trimite';

  @override
  String get outboxStatusSending => 'Se trimite';

  @override
  String get outboxStatusSent => 'Trimis';

  @override
  String get outboxStatusWaiting => 'În așteptarea trimiterii';

  @override
  String outboxSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elemente nu au putut fi trimise',
      one: '1 element nu a putut fi trimis',
    );
    return '$_temp0';
  }

  @override
  String outboxSummaryOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elemente vor fi trimise la reconectare',
      one: '1 element va fi trimis la reconectare',
    );
    return '$_temp0';
  }

  @override
  String outboxSummarySending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se trimit $count elemente…',
      one: 'Se trimite 1 element…',
    );
    return '$_temp0';
  }

  @override
  String get outboxSummarySynced => 'Totul este sincronizat';

  @override
  String outboxSummaryWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elemente în așteptarea trimiterii',
      one: '1 element în așteptarea trimiterii',
    );
    return '$_temp0';
  }

  @override
  String outboxTriedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Încercat de $count ori',
      one: 'Încercat o dată',
    );
    return '$_temp0';
  }

  @override
  String get panasCompletionText =>
      'Vă mulțumim că ați completat chestionarul PANAS!';

  @override
  String get panasCompletionTitle => 'Finalizat';

  @override
  String get panasEmotionActive => 'Activ(ă)';

  @override
  String get panasEmotionAfraid => 'Temător(oare)';

  @override
  String get panasEmotionAlert => 'Alert(ă)';

  @override
  String get panasEmotionAshamed => 'Rușinat(ă)';

  @override
  String get panasEmotionAttentive => 'Atent(ă)';

  @override
  String get panasEmotionDetermined => 'Hotărât(ă)';

  @override
  String get panasEmotionDistressed => 'Tulburat(ă)';

  @override
  String get panasEmotionEnthusiastic => 'Entuziast(ă)';

  @override
  String get panasEmotionExcited => 'Entuziasmat(ă)';

  @override
  String get panasEmotionGuilty => 'Vinovat(ă)';

  @override
  String get panasEmotionHostile => 'Ostil(ă)';

  @override
  String get panasEmotionInspired => 'Inspirat(ă)';

  @override
  String get panasEmotionInterested => 'Interesat(ă)';

  @override
  String get panasEmotionIrritable => 'Iritabil(ă)';

  @override
  String get panasEmotionJittery => 'Agitat(ă)';

  @override
  String get panasEmotionNervous => 'Nervos/Nervoasă';

  @override
  String get panasEmotionProud => 'Mândru(ă)';

  @override
  String get panasEmotionScared => 'Speriat(ă)';

  @override
  String get panasEmotionStrong => 'Puternic(ă)';

  @override
  String get panasEmotionUpset => 'Supărat(ă)';

  @override
  String get panasInstructionFootnote =>
      'Watson, D., Clark, L. A., & Tellegen, A. (1988). Development and validation of brief measures of positive and negative affect: The PANAS scales. Journal of Personality and Social Psychology, 54(6), 1063–1070.';

  @override
  String get panasInstructionText =>
      'Indicați în ce măsură vă simțiți astfel chiar acum, în acest moment.\n\n1—Deloc sau foarte puțin,\n2—Puțin,\n3—Moderat,\n4—Destul de mult,\n5—Extrem de mult';

  @override
  String get panasInstructionTitle =>
      'Scala afectelor pozitive și negative (PANAS; Watson et al., 1988)';

  @override
  String get panasScaleALittle => 'Puțin';

  @override
  String get panasScaleExtremely => 'Extrem de mult';

  @override
  String get panasScaleModerately => 'Moderat';

  @override
  String get panasScaleQuiteABit => 'Destul de mult';

  @override
  String get panasScaleVerySlightlyOrNotAtAll => 'Deloc sau foarte puțin';

  @override
  String get privateLabel => 'Privat';

  @override
  String get privateSwitchDescription =>
      'Vizibil doar când intrările private sunt afișate';

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
  String get projectRecommendationResolveTooltip => 'Marcați ca rezolvat';

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
      'Niciun proiect nu corespunde căutării dvs.';

  @override
  String get projectShowcaseOneOnOneReviewsTab => 'Revizuiri 1:1';

  @override
  String get projectShowcaseOngoing => 'În curs';

  @override
  String get projectShowcaseProjectTasksTab => 'Sarcinile proiectului';

  @override
  String get projectShowcaseSearchHint => 'Căutați proiecte';

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
  String get projectShowcaseViewBlocker => 'Vedeți blocajul';

  @override
  String get projectStatusActive => 'Activ';

  @override
  String get projectStatusArchived => 'Arhivat';

  @override
  String get projectStatusChangeTitle => 'Schimbă starea';

  @override
  String get projectStatusCompleted => 'Finalizat';

  @override
  String get projectStatusMonitoring => 'Monitorizare';

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
  String get promptGenerationCopyButton => 'Copiați promptul';

  @override
  String get promptGenerationCopyTooltip => 'Copiați promptul în clipboard';

  @override
  String get promptGenerationExpandTooltip => 'Afișați promptul complet';

  @override
  String get promptGenerationFullPromptLabel => 'Prompt complet:';

  @override
  String get promptSelectionModalTitle => 'Selectați un prompt preconfigurat';

  @override
  String get provisionedSyncBundleImported => 'Cod de provizionare importat';

  @override
  String get provisionedSyncConfigureButton => 'Configurați';

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
  String get provisionedSyncImportHint => 'Lipiți aici codul de configurare';

  @override
  String get provisionedSyncImportTitle => 'Configurați sincronizarea';

  @override
  String get provisionedSyncInvalidBundle => 'Cod de provizionare invalid';

  @override
  String get provisionedSyncJoiningRoom =>
      'Se alătură camerei de sincronizare...';

  @override
  String get provisionedSyncLoggingIn => 'Conectare în curs...';

  @override
  String get provisionedSyncPasteClipboard => 'Lipiți din clipboard';

  @override
  String get provisionedSyncReady =>
      'Scanați acest cod QR pe dispozitivul mobil';

  @override
  String get provisionedSyncRetry => 'Reîncercați';

  @override
  String get provisionedSyncRotatingPassword => 'Securizarea contului...';

  @override
  String get provisionedSyncScanButton => 'Scanați codul QR';

  @override
  String get provisionedSyncShowQr => 'Afișați codul QR de configurare';

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
  String get queueSkippedRetryAll => 'Reîncercați evenimentele omise';

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
  String get referenceImageContinue => 'Continuați';

  @override
  String referenceImageContinueWithCount(int count) {
    return 'Continuați ($count)';
  }

  @override
  String get referenceImageLoadError =>
      'Încărcarea imaginilor a eșuat. Vă rugăm să încercați din nou.';

  @override
  String get referenceImageSelectionSubtitle =>
      'Alegeți până la 5 imagini pentru a ghida stilul vizual al IA';

  @override
  String get referenceImageSelectionTitle => 'Selectați imagini de referință';

  @override
  String get referenceImageSkip => 'Săriți peste';

  @override
  String get saveButton => 'Salvați';

  @override
  String get saveButtonLabel => 'Salvați';

  @override
  String get saveLabel => 'Salvați';

  @override
  String get saveShortcutTooltip => 'Salvare — Ctrl+S (⌘S pe Mac)';

  @override
  String get saveSuccessful => 'Salvat cu succes';

  @override
  String get searchHint => 'Căutare...';

  @override
  String get searchModeFullText => 'Text integral';

  @override
  String get searchModeVector => 'Vector';

  @override
  String get searchTasksHint => 'Căutați sarcini...';

  @override
  String get selectButton => 'Selectați';

  @override
  String get selectColor => 'Alegeți o culoare';

  @override
  String get selectLanguage => 'Selectați limba';

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
  String get sessionRatingEditButton => 'Editați evaluarea';

  @override
  String get sessionRatingEnergyQuestion => 'Cât de energizat v-ați simțit?';

  @override
  String get sessionRatingFocusQuestion => 'Cât de concentrat ați fost?';

  @override
  String get sessionRatingNoteHint => 'Notă scurtă (opțional)';

  @override
  String get sessionRatingProductivityQuestion =>
      'Cât de productivă a fost această sesiune?';

  @override
  String get sessionRatingRateAction => 'Evaluează sesiunea';

  @override
  String get sessionRatingSaveButton => 'Salvați';

  @override
  String get sessionRatingSaveError =>
      'Nu s-a putut salva evaluarea. Vă rugăm să încercați din nou.';

  @override
  String get sessionRatingSkipButton => 'Omite';

  @override
  String get sessionRatingTitle => 'Evaluează această sesiune';

  @override
  String get sessionRatingViewAction => 'Vedeți evaluarea';

  @override
  String get settingsAboutAppInformation => 'Informații aplicație';

  @override
  String get settingsAboutAppTagline => 'Jurnalul dvs. personal';

  @override
  String get settingsAboutBuildType => 'Tip build';

  @override
  String get settingsAboutDailyOsPersonalizationTitle =>
      'Personalizare Daily OS';

  @override
  String get settingsAboutDailyOsUserNameHelper =>
      'Folosit pentru salutul Daily OS și sincronizat pe dispozitivele dvs.';

  @override
  String get settingsAboutDailyOsUserNameLabel => 'Numele dvs.';

  @override
  String get settingsAboutJournalEntries => 'Intrări jurnal';

  @override
  String get settingsAboutPlatform => 'Platformă';

  @override
  String get settingsAboutTitle => 'Despre Lotti';

  @override
  String get settingsAboutVersion => 'Versiune';

  @override
  String get settingsAboutYourData => 'Datele dvs.';

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
  String get settingsAdvancedManualLanguageSubtitle =>
      'Alegeți limba în care se deschide manualul Lotti';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Vizualizați și gestionați elementele care așteaptă sincronizarea';

  @override
  String get settingsAdvancedSubtitle => 'Setări avansate și întreținere';

  @override
  String get settingsAdvancedTitle => 'Setări avansate';

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
  String get settingsAiModelsSubtitle => 'Modele și capabilități per furnizor';

  @override
  String get settingsAiModelsTitle => 'Modele';

  @override
  String get settingsAiProfilesSubtitle => 'Furnizori și modele';

  @override
  String get settingsAiProfilesTitle => 'Profiluri de inferență';

  @override
  String get settingsAiProvidersSubtitle => 'Furnizori AI conectați și chei';

  @override
  String get settingsAiProvidersTitle => 'Furnizori';

  @override
  String get settingsAiSubtitle =>
      'Configurați furnizorii AI, modelele și prompturile';

  @override
  String get settingsAiTitle => 'Setări AI';

  @override
  String get settingsAiUsageSubtitle =>
      'Costul, energia și CO₂e ale apelurilor AI';

  @override
  String get settingsAiUsageTitle => 'Utilizare și impact';

  @override
  String get settingsBeamPageEditModelTitle => 'Editare model';

  @override
  String get settingsBeamPageEditProfileTitle => 'Editare profil';

  @override
  String get settingsCategoriesCreateTitle => 'Creare categorie';

  @override
  String get settingsCategoriesDetailsLabel => 'Editare categorie';

  @override
  String get settingsCategoriesEmptyState => 'Nicio categorie încă';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Creați o categorie pentru a organiza intrările dvs.';

  @override
  String get settingsCategoriesErrorLoading =>
      'Eroare la încărcarea categoriilor';

  @override
  String get settingsCategoriesNameLabel => 'Numele categoriei';

  @override
  String settingsCategoriesNoMatchQuery(String query) {
    return 'Nicio categorie nu corespunde cu \"$query\"';
  }

  @override
  String get settingsCategoriesSearchHint => 'Căutați categorii…';

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
  String get settingsCelebrationsChecklistDescription =>
      'Un efect și scântei când bifați un element';

  @override
  String get settingsCelebrationsChecklistTitle => 'Elemente din listă';

  @override
  String get settingsCelebrationsCustomizeTitle => 'Personalizați';

  @override
  String get settingsCelebrationsCustomizeTooltip => 'Personalizați acest stil';

  @override
  String get settingsCelebrationsEnabledDescription =>
      'Comutatorul principal pentru efectele de finalizare. Dezactivat, ascunde toate animațiile; vibrațiile au propriul comutator.';

  @override
  String get settingsCelebrationsEnabledTitle => 'Animații de finalizare';

  @override
  String get settingsCelebrationsGroupLook => 'Aspect';

  @override
  String get settingsCelebrationsGroupMotion => 'Mișcare';

  @override
  String get settingsCelebrationsGroupShape => 'Formă';

  @override
  String get settingsCelebrationsHabitsDescription =>
      'Strălucire și scântei când finalizați un obicei';

  @override
  String get settingsCelebrationsHabitsTitle => 'Obiceiuri';

  @override
  String get settingsCelebrationsHapticsDescription =>
      'O scurtă vibrație când terminați ceva, independentă de animație.';

  @override
  String get settingsCelebrationsHapticsTitle => 'Vibrații la finalizare';

  @override
  String get settingsCelebrationsKnobClearCenter => 'Spațiu central';

  @override
  String get settingsCelebrationsKnobCount => 'Particule';

  @override
  String get settingsCelebrationsKnobDescClearCenter =>
      'Spațiu liber în centru';

  @override
  String get settingsCelebrationsKnobDescCount => 'Câte particule ies';

  @override
  String get settingsCelebrationsKnobDescFallout => 'Cât de mult cad scânteile';

  @override
  String get settingsCelebrationsKnobDescFanSpread => 'Lățimea evantaiului';

  @override
  String get settingsCelebrationsKnobDescGlow => 'Intensitatea strălucirii';

  @override
  String get settingsCelebrationsKnobDescGravity => 'Cât de repede cad';

  @override
  String get settingsCelebrationsKnobDescHalo => 'Intensitatea haloului';

  @override
  String get settingsCelebrationsKnobDescInnerRing =>
      'Mărimea inelului interior';

  @override
  String get settingsCelebrationsKnobDescLaunch =>
      'Întârzierea înainte de explozie';

  @override
  String get settingsCelebrationsKnobDescPop => 'Când se sparg';

  @override
  String get settingsCelebrationsKnobDescReach => 'Cât de departe ajung';

  @override
  String get settingsCelebrationsKnobDescRise => 'Cât de sus se ridică';

  @override
  String get settingsCelebrationsKnobDescSize =>
      'Cât de mare e fiecare particulă';

  @override
  String get settingsCelebrationsKnobDescSpeedSpread => 'Variația vitezei';

  @override
  String get settingsCelebrationsKnobDescSpin => 'Cât de repede se rotesc';

  @override
  String get settingsCelebrationsKnobDescSpread => 'Lățimea jetului';

  @override
  String get settingsCelebrationsKnobDescSway => 'Cât de mult se leagănă';

  @override
  String get settingsCelebrationsKnobDescSwell => 'Cât de mult cresc';

  @override
  String get settingsCelebrationsKnobDescTrail => 'Lungimea dârei';

  @override
  String get settingsCelebrationsKnobDescTwinkle => 'Cât de mult pâlpâie';

  @override
  String get settingsCelebrationsKnobDescUpward => 'Cât de puternic se ridică';

  @override
  String get settingsCelebrationsKnobDescWobble => 'Cât de mult se clatină';

  @override
  String get settingsCelebrationsKnobFallout => 'Cădere';

  @override
  String get settingsCelebrationsKnobFanSpread => 'Deschiderea evantaiului';

  @override
  String get settingsCelebrationsKnobGlow => 'Strălucire';

  @override
  String get settingsCelebrationsKnobGravity => 'Gravitație';

  @override
  String get settingsCelebrationsKnobHalo => 'Halou';

  @override
  String get settingsCelebrationsKnobInnerRing => 'Inel interior';

  @override
  String get settingsCelebrationsKnobLaunch => 'Timp de lansare';

  @override
  String get settingsCelebrationsKnobPop => 'Punct de spargere';

  @override
  String get settingsCelebrationsKnobReach => 'Rază';

  @override
  String get settingsCelebrationsKnobRise => 'Înălțime de ridicare';

  @override
  String get settingsCelebrationsKnobSize => 'Dimensiune';

  @override
  String get settingsCelebrationsKnobSpeedSpread => 'Variația vitezei';

  @override
  String get settingsCelebrationsKnobSpin => 'Rotire';

  @override
  String get settingsCelebrationsKnobSpread => 'Unghi de dispersie';

  @override
  String get settingsCelebrationsKnobSway => 'Legănare';

  @override
  String get settingsCelebrationsKnobSwell => 'Umflare';

  @override
  String get settingsCelebrationsKnobTrail => 'Lungimea dârei';

  @override
  String get settingsCelebrationsKnobTwinkle => 'Sclipire';

  @override
  String get settingsCelebrationsKnobUpward => 'Ridicare';

  @override
  String get settingsCelebrationsKnobWobble => 'Tremurat';

  @override
  String get settingsCelebrationsPlaygroundHint =>
      'Atingeți rândul evidențiat pentru previzualizare';

  @override
  String get settingsCelebrationsPlaygroundLiveNote =>
      'Modificările se salvează și se aplică peste tot instantaneu';

  @override
  String get settingsCelebrationsPreviewChecklistItem => 'Bifați-mă';

  @override
  String get settingsCelebrationsPreviewDescription =>
      'Atingeți un control pentru a reda stilul ales.';

  @override
  String get settingsCelebrationsPreviewDone => 'Gata';

  @override
  String get settingsCelebrationsPreviewHabit => 'Obicei';

  @override
  String get settingsCelebrationsPreviewSample1 => 'Plimbare de dimineață';

  @override
  String get settingsCelebrationsPreviewSample2 => 'Termină raportul';

  @override
  String get settingsCelebrationsPreviewSample3 => 'Udă plantele';

  @override
  String get settingsCelebrationsPreviewTitle => 'Încercați';

  @override
  String get settingsCelebrationsReplay => 'Reia';

  @override
  String get settingsCelebrationsResetToast =>
      'Stil resetat la valorile implicite';

  @override
  String get settingsCelebrationsResetToDefault =>
      'Resetați la valorile implicite';

  @override
  String get settingsCelebrationsResetUndo => 'Anulați';

  @override
  String get settingsCelebrationsSectionDescription =>
      'O mică festivitate când finalizați ceva. Dacă dezactivați una, finalizarea și vibrația rămân — doar animația este omisă.';

  @override
  String get settingsCelebrationsSectionTitle => 'Celebrări la finalizare';

  @override
  String get settingsCelebrationsStyleDescription =>
      'Atingeți un card pentru a previzualiza un stil și a-l alege.';

  @override
  String get settingsCelebrationsStyleTitle => 'Stil';

  @override
  String get settingsCelebrationsSubtitle => 'Celebrări la finalizare';

  @override
  String get settingsCelebrationsTasksDescription =>
      'Strălucire și scântei când mutați o sarcină la Finalizat';

  @override
  String get settingsCelebrationsTasksTitle => 'Sarcini';

  @override
  String get settingsCelebrationsTitle => 'Animații';

  @override
  String get settingsCelebrationsVariantBubbles => 'Bule';

  @override
  String get settingsCelebrationsVariantCombine => 'Combinați două stiluri';

  @override
  String get settingsCelebrationsVariantCombineDescription =>
      'Două stiluri aleatorii suprapuse de fiecare dată';

  @override
  String get settingsCelebrationsVariantConfetti => 'Confeti';

  @override
  String get settingsCelebrationsVariantEmbers => 'Jar';

  @override
  String get settingsCelebrationsVariantFireworks => 'Artificii';

  @override
  String get settingsCelebrationsVariantRandom => 'Aleatoriu';

  @override
  String get settingsCelebrationsVariantRandomDescription =>
      'Un stil diferit de fiecare dată';

  @override
  String get settingsCelebrationsVariantSparks => 'Scântei';

  @override
  String get settingsConflictsTitle => 'Sync cu conflicte';

  @override
  String get settingsDashboardDetailsLabel => 'Editare panou de bord';

  @override
  String get settingsDashboardSaveLabel => 'Salvați';

  @override
  String get settingsDashboardsCreateTitle => 'Creare panou de bord';

  @override
  String get settingsDashboardsEmptyState => 'Niciun panou de bord încă';

  @override
  String get settingsDashboardsEmptyStateHint =>
      'Apăsați butonul + pentru a crea primul panou de bord.';

  @override
  String get settingsDashboardsErrorLoading =>
      'Eroare la încărcarea panourilor de bord';

  @override
  String settingsDashboardsNoMatchQuery(String query) {
    return 'Niciun panou de bord nu corespunde cu \"$query\"';
  }

  @override
  String get settingsDashboardsSearchHint => 'Căutați panouri de bord…';

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
  String get settingsHabitsCreateTitle => 'Creare obicei';

  @override
  String get settingsHabitsDeleteTooltip => 'Ștergeți obiceiul';

  @override
  String get settingsHabitsDescriptionLabel => 'Descriere (opțional)';

  @override
  String get settingsHabitsDetailsLabel => 'Editare obicei';

  @override
  String get settingsHabitsEmptyState => 'Niciun obicei încă';

  @override
  String get settingsHabitsEmptyStateHint =>
      'Apăsați butonul + pentru a crea primul obicei.';

  @override
  String get settingsHabitsErrorLoading => 'Eroare la încărcarea obiceiurilor';

  @override
  String get settingsHabitsNameLabel => 'Numele obiceiului';

  @override
  String settingsHabitsNoMatchQuery(String query) {
    return 'Niciun obicei nu corespunde cu \"$query\"';
  }

  @override
  String get settingsHabitsPrivateLabel => 'Privat:';

  @override
  String get settingsHabitsSaveLabel => 'Salvați';

  @override
  String get settingsHabitsSearchHint => 'Căutați obiceiuri…';

  @override
  String get settingsHabitsSubtitle =>
      'Gestionați obiceiurile și rutinele dvs.';

  @override
  String get settingsHabitsTitle => 'Obiceiuri';

  @override
  String get settingsHealthImportActivity => 'Importați datele de activitate';

  @override
  String get settingsHealthImportBloodPressure =>
      'Importați datele de tensiune arterială';

  @override
  String get settingsHealthImportBodyMeasurement =>
      'Importați datele de măsurători corporale';

  @override
  String get settingsHealthImportFromDate => 'Început';

  @override
  String get settingsHealthImportHeartRate => 'Importați datele de puls';

  @override
  String get settingsHealthImportSleep => 'Importați datele de somn';

  @override
  String get settingsHealthImportTitle => 'Import de date de sănătate';

  @override
  String get settingsHealthImportToDate => 'Sfârșit';

  @override
  String get settingsHealthImportWorkout => 'Importați datele de antrenament';

  @override
  String get settingsKeyboardShortcutsSubtitle =>
      'Aflați combinațiile de taste pentru navigare și editare mai rapide pe desktop';

  @override
  String get settingsKeyboardShortcutsTitle => 'Comenzi rapide de la tastatură';

  @override
  String get settingsLabelsCategoriesAdd => 'Adăugați o categorie';

  @override
  String get settingsLabelsCategoriesHeading => 'Categorii aplicabile';

  @override
  String get settingsLabelsCategoriesNone => 'Se aplică la toate categoriile';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Eliminați';

  @override
  String get settingsLabelsColorHeading => 'Culoare';

  @override
  String get settingsLabelsColorSubheading => 'Presetări rapide';

  @override
  String get settingsLabelsCreateTitle => 'Creați o etichetă';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Ștergeți';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return 'Sigur doriți să ștergeți „$labelName”? Sarcinile cu această etichetă vor pierde atribuirea.';
  }

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Ștergeți eticheta';

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
  String get settingsLabelsEditTitle => 'Editați eticheta';

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
      'Vizibil doar când intrările private sunt afișate';

  @override
  String get settingsLabelsPrivateTitle => 'Privat';

  @override
  String get settingsLabelsSearchHint => 'Căutați etichete…';

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
      other: '$count de sarcini',
      few: '$count sarcini',
      one: '1 sarcină',
    );
    return '$_temp0';
  }

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
  String get settingsMaintenanceOnboardingAnimationGallerySubtitle =>
      'Comparați în direct animațiile de bun venit și pagina de conectare (depanare)';

  @override
  String get settingsMaintenanceOnboardingAnimationGalleryTitle =>
      'Galeria de animații pentru onboarding';

  @override
  String get settingsMaintenanceOnboardingWelcomeSubtitle =>
      'Previzualizați ecranul de bun venit FTUE și cardurile furnizorilor (depanare)';

  @override
  String get settingsMaintenanceOnboardingWelcomeTitle =>
      'Afișați mesajul de bun venit pentru onboarding';

  @override
  String get settingsMaintenanceTitle => 'Întreținere';

  @override
  String get settingsManualLanguageCzechTitle => 'Cehă';

  @override
  String get settingsManualLanguageDutchTitle => 'Neerlandeză';

  @override
  String get settingsManualLanguageDanishTitle => 'Daneză';

  @override
  String get settingsManualLanguageEnglishTitle => 'Engleză';

  @override
  String get settingsManualLanguageFollowSystemSubtitle =>
      'Folosiți limba dispozitivului dvs. în Lotti și în manual dacă este acceptată; altfel, engleza.';

  @override
  String get settingsManualLanguageFollowSystemTitle => 'Urmați sistemul';

  @override
  String get settingsManualLanguageFrenchTitle => 'Franceză';

  @override
  String get settingsManualLanguageGermanTitle => 'Germană';

  @override
  String get settingsManualLanguageItalianTitle => 'Italiană';

  @override
  String get settingsManualLanguagePortugueseTitle => 'Portugheză';

  @override
  String get settingsManualLanguageRomanianTitle => 'Română';

  @override
  String get settingsManualLanguageSpanishTitle => 'Spaniolă';

  @override
  String get settingsManualLanguageSwedishTitle => 'Suedeză';

  @override
  String get settingsManualLanguageTitle => 'Limbă';

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
  String get settingsMatrixDiagnosticCopyButton => 'Copiați în clipboard';

  @override
  String get settingsMatrixDiagnosticDialogTitle =>
      'Informații de diagnostic pentru sincronizare';

  @override
  String get settingsMatrixDiagnosticShowButton =>
      'Afișați informațiile de diagnostic';

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
  String settingsMatrixSentMessageType(String eventType) {
    return 'Trimis ($eventType)';
  }

  @override
  String get settingsMatrixStartVerificationLabel => 'Începeți verificarea';

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
  String get settingsMatrixVerifyLabel => 'Verificați';

  @override
  String get settingsMeasurableAggregationHelper =>
      'Cum se combină intrările unei zile în grafice';

  @override
  String get settingsMeasurableAggregationLabel => 'Agregare implicită';

  @override
  String get settingsMeasurableDeleteTooltip => 'Ștergeți tipul măsurătorii';

  @override
  String get settingsMeasurableDescriptionLabel => 'Descriere';

  @override
  String get settingsMeasurableDetailsLabel => 'Editare măsurătoare';

  @override
  String get settingsMeasurableNameLabel => 'Numele măsurătorii';

  @override
  String get settingsMeasurablePrivateLabel => 'Privat: ';

  @override
  String get settingsMeasurableSaveLabel => 'Salvare';

  @override
  String get settingsMeasurablesCreateTitle => 'Creare măsurătoare';

  @override
  String get settingsMeasurablesEmptyState => 'Nicio măsurătoare încă';

  @override
  String get settingsMeasurablesEmptyStateHint =>
      'Măsurătorile sunt valori urmărite în timp — greutate, apă, pași.';

  @override
  String get settingsMeasurablesErrorLoading =>
      'Eroare la încărcarea măsurătorilor';

  @override
  String settingsMeasurablesNoMatchQuery(String query) {
    return 'Nicio măsurătoare nu corespunde cu \"$query\"';
  }

  @override
  String get settingsMeasurablesSearchHint => 'Căutați măsurători…';

  @override
  String get settingsMeasurablesSubtitle =>
      'Configurați tipurile de date măsurabile';

  @override
  String get settingsMeasurablesTitle => 'Măsurători';

  @override
  String get settingsMeasurableUnitLabel => 'Unitatea abrevierii';

  @override
  String get settingsOnboardingActionSubtitle =>
      'Redeschideți fluxul de bun venit — conectați-vă creierul AI și creați o sarcină';

  @override
  String get settingsOnboardingMetricsSubtitle =>
      'Pâlnie FTUE — instalare, activare, retenție (depanare)';

  @override
  String get settingsOnboardingMetricsTitle => 'Valori de onboarding';

  @override
  String get settingsOnboardingReplayTitle => 'Reluați onboardingul';

  @override
  String get settingsOnboardingStartTitle => 'Începeți onboardingul';

  @override
  String get settingsOnboardingStatusActivated =>
      'Ați creat prima dvs. sarcină cu AI';

  @override
  String get settingsOnboardingStatusLoading => 'Se încarcă…';

  @override
  String get settingsOnboardingStatusNotActivated => 'Neînceput încă';

  @override
  String get settingsOnboardingStatusTitle => 'Stare';

  @override
  String get settingsOnboardingSubtitle =>
      'Reafișați fluxul de bun venit oricând doriți';

  @override
  String get settingsOnboardingTestResetConfirm => 'Resetați';

  @override
  String get settingsOnboardingTestResetConfirmQuestion =>
      'Doriți să ștergeți istoricul solicitărilor și metricile de onboarding? Planurile Daily OS existente se păstrează, așadar utilizați un profil nou pentru a testa întregul parcurs Daily OS de la prima utilizare.';

  @override
  String get settingsOnboardingTestResetSubtitle =>
      'Ștergeți istoricul solicitărilor și metricile; planurile Daily OS existente se păstrează (depanare)';

  @override
  String get settingsOnboardingTestResetTitle =>
      'Resetați starea de test pentru onboarding';

  @override
  String get settingsOnboardingTitle => 'Configurare inițială';

  @override
  String get settingsOptionsTitle => 'Opțiuni';

  @override
  String get settingsRecordingStyleExplanation =>
      'Alegeți cum arată microfonul în timp ce înregistrați.';

  @override
  String get settingsRecordingStyleSubtitle =>
      'VU-metru sau orb de energie în timpul înregistrării';

  @override
  String get settingsRecordingStyleTitle => 'Stil de înregistrare';

  @override
  String get settingsResetGeminiConfirm => 'Resetați';

  @override
  String get settingsResetGeminiConfirmQuestion =>
      'Aceasta va afișa din nou dialogul de configurare Gemini. Continuați?';

  @override
  String get settingsResetGeminiSubtitle =>
      'Afișați din nou dialogul de configurare Gemini AI';

  @override
  String get settingsResetGeminiTitle =>
      'Resetați dialogul de configurare Gemini';

  @override
  String get settingsResetHintsConfirm => 'Confirmați';

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
      'Ștergeți sfaturile unice și indiciile de introducere';

  @override
  String get settingsResetHintsTitle => 'Resetați indiciile din aplicație';

  @override
  String get settingsSpeechSubtitle => 'Voce și citire cu voce tare';

  @override
  String get settingsSpeechTitle => 'Vorbire';

  @override
  String get settingsSyncConflictsSubtitle =>
      'Rezolvați conflictele de sincronizare pentru a asigura consistența datelor';

  @override
  String get settingsSyncNodeProfileCapabilitiesEmpty =>
      'Niciuna detectată — declanșarea automată a inferenței audio sincronizate nu va viza acest dispozitiv.';

  @override
  String get settingsSyncNodeProfileCapabilitiesLabel =>
      'Capabilități AI detectate';

  @override
  String get settingsSyncNodeProfileCapabilityMlxAudio => 'MLX Audio (local)';

  @override
  String get settingsSyncNodeProfileCapabilityOllamaLlm => 'Ollama LLM';

  @override
  String get settingsSyncNodeProfileCapabilityOmlxLlm => 'oMLX LLM';

  @override
  String get settingsSyncNodeProfileCapabilityVoxtral => 'Voxtral (local)';

  @override
  String get settingsSyncNodeProfileCapabilityWhisper => 'Whisper (local)';

  @override
  String get settingsSyncNodeProfileDisplayNameHelper =>
      'Vizibil pentru celelalte dispozitive ale dvs. când alegeți la care să fixați un profil.';

  @override
  String get settingsSyncNodeProfileDisplayNameLabel =>
      'Numele afișat al dispozitivului';

  @override
  String get settingsSyncNodeProfileKnownNodesEmpty =>
      'Niciun alt dispozitiv nu a publicat încă un profil.';

  @override
  String get settingsSyncNodeProfileKnownNodesTitle =>
      'Dispozitive de sincronizare cunoscute';

  @override
  String get settingsSyncNodeProfileSaveButton => 'Salvați';

  @override
  String get settingsSyncNodeProfileSubtitle =>
      'Denumiți acest dispozitiv și examinați capabilitățile vizibile pentru celelalte dispozitive.';

  @override
  String get settingsSyncNodeProfileTitle => 'Acest dispozitiv';

  @override
  String get settingsSyncOutboxTitle => 'Coadă de ieșire pentru sincronizare';

  @override
  String get settingsSyncStatsSubtitle =>
      'Inspectează metricile canalului de sincronizare';

  @override
  String get settingsSyncSubtitle =>
      'Configurați sincronizarea și vizualizați statisticile';

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
      'Vedeți cele mai recente actualizări și funcționalități';

  @override
  String get settingsWhatsNewTitle => 'Ce este nou';

  @override
  String get settingThemingDark => 'Temă întunecată';

  @override
  String get settingThemingLight => 'Temă luminoasă';

  @override
  String get sidebarActiveSectionTitle => 'Activitate';

  @override
  String get sidebarActivityCollapseTooltip => 'Restrângeți activitatea';

  @override
  String get sidebarActivityExpandTooltip => 'Extindeți activitatea';

  @override
  String get sidebarAudioRecordingStatusLabel => 'Înregistrare';

  @override
  String get sidebarRunningTimerLabel => 'Cronometru în execuție';

  @override
  String get sidebarRunningTimerStopTooltip => 'Opriți cronometrul';

  @override
  String get sidebarTimerStatusLabel => 'Cronometru';

  @override
  String get sidebarToggleCollapseLabel => 'Restrânge bara laterală';

  @override
  String get sidebarToggleExpandLabel => 'Extinde bara laterală';

  @override
  String sidebarWakesActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activi',
      few: '$count activi',
      one: '1 activ',
    );
    return '$_temp0';
  }

  @override
  String get sidebarWakesCancelTooltip => 'Anulați agentul';

  @override
  String get sidebarWakesHeader => 'Agenți';

  @override
  String get sidebarWakesNow => 'acum';

  @override
  String get sidebarWakesOpenList => 'Deschideți lista';

  @override
  String get sidebarWakesOpenTask => 'Deschideți sarcina';

  @override
  String sidebarWakesQueuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count în coadă',
      few: '$count în coadă',
      one: '1 în coadă',
    );
    return '$_temp0';
  }

  @override
  String get sidebarWakesQueuedLabel => 'În coadă';

  @override
  String get sidebarWakesWorkingLabel => 'Lucrează';

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
  String get speechSettingsModelDescription => 'Model de voce pe dispozitiv';

  @override
  String get speechSettingsModelDownloadsOnce => 'Se descarcă o singură dată';

  @override
  String get speechSettingsModelLabel => 'Model';

  @override
  String get speechSettingsRecommendedBadge => 'Recomandat';

  @override
  String get speechSettingsSpeedDescription =>
      'Cât de repede sunt citite rezumatele';

  @override
  String get speechSettingsSpeedLabel => 'Viteza de citire';

  @override
  String get speechSettingsVoiceDescription =>
      'Alegeți vocea care citește rezumatele cu voce tare';

  @override
  String get speechSettingsVoiceLabel => 'Voce';

  @override
  String get speechVoiceGenderFemale => 'Feminină';

  @override
  String get speechVoiceGenderMale => 'Masculină';

  @override
  String get speechVoicePreviewTooltip => 'Ascultați vocea';

  @override
  String get surveyBackButton => 'Înapoi';

  @override
  String get surveyCancelConfirmation => 'Anulați chestionarul?';

  @override
  String get surveyChooseOneOption => 'Alegeți o opțiune';

  @override
  String get surveyChooseOneOrMoreOptions =>
      'Alegeți una sau mai multe opțiuni';

  @override
  String get surveyDiscardConfirmation => 'Renunțați la rezultate și ieșiți?';

  @override
  String get surveyInputNumberValidation => 'Introduceți un număr';

  @override
  String get surveyNextButton => 'Înainte';

  @override
  String get surveyNoButton => 'Nu';

  @override
  String get surveyProgressOf => 'din';

  @override
  String get surveyTapToAnswer => 'Atingeți pentru a răspunde';

  @override
  String get surveyValueAnd => 'și';

  @override
  String get surveyValueBetween => 'Trebuie să fie între';

  @override
  String get surveyYesButton => 'Da';

  @override
  String get syncActivityIdle => 'inactivă';

  @override
  String get syncActivityInboxLabel => 'Intrare';

  @override
  String syncActivityIndicatorSemantics(int outbox, int inbox) {
    return 'Activitate sincronizare. Coadă de ieșire: $outbox. Coadă de intrare: $inbox. Deschide coada de ieșire pentru sincronizare.';
  }

  @override
  String get syncActivityOutboxLabel => 'Ieșire';

  @override
  String get syncActivitySyncingTitle => 'Se sincronizează';

  @override
  String get syncActivityTitle => 'Sincronizare';

  @override
  String get syncDeleteConfigConfirm => 'DA, SUNT SIGUR';

  @override
  String get syncDeleteConfigQuestion =>
      'Doriți să ștergeți configurația de sincronizare?';

  @override
  String get syncEntitiesConfirm => 'ÎNCEPE SINCRONIZAREA';

  @override
  String get syncEntitiesMessage =>
      'Alegeți datele pe care doriți să le sincronizați.';

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
  String get syncPayloadConfigFlag => 'Indicator de configurare';

  @override
  String get syncPayloadConsumptionEvent => 'Consum AI';

  @override
  String get syncPayloadDailyOsUserName => 'Nume Daily OS';

  @override
  String get syncPayloadEntityDefinition => 'Definiție entitate';

  @override
  String get syncPayloadEntryLink => 'Link intrare';

  @override
  String get syncPayloadJournalEntity => 'Intrare jurnal';

  @override
  String get syncPayloadNotification => 'Notificare';

  @override
  String get syncPayloadNotificationStateUpdate =>
      'Actualizare stare notificare';

  @override
  String get syncPayloadOutboxBundle => 'Pachet din căsuța de trimitere';

  @override
  String get syncPayloadSavedTaskFilter => 'Filtru de sarcini salvat';

  @override
  String get syncPayloadSavedTaskFilterDelete =>
      'Ștergere filtru de sarcini salvat';

  @override
  String get syncPayloadSyncNodeProfile => 'Profilul nodului de sincronizare';

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
  String get syncStepSavedTaskFilters => 'Filtre de sarcini salvate';

  @override
  String get taskActionBarAudioRecordingActive =>
      'Înregistrare audio în desfășurare';

  @override
  String get taskActionBarMoreActions => 'Mai multe acțiuni';

  @override
  String get taskActionBarOpenRunningTimer => 'Deschideți cronometrul activ';

  @override
  String get taskActionBarStopTracking => 'Opriți cronometrul';

  @override
  String get taskActionBarTrackTime => 'Înregistrați timpul';

  @override
  String get taskAgentAttributionUnavailable =>
      'Atribuirea nu este disponibilă';

  @override
  String get taskAgentAutomaticUpdatesLabel => 'Actualizări automate';

  @override
  String get taskAgentAutomaticUpdatesNeedsSetup =>
      'Alegeți o configurare AI înainte de a activa actualizările automate.';

  @override
  String get taskAgentCancelTimerTooltip =>
      'Anulați actualizarea automată în așteptare';

  @override
  String get taskAgentChooseModel => 'Alegeți un model de raționament';

  @override
  String get taskAgentChooseProfile => 'Alegeți un profil de inferență';

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
  String get taskAgentCurrentSetupHeader => 'Configurarea curentă';

  @override
  String get taskAgentCurrentSetupLabel => 'Configurarea curentă';

  @override
  String get taskAgentDirectModelOverride => 'Înlocuire directă a modelului';

  @override
  String get taskAgentDisableConfirmAction => 'Dezactivați';

  @override
  String get taskAgentDisableConfirmBody =>
      'Raportul curent rămâne vizibil, dar agentul nu poate rula până când alegeți o configurare.';

  @override
  String get taskAgentDisableConfirmTitle =>
      'Dezactivați AI pentru acest agent?';

  @override
  String get taskAgentInferenceProfileLabel => 'Profil de inferență';

  @override
  String get taskAgentModelPickerTitle => 'Alegeți modelul de raționament';

  @override
  String taskAgentNextUpdateIn(String countdown) {
    return 'Următoarea actualizare în $countdown';
  }

  @override
  String get taskAgentNoAiSetup => 'Fără configurare AI';

  @override
  String get taskAgentNoAiSetupDescription =>
      'Opriți inferența până când alegeți un profil sau un model.';

  @override
  String get taskAgentNoModelsAvailable =>
      'Nu există modele de raționament compatibile';

  @override
  String get taskAgentNoProfilesAvailable =>
      'Nu există profiluri disponibile pe acest dispozitiv';

  @override
  String get taskAgentNoProfileSelected => 'Nicio configurare AI';

  @override
  String get taskAgentNoProfileSelectedDescription =>
      'Alegeți o configurare salvată sau un model înainte ca agentul să poată rula.';

  @override
  String taskAgentProfileChangedToast(String profile) {
    return '$profile va fi utilizat pentru toate actualizările viitoare ale agentului până când îl schimbați.';
  }

  @override
  String get taskAgentProfileDefaultBadge => 'Modelul implicit al profilului';

  @override
  String get taskAgentReportOutdatedTitle => 'Acest rezumat nu mai este actual';

  @override
  String get taskAgentReportUpToDate => 'Rezumatul este actualizat';

  @override
  String get taskAgentRouteVia => 'prin';

  @override
  String get taskAgentRunNowTooltip => 'Rulează acum';

  @override
  String get taskAgentSavingSetup => 'Se salvează configurarea agentului';

  @override
  String taskAgentSetupAndReportSemantics(String identity) {
    return 'Acest raport și configurarea curentă folosesc $identity. Activați pentru a modifica configurarea.';
  }

  @override
  String get taskAgentSetupBroken =>
      'Configurarea AI selectată nu este disponibilă';

  @override
  String taskAgentSetupChangedToast(String model) {
    return '$model va fi folosit pentru toate actualizările viitoare până când îl schimbați.';
  }

  @override
  String get taskAgentSetupChoiceHelp =>
      'Alegeți un profil pentru valorile implicite sau înlocuiți doar modelul de raționament.';

  @override
  String get taskAgentSetupOriginCategory =>
      'Copiată din configurarea implicită a categoriei la crearea agentului';

  @override
  String get taskAgentSetupOriginDisabled => 'Dezactivată';

  @override
  String get taskAgentSetupOriginLegacy => 'Configurare veche';

  @override
  String get taskAgentSetupOriginTemplate => 'Copiată din șablon';

  @override
  String get taskAgentSetupOriginUser =>
      'Ați ales această configurare pentru acest agent';

  @override
  String get taskAgentSetupPersistenceDescription =>
      'Modificările se aplică tuturor actualizărilor viitoare până când le schimbați din nou.';

  @override
  String taskAgentSetupSemantics(String identity) {
    return 'Configurarea curentă: $identity. Activați pentru a o modifica.';
  }

  @override
  String get taskAgentSetupTitle => 'Configurarea agentului';

  @override
  String get taskAgentThinkingModelLabel => 'Model de raționament';

  @override
  String get taskAgentThisReportHeader => 'Acest raport';

  @override
  String get taskAgentTurnOffSetup => 'Dezactivați AI pentru acest agent';

  @override
  String get taskAgentUseCategoryDefault =>
      'Copiați configurarea implicită a categoriei';

  @override
  String get taskAgentUseCategoryDefaultDescription =>
      'Copiați configurarea curentă a categoriei. Modificările ulterioare ale categoriei nu vor afecta acest agent.';

  @override
  String get taskAgentUseProfileDefault =>
      'Folosiți modelul implicit al profilului';

  @override
  String get taskAgentWakeAgent => 'Treziți agentul';

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
  String get taskEstimateModalTitle => 'Timp estimat';

  @override
  String taskEstimateProgressLabel(String tracked, String estimate) {
    return '$tracked din $estimate';
  }

  @override
  String taskEstimateTooltip(String tracked, String estimate) {
    return 'Timp înregistrat: $tracked din $estimate estimat';
  }

  @override
  String taskLabelsMoreCount(int count) {
    return '+$count';
  }

  @override
  String get taskLabelsShowFewer => 'Afișați mai puține';

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
  String get taskLanguageLabel => 'Limbă';

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
  String get taskPriorityHigh => 'Ridicată';

  @override
  String get taskPriorityLow => 'Scăzută';

  @override
  String get taskPriorityMedium => 'Medie';

  @override
  String get taskPriorityUrgent => 'Urgentă';

  @override
  String get tasksAddLabelButton => 'Adăugați o etichetă';

  @override
  String get tasksAgentFilterAll => 'Toate';

  @override
  String get tasksAgentFilterHasAgent => 'Cu agent';

  @override
  String get tasksAgentFilterNoAgent => 'Fără agent';

  @override
  String get tasksAgentFilterTitle => 'Agent';

  @override
  String get tasksFilterApplyTitle => 'Aplicați filtrul';

  @override
  String get tasksFilterClearAll => 'Ștergeți tot';

  @override
  String get tasksFilterTitle => 'Filtrați sarcinile';

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
  String get tasksLabelsDialogClose => 'Închideți';

  @override
  String get tasksLabelsSheetApply => 'Aplicați';

  @override
  String get tasksLabelsSheetSearchHint => 'Căutați etichete…';

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
  String get tasksPriorityPickerTitle => 'Selectați prioritatea';

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
  String get tasksSavedFiltersAllShort => 'Toate';

  @override
  String get tasksSavedFiltersAllTasks => 'Toate sarcinile';

  @override
  String get tasksSavedFiltersCustom => 'Personalizat';

  @override
  String get tasksSavedFiltersDeleteConfirmAction => 'Ștergeți';

  @override
  String tasksSavedFiltersDeleteConfirmMessage(String name) {
    return 'Ștergeți filtrul salvat „$name”? Această acțiune nu poate fi anulată.';
  }

  @override
  String tasksSavedFiltersDeleteConfirmNamed(String name) {
    return 'Confirmați ștergerea $name';
  }

  @override
  String tasksSavedFiltersDeleteNamed(String name) {
    return 'Ștergeți $name';
  }

  @override
  String get tasksSavedFiltersDone => 'Gata';

  @override
  String get tasksSavedFiltersEdit => 'Editați';

  @override
  String get tasksSavedFiltersFilterNameLabel => 'Numele filtrului';

  @override
  String get tasksSavedFiltersGroupSemantics => 'Filtre de sarcini';

  @override
  String get tasksSavedFiltersManageTooltip => 'Gestionați filtrele de sarcini';

  @override
  String get tasksSavedFiltersRailButton => 'Filtre';

  @override
  String tasksSavedFiltersRenameNamed(String name) {
    return 'Redenumiți $name';
  }

  @override
  String get tasksSavedFiltersReorderHelper =>
      'Trageți pentru a stabili ordinea. Primele cinci filtre apar în bara laterală.';

  @override
  String get tasksSavedFiltersSaveAsNewButtonLabel => 'Salvați ca filtru nou…';

  @override
  String get tasksSavedFiltersSaveAsNewDescription =>
      'Păstrați filtrul existent neschimbat și creați unul separat.';

  @override
  String get tasksSavedFiltersSaveAsNewTitle => 'Salvați ca filtru nou';

  @override
  String get tasksSavedFiltersSaveButtonLabel => 'Salvați filtrul…';

  @override
  String get tasksSavedFiltersSaveChoiceIntro =>
      'Alegeți dacă actualizați filtrul salvat sau creați unul separat.';

  @override
  String get tasksSavedFiltersSaveChoiceTitle => 'Salvați filtrul';

  @override
  String get tasksSavedFiltersSaveCurrentAs => 'Salvați filtrul curent ca…';

  @override
  String get tasksSavedFiltersSaveError =>
      'Filtrul nu a putut fi salvat. Încercați din nou.';

  @override
  String get tasksSavedFiltersSavePageHelper =>
      'Dați filtrului un nume scurt. Îl puteți reordona ulterior în Filtre de sarcini.';

  @override
  String get tasksSavedFiltersSavePopupCancel => 'Anulați';

  @override
  String get tasksSavedFiltersSavePopupHint => 'ex.: Blocate sau în așteptare';

  @override
  String get tasksSavedFiltersSavePopupSave => 'Salvați';

  @override
  String get tasksSavedFiltersSavePopupTitle => 'Denumiți acest filtru';

  @override
  String get tasksSavedFiltersSheetTitle => 'Filtre de sarcini';

  @override
  String get tasksSavedFiltersShowLess => 'Afișați mai puțin';

  @override
  String tasksSavedFiltersShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'încă $count de filtre salvate',
      few: 'încă $count filtre salvate',
      one: 'încă 1 filtru salvat',
    );
    return '$_temp0';
  }

  @override
  String tasksSavedFiltersTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de sarcini',
      few: '$count sarcini',
      one: '1 sarcină',
    );
    return '$_temp0';
  }

  @override
  String get tasksSavedFiltersUpdateButtonLabel => 'Actualizați filtrul';

  @override
  String get tasksSavedFiltersUpdateExistingDescription =>
      'Înlocuiți criteriile salvate cu configurația curentă a filtrului.';

  @override
  String get tasksSavedFiltersUpdateExistingTitle =>
      'Actualizați filtrul existent';

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
  String get tasksShowCreationDate => 'Afișați data creării pe carduri';

  @override
  String get tasksShowDueDate => 'Afișați data scadenței pe carduri';

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
  String get thinkingDisclosureCopy => 'Copiați raționamentul';

  @override
  String get thinkingDisclosureHide => 'Ascundeți raționamentul';

  @override
  String get thinkingDisclosureShow => 'Afișați raționamentul';

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
      'Sigur doriți să deconectați această sarcină?';

  @override
  String get unlinkTaskTitle => 'Deconectați sarcina';

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
  String get whatsNewBadgeNew => 'NOU';

  @override
  String get whatsNewDoneButton => 'Gata';

  @override
  String get whatsNewSkipButton => 'Omite';
}

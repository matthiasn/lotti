// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Danish (`da`).
class AppLocalizationsDa extends AppLocalizations {
  AppLocalizationsDa([String locale = 'da']) : super(locale);

  @override
  String get activeLabel => 'Aktiv';

  @override
  String get addActionAddAudioRecording => 'Lydoptagelse';

  @override
  String get addActionAddChecklist => 'Tjekliste';

  @override
  String get addActionAddEvent => 'Begivenhed';

  @override
  String get addActionAddImageFromClipboard => 'Indsæt billede';

  @override
  String get addActionAddScreenshot => 'Skærmbillede';

  @override
  String get addActionAddTask => 'Opgave';

  @override
  String get addActionAddText => 'Tekstindtastning';

  @override
  String get addActionAddTimer => 'Åbningstider';

  @override
  String get addActionAddTimeRecording => 'Timerindtastning';

  @override
  String get addActionImportImage => 'Importbillede';

  @override
  String get addHabitCommentLabel => 'Kommentar';

  @override
  String get addHabitDateLabel => 'Færdiggjort i';

  @override
  String get addLinkedEntryLabel => 'Add linked entry';

  @override
  String get addMeasurementCommentLabel => 'Kommentar';

  @override
  String get addMeasurementDateLabel => 'Observeret ved';

  @override
  String get addMeasurementSaveButton => 'Gem';

  @override
  String get addToDictionary => 'Tilføj til ordbog';

  @override
  String get addToDictionaryDuplicate => 'Udtrykket findes allerede i ordbogen';

  @override
  String get addToDictionaryNoCategory =>
      'Kan ikke tilføje til ordbog: opgaven har ingen kategori';

  @override
  String get addToDictionarySaveFailed => 'Kunne ikke gemme ordbogen';

  @override
  String get addToDictionarySuccess => 'Udtryk tilføjet til ordbog';

  @override
  String get addToDictionaryTooLong => 'Perioden er for lang (maks 50 tegn)';

  @override
  String agentABComparisonChoose(String option) {
    return 'Vælg $option';
  }

  @override
  String agentABComparisonOption(String option) {
    return 'Mulighed $option';
  }

  @override
  String agentABComparisonPrefer(String option) {
    return 'Jeg foretrækker Option $option';
  }

  @override
  String get agentBinaryChoiceNo => 'Nej';

  @override
  String get agentBinaryChoiceYes => 'Ja';

  @override
  String get agentCategoryRatingsScaleMax => 'Fix først';

  @override
  String get agentCategoryRatingsScaleMin => 'Lad det ligge';

  @override
  String agentCategoryRatingsStarLabel(int starIndex, int totalStars) {
    return '$starIndex af $totalStars-stjerner';
  }

  @override
  String get agentCategoryRatingsSubmit => 'Brug disse prioriteter';

  @override
  String get agentCategoryRatingsSubtitle =>
      'Hvor vigtigt er det, at jeg retter hver af disse? 1 betyder lad det være, 5 betyder fix det først.';

  @override
  String get agentCategoryRatingsTitle => 'Hjælp mig med at prioritere';

  @override
  String agentControlsActionError(String error) {
    return 'Handling mislykkedes: $error';
  }

  @override
  String get agentControlsDeleteButton => 'Slet permanent';

  @override
  String get agentControlsDeleteDialogContent =>
      'Dette vil permanent slette alle data for denne agent, inklusive dens historik, rapporter og observationer. Det kan ikke gøres om.';

  @override
  String get agentControlsDeleteDialogTitle => 'Slette agent?';

  @override
  String get agentControlsDestroyButton => 'Ødelæg';

  @override
  String get agentControlsDestroyDialogContent =>
      'Dette vil permanent deaktivere agenten. Dens historie vil blive bevaret til revision.';

  @override
  String get agentControlsDestroyDialogTitle => 'Ødelægge Agent?';

  @override
  String get agentControlsDestroyedMessage => 'Dette stof er blevet ødelagt.';

  @override
  String get agentControlsPauseButton => 'Pause';

  @override
  String get agentControlsReanalyzeButton => 'Gen-analyser';

  @override
  String get agentControlsResumeButton => 'CV';

  @override
  String get agentConversationEmpty => 'Ingen samtaler endnu.';

  @override
  String agentConversationThreadSummary(
    int messageCount,
    int toolCallCount,
    String shortId,
  ) {
    return '$messageCount beskeder, $toolCallCount værktøjskald · $shortId';
  }

  @override
  String agentConversationTokenCount(String tokenCount) {
    return '$tokenCount tokens';
  }

  @override
  String get agentDefaultProfileLabel => 'Standard inferensprofil';

  @override
  String agentDetailErrorLoading(String error) {
    return 'Fejlindlæsningsagent: $error';
  }

  @override
  String get agentDetailNotFound => 'Agent ikke fundet.';

  @override
  String get agentDetailUnexpectedType => 'Uventet entitetstype.';

  @override
  String get agentEvolutionApprovalRate => 'Godkendelsesrate';

  @override
  String get agentEvolutionChartMttrTrend => 'MTTR-trend';

  @override
  String get agentEvolutionChartSuccessRateTrend => 'Succestendens';

  @override
  String get agentEvolutionChartVersionPerformance => 'Efter version';

  @override
  String get agentEvolutionChartWakeHistory => 'Wake-historie';

  @override
  String get agentEvolutionChatPlaceholder =>
      'Del feedback eller spørg om præstation...';

  @override
  String get agentEvolutionCurrentDirectives => 'Nuværende direktiver';

  @override
  String get agentEvolutionDashboardTitle => 'Ydeevne';

  @override
  String get agentEvolutionHistoryTitle => 'Evolutionshistorie';

  @override
  String get agentEvolutionMetricActive => 'Aktiv';

  @override
  String get agentEvolutionMetricAvgDuration => 'Gennemsnitlig varighed';

  @override
  String get agentEvolutionMetricFailures => 'Fejl';

  @override
  String get agentEvolutionMetricSuccess => 'Succes';

  @override
  String get agentEvolutionMetricWakes => 'Våger';

  @override
  String get agentEvolutionNoSessions => 'Ingen evolutionssessioner endnu';

  @override
  String get agentEvolutionNoteRecorded => 'Note Optaget';

  @override
  String get agentEvolutionProposalApprovalFailed =>
      'Godkendelsen mislykkedes — prøv venligst igen';

  @override
  String get agentEvolutionProposalRationale => 'Begrundelse';

  @override
  String get agentEvolutionProposalRejected =>
      'Forslag afvist — fortsæt samtalen';

  @override
  String get agentEvolutionProposalTitle => 'Foreslåede ændringer';

  @override
  String get agentEvolutionProposedDirectives => 'Foreslåede direktiver';

  @override
  String get agentEvolutionSessionAbandoned =>
      'Sessionen sluttede uden ændringer';

  @override
  String agentEvolutionSessionCompleted(int version) {
    return 'Session afsluttet — version $version oprettet';
  }

  @override
  String get agentEvolutionSessionCount => 'Sessioner';

  @override
  String get agentEvolutionSessionError => 'Ikke startet evolutionssessionen';

  @override
  String agentEvolutionSessionProgress(int sessionNumber, int totalSessions) {
    return 'Session $sessionNumber af $totalSessions';
  }

  @override
  String get agentEvolutionSessionStarting => 'Starter evolutionssession...';

  @override
  String agentEvolutionSessionTitle(int sessionNumber) {
    return 'Evolution #$sessionNumber';
  }

  @override
  String agentEvolutionSoulCurrentField(String field) {
    return 'Nuværende — $field';
  }

  @override
  String agentEvolutionSoulProposedField(String field) {
    return 'Foreslået — $field';
  }

  @override
  String get agentEvolutionStatusAbandoned => 'Forladt';

  @override
  String get agentEvolutionStatusActive => 'Aktiv';

  @override
  String get agentEvolutionStatusCompleted => 'Færdiggjort';

  @override
  String get agentEvolutionTimelineFeedbackLabel => 'Feedback';

  @override
  String get agentEvolutionVersionProposed => 'Foreslået version';

  @override
  String get agentFeedbackCategoryAccuracy => 'Nøjagtighed';

  @override
  String get agentFeedbackCategoryBreakdownTitle => 'Kategoriopdeling';

  @override
  String get agentFeedbackCategoryCommunication => 'Kommunikation';

  @override
  String get agentFeedbackCategoryGeneral => 'Generel';

  @override
  String get agentFeedbackCategoryPrioritization => 'Prioritering';

  @override
  String get agentFeedbackCategoryTimeliness => 'Aktualitet';

  @override
  String get agentFeedbackCategoryTooling => 'Værktøj';

  @override
  String get agentFeedbackClassificationTitle => 'Feedback-klassifikation';

  @override
  String get agentFeedbackExcellenceTitle => 'Noter om fremragende kvalitet';

  @override
  String get agentFeedbackGrievancesTitle => 'Klager';

  @override
  String get agentFeedbackHighPriorityTitle => 'Feedback med høj prioritet';

  @override
  String agentFeedbackItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count genstande',
      one: '1 genstand',
    );
    return '$_temp0';
  }

  @override
  String get agentFeedbackSourceDecision => 'Afgørelse';

  @override
  String get agentFeedbackSourceMetric => 'Metrik';

  @override
  String get agentFeedbackSourceObservation => 'Observation';

  @override
  String get agentFeedbackSourceRating => 'Vurdering';

  @override
  String get agentInstancesEmptyFiltered =>
      'Ingen instanser matcher dine filtre.';

  @override
  String get agentInstancesFilterClearAll => 'Ryd alt';

  @override
  String get agentInstancesFilterClearSection => 'Klart';

  @override
  String get agentInstancesFilterSectionSoul => 'Sjæl';

  @override
  String get agentInstancesFilterSectionStatus => 'Status';

  @override
  String get agentInstancesFilterSectionType => 'Type';

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
  String get agentInstancesGroupBySoul => 'Sjæl';

  @override
  String get agentInstancesGroupByStatus => 'Status';

  @override
  String get agentInstancesGroupByType => 'Type';

  @override
  String get agentInstancesKindEvolution => 'Udvikling';

  @override
  String get agentInstancesKindTaskAgent => 'Task Agent';

  @override
  String get agentInstancesPageTitle => 'Agentinstanser';

  @override
  String agentInstancesResultCountAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instanser',
      one: '1 instans',
    );
    return '$_temp0';
  }

  @override
  String agentInstancesResultCountFiltered(int filtered, int total) {
    return '$filtered af $total';
  }

  @override
  String get agentInstancesSearchClear => 'Ryd søgning';

  @override
  String get agentInstancesSearchPlaceholder => 'Søg instanser...';

  @override
  String get agentInstancesSortName => 'Navn';

  @override
  String get agentInstancesSortOldest => 'Ældste';

  @override
  String get agentInstancesSortRecent => 'Nyligt';

  @override
  String get agentInstancesTitle => 'Forekomster';

  @override
  String get agentInstancesToolbarFilters => 'Filtre';

  @override
  String get agentInstancesToolbarGroupBy => 'Grupper efter';

  @override
  String get agentInstancesUnassignedSoul => 'Ikke tildelt';

  @override
  String get agentLifecycleActive => 'Aktiv';

  @override
  String get agentLifecycleCreated => 'Oprettet';

  @override
  String get agentLifecycleDestroyed => 'Ødelagt';

  @override
  String get agentLifecycleDormant => 'Hvilende';

  @override
  String get agentMessageKindAction => 'Aktion';

  @override
  String get agentMessageKindMilestone => 'Milepæl';

  @override
  String get agentMessageKindObservation => 'Observation';

  @override
  String get agentMessageKindRetraction => 'Tilbagetrækning';

  @override
  String get agentMessageKindSummary => 'Resumé';

  @override
  String get agentMessageKindSystem => 'System';

  @override
  String get agentMessageKindSystemPrompt => 'Systemprompt';

  @override
  String get agentMessageKindThought => 'Tanker';

  @override
  String get agentMessageKindToolResult => 'Værktøjsresultat';

  @override
  String get agentMessageKindUser => 'Bruger';

  @override
  String get agentMessagePayloadEmpty => '(intet indhold)';

  @override
  String get agentMessagesEmpty => 'Ingen beskeder endnu.';

  @override
  String agentMessagesErrorLoading(String error) {
    return 'Beskeder kunne ikke indlæses: $error';
  }

  @override
  String get agentObservationsEmpty =>
      'Ingen observationer er registreret endnu.';

  @override
  String agentPendingWakesActivityHourDetail(
    String hour,
    int count,
    String reasons,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wakes',
      one: '1 wake',
    );
    return '$hour: $_temp0 ($reasons)';
  }

  @override
  String agentPendingWakesActivityHourDetailEmpty(String hour, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wakes',
      one: '1 wake',
    );
    return '$hour · $_temp0';
  }

  @override
  String get agentPendingWakesActivityTitle => 'Vågeaktivitet (24 timer)';

  @override
  String agentPendingWakesActivityTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samlede våger',
      one: '1 samlet våge',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesDeleteTooltip => 'Fjern bølgen';

  @override
  String get agentPendingWakesEmptyFiltered =>
      'Ingen bølger matcher dine filtre.';

  @override
  String get agentPendingWakesFilterSectionType => 'Type';

  @override
  String get agentPendingWakesGroupByType => 'Type';

  @override
  String get agentPendingWakesPendingLabel => 'Afventer';

  @override
  String agentPendingWakesRunningHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kører nu ($count)',
      one: 'Kører nu',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesScheduledLabel => 'Planlagt';

  @override
  String get agentPendingWakesSearchPlaceholder => 'Søgevågen...';

  @override
  String get agentPendingWakesSortDueLatest => 'Forventes senest';

  @override
  String get agentPendingWakesSortDueSoonest => 'Aflevering hurtigst muligt';

  @override
  String get agentPendingWakesTitle => 'Vågencyklusser';

  @override
  String get agentReportHistoryBadge => 'Rapport';

  @override
  String get agentReportHistoryEmpty => 'Ingen rapportsnapshots endnu.';

  @override
  String get agentReportHistoryError =>
      'Der opstod en fejl under indlæsning af rapporthistorikken.';

  @override
  String get agentReportNone => 'Ingen rapport tilgængelig endnu.';

  @override
  String get agentRitualReviewAction => 'Start samtale';

  @override
  String get agentRitualReviewNegativeSignals => 'Negativ';

  @override
  String get agentRitualReviewNeutralSignals => 'Neutral';

  @override
  String get agentRitualReviewNoFeedback =>
      'Ingen feedbacksignaler i dette vindue';

  @override
  String get agentRitualReviewNoNegativeSignals =>
      'Ingen negative feedbacksignaler i denne fane';

  @override
  String get agentRitualReviewNoNeutralSignals =>
      'Ingen neutrale feedbacksignaler i denne fane';

  @override
  String get agentRitualReviewNoPositiveSignals =>
      'Ingen positive feedbacksignaler i denne fane';

  @override
  String get agentRitualReviewPositiveSignals => 'Positiv';

  @override
  String get agentRitualReviewProposalSection => 'Nuværende forslag';

  @override
  String get agentRitualReviewSessionHistory => 'Sessionens historie';

  @override
  String get agentRitualReviewTitle => '1-mod-1';

  @override
  String get agentRitualSummaryApprovedChangesHeading => 'Godkendte ændringer';

  @override
  String get agentRitualSummaryConversationHeading => 'Samtale';

  @override
  String get agentRitualSummaryRecapHeading => 'Sessionsresumé';

  @override
  String get agentRitualSummaryRoleAssistant => 'Agent';

  @override
  String get agentRitualSummaryRoleUser => 'Du';

  @override
  String get agentRitualSummaryStartHint =>
      'Start et en-til-en møde for at gennemgå, hvad der generede dig, hvad der virkede, og hvad der bør ændres næste gang.';

  @override
  String get agentRitualSummarySubtitle =>
      'Nylige 1-til-1-møder, rigtig vågeaktivitet og de ændringer, du har accepteret.';

  @override
  String get agentRitualSummaryTokensSinceLast => 'Tokens siden sidste 1-mod-1';

  @override
  String get agentRitualSummaryWakeHistory30Days =>
      'Vågen aktivitet (de sidste 30 dage)';

  @override
  String get agentRitualSummaryWakesSinceLast => 'Våger siden sidste 1-til-1';

  @override
  String get agentRunningIndicator => 'Løb';

  @override
  String get agentSessionProgressTitle => 'Sessionens fremskridt';

  @override
  String get agentSettingsSubtitle => 'Skabeloner, instanser og overvågning';

  @override
  String get agentSettingsTitle => 'Agenter';

  @override
  String get agentSoulAntiSycophancyLabel => 'Anti-smiskerpolitik';

  @override
  String get agentSoulAssignedTemplatesTitle => 'Tildelte skabeloner';

  @override
  String get agentSoulAssignmentLabel => 'Sjæl';

  @override
  String get agentSoulCoachingStyleLabel => 'Trænerstil';

  @override
  String get agentSoulCreatedSuccess => 'Sjæl skabt';

  @override
  String get agentSoulCreateTitle => 'Skab Sjæl';

  @override
  String get agentSoulDeleteConfirmBody =>
      'Dette vil fjerne sjælen og alle dens versioner.';

  @override
  String get agentSoulDeleteConfirmTitle => 'Slet Soul';

  @override
  String get agentSoulDetailTitle => 'Sjæledetalje';

  @override
  String get agentSoulDisplayNameLabel => 'Navn';

  @override
  String get agentSoulEvolutionHistoryTitle => 'Sjælens evolutionshistorie';

  @override
  String get agentSoulEvolutionNoSessions =>
      'Ingen sessioner om sjæleudvikling endnu';

  @override
  String get agentSoulFieldAntiSycophancy => 'Anti-smiskeri';

  @override
  String get agentSoulFieldCoachingStyle => 'Trænerstil';

  @override
  String get agentSoulFieldToneBounds => 'Tonegrænser';

  @override
  String get agentSoulFieldVoice => 'Stemme';

  @override
  String get agentSoulInfoTab => 'Info';

  @override
  String get agentSoulNoneAssigned => 'Ingen sjæl tildelt';

  @override
  String get agentSoulNotFound => 'Sjæl ikke fundet';

  @override
  String get agentSoulProposalSubtitle => 'Foreslåede personlighedsændringer';

  @override
  String get agentSoulProposalTitle => 'Forslag om sjælepersonlighed';

  @override
  String get agentSoulReviewHeroSubtitle =>
      'Forfine personligheden på tværs af alle skabeloner, der deler denne sjæl. Evolutionsagenten ser feedback fra hver skabelon, der bruger denne personlighed.';

  @override
  String get agentSoulReviewStartAction => 'Start Personlighedsgennemgang';

  @override
  String get agentSoulReviewStartHint =>
      'Start en personlighedsfokuseret session for at gennemgå feedback og udvikle stemme, tone, coachingstil og direktehed.';

  @override
  String agentSoulReviewTemplateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skabeloner, der deler denne sjæl',
      one: '1 skabelon, der deler denne sjæl',
    );
    return '$_temp0';
  }

  @override
  String get agentSoulReviewTitle => 'Sjæl 1-mod-1';

  @override
  String get agentSoulRollbackAction => 'Rul tilbage til denne version';

  @override
  String agentSoulRollbackConfirm(int version) {
    return 'Skal vi rulle tilbage til version $version? Alle skabeloner, der bruger denne sjæl, vil opfange ændringen.';
  }

  @override
  String get agentSoulSelectTitle => 'Vælg sjæl';

  @override
  String get agentSoulsEmptyFiltered => 'Ingen sjæle matcher dine filtre.';

  @override
  String get agentSoulSettingsTab => 'Indstillinger';

  @override
  String get agentSoulsSearchPlaceholder => 'Søg sjæle...';

  @override
  String get agentSoulsTitle => 'Sjæle';

  @override
  String get agentSoulToneBoundsLabel => 'Tonegrænser';

  @override
  String get agentSoulVersionHistoryTitle => 'Versionshistorik';

  @override
  String agentSoulVersionLabel(int version) {
    return 'Version $version';
  }

  @override
  String get agentSoulVersionSaved => 'Ny soul-version reddet';

  @override
  String get agentSoulVoiceDirectiveLabel => 'Taledirektivet';

  @override
  String get agentStateConsecutiveFailures => 'På hinanden følgende fejl';

  @override
  String agentStateErrorLoading(String error) {
    return 'Fejlede i at indlæse tilstand: $error';
  }

  @override
  String get agentStateHeading => 'Statsinformation';

  @override
  String get agentStateLastWake => 'Sidste våge';

  @override
  String get agentStateNextWake => 'Næste våge';

  @override
  String get agentStateRevision => 'Revision';

  @override
  String get agentStateSleepingUntil => 'Sover indtil';

  @override
  String get agentStateWakeCount => 'Vågenopgørelse';

  @override
  String get agentStatsAverageLabel => 'Gennemsnit';

  @override
  String get agentStatsByModelHeading => 'By Model';

  @override
  String get agentStatsCacheRateLabel => 'Cache-hastighed';

  @override
  String get agentStatsDailyUsageHeading => 'Daglig brug';

  @override
  String agentStatsDayRangeLabel(int days) {
    return '${days}D';
  }

  @override
  String agentStatsHeroHighUsage(String name) {
    return '$name is using an unusually large share of today\'s tokens.';
  }

  @override
  String get agentStatsInputLabel => 'Input';

  @override
  String agentStatsLastNDays(int days) {
    return 'last $days days';
  }

  @override
  String agentStatsModelDayShare(int percentage) {
    return '$percentage% of this day';
  }

  @override
  String get agentStatsNoUsage =>
      'Der er ikke registreret tokenbrug de seneste 7 dage.';

  @override
  String get agentStatsOtherLabel => 'Other';

  @override
  String get agentStatsOutputLabel => 'Output';

  @override
  String agentStatsSourceActiveFor(String duration) {
    return 'Aktiv for $duration';
  }

  @override
  String get agentStatsSourceActivityHeading => 'Agentaktivitet';

  @override
  String get agentStatsSourceEmptyDay => 'No agent activity on this day.';

  @override
  String get agentStatsSourceHighUsage => 'Unusually heavy token use today';

  @override
  String get agentStatsSourceHighUsageDay =>
      'Unusually heavy token use this day';

  @override
  String agentStatsSourceScopeDayLabel(String day) {
    return '$day · % of tokens';
  }

  @override
  String get agentStatsSourceScopeLabel => 'Today · % of tokens';

  @override
  String agentStatsSourceWakes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wakes',
      one: '1 wake',
    );
    return '$_temp0';
  }

  @override
  String get agentStatsTabTitle => 'Statistik';

  @override
  String get agentStatsThoughtsLabel => 'Tankerne';

  @override
  String get agentStatsTodayLabel => 'I dag';

  @override
  String get agentStatsTokensPerWakeLabel => 'Tokens / Wake';

  @override
  String get agentStatsTokensUnit => 'Tokens';

  @override
  String agentStatsUsageAboveAverage(String time) {
    return 'Du bruger flere tokens i dag, end du normalt gør ifølge $time.';
  }

  @override
  String agentStatsUsageBelowAverage(String time) {
    return 'Du bruger færre tokens i dag, end du normalt gør ved $time.';
  }

  @override
  String get agentStatsWakesLabel => 'Våger';

  @override
  String get agentSuggestionTimeEntryUpdateCurrent => 'Nuværende';

  @override
  String get agentSuggestionTimeEntryUpdateNoChange => '(uændret)';

  @override
  String get agentSuggestionTimeEntryUpdateProposed => 'Foreslået';

  @override
  String get agentSuggestionTimeEntryUpdateUnavailable =>
      'Original indgang ikke tilgængelig';

  @override
  String get agentTabActivity => 'Aktivitet';

  @override
  String get agentTabConversations => 'Samtaler';

  @override
  String get agentTabObservations => 'Observationer';

  @override
  String get agentTabReports => 'Rapporter';

  @override
  String get agentTabStats => 'Statistik';

  @override
  String get agentTemplateAggregateTokenUsageHeading => 'Aggregeret token-brug';

  @override
  String get agentTemplateAssignedLabel => 'Skabelon';

  @override
  String get agentTemplateCreatedSuccess => 'Skabelon oprettet';

  @override
  String get agentTemplateCreateTitle => 'Opret skabelon';

  @override
  String get agentTemplateDeleteConfirm =>
      'Slette denne skabelon? Det kan ikke gøres om.';

  @override
  String get agentTemplateDeleteHasInstances =>
      'Kan ikke slette: aktive agenter bruger denne skabelon.';

  @override
  String get agentTemplateDisplayNameLabel => 'Navn';

  @override
  String get agentTemplateEditTitle => 'Rediger skabelon';

  @override
  String get agentTemplateEvolveApprove => 'Godkend & Gem';

  @override
  String get agentTemplateEvolveReject => 'Afvis';

  @override
  String get agentTemplateGeneralDirectiveHint =>
      'Definer agentens personlighed, værktøjer, mål og interaktionsstil...';

  @override
  String get agentTemplateGeneralDirectiveLabel => 'Generel direktiv';

  @override
  String get agentTemplateInstanceBreakdownHeading => 'Hændelsesopdeling';

  @override
  String get agentTemplateKindDayAgent => 'Dagagent';

  @override
  String get agentTemplateKindEventAgent => 'Event Agent';

  @override
  String get agentTemplateKindImprover => 'Skabelonforbedrer';

  @override
  String get agentTemplateKindProjectAgent => 'Projektagent';

  @override
  String get agentTemplateKindTaskAgent => 'Task Agent';

  @override
  String get agentTemplateMetricsTotalWakes => 'Samlede våger';

  @override
  String get agentTemplateNoneAssigned => 'Ingen skabelon tildelt';

  @override
  String get agentTemplateNoTemplates =>
      'Ingen skabeloner tilgængelige. Opret først en i Indstillinger.';

  @override
  String get agentTemplateNotFound => 'Skabelon ikke fundet';

  @override
  String get agentTemplateNoVersions => 'Ingen versioner';

  @override
  String get agentTemplateReportDirectiveHint =>
      'Definer rapportstrukturen, de nødvendige sektioner og formateringsreglerne...';

  @override
  String get agentTemplateReportDirectiveLabel => 'Rapportdirektivet';

  @override
  String get agentTemplateReportsEmpty => 'Ingen rapporter endnu.';

  @override
  String get agentTemplateReportsTab => 'Rapporter';

  @override
  String get agentTemplateRollbackAction => 'Rul tilbage til denne version';

  @override
  String agentTemplateRollbackConfirm(int version) {
    return 'Skal vi rulle tilbage til version $version? Agenten vil bruge denne version ved næste våge.';
  }

  @override
  String get agentTemplateSaveNewVersion => 'Gem';

  @override
  String get agentTemplateSelectTitle => 'Vælg skabelon';

  @override
  String get agentTemplatesEmptyFiltered =>
      'Ingen skabeloner matcher dine filtre.';

  @override
  String get agentTemplateSettingsTab => 'Indstillinger';

  @override
  String get agentTemplatesFilterSectionKind => 'Venlig';

  @override
  String get agentTemplatesGroupByKind => 'Venlig';

  @override
  String get agentTemplatesGroupNone => 'Alle';

  @override
  String get agentTemplatesSearchPlaceholder => 'Søg skabeloner...';

  @override
  String get agentTemplateStatsTab => 'Statistik';

  @override
  String get agentTemplateStatusActive => 'Aktiv';

  @override
  String get agentTemplateStatusArchived => 'Arkiveret';

  @override
  String get agentTemplatesTitle => 'Agent-skabeloner';

  @override
  String get agentTemplateSwitchHint =>
      'For at bruge en anden skabelon, ødelæg denne agent og lav en ny.';

  @override
  String get agentTemplateVersionHistoryTitle => 'Versionshistorik';

  @override
  String agentTemplateVersionLabel(int version) {
    return 'Version $version';
  }

  @override
  String get agentTemplateVersionSaved => 'Ny version gemt';

  @override
  String get agentThreadReportLabel => 'Rapport udarbejdet under denne våge';

  @override
  String get agentTokenUsageCachedTokens => 'Cachet';

  @override
  String get agentTokenUsageEmpty => 'Ingen token-brug registreret endnu.';

  @override
  String agentTokenUsageErrorLoading(String error) {
    return 'Manglende indlæsning af token: $error';
  }

  @override
  String get agentTokenUsageHeading => 'Tokenbrug';

  @override
  String get agentTokenUsageInputTokens => 'Input';

  @override
  String get agentTokenUsageModel => 'Model';

  @override
  String get agentTokenUsageOutputTokens => 'Output';

  @override
  String get agentTokenUsageThoughtsTokens => 'Tankerne';

  @override
  String get agentTokenUsageTotalTokens => 'Total';

  @override
  String get agentTokenUsageWakeCount => 'Våger';

  @override
  String get agentWakeReasonCreation => 'Creation';

  @override
  String get agentWakeReasonReanalysis => 'Re-analysis';

  @override
  String get agentWakeReasonScheduled => 'Scheduled';

  @override
  String get agentWakeReasonSubscription => 'Event';

  @override
  String get agentWakeReasonTranscription => 'Transcription';

  @override
  String get aggregationDailyAvg => 'Dagligt gennemsnit';

  @override
  String get aggregationDailyMax => 'Dagligt maksimum';

  @override
  String get aggregationDailySum => 'Daglig sum';

  @override
  String get aggregationHourlySum => 'Timebeløb';

  @override
  String get aggregationNone => 'Råværdier';

  @override
  String get aiAssistantTitle => 'Generer...';

  @override
  String get aiAttributionArtifactOutput => 'Output';

  @override
  String get aiAttributionCompletedAt => 'Completed at';

  @override
  String get aiAttributionCost => 'Cost';

  @override
  String get aiAttributionCostUnknown => 'Cost unknown';

  @override
  String get aiAttributionCreator => 'Creator';

  @override
  String get aiAttributionDiagnostics => 'Diagnostics';

  @override
  String get aiAttributionDuration => 'Duration';

  @override
  String get aiAttributionInteractions => 'Interactions';

  @override
  String get aiAttributionLoading => 'Loading AI attribution…';

  @override
  String get aiAttributionNoInteractionDetails =>
      'No interaction details are available.';

  @override
  String get aiAttributionRequestEvidence => 'Request evidence';

  @override
  String get aiAttributionResponseEvidence => 'Response evidence';

  @override
  String aiAttributionSecondary(String model, String time, int callCount) {
    String _temp0 = intl.Intl.pluralLogic(
      callCount,
      locale: localeName,
      other: '$callCount calls',
      one: '1 call',
      zero: 'no calls',
    );
    return '$model · $time · $_temp0';
  }

  @override
  String get aiAttributionStartedAt => 'Started at';

  @override
  String get aiAttributionStatus => 'Status';

  @override
  String get aiAttributionStatusCancelled => 'Cancelled';

  @override
  String get aiAttributionStatusFailed => 'Failed';

  @override
  String get aiAttributionStatusPartial => 'Partial';

  @override
  String get aiAttributionStatusSucceeded => 'Completed';

  @override
  String aiAttributionSummary(String actor, String trigger, String status) {
    return '$actor · $trigger · $status';
  }

  @override
  String get aiAttributionTitle => 'AI attribution';

  @override
  String aiAttributionTokenBreakdown(
    String input,
    String output,
    String cached,
    String reasoning,
  ) {
    return 'Input: $input · Output: $output · Cached: $cached · Reasoning: $reasoning';
  }

  @override
  String get aiAttributionTokens => 'Tokens';

  @override
  String get aiAttributionTokenUsageUnknown => 'Token usage unknown';

  @override
  String get aiAttributionTrigger => 'Trigger';

  @override
  String get aiAttributionTriggerAgent => 'Agent';

  @override
  String get aiAttributionTriggerAutomatic => 'Automatic';

  @override
  String get aiAttributionTriggerImported => 'Imported';

  @override
  String get aiAttributionTriggerManual => 'Manual';

  @override
  String get aiAttributionTriggerScheduled => 'Scheduled';

  @override
  String get aiAttributionTriggerSynced => 'From sync';

  @override
  String get aiAttributionUnavailable => 'AI attribution is unavailable.';

  @override
  String get aiAttributionUnknownCreator => 'Unknown creator';

  @override
  String get aiAttributionUnknownModel => 'Unknown model';

  @override
  String get aiAttributionYou => 'You';

  @override
  String get aiBatchToggleTooltip => 'Skift til standardoptagelse';

  @override
  String get aiCapabilityChipImageGeneration => 'Billedgenerering';

  @override
  String get aiCapabilityChipImageRecognition => 'Billedgenkendelse';

  @override
  String get aiCapabilityChipThinking => 'Tænkning';

  @override
  String get aiCapabilityChipTranscription => 'Udskrift';

  @override
  String aiCardHistoryToggle(int count) {
    return 'Historie · $count';
  }

  @override
  String get aiCardMenuActionDelete => 'Slet';

  @override
  String get aiCardMenuActionEdit => 'Redigering';

  @override
  String get aiCardMenuTooltip => 'Flere aktioner';

  @override
  String get aiCardOpenAgentInternals => 'Åbne agent-internals';

  @override
  String get aiCardProposalConfirmed => 'Bekræftet';

  @override
  String get aiCardProposalDismissed => 'Afvist';

  @override
  String get aiCardProposalKindAdd => 'Tilføj';

  @override
  String get aiCardProposalKindDue => 'To';

  @override
  String get aiCardProposalKindEstimate => 'Estimat';

  @override
  String get aiCardProposalKindLabel => 'Label';

  @override
  String get aiCardProposalKindPriority => 'Prioritet';

  @override
  String get aiCardProposalKindRemove => 'Fjern';

  @override
  String get aiCardProposalKindStatus => 'Status';

  @override
  String get aiCardProposalKindUpdate => 'Opdatering';

  @override
  String get aiCardReadMore => 'Læs mere';

  @override
  String get aiCardShowLess => 'Vis mindre';

  @override
  String get aiCardTitle => 'AI-oversigt';

  @override
  String get aiChatAssistantResponding => 'Assistenten svarer';

  @override
  String get aiChatMessageCopied => 'Kopieret til clipboard';

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Kunne ikke indlæse modellerne. Prøv venligst igen.';

  @override
  String get aiConfigNoModelsAvailable =>
      'Der er endnu ikke konfigureret AI-modeller. Tilføj venligst en i indstillingerne.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Ingen modeller opfylder kravene til denne prompt. Konfigurer venligst modeller, der understøtter de nødvendige funktioner.';

  @override
  String get aiConfigSelectProviderModalTitle => 'Vælg Inferensudbyder';

  @override
  String get aiConfigSelectProviderTypeModalTitle => 'Vælg udbydertype';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Brug ræsonnering';

  @override
  String aiConsumptionAttributionReference(String id) {
    return 'Attribution $id';
  }

  @override
  String aiConsumptionCallsLine(int count, int measured) {
    return 'AI-opkald: $count · Impact målt for $measured';
  }

  @override
  String aiConsumptionCostLine(String cost) {
    return 'Pris: $cost';
  }

  @override
  String aiConsumptionImpactLine(String energy, String carbon, String water) {
    return 'Impact: $energy · $carbon CO₂e · $water vand';
  }

  @override
  String aiConsumptionLedgerCap(int limit) {
    return 'Viser de nyeste $limit-kald i denne periode';
  }

  @override
  String get aiConsumptionLedgerTitle => 'Seneste opkald';

  @override
  String get aiConsumptionMetricsNotReported => 'Ikke rapporteret';

  @override
  String aiConsumptionTokensLabel(String tokens) {
    return '$tokens tokens';
  }

  @override
  String aiConsumptionTokensLine(String input, String output) {
    return 'Tokens: $input i · $output ud';
  }

  @override
  String get aiConsumptionTypeAgentTurn => 'Agent-turn';

  @override
  String get aiConsumptionTypeAudioTranscription => 'Udskrift';

  @override
  String get aiConsumptionTypeEmbeddingIndexing => 'Embedding indexing';

  @override
  String get aiConsumptionTypeImageAnalysis => 'Billedanalyse';

  @override
  String get aiConsumptionTypeImageGeneration => 'Billedgenerering';

  @override
  String get aiConsumptionTypePromptGeneration => 'Promptgenerering';

  @override
  String get aiConsumptionTypeTextGeneration => 'Tekstgenerering';

  @override
  String aiConsumptionWorkGroup(int callCount) {
    String _temp0 = intl.Intl.pluralLogic(
      callCount,
      locale: localeName,
      other: '$callCount calls',
      one: '1 call',
    );
    return 'AI work · $_temp0';
  }

  @override
  String aiDeleteToastCascadeDescription(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' Også fjernet $count modeller: $names',
      one: 'Også fjernet 1 model: $names',
    );
    return '$_temp0';
  }

  @override
  String aiDeleteToastErrorTitle(String name) {
    return 'Kunne ikke slette $name';
  }

  @override
  String get aiDeleteToastModelTitle => 'Model slettet';

  @override
  String get aiDeleteToastProfileTitle => 'Profil slettet';

  @override
  String get aiDeleteToastPromptTitle => 'Prompt slettet';

  @override
  String get aiDeleteToastProviderTitle => 'Udbyder slettet';

  @override
  String get aiDeleteToastSkillTitle => 'Færdighed slettet';

  @override
  String get aiDeleteToastUndoAction => 'Fortryd';

  @override
  String get aiFormCancel => 'Annuller';

  @override
  String get aiFormFixErrors => 'Ret venligst fejl, før du gemmer';

  @override
  String get aiFormNoChanges => 'Ingen ugemte ændringer';

  @override
  String get aiImageAnalysisPickerDefaultBadge => 'Default';

  @override
  String get aiImageAnalysisPickerTitle => 'Vælg en billedanalysemodel';

  @override
  String get aiImageGenerationPickerTitle => 'Vælg en billedgenereringsmodel';

  @override
  String get aiImpactBreakdownBoth => 'Begge dele';

  @override
  String get aiImpactBreakdownCategory => 'Efter kategori';

  @override
  String get aiImpactBreakdownModel => 'Efter model';

  @override
  String get aiImpactCategoryTitle => 'Kategoriopdeling';

  @override
  String get aiImpactChartHint =>
      'Tryk på en bar for at afgrænse opkald · Tap en serie for at isolere';

  @override
  String get aiImpactChartShareCaption => 'Sammensætning over tid';

  @override
  String get aiImpactChartShareSegment => 'Del';

  @override
  String aiImpactChartTitle(String metric) {
    return '$metric efter kategori';
  }

  @override
  String aiImpactChartTitleModel(String metric) {
    return '$metric efter model';
  }

  @override
  String get aiImpactCoverageNote =>
      'Energi, CO₂e og omkostninger måles kun for skymodeller.';

  @override
  String get aiImpactEmptyBody =>
      'AI-opkald fra dine opgaver og agenter vil dukke op her.';

  @override
  String get aiImpactEmptyTitle => 'Ingen AI-brug i dette område';

  @override
  String get aiImpactKpiCarbon => 'CO₂E';

  @override
  String get aiImpactKpiCost => 'OMKOSTNINGER';

  @override
  String aiImpactKpiDeltaBaseline(String period) {
    return 'vs $period';
  }

  @override
  String get aiImpactKpiEnergy => 'ENERGI';

  @override
  String get aiImpactKpiRequests => 'ANMODNINGER';

  @override
  String get aiImpactKpiTokens => 'TOKENS';

  @override
  String get aiImpactLedgerClearFilter => 'Vis alt';

  @override
  String get aiImpactLoadError => 'Kunne ikke indlæse AI-påvirkningsdata';

  @override
  String get aiImpactLocationColumn => 'BELIGGENHED';

  @override
  String get aiImpactLocationTitle => 'Indvirkning efter placering';

  @override
  String get aiImpactLocationUnknown => 'Ukendt';

  @override
  String get aiImpactMetricCarbon => 'CO₂e';

  @override
  String get aiImpactMetricCost => 'Omkostninger';

  @override
  String get aiImpactMetricEnergy => 'Energi';

  @override
  String get aiImpactMetricRequests => 'Anmodninger';

  @override
  String get aiImpactMetricTokens => 'Tokens';

  @override
  String aiImpactModelCallsLabel(String count) {
    return '$count kalder';
  }

  @override
  String get aiImpactModelColumn => 'MODEL';

  @override
  String get aiImpactModelCostHeavy => 'Omkostningstungt';

  @override
  String get aiImpactModelCoverageNote =>
      'Lokale modeller er udelukket fra dette diagram.';

  @override
  String get aiImpactModelOther => 'Andre modeller';

  @override
  String aiImpactModelRatePerMillion(String cost) {
    return '$cost/1M tok';
  }

  @override
  String get aiImpactModelTitle => 'Modelopdeling';

  @override
  String get aiImpactModelUnknown => 'Ukendt model';

  @override
  String get aiImpactRenewableColumn => 'VEDVARENDE ENERGI';

  @override
  String get aiImpactTitle => 'AI-indflydelse';

  @override
  String get aiInferenceErrorAuthenticationTitle =>
      'Autentificering mislykkedes';

  @override
  String get aiInferenceErrorConnectionFailedTitle =>
      'Forbindelsen mislykkedes';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Ugyldig anmodning';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Hastighedsgrænse overskredet';

  @override
  String get aiInferenceErrorRetryButton => 'Prøv igen';

  @override
  String get aiInferenceErrorServerTitle => 'Serverfejl';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Forslag:';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Anmodning udløbet';

  @override
  String get aiInferenceErrorUnknownTitle => 'Fejl';

  @override
  String get aiInternalsTitle => 'Agentens interne dele';

  @override
  String get aiModelDownloadCloseButton => 'Luk';

  @override
  String aiModelDownloadDialogDescription(String modelName) {
    return 'Lotti downloader $modelName ind i MLX Audio-cachen og bruger den til lokal talebehandling.';
  }

  @override
  String aiModelDownloadDialogTitle(String modelName) {
    return 'Installer $modelName';
  }

  @override
  String get aiModelDownloadInstallTooltip => 'Installationsmodel';

  @override
  String get aiModelDownloadOpenProgressTooltip => 'Vis downloadfremskridt';

  @override
  String get aiModelDownloadStatusChecking => 'Kontrol af modelstatus';

  @override
  String aiModelDownloadStatusDownloading(int percent) {
    return 'Downloader $percent%';
  }

  @override
  String get aiModelDownloadStatusDownloadingIndeterminate => 'Download';

  @override
  String get aiModelDownloadStatusFailed => 'Download mislykkedes';

  @override
  String get aiModelDownloadStatusInstalled => 'Installeret';

  @override
  String get aiModelDownloadStatusNotInstalled => 'Ikke installeret';

  @override
  String get aiModelDownloadStatusUnsupported => 'Apple Silicon påkrævet';

  @override
  String get aiModelInstallChoiceCancelButton => 'Annuller';

  @override
  String get aiModelInstallChoiceDescription =>
      'Vælg først den lokale tale-til-tekst-model til download. Du kan installere de andre senere fra modellisten.';

  @override
  String get aiModelInstallChoiceInstallButton => 'Installationsmodel';

  @override
  String get aiModelInstallChoiceRecommended => 'Anbefalet';

  @override
  String get aiModelInstallChoiceTitle => 'Vælg MLX Audio-modellen';

  @override
  String get aiModelPickerByProviderLabel => 'Vælg en udbyder';

  @override
  String get aiModelPickerCurrentDefaultLabel => 'Nuværende betalingsstandard';

  @override
  String aiModelPickerProviderModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String aiOllamaModelInstalledSuccessfully(String modelName) {
    return 'Model \"$modelName\" installeret med succes!';
  }

  @override
  String get aiPickProviderBadgeDesktopOnly => 'KUN SKRIVEBORD';

  @override
  String get aiPickProviderBadgeNew => 'NYT';

  @override
  String get aiPickProviderBadgeRecommended => 'ANBEFALET';

  @override
  String get aiPickProviderContinueButton => 'Fortsæt';

  @override
  String get aiPickProviderDontShowAgainButton => 'Vis ikke igen';

  @override
  String get aiPickProviderFooterHint =>
      'Du kan tilføje flere udbydere senere i Settings → AI. Din API-nøgle gemmes lokalt.';

  @override
  String get aiPickProviderModalTitle => 'Opsætning af AI-funktioner';

  @override
  String get aiPickProviderSubtitle =>
      'Vælg en udbyder til at komme i gang. Vi opsætter automatisk modeller og en startprofil.';

  @override
  String get aiProfileCardActiveBadge => 'Aktiv';

  @override
  String get aiProfileModelPickerSearchHint => 'Søg modeller...';

  @override
  String get aiProfileSlotModelMissing => 'Mangler';

  @override
  String get aiPromptGenerationPickerTitle => 'Vælg en prompt-genereringsmodel';

  @override
  String get aiProviderAlibabaDescription =>
      'Alibaba Clouds Qwen-familie af modeller via DashScope API';

  @override
  String get aiProviderAlibabaName => 'Alibaba Cloud (Qwen)';

  @override
  String get aiProviderAnthropicDescription =>
      'Anthropics Claude-familie af AI-assistenter';

  @override
  String get aiProviderAnthropicName => 'Anthropiske Claude';

  @override
  String get aiProviderCardDraftBadge => 'DRAFT';

  @override
  String get aiProviderCardFixButton => 'Løsning';

  @override
  String aiProviderCardModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String aiProviderCardModelCountWithLastUsed(int count, String lastUsed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modeller · Sidst brugt $lastUsed',
      one: '1 model · Sidst brugte $lastUsed',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardOllamaHint => 'Sørg for, at Ollama kører';

  @override
  String aiProviderCardStatusConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Connected · $count modeller',
      one: 'Forbundet · 1 model',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardStatusConnectedShort => 'Forbundet';

  @override
  String get aiProviderCardStatusInvalidKey => 'Ugyldig nøgle';

  @override
  String get aiProviderCardStatusOffline =>
      'Offline · Sørg for, at Ollama kører';

  @override
  String get aiProviderCardStatusOfflineShort => 'Offline';

  @override
  String get aiProviderConnectBackToProviders => 'Tilbage til udbydere';

  @override
  String get aiProviderConnectBreadcrumbAdd => 'Tilføj udbyder';

  @override
  String get aiProviderConnectFieldBaseUrlHint =>
      'Lad det stå tomt for at bruge det officielle endpoint';

  @override
  String get aiProviderConnectFieldBaseUrlLabelOptional =>
      'Basis-URL (valgfrit)';

  @override
  String get aiProviderConnectFieldBaseUrlPlaceholder =>
      'https://api.example.com';

  @override
  String get aiProviderConnectFieldDisplayNameHint =>
      'Vist på din udbyderliste';

  @override
  String get aiProviderConnectionCheckingLabel =>
      'Tjekker nøglen, lister tilgængelige modeller...';

  @override
  String aiProviderConnectionFailedBadResponseDetail(String type) {
    return 'Uventet responsform: $type';
  }

  @override
  String aiProviderConnectionFailedHttpDetail(int status, String message) {
    return 'HTTP $status · $message';
  }

  @override
  String get aiProviderConnectionFailedInvalidBaseUrlDetail =>
      'Basis-URL\'en skal inkludere http(s)-skemaet og værten (f.eks. https://api.example.com)';

  @override
  String aiProviderConnectionFailedNetworkDetail(String message) {
    return '$message';
  }

  @override
  String get aiProviderConnectionFailedTimeoutDetail => 'Anmodning udløbet';

  @override
  String aiProviderConnectionFailedTitle(String providerName) {
    return 'Kunne ikke nå $providerName. Tjek nøglen eller dit netværk.';
  }

  @override
  String get aiProviderConnectionRetestButton => 'Gentest';

  @override
  String get aiProviderConnectionRetryButton => 'Nyt forsøg';

  @override
  String aiProviderConnectionVerifiedSubtitle(int count, int ms) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modeller tilgængelige på din konto · Svarede i ${ms}ms',
      one: '1 model tilgængelig på din konto · Svarede i ${ms}ms',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderConnectionVerifiedTitle => 'Forbindelse bekræftet';

  @override
  String aiProviderConnectKeyHelperLink(String url) {
    return 'Få en nøgle på $url';
  }

  @override
  String get aiProviderConnectKeyHiddenLabel => 'Skjult';

  @override
  String get aiProviderConnectKeyPrivacyHint =>
      'Din API-nøgle forlader aldrig din enhed.';

  @override
  String aiProviderConnectPageTitle(String providerName) {
    return 'Forbind $providerName';
  }

  @override
  String get aiProviderConnectSaveAndContinue => 'Gem & Fortsæt';

  @override
  String get aiProviderConnectSaveAsDraft => 'Gem som udkast';

  @override
  String get aiProviderConnectSavedAsDraftToast => 'Gemt som udkast';

  @override
  String get aiProviderConnectStepChoose => 'Vælg udbyder';

  @override
  String get aiProviderConnectStepConnect => 'Forbind';

  @override
  String get aiProviderConnectStepReview => 'Anmeldelse';

  @override
  String get aiProviderDetailActiveProfileTitle => 'Aktiv profil';

  @override
  String get aiProviderDetailAddModelButton => 'Tilføj model';

  @override
  String get aiProviderDetailApiKeyLabel => 'API-nøgle';

  @override
  String get aiProviderDetailBackTooltip => 'Tilbage';

  @override
  String get aiProviderDetailBaseUrlLabel => 'Basis-URL';

  @override
  String get aiProviderDetailConnectionTitle => 'Forbindelse';

  @override
  String get aiProviderDetailDangerZoneTitle => 'Farezone';

  @override
  String get aiProviderDetailDisplayNameLabel => 'Visningsnavn';

  @override
  String get aiProviderDetailEditButton => 'Redigering';

  @override
  String get aiProviderDetailEditTooltip => 'Redigeringsudbyder';

  @override
  String get aiProviderDetailLoadError =>
      'Kunne ikke indlæse denne udbyder. Prøv igen fra AI-indstillingslisten.';

  @override
  String get aiProviderDetailMissingMessage =>
      'Denne udbyder er ikke længere tilgængelig.';

  @override
  String aiProviderDetailModelsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Modeller · $count',
      one: 'Modeller · 1',
      zero: 'Models',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderDetailNoModelsMessage =>
      'Ingen modeller endnu. Tilføj én for at begynde at bruge denne udbyder.';

  @override
  String get aiProviderDetailPageTitle => 'Udbyderoplysninger';

  @override
  String get aiProviderDetailRemoveButton => 'Fjern udbyderen';

  @override
  String get aiProviderDetailRemoveDescription =>
      'Det sletter udbyderen og alle modeller, der er afhængige af den. Det kan ikke gøres om.';

  @override
  String get aiProviderDetailRemoveTitle => 'Fjern denne udbyder';

  @override
  String get aiProviderDetailValueUnset => 'Ikke sat';

  @override
  String get aiProviderEmbeddedRuntimeHint =>
      'Kører indlejret i Apple-appens proces. Ingen lokal server eller basis-URL er nødvendig.';

  @override
  String get aiProviderGeminiDescription => 'Googles Gemini AI-modeller';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiDescription =>
      'API-kompatibelt med OpenAI-formatet';

  @override
  String get aiProviderGenericOpenAiName => 'OpenAI-kompatibel';

  @override
  String get aiProviderMeliousDescription =>
      'Europeisk-hostet inferens, med et dynamisk modelkatalog, routing, lyd og billeder';

  @override
  String get aiProviderMeliousName => 'Melious.ai';

  @override
  String get aiProviderMistralDescription =>
      'Mistral AI cloud API med indbygget lydtransskription';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderMlxAudioDescription =>
      'Indlejrede MLX Audio-modeller til lokal STT og TTS på Apple Silicon';

  @override
  String get aiProviderMlxAudioName => 'MLX Audio (lokal)';

  @override
  String get aiProviderNebiusAiStudioDescription =>
      'Nebius AI Studios modeller';

  @override
  String get aiProviderNebiusAiStudioName => 'Nebius AI Studio';

  @override
  String get aiProviderOllamaDescription => 'Kør inferens lokalt med Ollama';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOmlxDescription =>
      'Lokal OpenAI-kompatibel oMLX-inferens for MLX-modeller';

  @override
  String get aiProviderOmlxName => 'oMLX (lokal)';

  @override
  String get aiProviderOpenAiDescription => 'OpenAIs GPT-modeller';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'OpenRouters modeller';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderTaglineAlibaba =>
      'Qwen-modeller · multimodal · Lang kontekst';

  @override
  String get aiProviderTaglineAnthropic => 'Familien Claude · Lang kontekst';

  @override
  String get aiProviderTaglineGemini => 'Multimodal · Lydtransskription';

  @override
  String get aiProviderTaglineMelious =>
      'EU-vært · Dynamisk katalog · Eco-ruting';

  @override
  String get aiProviderTaglineMlxAudio =>
      'Indlejret · Apple Silicon · Lokal lyd';

  @override
  String get aiProviderTaglineOllama => 'Kører lokalt · Ingen skyopkald';

  @override
  String get aiProviderTaglineOmlx => 'Lokal MLX-inferens: · OpenAI-kompatibel';

  @override
  String get aiProviderTaglineOpenAi => 'GPT-familien · Vision + ræsonnement';

  @override
  String get aiProviderUnknownName => 'AI-udbyder';

  @override
  String get aiProviderVoxtralDescription =>
      'Lokal Voxtral transskription (op til 30 min lyd, 13 sprog)';

  @override
  String get aiProviderVoxtralName => 'Voxtral (lokal)';

  @override
  String get aiProviderWhisperDescription =>
      'Lokal Whisper-transskription med OpenAI-kompatibel API';

  @override
  String get aiProviderWhisperName => 'Whisper (lokal)';

  @override
  String get aiRealtimeToggleTooltip => 'Skift til live transskription';

  @override
  String get aiResponseDeleteCancel => 'Annuller';

  @override
  String get aiResponseDeleteConfirm => 'Slet';

  @override
  String get aiResponseDeleteError =>
      'Undlod at slette AI-svaret. Prøv venligst igen.';

  @override
  String get aiResponseDeleteTitle => 'Slet AI-svar';

  @override
  String get aiResponseDeleteWarning =>
      'Er du sikker på, at du vil slette dette AI-svar? Det kan ikke gøres om.';

  @override
  String get aiResponseTypeAudioTranscription => 'Lydtransskription';

  @override
  String get aiResponseTypeChecklistUpdates => 'Tjeklisteopdateringer';

  @override
  String get aiResponseTypeImageAnalysis => 'Billedanalyse';

  @override
  String get aiResponseTypeImagePromptGeneration => 'Billedprompt';

  @override
  String get aiResponseTypePromptGeneration => 'Genereret prompt';

  @override
  String get aiResponseTypeTaskSummary => 'Opgaveoversigt';

  @override
  String get aiRunningActivityOpenProgress => 'Vis AI-fremskridt';

  @override
  String get aiSettingsAddedLabel => 'Tilføjet';

  @override
  String get aiSettingsAddModelButton => 'Tilføj model';

  @override
  String get aiSettingsAddModelErrorDescription =>
      'Noget gik galt, da jeg tilføjede modellen. Prøv venligst igen.';

  @override
  String get aiSettingsAddModelErrorTitle => 'Kunne ikke tilføje model';

  @override
  String get aiSettingsAddModelTooltip => 'Tilføj denne model til din udbyder';

  @override
  String get aiSettingsAddProfileButton => 'Tilføj profil';

  @override
  String get aiSettingsAddProviderButton => 'Tilføj udbyder';

  @override
  String get aiSettingsAgentWakeConcurrencyDescription =>
      'Vælg hvor mange forskellige agenter, der kan køre inferensen på én gang. Højere værdier reagerer hurtigere, men bruger mere kapacitet til udbyder og enhed.';

  @override
  String get aiSettingsAgentWakeConcurrencyLabel => 'Samtidig agent vågner';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Ryd alle filtre';

  @override
  String get aiSettingsClearFiltersButton => 'Klart';

  @override
  String get aiSettingsCounterModels => 'Modeller';

  @override
  String get aiSettingsCounterProfiles => 'Profiler';

  @override
  String get aiSettingsCounterProviders => 'Udbydere';

  @override
  String get aiSettingsEmptyDescription =>
      'Tilføj én for at låse op for transskription, billedgenkendelse, billedgenerering og semantisk søgning.';

  @override
  String get aiSettingsEmptyTitle => 'Ingen udbydere endnu';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filtrer efter $capability-funktion';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filtrer efter $provider';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip =>
      'Filtrer efter ræsonnementsevne';

  @override
  String get aiSettingsFtueBannerDescription =>
      'Det tager cirka et minut. Lotti vil opstille modeller og en startprofil til dig.';

  @override
  String get aiSettingsFtueBannerStartButton => 'Start opsætning';

  @override
  String get aiSettingsFtueBannerTitle => 'Tilføj din første AI-udbyder';

  @override
  String get aiSettingsModalityAudio => 'Lyd';

  @override
  String get aiSettingsModalityText => 'Tekst';

  @override
  String get aiSettingsModalityVision => 'Vision';

  @override
  String get aiSettingsNoModelsConfigured => 'Ingen AI-modeller konfigureret';

  @override
  String get aiSettingsNoProvidersConfigured =>
      'Ingen AI-udbydere konfigureret';

  @override
  String get aiSettingsPageLead =>
      'Konfigurer AI-udbydere, de modeller Lotti kan kalde, og inferensprofilerne, der bestemmer, hvilken model der håndterer hvilken opgave.';

  @override
  String get aiSettingsPageTitle => 'AI-indstillinger';

  @override
  String get aiSettingsReasoningLabel => 'Begrundelse';

  @override
  String get aiSettingsRemoveModelTooltip =>
      'Fjern denne model fra din udbyder';

  @override
  String get aiSettingsSearchHint => 'Søgeudbydere, modeller, profiler...';

  @override
  String get aiSettingsSearchHintShort => 'Søgning';

  @override
  String get aiSettingsTabModels => 'Modeller';

  @override
  String get aiSettingsTabProfiles => 'Profiler';

  @override
  String get aiSettingsTabProviders => 'Udbydere';

  @override
  String get aiSetupPreviewAcceptButton => 'Accepter og afslut';

  @override
  String get aiSetupPreviewAlreadyAddedSectionLabel => 'Allerede tilføjet';

  @override
  String aiSetupPreviewCategoryFooter(String categoryName) {
    return 'Opret en testkategori $categoryName for at prøve det af.';
  }

  @override
  String aiSetupPreviewConnectedHeader(String providerName) {
    return '$providerName forbundet';
  }

  @override
  String get aiSetupPreviewCustomizeButton => 'Tilpas';

  @override
  String get aiSetupPreviewLead =>
      'Gennemgå, hvad Lotti vil tilføje. Fjern fluebenet i alt, du ikke ønsker; Du kan altid sætte det op senere i hånden.';

  @override
  String get aiSetupPreviewLiveBadge => 'Live';

  @override
  String aiSetupPreviewModalTitle(String providerName) {
    return '$providerName opsætning';
  }

  @override
  String get aiSetupPreviewModelsSectionLabel => 'Modeller';

  @override
  String get aiSetupPreviewProfileSectionLabel => 'Inferensprofil';

  @override
  String get aiSetupPreviewProfileSetActiveBadge => 'Sæt aktiv';

  @override
  String aiSetupResultBulletCategoryCreated(String categoryName) {
    return 'Opret en testkategori $categoryName for at prøve det af';
  }

  @override
  String aiSetupResultBulletCategoryReused(String categoryName) {
    return 'Genbrug af eksisterende testkategori $categoryName';
  }

  @override
  String aiSetupResultBulletModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Konfigureret $count modeller',
      one: 'Konfigureret 1 model',
    );
    return '$_temp0';
  }

  @override
  String aiSetupResultBulletProfile(String profileName) {
    return 'Oprettet inferensprofil $profileName';
  }

  @override
  String aiSetupResultErrorsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemer',
      one: '1 problem',
    );
    return '$_temp0 under opsætning';
  }

  @override
  String aiSetupResultHeader(String providerName) {
    return '$providerName er forbundet';
  }

  @override
  String aiSetupResultKnownModelsMissing(String providerName) {
    return 'Fandt ikke de nødvendige $providerName modelkonfigurationer';
  }

  @override
  String get aiSetupResultLead =>
      'Vi har arrangeret det for dig. AI-funktioner er klar til brug i din dagbog.';

  @override
  String aiSetupResultModalTitle(String providerName) {
    return '$providerName klar';
  }

  @override
  String get aiSetupResultStartUsingButton => 'Begynd at bruge AI';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Opretter optimerede modeller, prompts og en testkategori';

  @override
  String aiSetupWizardDescription(String providerName) {
    return 'Opsæt eller opdater modeller, prompts og testkategori for $providerName';
  }

  @override
  String get aiSetupWizardRunButton => 'Løbeopsætning';

  @override
  String get aiSetupWizardRunLabel => 'Kør opsætningsguiden';

  @override
  String get aiSetupWizardRunningButton => 'Løber...';

  @override
  String get aiSetupWizardSafeToRunMultiple =>
      'Sikkert at køre flere gange – eksisterende genstande vil blive bevaret';

  @override
  String get aiSetupWizardTitle => 'AI Opsætningsguide';

  @override
  String get aiSummaryPlayTooltip => 'Spilresumé';

  @override
  String get aiSummaryPreparingTooltip => 'Forberedelse af lyd';

  @override
  String get aiSummarySpeakTooltip => 'Læs resuméet højt lokalt';

  @override
  String get aiSummaryStopTooltip => 'Stop';

  @override
  String get aiSummaryThinkingLabel => 'Tænker...';

  @override
  String get aiSummaryTtsUnavailable => 'Tekst-til-tale er ikke tilgængelig';

  @override
  String get aiTaskSummaryTitle => 'AI-opgaveoversigt';

  @override
  String get aiTranscriptionPickerDefaultBadge => 'Default';

  @override
  String get aiTranscriptionPickerTitle => 'Vælg en transskriptionsmodel';

  @override
  String get apiKeyAddPageTitle => 'Tilføj udbyder';

  @override
  String get apiKeyAuthenticationDescription => 'Sikre din API-forbindelse';

  @override
  String get apiKeyAuthenticationTitle => 'Autentificering';

  @override
  String get apiKeyAvailableModelsDescription =>
      'Hurtig-tilføj forudkonfigurerede modeller til denne udbyder';

  @override
  String get apiKeyAvailableModelsTitle => 'Tilgængelige modeller';

  @override
  String get apiKeyBaseUrlLabel => 'Basis-URL';

  @override
  String get apiKeyDisplayNameHint => 'Indtast et venligt navn';

  @override
  String get apiKeyDisplayNameLabel => 'Visningsnavn';

  @override
  String get apiKeyDynamicModelsDescription =>
      'Søg i denne udbyders katalog over levende modeller og tilføj en hvilken som helst model';

  @override
  String get apiKeyEditGoBackButton => 'Gå tilbage';

  @override
  String get apiKeyEditLoadError => 'Kunne ikke indlæse API-nøglekonfiguration';

  @override
  String get apiKeyEditLoadErrorRetry =>
      'Prøv venligst igen eller kontakt support';

  @override
  String get apiKeyEditPageTitle => 'Rediger Udbyder';

  @override
  String get apiKeyHideTooltip => 'Skjul API-nøgle';

  @override
  String get apiKeyInputHint => 'Indtast din API-nøgle';

  @override
  String get apiKeyInputLabel => 'API-nøgle';

  @override
  String apiKeyKnownModelInputLabel(String modalities) {
    return 'I: $modalities';
  }

  @override
  String apiKeyKnownModelOutputLabel(String modalities) {
    return 'Ud: $modalities';
  }

  @override
  String get apiKeyProviderConfigDescription =>
      'Konfigurer dine AI-inferensudbyderindstillinger';

  @override
  String get apiKeyProviderConfigTitle => 'Udbyderkonfiguration';

  @override
  String get apiKeyProviderTypeHint => 'Vælg en udbydertype';

  @override
  String get apiKeyProviderTypeLabel => 'Udbydertype';

  @override
  String get apiKeyShowTooltip => 'Vis API-nøgle';

  @override
  String get audioRecordingCancel => 'AFLYS';

  @override
  String get audioRecordingDiscardDialogBody =>
      'Denne optagelse vil blive slettet. Der vil ikke blive oprettet lydindtastning, transskription eller opgaveoversigt.';

  @override
  String get audioRecordingDiscardDialogCancel => 'Bliv ved med at optage';

  @override
  String get audioRecordingDiscardDialogConfirm => 'Kasser';

  @override
  String get audioRecordingDiscardDialogTitle => 'Kassere optagelse?';

  @override
  String get audioRecordingListening => 'Lytter...';

  @override
  String get audioRecordingPause => 'PAS';

  @override
  String get audioRecordingRealtime => 'Live transskription';

  @override
  String get audioRecordingResume => 'CV';

  @override
  String get audioRecordings => 'Lydoptagelser';

  @override
  String get audioRecordingStandard => 'Standard';

  @override
  String get audioRecordingStop => 'STOP';

  @override
  String backfillAdvancedRecoveryActions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count handlinger',
      one: '1 handling',
    );
    return '$_temp0';
  }

  @override
  String get backfillAdvancedRecoveryTitle => 'Avanceret genopretning';

  @override
  String get backfillAskPeersConfirmAccept => 'Spørg jævnaldrende';

  @override
  String backfillAskPeersConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Dette vender alle $count uløselige sekvenslog-poster tilbage til at mangle, så den normale backfill-sweep spørger peers igen. Jævnaldrende, der stadig har nyttelasten, vil reagere; Virkelig uoprettelige bidrag vil igen trække sig tilbage efter 7-dages amnestivinduet. ',
      one:
          'Dette vender én uløselig sekvenslog-post tilbage til manglende, så den normale backfill-gennemgang spørger peers igen. Jævnaldrende, der stadig har nyttelasten, vil reagere; Virkelig uoprettelige bidrag vil igen trække sig tilbage efter 7-dages amnestivinduet. ',
    );
    return '$_temp0';
  }

  @override
  String get backfillAskPeersConfirmTitle =>
      'Skal jeg spørge kolleger igen om uløselige poster?';

  @override
  String get backfillAskPeersDescription =>
      'Vend alle uløselige sekvenslog-poster tilbage til manglende og lad den normale backfill sweep genspørge peers.';

  @override
  String get backfillAskPeersProcessing => 'Genåbning...';

  @override
  String get backfillAskPeersTitle => 'Bed peers om uløselig';

  @override
  String backfillAskPeersTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Spørg peers om $count poster',
      one: 'Spørg peers om 1 post',
    );
    return '$_temp0';
  }

  @override
  String get backfillCatchUpDescription =>
      'Træk nyligt manglende poster fra jævnaldrende lige nu.';

  @override
  String backfillDevicesMeta(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enheds-ID\'er',
      one: '1 enheds-ID',
    );
    return '$_temp0';
  }

  @override
  String get backfillManualDescription =>
      'Anmod om alle manglende poster uanset alder. Brug dette til at genoprette ældre synkroniseringshuller.';

  @override
  String get backfillManualProcessing => 'Behandler...';

  @override
  String get backfillManualTitle => 'Manuel tilbagefyldning';

  @override
  String get backfillManualTrigger => 'Anmod om manglende poster';

  @override
  String get backfillReRequestDescription =>
      'Anmod om nye indsendelser, der blev anmodet om, men aldrig modtaget. Brug dette, når svarene sidder fast.';

  @override
  String get backfillReRequestProcessing => 'Anmoder igen...';

  @override
  String get backfillReRequestTitle => 'Genanmodning verserer';

  @override
  String get backfillReRequestTrigger => 'Anmodning om ventende poster igen';

  @override
  String get backfillResetUnresolvableDescription =>
      'Nulstil poster, der er markeret som uløselige, tilbage til manglende post, så de kan anmodes om igen. Brug repopulationen efter sekvensloggen.';

  @override
  String get backfillResetUnresolvableProcessing => 'Nulstiller...';

  @override
  String get backfillResetUnresolvableTitle => 'Nulstil Uløselig';

  @override
  String get backfillResetUnresolvableTrigger => 'Nulstil uløselige poster';

  @override
  String get backfillRetireStuckConfirmAccept => 'Gå på pension nu';

  @override
  String backfillRetireStuckConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Dette markerer $count aktuelt åbne (manglende eller anmodede) sekvenslog-poster som uløselige. Brug dette til at fjerne blokeringen af vandmærket, når indgange har siddet fast i et stykke tid uden at 7-dages amnestivinduet er overstået. Poster kan stadig genoplives, hvis deres nyttelast senere ankommer til disken med en gyldig vektorclock. ',
      one:
          'Dette markerer 1 aktuelt åben (manglende eller anmodet om) sekvenslogpost som uløselig. Brug dette til at fjerne blokeringen af vandmærket, når indgange har siddet fast i et stykke tid uden at 7-dages amnestivinduet er overstået. Poster kan stadig genoplives, hvis deres nyttelast senere ankommer til disken med en gyldig vektorclock. ',
    );
    return '$_temp0';
  }

  @override
  String get backfillRetireStuckConfirmTitle =>
      'Pensionere fastlåste poster nu?';

  @override
  String get backfillRetireStuckDescription =>
      'Tving alle aktuelt åbne manglende eller anmodede sekvenslogposter til at være uløselige. Springer 7-dages amnestien over — brug kun for fastklemte rækker, der blokerer vandmærket.';

  @override
  String get backfillRetireStuckProcessing => 'Pensionering...';

  @override
  String get backfillRetireStuckTitle =>
      'Tilbagetrækning af fastlåste indleveringer';

  @override
  String backfillRetireStuckTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' Pensionér $count fastlåste indgange',
      one: 'Pensioner 1 fastlåst indgang',
    );
    return '$_temp0';
  }

  @override
  String get backfillSettingsSubtitle =>
      'Styr gendannelse af synkroniseringsgab.';

  @override
  String get backfillSettingsTitle => 'Backfill-synkronisering';

  @override
  String get backfillStatsBackfilled => 'Tilbagefyldt';

  @override
  String get backfillStatsBurned => 'Brændt';

  @override
  String get backfillStatsDeleted => 'Slettet';

  @override
  String get backfillStatsMissing => 'Savnet';

  @override
  String get backfillStatsNoData => 'Ingen synkroniseringsdata tilgængelig';

  @override
  String get backfillStatsReceived => 'Modtaget';

  @override
  String get backfillStatsRefresh => 'Opfrisk stats';

  @override
  String get backfillStatsRequested => 'Efterspurgt';

  @override
  String get backfillStatsTitle => 'Synkroniseringsstatistikker';

  @override
  String get backfillStatsTotalEntries => 'Samlet antal tilmeldinger';

  @override
  String get backfillStatsUnresolvable => 'Uløseligt';

  @override
  String get backfillStatusInboundQueue => 'Indkommende kø';

  @override
  String get backfillStatusMissing => 'Savnet';

  @override
  String get backfillStatusSkipped => 'Sprunget over';

  @override
  String get backfillToggleDescription =>
      'Anmodninger om manglende indtastninger fra de sidste 24 timer.';

  @override
  String get backfillToggleTitle => 'Automatisk tilbagefyldning';

  @override
  String get basicSettings => 'Grundlæggende indstillinger';

  @override
  String get calendarHasPlanLabel => 'Har en plan';

  @override
  String get calendarTodayLabel => 'I dag';

  @override
  String get cancelButton => 'Annuller';

  @override
  String get categoryActiveDescription =>
      'Inaktive kategorier vil ikke fremgå i udvælgelseslister';

  @override
  String get categoryActiveSwitchDescription => 'Kan vælges for nye bidrag';

  @override
  String get categoryAiDefaultsDescription =>
      'Sæt standard AI-profil og agentskabelon for nye opgaver i denne kategori';

  @override
  String get categoryAiDefaultsTitle => 'AI-standardindstillinger';

  @override
  String get categoryCreationError =>
      'Ikke i stand til at oprette kategori. Prøv venligst igen.';

  @override
  String get categoryDayPlanDescription =>
      'Gør denne kategori tilgængelig for valg i dagsplanen';

  @override
  String get categoryDayPlanLabel => 'Dagsplanlægning';

  @override
  String get categoryDefaultEventTemplateHint => 'Vælg en skabelon';

  @override
  String get categoryDefaultEventTemplateLabel =>
      'Standard event agent-skabelon';

  @override
  String get categoryDefaultLanguageDescription =>
      'Sæt et standardsprog for opgaver i denne kategori';

  @override
  String get categoryDefaultProfileHint => 'Vælg en profil';

  @override
  String get categoryDefaultTemplateHint => 'Vælg en skabelon';

  @override
  String get categoryDefaultTemplateLabel => 'Standardagent-skabelon';

  @override
  String get categoryDeleteConfirm => 'JA, SLET DENNE KATEGORI';

  @override
  String get categoryDeleteConfirmation =>
      'Denne handling kan ikke gøres om. Alle bidrag i denne kategori vil forblive, men vil ikke længere blive kategoriseret.';

  @override
  String get categoryDeleteTitle => 'Slette kategori?';

  @override
  String get categoryFavoriteBadgeLabel => 'Favorit';

  @override
  String get categoryFavoriteDescription => 'Sæt denne kategori som favorit';

  @override
  String get categoryIconChooseHint => 'Vælg et ikon';

  @override
  String get categoryIconCreateHint => 'Vælg et ikon';

  @override
  String get categoryIconEditHint => 'Vælg et andet ikon';

  @override
  String get categoryIconLabel => 'Ikon';

  @override
  String get categoryIconPickerTitle => 'Vælg ikon';

  @override
  String get categoryNameRequired => 'Kategorinavn er påkrævet';

  @override
  String get categoryNotFound => 'Kategori ikke fundet';

  @override
  String get categoryPrivateBadgeLabel => 'Privat';

  @override
  String get categoryPrivateDescription =>
      'Kun synlig, når private bidrag vises';

  @override
  String get categorySearchPlaceholder => 'Søgekategorier...';

  @override
  String get changeSetCardTitle => 'Foreslåede ændringer';

  @override
  String get changeSetConfirmAll => 'Bekræft alt';

  @override
  String changeSetConfirmAllPartialIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count genstande havde delvise problemer',
      one: '1 genstand havde delvise problemer',
    );
    return '$_temp0';
  }

  @override
  String get changeSetConfirmError => 'Undlod at ansøge om ændring';

  @override
  String get changeSetItemConfirmed => 'Ændring anvendt';

  @override
  String changeSetItemConfirmedWithWarning(String warning) {
    return 'Anvendt med advarsel: $warning';
  }

  @override
  String get changeSetItemRejected => 'Ændring afvist';

  @override
  String changeSetPendingCount(int count) {
    return '$count venter';
  }

  @override
  String get changeSetSwipeConfirm => 'Bekræft';

  @override
  String get changeSetSwipeReject => 'Afvis';

  @override
  String get chatInputCancelRealtime => 'Annuller (Esc)';

  @override
  String get chatInputCancelRecording => 'Annuller optagelse (Esc)';

  @override
  String get chatInputConfigureModel => 'Konfigurér model';

  @override
  String get chatInputHintDefault =>
      'Spørg ind til dine opgaver og produktivitet...';

  @override
  String get chatInputHintSelectModel =>
      'Vælg en model til at begynde at chatte';

  @override
  String get chatInputListening => 'Lytter...';

  @override
  String get chatInputPleaseWait => 'Vent venligst...';

  @override
  String get chatInputProcessing => 'Behandler...';

  @override
  String get chatInputRecordVoice => 'Optag talebesked';

  @override
  String get chatInputSendTooltip => 'Send besked';

  @override
  String get chatInputStartRealtime => 'Start live-transskription';

  @override
  String get chatInputStopRealtime => 'Stop live-transskriptionen';

  @override
  String get chatInputStopTranscribe => 'Stop og transskribér';

  @override
  String get checklistAddItem => 'Tilføj en ny genstand';

  @override
  String checklistAiConfidenceLabel(String level) {
    return 'Selvtillid: $level';
  }

  @override
  String get checklistAiMarkComplete => 'Mark Komplet';

  @override
  String get checklistAiSuggestionBody =>
      'Dette punkt ser ud til at være færdigt:';

  @override
  String get checklistAiSuggestionTitle => 'AI-forslag';

  @override
  String get checklistAllDone => 'Alle ting er fuldført!';

  @override
  String get checklistCollapseTooltip => 'Sammenbrud';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total færdig';
  }

  @override
  String get checklistDelete => 'Slette tjekliste?';

  @override
  String get checklistExpandTooltip => 'Udvid';

  @override
  String get checklistExportAsMarkdown => 'Eksporttjekliste som Markdown';

  @override
  String get checklistExportFailed => 'Eksporten mislykkedes';

  @override
  String get checklistItemArchived => 'Arkiveret genstand';

  @override
  String get checklistItemArchiveUndo => 'Fortryd';

  @override
  String get checklistItemDeleteCancel => 'Annuller';

  @override
  String get checklistItemDeleteConfirm => 'Bekræft';

  @override
  String get checklistItemDeleted => 'Genstanden slettet';

  @override
  String get checklistItemDeleteWarning => 'Denne handling kan ikke gøres om.';

  @override
  String get checklistMarkdownCopied => 'Tjekliste kopieret som Markdown';

  @override
  String get checklistMoreTooltip => 'Mere';

  @override
  String get checklistNoneDone => 'Ingen færdige opgaver endnu.';

  @override
  String get checklistNothingToExport => 'Ingen varer at eksportere';

  @override
  String get checklistProgressSemantics => 'Tjekliste fremskridt';

  @override
  String get checklistShare => 'Del';

  @override
  String get checklistShareHint => 'Længe presse på at dele';

  @override
  String get checklistsReorder => 'Omorganisering';

  @override
  String get clearButton => 'Klart';

  @override
  String get colorCustomLabel => 'Skik';

  @override
  String get colorLabel => 'Farve';

  @override
  String get commandPaletteNoResults =>
      'Ingen tilgængelige kommandoer matcher din søgning';

  @override
  String get commandPaletteSearchHint => 'Søgekommandoer...';

  @override
  String get commandPaletteTitle => 'Kommando-palette';

  @override
  String get commonError => 'Fejl';

  @override
  String get commonLoading => 'Indlæser...';

  @override
  String get commonUnknown => 'Ukendt';

  @override
  String get completeHabitFailButton => 'Missede';

  @override
  String get completeHabitSkipButton => 'Spring over';

  @override
  String get completeHabitSuccessButton => 'Succes';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Når den er aktiveret, vil appen forsøge at generere embeddings til dine poster for at forbedre søge- og relaterede indholdsforslag.';

  @override
  String get configFlagDailyOsOnboardingEnabled => 'Daglig OS-gennemgang';

  @override
  String get configFlagDailyOsOnboardingEnabledDescription =>
      'Guid førstegangsbrugere af Daily OS gennem en rigtig check-in, der gør tale til en opgave og en dagsplan.';

  @override
  String get configFlagEnableAiStreaming =>
      'Aktiver AI-streaming til opgavehandlinger';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Stream AI-svar for opgaverelaterede handlinger. Slå fra for at buffere svarene og hold brugerfladen mere jævn.';

  @override
  String get configFlagEnableAiSummaryTts => 'AI-opsummering afspilning';

  @override
  String get configFlagEnableAiSummaryTtsDescription =>
      'Vis den lokale tekst-til-tale-knap på opgave-AI-resuméer. Kræver en installeret MLX Audio TTS-model.';

  @override
  String get configFlagEnableDashboardsPage => 'Aktivér dashboards-siden';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Vis dashboards-siden i hovednavigationen. Se dine data og indsigter i tilpassede dashboards.';

  @override
  String get configFlagEnableEmbeddings => 'Generer indlejringer';

  @override
  String get configFlagEnableEvents => 'Aktiver begivenheder';

  @override
  String get configFlagEnableEventsDescription =>
      'Vis Events-funktionen for at oprette, spore og administrere begivenheder i din journal.';

  @override
  String get configFlagEnableForkHealing => 'Agent gaffel-helbredelse';

  @override
  String get configFlagEnableForkHealingDescription =>
      'Helbred divergerende agenthistorier fra brug af flere enheder ved at sammenflette dem ved næste våge.';

  @override
  String get configFlagEnableHabitsPage => 'Aktivér Vaner-siden';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Vis siden Vaner i hovednavigationen. Følg og styr dine daglige vaner her.';

  @override
  String get configFlagEnableLogging => 'Aktiver logning';

  @override
  String get configFlagEnableLoggingDescription =>
      'Aktivér detaljeret logning til fejlfindingsformål. Dette kan påvirke ydeevnen.';

  @override
  String get configFlagEnableMatrix => 'Aktivér Matrix-synkronisering';

  @override
  String get configFlagEnableMatrixDescription =>
      'Aktivér Matrix-integrationen for at synkronisere dine poster på tværs af enheder og med andre Matrix-brugere.';

  @override
  String get configFlagEnableNotifications => 'Aktivere notifikationer?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Modtag notifikationer om påmindelser, opdateringer og vigtige begivenheder.';

  @override
  String get configFlagEnableProjects => 'Muliggør projekter';

  @override
  String get configFlagEnableProjectsDescription =>
      'Vis projektstyringsfunktioner til at organisere opgaver i projekter.';

  @override
  String get configFlagEnableSessionRatings => 'Aktiver sessionsvurderinger';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Spørg om en hurtig sessionsvurdering, når du stopper en timer.';

  @override
  String get configFlagEnableTooltip => 'Aktivér tooltips';

  @override
  String get configFlagEnableTooltipDescription =>
      'Vis nyttige værktøjstips gennem hele appen, der guider dig gennem funktionerne.';

  @override
  String get configFlagEnableVectorSearch => 'Vektorsøgning';

  @override
  String get configFlagEnableVectorSearchDescription =>
      'Aktivér vektorsøgning i opgavefiltrene. Det kræver, at embeddings aktiveres, og at Ollama kører.';

  @override
  String get configFlagEnableWhatsNew => 'Vis hvad der er nyt';

  @override
  String get configFlagEnableWhatsNewDescription =>
      'Fremhæv nye funktioner og ændringer i indstillingstræet.';

  @override
  String get configFlagPrivate => 'Vise private indsendelser?';

  @override
  String get configFlagPrivateDescription =>
      'Aktivér dette for at gøre dine poster private som standard. Private indgange er kun synlige for dig.';

  @override
  String get configFlagRecordLocation => 'Registreringssted';

  @override
  String get configFlagRecordLocationDescription =>
      'Registrer automatisk din placering med nye indførsler. Dette hjælper med lokationsbaseret organisering og søgning.';

  @override
  String get configFlagResendAttachments => 'Sendte vedhæftede filer igen';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Aktivér dette for automatisk at sende mislykkede vedhæftede uploads igen, når forbindelsen genoprettes.';

  @override
  String get configFlagShowSyncActivityIndicator =>
      'Indikator for vis synkroniseret aktivitet';

  @override
  String get configFlagShowSyncActivityIndicatorDescription =>
      'Vis en stille synkroniseringsstatus i sidebaren; Køoptællinger vises kun, mens arbejdet er i gang.';

  @override
  String get conflictApplyButton => 'Ansøg';

  @override
  String get conflictApplyFailedTitle => 'Kunne ikke anvende opløsning';

  @override
  String conflictBannerAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dage siden',
      one: '1 dag siden',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h ago',
      one: '1 time siden',
    );
    return '$_temp0';
  }

  @override
  String get conflictBannerAgoJustNow => 'Lige nu';

  @override
  String conflictBannerAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min siden',
      one: '1 min siden',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerDivergedAgo(String entity, String ago) {
    return '$entity · divergede $ago';
  }

  @override
  String conflictBannerFieldsDifferList(String fields) {
    return 'Adskiller sig i: $fields';
  }

  @override
  String get conflictCombineApply => 'Ansøg kombineret';

  @override
  String get conflictCombineStartFrom => 'Start fra';

  @override
  String get conflictConfirmDeletion => 'Bekræft sletning';

  @override
  String get conflictDeleteVsEditDescription =>
      'Denne post blev redigeret på én enhed og slettet på en anden. Intet fjernes, før du vælger.';

  @override
  String get conflictDeleteVsEditTitle => 'Slettet på én enhed';

  @override
  String get conflictDetailEntryNotFoundTitle => 'Indlæg ikke fundet';

  @override
  String get conflictDetailLoadErrorTitle => 'Kunne ikke indlæse konflikt';

  @override
  String get conflictDetailNotFoundTitle => 'Konflikt ikke fundet';

  @override
  String get conflictDiffRecommended => 'Anbefalet';

  @override
  String conflictDiffUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count felter uændrede',
      one: '1 felt uændret',
    );
    return '$_temp0';
  }

  @override
  String get conflictFieldBody => 'Karrosseri';

  @override
  String get conflictFieldCategory => 'Kategori';

  @override
  String get conflictFieldDuration => 'Varighed';

  @override
  String get conflictFieldEnd => 'Slut';

  @override
  String get conflictFieldFlag => 'Flag';

  @override
  String get conflictFieldOther => 'Andre detaljer';

  @override
  String get conflictFieldOtherDescription =>
      'Disse versioner adskiller sig i detaljer, som ikke vises individuelt her.';

  @override
  String get conflictFieldPrivate => 'Privat';

  @override
  String get conflictFieldStarred => 'Medvirket';

  @override
  String get conflictFieldStart => 'Start';

  @override
  String get conflictFieldTitle => 'Titel';

  @override
  String get conflictFieldWordCount => 'Ordantal';

  @override
  String get conflictFlagFollowUp => 'Opfølgning nødvendig';

  @override
  String get conflictFlagImport => 'Importeret';

  @override
  String get conflictFlagNone => 'Ingen';

  @override
  String get conflictFooterHelperLocalSelected =>
      'Jeg beholder din lokale redigering og kasserer den synkroniserede version.';

  @override
  String get conflictFooterHelperPickASide => 'Vælg en side at anvende.';

  @override
  String get conflictFooterHelperRemoteSelected =>
      'Jeg accepterer den synkroniserede version og kasserer din lokale redigering.';

  @override
  String conflictHeaderPillEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count indførsler',
      one: '1 indgang',
    );
    return '$_temp0';
  }

  @override
  String conflictHeaderPillFieldsDiffer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count felter adskiller sig ',
      one: '1 felt adskiller sig',
    );
    return '$_temp0';
  }

  @override
  String get conflictKeepEdited => 'Behold den redigerede version';

  @override
  String conflictListItemSemanticsLabel(
    String status,
    String timestamp,
    String entityType,
    String id,
  ) {
    return '$status, $timestamp, $entityType, konflikt $id';
  }

  @override
  String conflictListItemTooltipFullId(String id) {
    return 'Konflikt-ID: $id';
  }

  @override
  String get conflictMetaLocalEdit => 'Lokal redigering';

  @override
  String get conflictMetaVecPrefix => 'VEC';

  @override
  String get conflictMetaViaSync => 'via sync';

  @override
  String conflictNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count indgange blev redigeret på to enheder',
      one: '1 indgang blev redigeret på to enheder',
    );
    return '$_temp0';
  }

  @override
  String get conflictNotificationTitle => 'Sync kræver din gennemgang';

  @override
  String get conflictPageLeadDesktop =>
      'Forskelle fremhævet inline. Klik på en side for at bruge den version, eller åbn Rediger & flet sammen for at kombinere dem.';

  @override
  String get conflictPageLeadMobile =>
      'Forskelle fremhævet inline. Tryk på en side for at bruge den version.';

  @override
  String get conflictPageTitle => 'Synkroniseringskonflikt';

  @override
  String get conflictPickerCombine => 'Kombiner...';

  @override
  String get conflictPickerEditMerge => 'Rediger og flet...';

  @override
  String get conflictPickerUseFromSync => 'Brug fra sync';

  @override
  String get conflictPickerUseThisDevice => 'Brug denne enhed';

  @override
  String get conflictResolvedToast => 'Konflikten løst';

  @override
  String get conflictsEmptyDescription =>
      'Alt er synkroniseret lige nu. Løste genstande forbliver tilgængelige i det andet filter.';

  @override
  String get conflictsEmptyTitle => 'Ingen konflikter opdaget';

  @override
  String get conflictSideFromSync => 'FRA SYNC';

  @override
  String get conflictSideThisDevice => 'DENNE ENHED';

  @override
  String get conflictsResolved => 'Løst';

  @override
  String get conflictsUnresolved => 'Uafklaret';

  @override
  String get conflictValueAbsent => 'Ikke sat';

  @override
  String get conflictValueNo => 'Nej';

  @override
  String get conflictValueYes => 'Ja';

  @override
  String conflictWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ord',
      one: '$count ord',
    );
    return '$_temp0';
  }

  @override
  String get copyAsMarkdown => 'Kopier som Markdown';

  @override
  String get copyAsText => 'Kopier som tekst';

  @override
  String get correctionExampleCancel => 'AFLYS';

  @override
  String correctionExamplePending(int seconds) {
    return 'Gemte korrektion i ${seconds}s...';
  }

  @override
  String get correctionExamplesEmpty =>
      'Ingen korrektioner er fanget endnu. Rediger et tjeklistepunkt for at tilføje dit første eksempel.';

  @override
  String get correctionExamplesSectionDescription =>
      'Når du manuelt retter tjekliste-elementer, gemmes disse her og bruges til at forbedre AI-forslag.';

  @override
  String get correctionExamplesSectionTitle =>
      'Eksempler på tjeklistekorrektion';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'Du har $count rettelser. Kun den nyeste $max vil blive brugt i AI-prompts. Overvej at slette gamle eller overflødige eksempler.';
  }

  @override
  String get coverArtChipActive => 'Forside';

  @override
  String get coverArtChipSet => 'Kulissecover';

  @override
  String get coverArtGenerationComplete => 'Coverkunst klar!';

  @override
  String get coverArtGenerationDismissHint =>
      'Du kan lukke dette — generationen fortsætter i baggrunden';

  @override
  String get createButton => 'Opret';

  @override
  String get createCategoryTitle => 'Opret kategori';

  @override
  String get createEntryLabel => 'Opret ny post';

  @override
  String get createEntryTitle => 'Tilføj';

  @override
  String get createNewLinkedTask => 'Opret ny sammenkædet opgave...';

  @override
  String get customColor => 'Specialfarve';

  @override
  String get dailyOsDayPlan => 'Dagsplan';

  @override
  String get dailyOsNextAgendaCapacityComfortable => 'Behageligt';

  @override
  String get dailyOsNextAgendaCapacityNearFull => 'Næsten fuld';

  @override
  String get dailyOsNextAgendaCapacityNoPlan => 'Ingen plan endnu';

  @override
  String dailyOsNextAgendaCapacityOf(String capacity) {
    return 'af $capacity';
  }

  @override
  String get dailyOsNextAgendaCapacityOver => 'Overkapacitet';

  @override
  String get dailyOsNextAgendaDonutLeft => 'Venstre';

  @override
  String get dailyOsNextAgendaDonutOver => 'Over';

  @override
  String dailyOsNextAgendaHeadlineLeft(String duration) {
    return '$duration forlod';
  }

  @override
  String dailyOsNextAgendaHeadlineOver(String duration) {
    return '$duration over';
  }

  @override
  String get dailyOsNextAgendaNoPlanBody =>
      'Din registrerede tid er her uanset hvad — tal med et check-in, og jeg udarbejder en dag omkring det.';

  @override
  String dailyOsNextAgendaNoPlanSummary(String duration) {
    return '$duration har indtil videre fulgt med på det. Tal et check-in, og jeg laver en dag omkring det.';
  }

  @override
  String get dailyOsNextAgendaNoPlanTitle => 'Ingen plan endnu for i dag.';

  @override
  String get dailyOsNextAgendaStateDone => 'Færdig';

  @override
  String get dailyOsNextAgendaStateInProgress => 'Under udvikling';

  @override
  String get dailyOsNextAgendaStateOpen => 'Åben';

  @override
  String get dailyOsNextAgendaStateOverdue => 'Forsinket';

  @override
  String dailyOsNextAgendaSummary(String scheduled, String capacity) {
    return '$scheduled af $capacity begået';
  }

  @override
  String dailyOsNextAgendaTrackedLegend(String duration, int completedCount) {
    return 'Sporet · $duration · $completedCount færdig';
  }

  @override
  String get dailyOsNextBlockEditCategoryLabel => 'Kategori';

  @override
  String get dailyOsNextBlockEditFailed =>
      'Kunne ikke opdatere blokeringen — prøv igen.';

  @override
  String get dailyOsNextBlockEditNameLabel => 'Titel';

  @override
  String get dailyOsNextBlockEditOpenTask => 'Åben opgave';

  @override
  String get dailyOsNextBlockEditSave => 'Gemmeændringer';

  @override
  String get dailyOsNextBlockEditSaved => 'Tidsplan opdateret.';

  @override
  String get dailyOsNextBlockEditTimeLabel => 'Start og slut';

  @override
  String get dailyOsNextBlockEditTitle => 'Rediger blok';

  @override
  String get dailyOsNextBlockEditTooltip => 'Rediger blok';

  @override
  String get dailyOsNextBlockEditWhyLabel => 'Hvorfor denne gang';

  @override
  String get dailyOsNextBlockMoveTooltip => 'Flytblok';

  @override
  String get dailyOsNextBlockResizeEndTooltip => 'Juster enden';

  @override
  String get dailyOsNextBlockResizeStartTooltip => 'Juster start';

  @override
  String get dailyOsNextCaptureCaptured => 'Forstået.';

  @override
  String get dailyOsNextCaptureDoneCta => 'Færdig';

  @override
  String get dailyOsNextCaptureErrorMicrophonePermissionDenied =>
      'Mikrofontilladelse blev nægtet.';

  @override
  String get dailyOsNextCaptureErrorNoActiveRealtimeSession =>
      'Ingen aktiv realtidssession.';

  @override
  String get dailyOsNextCaptureErrorNoAudioRecorded =>
      'Der blev ikke optaget lyd.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionFailed =>
      'Realtime-transskription fejlede.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionStartFailed =>
      'Realtime-transskription kunne ikke starte.';

  @override
  String get dailyOsNextCaptureErrorRecordingStartFailed =>
      'Optagelsen kunne ikke starte.';

  @override
  String get dailyOsNextCaptureErrorTranscriptionFailed =>
      'Transskriptionen mislykkedes.';

  @override
  String get dailyOsNextCaptureHeadlineCaptured => 'Ser det rigtigt ud?';

  @override
  String get dailyOsNextCaptureHeadlineLead => 'Hvad tænker du på';

  @override
  String get dailyOsNextCaptureHeadlineListening => 'Jeg lytter.';

  @override
  String get dailyOsNextCaptureHeadlineTail => 'For i dag?';

  @override
  String dailyOsNextCaptureHeadlineTailForDate(String date) {
    return 'for $date?';
  }

  @override
  String get dailyOsNextCaptureHeadlineTailTomorrow => 'Til i morgen?';

  @override
  String get dailyOsNextCaptureHeadlineTailYesterday => 'For i går?';

  @override
  String get dailyOsNextCaptureHeadlineTranscribing => 'At skrive det ned...';

  @override
  String get dailyOsNextCaptureIdleClick => 'Klik for at tale';

  @override
  String get dailyOsNextCaptureIdleExample =>
      '\"Dybt arbejde i morges, en gåtur efter frokost, mails før klokken fem.\"';

  @override
  String get dailyOsNextCaptureIdleHint => 'Tryk for at tale · Skriv i stedet';

  @override
  String get dailyOsNextCaptureIdleTalk => 'Tryk for at tale';

  @override
  String get dailyOsNextCaptureListeningStatus => 'Lytter...';

  @override
  String dailyOsNextCapturePastPrompt(String date) {
    return 'Er der noget, du stadig gerne vil spore fra $date?';
  }

  @override
  String get dailyOsNextCaptureReconcileCta => 'Anmeldelse';

  @override
  String get dailyOsNextCapturesPanelTitle => 'Fangster';

  @override
  String get dailyOsNextCaptureTranscribing => 'Transskriberer...';

  @override
  String get dailyOsNextCaptureTranscriptHint =>
      'Ret alt forkert i karakterudskriften, før du planlægger.';

  @override
  String get dailyOsNextCaptureTranscriptLabel => 'Gennemgå transskription';

  @override
  String get dailyOsNextCaptureTypeInstead => 'Type i stedet';

  @override
  String get dailyOsNextCaptureVoiceButtonReset => 'Start forfra';

  @override
  String get dailyOsNextCaptureVoiceButtonStart => 'Begynd at lytte';

  @override
  String get dailyOsNextCaptureVoiceButtonStop => 'Stop med at lytte';

  @override
  String get dailyOsNextCategoryFilterAll => 'Alle kategorier';

  @override
  String get dailyOsNextCategoryFilterDescription =>
      'Kun kategorier aktiveret til dagplanlægning vises for Daily OS automatiseret behandling.';

  @override
  String get dailyOsNextCategoryFilterEmpty =>
      'Ingen kategorier aktiveret til dagsplanlægning endnu.';

  @override
  String get dailyOsNextCategoryFilterIncludeAll => 'Inkluder alle';

  @override
  String get dailyOsNextCategoryFilterTitle => 'Behandlingskategorier';

  @override
  String get dailyOsNextCategoryFilterTooltip =>
      'Vælg Daily OS-behandlingskategorier';

  @override
  String dailyOsNextCommitCapacityNote(String scheduled, String capacity) {
    return '$scheduled af $capacity begået. Behagelig margin — du kan absorbere én overraskelse.';
  }

  @override
  String get dailyOsNextCommitDraftOverline => 'DIN DAG, INDKALDT';

  @override
  String get dailyOsNextCommitExplainer =>
      'Underskriv for at gå i dag fra værnepligt til committed.';

  @override
  String get dailyOsNextCommitFinalStepEyebrow => 'SIDSTE TRIN';

  @override
  String get dailyOsNextCommitHeadline => 'Gør den til din.';

  @override
  String get dailyOsNextCommitHoldHelper => 'Vent et øjeblik for at logge af';

  @override
  String get dailyOsNextCommitHoldWordDone => 'Forpligtet';

  @override
  String get dailyOsNextCommitHoldWordHolding => 'Bliv ved med at holde';

  @override
  String get dailyOsNextCommitHoldWordIdle => 'Hold';

  @override
  String get dailyOsNextCommitLockingIn => 'Låser ind...';

  @override
  String get dailyOsNextCommitShepherdSubline =>
      'Jeg skal nok tage mig af det — du gør arbejdet.';

  @override
  String get dailyOsNextCommitSubCaption =>
      'Du kan stadig tale med mig bagefter — men knoglerne bliver liggende.';

  @override
  String get dailyOsNextCommitTitle => 'Lås det fast';

  @override
  String get dailyOsNextCommitTodayIsYours => 'I dag er din.';

  @override
  String get dailyOsNextDayBack => 'Tilbage';

  @override
  String get dailyOsNextDayCheckInCta => 'Tal en check-in';

  @override
  String get dailyOsNextDayDeleteDialogBody =>
      'De udkastede blokke for denne dag vil blive fjernet. Optagelser og deres lydoptagelser bliver i din dagbog.';

  @override
  String get dailyOsNextDayDeleteDialogCancel => 'Annuller';

  @override
  String get dailyOsNextDayDeleteDialogConfirm => 'Slet';

  @override
  String get dailyOsNextDayDeleteDialogTitle => 'Slette denne plan?';

  @override
  String get dailyOsNextDayLockInCta => 'Lås ind';

  @override
  String get dailyOsNextDayMenuDeletePlan => 'Slet planen';

  @override
  String get dailyOsNextDayMenuInspectAgent => 'Inspektér agent';

  @override
  String get dailyOsNextDayMenuSettings => 'Daglige OS-indstillinger';

  @override
  String get dailyOsNextDayMoreTooltip => 'Mere';

  @override
  String get dailyOsNextDayRefineCta => 'Forfine';

  @override
  String get dailyOsNextDayRefineFooterHint =>
      'Tal med at omforme planen — du vil se alle ændringer, før noget bliver gemt.';

  @override
  String get dailyOsNextDayTitle => 'Din dag';

  @override
  String get dailyOsNextDayWhyChipLabel => 'HVORFOR';

  @override
  String get dailyOsNextDayWrapUpCta => 'Afslutning';

  @override
  String get dailyOsNextDraftingBackToDecisions => 'Tilbage til beslutninger';

  @override
  String get dailyOsNextDraftingHeader => 'Udkast til din dag...';

  @override
  String get dailyOsNextDraftingNudgeAccept => 'Ja, beskyt morgener';

  @override
  String get dailyOsNextDraftingNudgeDecline => 'Ikke i dag';

  @override
  String get dailyOsNextDraftingProgressBlocks => 'Draftblokke';

  @override
  String get dailyOsNextDraftingProgressMatching => 'Matchningsopgaver';

  @override
  String get dailyOsNextDraftingProgressQueued => 'Sat i kø';

  @override
  String get dailyOsNextDraftingProgressReading => 'Læse-check-in';

  @override
  String get dailyOsNextDraftingProgressSaving => 'Opsparingsplan';

  @override
  String get dailyOsNextDraftingProgressValidating => 'Validering';

  @override
  String get dailyOsNextDraftingReasoningOverline => '✦ RÆSONNEMENT';

  @override
  String get dailyOsNextDraftingRecoveryBody =>
      'Vågen gav ikke en plan. Prøv igen, eller gå tilbage og juster beslutningerne, før du udkaster.';

  @override
  String get dailyOsNextDraftingRecoveryTitle => 'Udkastningen gik i stå';

  @override
  String get dailyOsNextDraftingRetry => 'Prøv igen';

  @override
  String get dailyOsNextDraftingStatusAfternoon =>
      'At sekvensere eftermiddagen...';

  @override
  String get dailyOsNextDraftingStatusAlmost => 'Næsten der...';

  @override
  String get dailyOsNextDraftingStatusBreathing =>
      'Efterlader plads til at trække vejret...';

  @override
  String get dailyOsNextDraftingStatusDeepWork =>
      'At lægge dybt arbejde først...';

  @override
  String get dailyOsNextDraftingStatusMatching =>
      'At matche opgaver med din dag...';

  @override
  String get dailyOsNextDraftingStatusReading => 'Læser din check-in...';

  @override
  String get dailyOsNextDraftingStatusTimings =>
      'Dobbelttjekker tidspunkter...';

  @override
  String get dailyOsNextDraftingStatusYesterday =>
      'Når man ser på gårsdagens rytme...';

  @override
  String get dailyOsNextEditTitleHint => 'Rediger titel';

  @override
  String get dailyOsNextGenericError =>
      'Noget gik galt. Prøv igen om et øjeblik.';

  @override
  String get dailyOsNextGreetingAfternoon => 'God eftermiddag.';

  @override
  String get dailyOsNextGreetingEvening => 'God aften.';

  @override
  String dailyOsNextGreetingHiName(String name) {
    return 'Hej $name 👋';
  }

  @override
  String get dailyOsNextGreetingMorning => 'Godmorgen.';

  @override
  String get dailyOsNextKnowledgeConfirm => 'Bekræft';

  @override
  String get dailyOsNextKnowledgeConfirmedHeader => 'Bekræftet';

  @override
  String get dailyOsNextKnowledgeEdit => 'Redigering';

  @override
  String get dailyOsNextKnowledgeEditCancel => 'Annuller';

  @override
  String get dailyOsNextKnowledgeEditHookHint => 'Énlinjes resumé';

  @override
  String get dailyOsNextKnowledgeEditSave => 'Gem';

  @override
  String get dailyOsNextKnowledgeEditStatementHint => 'Hvad skal jeg huske?';

  @override
  String get dailyOsNextKnowledgeEmpty =>
      'Intet endnu — jeg vil huske, hvad du fortæller mig.';

  @override
  String dailyOsNextKnowledgeNudge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ting jeg lagde mærke til — review',
      one: '1 ting jeg lagde mærke til — review',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextKnowledgeProposedHeader => 'Afventer din bekræftelse';

  @override
  String get dailyOsNextKnowledgeRetract => 'Glem det';

  @override
  String get dailyOsNextKnowledgeStale => 'Er det stadig sandt?';

  @override
  String get dailyOsNextKnowledgeTitle => 'Hvad jeg har lært';

  @override
  String get dailyOsNextParsedCardBreakLinkTooltip => 'Break link';

  @override
  String get dailyOsNextPlanViewAgenda => 'Dagsorden';

  @override
  String get dailyOsNextPlanViewDay => 'Dag';

  @override
  String get dailyOsNextReconcileBadgeMatched => 'MATCHET';

  @override
  String get dailyOsNextReconcileBadgeNew => 'NYT';

  @override
  String get dailyOsNextReconcileBadgeUpdate => 'OPDATERING';

  @override
  String get dailyOsNextReconcileBuildDayCta => 'Byg min dag';

  @override
  String get dailyOsNextReconcileDecideOverline => 'VÆRD AT BESLUTTE SIG FOR';

  @override
  String dailyOsNextReconcileDecisionProgress(int decided, int total) {
    return '$decided af $total anmeldt';
  }

  @override
  String get dailyOsNextReconcileDefaultBehaviorHint =>
      'Gennemgå kortene, før du bygger din dag. Udvalgte handlinger indgår i planen; Kort, der efterlades, forbliver som de er.';

  @override
  String dailyOsNextReconcileError(String detail) {
    return 'Noget gik galt: $detail';
  }

  @override
  String get dailyOsNextReconcileHeadline => 'Her er, hvad jeg har hørt.';

  @override
  String get dailyOsNextReconcileHeardEmpty =>
      'Capture-kort vil dukke op her, når parsingen er færdig.';

  @override
  String get dailyOsNextReconcileHeardOverline => 'HØRT';

  @override
  String get dailyOsNextReconcileLowConfidence => 'lav selvtillid';

  @override
  String get dailyOsNextReconcileProcessing =>
      'At lytte tilbage og matche din dag...';

  @override
  String get dailyOsNextReconcileReRecord => 'Genindspilning';

  @override
  String get dailyOsNextReconcileVoiceHint =>
      'Gennemgå beslutninger, før du bygger din dag';

  @override
  String get dailyOsNextRefineAccept => 'Accepter';

  @override
  String get dailyOsNextRefineCurrentPlan => 'NUVÆRENDE PLAN';

  @override
  String get dailyOsNextRefineDiffAdded => 'TILFØJET';

  @override
  String get dailyOsNextRefineDiffDropped => 'DROPPET';

  @override
  String get dailyOsNextRefineDiffMoved => 'FLYTTET';

  @override
  String get dailyOsNextRefineHeadlineDiffReady =>
      'Her er, hvad jeg ville ændre.';

  @override
  String get dailyOsNextRefineHeadlineIdle => 'Hvad bør ændres?';

  @override
  String get dailyOsNextRefineHeadlineThinking => 'At omarbejde din plan...';

  @override
  String get dailyOsNextRefineKeepTalking => 'Bliv ved med at snakke';

  @override
  String get dailyOsNextRefineLooksGood => 'Ser godt ud';

  @override
  String get dailyOsNextRefineNoChanges =>
      'Der kom ingen ændringer i planen. Omformuler det og prøv igen.';

  @override
  String get dailyOsNextRefineOverline => '🎤 FORFINELSE';

  @override
  String get dailyOsNextRefineRevert => 'Tilbagevend';

  @override
  String get dailyOsNextRefineStatusAccepted => 'Låst inde.';

  @override
  String get dailyOsNextRefineStatusDiffReady =>
      'Her er, hvad der ændrede sig.';

  @override
  String get dailyOsNextRefineStatusIdle => 'Tryk for at tale.';

  @override
  String get dailyOsNextRefineStatusListening => 'Lytter...';

  @override
  String get dailyOsNextRefineStatusThinking => '✦ Omarbejder planen...';

  @override
  String get dailyOsNextRefineTitle => 'Forfine planen';

  @override
  String get dailyOsNextRenameFailed => 'Kunne ikke omdøbe — prøve igen.';

  @override
  String get dailyOsNextReviewAddBuffer => 'Tilføj buffer';

  @override
  String get dailyOsNextReviewAddBufferPrompt =>
      'Tilføj en realistisk buffer mellem de planlagte blokke, især omkring overgange og efter krævende arbejde.';

  @override
  String get dailyOsNextReviewAdjust => 'Juster';

  @override
  String get dailyOsNextReviewLooksGood => 'Ser godt ud';

  @override
  String get dailyOsNextReviewMoveLighter => 'Bevæg dig lettere';

  @override
  String get dailyOsNextReviewMoveLighterPrompt =>
      'Flyt det lettere eller lavenergi-arbejde senere, og behold det stærkeste fokusvindue til den mest krævende opgave.';

  @override
  String get dailyOsNextReviewTooMuch => 'For meget';

  @override
  String get dailyOsNextReviewTooMuchPrompt =>
      'Denne plan er for meget for i dag. Reducer belastningen, beskyt luftrummet, og behold kun de vigtigste blokke.';

  @override
  String get dailyOsNextReviewWhyTitle => 'Hvorfor disse kom med';

  @override
  String get dailyOsNextShutdownCarryoverDrop => 'Drop';

  @override
  String get dailyOsNextShutdownCarryoverDropped => 'Droppet';

  @override
  String get dailyOsNextShutdownCarryoverOverline => 'LØB FREMAD';

  @override
  String get dailyOsNextShutdownCarryoverPickDate => 'Vælg en dato';

  @override
  String get dailyOsNextShutdownCarryoverScheduled => 'Planlagt';

  @override
  String get dailyOsNextShutdownCloseDay => 'Luk dagen';

  @override
  String get dailyOsNextShutdownCompletedOverline => 'HVAD DU GJORDE';

  @override
  String get dailyOsNextShutdownMetricEnergy => 'ENERGI';

  @override
  String dailyOsNextShutdownMetricEnergyDelta(String delta) {
    return '$delta vs. uge';
  }

  @override
  String get dailyOsNextShutdownMetricFlow => 'FLOW-SESSIONER';

  @override
  String get dailyOsNextShutdownMetricFocus => 'FOKUSTID';

  @override
  String get dailyOsNextShutdownMetricSwitches => 'KONTEKSTSKIFT';

  @override
  String dailyOsNextShutdownMetricSwitchesAvg(String avg) {
    return 'AVG $avg denne uge';
  }

  @override
  String get dailyOsNextShutdownReflectionOverline => '💬 ENLINJE-REFLEKSION';

  @override
  String get dailyOsNextShutdownReflectionPlaceholder =>
      'f.eks. var morgenen skarp, eftermiddagen trak ud efter kaffen med Sarah trak ud.';

  @override
  String get dailyOsNextShutdownReflectionPrompt =>
      'Hvordan landede dagen i dag? (Dette fodrer morgendagens udkast.)';

  @override
  String get dailyOsNextShutdownReflectionSpeak => 'Sig det';

  @override
  String get dailyOsNextShutdownReflectionSubmit => 'Spring over';

  @override
  String get dailyOsNextShutdownReflectionThanks =>
      'Forstået — fodring i morgen.';

  @override
  String get dailyOsNextShutdownSaveAndClose => 'Gem og luk';

  @override
  String get dailyOsNextShutdownTitle => 'Afslutte dagen';

  @override
  String get dailyOsNextShutdownTomorrowOverline => '✦ TIL I MORGEN';

  @override
  String dailyOsNextStateDueOnDate(String date) {
    return 'To $date';
  }

  @override
  String get dailyOsNextStateDueToday => 'Afleveres i dag';

  @override
  String dailyOsNextStateInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' I gang · $count sessioner',
      one: ' Under udvikling · 1 session',
      zero: 'I gang',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: ' Forsinket · $days dage',
      one: ' Forsinket · 1 dag',
      zero: 'Overdue',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdueOnDate(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: ' Forfalden med $days dage på $date',
      one: ' Forfalden med 1 dag på $date',
      zero: 'Forfalden på $date',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextStateRecurringMissed => 'Tilbagevendende · Missede';

  @override
  String get dailyOsNextTimelineActual => 'Nuværende';

  @override
  String get dailyOsNextTimelineArrange => 'Arranger blokke';

  @override
  String get dailyOsNextTimelineBoth => 'Plan og faktisk';

  @override
  String get dailyOsNextTimelineMeridiemAm => 'AM';

  @override
  String get dailyOsNextTimelineMeridiemAmShort => 'på';

  @override
  String get dailyOsNextTimelineMeridiemPm => 'PM';

  @override
  String get dailyOsNextTimelineMeridiemPmShort => 'pm';

  @override
  String get dailyOsNextTimelinePlanned => 'Plan';

  @override
  String dailyOsNextTimelineSessionOf(int index, int total) {
    return 'Session $index af $total';
  }

  @override
  String get dailyOsNextTimelineShowBoth => 'Showplan og faktisk sammen';

  @override
  String get dailyOsNextTimelineShowPaged => 'Vis swipebar plan og faktisk';

  @override
  String get dailyOsNextTimelineSwipeHint =>
      'Swipe for actual · klem lodret for at zoome ind';

  @override
  String get dailyOsNextTimelineTracked => 'sporet';

  @override
  String dailyOsNextTimeSpentEarlierSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tidligere sessioner',
      one: '1 tidligere session',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextTimeSpentShowLess => 'Vis mindre';

  @override
  String dailyOsNextTimeSpentSummary(String duration, int completedCount) {
    return '$duration · $completedCount færdig';
  }

  @override
  String get dailyOsNextTimeSpentTitle => 'I DAG INDTIL VIDERE';

  @override
  String get dailyOsNextTimeSpentTitlePast => 'TID BRUGT';

  @override
  String get dailyOsNextTriageConfirmDefer => 'Udskudt';

  @override
  String get dailyOsNextTriageConfirmDone => 'Markeret som færdig';

  @override
  String get dailyOsNextTriageConfirmDoNow => 'Færdig nu';

  @override
  String get dailyOsNextTriageConfirmDrop => 'Droppet';

  @override
  String get dailyOsNextTriageConfirmToday => 'Tilføjet til i dag';

  @override
  String get dailyOsNextTriageDefer => 'Udsættelse';

  @override
  String get dailyOsNextTriageDone => 'Færdig';

  @override
  String get dailyOsNextTriageDoNow => 'Gør det nu';

  @override
  String get dailyOsNextTriageDrop => 'Drop';

  @override
  String get dailyOsNextTriageToday => 'I dag';

  @override
  String get dailyOsOnboardingCoachCapture =>
      'Sig, hvad der fanger din opmærksomhed.';

  @override
  String get dailyOsOnboardingCoachDrafting =>
      'Planlæggeren skaber nye opgaver og tilpasser arbejdet til din dag.';

  @override
  String get dailyOsOnboardingCoachReconcile =>
      'Vælg det, der hører til i dag. Nye ting bliver opgaver, når du bygger dagen.';

  @override
  String get dailyOsOnboardingSpotlightAction => 'Prøv det';

  @override
  String get dailyOsOnboardingSpotlightDismiss => 'Ikke nu';

  @override
  String get dailyOsOnboardingSpotlightMessage =>
      'Tryk her og sig, hvad du tænker på — jeg vil gøre det til en opgave og bygge din dag op omkring det.';

  @override
  String get dailyOsOnboardingSpotlightTitle => 'Gør snak til en plan';

  @override
  String get dailyOsSettingsChooseModelDescription =>
      'Overstyr kun planlæggerens tænkemodel.';

  @override
  String get dailyOsSettingsChooseModelTitle => 'Vælg model-overstyring';

  @override
  String get dailyOsSettingsChooseProfileDescription =>
      'Overstyr den fulde inferensprofil for denne planlægger.';

  @override
  String get dailyOsSettingsChooseProfileTitle => 'Vælg Daily OS-profil';

  @override
  String get dailyOsSettingsDataDisclosure =>
      'Daily OS sender relevante opgaver, optagelser, planer, indlærte præferencer og anden samlet planlægningskontekst til den valgte udbyder til behandling.';

  @override
  String get dailyOsSettingsDefaultProfileDescription =>
      'Bruges af Daily OS, medmindre planner-instansen har en override.';

  @override
  String get dailyOsSettingsDefaultProfileMissing => 'Vælg en profil';

  @override
  String get dailyOsSettingsDefaultRestored => 'Daglig OS-standard genoprettet';

  @override
  String get dailyOsSettingsDirectOverrideActive =>
      'Direkte modeloverstyring er aktiv.';

  @override
  String get dailyOsSettingsInferenceTitle => 'Standard inferensprofil';

  @override
  String get dailyOsSettingsInstanceCurrentSetup =>
      'Nuværende planlægningsopsætning';

  @override
  String get dailyOsSettingsInstanceOverrideDescription =>
      'Brug Daily OS\' standardprofil, vælg en profiloverstyring, eller overstyr kun denne planlæggers tankemodel.';

  @override
  String get dailyOsSettingsInstanceOverrideTitle => 'Daglig OS-inferens';

  @override
  String get dailyOsSettingsLocalDisclosure =>
      'Det valgte endepunkt er på denne enhed.';

  @override
  String dailyOsSettingsModelChanged(String model) {
    return 'Daily OS bruger nu $model';
  }

  @override
  String get dailyOsSettingsNameNudgeAction => 'Tilføj navn';

  @override
  String get dailyOsSettingsNameNudgeBody =>
      'At tilføje et foretrukket navn gør check-ins mere personlige. Du kan fortsætte med at planlægge uden det.';

  @override
  String get dailyOsSettingsNameNudgeTitle =>
      'Hvordan bør Daily OS henvende sig til dig?';

  @override
  String dailyOsSettingsProfileChanged(String profile) {
    return 'Daily OS bruger nu $profile';
  }

  @override
  String get dailyOsSettingsProfileOverrideActive => 'Profiloverstyring aktiv';

  @override
  String dailyOsSettingsRemoteDisclosure(String provider, String host) {
    return 'Daily OS sender den samlede planlægningskontekst til $provider på $host for fjernbehandling.';
  }

  @override
  String get dailyOsSettingsSetupAction => 'Opsætning af Daily OS';

  @override
  String get dailyOsSettingsSetupRequiredBody =>
      'Daily OS har brug for dit valg af udbyder, før det kan behandle din planlægningskontekst.';

  @override
  String get dailyOsSettingsSetupRequiredTitle => 'Vælg en inferensprofil';

  @override
  String get dailyOsSettingsSubtitle =>
      'Vælg, hvordan Daily OS adresserer dig, og hvilken slutningsprofil der planlægger dine dage.';

  @override
  String get dailyOsSettingsTitle => 'Daily OS';

  @override
  String get dailyOsSettingsTreeSubtitle =>
      'Planlægning, personalisering og AI-udbyder';

  @override
  String get dailyOsSettingsUseDefault => 'Brug Daily OS som standard';

  @override
  String get dailyOsSettingsUseDefaultDescription =>
      'Følg profilen, der er valgt i Daily OS-indstillingerne.';

  @override
  String get dailyOsTodayButton => 'I dag';

  @override
  String get dashboardActiveLabel => 'Aktiv';

  @override
  String get dashboardActiveSwitchDescription => 'Vist i dashboardlisten';

  @override
  String get dashboardAddChartsTitle => 'Hitlister';

  @override
  String get dashboardAddHabitButton => 'Vaner';

  @override
  String get dashboardAddHabitTitle => 'Vanediagrammer';

  @override
  String get dashboardAddHealthButton => 'Helbred';

  @override
  String get dashboardAddHealthTitle => 'Sundhedskort';

  @override
  String get dashboardAddMeasurementButton => 'Målinger';

  @override
  String get dashboardAddMeasurementTitle => 'Tilføj måleskemaer';

  @override
  String get dashboardAddMeasurementTooltip => 'Tilføj måling';

  @override
  String get dashboardAddSurveyButton => 'Opmålinger';

  @override
  String get dashboardAddSurveyTitle => 'Opmålingskort';

  @override
  String get dashboardAddWorkoutButton => 'Træninger';

  @override
  String get dashboardAddWorkoutTitle => 'Træningsdiagrammer';

  @override
  String get dashboardAggregationApplyImmediately =>
      'Vælg et resumé. Ændringer gælder straks.';

  @override
  String get dashboardAggregationDailyAverage => 'Dagligt gennemsnit';

  @override
  String get dashboardAggregationDailyMax => 'Daglig maks';

  @override
  String get dashboardAggregationDailyTotal => 'Dagligt total';

  @override
  String get dashboardAggregationHourlyTotal => 'Timesamlet';

  @override
  String get dashboardAggregationLabel => 'Aggregeringstype:';

  @override
  String get dashboardAggregationTitle => 'Aggregeringstype';

  @override
  String get dashboardAvailableChartsDescription =>
      'Vælg en type, vælg et eller flere diagrammer, og tilføj dem derefter.';

  @override
  String get dashboardAvailableChartsTitle => 'Tilføj diagrammer efter type';

  @override
  String get dashboardCategoryLabel => 'Kategori';

  @override
  String get dashboardChartNoData => 'Ingen data i dette område';

  @override
  String get dashboardConfigurationDescription =>
      'Gem dashboardet, og kopier derefter dets JSON-konfiguration.';

  @override
  String get dashboardConfigurationTitle => 'Eksportkonfiguration';

  @override
  String get dashboardCopyHint => 'Gem & Kopier dashboard-konfiguration';

  @override
  String get dashboardCopyLabel => 'Gem og kopier JSON';

  @override
  String get dashboardCurrentChartsDescription =>
      'Træk for at omorganisere. Målediagrammer kan vælges for at ændre deres aggregering.';

  @override
  String get dashboardCurrentChartsTitle => 'Diagrammer på dette dashboard';

  @override
  String get dashboardDeleteConfirm => 'JA, SLET DETTE DASHBOARD';

  @override
  String get dashboardDeleteHint => 'Slet dashboardet';

  @override
  String get dashboardDeleteQuestion => 'Vil du slette dette dashboard?';

  @override
  String get dashboardDescriptionLabel => 'Beskrivelse (valgfrit)';

  @override
  String get dashboardEditAggregationLabel => 'Redigeringsaggregering';

  @override
  String get dashboardHealthBloodPressure => 'Blodtryk';

  @override
  String get dashboardHealthDiastolic => 'Diastolisk';

  @override
  String get dashboardHealthSystolic => 'Systolisk';

  @override
  String dashboardMeasurementAddButtonWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' Tilføj $count diagrammer',
      one: 'Tilføj 1 diagram',
    );
    return '$_temp0';
  }

  @override
  String dashboardMeasurementAggregationFor(String name) {
    return 'Diagramtilstand for $name';
  }

  @override
  String get dashboardMeasurementAggregationHelp =>
      'Vælg måleskemaer. Juster diagramtilstand på udvalgte rækker, før du tilføjer.';

  @override
  String get dashboardNameLabel => 'Dashboard-navn';

  @override
  String get dashboardNoChartsAdded =>
      'Ingen skemaer tilføjet endnu. Tilføj en nedenfor.';

  @override
  String get dashboardNoHabitsForCharts =>
      'Skab først en vane for at tilføje vanediagrammer.';

  @override
  String get dashboardNoMeasurablesForCharts =>
      'Lav en målbar første metode til at tilføje målediagrammer.';

  @override
  String get dashboardNotFound => 'Instrumentbræt ikke fundet';

  @override
  String get dashboardPrivateLabel => 'Privat';

  @override
  String get dashboardRemoveChartLabel => 'Fjern skemaet';

  @override
  String get dashboardReorderChartLabel => 'Omarranger kort';

  @override
  String get dashboardTakeSurveyTooltip => 'Tag en undersøgelse';

  @override
  String get defaultLanguage => 'Standardsprog';

  @override
  String get deleteButton => 'Slet';

  @override
  String get deleteDeviceLabel => 'Slet enhed';

  @override
  String get designSystemActionVariantTitle => 'Med handling';

  @override
  String get designSystemActivatedLabel => 'Aktiveret';

  @override
  String get designSystemAvatarAwayLabel => 'Væk';

  @override
  String get designSystemAvatarBusyLabel => 'Travlt';

  @override
  String get designSystemAvatarConnectedLabel => 'Forbundet';

  @override
  String get designSystemAvatarEnabledLabel => 'Aktiveret';

  @override
  String get designSystemAvatarSizeMatrixTitle => 'Størrelsesmatrix';

  @override
  String get designSystemAvatarStatusMatrixTitle => 'Statusmatrix';

  @override
  String get designSystemBackLabel => 'Tilbage';

  @override
  String get designSystemBreadcrumbCurrentLabel => 'Brødkrummer';

  @override
  String get designSystemBreadcrumbDesignSystemLabel => 'Designsystem';

  @override
  String get designSystemBreadcrumbHomeLabel => 'Hjem';

  @override
  String get designSystemBreadcrumbMobileLabel => 'Mobil';

  @override
  String get designSystemBreadcrumbProjectsLabel => 'Projekter';

  @override
  String get designSystemBreadcrumbSampleLabel => 'Brødkrumme';

  @override
  String get designSystemBreadcrumbTrailTitle => 'Brødkrummesti';

  @override
  String get designSystemCalendarPickerLabel => 'Kalendervælger';

  @override
  String get designSystemCalendarViewsTitle => 'Kalendervisninger';

  @override
  String get designSystemCaptionDescriptionSample =>
      'Fjerner alle brugere, der ikke har været publiceret i dette projekt. Tilføj brugere for at publicere det igen.';

  @override
  String get designSystemCaptionIconLeftLabel => 'Venstre ikon';

  @override
  String get designSystemCaptionIconTopLabel => 'Topikon';

  @override
  String get designSystemCaptionNoIconLabel => 'Intet ikon';

  @override
  String get designSystemCaptionTitleSample => 'Billedtekst titel';

  @override
  String get designSystemCaptionVariantsTitle => 'Billedtekstvarianter';

  @override
  String get designSystemCaptionWithActionsLabel => 'Med handlinger';

  @override
  String get designSystemCaptionWithoutActionsLabel => 'Uden handlinger';

  @override
  String get designSystemCheckboxLabel => 'Afkrydsningsboks';

  @override
  String get designSystemContextMenuDeleteLabel => 'Slet';

  @override
  String get designSystemContextMenuVariantsTitle => 'Kontekstmenu-varianter';

  @override
  String get designSystemCountdownVariantTitle => 'Med nedtælling';

  @override
  String get designSystemDateCardsTitle => 'Datokort';

  @override
  String get designSystemDefaultLabel => 'Default';

  @override
  String get designSystemDisabledLabel => 'Handicappet';

  @override
  String get designSystemDividerLabelText => 'Divider-label';

  @override
  String get designSystemDropdownComboboxTitle => 'Combobox';

  @override
  String get designSystemDropdownFieldLabel => 'Label';

  @override
  String get designSystemDropdownInputLabel => 'Input';

  @override
  String get designSystemDropdownListTitle => 'Rullemenu';

  @override
  String get designSystemDropdownMultiselectInputLabel => 'Udvalgte hold';

  @override
  String get designSystemDropdownMultiselectTitle => 'Multiselect';

  @override
  String get designSystemDropdownOptionAnalytics => 'Analyse';

  @override
  String get designSystemDropdownOptionBackend => 'Backend';

  @override
  String get designSystemDropdownOptionDesign => 'Design';

  @override
  String get designSystemDropdownOptionFrontend => 'Frontend';

  @override
  String get designSystemDropdownOptionGrowth => 'Vækst';

  @override
  String get designSystemDropdownOptionMobile => 'Mobil';

  @override
  String get designSystemDropdownOptionQa => 'QA';

  @override
  String get designSystemErrorLabel => 'Fejl';

  @override
  String get designSystemFileUploadClickLabel => 'Klik for at uploade';

  @override
  String get designSystemFileUploadCompleteLabel => 'Komplet';

  @override
  String get designSystemFileUploadDefaultLabel => 'Default';

  @override
  String get designSystemFileUploadDragLabel => 'eller træk og slip';

  @override
  String get designSystemFileUploadDropZoneSectionTitle => 'Dropzone';

  @override
  String get designSystemFileUploadErrorLabel => 'Fejl';

  @override
  String get designSystemFileUploadFailedText => 'Upload mislykkedes';

  @override
  String get designSystemFileUploadHintText =>
      'SVG, PNG, JPG eller GIF (maks. 800×400px)';

  @override
  String get designSystemFileUploadHoverLabel => 'Hover';

  @override
  String get designSystemFileUploadItemSectionTitle => 'Arkivposter';

  @override
  String get designSystemFileUploadRetryLabel => 'Nyt forsøg';

  @override
  String get designSystemFileUploadUploadingLabel => 'Upload';

  @override
  String get designSystemFilledLabel => 'Fyldt';

  @override
  String get designSystemHeaderApiDocumentationLabel => 'API-dokumentation';

  @override
  String get designSystemHeaderBackActionLabel => 'Tilbage';

  @override
  String get designSystemHeaderDesktopSectionTitle => 'Skrivebord';

  @override
  String get designSystemHeaderHelpActionLabel => 'Hjælp';

  @override
  String get designSystemHeaderMobileSectionTitle => 'Mobil';

  @override
  String get designSystemHeaderNotificationsActionLabel => 'Notifikationer';

  @override
  String get designSystemHeaderSearchActionLabel => 'Søgning';

  @override
  String get designSystemHorizontalLabel => 'Horisontalt';

  @override
  String get designSystemHoverLabel => 'Hover';

  @override
  String get designSystemInfoLabel => 'Info';

  @override
  String get designSystemInputErrorSample => 'Dette felt er påkrævet';

  @override
  String get designSystemInputHelperSample => 'Indtast dit navn';

  @override
  String get designSystemInputHintSample => 'Pladsholder...';

  @override
  String get designSystemInputLabelSample => 'Label';

  @override
  String get designSystemInputVariantsTitle => 'Inputvarianter';

  @override
  String get designSystemInputWithErrorLabel => 'Med fejl';

  @override
  String get designSystemInputWithHelperLabel => 'Med hjælpetekst';

  @override
  String get designSystemInputWithIconsLabel => 'Med ikoner';

  @override
  String get designSystemListItemActivatedLabel => 'Aktiveret';

  @override
  String get designSystemListItemOneLineLabel => 'Én linje';

  @override
  String get designSystemListItemSubtitleSample => 'Undertekst';

  @override
  String get designSystemListItemTitleSample => 'Titel';

  @override
  String get designSystemListItemTwoLinesLabel => 'To linjer';

  @override
  String get designSystemListItemVariantsTitle => 'Listevarianter';

  @override
  String get designSystemListItemWithDividerLabel => 'Med skillevægge';

  @override
  String get designSystemMediumLabel => 'Medium';

  @override
  String designSystemMyDailyDurationHoursMinutesCompact(
    int hours,
    int minutes,
  ) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get designSystemNavigationCollapsedLabel => 'Kollapsede';

  @override
  String get designSystemNavigationDailyFilterSectionTitle => 'Dagligt filter';

  @override
  String get designSystemNavigationExpandedLabel => 'Udvidet';

  @override
  String get designSystemNavigationFilterByBlockLabel => 'Filter efter blok';

  @override
  String get designSystemNavigationHikingLabel => 'Vandreture';

  @override
  String get designSystemNavigationHolidayLabel => 'Ferie';

  @override
  String get designSystemNavigationInsightsLabel => 'Indsigter';

  @override
  String get designSystemNavigationLottiTasksLabel => 'Lotti-opgaver';

  @override
  String get designSystemNavigationMyDailyLabel => 'Min daglige';

  @override
  String get designSystemNavigationNewLabel => 'Ny';

  @override
  String get designSystemNavigationPlaceholderLabel => 'Pladsholder';

  @override
  String get designSystemNavigationSidebarSectionTitle => 'Sidebar-varianter';

  @override
  String get designSystemNavigationSubComponentsSectionTitle =>
      'Underkomponenter';

  @override
  String get designSystemNavigationTabBarSectionTitle => 'Tab-bjælkevarianter';

  @override
  String get designSystemPressedLabel => 'Presset';

  @override
  String get designSystemProgressBarChunkyLabel => 'Chunky';

  @override
  String get designSystemProgressBarLabelAndPercentageLabel =>
      'Label + Procent';

  @override
  String get designSystemProgressBarLabelOnlyLabel => 'Kun label';

  @override
  String get designSystemProgressBarOffLabel => 'Slukket';

  @override
  String get designSystemProgressBarPercentageOnlyLabel => 'Procentdel';

  @override
  String get designSystemProgressBarQuestBarLabel => 'Quest-bar';

  @override
  String get designSystemProgressBarQuestLabel => 'Mega-præmiemærke';

  @override
  String get designSystemProgressBarSampleLabel => 'Fremgangsbar-etiket';

  @override
  String get designSystemRadioButtonLabel => 'Radioknap';

  @override
  String get designSystemScrollbarSizesTitle => 'Scrollbar-størrelser';

  @override
  String get designSystemSearchClearLabel => 'Ryd søgning';

  @override
  String get designSystemSearchFilledText => 'Lotti-søgning';

  @override
  String get designSystemSearchHintLabel => 'Typebruger';

  @override
  String get designSystemSelectedLabel => 'Udvalgte';

  @override
  String get designSystemSizeScaleTitle => 'Størrelsesskala';

  @override
  String get designSystemSmallLabel => 'Lille';

  @override
  String get designSystemSpinnerPlainLabel => 'Slette';

  @override
  String get designSystemSpinnerSkeletonPulseLabel => 'Pulse';

  @override
  String get designSystemSpinnerSkeletonsTitle => 'Skeletter';

  @override
  String get designSystemSpinnerSkeletonWaveLabel => 'Bølge';

  @override
  String get designSystemSpinnerSpinnersTitle => 'Spinnere';

  @override
  String get designSystemSpinnerTrackLabel => 'Med skinner';

  @override
  String designSystemSplitButtonDropdownSemantics(String label) {
    return 'Åbn $label-muligheder';
  }

  @override
  String get designSystemStateMatrixTitle => 'Tilstandsmatrix';

  @override
  String get designSystemSuccessLabel => 'Succes';

  @override
  String get designSystemTabBarTitle => 'Tab-bar';

  @override
  String get designSystemTabPendingLabel => 'Afventer';

  @override
  String get designSystemTaskListBlockedLabel => 'Blokeret';

  @override
  String get designSystemTaskListDefaultLabel => 'Default';

  @override
  String get designSystemTaskListHoverLabel => 'Hover';

  @override
  String get designSystemTaskListItemSectionTitle => 'Opgaveliste-varianter';

  @override
  String get designSystemTaskListOnHoldLabel => 'På pause';

  @override
  String get designSystemTaskListOpenLabel => 'Åben';

  @override
  String get designSystemTaskListPressedLabel => 'Presset';

  @override
  String get designSystemTaskListSampleTime => '8:00-9:30';

  @override
  String get designSystemTaskListSampleTitle => 'Brugertest';

  @override
  String get designSystemTaskListWithDividerLabel => 'Med skillevægge';

  @override
  String get designSystemTextareaErrorSample => 'Dette felt er påkrævet';

  @override
  String get designSystemTextareaHelperSample => 'Indtast din besked her';

  @override
  String get designSystemTextareaHintSample => 'Skriv noget...';

  @override
  String get designSystemTextareaLabelSample => 'Label';

  @override
  String get designSystemTextareaVariantsTitle => 'Tekstområdevarianter';

  @override
  String get designSystemTextareaWithCounterLabel => 'Med tæller';

  @override
  String get designSystemTextareaWithErrorLabel => 'Med fejl';

  @override
  String get designSystemTextareaWithHelperLabel => 'Med hjælpetekst';

  @override
  String get designSystemTimePickerFormatsTitle => 'Tidsformater';

  @override
  String get designSystemTimePickerTwelveHourLabel => '12-timers';

  @override
  String get designSystemTimePickerTwentyFourHourLabel => '24 timer i døgnet';

  @override
  String get designSystemTitleOnlyVariantTitle => 'Kun titelvariant';

  @override
  String get designSystemToastDetailsLabel => 'Meddelelsesdetaljer';

  @override
  String get designSystemToggleLabel => 'Toggle-label';

  @override
  String get designSystemTooltipIconMessageSample =>
      'Nyttige oplysninger om dette felt';

  @override
  String get designSystemTooltipIconVariantsTitle => 'Tooltip-ikon';

  @override
  String get designSystemUndoLabel => 'Fortryd';

  @override
  String get designSystemVariantMatrixTitle => 'Variantmatrix';

  @override
  String get designSystemVerticalLabel => 'Vertikal';

  @override
  String get designSystemWarningLabel => 'Advarsel';

  @override
  String get designSystemWeeklyCalendarLabel => 'Ugentlig kalender';

  @override
  String get designSystemWithLabelLabel => 'Med label';

  @override
  String get desktopEmptyStateSelectDashboard =>
      'Vælg et dashboard for at se detaljer';

  @override
  String get desktopEmptyStateSelectProject =>
      'Vælg et projekt for at se detaljer';

  @override
  String get desktopEmptyStateSelectTask => 'Vælg en opgave for at se detaljer';

  @override
  String deviceDeletedSuccess(String deviceName) {
    return 'Enhed $deviceName slettet med succes';
  }

  @override
  String deviceDeleteFailed(String error) {
    return 'Manglende sletning af enhed: $error';
  }

  @override
  String get doneButton => 'Færdig';

  @override
  String get editMenuTitle => 'Redigering';

  @override
  String get editorDiscardChanges => 'Smid ændringer';

  @override
  String get editorInsertDivider => 'Indsæt skillevæg';

  @override
  String get editorMoreFormatting => 'Mere formatering';

  @override
  String get editorPlaceholder => 'Indtast noter...';

  @override
  String get embeddingSelectAll => 'Vælg alle';

  @override
  String get embeddingUnselectAll => 'Fravælg alle';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Vælg mellem færdiglavede prompt-skabeloner';

  @override
  String get enterCategoryName => 'Indtast kategorinavn';

  @override
  String get entryActions => 'Handlinger';

  @override
  String get entryLabelsActionSubtitle =>
      'Tildel etiketter til at organisere denne post';

  @override
  String get entryLabelsActionTitle => 'Etiketter';

  @override
  String get entryLabelsEditTooltip => 'Rediger etiketter';

  @override
  String get entryLabelsHeaderTitle => 'Etiketter';

  @override
  String get entryLabelsNoLabels => 'Ingen etiketter tildelt';

  @override
  String get entryTypeLabelAiResponse => 'AI-respons';

  @override
  String get entryTypeLabelChecklist => 'Tjekliste';

  @override
  String get entryTypeLabelChecklistItem => 'To Do';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Habit';

  @override
  String get entryTypeLabelJournalAudio => 'Lyd';

  @override
  String get entryTypeLabelJournalEntry => 'Tekst';

  @override
  String get entryTypeLabelJournalEvent => 'Begivenhed';

  @override
  String get entryTypeLabelJournalImage => 'Foto';

  @override
  String get entryTypeLabelMeasurementEntry => 'Målt';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Helbred';

  @override
  String get entryTypeLabelSurveyEntry => 'Opmåling';

  @override
  String get entryTypeLabelTask => 'Opgave';

  @override
  String get entryTypeLabelWorkoutEntry => 'Træning';

  @override
  String get eventNameLabel => 'Begivenhed:';

  @override
  String get eventsAddCoverPhoto => 'Tilføj forsidefoto';

  @override
  String get eventsAddLabel => 'Tilføj';

  @override
  String get eventsChangeCover => 'Skift omslag';

  @override
  String get eventsDeleteEvent => 'Slet-begivenhed';

  @override
  String get eventsFilterAll => 'Alle';

  @override
  String eventsMetricPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String eventsMetricTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opgaver',
      one: '1 opgave',
    );
    return '$_temp0';
  }

  @override
  String get eventsNewEvent => 'Ny begivenhed';

  @override
  String get eventsPageTitle => 'Begivenheder';

  @override
  String get eventsPhotosSection => 'Fotos';

  @override
  String get eventsRecapAwaitingContent =>
      'Tilføj et foto eller en note, og resuméet vil dukke op her.';

  @override
  String get eventsRecapUnavailable => 'Kunne ikke indlæse recapet.';

  @override
  String get eventsRegenerateSummary => 'Regenereringsresumé';

  @override
  String get eventsSearchHint => 'Søgebegivenheder';

  @override
  String get eventsSectionUpcoming => 'Kommende';

  @override
  String get eventsStatusCancelled => 'Aflyst';

  @override
  String get eventsStatusCompleted => 'Færdiggjort';

  @override
  String get eventsStatusMissed => 'Missede';

  @override
  String get eventsStatusOngoing => 'Løbende';

  @override
  String get eventsStatusPlanned => 'Planlagt';

  @override
  String get eventsStatusPostponed => 'Udsat';

  @override
  String get eventsStatusRescheduled => 'Omlagt';

  @override
  String get eventsStatusTentative => 'Forsøg';

  @override
  String get eventsSummaryTitle => 'Resumé';

  @override
  String get eventsTasksEmpty =>
      'Link til en forberedelses- eller opfølgende opgave';

  @override
  String get eventsTasksSection => 'Opgaver';

  @override
  String get eventsTimelineEmpty => 'Tilføj fotos, noter eller en talebesked';

  @override
  String get eventsTimelineSection => 'Tidslinje';

  @override
  String get eventsTitleHint => 'Begivenhedstitel';

  @override
  String get eventsVoiceNote => 'Stemmenote';

  @override
  String get favoriteLabel => 'Favorit';

  @override
  String get fileMenuNewEllipsis => 'Ny ...';

  @override
  String get fileMenuNewEntry => 'Ny tilføjelse';

  @override
  String get fileMenuNewScreenshot => 'Skærmbillede';

  @override
  String get fileMenuNewTask => 'Opgave';

  @override
  String get fileMenuTitle => 'Fil';

  @override
  String get filterSelectionNoMatches => 'Ingen kampe';

  @override
  String get geminiThinkingModeHighDescription =>
      'Dybeste ræsonnement; kan øge latenstid og omkostninger.';

  @override
  String get geminiThinkingModeHighLabel => 'Høj';

  @override
  String get geminiThinkingModeLowDescription =>
      'Lav begrundelse for hurtige daglige prompts.';

  @override
  String get geminiThinkingModeLowLabel => 'Lavt';

  @override
  String get geminiThinkingModeMediumDescription =>
      'Afbalanceret ræsonnement for mere omhyggelige svar.';

  @override
  String get geminiThinkingModeMediumLabel => 'Medium';

  @override
  String get geminiThinkingModeMinimalDescription =>
      'Hurtigste indstilling; Tvillingerne tænker måske stadig kort over komplekse prompts.';

  @override
  String get geminiThinkingModeMinimalLabel => 'Minimal';

  @override
  String get generateCoverArt => 'Generer coverkunst';

  @override
  String get generateCoverArtSubtitle =>
      'Opret billede ud fra stemmebeskrivelse';

  @override
  String get goMenuTitle => 'Gå';

  @override
  String get habitActiveFromLabel => 'Startdato';

  @override
  String get habitActiveSwitchDescription => 'Vist på Vaner-siden';

  @override
  String get habitArchivedLabel => 'Arkiveret';

  @override
  String get habitCategoryHint => 'Vælg en kategori';

  @override
  String get habitCategoryLabel => 'Kategori';

  @override
  String get habitCloseCompletionLabel => 'Tæt vane-fuldendelse';

  @override
  String habitCompleteSemanticLabel(String habit) {
    return 'Record $habit';
  }

  @override
  String get habitCompletionStatusCompleted => 'Færdiggjort';

  @override
  String get habitCompletionStatusFailed => 'Mislykkedes';

  @override
  String get habitCompletionStatusOpen => 'Åben';

  @override
  String get habitCompletionStatusSkipped => 'Sprunget over';

  @override
  String get habitDashboardHint => 'Vælg et dashboard';

  @override
  String get habitDashboardLabel => 'Dashboard (valgfrit)';

  @override
  String habitDayStatusSemantic(String habit, String status) {
    return '$habit, $status';
  }

  @override
  String get habitDeleteConfirm => 'JA, SLET DENNE VANE';

  @override
  String get habitDeleteQuestion => 'Vil du slette denne vane?';

  @override
  String habitHeatmapDaySemantic(String date, int done, int total) {
    return '$date, $done af $total færdig';
  }

  @override
  String get habitLogOtherDayHint => 'Hold for at logge en anden dag';

  @override
  String get habitNotRecordedLabel => 'Ikke registreret';

  @override
  String get habitPriorityLabel => 'Prioritet';

  @override
  String get habitsAboveGoal => 'På banen';

  @override
  String habitsActiveHabitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktive vaner',
      one: '1 aktiv vane',
    );
    return '$_temp0';
  }

  @override
  String get habitsAllDoneToday => 'Alt færdigt i dag';

  @override
  String get habitsChartUseDynamicBaseline => 'Brug dynamisk grundlinje';

  @override
  String get habitsChartUseZeroBaseline => 'Brug nulgrundlinje';

  @override
  String get habitsCompletedHeader => 'Færdiggjort';

  @override
  String get habitsCompletionRateTitle => 'Gennemførelsesrate';

  @override
  String get habitsConsistencyTitle => 'Konsistens';

  @override
  String habitsDayFailedPercent(int percent) {
    return '$percent% registrerede fejl';
  }

  @override
  String habitsDaySkippedPercent(int percent) {
    return '$percent% sprunget over';
  }

  @override
  String habitsDaySuccessfulPercent(int percent) {
    return '$percent% succesfuld';
  }

  @override
  String get habitsDoneTodayLabel => 'Udført i dag';

  @override
  String get habitSectionOptionsTitle => 'Muligheder';

  @override
  String get habitSectionScheduleTitle => 'Tidsplan';

  @override
  String get habitsFilterAll => 'Alle';

  @override
  String get habitsFilterCompleted => 'Færdig';

  @override
  String get habitsFilterOpenNow => 'To';

  @override
  String get habitsFilterPendingLater => 'Senere';

  @override
  String get habitsGoalLineLabel => 'Mål';

  @override
  String get habitsHeatmapEmpty =>
      'Tilføj en vane for at begynde at opbygge din konsistens';

  @override
  String get habitsHeatmapLess => 'Mindre';

  @override
  String get habitsHeatmapMore => 'Mere';

  @override
  String get habitShowAlertAtLabel => 'Vis alarm på';

  @override
  String get habitShowFromLabel => 'Udsendelse fra';

  @override
  String habitsLaggardHint(String habit, int kept, int active) {
    return '$habit — beholdt $kept af $active';
  }

  @override
  String get habitsOpenHeader => 'Afleveres nu';

  @override
  String get habitsPendingLaterHeader => 'Senere i dag';

  @override
  String habitsPointsToGoal(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points point til mål',
      one: '1 point til mål',
    );
    return '$_temp0';
  }

  @override
  String get habitsRecordButton => 'Rekord';

  @override
  String get habitsRollingAverageLabel => '7-dages gennemsnit';

  @override
  String get habitsStartStreakToday => 'Start en stime i dag';

  @override
  String habitsStreakLongCount(int count) {
    return '$count på en 7-dages stime';
  }

  @override
  String habitsStreakShortCount(int count) {
    return '$count på en 3-dages stime';
  }

  @override
  String get habitsTapForBreakdown => 'Tap en dag for opdelingen';

  @override
  String habitsToGoCount(int count) {
    return '$count til at tage af sted';
  }

  @override
  String habitStreakDaysSemantic(int count) {
    return '$count-dagsstime';
  }

  @override
  String get habitsVsPreviousWeek => 'vs forrige uge';

  @override
  String get helpMenuCommandPalette => 'Kommandopalette...';

  @override
  String get helpMenuKeyboardShortcuts => 'Tastaturgenveje...';

  @override
  String get helpMenuTitle => 'Hjælp';

  @override
  String get imageGenerationError => 'Kunne ikke generere billede';

  @override
  String get imageGenerationGenerating => 'Genererer billede...';

  @override
  String get imageGenerationProviderRejectedTitle =>
      'Billedleverandøren afviste denne anmodning';

  @override
  String imageGenerationWithReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' Brug af $count referencebilleder',
      one: ' Brug af 1 referencebillede',
      zero: 'Ingen referencebilleder',
    );
    return '$_temp0';
  }

  @override
  String get imagePromptGenerationCardTitle => 'AI billedprompt';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Billedprompt kopieret til clipboard';

  @override
  String get imagePromptGenerationCopyButton => 'Kopier prompt';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Kopier billedprompten til udklipsholderen';

  @override
  String get imagePromptGenerationExpandTooltip => 'Vis fuld prompt';

  @override
  String get imagePromptGenerationFullPromptLabel => 'Fuld billedprompt:';

  @override
  String get images => 'Billeder';

  @override
  String get imageViewerDownloadFailed => 'Kunne ikke gemme billedet';

  @override
  String get imageViewerDownloadingTooltip => 'Gem billede';

  @override
  String get imageViewerDownloadPermissionDenied =>
      'Fotoadgang nægtet — aktiver det i Indstillinger';

  @override
  String imageViewerDownloadSaved(String fileName) {
    return 'Reddet $fileName';
  }

  @override
  String get imageViewerDownloadSavedToGallery => 'Gemt som fotos';

  @override
  String get imageViewerDownloadTooltip => 'Download billede';

  @override
  String get inactiveLabel => 'Inaktiv';

  @override
  String get inactiveSwitchDescription =>
      'Kan vælges til nye indførsler, når den er på';

  @override
  String get inferenceProfileChooseModelTitle => 'Vælg en model';

  @override
  String get inferenceProfileChooseTitle => 'Vælg en inferensprofil';

  @override
  String get inferenceProfileCreateTitle => 'Opret profil';

  @override
  String get inferenceProfileDescriptionLabel => 'Beskrivelse';

  @override
  String get inferenceProfileDesktopOnly => 'Kun skrivebord';

  @override
  String get inferenceProfileDesktopOnlyDescription =>
      'Kun tilgængelig på desktopplatforme (f.eks. til lokale modeller)';

  @override
  String inferenceProfileDetailLoadError(String error) {
    return 'Kunne ikke indlæse profil: $error';
  }

  @override
  String get inferenceProfileDetailNotFound => 'Profil ikke fundet';

  @override
  String get inferenceProfileEditTitle => 'Rediger profil';

  @override
  String get inferenceProfileImageGeneration => 'Billedgenerering';

  @override
  String get inferenceProfileImageRecognition => 'Billedgenkendelse';

  @override
  String get inferenceProfileModelUnavailable =>
      'Model utilgængelig — dens udbyder kan være blevet fjernet';

  @override
  String get inferenceProfileNameLabel => 'Profilnavn';

  @override
  String get inferenceProfileNameRequired => 'Et profilnavn er påkrævet';

  @override
  String get inferenceProfilePinnedHostHelper =>
      'Når den er sat, kører kun denne enhed automatisk slutning for synkroniserede lydposter, der bruger denne profil.';

  @override
  String get inferenceProfilePinnedHostLabel => 'Fastgjort enhed';

  @override
  String get inferenceProfilePinnedHostNoEligibleNodes =>
      'Ingen kendte enheder reklamerer for de udbydere, denne profil bruger. Åbn Sync-nodeindstillinger på målenheden.';

  @override
  String get inferenceProfilePinnedHostNoneHelper =>
      'Synkroniserede lydposter transskriberes ikke automatisk, når ingen enhed er fastgjort.';

  @override
  String get inferenceProfilePinnedHostNoneLabel =>
      'Ikke fastlåst (ingen auto-trigger)';

  @override
  String get inferenceProfilePinnedHostThisDeviceSuffix => ' (denne enhed)';

  @override
  String get inferenceProfileSaveButton => 'Gem';

  @override
  String get inferenceProfileSelectModel => 'Vælg en model...';

  @override
  String get inferenceProfileSelectProfile => 'Vælg en profil...';

  @override
  String get inferenceProfilesEmpty => 'Ingen slutningsprofiler endnu';

  @override
  String inferenceProfileSkillModelRequired(String slotName) {
    return 'Kræver at $slotName-modellen sættes';
  }

  @override
  String get inferenceProfileSkillsSection => 'Automatiserede færdigheder';

  @override
  String inferenceProfileSkillUsesModel(String slotName) {
    return 'Bruger $slotName-modellen';
  }

  @override
  String get inferenceProfilesTitle => 'Inferensprofiler';

  @override
  String get inferenceProfileThinking => 'Tænkning';

  @override
  String get inferenceProfileThinkingHighEnd => 'Tænkning (High-End)';

  @override
  String get inferenceProfileThinkingRequired => 'En tænkemodel er nødvendig';

  @override
  String get inferenceProfileTranscription => 'Udskrift';

  @override
  String get inferenceProfileUnavailable => 'Inferensprofil ikke tilgængelig';

  @override
  String get inputDataTypeAudioFilesDescription => 'Brug lydfiler som input';

  @override
  String get inputDataTypeAudioFilesName => 'Lydfiler';

  @override
  String get inputDataTypeImagesDescription => 'Brug billeder som input';

  @override
  String get inputDataTypeImagesName => 'Billeder';

  @override
  String get inputDataTypeTaskDescription =>
      'Brug den aktuelle opgave som input';

  @override
  String get inputDataTypeTaskName => 'Opgave';

  @override
  String get inputDataTypeTasksListDescription =>
      'Brug en liste over opgaver som input';

  @override
  String get inputDataTypeTasksListName => 'Opgaveliste';

  @override
  String get insightsChartCompareCaption =>
      'Denne periode sammenlignet med den forrige';

  @override
  String get insightsChartCompareCaptionPartial =>
      'Denne periode indtil videre sammenlignet med den forrige';

  @override
  String get insightsChartCompareHint =>
      'Sammenligning vist i tabellen nedenfor';

  @override
  String get insightsChartCumulativeCaption => 'Løbende total over rækkevidden';

  @override
  String get insightsChartCumulativeShort =>
      'Der er endnu ikke nok dage til en løbende total';

  @override
  String get insightsChartDailyCaption => 'Tid pr. dag';

  @override
  String get insightsChartHourlyCaption => 'Tid pr. time';

  @override
  String get insightsChartPerDay => 'Pr. dag';

  @override
  String get insightsChartPerHour => 'Pr. time';

  @override
  String get insightsChartPerWeek => 'Pr. uge';

  @override
  String get insightsChartRunningTotal => 'Løbende total';

  @override
  String get insightsChartTitle => 'Tid efter kategori';

  @override
  String get insightsChartWeeklyCaption => 'Tid pr. uge';

  @override
  String get insightsChooseFocusCategories => 'Vælg fokuskategorier';

  @override
  String get insightsCompare => 'Sammenlign';

  @override
  String get insightsCompareFullPeriod => 'Fuld periode';

  @override
  String get insightsComparePrevious => 'Tidligere';

  @override
  String get insightsCompareSameDays => 'Samme dage';

  @override
  String get insightsCompareTooltip => 'Sammenlign med den forrige periode';

  @override
  String get insightsCompareVs => 'vs';

  @override
  String get insightsDeletedCategory => 'Slettet kategori';

  @override
  String get insightsDeltaNew => 'Ny';

  @override
  String get insightsEmptyBody =>
      'Tiden du holder styr på på poster og opgaver vil dukke op her.';

  @override
  String get insightsEmptyChart => 'Ingen data i dette område';

  @override
  String get insightsEmptyPreviousPeriod => 'Vis den forrige periode';

  @override
  String get insightsEmptyShowYear => 'Se i år';

  @override
  String get insightsEmptyTitle => 'Ingen sporet tid i dette område';

  @override
  String get insightsFocusCategoriesEmpty => 'Ingen aktive kategorier endnu.';

  @override
  String get insightsFocusCategoriesTitle => 'Fokuskategorier';

  @override
  String get insightsKpiFocus => 'FOKUS';

  @override
  String get insightsKpiFocusHelp => 'Kategorier, du ser';

  @override
  String get insightsKpiOther => 'ANDET';

  @override
  String get insightsKpiOtherHelp => 'Alt andet';

  @override
  String insightsKpiTopCategory(String category, String share) {
    return 'De fleste på $category · $share';
  }

  @override
  String get insightsKpiTotal => 'SAMLET';

  @override
  String get insightsLoadError => 'Kunne ikke indlæse tidsdata';

  @override
  String get insightsOtherCategories => 'Andet';

  @override
  String get insightsPartialWeek => 'Delvis uge';

  @override
  String get insightsPeriodDay => 'Dag';

  @override
  String get insightsPeriodJump => 'Spring til en dato';

  @override
  String get insightsPeriodMonth => 'Måned';

  @override
  String get insightsPeriodNext => 'Næste periode';

  @override
  String get insightsPeriodPrevious => 'Tidligere periode';

  @override
  String get insightsPeriodQuarter => 'Quarter';

  @override
  String get insightsPeriodToDateSuffix => 'indtil videre';

  @override
  String get insightsPeriodWeek => 'Uge';

  @override
  String get insightsPeriodYear => 'År';

  @override
  String get insightsRangeMonthToDate => 'Denne måned indtil videre';

  @override
  String get insightsRangeMtd => 'Denne måned';

  @override
  String get insightsRangeYearToDate => 'Indtil videre i år';

  @override
  String get insightsRangeYtd => 'I år';

  @override
  String get insightsRefreshError =>
      'Kunne ikke opdatere — viser de sidst indlæste data';

  @override
  String get insightsTableAvgPerDay => 'GENNEMSNIT/DAG';

  @override
  String get insightsTableCategory => 'KATEGORI';

  @override
  String get insightsTableCompareNote =>
      'Ændring i forhold til den forrige periode';

  @override
  String get insightsTableCurrent => 'NUVÆRENDE';

  @override
  String get insightsTableDelta => 'Forandring';

  @override
  String get insightsTablePrevious => 'TIDLIGERE';

  @override
  String get insightsTableShare => 'DEL';

  @override
  String get insightsTableTotal => 'SAMLET';

  @override
  String get insightsTimeAnalysisTitle => 'Tidsanalyse';

  @override
  String get insightsUncategorized => 'Ukategoriseret';

  @override
  String get journalCopyImageLabel => 'Kopier billedet';

  @override
  String get journalDateFromLabel => 'Dato fra:';

  @override
  String get journalDateInvalid => 'Ugyldigt datointerval';

  @override
  String get journalDateLabel => 'Dato';

  @override
  String get journalDateNowButton => 'Nu';

  @override
  String get journalDateSaveButton => 'Gem';

  @override
  String get journalDateTimeRangeTitle => 'Dato og Tid';

  @override
  String get journalDateToLabel => 'Dato til:';

  @override
  String get journalDeleteConfirm => 'JA, SLET DENNE POST';

  @override
  String get journalDeleteHint => 'Slet post';

  @override
  String get journalDeleteQuestion => 'Vil du slette denne dagbogspost?';

  @override
  String get journalDurationLabel => 'Varighed';

  @override
  String get journalEndDateLabel => 'Slutdato';

  @override
  String get journalEndsAnotherDayHint => 'Vælg en separat slutdato';

  @override
  String get journalEndsAnotherDayLabel => 'Slutter på en anden dag';

  @override
  String get journalEndTimeLabel => 'Endetid';

  @override
  String get journalEntryExpandLabel => 'Udvid opslag';

  @override
  String get journalFilterEntryTypesTitle => 'Deltagertyper';

  @override
  String get journalFilterFlagged => 'Flaget';

  @override
  String get journalFilterPrivate => 'Privat';

  @override
  String get journalFilterShowTitle => 'Show';

  @override
  String get journalFilterStarred => 'Medvirket';

  @override
  String get journalFilterTitle => 'Filterjournal';

  @override
  String get journalHideLinkHint => 'Skjul link';

  @override
  String get journalHideMapHint => 'Skjul kort';

  @override
  String get journalLinkedEntriesActivityFilterAudio => 'Lyd';

  @override
  String get journalLinkedEntriesActivityFilterCode => 'Kode';

  @override
  String get journalLinkedEntriesActivityFilterImages => 'Billeder';

  @override
  String get journalLinkedEntriesActivityFilterTimer => 'Åbningstider';

  @override
  String get journalLinkedEntriesFilterModalTitle => 'Filter & Sort';

  @override
  String get journalLinkedEntriesShowFlaggedOnly =>
      'Vis kun markerede indgange';

  @override
  String get journalLinkedEntriesShowHidden => 'Vis skjulte indgange';

  @override
  String get journalLinkedEntriesSortLabel => 'Sorter efter';

  @override
  String get journalLinkedEntriesSortNewestFirst => 'Nyeste første';

  @override
  String get journalLinkedEntriesSortOldestFirst => 'Ældste første';

  @override
  String get journalLinkedFromLabel => 'Linket fra:';

  @override
  String get journalLinkFromHint => 'Link fra';

  @override
  String get journalLinkToHint => 'Link til';

  @override
  String journalOvernightNextDay(String date) {
    return 'Slutter $date (næste dag)';
  }

  @override
  String get journalPrivateTooltip => 'Kun privat';

  @override
  String get journalSearchHint => 'Søg i dagbogen...';

  @override
  String get journalSetEndDateTimeNowSemantic =>
      'Sæt slutdato og tidspunkt til nu';

  @override
  String get journalSetStartDateTimeNowSemantic =>
      'Sæt startdato og tidspunkt til nu';

  @override
  String get journalShareHint => 'Del';

  @override
  String get journalShowLinkHint => 'Vis link';

  @override
  String get journalShowMapHint => 'Vis kort';

  @override
  String get journalStartDateLabel => 'Startdato';

  @override
  String get journalStartTimeLabel => 'Starttid';

  @override
  String get journalTodayButton => 'I dag';

  @override
  String get journalToggleFlaggedTitle => 'Flaget';

  @override
  String get journalTogglePrivateTitle => 'Privat';

  @override
  String get journalToggleStarredTitle => 'Favorit';

  @override
  String get journalUnlinkConfirm => 'JA, FRAKOBLE INDGANGEN';

  @override
  String get journalUnlinkHint => 'Afbryd forbindelsen';

  @override
  String get journalUnlinkQuestion =>
      'Er du sikker på, at du vil fjerne linket til dette indlæg?';

  @override
  String get keyboardCommandActivate => 'Aktiver fokuseret genstand';

  @override
  String get keyboardCommandCategoryCreation => 'Oprettelse';

  @override
  String get keyboardCommandCategoryEditing => 'Redigering';

  @override
  String get keyboardCommandCategoryGeneral => 'Generel';

  @override
  String get keyboardCommandCategoryListsAndControls => 'Lister og kontroller';

  @override
  String get keyboardCommandCategoryNavigation => 'Navigation';

  @override
  String get keyboardCommandCategoryView => 'Udsigt';

  @override
  String get keyboardCommandCreateInContext => 'Opret i aktimens visning';

  @override
  String get keyboardCommandFocusSearch => 'Fokussøgning';

  @override
  String get keyboardCommandMoveDown => 'Flyt fokuseret genstand ned';

  @override
  String get keyboardCommandMoveUp => 'Flyt fokuseret genstand op';

  @override
  String keyboardCommandNavigate(String destination) {
    return 'Gå til $destination';
  }

  @override
  String get keyboardCommandNextRegion => 'Fokus næste felt';

  @override
  String get keyboardCommandOpenPalette => 'Open command-palette';

  @override
  String get keyboardCommandPageDown => 'Flyt dig en side ned';

  @override
  String get keyboardCommandPageUp => 'Flyt en side frem';

  @override
  String get keyboardCommandPreviousRegion => 'Fokus forrige panel';

  @override
  String get keyboardCommandRefresh => 'Opdater den aktuelle visning';

  @override
  String get keyboardCommandRename => 'Omdøb fokuseret element';

  @override
  String get keyboardCommandSelectFirst => 'Vælg første punkt';

  @override
  String get keyboardCommandSelectLast => 'Vælg sidste punkt';

  @override
  String get keyboardCommandSelectNext => 'Vælg næste punkt';

  @override
  String get keyboardCommandSelectPrevious => 'Vælg forrige punkt';

  @override
  String get keyboardCommandToggle => 'Skift fokuseret objekt';

  @override
  String get keyboardKeyAlt => 'Gammel';

  @override
  String get keyboardKeyArrowDown => 'Nedadpil';

  @override
  String get keyboardKeyArrowLeft => 'Venstre pil';

  @override
  String get keyboardKeyArrowRight => 'Højre pil';

  @override
  String get keyboardKeyArrowUp => 'Opadpil';

  @override
  String get keyboardKeyControl => 'Ctrl';

  @override
  String get keyboardKeyDelete => 'Slet';

  @override
  String get keyboardKeyEnd => 'Slut';

  @override
  String get keyboardKeyEnter => 'Kom ind';

  @override
  String get keyboardKeyEscape => 'Flugt';

  @override
  String get keyboardKeyHome => 'Hjem';

  @override
  String get keyboardKeyMinus => 'Minus';

  @override
  String get keyboardKeyOr => 'eller';

  @override
  String get keyboardKeyPageDown => 'Side ned';

  @override
  String get keyboardKeyPageUp => 'Page Up';

  @override
  String get keyboardKeyPlus => 'Mere';

  @override
  String get keyboardKeyShift => 'Skift';

  @override
  String get keyboardKeySpace => 'Rum';

  @override
  String get keyboardResizeDividerLabel => 'Omsat størrelse på ruder';

  @override
  String keyboardResizeDividerValue(int value, int min, int max) {
    return 'Tilpas paneler, $value pixels. Område $min til $max pixels.';
  }

  @override
  String get keyboardShortcutsNoResults => 'Ingen genveje matcher din søgning';

  @override
  String get keyboardShortcutsSearchHint => 'Søgegenveje...';

  @override
  String get keyboardShortcutsSubtitle =>
      'Hver skrivebordskommando og dens nuværende tastaturkombination.';

  @override
  String get keyboardShortcutsTitle => 'Tastaturgenveje';

  @override
  String knowledgeGraphAgeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dage siden',
      one: '1 dag siden',
    );
    return '$_temp0';
  }

  @override
  String knowledgeGraphAgeMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count måneder siden',
      one: '1 måned siden',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeToday => 'I dag';

  @override
  String knowledgeGraphAgeWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uger siden',
      one: '1 uge siden',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeYesterday => 'I går';

  @override
  String get knowledgeGraphBack => 'Tilbage';

  @override
  String get knowledgeGraphCloseDetails => 'Nære detaljer';

  @override
  String get knowledgeGraphEmpty => 'Ingen links at udforske endnu';

  @override
  String get knowledgeGraphEntryLoadError => 'Kunne ikke indlæse denne indgang';

  @override
  String get knowledgeGraphEntryNotFound => 'Indlæg ikke fundet';

  @override
  String get knowledgeGraphError => 'Kunne ikke indlæse vidensgrafen';

  @override
  String knowledgeGraphLinkedSection(int count) {
    return 'FORBUNDET · $count';
  }

  @override
  String get knowledgeGraphMoreLinks => 'Flere links';

  @override
  String knowledgeGraphNodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count noder',
      one: '1 node',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphNodeTypeAiSummary => 'AI-oversigt';

  @override
  String get knowledgeGraphNodeTypeAudioNote => 'Lydnote';

  @override
  String get knowledgeGraphNodeTypeChecklist => 'Tjekliste';

  @override
  String get knowledgeGraphNodeTypeChecklistItem => 'Tjekliste';

  @override
  String get knowledgeGraphNodeTypeNote => 'Bemærk';

  @override
  String get knowledgeGraphNodeTypePhoto => 'Foto';

  @override
  String get knowledgeGraphNodeTypeProject => 'Projekt';

  @override
  String get knowledgeGraphNodeTypeRating => 'Vurdering';

  @override
  String get knowledgeGraphNodeTypeTask => 'Opgave';

  @override
  String get knowledgeGraphOpenDetails => 'Åbne detaljer';

  @override
  String get knowledgeGraphRecenter => 'Nyere';

  @override
  String get knowledgeGraphRecentToOlder => 'nylige → ældre';

  @override
  String get knowledgeGraphRelationAiSource => 'AI-kilde';

  @override
  String get knowledgeGraphRelationChecklist => 'Tjekliste';

  @override
  String get knowledgeGraphRelationInProject => 'i projektet';

  @override
  String get knowledgeGraphRelationLinkedTask => 'Sammenkoblet opgave';

  @override
  String get knowledgeGraphRelationNoteLog => 'Note / log';

  @override
  String get knowledgeGraphRelationRating => 'Vurdering';

  @override
  String get knowledgeGraphSummarySection => 'RESUMÉ';

  @override
  String get knowledgeGraphTitle => 'Vidensgraf';

  @override
  String get knowledgeGraphTooltip => 'Udforsk links';

  @override
  String knowledgeGraphWalkHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count noder',
      one: '1 node',
    );
    return 'Tryk på en node for at gå · $_temp0';
  }

  @override
  String get linkedFromCaption => 'fra';

  @override
  String get linkedTaskImageBadge => 'Fra linket opgave';

  @override
  String get linkedTasksMenuTooltip => 'Muligheder for tilknyttede opgaver';

  @override
  String get linkedTasksTitle => 'Sammenkoblede opgaver';

  @override
  String get linkedToCaption => 'til';

  @override
  String get linkExistingTask => 'Link eksisterende opgave...';

  @override
  String get logbookEmptyHint => 'Create your first entry to start journaling.';

  @override
  String get logbookEmptyTitle => 'Your logbook is empty';

  @override
  String get logbookNewEntriesHint => 'New entries will open here.';

  @override
  String get logbookNoMatchesHint =>
      'Adjust your search or filters to see more.';

  @override
  String get logbookNoMatchesTitle => 'No entries match';

  @override
  String get loggingDomainAgentRuntime => 'Agentens runtime';

  @override
  String get loggingDomainAgentWorkflow => 'Agentarbejdsgang';

  @override
  String get loggingDomainAi => 'AI';

  @override
  String get loggingDomainCalendar => 'Kalender og tid';

  @override
  String get loggingDomainChat => 'Chat';

  @override
  String get loggingDomainDailyOs => 'Daily OS';

  @override
  String get loggingDomainDatabase => 'Database';

  @override
  String get loggingDomainGeneral => 'Generel';

  @override
  String get loggingDomainHabits => 'Vaner';

  @override
  String get loggingDomainHealth => 'Helbred';

  @override
  String get loggingDomainLabels => 'Etiketter';

  @override
  String get loggingDomainLocation => 'Beliggenhed';

  @override
  String get loggingDomainNavigation => 'Navigation';

  @override
  String get loggingDomainNotifications => 'Notifikationer';

  @override
  String get loggingDomainOnboarding => 'Onboarding & FTUE';

  @override
  String get loggingDomainPersistence => 'Vedvarende';

  @override
  String get loggingDomainRatings => 'Seertal';

  @override
  String get loggingDomainScreenshots => 'Skærmbilleder';

  @override
  String get loggingDomainSettings => 'Indstillinger';

  @override
  String get loggingDomainSpeech => 'Tale og lyd';

  @override
  String get loggingDomainSync => 'Sync';

  @override
  String get loggingDomainTasks => 'Opgaver & tjeklister';

  @override
  String get loggingDomainTheming => 'Tematisering';

  @override
  String get loggingDomainWhatsNew => 'Hvad er nyt';

  @override
  String get maintenanceDeleteAgentDb => 'Slet agentdatabase';

  @override
  String get maintenanceDeleteAgentDbDescription =>
      'Slet agenternes database og genstart appen';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'JA, SLET DATABASEN';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Er du sikker på, at du vil slette $databaseName Database?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Slet editordatabase';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Slet editor drafts-database';

  @override
  String get maintenanceDeleteSyncDb => 'Slet synkroniseringsdatabase';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Slet synkroniseringsdatabase';

  @override
  String get maintenanceGenerateEmbeddings => 'Generer indlejringer';

  @override
  String get maintenanceGenerateEmbeddingsConfirm => 'JA, GENERER';

  @override
  String get maintenanceGenerateEmbeddingsDescription =>
      'Generer embeddings for poster i udvalgte kategorier';

  @override
  String get maintenanceGenerateEmbeddingsMessage =>
      'Vælg kategorier til at generere embeddings for.';

  @override
  String maintenanceGenerateEmbeddingsProgress(
    int processed,
    int total,
    int embedded,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$processed / $total entries ($embedded indlejret)',
      one: '$processed / $total post ($embedded indlejret)',
    );
    return '$_temp0';
  }

  @override
  String get maintenancePopulatePhaseAgentEntities =>
      'Behandlingsagent-enheder...';

  @override
  String get maintenancePopulatePhaseAgentLinks =>
      'Behandlingsagent-forbindelser...';

  @override
  String get maintenancePopulatePhaseJournal =>
      'Behandler journalindførsler...';

  @override
  String get maintenancePopulatePhaseLinks => 'Behandler indgangslinks...';

  @override
  String get maintenancePopulateSequenceLog =>
      'Udfyld synkroniseringssekvenslogen';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count indekserede opslag';
  }

  @override
  String get maintenancePopulateSequenceLogConfirm => 'JA, POPULER';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Indekser eksisterende poster for backfill-støtte';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'Dette scanner alle journalposter og tilføjer dem til synkroniseringssekvensloggen. Dette muliggør backfill-svar for poster, der er oprettet før denne funktion blev tilføjet.';

  @override
  String get maintenancePurgeDeleted => 'Rens slettede elementer';

  @override
  String get maintenancePurgeDeletedConfirm => 'Ja, rens ud i alt';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Rens alle slettede elementer permanent';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Er du sikker på, at du vil slette alle slettede elementer? Denne handling kan ikke gøres om.';

  @override
  String get maintenancePurgeSentOutbox => 'Rens gamle udsendte udbakke-varer';

  @override
  String get maintenancePurgeSentOutboxConfirm => 'JA, UDRENSNING';

  @override
  String get maintenancePurgeSentOutboxDescription =>
      'Slet sendte udbakke-rækker, der er ældre end 7 dage, og genindvind disken';

  @override
  String get maintenancePurgeSentOutboxQuestion =>
      'Udfyldte udbakke-varer ældre end 7 dage? Dette sletter allerede sendte rækker i chunks og kører VACUUM for at genvinde disken. Ventende og fejlposter gemmes.';

  @override
  String get maintenanceRecreateFts5 => 'Genskab fuldtekstindeks';

  @override
  String get maintenanceRecreateFts5Confirm => 'JA, GENSKAB INDEKSET';

  @override
  String get maintenanceRecreateFts5Description =>
      'Genskab fuldtekst-søgeindeks';

  @override
  String get maintenanceRecreateFts5Message =>
      'Er du sikker på, at du vil genskabe fuldtekstindekset? Det kan tage noget tid.';

  @override
  String get maintenanceReSync => 'Gensynkroniser beskeder';

  @override
  String get maintenanceReSyncAgentEntities => 'Agentenheder';

  @override
  String get maintenanceReSyncDescription =>
      'Gensynkroniser beskeder fra serveren';

  @override
  String get maintenanceReSyncEntityTypes => 'Enhedstyper';

  @override
  String get maintenanceReSyncJournalEntities => 'Tidsskriftsenheder';

  @override
  String get maintenanceReSyncSelectAtLeastOne => 'Vælg mindst én enhedstype';

  @override
  String get maintenanceReSyncStart => 'Start';

  @override
  String get maintenanceSyncDefinitions =>
      'Synkroniser målbare ting, dashboards, vaner, kategorier, AI-indstillinger';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Synkroniser målbare ting, dashboards, vaner, kategorier og AI-indstillinger';

  @override
  String get manageLinks => 'Administrer links...';

  @override
  String get matrixStatsCatchupBatches => 'Indhentningsgrupper';

  @override
  String get matrixStatsCircuitOpens => 'Banen åbner';

  @override
  String get matrixStatsConflicts => 'Konflikter';

  @override
  String get matrixStatsCopyDiagnostics => 'Kopier Diagnostik';

  @override
  String get matrixStatsCopyDiagnosticsTooltip =>
      'Kopier synkroniseringsdiagnostik til udklipsholderen';

  @override
  String get matrixStatsDbApplied => 'DB Applied';

  @override
  String get matrixStatsDbApply => 'DB Ansøg';

  @override
  String get matrixStatsDbIgnoredVectorClock => 'DB ignoreret (VectorClock)';

  @override
  String get matrixStatsDbMissingBase => 'DB Manglende Basis';

  @override
  String matrixStatsDroppedByType(Object type) {
    return 'Droppet ($type)';
  }

  @override
  String get matrixStatsEntryLinkNoops => 'EntryLink No-ops';

  @override
  String get matrixStatsFailures => 'Fejl';

  @override
  String get matrixStatsFlushes => 'Flushes';

  @override
  String get matrixStatsForceRescan => 'Force Rescan';

  @override
  String get matrixStatsForceRescanTooltip => 'Force-scan og indhent nu';

  @override
  String get matrixStatsLegend => 'Legende';

  @override
  String get matrixStatsLegendTooltip =>
      'Legende:\n• behandlet. <type> = behandlede synkroniseringsbeskeder efter nyttelasttype\n• droppedByType. <type> = per-type falder efter genforsøg eller ældre-besked ignorerer\n• dbApplied = databaserækker skrevet\n• dbIgnoredByVectorClock = ældre eller identiske indkommende data ignoreres af databasen\n• konflikterSkabt = samtidige vektorure logget\n• dbMissingBase = sprunget over mens man venter på en manglende afhængighed eller basisrække\n• staleAttachmentPurges = cachede forældede beskrivelser slettet før opdatering';

  @override
  String get matrixStatsProcessed => 'Forarbejdet';

  @override
  String matrixStatsProcessedByType(Object type) {
    return 'Behandlet ($type)';
  }

  @override
  String get matrixStatsRefresh => 'Opfrisk';

  @override
  String get matrixStatsReliability => 'Pålidelighed';

  @override
  String get matrixStatsRetriesScheduled => 'Planlagte forsøg';

  @override
  String get matrixStatsRetryNow => 'Prøv igen nu';

  @override
  String get matrixStatsRetryNowTooltip => 'Prøv igen ventende fejl nu';

  @override
  String get matrixStatsSignalLatencyLast => 'Signallatens (sidste ms)';

  @override
  String get matrixStatsSignalLatencyMax => 'Signallatens (max ms)';

  @override
  String get matrixStatsSignalLatencyMin => 'Signallatens (min ms)';

  @override
  String get matrixStatsSignals => 'Signaler';

  @override
  String get matrixStatsSignalsClientStream => 'Signaler (klientstrøm)';

  @override
  String get matrixStatsSignalsConnectivity => 'Signaler (forbindelse)';

  @override
  String get matrixStatsSignalsTimelineCallbacks =>
      'Signaler (tidslinje-callbacks)';

  @override
  String get matrixStatsSkipped => 'Sprunget over';

  @override
  String get matrixStatsSkippedRetryCap => 'Sprunget over (Retry Cap)';

  @override
  String get matrixStatsStaleAttachmentPurges => 'Stale Attachment Purges';

  @override
  String get matrixStatsThroughput => 'Gennemstrømning';

  @override
  String get matrixStatsTopKpis => 'Top KPI\'er';

  @override
  String get measurableDeleteConfirm => 'JA, SLET DENNE MÅLBARE';

  @override
  String get measurableDeleteQuestion =>
      'Vil du slette denne målbare datatype?';

  @override
  String get measurableNotFound => 'Målbar ikke fundet';

  @override
  String get measurementCommentHint => 'Tilføj en note (valgfrit)';

  @override
  String get measurementCommentSemantic => 'Kommentar, valgfrit';

  @override
  String measurementObservedAtChangeSemantic(String dateTime) {
    return 'Observeret ved $dateTime. Skift dato og tidspunkt.';
  }

  @override
  String get measurementQuickAddLabel => 'Hurtig log';

  @override
  String measurementQuickLogSemantic(String value) {
    return 'Log $value straks';
  }

  @override
  String get measurementSaveError =>
      'Kunne ikke gemme denne måling. Prøv igen.';

  @override
  String get measurementSetObservedAtNowSemantic =>
      'Sæt dato og tidspunkt for observeret til nu';

  @override
  String get measurementTimeLabel => 'Tidspunkt';

  @override
  String measurementValueSemantic(String measurable) {
    return 'Værdi for $measurable';
  }

  @override
  String get mediaShowInFileExplorerAction => 'Vis i Filfinder';

  @override
  String get mediaShowInFilesAction => 'Vis i filer';

  @override
  String get mediaShowInFinderAction => 'Vis i Finder';

  @override
  String get modalityAudioDescription => 'Lydbehandlingsmuligheder';

  @override
  String get modalityAudioName => 'Lyd';

  @override
  String get modalityImageDescription => 'Billedbehandlingsmuligheder';

  @override
  String get modalityImageName => 'Billede';

  @override
  String get modalityTextDescription => 'Tekstbaseret indhold og behandling';

  @override
  String get modalityTextName => 'Tekst';

  @override
  String get modelAddPageTitle => 'Tilføj model';

  @override
  String get modelEditBackTooltip => 'Tilbage';

  @override
  String get modelEditDescriptionHint => 'Beskriv denne model';

  @override
  String get modelEditDescriptionLabel => 'Beskrivelse';

  @override
  String get modelEditDisplayNameHint => 'Et venligt navn til denne model';

  @override
  String get modelEditDisplayNameLabel => 'Visningsnavn';

  @override
  String get modelEditFunctionCallingDescription =>
      'Denne model understøtter funktions- og værktøjskald.';

  @override
  String get modelEditFunctionCallingLabel => 'Funktionskald';

  @override
  String get modelEditGeminiThinkingModeLabel =>
      'Tvillingernes tænkningstilstand';

  @override
  String get modelEditInputModalitiesHint => 'Vælg inputtyper';

  @override
  String get modelEditInputModalitiesLabel => 'Inputmodaliteter';

  @override
  String get modelEditLoadError => 'Kunne ikke indlæse modelkonfiguration';

  @override
  String get modelEditMaxTokensHint =>
      'Valgfrit — lad det stå tomt for ubegrænset';

  @override
  String get modelEditMaxTokensLabel => 'Maks fuldførelsestokens';

  @override
  String get modelEditModalityNoneSelected => 'Ingen udvalgt';

  @override
  String get modelEditOutputModalitiesHint => 'Vælg outputtyper';

  @override
  String get modelEditOutputModalitiesLabel => 'Outputmodaliteter';

  @override
  String get modelEditPageTitle => 'Rediger model';

  @override
  String get modelEditProviderHint => 'Vælg en udbyder';

  @override
  String get modelEditProviderLabel => 'Udbyder';

  @override
  String get modelEditProviderModelIdHint => 'f.eks. GPT-4-turbo';

  @override
  String get modelEditProviderModelIdLabel => 'Udbydermodel-ID';

  @override
  String get modelEditReasoningDescription =>
      'Denne model bruger udvidet tænkning / tankekæde.';

  @override
  String get modelEditReasoningLabel => 'Ræsonnementsmodel';

  @override
  String get modelEditSaveButton => 'Gem';

  @override
  String get modelEditSectionCapabilities => 'Kapaciteter';

  @override
  String get modelEditSectionIdentity => 'Identitet';

  @override
  String modelManagementSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ler',
      one: '',
    );
    return '$count model$_temp0 valgt';
  }

  @override
  String get multiSelectAddButton => 'Tilføj';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Tilføj ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'Ingen genstande fundet';

  @override
  String get navSidebarManualBrowserHint => 'Åbner i din browser';

  @override
  String get navSidebarManualLabel => 'Manual';

  @override
  String navTabMoreSemanticsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mere, $count yderligere destinationer',
      one: 'Mere, 1 ekstra destination',
    );
    return '$_temp0';
  }

  @override
  String get navTabTitleCalendar => 'DailyOS';

  @override
  String get navTabTitleEvents => 'Begivenheder';

  @override
  String get navTabTitleHabits => 'Vaner';

  @override
  String get navTabTitleInsights => 'Indsigter';

  @override
  String get navTabTitleJournal => 'Logbog';

  @override
  String get navTabTitleMore => 'Mere';

  @override
  String get navTabTitleProjects => 'Projekter';

  @override
  String get navTabTitleSettings => 'Indstillinger';

  @override
  String get navTabTitleTasks => 'Opgaver';

  @override
  String nestedAiResponsesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '',
      one: '',
    );
    return '$count AI-svar$_temp0';
  }

  @override
  String get noDefaultLanguage => 'Intet standardsprog';

  @override
  String get noTasksFound => 'Ingen opgaver fundet';

  @override
  String get noTasksToLink => 'Ingen opgaver tilgængelige at linke';

  @override
  String get notificationBellEmptySemantics =>
      'Notifikationer, ingen ulæste advarsler';

  @override
  String get notificationBellTooltip => 'Notifikationer';

  @override
  String notificationBellUnseenSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'advarsler',
      one: 'advarsel',
    );
    return 'Notifikationer, $count ulæste $_temp0';
  }

  @override
  String get notificationInboxDismiss => 'Afvisningsmeddelelse';

  @override
  String get notificationInboxEmpty => 'Du er helt ajour.';

  @override
  String get notificationInboxError => 'Kunne ikke indlæse notifikationer.';

  @override
  String get notificationInboxTitle => 'Notifikationer';

  @override
  String get notificationSuggestionAttentionBodyFallback =>
      'Åbn opgaven for at gennemgå.';

  @override
  String notificationSuggestionAttentionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count forslag kræver din opmærksomhed',
      one: '1 forslag kræver din opmærksomhed',
    );
    return '$_temp0';
  }

  @override
  String get onboardingApiKeyConnect => 'Forbind';

  @override
  String get onboardingApiKeyConnecting => 'Forbinder...';

  @override
  String get onboardingApiKeyEnterKeyHint =>
      'Indtast en gyldig nøgle for at fortsætte.';

  @override
  String get onboardingApiKeyError =>
      'Kunne ikke få forbindelse. Tjek din nøgle og prøv igen.';

  @override
  String get onboardingApiKeyField => 'API-nøgle';

  @override
  String get onboardingApiKeyGetKeyAt => 'Få en nøgle på';

  @override
  String get onboardingApiKeyHide => 'Skjul nøgle';

  @override
  String get onboardingApiKeyInvalid =>
      'Den nøgle blev afvist. Dobbelttjek det og indsæt det igen.';

  @override
  String get onboardingApiKeyLocalNote =>
      'Kører på din enhed — ingen nøgle nødvendig.';

  @override
  String get onboardingApiKeyNoKeyHelp =>
      'Ny her? Log ind, opret en API-nøgle, og indsæt den så — gratis at starte med.';

  @override
  String get onboardingApiKeyReveal => 'Show-nøgle';

  @override
  String get onboardingApiKeyTitle => 'Indsæt din API-nøgle';

  @override
  String onboardingApiKeyUnreachable(String providerName) {
    return 'Kunne ikke nå $providerName. Tjek nøglen eller din forbindelse og prøv igen.';
  }

  @override
  String get onboardingApiKeyVerifying => 'Bekræfter...';

  @override
  String get onboardingCaptureCategoryPrompt => 'Hvor skal dette lande?';

  @override
  String get onboardingCaptureListening =>
      'Lytter... Tryk på, når du er færdig';

  @override
  String get onboardingCaptureOrbLabel => 'Optag dine tanker';

  @override
  String get onboardingCaptureRatherType => 'Vil du hellere skrive?';

  @override
  String get onboardingCaptureReassurance =>
      'Du vil kunne redigere alt næste gang.';

  @override
  String get onboardingCaptureThinking => 'At gøre dine ord til en opgave...';

  @override
  String get onboardingCaptureTypePrompt => 'Skriv din tanke';

  @override
  String get onboardingCategoryAddOwn => 'Tilføj din egen';

  @override
  String get onboardingCategoryContinue => 'Fortsæt';

  @override
  String get onboardingCategoryExplanation =>
      'Hvert område af dit liv får sit eget rum. Vælg dem, der passer – eller tilføj din egen.';

  @override
  String get onboardingCategoryFamily => 'Familie';

  @override
  String get onboardingCategoryFitness => 'Fitness';

  @override
  String get onboardingCategoryFriends => 'Venner';

  @override
  String get onboardingCategoryTitle => 'Hvor skal din AI fungere?';

  @override
  String get onboardingCategoryWhy => 'Hvorfor områder?';

  @override
  String onboardingCategoryWhyDetail(String provider) {
    return 'Hvert område kan bruge sin egen AI. $provider vil drive de områder, du vælger her — senere kan du give forskellige områder forskellige AI\'er.';
  }

  @override
  String get onboardingCategoryWork => 'Værk';

  @override
  String get onboardingConnectGeminiName => 'Tvillingerne';

  @override
  String get onboardingConnectGeminiTagline => 'USA';

  @override
  String get onboardingConnectLessOptions => 'Færre muligheder';

  @override
  String get onboardingConnectMistralName => 'Mistral';

  @override
  String get onboardingConnectMistralTagline => 'Den Europæiske Union';

  @override
  String get onboardingConnectMoreOptions => 'Flere muligheder';

  @override
  String get onboardingConnectNotSure =>
      'Melious.ai er den anbefalede standard.';

  @override
  String get onboardingConnectOllamaName => 'Ollama';

  @override
  String get onboardingConnectOpenAiName => 'OpenAI';

  @override
  String get onboardingConnectQwenName => 'Qwen';

  @override
  String get onboardingConnectQwenTagline => 'Kina';

  @override
  String get onboardingConnectTitle => 'Vælg AI-hjernen til dine opgaver';

  @override
  String get onboardingFirstTaskCreatedHint =>
      'Tryk på din opgave for at åbne den';

  @override
  String get onboardingFirstTaskCreatedTitle => 'Din første opgave er klar';

  @override
  String get onboardingFirstTaskGuidance =>
      'Tryk for at tale og sig, hvad der skal gøres — Lotti gør det til en reel opgave.';

  @override
  String get onboardingFirstTaskSuggestionDentist =>
      'Book en tid hos tandlægen';

  @override
  String get onboardingFirstTaskSuggestionMeeting =>
      'Forbered dig til mandagens møde';

  @override
  String get onboardingFirstTaskSuggestionPlanWeek => 'Planlæg min uge';

  @override
  String get onboardingFirstTaskSuggestionsLabel =>
      'Ikke klar til at tale? Start med en af disse:';

  @override
  String get onboardingFirstTaskTitle => 'Lav din første opgave';

  @override
  String get onboardingMetricsActiveDays => 'Aktive dage';

  @override
  String get onboardingMetricsActiveDaysInFirstSeven =>
      'Aktive dage i de første 7';

  @override
  String get onboardingMetricsBaselineCohort => 'Baseline-kohorte (før FTUE)';

  @override
  String get onboardingMetricsInstallFirstSeenUtc =>
      'Installer først set (UTC)';

  @override
  String get onboardingMetricsNo => 'Nej';

  @override
  String get onboardingMetricsReachedRealAha => 'Nåede rigtigt aha';

  @override
  String get onboardingMetricsYes => 'Ja';

  @override
  String get onboardingRecordingStyleAnalogue => 'Analog — VU-måler';

  @override
  String get onboardingRecordingStyleContinue => 'Fortsæt';

  @override
  String get onboardingRecordingStyleExplanation =>
      'Vælg et look til mikrofonen. Du kan ændre det når som helst i Indstillinger.';

  @override
  String get onboardingRecordingStyleModern => 'Moderne — energikugle';

  @override
  String get onboardingRecordingStyleTitle =>
      'Hvordan skal det føles at optage?';

  @override
  String get onboardingRecordingStyleTryVoice => 'Prøv med din stemme';

  @override
  String get onboardingSuccessContinue => 'Kom i gang';

  @override
  String get onboardingSuccessSubtitle =>
      'Din AI-hjerne er forbundet og klar til at omsætte dine ord til opgaver.';

  @override
  String get onboardingSuccessTitle => 'Du er klar';

  @override
  String get onboardingWelcomeConnectButton => 'Vælg din AI-hjerne';

  @override
  String get onboardingWelcomeMessage =>
      'Forbind din AI-hjerne, sig derefter en tanke og se den blive en struktureret opgave.';

  @override
  String get onboardingWelcomeSkipButton => 'Se dig omkring først';

  @override
  String get onboardingWelcomeTitle => 'Tal. Lotti gør det til en plan.';

  @override
  String get optionalCategoryLabel => 'Kategori (valgfrit)';

  @override
  String get outboxActionRemove => 'Fjern';

  @override
  String get outboxActionRetry => 'Nyt forsøg';

  @override
  String get outboxFailedReassurance =>
      'Den er stadig gemt på denne enhed — den synkroniseres, når problemet er løst.';

  @override
  String get outboxFilterFailed => 'Mislykkedes';

  @override
  String get outboxFilterWaiting => 'Venter';

  @override
  String get outboxMonitorAttachmentLabel => 'Tilknytning';

  @override
  String get outboxMonitorDelete => 'Slet';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Slet';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      'Er du sikker på, at du vil slette dette synkroniseringselement? Denne handling kan ikke gøres om.';

  @override
  String get outboxMonitorDeleteFailed =>
      'Sletning mislykkedes. Prøv venligst igen.';

  @override
  String get outboxMonitorDeleteSuccess => 'Genstanden slettet';

  @override
  String get outboxMonitorEmptyDescription =>
      'Der er ingen synkroniseringselementer i denne visning.';

  @override
  String get outboxMonitorEmptyTitle => 'Udboksen er fri';

  @override
  String get outboxMonitorFetchFailed =>
      'Kunne ikke loade outboxen. Træk for at opdatere og prøv igen.';

  @override
  String get outboxMonitorLabelError => 'fejl';

  @override
  String get outboxMonitorLabelPending => 'Afventer';

  @override
  String get outboxMonitorLabelSent => 'sendt';

  @override
  String get outboxMonitorLabelSuccess => 'Succes';

  @override
  String get outboxMonitorNoAttachment => 'ingen tilknytning';

  @override
  String get outboxMonitorPayloadSizeLabel => 'Størrelse';

  @override
  String get outboxMonitorRetries => 'Forsøg igen';

  @override
  String get outboxMonitorRetriesLabel => 'Forsøg igen';

  @override
  String get outboxMonitorRetry => 'Forsøg igen';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Prøv igen nu';

  @override
  String get outboxMonitorRetryConfirmMessage =>
      'Prøv dette synkroniseringselement igen nu?';

  @override
  String get outboxMonitorRetryFailed =>
      'Forsøg mislykkedes. Prøv venligst igen.';

  @override
  String get outboxMonitorRetryQueued => 'Omprøvning planlagt';

  @override
  String get outboxMonitorSubjectLabel => 'Emne';

  @override
  String get outboxMonitorVolumeChartTitle => 'Daglig synkroniseringsvolumen';

  @override
  String get outboxRemoveConfirmMessage =>
      'Denne ændring er endnu ikke synkroniseret. Hvis jeg fjerner den her, vil den ikke nå dine andre enheder. Den bliver på denne enhed.';

  @override
  String get outboxRemoveConfirmTitle => 'Fjern fra køen?';

  @override
  String get outboxRetryAll => 'Prøv alle igen';

  @override
  String get outboxShowDetails => 'Tekniske detaljer i programmet';

  @override
  String get outboxStatusFailed => 'Kunne ikke sende';

  @override
  String get outboxStatusSending => 'Sender';

  @override
  String get outboxStatusSent => 'Sendt';

  @override
  String get outboxStatusWaiting => 'Venter på at sende';

  @override
  String outboxSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count genstande kunne ikke sende',
      one: '1 genstand kunne ikke sende',
    );
    return '$_temp0';
  }

  @override
  String outboxSummaryOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count genstande vil blive sendt, når du genforbinder',
      one: '1 genstand vil blive sendt, når du genforbinder',
    );
    return '$_temp0';
  }

  @override
  String outboxSummarySending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sender $count genstande... ',
      one: 'Sender 1 vare... ',
    );
    return '$_temp0';
  }

  @override
  String get outboxSummarySynced => 'Alt er synkroniseret';

  @override
  String outboxSummaryWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count genstande, der venter på at blive sendt',
      one: '1 genstand, der venter på at blive sendt',
    );
    return '$_temp0';
  }

  @override
  String outboxTriedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Prøvede $count gange',
      one: 'Prøvede én gang',
    );
    return '$_temp0';
  }

  @override
  String get panasCompletionText => 'Tak fordi du udfyldte PANAS!';

  @override
  String get panasCompletionTitle => 'Færdig';

  @override
  String get panasEmotionActive => 'Aktiv';

  @override
  String get panasEmotionAfraid => 'Bange';

  @override
  String get panasEmotionAlert => 'Advarsel';

  @override
  String get panasEmotionAshamed => 'Skamfuld';

  @override
  String get panasEmotionAttentive => 'Opmærksomt';

  @override
  String get panasEmotionDetermined => 'Beslutsomt';

  @override
  String get panasEmotionDistressed => 'Bekymret';

  @override
  String get panasEmotionEnthusiastic => 'Entusiastisk';

  @override
  String get panasEmotionExcited => 'Spændt';

  @override
  String get panasEmotionGuilty => 'Skyldig';

  @override
  String get panasEmotionHostile => 'Fjendtlig';

  @override
  String get panasEmotionInspired => 'Inspireret';

  @override
  String get panasEmotionInterested => 'Interesseret';

  @override
  String get panasEmotionIrritable => 'Irritabel';

  @override
  String get panasEmotionJittery => 'Nervøs';

  @override
  String get panasEmotionNervous => 'Nervøs';

  @override
  String get panasEmotionProud => 'Stolt';

  @override
  String get panasEmotionScared => 'Bange';

  @override
  String get panasEmotionStrong => 'Stærk';

  @override
  String get panasEmotionUpset => 'Overraskelse';

  @override
  String get panasInstructionFootnote =>
      'Watson, D., Clark, L. A., & Tellegen, A. (1988). Udvikling og validering af korte målinger af positiv og negativ effekt: PANAS-skalaerne. Journal of Personality and Social Psychology, 54(6), 1063–1070.';

  @override
  String get panasInstructionText =>
      'Angiv, i hvor høj grad du føler sådan lige nu, altså lige nu.\n\n1—Meget lidt eller slet ikke,\n2—Lidt,\n3—Moderat,\n4—En hel del,\n5—Ekstremt';

  @override
  String get panasInstructionTitle =>
      'Positive og Negative Affect Schedule (PANAS; Watson et al., 1988)';

  @override
  String get panasScaleALittle => 'Lidt';

  @override
  String get panasScaleExtremely => 'Ekstremt meget';

  @override
  String get panasScaleModerately => 'Moderat';

  @override
  String get panasScaleQuiteABit => 'En hel del';

  @override
  String get panasScaleVerySlightlyOrNotAtAll => 'Meget lidt eller slet ikke';

  @override
  String get privateLabel => 'Privat';

  @override
  String get privateSwitchDescription => 'Kun synlig, når private bidrag vises';

  @override
  String get projectAgentNotProvisioned =>
      'Der er endnu ikke udpeget nogen projektagent til dette projekt.';

  @override
  String get projectAgentSectionTitle => 'Agent';

  @override
  String projectCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projekter',
      one: '$count projekt',
    );
    return '$_temp0';
  }

  @override
  String get projectCreateButton => 'Nyt projekt';

  @override
  String get projectCreateTitle => 'Opret projekt';

  @override
  String get projectDetailTitle => 'Projektdetaljer';

  @override
  String get projectErrorCreateFailed => 'Fejloprettelse af projekt.';

  @override
  String get projectErrorLoadFailed => 'Manglende indlæsning af projektdata.';

  @override
  String get projectErrorLoadProjects => 'Fejlindlæsningsprojekter';

  @override
  String get projectErrorUpdateFailed =>
      'Fejlede i at opdatere projektet. Prøv venligst igen.';

  @override
  String get projectFilterLabel => 'Projekt';

  @override
  String get projectHealthBandAtRisk => 'På risiko';

  @override
  String get projectHealthBandBlocked => 'Blokeret';

  @override
  String get projectHealthBandOnTrack => 'På banen';

  @override
  String get projectHealthBandSurviving => 'Overlevende';

  @override
  String get projectHealthBandWatch => 'Se';

  @override
  String get projectHealthSectionTitle => 'Projektets sundhed';

  @override
  String projectHealthSummary(int projectCount, int taskCount) {
    String _temp0 = intl.Intl.pluralLogic(
      projectCount,
      locale: localeName,
      other: '$projectCount projekter',
      one: '$projectCount projekt',
    );
    String _temp1 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: '$taskCount opgaver',
      one: '$taskCount opgave',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get projectHealthTitle => 'Projekter';

  @override
  String projectLinkedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linkede opgaver',
      one: '$count linket opgave',
    );
    return '$_temp0';
  }

  @override
  String get projectLinkedTasks => 'Sammenkoblede opgaver';

  @override
  String get projectManageTooltip => 'Styr projekter';

  @override
  String get projectNoLinkedTasks => 'Ingen opgaver er linket endnu';

  @override
  String get projectNoProjects => 'Ingen projekter endnu';

  @override
  String get projectNotFound => 'Projekt ikke fundet';

  @override
  String get projectPickerLabel => 'Projekt';

  @override
  String get projectPickerUnassigned => 'Intet projekt';

  @override
  String get projectRecommendationDismissTooltip => 'Afvist';

  @override
  String get projectRecommendationResolveTooltip => 'Mark besluttede sig';

  @override
  String get projectRecommendationsTitle => 'Anbefalede næste skridt';

  @override
  String get projectRecommendationUpdateError =>
      'Kunne ikke opdatere anbefalingen. Prøv venligst igen.';

  @override
  String get projectsFilterStatusLabel => 'Status:';

  @override
  String get projectsFilterTooltip => 'Filterprojekter';

  @override
  String get projectShowcaseAiReportTitle => 'AI-rapport';

  @override
  String projectShowcaseBlockedLegend(int count) {
    return '$count Blokeret';
  }

  @override
  String projectShowcaseBlockedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opgaver blokeret',
      one: '$count opgave blokeret',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseCompletedLegend(int count) {
    return '$count Færdiggjort';
  }

  @override
  String get projectShowcaseDescriptionTitle => 'Beskrivelse';

  @override
  String projectShowcaseDueDate(String date) {
    return 'To $date';
  }

  @override
  String get projectShowcaseHealthScoreDescription =>
      'Denne score er baseret på opgavehastighed, blokeringer og tid tilbage til deadline.';

  @override
  String get projectShowcaseHealthScoreTitle => 'Sundhedsscore';

  @override
  String get projectShowcaseNoResults => 'Ingen projekter matcher din søgning.';

  @override
  String get projectShowcaseOneOnOneReviewsTab => 'En-til-en anmeldelser';

  @override
  String get projectShowcaseOngoing => 'Løbende';

  @override
  String get projectShowcaseProjectTasksTab => 'Projektopgaver';

  @override
  String get projectShowcaseSearchHint => 'Søgeprojekter';

  @override
  String projectShowcaseSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessioner',
      one: '$count sessioner',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseTasksCompleted(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$completed/$total opgaver fuldført',
      one: '$completed/$total opgave fuldført',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseUpdatedHoursAgo(int hours) {
    return 'Opdateret ${hours}h for længe siden ↻';
  }

  @override
  String projectShowcaseUpdatedMinutesAgo(int minutes) {
    return 'Opdateret ${minutes}m for siden ↻';
  }

  @override
  String get projectShowcaseUsefulness => 'Nytteværdi';

  @override
  String get projectShowcaseViewBlocker => 'Visningsblokker';

  @override
  String get projectStatusActive => 'Aktiv';

  @override
  String get projectStatusArchived => 'Arkiveret';

  @override
  String get projectStatusChangeTitle => 'Ændre status';

  @override
  String get projectStatusCompleted => 'Færdiggjort';

  @override
  String get projectStatusMonitoring => 'Overvågning';

  @override
  String get projectStatusOnHold => 'På pause';

  @override
  String get projectStatusOpen => 'Åben';

  @override
  String get projectSummaryOutdated => 'Resumé er forældet.';

  @override
  String projectSummaryOutdatedScheduled(String date, String time) {
    return 'Resumé er forældet. Næste opdatering $date på $time.';
  }

  @override
  String get projectTargetDateLabel => 'Måldato';

  @override
  String get projectTitleLabel => 'Projekttitel';

  @override
  String get projectTitleRequired => 'Projekttitel kan ikke være tom';

  @override
  String get promptDefaultModelBadge => 'Default';

  @override
  String get promptGenerationCardTitle => 'AI-kodningsprompt';

  @override
  String get promptGenerationCopiedSnackbar => 'Prompt kopieret til clipboard';

  @override
  String get promptGenerationCopyButton => 'Kopier prompt';

  @override
  String get promptGenerationCopyTooltip =>
      'Kopier prompten til udklipsbrættet';

  @override
  String get promptGenerationExpandTooltip => 'Vis fuld prompt';

  @override
  String get promptGenerationFullPromptLabel => 'Fuld prompt:';

  @override
  String get promptSelectionModalTitle => 'Vælg forudkonfigureret prompt';

  @override
  String get provisionedSyncBundleImported => 'Importeret provisioneringskode';

  @override
  String get provisionedSyncConfigureButton => 'Konfigurér';

  @override
  String get provisionedSyncCopiedToClipboard => 'Kopieret til clipboard';

  @override
  String get provisionedSyncDisconnect => 'Afbrydelse';

  @override
  String get provisionedSyncDone => 'Synkronisering konfigureret korrekt';

  @override
  String get provisionedSyncError => 'Konfigurationen fejlede';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'Der opstod en fejl under konfigurationen. Prøv venligst igen.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'Login mislykkedes. Tjek venligst dine legitimationsoplysninger og prøv igen.';

  @override
  String get provisionedSyncImportButton => 'Import';

  @override
  String get provisionedSyncImportHint => 'Indsæt provisioneringskode her';

  @override
  String get provisionedSyncImportTitle => 'Synkroniseringsopsætning';

  @override
  String get provisionedSyncInvalidBundle => 'Ugyldig provisioneringskode';

  @override
  String get provisionedSyncJoiningRoom =>
      'Tilslutter synkroniseringsrummet...';

  @override
  String get provisionedSyncLoggingIn => 'Logger ind...';

  @override
  String get provisionedSyncPasteClipboard => 'Indsæt fra clipboard';

  @override
  String get provisionedSyncReady => 'Scan denne QR-kode på din mobilenhed';

  @override
  String get provisionedSyncRetry => 'Nyt forsøg';

  @override
  String get provisionedSyncRotatingPassword => 'Sikrer konto...';

  @override
  String get provisionedSyncScanButton => 'Scan QR-kode';

  @override
  String get provisionedSyncShowQr => 'Vis provisionering QR';

  @override
  String get provisionedSyncSubtitle =>
      'Opsæt synkronisering fra en provisioning-pakke';

  @override
  String get provisionedSyncSummaryHomeserver => 'Homeserver';

  @override
  String get provisionedSyncSummaryRoom => 'Værelse';

  @override
  String get provisionedSyncSummaryUser => 'Bruger';

  @override
  String get provisionedSyncTitle => 'Provisioneret synkronisering';

  @override
  String get provisionedSyncVerifyDevicesTitle => 'Enhedsverifikation';

  @override
  String get queueCatchUpNowButton => 'Følg med nu';

  @override
  String get queueCatchUpNowDone =>
      'Indhentning er smidt i gang — køen dræner mig.';

  @override
  String queueCatchUpNowError(String reason) {
    return 'Indhentning mislykkedes: $reason';
  }

  @override
  String get queueDepthCardEmpty => 'Køen er tom — medarbejderen er forsinket.';

  @override
  String get queueDepthCardLoading => 'Læse-kødybde...';

  @override
  String get queueDepthCardTitle => 'Indkommende kø';

  @override
  String get queueFetchAllHistoryCancel => 'Annuller';

  @override
  String queueFetchAllHistoryCancelled(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events begivenheder',
      one: '1 begivenhed',
      zero: ' ingen begivenheder',
    );
    return 'Aflyst — $_temp0 hentet indtil videre.';
  }

  @override
  String get queueFetchAllHistoryClose => 'Luk';

  @override
  String get queueFetchAllHistoryDescription =>
      'Går hele rummets synlige historie ind i køen. Sikkert at aflyse; En senere gennemspilning genoptages, hvor pagineringen stoppede.';

  @override
  String queueFetchAllHistoryDone(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages sider',
      one: '1 side',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages sider',
      one: '1 side',
    );
    String _temp2 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: 'Hentede $events begivenheder på tværs af $_temp0. ',
      one: 'Hentede 1 begivenhed over $_temp1. ',
      zero: 'Ingen begivenheder hentes. ',
    );
    return '$_temp2';
  }

  @override
  String queueFetchAllHistoryError(String reason) {
    return 'Hent stoppet: $reason';
  }

  @override
  String get queueFetchAllHistoryErrorUnknown => 'Apport stoppede uventet.';

  @override
  String queueFetchAllHistoryProgress(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: ' side $pages ·  $events begivenheder hentet',
      one: 'Side $pages ·  1 begivenhed hentet',
    );
    return '$_temp0';
  }

  @override
  String get queueFetchAllHistoryTitle => 'Hentehistorik';

  @override
  String queueSkippedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sprunget ',
      one: '1 springet over',
    );
    return '$_temp0 over';
  }

  @override
  String queueSkippedCardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count synkroniserer begivenheder, som køen opgav. Tryk på prøv igen for at forsøge igen. ',
      one:
          '1 synkroniseringsbegivenhed, som køen opgav på. Tryk på prøv igen for at forsøge igen. ',
    );
    return '$_temp0';
  }

  @override
  String get queueSkippedCardTitle => 'Sprunget begivenheder over';

  @override
  String get queueSkippedRetryAll => 'Gentagne overspringsbegivenheder';

  @override
  String queueSkippedRetryAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count begivenheder i kø til genforsøg. ',
      one: '1 event i kø til genforsøg. ',
      zero: 'Ingen springede events over at prøve igen. ',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedRetryAllError(String reason) {
    return 'Forsøg mislykkedes: $reason';
  }

  @override
  String get referenceImageContinue => 'Fortsæt';

  @override
  String referenceImageContinueWithCount(int count) {
    return 'Fortsæt ($count)';
  }

  @override
  String get referenceImageLoadError =>
      'Kunne ikke indlæse billeder. Prøv venligst igen.';

  @override
  String get referenceImageSelectionSubtitle =>
      'Vælg op til 5 billeder for at styre AI\'ens visuelle stil';

  @override
  String get referenceImageSelectionTitle => 'Vælg referencebilleder';

  @override
  String get referenceImageSkip => 'Spring over';

  @override
  String get saveButton => 'Gem';

  @override
  String get saveButtonLabel => 'Gem';

  @override
  String get saveLabel => 'Gem';

  @override
  String get saveShortcutTooltip => 'Gem — Ctrl+S (⌘S på Mac)';

  @override
  String get saveSuccessful => 'Reddet med succes';

  @override
  String get searchHint => 'Søg...';

  @override
  String get searchModeFullText => 'Fuld tekst';

  @override
  String get searchModeVector => 'Vektor';

  @override
  String get searchTasksHint => 'Søgeopgaver...';

  @override
  String get selectButton => 'Vælg';

  @override
  String get selectColor => 'Vælg en farve';

  @override
  String get selectLanguage => 'Vælg sprog';

  @override
  String get sessionRatingCardLabel => 'Session-vurdering';

  @override
  String get sessionRatingChallengeJustRight => 'Lige tilpas';

  @override
  String get sessionRatingChallengeTooEasy => 'Alt for nemt';

  @override
  String get sessionRatingChallengeTooHard => 'For udfordrende';

  @override
  String get sessionRatingDifficultyLabel => 'Dette arbejde føltes...';

  @override
  String get sessionRatingEditButton => 'Redigeret vurdering';

  @override
  String get sessionRatingEnergyQuestion => 'Hvor energisk følte du dig?';

  @override
  String get sessionRatingFocusQuestion => 'Hvor fokuseret var du?';

  @override
  String get sessionRatingNoteHint => 'Hurtig note (valgfrit)';

  @override
  String get sessionRatingProductivityQuestion =>
      'Hvor produktiv var denne session?';

  @override
  String get sessionRatingRateAction => 'Rate Session';

  @override
  String get sessionRatingSaveButton => 'Gem';

  @override
  String get sessionRatingSaveError =>
      'Gemte ikke bedømmelse. Prøv venligst igen.';

  @override
  String get sessionRatingSkipButton => 'Spring over';

  @override
  String get sessionRatingTitle => 'Bedøm denne session';

  @override
  String get sessionRatingViewAction => 'Visningsvurdering';

  @override
  String get settingsAboutAppInformation => 'App-information';

  @override
  String get settingsAboutAppTagline => 'Din personlige dagbog';

  @override
  String get settingsAboutBuildType => 'Byggetype';

  @override
  String get settingsAboutDailyOsPersonalizationTitle =>
      'Daglig OS-personalisering';

  @override
  String get settingsAboutDailyOsUserNameHelper =>
      'Bruges til Daily OS-hilsen og synkroniseres på tværs af dine enheder.';

  @override
  String get settingsAboutDailyOsUserNameLabel => 'Dit navn';

  @override
  String get settingsAboutJournalEntries => 'Dagbogsindlæg';

  @override
  String get settingsAboutPlatform => 'Platform';

  @override
  String get settingsAboutTitle => 'Om Lotti';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutYourData => 'Dine data';

  @override
  String get settingsAdvancedAboutSubtitle => 'Lær mere om Lotti-applikationen';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Importer sundhedsrelaterede data fra eksterne kilder';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Udfør vedligeholdelsesopgaver for at optimere applikationsydelsen';

  @override
  String get settingsAdvancedManualLanguageSubtitle =>
      'Vælg hvilket sprog du vil åbne Lotti-manualen på';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Administrer synkroniserede elementer';

  @override
  String get settingsAdvancedSubtitle =>
      'Avancerede indstillinger og vedligeholdelse';

  @override
  String get settingsAdvancedTitle => 'Avancerede indstillinger';

  @override
  String get settingsAgentsInstancesSubtitle => 'Kørende agenter';

  @override
  String get settingsAgentsPendingWakesSubtitle => 'Planlagte vågetimere';

  @override
  String get settingsAgentsSoulsSubtitle => 'Langlivede agentpersonligheder';

  @override
  String get settingsAgentsStatsSubtitle => 'Tokenbrug og aktivitet';

  @override
  String get settingsAgentsTemplatesSubtitle => 'Fælles agent-blueprints';

  @override
  String get settingsAiModelsSubtitle =>
      'Per-leverandør modelrækker og kapabiliteter';

  @override
  String get settingsAiModelsTitle => 'Modeller';

  @override
  String get settingsAiProfilesSubtitle => 'Udbydere og modeller';

  @override
  String get settingsAiProfilesTitle => 'Inferensprofiler';

  @override
  String get settingsAiProvidersSubtitle => 'Forbundne AI-udbydere og nøgler';

  @override
  String get settingsAiProvidersTitle => 'Udbydere';

  @override
  String get settingsAiSubtitle =>
      'Konfigurer AI-udbydere, modeller og prompts';

  @override
  String get settingsAiTitle => 'AI-indstillinger';

  @override
  String get settingsAiUsageSubtitle =>
      'Omkostninger, energi og CO₂e af AI-opkald';

  @override
  String get settingsAiUsageTitle => 'Anvendelse og indvirkning';

  @override
  String get settingsBeamPageEditModelTitle => 'Rediger model';

  @override
  String get settingsBeamPageEditProfileTitle => 'Rediger profil';

  @override
  String get settingsCategoriesCreateTitle => 'Opret kategori';

  @override
  String get settingsCategoriesDetailsLabel => 'Rediger kategori';

  @override
  String get settingsCategoriesEmptyState => 'Ingen kategorier endnu';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Opret en kategori til at organisere dine bidrag';

  @override
  String get settingsCategoriesErrorLoading => 'Fejlindlæsningskategorier';

  @override
  String get settingsCategoriesNameLabel => 'Kategorinavn';

  @override
  String settingsCategoriesNoMatchQuery(String query) {
    return 'Ingen kategorier matcher \"$query\"';
  }

  @override
  String get settingsCategoriesSearchHint => 'Søgekategorier...';

  @override
  String get settingsCategoriesSubtitle => 'Kategorier med AI-indstillinger';

  @override
  String settingsCategoriesTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opgaver',
      one: '$count opgave',
    );
    return '$_temp0';
  }

  @override
  String get settingsCategoriesTitle => 'Kategorier';

  @override
  String get settingsCelebrationsChecklistDescription =>
      'Et pop og gnister, når du krydser en genstand af';

  @override
  String get settingsCelebrationsChecklistTitle => 'Tjeklistepunkter';

  @override
  String get settingsCelebrationsCustomizeTitle => 'Tilpas';

  @override
  String get settingsCelebrationsCustomizeTooltip => 'Tilpas denne stil';

  @override
  String get settingsCelebrationsEnabledDescription =>
      'Master switch til fuldførelsesudsmykninger. Off skjuler alle animationer; Haptikere beholder deres egen kontakt.';

  @override
  String get settingsCelebrationsEnabledTitle => 'Fejringsanimationer';

  @override
  String get settingsCelebrationsGroupLook => 'Se';

  @override
  String get settingsCelebrationsGroupMotion => 'Bevægelse';

  @override
  String get settingsCelebrationsGroupShape => 'Form';

  @override
  String get settingsCelebrationsHabitsDescription =>
      'Glød og gnistrede, når du gennemfører en vane';

  @override
  String get settingsCelebrationsHabitsTitle => 'Vaner';

  @override
  String get settingsCelebrationsHapticsDescription =>
      'En kort summen, når du er færdig med noget — uafhængigt af animationen.';

  @override
  String get settingsCelebrationsHapticsTitle => 'Fuldstændig haptik';

  @override
  String get settingsCelebrationsKnobClearCenter => 'Mellemrum';

  @override
  String get settingsCelebrationsKnobCount => 'Partikler';

  @override
  String get settingsCelebrationsKnobDescClearCenter => 'Tomt rum i midten';

  @override
  String get settingsCelebrationsKnobDescCount =>
      'Hvor mange partikler flyver ud';

  @override
  String get settingsCelebrationsKnobDescFallout =>
      'Hvor langt gnister driver ned';

  @override
  String get settingsCelebrationsKnobDescFanSpread => 'Bredde på ventilatoren';

  @override
  String get settingsCelebrationsKnobDescGlow => 'Styrken af gløden';

  @override
  String get settingsCelebrationsKnobDescGravity =>
      'Hvor hurtigt partikler falder';

  @override
  String get settingsCelebrationsKnobDescHalo => 'Haloens styrke';

  @override
  String get settingsCelebrationsKnobDescInnerRing =>
      'Størrelsen på den indre ring';

  @override
  String get settingsCelebrationsKnobDescLaunch => 'Forsinkelse før udbruddet';

  @override
  String get settingsCelebrationsKnobDescPop => 'Når de springer';

  @override
  String get settingsCelebrationsKnobDescReach =>
      'Hvor langt partikler bevæger sig';

  @override
  String get settingsCelebrationsKnobDescRise =>
      'Hvordan partikler stiger højt';

  @override
  String get settingsCelebrationsKnobDescSize => 'Hvor stor hver partikel er';

  @override
  String get settingsCelebrationsKnobDescSpeedSpread =>
      'Variation i partikelhastighed';

  @override
  String get settingsCelebrationsKnobDescSpin =>
      'Hvor hurtigt brikkerne drejer';

  @override
  String get settingsCelebrationsKnobDescSpread => 'Bredden af sprøjtet';

  @override
  String get settingsCelebrationsKnobDescSway => 'Hvor meget brikkerne svajer';

  @override
  String get settingsCelebrationsKnobDescSwell => 'Hvor meget de vokser';

  @override
  String get settingsCelebrationsKnobDescTrail => 'Længde af hver sti';

  @override
  String get settingsCelebrationsKnobDescTwinkle =>
      'Hvor meget partikler blinker';

  @override
  String get settingsCelebrationsKnobDescUpward => 'Hvor stærkt de stiger';

  @override
  String get settingsCelebrationsKnobDescWobble => 'Hvor meget brikker vipper';

  @override
  String get settingsCelebrationsKnobFallout => 'Eftervirkninger';

  @override
  String get settingsCelebrationsKnobFanSpread => 'Viftespredning';

  @override
  String get settingsCelebrationsKnobGlow => 'Glød';

  @override
  String get settingsCelebrationsKnobGravity => 'Tyngdekraft';

  @override
  String get settingsCelebrationsKnobHalo => 'Halo';

  @override
  String get settingsCelebrationsKnobInnerRing => 'Indre ring';

  @override
  String get settingsCelebrationsKnobLaunch => 'Opsendelsestid';

  @override
  String get settingsCelebrationsKnobPop => 'Poppunkt';

  @override
  String get settingsCelebrationsKnobReach => 'Rækkevidde';

  @override
  String get settingsCelebrationsKnobRise => 'Højde';

  @override
  String get settingsCelebrationsKnobSize => 'Størrelse';

  @override
  String get settingsCelebrationsKnobSpeedSpread => 'Hastighedsvariation';

  @override
  String get settingsCelebrationsKnobSpin => 'Spin';

  @override
  String get settingsCelebrationsKnobSpread => 'Spredningsbue';

  @override
  String get settingsCelebrationsKnobSway => 'Svaj';

  @override
  String get settingsCelebrationsKnobSwell => 'Fedt';

  @override
  String get settingsCelebrationsKnobTrail => 'Stiens længde';

  @override
  String get settingsCelebrationsKnobTwinkle => 'Blink';

  @override
  String get settingsCelebrationsKnobUpward => 'Stigning';

  @override
  String get settingsCelebrationsKnobWobble => 'Vippe';

  @override
  String get settingsCelebrationsPlaygroundHint =>
      'Tryk på den fremhævede række for at forhåndsvise';

  @override
  String get settingsCelebrationsPlaygroundLiveNote =>
      'Ændringer gemmer og gælder overalt med det samme';

  @override
  String get settingsCelebrationsPreviewChecklistItem => 'Tjek mig';

  @override
  String get settingsCelebrationsPreviewDescription =>
      'Tryk på en kontrol for at spille din valgte stil.';

  @override
  String get settingsCelebrationsPreviewDone => 'Færdig';

  @override
  String get settingsCelebrationsPreviewHabit => 'Habit';

  @override
  String get settingsCelebrationsPreviewSample1 => 'Morgentur';

  @override
  String get settingsCelebrationsPreviewSample2 => 'Færdiggør rapporten';

  @override
  String get settingsCelebrationsPreviewSample3 => 'Vand planterne';

  @override
  String get settingsCelebrationsPreviewTitle => 'Prøv det';

  @override
  String get settingsCelebrationsReplay => 'Omkamp';

  @override
  String get settingsCelebrationsResetToast => 'Stilnulstilling til standard';

  @override
  String get settingsCelebrationsResetToDefault => 'Nulstil til standard';

  @override
  String get settingsCelebrationsResetUndo => 'Fortryd';

  @override
  String get settingsCelebrationsSectionDescription =>
      'Spil et flourish, når du er færdig med noget. At slå én fra bevarer fuldførelsen, og den er haptisk — den springer bare animationen over.';

  @override
  String get settingsCelebrationsSectionTitle => 'Fejring af færdiggørelse';

  @override
  String get settingsCelebrationsStyleDescription =>
      'Tryk på et kort for at forhåndsvise en feststil og gør den til din.';

  @override
  String get settingsCelebrationsStyleTitle => 'Stil';

  @override
  String get settingsCelebrationsSubtitle => 'Fejring af færdiggørelse';

  @override
  String get settingsCelebrationsTasksDescription =>
      'Gløder og gnistrer, når du flytter en opgave til Færdig';

  @override
  String get settingsCelebrationsTasksTitle => 'Opgaver';

  @override
  String get settingsCelebrationsTitle => 'Underholdning';

  @override
  String get settingsCelebrationsVariantBubbles => 'Bobler';

  @override
  String get settingsCelebrationsVariantCombine => 'Kombiner to';

  @override
  String get settingsCelebrationsVariantCombineDescription =>
      'To tilfældige stilarter, lagdelt, hver gang';

  @override
  String get settingsCelebrationsVariantConfetti => 'Konfetti';

  @override
  String get settingsCelebrationsVariantEmbers => 'Embers';

  @override
  String get settingsCelebrationsVariantFireworks => 'Fyrværkeri';

  @override
  String get settingsCelebrationsVariantRandom => 'Tilfældigt';

  @override
  String get settingsCelebrationsVariantRandomDescription =>
      'En frisk stil ved hver færdiggørelse';

  @override
  String get settingsCelebrationsVariantSparks => 'Sparks';

  @override
  String get settingsConflictsTitle => 'Synkroniseringskonflikter';

  @override
  String get settingsDashboardDetailsLabel => 'Rediger dashboard.';

  @override
  String get settingsDashboardSaveLabel => 'Gem';

  @override
  String get settingsDashboardsCreateTitle => 'Opret dashboard.';

  @override
  String get settingsDashboardsEmptyState => 'Ingen dashboards endnu';

  @override
  String get settingsDashboardsEmptyStateHint =>
      'Tryk på +-knappen for at oprette dit første dashboard.';

  @override
  String get settingsDashboardsErrorLoading => 'Fejlindlæsning af dashboards';

  @override
  String settingsDashboardsNoMatchQuery(String query) {
    return 'Ingen dashboards matcher \"$query\"';
  }

  @override
  String get settingsDashboardsSearchHint => 'Søge dashboards...';

  @override
  String get settingsDashboardsSubtitle => 'Tilpas dine dashboardvisninger';

  @override
  String get settingsDashboardsTitle => 'Dashboards';

  @override
  String get settingsDefinitionsSubtitle =>
      'Vaner, kategorier, etiketter, dashboards og målbare ting';

  @override
  String get settingsDefinitionsTitle => 'Definitioner';

  @override
  String get settingsFlagsEmptySearch => 'Ingen flag matcher din søgning';

  @override
  String get settingsFlagsSearchHint => 'Søgeflag';

  @override
  String get settingsFlagsSubtitle =>
      'Konfigurer funktionsflag og indstillinger';

  @override
  String get settingsFlagsTitle => 'Konfigurationsflag';

  @override
  String get settingsHabitsCreateTitle => 'Skab vaner';

  @override
  String get settingsHabitsDeleteTooltip => 'Slet vane';

  @override
  String get settingsHabitsDescriptionLabel => 'Beskrivelse (valgfrit)';

  @override
  String get settingsHabitsDetailsLabel => 'Redigeringsvane';

  @override
  String get settingsHabitsEmptyState => 'Ingen vaner endnu';

  @override
  String get settingsHabitsEmptyStateHint =>
      'Tryk på +-knappen for at oprette din første vane.';

  @override
  String get settingsHabitsErrorLoading => 'Fejlindlæsningsvaner';

  @override
  String get settingsHabitsNameLabel => 'Habitnavn';

  @override
  String settingsHabitsNoMatchQuery(String query) {
    return 'Ingen vaner matcher \"$query\"';
  }

  @override
  String get settingsHabitsPrivateLabel => 'Privat: ';

  @override
  String get settingsHabitsSaveLabel => 'Gem';

  @override
  String get settingsHabitsSearchHint => 'Søgevaner...';

  @override
  String get settingsHabitsSubtitle => 'Styr dine vaner og rutiner';

  @override
  String get settingsHabitsTitle => 'Vaner';

  @override
  String get settingsHealthImportActivity => 'Importer aktivitetsdata';

  @override
  String get settingsHealthImportBloodPressure => 'Importer blodtryksdata';

  @override
  String get settingsHealthImportBodyMeasurement => 'Import af kropsmåledata';

  @override
  String get settingsHealthImportFromDate => 'Start';

  @override
  String get settingsHealthImportHeartRate => 'Importer pulsdata';

  @override
  String get settingsHealthImportSleep => 'Importer søvndata';

  @override
  String get settingsHealthImportTitle => 'Sundhedsimport';

  @override
  String get settingsHealthImportToDate => 'Slut';

  @override
  String get settingsHealthImportWorkout => 'Importer træningsdata';

  @override
  String get settingsKeyboardShortcutsSubtitle =>
      'Lær tastaturkombinationerne for hurtigere navigation og redigering på skrivebordet';

  @override
  String get settingsKeyboardShortcutsTitle => 'Tastaturgenveje';

  @override
  String get settingsLabelsCategoriesAdd => 'Tilføj kategori';

  @override
  String get settingsLabelsCategoriesHeading => 'Relevante kategorier';

  @override
  String get settingsLabelsCategoriesNone => 'Gælder for alle kategorier';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Fjern';

  @override
  String get settingsLabelsColorHeading => 'Farve';

  @override
  String get settingsLabelsColorSubheading => 'Hurtige forudindstillinger';

  @override
  String get settingsLabelsCreateTitle => 'Opret label';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Slet';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return 'Er du sikker på, at du vil slette \"$labelName\"? Opgaver med denne etiket mister opgaven.';
  }

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Slet mærkaten';

  @override
  String settingsLabelsDeleteSuccess(Object labelName) {
    return 'Label \"$labelName\" slettet';
  }

  @override
  String get settingsLabelsDescriptionHint =>
      'Forklar, hvornår du skal anvende denne mærkat.';

  @override
  String get settingsLabelsDescriptionLabel => 'Beskrivelse (valgfrit)';

  @override
  String get settingsLabelsEditTitle => 'Rediger etikett';

  @override
  String get settingsLabelsEmptyState => 'Ingen etiketter endnu';

  @override
  String get settingsLabelsEmptyStateHint =>
      'Tryk på +-knappen for at oprette din første label.';

  @override
  String get settingsLabelsErrorLoading => 'Ikke indlæst etiketter';

  @override
  String get settingsLabelsNameHint =>
      'Fejl, frigivelsesblokering, synkronisering...';

  @override
  String get settingsLabelsNameLabel => 'Pladeselskabets navn';

  @override
  String settingsLabelsNoMatchCreate(String query) {
    return 'Opret \"$query\"-mærkaten';
  }

  @override
  String settingsLabelsNoMatchQuery(String query) {
    return 'Ingen etiketter matcher \"$query\"';
  }

  @override
  String get settingsLabelsPrivateDescription =>
      'Kun synlig, når private bidrag vises';

  @override
  String get settingsLabelsPrivateTitle => 'Privat';

  @override
  String get settingsLabelsSearchHint => 'Søgeetiketter...';

  @override
  String get settingsLabelsSubtitle =>
      'Organiser opgaver med farvede etiketter';

  @override
  String get settingsLabelsTitle => 'Etiketter';

  @override
  String settingsLabelsUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opgaver',
      one: '1 opgave',
    );
    return '$_temp0';
  }

  @override
  String get settingsLoggingDomainsSubtitle =>
      'Styr hvilke domæner der skriver til logbogen';

  @override
  String get settingsLoggingDomainsTitle => 'Logningsdomæner';

  @override
  String get settingsLoggingGlobalToggle => 'Aktiver logning';

  @override
  String get settingsLoggingGlobalToggleSubtitle =>
      'Hovedkontakt til al skovning';

  @override
  String get settingsLoggingSlowQueries => 'Langsomme databaseforespørgsler';

  @override
  String get settingsLoggingSlowQueriesSubtitle =>
      'Skriver langsomme forespørgsler til slow_queries-YYYY-MM-DD.log';

  @override
  String get settingsMaintenanceOnboardingAnimationGallerySubtitle =>
      'Sammenlign velkomstanimationer + forbind side live (fejlsøgning)';

  @override
  String get settingsMaintenanceOnboardingAnimationGalleryTitle =>
      'Onboarding animationsgalleri';

  @override
  String get settingsMaintenanceOnboardingWelcomeSubtitle =>
      'Forhåndsvisning af FTUE-velkomsten + udbyderfliser (fejlfinding)';

  @override
  String get settingsMaintenanceOnboardingWelcomeTitle =>
      'Velkommen til introduktion af programmet';

  @override
  String get settingsMaintenanceTitle => 'Vedligeholdelse';

  @override
  String get settingsManualLanguageCzechTitle => 'Tjekkisk';

  @override
  String get settingsManualLanguageDanishTitle => 'Dansk';

  @override
  String get settingsManualLanguageDutchTitle => 'Hollandsk';

  @override
  String get settingsManualLanguageEnglishTitle => 'Engelsk';

  @override
  String get settingsManualLanguageFollowSystemSubtitle =>
      'Brug dit enhedssprog, når manualen understøtter det; ellers brug engelsk.';

  @override
  String get settingsManualLanguageFollowSystemTitle => 'Følg systemet';

  @override
  String get settingsManualLanguageFrenchTitle => 'Fransk';

  @override
  String get settingsManualLanguageGermanTitle => 'Tysk';

  @override
  String get settingsManualLanguageItalianTitle => 'Italiensk';

  @override
  String get settingsManualLanguagePortugueseTitle => 'Portugisisk';

  @override
  String get settingsManualLanguageRomanianTitle => 'Rumænsk';

  @override
  String get settingsManualLanguageSpanishTitle => 'Spansk';

  @override
  String get settingsManualLanguageSwedishTitle => 'Svensk';

  @override
  String get settingsManualLanguageTitle => 'Sprog';

  @override
  String get settingsMatrixAccept => 'Accepter';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'Anden enhed viser emojis, fortsæt';

  @override
  String get settingsMatrixCancel => 'Annuller';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Accepter på en anden enhed for at fortsætte';

  @override
  String get settingsMatrixDiagnosticCopied =>
      'Diagnostisk info kopieret til clipboard';

  @override
  String get settingsMatrixDiagnosticCopyButton => 'Kopier til udklipsholderen';

  @override
  String get settingsMatrixDiagnosticDialogTitle =>
      'Synkroniseringsdiagnostisk info';

  @override
  String get settingsMatrixDiagnosticShowButton => 'Vis diagnostisk info';

  @override
  String get settingsMatrixDone => 'Færdig';

  @override
  String get settingsMatrixLastUpdated => 'Sidst opdateret:';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Uverificerede enheder';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Kør Matrix-vedligeholdelsesopgaver og gendannelsesværktøjer';

  @override
  String get settingsMatrixMaintenanceTitle => 'Vedligeholdelse';

  @override
  String get settingsMatrixMetrics => 'Synkroniseringsmålinger';

  @override
  String get settingsMatrixNextPage => 'Næste side';

  @override
  String get settingsMatrixNoUnverifiedLabel => 'Ingen uverificerede enheder';

  @override
  String get settingsMatrixPreviousPage => 'Forrige side';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Inviter til værelse $roomId fra $senderId. Acceptere?';
  }

  @override
  String get settingsMatrixRoomInviteTitle => 'Værelsesinvitation';

  @override
  String get settingsMatrixSentMessagesLabel => 'Sendte beskeder:';

  @override
  String settingsMatrixSentMessageType(String eventType) {
    return 'Sendt ($eventType)';
  }

  @override
  String get settingsMatrixStartVerificationLabel => 'Start verifikation';

  @override
  String get settingsMatrixStatsTitle => 'Matrixstatistikker';

  @override
  String get settingsMatrixTitle => 'Synkroniseringsindstillinger';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Uverificerede enheder';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Annulleret på anden enhed...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Forstået';

  @override
  String settingsMatrixVerificationSuccessLabel(
    String deviceName,
    String deviceID,
  ) {
    return 'Du har med succes verificeret $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Bekræft på den anden enhed, at emojis nedenfor vises på begge enheder, i samme rækkefølge:';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Bekræft, at emojis nedenfor vises på begge enheder i samme rækkefølge:';

  @override
  String get settingsMatrixVerifyLabel => 'Bekræft';

  @override
  String get settingsMeasurableAggregationHelper =>
      'Hvordan dagens indgange kombineres på diagrammer';

  @override
  String get settingsMeasurableAggregationLabel => 'Standard aggregeringstype';

  @override
  String get settingsMeasurableDeleteTooltip => 'Slet målbar type';

  @override
  String get settingsMeasurableDescriptionLabel => 'Beskrivelse (valgfrit)';

  @override
  String get settingsMeasurableDetailsLabel => 'Redigeret målbar';

  @override
  String get settingsMeasurableNameLabel => 'Målbart navn';

  @override
  String get settingsMeasurablePrivateLabel => 'Privat: ';

  @override
  String get settingsMeasurableSaveLabel => 'Gem';

  @override
  String get settingsMeasurablesCreateTitle => 'Skab målbar';

  @override
  String get settingsMeasurablesEmptyState => 'Ingen målbare ting endnu';

  @override
  String get settingsMeasurablesEmptyStateHint =>
      'Målbare tal er tal, du følger over tid — vægt, vand, skridt.';

  @override
  String get settingsMeasurablesErrorLoading => 'Fejlindlæsning af målbare';

  @override
  String settingsMeasurablesNoMatchQuery(String query) {
    return 'Ingen målbare størrelser matcher \"$query\"';
  }

  @override
  String get settingsMeasurablesSearchHint => 'Søgemål...';

  @override
  String get settingsMeasurablesSubtitle => 'Konfigurér målbare datatyper';

  @override
  String get settingsMeasurablesTitle => 'Målbare ting';

  @override
  String get settingsMeasurableUnitLabel => 'Enhedsforkortelse (valgfrit)';

  @override
  String get settingsOnboardingActionSubtitle =>
      'Genopblæs velkomstflowet — forbind din AI-hjerne og skab en opgave';

  @override
  String get settingsOnboardingMetricsSubtitle =>
      'FTUE-tragt — installation, aktivering, fastholdelse (fejlsøgning)';

  @override
  String get settingsOnboardingMetricsTitle => 'Onboarding-målinger';

  @override
  String get settingsOnboardingReplayTitle => 'Genafspilning onboarding';

  @override
  String get settingsOnboardingStartTitle => 'Start onboarding';

  @override
  String get settingsOnboardingStatusActivated =>
      'Du har skabt din første AI-opgave';

  @override
  String get settingsOnboardingStatusLoading => 'Indlæser...';

  @override
  String get settingsOnboardingStatusNotActivated => 'Ikke begyndt endnu';

  @override
  String get settingsOnboardingStatusTitle => 'Status';

  @override
  String get settingsOnboardingSubtitle =>
      'Afspil velkomstflowet når som helst';

  @override
  String get settingsOnboardingTestResetConfirm => 'Nulstil';

  @override
  String get settingsOnboardingTestResetConfirmQuestion =>
      'Klar onboarding-prompthistorik og målinger? Eksisterende Daily OS-planer er stadig tilgængelige, så brug en ren profil til at teste den komplette første gennemgang af Daily OS.';

  @override
  String get settingsOnboardingTestResetSubtitle =>
      'Klar prompthistorik og målinger; eksisterende Daily OS-planer er fortsat (fejlfinding)';

  @override
  String get settingsOnboardingTestResetTitle =>
      'Nulstil onboarding-teststatus';

  @override
  String get settingsOnboardingTitle => 'Onboarding';

  @override
  String get settingsOptionsTitle => 'Muligheder';

  @override
  String get settingsRecordingStyleExplanation =>
      'Vælg hvordan mikrofonen ser ud, mens du optager.';

  @override
  String get settingsRecordingStyleSubtitle =>
      'VU-måler eller energikugle under optagelse';

  @override
  String get settingsRecordingStyleTitle => 'Indspilningsstil';

  @override
  String get settingsResetGeminiConfirm => 'Nulstil';

  @override
  String get settingsResetGeminiConfirmQuestion =>
      'Dette vil vise Gemini-opsætningsdialogen igen. Fortsæt?';

  @override
  String get settingsResetGeminiSubtitle =>
      'Vis Gemini AI opsætningsdialogen igen';

  @override
  String get settingsResetGeminiTitle => 'Nulstil Gemini opsætningsdialog';

  @override
  String get settingsResetHintsConfirm => 'Bekræft';

  @override
  String get settingsResetHintsConfirmQuestion =>
      'Nulstille hints i appen, der vises på tværs af appen?';

  @override
  String settingsResetHintsResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nulstil $count hints',
      one: 'Nulstil ét hint',
      zero: 'Nul hints',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetHintsSubtitle =>
      'Klare engangstips og onboarding-tips';

  @override
  String get settingsResetHintsTitle => 'Nulstil tips i appen';

  @override
  String get settingsSpeechSubtitle => 'Stemme og højtlæsning';

  @override
  String get settingsSpeechTitle => 'Tale';

  @override
  String get settingsSyncConflictsSubtitle =>
      'Løs synkroniseringskonflikter for at sikre datakonsistens';

  @override
  String get settingsSyncNodeProfileCapabilitiesEmpty =>
      'Ingen opdaget — automatisk udløser af synkroniseret lydinferens vil ikke målrette denne enhed.';

  @override
  String get settingsSyncNodeProfileCapabilitiesLabel =>
      'Opdagede AI-kapaciteter';

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
      'Synligt for dine andre enheder, når du vælger, hvilken profil du vil fastgøre til.';

  @override
  String get settingsSyncNodeProfileDisplayNameLabel => 'Enhedsnavn';

  @override
  String get settingsSyncNodeProfileKnownNodesEmpty =>
      'Ingen andre enheder har endnu offentliggjort en profil.';

  @override
  String get settingsSyncNodeProfileKnownNodesTitle =>
      'Kendte synkroniseringsenheder';

  @override
  String get settingsSyncNodeProfileSaveButton => 'Gem';

  @override
  String get settingsSyncNodeProfileSubtitle =>
      'Navngiv denne enhed og gennemgå funktioner, der er synlige for dine andre enheder.';

  @override
  String get settingsSyncNodeProfileTitle => 'Denne enhed';

  @override
  String get settingsSyncOutboxTitle => 'Sync Outbox';

  @override
  String get settingsSyncStatsSubtitle =>
      'Inspicer synkroniserings-pipelinemetrikker';

  @override
  String get settingsSyncSubtitle =>
      'Konfigurer synkronisering og vis statistikker';

  @override
  String get settingsThemingAutomatic => 'Automatisk';

  @override
  String get settingsThemingDark => 'Mørkt udseende';

  @override
  String get settingsThemingLight => 'Lys udseende';

  @override
  String get settingsThemingSubtitle => 'Tilpas appens udseende og temaer';

  @override
  String get settingsThemingTitle => 'Tematisering';

  @override
  String get settingsV2CategoryEmptyBody =>
      'Vælg en underindstilling til venstre.';

  @override
  String get settingsV2DetailRootCrumb => 'Indstillinger';

  @override
  String get settingsV2EmptyStateBody =>
      'Vælg et afsnit til venstre for at begynde.';

  @override
  String get settingsV2ResizeHandleLabel => 'Ændr størrelsesindstillingstræet';

  @override
  String get settingsV2UnimplementedTitle => 'Panel endnu ikke implementeret';

  @override
  String get settingsWhatsNewSubtitle =>
      'Se de seneste opdateringer og funktioner';

  @override
  String get settingsWhatsNewTitle => 'Hvad er nyt';

  @override
  String get settingThemingDark => 'Mørkt tema';

  @override
  String get settingThemingLight => 'Lystema';

  @override
  String get sidebarActiveSectionTitle => 'Aktivitet';

  @override
  String get sidebarActivityCollapseTooltip => 'Kollapsaktivitet';

  @override
  String get sidebarActivityExpandTooltip => 'Udvid aktiviteten';

  @override
  String get sidebarAudioRecordingStatusLabel => 'Indspilning';

  @override
  String get sidebarRunningTimerLabel => 'Løbende timer';

  @override
  String get sidebarRunningTimerStopTooltip => 'Stoptimer';

  @override
  String get sidebarTimerStatusLabel => 'Åbningstider';

  @override
  String get sidebarToggleCollapseLabel => 'Sammenklappningssidebjælke';

  @override
  String get sidebarToggleExpandLabel => 'Udvid sidebjælken';

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
  String get sidebarWakesCancelTooltip => 'Annulleringsagent';

  @override
  String get sidebarWakesHeader => 'Agenter';

  @override
  String get sidebarWakesNow => 'Nu';

  @override
  String get sidebarWakesOpenList => 'Åben liste';

  @override
  String get sidebarWakesOpenTask => 'Åben opgave';

  @override
  String sidebarWakesQueuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count i kø ',
      one: '1 i kø',
    );
    return '$_temp0';
  }

  @override
  String get sidebarWakesQueuedLabel => 'Sat i kø';

  @override
  String get sidebarWakesWorkingLabel => 'Arbejde';

  @override
  String get skillsSectionTitle => 'Færdigheder';

  @override
  String get speechDictionaryHelper =>
      'Selektionsseparerede termer (maksimalt 50 tegn) for bedre talegenkendelse';

  @override
  String get speechDictionaryHint => 'macOS; Kirkjubæjarklaustur; Claude Code';

  @override
  String get speechDictionaryLabel => 'Taleordbog';

  @override
  String get speechDictionarySectionDescription =>
      'Tilføj termer, der ofte staves forkert af talegenkendelse (navne, steder, tekniske termer)';

  @override
  String get speechDictionarySectionTitle => 'Tagenkendelse';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Store ordbøger ($count termer) kan øge API-omkostningerne';
  }

  @override
  String get speechModalSelectLanguage => 'Vælg sprog';

  @override
  String get speechModalTitle => 'Talutegenkendelse';

  @override
  String get speechSettingsModelDescription => 'On-device talemodel';

  @override
  String get speechSettingsModelDownloadsOnce => 'Downloads én gang';

  @override
  String get speechSettingsModelLabel => 'Model';

  @override
  String get speechSettingsRecommendedBadge => 'Anbefalet';

  @override
  String get speechSettingsSpeedDescription => 'Hvor hurtigt resuméer læses';

  @override
  String get speechSettingsSpeedLabel => 'Læsehastighed';

  @override
  String get speechSettingsVoiceDescription =>
      'Vælg stemmen, der læser resuméer højt';

  @override
  String get speechSettingsVoiceLabel => 'Stemme';

  @override
  String get speechVoiceGenderFemale => 'Kvinde';

  @override
  String get speechVoiceGenderMale => 'Mand';

  @override
  String get speechVoicePreviewTooltip => 'Forhåndsvisning af stemme';

  @override
  String get surveyBackButton => 'Tilbage';

  @override
  String get surveyCancelConfirmation => 'Aflys undersøgelsen?';

  @override
  String get surveyChooseOneOption => 'Vælg én mulighed';

  @override
  String get surveyChooseOneOrMoreOptions => 'Vælg en eller flere muligheder';

  @override
  String get surveyDiscardConfirmation => 'Kassere resultater og stoppe?';

  @override
  String get surveyInputNumberValidation => 'Indtast et nummer';

  @override
  String get surveyNextButton => 'Næste';

  @override
  String get surveyNoButton => 'Nej';

  @override
  String get surveyProgressOf => 'af';

  @override
  String get surveyTapToAnswer => 'Tryk for at svare';

  @override
  String get surveyValueAnd => 'og';

  @override
  String get surveyValueBetween => 'Må være imellem';

  @override
  String get surveyYesButton => 'Ja';

  @override
  String get syncActivityIdle => 'Ledig';

  @override
  String get syncActivityInboxLabel => 'Indbakke';

  @override
  String syncActivityIndicatorSemantics(int outbox, int inbox) {
    return 'Synkroniser aktivitet. Udboks: $outbox. Indbakke: $inbox. Åbn sync outbox.';
  }

  @override
  String get syncActivityOutboxLabel => 'Udboks';

  @override
  String get syncActivitySyncingTitle => 'Synkronisering';

  @override
  String get syncActivityTitle => 'Sync';

  @override
  String get syncDeleteConfigConfirm => 'JA, JEG ER SIKKER';

  @override
  String get syncDeleteConfigQuestion =>
      'Vil du slette synkroniseringskonfigurationen?';

  @override
  String get syncEntitiesConfirm => 'START SYNC';

  @override
  String get syncEntitiesMessage => 'Vælg de enheder, du vil synkronisere.';

  @override
  String get syncEntitiesSuccessDescription => 'Alt er opdateret.';

  @override
  String get syncEntitiesSuccessTitle => 'Synkronisering fuldført';

  @override
  String syncListCountSummary(String label, int itemCount) {
    String _temp0 = intl.Intl.pluralLogic(
      itemCount,
      locale: localeName,
      other: '$itemCount genstande',
      one: '1 genstand',
      zero: '0 genstande',
    );
    return '$label · $_temp0';
  }

  @override
  String get syncListPayloadKindLabel => 'Nyttelast';

  @override
  String get syncListUnknownPayload => 'Ukendt nyttelast';

  @override
  String get syncNotLoggedInToast => 'Sync er ikke logget ind';

  @override
  String get syncPayloadAgentBundle => 'Agentbundt';

  @override
  String get syncPayloadAgentEntity => 'Agentenhed';

  @override
  String get syncPayloadAgentLink => 'Agentlink';

  @override
  String get syncPayloadAiConfig => 'AI-konfiguration';

  @override
  String get syncPayloadAiConfigDelete => 'AI-konfigurationssletning';

  @override
  String get syncPayloadBackfillRequest => 'Anmodning om tilbagefyldning';

  @override
  String get syncPayloadBackfillResponse => 'Tilbagefyldningsrespons';

  @override
  String get syncPayloadConfigFlag => 'Konfigurationsflag';

  @override
  String get syncPayloadConsumptionEvent => 'AI-forbrug';

  @override
  String get syncPayloadDailyOsUserName => 'Daily OS-navn';

  @override
  String get syncPayloadEntityDefinition => 'Entitetsdefinition';

  @override
  String get syncPayloadEntryLink => 'Indgangslink';

  @override
  String get syncPayloadJournalEntity => 'Dagbogsindlæg';

  @override
  String get syncPayloadNotification => 'Underretning';

  @override
  String get syncPayloadNotificationStateUpdate =>
      'Opdatering af notifikationsstatus';

  @override
  String get syncPayloadOutboxBundle => 'Udboks-bundt';

  @override
  String get syncPayloadSavedTaskFilter => 'Gemt opgavefilter';

  @override
  String get syncPayloadSavedTaskFilterDelete =>
      'Slet filter for gemte opgaver';

  @override
  String get syncPayloadSyncNodeProfile => 'Synkroniseringsnodeprofil';

  @override
  String get syncPayloadThemingSelection => 'Valg af tema';

  @override
  String get syncStepAgentEntities => 'Agentenheder';

  @override
  String get syncStepAgentLinks => 'Agentlinks';

  @override
  String get syncStepAiSettings => 'AI-indstillinger';

  @override
  String get syncStepBackfillAgentEntityClocks =>
      'Tilbagefyldningsagent-entitetsure';

  @override
  String get syncStepBackfillAgentLinkClocks => 'Tilbagefyldningsagent-linkure';

  @override
  String get syncStepCategories => 'Kategorier';

  @override
  String get syncStepComplete => 'Komplet';

  @override
  String get syncStepDashboards => 'Dashboards';

  @override
  String get syncStepHabits => 'Vaner';

  @override
  String get syncStepLabels => 'Etiketter';

  @override
  String get syncStepMeasurables => 'Målbare ting';

  @override
  String get syncStepSavedTaskFilters => 'Gemte opgavefiltre';

  @override
  String get taskActionBarAudioRecordingActive => 'Lydoptagelse i gang';

  @override
  String get taskActionBarMoreActions => 'Flere aktioner';

  @override
  String get taskActionBarOpenRunningTimer => 'Åben løbetimer';

  @override
  String get taskActionBarStopTracking => 'Stop tidsregistrering';

  @override
  String get taskActionBarTrackTime => 'Banetid';

  @override
  String get taskAgentAttributionUnavailable => 'Kilde ikke tilgængelig';

  @override
  String get taskAgentAutomaticUpdatesLabel => 'Automatiske opdateringer';

  @override
  String get taskAgentAutomaticUpdatesNeedsSetup =>
      'Vælg en AI-opsætning, før du aktiverer automatiske opdateringer.';

  @override
  String get taskAgentCancelTimerTooltip =>
      'Annuller afventende automatisk opdatering';

  @override
  String get taskAgentChooseModel => 'Vælg en tænkemodel';

  @override
  String get taskAgentChooseProfile => 'Vælg en inferensprofil';

  @override
  String taskAgentCountdownTooltip(String countdown) {
    return 'Næste auto-run i $countdown';
  }

  @override
  String get taskAgentCreateChipLabel => 'Tildelte agent';

  @override
  String taskAgentCreateError(String error) {
    return 'Fejlede i at oprette agent: $error';
  }

  @override
  String get taskAgentCurrentSetupHeader => 'Nuværende opsætning';

  @override
  String get taskAgentCurrentSetupLabel => 'Nuværende opsætning';

  @override
  String get taskAgentDirectModelOverride => 'Direkte modeloverstyring';

  @override
  String get taskAgentDisableConfirmAction => 'Sluk';

  @override
  String get taskAgentDisableConfirmBody =>
      'Den aktuelle rapport forbliver synlig, men denne agent kan ikke køre, før du vælger en opsætning.';

  @override
  String get taskAgentDisableConfirmTitle =>
      'Skal jeg slå AI fra for denne agent?';

  @override
  String get taskAgentInferenceProfileLabel => 'Inferensprofil';

  @override
  String get taskAgentModelPickerTitle => 'Vælg tænkemodel';

  @override
  String taskAgentNextUpdateIn(String countdown) {
    return 'Næste opdatering i $countdown';
  }

  @override
  String get taskAgentNoAiSetup => 'Ingen AI-opsætning';

  @override
  String get taskAgentNoAiSetupDescription =>
      'Pauser agentens slutning, indtil du vælger en profil eller model.';

  @override
  String get taskAgentNoModelsAvailable =>
      'Ingen kompatible tænkemodeller tilgængelige';

  @override
  String get taskAgentNoProfilesAvailable =>
      'Ingen profiler tilgængelige på denne enhed';

  @override
  String get taskAgentNoProfileSelected => 'Ingen AI-opsætning';

  @override
  String get taskAgentNoProfileSelectedDescription =>
      'Vælg en gemt opsætning eller tænkemodel, før denne agent kan køre.';

  @override
  String taskAgentProfileChangedToast(String profile) {
    return 'Bruger $profile til hver fremtidig agentopdatering, indtil du ændrer det.';
  }

  @override
  String get taskAgentProfileDefaultBadge => 'Profilstandard';

  @override
  String get taskAgentReportOutdatedTitle => 'Dette resumé er forældet';

  @override
  String get taskAgentReportUpToDate => 'Resuméet er opdateret';

  @override
  String get taskAgentRouteVia => 'Gade';

  @override
  String get taskAgentRunNowTooltip => 'Løb nu';

  @override
  String get taskAgentSavingSetup => 'Opsætning af spareagent';

  @override
  String taskAgentSetupAndReportSemantics(String identity) {
    return 'Denne rapport og nuværende opsætning bruger $identity. Aktiver for at ændre opsætningen.';
  }

  @override
  String get taskAgentSetupBroken => 'Valgt AI-opsætning er ikke tilgængelig';

  @override
  String taskAgentSetupChangedToast(String model) {
    return 'Bruger $model til hver fremtidig agentopdatering, indtil du ændrer det.';
  }

  @override
  String get taskAgentSetupChoiceHelp =>
      'Vælg en profil for dens standardindstillinger, eller tilsidesæt kun tænkemodellen.';

  @override
  String get taskAgentSetupOriginCategory =>
      'Kopieret fra kategoristandarden, da denne agent blev oprettet';

  @override
  String get taskAgentSetupOriginDisabled => 'Handicappet';

  @override
  String get taskAgentSetupOriginLegacy => 'Legacy-opsætning';

  @override
  String get taskAgentSetupOriginTemplate => 'Kopieret fra skabelonen';

  @override
  String get taskAgentSetupOriginUser => 'Du valgte denne til denne agent';

  @override
  String get taskAgentSetupPersistenceDescription =>
      'Ændringer gælder for alle fremtidige opdateringer, indtil du ændrer dem.';

  @override
  String taskAgentSetupSemantics(String identity) {
    return 'Nuværende opsætning: $identity. Aktiver for at ændre opsætningen.';
  }

  @override
  String get taskAgentSetupTitle => 'Agentopsætning';

  @override
  String get taskAgentThinkingModelLabel => 'Tænkningsmodel';

  @override
  String get taskAgentThisReportHeader => 'Denne rapport';

  @override
  String get taskAgentTurnOffSetup => 'Sluk AI for denne agent';

  @override
  String get taskAgentUseCategoryDefault => 'Kopier kategori standard';

  @override
  String get taskAgentUseCategoryDefaultDescription =>
      'Kopierer kategoriens nuværende opsætning. Senere kategoriændringer vil ikke påvirke denne agent.';

  @override
  String get taskAgentUseProfileDefault => 'Brug profilstandard';

  @override
  String get taskAgentWakeAgent => 'Wake-agent';

  @override
  String get taskCategoryAllLabel => 'Alle';

  @override
  String get taskCategoryLabel => 'Kategori:';

  @override
  String get taskCategoryUnassignedLabel => 'Ikke tildelt';

  @override
  String get taskDueDateLabel => 'Forfaldsdato';

  @override
  String taskDueDateWithDate(String date) {
    return 'To: $date';
  }

  @override
  String taskDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dage',
      one: '1 dag',
    );
    return 'Afleveringsfrist om $_temp0';
  }

  @override
  String get taskDueToday => 'Indfalder i dag';

  @override
  String get taskDueTomorrow => 'Afleveres i morgen';

  @override
  String get taskDueYesterday => 'Afleveres i går';

  @override
  String get taskEditTitleLabel => 'Rediger opgavetitel';

  @override
  String get taskEstimateLabel => 'Estimat:';

  @override
  String get taskEstimateModalTitle => 'Estimat';

  @override
  String taskEstimateProgressLabel(String tracked, String estimate) {
    return '$tracked af $estimate';
  }

  @override
  String taskEstimateTooltip(String tracked, String estimate) {
    return 'Tid registreret: $tracked af $estimate estimeret';
  }

  @override
  String taskLabelsMoreCount(int count) {
    return '+$count';
  }

  @override
  String get taskLabelsShowFewer => 'Vis færre';

  @override
  String get taskLanguageArabic => 'Arabisk';

  @override
  String get taskLanguageBengali => 'Bengali';

  @override
  String get taskLanguageBulgarian => 'Bulgarsk';

  @override
  String get taskLanguageChinese => 'Kinesisk';

  @override
  String get taskLanguageCroatian => 'Kroatisk';

  @override
  String get taskLanguageCzech => 'Tjekkisk';

  @override
  String get taskLanguageDanish => 'Dansk';

  @override
  String get taskLanguageDutch => 'Hollandsk';

  @override
  String get taskLanguageEnglish => 'Engelsk';

  @override
  String get taskLanguageEstonian => 'Estisk';

  @override
  String get taskLanguageFinnish => 'Finsk';

  @override
  String get taskLanguageFrench => 'Fransk';

  @override
  String get taskLanguageGerman => 'Tysk';

  @override
  String get taskLanguageGreek => 'Græsk';

  @override
  String get taskLanguageHebrew => 'Hebraisk';

  @override
  String get taskLanguageHindi => 'Hindi';

  @override
  String get taskLanguageHungarian => 'Ungarsk';

  @override
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageIndonesian => 'Indonesisk';

  @override
  String get taskLanguageItalian => 'Italiensk';

  @override
  String get taskLanguageJapanese => 'Japansk';

  @override
  String get taskLanguageKorean => 'Koreansk';

  @override
  String get taskLanguageLabel => 'Sprog';

  @override
  String get taskLanguageLatvian => 'Lettisk';

  @override
  String get taskLanguageLithuanian => 'Litauisk';

  @override
  String get taskLanguageNigerianPidgin => 'Nigeriansk Pidgin';

  @override
  String get taskLanguageNorwegian => 'Norsk';

  @override
  String get taskLanguagePolish => 'Polsk';

  @override
  String get taskLanguagePortuguese => 'Portugisisk';

  @override
  String get taskLanguageRomanian => 'Rumænsk';

  @override
  String get taskLanguageRussian => 'Russisk';

  @override
  String get taskLanguageSelectedLabel => 'Nuværende udvalgte';

  @override
  String get taskLanguageSerbian => 'Serbisk';

  @override
  String get taskLanguageSetAction => 'Sætsprog';

  @override
  String get taskLanguageSlovak => 'Slovakisk';

  @override
  String get taskLanguageSlovenian => 'Slovensk';

  @override
  String get taskLanguageSpanish => 'Spansk';

  @override
  String get taskLanguageSwahili => 'Swahili';

  @override
  String get taskLanguageSwedish => 'Svensk';

  @override
  String get taskLanguageThai => 'Thai';

  @override
  String get taskLanguageTurkish => 'Tyrkisk';

  @override
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageUkrainian => 'Ukrainsk';

  @override
  String get taskLanguageVietnamese => 'Vietnamesisk';

  @override
  String get taskLanguageYoruba => 'Yoruba';

  @override
  String get taskNoDueDateLabel => 'Ingen terminsdato';

  @override
  String get taskNoEstimateLabel => 'Ingen oversigt';

  @override
  String taskOverdueByDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dage',
      one: '1 dag',
    );
    return 'Forfalden med $_temp0';
  }

  @override
  String get taskPriorityHigh => 'Høj';

  @override
  String get taskPriorityLow => 'Lavt';

  @override
  String get taskPriorityMedium => 'Medium';

  @override
  String get taskPriorityUrgent => 'Hastende';

  @override
  String get tasksAddLabelButton => 'Tilføj Label';

  @override
  String get tasksAgentFilterAll => 'Alle';

  @override
  String get tasksAgentFilterHasAgent => 'Har agent';

  @override
  String get tasksAgentFilterNoAgent => 'Ingen agent';

  @override
  String get tasksAgentFilterTitle => 'Agent';

  @override
  String get tasksFilterApplyTitle => 'Påfør filter';

  @override
  String get tasksFilterClearAll => 'Ryd alt';

  @override
  String get tasksFilterTitle => 'Filteropgaver';

  @override
  String get taskShowcaseAudio => 'Lyd';

  @override
  String taskShowcaseCompletedCount(int completed, int total) {
    return '$completed / $total færdig';
  }

  @override
  String taskShowcaseDueDate(String date) {
    return 'To: $date';
  }

  @override
  String get taskShowcaseJumpToSection => 'Spring til sektion';

  @override
  String get taskShowcaseLinked => 'Links';

  @override
  String get taskShowcaseNoResults => 'Ingen opgaver matcher din søgning.';

  @override
  String get taskShowcaseReadMore => 'Læs mere';

  @override
  String taskShowcaseRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count optagelser',
      one: '1 optagelse',
    );
    return '$_temp0';
  }

  @override
  String taskShowcaseTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opgaver',
      one: '1 opgave',
    );
    return '$_temp0';
  }

  @override
  String get taskShowcaseTaskDescription => 'Opgavebeskrivelse';

  @override
  String get taskShowcaseTimeTracker => 'Tidssporer';

  @override
  String get taskShowcaseTodo => 'Alle';

  @override
  String get taskShowcaseTodos => 'Alle';

  @override
  String get tasksLabelFilterAll => 'Alle';

  @override
  String get tasksLabelFilterTitle => 'Label';

  @override
  String get tasksLabelFilterUnlabeled => 'Umærket';

  @override
  String get tasksLabelsDialogClose => 'Luk';

  @override
  String get tasksLabelsSheetApply => 'Ansøg';

  @override
  String get tasksLabelsSheetSearchHint => 'Søgeetiketter...';

  @override
  String get tasksLabelsUpdateFailed => 'Undlod at opdatere etiketter';

  @override
  String get tasksPriorityFilterAll => 'Alle';

  @override
  String get tasksPriorityFilterTitle => 'Prioritet';

  @override
  String get tasksPriorityP0 => 'Hastende';

  @override
  String get tasksPriorityP0Description => 'Hastende (ASAP)';

  @override
  String get tasksPriorityP1 => 'Høj';

  @override
  String get tasksPriorityP1Description => 'High (snart)';

  @override
  String get tasksPriorityP2 => 'Medium';

  @override
  String get tasksPriorityP2Description => 'Medium (Standard)';

  @override
  String get tasksPriorityP3 => 'Lavt';

  @override
  String get tasksPriorityP3Description => 'Lav (når som helst)';

  @override
  String get tasksPriorityPickerTitle => 'Vælg prioritet';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Ikke tildelt';

  @override
  String get tasksSavedFilterDeleteConfirmTooltip => 'Tryk igen for at slette';

  @override
  String get tasksSavedFilterDeleteTooltip => 'Slet gemt filter';

  @override
  String get tasksSavedFilterDragHandleSemantics => 'Træk for at omorganisere';

  @override
  String get tasksSavedFilterRenameSemantics => 'Omdøb det gemte filter';

  @override
  String get tasksSavedFiltersAllShort => 'Alle';

  @override
  String get tasksSavedFiltersAllTasks => 'Alle opgaver';

  @override
  String get tasksSavedFiltersCustom => 'Skik';

  @override
  String get tasksSavedFiltersDeleteConfirmAction => 'Slet';

  @override
  String tasksSavedFiltersDeleteConfirmMessage(String name) {
    return 'Slette det gemte filter \'$name\'? Det kan ikke gøres om.';
  }

  @override
  String tasksSavedFiltersDeleteConfirmNamed(String name) {
    return 'Bekræft slet $name';
  }

  @override
  String tasksSavedFiltersDeleteNamed(String name) {
    return 'Slet $name';
  }

  @override
  String get tasksSavedFiltersDone => 'Færdig';

  @override
  String get tasksSavedFiltersEdit => 'Redigering';

  @override
  String get tasksSavedFiltersFilterNameLabel => 'Filternavn';

  @override
  String get tasksSavedFiltersGroupSemantics => 'Opgavefiltre';

  @override
  String get tasksSavedFiltersManageTooltip => 'Administrer opgavefiltre';

  @override
  String get tasksSavedFiltersRailButton => 'Filtre';

  @override
  String tasksSavedFiltersRenameNamed(String name) {
    return 'Omdøb $name';
  }

  @override
  String get tasksSavedFiltersReorderHelper =>
      'Træk for at sætte rækkefølgen. De første fem filtre vises i sidebaren.';

  @override
  String get tasksSavedFiltersSaveAsNewButtonLabel => 'Gem som ny...';

  @override
  String get tasksSavedFiltersSaveAsNewDescription =>
      'Behold det eksisterende filter uændret og lav et separat.';

  @override
  String get tasksSavedFiltersSaveAsNewTitle => 'Gem som et nyt filter';

  @override
  String get tasksSavedFiltersSaveButtonLabel => 'Gem filter...';

  @override
  String get tasksSavedFiltersSaveChoiceIntro =>
      'Vælg om du vil opdatere det gemte filter eller oprette et separat.';

  @override
  String get tasksSavedFiltersSaveChoiceTitle => 'Gem filter';

  @override
  String get tasksSavedFiltersSaveCurrentAs => 'Gem strømfilteret...';

  @override
  String get tasksSavedFiltersSaveError =>
      'Kunne ikke gemme dette filter. Prøv igen.';

  @override
  String get tasksSavedFiltersSavePageHelper =>
      'Giv dette filter et kort navn. Du kan omarrangere det senere i Task-filtrene.';

  @override
  String get tasksSavedFiltersSavePopupCancel => 'Annuller';

  @override
  String get tasksSavedFiltersSavePopupHint =>
      'f.eks. blokeret eller på ventehold';

  @override
  String get tasksSavedFiltersSavePopupSave => 'Gem';

  @override
  String get tasksSavedFiltersSavePopupTitle => 'Navngiv dette filter';

  @override
  String get tasksSavedFiltersSheetTitle => 'Opgavefiltre';

  @override
  String get tasksSavedFiltersShowLess => 'Vis færre';

  @override
  String tasksSavedFiltersShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flere gemte filtre',
      one: '1 flere gemte filtre',
    );
    return '$_temp0';
  }

  @override
  String tasksSavedFiltersTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opgaver',
      one: '1 opgave',
    );
    return '$_temp0';
  }

  @override
  String get tasksSavedFiltersUpdateButtonLabel => 'Opdateringsfilter';

  @override
  String get tasksSavedFiltersUpdateExistingDescription =>
      'Erstat de gemte kriterier med den nuværende filterkonfiguration.';

  @override
  String get tasksSavedFiltersUpdateExistingTitle =>
      'Opdater eksisterende filter';

  @override
  String get tasksSavedFilterToastDeleted => 'Filter slettet';

  @override
  String tasksSavedFilterToastSaved(String name) {
    return 'Gemt \'$name\'';
  }

  @override
  String tasksSavedFilterToastUpdated(String name) {
    return 'Opdateret \'$name\'';
  }

  @override
  String get tasksSearchModeLabel => 'Søgefunktion';

  @override
  String get tasksShowCreationDate => 'Vis oprettelsesdato på kortene';

  @override
  String get tasksShowDueDate => 'Vis afleveringsdato på kortene';

  @override
  String get tasksSortByCreationDate => 'Oprettet';

  @override
  String get tasksSortByDueDate => 'Forfaldsdato';

  @override
  String get tasksSortByLabel => 'Sorter efter';

  @override
  String get tasksSortByPriority => 'Prioritet';

  @override
  String get taskStatusAll => 'Alle';

  @override
  String get taskStatusBlocked => 'Blokeret';

  @override
  String get taskStatusDone => 'Færdig';

  @override
  String get taskStatusGroomed => 'Plejet';

  @override
  String get taskStatusInProgress => 'Under udvikling';

  @override
  String get taskStatusLabel => 'Status:';

  @override
  String get taskStatusOnHold => 'På pause';

  @override
  String get taskStatusOpen => 'Åben';

  @override
  String get taskStatusRejected => 'Afvist';

  @override
  String get taskTitleEmpty => 'Ingen titel';

  @override
  String get taskUntitled => '(uden titel)';

  @override
  String get thinkingDisclosureCopied => 'Begrundelse kopieret';

  @override
  String get thinkingDisclosureCopy => 'Kopiræsonnement';

  @override
  String get thinkingDisclosureHide => 'Skjul ræsonnement';

  @override
  String get thinkingDisclosureShow => 'Show-ræsonnement';

  @override
  String get thinkingDisclosureStateCollapsed => 'kollapsede';

  @override
  String get thinkingDisclosureStateExpanded => 'Udvidet';

  @override
  String get timeEntryItemEnd => 'Slut';

  @override
  String get timeEntryItemRunning => 'Løb';

  @override
  String get timeEntryItemStart => 'Start';

  @override
  String transcriptLanguageLabel(String language) {
    return 'Language: $language';
  }

  @override
  String transcriptModelLabel(String provider, String model) {
    return 'Model: $provider, $model';
  }

  @override
  String get unlinkButton => 'Afbryd forbindelsen';

  @override
  String get unlinkTaskConfirm =>
      'Er du sikker på, at du vil koble denne opgave fra?';

  @override
  String get unlinkTaskTitle => 'Afkoblingsopgave';

  @override
  String vectorSearchTiming(int elapsed, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${elapsed}ms, $count results',
      one: '${elapsed}ms, $count result',
    );
    return '$_temp0';
  }

  @override
  String get viewMenuTitle => 'Udsigt';

  @override
  String get viewMenuZoomIn => 'Zoom ind';

  @override
  String get viewMenuZoomOut => 'Zoom ud';

  @override
  String get viewMenuZoomReset => 'Faktisk størrelse';

  @override
  String get whatsNewBadgeNew => 'NYT';

  @override
  String get whatsNewDoneButton => 'Færdig';

  @override
  String get whatsNewSkipButton => 'Spring over';
}

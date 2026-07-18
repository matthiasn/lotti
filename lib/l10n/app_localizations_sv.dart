// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get activeLabel => 'Aktiv';

  @override
  String get addActionAddAudioRecording => 'Ljudinspelning';

  @override
  String get addActionAddChecklist => 'Checklista';

  @override
  String get addActionAddEvent => 'Evenemang';

  @override
  String get addActionAddImageFromClipboard => 'Klistra in bild';

  @override
  String get addActionAddScreenshot => 'Skärmdump';

  @override
  String get addActionAddTask => 'Uppgift';

  @override
  String get addActionAddText => 'Textinmatning';

  @override
  String get addActionAddTimer => 'Lägg till timer';

  @override
  String get addActionAddTimeRecording => 'Lägg till tidsregistrering';

  @override
  String get addActionImportImage => 'Importera bild';

  @override
  String get addHabitCommentLabel => 'Kommentar';

  @override
  String get addHabitDateLabel => 'Färdigställd i';

  @override
  String get addMeasurementCommentLabel => 'Kommentar';

  @override
  String get addMeasurementDateLabel => 'Observerad vid';

  @override
  String get addMeasurementSaveButton => 'Spara';

  @override
  String get addToDictionary => 'Lägg till i ordbok';

  @override
  String get addToDictionaryDuplicate => 'Termen finns redan i ordboken';

  @override
  String get addToDictionaryNoCategory =>
      'Kan inte lägga till i ordbok: uppgiften har ingen kategori';

  @override
  String get addToDictionarySaveFailed => 'Misslyckades med att rädda ordboken';

  @override
  String get addToDictionarySuccess => 'Term tillagd i ordboken';

  @override
  String get addToDictionaryTooLong =>
      'Mandatperioden är för lång (max 50 tecken)';

  @override
  String agentABComparisonChoose(String option) {
    return 'Välj $option';
  }

  @override
  String agentABComparisonOption(String option) {
    return 'Alternativ $option';
  }

  @override
  String agentABComparisonPrefer(String option) {
    return 'Jag föredrar Alternativ $option';
  }

  @override
  String get agentBinaryChoiceNo => 'Nej';

  @override
  String get agentBinaryChoiceYes => 'Ja';

  @override
  String get agentCategoryRatingsScaleMax => 'Fixa först';

  @override
  String get agentCategoryRatingsScaleMin => 'Låt det vara';

  @override
  String agentCategoryRatingsStarLabel(int starIndex, int totalStars) {
    return '$starIndex av $totalStars-stjärnor';
  }

  @override
  String get agentCategoryRatingsSubmit => 'Använd dessa prioriteringar';

  @override
  String get agentCategoryRatingsSubtitle =>
      'Hur viktigt är det att jag fixar var och en av dessa? 1 betyder låt det vara, 5 betyder fixa det först.';

  @override
  String get agentCategoryRatingsTitle => 'Hjälp mig att prioritera';

  @override
  String agentControlsActionError(String error) {
    return 'Åtgärden misslyckades: $error';
  }

  @override
  String get agentControlsDeleteButton => 'Radera permanent';

  @override
  String get agentControlsDeleteDialogContent =>
      'Detta kommer permanent att radera all data för denna agent, inklusive dess historik, rapporter och observationer. Detta kan inte göras ogjort.';

  @override
  String get agentControlsDeleteDialogTitle => 'Ta bort agenten?';

  @override
  String get agentControlsDestroyButton => 'Förstör';

  @override
  String get agentControlsDestroyDialogContent =>
      'Detta kommer att permanent inaktivera agenten. Dess historia kommer att bevaras för revision.';

  @override
  String get agentControlsDestroyDialogTitle => 'Förstöra agenten?';

  @override
  String get agentControlsDestroyedMessage => 'Denna agent har förstörts.';

  @override
  String get agentControlsPauseButton => 'Paus';

  @override
  String get agentControlsReanalyzeButton => 'Omanalysera';

  @override
  String get agentControlsResumeButton => 'Fortsätt';

  @override
  String get agentConversationEmpty => 'Inga samtal än.';

  @override
  String agentConversationThreadSummary(
    int messageCount,
    int toolCallCount,
    String shortId,
  ) {
    return '$messageCount meddelanden, $toolCallCount verktygsanrop · $shortId';
  }

  @override
  String agentConversationTokenCount(String tokenCount) {
    return '$tokenCount tokens';
  }

  @override
  String get agentDefaultProfileLabel => 'Standardinferensprofil';

  @override
  String agentDetailErrorLoading(String error) {
    return 'Felladdningsagent: $error';
  }

  @override
  String get agentDetailNotFound => 'Agent ej hittad.';

  @override
  String get agentDetailUnexpectedType => 'Oväntad entitetstyp.';

  @override
  String get agentEvolutionApprovalRate => 'Godkännandegrad';

  @override
  String get agentEvolutionChartMttrTrend => 'MTTR-trend';

  @override
  String get agentEvolutionChartSuccessRateTrend => 'Framgångstrend';

  @override
  String get agentEvolutionChartVersionPerformance => 'Per version';

  @override
  String get agentEvolutionChartWakeHistory => 'Vake-historia';

  @override
  String get agentEvolutionChatPlaceholder =>
      'Dela feedback eller fråga om prestation...';

  @override
  String get agentEvolutionCurrentDirectives => 'Nuvarande direktiv';

  @override
  String get agentEvolutionDashboardTitle => 'Prestanda';

  @override
  String get agentEvolutionHistoryTitle => 'Evolutionshistoria';

  @override
  String get agentEvolutionMetricActive => 'Aktiv';

  @override
  String get agentEvolutionMetricAvgDuration => 'Genomsnittlig varaktighet';

  @override
  String get agentEvolutionMetricFailures => 'Misslyckanden';

  @override
  String get agentEvolutionMetricSuccess => 'Framgång';

  @override
  String get agentEvolutionMetricWakes => 'Vakor';

  @override
  String get agentEvolutionNoSessions => 'Inga evolutionssessioner än';

  @override
  String get agentEvolutionNoteRecorded => 'Notering Inspelad';

  @override
  String get agentEvolutionProposalApprovalFailed =>
      'Godkännandet misslyckades — försök igen';

  @override
  String get agentEvolutionProposalRationale => 'Motivering';

  @override
  String get agentEvolutionProposalRejected =>
      'Förslaget avvisas — fortsätt samtalet';

  @override
  String get agentEvolutionProposalTitle => 'Föreslagna förändringar';

  @override
  String get agentEvolutionProposedDirectives => 'Föreslagna direktiv';

  @override
  String get agentEvolutionSessionAbandoned =>
      'Sessionen avslutades utan ändringar';

  @override
  String agentEvolutionSessionCompleted(int version) {
    return 'Session slutförd — version $version skapad';
  }

  @override
  String get agentEvolutionSessionCount => 'Sessioner';

  @override
  String get agentEvolutionSessionError =>
      'Misslyckades med att starta evolutionssessionen';

  @override
  String agentEvolutionSessionProgress(int sessionNumber, int totalSessions) {
    return 'Session $sessionNumber av $totalSessions';
  }

  @override
  String get agentEvolutionSessionStarting => 'Startar evolutionssessionen...';

  @override
  String agentEvolutionSessionTitle(int sessionNumber) {
    return 'Evolution #$sessionNumber';
  }

  @override
  String agentEvolutionSoulCurrentField(String field) {
    return 'Nuvarande — $field';
  }

  @override
  String agentEvolutionSoulProposedField(String field) {
    return 'Föreslagen — $field';
  }

  @override
  String get agentEvolutionStatusAbandoned => 'Övergiven';

  @override
  String get agentEvolutionStatusActive => 'Aktiv';

  @override
  String get agentEvolutionStatusCompleted => 'Färdigställd';

  @override
  String get agentEvolutionTimelineFeedbackLabel => 'Feedback';

  @override
  String get agentEvolutionVersionProposed => 'Föreslagen version';

  @override
  String get agentFeedbackCategoryAccuracy => 'Noggrannhet';

  @override
  String get agentFeedbackCategoryBreakdownTitle => 'Kategoriuppdelning';

  @override
  String get agentFeedbackCategoryCommunication => 'Kommunikation';

  @override
  String get agentFeedbackCategoryGeneral => 'Allmänt';

  @override
  String get agentFeedbackCategoryPrioritization => 'Prioritering';

  @override
  String get agentFeedbackCategoryTimeliness => 'Aktualitet';

  @override
  String get agentFeedbackCategoryTooling => 'Verktyg';

  @override
  String get agentFeedbackClassificationTitle => 'Feedbackklassificering';

  @override
  String get agentFeedbackExcellenceTitle => 'Noter om excellens';

  @override
  String get agentFeedbackGrievancesTitle => 'Klagomål';

  @override
  String get agentFeedbackHighPriorityTitle => 'Högprioriterad återkoppling';

  @override
  String agentFeedbackItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count föremål',
      one: '1 föremål',
    );
    return '$_temp0';
  }

  @override
  String get agentFeedbackSourceDecision => 'Beslut';

  @override
  String get agentFeedbackSourceMetric => 'Metrik';

  @override
  String get agentFeedbackSourceObservation => 'Observation';

  @override
  String get agentFeedbackSourceRating => 'Betyg';

  @override
  String get agentInstancesEmptyFiltered => 'Inga exempel matchar dina filter.';

  @override
  String get agentInstancesFilterClearAll => 'Rensa allt';

  @override
  String get agentInstancesFilterClearSection => 'Klart';

  @override
  String get agentInstancesFilterSectionSoul => 'Själ';

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
  String get agentInstancesGroupBySoul => 'Själ';

  @override
  String get agentInstancesGroupByStatus => 'Status';

  @override
  String get agentInstancesGroupByType => 'Typ';

  @override
  String get agentInstancesKindEvolution => 'Utveckling';

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
    return '$filtered av $total';
  }

  @override
  String get agentInstancesSearchClear => 'Rensa sökning';

  @override
  String get agentInstancesSearchPlaceholder => 'Sökinstanser...';

  @override
  String get agentInstancesSortName => 'Namn';

  @override
  String get agentInstancesSortOldest => 'Äldsta';

  @override
  String get agentInstancesSortRecent => 'Nyligen';

  @override
  String get agentInstancesTitle => 'Instanser';

  @override
  String get agentInstancesToolbarFilters => 'Filter';

  @override
  String get agentInstancesToolbarGroupBy => 'Grupp efter';

  @override
  String get agentInstancesUnassignedSoul => 'Otilldelat';

  @override
  String get agentLifecycleActive => 'Aktiv';

  @override
  String get agentLifecycleCreated => 'Skapad';

  @override
  String get agentLifecycleDestroyed => 'Förstörd';

  @override
  String get agentLifecycleDormant => 'Vilande';

  @override
  String get agentMessageKindAction => 'Strid';

  @override
  String get agentMessageKindMilestone => 'Milstolpe';

  @override
  String get agentMessageKindObservation => 'Observation';

  @override
  String get agentMessageKindRetraction => 'Tillbakadragning';

  @override
  String get agentMessageKindSummary => 'Sammanfattning';

  @override
  String get agentMessageKindSystem => 'System';

  @override
  String get agentMessageKindSystemPrompt => 'Systemprompt';

  @override
  String get agentMessageKindThought => 'Tankar';

  @override
  String get agentMessageKindToolResult => 'Verktygsresultat';

  @override
  String get agentMessageKindUser => 'Användare';

  @override
  String get agentMessagePayloadEmpty => '(inget innehåll)';

  @override
  String get agentMessagesEmpty => 'Inga meddelanden än.';

  @override
  String agentMessagesErrorLoading(String error) {
    return 'Meddelanden kunde inte laddas: $error';
  }

  @override
  String get agentObservationsEmpty =>
      'Inga observationer har ännu registrerats.';

  @override
  String agentPendingWakesActivityHourDetail(
    String hour,
    int count,
    String reasons,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vakningar',
      one: '1 vakna',
    );
    return '$hour: $_temp0 ($reasons)';
  }

  @override
  String get agentPendingWakesActivityTitle => 'Vakaktivitet (24 timmar)';

  @override
  String agentPendingWakesActivityTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count totala vakningar',
      one: '1 total vakna',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesDeleteTooltip => 'Ta bort en våg';

  @override
  String get agentPendingWakesEmptyFiltered =>
      'Inga vaken matchar dina filter.';

  @override
  String get agentPendingWakesFilterSectionType => 'Typ';

  @override
  String get agentPendingWakesGroupByType => 'Typ';

  @override
  String get agentPendingWakesPendingLabel => 'Väntar';

  @override
  String agentPendingWakesRunningHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kör nu ($count)',
      one: 'Kör nu',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesScheduledLabel => 'Planerade';

  @override
  String get agentPendingWakesSearchPlaceholder => 'Sök vaknar...';

  @override
  String get agentPendingWakesSortDueLatest => 'Senaste tiden';

  @override
  String get agentPendingWakesSortDueSoonest => 'Snart beräknad';

  @override
  String get agentPendingWakesTitle => 'Vakningscykler';

  @override
  String get agentReportHistoryBadge => 'Rapport';

  @override
  String get agentReportHistoryEmpty => 'Inga rapportbilder än.';

  @override
  String get agentReportHistoryError =>
      'Ett fel uppstod när rapporthistoriken laddades.';

  @override
  String get agentReportNone => 'Ingen rapport finns tillgänglig än.';

  @override
  String get agentRitualReviewAction => 'Starta samtal';

  @override
  String get agentRitualReviewNegativeSignals => 'Negativt';

  @override
  String get agentRitualReviewNeutralSignals => 'Neutral';

  @override
  String get agentRitualReviewNoFeedback =>
      'Inga återkopplingssignaler i detta fönster';

  @override
  String get agentRitualReviewNoNegativeSignals =>
      'Inga negativa återkopplingssignaler i denna flik';

  @override
  String get agentRitualReviewNoNeutralSignals =>
      'Inga neutrala återkopplingssignaler i denna flik';

  @override
  String get agentRitualReviewNoPositiveSignals =>
      'Inga positiva återkopplingssignaler i denna flik';

  @override
  String get agentRitualReviewPositiveSignals => 'Positivt';

  @override
  String get agentRitualReviewProposalSection => 'Nuvarande förslag';

  @override
  String get agentRitualReviewSessionHistory => 'Sessionens historik';

  @override
  String get agentRitualReviewTitle => '1-mot-1';

  @override
  String get agentRitualSummaryApprovedChangesHeading =>
      'Godkända förändringar';

  @override
  String get agentRitualSummaryConversationHeading => 'Samtal';

  @override
  String get agentRitualSummaryRecapHeading => 'Sessionssammanfattning';

  @override
  String get agentRitualSummaryRoleAssistant => 'Agent';

  @override
  String get agentRitualSummaryRoleUser => 'Du';

  @override
  String get agentRitualSummaryStartHint =>
      'Starta ett enskilt möte för att gå igenom vad som störde dig, vad som fungerade och vad som bör ändras härnäst.';

  @override
  String get agentRitualSummarySubtitle =>
      'Nyliga enskilda möten, riktig vakaktivitet och de förändringar ni gått med på.';

  @override
  String get agentRitualSummaryTokensSinceLast => 'Tokens sedan förra 1-mot-1';

  @override
  String get agentRitualSummaryWakeHistory30Days =>
      'Vaken aktivitet (senaste 30 dagarna)';

  @override
  String get agentRitualSummaryWakesSinceLast =>
      'Vakor sedan senaste en-mot-en-mötet';

  @override
  String get agentRunningIndicator => 'Löpning';

  @override
  String get agentSessionProgressTitle => 'Sessionens framsteg';

  @override
  String get agentSettingsSubtitle => 'Mallar, instanser och övervakning';

  @override
  String get agentSettingsTitle => 'Agenter';

  @override
  String get agentSoulAntiSycophancyLabel => 'Anti-smygningspolitik';

  @override
  String get agentSoulAssignedTemplatesTitle => 'Tilldelade mallar';

  @override
  String get agentSoulAssignmentLabel => 'Själ';

  @override
  String get agentSoulCoachingStyleLabel => 'Coachingstil';

  @override
  String get agentSoulCreatedSuccess => 'Själ skapad';

  @override
  String get agentSoulCreateTitle => 'Skapa själ';

  @override
  String get agentSoulDeleteConfirmBody =>
      'Detta kommer att ta bort själen och alla dess versioner.';

  @override
  String get agentSoulDeleteConfirmTitle => 'Radera själen';

  @override
  String get agentSoulDetailTitle => 'Själsdetalj';

  @override
  String get agentSoulDisplayNameLabel => 'Namn';

  @override
  String get agentSoulEvolutionHistoryTitle => 'Själsutvecklingens historia';

  @override
  String get agentSoulEvolutionNoSessions =>
      'Inga själsutvecklingssessioner än';

  @override
  String get agentSoulFieldAntiSycophancy => 'Anti-smicker';

  @override
  String get agentSoulFieldCoachingStyle => 'Coachingstil';

  @override
  String get agentSoulFieldToneBounds => 'Tongränser';

  @override
  String get agentSoulFieldVoice => 'Röst';

  @override
  String get agentSoulInfoTab => 'Info';

  @override
  String get agentSoulNoneAssigned => 'Ingen själ tilldelad';

  @override
  String get agentSoulNotFound => 'Själ ej hittad';

  @override
  String get agentSoulProposalSubtitle =>
      'Föreslagna personlighetsförändringar';

  @override
  String get agentSoulProposalTitle => 'Själspersonlighetsförslag';

  @override
  String get agentSoulReviewHeroSubtitle =>
      'Förfina personligheten över alla mallar som delar denna själ. Evolutionsagenten ser feedback från varje mall som använder denna personlighet.';

  @override
  String get agentSoulReviewStartAction => 'Starta Personlighetsgranskning';

  @override
  String get agentSoulReviewStartHint =>
      'Starta en personlighetsfokuserad session för att granska feedback och utveckla röst, ton, coachningsstil och direkthet.';

  @override
  String agentSoulReviewTemplateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mallar som delar denna själ',
      one: '1 mall som delar denna själ',
    );
    return '$_temp0';
  }

  @override
  String get agentSoulReviewTitle => 'Soul 1-mot-1';

  @override
  String get agentSoulRollbackAction => 'Rulla tillbaka till denna version';

  @override
  String agentSoulRollbackConfirm(int version) {
    return 'Rulla tillbaka till version $version? Alla mallar som använder denna själ kommer att plocka upp förändringen.';
  }

  @override
  String get agentSoulSelectTitle => 'Välj själ';

  @override
  String get agentSoulsEmptyFiltered => 'Inga själar matchar dina filter.';

  @override
  String get agentSoulSettingsTab => 'Miljöer';

  @override
  String get agentSoulsSearchPlaceholder => 'Sök själar...';

  @override
  String get agentSoulsTitle => 'Själar';

  @override
  String get agentSoulToneBoundsLabel => 'Tongränser';

  @override
  String get agentSoulVersionHistoryTitle => 'Versionshistorik';

  @override
  String agentSoulVersionLabel(int version) {
    return 'Version $version';
  }

  @override
  String get agentSoulVersionSaved => 'Ny själversion räddad';

  @override
  String get agentSoulVoiceDirectiveLabel => 'Röstdirektivet';

  @override
  String get agentStateConsecutiveFailures =>
      'På varandra följande misslyckanden';

  @override
  String agentStateErrorLoading(String error) {
    return 'Misslyckades med att ladda tillstånd: $error';
  }

  @override
  String get agentStateHeading => 'Delstatsinformation';

  @override
  String get agentStateLastWake => 'Sista vaket';

  @override
  String get agentStateNextWake => 'Nästa vaka';

  @override
  String get agentStateRevision => 'Revision';

  @override
  String get agentStateSleepingUntil => 'Sov tills';

  @override
  String get agentStateWakeCount => 'Vakenräkning';

  @override
  String get agentStatsAllDayLegend => 'Hela dagen';

  @override
  String get agentStatsAverageLabel => 'Genomsnitt';

  @override
  String agentStatsByTimeLegend(String time) {
    return 'Dagligen av $time';
  }

  @override
  String get agentStatsCacheRateLabel => 'Cache-hastighet';

  @override
  String get agentStatsDailyUsageHeading => 'Daglig användning';

  @override
  String get agentStatsInputLabel => 'Indata';

  @override
  String get agentStatsNoUsage =>
      'Ingen tokenanvändning registrerades de senaste 7 dagarna.';

  @override
  String get agentStatsOutputLabel => 'Produktion';

  @override
  String agentStatsSourceActiveFor(String duration) {
    return 'Aktiv för $duration';
  }

  @override
  String get agentStatsSourceActivityHeading => 'Agentaktivitet';

  @override
  String agentStatsSourceWakes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vakningar',
      one: '1 vakna',
    );
    return '$_temp0';
  }

  @override
  String get agentStatsTabTitle => 'Statistik';

  @override
  String get agentStatsThoughtsLabel => 'Tankar';

  @override
  String get agentStatsTodayLabel => 'Idag';

  @override
  String get agentStatsTokensPerWakeLabel => 'Tokens / väckning';

  @override
  String get agentStatsTokensUnit => 'Tokens';

  @override
  String agentStatsUsageAboveAverage(String time) {
    return 'Du använder fler tokens idag än du brukar göra med $time.';
  }

  @override
  String agentStatsUsageBelowAverage(String time) {
    return 'Du använder färre tokens idag än du brukar göra vid $time.';
  }

  @override
  String get agentStatsWakesLabel => 'Väckningar';

  @override
  String get agentSuggestionTimeEntryUpdateCurrent => 'Nutid';

  @override
  String get agentSuggestionTimeEntryUpdateNoChange => '(oförändrat)';

  @override
  String get agentSuggestionTimeEntryUpdateProposed => 'Föreslaget';

  @override
  String get agentSuggestionTimeEntryUpdateUnavailable =>
      'Originalbidrag ej tillgängligt';

  @override
  String get agentTabActivity => 'Verksamhet';

  @override
  String get agentTabConversations => 'Samtal';

  @override
  String get agentTabObservations => 'Observationer';

  @override
  String get agentTabReports => 'Rapporter';

  @override
  String get agentTabStats => 'Statistik';

  @override
  String get agentTemplateAggregateTokenUsageHeading =>
      'Användning av aggregerad token';

  @override
  String get agentTemplateAssignedLabel => 'Mall';

  @override
  String get agentTemplateCreatedSuccess => 'Mall skapad';

  @override
  String get agentTemplateCreateTitle => 'Skapa mall';

  @override
  String get agentTemplateDeleteConfirm =>
      'Radera den här mallen? Detta kan inte göras ogjort.';

  @override
  String get agentTemplateDeleteHasInstances =>
      'Kan inte ta bort: aktiva agenter använder denna mall.';

  @override
  String get agentTemplateDisplayNameLabel => 'Namn';

  @override
  String get agentTemplateEditTitle => 'Redigera mall';

  @override
  String get agentTemplateEvolveApprove => 'Godkänn och spara';

  @override
  String get agentTemplateEvolveReject => 'Avvisa';

  @override
  String get agentTemplateGeneralDirectiveHint =>
      'Definiera agentens personlighet, verktyg, mål och interaktionsstil...';

  @override
  String get agentTemplateGeneralDirectiveLabel => 'Allmänna direktivet';

  @override
  String get agentTemplateInstanceBreakdownHeading => 'Uppdelning per instans';

  @override
  String get agentTemplateKindDayAgent => 'Dagagent';

  @override
  String get agentTemplateKindEventAgent => 'Händelseagent';

  @override
  String get agentTemplateKindImprover => 'Mallförbättrare';

  @override
  String get agentTemplateKindProjectAgent => 'Projektagent';

  @override
  String get agentTemplateKindTaskAgent => 'Task Agent';

  @override
  String get agentTemplateMetricsTotalWakes => 'Totala vågor';

  @override
  String get agentTemplateNoneAssigned => 'Ingen mall tilldelad';

  @override
  String get agentTemplateNoTemplates =>
      'Inga mallar tillgängliga. Skapa en i Inställningar först.';

  @override
  String get agentTemplateNotFound => 'Mall ej hittad';

  @override
  String get agentTemplateNoVersions => 'Inga versioner';

  @override
  String get agentTemplateReportDirectiveHint =>
      'Definiera rapportstrukturen, nödvändiga avsnitt och formateringsregler...';

  @override
  String get agentTemplateReportDirectiveLabel => 'Rapportdirektivet';

  @override
  String get agentTemplateReportsEmpty => 'Inga rapporter än.';

  @override
  String get agentTemplateReportsTab => 'Rapporter';

  @override
  String get agentTemplateRollbackAction => 'Rulla tillbaka till denna version';

  @override
  String agentTemplateRollbackConfirm(int version) {
    return 'Rulla tillbaka till version $version? Agenten kommer att använda denna version vid nästa vaka.';
  }

  @override
  String get agentTemplateSaveNewVersion => 'Spara';

  @override
  String get agentTemplateSelectTitle => 'Välj mall';

  @override
  String get agentTemplatesEmptyFiltered => 'Inga mallar matchar dina filter.';

  @override
  String get agentTemplateSettingsTab => 'Miljöer';

  @override
  String get agentTemplatesFilterSectionKind => 'Typ';

  @override
  String get agentTemplatesGroupByKind => 'Typ';

  @override
  String get agentTemplatesGroupNone => 'Alla';

  @override
  String get agentTemplatesSearchPlaceholder => 'Sök mallar...';

  @override
  String get agentTemplateStatsTab => 'Statistik';

  @override
  String get agentTemplateStatusActive => 'Aktiv';

  @override
  String get agentTemplateStatusArchived => 'Arkiverad';

  @override
  String get agentTemplatesTitle => 'Agentmallar';

  @override
  String get agentTemplateSwitchHint =>
      'För att använda en annan mall, förstör denna agent och skapa en ny.';

  @override
  String get agentTemplateVersionHistoryTitle => 'Versionshistorik';

  @override
  String agentTemplateVersionLabel(int version) {
    return 'Version $version';
  }

  @override
  String get agentTemplateVersionSaved => 'Ny version sparad';

  @override
  String get agentThreadReportLabel => 'Rapport producerad under denna vaka';

  @override
  String get agentTokenUsageCachedTokens => 'Cachad';

  @override
  String get agentTokenUsageEmpty => 'Ingen tokenanvändning registrerad än.';

  @override
  String agentTokenUsageErrorLoading(String error) {
    return 'Misslyckades med att ladda tokenanvändning: $error';
  }

  @override
  String get agentTokenUsageHeading => 'Tokenanvändning';

  @override
  String get agentTokenUsageInputTokens => 'Indata';

  @override
  String get agentTokenUsageModel => 'Modell';

  @override
  String get agentTokenUsageOutputTokens => 'Produktion';

  @override
  String get agentTokenUsageThoughtsTokens => 'Tankar';

  @override
  String get agentTokenUsageTotalTokens => 'Totalt';

  @override
  String get agentTokenUsageWakeCount => 'Vakor';

  @override
  String get aggregationDailyAvg => 'Dagligt genomsnitt';

  @override
  String get aggregationDailyMax => 'Daglig maxgräns';

  @override
  String get aggregationDailySum => 'Daglig summa';

  @override
  String get aggregationHourlySum => 'Timsumma';

  @override
  String get aggregationNone => 'Råa värden';

  @override
  String get aiAssistantTitle => 'Generera...';

  @override
  String get aiBatchToggleTooltip => 'Övergång till standardinspelning';

  @override
  String get aiCapabilityChipImageGeneration => 'Bildgenerering';

  @override
  String get aiCapabilityChipImageRecognition => 'Bildigenkänning';

  @override
  String get aiCapabilityChipThinking => 'Tänkande';

  @override
  String get aiCapabilityChipTranscription => 'Transkription';

  @override
  String aiCardHistoryToggle(int count) {
    return 'Historia · $count';
  }

  @override
  String get aiCardMenuActionDelete => 'Radera';

  @override
  String get aiCardMenuActionEdit => 'Redigering';

  @override
  String get aiCardMenuTooltip => 'Fler åtgärder';

  @override
  String get aiCardOpenAgentInternals => 'Öppna agent-interna funktioner';

  @override
  String get aiCardProposalConfirmed => 'Bekräftat';

  @override
  String get aiCardProposalDismissed => 'Avskedad';

  @override
  String get aiCardProposalKindAdd => 'Lägg till';

  @override
  String get aiCardProposalKindDue => 'Två';

  @override
  String get aiCardProposalKindEstimate => 'Uppskattning';

  @override
  String get aiCardProposalKindLabel => 'Etikett';

  @override
  String get aiCardProposalKindPriority => 'Prioritet';

  @override
  String get aiCardProposalKindRemove => 'Ta bort';

  @override
  String get aiCardProposalKindStatus => 'Status';

  @override
  String get aiCardProposalKindUpdate => 'Uppdatering';

  @override
  String get aiCardReadMore => 'Läs mer';

  @override
  String get aiCardShowLess => 'Visa mindre';

  @override
  String get aiCardTitle => 'AI-sammanfattning';

  @override
  String get aiChatAssistantResponding => 'Assistenten svarar';

  @override
  String get aiChatMessageCopied => 'Kopierat till skrivplatta';

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Misslyckades med att ladda modellerna. Försök igen, tack.';

  @override
  String get aiConfigNoModelsAvailable =>
      'Inga AI-modeller är konfigurerade än. Vänligen lägg till en i inställningarna.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Inga modeller uppfyller kraven för denna prompt. Vänligen konfigurera modeller som stödjer de nödvändiga funktionerna.';

  @override
  String get aiConfigSelectProviderModalTitle => 'Välj inferensleverantör';

  @override
  String get aiConfigSelectProviderTypeModalTitle => 'Välj leverantörstyp';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Använd resonemang';

  @override
  String aiConsumptionCallsLine(int count, int measured) {
    return 'AI-anrop: $count · Påverkan mätt för $measured';
  }

  @override
  String aiConsumptionCostLine(String cost) {
    return 'Kostnad: $cost';
  }

  @override
  String aiConsumptionImpactLine(String energy, String carbon, String water) {
    return 'Påverkan: $energy · $carbon CO₂e · $water vatten';
  }

  @override
  String aiConsumptionLedgerCap(int limit) {
    return 'Visar de senaste $limit-anropen under denna period';
  }

  @override
  String get aiConsumptionLedgerTitle => 'Senaste samtal';

  @override
  String get aiConsumptionMetricsNotReported => 'Ej rapporterad';

  @override
  String aiConsumptionTokensLabel(String tokens) {
    return '$tokens tokens';
  }

  @override
  String aiConsumptionTokensLine(String input, String output) {
    return 'Tokens: $input i · $output ut';
  }

  @override
  String get aiConsumptionTypeAgentTurn => 'Agentens omgång';

  @override
  String get aiConsumptionTypeAudioTranscription => 'Transkription';

  @override
  String get aiConsumptionTypeImageAnalysis => 'Bildanalys';

  @override
  String get aiConsumptionTypeImageGeneration => 'Bildgenerering';

  @override
  String get aiConsumptionTypePromptGeneration => 'Promptgenerering';

  @override
  String get aiConsumptionTypeTextGeneration => 'Textgenerering';

  @override
  String aiDeleteToastCascadeDescription(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' Tog även bort $count modeller: $names',
      one: 'Tog också bort 1 modell: $names',
    );
    return '$_temp0';
  }

  @override
  String aiDeleteToastErrorTitle(String name) {
    return 'Kunde inte radera $name';
  }

  @override
  String get aiDeleteToastModelTitle => 'Modell borttagen';

  @override
  String get aiDeleteToastProfileTitle => 'Profil borttagen';

  @override
  String get aiDeleteToastPromptTitle => 'Prompt borttagen';

  @override
  String get aiDeleteToastProviderTitle => 'Leverantör borttagen';

  @override
  String get aiDeleteToastSkillTitle => 'Färdighet borttagen';

  @override
  String get aiDeleteToastUndoAction => 'Ångra';

  @override
  String get aiFormCancel => 'Avbryt';

  @override
  String get aiFormFixErrors => 'Vänligen rätta fel innan du sparar';

  @override
  String get aiFormNoChanges => 'Inga osparade ändringar';

  @override
  String get aiImageAnalysisPickerDefaultBadge => 'Standard';

  @override
  String get aiImageAnalysisPickerTitle => 'Välj en bildanalysmodell';

  @override
  String get aiImageGenerationPickerTitle => 'Välj en bildgenereringsmodell';

  @override
  String get aiImpactBreakdownBoth => 'Båda';

  @override
  String get aiImpactBreakdownCategory => 'Efter kategori';

  @override
  String get aiImpactBreakdownModel => 'Efter modell';

  @override
  String get aiImpactCategoryTitle => 'Kategoriuppdelning';

  @override
  String get aiImpactChartHint =>
      'Tryck på en stapel för att avgränsa samtal · Tappa en serie för att isolera';

  @override
  String get aiImpactChartShareCaption => 'Sammansättning över tid';

  @override
  String get aiImpactChartShareSegment => 'Dela';

  @override
  String aiImpactChartTitle(String metric) {
    return '$metric efter kategori';
  }

  @override
  String aiImpactChartTitleModel(String metric) {
    return '$metric efter modell';
  }

  @override
  String get aiImpactCoverageNote =>
      'Energi, CO₂e och kostnad mäts endast för molnmodeller.';

  @override
  String get aiImpactEmptyBody =>
      'AI-samtal från dina uppgifter och agenter dyker upp här.';

  @override
  String get aiImpactEmptyTitle => 'Ingen AI-användning inom detta område';

  @override
  String get aiImpactKpiCarbon => 'CO₂E';

  @override
  String get aiImpactKpiCost => 'KOSTNAD';

  @override
  String aiImpactKpiDeltaBaseline(String period) {
    return 'vs $period';
  }

  @override
  String get aiImpactKpiEnergy => 'ENERGI';

  @override
  String get aiImpactKpiRequests => 'FÖRFRÅGNINGAR';

  @override
  String get aiImpactKpiTokens => 'TOKENS';

  @override
  String get aiImpactLedgerClearFilter => 'Visa allt';

  @override
  String get aiImpactLoadError => 'Kunde inte ladda AI-påverkandata';

  @override
  String get aiImpactLocationColumn => 'LÄGE';

  @override
  String get aiImpactLocationTitle => 'Påverkan per plats';

  @override
  String get aiImpactLocationUnknown => 'Okänt';

  @override
  String get aiImpactMetricCarbon => 'CO₂e';

  @override
  String get aiImpactMetricCost => 'Kostnad';

  @override
  String get aiImpactMetricEnergy => 'Energi';

  @override
  String get aiImpactMetricRequests => 'Förfrågningar';

  @override
  String get aiImpactMetricTokens => 'Tokens';

  @override
  String aiImpactModelCallsLabel(String count) {
    return '$count anrop';
  }

  @override
  String get aiImpactModelColumn => 'MODELL';

  @override
  String get aiImpactModelCostHeavy => 'Kostnadstungt';

  @override
  String get aiImpactModelCoverageNote =>
      'Lokala modeller är uteslutna från detta diagram.';

  @override
  String get aiImpactModelOther => 'Andra modeller';

  @override
  String aiImpactModelRatePerMillion(String cost) {
    return '$cost/1M tok';
  }

  @override
  String get aiImpactModelTitle => 'Modelluppdelning';

  @override
  String get aiImpactModelUnknown => 'Okänd modell';

  @override
  String get aiImpactRenewableColumn => 'FÖRNYBART';

  @override
  String get aiImpactTitle => 'AI-påverkan';

  @override
  String get aiInferenceErrorAuthenticationTitle =>
      'Autentisering misslyckades';

  @override
  String get aiInferenceErrorConnectionFailedTitle =>
      'Anslutningen misslyckades';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Ogiltig begäran';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Hastighetsgräns överskriden';

  @override
  String get aiInferenceErrorRetryButton => 'Försök igen';

  @override
  String get aiInferenceErrorServerTitle => 'Serverfel';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Förslag:';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Begäran löper ut';

  @override
  String get aiInferenceErrorUnknownTitle => 'Fel';

  @override
  String get aiInternalsTitle => 'Agentens inre delar';

  @override
  String get aiModelDownloadCloseButton => 'Stäng';

  @override
  String aiModelDownloadDialogDescription(String modelName) {
    return 'Lotti laddar ner $modelName till MLX Audio-cachen och använder den för lokal talbearbetning.';
  }

  @override
  String aiModelDownloadDialogTitle(String modelName) {
    return 'Installera $modelName';
  }

  @override
  String get aiModelDownloadInstallTooltip => 'Installationsmodell';

  @override
  String get aiModelDownloadOpenProgressTooltip => 'Visa nedladdningsframsteg';

  @override
  String get aiModelDownloadStatusChecking => 'Kontrollerar modellstatus';

  @override
  String aiModelDownloadStatusDownloading(int percent) {
    return 'Nedladdning av $percent%';
  }

  @override
  String get aiModelDownloadStatusDownloadingIndeterminate => 'Nedladdning';

  @override
  String get aiModelDownloadStatusFailed => 'Nedladdning misslyckades';

  @override
  String get aiModelDownloadStatusInstalled => 'Installerat';

  @override
  String get aiModelDownloadStatusNotInstalled => 'Ej installerad';

  @override
  String get aiModelDownloadStatusUnsupported => 'Apple Silicon krävs';

  @override
  String get aiModelInstallChoiceCancelButton => 'Avbryt';

  @override
  String get aiModelInstallChoiceDescription =>
      'Välj först den lokala tal-till-text-modellen att ladda ner. Du kan installera de andra senare från modelllistan.';

  @override
  String get aiModelInstallChoiceInstallButton => 'Installationsmodell';

  @override
  String get aiModelInstallChoiceRecommended => 'Rekommenderas';

  @override
  String get aiModelInstallChoiceTitle => 'Välj MLX Audio-modellen';

  @override
  String get aiModelPickerByProviderLabel => 'Välj en leverantör';

  @override
  String get aiModelPickerCurrentDefaultLabel =>
      'Nuvarande betalningsinställelse';

  @override
  String aiModelPickerProviderModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modeller',
      one: '1 modell',
    );
    return '$_temp0';
  }

  @override
  String aiOllamaModelInstalledSuccessfully(String modelName) {
    return 'Modell \"$modelName\" installerades framgångsrikt!';
  }

  @override
  String get aiPickProviderBadgeDesktopOnly => 'ENDAST SKRIVBORD';

  @override
  String get aiPickProviderBadgeNew => 'NYTT';

  @override
  String get aiPickProviderBadgeRecommended => 'REKOMMENDERAT';

  @override
  String get aiPickProviderContinueButton => 'Fortsätt';

  @override
  String get aiPickProviderDontShowAgainButton => 'Visa dig inte igen';

  @override
  String get aiPickProviderFooterHint =>
      'Du kan lägga till fler vårdgivare senare i Settings → AI. Din API-nyckel lagras lokalt.';

  @override
  String get aiPickProviderModalTitle => 'Ställ in AI-funktioner';

  @override
  String get aiPickProviderSubtitle =>
      'Välj en leverantör för att komma igång. Vi sätter automatiskt upp modeller och en startprofil.';

  @override
  String get aiProfileCardActiveBadge => 'Aktiv';

  @override
  String get aiProfileModelPickerSearchHint => 'Sök modeller...';

  @override
  String get aiProfileSlotModelMissing => 'Saknas';

  @override
  String get aiPromptGenerationPickerTitle => 'Välj en promptgenereringsmodell';

  @override
  String get aiProviderAlibabaDescription =>
      'Alibaba Clouds Qwen-familj av modeller via DashScope API';

  @override
  String get aiProviderAlibabaName => 'Alibaba Cloud (Qwen)';

  @override
  String get aiProviderAnthropicDescription =>
      'Anthropics Claude-familj av AI-assistenter';

  @override
  String get aiProviderAnthropicName => 'Anthropiske Claude';

  @override
  String get aiProviderCardDraftBadge => 'DRAFT';

  @override
  String get aiProviderCardFixButton => 'Fix';

  @override
  String aiProviderCardModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modeller',
      one: '1 modell',
    );
    return '$_temp0';
  }

  @override
  String aiProviderCardModelCountWithLastUsed(int count, String lastUsed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modeller · Senast använd $lastUsed',
      one: '1 modell · Senast använd $lastUsed',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardOllamaHint => 'Se till att Ollama är igång';

  @override
  String aiProviderCardStatusConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ansluten · $count modeller',
      one: 'Ansluten · 1 modell',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardStatusConnectedShort => 'Ansluten';

  @override
  String get aiProviderCardStatusInvalidKey => 'Ogiltig nyckel';

  @override
  String get aiProviderCardStatusOffline =>
      'Offline · Se till att Ollama är igång';

  @override
  String get aiProviderCardStatusOfflineShort => 'Offline';

  @override
  String get aiProviderConnectBackToProviders => 'Tillbaka till leverantörer';

  @override
  String get aiProviderConnectBreadcrumbAdd => 'Lägg till leverantör';

  @override
  String get aiProviderConnectFieldBaseUrlHint =>
      'Lämna tomt för att använda den officiella slutpunkten';

  @override
  String get aiProviderConnectFieldBaseUrlLabelOptional => 'Bas-URL (valfritt)';

  @override
  String get aiProviderConnectFieldBaseUrlPlaceholder =>
      'https://api.example.com';

  @override
  String get aiProviderConnectFieldDisplayNameHint =>
      'Visas i din leverantörslista';

  @override
  String get aiProviderConnectionCheckingLabel =>
      'Kryssar i nyckeln, listar tillgängliga modeller...';

  @override
  String aiProviderConnectionFailedBadResponseDetail(String type) {
    return 'Oväntad responsform: $type';
  }

  @override
  String aiProviderConnectionFailedHttpDetail(int status, String message) {
    return 'HTTP $status · $message';
  }

  @override
  String get aiProviderConnectionFailedInvalidBaseUrlDetail =>
      'Bas-URL:en måste inkludera http(s)-schema och värd (t.ex. https://api.example.com)';

  @override
  String aiProviderConnectionFailedNetworkDetail(String message) {
    return '$message';
  }

  @override
  String get aiProviderConnectionFailedTimeoutDetail => 'Begäran avslutad';

  @override
  String aiProviderConnectionFailedTitle(String providerName) {
    return 'Kunde inte nå $providerName. Kolla nyckeln eller ditt nätverk.';
  }

  @override
  String get aiProviderConnectionRetestButton => 'Omtest';

  @override
  String get aiProviderConnectionRetryButton => 'Omprövning';

  @override
  String aiProviderConnectionVerifiedSubtitle(int count, int ms) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modeller tillgängliga på ditt konto · svarade i ${ms}ms',
      one: '1 modell tillgänglig på ditt konto · Svarade i ${ms}ms',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderConnectionVerifiedTitle => 'Anslutning verifierad';

  @override
  String aiProviderConnectKeyHelperLink(String url) {
    return 'Skaffa en nyckel på $url';
  }

  @override
  String get aiProviderConnectKeyHiddenLabel => 'Dold';

  @override
  String get aiProviderConnectKeyPrivacyHint =>
      'Din API-nyckel lämnar aldrig din enhet.';

  @override
  String aiProviderConnectPageTitle(String providerName) {
    return 'Koppla $providerName';
  }

  @override
  String get aiProviderConnectSaveAndContinue => 'Spara & Fortsätt';

  @override
  String get aiProviderConnectSaveAsDraft => 'Spara som utkast';

  @override
  String get aiProviderConnectSavedAsDraftToast => 'Sparad som utkast';

  @override
  String get aiProviderConnectStepChoose => 'Välj leverantör';

  @override
  String get aiProviderConnectStepConnect => 'Koppla upp';

  @override
  String get aiProviderConnectStepReview => 'Granska';

  @override
  String get aiProviderDetailActiveProfileTitle => 'Aktiv profil';

  @override
  String get aiProviderDetailAddModelButton => 'Lägg till modell';

  @override
  String get aiProviderDetailApiKeyLabel => 'API-nyckel';

  @override
  String get aiProviderDetailBackTooltip => 'Tillbaka';

  @override
  String get aiProviderDetailBaseUrlLabel => 'Bas-URL';

  @override
  String get aiProviderDetailConnectionTitle => 'Anslutning';

  @override
  String get aiProviderDetailDangerZoneTitle => 'Farozon';

  @override
  String get aiProviderDetailDisplayNameLabel => 'Visningsnamn';

  @override
  String get aiProviderDetailEditButton => 'Redigering';

  @override
  String get aiProviderDetailEditTooltip => 'Redigeringsleverantör';

  @override
  String get aiProviderDetailLoadError =>
      'Kunde inte ladda denna leverantör. Försök igen från AI-inställningslistan.';

  @override
  String get aiProviderDetailMissingMessage =>
      'Denna leverantör finns inte längre tillgänglig.';

  @override
  String aiProviderDetailModelsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Modeller · $count',
      one: 'Modeller · 1',
      zero: 'Modeller',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderDetailNoModelsMessage =>
      'Inga modeller än. Lägg till en för att börja använda denna leverantör.';

  @override
  String get aiProviderDetailPageTitle => 'Leverantörsdetaljer';

  @override
  String get aiProviderDetailRemoveButton => 'Ta bort vårdgivaren';

  @override
  String get aiProviderDetailRemoveDescription =>
      'Tar bort leverantören och alla modeller som är beroende av den. Detta kan inte göras ogjort.';

  @override
  String get aiProviderDetailRemoveTitle => 'Ta bort denna leverantör';

  @override
  String get aiProviderDetailValueUnset => 'Inte inställt';

  @override
  String get aiProviderEmbeddedRuntimeHint =>
      'Körs inbäddad i Apple-appens process. Ingen lokal server eller bas-URL krävs.';

  @override
  String get aiProviderGeminiDescription => 'Googles Gemini AI-modeller';

  @override
  String get aiProviderGeminiName => 'Googla Gemini';

  @override
  String get aiProviderGenericOpenAiDescription =>
      'API kompatibelt med OpenAI-formatet';

  @override
  String get aiProviderGenericOpenAiName => 'OpenAI-kompatibel';

  @override
  String get aiProviderMeliousDescription =>
      'Europeiskt värd inferens med en dynamisk modellkatalog, routning, ljud och bilder';

  @override
  String get aiProviderMeliousName => 'Melious.ai';

  @override
  String get aiProviderMistralDescription =>
      'Mistral AI moln-API med inbyggd ljudtranskription';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderMlxAudioDescription =>
      'Inbyggda MLX Audio-modeller för lokal STT och TTS på Apple Silicon';

  @override
  String get aiProviderMlxAudioName => 'MLX Audio (lokal)';

  @override
  String get aiProviderNebiusAiStudioDescription =>
      'Nebius AI Studios modeller';

  @override
  String get aiProviderNebiusAiStudioName => 'Nebius AI Studio';

  @override
  String get aiProviderOllamaDescription => 'Kör inferens lokalt med Ollama';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOmlxDescription =>
      'Lokal OpenAI-kompatibel oMLX-inferens för MLX-modeller';

  @override
  String get aiProviderOmlxName => 'oMLX (lokal)';

  @override
  String get aiProviderOpenAiDescription => 'OpenAI:s GPT-modeller';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'OpenRouters modeller';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderTaglineAlibaba =>
      'Qwen-modeller · Multimodal · Lång kontext';

  @override
  String get aiProviderTaglineAnthropic => 'Familjen Claude · Lång kontext';

  @override
  String get aiProviderTaglineGemini => 'Multimodal · Ljudtranskription';

  @override
  String get aiProviderTaglineMelious =>
      'EU-värd · Dynamisk katalog · Eco-ruttning';

  @override
  String get aiProviderTaglineMlxAudio =>
      'Inbäddad · Apple Silicon · Lokalt ljud';

  @override
  String get aiProviderTaglineOllama => 'Körs lokalt · inga molnsamtal';

  @override
  String get aiProviderTaglineOmlx => 'Lokal MLX-inferens · OpenAI-kompatibel';

  @override
  String get aiProviderTaglineOpenAi => 'GPT-familjen · Vision + resonemang';

  @override
  String get aiProviderUnknownName => 'AI-leverantör';

  @override
  String get aiProviderVoxtralDescription =>
      'Lokal Voxtral transkription (upp till 30 min ljud, 13 språk)';

  @override
  String get aiProviderVoxtralName => 'Voxtral (lokal)';

  @override
  String get aiProviderWhisperDescription =>
      'Lokal Whisper-transkription med OpenAI-kompatibelt API';

  @override
  String get aiProviderWhisperName => 'Whisper (lokal)';

  @override
  String get aiRealtimeToggleTooltip => 'Byt till livetranskription';

  @override
  String get aiResponseDeleteCancel => 'Avbryt';

  @override
  String get aiResponseDeleteConfirm => 'Radera';

  @override
  String get aiResponseDeleteError =>
      'Misslyckades med att ta bort AI-svaret. Försök igen, tack.';

  @override
  String get aiResponseDeleteTitle => 'Ta bort AI-svar';

  @override
  String get aiResponseDeleteWarning =>
      'Är du säker på att du vill ta bort detta AI-svar? Detta kan inte göras ogjort.';

  @override
  String get aiResponseTypeAudioTranscription => 'Ljudtranskription';

  @override
  String get aiResponseTypeChecklistUpdates => 'Uppdateringar av checklistor';

  @override
  String get aiResponseTypeImageAnalysis => 'Bildanalys';

  @override
  String get aiResponseTypeImagePromptGeneration => 'Bildprompt';

  @override
  String get aiResponseTypePromptGeneration => 'Genererad prompt';

  @override
  String get aiResponseTypeTaskSummary => 'Uppgiftssammanfattning';

  @override
  String get aiRunningActivityOpenProgress => 'Visa AI-framsteg';

  @override
  String get aiSettingsAddedLabel => 'Tillagd';

  @override
  String get aiSettingsAddModelButton => 'Lägg till modell';

  @override
  String get aiSettingsAddModelErrorDescription =>
      'Något gick fel när jag lade till modellen. Försök igen, tack.';

  @override
  String get aiSettingsAddModelErrorTitle => 'Kunde inte lägga till modellen';

  @override
  String get aiSettingsAddModelTooltip =>
      'Lägg till denna modell i din leverantör';

  @override
  String get aiSettingsAddProfileButton => 'Lägg till profil';

  @override
  String get aiSettingsAddProviderButton => 'Lägg till leverantör';

  @override
  String get aiSettingsAgentWakeConcurrencyDescription =>
      'Välj hur många olika agenter som kan köra inferens samtidigt. Högre värden svarar snabbare men använder mer kapacitet för leverantörer och enheter.';

  @override
  String get aiSettingsAgentWakeConcurrencyLabel => 'Samtidigt agent vaknar';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Rensa alla filter';

  @override
  String get aiSettingsClearFiltersButton => 'Klart';

  @override
  String get aiSettingsCounterModels => 'Modeller';

  @override
  String get aiSettingsCounterProfiles => 'Profiler';

  @override
  String get aiSettingsCounterProviders => 'Leverantörer';

  @override
  String get aiSettingsEmptyDescription =>
      'Lägg till en för att låsa upp transkription, bildigenkänning, bildgenerering och semantisk sökning.';

  @override
  String get aiSettingsEmptyTitle => 'Inga leverantörer än';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filtrera efter $capability-funktion';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filtrera efter $provider';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip =>
      'Filtrera efter resonemangsförmåga';

  @override
  String get aiSettingsFtueBannerDescription =>
      'Det tar ungefär en minut. Lotti kommer att sätta upp modeller och en startprofil åt dig.';

  @override
  String get aiSettingsFtueBannerStartButton => 'Startuppsättning';

  @override
  String get aiSettingsFtueBannerTitle => 'Lägg till din första AI-leverantör';

  @override
  String get aiSettingsModalityAudio => 'Ljud';

  @override
  String get aiSettingsModalityText => 'Text';

  @override
  String get aiSettingsModalityVision => 'Vision';

  @override
  String get aiSettingsNoModelsConfigured => 'Inga AI-modeller konfigurerade';

  @override
  String get aiSettingsNoProvidersConfigured =>
      'Inga AI-leverantörer konfigurerade';

  @override
  String get aiSettingsPageLead =>
      'Konfigurera AI-leverantörer, modellerna Lotti kan kalla och inferensprofilerna som avgör vilken modell som hanterar vilken uppgift.';

  @override
  String get aiSettingsPageTitle => 'AI-inställningar';

  @override
  String get aiSettingsReasoningLabel => 'Resonemang';

  @override
  String get aiSettingsRemoveModelTooltip =>
      'Ta bort denna modell från din leverantör';

  @override
  String get aiSettingsSearchHint => 'Sökleverantörer, modeller, profiler...';

  @override
  String get aiSettingsSearchHintShort => 'Sökning';

  @override
  String get aiSettingsTabModels => 'Modeller';

  @override
  String get aiSettingsTabProfiles => 'Profiler';

  @override
  String get aiSettingsTabProviders => 'Leverantörer';

  @override
  String get aiSetupPreviewAcceptButton => 'Acceptera och avsluta';

  @override
  String get aiSetupPreviewAlreadyAddedSectionLabel => 'Redan tillagd';

  @override
  String aiSetupPreviewCategoryFooter(String categoryName) {
    return 'Sätt upp en testkategori $categoryName för att testa det.';
  }

  @override
  String aiSetupPreviewConnectedHeader(String providerName) {
    return '$providerName ansluten';
  }

  @override
  String get aiSetupPreviewCustomizeButton => 'Anpassa';

  @override
  String get aiSetupPreviewLead =>
      'Gå igenom vad Lotti kommer att lägga till. Avmarkera allt du inte vill ha; Du kan alltid sätta upp det senare för hand.';

  @override
  String get aiSetupPreviewLiveBadge => 'Live';

  @override
  String aiSetupPreviewModalTitle(String providerName) {
    return '$providerName uppsättning';
  }

  @override
  String get aiSetupPreviewModelsSectionLabel => 'Modeller';

  @override
  String get aiSetupPreviewProfileSectionLabel => 'Inferensprofil';

  @override
  String get aiSetupPreviewProfileSetActiveBadge => 'Aktivera';

  @override
  String aiSetupResultBulletCategoryCreated(String categoryName) {
    return 'Sätt upp en testkategori $categoryName för att testa det';
  }

  @override
  String aiSetupResultBulletCategoryReused(String categoryName) {
    return 'Återanvända befintlig testkategori $categoryName';
  }

  @override
  String aiSetupResultBulletModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Konfigurerade $count modeller',
      one: 'Konfigurerad 1 modell',
    );
    return '$_temp0';
  }

  @override
  String aiSetupResultBulletProfile(String profileName) {
    return 'Skapad inferensprofil $profileName';
  }

  @override
  String aiSetupResultErrorsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problem',
      one: '1 problem',
    );
    return '$_temp0 under installationen';
  }

  @override
  String aiSetupResultHeader(String providerName) {
    return '$providerName är sammankopplad';
  }

  @override
  String aiSetupResultKnownModelsMissing(String providerName) {
    return 'Misslyckades med att hitta nödvändiga $providerName modellkonfigurationer';
  }

  @override
  String get aiSetupResultLead =>
      'Vi ordnar allt åt dig. AI-funktioner är redo att användas i din journal.';

  @override
  String aiSetupResultModalTitle(String providerName) {
    return '$providerName redo';
  }

  @override
  String get aiSetupResultStartUsingButton => 'Börja använda AI';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Skapar optimerade modeller, promptar och en testkategori';

  @override
  String aiSetupWizardDescription(String providerName) {
    return 'Ställ in eller uppdatera modeller, promptar och testkategori för $providerName';
  }

  @override
  String get aiSetupWizardRunButton => 'Köruppsättning';

  @override
  String get aiSetupWizardRunLabel => 'Kör installationsguiden';

  @override
  String get aiSetupWizardRunningButton => 'Springer...';

  @override
  String get aiSetupWizardSafeToRunMultiple =>
      'Säkert att köra flera gånger – befintliga föremål kommer att behållas';

  @override
  String get aiSetupWizardTitle => 'AI-installationsguide';

  @override
  String get aiSummaryPlayTooltip => 'Spelsammanfattning';

  @override
  String get aiSummaryPreparingTooltip => 'Förberedelse av ljud';

  @override
  String get aiSummarySpeakTooltip => 'Läs sammanfattningen högt lokalt';

  @override
  String get aiSummaryStopTooltip => 'Stopp';

  @override
  String get aiSummaryThinkingLabel => 'Tänker...';

  @override
  String get aiSummaryTtsUnavailable => 'Text-till-tal är inte tillgängligt';

  @override
  String get aiTaskSummaryTitle => 'AI-uppgiftssammanfattning';

  @override
  String get aiTranscriptionPickerDefaultBadge => 'Standard';

  @override
  String get aiTranscriptionPickerTitle => 'Välj en transkriptionsmodell';

  @override
  String get apiKeyAddPageTitle => 'Lägg till leverantör';

  @override
  String get apiKeyAuthenticationDescription => 'Säkra din API-anslutning';

  @override
  String get apiKeyAuthenticationTitle => 'Autentisering';

  @override
  String get apiKeyAvailableModelsDescription =>
      'Snabbtillägg av förkonfigurerade modeller för denna leverantör';

  @override
  String get apiKeyAvailableModelsTitle => 'Tillgängliga modeller';

  @override
  String get apiKeyBaseUrlLabel => 'Bas-URL';

  @override
  String get apiKeyDisplayNameHint => 'Ange ett vänligt namn';

  @override
  String get apiKeyDisplayNameLabel => 'Visningsnamn';

  @override
  String get apiKeyDynamicModelsDescription =>
      'Sök i denna leverantörs katalog för levande modeller och lägg till vilken modell som helst';

  @override
  String get apiKeyEditGoBackButton => 'Gå tillbaka';

  @override
  String get apiKeyEditLoadError =>
      'Misslyckades med att ladda API-nyckelkonfiguration';

  @override
  String get apiKeyEditLoadErrorRetry => 'Försök igen eller kontakta supporten';

  @override
  String get apiKeyEditPageTitle => 'Redigera leverantör';

  @override
  String get apiKeyHideTooltip => 'Dölj API-nyckel';

  @override
  String get apiKeyInputHint => 'Ange din API-nyckel';

  @override
  String get apiKeyInputLabel => 'API-nyckel';

  @override
  String apiKeyKnownModelInputLabel(String modalities) {
    return 'I: $modalities';
  }

  @override
  String apiKeyKnownModelOutputLabel(String modalities) {
    return 'Ute: $modalities';
  }

  @override
  String get apiKeyProviderConfigDescription =>
      'Konfigurera dina inställningar för AI-inferensleverantör';

  @override
  String get apiKeyProviderConfigTitle => 'Leverantörskonfiguration';

  @override
  String get apiKeyProviderTypeHint => 'Välj en leverantörstyp';

  @override
  String get apiKeyProviderTypeLabel => 'Leverantörstyp';

  @override
  String get apiKeyShowTooltip => 'Visa API-nyckel';

  @override
  String get audioRecordingCancel => 'AVBRYT';

  @override
  String get audioRecordingDiscardDialogBody =>
      'Denna inspelning kommer att raderas. Ingen ljudinmatning, transkription eller uppgiftssammanfattning kommer att skapas.';

  @override
  String get audioRecordingDiscardDialogCancel => 'Fortsätt spela in';

  @override
  String get audioRecordingDiscardDialogConfirm => 'Kasta bort';

  @override
  String get audioRecordingDiscardDialogTitle => 'Släng inspelningen?';

  @override
  String get audioRecordingListening => 'Lyssnar...';

  @override
  String get audioRecordingPause => 'PAUS';

  @override
  String get audioRecordingRealtime => 'Livetranskription';

  @override
  String get audioRecordingResume => 'CV';

  @override
  String get audioRecordings => 'Ljudinspelningar';

  @override
  String get audioRecordingStandard => 'Standard';

  @override
  String get audioRecordingStop => 'STOPP';

  @override
  String backfillAdvancedRecoveryActions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count handlingar',
      one: '1 åtgärd',
    );
    return '$_temp0';
  }

  @override
  String get backfillAdvancedRecoveryTitle => 'Avancerad återhämtning';

  @override
  String get backfillAskPeersConfirmAccept => 'Fråga kollegor';

  @override
  String backfillAskPeersConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Detta vänder alla $count olösbara sekvensloggposter tillbaka till att saknas, så att den normala backfill-sweepen frågar peers igen. Jämliker som fortfarande har nyttolasten kommer att svara; Verkligt oåterkalleliga inträden kommer att pensioneras igen efter sju dagars amnestifönster. ',
      one:
          'Detta vänder tillbaka en olösbar sekvensloggpost till att saknas, så den normala backfill-svepningen frågar om peers. Jämliker som fortfarande har nyttolasten kommer att svara; Verkligt oåterkalleliga inträden kommer att pensioneras igen efter sju dagars amnestifönster. ',
    );
    return '$_temp0';
  }

  @override
  String get backfillAskPeersConfirmTitle =>
      'Fråga kollegor igen om olösbara poster?';

  @override
  String get backfillAskPeersDescription =>
      'Vänd tillbaka varje olösbar sekvensloggpost till saknad och låt den vanliga backfill-sweepen återfråga peers.';

  @override
  String get backfillAskPeersProcessing => 'Återöppnande...';

  @override
  String get backfillAskPeersTitle => 'Fråga peers om olösbar';

  @override
  String backfillAskPeersTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Be peers om $count poster',
      one: 'Be peers om 1 post',
    );
    return '$_temp0';
  }

  @override
  String get backfillCatchUpDescription =>
      'Hämta nyligen saknade poster från kollegor just nu.';

  @override
  String backfillDevicesMeta(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enhets-ID:n ',
      one: '1 enhets-ID',
    );
    return '$_temp0';
  }

  @override
  String get backfillManualDescription =>
      'Begär alla saknade poster oavsett ålder. Använd detta för att återställa äldre synkroniseringsluckor.';

  @override
  String get backfillManualProcessing => 'Bearbetar...';

  @override
  String get backfillManualTitle => 'Manuell fyllning';

  @override
  String get backfillManualTrigger => 'Begär saknade poster';

  @override
  String get backfillReRequestDescription =>
      'Begär om bidrag som efterfrågats men aldrig mottagits. Använd detta när svaren fastnar.';

  @override
  String get backfillReRequestProcessing => 'Begär igen...';

  @override
  String get backfillReRequestTitle => 'Ny begäran pågår';

  @override
  String get backfillReRequestTrigger => 'Begär på nytt väntande poster';

  @override
  String get backfillResetUnresolvableDescription =>
      'Återställ poster markerade som olösbara tillbaka till saknade så att de kan begäras igen. Använd repopulation efter sekvenslogg.';

  @override
  String get backfillResetUnresolvableProcessing => 'Återställer...';

  @override
  String get backfillResetUnresolvableTitle => 'Återställ Olösbar';

  @override
  String get backfillResetUnresolvableTrigger => 'Återställ olösbara poster';

  @override
  String get backfillRetireStuckConfirmAccept => 'Gå i pension nu';

  @override
  String backfillRetireStuckConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Detta markerar $count som för närvarande är öppna (saknade eller begärda) sekvensloggposter som olösbara. Använd detta för att avblockera vattenstämpeln när inlägg har fastnat ett tag utan att sjudagarsfönstret för amnesti har passerat. Poster kan fortfarande återupplivas om deras nyttolast senare anländer till disken med en giltig vektorklocka. ',
      one:
          'Detta markerar en för närvarande öppen (saknad eller begärd) sekvensloggpost som olösbar. Använd detta för att avblockera vattenstämpeln när inlägg har fastnat ett tag utan att sjudagarsfönstret för amnesti har passerat. Poster kan fortfarande återupplivas om deras nyttolast senare anländer till disken med en giltig vektorklocka. ',
    );
    return '$_temp0';
  }

  @override
  String get backfillRetireStuckConfirmTitle =>
      'Pensionera fastlåsta poster nu?';

  @override
  String get backfillRetireStuckDescription =>
      'Tvinga varje för närvarande öppen saknad eller efterfrågad sekvensloggpost till olösbar. Hoppar över 7-dagars amnestin — använd bara för fastkilade rader som blockerar vattenstämpeln.';

  @override
  String get backfillRetireStuckProcessing => 'Pensionering...';

  @override
  String get backfillRetireStuckTitle => 'Pensionera fastkörda anmälningar';

  @override
  String backfillRetireStuckTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pensionera $count fastna poster',
      one: 'Pensionera 1 fastnade poster',
    );
    return '$_temp0';
  }

  @override
  String get backfillSettingsSubtitle =>
      'Hantera synkroniseringsluckeåterställning';

  @override
  String get backfillSettingsTitle => 'Backfill-synkronisering';

  @override
  String get backfillStatsBackfilled => 'Fylld igen';

  @override
  String get backfillStatsBurned => 'Bränd';

  @override
  String get backfillStatsDeleted => 'Raderad';

  @override
  String get backfillStatsMissing => 'Saknad';

  @override
  String get backfillStatsNoData => 'Ingen synkdata tillgänglig';

  @override
  String get backfillStatsReceived => 'Mottaget';

  @override
  String get backfillStatsRefresh => 'Uppdatera statistik';

  @override
  String get backfillStatsRequested => 'Begärd';

  @override
  String get backfillStatsTitle => 'Synkstatistik';

  @override
  String get backfillStatsTotalEntries => 'Totalt antal anmälningar';

  @override
  String get backfillStatsUnresolvable => 'Olöslig';

  @override
  String get backfillStatusInboundQueue => 'Inkommande kö';

  @override
  String get backfillStatusMissing => 'Saknad';

  @override
  String get backfillStatusSkipped => 'Hoppade över';

  @override
  String get backfillToggleDescription =>
      'Begär saknade poster från de senaste 24 timmarna.';

  @override
  String get backfillToggleTitle => 'Automatisk återfyllning';

  @override
  String get basicSettings => 'Grundläggande miljöer';

  @override
  String get calendarHasPlanLabel => 'Har en plan';

  @override
  String get calendarTodayLabel => 'I dag';

  @override
  String get cancelButton => 'Avbryt';

  @override
  String get categoryActiveDescription =>
      'Inaktiva kategorier kommer inte att synas i urvalslistor';

  @override
  String get categoryActiveSwitchDescription => 'Valbar för nya bidrag';

  @override
  String get categoryAiDefaultsDescription =>
      'Sätt standard-AI-profil och agentmall för nya uppgifter i denna kategori';

  @override
  String get categoryAiDefaultsTitle => 'AI-standardinställningar';

  @override
  String get categoryCreationError =>
      'Misslyckades med att skapa kategori. Försök igen, tack.';

  @override
  String get categoryDayPlanDescription =>
      'Gör denna kategori tillgänglig för val i dagsplanen';

  @override
  String get categoryDayPlanLabel => 'Dagsplanering';

  @override
  String get categoryDefaultEventTemplateHint => 'Välj en mall';

  @override
  String get categoryDefaultEventTemplateLabel =>
      'Standardmall för händelseagent';

  @override
  String get categoryDefaultLanguageDescription =>
      'Sätt ett standardspråk för uppgifter i denna kategori';

  @override
  String get categoryDefaultProfileHint => 'Välj en profil';

  @override
  String get categoryDefaultTemplateHint => 'Välj en mall';

  @override
  String get categoryDefaultTemplateLabel => 'Standardagentmall';

  @override
  String get categoryDeleteConfirm => 'JA, TA BORT DENNA KATEGORI';

  @override
  String get categoryDeleteConfirmation =>
      'Denna åtgärd kan inte göras ogjort. Alla bidrag i denna kategori kommer att finnas kvar men kommer inte längre att kategoriseras.';

  @override
  String get categoryDeleteTitle => 'Ta bort kategori?';

  @override
  String get categoryFavoriteBadgeLabel => 'Favorit';

  @override
  String get categoryFavoriteDescription =>
      'Markera denna kategori som en favorit';

  @override
  String get categoryIconChooseHint => 'Välj en ikon';

  @override
  String get categoryIconCreateHint => 'Välj en ikon';

  @override
  String get categoryIconEditHint => 'Välj en annan ikon';

  @override
  String get categoryIconLabel => 'Ikon';

  @override
  String get categoryIconPickerTitle => 'Välj ikon';

  @override
  String get categoryNameRequired => 'Kategorinamn krävs';

  @override
  String get categoryNotFound => 'Kategori ej hittad';

  @override
  String get categoryPrivateBadgeLabel => 'Privat';

  @override
  String get categoryPrivateDescription =>
      'Endast synligt när privata bidrag visas';

  @override
  String get categorySearchPlaceholder => 'Sökkategorier...';

  @override
  String get changeSetCardTitle => 'Föreslagna förändringar';

  @override
  String get changeSetConfirmAll => 'Bekräfta allt';

  @override
  String changeSetConfirmAllPartialIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count föremål hade delvisa problem',
      one: '1 föremål hade delvisa problem',
    );
    return '$_temp0';
  }

  @override
  String get changeSetConfirmError => 'Misslyckades med att ansöka om ändring';

  @override
  String get changeSetItemConfirmed => 'Förändring applicerad';

  @override
  String changeSetItemConfirmedWithWarning(String warning) {
    return 'Applicerad med varning: $warning';
  }

  @override
  String get changeSetItemRejected => 'Förändring avvisad';

  @override
  String changeSetPendingCount(int count) {
    return '$count väntar';
  }

  @override
  String get changeSetSwipeConfirm => 'Bekräfta';

  @override
  String get changeSetSwipeReject => 'Avvisa';

  @override
  String get chatInputCancelRealtime => 'Avbryt (Esc)';

  @override
  String get chatInputCancelRecording => 'Avbryt inspelning (Esc)';

  @override
  String get chatInputConfigureModel => 'Konfigurera modell';

  @override
  String get chatInputHintDefault =>
      'Fråga om dina uppgifter och produktivitet...';

  @override
  String get chatInputHintSelectModel => 'Välj en modell för att börja chatta';

  @override
  String get chatInputListening => 'Lyssnar...';

  @override
  String get chatInputPleaseWait => 'Vänta, snälla...';

  @override
  String get chatInputProcessing => 'Bearbetar...';

  @override
  String get chatInputRecordVoice => 'Spela in röstmeddelande';

  @override
  String get chatInputSendTooltip => 'Skicka meddelande';

  @override
  String get chatInputStartRealtime => 'Starta livetranskription';

  @override
  String get chatInputStopRealtime => 'Stoppa livetranskriptionen';

  @override
  String get chatInputStopTranscribe => 'Stoppa och transkribera';

  @override
  String get checklistAddItem => 'Lägg till ett nytt föremål';

  @override
  String checklistAiConfidenceLabel(String level) {
    return 'Självförtroende: $level';
  }

  @override
  String get checklistAiMarkComplete => 'Markera Klar';

  @override
  String get checklistAiSuggestionBody => 'Detta verk verkar vara slutfört:';

  @override
  String get checklistAiSuggestionTitle => 'AI-förslag';

  @override
  String get checklistAllDone => 'Alla saker slutförda!';

  @override
  String get checklistCollapseTooltip => 'Kollaps';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total färdigt';
  }

  @override
  String get checklistDelete => 'Radera checklista?';

  @override
  String get checklistExpandTooltip => 'Utöka';

  @override
  String get checklistExportAsMarkdown => 'Exportchecklista som Markdown';

  @override
  String get checklistExportFailed => 'Exporten misslyckades';

  @override
  String get checklistItemArchived => 'Föremål arkiverat';

  @override
  String get checklistItemArchiveUndo => 'Ångra';

  @override
  String get checklistItemDeleteCancel => 'Avbryt';

  @override
  String get checklistItemDeleteConfirm => 'Bekräfta';

  @override
  String get checklistItemDeleted => 'Föremål borttaget';

  @override
  String get checklistItemDeleteWarning =>
      'Denna åtgärd kan inte göras ogjort.';

  @override
  String get checklistMarkdownCopied => 'Checklista kopierad som Markdown';

  @override
  String get checklistMoreTooltip => 'Mer';

  @override
  String get checklistNoneDone => 'Inga färdiga föremål än.';

  @override
  String get checklistNothingToExport => 'Inga varor att exportera';

  @override
  String get checklistProgressSemantics => 'Checklistans framsteg';

  @override
  String get checklistShare => 'Dela';

  @override
  String get checklistShareHint => 'Lång press för att dela';

  @override
  String get checklistsReorder => 'Omordning';

  @override
  String get clearButton => 'Klart';

  @override
  String get colorCustomLabel => 'Sedvänja';

  @override
  String get colorLabel => 'Färg';

  @override
  String get commandPaletteNoResults =>
      'Inga tillgängliga kommandon matchar din sökning';

  @override
  String get commandPaletteSearchHint => 'Sökkommandon...';

  @override
  String get commandPaletteTitle => 'Kommandopalett';

  @override
  String get commonError => 'Fel';

  @override
  String get commonLoading => 'Laddar...';

  @override
  String get commonUnknown => 'Okänt';

  @override
  String get completeHabitFailButton => 'Missade';

  @override
  String get completeHabitSkipButton => 'Hoppa över';

  @override
  String get completeHabitSuccessButton => 'Framgång';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'När den är aktiverad kommer appen att försöka generera inbäddningar för dina bidrag för att förbättra sök- och relaterade innehållsförslag.';

  @override
  String get configFlagDailyOsOnboardingEnabled => 'Daglig OS-genomgång';

  @override
  String get configFlagDailyOsOnboardingEnabledDescription =>
      'Vägled förstagångsanvändare av Daily OS genom en riktig avstämning som förvandlar tal till en uppgift och en dagsplan.';

  @override
  String get configFlagEnableAiStreaming =>
      'Aktivera AI-strömning för uppgiftsåtgärder';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Strömma AI-svar för uppgiftsrelaterade åtgärder. Stäng av för att buffra svar och håll gränssnittet smidigare.';

  @override
  String get configFlagEnableAiSummaryTts => 'AI-sammanfattningsuppspelning';

  @override
  String get configFlagEnableAiSummaryTtsDescription =>
      'Visa den lokala text-till-tal-knappen på sammanfattningar av uppgift-AI. Kräver en installerad MLX Audio TTS-modell.';

  @override
  String get configFlagEnableDashboardsPage => 'Aktivera dashboards-sidan';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Visa sidan Dashboards i huvudnavigeringen. Visa dina data och insikter i anpassningsbara instrumentpaneler.';

  @override
  String get configFlagEnableEmbeddings => 'Generera inbäddningar';

  @override
  String get configFlagEnableEvents => 'Aktivera händelser';

  @override
  String get configFlagEnableEventsDescription =>
      'Visa funktionen Händelser för att skapa, följa och hantera händelser i din journal.';

  @override
  String get configFlagEnableForkHealing => 'Agentgaffelläkning';

  @override
  String get configFlagEnableForkHealingDescription =>
      'Läka divergerande agenthistorier från användning med flera enheter genom att slå ihop dem vid nästa vak.';

  @override
  String get configFlagEnableHabitsPage => 'Aktivera Habits-sidan';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Visa sidan Vanor i huvudnavigeringen. Följ och hantera dina dagliga vanor här.';

  @override
  String get configFlagEnableLogging => 'Aktivera loggning';

  @override
  String get configFlagEnableLoggingDescription =>
      'Aktivera detaljerad loggning för felsökningsändamål. Detta kan påverka prestandan.';

  @override
  String get configFlagEnableMatrix => 'Aktivera matrissynkronisering';

  @override
  String get configFlagEnableMatrixDescription =>
      'Aktivera Matrix-integrationen för att synkronisera dina poster mellan enheter och med andra Matrix-användare.';

  @override
  String get configFlagEnableNotifications => 'Aktivera notiser?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Få notiser om påminnelser, uppdateringar och viktiga evenemang.';

  @override
  String get configFlagEnableProjects => 'Möjliggöra projekt';

  @override
  String get configFlagEnableProjectsDescription =>
      'Visa projektledningsfunktioner för att organisera uppgifter i projekt.';

  @override
  String get configFlagEnableSessionRatings => 'Aktivera sessionsbetyg';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Be om en snabb sessionsbedömning när du stoppar en timer.';

  @override
  String get configFlagEnableTooltip => 'Aktivera verktygstips';

  @override
  String get configFlagEnableTooltipDescription =>
      'Visa användbara verktygstips genom hela appen för att vägleda dig genom funktioner.';

  @override
  String get configFlagEnableVectorSearch => 'Vektorsökning';

  @override
  String get configFlagEnableVectorSearchDescription =>
      'Aktivera vektorsökning i uppgiftsfilter. Kräver att embeddings aktiveras och att Ollama körs.';

  @override
  String get configFlagEnableWhatsNew => 'Visa vad som är nytt';

  @override
  String get configFlagEnableWhatsNewDescription =>
      'Lyft fram nya funktioner och förändringar i Inställningar-trädet.';

  @override
  String get configFlagPrivate => 'Visa privata bidrag?';

  @override
  String get configFlagPrivateDescription =>
      'Aktivera detta för att göra dina poster privata som standard. Privata inträde är endast synliga för dig.';

  @override
  String get configFlagRecordLocation => 'Inspelningsplats';

  @override
  String get configFlagRecordLocationDescription =>
      'Registrera automatiskt din plats med nya poster. Detta hjälper till med platsbaserad organisering och sökning.';

  @override
  String get configFlagResendAttachments => 'Skicka bilagor på nytt';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Aktivera detta för att automatiskt skicka om misslyckade bilagor när anslutningen återställs.';

  @override
  String get configFlagShowSyncActivityIndicator =>
      'Visa synkroniseringsaktivitetsindikator';

  @override
  String get configFlagShowSyncActivityIndicatorDescription =>
      'Visa en tyst synkroniseringsstatus i sidofältet; Köräkningar visas endast medan arbete pågår.';

  @override
  String get conflictApplyButton => 'Ansök';

  @override
  String get conflictApplyFailedTitle => 'Kunde inte applicera upplösning';

  @override
  String conflictBannerAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagar sedan',
      one: '1 dag sedan',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h sedan',
      one: '1 timme sedan',
    );
    return '$_temp0';
  }

  @override
  String get conflictBannerAgoJustNow => 'Just nu';

  @override
  String conflictBannerAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min sedan',
      one: '1 min sedan',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerDivergedAgo(String entity, String ago) {
    return '$entity · divergerade $ago';
  }

  @override
  String conflictBannerFieldsDifferList(String fields) {
    return 'Skiljer sig i: $fields';
  }

  @override
  String get conflictCombineApply => 'Ansök kombinerad';

  @override
  String get conflictCombineStartFrom => 'Börja från';

  @override
  String get conflictConfirmDeletion => 'Bekräfta borttagning';

  @override
  String get conflictDeleteVsEditDescription =>
      'Denna post redigerades på en enhet och raderades på en annan. Inget tas bort förrän du väljer.';

  @override
  String get conflictDeleteVsEditTitle => 'Raderad på en enhet';

  @override
  String get conflictDetailEntryNotFoundTitle => 'Inlägg ej hittat';

  @override
  String get conflictDetailLoadErrorTitle => 'Kunde inte ladda konflikt';

  @override
  String get conflictDetailNotFoundTitle => 'Konflikt som inte hittades';

  @override
  String get conflictDiffRecommended => 'Rekommenderas';

  @override
  String conflictDiffUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fält oförändrade',
      one: '1 fält oförändrat',
    );
    return '$_temp0';
  }

  @override
  String get conflictFieldBody => 'Kaross';

  @override
  String get conflictFieldCategory => 'Kategori';

  @override
  String get conflictFieldDuration => 'Varaktighet';

  @override
  String get conflictFieldEnd => 'Slut';

  @override
  String get conflictFieldFlag => 'Flagga';

  @override
  String get conflictFieldOther => 'Övriga detaljer';

  @override
  String get conflictFieldOtherDescription =>
      'Dessa versioner skiljer sig åt i detaljer som inte visas individuellt här.';

  @override
  String get conflictFieldPrivate => 'Privat';

  @override
  String get conflictFieldStarred => 'Medverkad';

  @override
  String get conflictFieldStart => 'Start';

  @override
  String get conflictFieldTitle => 'Titel';

  @override
  String get conflictFieldWordCount => 'Ordantal';

  @override
  String get conflictFlagFollowUp => 'Uppföljning behövs';

  @override
  String get conflictFlagImport => 'Importerad';

  @override
  String get conflictFlagNone => 'Inga';

  @override
  String get conflictFooterHelperLocalSelected =>
      'Behåller din lokala redigering och slänger den synkade versionen.';

  @override
  String get conflictFooterHelperPickASide => 'Välj en sida att ansöka.';

  @override
  String get conflictFooterHelperRemoteSelected =>
      'Accepterar den synkade versionen och slänger din lokala redigering.';

  @override
  String conflictHeaderPillEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poster',
      one: '1 post',
    );
    return '$_temp0';
  }

  @override
  String conflictHeaderPillFieldsDiffer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fält skiljer sig åt',
      one: '1 fält skiljer sig',
    );
    return '$_temp0';
  }

  @override
  String get conflictKeepEdited => 'Behåll den redigerade versionen';

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
  String get conflictMetaViaSync => 'via synk';

  @override
  String conflictNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poster redigerades på två enheter',
      one: '1 artikel redigerades på två enheter',
    );
    return '$_temp0';
  }

  @override
  String get conflictNotificationTitle => 'Sync behöver din granskning';

  @override
  String get conflictPageLeadDesktop =>
      'Skillnader markeras inline. Klicka på en sida för att använda den versionen, eller öppna Redigera och slå ihop för att kombinera dem.';

  @override
  String get conflictPageLeadMobile =>
      'Skillnader markeras inline. Tryck på en sida för att använda den versionen.';

  @override
  String get conflictPageTitle => 'Synkroniseringskonflikt';

  @override
  String get conflictPickerCombine => 'Kombinera...';

  @override
  String get conflictPickerEditMerge => 'Redigera och slå ihop...';

  @override
  String get conflictPickerUseFromSync => 'Använd från sync';

  @override
  String get conflictPickerUseThisDevice => 'Använd denna enhet';

  @override
  String get conflictResolvedToast => 'Konflikten löst';

  @override
  String get conflictsEmptyDescription =>
      'Allt är i synk just nu. Lösta föremål förblir tillgängliga i det andra filtret.';

  @override
  String get conflictsEmptyTitle => 'Inga konflikter upptäckta';

  @override
  String get conflictSideFromSync => 'FRÅN SYNC';

  @override
  String get conflictSideThisDevice => 'DENNA APPARAT';

  @override
  String get conflictsResolved => 'Löst';

  @override
  String get conflictsUnresolved => 'olöst';

  @override
  String get conflictValueAbsent => 'Inte inställt';

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
  String get copyAsMarkdown => 'Kopiera som Markdown';

  @override
  String get copyAsText => 'Kopierad som text';

  @override
  String get correctionExampleCancel => 'AVBRYT';

  @override
  String correctionExamplePending(int seconds) {
    return 'Sparkorrigering i ${seconds}s...';
  }

  @override
  String get correctionExamplesEmpty =>
      'Inga korrigeringar har fångats än. Redigera en checklista för att lägga till ditt första exempel.';

  @override
  String get correctionExamplesSectionDescription =>
      'När du manuellt korrigerar checklistor sparas dessa korrigeringar här och används för att förbättra AI-förslag.';

  @override
  String get correctionExamplesSectionTitle =>
      'Exempel på checklistkorrigeringar';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'Du har $count-korrigeringar. Endast den senaste $max kommer att användas i AI-promptar. Överväg att ta bort gamla eller överflödiga exempel.';
  }

  @override
  String get coverArtChipActive => 'Omslag';

  @override
  String get coverArtChipSet => 'Scenografi';

  @override
  String get coverArtGenerationComplete => 'Omslagskonsten klar!';

  @override
  String get coverArtGenerationDismissHint =>
      'Du kan stänga detta – generationen fortsätter i bakgrunden';

  @override
  String get createButton => 'Skapa';

  @override
  String get createCategoryTitle => 'Skapa kategori';

  @override
  String get createEntryLabel => 'Skapa ny post';

  @override
  String get createEntryTitle => 'Lägg till';

  @override
  String get createNewLinkedTask => 'Skapa ny länkad uppgift...';

  @override
  String get customColor => 'Specialfärg';

  @override
  String get dailyOsDayPlan => 'Dagsplan';

  @override
  String get dailyOsNextAgendaCapacityComfortable => 'Bekvämt';

  @override
  String get dailyOsNextAgendaCapacityNearFull => 'Nästan full';

  @override
  String get dailyOsNextAgendaCapacityNoPlan => 'Ingen plan än';

  @override
  String dailyOsNextAgendaCapacityOf(String capacity) {
    return 'av $capacity';
  }

  @override
  String get dailyOsNextAgendaCapacityOver => 'Överkapacitet';

  @override
  String get dailyOsNextAgendaDonutLeft => 'Vänster';

  @override
  String get dailyOsNextAgendaDonutOver => 'över';

  @override
  String dailyOsNextAgendaHeadlineLeft(String duration) {
    return '$duration vänster';
  }

  @override
  String dailyOsNextAgendaHeadlineOver(String duration) {
    return '$duration över';
  }

  @override
  String get dailyOsNextAgendaNoPlanBody =>
      'Din registrerade tid är här oavsett — prata med en incheckning så skriver jag en dag runt den.';

  @override
  String dailyOsNextAgendaNoPlanSummary(String duration) {
    return '$duration har följt hittills. Håll en uppföljning så skriver jag en dag runt det.';
  }

  @override
  String get dailyOsNextAgendaNoPlanTitle => 'Ingen plan än för idag.';

  @override
  String get dailyOsNextAgendaStateDone => 'Klart';

  @override
  String get dailyOsNextAgendaStateInProgress => 'Pågående';

  @override
  String get dailyOsNextAgendaStateOpen => 'Öppet';

  @override
  String get dailyOsNextAgendaStateOverdue => 'Försenad';

  @override
  String dailyOsNextAgendaSummary(String scheduled, String capacity) {
    return '$scheduled av $capacity begått';
  }

  @override
  String dailyOsNextAgendaTrackedLegend(String duration, int completedCount) {
    return 'Spårad · $duration · $completedCount klart';
  }

  @override
  String get dailyOsNextBlockEditCategoryLabel => 'Kategori';

  @override
  String get dailyOsNextBlockEditFailed =>
      'Kunde inte uppdatera blocket — försök igen.';

  @override
  String get dailyOsNextBlockEditNameLabel => 'Titel';

  @override
  String get dailyOsNextBlockEditOpenTask => 'Öppen uppgift';

  @override
  String get dailyOsNextBlockEditSave => 'Sparändringar';

  @override
  String get dailyOsNextBlockEditSaved => 'Schemat uppdaterat.';

  @override
  String get dailyOsNextBlockEditTimeLabel => 'Start och slut';

  @override
  String get dailyOsNextBlockEditTitle => 'Redigera block';

  @override
  String get dailyOsNextBlockEditTooltip => 'Redigera block';

  @override
  String get dailyOsNextBlockEditWhyLabel => 'Varför just den här gången';

  @override
  String get dailyOsNextBlockMoveTooltip => 'Flyttblockering';

  @override
  String get dailyOsNextBlockResizeEndTooltip => 'Justera änden';

  @override
  String get dailyOsNextBlockResizeStartTooltip => 'Justera start';

  @override
  String get dailyOsNextCaptureCaptured => 'Förstått.';

  @override
  String get dailyOsNextCaptureDoneCta => 'Klart';

  @override
  String get dailyOsNextCaptureErrorMicrophonePermissionDenied =>
      'Mikrofontillstånd nekades.';

  @override
  String get dailyOsNextCaptureErrorNoActiveRealtimeSession =>
      'Ingen aktiv realtidssession.';

  @override
  String get dailyOsNextCaptureErrorNoAudioRecorded =>
      'Inget ljud spelades in.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionFailed =>
      'Realtidstranskribering misslyckades.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionStartFailed =>
      'Realtidstranskribering kunde inte starta.';

  @override
  String get dailyOsNextCaptureErrorRecordingStartFailed =>
      'Inspelningen kunde inte starta.';

  @override
  String get dailyOsNextCaptureErrorTranscriptionFailed =>
      'Transkriptionen misslyckades.';

  @override
  String get dailyOsNextCaptureHeadlineCaptured => 'Ser det här rätt ut?';

  @override
  String get dailyOsNextCaptureHeadlineLead => 'Vad tänker du på';

  @override
  String get dailyOsNextCaptureHeadlineListening => 'Jag lyssnar.';

  @override
  String get dailyOsNextCaptureHeadlineTail => 'För idag?';

  @override
  String dailyOsNextCaptureHeadlineTailForDate(String date) {
    return 'för $date?';
  }

  @override
  String get dailyOsNextCaptureHeadlineTailTomorrow => 'Till imorgon?';

  @override
  String get dailyOsNextCaptureHeadlineTailYesterday => 'För igår?';

  @override
  String get dailyOsNextCaptureHeadlineTranscribing => 'Att skriva ner det...';

  @override
  String get dailyOsNextCaptureIdleClick => 'Klicka för att prata';

  @override
  String get dailyOsNextCaptureIdleExample =>
      '\"Djupt arbete i morse, en promenad efter lunch, mejl före fem.\"';

  @override
  String get dailyOsNextCaptureIdleHint => 'Tryck för att prata · Typ istället';

  @override
  String get dailyOsNextCaptureIdleTalk => 'Tryck för att prata';

  @override
  String get dailyOsNextCaptureListeningStatus => 'Lyssnar...';

  @override
  String dailyOsNextCapturePastPrompt(String date) {
    return 'Finns det något du fortfarande vill spåra från $date?';
  }

  @override
  String get dailyOsNextCaptureReconcileCta => 'Recension';

  @override
  String get dailyOsNextCapturesPanelTitle => 'Fångster';

  @override
  String get dailyOsNextCaptureTranscribing => 'Transkriberar...';

  @override
  String get dailyOsNextCaptureTranscriptHint =>
      'Rätta till allt som transkriptet gjorde fel innan du planerar.';

  @override
  String get dailyOsNextCaptureTranscriptLabel => 'Recensionstranskription';

  @override
  String get dailyOsNextCaptureTypeInstead => 'Typ istället';

  @override
  String get dailyOsNextCaptureVoiceButtonReset => 'Börja om';

  @override
  String get dailyOsNextCaptureVoiceButtonStart => 'Börja lyssna';

  @override
  String get dailyOsNextCaptureVoiceButtonStop => 'Sluta lyssna';

  @override
  String get dailyOsNextCategoryFilterAll => 'Alla kategorier';

  @override
  String get dailyOsNextCategoryFilterDescription =>
      'Endast kategorier aktiverade för dagplanering visas för Daily OS automatiserad bearbetning.';

  @override
  String get dailyOsNextCategoryFilterEmpty =>
      'Inga kategorier aktiverade för dagplanering än.';

  @override
  String get dailyOsNextCategoryFilterIncludeAll => 'Inkludera alla';

  @override
  String get dailyOsNextCategoryFilterTitle => 'Bearbetningskategorier';

  @override
  String get dailyOsNextCategoryFilterTooltip =>
      'Välj dagliga OS-bearbetningskategorier';

  @override
  String dailyOsNextCommitCapacityNote(String scheduled, String capacity) {
    return '$scheduled av $capacity engagerad. Bekväm marginal – du kan ta in en överraskning.';
  }

  @override
  String get dailyOsNextCommitDraftOverline => 'DIN DAG, INKALLAD';

  @override
  String get dailyOsNextCommitExplainer =>
      'Logga ut för att gå idag från värnplikt till committ.';

  @override
  String get dailyOsNextCommitFinalStepEyebrow => 'SISTA STEGET';

  @override
  String get dailyOsNextCommitHeadline => 'Gör den till din.';

  @override
  String get dailyOsNextCommitHoldHelper => 'Vänta en sekund för att logga ut';

  @override
  String get dailyOsNextCommitHoldWordDone => 'Engagerad';

  @override
  String get dailyOsNextCommitHoldWordHolding => 'Fortsätt hålla i';

  @override
  String get dailyOsNextCommitHoldWordIdle => 'Håll';

  @override
  String get dailyOsNextCommitLockingIn => 'Låser in...';

  @override
  String get dailyOsNextCommitShepherdSubline =>
      'Jag ska vakta det — du gör jobbet.';

  @override
  String get dailyOsNextCommitSubCaption =>
      'Du kan fortfarande prata med mig efteråt – men benen stannar kvar.';

  @override
  String get dailyOsNextCommitTitle => 'Lås in det';

  @override
  String get dailyOsNextCommitTodayIsYours => 'Idag är din.';

  @override
  String get dailyOsNextDayBack => 'Tillbaka';

  @override
  String get dailyOsNextDayCheckInCta => 'Tala en incheckning';

  @override
  String get dailyOsNextDayDeleteDialogBody =>
      'De utkastade blocken för denna dag kommer att tas bort. Inspelningar och deras ljudinspelningar stannar i din dagbok.';

  @override
  String get dailyOsNextDayDeleteDialogCancel => 'Avbryt';

  @override
  String get dailyOsNextDayDeleteDialogConfirm => 'Radera';

  @override
  String get dailyOsNextDayDeleteDialogTitle => 'Radera den här planen?';

  @override
  String get dailyOsNextDayLockInCta => 'Lås in';

  @override
  String get dailyOsNextDayMenuDeletePlan => 'Ta bort planen';

  @override
  String get dailyOsNextDayMenuInspectAgent => 'Inspektera agent';

  @override
  String get dailyOsNextDayMenuSettings => 'Dagliga OS-inställningar';

  @override
  String get dailyOsNextDayMoreTooltip => 'Mer';

  @override
  String get dailyOsNextDayRefineCta => 'Förfina';

  @override
  String get dailyOsNextDayRefineFooterHint =>
      'Prata för att omforma planen – du kommer att se varje förändring innan något sparas.';

  @override
  String get dailyOsNextDayTitle => 'Din dag';

  @override
  String get dailyOsNextDayWhyChipLabel => 'VARFÖR';

  @override
  String get dailyOsNextDayWrapUpCta => 'Avslutning';

  @override
  String get dailyOsNextDraftingBackToDecisions => 'Tillbaka till besluten';

  @override
  String get dailyOsNextDraftingHeader => 'Utkast till din dag...';

  @override
  String get dailyOsNextDraftingNudgeAccept => 'Ja, skydda morgnarna';

  @override
  String get dailyOsNextDraftingNudgeDecline => 'Inte idag';

  @override
  String get dailyOsNextDraftingProgressBlocks => 'Draftblock';

  @override
  String get dailyOsNextDraftingProgressMatching => 'Matchningsuppgifter';

  @override
  String get dailyOsNextDraftingProgressQueued => 'Köad';

  @override
  String get dailyOsNextDraftingProgressReading => 'Läsincheckning';

  @override
  String get dailyOsNextDraftingProgressSaving => 'Sparplan';

  @override
  String get dailyOsNextDraftingProgressValidating => 'Validering';

  @override
  String get dailyOsNextDraftingReasoningOverline => '✦ RESONEMANG';

  @override
  String get dailyOsNextDraftingRecoveryBody =>
      'Vaket gav ingen plan. Försök igen, eller gå tillbaka och justera besluten innan du utkastar.';

  @override
  String get dailyOsNextDraftingRecoveryTitle => 'Draften stannade av';

  @override
  String get dailyOsNextDraftingRetry => 'Försök igen';

  @override
  String get dailyOsNextDraftingStatusAfternoon =>
      'Sekvenserar eftermiddagen...';

  @override
  String get dailyOsNextDraftingStatusAlmost => 'Nästan framme...';

  @override
  String get dailyOsNextDraftingStatusBreathing => 'Lämnar plats att andas...';

  @override
  String get dailyOsNextDraftingStatusDeepWork =>
      'Att lägga djupt arbete först...';

  @override
  String get dailyOsNextDraftingStatusMatching =>
      'Matcha uppgifter med din dag...';

  @override
  String get dailyOsNextDraftingStatusReading => 'Läser din incheckning...';

  @override
  String get dailyOsNextDraftingStatusTimings => 'Dubbelkollar tiderna...';

  @override
  String get dailyOsNextDraftingStatusYesterday =>
      'Att titta på gårdagens rytm...';

  @override
  String get dailyOsNextEditTitleHint => 'Redigera titeln';

  @override
  String get dailyOsNextGenericError =>
      'Något gick fel. Försök igen om en stund.';

  @override
  String get dailyOsNextGreetingAfternoon => 'God eftermiddag.';

  @override
  String get dailyOsNextGreetingEvening => 'God kväll.';

  @override
  String dailyOsNextGreetingHiName(String name) {
    return 'Hej $name 👋';
  }

  @override
  String get dailyOsNextGreetingMorning => 'God morgon.';

  @override
  String get dailyOsNextKnowledgeConfirm => 'Bekräfta';

  @override
  String get dailyOsNextKnowledgeConfirmedHeader => 'Bekräftat';

  @override
  String get dailyOsNextKnowledgeEdit => 'Redigering';

  @override
  String get dailyOsNextKnowledgeEditCancel => 'Avbryt';

  @override
  String get dailyOsNextKnowledgeEditHookHint => 'Enradssammanfattning';

  @override
  String get dailyOsNextKnowledgeEditSave => 'Spara';

  @override
  String get dailyOsNextKnowledgeEditStatementHint => 'Vad ska jag komma ihåg?';

  @override
  String get dailyOsNextKnowledgeEmpty =>
      'Inget än — jag kommer ihåg vad du berättar för mig.';

  @override
  String dailyOsNextKnowledgeNudge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saker jag lade märke till — recension',
      one: '1 sak jag lade märke till — recension',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextKnowledgeProposedHeader => 'Väntar på din bekräftelse';

  @override
  String get dailyOsNextKnowledgeRetract => 'Glöm';

  @override
  String get dailyOsNextKnowledgeStale => 'Stämmer det fortfarande?';

  @override
  String get dailyOsNextKnowledgeTitle => 'Vad jag har lärt mig';

  @override
  String get dailyOsNextParsedCardBreakLinkTooltip => 'Brytlänk';

  @override
  String get dailyOsNextPlanViewAgenda => 'Agenda';

  @override
  String get dailyOsNextPlanViewDay => 'Dag';

  @override
  String get dailyOsNextReconcileBadgeMatched => 'MATCHADE';

  @override
  String get dailyOsNextReconcileBadgeNew => 'NYTT';

  @override
  String get dailyOsNextReconcileBadgeUpdate => 'UPPDATERING';

  @override
  String get dailyOsNextReconcileBuildDayCta => 'Bygg min dag';

  @override
  String get dailyOsNextReconcileDecideOverline => 'VÄRT ATT BESTÄMMA SIG FÖR';

  @override
  String dailyOsNextReconcileDecisionProgress(int decided, int total) {
    return '$decided av $total recenserad';
  }

  @override
  String get dailyOsNextReconcileDefaultBehaviorHint =>
      'Gå igenom korten innan du bygger din dag. Valda handlingar matas in i planen; Korten som lämnas oförändrade förblir som de är.';

  @override
  String dailyOsNextReconcileError(String detail) {
    return 'Något gick fel: $detail';
  }

  @override
  String get dailyOsNextReconcileHeadline => 'Här är vad jag hörde.';

  @override
  String get dailyOsNextReconcileHeardEmpty =>
      'Capture-korten kommer att visas här när parsingen är klar.';

  @override
  String get dailyOsNextReconcileHeardOverline => 'HÖRDE';

  @override
  String get dailyOsNextReconcileLowConfidence => 'Låg självsäkerhet';

  @override
  String get dailyOsNextReconcileProcessing =>
      'Lyssnar tillbaka och matchar din dag...';

  @override
  String get dailyOsNextReconcileReRecord => 'Ominspelning';

  @override
  String get dailyOsNextReconcileVoiceHint =>
      'Gå igenom besluten innan du bygger din dag';

  @override
  String get dailyOsNextRefineAccept => 'Acceptera';

  @override
  String get dailyOsNextRefineCurrentPlan => 'NUVARANDE PLAN';

  @override
  String get dailyOsNextRefineDiffAdded => 'TILLAGD';

  @override
  String get dailyOsNextRefineDiffDropped => 'BORTTAGEN';

  @override
  String get dailyOsNextRefineDiffMoved => 'FLYTTADE';

  @override
  String get dailyOsNextRefineHeadlineDiffReady =>
      'Här är vad jag skulle ändra.';

  @override
  String get dailyOsNextRefineHeadlineIdle => 'Vad bör förändras?';

  @override
  String get dailyOsNextRefineHeadlineThinking => 'Att omarbeta din plan...';

  @override
  String get dailyOsNextRefineKeepTalking => 'Fortsätt prata';

  @override
  String get dailyOsNextRefineLooksGood => 'Ser bra ut';

  @override
  String get dailyOsNextRefineNoChanges =>
      'Inga ändringar i planen kom tillbaka tillbaka. Formulera om det och försök igen.';

  @override
  String get dailyOsNextRefineOverline => '🎤 FÖRFINING';

  @override
  String get dailyOsNextRefineRevert => 'Återställ';

  @override
  String get dailyOsNextRefineStatusAccepted => 'Låst.';

  @override
  String get dailyOsNextRefineStatusDiffReady => 'Här är vad som förändrades.';

  @override
  String get dailyOsNextRefineStatusIdle => 'Tryck för att prata.';

  @override
  String get dailyOsNextRefineStatusListening => 'Lyssnar...';

  @override
  String get dailyOsNextRefineStatusThinking => '✦ Omarbetar planen...';

  @override
  String get dailyOsNextRefineTitle => 'Förfina planen';

  @override
  String get dailyOsNextRenameFailed => 'Kunde inte byta namn – försöka igen.';

  @override
  String get dailyOsNextReviewAddBuffer => 'Lägg till buffert';

  @override
  String get dailyOsNextReviewAddBufferPrompt =>
      'Lägg till en realistisk buffert mellan de planerade blocken, särskilt vid övergångar och efter krävande arbete.';

  @override
  String get dailyOsNextReviewAdjust => 'Justera';

  @override
  String get dailyOsNextReviewLooksGood => 'Ser bra ut';

  @override
  String get dailyOsNextReviewMoveLighter => 'Rör dig lättare';

  @override
  String get dailyOsNextReviewMoveLighterPrompt =>
      'Flytta det lättare eller energisnåla arbetet senare, och behåll det starkaste fokusfönstret för den mest krävande uppgiften.';

  @override
  String get dailyOsNextReviewTooMuch => 'För mycket';

  @override
  String get dailyOsNextReviewTooMuchPrompt =>
      'Den här planen är för mycket för idag. Minska belastningen, skydda andningsutrymmet och behåll bara de viktigaste blocken.';

  @override
  String get dailyOsNextReviewWhyTitle => 'Varför dessa kom med';

  @override
  String get dailyOsNextShutdownCarryoverDrop => 'Släpp';

  @override
  String get dailyOsNextShutdownCarryoverDropped => 'Borttagen';

  @override
  String get dailyOsNextShutdownCarryoverOverline => 'LÖPNINGAR FRAMÅT';

  @override
  String get dailyOsNextShutdownCarryoverPickDate => 'Välj ett datum';

  @override
  String get dailyOsNextShutdownCarryoverScheduled => 'Planerade';

  @override
  String get dailyOsNextShutdownCloseDay => 'Avsluta dagen';

  @override
  String get dailyOsNextShutdownCompletedOverline => 'VAD DU GJORDE';

  @override
  String get dailyOsNextShutdownMetricEnergy => 'ENERGI';

  @override
  String dailyOsNextShutdownMetricEnergyDelta(String delta) {
    return '$delta vs. vecka';
  }

  @override
  String get dailyOsNextShutdownMetricFlow => 'FLÖDESSESSIONER';

  @override
  String get dailyOsNextShutdownMetricFocus => 'FOKUSTID';

  @override
  String get dailyOsNextShutdownMetricSwitches => 'KONTEXTBYTEN';

  @override
  String dailyOsNextShutdownMetricSwitchesAvg(String avg) {
    return 'AVG $avg denna vecka';
  }

  @override
  String get dailyOsNextShutdownReflectionOverline => '💬 ENRADSREFLEKTION';

  @override
  String get dailyOsNextShutdownReflectionPlaceholder =>
      't.ex. morgonen var skarp, eftermiddagen släpade ut efter kaffet med Sarah som drog ut på tiden.';

  @override
  String get dailyOsNextShutdownReflectionPrompt =>
      'Hur hamnade dagen? (Detta matar morgondagens utkast.)';

  @override
  String get dailyOsNextShutdownReflectionSpeak => 'Säg det';

  @override
  String get dailyOsNextShutdownReflectionSubmit => 'Hoppa över';

  @override
  String get dailyOsNextShutdownReflectionThanks => 'Fattar — matar imorgon.';

  @override
  String get dailyOsNextShutdownSaveAndClose => 'Spara och stäng';

  @override
  String get dailyOsNextShutdownTitle => 'Avsluta dagen';

  @override
  String get dailyOsNextShutdownTomorrowOverline => '✦ FÖR MORGONDAGEN';

  @override
  String dailyOsNextStateDueOnDate(String date) {
    return 'Förfaller: $date';
  }

  @override
  String get dailyOsNextStateDueToday => 'Förfaller idag';

  @override
  String dailyOsNextStateInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pågående · $count sessioner',
      one: 'Pågående · 1 session',
      zero: 'Pågående',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Försenad · $days dagar',
      one: 'Försenad · 1 dag',
      zero: 'Försenad',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdueOnDate(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: ' Förfallen med $days dagar på $date',
      one: ' Förfallen med 1 dag på $date',
      zero: 'Förfallen på $date',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextStateRecurringMissed => 'Återkommande · Missade';

  @override
  String get dailyOsNextTimelineActual => 'Nutid';

  @override
  String get dailyOsNextTimelineArrange => 'Arrangera block';

  @override
  String get dailyOsNextTimelineBoth => 'Plan och verklighet';

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
    return 'Session $index av $total';
  }

  @override
  String get dailyOsNextTimelineShowBoth =>
      'Showplan och verklighet tillsammans';

  @override
  String get dailyOsNextTimelineShowPaged => 'Visa swipebar plan och faktisk';

  @override
  String get dailyOsNextTimelineSwipeHint =>
      'Svep för faktiska · nyp vertikalt för att zooma in';

  @override
  String get dailyOsNextTimelineTracked => 'spårade';

  @override
  String dailyOsNextTimeSpentEarlierSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tidigare sessioner',
      one: '1 tidigare session',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextTimeSpentShowLess => 'Visa mindre';

  @override
  String dailyOsNextTimeSpentSummary(String duration, int completedCount) {
    return '$duration · $completedCount klart';
  }

  @override
  String get dailyOsNextTimeSpentTitle => 'IDAG HITTILLS';

  @override
  String get dailyOsNextTimeSpentTitlePast => 'TID SPENDERAD';

  @override
  String get dailyOsNextTriageConfirmDefer => 'Uppskjutet';

  @override
  String get dailyOsNextTriageConfirmDone => 'Markerat klart';

  @override
  String get dailyOsNextTriageConfirmDoNow => 'Klart nu';

  @override
  String get dailyOsNextTriageConfirmDrop => 'Borttagen';

  @override
  String get dailyOsNextTriageConfirmToday => 'Tillagd till idag';

  @override
  String get dailyOsNextTriageDefer => 'Skjut upp';

  @override
  String get dailyOsNextTriageDone => 'Klart';

  @override
  String get dailyOsNextTriageDoNow => 'Gör det nu';

  @override
  String get dailyOsNextTriageDrop => 'Släpp';

  @override
  String get dailyOsNextTriageToday => 'Idag';

  @override
  String get dailyOsOnboardingCoachCapture =>
      'Säg vad som fångar din uppmärksamhet.';

  @override
  String get dailyOsOnboardingCoachDrafting =>
      'Planeraren skapar nya uppgifter och anpassar arbetet till din dag.';

  @override
  String get dailyOsOnboardingCoachReconcile =>
      'Välj vad som hör hemma idag. Nya föremål blir uppgifter när du bygger dagen.';

  @override
  String get dailyOsOnboardingSpotlightAction => 'Prova';

  @override
  String get dailyOsOnboardingSpotlightDismiss => 'Inte nu';

  @override
  String get dailyOsOnboardingSpotlightMessage =>
      'Tryck här och säg vad du tänker på — jag gör det till en uppgift och bygger din dag kring det.';

  @override
  String get dailyOsOnboardingSpotlightTitle => 'Förvandla prat till en plan';

  @override
  String get dailyOsSettingsChooseModelDescription =>
      'Åsidosätt endast planerarens tänkandemodell.';

  @override
  String get dailyOsSettingsChooseModelTitle => 'Välj modell-överstyrning';

  @override
  String get dailyOsSettingsChooseProfileDescription =>
      'Åsidosätt hela inferensprofilen för denna planerare.';

  @override
  String get dailyOsSettingsChooseProfileTitle => 'Välj Daily OS-profil';

  @override
  String get dailyOsSettingsDataDisclosure =>
      'Daily OS skickar relevanta uppgifter, insamlingar, planer, inlärda preferenser och annan sammansatt planeringskontext till den valda leverantören för bearbetning.';

  @override
  String get dailyOsSettingsDefaultProfileDescription =>
      'Används av Daily OS om inte planerarinstansen har en överskrivning.';

  @override
  String get dailyOsSettingsDefaultProfileMissing => 'Välj en profil';

  @override
  String get dailyOsSettingsDefaultRestored => 'Daglig OS-standard återställd';

  @override
  String get dailyOsSettingsDirectOverrideActive =>
      'Direkt modellöverskrivning är aktiv.';

  @override
  String get dailyOsSettingsInferenceTitle => 'Standardinferensprofil';

  @override
  String get dailyOsSettingsInstanceCurrentSetup => 'Nuvarande planerarupplägg';

  @override
  String get dailyOsSettingsInstanceOverrideDescription =>
      'Använd Daily OS standardprofil, välj en profilöverskrivning eller åsidosätt endast denna planerares tänkandemodell.';

  @override
  String get dailyOsSettingsInstanceOverrideTitle => 'Daglig OS-inferens';

  @override
  String get dailyOsSettingsLocalDisclosure =>
      'Den valda ändpunkten finns på denna enhet.';

  @override
  String dailyOsSettingsModelChanged(String model) {
    return 'Daily OS använder nu $model';
  }

  @override
  String get dailyOsSettingsNameNudgeAction => 'Lägg till namn';

  @override
  String get dailyOsSettingsNameNudgeBody =>
      'Att lägga till ett föredraget namn gör incheckningarna mer personliga. Du kan fortsätta planera utan det.';

  @override
  String get dailyOsSettingsNameNudgeTitle => 'Hur bör Daily OS tilltala dig?';

  @override
  String dailyOsSettingsProfileChanged(String profile) {
    return 'Daily OS använder nu $profile';
  }

  @override
  String get dailyOsSettingsProfileOverrideActive => 'Profilöverstyrning aktiv';

  @override
  String dailyOsSettingsRemoteDisclosure(String provider, String host) {
    return 'Daily OS skickar den sammansatta planeringskontexten till $provider på $host för fjärrbearbetning.';
  }

  @override
  String get dailyOsSettingsSetupAction => 'Sätt upp Daily OS';

  @override
  String get dailyOsSettingsSetupRequiredBody =>
      'Daily OS behöver ditt val av leverantör innan det kan bearbeta din planeringskontext.';

  @override
  String get dailyOsSettingsSetupRequiredTitle => 'Välj en inferensprofil';

  @override
  String get dailyOsSettingsSubtitle =>
      'Välj hur Daily OS adresserar dig och vilken inferensprofil som planerar dina dagar.';

  @override
  String get dailyOsSettingsTitle => 'Daily OS';

  @override
  String get dailyOsSettingsTreeSubtitle =>
      'Leverantör av planering, personalisering och AI';

  @override
  String get dailyOsSettingsUseDefault => 'Använd Daily OS som standard';

  @override
  String get dailyOsSettingsUseDefaultDescription =>
      'Följ profilen som valts i Daily OS-inställningarna.';

  @override
  String get dailyOsTodayButton => 'Idag';

  @override
  String get dashboardActiveLabel => 'Aktiv';

  @override
  String get dashboardActiveSwitchDescription => 'Visas i dashboardlistan';

  @override
  String get dashboardAddChartsTitle => 'Topplistor';

  @override
  String get dashboardAddHabitButton => 'Habiter';

  @override
  String get dashboardAddHabitTitle => 'Vanediagram';

  @override
  String get dashboardAddHealthButton => 'Hälsa';

  @override
  String get dashboardAddHealthTitle => 'Hälsokartor';

  @override
  String get dashboardAddMeasurementButton => 'Mätningar';

  @override
  String get dashboardAddMeasurementTitle => 'Lägg till mätdiagram';

  @override
  String get dashboardAddMeasurementTooltip => 'Lägg till mätning';

  @override
  String get dashboardAddSurveyButton => 'Undersökningar';

  @override
  String get dashboardAddSurveyTitle => 'Kartor';

  @override
  String get dashboardAddWorkoutButton => 'Träningspass';

  @override
  String get dashboardAddWorkoutTitle => 'Träningsscheman';

  @override
  String get dashboardAggregationApplyImmediately =>
      'Välj en sammanfattning. Ändringar gäller omedelbart.';

  @override
  String get dashboardAggregationDailyAverage => 'Dagligt genomsnitt';

  @override
  String get dashboardAggregationDailyMax => 'Dagligt max';

  @override
  String get dashboardAggregationDailyTotal => 'Dagligt totalt';

  @override
  String get dashboardAggregationHourlyTotal => 'Timtotal';

  @override
  String get dashboardAggregationLabel => 'Aggregeringstyp:';

  @override
  String get dashboardAggregationTitle => 'Aggregeringstyp';

  @override
  String get dashboardAvailableChartsDescription =>
      'Välj en typ, välj en eller flera diagram, och lägg sedan till dem.';

  @override
  String get dashboardAvailableChartsTitle => 'Lägg till diagram efter typ';

  @override
  String get dashboardCategoryLabel => 'Kategori';

  @override
  String get dashboardChartNoData => 'Inga data i detta intervall';

  @override
  String get dashboardConfigurationDescription =>
      'Spara dashboarden och kopiera sedan dess JSON-konfiguration.';

  @override
  String get dashboardConfigurationTitle => 'Exportkonfiguration';

  @override
  String get dashboardCopyHint => 'Spara och kopiera dashboard-konfigurationen';

  @override
  String get dashboardCopyLabel => 'Spara och kopiera JSON';

  @override
  String get dashboardCurrentChartsDescription =>
      'Dra för att omordna. Mätdiagram kan väljas för att ändra sin aggregering.';

  @override
  String get dashboardCurrentChartsTitle => 'Diagram på denna instrumentpanel';

  @override
  String get dashboardDeleteConfirm => 'JA, TA BORT DENNA DASHBOARD';

  @override
  String get dashboardDeleteHint => 'Ta bort instrumentpanel';

  @override
  String get dashboardDeleteQuestion => 'Vill du ta bort den här dashboarden?';

  @override
  String get dashboardDescriptionLabel => 'Beskrivning (valfritt)';

  @override
  String get dashboardEditAggregationLabel => 'Redigeringsaggregering';

  @override
  String get dashboardHealthBloodPressure => 'Blodtryck';

  @override
  String get dashboardHealthDiastolic => 'Diastolisk';

  @override
  String get dashboardHealthSystolic => 'Systolisk';

  @override
  String dashboardMeasurementAddButtonWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' Lägg till $count diagram',
      one: 'Lägg till 1 diagram',
    );
    return '$_temp0';
  }

  @override
  String dashboardMeasurementAggregationFor(String name) {
    return 'Diagramläge för $name';
  }

  @override
  String get dashboardMeasurementAggregationHelp =>
      'Välj mätdiagram. Justera diagramläget på valda rader innan du lägger till.';

  @override
  String get dashboardNameLabel => 'Instrumentpanelens namn';

  @override
  String get dashboardNoChartsAdded =>
      'Inga diagram har lagts till än. Lägg till en nedan.';

  @override
  String get dashboardNoHabitsForCharts =>
      'Skapa en vana först för att lägga till vanediagram.';

  @override
  String get dashboardNoMeasurablesForCharts =>
      'Skapa en mätbar första för att lägga till måttdiagram.';

  @override
  String get dashboardNotFound => 'Instrumentpanel hittades inte';

  @override
  String get dashboardPrivateLabel => 'Privat';

  @override
  String get dashboardRemoveChartLabel => 'Ta bort diagram';

  @override
  String get dashboardReorderChartLabel => 'Omordning diagram';

  @override
  String get dashboardTakeSurveyTooltip => 'Gör en undersökning';

  @override
  String get defaultLanguage => 'Standardspråk';

  @override
  String get deleteButton => 'Radera';

  @override
  String get deleteDeviceLabel => 'Ta bort enheten';

  @override
  String get designSystemActionVariantTitle => 'Med handling';

  @override
  String get designSystemActivatedLabel => 'Aktiverad';

  @override
  String get designSystemAvatarAwayLabel => 'Borta';

  @override
  String get designSystemAvatarBusyLabel => 'Upptagen';

  @override
  String get designSystemAvatarConnectedLabel => 'Ansluten';

  @override
  String get designSystemAvatarEnabledLabel => 'Aktiverad';

  @override
  String get designSystemAvatarSizeMatrixTitle => 'Storleksmatris';

  @override
  String get designSystemAvatarStatusMatrixTitle => 'Statusmatris';

  @override
  String get designSystemBackLabel => 'Tillbaka';

  @override
  String get designSystemBreadcrumbCurrentLabel => 'Brödsmulor';

  @override
  String get designSystemBreadcrumbDesignSystemLabel => 'Designsystem';

  @override
  String get designSystemBreadcrumbHomeLabel => 'Hem';

  @override
  String get designSystemBreadcrumbMobileLabel => 'Mobil';

  @override
  String get designSystemBreadcrumbProjectsLabel => 'Projekt';

  @override
  String get designSystemBreadcrumbSampleLabel => 'Brödsmula';

  @override
  String get designSystemBreadcrumbTrailTitle => 'Brödsmulleden';

  @override
  String get designSystemCalendarPickerLabel => 'Kalendervalare';

  @override
  String get designSystemCalendarViewsTitle => 'Kalendervyer';

  @override
  String get designSystemCaptionDescriptionSample =>
      'Tar bort alla användare som inte publicerats i detta projekt. Lägg till användare för att publicera det igen.';

  @override
  String get designSystemCaptionIconLeftLabel => 'Vänster ikon';

  @override
  String get designSystemCaptionIconTopLabel => 'Toppikon';

  @override
  String get designSystemCaptionNoIconLabel => 'Ingen ikon';

  @override
  String get designSystemCaptionTitleSample => 'Bildtextens titel';

  @override
  String get designSystemCaptionVariantsTitle => 'Bildtextvarianter';

  @override
  String get designSystemCaptionWithActionsLabel => 'Med handlingar';

  @override
  String get designSystemCaptionWithoutActionsLabel => 'Utan handlingar';

  @override
  String get designSystemCheckboxLabel => 'Kryssruta';

  @override
  String get designSystemContextMenuDeleteLabel => 'Radera';

  @override
  String get designSystemContextMenuVariantsTitle => 'Varianter av kontextmeny';

  @override
  String get designSystemCountdownVariantTitle => 'Med nedräkning';

  @override
  String get designSystemDateCardsTitle => 'Datumkort';

  @override
  String get designSystemDefaultLabel => 'Standard';

  @override
  String get designSystemDisabledLabel => 'Funktionsnedsatt';

  @override
  String get designSystemDividerLabelText => 'Uppdelare';

  @override
  String get designSystemDropdownComboboxTitle => 'Combobox';

  @override
  String get designSystemDropdownFieldLabel => 'Etikett';

  @override
  String get designSystemDropdownInputLabel => 'Indata';

  @override
  String get designSystemDropdownListTitle => 'Rullgardinslista';

  @override
  String get designSystemDropdownMultiselectInputLabel => 'Utvalda lag';

  @override
  String get designSystemDropdownMultiselectTitle => 'Multiselect';

  @override
  String get designSystemDropdownOptionAnalytics => 'Analys';

  @override
  String get designSystemDropdownOptionBackend => 'Backend';

  @override
  String get designSystemDropdownOptionDesign => 'Design';

  @override
  String get designSystemDropdownOptionFrontend => 'Frontend';

  @override
  String get designSystemDropdownOptionGrowth => 'Tillväxt';

  @override
  String get designSystemDropdownOptionMobile => 'Mobil';

  @override
  String get designSystemDropdownOptionQa => 'QA';

  @override
  String get designSystemErrorLabel => 'Fel';

  @override
  String get designSystemFileUploadClickLabel => 'Klicka för att ladda upp';

  @override
  String get designSystemFileUploadCompleteLabel => 'Komplett';

  @override
  String get designSystemFileUploadDefaultLabel => 'Standard';

  @override
  String get designSystemFileUploadDragLabel => 'eller dra och släpp';

  @override
  String get designSystemFileUploadDropZoneSectionTitle => 'Nedsläppszon';

  @override
  String get designSystemFileUploadErrorLabel => 'Fel';

  @override
  String get designSystemFileUploadFailedText => 'Uppladdningen misslyckades';

  @override
  String get designSystemFileUploadHintText =>
      'SVG, PNG, JPG eller GIF (max. 800×400px)';

  @override
  String get designSystemFileUploadHoverLabel => 'Hover';

  @override
  String get designSystemFileUploadItemSectionTitle => 'Filobjekt';

  @override
  String get designSystemFileUploadRetryLabel => 'Omprövning';

  @override
  String get designSystemFileUploadUploadingLabel => 'Uppladdning';

  @override
  String get designSystemFilledLabel => 'Fylld';

  @override
  String get designSystemHeaderApiDocumentationLabel => 'API-dokumentation';

  @override
  String get designSystemHeaderBackActionLabel => 'Tillbaka';

  @override
  String get designSystemHeaderDesktopSectionTitle => 'Skrivbord';

  @override
  String get designSystemHeaderHelpActionLabel => 'Hjälp';

  @override
  String get designSystemHeaderMobileSectionTitle => 'Mobil';

  @override
  String get designSystemHeaderNotificationsActionLabel => 'Notiser';

  @override
  String get designSystemHeaderSearchActionLabel => 'Sökning';

  @override
  String get designSystemHorizontalLabel => 'Horisontellt';

  @override
  String get designSystemHoverLabel => 'Hover';

  @override
  String get designSystemInfoLabel => 'Info';

  @override
  String get designSystemInputErrorSample => 'Detta område är obligatoriskt';

  @override
  String get designSystemInputHelperSample => 'Ange ditt namn';

  @override
  String get designSystemInputHintSample => 'Platshållare...';

  @override
  String get designSystemInputLabelSample => 'Etikett';

  @override
  String get designSystemInputVariantsTitle => 'Ingångsvarianter';

  @override
  String get designSystemInputWithErrorLabel => 'Med fel';

  @override
  String get designSystemInputWithHelperLabel => 'Med hjälptext';

  @override
  String get designSystemInputWithIconsLabel => 'Med ikoner';

  @override
  String get designSystemListItemActivatedLabel => 'Aktiverad';

  @override
  String get designSystemListItemOneLineLabel => 'En rad';

  @override
  String get designSystemListItemSubtitleSample => 'Undertext';

  @override
  String get designSystemListItemTitleSample => 'Titel';

  @override
  String get designSystemListItemTwoLinesLabel => 'Två linjer';

  @override
  String get designSystemListItemVariantsTitle => 'Listvarianter';

  @override
  String get designSystemListItemWithDividerLabel => 'Med avskiljare';

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
  String get designSystemNavigationCollapsedLabel => 'Kollapsade';

  @override
  String get designSystemNavigationDailyFilterSectionTitle => 'Daily Filter';

  @override
  String get designSystemNavigationExpandedLabel => 'Utökad';

  @override
  String get designSystemNavigationFilterByBlockLabel => 'Filter per block';

  @override
  String get designSystemNavigationHikingLabel => 'Vandring';

  @override
  String get designSystemNavigationHolidayLabel => 'Semester';

  @override
  String get designSystemNavigationInsightsLabel => 'Insikter';

  @override
  String get designSystemNavigationLottiTasksLabel => 'Lotti-uppgifter';

  @override
  String get designSystemNavigationMyDailyLabel => 'Min dagliga';

  @override
  String get designSystemNavigationNewLabel => 'Nytt';

  @override
  String get designSystemNavigationPlaceholderLabel => 'Platshållare';

  @override
  String get designSystemNavigationSidebarSectionTitle => 'Sidofältsvarianter';

  @override
  String get designSystemNavigationSubComponentsSectionTitle =>
      'Delkomponenter';

  @override
  String get designSystemNavigationTabBarSectionTitle => 'Tabbar-varianter';

  @override
  String get designSystemPressedLabel => 'Pressad';

  @override
  String get designSystemProgressBarChunkyLabel => 'Chunky';

  @override
  String get designSystemProgressBarLabelAndPercentageLabel =>
      'Etikett + Procent';

  @override
  String get designSystemProgressBarLabelOnlyLabel => 'Endast skivbolag';

  @override
  String get designSystemProgressBarOffLabel => 'Av';

  @override
  String get designSystemProgressBarPercentageOnlyLabel => 'Procent';

  @override
  String get designSystemProgressBarQuestBarLabel => 'Uppdragsfältet';

  @override
  String get designSystemProgressBarQuestLabel => 'Megaprismärke';

  @override
  String get designSystemProgressBarSampleLabel => 'Förloppsmätaretikett';

  @override
  String get designSystemRadioButtonLabel => 'Radioknapp';

  @override
  String get designSystemScrollbarSizesTitle => 'Scrollbar-storlekar';

  @override
  String get designSystemSearchClearLabel => 'Rensa sökning';

  @override
  String get designSystemSearchFilledText => 'Lotti-sökningen';

  @override
  String get designSystemSearchHintLabel => 'Typanvändare';

  @override
  String get designSystemSelectedLabel => 'Utvalda';

  @override
  String get designSystemSizeScaleTitle => 'Storleksskala';

  @override
  String get designSystemSmallLabel => 'Liten';

  @override
  String get designSystemSpinnerPlainLabel => 'Plain';

  @override
  String get designSystemSpinnerSkeletonPulseLabel => 'Puls';

  @override
  String get designSystemSpinnerSkeletonsTitle => 'Skelett';

  @override
  String get designSystemSpinnerSkeletonWaveLabel => 'Wave';

  @override
  String get designSystemSpinnerSpinnersTitle => 'Spinners';

  @override
  String get designSystemSpinnerTrackLabel => 'Med spår';

  @override
  String designSystemSplitButtonDropdownSemantics(String label) {
    return 'Öppna $label-alternativ';
  }

  @override
  String get designSystemStateMatrixTitle => 'Tillståndsmatris';

  @override
  String get designSystemSuccessLabel => 'Framgång';

  @override
  String get designSystemTabBarTitle => 'Tabbar';

  @override
  String get designSystemTabPendingLabel => 'Väntar';

  @override
  String get designSystemTaskListBlockedLabel => 'Blockerad';

  @override
  String get designSystemTaskListDefaultLabel => 'Standard';

  @override
  String get designSystemTaskListHoverLabel => 'Hover';

  @override
  String get designSystemTaskListItemSectionTitle => 'Uppgiftslistvarianter';

  @override
  String get designSystemTaskListOnHoldLabel => 'På vänt';

  @override
  String get designSystemTaskListOpenLabel => 'Öppet';

  @override
  String get designSystemTaskListPressedLabel => 'Pressad';

  @override
  String get designSystemTaskListSampleTime => '08:00–09:30';

  @override
  String get designSystemTaskListSampleTitle => 'Användartestning';

  @override
  String get designSystemTaskListWithDividerLabel => 'Med avskiljare';

  @override
  String get designSystemTextareaErrorSample => 'Detta område är obligatoriskt';

  @override
  String get designSystemTextareaHelperSample => 'Skriv in ditt meddelande här';

  @override
  String get designSystemTextareaHintSample => 'Skriv något...';

  @override
  String get designSystemTextareaLabelSample => 'Etikett';

  @override
  String get designSystemTextareaVariantsTitle => 'Textarea-varianter';

  @override
  String get designSystemTextareaWithCounterLabel => 'Med räknare';

  @override
  String get designSystemTextareaWithErrorLabel => 'Med fel';

  @override
  String get designSystemTextareaWithHelperLabel => 'Med hjälptext';

  @override
  String get designSystemTimePickerFormatsTitle => 'Tidsformat';

  @override
  String get designSystemTimePickerTwelveHourLabel => '12-timmars';

  @override
  String get designSystemTimePickerTwentyFourHourLabel => '24-timmars';

  @override
  String get designSystemTitleOnlyVariantTitle => 'Endast titelvariant';

  @override
  String get designSystemToastDetailsLabel => 'Meddelandedetaljer';

  @override
  String get designSystemToggleLabel => 'Växlingsetikett';

  @override
  String get designSystemTooltipIconMessageSample =>
      'Hjälpsam information om detta område';

  @override
  String get designSystemTooltipIconVariantsTitle => 'Verktygstips-ikon';

  @override
  String get designSystemUndoLabel => 'Ångra';

  @override
  String get designSystemVariantMatrixTitle => 'Variantmatris';

  @override
  String get designSystemVerticalLabel => 'Vertikalt';

  @override
  String get designSystemWarningLabel => 'Varning';

  @override
  String get designSystemWeeklyCalendarLabel => 'Veckokalender';

  @override
  String get designSystemWithLabelLabel => 'Med skivbolag';

  @override
  String get desktopEmptyStateSelectDashboard =>
      'Välj en instrumentpanel för att visa detaljer';

  @override
  String get desktopEmptyStateSelectProject =>
      'Välj ett projekt för att se detaljer';

  @override
  String get desktopEmptyStateSelectTask =>
      'Välj en uppgift för att visa detaljer';

  @override
  String deviceDeletedSuccess(String deviceName) {
    return 'Enheten $deviceName har raderats';
  }

  @override
  String deviceDeleteFailed(String error) {
    return 'Misslyckades med att ta bort enheten: $error';
  }

  @override
  String get doneButton => 'Klart';

  @override
  String get editMenuTitle => 'Redigering';

  @override
  String get editorDiscardChanges => 'Ändringar i kassering';

  @override
  String get editorInsertDivider => 'Insättningsdelare';

  @override
  String get editorMoreFormatting => 'Mer formatering';

  @override
  String get editorPlaceholder => 'Skriv in anteckningarna...';

  @override
  String get embeddingSelectAll => 'Välj alla';

  @override
  String get embeddingUnselectAll => 'Avmarkera alla';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Välj bland färdiga promptmallar';

  @override
  String get enterCategoryName => 'Ange kategorinamn';

  @override
  String get entryActions => 'Åtgärder';

  @override
  String get entryLabelsActionSubtitle =>
      'Tilldela etiketter för att organisera denna post';

  @override
  String get entryLabelsActionTitle => 'Etiketter';

  @override
  String get entryLabelsEditTooltip => 'Redigera etiketter';

  @override
  String get entryLabelsHeaderTitle => 'Etiketter';

  @override
  String get entryLabelsNoLabels => 'Inga etiketter tilldelade';

  @override
  String get entryTypeLabelAiResponse => 'AI-respons';

  @override
  String get entryTypeLabelChecklist => 'Checklista';

  @override
  String get entryTypeLabelChecklistItem => 'Att göra';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Habit';

  @override
  String get entryTypeLabelJournalAudio => 'Ljud';

  @override
  String get entryTypeLabelJournalEntry => 'Text';

  @override
  String get entryTypeLabelJournalEvent => 'Evenemang';

  @override
  String get entryTypeLabelJournalImage => 'Foto';

  @override
  String get entryTypeLabelMeasurementEntry => 'Uppmätt';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Hälsa';

  @override
  String get entryTypeLabelSurveyEntry => 'Undersökning';

  @override
  String get entryTypeLabelTask => 'Uppgift';

  @override
  String get entryTypeLabelWorkoutEntry => 'Träning';

  @override
  String get eventNameLabel => 'Evenemang:';

  @override
  String get eventsAddCoverPhoto => 'Lägg till omslagsfoto';

  @override
  String get eventsAddLabel => 'Lägg till';

  @override
  String get eventsChangeCover => 'Byt omslag';

  @override
  String get eventsDeleteEvent => 'Ta bort händelsen';

  @override
  String get eventsFilterAll => 'Alla';

  @override
  String eventsMetricPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foton',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String eventsMetricTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uppgifter',
      one: '1 uppgift',
    );
    return '$_temp0';
  }

  @override
  String get eventsNewEvent => 'Nytt evenemang';

  @override
  String get eventsPageTitle => 'Evenemang';

  @override
  String get eventsPhotosSection => 'Foton';

  @override
  String get eventsRecapAwaitingContent =>
      'Lägg till ett foto eller en notis så visas sammanfattningen här.';

  @override
  String get eventsRecapUnavailable => 'Kunde inte ladda sammanfattningen.';

  @override
  String get eventsRegenerateSummary => 'Regenereringssammanfattning';

  @override
  String get eventsSearchHint => 'Sökhändelser';

  @override
  String get eventsSectionUpcoming => 'Kommande';

  @override
  String get eventsStatusCancelled => 'Nedlagd';

  @override
  String get eventsStatusCompleted => 'Färdigställd';

  @override
  String get eventsStatusMissed => 'Missade';

  @override
  String get eventsStatusOngoing => 'Pågående';

  @override
  String get eventsStatusPlanned => 'Planerat';

  @override
  String get eventsStatusPostponed => 'Uppskjuten';

  @override
  String get eventsStatusRescheduled => 'Ombokad';

  @override
  String get eventsStatusTentative => 'Försök';

  @override
  String get eventsSummaryTitle => 'Sammanfattning';

  @override
  String get eventsTasksEmpty =>
      'Länka en förberedelse- eller uppföljningsuppgift';

  @override
  String get eventsTasksSection => 'Uppgifter';

  @override
  String get eventsTimelineEmpty =>
      'Lägg till foton, anteckningar eller ett röstmeddelande';

  @override
  String get eventsTimelineSection => 'Tidslinje';

  @override
  String get eventsTitleHint => 'Evenemangstitel';

  @override
  String get eventsVoiceNote => 'Röstmeddelande';

  @override
  String get favoriteLabel => 'Favorit';

  @override
  String get fileMenuNewEllipsis => 'Nytt ...';

  @override
  String get fileMenuNewEntry => 'Ny del';

  @override
  String get fileMenuNewScreenshot => 'Skärmdump';

  @override
  String get fileMenuNewTask => 'Uppgift';

  @override
  String get fileMenuTitle => 'Fil';

  @override
  String get filterSelectionNoMatches => 'Inga matcher';

  @override
  String get geminiThinkingModeHighDescription =>
      'Djupaste resonemang; kan öka latens och kostnad.';

  @override
  String get geminiThinkingModeHighLabel => 'Högt';

  @override
  String get geminiThinkingModeLowDescription =>
      'Låg logik för snabba vardagspromptar.';

  @override
  String get geminiThinkingModeLowLabel => 'Lågt';

  @override
  String get geminiThinkingModeMediumDescription =>
      'Balanserat resonemang för mer noggranna svar.';

  @override
  String get geminiThinkingModeMediumLabel => 'Medium';

  @override
  String get geminiThinkingModeMinimalDescription =>
      'Snabbaste inställning; Gemini kan fortfarande tänka kort på komplexa uppmaningar.';

  @override
  String get geminiThinkingModeMinimalLabel => 'Minimal';

  @override
  String get generateCoverArt => 'Generera omslagskonst';

  @override
  String get generateCoverArtSubtitle => 'Skapa bild från röstbeskrivning';

  @override
  String get goMenuTitle => 'Gå';

  @override
  String get habitActiveFromLabel => 'Startdatum';

  @override
  String get habitActiveSwitchDescription => 'Visas på sidan Habits';

  @override
  String get habitArchivedLabel => 'Arkiverad';

  @override
  String get habitCategoryHint => 'Välj en kategori';

  @override
  String get habitCategoryLabel => 'Kategori';

  @override
  String get habitCloseCompletionLabel => 'Slutförande av nära vanor';

  @override
  String habitCompleteSemanticLabel(String habit) {
    return 'Record $habit';
  }

  @override
  String get habitCompletionStatusCompleted => 'Färdigställd';

  @override
  String get habitCompletionStatusFailed => 'Misslyckades';

  @override
  String get habitCompletionStatusOpen => 'Öppet';

  @override
  String get habitCompletionStatusSkipped => 'Hoppade över';

  @override
  String get habitDashboardHint => 'Välj en instrumentpanel';

  @override
  String get habitDashboardLabel => 'Instrumentpanel (valfritt)';

  @override
  String habitDayStatusSemantic(String habit, String status) {
    return '$habit, $status';
  }

  @override
  String get habitDeleteConfirm => 'JA, RADERA DEN HÄR VANAN';

  @override
  String get habitDeleteQuestion => 'Vill du ta bort den här vanan?';

  @override
  String habitHeatmapDaySemantic(String date, int done, int total) {
    return '$date, $done av $total gjort';
  }

  @override
  String get habitLogOtherDayHint => 'Håll kvar för att logga en annan dag';

  @override
  String get habitNotRecordedLabel => 'Ej inspelat';

  @override
  String get habitPriorityLabel => 'Prioritet';

  @override
  String get habitsAboveGoal => 'På banan';

  @override
  String habitsActiveHabitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktiva vanor',
      one: '1 aktiv vana',
    );
    return '$_temp0';
  }

  @override
  String get habitsAllDoneToday => 'Allt klart idag';

  @override
  String get habitsChartUseDynamicBaseline => 'Använd dynamisk baslinje';

  @override
  String get habitsChartUseZeroBaseline => 'Använd nollbaslinje';

  @override
  String get habitsCompletedHeader => 'Färdigställd';

  @override
  String get habitsCompletionRateTitle => 'Slutförandegrad';

  @override
  String get habitsConsistencyTitle => 'Konsekvens';

  @override
  String habitsDayFailedPercent(int percent) {
    return '$percent% registrerade misslyckanden';
  }

  @override
  String habitsDaySkippedPercent(int percent) {
    return '$percent% hoppades över';
  }

  @override
  String habitsDaySuccessfulPercent(int percent) {
    return '$percent% lyckad';
  }

  @override
  String get habitsDoneTodayLabel => 'Gjort idag';

  @override
  String get habitSectionOptionsTitle => 'Alternativ';

  @override
  String get habitSectionScheduleTitle => 'Schema';

  @override
  String get habitsFilterAll => 'alla';

  @override
  String get habitsFilterCompleted => 'Klart';

  @override
  String get habitsFilterOpenNow => 'två';

  @override
  String get habitsFilterPendingLater => 'Senare';

  @override
  String get habitsGoalLineLabel => 'Mål';

  @override
  String get habitsHeatmapEmpty =>
      'Lägg till en vana för att börja bygga din konsekvens';

  @override
  String get habitsHeatmapLess => 'Mindre';

  @override
  String get habitsHeatmapMore => 'Mer';

  @override
  String get habitShowAlertAtLabel => 'Visa varning på';

  @override
  String get habitShowFromLabel => 'Visa från';

  @override
  String habitsLaggardHint(String habit, int kept, int active) {
    return '$habit — behöll $kept av $active';
  }

  @override
  String get habitsOpenHeader => 'Ska vara klar nu';

  @override
  String get habitsPendingLaterHeader => 'Senare idag';

  @override
  String habitsPointsToGoal(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points poäng till mål',
      one: '1 poäng till mål',
    );
    return '$_temp0';
  }

  @override
  String get habitsRecordButton => 'Rekord';

  @override
  String get habitsRollingAverageLabel => '7-dagars snitt';

  @override
  String get habitsStartStreakToday => 'Starta en svit idag';

  @override
  String habitsStreakLongCount(int count) {
    return '$count på en sju dagar lång svit';
  }

  @override
  String habitsStreakShortCount(int count) {
    return '$count på en tre dagar lång streak';
  }

  @override
  String get habitsTapForBreakdown => 'Tryck en dag för uppdelningen';

  @override
  String habitsToGoCount(int count) {
    return '$count att gå';
  }

  @override
  String habitStreakDaysSemantic(int count) {
    return '$count-dagssvit';
  }

  @override
  String get habitsVsPreviousWeek => 'Mot föregående vecka';

  @override
  String get helpMenuCommandPalette => 'Kommandopalett...';

  @override
  String get helpMenuKeyboardShortcuts => 'Tangentbordsgenvägar...';

  @override
  String get helpMenuTitle => 'Hjälp';

  @override
  String get imageGenerationError => 'Misslyckades med att generera bilden';

  @override
  String get imageGenerationGenerating => 'Genererar bild...';

  @override
  String get imageGenerationProviderRejectedTitle =>
      'Bildleverantören avslog denna begäran';

  @override
  String imageGenerationWithReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' Använder $count referensbilder',
      one: ' Använder 1 referensbild',
      zero: 'Inga referensbilder',
    );
    return '$_temp0';
  }

  @override
  String get imagePromptGenerationCardTitle => 'AI-bildprompt';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Bildprompt kopierad till urklipp';

  @override
  String get imagePromptGenerationCopyButton => 'Kopiera prompt';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Kopiera bildprompten till urklippstavlan';

  @override
  String get imagePromptGenerationExpandTooltip => 'Visa fullständig prompt';

  @override
  String get imagePromptGenerationFullPromptLabel => 'Fullständig bildprompt:';

  @override
  String get images => 'Bilder';

  @override
  String get imageViewerDownloadFailed => 'Kunde inte spara bilden';

  @override
  String get imageViewerDownloadingTooltip => 'Spara bild';

  @override
  String get imageViewerDownloadPermissionDenied =>
      'Fotoåtkomst nekad — aktivera det i Inställningar';

  @override
  String imageViewerDownloadSaved(String fileName) {
    return 'Räddad $fileName';
  }

  @override
  String get imageViewerDownloadSavedToGallery => 'Sparat till foton';

  @override
  String get imageViewerDownloadTooltip => 'Ladda ner bild';

  @override
  String get inactiveLabel => 'Inaktiv';

  @override
  String get inactiveSwitchDescription =>
      'Kan väljas för nya poster när du är på';

  @override
  String get inferenceProfileChooseModelTitle => 'Välj en modell';

  @override
  String get inferenceProfileChooseTitle => 'Välj en inferensprofil';

  @override
  String get inferenceProfileCreateTitle => 'Skapa profil';

  @override
  String get inferenceProfileDescriptionLabel => 'Beskrivning';

  @override
  String get inferenceProfileDesktopOnly => 'Endast för skrivbord';

  @override
  String get inferenceProfileDesktopOnlyDescription =>
      'Endast tillgängligt på stationära plattformar (t.ex. för lokala modeller)';

  @override
  String inferenceProfileDetailLoadError(String error) {
    return 'Kunde inte ladda profil: $error';
  }

  @override
  String get inferenceProfileDetailNotFound => 'Profil ej hittad';

  @override
  String get inferenceProfileEditTitle => 'Redigera profil';

  @override
  String get inferenceProfileImageGeneration => 'Bildgenerering';

  @override
  String get inferenceProfileImageRecognition => 'Bildigenkänning';

  @override
  String get inferenceProfileModelUnavailable =>
      'Modell otillgänglig — dess leverantör kan ha tagits bort';

  @override
  String get inferenceProfileNameLabel => 'Profilnamn';

  @override
  String get inferenceProfileNameRequired => 'Ett profilnamn krävs';

  @override
  String get inferenceProfilePinnedHostHelper =>
      'När den är inställd kör endast denna enhet automatiskt inferens för synkade ljudposter som använder denna profil.';

  @override
  String get inferenceProfilePinnedHostLabel => 'Fastnålad enhet';

  @override
  String get inferenceProfilePinnedHostNoEligibleNodes =>
      'Inga kända enheter annonserar vilka leverantörer denna profil använder. Öppna Sync-nodinställningarna på målenheten.';

  @override
  String get inferenceProfilePinnedHostNoneHelper =>
      'Synkroniserade ljudposter transkriberas inte automatiskt när ingen enhet är fastnålad.';

  @override
  String get inferenceProfilePinnedHostNoneLabel =>
      'Inte fastnade (ingen auto-trigger)';

  @override
  String get inferenceProfilePinnedHostThisDeviceSuffix => ' (denna apparat)';

  @override
  String get inferenceProfileSaveButton => 'Spara';

  @override
  String get inferenceProfileSelectModel => 'Välj en modell...';

  @override
  String get inferenceProfileSelectProfile => 'Välj en profil...';

  @override
  String get inferenceProfilesEmpty => 'Inga inferensprofiler än';

  @override
  String inferenceProfileSkillModelRequired(String slotName) {
    return 'Kräver att $slotName-modellen sätts';
  }

  @override
  String get inferenceProfileSkillsSection => 'Automatiserade färdigheter';

  @override
  String inferenceProfileSkillUsesModel(String slotName) {
    return 'Använder $slotName-modellen';
  }

  @override
  String get inferenceProfilesTitle => 'Inferensprofiler';

  @override
  String get inferenceProfileThinking => 'Tänkande';

  @override
  String get inferenceProfileThinkingHighEnd => 'Tänkande (avancerat)';

  @override
  String get inferenceProfileThinkingRequired => 'En tänkande modell krävs';

  @override
  String get inferenceProfileTranscription => 'Transkription';

  @override
  String get inferenceProfileUnavailable => 'Inferensprofil ej tillgänglig';

  @override
  String get inputDataTypeAudioFilesDescription =>
      'Använd ljudfiler som indata';

  @override
  String get inputDataTypeAudioFilesName => 'Ljudfiler';

  @override
  String get inputDataTypeImagesDescription => 'Använd bilder som indata';

  @override
  String get inputDataTypeImagesName => 'Bilder';

  @override
  String get inputDataTypeTaskDescription =>
      'Använd den aktuella uppgiften som indata';

  @override
  String get inputDataTypeTaskName => 'Uppgift';

  @override
  String get inputDataTypeTasksListDescription =>
      'Använd en lista med uppgifter som indata';

  @override
  String get inputDataTypeTasksListName => 'Uppgiftslista';

  @override
  String get insightsChartCompareCaption =>
      'Denna period jämfört med den tidigare';

  @override
  String get insightsChartCompareCaptionPartial =>
      'Denna period hittills jämfört med den tidigare';

  @override
  String get insightsChartCompareHint => 'Jämförelse visas i tabellen nedan';

  @override
  String get insightsChartCumulativeCaption => 'Löpande total över räckvidden';

  @override
  String get insightsChartCumulativeShort =>
      'Inte tillräckligt många dagar än för en löpande total';

  @override
  String get insightsChartDailyCaption => 'Tid per dag';

  @override
  String get insightsChartHourlyCaption => 'Tid per timme';

  @override
  String get insightsChartPerDay => 'Per dag';

  @override
  String get insightsChartPerHour => 'Per timme';

  @override
  String get insightsChartPerWeek => 'Per vecka';

  @override
  String get insightsChartRunningTotal => 'Löpande totalantal';

  @override
  String get insightsChartTitle => 'Tid per kategori';

  @override
  String get insightsChartWeeklyCaption => 'Tid per vecka';

  @override
  String get insightsChooseFocusCategories => 'Välj fokuskategorier';

  @override
  String get insightsCompare => 'Jämför';

  @override
  String get insightsCompareFullPeriod => 'Fullständig period';

  @override
  String get insightsComparePrevious => 'Tidigare';

  @override
  String get insightsCompareSameDays => 'samma dagar';

  @override
  String get insightsCompareTooltip => 'Jämför med föregående period';

  @override
  String get insightsCompareVs => 'vs';

  @override
  String get insightsDeletedCategory => 'Borttagen kategori';

  @override
  String get insightsDeltaNew => 'Ny';

  @override
  String get insightsEmptyBody =>
      'Tiden du spårar poster och uppgifter kommer att visas här.';

  @override
  String get insightsEmptyChart => 'Inga data i detta intervall';

  @override
  String get insightsEmptyPreviousPeriod => 'Visa föregående period';

  @override
  String get insightsEmptyShowYear => 'Se i år';

  @override
  String get insightsEmptyTitle => 'Ingen spårad tid i detta intervall';

  @override
  String get insightsFocusCategoriesEmpty => 'Inga aktiva kategorier än.';

  @override
  String get insightsFocusCategoriesTitle => 'Fokuskategorier';

  @override
  String get insightsKpiFocus => 'FOKUS';

  @override
  String get insightsKpiFocusHelp => 'Kategorier du tittar på';

  @override
  String get insightsKpiOther => 'ÖVRIGT';

  @override
  String get insightsKpiOtherHelp => 'Allt annat';

  @override
  String insightsKpiTopCategory(String category, String share) {
    return 'De flesta på $category · $share';
  }

  @override
  String get insightsKpiTotal => 'TOTALT';

  @override
  String get insightsLoadError => 'Kunde inte ladda tidsdata';

  @override
  String get insightsOtherCategories => 'Övrigt';

  @override
  String get insightsPartialWeek => 'Delvecka';

  @override
  String get insightsPeriodDay => 'Dag';

  @override
  String get insightsPeriodJump => 'Hoppa till ett datum';

  @override
  String get insightsPeriodMonth => 'Månad';

  @override
  String get insightsPeriodNext => 'Nästa period';

  @override
  String get insightsPeriodPrevious => 'Föregående period';

  @override
  String get insightsPeriodQuarter => 'Kvart';

  @override
  String get insightsPeriodToDateSuffix => 'Hittills';

  @override
  String get insightsPeriodWeek => 'Vecka';

  @override
  String get insightsPeriodYear => 'År';

  @override
  String get insightsRangeMonthToDate => 'Den här månaden hittills';

  @override
  String get insightsRangeMtd => 'Den här månaden';

  @override
  String get insightsRangeYearToDate => 'I år hittills';

  @override
  String get insightsRangeYtd => 'I år';

  @override
  String get insightsRefreshError =>
      'Kunde inte uppdatera — visar den senaste laddade datan';

  @override
  String get insightsTableAvgPerDay => 'GENOMSNITT/DAG';

  @override
  String get insightsTableCategory => 'KATEGORI';

  @override
  String get insightsTableCompareNote =>
      'Förändring jämfört med föregående period';

  @override
  String get insightsTableCurrent => 'NUVARANDE';

  @override
  String get insightsTableDelta => 'Förändring';

  @override
  String get insightsTablePrevious => 'TIDIGARE';

  @override
  String get insightsTableShare => 'DELA';

  @override
  String get insightsTableTotal => 'TOTALT';

  @override
  String get insightsTimeAnalysisTitle => 'Tidsanalys';

  @override
  String get insightsUncategorized => 'Okategoriserad';

  @override
  String get journalCopyImageLabel => 'Kopiera bilden';

  @override
  String get journalDateFromLabel => 'Datum från:';

  @override
  String get journalDateInvalid => 'Ogiltigt datumintervall';

  @override
  String get journalDateLabel => 'Datum';

  @override
  String get journalDateNowButton => 'Nu';

  @override
  String get journalDateSaveButton => 'Spara';

  @override
  String get journalDateTimeRangeTitle => 'Datum och tid';

  @override
  String get journalDateToLabel => 'Datum till:';

  @override
  String get journalDeleteConfirm => 'JA, TA BORT DENNA POST';

  @override
  String get journalDeleteHint => 'Ta bort posten';

  @override
  String get journalDeleteQuestion => 'Vill du ta bort denna journalpost?';

  @override
  String get journalDurationLabel => 'Varaktighet';

  @override
  String get journalEndDateLabel => 'Slutdatum';

  @override
  String get journalEndsAnotherDayHint => 'Välj ett separat slutdatum';

  @override
  String get journalEndsAnotherDayLabel => 'Slutar på en annan dag';

  @override
  String get journalEndTimeLabel => 'Sluttid';

  @override
  String get journalEntryExpandLabel => 'Expandera post';

  @override
  String get journalFilterEntryTypesTitle => 'Inträdetyper';

  @override
  String get journalFilterFlagged => 'Flaggad';

  @override
  String get journalFilterPrivate => 'Privat';

  @override
  String get journalFilterShowTitle => 'Show';

  @override
  String get journalFilterStarred => 'Medverkad';

  @override
  String get journalFilterTitle => 'Filterjournal';

  @override
  String get journalHideLinkHint => 'Dölj länk';

  @override
  String get journalHideMapHint => 'Göm kartan';

  @override
  String get journalLinkedEntriesActivityFilterAudio => 'Ljud';

  @override
  String get journalLinkedEntriesActivityFilterCode => 'Kod';

  @override
  String get journalLinkedEntriesActivityFilterImages => 'Bilder';

  @override
  String get journalLinkedEntriesActivityFilterTimer => 'Öppettider';

  @override
  String get journalLinkedEntriesFilterModalTitle => 'Filter & Sort';

  @override
  String get journalLinkedEntriesShowFlaggedOnly =>
      'Visa endast flaggade bidrag';

  @override
  String get journalLinkedEntriesShowHidden => 'Visa dolda poster';

  @override
  String get journalLinkedEntriesSortLabel => 'Sortera efter';

  @override
  String get journalLinkedEntriesSortNewestFirst => 'Nyaste första gången';

  @override
  String get journalLinkedEntriesSortOldestFirst => 'Äldsta första';

  @override
  String get journalLinkedFromLabel => 'Länkad från:';

  @override
  String get journalLinkFromHint => 'Länk från';

  @override
  String get journalLinkToHint => 'Länk till';

  @override
  String journalOvernightNextDay(String date) {
    return 'Slutar $date (nästa dag)';
  }

  @override
  String get journalPrivateTooltip => 'Endast privat';

  @override
  String get journalSearchHint => 'Sökjournal...';

  @override
  String get journalSetEndDateTimeNowSemantic =>
      'Sätt slutdatum och tid till nu';

  @override
  String get journalSetStartDateTimeNowSemantic =>
      'Sätt startdatum och tid till nu';

  @override
  String get journalShareHint => 'Dela';

  @override
  String get journalShowLinkHint => 'Showlänk';

  @override
  String get journalShowMapHint => 'Visa karta';

  @override
  String get journalStartDateLabel => 'Startdatum';

  @override
  String get journalStartTimeLabel => 'Starttid';

  @override
  String get journalTodayButton => 'Idag';

  @override
  String get journalToggleFlaggedTitle => 'Flaggad';

  @override
  String get journalTogglePrivateTitle => 'Privat';

  @override
  String get journalToggleStarredTitle => 'Favorit';

  @override
  String get journalUnlinkConfirm => 'JA, KOPPLA BORT INTRÄDET';

  @override
  String get journalUnlinkHint => 'Avlänka';

  @override
  String get journalUnlinkQuestion =>
      'Är du säker på att du vill koppla bort detta inlägg?';

  @override
  String get keyboardCommandActivate => 'Aktivera fokuserat föremål';

  @override
  String get keyboardCommandCategoryCreation => 'Skapandet';

  @override
  String get keyboardCommandCategoryEditing => 'Redigering';

  @override
  String get keyboardCommandCategoryGeneral => 'Allmänt';

  @override
  String get keyboardCommandCategoryListsAndControls => 'Listor och kontroller';

  @override
  String get keyboardCommandCategoryNavigation => 'Navigering';

  @override
  String get keyboardCommandCategoryView => 'Vy';

  @override
  String get keyboardCommandCreateInContext => 'Skapa i aktuell vy';

  @override
  String get keyboardCommandFocusSearch => 'Fokussökning';

  @override
  String get keyboardCommandMoveDown => 'Flytta fokuserat föremål nedåt';

  @override
  String get keyboardCommandMoveUp => 'Flytta fokuserat föremål uppåt';

  @override
  String keyboardCommandNavigate(String destination) {
    return 'Gå till $destination';
  }

  @override
  String get keyboardCommandNextRegion => 'Fokusera nästa ruta';

  @override
  String get keyboardCommandOpenPalette => 'Öppna kommandopalett';

  @override
  String get keyboardCommandPageDown => 'Flytta ner en sida';

  @override
  String get keyboardCommandPageUp => 'Flytta fram en sida';

  @override
  String get keyboardCommandPreviousRegion => 'Fokusera föregående panel';

  @override
  String get keyboardCommandRefresh => 'Uppdatera aktuell vy';

  @override
  String get keyboardCommandRename => 'Byt namn på fokuserad artikel';

  @override
  String get keyboardCommandSelectFirst => 'Välj första objektet';

  @override
  String get keyboardCommandSelectLast => 'Välj sista punkten';

  @override
  String get keyboardCommandSelectNext => 'Välj nästa punkt';

  @override
  String get keyboardCommandSelectPrevious => 'Välj föregående punkt';

  @override
  String get keyboardCommandToggle => 'Växla fokuserat föremål';

  @override
  String get keyboardKeyAlt => 'Gammal';

  @override
  String get keyboardKeyArrowDown => 'Nedåtpil';

  @override
  String get keyboardKeyArrowLeft => 'Vänsterpil';

  @override
  String get keyboardKeyArrowRight => 'Högerpil';

  @override
  String get keyboardKeyArrowUp => 'Uppåtpil';

  @override
  String get keyboardKeyControl => 'Ctrl';

  @override
  String get keyboardKeyDelete => 'Radera';

  @override
  String get keyboardKeyEnd => 'Slut';

  @override
  String get keyboardKeyEnter => 'Kom in';

  @override
  String get keyboardKeyEscape => 'Flykt';

  @override
  String get keyboardKeyHome => 'Hem';

  @override
  String get keyboardKeyMinus => 'Minus';

  @override
  String get keyboardKeyOr => 'eller';

  @override
  String get keyboardKeyPageDown => 'Sida ner';

  @override
  String get keyboardKeyPageUp => 'Page Up';

  @override
  String get keyboardKeyPlus => 'Mer';

  @override
  String get keyboardKeyShift => 'Skift';

  @override
  String get keyboardKeySpace => 'Rymden';

  @override
  String get keyboardResizeDividerLabel => 'Storleksjustera rutorna';

  @override
  String keyboardResizeDividerValue(int value, int min, int max) {
    return 'Panelstorlek: $value pixlar. Tillåtet intervall: $min–$max pixlar.';
  }

  @override
  String get keyboardShortcutsNoResults => 'Inga genvägar matchar din sökning';

  @override
  String get keyboardShortcutsSearchHint => 'Sökgenvägar...';

  @override
  String get keyboardShortcutsSubtitle =>
      'Varje skrivbordskommando och dess nuvarande tangentbordskombination.';

  @override
  String get keyboardShortcutsTitle => 'Tangentbordsgenvägar';

  @override
  String knowledgeGraphAgeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagar sedan',
      one: '1 dag sedan',
    );
    return '$_temp0';
  }

  @override
  String knowledgeGraphAgeMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count månader sedan',
      one: '1 månad sedan',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeToday => 'Idag';

  @override
  String knowledgeGraphAgeWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veckor sedan',
      one: ' 1 vecka sedan',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeYesterday => 'Igår';

  @override
  String get knowledgeGraphBack => 'Tillbaka';

  @override
  String get knowledgeGraphCloseDetails => 'Närbild';

  @override
  String get knowledgeGraphEmpty => 'Inga länkar att utforska än';

  @override
  String get knowledgeGraphEntryLoadError => 'Kunde inte ladda denna post';

  @override
  String get knowledgeGraphEntryNotFound => 'Inlägg ej hittat';

  @override
  String get knowledgeGraphError => 'Kunde inte ladda kunskapsgrafen';

  @override
  String knowledgeGraphLinkedSection(int count) {
    return 'LÄNKAD · $count';
  }

  @override
  String get knowledgeGraphMoreLinks => 'fler länkar';

  @override
  String knowledgeGraphNodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count noder',
      one: '1 nod',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphNodeTypeAiSummary => 'AI-sammanfattning';

  @override
  String get knowledgeGraphNodeTypeAudioNote => 'Ljudnot';

  @override
  String get knowledgeGraphNodeTypeChecklist => 'Checklista';

  @override
  String get knowledgeGraphNodeTypeChecklistItem => 'Checklista';

  @override
  String get knowledgeGraphNodeTypeNote => 'Not';

  @override
  String get knowledgeGraphNodeTypePhoto => 'Foto';

  @override
  String get knowledgeGraphNodeTypeProject => 'Projekt';

  @override
  String get knowledgeGraphNodeTypeRating => 'Betyg';

  @override
  String get knowledgeGraphNodeTypeTask => 'Uppgift';

  @override
  String get knowledgeGraphOpenDetails => 'Öppna detaljer';

  @override
  String get knowledgeGraphRecenter => 'Nyare';

  @override
  String get knowledgeGraphRecentToOlder => 'nyligen → äldre';

  @override
  String get knowledgeGraphRelationAiSource => 'AI-källa';

  @override
  String get knowledgeGraphRelationChecklist => 'Checklista';

  @override
  String get knowledgeGraphRelationInProject => 'I projektet';

  @override
  String get knowledgeGraphRelationLinkedTask => 'Länkad uppgift';

  @override
  String get knowledgeGraphRelationNoteLog => 'Anteckning / Logg';

  @override
  String get knowledgeGraphRelationRating => 'Betyg';

  @override
  String get knowledgeGraphSummarySection => 'SAMMANFATTNING';

  @override
  String get knowledgeGraphTitle => 'Kunskapsgraf';

  @override
  String get knowledgeGraphTooltip => 'Utforska länkar';

  @override
  String knowledgeGraphWalkHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count noder',
      one: '1 nod',
    );
    return 'Tryck på en nod för att gå · $_temp0';
  }

  @override
  String get linkedFromCaption => 'från';

  @override
  String get linkedTaskImageBadge => 'Från länkad uppgift';

  @override
  String get linkedTasksMenuTooltip => 'Länkade uppgifter alternativ';

  @override
  String get linkedTasksTitle => 'Länkade uppgifter';

  @override
  String get linkedToCaption => 'att';

  @override
  String get linkExistingTask => 'Länka befintlig uppgift...';

  @override
  String get loggingDomainAgentRuntime => 'Agentens runtime';

  @override
  String get loggingDomainAgentWorkflow => 'Agentens arbetsflöde';

  @override
  String get loggingDomainAi => 'AI';

  @override
  String get loggingDomainCalendar => 'Kalender och tid';

  @override
  String get loggingDomainChat => 'Chatt';

  @override
  String get loggingDomainDailyOs => 'Daily OS';

  @override
  String get loggingDomainDatabase => 'Databas';

  @override
  String get loggingDomainGeneral => 'Allmänt';

  @override
  String get loggingDomainHabits => 'Habiter';

  @override
  String get loggingDomainHealth => 'Hälsa';

  @override
  String get loggingDomainLabels => 'Etiketter';

  @override
  String get loggingDomainLocation => 'Läge';

  @override
  String get loggingDomainNavigation => 'Navigering';

  @override
  String get loggingDomainNotifications => 'Notiser';

  @override
  String get loggingDomainOnboarding => 'Onboarding och FTUE';

  @override
  String get loggingDomainPersistence => 'Beständighet';

  @override
  String get loggingDomainRatings => 'Tittarsiffror';

  @override
  String get loggingDomainScreenshots => 'Skärmdumpar';

  @override
  String get loggingDomainSettings => 'Miljöer';

  @override
  String get loggingDomainSpeech => 'Tal och ljud';

  @override
  String get loggingDomainSync => 'Synk';

  @override
  String get loggingDomainTasks => 'Uppgifter och checklistor';

  @override
  String get loggingDomainTheming => 'Tematisering';

  @override
  String get loggingDomainWhatsNew => 'Vad är nytt';

  @override
  String get maintenanceDeleteAgentDb => 'Databas för borttagningsagenter';

  @override
  String get maintenanceDeleteAgentDbDescription =>
      'Ta bort agentdatabasen och starta om appen';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'JA, TA BORT DATABASEN';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Är du säker på att du vill radera $databaseName-databasen?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Ta bort editordatabasen';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Ta bort editor drafts-databasen';

  @override
  String get maintenanceDeleteSyncDb => 'Ta bort synkdatabasen';

  @override
  String get maintenanceDeleteSyncDbDescription => 'Ta bort synkdatabas';

  @override
  String get maintenanceGenerateEmbeddings => 'Generera inbäddningar';

  @override
  String get maintenanceGenerateEmbeddingsConfirm => 'JA, GENERERA';

  @override
  String get maintenanceGenerateEmbeddingsDescription =>
      'Generera inbäddningar för poster i utvalda kategorier';

  @override
  String get maintenanceGenerateEmbeddingsMessage =>
      'Välj kategorier att generera embeddings för.';

  @override
  String maintenanceGenerateEmbeddingsProgress(
    int processed,
    int total,
    int embedded,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$processed / $total poster ($embedded inbäddade)',
      one: '$processed / $total post ($embedded inbäddad)',
    );
    return '$_temp0';
  }

  @override
  String get maintenancePopulatePhaseAgentEntities => 'Bearbetningsagenter...';

  @override
  String get maintenancePopulatePhaseAgentLinks =>
      'Kopplingar till behandlingsagent...';

  @override
  String get maintenancePopulatePhaseJournal =>
      'Bearbetar journalanteckningar...';

  @override
  String get maintenancePopulatePhaseLinks => 'Behandlar inmatningslänkar...';

  @override
  String get maintenancePopulateSequenceLog => 'Fyll i synksekvenslogg';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count indexerade poster';
  }

  @override
  String get maintenancePopulateSequenceLogConfirm => 'JA, BEFOLKA';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Indexera befintliga poster för backfill-stöd';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'Detta skannar alla journalposter och lägger till dem i synkroniseringssekvensloggen. Detta möjliggör backfill-svar för poster skapade innan denna funktion lades till.';

  @override
  String get maintenancePurgeDeleted => 'Rensa bort raderade objekt';

  @override
  String get maintenancePurgeDeletedConfirm => 'Ja, rensa ut allt';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Rensa alla raderade föremål permanent';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Är du säker på att du vill rensa alla raderade objekt? Denna åtgärd kan inte göras ogjort.';

  @override
  String get maintenancePurgeSentOutbox => 'Rensa gamla ut-ut-varor';

  @override
  String get maintenancePurgeSentOutboxConfirm => 'JA, UTRENSNING';

  @override
  String get maintenancePurgeSentOutboxDescription =>
      'Radera rader som skickats ut käll äldre än 7 dagar och hämta disken';

  @override
  String get maintenancePurgeSentOutboxQuestion =>
      'Purge skickade ut utkorgsartiklar äldre än 7 dagar? Detta raderar redan skickade rader i bitar och kör VACUUM för att återta disken. Väntande och felposter sparas.';

  @override
  String get maintenanceRecreateFts5 => 'Återskapa fulltextindex';

  @override
  String get maintenanceRecreateFts5Confirm => 'JA, ÅTERSKAPA INDEX';

  @override
  String get maintenanceRecreateFts5Description =>
      'Återskapa fulltext-sökindex';

  @override
  String get maintenanceRecreateFts5Message =>
      'Är du säker på att du vill återskapa fulltextindexet? Detta kan ta lite tid.';

  @override
  String get maintenanceReSync => 'Synkronisera om meddelanden';

  @override
  String get maintenanceReSyncAgentEntities => 'Agententiteter';

  @override
  String get maintenanceReSyncDescription =>
      'Synkronisera om meddelanden från servern';

  @override
  String get maintenanceReSyncEntityTypes => 'Enhetstyper';

  @override
  String get maintenanceReSyncJournalEntities => 'Tidskriftsenheter';

  @override
  String get maintenanceReSyncSelectAtLeastOne => 'Välj minst en enhetstyp';

  @override
  String get maintenanceReSyncStart => 'Start';

  @override
  String get maintenanceSyncDefinitions =>
      'Synkronisera mätbara saker, instrumentpaneler, vanor, kategorier, AI-inställningar';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Synkronisera mätbara saker, instrumentpaneler, vanor, kategorier och AI-inställningar';

  @override
  String get manageLinks => 'Hantera länkar...';

  @override
  String get matrixStatsCatchupBatches => 'Upphämtande omgångar';

  @override
  String get matrixStatsCircuitOpens => 'Banan öppnas';

  @override
  String get matrixStatsConflicts => 'Konflikter';

  @override
  String get matrixStatsCopyDiagnostics => 'Kopiera diagnostik';

  @override
  String get matrixStatsCopyDiagnosticsTooltip =>
      'Kopiera synkdiagnostik till urklippet';

  @override
  String get matrixStatsDbApplied => 'DB Applied';

  @override
  String get matrixStatsDbApply => 'DB Apply';

  @override
  String get matrixStatsDbIgnoredVectorClock => 'DB ignorerad (VectorClock)';

  @override
  String get matrixStatsDbMissingBase => 'DB saknar bas';

  @override
  String matrixStatsDroppedByType(Object type) {
    return 'Tappad ($type)';
  }

  @override
  String get matrixStatsEntryLinkNoops => 'EntryLink No-ops';

  @override
  String get matrixStatsFailures => 'Misslyckanden';

  @override
  String get matrixStatsFlushes => 'Flushes';

  @override
  String get matrixStatsForceRescan => 'Force Omscan';

  @override
  String get matrixStatsForceRescanTooltip => 'Tvinga om och ta igen nu';

  @override
  String get matrixStatsLegend => 'Legend';

  @override
  String get matrixStatsLegendTooltip =>
      'Legend:\n• bearbetad. <type> = bearbetade synkmeddelanden efter nyttolasttyp\n• droppadeByType. <type> = per typ droppar efter omförsök eller äldre meddelande ignorerar\n• dbApplied = databasrader skrivna\n• dbIgnoredByVectorClock = äldre eller identisk inkommande data ignoreras av databasen\n• conflictsCreated = samtidiga vektorklockor loggade\n• dbMissingBase = hoppas över medan man väntar på en saknad beroende eller basrad\n• staleAttachmentPurges = cachade föråldrade deskriptorer rensade före uppdatering';

  @override
  String get matrixStatsProcessed => 'Bearbetad';

  @override
  String matrixStatsProcessedByType(Object type) {
    return 'Behandlad ($type)';
  }

  @override
  String get matrixStatsRefresh => 'Uppdatera';

  @override
  String get matrixStatsReliability => 'Tillförlitlighet';

  @override
  String get matrixStatsRetriesScheduled => 'Omprövningar schemalagda';

  @override
  String get matrixStatsRetryNow => 'Försök igen nu';

  @override
  String get matrixStatsRetryNowTooltip =>
      'Försök igen väntade misslyckanden nu';

  @override
  String get matrixStatsSignalLatencyLast => 'Signallatens (senaste ms)';

  @override
  String get matrixStatsSignalLatencyMax => 'Signallatens (max ms)';

  @override
  String get matrixStatsSignalLatencyMin => 'Signallatens (min ms)';

  @override
  String get matrixStatsSignals => 'Signaler';

  @override
  String get matrixStatsSignalsClientStream => 'Signaler (klientström)';

  @override
  String get matrixStatsSignalsConnectivity => 'Signaler (anslutning)';

  @override
  String get matrixStatsSignalsTimelineCallbacks =>
      'Signaler (tidslinje-återkopplingar)';

  @override
  String get matrixStatsSkipped => 'Hoppade över';

  @override
  String get matrixStatsSkippedRetryCap => 'Hoppade över (omprövad kap)';

  @override
  String get matrixStatsStaleAttachmentPurges =>
      'Uttjukna anknytningsutrensningar';

  @override
  String get matrixStatsThroughput => 'Genomströmning';

  @override
  String get matrixStatsTopKpis => 'Topp-KPI:er';

  @override
  String get measurableDeleteConfirm => 'JA, RADERA DETTA MÄTBARA';

  @override
  String get measurableDeleteQuestion =>
      'Vill du ta bort denna mätbara datatyp?';

  @override
  String get measurableNotFound => 'Mätbar inte hittad';

  @override
  String get measurementCommentHint => 'Lägg till en anteckning (valfritt)';

  @override
  String get measurementCommentSemantic => 'Kommentar, valfritt';

  @override
  String measurementObservedAtChangeSemantic(String dateTime) {
    return 'Observerad vid $dateTime. Ändra datum och tid.';
  }

  @override
  String get measurementQuickAddLabel => 'Snabblogg';

  @override
  String measurementQuickLogSemantic(String value) {
    return 'Logga $value omedelbart';
  }

  @override
  String get measurementSaveError =>
      'Kunde inte spara den här mätningen. Försök igen.';

  @override
  String get measurementSetObservedAtNowSemantic =>
      'Sätt datum och tid för observerat till nu';

  @override
  String get measurementTimeLabel => 'Tid';

  @override
  String measurementValueSemantic(String measurable) {
    return 'Värde för $measurable';
  }

  @override
  String get mediaShowInFileExplorerAction => 'Visa i Filutforskaren';

  @override
  String get mediaShowInFilesAction => 'Visa i filer';

  @override
  String get mediaShowInFinderAction => 'Visa i Finder';

  @override
  String get modalityAudioDescription => 'Ljudbearbetningsmöjligheter';

  @override
  String get modalityAudioName => 'Ljud';

  @override
  String get modalityImageDescription => 'Bildbehandlingsmöjligheter';

  @override
  String get modalityImageName => 'Bild';

  @override
  String get modalityTextDescription => 'Textbaserat innehåll och bearbetning';

  @override
  String get modalityTextName => 'Text';

  @override
  String get modelAddPageTitle => 'Lägg till modell';

  @override
  String get modelEditBackTooltip => 'Tillbaka';

  @override
  String get modelEditDescriptionHint => 'Beskriv denna modell';

  @override
  String get modelEditDescriptionLabel => 'Beskrivning';

  @override
  String get modelEditDisplayNameHint => 'Ett vänligt namn för denna modell';

  @override
  String get modelEditDisplayNameLabel => 'Visningsnamn';

  @override
  String get modelEditFunctionCallingDescription =>
      'Denna modell stödjer funktion och verktygsanrop.';

  @override
  String get modelEditFunctionCallingLabel => 'Funktionsanrop';

  @override
  String get modelEditGeminiThinkingModeLabel => 'Gemini-tänkeläge';

  @override
  String get modelEditInputModalitiesHint => 'Välj ingångstyper';

  @override
  String get modelEditInputModalitiesLabel => 'Inmatningsmodaliteter';

  @override
  String get modelEditLoadError =>
      'Misslyckades med att ladda modellkonfigurationen';

  @override
  String get modelEditMaxTokensHint => 'Valfritt — lämna tomt för obegränsat';

  @override
  String get modelEditMaxTokensLabel => 'Max-fullbordande-tokens';

  @override
  String get modelEditModalityNoneSelected => 'Ingen vald';

  @override
  String get modelEditOutputModalitiesHint => 'Välj utdatatyper';

  @override
  String get modelEditOutputModalitiesLabel => 'Utdatamodaliteter';

  @override
  String get modelEditPageTitle => 'Redigera modell';

  @override
  String get modelEditProviderHint => 'Välj en leverantör';

  @override
  String get modelEditProviderLabel => 'Leverantör';

  @override
  String get modelEditProviderModelIdHint => 'T.ex. GPT-4-Turbo';

  @override
  String get modelEditProviderModelIdLabel => 'Leverantörsmodell-ID';

  @override
  String get modelEditReasoningDescription =>
      'Denna modell använder utökat tänkande / tankekedja.';

  @override
  String get modelEditReasoningLabel => 'Resonemangsmodell';

  @override
  String get modelEditSaveButton => 'Spara';

  @override
  String get modelEditSectionCapabilities => 'Kapabiliteter';

  @override
  String get modelEditSectionIdentity => 'Identitet';

  @override
  String modelManagementSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'er',
      one: '',
    );
    return '$count modell$_temp0 vald';
  }

  @override
  String get multiSelectAddButton => 'Lägg till';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Lägg till ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'Inga föremål hittades';

  @override
  String get navSidebarManualBrowserHint => 'Öppnas i din webbläsare';

  @override
  String get navSidebarManualLabel => 'Manuell';

  @override
  String navTabMoreSemanticsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mer, $count ytterligare destinationer',
      one: 'Mer, 1 ytterligare destination',
    );
    return '$_temp0';
  }

  @override
  String get navTabTitleCalendar => 'DailyOS';

  @override
  String get navTabTitleEvents => 'Evenemang';

  @override
  String get navTabTitleHabits => 'Habiter';

  @override
  String get navTabTitleInsights => 'Insikter';

  @override
  String get navTabTitleJournal => 'Loggbok';

  @override
  String get navTabTitleMore => 'Mer';

  @override
  String get navTabTitleProjects => 'Projekt';

  @override
  String get navTabTitleSettings => 'Miljöer';

  @override
  String get navTabTitleTasks => 'Uppgifter';

  @override
  String nestedAiResponsesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count AI-respons$_temp0';
  }

  @override
  String get noDefaultLanguage => 'Inget standardspråk';

  @override
  String get noTasksFound => 'Inga uppgifter hittades';

  @override
  String get noTasksToLink => 'Inga uppgifter tillgängliga att länka';

  @override
  String get notificationBellEmptySemantics =>
      'Notiser, inga olästa aviseringar';

  @override
  String get notificationBellTooltip => 'Notiser';

  @override
  String notificationBellUnseenSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'varningar',
      one: 'varning',
    );
    return 'Notiser, $count olästa $_temp0';
  }

  @override
  String get notificationInboxDismiss => 'Avvisande meddelande';

  @override
  String get notificationInboxEmpty => 'Du är helt ikapp.';

  @override
  String get notificationInboxError => 'Kunde inte ladda notiser.';

  @override
  String get notificationInboxTitle => 'Notiser';

  @override
  String get notificationSuggestionAttentionBodyFallback =>
      'Öppna uppgiften för att granska.';

  @override
  String notificationSuggestionAttentionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count förslag behöver din uppmärksamhet',
      one: '1 förslag behöver din uppmärksamhet',
    );
    return '$_temp0';
  }

  @override
  String get onboardingApiKeyConnect => 'Koppla upp';

  @override
  String get onboardingApiKeyConnecting => 'Kopplar...';

  @override
  String get onboardingApiKeyEnterKeyHint =>
      'Ange en giltig nyckel för att fortsätta.';

  @override
  String get onboardingApiKeyError =>
      'Kunde inte få kontakt. Kolla din nyckel och försök igen.';

  @override
  String get onboardingApiKeyField => 'API-nyckel';

  @override
  String get onboardingApiKeyGetKeyAt => 'Skaffa en nyckel på';

  @override
  String get onboardingApiKeyHide => 'Göm nyckeln';

  @override
  String get onboardingApiKeyInvalid =>
      'Den nyckeln avvisades. Dubbelkolla och klistra in den igen.';

  @override
  String get onboardingApiKeyLocalNote =>
      'Körs på din enhet — ingen nyckel behövs.';

  @override
  String get onboardingApiKeyNoKeyHelp =>
      'Ny här? Logga in, skapa en API-nyckel, klistra in den – gratis att starta.';

  @override
  String get onboardingApiKeyReveal => 'Show-nyckel';

  @override
  String get onboardingApiKeyTitle => 'Klistra in din API-nyckel';

  @override
  String onboardingApiKeyUnreachable(String providerName) {
    return 'Kunde inte nå $providerName. Kontrollera nyckeln eller din anslutning och försök igen.';
  }

  @override
  String get onboardingApiKeyVerifying => 'Verifierar...';

  @override
  String get onboardingCaptureCategoryPrompt => 'Var ska detta landa?';

  @override
  String get onboardingCaptureListening => 'Lyssnar... Knack när du är klar';

  @override
  String get onboardingCaptureOrbLabel => 'Skriv ner dina tankar';

  @override
  String get onboardingCaptureRatherType => 'Ganska typ?';

  @override
  String get onboardingCaptureReassurance =>
      'Du kommer kunna redigera allt härnäst.';

  @override
  String get onboardingCaptureThinking =>
      'Att göra dina ord till en uppgift...';

  @override
  String get onboardingCaptureTypePrompt => 'Skriv din tanke';

  @override
  String get onboardingCategoryAddOwn => 'Lägg till din egen';

  @override
  String get onboardingCategoryContinue => 'Fortsätt';

  @override
  String get onboardingCategoryExplanation =>
      'Varje område i ditt liv får sitt eget utrymme. Välj vilken som passar – eller lägg till din egen.';

  @override
  String get onboardingCategoryFamily => 'Familj';

  @override
  String get onboardingCategoryFitness => 'Kondition';

  @override
  String get onboardingCategoryFriends => 'Vänner';

  @override
  String get onboardingCategoryTitle => 'Var ska din AI arbeta?';

  @override
  String get onboardingCategoryWhy => 'Varför områden?';

  @override
  String onboardingCategoryWhyDetail(String provider) {
    return 'Varje område kan använda sin egen AI. $provider kommer att driva de områden du väljer här — senare kan du ge olika områden olika AI:er.';
  }

  @override
  String get onboardingCategoryWork => 'Verk';

  @override
  String get onboardingConnectGeminiName => 'Tvillingarna';

  @override
  String get onboardingConnectGeminiTagline => 'USA';

  @override
  String get onboardingConnectLessOptions => 'Färre alternativ';

  @override
  String get onboardingConnectMistralName => 'Mistral';

  @override
  String get onboardingConnectMistralTagline => 'Europeiska unionen';

  @override
  String get onboardingConnectMoreOptions => 'Fler alternativ';

  @override
  String get onboardingConnectNotSure =>
      'Melious.ai är den rekommenderade standarden.';

  @override
  String get onboardingConnectOllamaName => 'Ollama';

  @override
  String get onboardingConnectOpenAiName => 'OpenAI';

  @override
  String get onboardingConnectQwenName => 'Qwen';

  @override
  String get onboardingConnectQwenTagline => 'Kina';

  @override
  String get onboardingConnectTitle => 'Välj AI-hjärnan för dina uppgifter';

  @override
  String get onboardingFirstTaskCreatedHint =>
      'Tryck på din uppgift för att öppna den';

  @override
  String get onboardingFirstTaskCreatedTitle => 'Din första uppgift är klar';

  @override
  String get onboardingFirstTaskGuidance =>
      'Tryck för att prata och säg vad som behöver göras — Lotti gör det till en riktig uppgift.';

  @override
  String get onboardingFirstTaskSuggestionDentist =>
      'Boka en tid hos tandläkaren';

  @override
  String get onboardingFirstTaskSuggestionMeeting =>
      'Förbered dig för måndagens möte';

  @override
  String get onboardingFirstTaskSuggestionPlanWeek => 'Planera min vecka';

  @override
  String get onboardingFirstTaskSuggestionsLabel =>
      'Inte redo att prata? Börja med en av dessa:';

  @override
  String get onboardingFirstTaskTitle => 'Skapa din första uppgift';

  @override
  String get onboardingMetricsActiveDays => 'Aktiva dagar';

  @override
  String get onboardingMetricsActiveDaysInFirstSeven =>
      'Aktiva dagar i de första 7';

  @override
  String get onboardingMetricsBaselineCohort => 'Baslinjekohort (före FTUE)';

  @override
  String get onboardingMetricsInstallFirstSeenUtc =>
      'Installation först sedd (UTC)';

  @override
  String get onboardingMetricsNo => 'Nej';

  @override
  String get onboardingMetricsReachedRealAha => 'Nådde riktigt aha.';

  @override
  String get onboardingMetricsYes => 'ja';

  @override
  String get onboardingRecordingStyleAnalogue => 'Analog — VU-mätare';

  @override
  String get onboardingRecordingStyleContinue => 'Fortsätt';

  @override
  String get onboardingRecordingStyleExplanation =>
      'Välj en look till mikrofonen. Du kan ändra det när som helst i Inställningar.';

  @override
  String get onboardingRecordingStyleModern => 'Modern — energiklot';

  @override
  String get onboardingRecordingStyleTitle => 'Hur ska inspelning kännas?';

  @override
  String get onboardingRecordingStyleTryVoice => 'Prova med din röst';

  @override
  String get onboardingSuccessContinue => 'Sätt igång';

  @override
  String get onboardingSuccessSubtitle =>
      'Din AI-hjärna är uppkopplad och redo att omvandla dina ord till uppgifter.';

  @override
  String get onboardingSuccessTitle => 'Du är redo';

  @override
  String get onboardingWelcomeConnectButton => 'Välj din AI-hjärna';

  @override
  String get onboardingWelcomeMessage =>
      'Koppla in din AI-hjärna, säg sedan en tanke och se hur den blir en strukturerad uppgift.';

  @override
  String get onboardingWelcomeSkipButton => 'Titta runt först';

  @override
  String get onboardingWelcomeTitle => 'Prata. Lotti gör det till en plan.';

  @override
  String get optionalCategoryLabel => 'Kategori (valfritt)';

  @override
  String get outboxActionRemove => 'Ta bort';

  @override
  String get outboxActionRetry => 'Omprövning';

  @override
  String get outboxFailedReassurance =>
      'Den sparas fortfarande på denna enhet – den synkar när problemet är över.';

  @override
  String get outboxFilterFailed => 'Misslyckades';

  @override
  String get outboxFilterWaiting => 'Väntan';

  @override
  String get outboxMonitorAttachmentLabel => 'Fäste';

  @override
  String get outboxMonitorDelete => 'Ta bort';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Radera';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      'Är du säker på att du vill ta bort detta synkpunkt? Denna åtgärd kan inte göras ogjort.';

  @override
  String get outboxMonitorDeleteFailed =>
      'Borttagningen misslyckades. Försök igen, tack.';

  @override
  String get outboxMonitorDeleteSuccess => 'Föremål borttaget';

  @override
  String get outboxMonitorEmptyDescription =>
      'Det finns inga synkobjekt i denna vy.';

  @override
  String get outboxMonitorEmptyTitle => 'Utkorgen är klar';

  @override
  String get outboxMonitorFetchFailed =>
      'Kunde inte ladda utkorgen. Dra för att uppdatera och försök igen.';

  @override
  String get outboxMonitorLabelError => 'Fel';

  @override
  String get outboxMonitorLabelPending => 'Väntar';

  @override
  String get outboxMonitorLabelSent => 'Skickat';

  @override
  String get outboxMonitorLabelSuccess => 'Framgång';

  @override
  String get outboxMonitorNoAttachment => 'Ingen anknytning';

  @override
  String get outboxMonitorPayloadSizeLabel => 'Storlek';

  @override
  String get outboxMonitorRetries => 'Omprövningar';

  @override
  String get outboxMonitorRetriesLabel => 'Omprövningar';

  @override
  String get outboxMonitorRetry => 'Omprövning';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Försök igen nu';

  @override
  String get outboxMonitorRetryConfirmMessage =>
      'Försök igen med detta synkroniseringsobjekt nu?';

  @override
  String get outboxMonitorRetryFailed =>
      'Omförsök misslyckades. Försök igen, tack.';

  @override
  String get outboxMonitorRetryQueued => 'Omprövning inbokad';

  @override
  String get outboxMonitorSubjectLabel => 'Ämne';

  @override
  String get outboxMonitorVolumeChartTitle => 'Daglig synkroniseringsvolym';

  @override
  String get outboxRemoveConfirmMessage =>
      'Den här förändringen har inte synkats än. Att ta bort den här betyder att den inte når dina andra enheter. Den stannar kvar på den här enheten.';

  @override
  String get outboxRemoveConfirmTitle => 'Ta bort från kön?';

  @override
  String get outboxRetryAll => 'Försök om alla';

  @override
  String get outboxShowDetails => 'Visa tekniska detaljer';

  @override
  String get outboxStatusFailed => 'Kunde inte skicka';

  @override
  String get outboxStatusSending => 'Sändning';

  @override
  String get outboxStatusSent => 'Skickat';

  @override
  String get outboxStatusWaiting => 'Väntar på att skicka';

  @override
  String outboxSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count föremål kunde inte skickas',
      one: '1 föremål kunde inte skickas',
    );
    return '$_temp0';
  }

  @override
  String outboxSummaryOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count föremål skickas när du återansluter',
      one: '1 föremål skickas när du återansluter',
    );
    return '$_temp0';
  }

  @override
  String outboxSummarySending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skickar $count-föremål... ',
      one: 'Skickar 1 föremål... ',
    );
    return '$_temp0';
  }

  @override
  String get outboxSummarySynced => 'Allt är synkat';

  @override
  String outboxSummaryWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count föremål som väntar på att skickas',
      one: '1 föremål som väntar på att skickas',
    );
    return '$_temp0';
  }

  @override
  String outboxTriedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Försökte $count gånger',
      one: 'Försökte en gång',
    );
    return '$_temp0';
  }

  @override
  String get panasCompletionText => 'Tack för att du fyllde i PANAS!';

  @override
  String get panasCompletionTitle => 'Färdigt';

  @override
  String get panasEmotionActive => 'Aktiv';

  @override
  String get panasEmotionAfraid => 'Rädd';

  @override
  String get panasEmotionAlert => 'Varning';

  @override
  String get panasEmotionAshamed => 'Skäms';

  @override
  String get panasEmotionAttentive => 'Uppmärksam';

  @override
  String get panasEmotionDetermined => 'Bestämd';

  @override
  String get panasEmotionDistressed => 'Upprörd';

  @override
  String get panasEmotionEnthusiastic => 'Entusiastisk';

  @override
  String get panasEmotionExcited => 'Uppspelt';

  @override
  String get panasEmotionGuilty => 'Skyldig';

  @override
  String get panasEmotionHostile => 'Fientlig';

  @override
  String get panasEmotionInspired => 'Inspirerad';

  @override
  String get panasEmotionInterested => 'Intresserad';

  @override
  String get panasEmotionIrritable => 'Irriterad';

  @override
  String get panasEmotionJittery => 'Nervös';

  @override
  String get panasEmotionNervous => 'Nervös';

  @override
  String get panasEmotionProud => 'Stolt';

  @override
  String get panasEmotionScared => 'Rädd';

  @override
  String get panasEmotionStrong => 'Stark';

  @override
  String get panasEmotionUpset => 'Upprörd';

  @override
  String get panasInstructionFootnote =>
      'Watson, D., Clark, L. A., & Tellegen, A. (1988). Utveckling och validering av korta mått på positiv och negativ effekt: PANAS-skalorna. Journal of Personality and Social Psychology, 54(6), 1063–1070.';

  @override
  String get panasInstructionText =>
      'Ange i vilken utsträckning du känner så just nu, alltså just nu.\n\n1—Mycket lite eller inte alls,\n2—Lite,\n3—Måttligt,\n4—Ganska mycket,\n5—Extremt';

  @override
  String get panasInstructionTitle =>
      'Schemat för positiv och negativ affekt (PANAS; Watson et al., 1988)';

  @override
  String get panasScaleALittle => 'Lite';

  @override
  String get panasScaleExtremely => 'Extremt';

  @override
  String get panasScaleModerately => 'Måttligt';

  @override
  String get panasScaleQuiteABit => 'Ganska mycket';

  @override
  String get panasScaleVerySlightlyOrNotAtAll =>
      'Mycket lite grann eller inte alls';

  @override
  String get privateLabel => 'Privat';

  @override
  String get privateSwitchDescription =>
      'Endast synligt när privata bidrag visas';

  @override
  String get projectAgentNotProvisioned =>
      'Ingen projektagent har ännu tilldelats detta projekt.';

  @override
  String get projectAgentSectionTitle => 'Agent';

  @override
  String projectCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projekt',
      one: '$count projekt',
    );
    return '$_temp0';
  }

  @override
  String get projectCreateButton => 'Nytt projekt';

  @override
  String get projectCreateTitle => 'Skapa projekt';

  @override
  String get projectDetailTitle => 'Projektdetaljer';

  @override
  String get projectErrorCreateFailed => 'Felskapande projekt.';

  @override
  String get projectErrorLoadFailed =>
      'Misslyckades med att ladda projektdata.';

  @override
  String get projectErrorLoadProjects => 'Felladdningsprojekt';

  @override
  String get projectErrorUpdateFailed =>
      'Misslyckades med att uppdatera projektet. Försök igen, tack.';

  @override
  String get projectFilterLabel => 'Projekt';

  @override
  String get projectHealthBandAtRisk => 'I riskzonen';

  @override
  String get projectHealthBandBlocked => 'Blockerad';

  @override
  String get projectHealthBandOnTrack => 'På banan';

  @override
  String get projectHealthBandSurviving => 'Bevarade';

  @override
  String get projectHealthBandWatch => 'Titta';

  @override
  String get projectHealthSectionTitle => 'Projekthälsa';

  @override
  String projectHealthSummary(int projectCount, int taskCount) {
    String _temp0 = intl.Intl.pluralLogic(
      projectCount,
      locale: localeName,
      other: '$projectCount projekt',
      one: '$projectCount projekt',
    );
    String _temp1 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: '$taskCount uppgifter',
      one: '$taskCount uppgift',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get projectHealthTitle => 'Projekt';

  @override
  String projectLinkedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count länkade uppgifter',
      one: '$count länkad uppgift',
    );
    return '$_temp0';
  }

  @override
  String get projectLinkedTasks => 'Länkade uppgifter';

  @override
  String get projectManageTooltip => 'Hantera projekt';

  @override
  String get projectNoLinkedTasks => 'Inga uppgifter är länkade än';

  @override
  String get projectNoProjects => 'Inga projekt än';

  @override
  String get projectNotFound => 'Projekt ej hittat';

  @override
  String get projectPickerLabel => 'Projekt';

  @override
  String get projectPickerUnassigned => 'Inget projekt';

  @override
  String get projectRecommendationDismissTooltip => 'Avslut';

  @override
  String get projectRecommendationResolveTooltip => 'Mark bestämde sig';

  @override
  String get projectRecommendationsTitle => 'Rekommenderade nästa steg';

  @override
  String get projectRecommendationUpdateError =>
      'Kunde inte uppdatera rekommendationen. Försök igen, tack.';

  @override
  String get projectsFilterStatusLabel => 'Status:';

  @override
  String get projectsFilterTooltip => 'Filtrera projekt';

  @override
  String get projectShowcaseAiReportTitle => 'AI-rapport';

  @override
  String projectShowcaseBlockedLegend(int count) {
    return '$count Blockerad';
  }

  @override
  String projectShowcaseBlockedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uppgifter blockerade',
      one: '$count uppgift blockerad',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseCompletedLegend(int count) {
    return '$count Färdigställd';
  }

  @override
  String get projectShowcaseDescriptionTitle => 'Beskrivning';

  @override
  String projectShowcaseDueDate(String date) {
    return 'Förfaller: $date';
  }

  @override
  String get projectShowcaseHealthScoreDescription =>
      'Detta poäng baseras på uppgiftens hastighet, blockerare och tid kvar till deadline.';

  @override
  String get projectShowcaseHealthScoreTitle => 'Hälsopoäng';

  @override
  String get projectShowcaseNoResults => 'Inga projekt matchar din sökning.';

  @override
  String get projectShowcaseOneOnOneReviewsTab => 'Enskilda recensioner';

  @override
  String get projectShowcaseOngoing => 'Pågående';

  @override
  String get projectShowcaseProjectTasksTab => 'Projektuppgifter';

  @override
  String get projectShowcaseSearchHint => 'Sökprojekt';

  @override
  String projectShowcaseSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessioner',
      one: '$count session',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseTasksCompleted(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$completed/$total uppgifter slutförda',
      one: '$completed/$total uppgift slutförd',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseUpdatedHoursAgo(int hours) {
    return 'Uppdaterad $hours för länge sedan ↻';
  }

  @override
  String projectShowcaseUpdatedMinutesAgo(int minutes) {
    return 'Uppdaterad $minutes för länge sedan ↻';
  }

  @override
  String get projectShowcaseUsefulness => 'Användbarhet';

  @override
  String get projectShowcaseViewBlocker => 'Visningsblockerare';

  @override
  String get projectStatusActive => 'Aktiv';

  @override
  String get projectStatusArchived => 'Arkiverad';

  @override
  String get projectStatusChangeTitle => 'Ändra status';

  @override
  String get projectStatusCompleted => 'Färdigställd';

  @override
  String get projectStatusMonitoring => 'Övervakning';

  @override
  String get projectStatusOnHold => 'På vänt';

  @override
  String get projectStatusOpen => 'Öppet';

  @override
  String get projectSummaryOutdated => 'Sammanfattning är föråldrad.';

  @override
  String projectSummaryOutdatedScheduled(String date, String time) {
    return 'Sammanfattning är föråldrad. Nästa uppdatering $date på $time.';
  }

  @override
  String get projectTargetDateLabel => 'Måldatum';

  @override
  String get projectTitleLabel => 'Projekttitel';

  @override
  String get projectTitleRequired => 'Projekttiteln kan inte vara tom';

  @override
  String get promptDefaultModelBadge => 'Standard';

  @override
  String get promptGenerationCardTitle => 'AI-kodningsprompt';

  @override
  String get promptGenerationCopiedSnackbar =>
      'Prompt kopierad till skrivplatta';

  @override
  String get promptGenerationCopyButton => 'Kopiera prompt';

  @override
  String get promptGenerationCopyTooltip =>
      'Kopiera prompten till urklippstavlan';

  @override
  String get promptGenerationExpandTooltip => 'Visa fullständig prompt';

  @override
  String get promptGenerationFullPromptLabel => 'Fullständig prompt:';

  @override
  String get promptSelectionModalTitle => 'Välj förkonfigurerad prompt';

  @override
  String get provisionedSyncBundleImported => 'Importerad provisioneringskod';

  @override
  String get provisionedSyncConfigureButton => 'Konfigurera';

  @override
  String get provisionedSyncCopiedToClipboard => 'Kopierat till skrivplatta';

  @override
  String get provisionedSyncDisconnect => 'Koppla bort';

  @override
  String get provisionedSyncDone =>
      'Synkroniserade konfigurerade framgångsrikt';

  @override
  String get provisionedSyncError => 'Konfigurationen misslyckades';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'Ett fel uppstod under konfigurationen. Försök igen, tack.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'Inloggningen misslyckades. Kontrollera dina behörigheter och försök igen.';

  @override
  String get provisionedSyncImportButton => 'Import';

  @override
  String get provisionedSyncImportHint => 'Klistra in provisioneringskoden här';

  @override
  String get provisionedSyncImportTitle => 'Synkroniseringsinställning';

  @override
  String get provisionedSyncInvalidBundle => 'Ogiltig provisioneringskod';

  @override
  String get provisionedSyncJoiningRoom => 'Ansluter till synkrummet...';

  @override
  String get provisionedSyncLoggingIn => 'Loggar in...';

  @override
  String get provisionedSyncPasteClipboard => 'Klistra in från skrivplatta';

  @override
  String get provisionedSyncReady => 'Skanna denna QR-kod på din mobila enhet';

  @override
  String get provisionedSyncRetry => 'Omprövning';

  @override
  String get provisionedSyncRotatingPassword => 'Säkrar kontot...';

  @override
  String get provisionedSyncScanButton => 'Skanna QR-kod';

  @override
  String get provisionedSyncShowQr => 'Visa provisionering QR';

  @override
  String get provisionedSyncSubtitle =>
      'Sätt upp synk från ett provisioning-paket';

  @override
  String get provisionedSyncSummaryHomeserver => 'Homeserver';

  @override
  String get provisionedSyncSummaryRoom => 'Rum';

  @override
  String get provisionedSyncSummaryUser => 'Användare';

  @override
  String get provisionedSyncTitle => 'Provisionerad synkronisering';

  @override
  String get provisionedSyncVerifyDevicesTitle => 'Enhetsverifiering';

  @override
  String get queueCatchUpNowButton => 'Ta igen nu';

  @override
  String get queueCatchUpNowDone => 'Uppskjutning – kön är utmattande.';

  @override
  String queueCatchUpNowError(String reason) {
    return 'Att komma ikapp misslyckades: $reason';
  }

  @override
  String get queueDepthCardEmpty => 'Kön är tom — arbetaren är ikapp.';

  @override
  String get queueDepthCardLoading => 'Läser köens djup...';

  @override
  String get queueDepthCardTitle => 'Inkommande kö';

  @override
  String get queueFetchAllHistoryCancel => 'Avbryt';

  @override
  String queueFetchAllHistoryCancelled(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events evenemang',
      one: '1 händelse',
      zero: 'inga evenemang',
    );
    return 'Inställt — $_temp0 hittills.';
  }

  @override
  String get queueFetchAllHistoryClose => 'Stäng';

  @override
  String get queueFetchAllHistoryDescription =>
      'Går in i rummets hela synliga historia i kön. Säkert att avboka; en senare genomspelning återupptas där pagineringen slutade.';

  @override
  String queueFetchAllHistoryDone(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages sidor',
      one: '1 sida',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages sidor',
      one: '1 sida',
    );
    String _temp2 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: 'Hämtade $events händelser över $_temp0. ',
      one: 'Hämtade 1 händelse över $_temp1. ',
      zero: 'Inga händelser hämtades. ',
    );
    return '$_temp2';
  }

  @override
  String queueFetchAllHistoryError(String reason) {
    return 'Apportering stoppad: $reason';
  }

  @override
  String get queueFetchAllHistoryErrorUnknown => 'Apporten stannade oväntat.';

  @override
  String queueFetchAllHistoryProgress(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: ' sida $pages ·  $events händelser hämtade',
      one: 'Sida $pages ·  1 händelse hämtad',
    );
    return '$_temp0';
  }

  @override
  String get queueFetchAllHistoryTitle => 'Hämtningshistorik';

  @override
  String queueSkippedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hoppade över ',
      one: '1 hoppade över ',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedCardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count synkhändelser som kön gav upp på. Tryck på försök igen för att försöka igen. ',
      one:
          '1 synkroniseringshändelse som kön gav upp. Tryck på försök igen för att försöka igen. ',
    );
    return '$_temp0';
  }

  @override
  String get queueSkippedCardTitle => 'Hoppade evenemang';

  @override
  String get queueSkippedRetryAll => 'Omförsök hoppade över evenemang';

  @override
  String queueSkippedRetryAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count händelser i kö för omförsök. ',
      one: '1 händelse köad för omförsök. ',
      zero: 'Inga hoppade grenar att försöka om. ',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedRetryAllError(String reason) {
    return 'Försök misslyckades: $reason';
  }

  @override
  String get referenceImageContinue => 'Fortsätt';

  @override
  String referenceImageContinueWithCount(int count) {
    return 'Fortsätt ($count)';
  }

  @override
  String get referenceImageLoadError =>
      'Misslyckades med att ladda bilder. Försök igen, tack.';

  @override
  String get referenceImageSelectionSubtitle =>
      'Välj upp till 5 bilder för att styra AI:ns visuella stil';

  @override
  String get referenceImageSelectionTitle => 'Välj referensbilder';

  @override
  String get referenceImageSkip => 'Hoppa över';

  @override
  String get saveButton => 'Spara';

  @override
  String get saveButtonLabel => 'Spara';

  @override
  String get saveLabel => 'Spara';

  @override
  String get saveShortcutTooltip => 'Spara — Ctrl+S (⌘S på Mac)';

  @override
  String get saveSuccessful => 'Räddad framgångsrikt';

  @override
  String get searchHint => 'Sök...';

  @override
  String get searchModeFullText => 'Fulltext';

  @override
  String get searchModeVector => 'Vektor';

  @override
  String get searchTasksHint => 'Sökuppgifter...';

  @override
  String get selectButton => 'Välj';

  @override
  String get selectColor => 'Välj en färg';

  @override
  String get selectLanguage => 'Välj språk';

  @override
  String get sessionRatingCardLabel => 'Sessionsbetyg';

  @override
  String get sessionRatingChallengeJustRight => 'Precis lagom';

  @override
  String get sessionRatingChallengeTooEasy => 'För lätt';

  @override
  String get sessionRatingChallengeTooHard => 'För utmanande';

  @override
  String get sessionRatingDifficultyLabel => 'Det här arbetet kändes...';

  @override
  String get sessionRatingEditButton => 'Redigeringsbetyg';

  @override
  String get sessionRatingEnergyQuestion => 'Hur energisk kände du dig?';

  @override
  String get sessionRatingFocusQuestion => 'Hur fokuserad var du?';

  @override
  String get sessionRatingNoteHint => 'Snabb notis (valfritt)';

  @override
  String get sessionRatingProductivityQuestion =>
      'Hur produktiv var den här sessionen?';

  @override
  String get sessionRatingRateAction => 'Prissession';

  @override
  String get sessionRatingSaveButton => 'Spara';

  @override
  String get sessionRatingSaveError =>
      'Misslyckades med att rädda. Försök igen, tack.';

  @override
  String get sessionRatingSkipButton => 'Hoppa över';

  @override
  String get sessionRatingTitle => 'Betygsätt denna session';

  @override
  String get sessionRatingViewAction => 'Visningsbetyg';

  @override
  String get settingsAboutAppInformation => 'Appinformation';

  @override
  String get settingsAboutAppTagline => 'Din personliga dagbok';

  @override
  String get settingsAboutBuildType => 'Byggtyp';

  @override
  String get settingsAboutDailyOsPersonalizationTitle =>
      'Daglig personalisering av operativsystemet';

  @override
  String get settingsAboutDailyOsUserNameHelper =>
      'Används för Daily OS-hälsningen och synkroniseras mellan dina enheter.';

  @override
  String get settingsAboutDailyOsUserNameLabel => 'Ditt namn';

  @override
  String get settingsAboutJournalEntries => 'Dagboksanteckningar';

  @override
  String get settingsAboutPlatform => 'Plattform';

  @override
  String get settingsAboutTitle => 'Om Lotti';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutYourData => 'Dina data';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'Lär dig mer om Lotti-applikationen';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Importera hälsodata från externa källor';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Utför underhållsuppgifter för att optimera applikationsprestandan';

  @override
  String get settingsAdvancedManualLanguageSubtitle =>
      'Välj vilket språk du ska öppna Lotti-manualen på';

  @override
  String get settingsAdvancedOutboxSubtitle => 'Hantera synkobjekt';

  @override
  String get settingsAdvancedSubtitle =>
      'Avancerade inställningar och underhåll';

  @override
  String get settingsAdvancedTitle => 'Avancerade inställningar';

  @override
  String get settingsAgentsInstancesSubtitle => 'Drivande agenter';

  @override
  String get settingsAgentsPendingWakesSubtitle => 'Schemalagda väckningstider';

  @override
  String get settingsAgentsSoulsSubtitle => 'Långlivade agentpersonligheter';

  @override
  String get settingsAgentsStatsSubtitle => 'Tokenanvändning och aktivitet';

  @override
  String get settingsAgentsTemplatesSubtitle => 'Ritningar för delade agenter';

  @override
  String get settingsAiModelsSubtitle =>
      'Per-leverantörsmodellrader och kapabiliteter';

  @override
  String get settingsAiModelsTitle => 'Modeller';

  @override
  String get settingsAiProfilesSubtitle => 'Leverantörer och modeller';

  @override
  String get settingsAiProfilesTitle => 'Slutsatsprofiler';

  @override
  String get settingsAiProvidersSubtitle =>
      'Leverantörer och nycklar av uppkopplad AI-intelligens';

  @override
  String get settingsAiProvidersTitle => 'Leverantörer';

  @override
  String get settingsAiSubtitle =>
      'Konfigurera AI-leverantörer, modeller och prompts';

  @override
  String get settingsAiTitle => 'AI-inställningar';

  @override
  String get settingsAiUsageSubtitle =>
      'Kostnad, energi och CO₂e för AI-samtal';

  @override
  String get settingsAiUsageTitle => 'Användning och påverkan';

  @override
  String get settingsBeamPageEditModelTitle => 'Redigera modell';

  @override
  String get settingsBeamPageEditProfileTitle => 'Redigera profil';

  @override
  String get settingsCategoriesCreateTitle => 'Skapa kategori';

  @override
  String get settingsCategoriesDetailsLabel => 'Redigeringskategori';

  @override
  String get settingsCategoriesEmptyState => 'Inga kategorier än';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Skapa en kategori för att organisera dina bidrag';

  @override
  String get settingsCategoriesErrorLoading => 'Felladdningskategorier';

  @override
  String get settingsCategoriesNameLabel => 'Kategorinamn';

  @override
  String settingsCategoriesNoMatchQuery(String query) {
    return 'Inga kategorier matchar \"$query\"';
  }

  @override
  String get settingsCategoriesSearchHint => 'Sökkategorier...';

  @override
  String get settingsCategoriesSubtitle => 'Kategorier med AI-inställningar';

  @override
  String settingsCategoriesTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uppgifter',
      one: '$count uppgift',
    );
    return '$_temp0';
  }

  @override
  String get settingsCategoriesTitle => 'Kategorier';

  @override
  String get settingsCelebrationsChecklistDescription =>
      'Ett popp och gnistor när du bockar av en vara';

  @override
  String get settingsCelebrationsChecklistTitle => 'Checklistor';

  @override
  String get settingsCelebrationsCustomizeTitle => 'Anpassa';

  @override
  String get settingsCelebrationsCustomizeTooltip => 'Anpassa denna stil';

  @override
  String get settingsCelebrationsEnabledDescription =>
      'Huvudbrytare för fullbordande flourishes. Off döljer alla animationer; Haptiker behåller sin egen switch.';

  @override
  String get settingsCelebrationsEnabledTitle => 'Firandeanimationer';

  @override
  String get settingsCelebrationsGroupLook => 'Titta';

  @override
  String get settingsCelebrationsGroupMotion => 'Rörelse';

  @override
  String get settingsCelebrationsGroupShape => 'Form';

  @override
  String get settingsCelebrationsHabitsDescription =>
      'Lyser och gnistrar när du fullföljer en vana';

  @override
  String get settingsCelebrationsHabitsTitle => 'Habiter';

  @override
  String get settingsCelebrationsHapticsDescription =>
      'Ett kort surr när du är klar med något – oberoende av animationen.';

  @override
  String get settingsCelebrationsHapticsTitle => 'Kompletteringshaptik';

  @override
  String get settingsCelebrationsKnobClearCenter => 'Mittgap';

  @override
  String get settingsCelebrationsKnobCount => 'Partiklar';

  @override
  String get settingsCelebrationsKnobDescClearCenter =>
      'Tomt utrymme i centrum';

  @override
  String get settingsCelebrationsKnobDescCount =>
      'Hur många partiklar flyger ut';

  @override
  String get settingsCelebrationsKnobDescFallout =>
      'Hur långt gnistor driver ner';

  @override
  String get settingsCelebrationsKnobDescFanSpread => 'Fläktens bredd';

  @override
  String get settingsCelebrationsKnobDescGlow => 'Styrkan i glöden';

  @override
  String get settingsCelebrationsKnobDescGravity =>
      'Hur snabbt partiklar faller';

  @override
  String get settingsCelebrationsKnobDescHalo => 'Glorians styrka';

  @override
  String get settingsCelebrationsKnobDescInnerRing =>
      'Storleken på den inre ringen';

  @override
  String get settingsCelebrationsKnobDescLaunch => 'Vänta innan utbrottet';

  @override
  String get settingsCelebrationsKnobDescPop => 'När de spricker';

  @override
  String get settingsCelebrationsKnobDescReach => 'Hur långt partiklar färdas';

  @override
  String get settingsCelebrationsKnobDescRise => 'Hur partiklar stiger högt';

  @override
  String get settingsCelebrationsKnobDescSize => 'Hur stor varje partikel är';

  @override
  String get settingsCelebrationsKnobDescSpeedSpread =>
      'Variation i partikelhastighet';

  @override
  String get settingsCelebrationsKnobDescSpin => 'Hur snabbt bitarna snurrar';

  @override
  String get settingsCelebrationsKnobDescSpread => 'Bredden på sprayen';

  @override
  String get settingsCelebrationsKnobDescSway => 'Hur mycket pjäserna svajar';

  @override
  String get settingsCelebrationsKnobDescSwell => 'Hur mycket de växer';

  @override
  String get settingsCelebrationsKnobDescTrail => 'Längd på varje led';

  @override
  String get settingsCelebrationsKnobDescTwinkle =>
      'Hur mycket partiklar flimrar';

  @override
  String get settingsCelebrationsKnobDescUpward => 'Hur starkt de stiger';

  @override
  String get settingsCelebrationsKnobDescWobble => 'Hur mycket bitar vaggar';

  @override
  String get settingsCelebrationsKnobFallout => 'Efterspel';

  @override
  String get settingsCelebrationsKnobFanSpread => 'Spridning av solfjädrar';

  @override
  String get settingsCelebrationsKnobGlow => 'Glöd';

  @override
  String get settingsCelebrationsKnobGravity => 'Gravitation';

  @override
  String get settingsCelebrationsKnobHalo => 'Halo';

  @override
  String get settingsCelebrationsKnobInnerRing => 'Inre ring';

  @override
  String get settingsCelebrationsKnobLaunch => 'Uppskjutningstid';

  @override
  String get settingsCelebrationsKnobPop => 'Pop point';

  @override
  String get settingsCelebrationsKnobReach => 'Reach';

  @override
  String get settingsCelebrationsKnobRise => 'Höjd';

  @override
  String get settingsCelebrationsKnobSize => 'Storlek';

  @override
  String get settingsCelebrationsKnobSpeedSpread => 'Hastighetsvariation';

  @override
  String get settingsCelebrationsKnobSpin => 'Snurr';

  @override
  String get settingsCelebrationsKnobSpread => 'Spridningsbåge';

  @override
  String get settingsCelebrationsKnobSway => 'Svaj';

  @override
  String get settingsCelebrationsKnobSwell => 'Svällning';

  @override
  String get settingsCelebrationsKnobTrail => 'Ledens längd';

  @override
  String get settingsCelebrationsKnobTwinkle => 'Blinka';

  @override
  String get settingsCelebrationsKnobUpward => 'Uppgång';

  @override
  String get settingsCelebrationsKnobWobble => 'Vobbla';

  @override
  String get settingsCelebrationsPlaygroundHint =>
      'Tryck på den markerade raden för att förhandsgranska';

  @override
  String get settingsCelebrationsPlaygroundLiveNote =>
      'Ändringar sparar och gäller överallt omedelbart';

  @override
  String get settingsCelebrationsPreviewChecklistItem => 'Kolla mig';

  @override
  String get settingsCelebrationsPreviewDescription =>
      'Tryck på en kontroll för att spela din valda stil.';

  @override
  String get settingsCelebrationsPreviewDone => 'Klart';

  @override
  String get settingsCelebrationsPreviewHabit => 'Habit';

  @override
  String get settingsCelebrationsPreviewSample1 => 'Morgonpromenad';

  @override
  String get settingsCelebrationsPreviewSample2 => 'Avsluta rapporten';

  @override
  String get settingsCelebrationsPreviewSample3 => 'Vattna växterna';

  @override
  String get settingsCelebrationsPreviewTitle => 'Prova';

  @override
  String get settingsCelebrationsReplay => 'Omspel';

  @override
  String get settingsCelebrationsResetToast =>
      'Stilåterställning till standard';

  @override
  String get settingsCelebrationsResetToDefault => 'Återställ till standard';

  @override
  String get settingsCelebrationsResetUndo => 'Ångra';

  @override
  String get settingsCelebrationsSectionDescription =>
      'Spela en flourish när du är klar med något. Att stänga av en håller slutförandet och det är haptiskt — det hoppar bara över animationen.';

  @override
  String get settingsCelebrationsSectionTitle => 'Färdigställandefiranden';

  @override
  String get settingsCelebrationsStyleDescription =>
      'Tryck på ett kort för att förhandsgranska en feststil och gör den till din.';

  @override
  String get settingsCelebrationsStyleTitle => 'Stil';

  @override
  String get settingsCelebrationsSubtitle => 'Färdigställandefiranden';

  @override
  String get settingsCelebrationsTasksDescription =>
      'Lyser och gnistrar när du flyttar en uppgift till Klart';

  @override
  String get settingsCelebrationsTasksTitle => 'Uppgifter';

  @override
  String get settingsCelebrationsTitle => 'Underhållning';

  @override
  String get settingsCelebrationsVariantBubbles => 'Bubblor';

  @override
  String get settingsCelebrationsVariantCombine => 'Kombinera två';

  @override
  String get settingsCelebrationsVariantCombineDescription =>
      'Två slumpmässiga stilar, lager på lager, varje gång';

  @override
  String get settingsCelebrationsVariantConfetti => 'Konfetti';

  @override
  String get settingsCelebrationsVariantEmbers => 'Glöd';

  @override
  String get settingsCelebrationsVariantFireworks => 'Fyrverkerier';

  @override
  String get settingsCelebrationsVariantRandom => 'Slumpmässigt';

  @override
  String get settingsCelebrationsVariantRandomDescription =>
      'En fräsch stil vid varje avslut';

  @override
  String get settingsCelebrationsVariantSparks => 'Gnistor';

  @override
  String get settingsConflictsTitle => 'Synkroniseringskonflikter';

  @override
  String get settingsDashboardDetailsLabel => 'Redigera instrumentpanel';

  @override
  String get settingsDashboardSaveLabel => 'Spara';

  @override
  String get settingsDashboardsCreateTitle => 'Skapa instrumentpanel';

  @override
  String get settingsDashboardsEmptyState => 'Inga dashboards än';

  @override
  String get settingsDashboardsEmptyStateHint =>
      'Tryck på +-knappen för att skapa din första dashboard.';

  @override
  String get settingsDashboardsErrorLoading => 'Felladdningsinstrumentpaneler';

  @override
  String settingsDashboardsNoMatchQuery(String query) {
    return 'Inga dashboards matchar \"$query\"';
  }

  @override
  String get settingsDashboardsSearchHint => 'Sök i instrumentpaneler...';

  @override
  String get settingsDashboardsSubtitle => 'Anpassa dina dashboardvyer';

  @override
  String get settingsDashboardsTitle => 'Instrumentpaneler';

  @override
  String get settingsDefinitionsSubtitle =>
      'Vanor, kategorier, etiketter, instrumentpaneler och mätbara saker';

  @override
  String get settingsDefinitionsTitle => 'Definitioner';

  @override
  String get settingsFlagsEmptySearch => 'Inga flaggor matchar din sökning';

  @override
  String get settingsFlagsSearchHint => 'Sökflaggor';

  @override
  String get settingsFlagsSubtitle =>
      'Konfigurera funktionsflaggor och alternativ';

  @override
  String get settingsFlagsTitle => 'Konfigurationsflaggor';

  @override
  String get settingsHabitsCreateTitle => 'Skapa vana';

  @override
  String get settingsHabitsDeleteTooltip => 'Radera vana';

  @override
  String get settingsHabitsDescriptionLabel => 'Beskrivning (valfritt)';

  @override
  String get settingsHabitsDetailsLabel => 'Redigeringsvana';

  @override
  String get settingsHabitsEmptyState => 'Inga vanor än';

  @override
  String get settingsHabitsEmptyStateHint =>
      'Tryck på +-knappen för att skapa din första vana.';

  @override
  String get settingsHabitsErrorLoading => 'Felladdningsvanor';

  @override
  String get settingsHabitsNameLabel => 'Habitnamn';

  @override
  String settingsHabitsNoMatchQuery(String query) {
    return 'Inga vanor matchar \"$query\"';
  }

  @override
  String get settingsHabitsPrivateLabel => 'Privat: ';

  @override
  String get settingsHabitsSaveLabel => 'Spara';

  @override
  String get settingsHabitsSearchHint => 'Sökvanor...';

  @override
  String get settingsHabitsSubtitle => 'Hantera dina vanor och rutiner';

  @override
  String get settingsHabitsTitle => 'Habiter';

  @override
  String get settingsHealthImportActivity => 'Importera aktivitetsdata';

  @override
  String get settingsHealthImportBloodPressure => 'Importera blodtrycksdata';

  @override
  String get settingsHealthImportBodyMeasurement => 'Importera kroppsmätdata';

  @override
  String get settingsHealthImportFromDate => 'Start';

  @override
  String get settingsHealthImportHeartRate => 'Importera hjärtfrekvensdata';

  @override
  String get settingsHealthImportSleep => 'Importera sömndata';

  @override
  String get settingsHealthImportTitle => 'Hälsoimport';

  @override
  String get settingsHealthImportToDate => 'Slut';

  @override
  String get settingsHealthImportWorkout => 'Importera träningsdata';

  @override
  String get settingsKeyboardShortcutsSubtitle =>
      'Lär dig tangentbordskombinationerna för snabbare navigering och redigering på skrivbordet';

  @override
  String get settingsKeyboardShortcutsTitle => 'Tangentbordsgenvägar';

  @override
  String get settingsLabelsCategoriesAdd => 'Lägg till kategori';

  @override
  String get settingsLabelsCategoriesHeading => 'Tillämpliga kategorier';

  @override
  String get settingsLabelsCategoriesNone => 'Gäller för alla kategorier';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Ta bort';

  @override
  String get settingsLabelsColorHeading => 'Färg';

  @override
  String get settingsLabelsColorSubheading => 'Snabba förinställningar';

  @override
  String get settingsLabelsCreateTitle => 'Skapa etikett';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Radera';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return 'Är du säker på att du vill radera \"$labelName\"? Uppgifter med denna etikett förlorar tilldelningen.';
  }

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Ta bort etiketten';

  @override
  String settingsLabelsDeleteSuccess(Object labelName) {
    return 'Etikett \"$labelName\" borttagen';
  }

  @override
  String get settingsLabelsDescriptionHint =>
      'Förklara när du ska applicera denna etikett';

  @override
  String get settingsLabelsDescriptionLabel => 'Beskrivning (valfritt)';

  @override
  String get settingsLabelsEditTitle => 'Redigera etikett';

  @override
  String get settingsLabelsEmptyState => 'Inga etiketter än';

  @override
  String get settingsLabelsEmptyStateHint =>
      'Tryck på +-knappen för att skapa din första etikett.';

  @override
  String get settingsLabelsErrorLoading =>
      'Misslyckades med att ladda etiketter';

  @override
  String get settingsLabelsNameHint => 'Bugg, frisättningsblockerare, synk...';

  @override
  String get settingsLabelsNameLabel => 'Skivbolagets namn';

  @override
  String settingsLabelsNoMatchCreate(String query) {
    return 'Skapa etiketten \"$query\"';
  }

  @override
  String settingsLabelsNoMatchQuery(String query) {
    return 'Inga etiketter matchar \"$query\"';
  }

  @override
  String get settingsLabelsPrivateDescription =>
      'Endast synligt när privata bidrag visas';

  @override
  String get settingsLabelsPrivateTitle => 'Privat';

  @override
  String get settingsLabelsSearchHint => 'Söketiketter...';

  @override
  String get settingsLabelsSubtitle =>
      'Organisera uppgifter med färgade etiketter';

  @override
  String get settingsLabelsTitle => 'Etiketter';

  @override
  String settingsLabelsUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uppgifter',
      one: '1 uppgift',
    );
    return '$_temp0';
  }

  @override
  String get settingsLoggingDomainsSubtitle =>
      'Kontrollera vilka domäner som skriver till loggen';

  @override
  String get settingsLoggingDomainsTitle => 'Loggningsdomäner';

  @override
  String get settingsLoggingGlobalToggle => 'Aktivera loggning';

  @override
  String get settingsLoggingGlobalToggleSubtitle =>
      'Huvudomkopplare för all avverkning';

  @override
  String get settingsLoggingSlowQueries => 'Långsamma databasfrågor';

  @override
  String get settingsLoggingSlowQueriesSubtitle =>
      'Skriver långsamma frågor till slow_queries-YYYY-MM-DD.log';

  @override
  String get settingsMaintenanceOnboardingAnimationGallerySubtitle =>
      'Jämför välkomstanimationer + koppla sida live (felsökning)';

  @override
  String get settingsMaintenanceOnboardingAnimationGalleryTitle =>
      'Introduktionsanimationsgalleri';

  @override
  String get settingsMaintenanceOnboardingWelcomeSubtitle =>
      'Förhandsgranska FTUE-välkomsten + leverantörsrutor (felsökning)';

  @override
  String get settingsMaintenanceOnboardingWelcomeTitle =>
      'Välkommen för introduktion av programmet';

  @override
  String get settingsMaintenanceTitle => 'Underhåll';

  @override
  String get settingsManualLanguageCzechTitle => 'Tjeckiska';

  @override
  String get settingsManualLanguageDanishTitle => 'Dansk';

  @override
  String get settingsManualLanguageDutchTitle => 'Nederländska';

  @override
  String get settingsManualLanguageEnglishTitle => 'Engelska';

  @override
  String get settingsManualLanguageFollowSystemSubtitle =>
      'Använd ditt enhetsspråk när manualen stöder det; annars använd engelska.';

  @override
  String get settingsManualLanguageFollowSystemTitle => 'Följ systemet';

  @override
  String get settingsManualLanguageFrenchTitle => 'Franska';

  @override
  String get settingsManualLanguageGermanTitle => 'Tyska';

  @override
  String get settingsManualLanguageItalianTitle => 'Italienska';

  @override
  String get settingsManualLanguagePortugueseTitle => 'Portugisiska';

  @override
  String get settingsManualLanguageRomanianTitle => 'Rumänska';

  @override
  String get settingsManualLanguageSpanishTitle => 'Spanska';

  @override
  String get settingsManualLanguageSwedishTitle => 'Svenska';

  @override
  String get settingsManualLanguageTitle => 'Språk';

  @override
  String get settingsMatrixAccept => 'Acceptera';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'Annan enhet visar emojis, fortsätt';

  @override
  String get settingsMatrixCancel => 'Avbryt';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Acceptera på annan enhet för att fortsätta';

  @override
  String get settingsMatrixDiagnosticCopied =>
      'Diagnostisk information kopierad till skrivplatta';

  @override
  String get settingsMatrixDiagnosticCopyButton => 'Kopiera till urklipp';

  @override
  String get settingsMatrixDiagnosticDialogTitle =>
      'Synkronisera diagnostisk information';

  @override
  String get settingsMatrixDiagnosticShowButton =>
      'Visa diagnostisk information';

  @override
  String get settingsMatrixDone => 'Klart';

  @override
  String get settingsMatrixLastUpdated => 'Senast uppdaterad:';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Overifierade enheter';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Kör underhållsuppgifter och återställningsverktyg för matrisen';

  @override
  String get settingsMatrixMaintenanceTitle => 'Underhåll';

  @override
  String get settingsMatrixMetrics => 'Synkroniseringsmått';

  @override
  String get settingsMatrixNextPage => 'Nästa sida';

  @override
  String get settingsMatrixNoUnverifiedLabel => 'Inga overifierade enheter';

  @override
  String get settingsMatrixPreviousPage => 'Föregående sida';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Bjud in till rum $roomId från $senderId. Acceptera?';
  }

  @override
  String get settingsMatrixRoomInviteTitle => 'Rumsinbjudan';

  @override
  String get settingsMatrixSentMessagesLabel => 'Skickade meddelanden:';

  @override
  String settingsMatrixSentMessageType(String eventType) {
    return 'Skickad ($eventType)';
  }

  @override
  String get settingsMatrixStartVerificationLabel => 'Starta verifiering';

  @override
  String get settingsMatrixStatsTitle => 'Matrisstatistik';

  @override
  String get settingsMatrixTitle => 'Synkroniseringsinställningar';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Overifierade enheter';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Avbrutet på annan enhet...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Fattar';

  @override
  String settingsMatrixVerificationSuccessLabel(
    String deviceName,
    String deviceID,
  ) {
    return 'Du har framgångsrikt verifierat $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Bekräfta på en annan enhet att emojis nedan visas på båda enheterna, i samma ordning:';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Bekräfta att emojis nedan visas på båda enheterna, i samma ordning:';

  @override
  String get settingsMatrixVerifyLabel => 'Verifiera';

  @override
  String get settingsMeasurableAggregationHelper =>
      'Hur dagens poster kombineras på diagram';

  @override
  String get settingsMeasurableAggregationLabel => 'Standardaggregeringstyp';

  @override
  String get settingsMeasurableDeleteTooltip => 'Ta bort mätbar typ';

  @override
  String get settingsMeasurableDescriptionLabel => 'Beskrivning (valfritt)';

  @override
  String get settingsMeasurableDetailsLabel => 'Redigering mätbar';

  @override
  String get settingsMeasurableNameLabel => 'Mätbart namn';

  @override
  String get settingsMeasurablePrivateLabel => 'Privat: ';

  @override
  String get settingsMeasurableSaveLabel => 'Spara';

  @override
  String get settingsMeasurablesCreateTitle => 'Skapa mätbart';

  @override
  String get settingsMeasurablesEmptyState => 'Inga mätbara faktorer än';

  @override
  String get settingsMeasurablesEmptyStateHint =>
      'Mätbara är siffror du följer över tid — vikt, vatten, steg.';

  @override
  String get settingsMeasurablesErrorLoading => 'Fellastningsmätbara';

  @override
  String settingsMeasurablesNoMatchQuery(String query) {
    return 'Inga mätbara värden matchar \"$query\"';
  }

  @override
  String get settingsMeasurablesSearchHint => 'Sök mätbara saker...';

  @override
  String get settingsMeasurablesSubtitle => 'Konfigurera mätbara datatyper';

  @override
  String get settingsMeasurablesTitle => 'Mätbara egenskaper';

  @override
  String get settingsMeasurableUnitLabel => 'Enhetsförkortning (valfritt)';

  @override
  String get settingsOnboardingActionSubtitle =>
      'Öppna välkomstflödet igen – koppla upp din AI-hjärna och skapa en uppgift';

  @override
  String get settingsOnboardingMetricsSubtitle =>
      'FTUE-tratten — installation, aktivering, retention (felsökning)';

  @override
  String get settingsOnboardingMetricsTitle => 'Onboarding-mått';

  @override
  String get settingsOnboardingReplayTitle => 'Omspelningsintroduktion';

  @override
  String get settingsOnboardingStartTitle => 'Börja onboarding';

  @override
  String get settingsOnboardingStatusActivated =>
      'Du har skapat din första AI-uppgift';

  @override
  String get settingsOnboardingStatusLoading => 'Laddar...';

  @override
  String get settingsOnboardingStatusNotActivated => 'Inte påbörjad än';

  @override
  String get settingsOnboardingStatusTitle => 'Status';

  @override
  String get settingsOnboardingSubtitle =>
      'Spela upp välkomstflödet när som helst';

  @override
  String get settingsOnboardingTestResetConfirm => 'Återställ';

  @override
  String get settingsOnboardingTestResetConfirmQuestion =>
      'Tydlig onboarding-historik och mätvärden? Befintliga Daily OS-planer finns kvar, så använd en ren profil för att testa den kompletta första genomgången av Daily OS.';

  @override
  String get settingsOnboardingTestResetSubtitle =>
      'Tydlig prompthistorik och mätvärden; befintliga Daily OS-planer finns kvar (felsökning)';

  @override
  String get settingsOnboardingTestResetTitle =>
      'Återställ onboarding-teststatus';

  @override
  String get settingsOnboardingTitle => 'Onboarding';

  @override
  String get settingsOptionsTitle => 'Alternativ';

  @override
  String get settingsRecordingStyleExplanation =>
      'Välj hur mikrofonen ser ut medan du spelar in.';

  @override
  String get settingsRecordingStyleSubtitle =>
      'VU-mätare eller energikula under inspelning';

  @override
  String get settingsRecordingStyleTitle => 'Inspelningsstil';

  @override
  String get settingsResetGeminiConfirm => 'Återställ';

  @override
  String get settingsResetGeminiConfirmQuestion =>
      'Detta visar Gemini-inställningsdialogen igen. Fortsätta?';

  @override
  String get settingsResetGeminiSubtitle =>
      'Visa Gemini AI-inställningsdialogen igen';

  @override
  String get settingsResetGeminiTitle =>
      'Återställ Gemini-inställningsdialogen';

  @override
  String get settingsResetHintsConfirm => 'Bekräfta';

  @override
  String get settingsResetHintsConfirmQuestion =>
      'Återställa ledtrådar i appen som visas i hela appen?';

  @override
  String settingsResetHintsResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Återställ $count ledtrådar',
      one: 'Återställ en ledtråd',
      zero: 'Återställ noll ledtrådar',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetHintsSubtitle =>
      'Tydliga engångstips och introduktionstips';

  @override
  String get settingsResetHintsTitle => 'Återställ tips i appen';

  @override
  String get settingsSpeechSubtitle => 'Röst och högläsning';

  @override
  String get settingsSpeechTitle => 'Tal';

  @override
  String get settingsSyncConflictsSubtitle =>
      'Lös synkroniseringskonflikter för att säkerställa datakonsistens';

  @override
  String get settingsSyncNodeProfileCapabilitiesEmpty =>
      'Ingen upptäckt — automatisk utlösning av synkroniserad ljudinferens riktar inte in sig på denna enhet.';

  @override
  String get settingsSyncNodeProfileCapabilitiesLabel =>
      'Upptäckta AI-förmågor';

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
      'Synligt för dina andra enheter när du väljer vilken du ska fästa en profil på.';

  @override
  String get settingsSyncNodeProfileDisplayNameLabel => 'Enhetens visningsnamn';

  @override
  String get settingsSyncNodeProfileKnownNodesEmpty =>
      'Inga andra enheter har ännu publicerat en profil.';

  @override
  String get settingsSyncNodeProfileKnownNodesTitle => 'Kända synkenheter';

  @override
  String get settingsSyncNodeProfileSaveButton => 'Spara';

  @override
  String get settingsSyncNodeProfileSubtitle =>
      'Namnge denna enhet och granska funktioner som är synliga för dina andra enheter.';

  @override
  String get settingsSyncNodeProfileTitle => 'Den här apparaten';

  @override
  String get settingsSyncOutboxTitle => 'Sync Outbox';

  @override
  String get settingsSyncStatsSubtitle => 'Inspektera synkpipeline-metrik';

  @override
  String get settingsSyncSubtitle => 'Konfigurera synk och visa statistik';

  @override
  String get settingsThemingAutomatic => 'Automatisk';

  @override
  String get settingsThemingDark => 'Mörkt utseende';

  @override
  String get settingsThemingLight => 'Ljusets utseende';

  @override
  String get settingsThemingSubtitle => 'Anpassa appens utseende och teman';

  @override
  String get settingsThemingTitle => 'Tematisering';

  @override
  String get settingsV2CategoryEmptyBody =>
      'Välj en underinställning till vänster.';

  @override
  String get settingsV2DetailRootCrumb => 'Miljöer';

  @override
  String get settingsV2EmptyStateBody =>
      'Välj en sektion till vänster för att börja.';

  @override
  String get settingsV2ResizeHandleLabel => 'Ändra storleksinställningsträd';

  @override
  String get settingsV2UnimplementedTitle =>
      'Panelen har ännu inte implementerats';

  @override
  String get settingsWhatsNewSubtitle =>
      'Se de senaste uppdateringarna och funktionerna';

  @override
  String get settingsWhatsNewTitle => 'Vad är nytt';

  @override
  String get settingThemingDark => 'Mörkt tema';

  @override
  String get settingThemingLight => 'Ljustema';

  @override
  String get sidebarActiveSectionTitle => 'Verksamhet';

  @override
  String get sidebarActivityCollapseTooltip => 'Kollapsaktivitet';

  @override
  String get sidebarActivityExpandTooltip => 'Utöka verksamheten';

  @override
  String get sidebarAudioRecordingStatusLabel => 'Inspelning';

  @override
  String get sidebarRunningTimerLabel => 'Löptimer';

  @override
  String get sidebarRunningTimerStopTooltip => 'Stopptimer';

  @override
  String get sidebarTimerStatusLabel => 'Öppettider';

  @override
  String get sidebarToggleCollapseLabel => 'Kollaps-sidofält';

  @override
  String get sidebarToggleExpandLabel => 'Utöka sidofältet';

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
  String get sidebarWakesCancelTooltip => 'Avbrytningsagent';

  @override
  String get sidebarWakesHeader => 'Agenter';

  @override
  String get sidebarWakesNow => 'Nu';

  @override
  String get sidebarWakesOpenList => 'Öppen lista';

  @override
  String get sidebarWakesOpenTask => 'Öppen uppgift';

  @override
  String sidebarWakesQueuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count köad ',
      one: '1 köad',
    );
    return '$_temp0';
  }

  @override
  String get sidebarWakesQueuedLabel => 'Köad';

  @override
  String get sidebarWakesWorkingLabel => 'Arbete';

  @override
  String get skillsSectionTitle => 'Färdigheter';

  @override
  String get speechDictionaryHelper =>
      'Separerade semikolontermer (max 50 tecken) för bättre taligenkänning';

  @override
  String get speechDictionaryHint => 'macOS; Kirkjubæjarklaustur; Claude Code';

  @override
  String get speechDictionaryLabel => 'Talordbok';

  @override
  String get speechDictionarySectionDescription =>
      'Lägg till termer som ofta stavas fel av taligenkänning (namn, platser, tekniska termer)';

  @override
  String get speechDictionarySectionTitle => 'Taligenkänning';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Stora ordböcker ($count-termer) kan öka API-kostnaderna';
  }

  @override
  String get speechModalSelectLanguage => 'Välj språk';

  @override
  String get speechModalTitle => 'Taligenkänning';

  @override
  String get speechSettingsModelDescription => 'Talmodell på enheten';

  @override
  String get speechSettingsModelDownloadsOnce => 'Nedladdningar en gång';

  @override
  String get speechSettingsModelLabel => 'Modell';

  @override
  String get speechSettingsRecommendedBadge => 'Rekommenderas';

  @override
  String get speechSettingsSpeedDescription =>
      'Hur snabbt sammanfattningar läses';

  @override
  String get speechSettingsSpeedLabel => 'Läshastighet';

  @override
  String get speechSettingsVoiceDescription =>
      'Välj rösten som läser sammanfattningar högt';

  @override
  String get speechSettingsVoiceLabel => 'Röst';

  @override
  String get speechVoiceGenderFemale => 'Kvinna';

  @override
  String get speechVoiceGenderMale => 'Manlig';

  @override
  String get speechVoicePreviewTooltip => 'Förhandsvisningsröst';

  @override
  String get surveyBackButton => 'Tillbaka';

  @override
  String get surveyCancelConfirmation => 'Avbryta undersökningen?';

  @override
  String get surveyChooseOneOption => 'Välj ett alternativ';

  @override
  String get surveyChooseOneOrMoreOptions => 'Välj ett eller flera alternativ';

  @override
  String get surveyDiscardConfirmation => 'Kassera resultaten och sluta?';

  @override
  String get surveyInputNumberValidation => 'Ange ett nummer';

  @override
  String get surveyNextButton => 'Nästa';

  @override
  String get surveyNoButton => 'Nej';

  @override
  String get surveyProgressOf => 'av';

  @override
  String get surveyTapToAnswer => 'Tryck för att svara';

  @override
  String get surveyValueAnd => 'och';

  @override
  String get surveyValueBetween => 'Måste vara mitt emellan';

  @override
  String get surveyYesButton => 'Ja';

  @override
  String get syncActivityIdle => 'vila';

  @override
  String get syncActivityInboxLabel => 'Inkorg';

  @override
  String syncActivityIndicatorSemantics(int outbox, int inbox) {
    return 'Synkronisera aktiviteten. Utbox: $outbox. Inkorg: $inbox. Öppna synkutkorgen.';
  }

  @override
  String get syncActivityOutboxLabel => 'Utbox';

  @override
  String get syncActivitySyncingTitle => 'Synkronisering';

  @override
  String get syncActivityTitle => 'Synk';

  @override
  String get syncDeleteConfigConfirm => 'JA, JAG ÄR SÄKER';

  @override
  String get syncDeleteConfigQuestion =>
      'Vill du ta bort synkroniseringskonfigurationen?';

  @override
  String get syncEntitiesConfirm => 'STARTA SYNKRONISERING';

  @override
  String get syncEntitiesMessage => 'Välj de enheter du vill synka.';

  @override
  String get syncEntitiesSuccessDescription => 'Allt är uppdaterat.';

  @override
  String get syncEntitiesSuccessTitle => 'Synkronisering klar';

  @override
  String syncListCountSummary(String label, int itemCount) {
    String _temp0 = intl.Intl.pluralLogic(
      itemCount,
      locale: localeName,
      other: '$itemCount föremål',
      one: '1 föremål',
      zero: '0 föremål',
    );
    return '$label · $_temp0';
  }

  @override
  String get syncListPayloadKindLabel => 'Nyttolast';

  @override
  String get syncListUnknownPayload => 'Okänd last';

  @override
  String get syncNotLoggedInToast => 'Sync är inte inloggad';

  @override
  String get syncPayloadAgentBundle => 'Agentbunt';

  @override
  String get syncPayloadAgentEntity => 'Agentenhet';

  @override
  String get syncPayloadAgentLink => 'Agentlänk';

  @override
  String get syncPayloadAiConfig => 'AI-konfiguration';

  @override
  String get syncPayloadAiConfigDelete => 'AI-konfigurationsborttagning';

  @override
  String get syncPayloadBackfillRequest => 'Begäran om återfyllning';

  @override
  String get syncPayloadBackfillResponse => 'Återfyllningsrespons';

  @override
  String get syncPayloadConfigFlag => 'Konfigurationsflagga';

  @override
  String get syncPayloadConsumptionEvent => 'AI-konsumtion';

  @override
  String get syncPayloadDailyOsUserName => 'Daily OS-namn';

  @override
  String get syncPayloadEntityDefinition => 'Entitetsdefinition';

  @override
  String get syncPayloadEntryLink => 'Inträdeslänk';

  @override
  String get syncPayloadJournalEntity => 'Dagboksanteckning';

  @override
  String get syncPayloadNotification => 'Meddelande';

  @override
  String get syncPayloadNotificationStateUpdate =>
      'Uppdatering av notifikationstillstånd';

  @override
  String get syncPayloadOutboxBundle => 'Utboxspaket';

  @override
  String get syncPayloadSavedTaskFilter => 'Sparat uppgiftsfilter';

  @override
  String get syncPayloadSavedTaskFilterDelete =>
      'Sparad uppgiftsfilter borttagning';

  @override
  String get syncPayloadSyncNodeProfile => 'Synknodprofil';

  @override
  String get syncPayloadThemingSelection => 'Tematval';

  @override
  String get syncStepAgentEntities => 'Agententiteter';

  @override
  String get syncStepAgentLinks => 'Agentlänkar';

  @override
  String get syncStepAiSettings => 'AI-inställningar';

  @override
  String get syncStepBackfillAgentEntityClocks =>
      'Urtagningsagentens enhetsklockor';

  @override
  String get syncStepBackfillAgentLinkClocks =>
      'Klockor för backfill agent link';

  @override
  String get syncStepCategories => 'Kategorier';

  @override
  String get syncStepComplete => 'Komplett';

  @override
  String get syncStepDashboards => 'Instrumentpaneler';

  @override
  String get syncStepHabits => 'Habiter';

  @override
  String get syncStepLabels => 'Etiketter';

  @override
  String get syncStepMeasurables => 'Mätbara egenskaper';

  @override
  String get syncStepSavedTaskFilters => 'Sparade uppgiftsfilter';

  @override
  String get taskActionBarAudioRecordingActive => 'Ljudinspelning pågår';

  @override
  String get taskActionBarMoreActions => 'Fler åtgärder';

  @override
  String get taskActionBarOpenRunningTimer => 'Öppen löptimer';

  @override
  String get taskActionBarStopTracking => 'Stopptidsspårning';

  @override
  String get taskActionBarTrackTime => 'Bantid';

  @override
  String get taskAgentAttributionUnavailable => 'Källa otillgänglig';

  @override
  String get taskAgentAutomaticUpdatesLabel => 'Automatiska uppdateringar';

  @override
  String get taskAgentAutomaticUpdatesNeedsSetup =>
      'Välj en AI-lösning innan du slår på automatiska uppdateringar.';

  @override
  String get taskAgentCancelTimerTooltip =>
      'Avboka väntande automatisk uppdatering';

  @override
  String get taskAgentChooseModel => 'Välj en tänkande modell';

  @override
  String get taskAgentChooseProfile => 'Välj en inferensprofil';

  @override
  String taskAgentCountdownTooltip(String countdown) {
    return 'Nästa auto-körning i $countdown';
  }

  @override
  String get taskAgentCreateChipLabel => 'Tilldelad agent';

  @override
  String taskAgentCreateError(String error) {
    return 'Misslyckades med att skapa agent: $error';
  }

  @override
  String get taskAgentCurrentSetupHeader => 'Nuvarande upplägg';

  @override
  String get taskAgentCurrentSetupLabel => 'Nuvarande upplägg';

  @override
  String get taskAgentDirectModelOverride => 'Direkt modellöverstyrning';

  @override
  String get taskAgentDisableConfirmAction => 'Stäng av';

  @override
  String get taskAgentDisableConfirmBody =>
      'Den aktuella rapporten förblir synlig, men denna agent kan inte köras förrän du väljer en setup.';

  @override
  String get taskAgentDisableConfirmTitle => 'Stänga av AI för denna agent?';

  @override
  String get taskAgentInferenceProfileLabel => 'Inferensprofil';

  @override
  String get taskAgentModelPickerTitle => 'Välj tänkandemodell';

  @override
  String taskAgentNextUpdateIn(String countdown) {
    return 'Nästa uppdatering i $countdown';
  }

  @override
  String get taskAgentNoAiSetup => 'Ingen AI-installation';

  @override
  String get taskAgentNoAiSetupDescription =>
      'Pausar agentens inferens tills du väljer en profil eller modell.';

  @override
  String get taskAgentNoModelsAvailable =>
      'Inga kompatibla tänkande modeller tillgängliga';

  @override
  String get taskAgentNoProfilesAvailable =>
      'Inga profiler tillgängliga på denna enhet';

  @override
  String get taskAgentNoProfileSelected => 'Ingen AI-installation';

  @override
  String get taskAgentNoProfileSelectedDescription =>
      'Välj en sparad setup eller tänkmodell innan denna agent kan köras.';

  @override
  String taskAgentProfileChangedToast(String profile) {
    return 'Använder $profile för varje framtida agentuppdatering tills du ändrar den.';
  }

  @override
  String get taskAgentProfileDefaultBadge => 'Profilstandard';

  @override
  String get taskAgentReportOutdatedTitle =>
      'Denna sammanfattning är föråldrad';

  @override
  String get taskAgentReportUpToDate => 'Sammanfattningen är uppdaterad';

  @override
  String get taskAgentRouteVia => 'Gata';

  @override
  String get taskAgentRunNowTooltip => 'Spring nu';

  @override
  String get taskAgentSavingSetup => 'Inställning av sparande agenter';

  @override
  String taskAgentSetupAndReportSemantics(String identity) {
    return 'Denna rapport och nuvarande setup använder $identity. Aktivera för att ändra inställningen.';
  }

  @override
  String get taskAgentSetupBroken => 'Vald AI-installation är inte tillgänglig';

  @override
  String taskAgentSetupChangedToast(String model) {
    return 'Använder $model för varje framtida agentuppdatering tills du ändrar den.';
  }

  @override
  String get taskAgentSetupChoiceHelp =>
      'Välj en profil för dess standardvärden, eller åsidosätt bara tänkande modellen.';

  @override
  String get taskAgentSetupOriginCategory =>
      'Kopierat från kategoristandarden när denna agent skapades';

  @override
  String get taskAgentSetupOriginDisabled => 'Funktionsnedsatt';

  @override
  String get taskAgentSetupOriginLegacy => 'Legacy-upplägg';

  @override
  String get taskAgentSetupOriginTemplate => 'Kopierat från mallen';

  @override
  String get taskAgentSetupOriginUser => 'Du valde det här för den här agenten';

  @override
  String get taskAgentSetupPersistenceDescription =>
      'Ändringar gäller för varje framtida uppdatering tills du ändrar dem.';

  @override
  String taskAgentSetupSemantics(String identity) {
    return 'Nuvarande uppställning: $identity. Aktivera för att ändra inställningen.';
  }

  @override
  String get taskAgentSetupTitle => 'Agentuppsättning';

  @override
  String get taskAgentThinkingModelLabel => 'Tänkande modell';

  @override
  String get taskAgentThisReportHeader => 'Denna rapport';

  @override
  String get taskAgentTurnOffSetup => 'Stäng av AI för denna agent';

  @override
  String get taskAgentUseCategoryDefault => 'Kopiera kategori standard';

  @override
  String get taskAgentUseCategoryDefaultDescription =>
      'Kopierar kategorins nuvarande uppställning. Senare kategoriändringar påverkar inte denna agent.';

  @override
  String get taskAgentUseProfileDefault => 'Använd profilstandard';

  @override
  String get taskAgentWakeAgent => 'Wake-agent';

  @override
  String get taskCategoryAllLabel => 'alla';

  @override
  String get taskCategoryLabel => 'Kategori:';

  @override
  String get taskCategoryUnassignedLabel => 'ej tilldelad';

  @override
  String get taskDueDateLabel => 'Beräknat datum';

  @override
  String taskDueDateWithDate(String date) {
    return 'Förfaller: $date';
  }

  @override
  String taskDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagar',
      one: '1 dag',
    );
    return 'Förfaller om $_temp0';
  }

  @override
  String get taskDueToday => 'Ska lämnas in idag';

  @override
  String get taskDueTomorrow => 'Ska vara klar imorgon';

  @override
  String get taskDueYesterday => 'Inlämning igår';

  @override
  String get taskEditTitleLabel => 'Redigera uppgiftstitel';

  @override
  String get taskEstimateLabel => 'Uppskattning:';

  @override
  String get taskEstimateModalTitle => 'Uppskattning';

  @override
  String taskEstimateProgressLabel(String tracked, String estimate) {
    return '$tracked av $estimate';
  }

  @override
  String taskEstimateTooltip(String tracked, String estimate) {
    return 'Tid spårad: $tracked av $estimate uppskattad';
  }

  @override
  String taskLabelsMoreCount(int count) {
    return '+$count';
  }

  @override
  String get taskLabelsShowFewer => 'Visa färre';

  @override
  String get taskLanguageArabic => 'Arabiska';

  @override
  String get taskLanguageBengali => 'Bengali';

  @override
  String get taskLanguageBulgarian => 'Bulgariska';

  @override
  String get taskLanguageChinese => 'Kinesiska';

  @override
  String get taskLanguageCroatian => 'Kroatisk';

  @override
  String get taskLanguageCzech => 'Tjeckiska';

  @override
  String get taskLanguageDanish => 'Dansk';

  @override
  String get taskLanguageDutch => 'Nederländska';

  @override
  String get taskLanguageEnglish => 'Engelska';

  @override
  String get taskLanguageEstonian => 'Estniska';

  @override
  String get taskLanguageFinnish => 'Finska';

  @override
  String get taskLanguageFrench => 'Franska';

  @override
  String get taskLanguageGerman => 'Tyska';

  @override
  String get taskLanguageGreek => 'Grekiska';

  @override
  String get taskLanguageHebrew => 'Hebreiska';

  @override
  String get taskLanguageHindi => 'Hindi';

  @override
  String get taskLanguageHungarian => 'Ungerskt';

  @override
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageIndonesian => 'Indonesiska';

  @override
  String get taskLanguageItalian => 'Italienska';

  @override
  String get taskLanguageJapanese => 'Japanska';

  @override
  String get taskLanguageKorean => 'Koreanska';

  @override
  String get taskLanguageLabel => 'Språk';

  @override
  String get taskLanguageLatvian => 'Lettiska';

  @override
  String get taskLanguageLithuanian => 'Litauiska';

  @override
  String get taskLanguageNigerianPidgin => 'Nigeriansk Pidgin';

  @override
  String get taskLanguageNorwegian => 'Norska';

  @override
  String get taskLanguagePolish => 'Polska';

  @override
  String get taskLanguagePortuguese => 'Portugisiska';

  @override
  String get taskLanguageRomanian => 'Rumänska';

  @override
  String get taskLanguageRussian => 'Ryska';

  @override
  String get taskLanguageSelectedLabel => 'För närvarande utvald';

  @override
  String get taskLanguageSerbian => 'Serbiska';

  @override
  String get taskLanguageSetAction => 'Setspråk';

  @override
  String get taskLanguageSlovak => 'Slovakiska';

  @override
  String get taskLanguageSlovenian => 'Slovenska';

  @override
  String get taskLanguageSpanish => 'Spanska';

  @override
  String get taskLanguageSwahili => 'Swahili';

  @override
  String get taskLanguageSwedish => 'Svenska';

  @override
  String get taskLanguageThai => 'Thai';

  @override
  String get taskLanguageTurkish => 'Turkiska';

  @override
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageUkrainian => 'Ukrainska';

  @override
  String get taskLanguageVietnamese => 'Vietnameser';

  @override
  String get taskLanguageYoruba => 'Yoruba';

  @override
  String get taskNoDueDateLabel => 'Ingen beräknad förlossningsdag';

  @override
  String get taskNoEstimateLabel => 'Ingen uppskattning';

  @override
  String taskOverdueByDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagar',
      one: '1 dag',
    );
    return 'försenad med $_temp0';
  }

  @override
  String get taskPriorityHigh => 'Högt';

  @override
  String get taskPriorityLow => 'Lågt';

  @override
  String get taskPriorityMedium => 'Medium';

  @override
  String get taskPriorityUrgent => 'Brådskande';

  @override
  String get tasksAddLabelButton => 'Lägg till etikett';

  @override
  String get tasksAgentFilterAll => 'Alla';

  @override
  String get tasksAgentFilterHasAgent => 'Har agent';

  @override
  String get tasksAgentFilterNoAgent => 'Ingen agent';

  @override
  String get tasksAgentFilterTitle => 'Agent';

  @override
  String get tasksFilterApplyTitle => 'Använd filter';

  @override
  String get tasksFilterClearAll => 'Rensa allt';

  @override
  String get tasksFilterTitle => 'Filtrera uppgifter';

  @override
  String get taskShowcaseAudio => 'Ljud';

  @override
  String taskShowcaseCompletedCount(int completed, int total) {
    return '$completed / $total färdigt';
  }

  @override
  String taskShowcaseDueDate(String date) {
    return 'Två: $date';
  }

  @override
  String get taskShowcaseJumpToSection => 'Hoppa till avsnitt';

  @override
  String get taskShowcaseLinked => 'Länkad';

  @override
  String get taskShowcaseNoResults => 'Inga uppgifter matchar din sökning.';

  @override
  String get taskShowcaseReadMore => 'Läs mer';

  @override
  String taskShowcaseRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inspelningar',
      one: '1 inspelning',
    );
    return '$_temp0';
  }

  @override
  String taskShowcaseTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uppgifter',
      one: '1 uppgift',
    );
    return '$_temp0';
  }

  @override
  String get taskShowcaseTaskDescription => 'Uppgiftsbeskrivning';

  @override
  String get taskShowcaseTimeTracker => 'Tidsspårare';

  @override
  String get taskShowcaseTodo => 'Alla';

  @override
  String get taskShowcaseTodos => 'Alla';

  @override
  String get tasksLabelFilterAll => 'Alla';

  @override
  String get tasksLabelFilterTitle => 'Etikett';

  @override
  String get tasksLabelFilterUnlabeled => 'Omärkt';

  @override
  String get tasksLabelsDialogClose => 'Stäng';

  @override
  String get tasksLabelsSheetApply => 'Ansök';

  @override
  String get tasksLabelsSheetSearchHint => 'Söketiketter...';

  @override
  String get tasksLabelsUpdateFailed =>
      'Misslyckades med att uppdatera etiketterna';

  @override
  String get tasksPriorityFilterAll => 'Alla';

  @override
  String get tasksPriorityFilterTitle => 'Prioritet';

  @override
  String get tasksPriorityP0 => 'Brådskande';

  @override
  String get tasksPriorityP0Description => 'Brådskande (så snart som möjligt)';

  @override
  String get tasksPriorityP1 => 'Högt';

  @override
  String get tasksPriorityP1Description => 'Hög (snart)';

  @override
  String get tasksPriorityP2 => 'Medium';

  @override
  String get tasksPriorityP2Description => 'Medium (Standard)';

  @override
  String get tasksPriorityP3 => 'Lågt';

  @override
  String get tasksPriorityP3Description => 'Lågt (när som helst)';

  @override
  String get tasksPriorityPickerTitle => 'Välj prioritet';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Otilldelat';

  @override
  String get tasksSavedFilterDeleteConfirmTooltip =>
      'Tryck igen för att ta bort';

  @override
  String get tasksSavedFilterDeleteTooltip => 'Ta bort sparat filter';

  @override
  String get tasksSavedFilterDragHandleSemantics => 'Dra för att omordna';

  @override
  String get tasksSavedFilterRenameSemantics => 'Byt namn på sparat filter';

  @override
  String get tasksSavedFiltersAllShort => 'Alla';

  @override
  String get tasksSavedFiltersAllTasks => 'Alla uppgifter';

  @override
  String get tasksSavedFiltersCustom => 'Sedvänja';

  @override
  String get tasksSavedFiltersDeleteConfirmAction => 'Radera';

  @override
  String tasksSavedFiltersDeleteConfirmMessage(String name) {
    return 'Radera det sparade filtret \'$name\'? Det här kan inte göras ogjort.';
  }

  @override
  String tasksSavedFiltersDeleteConfirmNamed(String name) {
    return 'Bekräfta ta bort $name';
  }

  @override
  String tasksSavedFiltersDeleteNamed(String name) {
    return 'Radera $name';
  }

  @override
  String get tasksSavedFiltersDone => 'Klart';

  @override
  String get tasksSavedFiltersEdit => 'Redigering';

  @override
  String get tasksSavedFiltersFilterNameLabel => 'Filternamn';

  @override
  String get tasksSavedFiltersGroupSemantics => 'Uppgiftsfilter';

  @override
  String get tasksSavedFiltersManageTooltip => 'Hantera uppgiftsfilter';

  @override
  String get tasksSavedFiltersRailButton => 'Filter';

  @override
  String tasksSavedFiltersRenameNamed(String name) {
    return 'Byt namn på $name';
  }

  @override
  String get tasksSavedFiltersReorderHelper =>
      'Dra för att ställa in ordningen. De fem första filtren finns i sidofältet.';

  @override
  String get tasksSavedFiltersSaveAsNewButtonLabel => 'Spara som ny...';

  @override
  String get tasksSavedFiltersSaveAsNewDescription =>
      'Låt det befintliga filtret vara oförändrat och skapa ett separat.';

  @override
  String get tasksSavedFiltersSaveAsNewTitle => 'Spara som ett nytt filter';

  @override
  String get tasksSavedFiltersSaveButtonLabel => 'Spara filter...';

  @override
  String get tasksSavedFiltersSaveChoiceIntro =>
      'Välj om du vill uppdatera sparat filter eller skapa ett separat.';

  @override
  String get tasksSavedFiltersSaveChoiceTitle => 'Spara filter';

  @override
  String get tasksSavedFiltersSaveCurrentAs => 'Spara strömfilter...';

  @override
  String get tasksSavedFiltersSaveError =>
      'Kunde inte rädda det här filtret. Försök igen.';

  @override
  String get tasksSavedFiltersSavePageHelper =>
      'Ge detta filter ett kort namn. Du kan ordna om det senare i Uppgiftsfiltren.';

  @override
  String get tasksSavedFiltersSavePopupCancel => 'Avbryt';

  @override
  String get tasksSavedFiltersSavePopupHint =>
      't.ex. blockerad eller i vänteläge';

  @override
  String get tasksSavedFiltersSavePopupSave => 'Spara';

  @override
  String get tasksSavedFiltersSavePopupTitle => 'Namnge detta filter';

  @override
  String get tasksSavedFiltersSheetTitle => 'Uppgiftsfilter';

  @override
  String get tasksSavedFiltersShowLess => 'Visa färre';

  @override
  String tasksSavedFiltersShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fler sparade filter',
      one: '1 fler sparade filter',
    );
    return '$_temp0';
  }

  @override
  String tasksSavedFiltersTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uppgifter',
      one: '1 uppgift',
    );
    return '$_temp0';
  }

  @override
  String get tasksSavedFiltersUpdateButtonLabel => 'Uppdateringsfilter';

  @override
  String get tasksSavedFiltersUpdateExistingDescription =>
      'Byt ut dess sparade kriterier mot den nuvarande filterkonfigurationen.';

  @override
  String get tasksSavedFiltersUpdateExistingTitle =>
      'Uppdatera befintligt filter';

  @override
  String get tasksSavedFilterToastDeleted => 'Filter borttaget';

  @override
  String tasksSavedFilterToastSaved(String name) {
    return 'Filtret \'$name\' sparades';
  }

  @override
  String tasksSavedFilterToastUpdated(String name) {
    return 'Filtret \'$name\' uppdaterades';
  }

  @override
  String get tasksSearchModeLabel => 'Sökläge';

  @override
  String get tasksShowCreationDate => 'Showens skapandedatum på korten';

  @override
  String get tasksShowDueDate => 'Visa inlämningsdatum på korten';

  @override
  String get tasksSortByCreationDate => 'Skapad';

  @override
  String get tasksSortByDueDate => 'Beräknat datum';

  @override
  String get tasksSortByLabel => 'Sortera efter';

  @override
  String get tasksSortByPriority => 'Prioritet';

  @override
  String get taskStatusAll => 'Alla';

  @override
  String get taskStatusBlocked => 'Blockerad';

  @override
  String get taskStatusDone => 'Klart';

  @override
  String get taskStatusGroomed => 'Välvårdad';

  @override
  String get taskStatusInProgress => 'Pågående';

  @override
  String get taskStatusLabel => 'Status:';

  @override
  String get taskStatusOnHold => 'På vänt';

  @override
  String get taskStatusOpen => 'Öppet';

  @override
  String get taskStatusRejected => 'Avvisad';

  @override
  String get taskTitleEmpty => 'Ingen titel';

  @override
  String get taskUntitled => '(utan titel)';

  @override
  String get thinkingDisclosureCopied => 'Motivering kopierad';

  @override
  String get thinkingDisclosureCopy => 'Kopiera resonemang';

  @override
  String get thinkingDisclosureHide => 'Göm resonemanget';

  @override
  String get thinkingDisclosureShow => 'Show-resonemang';

  @override
  String get thinkingDisclosureStateCollapsed => 'kollapsade';

  @override
  String get thinkingDisclosureStateExpanded => 'Utökad';

  @override
  String get timeEntryItemEnd => 'Slut';

  @override
  String get timeEntryItemRunning => 'Löpning';

  @override
  String get timeEntryItemStart => 'Start';

  @override
  String get unlinkButton => 'Avlänka';

  @override
  String get unlinkTaskConfirm =>
      'Är du säker på att du vill koppla bort denna uppgift?';

  @override
  String get unlinkTaskTitle => 'Koppla bort uppgiften';

  @override
  String vectorSearchTiming(int elapsed, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${elapsed}ms, $count resultat',
      one: '${elapsed}ms, $count resultat',
    );
    return '$_temp0';
  }

  @override
  String get viewMenuTitle => 'Vy';

  @override
  String get viewMenuZoomIn => 'Zooma in';

  @override
  String get viewMenuZoomOut => 'Zooma ut';

  @override
  String get viewMenuZoomReset => 'Faktisk storlek';

  @override
  String get whatsNewBadgeNew => 'NYTT';

  @override
  String get whatsNewDoneButton => 'Klart';

  @override
  String get whatsNewSkipButton => 'Hoppa över';
}
